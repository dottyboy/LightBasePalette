unit ta_meta;
{ Application database: one SQLite file holds the user's tables plus the
  metadata (_sys_* tables) describing forms, reports, queries, macros. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZConnection, ZDataset, DB, FmtBCD, ZDbcSqLite, contnrs, ta_types, ta_params;

const
  SysTables: array[0..8] of string = (
    '_sys_forms', '_sys_reports', '_sys_queries', '_sys_macros', '_sys_modules', '_sys_letters', '_sys_programs',
    '_sys_propclasses', '_sys_ctlgroups');

type
  TFieldDef = record
    Name: string;
    SqlType: string;
    PrimaryKey: Boolean;
    NotNull: Boolean;
    Meta: TaFieldMeta;   { optional logical type info; owned by the caller }
    RefTable, RefField, OnDelete: string;   { optional foreign key }
  end;
  TFieldDefs2 = array of TFieldDef;

  { A foreign key as SQLite reports it. }
  TaFkDef = record
    FromCol, RefTable, RefCol, OnDelete, OnUpdate: string;
  end;
  TaFkDefs = array of TaFkDef;

  { A relation between two tables: the child holds the key. }
  TaRelation = record
    Child, ChildCol, Parent, ParentCol, OnDelete, OnUpdate: string;
  end;
  TaRelations = array of TaRelation;

  TAppDb = class;
  { Poziva se prije/poslije promjene strukture tablice (revizijski trag treba
    maknuti i ponovno napraviti okidace). }
  TSchemaHook = procedure(ADb: TAppDb; const ATable: string);

  { TAppDb }

  TDbKind = (dkSqlite, dkPostgres, dkMaria);

  TAppDb = class
  private
    FConn: TZConnection;
    FKind: TDbKind;
    function PgType(const ASqliteType: string): string;
    function MariaType(const ASqliteType: string; AIsKey: Boolean): string;
    function MariaTableInfoSql(const ATable: string): string;
    function MariaFkSql(const ATable: string): string;
    function PgTableInfoSql(const ATable: string): string;
    function PgFkSql(const ATable: string): string;
    procedure SetFksSqlite(const ATable: string; const AFks: TaFkDefs);
    procedure CreateSysTables;
    function ColumnExists(const ATable, AColumn: string): Boolean;
  public
    { parametri upita ([?Naziv] u SQL-u): odgovori vrijede dok se ne pozove ClearParams }
    ParamValues, ParamLast: TStringList;
    QuietParams: Integer;          { > 0: bez pitanja, nepoznati parametri su NULL }
    constructor Create;
    destructor Destroy; override;
    procedure Open(const AFile: string);
    procedure OpenPostgres(const AHost: string; APort: Integer; const ADb, AUser, APassword: string);
    procedure OpenMaria(const AHost: string; APort: Integer; const ADb, AUser, APassword: string);
    function NowSql: string;
    function RowIdSql(const ATable: string): string;
    function UpsertSql(const ATable, AKeyCols, AAllCols, AValues: string): string;
    procedure Close;
    function Connected: Boolean;
    function UserTables: TStringList;
    function TableInfo(const ATable: string): TZQuery;
    function NewQuery(const ASql: string): TZQuery;
    procedure SetFloatFormats(ADataSet: TDataSet);
    procedure CreateTable(const AName: string; const AFields: TFieldDefs2);
    procedure DropTable(const AName: string);
    function QuoteId(const S: string): string;
    function QuoteLit(const S: string): string;
    procedure SaveObject(const ATable, AName, ADef: string);
    function LoadObject(const ATable, AName: string): string;
    function ListObjects(const ATable: string): TStringList;
    procedure DeleteObject(const ATable, AName: string);
    procedure ClearParams;
    function ExpandParams(const ASql: string): string;
    function SourceFromRaw(const AName: string): string;   { s oznakama parametara }
    function SourceFrom(const AName: string): string;
    function SourceSql(const AName: string): string;
    function ForeignKeys(const ATable: string): TStringList;
    procedure AddColumn(const ATable: string; const ADef: TFieldDef);
    procedure AddColumnInner(const ATable: string; const ADef: TFieldDef);
    procedure DropColumn(const ATable, AColumn: string);
    procedure DropColumnInner(const ATable, AColumn: string);
    procedure RenameColumn(const ATable, AOld, ANew: string);
    procedure RenameColumnInner(const ATable, AOld, ANew: string);
    function RefClause(const ADef: TFieldDef): string;
    function GetFks(const ATable: string): TaFkDefs;
    procedure SetFks(const ATable: string; const AFks: TaFkDefs);
    procedure SetFksInner(const ATable: string; const AFks: TaFkDefs);
    function AllRelations: TaRelations;
    function SaveSetting(const AKey, AValue: string): Boolean;
    function LoadSetting(const AKey: string): string;
    function PrimaryKeyOf(const ATable: string): string;
    procedure SaveFieldMeta(M: TaFieldMeta);
    function LoadFieldMetas(const ATable: string): TFPObjectList;
    function FindFieldMeta(const ATable, AField: string): TaFieldMeta;
    procedure DeleteFieldMeta(const ATable: string; const AField: string = '');
    property Conn: TZConnection read FConn;
    property Kind: TDbKind read FKind;
  end;

var
  BeforeSchemaChange: TSchemaHook = nil;
  AfterSchemaChange: TSchemaHook = nil;

implementation

uses
  ta_i18n;


{ TAppDb }

constructor TAppDb.Create;
begin
  FConn := TZConnection.Create(nil);
  FConn.Protocol := 'sqlite';
end;

function TAppDb.PgType(const ASqliteType: string): string;
var
  U: string;
begin
  U := UpperCase(Trim(ASqliteType));
  if (U = 'REAL') or (U = 'FLOAT') or (U = 'DOUBLE') then Result := 'double precision'
  else if U = 'BLOB' then Result := 'bytea'
  else Result := ASqliteType;
end;

function TAppDb.MariaType(const ASqliteType: string; AIsKey: Boolean): string;
var
  U: string;
begin
  U := UpperCase(Trim(ASqliteType));
  if U = 'REAL' then Result := 'DOUBLE'
  else if U = 'BLOB' then Result := 'LONGBLOB'
  else if U = 'TEXT' then
  begin
    if AIsKey then Result := 'VARCHAR(190)' else Result := 'LONGTEXT';
  end
  else Result := ASqliteType;
end;

{ Isti stupci kao SQLite-ov PRAGMA table_info: cid, name, type, notnull, dflt_value, pk. }
function TAppDb.MariaTableInfoSql(const ATable: string): string;
begin
  Result := 'SELECT c.ordinal_position - 1 AS cid, c.column_name AS name, c.data_type AS type, ' +
    'IF(c.is_nullable = ''NO'', 1, 0) AS "notnull", c.column_default AS dflt_value, ' +
    'COALESCE((SELECT k.ordinal_position FROM information_schema.key_column_usage k ' +
    'WHERE k.table_schema = c.table_schema AND k.table_name = c.table_name AND k.constraint_name = ''PRIMARY'' ' +
    'AND k.column_name = c.column_name), 0) AS pk ' +
    'FROM information_schema.columns c WHERE c.table_schema = DATABASE() ' +
    'AND lower(c.table_name) = lower(' + QuoteLit(ATable) + ') ORDER BY c.ordinal_position';
end;

{ Isti stupci kao PRAGMA foreign_key_list: from, table, to, on_delete, on_update. }
function TAppDb.MariaFkSql(const ATable: string): string;
begin
  Result := 'SELECT k.column_name AS "from", k.referenced_table_name AS "table", k.referenced_column_name AS "to", ' +
    'r.delete_rule AS on_delete, r.update_rule AS on_update ' +
    'FROM information_schema.key_column_usage k JOIN information_schema.referential_constraints r ' +
    'ON r.constraint_schema = k.constraint_schema AND r.constraint_name = k.constraint_name AND r.table_name = k.table_name ' +
    'WHERE k.table_schema = DATABASE() AND lower(k.table_name) = lower(' + QuoteLit(ATable) + ') ' +
    'AND k.referenced_table_name IS NOT NULL ORDER BY k.constraint_name, k.ordinal_position';
end;

{ Naziv kako se pise u metapodacima: u Postgresu malim slovima. }
function Nm(const S: string): string;
begin
  if SqlPostgres or SqlMaria then Result := LowerCase(S) else Result := S;
end;

{ Isti stupci kao SQLite-ov PRAGMA table_info: cid, name, type, notnull, dflt_value, pk. }
function TAppDb.PgTableInfoSql(const ATable: string): string;
begin
  Result := 'SELECT c.ordinal_position - 1 AS cid, c.column_name AS name, c.data_type AS type, ' +
    'CASE WHEN c.is_nullable = ''NO'' THEN 1 ELSE 0 END AS "notnull", c.column_default AS dflt_value, ' +
    'COALESCE((SELECT k.ordinal_position FROM information_schema.table_constraints t ' +
    'JOIN information_schema.key_column_usage k ON k.constraint_name = t.constraint_name ' +
    'AND k.table_schema = t.table_schema AND k.table_name = t.table_name ' +
    'WHERE t.constraint_type = ''PRIMARY KEY'' AND t.table_schema = c.table_schema ' +
    'AND t.table_name = c.table_name AND k.column_name = c.column_name), 0) AS pk ' +
    'FROM information_schema.columns c WHERE c.table_schema = current_schema() ' +
    'AND lower(c.table_name) = lower(' + QuoteLit(ATable) + ') ORDER BY c.ordinal_position';
end;

{ Isti stupci kao PRAGMA foreign_key_list: from, table, to, on_delete, on_update. }
function TAppDb.PgFkSql(const ATable: string): string;
const
  Act = 'CASE %s WHEN ''c'' THEN ''CASCADE'' WHEN ''n'' THEN ''SET NULL'' WHEN ''d'' THEN ''SET DEFAULT'' ' +
        'WHEN ''r'' THEN ''RESTRICT'' ELSE ''NO ACTION'' END';
begin
  Result := 'SELECT a.attname AS "from", cf.relname AS "table", af.attname AS "to", ' +
    Format(Act, ['con.confdeltype']) + ' AS on_delete, ' + Format(Act, ['con.confupdtype']) + ' AS on_update ' +
    'FROM pg_constraint con JOIN pg_class c ON c.oid = con.conrelid ' +
    'JOIN pg_namespace n ON n.oid = c.relnamespace JOIN pg_class cf ON cf.oid = con.confrelid ' +
    'CROSS JOIN LATERAL unnest(con.conkey, con.confkey) AS u(ck, fk) ' +
    'JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = u.ck ' +
    'JOIN pg_attribute af ON af.attrelid = con.confrelid AND af.attnum = u.fk ' +
    'WHERE con.contype = ''f'' AND lower(c.relname) = lower(' + QuoteLit(ATable) +
    ') AND n.nspname = current_schema() ORDER BY con.conname, u.ck';
end;

{ INSERT OR REPLACE (SQLite) / INSERT .. ON CONFLICT DO UPDATE (Postgres).
  ATable je vec citirano, AKeyCols i AAllCols su popisi stupaca odvojeni zarezom. }
function TAppDb.UpsertSql(const ATable, AKeyCols, AAllCols, AValues: string): string;
var
  Cols, Keys: TStringList;
  I: Integer;
  Sets: string;
begin
  if FKind = dkSqlite then
    Exit('INSERT OR REPLACE INTO ' + ATable + ' (' + AAllCols + ') VALUES (' + AValues + ')');
  if FKind = dkMaria then
  begin
    Cols := TStringList.Create;
    Keys := TStringList.Create;
    try
      Cols.CommaText := StringReplace(AAllCols, ' ', '', [rfReplaceAll]);
      Keys.CommaText := StringReplace(AKeyCols, ' ', '', [rfReplaceAll]);
      Sets := '';
      for I := 0 to Cols.Count - 1 do
        if Keys.IndexOf(Cols[I]) < 0 then
        begin
          if Sets <> '' then Sets := Sets + ', ';
          Sets := Sets + Cols[I] + ' = VALUES(' + Cols[I] + ')';
        end;
      Result := 'INSERT INTO ' + ATable + ' (' + AAllCols + ') VALUES (' + AValues + ')';
      if Sets <> '' then Result := Result + ' ON DUPLICATE KEY UPDATE ' + Sets
      else Result := StringReplace(Result, 'INSERT INTO', 'INSERT IGNORE INTO', []);
    finally
      Keys.Free;
      Cols.Free;
    end;
    Exit;
  end;
  Cols := TStringList.Create;
  Keys := TStringList.Create;
  try
    Cols.CommaText := StringReplace(AAllCols, ' ', '', [rfReplaceAll]);
    Keys.CommaText := StringReplace(AKeyCols, ' ', '', [rfReplaceAll]);
    Sets := '';
    for I := 0 to Cols.Count - 1 do
      if Keys.IndexOf(Cols[I]) < 0 then
      begin
        if Sets <> '' then Sets := Sets + ', ';
        Sets := Sets + Cols[I] + ' = EXCLUDED.' + Cols[I];
      end;
    Result := 'INSERT INTO ' + ATable + ' (' + AAllCols + ') VALUES (' + AValues + ') ON CONFLICT (' + AKeyCols + ')';
    if Sets = '' then Result := Result + ' DO NOTHING' else Result := Result + ' DO UPDATE SET ' + Sets;
  finally
    Keys.Free;
    Cols.Free;
  end;
end;

function TAppDb.RowIdSql(const ATable: string): string;
begin
  if FKind = dkPostgres then Result := 'ctid::text'
  else if FKind = dkMaria then Result := QuoteId(PrimaryKeyOf(ATable))   { nema rowid: prvi primarni kljuc }
  else Result := 'rowid';
end;

{ Zeos trazi libmariadb.so bez verzije, a na Debianu je samo libmariadb.so.3 (bez razvojnih paketa). }
function FindMariaClient: string;
const
  Names: array[0..3] of string = ('libmariadb.so.3', 'libmariadb.so', 'libmysqlclient.so.21', 'libmysqlclient.so');
  Dirs: array[0..3] of string = ('/usr/lib/x86_64-linux-gnu/', '/usr/lib64/', '/usr/lib/', '/usr/local/lib/');
var
  N, D: string;
begin
  Result := '';
  for N in Names do
    for D in Dirs do
      if FileExists(D + N) then Exit(D + N);
end;

procedure TAppDb.OpenMaria(const AHost: string; APort: Integer; const ADb, AUser, APassword: string);
begin
  Close;
  FKind := dkMaria;
  SqlPostgres := False;
  SqlMaria := True;
  FConn.Protocol := 'mariadb';
  FConn.LibraryLocation := FindMariaClient;
  FConn.HostName := AHost;
  FConn.Port := APort;
  FConn.Database := ADb;
  FConn.User := AUser;
  FConn.Password := APassword;
  FConn.Connect;
  { navodnici za identifikatore, || kao spajanje teksta, bez posebnog znacenja kose crte }
  FConn.ExecuteDirect('SET SESSION sql_mode = ''ANSI_QUOTES,PIPES_AS_CONCAT,NO_BACKSLASH_ESCAPES,STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION''');
  FConn.ExecuteDirect('SET NAMES utf8mb4');
  CreateSysTables;
end;

function TAppDb.NowSql: string;
begin
  if FKind = dkMaria then
    Result := 'DATE_FORMAT(UTC_TIMESTAMP(), ''%Y-%m-%d %H:%i:%s'')'
  else if FKind = dkPostgres then
    Result := 'to_char(now() at time zone ''utc'', ''YYYY-MM-DD HH24:MI:SS'')'
  else
    Result := 'datetime(''now'')';
end;

destructor TAppDb.Destroy;
begin
  ParamValues.Free;
  ParamLast.Free;
  FConn.Free;
  inherited Destroy;
end;

function TAppDb.QuoteLit(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
end;

function TAppDb.QuoteId(const S: string): string;
begin
  Result := QuoteIdent(S);
end;

function TAppDb.ColumnExists(const ATable, AColumn: string): Boolean;
var
  Q: TZQuery;
begin
  Result := False;
  Q := TableInfo(ATable);
  try
    while not Q.EOF do
    begin
      if SameText(Q.FieldByName('name').AsString, AColumn) then Result := True;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure TAppDb.CreateSysTables;
var
  T, AutoIdType: string;
begin
  if FKind = dkPostgres then AutoIdType := 'BIGSERIAL PRIMARY KEY'
  else if FKind = dkMaria then AutoIdType := 'BIGINT AUTO_INCREMENT PRIMARY KEY'
  else AutoIdType := 'INTEGER PRIMARY KEY AUTOINCREMENT';
  if FKind = dkMaria then
  begin
    { TEXT ne moze biti kljuc, a TEXT je najvise 64 KB }
    for T in SysTables do
      FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS ' + T +
        ' (name VARCHAR(190) PRIMARY KEY, definition LONGTEXT, modified VARCHAR(40))');
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_settings (k VARCHAR(190) PRIMARY KEY, v LONGTEXT)');
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_audit (id ' + AutoIdType + ', ' +
      'ts VARCHAR(40), usr VARCHAR(190), tbl VARCHAR(190), rowkey VARCHAR(190), action VARCHAR(10), ' +
      'field VARCHAR(190), old_value LONGTEXT, new_value LONGTEXT)');
    FConn.ExecuteDirect('CREATE INDEX IF NOT EXISTS _sys_audit_tbl ON _sys_audit (tbl, rowkey)');
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_tasks (name VARCHAR(190) PRIMARY KEY, kind VARCHAR(60), ' +
      'arg LONGTEXT, arg2 LONGTEXT, schedule VARCHAR(190), enabled INTEGER, last_run VARCHAR(40), last_result LONGTEXT)');
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_users (name VARCHAR(190) PRIMARY KEY, pwd VARCHAR(255), role VARCHAR(40))');
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_rights (kind VARCHAR(60), name VARCHAR(190), min_role VARCHAR(40), PRIMARY KEY (kind, name))');
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_fields (tbl VARCHAR(190), fld VARCHAR(190), ftype VARCHAR(60), ' +
      '`format` VARCHAR(255), default_expr LONGTEXT, decimals INTEGER, validation LONGTEXT, validation_msg LONGTEXT, ' +
      'caption VARCHAR(255), descr LONGTEXT, colwidth INTEGER, extra LONGTEXT, PRIMARY KEY (tbl, fld))');
    if not ColumnExists('_sys_fields', 'extra') then
      FConn.ExecuteDirect('ALTER TABLE _sys_fields ADD COLUMN extra LONGTEXT');
    Exit;
  end;
  for T in SysTables do
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS ' + T +
      ' (name TEXT PRIMARY KEY, definition TEXT, modified TEXT)');
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_settings (k TEXT PRIMARY KEY, v TEXT)');
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_audit (id ' + AutoIdType + ', ' +
    'ts TEXT, usr TEXT, tbl TEXT, rowkey TEXT, action TEXT, field TEXT, old_value TEXT, new_value TEXT)');
  FConn.ExecuteDirect('CREATE INDEX IF NOT EXISTS _sys_audit_tbl ON _sys_audit (tbl, rowkey)');
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_tasks (name TEXT PRIMARY KEY, kind TEXT, arg TEXT, arg2 TEXT, ' +
    'schedule TEXT, enabled INTEGER, last_run TEXT, last_result TEXT)');
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_users (name TEXT PRIMARY KEY, pwd TEXT, role TEXT)');
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_rights (kind TEXT, name TEXT, min_role TEXT, PRIMARY KEY (kind, name))');
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_fields (tbl TEXT, fld TEXT, ftype TEXT, ' +
    'format TEXT, default_expr TEXT, decimals INTEGER, PRIMARY KEY (tbl, fld))');
  { databases made before validation rules existed }
  if not ColumnExists('_sys_fields', 'validation') then
    FConn.ExecuteDirect('ALTER TABLE _sys_fields ADD COLUMN validation TEXT');
  if not ColumnExists('_sys_fields', 'validation_msg') then
    FConn.ExecuteDirect('ALTER TABLE _sys_fields ADD COLUMN validation_msg TEXT');
  if not ColumnExists('_sys_fields', 'caption') then
    FConn.ExecuteDirect('ALTER TABLE _sys_fields ADD COLUMN caption TEXT');
  if not ColumnExists('_sys_fields', 'descr') then
    FConn.ExecuteDirect('ALTER TABLE _sys_fields ADD COLUMN descr TEXT');
  if not ColumnExists('_sys_fields', 'colwidth') then
    FConn.ExecuteDirect('ALTER TABLE _sys_fields ADD COLUMN colwidth INTEGER');
  if not ColumnExists('_sys_fields', 'extra') then
    FConn.ExecuteDirect('ALTER TABLE _sys_fields ADD COLUMN extra TEXT');
