unit ta_schemaplan;
{ Analiza sheme baze (etapa 1 plana PLAN-generator-aplikacije.md): za svaku tablicu odredi ulogu i stupce (kljuc, obavezno, strani kljuc),
  a ApplyDictionaryFromSchema iz toga popuni rjecnik podataka (_sys_fields) samo ondje gdje jos nema vrijednosti.
  Uloge: glavna (Main), stavke (Detail), sifrarnik (Codebook), veza (Junction), preskoci (Skip). Uloga se moze promijeniti rucno. }
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, ta_types, ta_meta;

type
  TaTableRole = (trMain, trDetail, trCodebook, trJunction, trSkip);

  TaColPlan = record
    Name: string;
    LType: TaLogicalType;
    IsKey, NotNull, HasDefault: Boolean;
    FkTable, FkCol: string;      { strani kljuc: prema kojoj tablici i stupcu }
  end;

  TaTablePlan = class
  public
    Name, Caption: string;
    Role: TaTableRole;
    Cols: array of TaColPlan;
    Parent: string;              { stavke: nadredena tablica }
    FkToParent, ParentCol: string;
    KeyCount: Integer;           { broj stupaca u primarnom kljucu }
    function ColIndex(const AName: string): Integer;
    function FkCount: Integer;
    function OtherCount: Integer;   { stupci koji nisu kljuc ni strani kljuc }
  end;

  TaSchemaPlan = class(TObjectList)
  public
    function Table(const AName: string): TaTablePlan;
    function Items2(I: Integer): TaTablePlan;
  end;

  TaDictOptions = record
    Numbering: Boolean;    { stupac s brojem dokumenta dobiva serijski broj {seq}/{pp}/{nu} }
    Stamps: Boolean;       { stupci created/modified dobivaju automatski upis }
  end;

const
  RoleNames: array[TaTableRole] of string = ('main', 'detail', 'codebook', 'junction', 'skip');

function AnalyzeSchema(ADb: TAppDb): TaSchemaPlan;
function RoleFromName(const AName: string): TaTableRole;
{ rucno mijenjanje uloge: za stavke trazi nadredenu tablicu preko stranog kljuca (AParent = '' bira najbolju); False kad to nije moguce }
function SetTableRole(APlan: TaSchemaPlan; T: TaTablePlan; ARole: TaTableRole; const AParent: string): Boolean;
{ tablice na koje ova tablica ima strani kljuc (moguci nadredeni zapisi za stavke) }
function ParentCandidates(APlan: TaSchemaPlan; T: TaTablePlan): TStringList;
{ popunjava rjecnik; vraca broj polja ciji je zapis dopunjen }
function ApplyDictionaryFromSchema(ADb: TAppDb; APlan: TaSchemaPlan; const AOpt: TaDictOptions; ALog: TStrings): Integer;

implementation

uses
  DB, ZDataset, Math, LazUTF8, ta_wizardgen;

function TaTablePlan.ColIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Cols) do
    if SameText(Cols[I].Name, AName) then Exit(I);
  Result := -1;
end;

function TaTablePlan.FkCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Cols) do
    if Cols[I].FkTable <> '' then Inc(Result);
end;

function TaTablePlan.OtherCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(Cols) do
    if (not Cols[I].IsKey) and (Cols[I].FkTable = '') then Inc(Result);
end;

function TaSchemaPlan.Table(const AName: string): TaTablePlan;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items2(I).Name, AName) then Exit(Items2(I));
  Result := nil;
end;

function TaSchemaPlan.Items2(I: Integer): TaTablePlan;
begin
  Result := TaTablePlan(Items[I]);
end;

function RoleFromName(const AName: string): TaTableRole;
var
  R: TaTableRole;
begin
  for R := Low(R) to High(R) do
    if SameText(RoleNames[R], AName) then Exit(R);
  Result := trMain;
end;

function ParentCandidates(APlan: TaSchemaPlan; T: TaTablePlan): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(T.Cols) do
    if (T.Cols[I].FkTable <> '') and (SameText(T.Cols[I].FkTable, T.Name) = False) and (APlan.Table(T.Cols[I].FkTable) <> nil) and
       (Result.IndexOf(T.Cols[I].FkTable) < 0) then Result.Add(T.Cols[I].FkTable);
