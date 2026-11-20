unit ta_esphome;
{ Izrada ESPHome konfiguracije (YAML) za ESP32 u pogonu iz tablica aplikacije "Proizvodni procesi": pogoni (pogon), uredjaji (senzori i izlazi),
  lokacije (vremenska zona). Uredjaj ima model i prikljucke (polja model, pin, pin2, adresa, invertirano, kal_a, kal_b).

  Modeli senzora: dht22, sht3x, ds18b20, bh1750, adc (uz kalibraciju vrijednost = kal_a * ocitanje + kal_b).
  Modeli izlaza: rele (svjetlo, pumpa, ventilator...), dozator (pumpa koja radi izracunato trajanje), prozor (dva releja, pomicni).

  Protokol je isti kao u mostu procesi_most.py:
    <tema pogona>/<tema uredjaja>/stanje      broj ili ON/OFF
    <tema pogona>/<tema uredjaja>/set         JSON {"id","akcija","vrijednost","kolicina","trajanje_s"}; uredjaj odgovara na .../ack s {"id"}
    <tema pogona>/<tema uredjaja>/raspored    JSON s stavkama; izlaz ga izvrsava sam (ta_esphome_h.inc = procesi_raspored.h)
    <tema pogona>/status                      online / offline (last will)
  Prikljucci i modeli koje generator ne poznaje ne ruse izradu: u dnevnik ide upozorenje, a uredjaj se preskace. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta;

{ YAML jednog pogona; ALog dobiva upozorenja }
function EspHomeConfig(ADb: TAppDb; AProstorId: Integer; ALog: TStrings): string;
{ svi pogoni koji imaju temu: <ime>.yaml, procesi_raspored.h i secrets.yaml.example u mapi; vraca broj pogona }
function EspHomeExportAll(ADb: TAppDb; const ADir: string; ALog: TStrings): Integer;
{ zaglavlje procesi_raspored.h kao tekst }
function EspHomeHeader: string;

implementation

uses
  StrUtils, ZDataset;

{$I ta_esphome_h.inc}

function EspHomeHeader: string;
begin
  Result := EspHomeRasporedH;
end;

function Q(const S: string): string;
begin
  Result := '"' + StringReplace(StringReplace(S, '\', '\\', [rfReplaceAll]), '"', '\"', [rfReplaceAll]) + '"';
end;

{ identifikator: mala slova, znamenke i _ }
function Ident(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if C in ['A'..'Z'] then C := Chr(Ord(C) + 32);
    if C in ['a'..'z', '0'..'9'] then Result := Result + C
    else if (Result <> '') and (Result[Length(Result)] <> '_') then Result := Result + '_';
  end;
  Result := Trim(Result);
  while (Result <> '') and (Result[Length(Result)] = '_') do Delete(Result, Length(Result), 1);
  if (Result = '') or (Result[1] in ['0'..'9']) then Result := 'x' + Result;
end;

function HostName(const ATema: string; AId: Integer): string;
var
  P, I: Integer;
  S: string;
begin
  S := ATema;
  P := LastDelimiter('/', S);
  if P > 0 then S := Copy(S, P + 1, MaxInt);
  Result := '';
  for I := 1 to Length(S) do
    if S[I] in ['a'..'z', 'A'..'Z', '0'..'9'] then Result := Result + LowerCase(S[I])
    else if (Result <> '') and (Result[Length(Result)] <> '-') then Result := Result + '-';
  while (Result <> '') and (Result[Length(Result)] = '-') do Delete(Result, Length(Result), 1);
  if Result = '' then Result := 'pogon' + IntToStr(AId);
end;

function PinOf(const S: string): string;
var
  T: string;
  I: Integer;
  Digits: Boolean;
begin
  T := Trim(S);
  Digits := T <> '';
  for I := 1 to Length(T) do if not (T[I] in ['0'..'9']) then Digits := False;
  if Digits then Result := 'GPIO' + T else Result := T;
end;

function Num(const S: string): string;
begin
  Result := StringReplace(S, ',', '.', [rfReplaceAll]);
end;

type
  TDev = record
    Id: Integer;
    Name, Tema, Ident, Model, Pin, Pin2, Addr, Vrsta, Role, Jedinica: string;
    Inv: Boolean;
    KalA, KalB, MlMin: string;
    MaxS: Integer;
    HasA, HasB: Boolean;
  end;

function IsTemp(const D: TDev): Boolean;
begin
  Result := Pos('temperatura', LowerCase(D.Vrsta)) > 0;
end;

function IsHum(const D: TDev): Boolean;
begin
  Result := (Pos('vlaga zraka', LowerCase(D.Vrsta)) > 0) or ((Pos('vlaga', LowerCase(D.Vrsta)) > 0) and (D.Model <> 'adc'));
end;

procedure Add(L: TStrings; const S: string);
begin
  L.Add(S);
end;

function EspHomeConfig(ADb: TAppDb; AProstorId: Integer; ALog: TStrings): string;
var
  Qr: TZQuery;
  Devs: array of TDev;
  N, I, J: Integer;
  Prefix, Naziv, Tema, Zona, Board: string;
  Y: TStringList;
  Sched: TStringList;     { id-evi izlaza s rasporedom, redom }
  SchedKind: TStringList; { 'sw' ili 'cv' }
  NeedI2c, NeedOneWire, HasSensor, HasSwitch, HasCover, HasScript: Boolean;
  Done: array of Boolean;
  D, E: TDev;
  OwPin: string;

  procedure Warn(const S: string);
  begin
    if ALog <> nil then ALog.Add(Naziv + ': ' + S);
  end;

  function Topic(const D: TDev; const Suf: string): string;
  begin
    Result := Prefix + '/' + D.Tema + '/' + Suf;
  end;

  procedure SensorHead(const D: TDev; AIndent: string; const AKey: string);
  begin
    Add(Y, AIndent + AKey + ':');
    Add(Y, AIndent + '  id: s_' + D.Ident);
    Add(Y, AIndent + '  name: ' + Q(D.Name));
    Add(Y, AIndent + '  state_topic: ' + Q(Topic(D, 'stanje')));
    if D.Jedinica <> '' then Add(Y, AIndent + '  unit_of_measurement: ' + Q(D.Jedinica));
  end;

  procedure Ack(const D: TDev; AIndent: string);
  begin
    Add(Y, AIndent + '- mqtt.publish_json:');
    Add(Y, AIndent + '    topic: ' + Q(Topic(D, 'ack')));
    Add(Y, AIndent + '    payload: |-');
    Add(Y, AIndent + '      root["id"] = x["id"];');
  end;

begin
  Result := '';
  Qr := ADb.NewQuery('SELECT p.naziv, p.tema, p.ploca, l.zona FROM pogoni p LEFT JOIN lokacije l ON l.id = p.lokacija_id WHERE p.id = :p');
  try
    Qr.ParamByName('p').AsInteger := AProstorId;
    Qr.Open;
    if Qr.EOF then Exit;
    Naziv := Qr.FieldByName('naziv').AsString;
    Tema := Trim(Qr.FieldByName('tema').AsString);
    Board := Trim(Qr.FieldByName('ploca').AsString);
    Zona := Trim(Qr.FieldByName('zona').AsString);
  finally
    Qr.Free;
  end;
  if Tema = '' then begin if ALog <> nil then ALog.Add(Naziv + ': pogon nema MQTT temu (polje tema)'); Exit; end;
  if Board = '' then Board := 'esp32dev';
  if Zona = '' then Zona := 'Europe/Zagreb';
  Prefix := Tema;
  { uredjaji }
  Qr := ADb.NewQuery('SELECT u.id, u.naziv, u.tema, u.model, u.pin, u.pin2, u.adresa, u.invertirano, u.kal_a, u.kal_b, u.ml_po_min, u.najdulje_s, ' +
    'v.naziv AS vrsta, v.uloga, v.jedinica FROM uredjaji u JOIN vrste_uredjaja v ON v.id = u.vrsta_id ' +
    'WHERE u.pogon_id = :p AND COALESCE(u.aktivan, 1) = 1 ORDER BY u.id');
  try
    Qr.ParamByName('p').AsInteger := AProstorId;
    Qr.Open;
    N := 0;
    while not Qr.EOF do
    begin
      FillChar(D, SizeOf(D), 0);
      D.Id := Qr.FieldByName('id').AsInteger;
      D.Name := Qr.FieldByName('naziv').AsString;
      D.Tema := Trim(Qr.FieldByName('tema').AsString);
      D.Model := LowerCase(Trim(Qr.FieldByName('model').AsString));
      D.Pin := PinOf(Qr.FieldByName('pin').AsString);
      D.Pin2 := PinOf(Qr.FieldByName('pin2').AsString);
      D.Addr := Trim(Qr.FieldByName('adresa').AsString);
      D.Inv := Qr.FieldByName('invertirano').AsInteger > 0;
      D.HasA := not Qr.FieldByName('kal_a').IsNull;
      D.HasB := not Qr.FieldByName('kal_b').IsNull;
      D.KalA := Num(Qr.FieldByName('kal_a').AsString);
      D.KalB := Num(Qr.FieldByName('kal_b').AsString);
      D.MlMin := Num(Qr.FieldByName('ml_po_min').AsString);
      D.MaxS := Qr.FieldByName('najdulje_s').AsInteger;
      D.Vrsta := Qr.FieldByName('vrsta').AsString;
      D.Role := Qr.FieldByName('uloga').AsString;
      D.Jedinica := Qr.FieldByName('jedinica').AsString;
      D.Ident := Ident(D.Tema);
      if D.Tema = '' then Warn('uredjaj "' + D.Name + '" nema temu, preskacem')
      else if D.Model = '' then Warn('uredjaj "' + D.Name + '" nema model, preskacem')
      else
      begin
        SetLength(Devs, N + 1);
        Devs[N] := D;
        Inc(N);
      end;
      Qr.Next;
    end;
  finally
    Qr.Free;
  end;
  SetLength(Done, N);
  Y := TStringList.Create;
  Sched := TStringList.Create;
  SchedKind := TStringList.Create;
  try
    NeedI2c := False; NeedOneWire := False; HasSensor := False; HasSwitch := False; HasCover := False; HasScript := False;
    OwPin := '';
    for I := 0 to N - 1 do
    begin
      if Devs[I].Role = 'senzor' then
      begin
        if Devs[I].Model = 'ds18b20' then begin NeedOneWire := True; if OwPin = '' then OwPin := Devs[I].Pin; end
        else if (Devs[I].Model = 'sht3x') or (Devs[I].Model = 'bh1750') then NeedI2c := True;
      end;
    end;
    Add(Y, '# Izradeno iz aplikacije Procesi (pogon: ' + Naziv + '). Ne uredjuj rucno: konfiguracija se ponovno izradjuje.');
    Add(Y, '# Tajne (wifi, MQTT, OTA) su u secrets.yaml, vidi secrets.yaml.example.');
    Add(Y, 'esphome:');
    Add(Y, '  name: ' + HostName(Tema, AProstorId));
    Add(Y, '  friendly_name: ' + Q(Naziv));
    Add(Y, '  includes:');
    Add(Y, '    - procesi_raspored.h');
    Add(Y, 'esp32:');
    Add(Y, '  board: ' + Board);
    Add(Y, 'logger:');
    Add(Y, 'wifi:');
    Add(Y, '  ssid: !secret wifi_ssid');
    Add(Y, '  password: !secret wifi_password');
    Add(Y, 'ota:');
    Add(Y, '  - platform: esphome');
    Add(Y, '    password: !secret ota_password');
    Add(Y, 'time:');
    Add(Y, '  - platform: sntp');
    Add(Y, '    id: sntp_time');
    Add(Y, '    timezone: ' + Q(Zona));
    if NeedI2c then
    begin
      Add(Y, 'i2c:');
      Add(Y, '  sda: GPIO21');
      Add(Y, '  scl: GPIO22');
    end;
    if NeedOneWire then
    begin
      Add(Y, 'one_wire:');
      Add(Y, '  - platform: gpio');
      Add(Y, '    id: ow_bus');
      Add(Y, '    pin: ' + OwPin);
    end;
    { izlazi koji se vode rasporedom }
    for I := 0 to N - 1 do
      if (Devs[I].Role = 'izvrsni') and ((Devs[I].Model = 'rele') or (Devs[I].Model = 'prozor')) and (Devs[I].Pin <> '') then
      begin
        if Sched.Count >= 16 then begin Warn('najvise 16 izlaza s rasporedom, ' + Devs[I].Name + ' nema raspored'); Continue; end;
        Sched.Add(Devs[I].Ident);
        if Devs[I].Model = 'prozor' then SchedKind.Add('cv') else SchedKind.Add('sw');
      end;
    { mqtt }
    Add(Y, 'mqtt:');
    Add(Y, '  broker: !secret mqtt_broker');
    Add(Y, '  username: !secret mqtt_user');
    Add(Y, '  password: !secret mqtt_password');
    Add(Y, '  topic_prefix: ' + Q(Prefix));
    Add(Y, '  birth_message:');
    Add(Y, '    topic: ' + Q(Prefix + '/status'));
    Add(Y, '    payload: online');
    Add(Y, '    retain: true');
    Add(Y, '  will_message:');
    Add(Y, '    topic: ' + Q(Prefix + '/status'));
    Add(Y, '    payload: offline');
    Add(Y, '    retain: true');
    J := 0;
    for I := 0 to N - 1 do
      if (Devs[I].Role = 'izvrsni') and (Devs[I].Pin <> '') then Inc(J);
    if J > 0 then
    begin
      Add(Y, '  on_json_message:');
      for I := 0 to N - 1 do
      begin
        D := Devs[I];
        if (D.Role <> 'izvrsni') or (D.Pin = '') then Continue;
        if D.Model = 'rele' then
        begin
          Add(Y, '    - topic: ' + Q(Topic(D, 'set')));
          Add(Y, '      then:');
          Add(Y, '        - lambda: |-');
          Add(Y, '            std::string a = x["akcija"] | "";');
          Add(Y, '            if (a == "ukljuci") id(sw_' + D.Ident + ').turn_on();');
          Add(Y, '            else if (a == "iskljuci") id(sw_' + D.Ident + ').turn_off();');
          Ack(D, '        ');
        end
        else if D.Model = 'dozator' then
        begin
          Add(Y, '    - topic: ' + Q(Topic(D, 'set')));
          Add(Y, '      then:');
          Add(Y, '        - lambda: |-');
          Add(Y, '            std::string a = x["akcija"] | "";');
          Add(Y, '            if (a == "iskljuci") { id(doza_' + D.Ident + ').stop(); id(sw_' + D.Ident + ').turn_off(); }');
          Add(Y, '            else if (a == "ukljuci") id(sw_' + D.Ident + ').turn_on();');
          Add(Y, '            else if (a == "doziraj") id(doza_' + D.Ident + ').execute(x["trajanje_s"] | 0.0f);');
          Ack(D, '        ');
        end
        else if D.Model = 'prozor' then
        begin
          Add(Y, '    - topic: ' + Q(Topic(D, 'set')));
          Add(Y, '      then:');
          Add(Y, '        - lambda: |-');
          Add(Y, '            std::string a = x["akcija"] | "";');
          Add(Y, '            if (a == "ukljuci") id(cv_' + D.Ident + ').make_call().set_command_open().perform();');
          Add(Y, '            else if (a == "iskljuci") id(cv_' + D.Ident + ').make_call().set_command_close().perform();');
          Add(Y, '            else if (a == "postavi") id(cv_' + D.Ident + ').make_call().set_position((float) (x["vrijednost"] | 0.0f) / 100.0f).perform();');
          Ack(D, '        ');
        end;
        if (D.Model = 'rele') or (D.Model = 'prozor') then
        begin
          Add(Y, '    - topic: ' + Q(Topic(D, 'raspored')));
          Add(Y, '      then:');
          Add(Y, '        - lambda: |-');
          Add(Y, '            ProcesRaspored &r = proces_rasp(' + IntToStr(Sched.IndexOf(D.Ident)) + ');');
          Add(Y, '            proces_obrisi(r);');
          Add(Y, '            for (JsonObjectConst e : x["stavke"].as<JsonArrayConst>())');
          Add(Y, '              proces_dodaj(r, e["dani"] | "1234567", e["od"] | "", e["do"] | "", e["svakih_min"] | 0, e["trajanje_s"] | 0);');
        end;
      end;
    end;
    { senzori }
    for I := 0 to N - 1 do
      if Devs[I].Role = 'senzor' then HasSensor := True;
    if HasSensor then Add(Y, 'sensor:');
    for I := 0 to N - 1 do
    begin
      D := Devs[I];
      if (D.Role <> 'senzor') or Done[I] then Continue;
      if (D.Model = 'dht22') or (D.Model = 'dht11') then
      begin
        if D.Pin = '' then begin Warn('senzor "' + D.Name + '" nema pin, preskacem'); Done[I] := True; Continue; end;
        Add(Y, '  - platform: dht');
        Add(Y, '    model: ' + UpperCase(D.Model));
        Add(Y, '    pin: ' + D.Pin);
        Add(Y, '    update_interval: 30s');
        for J := I to N - 1 do
        begin
          E := Devs[J];
          if (E.Role <> 'senzor') or Done[J] or (E.Model <> D.Model) or (E.Pin <> D.Pin) then Continue;
          if IsTemp(E) then begin SensorHead(E, '    ', 'temperature'); Add(Y, '      accuracy_decimals: 1'); Done[J] := True; end
          else if IsHum(E) then begin SensorHead(E, '    ', 'humidity'); Add(Y, '      accuracy_decimals: 1'); Done[J] := True; end;
        end;
        if not Done[I] then begin Warn('senzor "' + D.Name + '": DHT daje samo temperaturu i vlagu zraka'); Done[I] := True; end;
      end
      else if D.Model = 'sht3x' then
      begin
        Add(Y, '  - platform: sht3xd');
        if D.Addr <> '' then Add(Y, '    address: ' + D.Addr) else Add(Y, '    address: 0x44');
        Add(Y, '    update_interval: 30s');
        for J := I to N - 1 do
        begin
          E := Devs[J];
          if (E.Role <> 'senzor') or Done[J] or (E.Model <> 'sht3x') or (E.Addr <> D.Addr) then Continue;
          if IsTemp(E) then begin SensorHead(E, '    ', 'temperature'); Add(Y, '      accuracy_decimals: 1'); Done[J] := True; end
          else if IsHum(E) then begin SensorHead(E, '    ', 'humidity'); Add(Y, '      accuracy_decimals: 1'); Done[J] := True; end;
        end;
        if not Done[I] then begin Warn('senzor "' + D.Name + '": SHT3x daje samo temperaturu i vlagu zraka'); Done[I] := True; end;
      end
      else if D.Model = 'ds18b20' then
      begin
        Add(Y, '  - platform: dallas_temp');
        Add(Y, '    one_wire_id: ow_bus');
        if D.Addr <> '' then Add(Y, '    address: ' + D.Addr);
        Add(Y, '    id: s_' + D.Ident);
        Add(Y, '    name: ' + Q(D.Name));
        Add(Y, '    state_topic: ' + Q(Topic(D, 'stanje')));
        Add(Y, '    unit_of_measurement: ' + Q('°C'));
        Add(Y, '    accuracy_decimals: 1');
        Add(Y, '    update_interval: 30s');
        Done[I] := True;
      end
      else if D.Model = 'bh1750' then
      begin
        Add(Y, '  - platform: bh1750');
        if D.Addr <> '' then Add(Y, '    address: ' + D.Addr);
        Add(Y, '    id: s_' + D.Ident);
        Add(Y, '    name: ' + Q(D.Name));
        Add(Y, '    state_topic: ' + Q(Topic(D, 'stanje')));
        Add(Y, '    update_interval: 30s');
        Done[I] := True;
      end
      else if D.Model = 'adc' then
      begin
        if D.Pin = '' then begin Warn('senzor "' + D.Name + '" nema pin, preskacem'); Done[I] := True; Continue; end;
        Add(Y, '  - platform: adc');
        Add(Y, '    pin: ' + D.Pin);
        Add(Y, '    attenuation: 12db');
        Add(Y, '    id: s_' + D.Ident);
        Add(Y, '    name: ' + Q(D.Name));
        Add(Y, '    state_topic: ' + Q(Topic(D, 'stanje')));
        if D.Jedinica <> '' then Add(Y, '    unit_of_measurement: ' + Q(D.Jedinica));
        Add(Y, '    accuracy_decimals: 2');
        Add(Y, '    update_interval: 30s');
        Add(Y, '    filters:');
        Add(Y, '      - median:');
        Add(Y, '          window_size: 5');
        Add(Y, '          send_every: 1');
        if D.HasA or D.HasB then
        begin
          if not D.HasA then D.KalA := '1';
          if not D.HasB then D.KalB := '0';
          Add(Y, '      - lambda: return x * ' + D.KalA + ' + ' + D.KalB + ';');
        end
        else Warn('senzor "' + D.Name + '" (adc) nema kalibraciju kal_a/kal_b: vrijednost je napon u voltima');
        Done[I] := True;
      end
      else begin Warn('senzor "' + D.Name + '": nepoznat model "' + D.Model + '", preskacem'); Done[I] := True; end;
    end;
    { izlazi }
    for I := 0 to N - 1 do
    begin
      D := Devs[I];
      if D.Role <> 'izvrsni' then Continue;
      if D.Pin = '' then begin Warn('izlaz "' + D.Name + '" nema pin, preskacem'); Continue; end;
      if (D.Model = 'rele') or (D.Model = 'dozator') then HasSwitch := True
      else if D.Model = 'prozor' then begin HasSwitch := True; HasCover := True; end
      else Warn('izlaz "' + D.Name + '": nepoznat model "' + D.Model + '", preskacem');
      if D.Model = 'dozator' then HasScript := True;
      if (D.Model = 'rele') and (D.MaxS > 0) then HasScript := True;
    end;
    if HasSwitch then Add(Y, 'switch:');
    for I := 0 to N - 1 do
    begin
      D := Devs[I];
      if (D.Role <> 'izvrsni') or (D.Pin = '') then Continue;
      if (D.Model = 'rele') or (D.Model = 'dozator') then
      begin
        Add(Y, '  - platform: gpio');
        Add(Y, '    id: sw_' + D.Ident);
        Add(Y, '    name: ' + Q(D.Name));
        Add(Y, '    pin:');
        Add(Y, '      number: ' + D.Pin);
        if D.Inv then Add(Y, '      inverted: true');
        if (D.Model = 'dozator') or (Pos('pump', LowerCase(D.Vrsta)) > 0) then Add(Y, '    restore_mode: ALWAYS_OFF')
        else Add(Y, '    restore_mode: RESTORE_DEFAULT_OFF');
        Add(Y, '    state_topic: ' + Q(Topic(D, 'stanje')));
        Add(Y, '    command_topic: ' + Q(Topic(D, 'komanda')));
        if (D.Model = 'rele') and (D.MaxS > 0) then
        begin
          Add(Y, '    on_turn_on:');
          Add(Y, '      - script.execute: max_' + D.Ident);
          Add(Y, '    on_turn_off:');
          Add(Y, '      - script.stop: max_' + D.Ident);
        end;
      end
      else if D.Model = 'prozor' then
      begin
        if D.Pin2 = '' then begin Warn('prozor "' + D.Name + '" treba pin i pin2 (otvaranje i zatvaranje)'); Continue; end;
        Add(Y, '  - platform: gpio');
        Add(Y, '    id: sw_' + D.Ident + '_o');
        Add(Y, '    pin:');
        Add(Y, '      number: ' + D.Pin);
        if D.Inv then Add(Y, '      inverted: true');
        Add(Y, '    internal: true');
        Add(Y, '    interlock: [sw_' + D.Ident + '_z]');
        Add(Y, '  - platform: gpio');
        Add(Y, '    id: sw_' + D.Ident + '_z');
        Add(Y, '    pin:');
        Add(Y, '      number: ' + D.Pin2);
        if D.Inv then Add(Y, '      inverted: true');
        Add(Y, '    internal: true');
        Add(Y, '    interlock: [sw_' + D.Ident + '_o]');
      end;
    end;
    if HasCover then Add(Y, 'cover:');
    for I := 0 to N - 1 do
    begin
      D := Devs[I];
      if (D.Role <> 'izvrsni') or (D.Pin = '') or (D.Model <> 'prozor') or (D.Pin2 = '') then Continue;
      J := D.MaxS;
      if J <= 0 then J := 30;
      Add(Y, '  - platform: time_based');
      Add(Y, '    id: cv_' + D.Ident);
      Add(Y, '    name: ' + Q(D.Name));
      Add(Y, '    position_state_topic: ' + Q(Topic(D, 'stanje')));
      Add(Y, '    open_action:');
      Add(Y, '      - switch.turn_on: sw_' + D.Ident + '_o');
      Add(Y, '    open_duration: ' + IntToStr(J) + 's');
      Add(Y, '    close_action:');
      Add(Y, '      - switch.turn_on: sw_' + D.Ident + '_z');
      Add(Y, '    close_duration: ' + IntToStr(J) + 's');
      Add(Y, '    stop_action:');
      Add(Y, '      - switch.turn_off: sw_' + D.Ident + '_o');
      Add(Y, '      - switch.turn_off: sw_' + D.Ident + '_z');
    end;
    if HasScript then Add(Y, 'script:');
    for I := 0 to N - 1 do
    begin
      D := Devs[I];
      if (D.Role <> 'izvrsni') or (D.Pin = '') then Continue;
      if D.Model = 'dozator' then
      begin
        Add(Y, '  - id: doza_' + D.Ident);
        Add(Y, '    mode: restart');
        Add(Y, '    parameters:');
        Add(Y, '      seconds: float');
        Add(Y, '    then:');
        Add(Y, '      - switch.turn_on: sw_' + D.Ident);
        if D.MaxS > 0 then Add(Y, '      - delay: !lambda ''return std::min(seconds, (float) ' + IntToStr(D.MaxS) + ') * 1000;''')
        else Add(Y, '      - delay: !lambda ''return seconds * 1000;''');
        Add(Y, '      - switch.turn_off: sw_' + D.Ident);
      end
      else if (D.Model = 'rele') and (D.MaxS > 0) then
      begin
        Add(Y, '  - id: max_' + D.Ident);
        Add(Y, '    mode: restart');
        Add(Y, '    then:');
        Add(Y, '      - delay: ' + IntToStr(D.MaxS) + 's');
        Add(Y, '      - switch.turn_off: sw_' + D.Ident);
      end;
    end;
    if Sched.Count > 0 then
    begin
      Add(Y, 'interval:');
      Add(Y, '  - interval: 15s');
      Add(Y, '    then:');
      Add(Y, '      - lambda: |-');
      Add(Y, '          auto t = id(sntp_time).now();');
      Add(Y, '          if (!t.is_valid()) return;');
      Add(Y, '          int dan = t.day_of_week == 1 ? 7 : t.day_of_week - 1;');
      Add(Y, '          int minute = t.hour * 60 + t.minute;');
      for I := 0 to Sched.Count - 1 do
      begin
        Add(Y, '          {');
        Add(Y, '            ProcesRaspored &r = proces_rasp(' + IntToStr(I) + ');');
        Add(Y, '            int p = proces_promjena(r, proces_ukljuceno(r, dan, minute, t.second));');
        if SchedKind[I] = 'cv' then
          Add(Y, '            if (p == 1) id(cv_' + Sched[I] + ').make_call().set_command_open().perform(); else if (p == 0) id(cv_' + Sched[I] + ').make_call().set_command_close().perform();')
        else
          Add(Y, '            if (p == 1) id(sw_' + Sched[I] + ').turn_on(); else if (p == 0) id(sw_' + Sched[I] + ').turn_off();');
        Add(Y, '          }');
      end;
    end;
    Result := Y.Text;
  finally
    SchedKind.Free;
    Sched.Free;
    Y.Free;
  end;
end;

function EspHomeExportAll(ADb: TAppDb; const ADir: string; ALog: TStrings): Integer;
var
  Qr: TZQuery;
  Ids: TStringList;
  I: Integer;
  Txt, Nm, Tema: string;
  F: TStringList;
begin
  Result := 0;
  ForceDirectories(ADir);
  Ids := TStringList.Create;
  F := TStringList.Create;
  try
    Qr := ADb.NewQuery('SELECT id, tema FROM pogoni WHERE tema IS NOT NULL AND tema <> '''' ORDER BY id');
    try
      Qr.Open;
      while not Qr.EOF do
      begin
        Ids.Add(Qr.FieldByName('id').AsString + '=' + Qr.FieldByName('tema').AsString);
        Qr.Next;
      end;
    finally
      Qr.Free;
    end;
    for I := 0 to Ids.Count - 1 do
    begin
      Txt := EspHomeConfig(ADb, StrToInt(Ids.Names[I]), ALog);
      if Txt = '' then Continue;
      Tema := Ids.ValueFromIndex[I];
      Nm := HostName(Tema, StrToInt(Ids.Names[I]));
      F.Text := Txt;
      F.SaveToFile(IncludeTrailingPathDelimiter(ADir) + Nm + '.yaml');
      if ALog <> nil then ALog.Add('izradeno: ' + Nm + '.yaml');
      Inc(Result);
    end;
    F.Text := EspHomeHeader;
    F.SaveToFile(IncludeTrailingPathDelimiter(ADir) + 'procesi_raspored.h');
    F.Clear;
    F.Add('# Kopiraj u secrets.yaml i popuni.');
    F.Add('wifi_ssid: "naziv mreze"');
    F.Add('wifi_password: "lozinka"');
    F.Add('mqtt_broker: "192.168.1.10"');
    F.Add('mqtt_user: "proces"');
    F.Add('mqtt_password: "lozinka"');
    F.Add('ota_password: "lozinka"');
    F.SaveToFile(IncludeTrailingPathDelimiter(ADir) + 'secrets.yaml.example');
  finally
    F.Free;
    Ids.Free;
  end;
end;

end.