end;

procedure TAppDb.Open(const AFile: string);
begin
  Close;
  FKind := dkSqlite;
  SqlPostgres := False;
  SqlMaria := False;
  FConn.Protocol := 'sqlite';
  FConn.Database := AFile;
  FConn.Connect;
  FConn.ExecuteDirect('PRAGMA foreign_keys = ON');
  CreateSysTables;
end;

procedure TAppDb.OpenPostgres(const AHost: string; APort: Integer; const ADb, AUser, APassword: string);
begin
  Close;
  FKind := dkPostgres;
  SqlPostgres := True;
  SqlMaria := False;
  FConn.Protocol := 'postgresql';
  FConn.HostName := AHost;
  FConn.Port := APort;
  FConn.Database := ADb;
  FConn.User := AUser;
  FConn.Password := APassword;
  FConn.Connect;
  CreateSysTables;
end;

procedure TAppDb.Close;
begin
  if FConn.Connected then FConn.Disconnect;
end;

function TAppDb.Connected: Boolean;
begin
  Result := FConn.Connected;
end;

function TAppDb.NewQuery(const ASql: string): TZQuery;
begin
  Result := TZQuery.Create(nil);
  Result.Connection := FConn;
  Result.SQL.Text := ASql;
  Result.AfterOpen := @SetFloatFormats;
