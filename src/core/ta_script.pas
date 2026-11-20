unit ta_script;
{ Scripting: modules (PascalScript source kept in _sys_modules), macros (one
  action per line kept in _sys_macros) and the context through which both talk
  to the running form.

  A module holds procedures and functions only - the engine adds the closing
  "begin end." itself. All modules are compiled together, so they can call
  each other. Functions are also callable from expressions: =Dvaput([iznos]). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Variants, DB, Controls, Dialogs, uPSComponent, uPSRuntime, uPSCompiler, uPSUtils,
  ZDataset, Forms, LCLIntf, FileUtil, ta_meta, ta_expr, ta_exprdb, ta_parse, ta_blocks, ta_maint, ta_importexport;

var
  { pokrece 4GL program zadan tekstom (postavlja GUI jedinica); Result = izlazni kod }
  OnRunFglText: function(ADb: TAppDb; const AText: string): Integer = nil;

type
  { What a script or macro can reach. The base class works without a form
    (database actions only); the form runtime derives from it. }
  TaScriptContext = class
  public
    Db: TAppDb;
    Cancelled: Boolean;
    { varijable makroa (let ime = izraz): vrijede dok se najvisi makro izvodi }
    Vars: TStringList;
    MacroLevel: Integer;
    constructor Create(ADb: TAppDb);
    destructor Destroy; override;
    procedure SetVar(const AName: string; const AValue: Variant);
    function HasVar(const AName: string): Boolean;
    function GetVar(const AName: string): Variant;
    function GetValue(const AName: string): string; virtual;
    procedure SetValue(const AName, AValue: string); virtual;
    function EvalV(const AExpr: string): Variant; virtual;
    function Eval(const AExpr: string): string;
    procedure DoAction(const AAction: string); virtual;
    { dokument iz dokumenta: izvor [WHERE uvjet] -> cilj : polje = izraz, ... }
    procedure DoCopyRows(const AArg: string);
    { actions the base class does not know }
    procedure DoOther(const AVerb, AArg: string); virtual;
    procedure SetVisible(const AName: string; AValue: Boolean); virtual;
    procedure SetEnabled(const AName: string; AValue: Boolean); virtual;
    procedure SetCaption(const AName, AValue: string); virtual;
    procedure FocusControl(const AName: string); virtual;
    procedure Cancel;
  end;

  TaScripts = class
  private
    FDb: TAppDb;
    FScript: TPSScript;
    FSignature: string;
    FReady: Boolean;
    FError: string;
    FNames: TStringList;
    procedure ScriptCompile(Sender: TPSScript);
    function SourceText(const AReplaceName, AReplaceText: string; out ALineOffset: Integer): string;
    function Compile(const ASource: string; out AErrors: string): Boolean;
  public
    constructor Create(ADb: TAppDb);
    destructor Destroy; override;
    { true when the stored modules compile }
    function Ensure: Boolean;
    function HasProc(const AName: string): Boolean;
    { Compile the stored modules with AText standing in for module AName. }
    function Check(const AName, AText: string; out AErrors: string): Boolean;
    function CallProc(ACtx: TaScriptContext; const AName: string; const AArgs: array of Variant;
      out AResult: Variant): Boolean;
    property LastError: string read FError;
  end;

var
  { set to capture messages instead of showing dialogs (tests) }
  OnScriptMessage: procedure(const AMsg: string) = nil;
  { pitanja iz makroa (ask / input); bez njih se koriste standardni dijalozi }
  OnScriptAsk: function(const AMsg: string): Boolean = nil;
  OnScriptInput: function(const APrompt: string; out AValue: string): Boolean = nil;

procedure ScriptNotify(const AMsg: string);
function Scripts(ADb: TAppDb): TaScripts;
procedure RunMacro(ACtx: TaScriptContext; const AText: string; ADepth: Integer = 0);
procedure RunMacroByName(ACtx: TaScriptContext; const AName: string; ADepth: Integer = 0);
{ names of the functions a script can call, as "declaration" lines, for the editor help }
function ScriptHelpLines: TStringList;
function MacroHelpLines: TStringList;
procedure ResetScripts;

implementation

uses
  ta_i18n;


var
  GScripts: TaScripts = nil;
  CurCtx: TaScriptContext = nil;
  FallbackCtx: TaScriptContext = nil;

procedure ScriptNotify(const AMsg: string);
begin
  if Assigned(OnScriptMessage) then OnScriptMessage(AMsg) else ShowMessage(AMsg);
end;

{ ---------------- context ---------------- }

type
  TNullHost = class(TaExprHost)
  public
    Db: TAppDb;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
  end;

function TNullHost.FieldValue(const AName: string): Variant;
begin
  Result := Null;
end;

function TNullHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TNullHost.Variable(const AName: string): Variant;
begin
  Result := Null;
end;

function TNullHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  Result := DbDomain(Db, AFunc, AExpr, ADomain, ACriteria);
end;

constructor TaScriptContext.Create(ADb: TAppDb);
begin
  Db := ADb;
  Vars := TStringList.Create;
end;

destructor TaScriptContext.Destroy;
begin
  Vars.Free;
  inherited Destroy;
end;

{ vrijednost se pamti kao "n:broj", "s:tekst" ili "z:" (prazno) }
procedure TaScriptContext.SetVar(const AName: string; const AValue: Variant);
var
  K, V: string;
  D: Double;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  K := LowerCase(Trim(AName));
  if VarIsNull(AValue) or VarIsEmpty(AValue) then V := 'z:'
  else if VarIsStr(AValue) then V := 's:' + VarToStr(AValue)
  else if VarType(AValue) = varBoolean then
  begin
    if AValue then V := 'n:1' else V := 'n:0';
  end
  else
  begin
    D := AValue;
    V := 'n:' + SysUtils.FloatToStr(D, FS);
  end;
  Vars.Values[K] := V;
end;

function TaScriptContext.HasVar(const AName: string): Boolean;
begin
  Result := Vars.IndexOfName(LowerCase(Trim(AName))) >= 0;
end;

function TaScriptContext.GetVar(const AName: string): Variant;
var
  V: string;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  V := Vars.Values[LowerCase(Trim(AName))];
  if (V = '') or (Copy(V, 1, 2) = 'z:') then Result := Null
  else if Copy(V, 1, 2) = 'n:' then Result := StrToFloatDef(Copy(V, 3, MaxInt), 0, FS)
  else Result := Copy(V, 3, MaxInt);
end;

function TaScriptContext.GetValue(const AName: string): string;
begin
  Result := '';
end;

procedure TaScriptContext.SetValue(const AName, AValue: string);
begin
end;

function TaScriptContext.EvalV(const AExpr: string): Variant;
var
  H: TNullHost;
begin
  H := TNullHost.Create;
  try
    H.Db := Db;
    Result := EvalExpr(AExpr, H);
  finally
    H.Free;
  end;
end;

function TaScriptContext.Eval(const AExpr: string): string;
begin
  Result := FormatValue(EvalV(AExpr), '');
end;

procedure TaScriptContext.Cancel;
begin
  Cancelled := True;
end;

procedure TaScriptContext.SetVisible(const AName: string; AValue: Boolean);
begin
end;

procedure TaScriptContext.SetEnabled(const AName: string; AValue: Boolean);
begin
end;

procedure TaScriptContext.SetCaption(const AName, AValue: string);
begin
end;

procedure TaScriptContext.FocusControl(const AName: string);
begin
end;

procedure TaScriptContext.DoOther(const AVerb, AArg: string);
begin
  ScriptNotify(Tr('Unknown action: ') + AVerb);
end;

function SafeIdent(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit(False);
end;

{ zarezi izvan navodnika i zagrada }
procedure SplitMapping(const S: string; AOut: TStrings);
var
  I, Depth: Integer;
  InQ: Boolean;
  Cur: string;
begin
  Cur := '';
  Depth := 0;
  InQ := False;
  for I := 1 to Length(S) do
  begin
    if S[I] = '''' then InQ := not InQ
    else if not InQ then
    begin
      if S[I] = '(' then Inc(Depth)
      else if S[I] = ')' then Dec(Depth)
      else if (S[I] = ',') and (Depth = 0) then
      begin
        AOut.Add(Trim(Cur));
        Cur := '';
        Continue;
      end;
    end;
    Cur := Cur + S[I];
  end;
  if Trim(Cur) <> '' then AOut.Add(Trim(Cur));
end;

procedure TaScriptContext.DoCopyRows(const AArg: string);
var
  P, Q, I, Eq: Integer;
  Src, Dst, Maps, Where, Cols, Exprs, Sql: string;
  L: TStringList;
  R: TZQuery;
  Cnt: Integer;
begin
  P := Pos('->', AArg);
  if P = 0 then begin ScriptNotify(Tr('The copyrows command needs the form: source [WHERE condition] -> target : field = expression, ...')); Exit; end;
  Src := Trim(Copy(AArg, 1, P - 1));
  Dst := Trim(Copy(AArg, P + 2, MaxInt));
  Q := Pos(':', Dst);
  if Q = 0 then begin ScriptNotify(Tr('The copyrows command: the list of fields after ":" is missing')); Exit; end;
  Maps := Trim(Copy(Dst, Q + 1, MaxInt));
  Dst := Trim(Copy(Dst, 1, Q - 1));
  Where := '';
  P := Pos(' WHERE ', UpperCase(Src));
  if P > 0 then
  begin
    Where := Trim(Copy(Src, P + 7, MaxInt));
    Src := Trim(Copy(Src, 1, P - 1));
  end;
  if (not SafeIdent(Src)) or (not SafeIdent(Dst)) then begin ScriptNotify(Tr('copyrows: invalid table name.')); Exit; end;
  L := TStringList.Create;
  try
    SplitMapping(Maps, L);
    Cols := ''; Exprs := '';
    for I := 0 to L.Count - 1 do
    begin
      Eq := Pos('=', L[I]);
      if (Eq < 2) or (not SafeIdent(Trim(Copy(L[I], 1, Eq - 1)))) or (Trim(Copy(L[I], Eq + 1, MaxInt)) = '') then
      begin
        ScriptNotify(Tr('copyrows: invalid assignment "') + L[I] + Tr('" (form: field = expression).'));
        Exit;
      end;
      if Cols <> '' then begin Cols := Cols + ', '; Exprs := Exprs + ', '; end;
      Cols := Cols + Trim(Copy(L[I], 1, Eq - 1));
      Exprs := Exprs + Trim(Copy(L[I], Eq + 1, MaxInt));
    end;
  finally
    L.Free;
  end;
  if Cols = '' then begin ScriptNotify(Tr('copyrows: there are no fields to copy.')); Exit; end;
  Sql := ' FROM ' + Src;
  if Where <> '' then Sql := Sql + ' WHERE ' + Where;
  try
    R := Db.NewQuery('SELECT COUNT(*)' + Sql);
    try
      R.Open;
      Cnt := R.Fields[0].AsInteger;
    finally
      R.Free;
    end;
    Db.Conn.ExecuteDirect('INSERT INTO ' + Dst + ' (' + Cols + ') SELECT ' + Exprs + Sql);
    SetVar('kopirano', Cnt);
    try
      R := Db.NewQuery('SELECT MAX(id) FROM ' + Dst);
      try
        R.Open;
        if R.Fields[0].IsNull then SetVar('novi', Null) else SetVar('novi', R.Fields[0].AsInteger);
      finally
        R.Free;
      end;
    except
      SetVar('novi', Null);
    end;
  except
    on E: Exception do ScriptNotify(Tr('copyrows failed: ') + E.Message);
  end;
end;

function UrlEncodePart(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~', '@'] then Result := Result + S[I]
    else Result := Result + '%' + IntToHex(Ord(S[I]), 2);
end;

procedure TaScriptContext.DoAction(const AAction: string);
var
  A, Verb, Arg, Verb2, Url: string;
  P: Integer;
  R: Variant;
  Q: TZQuery;
  ImpRows: TaRows;
  ImpRes: TaImportResult;
begin
  A := Trim(AAction);
  if A = '' then Exit;
  P := Pos(':', A);
  if P > 0 then
  begin
    Verb := LowerCase(Trim(Copy(A, 1, P - 1)));
    Arg := Trim(Copy(A, P + 1, MaxInt));
  end
  else
  begin
    Verb := LowerCase(A);
    Arg := '';
  end;
  if Verb = 'msg' then ScriptNotify(Arg)
  else if Verb = 'sql' then
  begin
    try
      Db.Conn.ExecuteDirect(Arg);
    except
      on E: Exception do ScriptNotify(Tr('SQL failed: ') + E.Message);
    end;
  end
  else if Verb = 'copyrows' then DoCopyRows(Arg)
  else if Verb = 'run4gl' then
  begin
    A := Db.LoadObject('_sys_programs', Trim(Arg));
    if A = '' then ScriptNotify(Tr('There is no 4GL program: ') + Arg)
    else if not Assigned(OnRunFglText) then ScriptNotify(Tr('4GL cannot be run from this environment.'))
    else SetVar('izlaz4gl', OnRunFglText(Db, A));
  end
  else if Verb = 'run' then
  begin
    if not Scripts(Db).CallProc(Self, Arg, [], R) then ScriptNotify(Tr('There is no procedure: ') + Arg);
  end
  else if Verb = 'macro' then RunMacroByName(Self, Arg)
  else if (Verb = 'set') or (Verb = 'visible') or (Verb = 'enabled') or (Verb = 'caption') then
  begin
    P := Pos('=', Arg);
    if P = 0 then ScriptNotify(Tr('The command ') + Verb + Tr(' needs the form: name = expression'))
    else
    begin
      Verb2 := Trim(Copy(Arg, 1, P - 1));
      R := EvalV(Trim(Copy(Arg, P + 1, MaxInt)));
      if Verb = 'set' then SetValue(Verb2, FormatValue(R, ''))
      else if Verb = 'visible' then SetVisible(Verb2, ExprIsTrue(R))
      else if Verb = 'enabled' then SetEnabled(Verb2, ExprIsTrue(R))
      else SetCaption(Verb2, FormatValue(R, ''));
    end;
  end
  else if Verb = 'beep' then Write(#7)
  else if Verb = 'ask' then
  begin
    if Assigned(OnScriptAsk) then SetVar('odgovor', Ord(OnScriptAsk(Arg)))
    else SetVar('odgovor', Ord(MessageDlg(Arg, mtConfirmation, [mbYes, mbNo], 0) = mrYes));
  end
  else if Verb = 'input' then
  begin
    Verb2 := '';
    if Assigned(OnScriptInput) then
    begin
      if not OnScriptInput(Arg, Verb2) then Verb2 := '';
    end
    else Verb2 := InputBox('Unos', Arg, '');
    SetVar('unos', Verb2);
  end
  else if Verb = 'fetch' then
  begin
    { fetch: ime = SELECT ...  prvo polje prvog retka postaje varijabla (prazno = Null) }
    P := Pos('=', Arg);
    if P = 0 then ScriptNotify(Tr('The fetch command needs the form: name = SELECT ...'))
    else
    try
      Q := Db.NewQuery(Trim(Copy(Arg, P + 1, MaxInt)));
      try
        Q.Open;
        if Q.EOF or Q.Fields[0].IsNull then SetVar(Trim(Copy(Arg, 1, P - 1)), Null)
        else if Q.Fields[0].DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftAutoInc, ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle] then
          SetVar(Trim(Copy(Arg, 1, P - 1)), Q.Fields[0].AsFloat)
        else SetVar(Trim(Copy(Arg, 1, P - 1)), Q.Fields[0].AsString);
      finally
        Q.Free;
      end;
    except
      on E: Exception do ScriptNotify(Tr('The query failed: ') + E.Message);
    end;
  end
  else if Verb = 'exporttable' then
  begin
    P := Pos('>', Arg);
    if P = 0 then ScriptNotify(Tr('The exporttable command needs the form: source > file'))
    else
    try
      Verb2 := Trim(Copy(Arg, P + 1, MaxInt));
      A := Trim(Copy(Arg, 1, P - 1));
      ForceDirectories(ExtractFilePath(ExpandFileName(Verb2)));
      if LowerCase(ExtractFileExt(Verb2)) = '.xlsx' then ExportXlsx(Db, A, Verb2)
      else if LowerCase(ExtractFileExt(Verb2)) = '.json' then ExportJson(Db, A, Verb2)
      else ExportCsv(Db, A, Verb2, ';');
    except
      on E: Exception do ScriptNotify(Tr('Export failed: ') + E.Message);
    end;
  end
  else if Verb = 'compact' then
  begin
    CheckAndCompact(Db, True, Verb2);
    ScriptNotify(Verb2);
  end
  else if Verb = 'wait' then
  begin
    Sleep(Round(1000 * Min(60, Max(0, StrToFloatDef(StringReplace(Arg, ',', '.', []), 0, DefaultFormatSettings)))));
  end
  else if Verb = 'openurl' then OpenURL(Arg)
  else if Verb = 'mailto' then
  begin
    { adresa ; predmet ; tekst }
    A := Arg;
    Verb2 := '';
    P := Pos(';', A);
    if P > 0 then
    begin
      Verb2 := Trim(Copy(A, 1, P - 1));
      A := Copy(A, P + 1, MaxInt);
    end
    else begin Verb2 := Trim(A); A := ''; end;
    Url := 'mailto:' + UrlEncodePart(Verb2);
    P := Pos(';', A);
    if P > 0 then Url := Url + '?subject=' + UrlEncodePart(Trim(Copy(A, 1, P - 1))) + '&body=' + UrlEncodePart(Trim(Copy(A, P + 1, MaxInt)))
    else if Trim(A) <> '' then Url := Url + '?subject=' + UrlEncodePart(Trim(A));
    OpenURL(Url);
  end
  else if Verb = 'copyfile' then
  begin
    P := Pos('>', Arg);
    if P = 0 then ScriptNotify(Tr('The copyfile command needs the form: source > destination'))
    else
    try
      Verb2 := Trim(Copy(Arg, P + 1, MaxInt));
      A := Trim(Copy(Arg, 1, P - 1));
      if not FileExists(A) then ScriptNotify(Tr('The file does not exist: ') + A)
      else
      begin
        ForceDirectories(ExtractFilePath(ExpandFileName(Verb2)));
        if not CopyFile(A, Verb2, [cffOverwriteFile]) then ScriptNotify(Tr('Copying failed: ') + A);
      end;
    except
      on E: Exception do ScriptNotify(Tr('Copying failed: ') + E.Message);
    end;
  end
  else if Verb = 'importtable' then
  begin
    P := Pos('<', Arg);
    if P = 0 then ScriptNotify(Tr('The importtable command needs the form: table < file'))
    else
    try
      A := Trim(Copy(Arg, 1, P - 1));
      Verb2 := Trim(Copy(Arg, P + 1, MaxInt));
      if not FileExists(Verb2) then ScriptNotify(Tr('The file does not exist: ') + Verb2)
      else if not ReadAnyFile(Verb2, ';', ImpRows) then ScriptNotify(Tr('The file cannot be read: ') + Verb2)
      else
      begin
        ImpRes := ImportToExisting(Db, A, ImpRows, True);
        SetVar('uvezeno', ImpRes.Inserted);
        SetVar('preskoceno', ImpRes.Skipped);
      end;
    except
      on E: Exception do ScriptNotify(Tr('Import failed: ') + E.Message);
    end;
  end
  else if Verb = 'backup' then
  begin
    if not BackupDatabase(Db, Arg, Verb2) then ScriptNotify(Tr('Backup failed: ') + Verb2);
  end
  else DoOther(Verb, Arg);
end;

{ ---------------- macros ---------------- }

{ [ime] u izrazu zamjenjuje vrijednost varijable makroa (osim unutar navodnika) }
function SubstVars(ACtx: TaScriptContext; const AExpr: string): string;
var
  I, J: Integer;
  Q: Char;
  Nm: string;
  V: Variant;
  FS: TFormatSettings;
begin
  Result := '';
  if ACtx.Vars.Count = 0 then Exit(AExpr);
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Q := #0;
  I := 1;
  while I <= Length(AExpr) do
  begin
    if Q <> #0 then
    begin
      Result := Result + AExpr[I];
      if AExpr[I] = Q then Q := #0;
      Inc(I);
    end
    else if (AExpr[I] = '"') or (AExpr[I] = '''') then
    begin
      Q := AExpr[I];
      Result := Result + AExpr[I];
      Inc(I);
    end
    else if AExpr[I] = '[' then
    begin
      J := I + 1;
      while (J <= Length(AExpr)) and (AExpr[J] <> ']') do Inc(J);
      Nm := Copy(AExpr, I + 1, J - I - 1);
      if (J <= Length(AExpr)) and ACtx.HasVar(Nm) then
      begin
        V := ACtx.GetVar(Nm);
        if VarIsNull(V) then Result := Result + 'Null'
        else if VarIsStr(V) then Result := Result + '"' + StringReplace(VarToStr(V), '"', '""', [rfReplaceAll]) + '"'
        else Result := Result + SysUtils.FloatToStr(Double(V), FS);
        I := J + 1;
      end
      else
      begin
        Result := Result + AExpr[I];
        Inc(I);
      end;
    end
    else
    begin
      Result := Result + AExpr[I];
      Inc(I);
    end;
  end;
end;

{ {ime} u argumentu naredbe: tekst; u sql naredbi SQL vrijednost (broj ili tekst u navodnicima) }
function ExpandBraces(ACtx: TaScriptContext; const AText: string; ASql: Boolean): string;
var
  I, J: Integer;
  Nm, T: string;
  V: Variant;
  FS: TFormatSettings;
begin
  Result := '';
  if ACtx.Vars.Count = 0 then Exit(AText);
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  I := 1;
  while I <= Length(AText) do
  begin
    if AText[I] = '{' then
    begin
      J := I + 1;
      while (J <= Length(AText)) and (AText[J] <> '}') do Inc(J);
      Nm := Copy(AText, I + 1, J - I - 1);
      if (J <= Length(AText)) and ACtx.HasVar(Nm) then
      begin
        V := ACtx.GetVar(Nm);
        if VarIsNull(V) then T := ''
        else if VarIsStr(V) then T := VarToStr(V)
        else T := FormatValue(V, '');
        if ASql then
        begin
          if VarIsNull(V) then T := 'NULL'
          else if VarIsStr(V) then T := '''' + StringReplace(T, '''', '''''', [rfReplaceAll]) + ''''
          else T := SysUtils.FloatToStr(Double(V), FS);
        end;
        Result := Result + T;
        I := J + 1;
        Continue;
      end;
    end;
    Result := Result + AText[I];
    Inc(I);
  end;
end;

function ActionOf(ACtx: TaScriptContext; B: TaBlock): string;
var
  A, Nm: string;
  P: Integer;
begin
  A := B.Arg;
  if BlockVerbArg(B.Verb) = baAssign then
  begin
    P := Pos('=', A);
    if P > 0 then
    begin
      Nm := Trim(Copy(A, 1, P - 1));
      A := Nm + ' = ' + SubstVars(ACtx, Trim(Copy(A, P + 1, MaxInt)));
    end;
  end
  else A := ExpandBraces(ACtx, A, (B.Verb = 'sql') or (B.Verb = 'fetch') or (B.Verb = 'copyrows'));
  if A = '' then Result := B.Verb else Result := B.Verb + ': ' + A;
end;

procedure RunMacro(ACtx: TaScriptContext; const AText: string; ADepth: Integer);
var
  Prog: TaBlockProgram;
  Op, El, En: TIntArray;
  Cnt: array of Integer;
  Err: string;
  Pc, N, Guard: Integer;
  B: TaBlock;

  function IsTrue(const ACond: string): Boolean;
  begin
    Result := ExprIsTrue(ACtx.EvalV(SubstVars(ACtx, ACond)));
  end;

begin
  if ADepth > 8 then begin ScriptNotify(Tr('The macro is nested too deeply.')); Exit; end;
  Prog := TaBlockProgram.Create;
  try
    Prog.LoadText(AText);
    if not Prog.Match(Op, El, En, Err) then begin ScriptNotify(Tr('Macro, ') + Err); Exit; end;
    Inc(ACtx.MacroLevel);
    try
      if ACtx.MacroLevel = 1 then
      begin
        ACtx.Vars.Clear;
        { ugradene varijable }
        ACtx.SetVar('korisnik', CurrentUserName);
        ACtx.SetVar('datum', FormatDateTime('yyyy-mm-dd', Date));
        ACtx.SetVar('vrijeme', FormatDateTime('hh:nn', Time));
      end;
      N := Prog.Count;
      SetLength(Cnt, N);
      for Pc := 0 to N - 1 do Cnt[Pc] := -1;
      Pc := 0;
      Guard := 0;
      while Pc < N do
      begin
        Inc(Guard);
        if Guard > 100000 then begin ScriptNotify(Tr('The macro runs too long (infinite loop?).')); Break; end;
        B := Prog[Pc];
        case B.Kind of
          bkStop: Break;
          bkCommand:
            begin
              ACtx.DoAction(ActionOf(ACtx, B));
              Inc(Pc);
            end;
          bkIf:
            begin
              if B.Verb = '' then begin ScriptNotify(Tr('Macro, line ') + IntToStr(Pc + 1) + Tr(': "then" is missing.')); Break; end;
              if IsTrue(B.Cond) then
              begin
                if B.Verb = 'stop' then Break;
                ACtx.DoAction(ActionOf(ACtx, B));
              end;
              Inc(Pc);
            end;
          bkIfBlock:
            if IsTrue(B.Cond) then Inc(Pc)
            else if El[Pc] >= 0 then Pc := El[Pc] + 1
            else Pc := En[Pc] + 1;
          bkElse: Pc := En[Op[Pc]] + 1;
          bkWhile:
            if IsTrue(B.Cond) then Inc(Pc) else Pc := En[Pc] + 1;
          bkEndWhile, bkEndRepeat: Pc := Op[Pc];
          bkRepeat:
            begin
              if Cnt[Pc] < 0 then Cnt[Pc] := Round(Double(ACtx.EvalV(SubstVars(ACtx, B.Cond))));
              if Cnt[Pc] > 0 then begin Dec(Cnt[Pc]); Inc(Pc); end
              else begin Cnt[Pc] := -1; Pc := En[Pc] + 1; end;
            end;
          bkLet:
            begin
              ACtx.SetVar(B.Arg, ACtx.EvalV(SubstVars(ACtx, B.Cond)));
              Inc(Pc);
            end;
        else
          Inc(Pc);   { prazno, komentar, end if }
        end;
      end;
    finally
      Dec(ACtx.MacroLevel);
    end;
  finally
    Prog.Free;
  end;
end;

procedure RunMacroByName(ACtx: TaScriptContext; const AName: string; ADepth: Integer);
var
  T: string;
begin
  T := ACtx.Db.LoadObject('_sys_macros', AName);
  if T = '' then begin ScriptNotify(Tr('There is no macro: ') + AName); Exit; end;
  RunMacro(ACtx, T, ADepth + 1);
end;

{ ---------------- functions offered to scripts ---------------- }

procedure PS_ShowMessage(S: string);
begin
  ScriptNotify(S);
end;

function PS_Confirm(S: string): Boolean;
begin
  Result := MessageDlg(S, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

function PS_InputBox(ACaption, APrompt, ADefault: string): string;
begin
  Result := InputBox(ACaption, APrompt, ADefault);
end;

function PS_GetValue(AName: string): string;
begin
  if CurCtx = nil then Result := '' else Result := CurCtx.GetValue(AName);
end;

function PS_GetNumber(AName: string): Double;
var
  V: Double;
begin
  if (CurCtx <> nil) and ParseNumber(CurCtx.GetValue(AName), V) then Result := V else Result := 0;
end;

procedure PS_SetValue(AName, AValue: string);
begin
  if CurCtx <> nil then CurCtx.SetValue(AName, AValue);
end;

procedure PS_SetNumber(AName: string; AValue: Double);
begin
  if CurCtx <> nil then CurCtx.SetValue(AName, SysUtils.FloatToStr(AValue, ParseFS));
end;

function PS_Eval(AExpr: string): string;
begin
  if CurCtx = nil then Result := '' else Result := CurCtx.Eval(AExpr);
end;

function PS_EvalNumber(AExpr: string): Double;
var
  V: Variant;
begin
  Result := 0;
  if CurCtx = nil then Exit;
  V := CurCtx.EvalV(AExpr);
  if VarIsNull(V) or VarIsEmpty(V) then Exit;
  try
    Result := V;
  except
    Result := 0;
  end;
end;

procedure PS_DoAction(AAction: string);
begin
  if CurCtx <> nil then CurCtx.DoAction(AAction);
end;

procedure PS_SetVisible(AName: string; AValue: Boolean);
begin
  if CurCtx <> nil then CurCtx.SetVisible(AName, AValue);
end;

procedure PS_SetEnabled(AName: string; AValue: Boolean);
begin
  if CurCtx <> nil then CurCtx.SetEnabled(AName, AValue);
end;

procedure PS_SetCaption(AName, AValue: string);
begin
  if CurCtx <> nil then CurCtx.SetCaption(AName, AValue);
end;

procedure PS_FocusControl(AName: string);
begin
  if CurCtx <> nil then CurCtx.FocusControl(AName);
end;

{ podaci o okidacu: eventControl, eventValue, eventKey, eventMessage (OnError) }
function PS_EventInfo(AName: string): string;
begin
  Result := '';
  if (CurCtx <> nil) and CurCtx.HasVar(AName) then Result := VarToStr(CurCtx.GetVar(AName));
end;

procedure PS_SetEventInfo(AName, AValue: string);
begin
  if CurCtx <> nil then CurCtx.SetVar(AName, AValue);
end;

procedure PS_CancelEvent;
begin
  if CurCtx <> nil then CurCtx.Cancel;
end;

function PS_DLookup(AExpr, ADomain, ACrit: string): string;
var
  V: Variant;
begin
  if CurCtx = nil then Exit('');
  V := DbDomain(CurCtx.Db, 'dlookup', AExpr, ADomain, ACrit);
  if VarIsNull(V) then Result := '' else Result := VarToStr(V);
end;

function PS_DCount(ADomain, ACrit: string): Integer;
var
  V: Variant;
begin
  Result := 0;
  if CurCtx = nil then Exit;
  V := DbDomain(CurCtx.Db, 'dcount', '*', ADomain, ACrit);
  if not VarIsNull(V) then Result := V;
end;

function PS_DSum(AExpr, ADomain, ACrit: string): Double;
var
  V: Variant;
begin
  Result := 0;
  if CurCtx = nil then Exit;
  V := DbDomain(CurCtx.Db, 'dsum', AExpr, ADomain, ACrit);
  if not VarIsNull(V) then Result := V;
end;

function PS_SqlExec(ASql: string): Boolean;
begin
  Result := False;
  if CurCtx = nil then Exit;
  try
    CurCtx.Db.Conn.ExecuteDirect(ASql);
    Result := True;
  except
    on E: Exception do ScriptNotify(Tr('SQL failed: ') + E.Message);
  end;
end;

function PS_SqlValue(ASql: string): string;
var
  Q: TZQuery;
begin
  Result := '';
  if CurCtx = nil then Exit;
  Q := CurCtx.Db.NewQuery(ASql);
  try
    try
      Q.Open;
      if (not Q.EOF) and (Q.FieldCount > 0) and not Q.Fields[0].IsNull then
        Result := Q.Fields[0].AsString;
    except
      Result := '';
    end;
  finally
    Q.Free;
  end;
end;

function PS_Today: string;
begin
  Result := FormatDateTime('yyyy-mm-dd', Date);
end;

function PS_NowStr: string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
end;

function PS_FormatVal(AValue, AFormat: string): string;
var
  V: Variant;
  D: Double;
begin
  if ParseNumber(AValue, D) then V := D else V := AValue;
  Result := FormatValue(V, AFormat);
end;

function PS_NumToStr(AValue: Double): string;
begin
  Result := SysUtils.FloatToStr(AValue, ParseFS);
end;

function PS_StrToNum(AValue: string): Double;
var
  D: Double;
begin
  if ParseNumber(AValue, D) then Result := D else Result := 0;
end;

procedure TaScripts.ScriptCompile(Sender: TPSScript);
begin
  Sender.AddFunction(@PS_ShowMessage, 'procedure ShowMessage(S: string);');
  Sender.AddFunction(@PS_ShowMessage, 'procedure Msg(S: string);');
  Sender.AddFunction(@PS_Confirm, 'function Confirm(S: string): Boolean;');
  Sender.AddFunction(@PS_InputBox, 'function InputBox(ACaption, APrompt, ADefault: string): string;');
  Sender.AddFunction(@PS_GetValue, 'function GetValue(AName: string): string;');
  Sender.AddFunction(@PS_GetNumber, 'function GetNumber(AName: string): Double;');
  Sender.AddFunction(@PS_SetValue, 'procedure SetValue(AName, AValue: string);');
  Sender.AddFunction(@PS_SetNumber, 'procedure SetNumber(AName: string; AValue: Double);');
  Sender.AddFunction(@PS_Eval, 'function Eval(AExpr: string): string;');
  Sender.AddFunction(@PS_EvalNumber, 'function EvalNumber(AExpr: string): Double;');
  Sender.AddFunction(@PS_DoAction, 'procedure DoAction(AAction: string);');
  Sender.AddFunction(@PS_SetVisible, 'procedure SetVisible(AName: string; AValue: Boolean);');
  Sender.AddFunction(@PS_SetEnabled, 'procedure SetEnabled(AName: string; AValue: Boolean);');
  Sender.AddFunction(@PS_SetCaption, 'procedure SetCaption(AName, AValue: string);');
  Sender.AddFunction(@PS_FocusControl, 'procedure FocusControl(AName: string);');
  Sender.AddFunction(@PS_CancelEvent, 'procedure CancelEvent;');
  Sender.AddFunction(@PS_EventInfo, 'function EventInfo(Name: string): string;');
  Sender.AddFunction(@PS_SetEventInfo, 'procedure SetEventInfo(Name, Value: string);');
  Sender.AddFunction(@PS_DLookup, 'function DLookup(AExpr, ADomain, ACrit: string): string;');
  Sender.AddFunction(@PS_DCount, 'function DCount(ADomain, ACrit: string): Integer;');
  Sender.AddFunction(@PS_DSum, 'function DSum(AExpr, ADomain, ACrit: string): Double;');
  Sender.AddFunction(@PS_SqlExec, 'function SqlExec(ASql: string): Boolean;');
  Sender.AddFunction(@PS_SqlValue, 'function SqlValue(ASql: string): string;');
  Sender.AddFunction(@PS_Today, 'function Today: string;');
  Sender.AddFunction(@PS_NowStr, 'function NowStr: string;');
  Sender.AddFunction(@PS_FormatVal, 'function FormatVal(AValue, AFormat: string): string;');
  Sender.AddFunction(@PS_NumToStr, 'function NumToStr(AValue: Double): string;');
  Sender.AddFunction(@PS_StrToNum, 'function StrToNum(AValue: string): Double;');
end;

function ScriptHelpLines: TStringList;
begin
  Result := TStringList.Create;
  Result.Text :=
    'procedure Msg(S: string);' + LineEnding +
    'function Confirm(S: string): Boolean;' + LineEnding +
    'function InputBox(Caption, Prompt, Default: string): string;' + LineEnding +
    'function GetValue(Name: string): string;' + LineEnding +
    'function GetNumber(Name: string): Double;' + LineEnding +
    'procedure SetValue(Name, Value: string);' + LineEnding +
    'procedure SetNumber(Name: string; Value: Double);' + LineEnding +
    'function Eval(Expr: string): string;' + LineEnding +
    'function EvalNumber(Expr: string): Double;' + LineEnding +
    'procedure DoAction(Action: string);' + LineEnding +
    'procedure SetVisible(Name: string; V: Boolean);' + LineEnding +
    'procedure SetEnabled(Name: string; V: Boolean);' + LineEnding +
    'procedure SetCaption(Name, Text: string);' + LineEnding +
    'procedure FocusControl(Name: string);' + LineEnding +
    'procedure CancelEvent;  { u BeforeInsert/BeforeUpdate/BeforeDelete/OnClose, OnExit/OnValidate/OnKey (kontrola), OnError }' + LineEnding +
    'function EventInfo(Name: string): string;  { eventControl, eventValue, eventKey, eventMessage }' + LineEnding +
    'procedure SetEventInfo(Name, Value: string);  { npr. promjena eventMessage u OnError }' + LineEnding +
    'function DLookup(Expr, Domain, Crit: string): string;' + LineEnding +
    'function DCount(Domain, Crit: string): Integer;' + LineEnding +
    'function DSum(Expr, Domain, Crit: string): Double;' + LineEnding +
    'function SqlExec(Sql: string): Boolean;' + LineEnding +
    'function SqlValue(Sql: string): string;' + LineEnding +
    'function Today: string;' + LineEnding +
    'function NowStr: string;' + LineEnding +
    'function FormatVal(Value, Format: string): string;' + LineEnding +
    'function NumToStr(V: Double): string;' + LineEnding +
    'function StrToNum(S: string): Double;' + LineEnding +
    '{ standardno: IntToStr StrToInt StrToIntDef UpperCase LowerCase Trim Copy Pos Length Round ... }';
end;

function MacroHelpLines: TStringList;
begin
  Result := TStringList.Create;
  Result.Text :=
    'first | prior | next | last | new | delete | save | undo | requery' + LineEnding +
    'close' + LineEnding +
    'msg:tekst' + LineEnding +
    'ask:pitanje   (odgovor u [odgovor], 1 = Da)' + LineEnding +
    'input:pitanje   (unos u [unos])' + LineEnding +
    'sql:UPDATE ... (izvršava SQL; {ime} = varijabla)' + LineEnding +
    'run:ImeProcedure   (skripta iz modula)' + LineEnding +
    'macro:ImeMakroa' + LineEnding +
    'openform:Naziv' + LineEnding +
    'openreport:Naziv' + LineEnding +
    'exportpdf:Naziv > datoteka.pdf' + LineEnding +
    'backup:datoteka.db' + LineEnding +
    'openurl:adresa' + LineEnding +
    'filter:iznos > 100   |   nofilter' + LineEnding +
    'goto:imeKontrole' + LineEnding +
    'set:polje = izraz' + LineEnding +
    'visible:kontrola = izraz   |   enabled:  |   caption:' + LineEnding +
    'let ime = izraz   (varijabla; u izrazu [ime])' + LineEnding +
    'if [iznos] > 100 then msg:veliko   (uvjet je izraz)' + LineEnding +
    'if uvjet ... else ... end if' + LineEnding +
    'while uvjet ... end while' + LineEnding +
    'repeat n ... end repeat' + LineEnding +
    'stop' + LineEnding +
    '# komentar';
end;

{ ---------------- scripts ---------------- }

constructor TaScripts.Create(ADb: TAppDb);
begin
  FDb := ADb;
  FNames := TStringList.Create;
  FNames.Sorted := True;
  FNames.Duplicates := dupIgnore;
end;

destructor TaScripts.Destroy;
begin
  FScript.Free;
  FNames.Free;
  inherited Destroy;
end;

{ All modules joined; the closing main block is added here. AReplaceText stands
  in for the module AReplaceName (used by the editor's "check"). }
function TaScripts.SourceText(const AReplaceName, AReplaceText: string; out ALineOffset: Integer): string;
var
  Names: TStringList;
  I: Integer;
  T: string;
  Lines: Integer;

  function CountLines(const S: string): Integer;
  var
    K: Integer;
  begin
    Result := 0;
    for K := 1 to Length(S) do
      if S[K] = #10 then Inc(Result);
  end;

begin
  Result := '';
  ALineOffset := 0;
  Names := FDb.ListObjects('_sys_modules');
  try
    { the edited module goes last so its line numbers are easy to relate }
    for I := 0 to Names.Count - 1 do
    begin
      if SameText(Names[I], AReplaceName) then Continue;
      T := FDb.LoadObject('_sys_modules', Names[I]);
      Result := Result + T + LineEnding;
    end;
    Lines := CountLines(Result);
    if AReplaceName <> '' then
    begin
      ALineOffset := Lines;
      Result := Result + AReplaceText + LineEnding;
    end
    else
    begin
      Names.Free;
      Names := nil;
    end;
  finally
    Names.Free;
  end;
  Result := Result + 'begin' + LineEnding + 'end.';
end;

function TaScripts.Compile(const ASource: string; out AErrors: string): Boolean;
var
  S: TPSScript;
  I: Integer;
  P: TPSProcRec;
begin
  AErrors := '';
  S := TPSScript.Create(nil);
  try
    S.OnCompile := @ScriptCompile;
    S.Script.Text := ASource;
    Result := S.Compile;
    if not Result then
      for I := 0 to S.CompilerMessageCount - 1 do
        AErrors := AErrors + S.CompilerMessages[I].MessageToString + LineEnding;
    if Result then
    begin
      FNames.Clear;
      for I := 0 to S.Exec.GetProcCount - 1 do
      begin
        P := S.Exec.GetProcNo(I);
        if (P is TPSInternalProcRec) and (TPSInternalProcRec(P).ExportName <> '') and
           (TPSInternalProcRec(P).ExportName <> '!MAIN') then
          FNames.Add(UpperCase(TPSInternalProcRec(P).ExportName));
      end;
    end;
  finally
    S.Free;
  end;
end;

function TaScripts.Check(const AName, AText: string; out AErrors: string): Boolean;
var
  Off, I: Integer;
  Src, Raw, Line, Fixed: string;
  L: TStringList;
  P1, P2, Ln: Integer;
  Saved: TStringList;
begin
  Src := SourceText(AName, AText, Off);
  Saved := TStringList.Create;
  try
    Saved.Assign(FNames);
    Result := Compile(Src, Raw);
    FNames.Assign(Saved);
  finally
    Saved.Free;
  end;
  { relate "(line:col)" to the edited module }
  Fixed := '';
  L := TStringList.Create;
  try
    L.Text := Raw;
    for I := 0 to L.Count - 1 do
    begin
      Line := L[I];
      P1 := Pos('(', Line);
      P2 := Pos(':', Line);
      if (P1 > 0) and (P2 > P1) and TryStrToInt(Copy(Line, P1 + 1, P2 - P1 - 1), Ln) then
        Line := Copy(Line, 1, P1) + IntToStr(Ln - Off) + Copy(Line, P2, MaxInt);
      Fixed := Fixed + Line + LineEnding;
    end;
  finally
    L.Free;
  end;
  AErrors := Fixed;
end;

function TaScripts.Ensure: Boolean;
var
  Off, I: Integer;
  Src, Sig: string;
  Err: string;
begin
  Src := SourceText('', '', Off);
  Sig := IntToStr(Length(Src)) + ':' + IntToStr(StrToInt64Def('$' + IntToHex(Length(Src), 8), 0));
  { cheap change detection: the text itself }
  Sig := Src;
  if FReady and (Sig = FSignature) then Exit(FError = '');
  FreeAndNil(FScript);
  FReady := True;
  FSignature := Sig;
  FError := '';
  if not Compile(Src, Err) then
  begin
    FError := Err;
    UserFunctionNames.Clear;
    Exit(False);
  end;
  FScript := TPSScript.Create(nil);
  FScript.OnCompile := @ScriptCompile;
  FScript.Script.Text := Src;
  if not FScript.Compile then
  begin
    FError := 'Prevođenje nije uspjelo.';
    FreeAndNil(FScript);
    Exit(False);
  end;
  UserFunctionNames.Clear;
  for I := 0 to FNames.Count - 1 do UserFunctionNames.Add(FNames[I]);
  Result := True;
end;

function TaScripts.HasProc(const AName: string): Boolean;
begin
  Result := Ensure and (FNames.IndexOf(UpperCase(AName)) >= 0);
end;

function TaScripts.CallProc(ACtx: TaScriptContext; const AName: string;
  const AArgs: array of Variant; out AResult: Variant): Boolean;
var
  Saved: TaScriptContext;
begin
  Result := False;
  AResult := Null;
  if not Ensure then
  begin
    if FError <> '' then ScriptNotify(Tr('The script does not compile:') + LineEnding + FError);
    Exit;
  end;
  if FNames.IndexOf(UpperCase(AName)) < 0 then Exit;
  Saved := CurCtx;
  CurCtx := ACtx;
  try
    try
      AResult := FScript.ExecuteFunction(AArgs, UpperCase(AName));
      Result := True;
    except
      on E: Exception do ScriptNotify(Tr('Error in the script (') + AName + '): ' + E.Message);
    end;
  finally
    CurCtx := Saved;
  end;
end;

{ ---------------- singleton ---------------- }

function UserFnHook(const AName: string; const AArgs: array of Variant; out AResult: Variant): Boolean;
var
  Ctx: TaScriptContext;
begin
  Result := False;
  AResult := Null;
  if GScripts = nil then Exit;
  if not GScripts.HasProc(AName) then Exit;
  Ctx := CurCtx;
  if Ctx = nil then Ctx := FallbackCtx;
  Result := GScripts.CallProc(Ctx, AName, AArgs, AResult);
end;

function Scripts(ADb: TAppDb): TaScripts;
begin
  if (GScripts <> nil) and (GScripts.FDb <> ADb) then ResetScripts;
  if GScripts = nil then
  begin
    GScripts := TaScripts.Create(ADb);
    FallbackCtx := TaScriptContext.Create(ADb);
    UserFunctionHook := @UserFnHook;
  end;
  Result := GScripts;
end;

procedure ResetScripts;
begin
  UserFunctionHook := nil;
  FreeAndNil(GScripts);
  FreeAndNil(FallbackCtx);
  CurCtx := nil;
  if UserFunctionNames <> nil then UserFunctionNames.Clear;
end;

finalization
  ResetScripts;
end.
