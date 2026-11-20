unit ta_keymap;
{ Mapa tipki neprekidne forme (i kasnije drugih obitelji): radnja -> jedna ili vise tipki, sve se moze promijeniti.
  Tipka se zapisuje tekstom: "Ctrl+N", "Insert", "Shift+Enter", "F12", "Esc", "Ctrl+Home".
  Zadano je u KeyMapDefaults; korisnik ga mijenja u postavkama aplikacije (JSON u postavci "tipke.json")
  ili po formi. Isti zapis cita dizajner, runtime i IDE. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLType, fpjson, jsonparser, ta_meta, ta_i18n;

type
  TaKeyAction = (kaNone, kaNextField, kaPrevField, kaNextRow, kaPrevRow, kaPageDown, kaPageUp, kaFirstRecord,
    kaLastRecord, kaNewRecord, kaSaveRow, kaCancelRow, kaDeleteRow, kaCloseForm, kaCancelOrClose,
    kaQuery, kaExecuteQuery, kaLov);

  TaKeyCombo = record
    Key: Word;
    Ctrl, Shift, Alt: Boolean;
  end;

  TaKeyMap = class
  private
    FKeys: array[TaKeyAction] of array of TaKeyCombo;
  public
    constructor Create;
    procedure LoadDefaults;
    procedure Clear;
    { zamijeni sve tipke radnje; AKeys je "Ctrl+N, Insert" }
    function SetKeys(AAction: TaKeyAction; const AKeys: string; out AError: string): Boolean;
    procedure AddKey(AAction: TaKeyAction; const AKey: string);
    function KeysOf(AAction: TaKeyAction): string;
    { koja radnja pripada kombinaciji (kaNone ako nijedna) }
    function Resolve(AKey: Word; AShift: TShiftState): TaKeyAction;
    { radnja kojoj je kombinacija vec dodijeljena (osim AExcept) }
    function ConflictOf(const ACombo: string; AExcept: TaKeyAction): TaKeyAction;
    function ToJson: string;
    function FromJson(const AJson: string; out AError: string): Boolean;
  end;

function ActionName(AAction: TaKeyAction): string;
function ActionFromName(const AName: string): TaKeyAction;
function ActionTitle(AAction: TaKeyAction): string;
function ParseCombo(const S: string; out ACombo: TaKeyCombo): Boolean;
function ComboToStr(const ACombo: TaKeyCombo): string;
{ postavka aplikacije "tipke.json": ucitaj u mapu (zadano ako je nema) / spremi }
function KeyMapLoad(ADb: TAppDb; AMap: TaKeyMap; out AError: string): Boolean;
function KeyMapSave(ADb: TAppDb; AMap: TaKeyMap): Boolean;
{ zajednicka mapa aplikacije }
function GlobalKeyMap: TaKeyMap;

implementation

const
  Names: array[TaKeyAction] of string = ('', 'NextField', 'PrevField', 'NextRow', 'PrevRow', 'PageDown', 'PageUp',
    'FirstRecord', 'LastRecord', 'NewRecord', 'SaveRow', 'CancelRow', 'DeleteRow', 'CloseForm', 'CancelOrClose',
    'Query', 'ExecuteQuery', 'Lov');
  Titles: array[TaKeyAction] of string = ('', 'Sljedeće polje', 'Prethodno polje', 'Sljedeći zapis', 'Prethodni zapis',
    'Stranica dolje', 'Stranica gore', 'Prvi zapis', 'Zadnji zapis', 'Novi zapis', 'Spremi zapis', 'Poništi izmjene',
    'Briši zapis', 'Zatvori formu', 'Poništi, a ako nema izmjena zatvori', 'Upit po formi', 'Izvrši upit', 'Popis vrijednosti (LOV)');
  { zadano: Access-slicno }
  Defaults: array[TaKeyAction] of string = ('', 'Tab, Enter', 'Shift+Tab', 'Down', 'Up', 'PageDown', 'PageUp',
    'Ctrl+Home', 'Ctrl+End', 'Ctrl+N', 'Shift+Enter, F10', 'Esc', 'Ctrl+Delete', '', '', 'F7', 'F8', 'F9');

type
  TKeyName = record
    N: string;
    K: Word;
  end;

const
  KeyNames: array[0..24] of TKeyName = (
    (N: 'Tab'; K: VK_TAB), (N: 'Enter'; K: VK_RETURN), (N: 'Esc'; K: VK_ESCAPE), (N: 'Space'; K: VK_SPACE),
    (N: 'Backspace'; K: VK_BACK), (N: 'Insert'; K: VK_INSERT), (N: 'Delete'; K: VK_DELETE), (N: 'Home'; K: VK_HOME),
    (N: 'End'; K: VK_END), (N: 'PageUp'; K: VK_PRIOR), (N: 'PageDown'; K: VK_NEXT), (N: 'Up'; K: VK_UP),
    (N: 'Down'; K: VK_DOWN), (N: 'Left'; K: VK_LEFT), (N: 'Right'; K: VK_RIGHT), (N: 'Plus'; K: VK_ADD),
    (N: 'Minus'; K: VK_SUBTRACT), (N: 'Pause'; K: VK_PAUSE), (N: 'Menu'; K: VK_APPS), (N: 'Escape'; K: VK_ESCAPE),
    (N: 'Return'; K: VK_RETURN), (N: 'Del'; K: VK_DELETE), (N: 'Ins'; K: VK_INSERT), (N: 'PgUp'; K: VK_PRIOR),
    (N: 'PgDn'; K: VK_NEXT));

var
  GMap: TaKeyMap = nil;

function GlobalKeyMap: TaKeyMap;
begin
  if GMap = nil then GMap := TaKeyMap.Create;
  Result := GMap;
end;

function ActionName(AAction: TaKeyAction): string;
begin
  Result := Names[AAction];
end;

function ActionTitle(AAction: TaKeyAction): string;
begin
  Result := Tr(Titles[AAction]);
end;

function ActionFromName(const AName: string): TaKeyAction;
var
  A: TaKeyAction;
begin
  for A := Succ(Low(TaKeyAction)) to High(TaKeyAction) do
    if SameText(Names[A], AName) then Exit(A);
  Result := kaNone;
end;

function ParseCombo(const S: string; out ACombo: TaKeyCombo): Boolean;
var
  Parts: TStringList;
  I, N: Integer;
  P, U: string;
begin
  Result := False;
  FillChar(ACombo, SizeOf(ACombo), 0);
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '+';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Trim(S);
    { "Ctrl++" = Ctrl i znak plus }
    if (Parts.Count >= 2) and (Parts[Parts.Count - 1] = '') and (Parts[Parts.Count - 2] = '') then
    begin
      Parts.Delete(Parts.Count - 1);
      Parts[Parts.Count - 1] := 'Plus';
    end;
    if Parts.Count = 0 then Exit;
    for I := 0 to Parts.Count - 2 do
    begin
      U := UpperCase(Trim(Parts[I]));
      if (U = 'CTRL') or (U = 'CONTROL') or (U = 'STRG') then ACombo.Ctrl := True
      else if U = 'SHIFT' then ACombo.Shift := True
      else if (U = 'ALT') then ACombo.Alt := True
      else Exit;
    end;
    P := Trim(Parts[Parts.Count - 1]);
    if P = '' then Exit;
    U := UpperCase(P);
    if (Length(P) = 1) and (U[1] in ['A'..'Z', '0'..'9']) then begin ACombo.Key := Ord(U[1]); Exit(True); end;
    if (U[1] = 'F') and (Length(U) >= 2) and (Length(U) <= 3) then
    begin
      N := StrToIntDef(Copy(U, 2, 2), 0);
      if (N >= 1) and (N <= 24) then begin ACombo.Key := VK_F1 + N - 1; Exit(True); end;
    end;
    for I := 0 to High(KeyNames) do
      if SameText(KeyNames[I].N, P) then begin ACombo.Key := KeyNames[I].K; Exit(True); end;
  finally
    Parts.Free;
  end;
end;

function ComboToStr(const ACombo: TaKeyCombo): string;
var
  I: Integer;
  K: string;
begin
  Result := '';
  if ACombo.Ctrl then Result := Result + 'Ctrl+';
  if ACombo.Shift then Result := Result + 'Shift+';
  if ACombo.Alt then Result := Result + 'Alt+';
  K := '';
  if (ACombo.Key >= VK_F1) and (ACombo.Key <= VK_F24) then K := 'F' + IntToStr(ACombo.Key - VK_F1 + 1)
  else if (ACombo.Key >= Ord('A')) and (ACombo.Key <= Ord('Z')) then K := Chr(ACombo.Key)
  else if (ACombo.Key >= Ord('0')) and (ACombo.Key <= Ord('9')) then K := Chr(ACombo.Key)
  else
    for I := 0 to 17 do   { prvih 18 su kanonska imena }
      if KeyNames[I].K = ACombo.Key then begin K := KeyNames[I].N; Break; end;
  Result := Result + K;
end;

constructor TaKeyMap.Create;
begin
  LoadDefaults;
end;

procedure TaKeyMap.Clear;
var
  A: TaKeyAction;
begin
  for A := Low(TaKeyAction) to High(TaKeyAction) do SetLength(FKeys[A], 0);
end;

procedure TaKeyMap.LoadDefaults;
var
  A: TaKeyAction;
  E: string;
begin
  Clear;
  for A := Succ(Low(TaKeyAction)) to High(TaKeyAction) do
    if Defaults[A] <> '' then SetKeys(A, Defaults[A], E);
end;

function TaKeyMap.SetKeys(AAction: TaKeyAction; const AKeys: string; out AError: string): Boolean;
var
  L: TStringList;
  I: Integer;
  C: TaKeyCombo;
  Tmp: array of TaKeyCombo;
begin
  Result := False;
  AError := '';
  SetLength(Tmp, 0);
  L := TStringList.Create;
  try
    L.Delimiter := ',';
    L.StrictDelimiter := True;
    L.DelimitedText := AKeys;
    for I := 0 to L.Count - 1 do
    begin
      if Trim(L[I]) = '' then Continue;
      if not ParseCombo(L[I], C) then begin AError := 'Nepoznata tipka: "' + Trim(L[I]) + '"'; Exit; end;
      SetLength(Tmp, Length(Tmp) + 1);
      Tmp[High(Tmp)] := C;
    end;
  finally
    L.Free;
  end;
  FKeys[AAction] := Tmp;
  Result := True;
end;

procedure TaKeyMap.AddKey(AAction: TaKeyAction; const AKey: string);
var
  C: TaKeyCombo;
begin
  if ParseCombo(AKey, C) then
  begin
    SetLength(FKeys[AAction], Length(FKeys[AAction]) + 1);
    FKeys[AAction][High(FKeys[AAction])] := C;
  end;
end;

function TaKeyMap.KeysOf(AAction: TaKeyAction): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FKeys[AAction]) do
  begin
    if Result <> '' then Result := Result + ', ';
    Result := Result + ComboToStr(FKeys[AAction][I]);
  end;