end;

{ Bez ovoga mreza pokazuje 150 kao 1.5E2: decimalni brojevi dobivaju običan zapis. }
procedure TAppDb.SetFloatFormats(ADataSet: TDataSet);
var
  I: Integer;
begin
  for I := 0 to ADataSet.FieldCount - 1 do
    if (ADataSet.Fields[I] is TFloatField) and (TFloatField(ADataSet.Fields[I]).DisplayFormat = '') then
      TFloatField(ADataSet.Fields[I]).DisplayFormat := '#,##0.######'
    else if (ADataSet.Fields[I] is TFMTBCDField) and (TFMTBCDField(ADataSet.Fields[I]).DisplayFormat = '') then
    begin
      { numeric(12,2) iz Postgresa: broj decimala je opseg stupca }
      if ADataSet.Fields[I].Size > 0 then
        TFMTBCDField(ADataSet.Fields[I]).DisplayFormat := '#,##0.' + StringOfChar('0', ADataSet.Fields[I].Size)
      else
        TFMTBCDField(ADataSet.Fields[I]).DisplayFormat := '#,##0';
    end;
end;

function TAppDb.UserTables: TStringList;
var
  Q: TZQuery;
begin
  Result := TStringList.Create;
  if FKind = dkMaria then
    Q := NewQuery('SELECT table_name AS name FROM information_schema.tables ' +
      'WHERE table_schema = DATABASE() AND table_type = ''BASE TABLE'' ' +
      'AND table_name NOT LIKE ''\_sys\_%'' ORDER BY table_name')
  else if FKind = dkPostgres then
    Q := NewQuery('SELECT table_name AS name FROM information_schema.tables ' +
      'WHERE table_schema = current_schema() AND table_type = ''BASE TABLE'' ' +
      'AND table_name NOT LIKE ''\_sys\_%'' ESCAPE ''\'' ORDER BY table_name')
  else
    Q := NewQuery('SELECT name FROM sqlite_master WHERE type=''table'' ' +
      'AND name NOT LIKE ''sqlite_%'' AND name NOT LIKE ''\_sys\_%'' ESCAPE ''\'' ORDER BY name');
  try
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Q.Fields[0].AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TAppDb.TableInfo(const ATable: string): TZQuery;
begin
  if FKind = dkMaria then Result := NewQuery(MariaTableInfoSql(ATable))
  else if FKind = dkPostgres then Result := NewQuery(PgTableInfoSql(ATable))
  else Result := NewQuery('PRAGMA table_info(' + QuoteId(ATable) + ')');
  Result.Open;
end;

procedure TAppDb.CreateTable(const AName: string; const AFields: TFieldDefs2);
var
  S, Pks, FkTail: string;
  I, PkCount: Integer;
  Typ: string;
begin
  if Length(AFields) = 0 then raise Exception.Create(Tr('A table must have at least one field'));
  PkCount := 0;
  for I := 0 to High(AFields) do
    if AFields[I].PrimaryKey then Inc(PkCount);
  S := 'CREATE TABLE ' + QuoteId(AName) + ' (';
  Pks := '';
  FkTail := '';
  for I := 0 to High(AFields) do
  begin
    if I > 0 then S := S + ', ';
    Typ := AFields[I].SqlType;
    if AFields[I].Meta <> nil then Typ := PhysicalType(AFields[I].Meta.LType);
    if FKind = dkMaria then
    begin
      Typ := MariaType(Typ, AFields[I].PrimaryKey or (AFields[I].RefTable <> ''));
      if (AFields[I].Meta <> nil) and (AFields[I].Meta.LType = ltAutoNumber) then
        Typ := 'INTEGER AUTO_INCREMENT';
    end;
    if FKind = dkPostgres then
    begin
      Typ := PgType(Typ);
      if (AFields[I].Meta <> nil) and (AFields[I].Meta.LType = ltAutoNumber) then
        Typ := 'integer GENERATED BY DEFAULT AS IDENTITY';
    end;
    S := S + QuoteId(AFields[I].Name) + ' ' + Typ;
    if FKind = dkMaria then
    begin
      { MariaDB ignorira REFERENCES uz stupac: veza ide kao zasebno ogranicenje }
      if AFields[I].RefTable <> '' then
        FkTail := FkTail + ', FOREIGN KEY (' + QuoteId(AFields[I].Name) + ')' + RefClause(AFields[I]);
    end
    else
      S := S + RefClause(AFields[I]);
    if AFields[I].PrimaryKey then
    begin
      if PkCount = 1 then S := S + ' PRIMARY KEY'
      else
      begin
        if Pks <> '' then Pks := Pks + ', ';
        Pks := Pks + QuoteId(AFields[I].Name);
      end;
    end;
    if AFields[I].NotNull then S := S + ' NOT NULL';
  end;
  if Pks <> '' then S := S + ', PRIMARY KEY (' + Pks + ')';
  FConn.ExecuteDirect(S + FkTail + ')');
  for I := 0 to High(AFields) do
    if AFields[I].Meta <> nil then
    begin
      AFields[I].Meta.TableName := AName;
      AFields[I].Meta.FieldName := AFields[I].Name;
      SaveFieldMeta(AFields[I].Meta);
    end;
end;

procedure TAppDb.DropTable(const AName: string);
begin
  if Assigned(BeforeSchemaChange) then BeforeSchemaChange(Self, AName);
  FConn.ExecuteDirect('DROP TABLE ' + QuoteId(AName));
  DeleteFieldMeta(AName);
  if Assigned(AfterSchemaChange) then AfterSchemaChange(Self, AName);
end;

procedure TAppDb.SaveObject(const ATable, AName, ADef: string);
var
  Q: TZQuery;
begin
  Q := NewQuery(UpsertSql(QuoteId(ATable), 'name', 'name, definition, modified', ':n, :d, ' + NowSql));
  try
    Q.ParamByName('n').AsString := AName;
    Q.ParamByName('d').AsString := ADef;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TAppDb.LoadObject(const ATable, AName: string): string;
var
  Q: TZQuery;
begin
  Q := NewQuery('SELECT definition FROM ' + QuoteId(ATable) + ' WHERE name = :n');
  try
    Q.ParamByName('n').AsString := AName;
    Q.Open;
    if Q.EOF then Result := '' else Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

function TAppDb.ListObjects(const ATable: string): TStringList;
var
  Q: TZQuery;
begin
  Result := TStringList.Create;
  Q := NewQuery('SELECT name FROM ' + QuoteId(ATable) + ' ORDER BY name');
  try
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Q.Fields[0].AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure TAppDb.DeleteObject(const ATable, AName: string);
var
  Q: TZQuery;
begin
  Q := NewQuery('DELETE FROM ' + QuoteId(ATable) + ' WHERE name = :n');
  try
    Q.ParamByName('n').AsString := AName;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function CleanSql(const S: string): string;
begin
  Result := Trim(S);
  while (Result <> '') and (Result[Length(Result)] = ';') do
    Result := Trim(Copy(Result, 1, Length(Result) - 1));
end;

{ A saved query name resolves to its SQL, anything else to the table itself. }
function TAppDb.SourceFromRaw(const AName: string): string;
var
  Sql: string;
begin
  Sql := LoadObject('_sys_queries', AName);
  if Sql <> '' then Result := '(' + CleanSql(Sql) + ')'
  else Result := QuoteId(AName);
end;

function TAppDb.SourceFrom(const AName: string): string;
begin
  Result := ExpandParams(SourceFromRaw(AName));
  { MariaDB i Postgres do 15 traze naziv za izvedenu tablicu }
  if (Result <> '') and (Result[1] = '(') then Result := Result + ' AS _src';
end;

procedure TAppDb.ClearParams;
begin
  if ParamValues <> nil then ParamValues.Clear;
end;

function TAppDb.ExpandParams(const ASql: string): string;
var
  Names, Ask, Vals: TStringList;
  I: Integer;
begin
  Result := ASql;
  if Pos('[?', ASql) = 0 then Exit;
  if ParamValues = nil then ParamValues := TStringList.Create;
  if ParamLast = nil then ParamLast := TStringList.Create;
  Names := ParamNamesIn(ASql);
  try
    Ask := TStringList.Create;
    try
      for I := 0 to Names.Count - 1 do
        if ParamValues.IndexOfName(Names[I]) < 0 then Ask.Add(Names[I]);
      if (Ask.Count > 0) and (QuietParams = 0) and Assigned(ParamPromptHook) then
      begin
        { zadano je ono sto je zadnji put uneseno }
        Vals := TStringList.Create;
        try
          for I := 0 to Ask.Count - 1 do
            Vals.Values[Ask[I]] := ParamLast.Values[Ask[I]];
          if not ParamPromptHook(Ask, Vals) then
            raise EParamCancel.Create('Upit otkazan: parametri nisu uneseni.');
          for I := 0 to Ask.Count - 1 do
          begin
            ParamValues.Values[Ask[I]] := Vals.Values[Ask[I]];
            ParamLast.Values[Ask[I]] := Vals.Values[Ask[I]];
          end;
        finally
          Vals.Free;
        end;
      end;
    finally
      Ask.Free;
    end;
  finally
    Names.Free;
  end;
  Result := SubstituteParams(ASql, ParamValues);
end;

function TAppDb.SourceSql(const AName: string): string;
begin
  Result := 'SELECT * FROM ' + SourceFrom(AName);
end;

{ Rows are 'from|reftable|to'. }
function TAppDb.ForeignKeys(const ATable: string): TStringList;
var
  Q: TZQuery;
begin
  Result := TStringList.Create;
  if FKind = dkMaria then Q := NewQuery(MariaFkSql(ATable))
  else if FKind = dkPostgres then Q := NewQuery(PgFkSql(ATable))
  else Q := NewQuery('PRAGMA foreign_key_list(' + QuoteId(ATable) + ')');
  try
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Q.FieldByName('from').AsString + '|' + Q.FieldByName('table').AsString +
        '|' + Q.FieldByName('to').AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure TAppDb.AddColumn(const ATable: string; const ADef: TFieldDef);
begin
  if Assigned(BeforeSchemaChange) then BeforeSchemaChange(Self, ATable);
  try
    AddColumnInner(ATable, ADef);
  finally
    if Assigned(AfterSchemaChange) then AfterSchemaChange(Self, ATable);
  end;
end;

procedure TAppDb.AddColumnInner(const ATable: string; const ADef: TFieldDef);
var
  Typ: string;
begin
  Typ := ADef.SqlType;
  if ADef.Meta <> nil then Typ := PhysicalType(ADef.Meta.LType);
  if FKind = dkPostgres then Typ := PgType(Typ);
  if FKind = dkMaria then
  begin
    Typ := MariaType(Typ, ADef.RefTable <> '');
    FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(ATable) + ' ADD COLUMN ' + QuoteId(ADef.Name) + ' ' + Typ);
    if ADef.RefTable <> '' then
      FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(ATable) + ' ADD FOREIGN KEY (' + QuoteId(ADef.Name) + ')' + RefClause(ADef));
  end
  else
  FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(ATable) + ' ADD COLUMN ' + QuoteId(ADef.Name) + ' ' + Typ +
    RefClause(ADef));
  if ADef.Meta <> nil then
  begin
    ADef.Meta.TableName := ATable;
    ADef.Meta.FieldName := ADef.Name;
    SaveFieldMeta(ADef.Meta);
  end;
