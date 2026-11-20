unit ta_autoenter;
{ Automatski unosi polja (plan: PLAN-rjecnik-okidaci.md, korak 2). Opisuju se u rjecniku podataka (TaFieldMeta.Extra):
    autoenter=serial|created|modified|user|expr|const
    autoon=new|always          kad se upisuje (zadano: new; modified i user su always)
    serial=<predlozak>         npr. {seq}/{pp}/{nu}  ili  {nu}{seq:6}
    serialyear=1               brojac ide ispocetka svake godine
    serialpp=, serialnu=       nadjacavaju oznake iz fiskalnih postavki
    autoexpr=<izraz>           za autoenter=expr
    autoconst=<tekst>          za autoenter=const
    autocopy=<tablica.stupac>, autocopykey=<lokalno polje s kljucem>, autocopysrckey=<kljuc izvora, zadano id>
                               za autoenter=copy: kad se promijeni polje s kljucem, uzima se stupac iz povezane tablice
  Predlozak broja: {seq} redni broj, {seq:N} nadopunjen nulama do N znamenki, {pp} oznaka poslovnog prostora, {nu} oznaka
  naplatnog uredaja, {year} godina (4), {yy} godina (2), {mm} mjesec (2).
  Hrvatski racun (Zakon o fiskalizaciji u prometu gotovinom): tri dijela, redni broj / poslovni prostor / naplatni uredaj,
  neprekinut slijed. Zadani predlozak je zato {seq}/{pp}/{nu}; numericki oblik s uredajem je {nu}{seq:6} (8000001).
  Brojac je u tablici _sys_serials. Dodjeljuje se u istoj transakciji kao spremanje zapisa, pa neuspjelo spremanje ne
  trosi broj (slijed ostaje bez rupa). Prikaz sljedeceg broja prije spremanja (preview) ne mijenja nista. }
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZDataset, ta_types, ta_meta, ta_bindengine;

type
  TaAutoKind = (akNone, akSerial, akCreated, akModified, akUser, akExpr, akConst, akCopy);

const
  SerialsTable = '_sys_serials';
  DefaultInvoiceTemplate = '{seq}/{pp}/{nu}';
  NumericInvoiceTemplate = '{nu}{seq:6}';

function AutoKindOf(M: TaFieldMeta): TaAutoKind;
{ polje se upisuje i pri izmjeni postojeceg zapisa (inace samo pri unosu novog) }
function AutoAlways(M: TaFieldMeta): Boolean;
function AutoKindName(AKind: TaAutoKind): string;

{ oblikuje broj prema predlosku }
function SerialFormat(const ATemplate: string; ASeq: Integer; const APP, ANU: string; ADate: TDateTime): string;
{ oznake poslovnog prostora i uredaja za polje: svojstva polja, pa fiskalne postavke, pa '1' }
procedure SerialMarks(ADb: TAppDb; M: TaFieldMeta; out APP, ANU: string; out AScopeOnDevice: Boolean);
{ kljuc brojaca: pp (ili pp|nu) i godina ako je serialyear=1 }
function SerialScope(M: TaFieldMeta; const APP, ANU: string; AOnDevice: Boolean; ADate: TDateTime): string;
{ sljedeci broj samo za prikaz }
function SerialPreview(ADb: TAppDb; M: TaFieldMeta; ADate: TDateTime): string;
{ dodjeljuje sljedeci broj (u transakciji pozivatelja, ili u vlastitoj) }
function SerialCommit(ADb: TAppDb; M: TaFieldMeta; ADate: TDateTime): string;
{ vrsta copy: pravilo AutoFill (polje s kljucem > tablica.kljuc : cilj = izvorni stupac); False ako nije potpuno zadano }
function CopyRuleFor(M: TaFieldMeta; out ARule: TaAutoFillDef): Boolean;
{ zadnji dodijeljeni redni broj za kljuc (0 ako ga nema) }
function SerialLast(ADb: TAppDb; const ATable, AField, AScope: string): Integer;

implementation

uses
  ta_fiscalhook;

