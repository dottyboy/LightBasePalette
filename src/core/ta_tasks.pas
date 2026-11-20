unit ta_tasks;
{ Planer zadataka: sigurnosne kopije, izvoz izvjesca u PDF, izvoz u CSV, SQL i makroi
  po rasporedu. Zadaci su u _sys_tasks; izvrsava ih aplikacija dok je otvorena
  (mjerac) ili naredba "TyphAccess --run-tasks baza.db". }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, ZDataset, ta_meta;

type
  TaTask = record
    Name, Kind, Arg, Arg2, Schedule: string;
    Enabled: Boolean;
    LastRun: TDateTime;
    LastResult: string;
  end;
  TaTasks = array of TaTask;

  TSchedKind = (skInterval, skDaily, skWeekly, skMonthly);
  TSchedule = record
    Kind: TSchedKind;
    Minutes: Integer;      { interval }
    Weekday: Integer;      { 1 = ponedjeljak .. 7 = nedjelja }
    Day: Integer;          { dan u mjesecu }
    Hour, Min: Integer;
  end;

const
  TaskKinds: array[0..4] of string = ('backup', 'report_pdf', 'export_csv', 'sql', 'macro');

var
  { PDF izvoz izvjesca nalazi se u GUI sloju, pa ga ta jedinica registrira }
  TaskPdfHook: function(ADb: TAppDb; const AReport, AFile: string; out AErr: string): Boolean = nil;

function ParseSchedule(const S: string; out ASch: TSchedule; out AErr: string): Boolean;
{ Zadnje vrijeme izvrsavanja rasporeda koje je proslo (ne vrijedi za interval). }
function PrevOccurrence(const ASch: TSchedule; ANow: TDateTime): TDateTime;
function IsDue(const ASch: TSchedule; ALastRun, ANow: TDateTime): Boolean;

function LoadTasks(ADb: TAppDb): TaTasks;
procedure SaveTask(ADb: TAppDb; const ATask: TaTask);
procedure DeleteTask(ADb: TAppDb; const AName: string);
{ Izvrsi jedan zadatak odmah; Msg je rezultat ili greska. }
function RunTask(ADb: TAppDb; const ATask: TaTask; out AMsg: string): Boolean;
{ Izvrsi sve zadatke koji su na redu; vraca koliko ih je izvrseno. }
function RunDueTasks(ADb: TAppDb; ANow: TDateTime; ALog: TStrings): Integer;

implementation

uses
  ta_importexport, ta_script;

const
  DayNames: array[1..7] of string = ('pon', 'uto', 'sri', 'cet', 'pet', 'sub', 'ned');

function Tok(const S: string; AIndex: Integer): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Delimiter := ' ';
    L.StrictDelimiter := True;
    L.DelimitedText := Trim(S);
    if (AIndex < L.Count) then Result := L[AIndex] else Result := '';
  finally
    L.Free;
  end;
end;

function ParseTime(const S: string; out H, M: Integer): Boolean;
var
  P: Integer;
begin
  P := Pos(':', S);
  Result := False;
  if P < 2 then Exit;
  H := StrToIntDef(Copy(S, 1, P - 1), -1);
  M := StrToIntDef(Copy(S, P + 1, MaxInt), -1);
  Result := (H >= 0) and (H < 24) and (M >= 0) and (M < 60);
end;

function ParseSchedule(const S: string; out ASch: TSchedule; out AErr: string): Boolean;
var
  T0, T1, T2, T3, U: string;
  I, N: Integer;