end;

procedure TAppDb.DropColumn(const ATable, AColumn: string);
begin
  if Assigned(BeforeSchemaChange) then BeforeSchemaChange(Self, ATable);
  try
    DropColumnInner(ATable, AColumn);
  finally
    if Assigned(AfterSchemaChange) then AfterSchemaChange(Self, ATable);
  end;
end;

procedure TAppDb.DropColumnInner(const ATable, AColumn: string);
begin
  FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(ATable) + ' DROP COLUMN ' + QuoteId(AColumn));
  DeleteFieldMeta(ATable, AColumn);
end;

procedure TAppDb.RenameColumn(const ATable, AOld, ANew: string);
begin
  if Assigned(BeforeSchemaChange) then BeforeSchemaChange(Self, ATable);
  try
    RenameColumnInner(ATable, AOld, ANew);
  finally
    if Assigned(AfterSchemaChange) then AfterSchemaChange(Self, ATable);
  end;
end;

procedure TAppDb.RenameColumnInner(const ATable, AOld, ANew: string);
var
  Q: TZQuery;
begin
  FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(ATable) + ' RENAME COLUMN ' +
    QuoteId(AOld) + ' TO ' + QuoteId(ANew));
  Q := NewQuery('UPDATE _sys_fields SET fld = :n WHERE tbl = :t AND fld = :o');
  try
    Q.ParamByName('n').AsString := Nm(ANew);
    Q.ParamByName('t').AsString := Nm(ATable);
    Q.ParamByName('o').AsString := Nm(AOld);
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TAppDb.SaveFieldMeta(M: TaFieldMeta);
var
  Q: TZQuery;
