unit ta_doctypes;
{ Vrste dokumenata za objedinjene forme: jedna forma (npr. "Dokument") radi za vise vrsta (otpremnica, revers, racun...).
  Tablica "dokumenti" (po jedan redak za svaku vrstu):
    vrsta     kratka oznaka vrste (otp, rv, rac)   ... parametar kojim izbornik otvara formu: openform:Dokument#vrsta=otp
    naziv     naziv za prikaz (Otpremnica)          ... naslov kartice
    sifradok  prefiks broja (otp)
    rednidok  zadnji dodijeljeni redni broj
    godina    godina zadnjeg broja (svake godine broj ide ispocetka)
    format    oblik broja, npr. {sifra}-{godina}-{broj:4}  =>  otp-2026-0001
    srodne    vrste koje ne smiju biti otvorene dok je ova otvorena (oznake odvojene zarezom)
  Broj se predlaze iz zadnje upisane vrijednosti, a tek pri spremanju novog dokumenta stvarno se dodjeljuje i upisuje u tablicu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZDataset, ta_meta;

type
  TaDocType = record
    Code, Name, Prefix, Format, Related: string;
    Last, Year: Integer;
  end;

const
  DocTypesTable = 'dokumenti';
  DefaultDocFormat = '{sifra}-{godina}-{broj:4}';

{ izradi tablicu vrsta ako je nema }
procedure EnsureDocTypes(ADb: TAppDb);
function DocTypeExists(ADb: TAppDb; const ACode: string): Boolean;
function DocTypeLoad(ADb: TAppDb; const ACode: string; out AType: TaDocType): Boolean;
procedure DocTypeSave(ADb: TAppDb; const AType: TaDocType);
procedure DocTypeDelete(ADb: TAppDb; const ACode: string);
function DocTypeCodes(ADb: TAppDb): TStringList;
{ oblikuje broj prema uzorku }
function DocFormatNumber(const AFormat, APrefix: string; AYear, ASerial: Integer): string;
function DocCurrentYear: Integer;
{ sljedeci broj samo za prikaz (nista se ne upisuje) }
function DocPreviewNumber(ADb: TAppDb; const ACode: string): string;
{ stvarno dodjeljuje sljedeci broj i upisuje ga u tablicu vrsta; vraca formatirani broj }
function DocCommitNumber(ADb: TAppDb; const ACode: string): string;
{ blokiraju li se dvije vrste (jedna navodi drugu u srodnim) }
function DocTypesBlock(ADb: TAppDb; const ACodeA, ACodeB: string): Boolean;
{ "vrsta=otp;druga=x" -> popis ime=vrijednost }
procedure ParseOpenArgs(const AArgs: string; AList: TStrings);
{ "Dokument#vrsta=otp" -> naziv forme i argumenti }
procedure SplitFormAction(const AArg: string; out AForm, AArgs: string);

implementation

function HasTable(ADb: TAppDb): Boolean;
var
  L: TStringList;
begin
  L := ADb.UserTables;
  try
    Result := L.IndexOf(DocTypesTable) >= 0;
  finally
    L.Free;
  end;
end;

procedure EnsureDocTypes(ADb: TAppDb);
begin
  if HasTable(ADb) then Exit;
  ADb.Conn.ExecuteDirect('CREATE TABLE ' + DocTypesTable + ' (vrsta VARCHAR(40) PRIMARY KEY, naziv VARCHAR(100), ' +
    'sifradok VARCHAR(20), rednidok INTEGER DEFAULT 0, godina INTEGER DEFAULT 0, format VARCHAR(80), srodne VARCHAR(255))');
end;

function DocTypeLoad(ADb: TAppDb; const ACode: string; out AType: TaDocType): Boolean;
var
  Q: TZQuery;
begin
  Result := False;
  AType.Code := ''; AType.Name := ''; AType.Prefix := ''; AType.Format := DefaultDocFormat; AType.Related := '';
  AType.Last := 0; AType.Year := 0;
  if not HasTable(ADb) then Exit;
  Q := ADb.NewQuery('SELECT vrsta, naziv, sifradok, rednidok, godina, format, srodne FROM ' + DocTypesTable +
    ' WHERE vrsta = ' + ADb.QuoteLit(ACode));
  try
    Q.Open;
    if Q.IsEmpty then Exit;
    AType.Code := Q.Fields[0].AsString;
    AType.Name := Q.Fields[1].AsString;
    AType.Prefix := Q.Fields[2].AsString;
    AType.Last := Q.Fields[3].AsInteger;
    AType.Year := Q.Fields[4].AsInteger;
    AType.Format := Q.Fields[5].AsString;
    AType.Related := Q.Fields[6].AsString;
    if AType.Format = '' then AType.Format := DefaultDocFormat;
    if AType.Prefix = '' then AType.Prefix := AType.Code;
    if AType.Name = '' then AType.Name := AType.Code;
    Result := True;
  finally
    Q.Free;
  end;
end;

function DocTypeExists(ADb: TAppDb; const ACode: string): Boolean;
var
  T: TaDocType;
begin
  Result := DocTypeLoad(ADb, ACode, T);
end;

procedure DocTypeSave(ADb: TAppDb; const AType: TaDocType);
var
  Old: TaDocType;
begin
  EnsureDocTypes(ADb);
  if DocTypeLoad(ADb, AType.Code, Old) then
    ADb.Conn.ExecuteDirect('UPDATE ' + DocTypesTable + ' SET naziv = ' + ADb.QuoteLit(AType.Name) +
      ', sifradok = ' + ADb.QuoteLit(AType.Prefix) + ', rednidok = ' + IntToStr(AType.Last) +
      ', godina = ' + IntToStr(AType.Year) + ', format = ' + ADb.QuoteLit(AType.Format) +
      ', srodne = ' + ADb.QuoteLit(AType.Related) + ' WHERE vrsta = ' + ADb.QuoteLit(AType.Code))
  else
    ADb.Conn.ExecuteDirect('INSERT INTO ' + DocTypesTable + ' (vrsta, naziv, sifradok, rednidok, godina, format, srodne) VALUES (' +
      ADb.QuoteLit(AType.Code) + ', ' + ADb.QuoteLit(AType.Name) + ', ' + ADb.QuoteLit(AType.Prefix) + ', ' +
      IntToStr(AType.Last) + ', ' + IntToStr(AType.Year) + ', ' + ADb.QuoteLit(AType.Format) + ', ' + ADb.QuoteLit(AType.Related) + ')');
end;

procedure DocTypeDelete(ADb: TAppDb; const ACode: string);
begin
  if not HasTable(ADb) then Exit;
  ADb.Conn.ExecuteDirect('DELETE FROM ' + DocTypesTable + ' WHERE vrsta = ' + ADb.QuoteLit(ACode));
end;

function DocTypeCodes(ADb: TAppDb): TStringList;
var
  Q: TZQuery;
begin
  Result := TStringList.Create;
  if not HasTable(ADb) then Exit;
  Q := ADb.NewQuery('SELECT vrsta FROM ' + DocTypesTable + ' ORDER BY vrsta');
  try
    Q.Open;
    while not Q.EOF do begin Result.Add(Q.Fields[0].AsString); Q.Next; end;
  finally
    Q.Free;
  end;
end;

function DocFormatNumber(const AFormat, APrefix: string; AYear, ASerial: Integer): string;
var
  I, J, W: Integer;
  Tok, Spec, F: string;
begin
  F := AFormat;
  if F = '' then F := DefaultDocFormat;
  Result := '';
  I := 1;
  while I <= Length(F) do
  begin
    if F[I] = '{' then
    begin
      J := I + 1;
      while (J <= Length(F)) and (F[J] <> '}') do Inc(J);
      Tok := LowerCase(Copy(F, I + 1, J - I - 1));
      Spec := '';
      if Pos(':', Tok) > 0 then begin Spec := Copy(Tok, Pos(':', Tok) + 1, MaxInt); Tok := Copy(Tok, 1, Pos(':', Tok) - 1); end;
      if Tok = 'sifra' then Result := Result + APrefix
      else if Tok = 'godina' then
      begin
        if Spec = '2' then Result := Result + Format('%.2d', [AYear mod 100]) else Result := Result + IntToStr(AYear);
      end
      else if Tok = 'broj' then
      begin
        W := StrToIntDef(Spec, 0);
        Result := Result + Format('%.*d', [W, ASerial]);
      end
      else Result := Result + Copy(F, I, J - I + 1);
      I := J + 1;
    end
    else begin Result := Result + F[I]; Inc(I); end;
  end;
end;

function DocCurrentYear: Integer;
var
  Y, M, D: Word;
begin
  DecodeDate(Date, Y, M, D);
  Result := Y;
end;

function DocPreviewNumber(ADb: TAppDb; const ACode: string): string;
var
  T: TaDocType;
  N: Integer;
begin
  Result := '';
  if not DocTypeLoad(ADb, ACode, T) then Exit;
  if T.Year = DocCurrentYear then N := T.Last + 1 else N := 1;
  Result := DocFormatNumber(T.Format, T.Prefix, DocCurrentYear, N);
end;

function DocCommitNumber(ADb: TAppDb; const ACode: string): string;
var
  T: TaDocType;
  Y: Integer;
  Own: Boolean;
begin
  Result := '';
  if not DocTypeLoad(ADb, ACode, T) then Exit;
  Y := DocCurrentYear;
  { povecanje i citanje u jednoj transakciji, a UPDATE je relativan (nije "upisi izracunani broj"), pa dva korisnika ne dobiju isti broj }
  Own := not ADb.Conn.InTransaction;
  if Own then ADb.Conn.StartTransaction;
  try
    ADb.Conn.ExecuteDirect('UPDATE ' + DocTypesTable + ' SET rednidok = CASE WHEN godina = ' + IntToStr(Y) +
      ' THEN rednidok + 1 ELSE 1 END, godina = ' + IntToStr(Y) + ' WHERE vrsta = ' + ADb.QuoteLit(ACode));
    DocTypeLoad(ADb, ACode, T);
    if Own then ADb.Conn.Commit;
  except
    if Own then ADb.Conn.Rollback;
    raise;
  end;
  Result := DocFormatNumber(T.Format, T.Prefix, Y, T.Last);
end;

function InList(const AList, AItem: string): Boolean;
var
  L: TStringList;
  I: Integer;
begin
  Result := False;
  if (Trim(AList) = '') or (AItem = '') then Exit;
  L := TStringList.Create;
  try
    L.CommaText := StringReplace(AList, ';', ',', [rfReplaceAll]);
    for I := 0 to L.Count - 1 do
      if SameText(Trim(L[I]), AItem) then Exit(True);
  finally
    L.Free;
  end;
end;

function DocTypesBlock(ADb: TAppDb; const ACodeA, ACodeB: string): Boolean;
var
  A, B: TaDocType;
begin
  Result := False;
  if SameText(ACodeA, ACodeB) then Exit;
  if DocTypeLoad(ADb, ACodeA, A) and InList(A.Related, ACodeB) then Exit(True);
  if DocTypeLoad(ADb, ACodeB, B) and InList(B.Related, ACodeA) then Exit(True);
end;

procedure ParseOpenArgs(const AArgs: string; AList: TStrings);
var
  L: TStringList;
  I, P: Integer;
begin
  AList.Clear;
  L := TStringList.Create;
  try
    L.Delimiter := ';';
    L.StrictDelimiter := True;
    L.DelimitedText := AArgs;
    for I := 0 to L.Count - 1 do
    begin
      P := Pos('=', L[I]);
      if P > 0 then AList.Values[Trim(Copy(L[I], 1, P - 1))] := Trim(Copy(L[I], P + 1, MaxInt));
    end;
  finally
    L.Free;
  end;
end;

procedure SplitFormAction(const AArg: string; out AForm, AArgs: string);
var
  P: Integer;
begin
  P := Pos('#', AArg);
  if P > 0 then begin AForm := Trim(Copy(AArg, 1, P - 1)); AArgs := Trim(Copy(AArg, P + 1, MaxInt)); end
  else begin AForm := Trim(AArg); AArgs := ''; end;
end;

end.