end;

function TaKeyMap.Resolve(AKey: Word; AShift: TShiftState): TaKeyAction;
var
  A: TaKeyAction;
  I: Integer;
  C: TaKeyCombo;
begin
  for A := Succ(Low(TaKeyAction)) to High(TaKeyAction) do
    for I := 0 to High(FKeys[A]) do
    begin
      C := FKeys[A][I];
      if (C.Key = AKey) and (C.Ctrl = (ssCtrl in AShift)) and (C.Shift = (ssShift in AShift)) and (C.Alt = (ssAlt in AShift)) then
        Exit(A);
    end;
  Result := kaNone;
end;

function TaKeyMap.ConflictOf(const ACombo: string; AExcept: TaKeyAction): TaKeyAction;
var
  A: TaKeyAction;
  I: Integer;
  C: TaKeyCombo;
begin
  Result := kaNone;
  if not ParseCombo(ACombo, C) then Exit;
  for A := Succ(Low(TaKeyAction)) to High(TaKeyAction) do
    if A <> AExcept then
      for I := 0 to High(FKeys[A]) do
        if (FKeys[A][I].Key = C.Key) and (FKeys[A][I].Ctrl = C.Ctrl) and (FKeys[A][I].Shift = C.Shift) and (FKeys[A][I].Alt = C.Alt) then
          Exit(A);