begin
  Q := NewQuery(UpsertSql('_sys_fields', 'tbl, fld',
    'tbl, fld, ftype, format, default_expr, decimals, validation, validation_msg, caption, descr, colwidth, extra',
    ':t, :f, :y, :m, :d, :c, :v, :g, :cp, :ds, :cw, :ex'));
  try
    Q.ParamByName('t').AsString := Nm(M.TableName);
    Q.ParamByName('f').AsString := Nm(M.FieldName);
    Q.ParamByName('y').AsString := LogicalNames[M.LType];
    Q.ParamByName('m').AsString := M.Format;
    Q.ParamByName('d').AsString := M.DefaultExpr;
    Q.ParamByName('c').AsInteger := M.Decimals;
    Q.ParamByName('v').AsString := M.Validation;
    Q.ParamByName('g').AsString := M.ValidationMsg;
    Q.ParamByName('cp').AsString := M.Caption;
    Q.ParamByName('ds').AsString := M.Description;
    Q.ParamByName('cw').AsInteger := M.ColWidth;
    Q.ParamByName('ex').AsString := M.Extra;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TAppDb.LoadFieldMetas(const ATable: string): TFPObjectList;
var
  Q: TZQuery;
  M: TaFieldMeta;
begin
  Result := TFPObjectList.Create(True);
  Q := NewQuery('SELECT fld, ftype, format, default_expr, decimals, validation, validation_msg, caption, descr, colwidth, extra FROM _sys_fields WHERE tbl = :t');
  try
    Q.ParamByName('t').AsString := Nm(ATable);
    Q.Open;
    while not Q.EOF do
    begin
      M := TaFieldMeta.Create;
      M.TableName := ATable;
      M.FieldName := Q.Fields[0].AsString;
      M.LType := LogicalFromName(Q.Fields[1].AsString);
      M.Format := Q.Fields[2].AsString;
      M.DefaultExpr := Q.Fields[3].AsString;
      M.Decimals := Q.Fields[4].AsInteger;
      M.Validation := Q.Fields[5].AsString;
      M.ValidationMsg := Q.Fields[6].AsString;
      M.Caption := Q.Fields[7].AsString;
      M.Description := Q.Fields[8].AsString;
      M.ColWidth := Q.Fields[9].AsInteger;
      M.Extra := Q.Fields[10].AsString;
      Result.Add(M);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

