unit ta_app;
{ Application level: settings (title, startup form, runtime mode), users and
  roles, per-object rights, and packaging a finished application.

  Roles: viewer (read-only data), user (edit data, run forms/reports/macros),
  admin (everything, including design). With no users defined everyone is
  admin, so a new database works without a login. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sha1, ZDataset,
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  ta_meta, ta_expr, ta_filestore;

type
  TaRole = (arViewer, arUser, arAdmin);

  TaAppSettings = record
    Title: string;
    StartupForm: string;
    RuntimeOnly: Boolean;
  end;

const
  RoleNames: array[TaRole] of string = ('viewer', 'user', 'admin');

var
  SessionUser: string = '';
  SessionRole: TaRole = arAdmin;

function RoleFromName(const S: string): TaRole;
function LoadAppSettings(ADb: TAppDb): TaAppSettings;
procedure SaveAppSettings(ADb: TAppDb; const S: TaAppSettings);

{ users }
function UserCount(ADb: TAppDb): Integer;
function AddUser(ADb: TAppDb; const AName, APassword: string; ARole: TaRole): Boolean;
function SetPassword(ADb: TAppDb; const AName, APassword: string): Boolean;
function SetUserRole(ADb: TAppDb; const AName: string; ARole: TaRole): Boolean;
function DeleteUser(ADb: TAppDb; const AName: string): Boolean;
function ListUsers(ADb: TAppDb): TStringList;     { 'name|role' }
function Authenticate(ADb: TAppDb; const AName, APassword: string; out ARole: TaRole): Boolean;
procedure StartSession(const AName: string; ARole: TaRole);

{ rights: an object can demand a minimum role }
procedure SetObjectRight(ADb: TAppDb; const AKind, AName: string; AMin: TaRole);
function GetObjectRight(ADb: TAppDb; const AKind, AName: string): TaRole;
function CanRun(ADb: TAppDb; const AKind, AName: string): Boolean;

{ packaging: copy of the database (VACUUM INTO) + the program + a launcher script }
function ExportApplication(ADb: TAppDb; const ATargetDir, AExePath, ATitle: string): string;

implementation

function RoleFromName(const S: string): TaRole;
var
  R: TaRole;
begin
  for R := Low(R) to High(R) do
    if SameText(RoleNames[R], S) then Exit(R);
  Result := arUser;
end;

function LoadAppSettings(ADb: TAppDb): TaAppSettings;
begin
  Result.Title := ADb.LoadSetting('app_title');
  Result.StartupForm := ADb.LoadSetting('startup_form');
  Result.RuntimeOnly := ADb.LoadSetting('runtime_only') = '1';
end;

procedure SaveAppSettings(ADb: TAppDb; const S: TaAppSettings);
begin
  ADb.SaveSetting('app_title', S.Title);
  ADb.SaveSetting('startup_form', S.StartupForm);
  if S.RuntimeOnly then ADb.SaveSetting('runtime_only', '1') else ADb.SaveSetting('runtime_only', '0');
end;

{ ---------------- users ---------------- }

function MakeSalt: string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to 12 do Result := Result + IntToHex(Random(16), 1);
end;

function HashPassword(const ASalt, APassword: string): string;
begin
  Result := ASalt + '$' + SHA1Print(SHA1String(ASalt + APassword));
end;

function UserCount(ADb: TAppDb): Integer;
var
  L: TStringList;
begin
  L := ADb.ListObjects('_sys_users');
  try
    Result := L.Count;
  finally
    L.Free;
  end;
end;

function UserExists(ADb: TAppDb; const AName: string): Boolean;
var
  L: TStringList;
begin
  L := ADb.ListObjects('_sys_users');
  try
    Result := L.IndexOf(AName) >= 0;
    if not Result then
      Result := L.IndexOf(LowerCase(AName)) >= 0;
  finally
    L.Free;
  end;
end;

function AddUser(ADb: TAppDb; const AName, APassword: string; ARole: TaRole): Boolean;
var
  Q: TZQuery;
begin
  Result := False;
  if (Trim(AName) = '') or UserExists(ADb, Trim(AName)) then Exit;
  Q := ADb.NewQuery('INSERT INTO _sys_users (name, pwd, role) VALUES (:n, :p, :r)');
  try
    Q.ParamByName('n').AsString := Trim(AName);
    Q.ParamByName('p').AsString := HashPassword(MakeSalt, APassword);
    Q.ParamByName('r').AsString := RoleNames[ARole];
    Q.ExecSQL;
    Result := True;
  finally
    Q.Free;
  end;
end;

function SetPassword(ADb: TAppDb; const AName, APassword: string): Boolean;
var
  Q: TZQuery;
begin
  Q := ADb.NewQuery('UPDATE _sys_users SET pwd = :p WHERE name = :n');
  try
    Q.ParamByName('n').AsString := AName;
    Q.ParamByName('p').AsString := HashPassword(MakeSalt, APassword);
    Q.ExecSQL;
    Result := Q.RowsAffected > 0;
  finally
    Q.Free;
  end;
end;

function SetUserRole(ADb: TAppDb; const AName: string; ARole: TaRole): Boolean;
var
  Q: TZQuery;
begin
  Q := ADb.NewQuery('UPDATE _sys_users SET role = :r WHERE name = :n');
  try
    Q.ParamByName('n').AsString := AName;
    Q.ParamByName('r').AsString := RoleNames[ARole];
    Q.ExecSQL;
    Result := Q.RowsAffected > 0;
  finally
    Q.Free;
  end;
end;

function AdminCount(ADb: TAppDb): Integer;
var
  Q: TZQuery;
begin
  Q := ADb.NewQuery('SELECT COUNT(*) FROM _sys_users WHERE role = ''admin''');
  try
    Q.Open;
    Result := Q.Fields[0].AsInteger;
  finally
    Q.Free;
  end;
end;

function DeleteUser(ADb: TAppDb; const AName: string): Boolean;
var
  Q: TZQuery;
  Role: TaRole;
begin
  Result := False;
  { the last administrator can't be removed, or nobody could design again }
  Q := ADb.NewQuery('SELECT role FROM _sys_users WHERE name = :n');
  try
    Q.ParamByName('n').AsString := AName;
    Q.Open;
    if Q.EOF then Exit;
    Role := RoleFromName(Q.Fields[0].AsString);
  finally
    Q.Free;
  end;
  if (Role = arAdmin) and (AdminCount(ADb) <= 1) then Exit;
  Q := ADb.NewQuery('DELETE FROM _sys_users WHERE name = :n');
  try
    Q.ParamByName('n').AsString := AName;
    Q.ExecSQL;
    Result := True;
  finally
    Q.Free;
  end;
end;

function ListUsers(ADb: TAppDb): TStringList;
var
  Q: TZQuery;
begin
  Result := TStringList.Create;
  Q := ADb.NewQuery('SELECT name, role FROM _sys_users ORDER BY name');
  try
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Q.Fields[0].AsString + '|' + Q.Fields[1].AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function Authenticate(ADb: TAppDb; const AName, APassword: string; out ARole: TaRole): Boolean;
var
  Q: TZQuery;
  Stored, Salt: string;
  P: Integer;
begin
  Result := False;
  ARole := arViewer;
  Q := ADb.NewQuery('SELECT pwd, role FROM _sys_users WHERE name = :n');
  try
    Q.ParamByName('n').AsString := Trim(AName);
    Q.Open;
    if Q.EOF then Exit;
    Stored := Q.Fields[0].AsString;
    P := Pos('$', Stored);
    if P = 0 then Exit;
    Salt := Copy(Stored, 1, P - 1);
    if HashPassword(Salt, APassword) <> Stored then Exit;
    ARole := RoleFromName(Q.Fields[1].AsString);
    Result := True;
  finally
    Q.Free;
  end;
end;

procedure StartSession(const AName: string; ARole: TaRole);
begin
  SessionUser := AName;
  SessionRole := ARole;
  CurrentUserName := AName;
  CurrentUserRole := RoleNames[ARole];
end;

{ ---------------- rights ---------------- }

procedure SetObjectRight(ADb: TAppDb; const AKind, AName: string; AMin: TaRole);
var
  Q: TZQuery;
begin
  if AMin = arViewer then
    Q := ADb.NewQuery('DELETE FROM _sys_rights WHERE kind = :k AND name = :n')
  else
    Q := ADb.NewQuery(ADb.UpsertSql('_sys_rights', 'kind, name', 'kind, name, min_role', ':k, :n, :r'));
  try
    Q.ParamByName('k').AsString := AKind;
    Q.ParamByName('n').AsString := AName;
    if AMin <> arViewer then Q.ParamByName('r').AsString := RoleNames[AMin];
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function GetObjectRight(ADb: TAppDb; const AKind, AName: string): TaRole;
var
  Q: TZQuery;
begin
  Result := arViewer;
  Q := ADb.NewQuery('SELECT min_role FROM _sys_rights WHERE kind = :k AND name = :n');
  try
    Q.ParamByName('k').AsString := AKind;
    Q.ParamByName('n').AsString := AName;
    Q.Open;
    if not Q.EOF then Result := RoleFromName(Q.Fields[0].AsString);
  finally
    Q.Free;
  end;
end;

function CanRun(ADb: TAppDb; const AKind, AName: string): Boolean;
begin
  Result := SessionRole >= GetObjectRight(ADb, AKind, AName);
end;

{ ---------------- packaging ---------------- }

procedure CopyFileBytes(const ASrc, ADst: string);
var
  S, D: TFileStream;
begin
  S := TFileStream.Create(ASrc, fmOpenRead or fmShareDenyNone);
  try
    D := TFileStream.Create(ADst, fmCreate);
    try
      D.CopyFrom(S, 0);
    finally
      D.Free;
    end;
  finally
    S.Free;
  end;
end;

procedure MakeExecutable(const AFile: string);
begin
  {$IFDEF UNIX}
  FpChmod(AFile, &755);
  {$ENDIF}
end;

function ExportApplication(ADb: TAppDb; const ATargetDir, AExePath, ATitle: string): string;
var
  Dir, DbFile, ExeFile, Script, Desktop, Base: string;
  L: TStringList;
begin
  Dir := IncludeTrailingPathDelimiter(ATargetDir);
  ForceDirectories(Dir);
  Base := ATitle;
  if Trim(Base) = '' then Base := 'aplikacija';
  Base := StringReplace(Trim(Base), ' ', '_', [rfReplaceAll]);
  DbFile := Dir + Base + '.db';
  ExeFile := Dir + 'TyphAccess';
  if FileExists(DbFile) then DeleteFile(DbFile);
  ADb.Conn.ExecuteDirect('VACUUM INTO ''' + StringReplace(DbFile, '''', '''''', [rfReplaceAll]) + '''');
  if (AExePath <> '') and FileExists(AExePath) then
  begin
    if FileExists(ExeFile) then DeleteFile(ExeFile);
    CopyFileBytes(AExePath, ExeFile);
    MakeExecutable(ExeFile);
  end;
  { slike: mapa pohrane ide uz izvezenu bazu (osim kad je postavljena vlastita/dijeljena mapa) }
  if Trim(ADb.LoadSetting(StoreSettingKey)) = '' then CopyStoreToFolder(ADb, Dir + Base + '_datoteke');
  Script := Dir + Base + '.sh';
  L := TStringList.Create;
  try
    L.Add('#!/bin/sh');
    L.Add('cd "$(dirname "$0")"');
    L.Add('export DBUS_SESSION_BUS_ADDRESS=disabled:');
    L.Add('exec ./TyphAccess --runtime "' + Base + '.db" "$@"');
    L.SaveToFile(Script);
    MakeExecutable(Script);
    Desktop := Dir + Base + '.desktop';
    L.Clear;
    L.Add('[Desktop Entry]');
    L.Add('Type=Application');
    L.Add('Name=' + ATitle);
    L.Add('Exec=' + Script);
    L.Add('Path=' + ExcludeTrailingPathDelimiter(Dir));
    L.Add('Terminal=false');
    L.SaveToFile(Desktop);
  finally
    L.Free;
  end;
  Result := Dir;
end;

end.