end;

function SetTableRole(APlan: TaSchemaPlan; T: TaTablePlan; ARole: TaTableRole; const AParent: string): Boolean;
var
  I, K: Integer;
  Cand: TStringList;
  PName: string;
begin
  Result := True;
  if ARole <> trDetail then
  begin
    T.Role := ARole;
    T.Parent := '';
    T.FkToParent := '';
    T.ParentCol := '';
    Exit;
  end;
  Cand := ParentCandidates(APlan, T);
  try
    PName := AParent;
    if PName = '' then
    begin
      { najbolja: glavna tablica, inace prva }
      for I := 0 to Cand.Count - 1 do
        if (APlan.Table(Cand[I]).Role = trMain) and (PName = '') then PName := Cand[I];
      if (PName = '') and (Cand.Count > 0) then PName := Cand[0];
    end;
    if (PName = '') or (Cand.IndexOf(PName) < 0) then Exit(False);
  finally
    Cand.Free;
  end;
  K := -1;
  for I := 0 to High(T.Cols) do
    if SameText(T.Cols[I].FkTable, PName) then begin K := I; Break; end;
  if K < 0 then Exit(False);
  T.Role := trDetail;
  T.Parent := PName;
  T.FkToParent := T.Cols[K].Name;
  T.ParentCol := T.Cols[K].FkCol;
  { nadredena tablica ne smije biti stavka; ako je bila skip/sifrarnik ostaje kakva je }
  if APlan.Table(PName).Role = trDetail then Result := False;
end;

function LooksLikeDetail(const AName: string): Boolean;
var
  L: string;
begin
  L := LowerCase(AName);
  Result := (Pos('detail', L) > 0) or (Pos('detalj', L) > 0) or (Pos('stavk', L) > 0) or (Pos('item', L) > 0) or
    (Pos('line', L) > 0) or (Pos('row', L) > 0);
end;

{ pomocne tablice: zapisnik, arhiva, uvoz, privremeno: nisu dio aplikacije za unos }
function LooksLikeUtility(const AName: string): Boolean;
var
  L: string;
begin
  L := LowerCase(AName);
  Result := (Pos('dnevnik', L) > 0) or (Pos('log', L) = 1) or (Pos('_log', L) > 0) or (Pos('audit', L) > 0) or (Pos('arhiv', L) > 0) or
    (Pos('archive', L) > 0) or (Pos('uvoz', L) > 0) or (Pos('import', L) > 0) or (Pos('temp', L) = 1) or (Pos('tmp', L) = 1) or
    (Pos('backup', L) > 0) or (Pos('staging', L) > 0) or (Pos('history', L) > 0) or (Pos('povijest', L) > 0);
end;

{ naziv nadredene tablice je (u jednini ili mnozini) sadrzan u nazivu stavki: OrderDetails/Orders, stavke_racuna/racuni }
function NameContains(const ADetail, AParent: string): Boolean;
var
  D, P, Stem: string;
begin
  D := LowerCase(ADetail);
  P := LowerCase(AParent);
  if Pos(P, D) > 0 then Exit(True);
  Stem := P;
  while (Length(Stem) > 3) and (Stem[Length(Stem)] in ['s', 'i', 'a', 'e', 'u']) do Delete(Stem, Length(Stem), 1);
  Result := (Length(Stem) >= 3) and (Pos(Stem, D) > 0);
end;

{ naziv tablice pocinje nazivom nadredene (ugovor_faze / ugovori, ponude_posla_faze / ponude_posla) }
function StartsWithParent(const AChild, AParent: string): Boolean;
var
  C, P, Stem: string;
begin
  C := LowerCase(AChild);
  P := LowerCase(AParent);
  if (Length(C) > Length(P)) and (Copy(C, 1, Length(P)) = P) then Exit(True);
  Stem := P;
  while (Length(Stem) > 3) and (Stem[Length(Stem)] in ['s', 'i', 'a', 'e', 'u']) do Delete(Stem, Length(Stem), 1);
  Result := (Length(Stem) >= 4) and (Length(C) > Length(Stem)) and (Copy(C, 1, Length(Stem)) = Stem) and (C[Length(Stem) + 1] = '_');