{ Returns a new object, or nil when the field has no metadata. }
function TAppDb.FindFieldMeta(const ATable, AField: string): TaFieldMeta;
var
  L: TFPObjectList;
  I: Integer;
begin
  Result := nil;
  L := LoadFieldMetas(ATable);
  try
    for I := 0 to L.Count - 1 do
      if SameText(TaFieldMeta(L[I]).FieldName, AField) then
        Exit(TaFieldMeta(L[I]).Clone);
  finally
    L.Free;
  end;
end;

procedure TAppDb.DeleteFieldMeta(const ATable: string; const AField: string);
var
  Q: TZQuery;
begin
  if AField = '' then Q := NewQuery('DELETE FROM _sys_fields WHERE tbl = :t')
  else Q := NewQuery('DELETE FROM _sys_fields WHERE tbl = :t AND fld = :f');
  try
    Q.ParamByName('t').AsString := Nm(ATable);
    if AField <> '' then Q.ParamByName('f').AsString := Nm(AField);
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TAppDb.RefClause(const ADef: TFieldDef): string;
begin
  Result := '';
  if ADef.RefTable = '' then Exit;
  Result := ' REFERENCES ' + QuoteId(ADef.RefTable);
  if ADef.RefField <> '' then Result := Result + '(' + QuoteId(ADef.RefField) + ')';
  if (ADef.OnDelete <> '') and not SameText(ADef.OnDelete, 'NO ACTION') then
    Result := Result + ' ON DELETE ' + ADef.OnDelete;
end;

function TAppDb.GetFks(const ATable: string): TaFkDefs;
var
  Q: TZQuery;
  N: Integer;
begin
  SetLength(Result, 0);
  if FKind = dkMaria then Q := NewQuery(MariaFkSql(ATable))
  else if FKind = dkPostgres then Q := NewQuery(PgFkSql(ATable))
  else Q := NewQuery('PRAGMA foreign_key_list(' + QuoteId(ATable) + ')');
  try
    Q.Open;
    N := 0;
    while not Q.EOF do
    begin
      SetLength(Result, N + 1);
      Result[N].FromCol := Q.FieldByName('from').AsString;
      Result[N].RefTable := Q.FieldByName('table').AsString;
      Result[N].RefCol := Q.FieldByName('to').AsString;
      Result[N].OnDelete := Q.FieldByName('on_delete').AsString;
      Result[N].OnUpdate := Q.FieldByName('on_update').AsString;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TAppDb.PrimaryKeyOf(const ATable: string): string;
var
  Q: TZQuery;
begin
  Result := '';
  Q := TableInfo(ATable);
  try
    while not Q.EOF do
    begin
      if (Result = '') and (Q.FieldByName('pk').AsInteger = 1) then Result := Q.FieldByName('name').AsString;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TAppDb.AllRelations: TaRelations;