function CopyRuleFor(M: TaFieldMeta; out ARule: TaAutoFillDef): Boolean;
var
  Src, Tbl, Col: string;
  P: Integer;
begin
  Result := False;
  if (M = nil) or (LowerCase(M.GetX('autoenter')) <> 'copy') then Exit;
  Src := Trim(M.GetX('autocopy'));
  P := Pos('.', Src);
  if (P < 2) or (Trim(M.GetX('autocopykey')) = '') then Exit;
  Tbl := Trim(Copy(Src, 1, P - 1));
  Col := Trim(Copy(Src, P + 1, MaxInt));
  if (Tbl = '') or (Col = '') then Exit;
  ARule.Field := Trim(M.GetX('autocopykey'));
  ARule.Table := Tbl;
  ARule.KeyCol := Trim(M.GetX('autocopysrckey'));
  if ARule.KeyCol = '' then ARule.KeyCol := 'id';
  SetLength(ARule.Targets, 1);
  SetLength(ARule.Sources, 1);
  ARule.Targets[0] := M.FieldName;
  ARule.Sources[0] := Col;
  Result := True;
end;

function AutoKindOf(M: TaFieldMeta): TaAutoKind;
var
  S: string;
begin
  Result := akNone;
  if M = nil then Exit;
  S := LowerCase(M.GetX('autoenter'));
  if S = 'serial' then Result := akSerial
  else if S = 'created' then Result := akCreated
  else if S = 'modified' then Result := akModified
  else if S = 'user' then Result := akUser
  else if S = 'expr' then Result := akExpr
  else if S = 'const' then Result := akConst
  else if S = 'copy' then Result := akCopy;
end;

function AutoKindName(AKind: TaAutoKind): string;
const
  N: array[TaAutoKind] of string = ('', 'serial', 'created', 'modified', 'user', 'expr', 'const', 'copy');
begin
  Result := N[AKind];
end;

function AutoAlways(M: TaFieldMeta): Boolean;
var
  S: string;
begin
  S := LowerCase(M.GetX('autoon'));
  if S = 'always' then Exit(True);
  if S = 'new' then Exit(False);
  Result := AutoKindOf(M) = akModified;
end;

function SerialFormat(const ATemplate: string; ASeq: Integer; const APP, ANU: string; ADate: TDateTime): string;
var
  I, J, N: Integer;
  Tok, Arg: string;
  Y, Mo, Dd: Word;
begin
  DecodeDate(ADate, Y, Mo, Dd);
  Result := '';
  I := 1;
  while I <= Length(ATemplate) do
  begin
    if ATemplate[I] = '{' then
    begin
      J := Pos('}', ATemplate, I);
      if J = 0 then begin Result := Result + Copy(ATemplate, I, MaxInt); Break; end;
      Tok := Copy(ATemplate, I + 1, J - I - 1);
      Arg := '';
      if Pos(':', Tok) > 0 then
      begin
        Arg := Copy(Tok, Pos(':', Tok) + 1, MaxInt);
        Tok := Copy(Tok, 1, Pos(':', Tok) - 1);
      end;
      Tok := LowerCase(Tok);
      if Tok = 'seq' then
      begin
        N := StrToIntDef(Arg, 0);
        Result := Result + Format('%.*d', [N, ASeq]);
      end
      else if Tok = 'pp' then Result := Result + APP
      else if Tok = 'nu' then Result := Result + ANU
      else if Tok = 'year' then Result := Result + Format('%.4d', [Y])
      else if Tok = 'yy' then Result := Result + Format('%.2d', [Y mod 100])
      else if Tok = 'mm' then Result := Result + Format('%.2d', [Mo])
      else Result := Result + '{' + Copy(ATemplate, I + 1, J - I - 1) + '}';
      I := J + 1;
    end
    else
    begin
      Result := Result + ATemplate[I];
      Inc(I);
    end;
  end;
end;

procedure SerialMarks(ADb: TAppDb; M: TaFieldMeta; out APP, ANU: string; out AScopeOnDevice: Boolean);
var
  P2, N2: string;
  Dev: Boolean;