end;

{ ima li tablica stupac po kojem se zapis samostalno prepoznaje (broj, naziv, sifra) }
function HasIdentity(T: TaTablePlan): Boolean;
const
  Names: array[0..7] of string = ('broj', 'number', 'naziv', 'name', 'sifra', 'code', 'oznaka', 'title');
var
  I, J: Integer;
begin
  Result := False;
  for I := 0 to High(T.Cols) do
    for J := 0 to High(Names) do
      if SameText(T.Cols[I].Name, Names[J]) then Exit(True);
end;

function AnalyzeSchema(ADb: TAppDb): TaSchemaPlan;
var
  Tables: TStringList;
  Fields: TaSourceFields;
  Fks: TaFkDefs;
  Q: TZQuery;
  I, J, K, N: Integer;
  P: TaTablePlan;
  Info, InfoNN, InfoDef, InfoPk: TStringList;     { paralelno: naziv, notnull, zadano, pk }
  Pk: string;
  Referenced: TStringList;
  Cand: TaTablePlan;
  Best, Score: Integer;
begin
  Result := TaSchemaPlan.Create(True);
  Tables := ADb.UserTables;
  Referenced := TStringList.Create;
  Info := TStringList.Create;
  InfoNN := TStringList.Create;
  InfoDef := TStringList.Create;
  InfoPk := TStringList.Create;
  try
    Referenced.CaseSensitive := False;
    for I := 0 to Tables.Count - 1 do
    begin
      if (Copy(Tables[I], 1, 5) = '_sys_') then Continue;
      P := TaTablePlan.Create;
      P.Name := Tables[I];
      P.Caption := PrettyName(Tables[I]);
      P.Role := trMain;
      Fields := SourceFieldList(ADb, Tables[I]);
      Info.Clear;
      InfoNN.Clear;
      InfoDef.Clear;
      InfoPk.Clear;
      Q := ADb.TableInfo(Tables[I]);
      try
        while not Q.EOF do
        begin
          Info.Add(Q.FieldByName('name').AsString);
          InfoNN.Add(IntToStr(Q.FieldByName('notnull').AsInteger));
          InfoDef.Add(Q.FieldByName('dflt_value').AsString);
          InfoPk.Add(IntToStr(Q.FieldByName('pk').AsInteger));
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      Fks := ADb.GetFks(Tables[I]);
      SetLength(P.Cols, Length(Fields));
      for J := 0 to High(Fields) do
      begin
        P.Cols[J].Name := Fields[J].Name;
        P.Cols[J].LType := Fields[J].LType;
        K := Info.IndexOf(Fields[J].Name);
        P.Cols[J].NotNull := (K >= 0) and (InfoNN[K] = '1');
        P.Cols[J].HasDefault := (K >= 0) and (InfoDef[K] <> '');
        P.Cols[J].IsKey := (K >= 0) and (InfoPk[K] <> '0') and (InfoPk[K] <> '');
        for N := 0 to High(Fks) do
          if SameText(Fks[N].FromCol, Fields[J].Name) then
          begin
            P.Cols[J].FkTable := Fks[N].RefTable;
            P.Cols[J].FkCol := Fks[N].RefCol;
            if Referenced.IndexOf(Fks[N].RefTable) < 0 then Referenced.Add(Fks[N].RefTable);
          end;
        if P.Cols[J].IsKey then Inc(P.KeyCount);
      end;
      Result.Add(P);
    end;
    { uloge }
    for I := 0 to Result.Count - 1 do
    begin
      P := Result.Items2(I);
      if (P.FkCount >= 2) and (P.OtherCount <= 1) then P.Role := trJunction
      else if (Referenced.IndexOf(P.Name) >= 0) and (P.OtherCount <= 3) and (P.FkCount = 0) then P.Role := trCodebook
      else if (P.FkCount = 0) and LooksLikeUtility(P.Name) and (Referenced.IndexOf(P.Name) < 0) then P.Role := trSkip
      else P.Role := trMain;
    end;
    { stavke: strani kljuc prema glavnoj tablici i naziv koji to pokazuje }
    for I := 0 to Result.Count - 1 do
    begin
      P := Result.Items2(I);
      if P.Role <> trMain then Continue;
      Cand := nil;
      Best := -1;
      for J := 0 to High(P.Cols) do
        if P.Cols[J].FkTable <> '' then
        begin
          Score := 0;
          if (Result.Table(P.Cols[J].FkTable) <> nil) and (Result.Table(P.Cols[J].FkTable).Role in [trMain]) then Score := 1;
          if NameContains(P.Name, P.Cols[J].FkTable) then Inc(Score, 2);
          if Score > Best then begin Best := Score; Cand := Result.Table(P.Cols[J].FkTable); K := J; end;
        end;
      if (Cand <> nil) and (Cand.Role = trMain) and (Cand <> P) and (LooksLikeDetail(P.Name) or ((P.KeyCount > 1) and NameContains(P.Name, Cand.Name)) or
         StartsWithParent(P.Name, Cand.Name) or ((P.FkCount = 1) and not HasIdentity(P) and (P.OtherCount <= 4) and (Referenced.IndexOf(P.Name) < 0))) then
      begin
        P.Role := trDetail;
        P.Parent := Cand.Name;
        P.FkToParent := P.Cols[K].Name;
        P.ParentCol := P.Cols[K].FkCol;
      end;
    end;
  finally
    Info.Free;
    InfoNN.Free;
    InfoDef.Free;
    InfoPk.Free;
    Referenced.Free;
    Tables.Free;
  end;