var
  T: TStringList;
  I, J, N: Integer;
  F: TaFkDefs;
begin
  SetLength(Result, 0);
  T := UserTables;
  try
    N := 0;
    for I := 0 to T.Count - 1 do
    begin
      F := GetFks(T[I]);
      for J := 0 to High(F) do
      begin
        SetLength(Result, N + 1);
        Result[N].Child := T[I];
        Result[N].ChildCol := F[J].FromCol;
        Result[N].Parent := F[J].RefTable;
        Result[N].ParentCol := F[J].RefCol;
        Result[N].OnDelete := F[J].OnDelete;
        Result[N].OnUpdate := F[J].OnUpdate;
        Inc(N);
      end;
    end;
  finally
    T.Free;
  end;
end;

function TAppDb.SaveSetting(const AKey, AValue: string): Boolean;
var
  Q: TZQuery;
begin
  Q := NewQuery(UpsertSql('_sys_settings', 'k', 'k, v', ':k, :v'));
  try
    Q.ParamByName('k').AsString := AKey;
    Q.ParamByName('v').AsString := AValue;
    Q.ExecSQL;
    Result := True;
  finally
    Q.Free;
  end;
end;

function TAppDb.LoadSetting(const AKey: string): string;
var
  Q: TZQuery;
begin
  Q := NewQuery('SELECT v FROM _sys_settings WHERE k = :k');
  try
    Q.ParamByName('k').AsString := AKey;
    Q.Open;
    if Q.EOF then Result := '' else Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

{ SQLite cannot add or change a foreign key in place, so the table is rebuilt:
  new table with the same columns, primary key, unique constraints and the
  requested foreign keys, rows copied across, indexes recreated. Existing rows
  that violate a key make the whole operation roll back. }
procedure TAppDb.SetFks(const ATable: string; const AFks: TaFkDefs);
begin
  if Assigned(BeforeSchemaChange) then BeforeSchemaChange(Self, ATable);
  try
    SetFksInner(ATable, AFks);
  finally
    if Assigned(AfterSchemaChange) then AfterSchemaChange(Self, ATable);
  end;
end;

procedure TAppDb.SetFksInner(const ATable: string; const AFks: TaFkDefs);
var
  MaOld: TaFkDefs;
  MaNames: TStringList;
  MaQ: TZQuery;
  MaI: Integer;

  procedure MaAdd(const AF: TaFkDefs);
  var
    J: Integer;
    Sq: string;
  begin
    for J := 0 to High(AF) do
    begin
      Sq := 'ALTER TABLE ' + QuoteId(ATable) + ' ADD CONSTRAINT ' + QuoteId('fk_' + ATable + '_' + AF[J].FromCol) +
        ' FOREIGN KEY (' + QuoteId(AF[J].FromCol) + ') REFERENCES ' + QuoteId(AF[J].RefTable);
      if AF[J].RefCol <> '' then Sq := Sq + '(' + QuoteId(AF[J].RefCol) + ')';
      if (AF[J].OnDelete <> '') and not SameText(AF[J].OnDelete, 'NO ACTION') then Sq := Sq + ' ON DELETE ' + AF[J].OnDelete;
      if (AF[J].OnUpdate <> '') and not SameText(AF[J].OnUpdate, 'NO ACTION') then Sq := Sq + ' ON UPDATE ' + AF[J].OnUpdate;
      FConn.ExecuteDirect(Sq);
    end;
  end;

var
  PgNames: TStringList;
  PgQ: TZQuery;
  PgI: Integer;
  PgSql: string;
begin
  if FKind = dkMaria then
  begin
    { DDL u MariaDB-u nije transakcijski: ako nove veze ne prodju, vraca se staro stanje }
    MaOld := GetFks(ATable);
    MaNames := TStringList.Create;
    try
      MaQ := NewQuery('SELECT DISTINCT constraint_name FROM information_schema.key_column_usage ' +
        'WHERE table_schema = DATABASE() AND lower(table_name) = lower(' + QuoteLit(ATable) + ') AND referenced_table_name IS NOT NULL');
      try
        MaQ.Open;
        while not MaQ.EOF do begin MaNames.Add(MaQ.Fields[0].AsString); MaQ.Next; end;
      finally
        MaQ.Free;
      end;
      for MaI := 0 to MaNames.Count - 1 do
        FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(ATable) + ' DROP FOREIGN KEY ' + QuoteId(MaNames[MaI]));
      try
        MaAdd(AFks);
      except
        for MaI := 0 to MaNames.Count - 1 do
          try
            FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(ATable) + ' DROP FOREIGN KEY ' + QuoteId('fk_' + ATable + '_' + MaOld[0].FromCol));
          except end;
        try MaAdd(MaOld); except end;
        raise;
      end;
    finally
      MaNames.Free;
    end;
    Exit;
  end;
  if FKind = dkPostgres then
  begin
    { Postgres mijenja veze na mjestu: makni postojece, dodaj trazene }
    PgNames := TStringList.Create;
    try
      PgQ := NewQuery('SELECT con.conname FROM pg_constraint con JOIN pg_class c ON c.oid = con.conrelid ' +
        'JOIN pg_namespace n ON n.oid = c.relnamespace WHERE con.contype = ''f'' AND lower(c.relname) = lower(' +
        QuoteLit(ATable) + ') AND n.nspname = current_schema()');
      try
        PgQ.Open;
        while not PgQ.EOF do begin PgNames.Add(PgQ.Fields[0].AsString); PgQ.Next; end;
      finally
        PgQ.Free;
      end;
      FConn.StartTransaction;
      try
        for PgI := 0 to PgNames.Count - 1 do
          FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(ATable) + ' DROP CONSTRAINT ' + QuoteId(PgNames[PgI]));
        for PgI := 0 to High(AFks) do
        begin
          PgSql := 'ALTER TABLE ' + QuoteId(ATable) + ' ADD CONSTRAINT ' +
            QuoteId('fk_' + ATable + '_' + AFks[PgI].FromCol) + ' FOREIGN KEY (' + QuoteId(AFks[PgI].FromCol) +
            ') REFERENCES ' + QuoteId(AFks[PgI].RefTable);
          if AFks[PgI].RefCol <> '' then PgSql := PgSql + '(' + QuoteId(AFks[PgI].RefCol) + ')';
          if (AFks[PgI].OnDelete <> '') and not SameText(AFks[PgI].OnDelete, 'NO ACTION') then
            PgSql := PgSql + ' ON DELETE ' + AFks[PgI].OnDelete;
          if (AFks[PgI].OnUpdate <> '') and not SameText(AFks[PgI].OnUpdate, 'NO ACTION') then
            PgSql := PgSql + ' ON UPDATE ' + AFks[PgI].OnUpdate;
          FConn.ExecuteDirect(PgSql);
        end;
        FConn.Commit;
      except
        FConn.Rollback;
        raise;
      end;
    finally
      PgNames.Free;
    end;
    Exit;
  end;
  SetFksSqlite(ATable, AFks);
