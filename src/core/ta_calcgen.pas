unit ta_calcgen;
{ Templates for calculated fields. Each one has a few named parameters (a field,
  a number, some text, a choice) and expands to an expression in the usual
  language, e.g. "Iznos s PDV-om" with a = [iznos] and rate = 25 gives
  [iznos] * (1 + 25 / 100). Whether a template also works inside a query is
  found out by translating it, so the list never offers what cannot run. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_parse, ta_expr, ta_exprsql, ta_params;

type
  TaCalcParam = record
    Key, Caption: string;
    Kind: string;       { field | number | text | value | choice }
    FType: string;      { for fields: num | text | date | any }
    Default: string;
    Options: string;    { choice: comma separated }
  end;

  TaCalcTemplate = record
    Category, Title, Desc, Pattern, DefaultAlias: string;
    Params: array of TaCalcParam;
  end;
  TaCalcTemplates = array of TaCalcTemplate;

function CalcTemplates: TaCalcTemplates;
{ Values holds key=value lines. Fields are written as [name]. }
function ExpandCalc(const T: TaCalcTemplate; AValues: TStrings): string;
{ does it translate to SQL (used inside queries)? }
function CalcWorksInQuery(const T: TaCalcTemplate): Boolean;
{ a sample value for every parameter, for tests and previews }
function SampleValues(const T: TaCalcTemplate; const ANum1, ANum2, AText, ADate: string): TStringList;

implementation

var
  Cache: TaCalcTemplates;
  Loaded: Boolean = False;

procedure Add(const ACat, ATitle, ADesc, APattern, AAlias: string; const AParams: array of string);
var
  N, I: Integer;
  P: TStringList;
begin
  N := Length(Cache);
  SetLength(Cache, N + 1);
  Cache[N].Category := ACat;
  Cache[N].Title := ATitle;
  Cache[N].Desc := ADesc;
  Cache[N].Pattern := APattern;
  Cache[N].DefaultAlias := AAlias;
  { each parameter: key|caption|kind|ftype|default|options }
  SetLength(Cache[N].Params, Length(AParams));
  P := TStringList.Create;
  try
    P.Delimiter := '|';
    P.StrictDelimiter := True;
    for I := 0 to High(AParams) do
    begin
      P.DelimitedText := AParams[I];
      while P.Count < 6 do P.Add('');
      Cache[N].Params[I].Key := P[0];
      Cache[N].Params[I].Caption := P[1];
      Cache[N].Params[I].Kind := P[2];
      Cache[N].Params[I].FType := P[3];
      Cache[N].Params[I].Default := P[4];
      Cache[N].Params[I].Options := P[5];
    end;
  finally
    P.Free;
  end;
end;

function CalcTemplates: TaCalcTemplates;
const
  Ops = '=,<>,>,<,>=,<=';
begin
  if not Loaded then
  begin
    Loaded := True;
    { ---- text ---- }
    Add('Tekst', 'Spoji dva polja', 'npr. ime i prezime u jedno polje', '{a} & {sep} & {b}', 'PunoIme',
      ['a|Prvo polje|field|text||', 'sep|Razmak ili znak između|text||" "|', 'b|Drugo polje|field|text||']);
    Add('Tekst', 'Spoji tekst i polje', 'npr. "Račun br. " + broj', '{pre} & {a}', 'Opis',
      ['pre|Tekst ispred|text||"Br. "|', 'a|Polje|field|any||']);
    Add('Tekst', 'Prvih n znakova', 'početak teksta', 'Left({a}, {n})', 'Pocetak',
      ['a|Polje|field|text||', 'n|Broj znakova|number||3|']);
    Add('Tekst', 'Zadnjih n znakova', 'kraj teksta', 'Right({a}, {n})', 'Kraj',
      ['a|Polje|field|text||', 'n|Broj znakova|number||3|']);
    Add('Tekst', 'VELIKA slova', '', 'UCase({a})', 'Velika', ['a|Polje|field|text||']);
    Add('Tekst', 'mala slova', '', 'LCase({a})', 'Mala', ['a|Polje|field|text||']);
    Add('Tekst', 'Veliko Početno Slovo', 'svaka riječ velikim početnim (samo forme i izvješća)', 'Proper({a})', 'Naziv',
      ['a|Polje|field|text||']);
    Add('Tekst', 'Duljina teksta', 'broj znakova', 'Len({a})', 'Duljina', ['a|Polje|field|text||']);
    Add('Tekst', 'Zamijeni tekst', 'zamijeni dio teksta drugim', 'Replace({a}, {from}, {to})', 'Zamijenjeno',
      ['a|Polje|field|text||', 'from|Traži|text||"a"|', 'to|Zamijeni s|text||"b"|']);
    Add('Tekst', 'Skrati na n znakova', 'dugi opis skraćen s …', 'Shorten({a}, {n})', 'Kratko',
      ['a|Polje|field|text||', 'n|Najviše znakova|number||30|']);
    Add('Tekst', 'Broj s vodećim nulama', 'npr. 000123 (samo forme i izvješća)', 'LPad({a}, {n}, "0")', 'Broj6',
      ['a|Polje|field|any||', 'n|Ukupno znakova|number||6|']);
    { ---- numbers ---- }
    Add('Brojevi', 'Zbroj dva polja', '', '{a} + {b}', 'Zbroj', ['a|Prvo polje|field|num||', 'b|Drugo polje|field|num||']);
    Add('Brojevi', 'Razlika dva polja', '', '{a} - {b}', 'Razlika', ['a|Od polja|field|num||', 'b|Oduzmi polje|field|num||']);
    Add('Brojevi', 'Količina × cijena', 'umnožak dva polja', '{a} * {b}', 'Iznos', ['a|Prvo polje|field|num||', 'b|Drugo polje|field|num||']);
    Add('Brojevi', 'Omjer dva polja', 'prvo podijeljeno s drugim', '{a} / {b}', 'Omjer', ['a|Brojnik|field|num||', 'b|Nazivnik|field|num||']);
    Add('Brojevi', 'Iznos s PDV-om', 'neto iznos uvećan za PDV', '{a} * (1 + {rate} / 100)', 'SPdv',
      ['a|Neto iznos|field|num||', 'rate|Stopa PDV-a (%)|number||25|']);
    Add('Brojevi', 'Samo PDV', 'iznos poreza na neto iznos', '{a} * {rate} / 100', 'Pdv',
      ['a|Neto iznos|field|num||', 'rate|Stopa PDV-a (%)|number||25|']);
    Add('Brojevi', 'Neto iz bruto iznosa', 'iznos bez PDV-a', '{a} / (1 + {rate} / 100)', 'Neto',
      ['a|Bruto iznos|field|num||', 'rate|Stopa PDV-a (%)|number||25|']);
    Add('Brojevi', 'Iznos nakon popusta', '', '{a} * (1 - {pct} / 100)', 'SPopustom',
      ['a|Iznos|field|num||', 'pct|Popust (%)|number||10|']);
    Add('Brojevi', 'Postotak jednog polja od drugog', 'npr. udio u ukupnom', 'Percent({a}, {b})', 'Postotak',
      ['a|Dio|field|num||', 'b|Cjelina|field|num||']);
    Add('Brojevi', 'Zaokruži', '', 'Round({a}, {n})', 'Zaokruzeno', ['a|Polje|field|num||', 'n|Decimala|number||2|']);
    Add('Brojevi', 'Apsolutna vrijednost', '', 'Abs({a})', 'Apsolutno', ['a|Polje|field|num||']);
    { ---- dates ---- }
    Add('Datum', 'Dodaj dane datumu', 'npr. rok plaćanja', 'DateAdd("d", {n}, {a})', 'Rok',
      ['a|Datum|field|date||', 'n|Broj dana|number||30|']);
    Add('Datum', 'Dodaj mjesece datumu', '', 'DateAdd("m", {n}, {a})', 'Poslije',
      ['a|Datum|field|date||', 'n|Broj mjeseci|number||1|']);
    Add('Datum', 'Razlika datuma u danima', 'od prvog do drugog datuma', 'DateDiff("d", {a}, {b})', 'Dana',
      ['a|Od datuma|field|date||', 'b|Do datuma|field|date||']);
    Add('Datum', 'Dana do datuma (od danas)', 'koliko je dana do roka (negativno = prošao)', 'DateDiff("d", Date(), {a})', 'DanaDoRoka',
      ['a|Datum|field|date||']);
    Add('Datum', 'Starost u godinama', 'od datuma do danas', 'Age({a})', 'Starost', ['a|Datum rođenja ili početka|field|date||']);
    Add('Datum', 'Godina', '', 'Year({a})', 'Godina', ['a|Datum|field|date||']);
    Add('Datum', 'Mjesec (broj)', '', 'Month({a})', 'Mjesec', ['a|Datum|field|date||']);
    Add('Datum', 'Kvartal', '', 'Quarter({a})', 'Kvartal', ['a|Datum|field|date||']);
    Add('Datum', 'Zadnji dan mjeseca', '', 'Format(EOMonth({a}), "yyyy-mm-dd")', 'KrajMjeseca', ['a|Datum|field|date||']);
    Add('Datum', 'Prvi dan mjeseca', '', 'Format(BOMonth({a}), "yyyy-mm-dd")', 'PocetakMjeseca', ['a|Datum|field|date||']);
    Add('Datum', 'Oblikuj datum', 'prikaz datuma po želji', 'Format({a}, {fmt})', 'DatumTekst',
      ['a|Datum|field|date||', 'fmt|Oblik|choice||dd.mm.yyyy|dd.mm.yyyy,yyyy-mm-dd,mm/yyyy,yyyy,dd.mm.yyyy hh:nn']);
    Add('Datum', 'Naziv dana u tjednu', 'ponedjeljak, utorak… (samo forme i izvješća)', 'DayName({a})', 'Dan', ['a|Datum|field|date||']);
    { ---- logic ---- }
    Add('Uvjeti', 'Ako uvjet, ova vrijednost, inače druga', 'usporedi polje s vrijednošću',
      'Iif({a} {op} {v}, {yes}, {no})', 'Rezultat',
      ['a|Polje|field|any||', 'op|Usporedba|choice||>|' + Ops, 'v|Vrijednost|value||0|', 'yes|Ako je istina|value||"Da"|', 'no|Inače|value||"Ne"|']);
    Add('Uvjeti', 'Da / Ne iz uvjeta', 'tekst Da ili Ne', 'Iif({a} {op} {v}, "Da", "Ne")', 'Uvjet',
      ['a|Polje|field|any||', 'op|Usporedba|choice||>|' + Ops, 'v|Vrijednost|value||0|']);
    Add('Uvjeti', 'Ako je prazno, zamijeni', 'prazna vrijednost postaje zadana', 'Nz({a}, {v})', 'BezPraznog',
      ['a|Polje|field|any||', 'v|Zamjena|value||0|']);
    Add('Uvjeti', 'Razredi po rasponu (tri razine)', 'npr. mali / srednji / veliki', 'Switch({a} < {t1}, {l1}, {a} < {t2}, {l2}, True, {l3})', 'Razred',
      ['a|Polje|field|num||', 't1|Prva granica|number||100|', 'l1|Ispod prve|value||"Mali"|', 't2|Druga granica|number||1000|', 'l2|Ispod druge|value||"Srednji"|', 'l3|Iznad|value||"Veliki"|']);
    { ---- reports ---- }
    Add('Izvješće', 'Tekući zbroj', 'zbroj od početka izvješća (samo izvješća)', 'RunSum({a})', 'Tekuci', ['a|Polje|field|num||']);
    Add('Izvješće', 'Udio u ukupnom', 'posto ukupnog zbroja izvješća (samo izvješća)', 'Percent({a}, SumAll({a}))', 'Udio', ['a|Polje|field|num||']);
    Add('Izvješće', 'Redni broj retka', '(samo izvješća)', 'RowNum', 'Rb', []);
  end;
  Result := Cache;
end;

function ExpandCalc(const T: TaCalcTemplate; AValues: TStrings): string;
var
  I: Integer;
  V, Rep: string;
  D: Double;
begin
  Result := T.Pattern;
  for I := 0 to High(T.Params) do
  begin
    V := AValues.Values[T.Params[I].Key];
    if V = '' then V := T.Params[I].Default;
    if T.Params[I].Kind = 'field' then
    begin
      if (V <> '') and (V[1] <> '[') then Rep := '[' + V + ']' else Rep := V;
    end
    else if T.Params[I].Kind = 'text' then
    begin
      { already quoted defaults stay as they are }
      if (V <> '') and (V[1] in ['"', '''']) then Rep := V
      else Rep := '"' + StringReplace(V, '"', '""', [rfReplaceAll]) + '"';
    end
    else if T.Params[I].Kind = 'value' then
    begin
      if (V = '') then Rep := '""'
      else if (V[1] in ['"', '[', '#']) or ParseNumber(V, D) then Rep := V
      else Rep := '"' + StringReplace(V, '"', '""', [rfReplaceAll]) + '"';
      if ParseNumber(V, D) then Rep := StringReplace(V, ',', '.', []);
    end
    else
    begin
      if V = '' then V := '0';
      Rep := StringReplace(V, ',', '.', []);
      if T.Params[I].Kind = 'choice' then Rep := V;
      if (T.Params[I].Kind = 'choice') and (Pos('yy', V) > 0) then Rep := '"' + V + '"';
    end;
    Result := StringReplace(Result, '{' + T.Params[I].Key + '}', Rep, [rfReplaceAll]);
  end;
end;

type
  TNoResolve = class
    function Pass(const AName: string): string;
  end;

function TNoResolve.Pass(const AName: string): string;
begin
  Result := QuoteIdent(AName);
end;

function SampleValues(const T: TaCalcTemplate; const ANum1, ANum2, AText, ADate: string): TStringList;
var
  I, NumSeen, DateSeen: Integer;
  P: TaCalcParam;
begin
  Result := TStringList.Create;
  NumSeen := 0;
  DateSeen := 0;
  for I := 0 to High(T.Params) do
  begin
    P := T.Params[I];
    if P.Kind <> 'field' then Continue;
    if P.FType = 'num' then
    begin
      if NumSeen = 0 then Result.Values[P.Key] := ANum1 else Result.Values[P.Key] := ANum2;
      Inc(NumSeen);
    end
    else if P.FType = 'date' then
    begin
      Result.Values[P.Key] := ADate;
      Inc(DateSeen);
    end
    else if P.FType = 'any' then Result.Values[P.Key] := ANum1
    else Result.Values[P.Key] := AText;
  end;
  { several "any" fields: a number works for comparisons, text for joins }
  for I := 0 to High(T.Params) do
    if (T.Params[I].Kind = 'field') and (T.Params[I].FType = 'any') and (Result.Values[T.Params[I].Key] = '') then
      Result.Values[T.Params[I].Key] := ANum1;
end;

function CalcWorksInQuery(const T: TaCalcTemplate): Boolean;
var
  V: TStringList;
  N: TNoResolve;
  Sql, Err, E: string;
begin
  V := SampleValues(T, 'a', 'b', 's', 'd');
  N := TNoResolve.Create;
  try
    E := ExpandCalc(T, V);
    Result := ExprToSql(E, @N.Pass, Sql, Err);
  finally
    N.Free;
    V.Free;
  end;
end;

end.