end;

function HumanizeKey(const ACol: string): string;
var
  S: string;
begin
  S := ACol;
  if (Length(S) > 3) and SameText(Copy(S, Length(S) - 2, 3), '_id') then Delete(S, Length(S) - 2, 3)
  else if (Length(S) > 2) and (Copy(S, Length(S) - 1, 2) = 'ID') then Delete(S, Length(S) - 1, 2)
  else if (Length(S) > 2) and (Copy(S, Length(S) - 1, 2) = 'Id') then Delete(S, Length(S) - 1, 2);
  Result := PrettyName(S);
end;

{ sirina stupca u mrezi (px) prema vrsti, zaglavlju i uzorku podataka; za strani kljuc prema nazivima iz povezane tablice }
function GridWidthFor(ADb: TAppDb; APlan: TaSchemaPlan; T: TaTablePlan; const C: TaColPlan; const ACaption: string): Integer;
var
  Chars, Len: Integer;
  Q: TZQuery;
  Src, Col: string;
begin
  Chars := UTF8Length(ACaption) + 2;
  case C.LType of
    ltInteger, ltAutoNumber: Chars := Max(Chars, 6);
    ltDecimal, ltCurrency: Chars := Max(Chars, 11);
    ltDate: Chars := Max(Chars, 11);
    ltDateTime: Chars := Max(Chars, 17);
    ltYesNo: Chars := Max(Chars, 7);
  end;
  Src := T.Name;
  Col := C.Name;
  if (C.FkTable <> '') and (APlan.Table(C.FkTable) <> nil) then
  begin
    Src := C.FkTable;
    Col := DisplayColumn(ADb, C.FkTable, C.FkCol);
  end;
  if (C.LType in [ltText, ltMemo]) or (C.FkTable <> '') then
  begin
    try
      Q := ADb.NewQuery('SELECT ' + ADb.QuoteId(Col) + ' FROM ' + ADb.QuoteId(Src) + ' LIMIT 200');
      try
        Q.Open;
        while not Q.Eof do
        begin
          Len := UTF8Length(Q.Fields[0].AsString);
          if Len > Chars then Chars := Len;
          Q.Next;
        end;
        if Q.RecordCount = 0 then Chars := Max(Chars, 14);
      finally
        Q.Free;
      end;
    except
    end;
  end;
  if Chars > 32 then Chars := 32;
  Result := Chars * 9 + 22;
end;

function ApplyDictionaryFromSchema(ADb: TAppDb; APlan: TaSchemaPlan; const AOpt: TaDictOptions; ALog: TStrings): Integer;
var
  I, J: Integer;
  T: TaTablePlan;
  C: TaColPlan;
  M: TaFieldMeta;
  Changed: Boolean;
  L: string;
  Total: Integer;
  Scale: Double;

  procedure Put(const AKey, AValue: string);
  begin
    if (AValue <> '') and (M.GetX(AKey) = '') then
    begin
      M.SetX(AKey, AValue);
      Changed := True;
    end;
  end;

