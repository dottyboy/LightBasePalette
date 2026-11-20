unit ta_filestore;
{ Pohrana datoteka (slike i sl.) izvan baze. U bazi je samo VEZA (tekst); datoteka
  je u mapi pohrane:

    1. varijabla okoline TYPHACCESS_FILES (po računalu: različito na svakom klijentu),
    2. postavka baze "pohrana.mapa" (apsolutna, ili relativna prema mapi SQLite datoteke),
    3. zadano: SQLite -> "<ime baze>_datoteke" pokraj datoteke baze;
       Postgres/MariaDB -> mapa u korisnikovu profilu (NIJE podijeljena: treba postaviti
       dijeljenu mapu da svi klijenti vide iste datoteke).

  Veza je relativna prema korijenu ("slike/kupac/20261103-ime.png"), pa baza i mapa putuju
  zajedno. Dopuštene su i vanjske veze: apsolutni put i http(s):// adresa. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, ta_meta;

var
  { baza čije se datoteke prikazuju (postavlja glavni prozor; testovi ručno) }
  ActiveStoreDb: TAppDb = nil;

const
  StoreSettingKey = 'pohrana.mapa';
  StoreEnvVar = 'TYPHACCESS_FILES';

{ Korijenska mapa pohrane (s završnim separatorom); ASource opisuje odakle je određena,
  AShared je False kad mapa nije podijeljena među klijentima (poslužiteljske baze bez postavke). }
function FileStoreRoot(ADb: TAppDb; out ASource: string; out AShared: Boolean): string;
function FileStoreRootOnly(ADb: TAppDb): string;
procedure SetFileStoreFolder(ADb: TAppDb; const APath: string);

{ Vanjska veza: http(s)://, file:// ili apsolutni put. }
function IsExternalLink(const ALink: string): Boolean;
{ Puni put datoteke za vezu ('' ako se ne može razriješiti ili je URL). }
function ResolveFileLink(ADb: TAppDb; const ALink: string): string;
{ Naziv bez neprikladnih znakova za datoteku; ostaju slova (i UTF-8), znamenke, . _ - }
function SanitizeName(const S: string): string;
{ Podmapa za slike jedne grupe (forma, tablica): 'slike/<naziv>' }
function PictureSubDir(const AGroup: string): string;
{ Kopira datoteku u pohranu (podmapa npr. 'slike/kupac') i vraća vezu. Baca Exception. }
function StoreFile(ADb: TAppDb; const ASrc, ASubDir: string): string;
{ Veza iz sadržaja (npr. slika iz stare BLOB kolone): sprema bajtove, vraća vezu. }
function StoreBytes(ADb: TAppDb; const ABytes, ASubDir, ABaseName: string): string;

{ Slike spremljene u bazu (BLOB) pretvara u datoteke i vezu; vraća broj pretvorenih polja. }
function ConvertBlobPictures(ADb: TAppDb; ALog: TStrings): Integer;
{ Slike ugrađene (base64) u definicije formi i izvješća postaju datoteke i veze 'file:...'.
  Vraća broj pretvorenih slika. }
function ConvertDefinitionPictures(ADb: TAppDb; ALog: TStrings): Integer;

{ Broj datoteka i ukupna veličina u bajtima u pohrani. }
function FileStoreStats(ADb: TAppDb; out ASize: Int64): Integer;
{ Kopira pohranu baze u mapu ADir (sigurnosna kopija). Vraća broj datoteka. }
function CopyStoreToFolder(ADb: TAppDb; const ADir: string): Integer;

{ Kopira sve datoteke iz pohrane izvorne baze u pohranu odredišne (nakon migracije baze). }
function CopyFileStore(ASrc, ADst: TAppDb; ALog: TStrings): Integer;

{ Datoteke u pohrani koje nijedna veza ne koristi (polja Picture, slike u formama i izvješćima).
  AFiles dobiva relativne veze; mapa _neiskoristeno se ne pregledava. Vraća broj. }
function FindOrphanFiles(ADb: TAppDb; AFiles: TStrings): Integer;
{ Neiskorištene datoteke premješta u <pohrana>/_neiskoristeno (ništa se ne briše). }
function MoveOrphanFiles(ADb: TAppDb; ALog: TStrings): Integer;

implementation

uses
  ta_i18n,
  FileUtil, LazFileUtils, ZDataset, ta_types, ta_formdef, ta_reportdef, base64;

function UserStoreDir(ADb: TAppDb): string;
var
  Id: string;
begin
  Id := ADb.Conn.HostName + '_' + ADb.Conn.Database;
  Id := StringReplace(StringReplace(Id, '/', '_', [rfReplaceAll]), '\', '_', [rfReplaceAll]);
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'datoteke' + PathDelim + Id;
end;

function FileStoreRoot(ADb: TAppDb; out ASource: string; out AShared: Boolean): string;
var
  Env, Setting, DbFile, Base: string;
begin
  AShared := True;
  ASource := '';
  Result := '';
  if ADb = nil then Exit;
  DbFile := '';
  if ADb.Kind = dkSqlite then DbFile := ExpandFileName(ADb.Conn.Database);
  Env := GetEnvironmentVariable(StoreEnvVar);
  if Env <> '' then
  begin
    ASource := 'varijabla okoline ' + StoreEnvVar;
    Exit(IncludeTrailingPathDelimiter(ExpandFileName(Env)));
  end;
  Setting := Trim(ADb.LoadSetting(StoreSettingKey));
  if Setting <> '' then
  begin
    ASource := 'postavka baze';
    if FilenameIsAbsolute(Setting) then Result := Setting
    else if DbFile <> '' then Result := ExtractFilePath(DbFile) + Setting
    else Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + Setting;
    Exit(IncludeTrailingPathDelimiter(Result));
  end;
  if DbFile <> '' then
  begin
    Base := ChangeFileExt(ExtractFileName(DbFile), '');
    ASource := 'zadano (pokraj datoteke baze)';
    Exit(ExtractFilePath(DbFile) + Base + '_datoteke' + PathDelim);
  end;
  ASource := 'zadano (korisnikov profil, nije podijeljeno)';
  AShared := False;
  Result := IncludeTrailingPathDelimiter(UserStoreDir(ADb));
end;

function FileStoreRootOnly(ADb: TAppDb): string;
var
  S: string;
  B: Boolean;
begin
  Result := FileStoreRoot(ADb, S, B);
end;

procedure SetFileStoreFolder(ADb: TAppDb; const APath: string);
begin
  ADb.SaveSetting(StoreSettingKey, Trim(APath));
end;

function IsExternalLink(const ALink: string): Boolean;
var
  L: string;
begin
  L := LowerCase(Trim(ALink));
  Result := (Copy(L, 1, 7) = 'http://') or (Copy(L, 1, 8) = 'https://') or (Copy(L, 1, 7) = 'file://') or
    ((L <> '') and FilenameIsAbsolute(Trim(ALink)));
end;

function SafeRelative(const ALink: string): Boolean;
var
  Parts: TStringList;
  I: Integer;
begin
  Result := True;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '/';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := StringReplace(ALink, '\', '/', [rfReplaceAll]);
    for I := 0 to Parts.Count - 1 do
      if Parts[I] = '..' then Exit(False);
  finally
    Parts.Free;
  end;
end;

function ResolveFileLink(ADb: TAppDb; const ALink: string): string;
var
  L: string;
begin
  Result := '';
  L := Trim(ALink);
  if L = '' then Exit;
  if (Copy(LowerCase(L), 1, 7) = 'http://') or (Copy(LowerCase(L), 1, 8) = 'https://') then Exit;
  if Copy(LowerCase(L), 1, 7) = 'file://' then L := Copy(L, 8, MaxInt);
  if FilenameIsAbsolute(L) then Exit(L);
  if not SafeRelative(L) then Exit;
  if ADb = nil then Exit;
  Result := FileStoreRootOnly(ADb) + StringReplace(L, '/', PathDelim, [rfReplaceAll]);
end;

function SanitizeName(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if C in ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-'] then Result := Result + C
    else if C in [' ', '(', ')'] then Result := Result + '_'
    else if Ord(C) >= 128 then Result := Result + C   { UTF-8 slova ostaju }
    else Result := Result + '_';
  end;
  if Result = '' then Result := 'datoteka';
end;

function PictureSubDir(const AGroup: string): string;
begin
  Result := 'slike/' + SanitizeName(AGroup);
end;

function CleanSubDir(const ASubDir: string): string;
begin
  Result := StringReplace(Trim(ASubDir), '\', '/', [rfReplaceAll]);
  while (Result <> '') and (Result[1] = '/') do Delete(Result, 1, 1);
  while (Result <> '') and (Result[Length(Result)] = '/') do Delete(Result, Length(Result), 1);
  if not SafeRelative(Result) then raise Exception.Create(Tr('Disallowed subfolder: ') + ASubDir);
end;

function UniqueName(const ADir, AName: string): string;
var
  Base, Ext: string;
  N: Integer;
begin
  Result := AName;
  if not FileExists(ADir + Result) then Exit;
  Ext := ExtractFileExt(AName);
  Base := Copy(AName, 1, Length(AName) - Length(Ext));
  for N := 2 to 9999 do
  begin
    Result := Base + '-' + IntToStr(N) + Ext;
    if not FileExists(ADir + Result) then Exit;
  end;
  raise Exception.Create(Tr('There is no free file name in ') + ADir);
end;

function StoreFile(ADb: TAppDb; const ASrc, ASubDir: string): string;
var
  Root, Sub, Dir, Name, Rel: string;
begin
  if not FileExists(ASrc) then raise Exception.Create(Tr('There is no file: ') + ASrc);
  Root := FileStoreRootOnly(ADb);
  if Root = '' then raise Exception.Create(Tr('The file store is not available (the database is not open)'));
  { datoteka je već u pohrani: samo veza }
  Rel := ExtractRelativePath(Root, ExpandFileName(ASrc));
  if (Rel <> '') and (Copy(Rel, 1, 2) <> '..') and not FilenameIsAbsolute(Rel) then
    Exit(StringReplace(Rel, PathDelim, '/', [rfReplaceAll]));
  Sub := CleanSubDir(ASubDir);
  Dir := Root;
  if Sub <> '' then Dir := Dir + StringReplace(Sub, '/', PathDelim, [rfReplaceAll]) + PathDelim;
  if not ForceDirectories(Dir) then raise Exception.Create(Tr('Cannot create the folder ') + Dir);
  Name := UniqueName(Dir, FormatDateTime('yyyymmdd', Now) + '-' + SanitizeName(ExtractFileName(ASrc)));
  if not CopyFile(ASrc, Dir + Name, [cffOverwriteFile]) then
    raise Exception.Create(Tr('Copying failed: ') + ASrc + ' → ' + Dir + Name);
  if Sub <> '' then Result := Sub + '/' + Name else Result := Name;
end;

function ImageExtOf(const ABytes: string): string;
begin
  Result := '.bin';
  if (Length(ABytes) > 4) and (Copy(ABytes, 1, 4) = #137'PNG') then Result := '.png'
  else if (Length(ABytes) > 2) and (Copy(ABytes, 1, 2) = #255#216) then Result := '.jpg'
  else if (Length(ABytes) > 3) and (Copy(ABytes, 1, 3) = 'GIF') then Result := '.gif'
  else if (Length(ABytes) > 2) and (Copy(ABytes, 1, 2) = 'BM') then Result := '.bmp';
end;

function StoreBytes(ADb: TAppDb; const ABytes, ASubDir, ABaseName: string): string;
var
  Root, Sub, Dir, Name: string;
  Fs: TFileStream;
begin
  Root := FileStoreRootOnly(ADb);
  if Root = '' then raise Exception.Create(Tr('The file store is not available (the database is not open)'));
  Sub := CleanSubDir(ASubDir);
  Dir := Root;
  if Sub <> '' then Dir := Dir + StringReplace(Sub, '/', PathDelim, [rfReplaceAll]) + PathDelim;
  if not ForceDirectories(Dir) then raise Exception.Create(Tr('Cannot create the folder ') + Dir);
  Name := UniqueName(Dir, SanitizeName(ABaseName) + ImageExtOf(ABytes));
  Fs := TFileStream.Create(Dir + Name, fmCreate);
  try
    if ABytes <> '' then Fs.WriteBuffer(ABytes[1], Length(ABytes));
  finally
    Fs.Free;
  end;
  if Sub <> '' then Result := Sub + '/' + Name else Result := Name;
end;

function ConvertBlobPictures(ADb: TAppDb; ALog: TStrings): Integer;
var
  Tables: TStringList;
  Metas: TFPObjectList;
  I, J: Integer;
  M, Saved: TaFieldMeta;
  Info: TZQuery;
  ColType, Pk, Tmp, Link, Rid: string;
  IsBlob: Boolean;
  Sel, Upd: TZQuery;
  Def: ta_meta.TFieldDef;
  N: Integer;
begin
  Result := 0;
  Tables := ADb.UserTables;
  try
    for I := 0 to Tables.Count - 1 do
    begin
      Metas := ADb.LoadFieldMetas(Tables[I]);
      try
        for J := 0 to Metas.Count - 1 do
        begin
          M := TaFieldMeta(Metas[J]);
          if M.LType <> ltPicture then Continue;
          { je li stupac još BLOB? }
          ColType := '';
          Info := ADb.TableInfo(Tables[I]);
          try
            while not Info.EOF do
            begin
              if SameText(Info.FieldByName('name').AsString, M.FieldName) then ColType := UpperCase(Info.FieldByName('type').AsString);
              Info.Next;
            end;
          finally
            Info.Free;
          end;
          IsBlob := (Pos('BLOB', ColType) > 0) or (Pos('BYTEA', ColType) > 0);
          if not IsBlob then Continue;
          Pk := ADb.PrimaryKeyOf(Tables[I]);
          if Pk = '' then
          begin
            ALog.Add('preskočeno ' + Tables[I] + '.' + M.FieldName + ': tablica nema primarni ključ');
            Continue;
          end;
          Saved := M.Clone;
          try
            Tmp := M.FieldName + '__veza';
            Def.Name := Tmp;
            Def.SqlType := 'TEXT';
            Def.PrimaryKey := False;
            Def.NotNull := False;
            Def.Meta := nil;
            Def.RefTable := ''; Def.RefField := ''; Def.OnDelete := '';
            ADb.AddColumn(Tables[I], Def);
            Sel := ADb.NewQuery('SELECT ' + ADb.QuoteId(Pk) + ', ' + ADb.QuoteId(M.FieldName) + ' FROM ' + ADb.QuoteId(Tables[I]) +
              ' WHERE ' + ADb.QuoteId(M.FieldName) + ' IS NOT NULL');
            Upd := ADb.NewQuery('UPDATE ' + ADb.QuoteId(Tables[I]) + ' SET ' + ADb.QuoteId(Tmp) + ' = :l WHERE ' + ADb.QuoteId(Pk) + ' = :k');
            N := 0;
            try
              Sel.Open;
              while not Sel.EOF do
              begin
                Rid := Sel.Fields[0].AsString;
                if Sel.Fields[1].AsString <> '' then
                begin
                  Link := StoreBytes(ADb, Sel.Fields[1].AsString, 'slike/' + Tables[I], Rid + '-' + M.FieldName);
                  Upd.ParamByName('l').AsString := Link;
                  Upd.ParamByName('k').AsString := Rid;
                  Upd.ExecSQL;
                  Inc(N);
                end;
                Sel.Next;
              end;
            finally
              Sel.Free;
              Upd.Free;
            end;
            ADb.DropColumn(Tables[I], M.FieldName);
            ADb.RenameColumn(Tables[I], Tmp, Saved.FieldName);
            Saved.TableName := Tables[I];
            ADb.SaveFieldMeta(Saved);
            ALog.Add(Tables[I] + '.' + Saved.FieldName + ': ' + IntToStr(N) + ' slika prebačeno u datoteke');
            Inc(Result);
          finally
            Saved.Free;
          end;
        end;
      finally
        Metas.Free;
      end;
    end;
  finally
    Tables.Free;
  end;
end;

function CopyTree(const ASrc, ADst: string; var ACount: Integer): Boolean;
var
  SR: TSearchRec;
begin
  Result := True;
  if not ForceDirectories(ADst) then Exit(False);
  if FindFirst(ASrc + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) <> 0 then
          Result := CopyTree(ASrc + SR.Name + PathDelim, ADst + SR.Name + PathDelim, ACount) and Result
        else if CopyFile(ASrc + SR.Name, ADst + SR.Name, [cffOverwriteFile]) then Inc(ACount)
        else Result := False;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function CountTree(const ADir: string; var ASize: Int64): Integer;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(ADir + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) <> 0 then Inc(Result, CountTree(ADir + SR.Name + PathDelim, ASize))
        else begin Inc(Result); Inc(ASize, SR.Size); end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function FileStoreStats(ADb: TAppDb; out ASize: Int64): Integer;
var
  R: string;
begin
  ASize := 0;
  Result := 0;
  R := FileStoreRootOnly(ADb);
  if (R <> '') and DirectoryExists(R) then Result := CountTree(R, ASize);
end;

function CopyStoreToFolder(ADb: TAppDb; const ADir: string): Integer;
var
  S: string;
begin
  Result := 0;
  S := FileStoreRootOnly(ADb);
  if (S = '') or not DirectoryExists(S) then Exit;
  CopyTree(S, IncludeTrailingPathDelimiter(ADir), Result);
end;

function CopyFileStore(ASrc, ADst: TAppDb; ALog: TStrings): Integer;
var
  S, D: string;
begin
  Result := 0;
  S := FileStoreRootOnly(ASrc);
  D := FileStoreRootOnly(ADst);
  if (S = '') or (D = '') or not DirectoryExists(S) then Exit;
  if SameFileName(S, D) then
  begin
    ALog.Add('datoteke: ista mapa pohrane, ništa za kopirati');
    Exit;
  end;
  if CopyTree(S, D, Result) then ALog.Add('datoteke: ' + IntToStr(Result) + ' kopirano u ' + D)
  else ALog.Add('UPOZORENJE datoteke: kopirano ' + IntToStr(Result) + ', ali nisu sve datoteke prenesene u ' + D);
end;

function ConvertDefinitionPictures(ADb: TAppDb; ALog: TStrings): Integer;
var
  Names: TStringList;
  I, J, Done: Integer;
  Form: TaFormDef;
  Rep: TaReportDef;
  Raw: string;

  { true ako je slika u kontroli pretvorena }
  function Fix(AC: TaControlDef; const AObj, ASub: string): Boolean;
  var
    B: string;
  begin
    Result := False;
    B := AC.GetX('picture');
    if (B = '') or (Copy(B, 1, 5) = 'file:') then Exit;
    try
      Raw := DecodeStringBase64(B);
    except
      ALog.Add('UPOZORENJE ' + AObj + '.' + AC.Name + ': slika nije ispravna, preskočeno');
      Exit;
    end;
    if Raw = '' then Exit;
    AC.SetX('picture', 'file:' + StoreBytes(ADb, Raw, ASub, AObj + '-' + AC.Name));
    Result := True;
  end;

begin
  Result := 0;
  Names := ADb.ListObjects('_sys_forms');
  try
    for I := 0 to Names.Count - 1 do
    begin
      Form := TaFormDef.Create;
      try
        Form.FromJson(ADb.LoadObject('_sys_forms', Names[I]));
        Done := 0;
        for J := 0 to Form.Count - 1 do
          if Fix(Form[J], Names[I], 'slike/_forme') then Inc(Done);
        if Done > 0 then
        begin
          ADb.SaveObject('_sys_forms', Names[I], Form.ToJson);
          ALog.Add('forma ' + Names[I] + ': ' + IntToStr(Done) + ' slika u datoteke');
          Inc(Result, Done);
        end;
      finally
        Form.Free;
      end;
    end;
  finally
    Names.Free;
  end;
  Names := ADb.ListObjects('_sys_reports');
  try
    for I := 0 to Names.Count - 1 do
    begin
      Rep := TaReportDef.Create;
      try
        Rep.FromJson(ADb.LoadObject('_sys_reports', Names[I]));
        Done := 0;
        for J := 0 to Rep.Count - 1 do
          if Fix(Rep[J], Names[I], 'slike/_izvjesca') then Inc(Done);
        if Done > 0 then
        begin
          ADb.SaveObject('_sys_reports', Names[I], Rep.ToJson);
          ALog.Add('izvješće ' + Names[I] + ': ' + IntToStr(Done) + ' slika u datoteke');
          Inc(Result, Done);
        end;
      finally
        Rep.Free;
      end;
    end;
  finally
    Names.Free;
  end;
end;


const
  OrphanDir = '_neiskoristeno';

{ skuplja sve veze koje baza koristi: polja Picture u tablicama i slike u formama/izvješćima }
procedure CollectLinks(ADb: TAppDb; ALinks: TStringList);
var
  Tables, Names: TStringList;
  Metas: TFPObjectList;
  I, J: Integer;
  M: TaFieldMeta;
  Q: TZQuery;
  Form: TaFormDef;
  Rep: TaReportDef;
  K: string;
begin
  ALinks.Sorted := True;
  ALinks.Duplicates := dupIgnore;
  Tables := ADb.UserTables;
  try
    for I := 0 to Tables.Count - 1 do
    begin
      Metas := ADb.LoadFieldMetas(Tables[I]);
      try
        for J := 0 to Metas.Count - 1 do
        begin
          M := TaFieldMeta(Metas[J]);
          if M.LType <> ltPicture then Continue;
          Q := ADb.NewQuery('SELECT ' + ADb.QuoteId(M.FieldName) + ' FROM ' + ADb.QuoteId(Tables[I]) +
            ' WHERE ' + ADb.QuoteId(M.FieldName) + ' IS NOT NULL');
          try
            Q.Open;
            while not Q.EOF do
            begin
              K := Q.Fields[0].AsString;
              if K <> '' then ALinks.Add(K);
              Q.Next;
            end;
          finally
            Q.Free;
          end;
        end;
      finally
        Metas.Free;
      end;
    end;
  finally
    Tables.Free;
  end;
  Names := ADb.ListObjects('_sys_forms');
  try
    for I := 0 to Names.Count - 1 do
    begin
      Form := TaFormDef.Create;
      try
        Form.FromJson(ADb.LoadObject('_sys_forms', Names[I]));
        for J := 0 to Form.Count - 1 do
        begin
          K := Form[J].GetX('picture');
          if Copy(K, 1, 5) = 'file:' then ALinks.Add(Copy(K, 6, MaxInt));
        end;
      finally
        Form.Free;
      end;
    end;
  finally
    Names.Free;
  end;
  Names := ADb.ListObjects('_sys_reports');
  try
    for I := 0 to Names.Count - 1 do
    begin
      Rep := TaReportDef.Create;
      try
        Rep.FromJson(ADb.LoadObject('_sys_reports', Names[I]));
        for J := 0 to Rep.Count - 1 do
        begin
          K := Rep[J].GetX('picture');
          if Copy(K, 1, 5) = 'file:' then ALinks.Add(Copy(K, 6, MaxInt));
        end;
      finally
        Rep.Free;
      end;
    end;
  finally
    Names.Free;
  end;
end;

procedure WalkFiles(const ARoot, ARel: string; AList: TStrings);
var
  SR: TSearchRec;
begin
  if FindFirst(ARoot + ARel + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if (ARel = '') and (SR.Name = OrphanDir) then Continue;
          WalkFiles(ARoot, ARel + SR.Name + '/', AList);
        end
        else AList.Add(ARel + SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function FindOrphanFiles(ADb: TAppDb; AFiles: TStrings): Integer;
var
  Root: string;
  Links, All: TStringList;
  I: Integer;
begin
  AFiles.Clear;
  Root := FileStoreRootOnly(ADb);
  if (Root = '') or not DirectoryExists(Root) then Exit(0);
  Links := TStringList.Create;
  All := TStringList.Create;
  try
    CollectLinks(ADb, Links);
    WalkFiles(Root, '', All);
    All.Sort;
    for I := 0 to All.Count - 1 do
      if Links.IndexOf(All[I]) < 0 then AFiles.Add(All[I]);
  finally
    Links.Free;
    All.Free;
  end;
  Result := AFiles.Count;
end;

function MoveOrphanFiles(ADb: TAppDb; ALog: TStrings): Integer;
var
  Root, Dest: string;
  Orph: TStringList;
  I: Integer;
begin
  Result := 0;
  Root := FileStoreRootOnly(ADb);
  Orph := TStringList.Create;
  try
    FindOrphanFiles(ADb, Orph);
    for I := 0 to Orph.Count - 1 do
    begin
      Dest := Root + OrphanDir + PathDelim + StringReplace(Orph[I], '/', PathDelim, [rfReplaceAll]);
      if not ForceDirectories(ExtractFilePath(Dest)) then
      begin
        ALog.Add('UPOZORENJE: ne mogu napraviti mapu za ' + Orph[I]);
        Continue;
      end;
      if FileExists(Dest) then Dest := Dest + '.' + FormatDateTime('hhnnss', Now);
      if RenameFile(Root + StringReplace(Orph[I], '/', PathDelim, [rfReplaceAll]), Dest) then
      begin
        ALog.Add('premješteno: ' + Orph[I]);
        Inc(Result);
      end
      else ALog.Add('UPOZORENJE: nije premješteno ' + Orph[I]);
    end;
  finally
    Orph.Free;
  end;
end;

end.
