unit ta_audit;
{ Revizijski trag: tko je, kada i sto promijenio u pracenim tablicama.
  Radi preko SQLite okidaca (INSERT/UPDATE/DELETE) pa biljezi sve izmjene,
  bez obzira dolaze li iz forme, mreze, skripte, uvoza ili SQL-a. Izvor istine
  su sami okidaci (_ta_audit_i_/u_/d_<tablica>); zapisi su u _sys_audit. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZDataset, ta_meta;

{ Tablice koje se prate. }
function AuditTables(ADb: TAppDb): TStringList;
function AuditEnabled(ADb: TAppDb; const ATable: string): Boolean;
procedure AuditEnable(ADb: TAppDb; const ATable: string);
procedure AuditDisable(ADb: TAppDb; const ATable: string);
{ Tko je prijavljen (upisuje se u zapise). Prazno = korisnik operacijskog sustava. }
procedure AuditSetUser(ADb: TAppDb; const AUser: string);
{ Zapisi, najnoviji prvo. Prazan filter = bez filtera. AFrom/ATo su ISO datumi. }
function AuditQuery(ADb: TAppDb; const ATable, AUser, AAction, AKey, AFrom, ATo: string;
  ALimit: Integer): TZQuery;
{ Brise zapise starije od ADays dana; vraca koliko ih je obrisano. }
function AuditPurge(ADb: TAppDb; ADays: Integer): Integer;

implementation

var
  Pending: TStringList = nil;

function TrigName(const AKind, ATable: string): string;
begin
  Result := '_ta_audit_' + AKind + '_' + ATable;
end;

const
  PgAuditFn: array[0..2] of string = (
    'CREATE OR REPLACE FUNCTION _ta_q(v json) RETURNS text LANGUAGE sql IMMUTABLE AS $f$ ' +
    'SELECT CASE json_typeof(v) WHEN ''null'' THEN ''NULL'' WHEN ''number'' THEN v #>> ''{}'' ' +
    'ELSE quote_literal(v #>> ''{}'') END $f$',
    'CREATE OR REPLACE FUNCTION _ta_audit_fn() RETURNS trigger LANGUAGE plpgsql AS $f$ ' +
    'DECLARE pk text := TG_ARGV[0]; jn json; jo json; fld text; usr text; rk text; s text; ' +
    'ts text := to_char(localtimestamp(0), ''YYYY-MM-DD HH24:MI:SS''); ' +
    'BEGIN ' +
    'usr := (SELECT v FROM _sys_settings WHERE k = ''session.user''); ' +
    'IF TG_OP = ''INSERT'' THEN ' +
    '  jn := to_json(NEW); rk := coalesce(jn ->> pk, ''''); ' +
    '  SELECT string_agg(key || ''='' || _ta_q(value), ''; '') INTO s FROM json_each(jn); ' +
    '  INSERT INTO _sys_audit (ts, usr, tbl, rowkey, action, field, old_value, new_value) ' +
    '  VALUES (ts, usr, TG_TABLE_NAME, rk, ''I'', NULL, NULL, s); RETURN NEW; ' +
    'ELSIF TG_OP = ''DELETE'' THEN ' +
    '  jo := to_json(OLD); rk := coalesce(jo ->> pk, ''''); ' +
    '  SELECT string_agg(key || ''='' || _ta_q(value), ''; '') INTO s FROM json_each(jo); ' +
    '  INSERT INTO _sys_audit (ts, usr, tbl, rowkey, action, field, old_value, new_value) ' +
    '  VALUES (ts, usr, TG_TABLE_NAME, rk, ''D'', NULL, s, NULL); RETURN OLD; ' +
    'ELSE ' +
    '  jn := to_json(NEW); jo := to_json(OLD); rk := coalesce(jn ->> pk, ''''); ' +
    '  FOR fld IN SELECT key FROM json_each(jn) LOOP ' +
    '    IF (jn ->> fld) IS DISTINCT FROM (jo ->> fld) THEN ' +
    '      INSERT INTO _sys_audit (ts, usr, tbl, rowkey, action, field, old_value, new_value) ' +
    '      VALUES (ts, usr, TG_TABLE_NAME, rk, ''U'', fld, jo ->> fld, jn ->> fld); ' +
    '    END IF; ' +
    '  END LOOP; RETURN NEW; ' +
    'END IF; END $f$',
    '');

function PgTrigName(const ATable: string): string;
begin
  Result := '_ta_audit_' + LowerCase(ATable);
end;

procedure PgAuditEnable(ADb: TAppDb; const ATable: string);
var
  I: Integer;
begin
  for I := 0 to 1 do ADb.Conn.ExecuteDirect(PgAuditFn[I]);
  ADb.Conn.ExecuteDirect('DROP TRIGGER IF EXISTS ' + ADb.QuoteId(PgTrigName(ATable)) + ' ON ' + ADb.QuoteId(ATable));
  ADb.Conn.ExecuteDirect('CREATE TRIGGER ' + ADb.QuoteId(PgTrigName(ATable)) + ' AFTER INSERT OR UPDATE OR DELETE ON ' +
    ADb.QuoteId(ATable) + ' FOR EACH ROW EXECUTE FUNCTION _ta_audit_fn(' + ADb.QuoteLit(LowerCase(ADb.PrimaryKeyOf(ATable))) + ')');
end;

function AuditEnabled(ADb: TAppDb; const ATable: string): Boolean;
var
  Q: TZQuery;
begin
  if ADb.Kind = dkPostgres then
    Q := ADb.NewQuery('SELECT 1 FROM pg_trigger WHERE NOT tgisinternal AND tgname = :n')
  else if ADb.Kind = dkMaria then
    Q := ADb.NewQuery('SELECT 1 FROM information_schema.triggers WHERE trigger_schema = DATABASE() AND lower(trigger_name) = lower(:n)')
  else
    Q := ADb.NewQuery('SELECT 1 FROM sqlite_master WHERE type = ''trigger'' AND name = :n');
  try
    if ADb.Kind = dkPostgres then Q.ParamByName('n').AsString := PgTrigName(ATable)
    else Q.ParamByName('n').AsString := TrigName('i', ATable);
    Q.Open;
    Result := not Q.EOF;
  finally
    Q.Free;
  end;
end;

function AuditTables(ADb: TAppDb): TStringList;
var
  Q: TZQuery;
begin
  Result := TStringList.Create;
  if ADb.Kind = dkMaria then
  begin
    Q := ADb.NewQuery('SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema = DATABASE() ' +
      'AND trigger_name LIKE ''\_ta\_audit\_i\_%'' ORDER BY trigger_name');
    try
      Q.Open;
      while not Q.EOF do
      begin
        Result.Add(Copy(Q.Fields[0].AsString, Length('_ta_audit_i_') + 1, MaxInt));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    Exit;
  end;
  if ADb.Kind = dkPostgres then
  begin
    Q := ADb.NewQuery('SELECT c.relname FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid ' +
      'WHERE NOT t.tgisinternal AND t.tgname LIKE ''\_ta\_audit\_%'' ORDER BY c.relname');
    try
      Q.Open;
      while not Q.EOF do begin Result.Add(Q.Fields[0].AsString); Q.Next; end;
    finally
      Q.Free;
    end;
    Exit;
  end;
  Q := ADb.NewQuery('SELECT name FROM sqlite_master WHERE type = ''trigger'' AND name LIKE ''\_ta\_audit\_i\_%'' ESCAPE ''\'' ORDER BY name');
  try
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Copy(Q.Fields[0].AsString, Length('_ta_audit_i_') + 1, MaxInt));
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure DropTriggers(ADb: TAppDb; const ATable: string);
var
  K: string;
begin
  for K in ['i', 'u', 'd'] do
    ADb.Conn.ExecuteDirect('DROP TRIGGER IF EXISTS ' + ADb.QuoteId(TrigName(K, ATable)));
end;

procedure CreateTriggers(ADb: TAppDb; const ATable: string);
const
  Pre = 'INSERT INTO _sys_audit (ts, usr, tbl, rowkey, action, field, old_value, new_value) ';
var
  Q: TZQuery;
  Cols, Blobs: TStringList;
  I: Integer;
  T, Head, OldSum, NewSum, Body, Pk, NewKey, OldKey: string;

  function Col(const AName: string): string;
  begin
    Result := ADb.QuoteId(AName);
  end;

  function Sum(const ARow: string): string;
  var
    J: Integer;
  begin
    Result := '';
    for J := 0 to Cols.Count - 1 do
    begin
      if J > 0 then Result := Result + ' || ''; '' || ';
      if Blobs.IndexOf(Cols[J]) >= 0 then
        Result := Result + '''' + StringReplace(Cols[J], '''', '''''', [rfReplaceAll]) + '=(slika)'''
      else
        Result := Result + '''' + StringReplace(Cols[J], '''', '''''', [rfReplaceAll]) + '='' || quote(' + ARow + '.' + Col(Cols[J]) + ')';
    end;
  end;

begin
  Cols := TStringList.Create;
  Blobs := TStringList.Create;
  try
    Q := ADb.TableInfo(ATable);
    try
      while not Q.EOF do
      begin
        Cols.Add(Q.FieldByName('name').AsString);
        if Pos('BLOB', UpperCase(Q.FieldByName('type').AsString)) > 0 then Blobs.Add(Q.FieldByName('name').AsString);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    if Cols.Count = 0 then Exit;
    T := '''' + StringReplace(ATable, '''', '''''', [rfReplaceAll]) + '''';
    if ADb.Kind = dkMaria then
    begin
      T := '''' + StringReplace(LowerCase(ATable), '''', '''''', [rfReplaceAll]) + '''';
      Pk := ADb.PrimaryKeyOf(ATable);
      Head := '(SELECT DATE_FORMAT(NOW(), ''%Y-%m-%d %H:%i:%s'')), ' +
        '(SELECT v FROM _sys_settings WHERE k = ''session.user''), ' + T + ', ';
      if Pk = '' then begin NewKey := ''''''; OldKey := ''''''; end
      else begin NewKey := 'CAST(NEW.' + Col(Pk) + ' AS CHAR)'; OldKey := 'CAST(OLD.' + Col(Pk) + ' AS CHAR)'; end;
      NewSum := Sum('NEW');
      OldSum := Sum('OLD');
      ADb.Conn.ExecuteDirect('CREATE TRIGGER ' + ADb.QuoteId(TrigName('i', ATable)) + ' AFTER INSERT ON ' +
        ADb.QuoteId(ATable) + ' FOR EACH ROW ' + Pre + 'VALUES (' + Head + NewKey + ', ''I'', NULL, NULL, ' + NewSum + ')');
      ADb.Conn.ExecuteDirect('CREATE TRIGGER ' + ADb.QuoteId(TrigName('d', ATable)) + ' AFTER DELETE ON ' +
        ADb.QuoteId(ATable) + ' FOR EACH ROW ' + Pre + 'VALUES (' + Head + OldKey + ', ''D'', NULL, ' + OldSum + ', NULL)');
      Body := '';
      for I := 0 to Cols.Count - 1 do
      begin
        if Blobs.IndexOf(Cols[I]) >= 0 then
          Body := Body + Pre + 'SELECT ' + Head + NewKey + ', ''U'', ''' + StringReplace(Cols[I], '''', '''''', [rfReplaceAll]) +
            ''', ''(slika)'', ''(promijenjeno)'' FROM DUAL WHERE NOT (OLD.' + Col(Cols[I]) + ' <=> NEW.' + Col(Cols[I]) + '); '
        else
          Body := Body + Pre + 'SELECT ' + Head + NewKey + ', ''U'', ''' + StringReplace(Cols[I], '''', '''''', [rfReplaceAll]) +
            ''', OLD.' + Col(Cols[I]) + ', NEW.' + Col(Cols[I]) + ' FROM DUAL WHERE NOT (OLD.' + Col(Cols[I]) + ' <=> NEW.' +
            Col(Cols[I]) + '); ';
      end;
      ADb.Conn.ExecuteDirect('CREATE TRIGGER ' + ADb.QuoteId(TrigName('u', ATable)) + ' AFTER UPDATE ON ' +
        ADb.QuoteId(ATable) + ' FOR EACH ROW BEGIN ' + Body + 'END');
      Exit;
    end;
    Head := '(SELECT datetime(''now'', ''localtime'')), ' +
      '(SELECT v FROM _sys_settings WHERE k = ''session.user''), ' + T + ', ';
    NewSum := Sum('NEW');
    OldSum := Sum('OLD');
    ADb.Conn.ExecuteDirect('CREATE TRIGGER ' + ADb.QuoteId(TrigName('i', ATable)) + ' AFTER INSERT ON ' +
      ADb.QuoteId(ATable) + ' BEGIN ' + Pre + 'VALUES (' + Head + 'CAST(NEW.rowid AS TEXT), ''I'', NULL, NULL, ' +
      NewSum + '); END');
    ADb.Conn.ExecuteDirect('CREATE TRIGGER ' + ADb.QuoteId(TrigName('d', ATable)) + ' AFTER DELETE ON ' +
      ADb.QuoteId(ATable) + ' BEGIN ' + Pre + 'VALUES (' + Head + 'CAST(OLD.rowid AS TEXT), ''D'', NULL, ' +
      OldSum + ', NULL); END');
    Body := '';
    for I := 0 to Cols.Count - 1 do
    begin
      if Blobs.IndexOf(Cols[I]) >= 0 then
        Body := Body + Pre + 'SELECT ' + Head + 'CAST(NEW.rowid AS TEXT), ''U'', ' + '''' +
          StringReplace(Cols[I], '''', '''''', [rfReplaceAll]) + ''', ''(slika)'', ''(promijenjeno)'' WHERE OLD.' +
          Col(Cols[I]) + ' IS NOT NEW.' + Col(Cols[I]) + '; '
      else
        Body := Body + Pre + 'SELECT ' + Head + 'CAST(NEW.rowid AS TEXT), ''U'', ' + '''' +
          StringReplace(Cols[I], '''', '''''', [rfReplaceAll]) + ''', OLD.' + Col(Cols[I]) + ', NEW.' + Col(Cols[I]) +
          ' WHERE OLD.' + Col(Cols[I]) + ' IS NOT NEW.' + Col(Cols[I]) + '; ';
    end;
    ADb.Conn.ExecuteDirect('CREATE TRIGGER ' + ADb.QuoteId(TrigName('u', ATable)) + ' AFTER UPDATE ON ' +
      ADb.QuoteId(ATable) + ' BEGIN ' + Body + 'END');
  finally
    Cols.Free;
    Blobs.Free;
  end;
end;

procedure AuditEnable(ADb: TAppDb; const ATable: string);
begin
  if (ATable = '') or (Pos('_sys_', ATable) = 1) then Exit;
  if ADb.Kind = dkPostgres then begin PgAuditEnable(ADb, ATable); Exit; end;
  DropTriggers(ADb, ATable);
  CreateTriggers(ADb, ATable);
end;

procedure AuditDisable(ADb: TAppDb; const ATable: string);
begin
  if ADb.Kind = dkPostgres then
  begin
    ADb.Conn.ExecuteDirect('DROP TRIGGER IF EXISTS ' + ADb.QuoteId(PgTrigName(ATable)) + ' ON ' + ADb.QuoteId(ATable));
    Exit;
  end;
  DropTriggers(ADb, ATable);
end;

procedure AuditSetUser(ADb: TAppDb; const AUser: string);
var
  U: string;
begin
  U := AUser;
  if U = '' then U := GetEnvironmentVariable('USER');
  ADb.SaveSetting('session.user', U);
end;

function AuditQuery(ADb: TAppDb; const ATable, AUser, AAction, AKey, AFrom, ATo: string;
  ALimit: Integer): TZQuery;
var
  W, Sql: string;

  procedure And_(const ACond: string);
  begin
    if W <> '' then W := W + ' AND ';
    W := W + ACond;
  end;

begin
  W := '';
  if ATable <> '' then And_('tbl = ' + ADb.QuoteLit(ATable));
  if AUser <> '' then And_('usr LIKE ' + ADb.QuoteLit('%' + AUser + '%'));
  if AAction <> '' then And_('action = ' + ADb.QuoteLit(AAction));
  if AKey <> '' then And_('rowkey = ' + ADb.QuoteLit(AKey));
  if AFrom <> '' then And_('ts >= ' + ADb.QuoteLit(AFrom));
  if ATo <> '' then And_('ts < ' + ADb.QuoteLit(ATo + ' 99'));
  Sql := 'SELECT id, ts AS vrijeme, usr AS korisnik, tbl AS tablica, rowkey AS zapis, ' +
    'CASE action WHEN ''I'' THEN ''dodano'' WHEN ''U'' THEN ''izmijenjeno'' WHEN ''D'' THEN ''obrisano'' ELSE action END AS radnja, ' +
    'field AS polje, old_value AS staro, new_value AS novo FROM _sys_audit';
  if W <> '' then Sql := Sql + ' WHERE ' + W;
  Sql := Sql + ' ORDER BY id DESC';
  if ALimit > 0 then Sql := Sql + ' LIMIT ' + IntToStr(ALimit);
  Result := ADb.NewQuery(Sql);
  Result.Open;
end;

function AuditPurge(ADb: TAppDb; ADays: Integer): Integer;
var
  Q: TZQuery;
begin
  if ADb.Kind = dkPostgres then
  begin
    Q := ADb.NewQuery('DELETE FROM _sys_audit WHERE ts < to_char(now() - make_interval(days => :d), ''YYYY-MM-DD HH24:MI:SS'')');
    try
      Q.ParamByName('d').AsInteger := ADays;
      Q.ExecSQL;
      Exit(Q.RowsAffected);
    finally
      Q.Free;
    end;
  end;
  if ADb.Kind = dkMaria then
  begin
    Q := ADb.NewQuery('DELETE FROM _sys_audit WHERE ts < DATE_FORMAT(NOW() - INTERVAL :d DAY, ''%Y-%m-%d %H:%i:%s'')');
    try
      Q.ParamByName('d').AsInteger := ADays;
      Q.ExecSQL;
      Exit(Q.RowsAffected);
    finally
      Q.Free;
    end;
  end;
  Q := ADb.NewQuery('DELETE FROM _sys_audit WHERE ts < datetime(''now'', ''localtime'', :d)');
  try
    Q.ParamByName('d').AsString := '-' + IntToStr(ADays) + ' days';
    Q.ExecSQL;
    Result := Q.RowsAffected;
  finally
    Q.Free;
  end;
end;

procedure BeforeChange(ADb: TAppDb; const ATable: string);
begin
  if ADb.Kind = dkPostgres then Exit;   { opci okidac cita stupce u trenutku izvrsavanja }
  if Pending = nil then Pending := TStringList.Create;
  if AuditEnabled(ADb, ATable) then
  begin
    if Pending.IndexOf(ATable) < 0 then Pending.Add(ATable);
    DropTriggers(ADb, ATable);
  end;
end;

procedure AfterChange(ADb: TAppDb; const ATable: string);
var
  I: Integer;
begin
  if Pending = nil then Exit;
  I := Pending.IndexOf(ATable);
  if I < 0 then Exit;
  Pending.Delete(I);
  try
    CreateTriggers(ADb, ATable);
  except
    { tablica vise ne postoji ili nema stupaca }
  end;
end;

initialization
  BeforeSchemaChange := @BeforeChange;
  AfterSchemaChange := @AfterChange;

finalization
  Pending.Free;

end.
