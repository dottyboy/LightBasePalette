unit ta_gridtools;
{ Filteri po stupcima za mreze (datasheet): unos tipa >100, 5..10, ra*, 2026,
  (prazno) pretvara se u SQL uvjet nad jednim stupcem. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta;

type
  TFilterKind = (fkText, fkNumber, fkDate, fkBool);

{ ACol je stupac vec citiran za SQL. Prazan AText daje prazan uvjet. }
function ColumnFilterSql(const ACol: string; AKind: TFilterKind; const AText: string;
  out ASql, AError: string): Boolean;
{ Kratak opis sintakse za pomoc u dijalogu. }
function FilterHelp(AKind: TFilterKind): string;

{ Spremljeni skupovi filtera po formi (u postavkama baze): Polje=filter po retku. }
procedure SaveFilterSet(ADb: TAppDb; const AForm, AName: string; AFilters: TStrings);
function LoadFilterSet(ADb: TAppDb; const AForm, AName: string; AFilters: TStrings): Boolean;
function ListFilterSets(ADb: TAppDb; const AForm: string): TStringList;
procedure DeleteFilterSet(ADb: TAppDb; const AForm, AName: string);

implementation

uses
  ZDataset, ta_params;

function Lit(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function IsQuotedIsoDate(const S: string): Boolean;
begin
  Result := (Length(S) = 12) and (S[1] = '''') and (S[12] = '''') and (S[6] = '-') and (S[9] = '-');
end;

function FilterHelp(AKind: TFilterKind): string;
begin
  case AKind of
    fkNumber: Result := 'npr. 100, >100, <=50, 10..20, (prazno)';
    fkDate: Result := 'npr. 31.12.2026, >2026-01-01, 01.01.2026..31.03.2026, 2026, (prazno)';
    fkBool: Result := 'da / ne';
  else
    Result := 'sadrži tekst; ra* = počinje s ra; =točno; (prazno)';
  end;
end;

function ColumnFilterSql(const ACol: string; AKind: TFilterKind; const AText: string;
  out ASql, AError: string): Boolean;
const
  Ops: array[0..5] of string = ('>=', '<=', '<>', '>', '<', '=');
var
  T, L, Op, Rest, V, V2, Col, P: string;
  I, K: Integer;

  function Value(const S: string; out ALit: string): Boolean;
  begin
    ALit := ParamLiteral(S);
    case AKind of
      fkNumber:
        begin
          Result := (ALit <> 'NULL') and (ALit[1] <> '''');
          if not Result then AError := 'Očekujem broj: ' + S;
        end;
      fkDate:
        begin
          Result := IsQuotedIsoDate(ALit);
          if not Result then AError := 'Očekujem datum (dd.mm.gggg): ' + S;
        end;
    else
      Result := True;
      if (ALit = 'NULL') or ((ALit <> '') and (ALit[1] <> '''')) then ALit := Lit(Trim(S));
    end;
  end;

begin
  ASql := '';
  AError := '';
  Result := True;
  T := Trim(AText);
  if T = '' then Exit;
  L := LowerCase(T);
  if (L = '(prazno)') or (L = 'prazno') or (L = 'null') then
  begin
    ASql := '(' + ACol + ' IS NULL OR ' + ACol + ' = '''')';
    Exit;
  end;
  if (L = '(nije prazno)') or (L = '!prazno') or (L = 'nije prazno') or (L = 'not null') then
  begin
    ASql := '(' + ACol + ' IS NOT NULL AND ' + ACol + ' <> '''')';
    Exit;
  end;
  if AKind = fkBool then
  begin
    if (L = 'da') or (L = '1') or (L = 'true') or (L = 'yes') then ASql := ACol + ' = 1'
    else if (L = 'ne') or (L = '0') or (L = 'false') or (L = 'no') then ASql := '(' + ACol + ' = 0 OR ' + ACol + ' IS NULL)'
    else begin AError := 'Za Da/Ne upiši da ili ne'; Result := False; end;
    Exit;
  end;
  Col := ACol;
  if AKind = fkDate then Col := 'substr(' + ACol + ', 1, 10)';
  { godina: 2026 }
  if (AKind = fkDate) and (Length(T) = 4) and (StrToIntDef(T, -1) > 999) then
  begin
    ASql := 'substr(' + ACol + ', 1, 4) = ' + Lit(T);
    Exit;
  end;
  { raspon a..b }
  K := Pos('..', T);
  if (K > 1) and (AKind in [fkNumber, fkDate]) then
  begin
    if not (Value(Trim(Copy(T, 1, K - 1)), V) and Value(Trim(Copy(T, K + 2, MaxInt)), V2)) then Exit(False);
    ASql := '(' + Col + ' BETWEEN ' + V + ' AND ' + V2 + ')';
    Exit;
  end;
  { operator }
  Op := '';
  Rest := T;
  for I := 0 to High(Ops) do
    if Copy(T, 1, Length(Ops[I])) = Ops[I] then
    begin
      Op := Ops[I];
      Rest := Trim(Copy(T, Length(Op) + 1, MaxInt));
      Break;
    end;
  if Op <> '' then
  begin
    if Rest = '' then begin AError := 'Nedostaje vrijednost iza ' + Op; Exit(False); end;
    if not Value(Rest, V) then Exit(False);
    if (AKind = fkText) and (Op = '=') then ASql := ACol + ' = ' + V
    else ASql := Col + ' ' + Op + ' ' + V;
    Exit;
  end;
  case AKind of
    fkNumber, fkDate:
      begin
        if not Value(T, V) then Exit(False);
        ASql := Col + ' = ' + V;
      end;
  else
    if (Pos('*', T) > 0) or (Pos('?', T) > 0) then
    begin
      P := StringReplace(T, '\', '\\', [rfReplaceAll]);
      P := StringReplace(P, '%', '\%', [rfReplaceAll]);
      P := StringReplace(P, '_', '\_', [rfReplaceAll]);
      P := StringReplace(P, '*', '%', [rfReplaceAll]);
      P := StringReplace(P, '?', '_', [rfReplaceAll]);
      ASql := 'CAST(' + ACol + ' AS TEXT) LIKE ' + Lit(P) + ' ESCAPE ''\''';
    end
    else
      ASql := 'instr(lower(CAST(' + ACol + ' AS TEXT)), lower(' + Lit(T) + ')) > 0';
  end;
end;

{ ---------------- spremljeni filteri ---------------- }

function SetKey(const AForm, AName: string): string;
begin
  Result := 'gridfilter.' + AForm + '.' + AName;
end;

procedure SaveFilterSet(ADb: TAppDb; const AForm, AName: string; AFilters: TStrings);
var
  I: Integer;
  S: string;
begin
  S := '';
  for I := 0 to AFilters.Count - 1 do
    if Trim(AFilters[I]) <> '' then S := S + AFilters[I] + #10;
  ADb.SaveSetting(SetKey(AForm, AName), S);
end;

function LoadFilterSet(ADb: TAppDb; const AForm, AName: string; AFilters: TStrings): Boolean;
var
  S: string;
begin
  S := ADb.LoadSetting(SetKey(AForm, AName));
  Result := S <> '';
  AFilters.Clear;
  if Result then AFilters.Text := StringReplace(S, #10, LineEnding, [rfReplaceAll]);
end;

function ListFilterSets(ADb: TAppDb; const AForm: string): TStringList;
var
  Q: TZQuery;
  Pre: string;
begin
  Result := TStringList.Create;
  Pre := 'gridfilter.' + AForm + '.';
  Q := ADb.NewQuery('SELECT k FROM _sys_settings WHERE substr(k, 1, ' + IntToStr(Length(Pre)) + ') = ' + ADb.QuoteLit(Pre) + ' ORDER BY k');
  try
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Copy(Q.Fields[0].AsString, Length(Pre) + 1, MaxInt));
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure DeleteFilterSet(ADb: TAppDb; const AForm, AName: string);
var
  Q: TZQuery;
begin
  Q := ADb.NewQuery('DELETE FROM _sys_settings WHERE k = :k');
  try
    Q.ParamByName('k').AsString := SetKey(AForm, AName);
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

end.