begin
  Result := False;
  AErr := '';
  FillChar(ASch, SizeOf(ASch), 0);
  T0 := LowerCase(Tok(S, 0));
  T1 := LowerCase(Tok(S, 1));
  T2 := LowerCase(Tok(S, 2));
  T3 := LowerCase(Tok(S, 3));
  if (Copy(T0, 1, 5) = 'svaki') and (T1 = 'dan') then
  begin
    ASch.Kind := skDaily;
    if not ParseTime(T2, ASch.Hour, ASch.Min) then begin AErr := 'Očekujem vrijeme (HH:MM): ' + T2; Exit; end;
    Exit(True);
  end;
  if Copy(T0, 1, 5) = 'svaki' then
  begin
    N := StrToIntDef(T1, 0);
    U := T2;
    if N <= 0 then begin AErr := 'Očekujem broj iza "svakih"'; Exit; end;
    if (Copy(U, 1, 3) = 'min') then ASch.Minutes := N
    else if (U = 'h') or (Copy(U, 1, 3) = 'sat') then ASch.Minutes := N * 60
    else begin AErr := 'Jedinica mora biti min ili h'; Exit; end;
    ASch.Kind := skInterval;
    Exit(True);
  end;
  if Copy(T0, 1, 4) = 'dnev' then
  begin
    ASch.Kind := skDaily;
    if not ParseTime(T1, ASch.Hour, ASch.Min) then begin AErr := 'Očekujem vrijeme (HH:MM): ' + T1; Exit; end;
    Exit(True);
  end;
  if Copy(T0, 1, 4) = 'tjed' then
  begin
    ASch.Kind := skWeekly;
    ASch.Weekday := 0;
    for I := 1 to 7 do
      if Copy(T1, 1, 3) = DayNames[I] then ASch.Weekday := I;
    if ASch.Weekday = 0 then begin AErr := 'Dan mora biti pon, uto, sri, cet, pet, sub ili ned'; Exit; end;
    if not ParseTime(T2, ASch.Hour, ASch.Min) then begin AErr := 'Očekujem vrijeme (HH:MM): ' + T2; Exit; end;
    Exit(True);
  end;
  if Copy(T0, 1, 5) = 'mjese' then
  begin
    ASch.Kind := skMonthly;
    ASch.Day := StrToIntDef(T1, 0);
    if (ASch.Day < 1) or (ASch.Day > 31) then begin AErr := 'Dan u mjesecu mora biti 1 do 31'; Exit; end;
    if not ParseTime(T2, ASch.Hour, ASch.Min) then begin AErr := 'Očekujem vrijeme (HH:MM): ' + T2; Exit; end;
    Exit(True);
  end;
  AErr := 'Raspored: "svakih 30 min", "dnevno 02:00", "tjedno pon 08:00" ili "mjesecno 1 03:00"';
  if T3 = '' then;
end;

function MonthDay(AYear, AMonth, ADay: Integer): TDateTime;
var
  D: Integer;
begin
  D := ADay;
  if D > DaysInAMonth(AYear, AMonth) then D := DaysInAMonth(AYear, AMonth);
  Result := EncodeDate(AYear, AMonth, D);
end;

function PrevOccurrence(const ASch: TSchedule; ANow: TDateTime): TDateTime;
var
  T: TDateTime;
  I: Integer;
  Y, M, D: Word;
begin
  Result := 0;
  case ASch.Kind of
    skDaily:
      begin
        T := Trunc(ANow) + EncodeTime(ASch.Hour, ASch.Min, 0, 0);
        if T > ANow then T := T - 1;
        Result := T;
      end;
    skWeekly:
      for I := 0 to 7 do
      begin
        T := Trunc(ANow) - I + EncodeTime(ASch.Hour, ASch.Min, 0, 0);
        if (DayOfTheWeek(T) = ASch.Weekday) and (T <= ANow) then Exit(T);
      end;
    skMonthly:
      begin
        DecodeDate(ANow, Y, M, D);
        T := MonthDay(Y, M, ASch.Day) + EncodeTime(ASch.Hour, ASch.Min, 0, 0);
        if T > ANow then
        begin
          Dec(M);
          if M = 0 then begin M := 12; Dec(Y); end;
          T := MonthDay(Y, M, ASch.Day) + EncodeTime(ASch.Hour, ASch.Min, 0, 0);
        end;
        Result := T;
      end;
  end;
end;

function IsDue(const ASch: TSchedule; ALastRun, ANow: TDateTime): Boolean;
begin
  if ASch.Kind = skInterval then
    Result := (ALastRun = 0) or (ANow - ALastRun >= ASch.Minutes / 1440)
  else
    Result := PrevOccurrence(ASch, ANow) > ALastRun;
end;

{ ---------------- storage ---------------- }

function IsoToDt(const S: string): TDateTime;
var
  FS: TFormatSettings;
begin
  Result := 0;
  if Trim(S) = '' then Exit;
  FS := DefaultFormatSettings;
  FS.DateSeparator := '-'; FS.TimeSeparator := ':';
  FS.ShortDateFormat := 'yyyy-mm-dd'; FS.LongTimeFormat := 'hh:nn:ss';
  if not TryStrToDateTime(S, Result, FS) then Result := 0;
end;

function DtToIso(ADt: TDateTime): string;
begin
  if ADt = 0 then Result := '' else Result := FormatDateTime('yyyy"-"mm"-"dd" "hh":"nn":"ss', ADt);
end;