end;

procedure TAppDb.SetFksSqlite(const ATable: string; const AFks: TaFkDefs);
var
  Info, Q: TZQuery;
  Cols, Names, Pks, Uniques, Indexes: TStringList;
  I, K: Integer;
  Sql, Tmp, Def, Name: string;
  PkCount: Integer;
  Cnt: Integer;
begin
  Tmp := '_rebuild_' + ATable;
  Cols := TStringList.Create;
  Names := TStringList.Create;
  Pks := TStringList.Create;
  Uniques := TStringList.Create;
  Indexes := TStringList.Create;
  try
    Info := TableInfo(ATable);
    try
      while not Info.EOF do
      begin
        Name := Info.FieldByName('name').AsString;
        Names.Add(QuoteId(Name));
        Def := QuoteId(Name) + ' ' + Info.FieldByName('type').AsString;
        if Info.FieldByName('notnull').AsInteger > 0 then Def := Def + ' NOT NULL';
        if not Info.FieldByName('dflt_value').IsNull then Def := Def + ' DEFAULT ' + Info.FieldByName('dflt_value').AsString;
        Cols.AddObject(Def, TObject(PtrInt(Info.FieldByName('pk').AsInteger)));
        Info.Next;
      end;
    finally
      Info.Free;
    end;
    PkCount := 0;
    for I := 0 to Cols.Count - 1 do
      if PtrInt(Cols.Objects[I]) > 0 then Inc(PkCount);
    if PkCount = 1 then
    begin
      for I := 0 to Cols.Count - 1 do
        if PtrInt(Cols.Objects[I]) > 0 then Cols[I] := Cols[I] + ' PRIMARY KEY';
    end
    else if PkCount > 1 then
    begin
      { composite key: keep the declared order (pk column holds the position) }
      for K := 1 to PkCount do
        for I := 0 to Cols.Count - 1 do
          if PtrInt(Cols.Objects[I]) = K then Pks.Add(Names[I]);
    end;
    { UNIQUE constraints and plain indexes }
    Q := NewQuery('PRAGMA index_list(' + QuoteId(ATable) + ')');
    try
      Q.Open;
      while not Q.EOF do
      begin
        Name := Q.FieldByName('name').AsString;
        if SameText(Q.FieldByName('origin').AsString, 'u') then Uniques.Add(Name)
        else if SameText(Q.FieldByName('origin').AsString, 'c') then Indexes.Add(Name);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    Sql := 'CREATE TABLE ' + QuoteId(Tmp) + ' (';
    for I := 0 to Cols.Count - 1 do
    begin
      if I > 0 then Sql := Sql + ', ';
      Sql := Sql + Cols[I];
    end;
    if Pks.Count > 0 then
    begin
      Sql := Sql + ', PRIMARY KEY (';
      for I := 0 to Pks.Count - 1 do
      begin
        if I > 0 then Sql := Sql + ', ';
        Sql := Sql + Pks[I];
      end;
      Sql := Sql + ')';
    end;
    for I := 0 to Uniques.Count - 1 do
    begin
      Q := NewQuery('PRAGMA index_info(' + QuoteId(Uniques[I]) + ')');
      try
        Q.Open;
        Def := '';
        while not Q.EOF do
        begin
          if Def <> '' then Def := Def + ', ';
          Def := Def + QuoteId(Q.FieldByName('name').AsString);
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      Sql := Sql + ', UNIQUE (' + Def + ')';
    end;
    for I := 0 to High(AFks) do
    begin
      Sql := Sql + ', FOREIGN KEY (' + QuoteId(AFks[I].FromCol) + ') REFERENCES ' + QuoteId(AFks[I].RefTable);
      if AFks[I].RefCol <> '' then Sql := Sql + '(' + QuoteId(AFks[I].RefCol) + ')';
      if (AFks[I].OnDelete <> '') and not SameText(AFks[I].OnDelete, 'NO ACTION') then
        Sql := Sql + ' ON DELETE ' + AFks[I].OnDelete;
      if (AFks[I].OnUpdate <> '') and not SameText(AFks[I].OnUpdate, 'NO ACTION') then
        Sql := Sql + ' ON UPDATE ' + AFks[I].OnUpdate;
    end;
    Sql := Sql + ')';

    { index definitions must be read before the old table disappears }
    for I := 0 to Indexes.Count - 1 do
    begin
      Q := NewQuery('SELECT sql FROM sqlite_master WHERE type = ''index'' AND name = :n');
      try
        Q.ParamByName('n').AsString := Indexes[I];
        Q.Open;
        if not Q.EOF then Indexes[I] := Q.Fields[0].AsString else Indexes[I] := '';
      finally
        Q.Free;
      end;
    end;

    FConn.ExecuteDirect('PRAGMA foreign_keys = OFF');
    try
      FConn.StartTransaction;
      try
        FConn.ExecuteDirect('DROP TABLE IF EXISTS ' + QuoteId(Tmp));
        FConn.ExecuteDirect(Sql);
        Def := '';
        for I := 0 to Names.Count - 1 do
        begin
          if I > 0 then Def := Def + ', ';
          Def := Def + Names[I];
        end;
        FConn.ExecuteDirect('INSERT INTO ' + QuoteId(Tmp) + ' (' + Def + ') SELECT ' + Def + ' FROM ' + QuoteId(ATable));
        FConn.ExecuteDirect('DROP TABLE ' + QuoteId(ATable));
        FConn.ExecuteDirect('ALTER TABLE ' + QuoteId(Tmp) + ' RENAME TO ' + QuoteId(ATable));
        for I := 0 to Indexes.Count - 1 do
          if Indexes[I] <> '' then FConn.ExecuteDirect(Indexes[I]);
        Q := NewQuery('PRAGMA foreign_key_check(' + QuoteId(ATable) + ')');
        try
          Q.Open;
          Cnt := 0;
          while not Q.EOF do begin Inc(Cnt); Q.Next; end;
        finally
          Q.Free;
        end;
        if Cnt > 0 then
          raise Exception.CreateFmt(Tr('The link is not possible: %d rows have no matching record in the linked table.'), [Cnt]);
        FConn.Commit;
      except
        FConn.Rollback;
        raise;
      end;
    finally
      FConn.ExecuteDirect('PRAGMA foreign_keys = ON');
    end;
  finally
    Indexes.Free;
    Uniques.Free;
    Pks.Free;
    Names.Free;
    Cols.Free;
  end;
end;

end.
