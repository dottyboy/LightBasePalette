unit ta_bindengine;
{ Zajednicki stroj ponasanja (poglavlje 8.2 plana, etapa E10): ISTA pravila vrednovanja za TaFormRunner i TaFormBinder.
  Nevizualan: ulaz je izraz i domacin izraza (vrijednosti polja), izlaz je odluka (vidljivo, omoguceno, stil, vrijednost,
  pravilo ispunjeno). Adapteri (runner, binder) samo PRIMJENJUJU rezultat na kontrole.

  Dogovorena pravila (odlucena pri izdvajanju, vrijede u oba adaptera):
    * uvjet je istinit prema ExprIsTrue: logicko, broj <> 0, tekst "true"/"da"/"1"; Null je laz;
    * izraz s greskom NE daje odluku (Ok = False): adapter ostavlja kontrolu kakva jest;
    * pravilo je prekrseno samo kad je izraz ispravan, nije Null i nije istinit (Null = bez odluke, ne prekrsaj);
    * stil: prvo pravilo uvjetnog oblikovanja koje vrijedi. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, Math, DB, ZDataset, ta_meta, ta_types, ta_expr, ta_condfmt;

const
  { pozadina kontrole cije je pravilo provjere prekrseno (isto u runneru i binderu); TColor BGR }
  RuleBadColor = $DDDDFF;

type
  { pravilo izracuna: "cijena,kolicina -> iznos = izraz" }
  TaCalcRuleDef = record
    Triggers: array of string;      { mala slova }
    Target, Expr: string;
  end;
  TaCalcRuleDefs = array of TaCalcRuleDef;

  { AutoFill: "polje>tablica.kljuc:cilj=izvor,cilj2=izvor2" }
  TaAutoFillDef = record
    Field, Table, KeyCol: string;
    Targets, Sources: array of string;
  end;
  TaAutoFillDefs = array of TaAutoFillDef;

  TaBindStyle = record
    Matched: Boolean;
    Fore, Back: string;     { #RRGGBB ili '' (bez promjene) }
    Bold: Boolean;
  end;

  TaBindingEngine = class
  private
    FHost: TaExprHost;
  public
    constructor Create(AHost: TaExprHost);
    property Host: TaExprHost read FHost write FHost;
    { vrijednost izraza; AErr = '' kad je izraz ispravan }
    function Value(const AExpr: string; out AErr: string): Variant;
    { prikaz izracunatog polja: vrijednost (V; '#Err' kad je izraz neispravan) i tekst oblikovan prema AFormat }
    function Display(const AExpr, AFormat: string; out V: Variant): string;
    { uvjet (VisibleIf, EnabledIf): AOk = False kad je izraz neispravan (nema odluke) }
    function Condition(const AExpr: string; out AOk: Boolean): Boolean;
    { pravilo provjere: True kad je pravilo PREKRSENO }
    function RuleFailed(const ARule: string): Boolean;
    { uvjetno oblikovanje: prvo pravilo koje vrijedi }
    function Style(const ACondFormat: string): TaBindStyle;
    { zadana vrijednost: izraz (vodeci = se skida); sto nije izraz uzima se doslovno; Null = bez zadane vrijednosti }
    function DefaultValue(const AExpr: string; out V: Variant): Boolean;
    { rezultat pravila izracuna u pohranjenom obliku (broj s tockom); False kad nema vrijednosti (greska, Null, NaN) }
    function CalcRuleStored(const ARule: TaCalcRuleDef; out AStored: string; out AIsNumber: Boolean): Boolean;
  end;

function ParseCalcRuleDefs(const AText: string): TaCalcRuleDefs;
function ParseAutoFillDefs(const AText: string): TaAutoFillDefs;
{ red iz tablice po kljucu: AStored dobiva Targets[i]=pohranjena vrijednost; False kad reda nema ili upit ne uspije }
function AutoFillLookup(ADb: TAppDb; const ARule: TaAutoFillDef; const AKey: string; AStored: TStrings): Boolean;

implementation

constructor TaBindingEngine.Create(AHost: TaExprHost);
begin
  FHost := AHost;
end;

function TaBindingEngine.Value(const AExpr: string; out AErr: string): Variant;
begin
  AErr := '';
  if Trim(AExpr) = '' then Exit(Null);
  Result := EvalExprEx(AExpr, FHost, AErr);
end;

function TaBindingEngine.Display(const AExpr, AFormat: string; out V: Variant): string;
var
  Err: string;
begin
  V := EvalExprEx(AExpr, FHost, Err);
  if Err <> '' then
  begin
    V := '#Err';
    Exit('#Err');
  end;
  Result := FormatValue(V, AFormat);
end;

function TaBindingEngine.Condition(const AExpr: string; out AOk: Boolean): Boolean;
var
  V: Variant;
  Err: string;
begin
  Result := False;
  AOk := False;
  if Trim(AExpr) = '' then Exit;
  V := EvalExprEx(AExpr, FHost, Err);
  if Err <> '' then Exit;
  AOk := True;
  Result := ExprIsTrue(V);
end;

function TaBindingEngine.RuleFailed(const ARule: string): Boolean;
var
  V: Variant;
  Err: string;
begin
  Result := False;
  if Trim(ARule) = '' then Exit;
  V := EvalExprEx(ARule, FHost, Err);
  if Err <> '' then Exit;
  if VarIsNull(V) or VarIsEmpty(V) then Exit;
  Result := not ExprIsTrue(V);
end;

function TaBindingEngine.Style(const ACondFormat: string): TaBindStyle;
var
  Rules: TCondRules;
  R: TCondRule;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Trim(ACondFormat) = '' then Exit;
  Rules := ParseCondFormat(ACondFormat);
  if MatchCondFormat(Rules, FHost, R) then
  begin
    Result.Matched := True;
    if R.Fore <> '-' then Result.Fore := R.Fore;
    if R.Back <> '-' then Result.Back := R.Back;
    Result.Bold := R.Bold;
  end;
end;

function TaBindingEngine.DefaultValue(const AExpr: string; out V: Variant): Boolean;
var
  E, Err: string;
begin
  V := Null;
  Result := False;
  E := Trim(AExpr);
  if E = '' then Exit;
  if E[1] = '=' then E := Trim(Copy(E, 2, MaxInt));
  V := EvalExprEx(E, FHost, Err);
  if Err <> '' then V := Trim(AExpr);        { nije izraz: doslovna vrijednost }
  Result := not (VarIsNull(V) or VarIsEmpty(V));
end;

function TaBindingEngine.CalcRuleStored(const ARule: TaCalcRuleDef; out AStored: string; out AIsNumber: Boolean): Boolean;
var
  V: Variant;
  Err: string;
  Num: Double;
begin
  AStored := '';
  AIsNumber := False;
  Result := False;
  try
    V := EvalExprEx(ARule.Expr, FHost, Err);
    if (Err <> '') or VarIsNull(V) or VarIsEmpty(V) then Exit;
    if VarIsNumeric(V) then
    begin
      Num := V;
      if IsNan(Num) or IsInfinite(Num) then Exit;
      AStored := FloatToStr(Num, InvariantFS);
      AIsNumber := True;
    end
    else AStored := VarToStr(V);
    Result := True;
  except
    Result := False;
  end;
end;

function ParseCalcRuleDefs(const AText: string): TaCalcRuleDefs;
var
  Txt, Rule, Head, Rest: string;
  P, Q, I, N: Integer;
  Names: TStringList;
begin
  SetLength(Result, 0);
  Names := TStringList.Create;
  try
    Txt := AText;
    while Trim(Txt) <> '' do
    begin
      P := Pos(';;', Txt);
      if P = 0 then begin Rule := Txt; Txt := ''; end
      else begin Rule := Copy(Txt, 1, P - 1); Txt := Copy(Txt, P + 2, MaxInt); end;
      P := Pos('->', Rule);
      if P < 2 then Continue;
      Head := Trim(Copy(Rule, 1, P - 1));
      Rest := Copy(Rule, P + 2, MaxInt);
      Q := Pos('=', Rest);
      if Q < 2 then Continue;
      N := Length(Result);
      SetLength(Result, N + 1);
      Names.Clear;
      Names.Delimiter := ',';
      Names.StrictDelimiter := True;
      Names.DelimitedText := Head;
      SetLength(Result[N].Triggers, 0);
      for I := 0 to Names.Count - 1 do
        if Trim(Names[I]) <> '' then
        begin
          SetLength(Result[N].Triggers, Length(Result[N].Triggers) + 1);
          Result[N].Triggers[High(Result[N].Triggers)] := LowerCase(Trim(Names[I]));
        end;
      Result[N].Target := Trim(Copy(Rest, 1, Q - 1));
      Result[N].Expr := Trim(Copy(Rest, Q + 1, MaxInt));
      if (Length(Result[N].Triggers) = 0) or (Result[N].Target = '') or (Result[N].Expr = '') then SetLength(Result, N);
    end;
  finally
    Names.Free;
  end;
end;

function ParseAutoFillDefs(const AText: string): TaAutoFillDefs;
var
  Txt, Rule, Head, Pair: string;
  P, Q, J, N: Integer;
  Pairs: TStringList;
  D: TaAutoFillDef;
begin
  SetLength(Result, 0);
  Pairs := TStringList.Create;
  try
    Txt := AText;
    while Trim(Txt) <> '' do
    begin
      P := Pos(';;', Txt);
      if P = 0 then begin Rule := Txt; Txt := ''; end
      else begin Rule := Copy(Txt, 1, P - 1); Txt := Copy(Txt, P + 2, MaxInt); end;
      Rule := Trim(Rule);
      P := Pos('>', Rule);
      Q := Pos(':', Rule);
      if (P < 2) or (Q < P) then Continue;
      D.Field := Trim(Copy(Rule, 1, P - 1));
      Head := Trim(Copy(Rule, P + 1, Q - P - 1));
      if Pos('.', Head) > 0 then
      begin
        D.Table := Copy(Head, 1, Pos('.', Head) - 1);
        D.KeyCol := Copy(Head, Pos('.', Head) + 1, MaxInt);
      end
      else begin D.Table := Head; D.KeyCol := 'id'; end;
      SetLength(D.Targets, 0);
      SetLength(D.Sources, 0);
      Pairs.Delimiter := ',';
      Pairs.StrictDelimiter := True;
      Pairs.DelimitedText := Copy(Rule, Q + 1, MaxInt);
      for J := 0 to Pairs.Count - 1 do
      begin
        Pair := Trim(Pairs[J]);
        if Pos('=', Pair) > 1 then
        begin
          N := Length(D.Targets);
          SetLength(D.Targets, N + 1);
          SetLength(D.Sources, N + 1);
          D.Targets[N] := Trim(Copy(Pair, 1, Pos('=', Pair) - 1));
          D.Sources[N] := Trim(Copy(Pair, Pos('=', Pair) + 1, MaxInt));
        end;
      end;
      if Length(D.Targets) = 0 then Continue;
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N] := D;
    end;
  finally
    Pairs.Free;
  end;
end;

function AutoFillLookup(ADb: TAppDb; const ARule: TaAutoFillDef; const AKey: string; AStored: TStrings): Boolean;
var
  Q: TZQuery;
  Sel: string;
  I: Integer;
begin
  Result := False;
  AStored.Clear;
  if Length(ARule.Targets) = 0 then Exit;
  Sel := '';
  for I := 0 to High(ARule.Sources) do
  begin
    if Sel <> '' then Sel := Sel + ', ';
    Sel := Sel + ADb.QuoteId(ARule.Sources[I]);
  end;
  Q := ADb.NewQuery('SELECT ' + Sel + ' FROM ' + ADb.QuoteId(ARule.Table) + ' WHERE ' + ADb.QuoteId(ARule.KeyCol) + ' = :k');
  try
    try
      Q.ParamByName('k').AsString := AKey;
      Q.Open;
      if Q.EOF then Exit;
      for I := 0 to High(ARule.Targets) do AStored.Add(ARule.Targets[I] + '=' + FieldStored(Q.Fields[I]));
      Result := True;
    except
      Result := False;
    end;
  finally
    Q.Free;
  end;
end;

end.