begin
  APP := M.GetX('serialpp');
  ANU := M.GetX('serialnu');
  AScopeOnDevice := True;
  P2 := ''; N2 := '';
  Dev := True;
  if Assigned(FiscalMarksHook) then
    try
      if FiscalMarksHook(ADb, P2, N2, Dev) then AScopeOnDevice := Dev;
    except
      { bez postavki modula }
    end;
  if APP = '' then APP := P2;
  if ANU = '' then ANU := N2;
  if APP = '' then APP := '1';
  if ANU = '' then ANU := '1';
end;

function SerialScope(M: TaFieldMeta; const APP, ANU: string; AOnDevice: Boolean; ADate: TDateTime): string;
var
  Y, Mo, Dd: Word;
begin
  Result := APP;
  if AOnDevice then Result := Result + '|' + ANU;
  if M.GetX('serialyear') = '1' then
  begin
    DecodeDate(ADate, Y, Mo, Dd);
    Result := Result + '|' + IntToStr(Y);
  end;
end;

procedure EnsureSerials(ADb: TAppDb);
begin
  ADb.Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS ' + SerialsTable +
    ' (tbl VARCHAR(190), fld VARCHAR(190), scope VARCHAR(190), n INTEGER, PRIMARY KEY (tbl, fld, scope))');
end;

function SerialLast(ADb: TAppDb; const ATable, AField, AScope: string): Integer;
var
  Q: TZQuery;
begin
  Result := 0;
  EnsureSerials(ADb);
  Q := ADb.NewQuery('SELECT n FROM ' + SerialsTable + ' WHERE tbl = ' + ADb.QuoteLit(ATable) + ' AND fld = ' +
    ADb.QuoteLit(AField) + ' AND scope = ' + ADb.QuoteLit(AScope));
  try
    Q.Open;
    if not Q.EOF then Result := Q.Fields[0].AsInteger;
  finally
    Q.Free;
  end;
end;

function Template(M: TaFieldMeta): string;
begin
  Result := M.GetX('serial');
  if Result = '' then Result := DefaultInvoiceTemplate;
end;

function SerialPreview(ADb: TAppDb; M: TaFieldMeta; ADate: TDateTime): string;
var
  PP, NU, Sc: string;
  OnDev: Boolean;
begin
  SerialMarks(ADb, M, PP, NU, OnDev);
  Sc := SerialScope(M, PP, NU, OnDev, ADate);
  Result := SerialFormat(Template(M), SerialLast(ADb, M.TableName, M.FieldName, Sc) + 1, PP, NU, ADate);
end;

function SerialCommit(ADb: TAppDb; M: TaFieldMeta; ADate: TDateTime): string;
var
  PP, NU, Sc: string;
  OnDev, Own: Boolean;
  N: Integer;
begin
  SerialMarks(ADb, M, PP, NU, OnDev);
  Sc := SerialScope(M, PP, NU, OnDev, ADate);
  EnsureSerials(ADb);
  Own := not ADb.Conn.InTransaction;
  if Own then ADb.Conn.StartTransaction;
  try
    { relativan UPDATE (n + 1), pa dva korisnika ne dobiju isti broj }
    ADb.Conn.ExecuteDirect('UPDATE ' + SerialsTable + ' SET n = n + 1 WHERE tbl = ' + ADb.QuoteLit(M.TableName) +
      ' AND fld = ' + ADb.QuoteLit(M.FieldName) + ' AND scope = ' + ADb.QuoteLit(Sc));
    if SerialLast(ADb, M.TableName, M.FieldName, Sc) = 0 then
      ADb.Conn.ExecuteDirect('INSERT INTO ' + SerialsTable + ' (tbl, fld, scope, n) VALUES (' + ADb.QuoteLit(M.TableName) +
        ', ' + ADb.QuoteLit(M.FieldName) + ', ' + ADb.QuoteLit(Sc) + ', 1)');
    N := SerialLast(ADb, M.TableName, M.FieldName, Sc);
    if Own then ADb.Conn.Commit;
  except
    if Own then ADb.Conn.Rollback;
    raise;
  end;
  Result := SerialFormat(Template(M), N, PP, NU, ADate);
end;

end.