procedure EnsureTable(ADb: TAppDb);
begin
  ADb.Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_tasks (name TEXT PRIMARY KEY, kind TEXT, ' +
    'arg TEXT, arg2 TEXT, schedule TEXT, enabled INTEGER, last_run TEXT, last_result TEXT)');
end;

function LoadTasks(ADb: TAppDb): TaTasks;
var
  Q: TZQuery;
  N: Integer;
begin
  EnsureTable(ADb);
  SetLength(Result, 0);
  Q := ADb.NewQuery('SELECT name, kind, arg, arg2, schedule, enabled, last_run, last_result FROM _sys_tasks ORDER BY name');
  try
    Q.Open;
    N := 0;
    while not Q.EOF do
    begin
      SetLength(Result, N + 1);
      Result[N].Name := Q.Fields[0].AsString;
      Result[N].Kind := Q.Fields[1].AsString;
      Result[N].Arg := Q.Fields[2].AsString;
      Result[N].Arg2 := Q.Fields[3].AsString;
      Result[N].Schedule := Q.Fields[4].AsString;
      Result[N].Enabled := Q.Fields[5].AsInteger <> 0;
      Result[N].LastRun := IsoToDt(Q.Fields[6].AsString);
      Result[N].LastResult := Q.Fields[7].AsString;
      Inc(N);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure SaveTask(ADb: TAppDb; const ATask: TaTask);
var
  Q: TZQuery;
begin
  EnsureTable(ADb);
  Q := ADb.NewQuery(ADb.UpsertSql('_sys_tasks', 'name',
    'name, kind, arg, arg2, schedule, enabled, last_run, last_result', ':n, :k, :a, :b, :s, :e, :l, :r'));
  try
    Q.ParamByName('n').AsString := ATask.Name;
    Q.ParamByName('k').AsString := ATask.Kind;
    Q.ParamByName('a').AsString := ATask.Arg;
    Q.ParamByName('b').AsString := ATask.Arg2;
    Q.ParamByName('s').AsString := ATask.Schedule;
    Q.ParamByName('e').AsInteger := Ord(ATask.Enabled);
    Q.ParamByName('l').AsString := DtToIso(ATask.LastRun);
    Q.ParamByName('r').AsString := ATask.LastResult;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure DeleteTask(ADb: TAppDb; const AName: string);
var
  Q: TZQuery;
begin
  EnsureTable(ADb);
  Q := ADb.NewQuery('DELETE FROM _sys_tasks WHERE name = :n');
  try
    Q.ParamByName('n').AsString := AName;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

{ ---------------- execution ---------------- }

