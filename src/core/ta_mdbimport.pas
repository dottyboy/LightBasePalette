unit ta_mdbimport;
{ Uvoz iz Microsoft Accessa (.mdb, .accdb): tablice s vrstama polja, kljucevima, vezama i podacima, opisi polja,
  zadane vrijednosti, indeksi i spremljeni upiti. Forme, izvjesca, makroi i moduli iz Accessa NE prevode se
  (to je vlasnicki format vezan uz VBA), nego se navode u izvjestaju o neuvezenom, a nova aplikacija (forme, popisi,
  izbornik) slozi se iz uvezenih tablica pomocu opisa aplikacije.

  Citanje datoteke radi program mdbtools (mdb-tables, mdb-schema, mdb-export, mdb-queries), koji se samo POKRECE
  kao zaseban program (nije ugradjen). Nazivi tablica i polja ostaju kakvi su u Accessu, pa se spremljeni upiti
  (koji ih koriste) mogu izvesti bez prepravljanja. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta;

{ mapa u kojoj su mdb-* programi ('' = nisu pronadjeni); trazi se MDBTOOLS_DIR, PATH i ~/.local/share/typhaccess/mdbtools }
function MdbToolsDir: string;
function MdbToolsAvailable: Boolean;
{ tablice, veze, podaci i upiti iz Access datoteke u otvorenu bazu; ASpecText je opis aplikacije (nacrt) nad uvezenim tablicama.
  AReport dobiva izvjestaj o onome sto nije uvezeno. }
{ prepisuje Access SELECT u SQL (DISTINCTROW, TOP, CCur, IIf, Nz, Year...) }
function AccessSqlToSqlite(const ASql: string): string;
{ djelomicno pravilo iz Accessa (">= 0") u izraz nad poljem }
function MdbValidationExpr(const AField, ARule: string): string;
function ImportMdb(ADb: TAppDb; const AFile: string; ALog, AReport: TStrings; out ASpecText: string): Boolean;

implementation

uses
  ta_i18n,
  Process, Contnrs, StrUtils, ZDataset, LConvEncoding, ta_types, ta_filestore;

const
  NullMark = #1;

type
  TMdbColumn = class
  public
    Name, AccType, DefaultRaw, Comment: string;
    NotNull, Serial, Skip, IsOle: Boolean;
    Caption, ValRule, ValText, LookupTable, LookupCol: string;
    Logical: TaLogicalType;
    Decimals: Integer;
    Idx: Integer;          { stupac u CSV-u }
  end;

  TMdbIndex = class
  public
    Name, Table, Cols: string;
    Unique: Boolean;
  end;

  TMdbTable = class
  public
    Name, Comment: string;
    Columns: TObjectList;
    PkCols: TStringList;
    Indexes: TObjectList;
    Rows: TObjectList;     { TStringList po retku }
    RowCount: Integer;
    Created: Boolean;
    constructor Create;
    destructor Destroy; override;
    function ColByName(const AName: string): TMdbColumn;
  end;

  TMdbRelation = class
  public
    Name, Child, ChildCol, Parent, ParentCol: string;
    Flags, ColCount: Integer;
  end;

constructor TMdbTable.Create;
begin
  Columns := TObjectList.Create(True);
  PkCols := TStringList.Create;
  Indexes := TObjectList.Create(True);
  Rows := TObjectList.Create(True);
end;

destructor TMdbTable.Destroy;
begin
  Columns.Free; PkCols.Free; Indexes.Free; Rows.Free;
  inherited Destroy;
end;

function TMdbTable.ColByName(const AName: string): TMdbColumn;
var
  I: Integer;
begin
  for I := 0 to Columns.Count - 1 do
    if SameText(TMdbColumn(Columns[I]).Name, AName) then Exit(TMdbColumn(Columns[I]));
  Result := nil;
end;

{ ---------------- pokretanje mdbtools ---------------- }

var
  CachedDir: string = '?';

function MdbToolsDir: string;
var
  Cand: array[0..3] of string;
  I: Integer;
  P: string;
begin
  if CachedDir <> '?' then Exit(CachedDir);
  CachedDir := '';
  Cand[0] := GetEnvironmentVariable('MDBTOOLS_DIR');
  Cand[1] := '';
  P := FileSearch('mdb-tables', GetEnvironmentVariable('PATH'));
  if P <> '' then Cand[1] := ExtractFilePath(P);
  Cand[2] := IncludeTrailingPathDelimiter(GetUserDir) + '.local/share/typhaccess/mdbtools/usr/bin/';
  Cand[3] := '/usr/bin/';
  for I := 0 to High(Cand) do
    if (Cand[I] <> '') and FileExists(IncludeTrailingPathDelimiter(Cand[I]) + 'mdb-tables') then
    begin
      CachedDir := IncludeTrailingPathDelimiter(Cand[I]);
      Break;
    end;
  Result := CachedDir;
end;

function MdbToolsAvailable: Boolean;
begin
  Result := MdbToolsDir <> '';
end;

{ pokrece mdb-program i vraca njegov izlaz (UTF-8) }
function RunMdb(const ATool: string; const AArgs: array of string; out AOut: string): Boolean;
var
  P: TProcess;
  I, N: Integer;
  Buf: array[0..65535] of Byte;
  Ms: TMemoryStream;
  Lib: string;
begin
  Result := False;
  AOut := '';
  P := TProcess.Create(nil);
  Ms := TMemoryStream.Create;
  try
    P.Executable := MdbToolsDir + ATool;
    for I := 0 to High(AArgs) do P.Parameters.Add(AArgs[I]);
    P.Options := [poUsePipes, poStderrToOutput];
    { biblioteke uz lokalno raspakirani mdbtools }
    Lib := ExtractFilePath(ExcludeTrailingPathDelimiter(MdbToolsDir)) + 'lib/x86_64-linux-gnu';
    if DirectoryExists(Lib) then
    begin
      for I := 1 to GetEnvironmentVariableCount do P.Environment.Add(GetEnvironmentString(I));
      P.Environment.Add('LD_LIBRARY_PATH=' + Lib + ':' + GetEnvironmentVariable('LD_LIBRARY_PATH'));
    end;
    try
      P.Execute;
    except
      Exit;
    end;
    while P.Running or (P.Output.NumBytesAvailable > 0) do
    begin
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then Ms.WriteBuffer(Buf, N)
      else if not P.Running then Break
      else Sleep(2);
    end;
    SetLength(AOut, Ms.Size);
    if Ms.Size > 0 then Move(Ms.Memory^, AOut[1], Ms.Size);
    Result := P.ExitStatus = 0;
  finally
    Ms.Free;
    P.Free;
  end;
end;

{ ---------------- CSV ---------------- }

{ jedan redak po TStringList; NULL (prazno bez navodnika) je NullMark, prazan tekst je '' }
procedure ParseCsv(const S: string; ARows: TObjectList);
var
  I, L: Integer;
  Row: TStringList;
  Cur: string;
  Quoted, HaveField: Boolean;
begin
  L := Length(S);
  I := 1;
  Row := TStringList.Create;
  Cur := '';
  Quoted := False;
  HaveField := False;
  while I <= L do
  begin
    if S[I] = '"' then
    begin
      Quoted := True;
      HaveField := True;
      Inc(I);
      while I <= L do
      begin
        if S[I] = '"' then
        begin
          if (I < L) and (S[I + 1] = '"') then begin Cur := Cur + '"'; Inc(I, 2); end
          else begin Inc(I); Break; end;
        end
        else begin Cur := Cur + S[I]; Inc(I); end;
      end;
    end
    else if S[I] = ',' then
    begin
      if Quoted then Row.Add(Cur) else if Cur = '' then Row.Add(NullMark) else Row.Add(Cur);
      Cur := ''; Quoted := False; HaveField := False;
      Inc(I);
    end
    else if (S[I] = #13) or (S[I] = #10) then
    begin
      if HaveField or (Cur <> '') or (Row.Count > 0) then
      begin
        if Quoted then Row.Add(Cur) else if Cur = '' then Row.Add(NullMark) else Row.Add(Cur);
        ARows.Add(Row);
        Row := TStringList.Create;
      end;
      Cur := ''; Quoted := False; HaveField := False;
      if (S[I] = #13) and (I < L) and (S[I + 1] = #10) then Inc(I);
      Inc(I);
    end
    else begin Cur := Cur + S[I]; HaveField := True; Inc(I); end;
  end;
  if HaveField or (Cur <> '') or (Row.Count > 0) then
  begin
    if Quoted then Row.Add(Cur) else if Cur = '' then Row.Add(NullMark) else Row.Add(Cur);
    ARows.Add(Row);
  end
  else Row.Free;
end;

function InvariantFloat(const S: string; out V: Double): Boolean;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := TryStrToFloat(Trim(S), V, FS);
end;

{ ---------------- shema ---------------- }

function Unbracket(const S: string): string;
var
  T: string;
begin
  T := Trim(S);
  if (Length(T) >= 2) and (T[1] = '[') and (T[Length(T)] = ']') then T := Copy(T, 2, Length(T) - 2);
  Result := T;
end;

function MapType(const AAcc: string; out ADecimals: Integer): TaLogicalType;
var
  T: string;
begin
  ADecimals := 0;
  T := LowerCase(Trim(AAcc));
  if Pos('(', T) > 0 then T := Trim(Copy(T, 1, Pos('(', T) - 1));
  Result := ltText;
  if (T = 'long integer') or (T = 'integer') or (T = 'byte') or (T = 'big int') then Result := ltInteger
  else if (T = 'single') or (T = 'double') or (T = 'numeric') or (T = 'decimal') then begin Result := ltDecimal; ADecimals := 2; end
  else if T = 'currency' then begin Result := ltCurrency; ADecimals := 2; end
  else if (T = 'boolean') or (T = 'yes/no') then Result := ltYesNo
  else if (Copy(T, 1, 8) = 'datetime') or (T = 'date') then Result := ltDateTime
  else if (Copy(T, 1, 4) = 'memo') then Result := ltMemo
  else if (T = 'text') or (T = 'replication id') then Result := ltText;
end;

{ zadana vrijednost iz Accessa -> izraz ovog alata ('' ako nema smisla) }
function MapDefault(const ARaw: string; ALogical: TaLogicalType): string;
var
  T, L: string;
begin
  T := Trim(ARaw);
  Result := '';
  if T = '' then Exit;
  if T[1] = '=' then T := Trim(Copy(T, 2, MaxInt));
  L := LowerCase(T);
  if (L = 'no') or (L = 'false') then Exit('0');
  if (L = 'yes') or (L = 'true') then Exit('1');
  if (L = 'now()') then Exit('Now()');
  if (L = 'date()') or (L = 'today()') then Exit('Today()');
  if (T[1] = '"') or (T[1] = '''') then Exit(T);
  if (T[1] in ['0'..'9', '-', '.']) then Exit(T);
end;

{ djelomicno pravilo iz Accessa (">= 0", "Is Not Null") u potpun izraz nad poljem }
function MdbValidationExpr(const AField, ARule: string): string;
var
  R, L: string;
begin
  R := Trim(ARule);
  L := LowerCase(R);
  Result := R;
  if R = '' then Exit;
  if L = 'is not null' then Result := 'Not IsNull([' + AField + '])'
  else if L = 'is null' then Result := 'IsNull([' + AField + '])'
  else if (R[1] in ['<', '>', '=']) or (Copy(L, 1, 7) = 'between') or (Copy(L, 1, 4) = 'like') or (Copy(L, 1, 3) = 'in ') then
    Result := '[' + AField + '] ' + R;
end;

{ sto mdb-prop kaze o stupcima tablice: Caption, ValidationRule/Text, DefaultValue, Required i popis za odabir (lookup) }
procedure ApplyColumnProps(const AText: string; T: TMdbTable);
var
  L: TStringList;
  I, P, Matched: Integer;
  Ln, Key, Val: string;
  C: TMdbColumn;
  RowSrc, SrcType: string;
  procedure Finish;
  var
    Tn, Kc: string;
    K: Integer;
  begin
    if C = nil then Exit;
    if (RowSrc <> '') and (LowerCase(SrcType) <> 'value list') and (LowerCase(SrcType) <> 'field list') then
    begin
      { naziv tablice, ili SELECT [T].[kljuc], ... FROM [T] }
      Tn := Unbracket(RowSrc);
      Kc := '';
      if Pos('select', LowerCase(Trim(RowSrc))) = 1 then
      begin
        K := Pos(' from ', LowerCase(RowSrc));
        Tn := '';
        if K > 0 then
        begin
          Tn := Trim(Copy(RowSrc, K + 6, MaxInt));
          if Pos(' ', Tn) > 0 then Tn := Copy(Tn, 1, Pos(' ', Tn) - 1);
          Tn := Unbracket(StringReplace(Tn, ';', '', [rfReplaceAll]));
          Kc := Trim(Copy(RowSrc, 7, K - 7));
          if Pos(',', Kc) > 0 then Kc := Copy(Kc, 1, Pos(',', Kc) - 1);
          if Pos('.', Kc) > 0 then Kc := Copy(Kc, LastDelimiter('.', Kc) + 1, MaxInt);
          Kc := Unbracket(Kc);
        end;
      end;
      if Tn <> '' then
      begin
        C.LookupTable := Tn;
        C.LookupCol := Kc;
      end;
    end;
    C := nil;
  end;
begin
  L := TStringList.Create;
  try
    L.Text := AText;
    Matched := 0;
    for I := 0 to L.Count - 1 do
      if Copy(L[I], 1, 6) = 'name: ' then
        if T.ColByName(Copy(L[I], 7, MaxInt)) <> nil then Inc(Matched);
    { mdb-prop trazi objekt po nazivu: isti naziv moze imati i forma, pa se rezultat vjeruje samo ako sadrzi stupce ove tablice }
    if Matched = 0 then Exit;
    C := nil;
    for I := 0 to L.Count - 1 do
    begin
      Ln := L[I];
      if Copy(Ln, 1, 6) = 'name: ' then
      begin
        Finish;
        C := T.ColByName(Copy(Ln, 7, MaxInt));
        RowSrc := ''; SrcType := '';
        Continue;
      end;
      if C = nil then Continue;
      Ln := Trim(Ln);
      P := Pos(': ', Ln);
      if P = 0 then Continue;
      Key := Copy(Ln, 1, P - 1);
      Val := Copy(Ln, P + 2, MaxInt);
      if Key = 'Caption' then C.Caption := Val
      else if Key = 'ValidationRule' then C.ValRule := Val
      else if Key = 'ValidationText' then C.ValText := Val
      else if (Key = 'DefaultValue') and (C.DefaultRaw = '') then C.DefaultRaw := Val
      else if (Key = 'Required') and (LowerCase(Val) = 'yes') then C.NotNull := True
      else if Key = 'RowSource' then RowSrc := Val
      else if Key = 'RowSourceType' then SrcType := Val;
    end;
    Finish;
  finally
    L.Free;
  end;
end;

{ Access sprema sliku kao OLE objekt (zaglavlje + slika). Trazi pocetak slike (BMP, PNG, JPEG ili GIF) u heksadecimalnom zapisu
  i vraca bajtove slike; '' ako slike nema. }
function HexToBytes(const AHex: string; AFrom, ACount: Integer): string;
var
  I, N: Integer;
begin
  N := ACount;
  if (AFrom - 1) + N * 2 > Length(AHex) then N := (Length(AHex) - (AFrom - 1)) div 2;
  SetLength(Result, N);
  for I := 0 to N - 1 do
    Result[I + 1] := Char(StrToIntDef('$' + Copy(AHex, AFrom + I * 2, 2), 0));
end;

function OleImageBytes(const AHex: string): string;
var
  H: string;
  P, Best, Sz: Integer;
  Kind: Integer;
  function FirstOf(const APat: string; ACheck: Integer): Integer;
  var
    Q: Integer;
  begin
    Result := 0;
    Q := Pos(APat, H);
    while Q > 0 do
    begin
      if (Q mod 2 = 1) and ((ACheck = 0) or ((Copy(H, Q + 12, 8) = '00000000') and (Copy(H, Q + 28, 8) = '28000000'))) then Exit(Q);
      Q := PosEx(APat, H, Q + 1);
    end;
  end;
begin
  Result := '';
  H := UpperCase(AHex);
  Best := 0;
  Kind := 0;
  P := FirstOf('424D', 1);
  if P > 0 then begin Best := P; Kind := 1; end;
  P := FirstOf('89504E470D0A1A0A', 0);
  if (P > 0) and ((Best = 0) or (P < Best)) then begin Best := P; Kind := 2; end;
  P := FirstOf('FFD8FF', 0);
  if (P > 0) and ((Best = 0) or (P < Best)) then begin Best := P; Kind := 3; end;
  P := FirstOf('47494638', 0);
  if (P > 0) and ((Best = 0) or (P < Best)) then begin Best := P; Kind := 4; end;
  if Best = 0 then Exit;
  if Kind = 1 then
  begin
    { velicina datoteke je u zaglavlju (4 bajta, little endian): ostatak je OLE ostatak }
    Sz := StrToIntDef('$' + Copy(H, Best + 10, 2) + Copy(H, Best + 8, 2) + Copy(H, Best + 6, 2) + Copy(H, Best + 4, 2), 0);
    if (Sz > 54) and (Best - 1 + Sz * 2 <= Length(H)) then Exit(HexToBytes(H, Best, Sz));
  end;
  Result := HexToBytes(H, Best, (Length(H) - Best + 1) div 2);
end;

{ cita shemu jedne tablice: stupci (Access oblik), pa PK, indekse i komentare (iz Postgres oblika, koji ima SERIAL) }
procedure ReadSchema(const AFile: string; T: TMdbTable);
var
  Out1, Line, Ln, Nm, Rest, Cmt, Cols: string;
  L: TStringList;
  I, P, Q: Integer;
  C: TMdbColumn;
  Ix: TMdbIndex;
  Col: string;
  Cn: TMdbColumn;
  Parts: TStringList;
  InTable: Boolean;
begin
  L := TStringList.Create;
  try
    if RunMdb('mdb-schema', ['-T', T.Name, '--default-values', AFile, 'access'], Out1) then
    begin
      L.Text := Out1;
      InTable := False;
      for I := 0 to L.Count - 1 do
      begin
        Line := Trim(L[I]);
        if Copy(Line, 1, 12) = 'CREATE TABLE' then begin InTable := True; Continue; end;
        if not InTable then Continue;
        if (Line = '(') or (Line = '') then Continue;
        if Line[1] = ')' then Break;
        if Line[1] <> '[' then Continue;
        P := Pos(']', Line);
        Nm := Copy(Line, 2, P - 2);
        Rest := Trim(Copy(Line, P + 1, MaxInt));
        if (Rest <> '') and (Rest[Length(Rest)] = ',') then Rest := Trim(Copy(Rest, 1, Length(Rest) - 1));
        C := TMdbColumn.Create;
        C.Name := Nm;
        C.Idx := T.Columns.Count;
        C.NotNull := Pos(' NOT NULL', Rest) > 0;
        Q := Pos(' DEFAULT ', Rest);
        if Q > 0 then begin C.DefaultRaw := Trim(Copy(Rest, Q + 9, MaxInt)); Rest := Copy(Rest, 1, Q - 1); end;
        Rest := StringReplace(Rest, ' NOT NULL', '', []);
        C.AccType := Trim(Rest);
        C.Logical := MapType(C.AccType, C.Decimals);
        if Pos('OLE', UpperCase(C.AccType)) = 1 then begin C.IsOle := True; C.Logical := ltPicture; end;
        T.Columns.Add(C);
      end;
    end;
    { Postgres oblik: SERIAL, komentari, primarni kljuc i indeksi (nazivi su mala slova) }
    if RunMdb('mdb-schema', ['-T', T.Name, '--indexes', '--comments', AFile, 'postgres'], Out1) then
    begin
      L.Text := Out1;
      Parts := TStringList.Create;
      try
        for I := 0 to L.Count - 1 do
        begin
          Ln := Trim(L[I]);
          if (Pos('"', Ln) = 1) and (Pos('SERIAL', Ln) > 0) then
          begin
            Nm := Copy(Ln, 2, Pos('"', Copy(Ln, 2, MaxInt)) - 1);
            Cn := T.ColByName(Nm);
            if Cn <> nil then begin Cn.Serial := True; Cn.Logical := ltAutoNumber; end;
          end
          else if Copy(Ln, 1, 17) = 'COMMENT ON COLUMN' then
          begin
            { COMMENT ON COLUMN "tablica"."polje" IS 'tekst'; }
            P := Pos(' IS ''', Ln);
            Cmt := Copy(Ln, P + 5, MaxInt);
            if (Cmt <> '') and (Cmt[Length(Cmt)] = ';') then Delete(Cmt, Length(Cmt), 1);
            if (Cmt <> '') and (Cmt[Length(Cmt)] = '''') then Delete(Cmt, Length(Cmt), 1);
            Cmt := StringReplace(Cmt, '''''', '''', [rfReplaceAll]);
            Col := Copy(Ln, 19, P - 19);              { "tablica"."polje" }
            Col := Copy(Col, LastDelimiter('.', Col) + 1, MaxInt);
            Col := StringReplace(Col, '"', '', [rfReplaceAll]);
            Cn := T.ColByName(Col);
            if Cn <> nil then Cn.Comment := Cmt;
          end
          else if Copy(Ln, 1, 16) = 'COMMENT ON TABLE' then
          begin
            P := Pos(' IS ''', Ln);
            Cmt := Copy(Ln, P + 5, MaxInt);
            if (Cmt <> '') and (Cmt[Length(Cmt)] = ';') then Delete(Cmt, Length(Cmt), 1);
            if (Cmt <> '') and (Cmt[Length(Cmt)] = '''') then Delete(Cmt, Length(Cmt), 1);
            T.Comment := StringReplace(Cmt, '''''', '''', [rfReplaceAll]);
          end
          else if (Pos('PRIMARY KEY', Ln) > 0) and (Pos('ADD CONSTRAINT', Ln) > 0) then
          begin
            Cols := Copy(Ln, Pos('PRIMARY KEY', Ln) + 11, MaxInt);
            Cols := StringReplace(StringReplace(StringReplace(Cols, '(', '', [rfReplaceAll]), ')', '', [rfReplaceAll]), ';', '', [rfReplaceAll]);
            Parts.CommaText := StringReplace(Cols, '"', '', [rfReplaceAll]);
            for Q := 0 to Parts.Count - 1 do
            begin
              Cn := T.ColByName(Trim(Parts[Q]));
              if Cn <> nil then T.PkCols.Add(Cn.Name);
            end;
          end
          else if (Copy(Ln, 1, 12) = 'CREATE INDEX') or (Copy(Ln, 1, 19) = 'CREATE UNIQUE INDEX') then
          begin
            Ix := TMdbIndex.Create;
            Ix.Unique := Copy(Ln, 1, 19) = 'CREATE UNIQUE INDEX';
            Cols := Copy(Ln, Pos('(', Ln) + 1, MaxInt);
            Cols := StringReplace(StringReplace(StringReplace(Cols, ')', '', [rfReplaceAll]), ';', '', [rfReplaceAll]), '"', '', [rfReplaceAll]);
            Parts.CommaText := Cols;
            Ix.Cols := '';
            for Q := 0 to Parts.Count - 1 do
            begin
              Cn := T.ColByName(Trim(Parts[Q]));
              if Cn <> nil then begin if Ix.Cols <> '' then Ix.Cols := Ix.Cols + ','; Ix.Cols := Ix.Cols + Cn.Name; end;
            end;
            Ix.Table := T.Name;
            Ix.Name := '';
            if Ix.Cols = '' then Ix.Free else T.Indexes.Add(Ix);
          end;
        end;
      finally
        Parts.Free;
      end;
    end;
    { svojstva stupaca: naslov, pravila, zadano, popis za odabir }
    if RunMdb('mdb-prop', [AFile, T.Name], Out1) then ApplyColumnProps(Out1, T);
  finally
    L.Free;
  end;
end;

{ ---------------- Access SQL -> SQL ---------------- }

{ argumenti poziva funkcije na najvisoj razini (zarezi unutar zagrada i navodnika ne dijele) }
procedure SplitArgs(const S: string; AList: TStrings);
var
  I, Depth: Integer;
  Cur: string;
  Q: Char;
begin
  AList.Clear;
  Cur := '';
  Depth := 0;
  Q := #0;
  for I := 1 to Length(S) do
  begin
    if Q <> #0 then
    begin
      Cur := Cur + S[I];
      if S[I] = Q then Q := #0;
    end
    else if (S[I] = '"') or (S[I] = '''') then begin Q := S[I]; Cur := Cur + S[I]; end
    else if S[I] = '(' then begin Inc(Depth); Cur := Cur + S[I]; end
    else if S[I] = ')' then begin Dec(Depth); Cur := Cur + S[I]; end
    else if (S[I] = ',') and (Depth = 0) then begin AList.Add(Trim(Cur)); Cur := ''; end
    else Cur := Cur + S[I];
  end;
  AList.Add(Trim(Cur));
end;

{ DatePart("q", x) -> izraz za SQLite; '' kad interval nije podrzan }
function DatePartSql(const AInterval, AExpr: string): string;
var
  I: string;
begin
  I := LowerCase(Trim(AInterval));
  I := StringReplace(StringReplace(I, '"', '', [rfReplaceAll]), '''', '', [rfReplaceAll]);
  Result := '';
  if I = 'yyyy' then Result := 'CAST(strftime(''%Y'', ' + AExpr + ') AS INTEGER)'
  else if I = 'q' then Result := '((CAST(strftime(''%m'', ' + AExpr + ') AS INTEGER) + 2) / 3)'
  else if I = 'm' then Result := 'CAST(strftime(''%m'', ' + AExpr + ') AS INTEGER)'
  else if I = 'd' then Result := 'CAST(strftime(''%d'', ' + AExpr + ') AS INTEGER)'
  else if I = 'w' then Result := '(CAST(strftime(''%w'', ' + AExpr + ') AS INTEGER) + 1)'
  else if I = 'y' then Result := 'CAST(strftime(''%j'', ' + AExpr + ') AS INTEGER)'
  else if I = 'h' then Result := 'CAST(strftime(''%H'', ' + AExpr + ') AS INTEGER)'
  else if I = 'n' then Result := 'CAST(strftime(''%M'', ' + AExpr + ') AS INTEGER)'
  else if I = 's' then Result := 'CAST(strftime(''%S'', ' + AExpr + ') AS INTEGER)';
end;

{ Format(x, "yyyy-mm") i slicni datumski oblici, te brojevi s dvije decimale }
function FormatSql(const AExpr, AFormat: string): string;
var
  F: string;
begin
  F := LowerCase(Trim(AFormat));
  F := StringReplace(StringReplace(F, '"', '', [rfReplaceAll]), '''', '', [rfReplaceAll]);
  Result := '';
  if F = 'yyyy' then Result := 'strftime(''%Y'', ' + AExpr + ')'
  else if F = 'mm' then Result := 'strftime(''%m'', ' + AExpr + ')'
  else if F = 'dd' then Result := 'strftime(''%d'', ' + AExpr + ')'
  else if F = 'yyyy-mm' then Result := 'strftime(''%Y-%m'', ' + AExpr + ')'
  else if F = 'yyyy-mm-dd' then Result := 'strftime(''%Y-%m-%d'', ' + AExpr + ')'
  else if F = 'mm/yyyy' then Result := 'strftime(''%m/%Y'', ' + AExpr + ')'
  else if F = 'dd.mm.yyyy' then Result := 'strftime(''%d.%m.%Y'', ' + AExpr + ')'
  else if (F = '0.00') or (F = '#,##0.00') or (F = 'fixed') or (F = 'standard') then Result := 'printf(''%.2f'', ' + AExpr + ')'
  else if (F = '0') or (F = '#,##0') then Result := 'printf(''%d'', ' + AExpr + ')';
end;

{ jedan prolaz: zamjenjuje prvi poziv funkcije Access-a koji pronadje; False kad nema vise }
function RewriteOnce(var ASql: string): Boolean;
const
  Funcs: array[0..25] of string = ('CCur', 'CDbl', 'CSng', 'CLng', 'CInt', 'Nz', 'IIf', 'Year', 'Month', 'Day', 'CStr', 'Int',
    'Left', 'Right', 'Mid', 'Len', 'UCase', 'LCase', 'InStr', 'DatePart', 'Format', 'Date', 'Now', 'IsNull', 'Trim', 'Abs');
var
  F, P, I, Depth, Start: Integer;
  Low, Inner, Rep: string;
  Args: TStringList;
  Ch: Char;
begin
  Result := False;
  Low := LowerCase(ASql);
  for F := 0 to High(Funcs) do
  begin
    P := Pos(LowerCase(Funcs[F]) + '(', Low);
    while P > 0 do
    begin
      { mora biti zasebna rijec }
      if (P = 1) or not (Low[P - 1] in ['a'..'z', '0'..'9', '_']) then Break;
      P := PosEx(LowerCase(Funcs[F]) + '(', Low, P + 1);
    end;
    if P = 0 then Continue;
    Start := P + Length(Funcs[F]);       { pozicija zagrade }
    Depth := 0;
    I := Start;
    while I <= Length(ASql) do
    begin
      Ch := ASql[I];
      if Ch = '(' then Inc(Depth)
      else if Ch = ')' then begin Dec(Depth); if Depth = 0 then Break; end;
      Inc(I);
    end;
    if I > Length(ASql) then Continue;
    Inner := Copy(ASql, Start + 1, I - Start - 1);
    Args := TStringList.Create;
    try
      SplitArgs(Inner, Args);
      Rep := '';
      if (Funcs[F] = 'CCur') or (Funcs[F] = 'CDbl') or (Funcs[F] = 'CSng') then Rep := '(' + Inner + ')'
      else if (Funcs[F] = 'CLng') or (Funcs[F] = 'CInt') or (Funcs[F] = 'Int') then Rep := 'CAST((' + Inner + ') AS INTEGER)'
      else if Funcs[F] = 'CStr' then Rep := 'CAST((' + Inner + ') AS TEXT)'
      else if (Funcs[F] = 'Nz') and (Args.Count = 1) then Rep := 'COALESCE(' + Args[0] + ', '''')'
      else if (Funcs[F] = 'Nz') and (Args.Count = 2) then Rep := 'COALESCE(' + Args[0] + ', ' + Args[1] + ')'
      else if (Funcs[F] = 'IIf') and (Args.Count = 3) then Rep := '(CASE WHEN ' + Args[0] + ' THEN ' + Args[1] + ' ELSE ' + Args[2] + ' END)'
      else if Funcs[F] = 'Year' then Rep := 'CAST(strftime(''%Y'', ' + Inner + ') AS INTEGER)'
      else if Funcs[F] = 'Month' then Rep := 'CAST(strftime(''%m'', ' + Inner + ') AS INTEGER)'
      else if Funcs[F] = 'Day' then Rep := 'CAST(strftime(''%d'', ' + Inner + ') AS INTEGER)'
      else if (Funcs[F] = 'Left') and (Args.Count = 2) then Rep := 'substr(' + Args[0] + ', 1, ' + Args[1] + ')'
      else if (Funcs[F] = 'Right') and (Args.Count = 2) then Rep := 'substr(' + Args[0] + ', -(' + Args[1] + '))'
      else if (Funcs[F] = 'Mid') and (Args.Count = 3) then Rep := 'substr(' + Args[0] + ', ' + Args[1] + ', ' + Args[2] + ')'
      else if (Funcs[F] = 'Mid') and (Args.Count = 2) then Rep := 'substr(' + Args[0] + ', ' + Args[1] + ')'
      else if Funcs[F] = 'Len' then Rep := 'length(' + Inner + ')'
      else if Funcs[F] = 'UCase' then Rep := 'upper(' + Inner + ')'
      else if Funcs[F] = 'LCase' then Rep := 'lower(' + Inner + ')'
      else if (Funcs[F] = 'InStr') and (Args.Count = 2) then Rep := 'instr(' + Args[0] + ', ' + Args[1] + ')'
      else if (Funcs[F] = 'IsNull') and (Args.Count = 1) then Rep := '(' + Args[0] + ' IS NULL)'
      else if Funcs[F] = 'Trim' then Rep := 'trim(' + Inner + ')'
      else if Funcs[F] = 'Abs' then Rep := 'abs(' + Inner + ')'
      else if (Funcs[F] = 'Date') and (Trim(Inner) = '') then Rep := 'date(''now'')'
      else if (Funcs[F] = 'Now') and (Trim(Inner) = '') then Rep := 'datetime(''now'')'
      else if (Funcs[F] = 'DatePart') and (Args.Count >= 2) then Rep := DatePartSql(Args[0], Args[1])
      else if (Funcs[F] = 'Format') and (Args.Count = 2) then Rep := FormatSql(Args[0], Args[1]);
    finally
      Args.Free;
    end;
    if Rep = '' then Continue;
    ASql := Copy(ASql, 1, P - 1) + Rep + Copy(ASql, I + 1, MaxInt);
    Exit(True);
  end;
end;

{ znakovni prolaz izvan navodnika: & -> ||, #m/d/yyyy# -> 'yyyy-mm-dd', Yes/No/True/False -> 1/0, DESCENDING -> DESC }
{ rijec koja je u SQL-u rezervirana, a u Accessu je moze biti naziv stupca (Bkg.From) }
function SqlKeyword(const AWord: string): Boolean;
begin
  Result := (' from to order group select where table index key by as on in is not and or limit values default check primary references all end case when then else set update delete insert into join left right inner outer union having distinct ' <> '') and
    (Pos(' ' + AWord + ' ', ' from to order group select where table index key by as on in is not and or limit values default check primary references all end case when then else set update delete insert into join left right inner outer union having distinct ') > 0);
end;

function NormalizeAccessText(const S: string): string;
var
  I, J, P1, P2: Integer;
  Q: Char;
  W, Lw, D: string;
  M, Dd, Y: Integer;
  AfterLike: Boolean;
begin
  Result := '';
  AfterLike := False;
  Q := #0;
  I := 1;
  while I <= Length(S) do
  begin
    if Q <> #0 then
    begin
      Result := Result + S[I];
      if S[I] = Q then Q := #0;
      Inc(I);
    end
    else if S[I] = '"' then
    begin
      { tekst u dvostrukim navodnicima je u SQL-u tekst u jednostrukim }
      J := PosEx('"', S, I + 1);
      if J = 0 then J := Length(S) + 1;
      W := Copy(S, I + 1, J - I - 1);
      W := StringReplace(W, '''', '''''', [rfReplaceAll]);
      if AfterLike then begin W := StringReplace(StringReplace(W, '*', '%', [rfReplaceAll]), '?', '_', [rfReplaceAll]); AfterLike := False; end;
      Result := Result + '''' + W + '''';
      I := J + 1;
    end
    else if S[I] = '''' then
    begin
      Result := Result + S[I];
      Inc(I);
      J := I;
      while (J <= Length(S)) and (S[J] <> '''') do Inc(J);
      W := Copy(S, I, J - I);
      if AfterLike then begin W := StringReplace(StringReplace(W, '*', '%', [rfReplaceAll]), '?', '_', [rfReplaceAll]); AfterLike := False; end;
      Result := Result + W;
      I := J;
      if I <= Length(S) then begin Result := Result + ''''; Inc(I); end;
    end
    else if S[I] = '&' then begin Result := Result + ' || '; Inc(I); end
    else if S[I] = '#' then
    begin
      J := PosEx('#', S, I + 1);
      if J > 0 then
      begin
        D := Copy(S, I + 1, J - I - 1);
        P1 := Pos('/', D);
        P2 := PosEx('/', D, P1 + 1);
        if (P1 > 0) and (P2 > 0) then
        begin
          M := StrToIntDef(Copy(D, 1, P1 - 1), 1);
          Dd := StrToIntDef(Copy(D, P1 + 1, P2 - P1 - 1), 1);
          Y := StrToIntDef(Copy(D, P2 + 1, 4), 1900);
          if Y < 100 then Inc(Y, 1900);
          Result := Result + '''' + Format('%.4d-%.2d-%.2d', [Y, M, Dd]) + '''';
          I := J + 1;
          Continue;
        end;
      end;
      Result := Result + S[I];
      Inc(I);
    end
    else if S[I] = '[' then
    begin
      { naziv u uglatim zagradama ostaje kakav jest (npr. [Membership No]) }
      J := PosEx(']', S, I + 1);
      if J = 0 then J := Length(S);
      Result := Result + Copy(S, I, J - I + 1);
      I := J + 1;
    end
    else if S[I] in ['A'..'Z', 'a'..'z', '_'] then
    begin
      J := I;
      while (J <= Length(S)) and (S[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(J);
      W := Copy(S, I, J - I);
      Lw := LowerCase(W);
      { naziv stupca ili tablice pored tocke ostaje }
      if (I > 1) and (S[I - 1] = '.') and SqlKeyword(Lw) then Result := Result + '"' + W + '"'
      else if ((I > 1) and (S[I - 1] = '.')) or ((J <= Length(S)) and (S[J] = '.')) then Result := Result + W
      else if (Lw = 'yes') or (Lw = 'true') then Result := Result + '1'
      else if (Lw = 'no') or (Lw = 'false') then Result := Result + '0'
      else if Lw = 'descending' then Result := Result + 'DESC'
      else if Lw = 'ascending' then Result := Result + 'ASC'
      else begin Result := Result + W; if Lw = 'like' then AfterLike := True; end;
      I := J;
    end
    else begin Result := Result + S[I]; Inc(I); end;
  end;
end;

{ [Forms]![Obrazac]![Polje] i Forms!Obrazac!Polje (s zagradama ili bez) postaju upit za vrijednost pri otvaranju: [?Polje] }
function ReplaceFormRefs(const S: string): string;
var
  I, P: Integer;
  Low, Ctl: string;
  { cita naziv od pozicije APos: [naziv s razmacima] ili rijec; APos ide iza naziva }
  function ReadName(var APos: Integer): string;
  var
    E: Integer;
  begin
    Result := '';
    if APos > Length(S) then Exit;
    if S[APos] = '[' then
    begin
      E := PosEx(']', S, APos + 1);
      if E = 0 then Exit;
      Result := Copy(S, APos + 1, E - APos - 1);
      APos := E + 1;
    end
    else
    begin
      E := APos;
      while (E <= Length(S)) and (S[E] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(E);
      Result := Copy(S, APos, E - APos);
      APos := E;
    end;
  end;
var
  Ok: Boolean;
  Nm, Tail: string;
  Q, R: Integer;
begin
  Result := '';
  Low := LowerCase(S);
  I := 1;
  while I <= Length(S) do
  begin
    Ok := False;
    if (Low[I] in ['f', '[']) and ((I = 1) or not (Low[I - 1] in ['a'..'z', '0'..'9', '_', '.', '!'])) then
    begin
      P := I;
      if Low[P] = '[' then Inc(P);
      if Copy(Low, P, 5) = 'forms' then
      begin
        Inc(P, 5);
        if (I < P - 5) then
        begin
          if (P <= Length(S)) and (S[P] = ']') then Inc(P) else P := 0;
        end;
        if (P > 0) and (P <= Length(S)) and (S[P] = '!') then
        begin
          Inc(P);
          Nm := ReadName(P);
          Ctl := '';
          Q := P;
          { Forms!Obrazac!Polje, a za podforme i Forms!Obrazac.Form!Podforma.Form!Polje: vrijedi zadnje polje }
          while (Nm <> '') and (Q <= Length(S)) do
          begin
            if S[Q] = '!' then
            begin
              Inc(Q);
              Ctl := ReadName(Q);
            end
            else if S[Q] = '.' then
            begin
              R := Q + 1;
              Tail := ReadName(R);
              if SameText(Tail, 'form') and (R <= Length(S)) and (S[R] = '!') then Q := R else Break;
            end
            else Break;
          end;
          if Nm <> '' then
          begin
            if Ctl <> '' then
            begin
              Result := Result + '[?' + Ctl + ']';
              I := Q;
              Ok := True;
            end;
          end;
        end;
      end;
    end;
    if not Ok then begin Result := Result + S[I]; Inc(I); end;
  end;
  Tail := '';
end;

{ SELECT s Access oblikom (DISTINCTROW, TOP n, CCur, IIf, Nz, Year...) u SQL koji razumije baza }
function AccessSqlToSqlite(const ASql: string): string;
var
  S, TopN: string;
  P, I, Guard: Integer;
begin
  S := ReplaceFormRefs(Trim(ASql));
  while (S <> '') and (S[Length(S)] = ';') do Delete(S, Length(S), 1);
  S := StringReplace(S, 'DISTINCTROW', 'DISTINCT', [rfReplaceAll, rfIgnoreCase]);
  S := NormalizeAccessText(S);
  { TOP n -> LIMIT n }
  P := Pos(' top ', LowerCase(S));
  if P > 0 then
  begin
    I := P + 5;
    TopN := '';
    while (I <= Length(S)) and (S[I] in ['0'..'9']) do begin TopN := TopN + S[I]; Inc(I); end;
    if TopN <> '' then S := Copy(S, 1, P) + Trim(Copy(S, I, MaxInt)) + ' LIMIT ' + TopN;
  end;
  Guard := 0;
  while RewriteOnce(S) and (Guard < 200) do Inc(Guard);
  Result := S;
end;

{ ---------------- upiti iz MSysQueries ---------------- }

type
  TQPart = class
  public
    Attr: Integer;
    Name1, Name2, Expr, Flag: string;
  end;

function CsvCell(ARow: TStringList; AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= ARow.Count) or (ARow[AIndex] = NullMark) then Result := '' else Result := ARow[AIndex];
end;

{ naziv upita -> TObjectList dijelova (TQPart) iz tablice MSysQueries; AOrder dobiva nazive redom }
procedure LoadMsysQueries(const AFile: string; AByName: TStringList);
var
  Out1: string;
  Rows: TObjectList;
  Ids: TStringList;
  I, K: Integer;
  Row: TStringList;
  P: TQPart;
  Lst: TObjectList;
  Nm: string;
begin
  Rows := TObjectList.Create(True);
  Ids := TStringList.Create;
  try
    { id -> naziv upita (vrsta 5) }
    if not RunMdb('mdb-export', [AFile, 'MSysObjects'], Out1) then Exit;
    ParseCsv(Out1, Rows);
    for I := 1 to Rows.Count - 1 do
    begin
      Row := TStringList(Rows[I]);
      if CsvCell(Row, 3) = '5' then Ids.Values[CsvCell(Row, 0)] := CsvCell(Row, 2);
    end;
    Rows.Clear;
    if not RunMdb('mdb-export', [AFile, 'MSysQueries'], Out1) then Exit;
    ParseCsv(Out1, Rows);
    for I := 1 to Rows.Count - 1 do
    begin
      Row := TStringList(Rows[I]);
      Nm := Ids.Values[CsvCell(Row, 0)];
      if Nm = '' then Continue;
      K := AByName.IndexOf(Nm);
      if K < 0 then K := AByName.AddObject(Nm, TObjectList.Create(True));
      Lst := TObjectList(AByName.Objects[K]);
      P := TQPart.Create;
      P.Attr := StrToIntDef(CsvCell(Row, 1), -1);
      P.Name1 := CsvCell(Row, 3);
      P.Name2 := CsvCell(Row, 4);
      P.Expr := CsvCell(Row, 5);
      P.Flag := CsvCell(Row, 6);
      Lst.Add(P);
    end;
  finally
    Ids.Free;
    Rows.Free;
  end;
end;

function AggParts(const AExpr: string; out AFunc, AInner: string): Boolean;
var
  P, Q: Integer;
  E: string;
begin
  Result := False;
  E := Trim(AExpr);
  P := Pos('(', E);
  if (P < 2) or (E[Length(E)] <> ')') then Exit;
  AFunc := LowerCase(Trim(Copy(E, 1, P - 1)));
  if (AFunc <> 'sum') and (AFunc <> 'count') and (AFunc <> 'avg') and (AFunc <> 'min') and (AFunc <> 'max') and
     (AFunc <> 'first') and (AFunc <> 'last') then Exit;
  Q := Length(E);
  AInner := Trim(Copy(E, P + 1, Q - P - 1));
  Result := True;
end;

{ sastavlja SELECT iz dijelova upita; '' ako je upit akcijski ili se ne moze sastaviti.
  ADb sluzi samo za popis vrijednosti stupca u unakrsnom upitu bez zadanog popisa. }
function ReconstructQuery(ADb: TAppDb; AParts: TObjectList; out AWhyNot: string): string;
var
  I, J, Kind, TopN: Integer;
  HasType: Boolean;
  P: TQPart;
  Cols, Tables, Orders, Groups: TStringList;
  Incl: TStringList;
  Where, Having, Dist, TopS, From, Sel, Ord, Grp, E, Alias: string;
  Used: array of Boolean;
  Qy: TZQuery;
  PivotExpr, PivotRaw, ValueExpr, AggF, AggIn, Cell, V: string;
  Vals, Rowc: TStringList;
  Temp: TStringList;
  Opt: Integer;
  Sub: string;
  JoinKw, NewT: string;
  LeftIncl, RightIncl: Boolean;

  { parametri koje upit sam trazi ([Beginning Date]) postaju upit za vrijednost pri otvaranju: [?Beginning Date] }
  function ApplyParams(const ASql: string): string;
  var
    K: Integer;
    Q2: TQPart;
  begin
    Result := ASql;
    for K := 0 to AParts.Count - 1 do
    begin
      Q2 := TQPart(AParts[K]);
      if (Q2.Attr = 2) and (Q2.Name1 <> '') and (Pos('!', Q2.Name1) = 0) then
        Result := StringReplace(Result, '[' + Q2.Name1 + ']', '[?' + Q2.Name1 + ']', [rfReplaceAll, rfIgnoreCase]);
    end;
  end;

  function TableRef(const AName, AAlias: string): string;
  begin
    Result := '[' + AName + ']';
    if (AAlias <> '') then Result := Result + ' AS [' + AAlias + ']';
  end;

  function InTables(const AName: string): Integer;
  var
    K: Integer;
  begin
    for K := 0 to Tables.Count - 1 do
      if SameText(Tables.Names[K], AName) or ((Tables.ValueFromIndex[K] <> '') and SameText(Tables.ValueFromIndex[K], AName)) then Exit(K);
    Result := -1;
  end;

  procedure BuildFrom;
  var
    K, T1, T2, Done: Integer;
    J2: TQPart;
    JList: TObjectList;
    Pass: Integer;
    Applied: array of Boolean;
  begin
    if Tables.Count = 0 then begin From := ''; Exit; end;
    Incl.Clear;
    From := TableRef(Tables.Names[0], Tables.ValueFromIndex[0]);
    if Tables.Names[0] = '' then From := '';
    Incl.Add(IntToStr(0));
    JList := TObjectList.Create(False);
    try
      for K := 0 to AParts.Count - 1 do
        if TQPart(AParts[K]).Attr = 7 then JList.Add(AParts[K]);
      SetLength(Applied, JList.Count);
      Done := 0;
      for Pass := 1 to JList.Count + Tables.Count do
        for K := 0 to JList.Count - 1 do
        begin
          if Applied[K] then Continue;
          J2 := TQPart(JList[K]);
          T1 := InTables(J2.Name1);
          T2 := InTables(J2.Name2);
          if (T1 < 0) or (T2 < 0) then begin Applied[K] := True; Continue; end;
          LeftIncl := Incl.IndexOf(IntToStr(T1)) >= 0;
          RightIncl := Incl.IndexOf(IntToStr(T2)) >= 0;
          if LeftIncl and RightIncl then
          begin
            { veza izmedju vec ukljucenih tablica: uvjet ide u WHERE }
            if Where <> '' then Where := '(' + Where + ') AND (' + J2.Expr + ')' else Where := J2.Expr;
            Applied[K] := True;
            Continue;
          end;
          if not (LeftIncl or RightIncl) then Continue;
          if LeftIncl then begin NewT := TableRef(Tables.Names[T2], Tables.ValueFromIndex[T2]); Incl.Add(IntToStr(T2)); end
          else begin NewT := TableRef(Tables.Names[T1], Tables.ValueFromIndex[T1]); Incl.Add(IntToStr(T1)); end;
          JoinKw := 'JOIN';
          if J2.Flag = '2' then begin if LeftIncl then JoinKw := 'LEFT JOIN' else JoinKw := 'RIGHT JOIN'; end
          else if J2.Flag = '3' then begin if LeftIncl then JoinKw := 'RIGHT JOIN' else JoinKw := 'LEFT JOIN'; end;
          From := From + ' ' + JoinKw + ' ' + NewT + ' ON ' + J2.Expr;
          Applied[K] := True;
          Inc(Done);
        end;
      { tablice bez veze: zarezom (unakrsni umnozak) }
      for K := 1 to Tables.Count - 1 do
        if Incl.IndexOf(IntToStr(K)) < 0 then
        begin
          From := From + ', ' + TableRef(Tables.Names[K], Tables.ValueFromIndex[K]);
          Incl.Add(IntToStr(K));
        end;
    finally
      JList.Free;
    end;
  end;

begin
  Result := '';
  AWhyNot := '';
  Kind := 0;
  HasType := False;
  TopN := 0;
  Opt := 0;
  Cols := TStringList.Create; Tables := TStringList.Create; Orders := TStringList.Create; Groups := TStringList.Create;
  Incl := TStringList.Create; Vals := TStringList.Create; Rowc := TStringList.Create; Temp := TStringList.Create;
  try
    Where := ''; Having := ''; TopS := '';
    for I := 0 to AParts.Count - 1 do
    begin
      P := TQPart(AParts[I]);
      case P.Attr of
        1: begin Kind := StrToIntDef(P.Flag, 0); HasType := True; end;
        3: begin Opt := StrToIntDef(P.Flag, 0); TopN := StrToIntDef(P.Name1, 0); end;
        5: if P.Expr <> '' then Tables.Add('=' + P.Expr) else Tables.Add(P.Name1 + '=' + P.Name2);
        8: Where := P.Expr;
        10: Having := P.Expr;
        11:
          begin
            E := P.Expr;
            if P.Name1 = 'D' then E := E + ' DESC';
            Orders.Add(E);
          end;
      end;
    end;
    { neki upiti nemaju redak s vrstom upita: to je obican SELECT }
    if (Kind = 0) and (Tables.Count > 0) and not HasType then Kind := 1;
    if (Kind <> 1) and (Kind <> 6) and (Kind <> 9) then
    begin
      case Kind of
        2: AWhyNot := 'upit za izradu tablice';
        3: AWhyNot := 'upit za dodavanje zapisa';
        4: AWhyNot := 'upit za izmjenu zapisa';
        5: AWhyNot := 'upit za brisanje zapisa';
        7: AWhyNot := 'upit definicije podataka';
        8: AWhyNot := 'upit prema drugom poslužitelju';
      else AWhyNot := 'nepoznata vrsta upita';
      end;
      Exit;
    end;
    { unija: svaka tablica je zaseban SELECT }
    if Kind = 9 then
    begin
      Sel := '';
      for I := 0 to Tables.Count - 1 do
      begin
        Sub := Trim(Copy(Tables[I], 2, MaxInt));
        if Sel <> '' then Sel := Sel + LineEnding + 'UNION' + LineEnding;
        Sel := Sel + Sub;
      end;
      if Orders.Count > 0 then Sel := Sel + LineEnding + 'ORDER BY ' + Orders.CommaText;
      Exit(ApplyParams(Sel));
    end;
    BuildFrom;
    if From = '' then begin AWhyNot := 'upit bez tablica'; Exit; end;
    { stupci }
    PivotRaw := ''; ValueExpr := '';
    for I := 0 to AParts.Count - 1 do
    begin
      P := TQPart(AParts[I]);
      if P.Attr <> 6 then Continue;
      E := P.Expr;
      Alias := P.Name1;
      if Kind = 6 then
      begin
        if P.Flag = '1' then PivotRaw := E
        else if P.Flag = '0' then ValueExpr := E
        else begin
          if Alias <> '' then Rowc.Add(E + ' AS [' + Alias + ']') else Rowc.Add(E);
          Groups.Add(E);
        end;
        Continue;
      end;
      if (Alias <> '') then Cols.Add(E + ' AS [' + Alias + ']') else Cols.Add(E);
    end;
    for I := 0 to AParts.Count - 1 do
    begin
      P := TQPart(AParts[I]);
      if (P.Attr = 9) and (Kind <> 6) then Groups.Add(P.Expr);
    end;
    if Kind = 6 then
    begin
      { unakrsni: stupac za svaku vrijednost zaglavlja; popis je zadan s In (...) ili se cita iz podataka }
      if (PivotRaw = '') or (ValueExpr = '') or (Rowc.Count = 0) then begin AWhyNot := 'unakrsni upit bez zaglavlja ili vrijednosti'; Exit; end;
      PivotExpr := PivotRaw;
      J := Pos(' in (', LowerCase(PivotRaw));
      Vals.Clear;
      if J > 0 then
      begin
        PivotExpr := Trim(Copy(PivotRaw, 1, J - 1));
        Sub := Trim(Copy(PivotRaw, J + 5, MaxInt));
        if (Sub <> '') and (Sub[Length(Sub)] = ')') then Delete(Sub, Length(Sub), 1);
        SplitArgs(Sub, Temp);
        for I := 0 to Temp.Count - 1 do
        begin
          V := Temp[I];
          if (Length(V) >= 2) and (V[1] = '"') and (V[Length(V)] = '"') then V := Copy(V, 2, Length(V) - 2);
          Vals.Add(V);
        end;
      end
      else
      begin
        Sub := 'SELECT DISTINCT ' + PivotExpr + ' FROM ' + From;
        if Where <> '' then Sub := Sub + ' WHERE ' + Where;
        try
          Qy := ADb.NewQuery(AccessSqlToSqlite(Sub) + ' ORDER BY 1');
          try
            Qy.Open;
            while (not Qy.EOF) and (Vals.Count < 60) do begin Vals.Add(Qy.Fields[0].AsString); Qy.Next; end;
          finally
            Qy.Free;
          end;
        except
          AWhyNot := 'unakrsni upit: zaglavlja stupaca se ne mogu pročitati iz podataka';
          Exit;
        end;
      end;
      if Vals.Count = 0 then begin AWhyNot := 'unakrsni upit nema zaglavlja stupaca'; Exit; end;
      AggF := 'sum'; AggIn := ValueExpr;
      if not AggParts(ValueExpr, AggF, AggIn) then begin AggF := 'sum'; AggIn := ValueExpr; end;
      if AggIn = '*' then AggIn := '1';
      if AggF = 'first' then AggF := 'min' else if AggF = 'last' then AggF := 'max';
      Cols.Assign(Rowc);
      for I := 0 to Vals.Count - 1 do
      begin
        Cell := UpperCase(AggF) + '(CASE WHEN ' + PivotExpr + ' = ''' + StringReplace(Vals[I], '''', '''''', [rfReplaceAll]) + ''' THEN ' + AggIn + ' END)';
        Cols.Add(Cell + ' AS [' + Vals[I] + ']');
      end;
      if Orders.Count = 0 then for I := 0 to Groups.Count - 1 do Orders.Add(Groups[I]);
    end;
    if Cols.Count = 0 then Cols.Add('*');
    Dist := '';
    if (Kind = 1) and ((Opt and 8) <> 0) and (TopN = 0) and (Groups.Count = 0) then Dist := 'DISTINCT ';
    if TopN > 0 then TopS := 'TOP ' + IntToStr(TopN) + ' ';
    Sel := 'SELECT ' + Dist + TopS;
    for I := 0 to Cols.Count - 1 do
    begin
      if I > 0 then Sel := Sel + ', ';
      Sel := Sel + Cols[I];
    end;
    Sel := Sel + ' FROM ' + From;
    if Where <> '' then Sel := Sel + ' WHERE ' + Where;
    if Groups.Count > 0 then
    begin
      Grp := '';
      for I := 0 to Groups.Count - 1 do begin if Grp <> '' then Grp := Grp + ', '; Grp := Grp + Groups[I]; end;
      Sel := Sel + ' GROUP BY ' + Grp;
    end;
    if Having <> '' then Sel := Sel + ' HAVING ' + Having;
    if Orders.Count > 0 then
    begin
      Ord := '';
      for I := 0 to Orders.Count - 1 do begin if Ord <> '' then Ord := Ord + ', '; Ord := Ord + Orders[I]; end;
      Sel := Sel + ' ORDER BY ' + Ord;
    end;
    Result := ApplyParams(Sel);
  finally
    Temp.Free; Rowc.Free; Vals.Free; Incl.Free; Groups.Free; Orders.Free; Tables.Free; Cols.Free;
  end;
end;

{ ---------------- uvoz ---------------- }

function SafeIdx(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then Result := Result + S[I] else Result := Result + '_';
end;

{ ---------------- VBA kod iz Accessa ---------------- }

{ MS-OVBA: sazeti izvorni kod (CompressedContainer) -> tekst; '' ako se ne moze dekodirati }
function DecompressVba(const AData: string; AStart: Integer): string;
var
  Pos0, ChunkEnd, ChunkStart, Hdr, Size, Flag, Bit, Tok, DecLen, BitCount, LenMask, Off, Ln, K, Bad: Integer;
  Out1: string;
  Sig, Comp: Integer;
begin
  Result := '';
  if (AStart > Length(AData)) or (Ord(AData[AStart]) <> 1) then Exit;
  Pos0 := AStart + 1;
  Out1 := '';
  while Pos0 + 1 <= Length(AData) do
  begin
    Hdr := Ord(AData[Pos0]) or (Ord(AData[Pos0 + 1]) shl 8);
    Size := (Hdr and $0FFF) + 3;
    Sig := (Hdr shr 12) and 7;
    Comp := (Hdr shr 15) and 1;
    if Sig <> 3 then Break;
    ChunkEnd := Pos0 + Size;
    if ChunkEnd > Length(AData) + 1 then ChunkEnd := Length(AData) + 1;
    Inc(Pos0, 2);
    ChunkStart := Length(Out1);
    if Comp = 0 then
    begin
      Out1 := Out1 + Copy(AData, Pos0, 4096);
      Inc(Pos0, 4096);
      Bad := 0;
      for K := ChunkStart + 1 to Length(Out1) do
        if Ord(Out1[K]) in [0..8, 11, 12, 14..31, 127] then Inc(Bad);
      if Bad > 2 then
      begin
        SetLength(Out1, ChunkStart);
        Break;
      end;
      Continue;
    end;
    while Pos0 < ChunkEnd do
    begin
      Flag := Ord(AData[Pos0]);
      Inc(Pos0);
      for Bit := 0 to 7 do
      begin
        if Pos0 >= ChunkEnd then Break;
        if ((Flag shr Bit) and 1) = 0 then
        begin
          Out1 := Out1 + AData[Pos0];
          Inc(Pos0);
        end
        else
        begin
          if Pos0 + 1 > Length(AData) then Exit('');
          Tok := Ord(AData[Pos0]) or (Ord(AData[Pos0 + 1]) shl 8);
          Inc(Pos0, 2);
          DecLen := Length(Out1) - ChunkStart;
          BitCount := 4;
          while (1 shl BitCount) < DecLen do Inc(BitCount);
          LenMask := $FFFF shr BitCount;
          Off := (Tok shr (16 - BitCount)) + 1;
          Ln := (Tok and LenMask) + 3;
          if Off > Length(Out1) then Exit('');
          for K := 1 to Ln do Out1 := Out1 + Out1[Length(Out1) - Off + 1];
        end;
      end;
    end;
    { iza izvornog koda u istom bloku mogu biti drugi podaci: komad s kontrolnim znakovima nije tekst }
    Bad := 0;
    for K := ChunkStart + 1 to Length(Out1) do
      if Ord(Out1[K]) in [0..8, 11, 12, 14..31, 127] then Inc(Bad);
    if Bad > 2 then
    begin
      SetLength(Out1, ChunkStart);
      Break;
    end;
  end;
  Result := Out1;
end;

function HexToRaw(const AHex: string): string;
begin
  Result := HexToBytes(AHex, 1, Length(AHex) div 2);
end;

{ izvlaci izvorni kod modula i kodova iza formi/izvjesca u mapu; vraca broj datoteka }
function ExtractVba(const AFile, ADir: string; AReport: TStrings): Integer;
var
  Out1, Raw, Src, Nm, FirstLine: string;
  Rows: TObjectList;
  I, J: Integer;
  Row: TStringList;
  Txt: TStringList;
begin
  Result := 0;
  Rows := TObjectList.Create(True);
  try
    if not RunMdb('mdb-export', ['-b', 'hex', AFile, 'MSysModules2'], Out1) then Exit;
    ParseCsv(Out1, Rows);
    if Rows.Count < 2 then Exit;
    { stupci: Flags,Form,Module,Name,... }
    for I := 1 to Rows.Count - 1 do
    begin
      Row := TStringList(Rows[I]);
      Nm := CsvCell(Row, 3);
      Raw := HexToRaw(CsvCell(Row, 2));
      if (Nm = '') or (Raw = '') then Continue;
      Src := '';
      for J := 1 to Length(Raw) - 3 do
        if Ord(Raw[J]) = 1 then
        begin
          if ((Ord(Raw[J + 1]) or (Ord(Raw[J + 2]) shl 8)) shr 12) and 7 <> 3 then Continue;
          Src := DecompressVba(Raw, J);
          if (Pos('Attribute VB_Name', Src) > 0) or (Pos('Option ', Src) > 0) or (Pos('Sub ', Src) > 0) or (Pos('Function ', Src) > 0) then Break;
          Src := '';
        end;
      if Src = '' then Continue;
      if not DirectoryExists(ADir) then ForceDirectories(ADir);
      Txt := TStringList.Create;
      try
        Txt.Text := CP1252ToUTF8(StringReplace(StringReplace(Src, #13#10, #10, [rfReplaceAll]), #13, #10, [rfReplaceAll]));
        FirstLine := '';
        for J := 0 to Txt.Count - 1 do
          if (Copy(Trim(Txt[J]), 1, 1) = '''') then begin FirstLine := Trim(Copy(Trim(Txt[J]), 2, 100)); Break; end;
        Txt.SaveToFile(IncludeTrailingPathDelimiter(ADir) + SafeIdx(Nm) + '.bas');
        AReport.Add('VBA "' + Nm + '" izvučen u ' + SafeIdx(Nm) + '.bas (' + IntToStr(Txt.Count) + ' redaka)' +
          IfThen(FirstLine <> '', ': ' + FirstLine, ''));
        Inc(Result);
      finally
        Txt.Free;
      end;
    end;
  finally
    Rows.Free;
  end;
end;

function SpecName(const S: string): string;
begin
  if (Pos(' ', S) > 0) or (Pos('"', S) > 0) then Result := '"' + S + '"' else Result := S;
end;

function ImportMdb(ADb: TAppDb; const AFile: string; ALog, AReport: TStrings; out ASpecText: string): Boolean;
var
  Names: TStringList;
  Tables: TObjectList;
  Rels: TObjectList;
  Rows: TObjectList;
  Out1, Ver: string;
  I, J, K, R, N, Batch: Integer;
  T, T2: TMdbTable;
  C: TMdbColumn;
  Rel: TMdbRelation;
  Fl: TFieldDefs2;
  M: TaFieldMeta;
  Row: TStringList;
  V, Sql, Vals, Cols: string;
  Fv: Double;
  HasTime: Boolean;
  Done, Progress: Boolean;
  Spec: TStringList;
  Ix: TMdbIndex;
  Rl: TStringList;
  Cnt: Integer;
  RelRows: TObjectList;
  QNames: TStringList;
  Q, Msg: string;
  Qr: TZQuery;
  Pending: TStringList;
  Pass, Tries, PosC: Integer;
  Again: Boolean;
  ColNm: string;
  BinMode, PicKey, PicBytes, Why: string;
  QParts: TStringList;
  PicCount: Integer;
begin
  Result := False;
  ASpecText := '';
  if not MdbToolsAvailable then
  begin
    ALog.Add('GREŠKA: nisu pronađeni mdbtools programi (mdb-tables, mdb-schema, mdb-export). Instaliraj paket mdbtools ili postavi MDBTOOLS_DIR.');
    Exit;
  end;
  if not RunMdb('mdb-ver', [AFile], Ver) then
  begin
    ALog.Add('GREŠKA: datoteka se ne može pročitati kao Access baza: ' + Trim(Ver));
    Exit;
  end;
  ALog.Add('Access datoteka: ' + Trim(Ver));
  Names := TStringList.Create;
  Tables := TObjectList.Create(True);
  Rels := TObjectList.Create(True);
  try
    if not RunMdb('mdb-tables', ['-1', AFile], Out1) then raise Exception.Create(Tr('the list of tables was not read'));
    Names.Text := Out1;
    for I := Names.Count - 1 downto 0 do
      if (Trim(Names[I]) = '') or (Copy(Names[I], 1, 4) = 'MSys') or (Copy(Names[I], 1, 1) = '~') then Names.Delete(I);
    for I := 0 to Names.Count - 1 do
    begin
      T := TMdbTable.Create;
      T.Name := Trim(Names[I]);
      Tables.Add(T);
      ReadSchema(AFile, T);
      if T.Columns.Count = 0 then begin ALog.Add('preskočena tablica ' + T.Name + ' (shema nije pročitana)'); Continue; end;
      { podaci }
      Rows := TObjectList.Create(True);
      try
        BinMode := 'strip';
        for J := 0 to T.Columns.Count - 1 do if TMdbColumn(T.Columns[J]).IsOle then BinMode := 'hex';
        if RunMdb('mdb-export', ['-T', '%Y-%m-%d %H:%M:%S', '-D', '%Y-%m-%d', '-b', BinMode, AFile, T.Name], Out1) then
          ParseCsv(Out1, Rows);
        { prvi redak je zaglavlje: poredak stupaca }
        if Rows.Count > 0 then
        begin
          Row := TStringList(Rows[0]);
          for J := 0 to T.Columns.Count - 1 do
          begin
            C := TMdbColumn(T.Columns[J]);
            C.Idx := Row.IndexOf(C.Name);
          end;
          Rows.OwnsObjects := False;
          Rows.Delete(0);
          Row.Free;
          Rows.OwnsObjects := True;
        end;
        T.RowCount := Rows.Count;
        { datum ili datum i vrijeme: ako je sve u ponoc, stupac je datum }
        for J := 0 to T.Columns.Count - 1 do
        begin
          C := TMdbColumn(T.Columns[J]);
          if (C.Logical = ltDateTime) and (C.Idx >= 0) then
          begin
            HasTime := False;
            for R := 0 to Rows.Count - 1 do
            begin
              V := TStringList(Rows[R])[C.Idx];
              if (V <> NullMark) and (Length(V) > 10) and (Copy(V, 12, 8) <> '00:00:00') then begin HasTime := True; Break; end;
            end;
            if not HasTime then C.Logical := ltDate;
          end;
        end;
        { privremeno cuva podatke u tablici (u memoriji) do izrade tablica }
        T.Rows.Free;
        T.Rows := Rows;
        Rows := nil;
      finally
        Rows.Free;
      end;
    end;
    { veze }
    if RunMdb('mdb-export', ['-d', ',', AFile, 'MSysRelationships'], Out1) then
    begin
      RelRows := TObjectList.Create(True);
      try
        ParseCsv(Out1, RelRows);
        for I := 1 to RelRows.Count - 1 do
        begin
          Row := TStringList(RelRows[I]);
          if Row.Count < 8 then Continue;
          Rel := TMdbRelation.Create;
          Rel.Name := Row[0];
          Rel.Flags := StrToIntDef(Row[1], 0);
          Rel.ColCount := StrToIntDef(Row[2], 1);
          Rel.Child := Row[4]; Rel.ChildCol := Row[5]; Rel.Parent := Row[6]; Rel.ParentCol := Row[7];
          Rels.Add(Rel);
        end;
      finally
        RelRows.Free;
      end;
    end;
    { popis za odabir u Accessu (lookup) bez zasebne veze postaje veza }
    for I := 0 to Tables.Count - 1 do
    begin
      T := TMdbTable(Tables[I]);
      for J := 0 to T.Columns.Count - 1 do
      begin
        C := TMdbColumn(T.Columns[J]);
        if C.LookupTable = '' then Continue;
        T2 := nil;
        for K := 0 to Tables.Count - 1 do
          if SameText(TMdbTable(Tables[K]).Name, C.LookupTable) then T2 := TMdbTable(Tables[K]);
        if (T2 = nil) or (T2 = T) then Continue;
        Rl := TStringList.Create;
        try
          if (C.LookupCol <> '') and (T2.ColByName(C.LookupCol) <> nil) then Rl.Add(T2.ColByName(C.LookupCol).Name)
          else if T2.PkCols.Count = 1 then Rl.Add(T2.PkCols[0]);
          if Rl.Count = 1 then
          begin
            Cnt := 0;
            for K := 0 to Rels.Count - 1 do
              if SameText(TMdbRelation(Rels[K]).Child, T.Name) and SameText(TMdbRelation(Rels[K]).ChildCol, C.Name) then Inc(Cnt);
            if Cnt = 0 then
            begin
              Rel := TMdbRelation.Create;
              Rel.Name := 'lookup ' + T.Name + '.' + C.Name;
              Rel.Child := T.Name; Rel.ChildCol := C.Name; Rel.Parent := T2.Name; Rel.ParentCol := Rl[0];
              Rel.Flags := 0; Rel.ColCount := 1;
              Rels.Add(Rel);
              ALog.Add('popis za odabir ' + T.Name + '.' + C.Name + ' postao je veza na ' + T2.Name);
            end;
          end;
        finally
          Rl.Free;
        end;
      end;
    end;
    { izrada tablica prema vezama: roditelji prvi; Access ne mora imati urednu referencijalnu cjelovitost,
      pa se provjera veza ukljucuje tek nakon uvoza i javlja kao izvjestaj }
    try ADb.Conn.ExecuteDirect('PRAGMA foreign_keys = OFF'); except end;
    ADb.Conn.StartTransaction;
    try
      repeat
        Progress := False;
        for I := 0 to Tables.Count - 1 do
        begin
          T := TMdbTable(Tables[I]);
          if T.Created or (T.Columns.Count = 0) then Continue;
          Done := True;
          for K := 0 to Rels.Count - 1 do
          begin
            Rel := TMdbRelation(Rels[K]);
            if SameText(Rel.Child, T.Name) and not SameText(Rel.Parent, T.Name) then
              for J := 0 to Tables.Count - 1 do
                if SameText(TMdbTable(Tables[J]).Name, Rel.Parent) and not TMdbTable(Tables[J]).Created then Done := False;
          end;
          if not Done then Continue;
          { polja }
          SetLength(Fl, 0);
          N := 0;
          for J := 0 to T.Columns.Count - 1 do
          begin
            C := TMdbColumn(T.Columns[J]);
            if C.Skip then
            begin
              AReport.Add('polje ' + T.Name + '.' + C.Name + ' (' + C.AccType + ') nije uvezeno: slike i OLE objekti se ne prenose');
              Continue;
            end;
            SetLength(Fl, N + 1);
            Fl[N].Name := C.Name;
            M := TaFieldMeta.Create;
            M.LType := C.Logical;
            M.Decimals := C.Decimals;
            M.Format := DefaultFormat(C.Logical, C.Decimals);
            M.DefaultExpr := MapDefault(C.DefaultRaw, C.Logical);
            M.Description := C.Comment;
            M.Caption := C.Caption;
            M.Validation := MdbValidationExpr(C.Name, C.ValRule);
            M.ValidationMsg := C.ValText;
            Fl[N].Meta := M;
            Fl[N].SqlType := PhysicalType(C.Logical);
            Fl[N].NotNull := C.NotNull and (T.PkCols.IndexOf(C.Name) < 0) and not C.Serial;
            Fl[N].PrimaryKey := (T.PkCols.IndexOf(C.Name) >= 0);
            { AutoNumber je ključ tablice samo kad je jedini ključ }
            if C.Serial and (T.PkCols.Count <> 1) then begin M.LType := ltInteger; Fl[N].PrimaryKey := Fl[N].PrimaryKey; end;
            Inc(N);
          end;
          { veze koje polje ima: samo jednostupcane, na kljuc roditelja }
          for K := 0 to Rels.Count - 1 do
          begin
            Rel := TMdbRelation(Rels[K]);
            if not SameText(Rel.Child, T.Name) then Continue;
            if Rel.ColCount <> 1 then begin AReport.Add('veza ' + Rel.Name + ' ima više stupaca i nije uvezena'); Continue; end;
            for J := 0 to High(Fl) do
              if SameText(Fl[J].Name, Rel.ChildCol) then
              begin
                Fl[J].RefTable := Rel.Parent;
                Fl[J].RefField := Rel.ParentCol;
                if (Rel.Flags and 4096) <> 0 then Fl[J].OnDelete := 'CASCADE';
              end;
          end;
          ADb.CreateTable(T.Name, Fl);
          for J := 0 to High(Fl) do Fl[J].Meta.Free;
          T.Created := True;
          Progress := True;
          ALog.Add('izrađena tablica ' + T.Name);
        end;
      until not Progress;
      { podaci }
      for I := 0 to Tables.Count - 1 do
      begin
        T := TMdbTable(Tables[I]);
        if not T.Created then Continue;
        Cols := '';
        for J := 0 to T.Columns.Count - 1 do
          if not TMdbColumn(T.Columns[J]).Skip then
          begin
            if Cols <> '' then Cols := Cols + ', ';
            Cols := Cols + ADb.QuoteId(TMdbColumn(T.Columns[J]).Name);
          end;
        Sql := '';
        Batch := 0;
        PicCount := 0;
        for R := 0 to T.Rows.Count - 1 do
        begin
          Row := TStringList(T.Rows[R]);
          Vals := '';
          for J := 0 to T.Columns.Count - 1 do
          begin
            C := TMdbColumn(T.Columns[J]);
            if C.Skip then Continue;
            if Vals <> '' then Vals := Vals + ', ';
            if (C.Idx < 0) or (C.Idx >= Row.Count) then V := NullMark else V := Row[C.Idx];
            if V = NullMark then Vals := Vals + 'NULL'
            else if C.Logical in [ltInteger, ltAutoNumber, ltYesNo, ltDecimal, ltCurrency] then
            begin
              if InvariantFloat(V, Fv) then Vals := Vals + Trim(V) else Vals := Vals + 'NULL';
            end
            else if C.IsOle then
            begin
              PicBytes := OleImageBytes(V);
              if PicBytes = '' then Vals := Vals + 'NULL'
              else
              begin
                PicKey := StoreBytes(ADb, PicBytes, 'slike/' + SafeIdx(T.Name), SafeIdx(T.Name + '_' + C.Name + '_' + IntToStr(R + 1)));
                Vals := Vals + ADb.QuoteLit(PicKey);
                Inc(PicCount);
              end;
            end
            else if C.Logical = ltDate then Vals := Vals + ADb.QuoteLit(Copy(V, 1, 10))
            else Vals := Vals + ADb.QuoteLit(V);
          end;
          if Sql <> '' then Sql := Sql + ', ';
          Sql := Sql + '(' + Vals + ')';
          Inc(Batch);
          if (Batch >= 200) or (R = T.Rows.Count - 1) then
          begin
            ADb.Conn.ExecuteDirect('INSERT INTO ' + ADb.QuoteId(T.Name) + ' (' + Cols + ') VALUES ' + Sql);
            Sql := '';
            Batch := 0;
          end;
        end;
        ALog.Add('uvezeno ' + IntToStr(T.Rows.Count) + ' redaka u ' + T.Name);
        if PicCount > 0 then begin ALog.Add('spremljeno slika: ' + IntToStr(PicCount) + ' (' + T.Name + ')'); PicCount := 0; end;
        T.Rows.Clear;
        { indeksi }
        for K := 0 to T.Indexes.Count - 1 do
        begin
          Ix := TMdbIndex(T.Indexes[K]);
          Rl := TStringList.Create;
          try
            Rl.CommaText := Ix.Cols;
            Cols := '';
            for J := 0 to Rl.Count - 1 do
            begin
              if Cols <> '' then Cols := Cols + ', ';
              Cols := Cols + ADb.QuoteId(Rl[J]);
            end;
            try
              ADb.Conn.ExecuteDirect('CREATE ' + 'INDEX ' + ADb.QuoteId('ix_' + SafeIdx(T.Name) + '_' + IntToStr(K + 1)) + ' ON ' + ADb.QuoteId(T.Name) + ' (' + Cols + ')');
            except
              on E: Exception do AReport.Add('indeks na ' + T.Name + ' (' + Ix.Cols + ') nije izrađen: ' + E.Message);
            end;
          finally
            Rl.Free;
          end;
        end;
      end;
      ADb.Conn.Commit;
      try ADb.Conn.ExecuteDirect('PRAGMA foreign_keys = ON'); except end;
      { zapisi cija veza vodi u prazno }
      try
        Qr := ADb.NewQuery('PRAGMA foreign_key_check');
        try
          Qr.Open;
          Cnt := 0;
          while not Qr.EOF do begin Inc(Cnt); Qr.Next; end;
          if Cnt > 0 then AReport.Add('veze: ' + IntToStr(Cnt) + ' zapisa upućuje na zapis kojeg nema (Access to dopušta); popravi ih prije dodavanja novih');
        finally
          Qr.Free;
        end;
      except
      end;
    except
      ADb.Conn.Rollback;
      try ADb.Conn.ExecuteDirect('PRAGMA foreign_keys = ON'); except end;
      raise;
    end;
    { spremljeni upiti: neki ovise o drugima, pa se pokusava u nekoliko prolaza }
    QNames := TStringList.Create;
    Pending := TStringList.Create;
    QParts := TStringList.Create;
    LoadMsysQueries(AFile, QParts);
    try
      if RunMdb('mdb-queries', ['-1', AFile], Out1) then QNames.Text := Out1;
      { upiti ciji naziv pocinje s ~ su interni (iz formi i izvjesca) i ne uvoze se }
      for I := 0 to QNames.Count - 1 do if (Trim(QNames[I]) <> '') and (Copy(Trim(QNames[I]), 1, 1) <> '~') then Pending.Add(Trim(QNames[I]));
      for Pass := 1 to 4 do
      begin
        I := 0;
        while I < Pending.Count do
        begin
          Q := Pending[I];
          Msg := '';
          Out1 := '';
          Why := '';
          K := QParts.IndexOf(Q);
          if K >= 0 then
          try
            Out1 := ReconstructQuery(ADb, TObjectList(QParts.Objects[K]), Why);
          except
            on E: Exception do begin Out1 := ''; Why := E.Message; end;
          end;
          if (Out1 = '') and (Why <> '') and (Pos('upit za', Why) = 1) then
          begin
            AReport.Add('upit "' + Q + '" nije uvezen: ' + Why + ' (akcijski upiti se ne prenose)');
            Pending.Delete(I);
            Continue;
          end;
          if (Out1 = '') and not (RunMdb('mdb-queries', ['-1', AFile, Q], Out1) and (Trim(Out1) <> '') and (Pos('SELECT  FROM', Out1) = 0)) then Out1 := '';
          if Out1 <> '' then
          begin
            Out1 := AccessSqlToSqlite(Out1);
            Inc(ADb.QuietParams);
            try
              Tries := 0;
              repeat
                Inc(Tries);
                Msg := '';
                Again := False;
                try
                  ADb.SaveObject('_sys_queries', Q, Out1);
                  Qr := ADb.NewQuery(ADb.SourceSql(Q));
                  try
                    Qr.Open;
                  finally
                    Qr.Free;
                  end;
                except
                  on E: Exception do Msg := E.Message;
                end;
                { [Tekst za pretragu] koji nije stupac je parametar koji upit sam trazi: upit za vrijednost pri otvaranju }
                if Msg <> '' then
                begin
                  PosC := Pos('no such column: ', Msg);
                  if PosC > 0 then
                  begin
                    ColNm := Copy(Msg, PosC + 16, MaxInt);
                    ColNm := StringReplace(StringReplace(ColNm, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
                    if Pos(' Code:', ColNm) > 0 then ColNm := Copy(ColNm, 1, Pos(' Code:', ColNm) - 1);
                    ColNm := Trim(ColNm);
                    if (ColNm <> '') and (Pos('.', ColNm) = 0) and (Pos('[' + ColNm + ']', Out1) > 0) then
                    begin
                      Out1 := StringReplace(Out1, '[' + ColNm + ']', '[?' + ColNm + ']', [rfReplaceAll]);
                      Again := True;
                    end;
                  end;
                end;
              until (not Again) or (Tries > 8);
            finally
              Dec(ADb.QuietParams);
            end;
            if Msg = '' then
            begin
              { drugi upiti se mogu pozivati na ovaj kao na tablicu: u SQLite-u to je pogled }
              try ADb.Conn.ExecuteDirect('CREATE VIEW ' + ADb.QuoteId(Q) + ' AS ' + Out1); except end;
              ALog.Add('uvezen upit ' + Q);
              Pending.Delete(I);
              Continue;
            end;
            ADb.DeleteObject('_sys_queries', Q);
            Pending.Objects[I] := TObject(Pointer(PtrUInt(Pass)));
            Pending[I] := Q;
            if Pass = 4 then
              AReport.Add('upit "' + Q + '" ne radi bez prepravka (' + Copy(StringReplace(Msg, LineEnding, ' ', [rfReplaceAll]), 1, 140) + '); SQL: ' + StringReplace(Out1, LineEnding, ' ', [rfReplaceAll]));
          end
          else if Pass = 4 then AReport.Add('upit "' + Q + '" nije se mogao pročitati (složen, križni ili s parametrima)');
          Inc(I);
        end;
      end;
    finally
      for K := 0 to QParts.Count - 1 do QParts.Objects[K].Free;
      QParts.Free;
      Pending.Free;
      QNames.Free;
    end;
    { forme, izvjesca, makroi i moduli: samo popis }
    if RunMdb('mdb-export', [AFile, 'MSysObjects'], Out1) then
    begin
      RelRows := TObjectList.Create(True);
      try
        ParseCsv(Out1, RelRows);
        for I := 1 to RelRows.Count - 1 do
        begin
          Row := TStringList(RelRows[I]);
          if Row.Count < 4 then Continue;
          K := StrToIntDef(Row[3], 0);
          if K = -32768 then AReport.Add('forma "' + Row[2] + '" nije uvezena: nove forme slažu se opisom aplikacije')
          else if K = -32764 then AReport.Add('izvješće "' + Row[2] + '" nije uvezeno: nova izvješća slažu se opisom aplikacije')
          else if K = -32766 then AReport.Add('makro "' + Row[2] + '" nije uvezen')
          else if K = -32761 then AReport.Add('modul (VBA) "' + Row[2] + '" nije uvezen');
        end;
      finally
        RelRows.Free;
      end;
    end;
    { izvorni kod VBA (moduli i kod iza formi i izvjesca) sprema se u mapu uz bazu, za proucavanje i prepisivanje }
    try
      K := ExtractVba(AFile, ChangeFileExt(ADb.Conn.Database, '') + '_vba', AReport);
      if K > 0 then ALog.Add('izvučen VBA kod: ' + IntToStr(K) + ' datoteka u ' + ChangeFileExt(ADb.Conn.Database, '') + '_vba');
    except
      on E: Exception do AReport.Add('VBA kod nije izvučen: ' + E.Message);
    end;
    { nacrt opisa aplikacije nad uvezenim tablicama }
    Spec := TStringList.Create;
    try
      Spec.Add('// Nacrt iz Access datoteke ' + ExtractFileName(AFile) + ': tablice, veze i polja kakvi su uvezeni; forme, popisi i izbornik slažu se sami.');
      Spec.Add('aplikacija "' + ChangeFileExt(ExtractFileName(AFile), '') + '"');
      Spec.Add('  naslov: ' + ChangeFileExt(ExtractFileName(AFile), ''));
      Spec.Add('');
      for I := 0 to Tables.Count - 1 do
      begin
        T := TMdbTable(Tables[I]);
        if not T.Created then Continue;
        Spec.Add('tablica ' + SpecName(T.Name));
        for J := 0 to T.Columns.Count - 1 do
        begin
          C := TMdbColumn(T.Columns[J]);
          if C.Skip then Continue;
          Q := '  ' + SpecName(C.Name) + ' ' + LogicalNames[C.Logical];
          if C.Logical in [ltDecimal, ltCurrency] then Q := Q + '/' + IntToStr(C.Decimals);
          for K := 0 to Rels.Count - 1 do
          begin
            Rel := TMdbRelation(Rels[K]);
            if SameText(Rel.Child, T.Name) and SameText(Rel.ChildCol, C.Name) and (Rel.ColCount = 1) then
              Q := Q + ' ' + SpecName('veza=' + Rel.Parent + '.' + Rel.ParentCol);
          end;
          Spec.Add(Q);
        end;
        Spec.Add('');
      end;
      ASpecText := Spec.Text;
    finally
      Spec.Free;
    end;
    Result := True;
  finally
    Rels.Free;
    Tables.Free;
    Names.Free;
  end;
end;

end.