begin
  Result := 0;
  for I := 0 to APlan.Count - 1 do
  begin
    T := APlan.Items2(I);
    if T.Role = trSkip then Continue;
    { stavke se pokazuju u podformi uz glavnu formu: stupci se skupe da stanu u oko 760 px }
    Scale := 1.0;
    if T.Role = trDetail then
    begin
      Total := 0;
      for J := 0 to High(T.Cols) do
        if not SameText(T.Cols[J].Name, T.FkToParent) then Inc(Total, GridWidthFor(ADb, APlan, T, T.Cols[J], PrettyName(T.Cols[J].Name)));
      if Total > 760 then Scale := 760 / Total;
    end;
    for J := 0 to High(T.Cols) do
    begin
      C := T.Cols[J];
      M := ADb.FindFieldMeta(T.Name, C.Name);
      Changed := False;
      if M = nil then
      begin
        M := TaFieldMeta.Create;
        M.TableName := T.Name;
        M.FieldName := C.Name;
        M.LType := C.LType;
        Changed := True;
      end;
      try
        L := LowerCase(C.Name);
        if M.Caption = '' then
        begin
          if C.FkTable <> '' then M.Caption := HumanizeKey(C.Name) else M.Caption := PrettyName(C.Name);
          Changed := True;
        end;
        if (M.Format = '') and (M.LType in [ltDecimal, ltCurrency]) then begin M.Format := '#,##0.00'; Changed := True; end;
        if (M.Format = '') and (M.LType in [ltDate, ltDateTime]) then
        begin
          if M.LType = ltDate then M.Format := 'dd.mm.yyyy' else M.Format := 'dd.mm.yyyy hh:nn';
          Changed := True;
        end;
        if M.ColWidth = 0 then begin M.ColWidth := Max(56, Trunc(GridWidthFor(ADb, APlan, T, C, M.Caption) * Scale)); Changed := True; end;
        if C.NotNull and not C.IsKey and not C.HasDefault and (M.LType <> ltYesNo) then Put('required', '1');
        if (M.LType in [ltInteger, ltDecimal, ltCurrency]) and not C.IsKey and (C.FkTable = '') then Put('align', 'right');
        if M.LType = ltYesNo then Put('variant', 'switch');
        if (C.FkTable <> '') and (APlan.Table(C.FkTable) <> nil) then
        begin
          Put('variant', 'combo');
          Put('rowsource', LookupQuerySql(ADb, C.FkTable, C.FkCol));
        end;
        if (Pos('oib', L) > 0) and (C.FkTable = '') then Put('mask', '99999999999');
        if (Pos('iban', L) > 0) then Put('mask', 'HR99 9999 9999 9999 9999 9');
        if ((Pos('postanski', L) > 0) or (Pos('postal', L) > 0) or (L = 'zip') or (L = 'pbr')) and (M.LType = ltText) then Put('mask', '99999');
        if AOpt.Stamps and (M.LType in [ltDate, ltDateTime, ltText]) then
        begin
          if (L = 'created') or (L = 'created_at') or (L = 'kreiran') or (L = 'datum_unosa') then Put('autoenter', 'created')
          else if (L = 'modified') or (L = 'updated') or (L = 'updated_at') or (L = 'izmijenjen') or (L = 'datum_izmjene') then Put('autoenter', 'modified');
        end;
        if AOpt.Numbering and (T.Role = trMain) and (M.LType = ltText) and not C.IsKey and
           ((L = 'broj') or (L = 'number') or (L = 'invoice_number') or (L = 'racun_broj') or (L = 'broj_racuna') or (L = 'doc_number')) then
        begin
          Put('autoenter', 'serial');
          Put('serial', '{seq}/{pp}/{nu}');
        end;
        if Changed then
        begin
          ADb.SaveFieldMeta(M);
          Inc(Result);
        end;
      finally
        M.Free;
      end;
    end;
    if ALog <> nil then ALog.Add(Format('%s: %s (%d polja)', [T.Name, RoleNames[T.Role], Length(T.Cols)]));
  end;
end;

end.