end;

function TaKeyMap.ToJson: string;
var
  O: TJSONObject;
  A: TaKeyAction;
  Arr: TJSONArray;
  I: Integer;
begin
  O := TJSONObject.Create;
  try
    for A := Succ(Low(TaKeyAction)) to High(TaKeyAction) do
    begin
      Arr := TJSONArray.Create;
      for I := 0 to High(FKeys[A]) do Arr.Add(ComboToStr(FKeys[A][I]));
      O.Add(Names[A], Arr);
    end;
    Result := O.FormatJSON;
  finally
    O.Free;
  end;
end;

function TaKeyMap.FromJson(const AJson: string; out AError: string): Boolean;
var
  D: TJSONData;
  O: TJSONObject;
  I, J: Integer;
  A: TaKeyAction;
  Arr: TJSONArray;
  S, E: string;
begin
  Result := False;
  AError := '';
  try
    D := GetJSON(AJson);
  except
    on Ex: Exception do begin AError := 'Neispravan JSON: ' + Ex.Message; Exit; end;
  end;
  try
    if not (D is TJSONObject) then begin AError := 'Očekivan JSON objekt'; Exit; end;
    O := TJSONObject(D);
    { sto nije navedeno, ostaje zadano }
    LoadDefaults;
    for I := 0 to O.Count - 1 do
    begin
      A := ActionFromName(O.Names[I]);
      if A = kaNone then begin AError := AError + 'Nepoznata radnja "' + O.Names[I] + '"; '; Continue; end;
      S := '';
      if O.Items[I] is TJSONArray then
      begin
        Arr := TJSONArray(O.Items[I]);
        for J := 0 to Arr.Count - 1 do
        begin
          if S <> '' then S := S + ', ';
          S := S + Arr.Strings[J];
        end;
      end
      else S := O.Items[I].AsString;
      if not SetKeys(A, S, E) then AError := AError + O.Names[I] + ': ' + E + '; ';
    end;
    Result := AError = '';
  finally
    D.Free;
  end;
end;

function KeyMapLoad(ADb: TAppDb; AMap: TaKeyMap; out AError: string): Boolean;
var
  J: string;
begin
  AError := '';
  J := '';
  if ADb <> nil then J := ADb.LoadSetting('tipke.json');
  if Trim(J) = '' then begin AMap.LoadDefaults; Exit(True); end;
  Result := AMap.FromJson(J, AError);
end;

function KeyMapSave(ADb: TAppDb; AMap: TaKeyMap): Boolean;
begin
  Result := (ADb <> nil) and ADb.SaveSetting('tipke.json', AMap.ToJson);
end;

finalization
  GMap.Free;

end.