function SafeName(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if not (Result[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-']) and (Ord(Result[I]) < 128) then Result[I] := '_';
end;

procedure PruneBackups(const AFolder, ABase: string; AKeep: Integer);
var
  SR: TSearchRec;
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(AFolder) + ABase + '_*.db', faAnyFile, SR) = 0 then
    begin
      repeat
        L.Add(SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    L.Sort;
    for I := 0 to L.Count - AKeep - 1 do
      DeleteFile(IncludeTrailingPathDelimiter(AFolder) + L[I]);
  finally
    L.Free;
  end;
end;

var
  TaskMsgs: string;

procedure TaskMessage(const AMsg: string);
begin
  if TaskMsgs <> '' then TaskMsgs := TaskMsgs + ' | ';
  TaskMsgs := TaskMsgs + AMsg;
end;

function RunTaskInner(ADb: TAppDb; const ATask: TaTask; out AMsg: string): Boolean; forward;

{ zadatak radi bez korisnika: upiti s parametrima ne pitaju (nepoznato = NULL), a poruke makroa idu u rezultat }
function RunTask(ADb: TAppDb; const ATask: TaTask; out AMsg: string): Boolean;
var
  Old: procedure(const AMsg: string);
begin
  Old := OnScriptMessage;
  OnScriptMessage := @TaskMessage;
  TaskMsgs := '';
  Scripts(ADb);          { funkcije iz modula moraju biti dostupne izrazima u izvjescima }
  Inc(ADb.QuietParams);
  try
    Result := RunTaskInner(ADb, ATask, AMsg);
    if (TaskMsgs <> '') and Result then AMsg := AMsg + ': ' + TaskMsgs;
  finally
    Dec(ADb.QuietParams);
    OnScriptMessage := Old;
  end;
end;

function RunTaskInner(ADb: TAppDb; const ATask: TaTask; out AMsg: string): Boolean;
var
  Dir, Base, Dest, Err: string;
  Keep: Integer;
  Ctx: TaScriptContext;
begin
  Result := False;
  AMsg := '';
  try
    if ATask.Kind = 'backup' then
    begin
      Dir := Trim(ATask.Arg);
      if Dir = '' then begin AMsg := 'Nije zadana mapa'; Exit; end;
      ForceDirectories(Dir);
      Base := SafeName(ChangeFileExt(ExtractFileName(ADb.Conn.Database), ''));
      if Base = '' then Base := 'baza';
      Dest := IncludeTrailingPathDelimiter(Dir) + Base + '_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.db';
      Keep := 1;
      while FileExists(Dest) do
      begin
        Dest := IncludeTrailingPathDelimiter(Dir) + Base + '_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '_' + IntToStr(Keep) + '.db';
        Inc(Keep);
      end;
      ADb.Conn.ExecuteDirect('VACUUM INTO ' + ADb.QuoteLit(Dest));
      Keep := StrToIntDef(Trim(ATask.Arg2), 10);
      if Keep < 1 then Keep := 1;
      PruneBackups(Dir, Base, Keep);
      AMsg := 'Kopija: ' + Dest;
      Exit(True);
    end;
    if ATask.Kind = 'report_pdf' then
    begin
      Dir := Trim(ATask.Arg2);
      if (Trim(ATask.Arg) = '') or (Dir = '') then begin AMsg := 'Treba izvješće i mapa'; Exit; end;
      if not Assigned(TaskPdfHook) then begin AMsg := 'PDF izvoz nije dostupan'; Exit; end;
      ForceDirectories(Dir);
      Dest := IncludeTrailingPathDelimiter(Dir) + SafeName(ATask.Arg) + '_' + FormatDateTime('yyyymmdd', Now) + '.pdf';
      if not TaskPdfHook(ADb, ATask.Arg, Dest, Err) then begin AMsg := Err; Exit; end;
      AMsg := 'PDF: ' + Dest;
      Exit(True);
    end;
    if ATask.Kind = 'export_csv' then
    begin
      Dir := Trim(ATask.Arg2);
      if (Trim(ATask.Arg) = '') or (Dir = '') then begin AMsg := 'Treba tablica/upit i mapa'; Exit; end;
      ForceDirectories(Dir);
      Dest := IncludeTrailingPathDelimiter(Dir) + SafeName(ATask.Arg) + '_' + FormatDateTime('yyyymmdd', Now) + '.csv';
      ExportCsv(ADb, Trim(ATask.Arg), Dest, ';');
      AMsg := 'CSV: ' + Dest;
      Exit(True);
    end;
    if ATask.Kind = 'sql' then
    begin
      if Trim(ATask.Arg) = '' then begin AMsg := 'Nema SQL naredbe'; Exit; end;
      ADb.Conn.ExecuteDirect(ATask.Arg);
      AMsg := 'SQL izvršen';
      Exit(True);
    end;
    if ATask.Kind = 'macro' then
    begin
      if ADb.LoadObject('_sys_macros', Trim(ATask.Arg)) = '' then begin AMsg := 'Nema makroa: ' + ATask.Arg; Exit; end;
      Ctx := TaScriptContext.Create(ADb);
      try
        RunMacroByName(Ctx, Trim(ATask.Arg));
      finally
        Ctx.Free;
      end;
      AMsg := 'Makro izvršen';
      Exit(True);
    end;
    AMsg := 'Nepoznata vrsta zadatka: ' + ATask.Kind;
  except
    on E: Exception do begin AMsg := E.Message; Result := False; end;
  end;
end;

function RunDueTasks(ADb: TAppDb; ANow: TDateTime; ALog: TStrings): Integer;
var
  L: TaTasks;
  I: Integer;
  Sch: TSchedule;
  Err, Msg: string;
  Ok: Boolean;
begin
  Result := 0;
  L := LoadTasks(ADb);
  for I := 0 to High(L) do
  begin
    if not L[I].Enabled then Continue;
    if not ParseSchedule(L[I].Schedule, Sch, Err) then Continue;
    if not IsDue(Sch, L[I].LastRun, ANow) then Continue;
    Ok := RunTask(ADb, L[I], Msg);
    L[I].LastRun := ANow;
    if Ok then L[I].LastResult := 'OK: ' + Msg else L[I].LastResult := 'GREŠKA: ' + Msg;
    SaveTask(ADb, L[I]);
    if ALog <> nil then ALog.Add(L[I].Name + ' - ' + L[I].LastResult);
    Inc(Result);
  end;
end;

end.
