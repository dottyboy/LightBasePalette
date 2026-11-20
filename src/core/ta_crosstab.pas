unit ta_crosstab;
{ Unakrsni upiti (pivot) i unije: generiraju običan SQL koji se sprema kao upit.
  Stupci unakrsnog upita su vrijednosti polja u trenutku izrade; ako se pojave
  nove vrijednosti, upit treba ponovno izraditi. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZDataset, ta_meta, ta_wizardgen;

type
  TCtAgg = (caSum, caCount, caAvg, caMin, caMax);

const
  CtMaxColumns = 60;
  CtAggNames: array[TCtAgg] of string = ('Zbroj', 'Broj', 'Prosjek', 'Najmanje', 'Najviše');

{ ARowField: što je u retku, AColField: čije vrijednosti postaju stupci,
  AValueField: što se zbraja (za Broj može biti prazno). }
function BuildCrosstabSql(ADb: TAppDb; const ASource, ARowField, AColField, AValueField: string;
  AAgg: TCtAgg; AShowTotal: Boolean; out ASql, AError: string): Boolean;
{ Spaja izvore (tablice ili upite) sa istim brojem stupaca. }
function BuildUnionSql(ADb: TAppDb; ASources: TStrings; AAll: Boolean; out ASql, AError: string): Boolean;

implementation

function AggRaw(AAgg: TCtAgg; const AExpr: string): string; forward;

{ Prazne celije su 0.0: izraz bez deklariranog tipa u SQLite-u Zeos inace pretvori u
  memo polje ako je prvi redak NULL, a mreža bi tada pokazala "(MEMO)". }
function AggSql(AAgg: TCtAgg; const AExpr: string): string;
begin
  Result := 'COALESCE(' + AggRaw(AAgg, AExpr) + ', 0.0)';
  if AAgg = caCount then Result := AggRaw(AAgg, AExpr);
end;

function AggRaw(AAgg: TCtAgg; const AExpr: string): string;
begin
  case AAgg of
    caSum: Result := 'SUM(' + AExpr + ')';
    caCount: Result := 'COUNT(' + AExpr + ')';
    caAvg: Result := 'AVG(' + AExpr + ')';
    caMin: Result := 'MIN(' + AExpr + ')';
  else
    Result := 'MAX(' + AExpr + ')';
  end;
end;

function BuildCrosstabSql(ADb: TAppDb; const ASource, ARowField, AColField, AValueField: string;
  AAgg: TCtAgg; AShowTotal: Boolean; out ASql, AError: string): Boolean;
var
  Q: TZQuery;
  From, Col, Row, Val, Cond, Alias, Sel, Total: string;
  Used: TStringList;
  N: Integer;
  IsNullVal: Boolean;
  V: string;

  function UniqueAlias(const A: string): string;
  var
    K: Integer;
  begin
    Result := A;
    K := 2;
    while Used.IndexOf(LowerCase(Result)) >= 0 do
    begin
      Result := A + '_' + IntToStr(K);
      Inc(K);
    end;
    Used.Add(LowerCase(Result));
  end;

begin
  Result := False;
  ASql := '';
  AError := '';
  if (ASource = '') or (ARowField = '') or (AColField = '') then
  begin AError := 'Odaberi izvor, polje za retke i polje za stupce.'; Exit; end;
  if SameText(ARowField, AColField) then begin AError := 'Retci i stupci moraju biti različita polja.'; Exit; end;
  if (AValueField = '') and (AAgg <> caCount) then begin AError := 'Odaberi polje koje se zbraja.'; Exit; end;
  From := ADb.SourceFromRaw(ASource);
  Row := ADb.QuoteId(ARowField);
  Col := ADb.QuoteId(AColField);
  if AValueField = '' then Val := '*' else Val := ADb.QuoteId(AValueField);
  Used := TStringList.Create;
  try
    Used.Add(LowerCase(ARowField));
    Inc(ADb.QuietParams);
    try
      Q := ADb.NewQuery('SELECT DISTINCT ' + Col + ' FROM ' + ADb.SourceFrom(ASource) + ' ORDER BY ' + Col);
    finally
      Dec(ADb.QuietParams);
    end;
    try
      try
        Q.Open;
      except
        on E: Exception do begin AError := E.Message; Exit; end;
      end;
      Sel := '';
      N := 0;
      while not Q.EOF do
      begin
        if N >= CtMaxColumns then
        begin
          AError := 'Polje "' + AColField + '" ima više od ' + IntToStr(CtMaxColumns) + ' različitih vrijednosti.';
          Exit;
        end;
        IsNullVal := Q.Fields[0].IsNull;
        V := Q.Fields[0].AsString;
        if IsNullVal then
        begin
          Cond := Col + ' IS NULL';
          Alias := '(prazno)';
        end
        else
        begin
          Cond := 'CAST(' + Col + ' AS TEXT) = ' + ADb.QuoteLit(V);
          Alias := V;
          if Trim(Alias) = '' then Alias := '(prazno)';
        end;
        Alias := UniqueAlias(Alias);
        if Sel <> '' then Sel := Sel + ',' + LineEnding + '       ';
        if AAgg = caCount then
          Sel := Sel + 'COUNT(CASE WHEN ' + Cond + ' THEN 1 END) AS ' + ADb.QuoteId(Alias)
        else
          Sel := Sel + AggSql(AAgg, 'CASE WHEN ' + Cond + ' THEN ' + Val + ' END') + ' AS ' + ADb.QuoteId(Alias);
        Inc(N);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    if N = 0 then begin AError := 'Nema podataka za stupce.'; Exit; end;
    Total := '';
    if AShowTotal then
    begin
      if AAgg = caCount then Total := ',' + LineEnding + '       COUNT(*) AS ' + ADb.QuoteId(UniqueAlias('Ukupno'))
      else Total := ',' + LineEnding + '       ' + AggSql(AAgg, Val) + ' AS ' + ADb.QuoteId(UniqueAlias('Ukupno'));
    end;
    ASql := 'SELECT ' + Row + ' AS ' + ADb.QuoteId(ARowField) + ',' + LineEnding + '       ' + Sel + Total + LineEnding +
      'FROM ' + From + LineEnding + 'GROUP BY ' + Row + LineEnding + 'ORDER BY ' + Row;
    Result := True;
  finally
    Used.Free;
  end;
end;

function BuildUnionSql(ADb: TAppDb; ASources: TStrings; AAll: Boolean; out ASql, AError: string): Boolean;
var
  I, N0, N: Integer;
  L: TaSourceFields;
  Glue: string;
begin
  Result := False;
  ASql := '';
  AError := '';
  if ASources.Count < 2 then begin AError := 'Odaberi barem dva izvora.'; Exit; end;
  N0 := -1;
  for I := 0 to ASources.Count - 1 do
  begin
    try
      L := SourceFieldList(ADb, ASources[I]);
    except
      on E: Exception do begin AError := ASources[I] + ': ' + E.Message; Exit; end;
    end;
    N := Length(L);
    if N0 < 0 then N0 := N
    else if N <> N0 then
    begin
      AError := 'Izvori nemaju isti broj stupaca: ' + ASources[0] + ' (' + IntToStr(N0) + ') i ' +
        ASources[I] + ' (' + IntToStr(N) + ').';
      Exit;
    end;
  end;
  if AAll then Glue := LineEnding + 'UNION ALL' + LineEnding else Glue := LineEnding + 'UNION' + LineEnding;
  for I := 0 to ASources.Count - 1 do
  begin
    if I > 0 then ASql := ASql + Glue;
    ASql := ASql + 'SELECT * FROM ' + ADb.SourceFromRaw(ASources[I]);
  end;
  Result := True;
end;

end.
