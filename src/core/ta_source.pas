unit ta_source;
{ Jedinstveni opis izvora podataka (TaSourceDef, poglavlje 7 plana): tablica, SQL, izraz, popis ili 4GL.
  Bez prefiksa znaci isto sto i prije (naziv tablice, upita ili SELECT). S prefiksom:
    sql:SELECT ...        izricito SQL
    list:A;B;C            fiksni popis (jedan stupac)
    expr:izraz            izraz koji vraca jednu vrijednost
    fgl:Program(arg=[polje], ...)   4GL funkcija koja vraca retke naredbama COLUMNS i EMIT
    fglv:Program(...)     4GL funkcija koja vraca jednu vrijednost (RETURN)
  Parametri 4GL poziva su izrazi koji se racunaju nad zapisom forme (AEval); kad se polje iz parametara
  promijeni, kontrola ponovno otvori izvor (SourceFieldRefs daje polja o kojima izvor ovisi). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, DB, BufDataset, ta_meta, ta_fgl;

type
  { alias da jedinice koje ne koriste unit DB (zbog sukoba imena) mogu imenovati skup podataka }
  TaDataSet = TDataSet;

  TaSourceKind = (skTable, skSql, skList, skExpr, skFgl, skFglValue);

  TaSourceDef = record
    Kind: TaSourceKind;
    Body: string;       { tekst iza prefiksa }
  end;

  { vraca vrijednost izraza (npr. [grad]) nad zapisom forme; False = izraz se ne moze izracunati }
  TaParamEval = function(const AExpr: string; out AValue: Variant): Boolean of object;

  { memorijski skup podataka koji je puni 4GL program }
  TaFglDataSet = class(TBufDataset)
  private
    FRunMs: Integer;
    FLog: string;
  public
    procedure LoadFrom(R: TaFglResult);
    property RunMs: Integer read FRunMs;
    property Log: string read FLog;
  end;

const
  DefaultSourceTimeMs = 5000;
  DefaultSourceMaxRows = 100000;

function ParseSource(const AText: string): TaSourceDef;
{ "Program.Funkcija(a=[x], 1)" -> naziv + argumenti (naziv argumenta je prazan za pozicijski) }
procedure SplitCall(const ACall: string; out AName: string; AArgNames, AArgExprs: TStrings);
{ polja forme na koja se izvor poziva ([polje] u argumentima) }
procedure SourceFieldRefs(const ASource: string; ARefs: TStrings);
function SourceIsFgl(const ASource: string): Boolean;

{ popis iz teksta: "A;B;C" ili "kljuc=oznaka;..." (stupci: kljuc, oznaka) }
function OpenListSource(const ABody: string; AOwner: TComponent): TDataSet;
function OpenFglSource(ADb: TAppDb; const ABody: string; AEval: TaParamEval; AOwner: TComponent;
  out AErr: string; ATimeMs: Integer = DefaultSourceTimeMs; AMaxRows: Integer = DefaultSourceMaxRows): TDataSet;
{ tablica/upit/SQL/popis/4GL; nil + AErr kad ne uspije. Izraze (expr:, fglv:) ne otvara (vidi EvalSourceValue) }
function OpenSource(ADb: TAppDb; const ASource: string; AEval: TaParamEval; AOwner: TComponent;
  out AErr: string): TDataSet;
{ izvor koji vraca jednu vrijednost (fglv: ili expr:) }
function EvalSourceValue(ADb: TAppDb; const ASource: string; AEval: TaParamEval; out AValue: Variant;
  out AErr: string): Boolean;
{ poziv 4GL funkcije koja vraca jednu vrijednost (RETURN) }
function CallFglValue(ADb: TAppDb; const ACall: string; AEval: TaParamEval; out AValue: Variant;
  out AErr: string): Boolean;
type
  { popis vrijednosti: postavlja dijalog iz paketa editors (ta_lovdlg); True = skup podataka stoji na odabranom retku }
  TaLovPicker = function(AOwner: TComponent; ADs: TDataSet; const ATitle, AInitial: string): Boolean;

var
  LovPicker: TaLovPicker = nil;

function PickLov(AOwner: TComponent; ADs: TDataSet; const ATitle, AInitial: string): Boolean;

{ postavlja funkciju Fgl("Program.Funkcija"; arg; ...) u jeziku izraza }
procedure InstallFglHook;

implementation

uses
  ta_expr, ta_filestore, DateUtils, StrUtils;

{ ---------------- zapis izvora ---------------- }

function PickLov(AOwner: TComponent; ADs: TDataSet; const ATitle, AInitial: string): Boolean;
begin
  Result := Assigned(LovPicker) and LovPicker(AOwner, ADs, ATitle, AInitial);
end;

function StartsWithCI(const S, APrefix: string): Boolean;
begin
  Result := (Length(S) >= Length(APrefix)) and SameText(Copy(S, 1, Length(APrefix)), APrefix);
end;

function ParseSource(const AText: string): TaSourceDef;
var
  T: string;
begin
  T := Trim(AText);
  Result.Body := T;
  Result.Kind := skTable;
  if StartsWithCI(T, 'fglv:') then begin Result.Kind := skFglValue; Result.Body := Trim(Copy(T, 6, MaxInt)); end
  else if StartsWithCI(T, 'fgl:') then begin Result.Kind := skFgl; Result.Body := Trim(Copy(T, 5, MaxInt)); end
  else if StartsWithCI(T, 'sql:') then begin Result.Kind := skSql; Result.Body := Trim(Copy(T, 5, MaxInt)); end
  else if StartsWithCI(T, 'list:') then begin Result.Kind := skList; Result.Body := Copy(T, 6, MaxInt); end
  else if StartsWithCI(T, 'expr:') then begin Result.Kind := skExpr; Result.Body := Trim(Copy(T, 6, MaxInt)); end
  else if Pos('SELECT', UpperCase(TrimLeft(T))) = 1 then Result.Kind := skSql;
end;

function SourceIsFgl(const ASource: string): Boolean;
begin
  Result := ParseSource(ASource).Kind in [skFgl, skFglValue];
end;

{ razdvaja argumente po zarezima izvan zagrada, uglatih zagrada i navodnika }
procedure SplitTop(const S: string; AParts: TStrings);
var
  I, Depth, Br: Integer;
  Q: Char;
  Cur: string;
begin
  Depth := 0; Br := 0; Q := #0; Cur := '';
  for I := 1 to Length(S) do
  begin
    if Q <> #0 then
    begin
      Cur := Cur + S[I];
      if S[I] = Q then Q := #0;
      Continue;
    end;
    case S[I] of
      '''', '"': begin Q := S[I]; Cur := Cur + S[I]; end;
      '(': begin Inc(Depth); Cur := Cur + S[I]; end;
      ')': begin Dec(Depth); Cur := Cur + S[I]; end;
      '[': begin Inc(Br); Cur := Cur + S[I]; end;
      ']': begin Dec(Br); Cur := Cur + S[I]; end;
      ',', ';':
        if (Depth = 0) and (Br = 0) then begin AParts.Add(Trim(Cur)); Cur := ''; end
        else Cur := Cur + S[I];
    else
      Cur := Cur + S[I];
    end;
  end;
  if (Trim(Cur) <> '') or (AParts.Count > 0) then AParts.Add(Trim(Cur));
end;

function IsIdent(const S: string): Boolean;
var
  I: Integer;
begin
  Result := (S <> '') and (S[1] in ['A'..'Z', 'a'..'z', '_']);
  if not Result then Exit;
  for I := 2 to Length(S) do
    if not (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit(False);
end;

procedure SplitCall(const ACall: string; out AName: string; AArgNames, AArgExprs: TStrings);
var
  P, E: Integer;
  Args, Part, Nm: string;
  L: TStringList;
  I, Eq: Integer;
begin
  AArgNames.Clear;
  AArgExprs.Clear;
  P := Pos('(', ACall);
  if P = 0 then
  begin
    AName := Trim(ACall);
    Exit;
  end;
  AName := Trim(Copy(ACall, 1, P - 1));
  E := Length(ACall);
  while (E > P) and (ACall[E] <= ' ') do Dec(E);
  if ACall[E] = ')' then Dec(E);
  Args := Copy(ACall, P + 1, E - P);
  L := TStringList.Create;
  try
    SplitTop(Args, L);
    for I := 0 to L.Count - 1 do
    begin
      Part := L[I];
      if Part = '' then Continue;
      Eq := Pos('=', Part);
      Nm := '';
      if (Eq > 1) and (Eq < Length(Part)) and (Part[Eq + 1] <> '=') then
      begin
        Nm := Trim(Copy(Part, 1, Eq - 1));
        if IsIdent(Nm) then Part := Trim(Copy(Part, Eq + 1, MaxInt)) else Nm := '';
      end;
      AArgNames.Add(Nm);
      AArgExprs.Add(Part);
    end;
  finally
    L.Free;
  end;
end;

procedure SourceFieldRefs(const ASource: string; ARefs: TStrings);
var
  D: TaSourceDef;
  I, J: Integer;
  S, Nm: string;
begin
  ARefs.Clear;
  D := ParseSource(ASource);
  S := D.Body;
  if not (D.Kind in [skFgl, skFglValue, skExpr]) then Exit;
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '[' then
    begin
      J := PosEx(']', S, I + 1);
      if J = 0 then Break;
      Nm := Trim(Copy(S, I + 1, J - I - 1));
      if (Nm <> '') and (ARefs.IndexOf(Nm) < 0) then ARefs.Add(Nm);
      I := J;
    end;
    Inc(I);
  end;
end;

{ ---------------- vrijednosti ---------------- }

function LiteralValue(const AExpr: string): Variant;
var
  S: string;
  D: Double;
begin
  S := Trim(AExpr);
  if S = '' then Exit(Null);
  if (Length(S) >= 2) and (S[1] in ['''', '"']) and (S[Length(S)] = S[1]) then
    Exit(Copy(S, 2, Length(S) - 2));
  if SameText(S, 'null') then Exit(Null);
  if SameText(S, 'true') then Exit(True);
  if SameText(S, 'false') then Exit(False);
  if TryStrToFloat(StringReplace(S, ',', '.', []), D, DefaultFormatSettings) then
  begin
    if (Pos('.', S) = 0) and (Pos(',', S) = 0) and (Abs(D) < 1e15) then Exit(Int64(Round(D)));
    Exit(D);
  end;
  Result := S;
end;

function EvalArg(const AExpr: string; AEval: TaParamEval): Variant;
begin
  if Assigned(AEval) and AEval(AExpr, Result) then Exit;
  Result := LiteralValue(AExpr);
end;

{ ---------------- skup podataka ---------------- }

procedure TaFglDataSet.LoadFrom(R: TaFglResult);
var
  C, I, MaxLen: Integer;
  T: string;
  V: Variant;
  F: TField;
begin
  FieldDefs.Clear;
  for C := 0 to R.ColNames.Count - 1 do
  begin
    T := R.ColTypes[C];
    if T = 'int' then FieldDefs.Add(R.ColNames[C], ftLargeint)
    else if T = 'float' then FieldDefs.Add(R.ColNames[C], ftFloat)
    else if T = 'date' then FieldDefs.Add(R.ColNames[C], ftDate)
    else if T = 'datetime' then FieldDefs.Add(R.ColNames[C], ftDateTime)
    else if T = 'bool' then FieldDefs.Add(R.ColNames[C], ftBoolean)
    else
    begin
      MaxLen := 1;
      for I := 0 to R.RowCount - 1 do
        if (C < Length(R.Rows[I])) and not VarIsNull(R.Rows[I][C]) then
          if Length(FglAsText(R.Rows[I][C])) > MaxLen then MaxLen := Length(FglAsText(R.Rows[I][C]));
      if MaxLen > 4000 then FieldDefs.Add(R.ColNames[C], ftMemo)
      else FieldDefs.Add(R.ColNames[C], ftString, MaxLen);
    end;
  end;
  CreateDataset;
  Open;
  for I := 0 to R.RowCount - 1 do
  begin
    Append;
    for C := 0 to R.ColNames.Count - 1 do
    begin
      F := Fields[C];
      if C >= Length(R.Rows[I]) then Continue;
      V := R.Rows[I][C];
      if VarIsNull(V) or VarIsEmpty(V) then Continue;
      T := R.ColTypes[C];
      try
        if T = 'int' then F.AsLargeInt := Round(Double(V))
        else if T = 'float' then F.AsFloat := V
        else if T = 'date' then F.AsDateTime := VarToDateTime(V)
        else if T = 'datetime' then F.AsDateTime := VarToDateTime(V)
        else if T = 'bool' then F.AsBoolean := Boolean(V)
        else F.AsString := FglAsText(V);
      except
        F.AsString := FglAsText(V);
      end;
    end;
    Post;
  end;
  First;
end;

function OpenListSource(const ABody: string; AOwner: TComponent): TDataSet;
var
  Items: TStringList;
  I, P: Integer;
  S: string;
  R: TaFglResult;
  Pairs: Boolean;
  Ds: TaFglDataSet;
begin
  Items := TStringList.Create;
  R := TaFglResult.Create;
  try
    Items.Delimiter := ';';
    Items.StrictDelimiter := True;
    Items.DelimitedText := ABody;
    Pairs := False;
    for I := 0 to Items.Count - 1 do
      if Pos('=', Items[I]) > 0 then Pairs := True;
    if Pairs then begin R.AddColumn('kljuc', 'text'); R.AddColumn('oznaka', 'text'); end
    else R.AddColumn('vrijednost', 'text');
    for I := 0 to Items.Count - 1 do
    begin
      S := Items[I];
      if Trim(S) = '' then Continue;
      if Pairs then
      begin
        P := Pos('=', S);
        if P > 0 then R.AddRow([Copy(S, 1, P - 1), Copy(S, P + 1, MaxInt)])
        else R.AddRow([S, S]);
      end
      else R.AddRow([S]);
    end;
    Ds := TaFglDataSet.Create(AOwner);
    Ds.LoadFrom(R);
    Result := Ds;
  finally
    R.Free;
    Items.Free;
  end;
end;

{ ---------------- 4GL izvor ---------------- }

{ pronalazi program i funkciju za poziv "Program" ili "Program.Funkcija" }
function PrepareCall(ADb: TAppDb; const ACallName: string; out AProg: TaFglProgram; out AFunc: string;
  out AErr: string): Boolean;
var
  ProgName, Text: string;
  P: Integer;
begin
  Result := False;
  AProg := nil;
  AFunc := '';
  P := Pos('.', ACallName);
  if P > 0 then
  begin
    ProgName := Copy(ACallName, 1, P - 1);
    AFunc := Copy(ACallName, P + 1, MaxInt);
  end
  else
  begin
    ProgName := ACallName;
    AFunc := ACallName;
  end;
  Text := ADb.LoadObject('_sys_programs', ProgName);
  if Text = '' then
  begin
    AErr := 'Nema 4GL programa "' + ProgName + '"';
    Exit;
  end;
  AProg := TaFglProgram.Create;
  try
    AProg.LoadText(Text, ProgName);
  except
    on E: Exception do
    begin
      AErr := E.Message;
      FreeAndNil(AProg);
      Exit;
    end;
  end;
  { funkcija istog naziva; inace jedina funkcija programa; inace MAIN }
  if AProg.Funcs.IndexOf(LowerCase(AFunc)) < 0 then
  begin
    if (P = 0) and (AProg.Funcs.Count = 1) then AFunc := AProg.Funcs[0]
    else if (P = 0) and (AProg.Main <> nil) then AFunc := ''
    else
    begin
      AErr := 'Program "' + ProgName + '" nema funkciju "' + AFunc + '"';
      FreeAndNil(AProg);
      Exit;
    end;
  end;
  Result := True;
end;

function BuildArgs(AProg: TaFglProgram; const AFunc: string; ANames, AExprs: TStrings; AEval: TaParamEval;
  out AArgs: TVariantArray): Boolean;
var
  F: TFglFunc;
  K, I, J, Pos0: Integer;
  Found: Boolean;
begin
  Result := True;
  SetLength(AArgs, 0);
  if AFunc = '' then Exit;
  K := AProg.Funcs.IndexOf(LowerCase(AFunc));
  F := TFglFunc(AProg.Funcs.Objects[K]);
  SetLength(AArgs, F.Params.Count);
  for I := 0 to High(AArgs) do AArgs[I] := Null;
  { imenovani prvo }
  for J := 0 to ANames.Count - 1 do
    if ANames[J] <> '' then
    begin
      Found := False;
      for I := 0 to F.Params.Count - 1 do
        if SameText(F.Params[I], ANames[J]) then
        begin
          AArgs[I] := EvalArg(AExprs[J], AEval);
          Found := True;
        end;
      if not Found then Exit(False);
    end;
  { pozicijski u preostala mjesta po redu }
  Pos0 := 0;
  for J := 0 to ANames.Count - 1 do
    if ANames[J] = '' then
    begin
      while (Pos0 < F.Params.Count) and not VarIsNull(AArgs[Pos0]) do Inc(Pos0);
      if Pos0 >= F.Params.Count then Exit(False);
      AArgs[Pos0] := EvalArg(AExprs[J], AEval);
      Inc(Pos0);
    end;
end;

function RunCall(ADb: TAppDb; const ACall: string; AEval: TaParamEval; AColl: TaFglResult; out ARet: TVariantArray;
  out AErr: string; ATimeMs: Integer; out ALog: string): Boolean;
var
  Name, Func: string;
  Names, Exprs: TStringList;
  Prog: TaFglProgram;
  IO: TaFglSourceIO;
  Runner: TaFglRunner;
  Args: TVariantArray;
begin
  Result := False;
  ALog := '';
  SetLength(ARet, 0);
  Names := TStringList.Create;
  Exprs := TStringList.Create;
  try
    SplitCall(ACall, Name, Names, Exprs);
    if not PrepareCall(ADb, Name, Prog, Func, AErr) then Exit;
    try
      if not BuildArgs(Prog, Func, Names, Exprs, AEval, Args) then
      begin
        AErr := 'Argumenti ne odgovaraju parametrima funkcije ' + Func;
        Exit;
      end;
      IO := TaFglSourceIO.Create;
      Runner := TaFglRunner.Create(Prog, ADb, IO);
      try
        Runner.Collector := AColl;
        Runner.TimeLimitMs := ATimeMs;
        Result := Runner.CallFunc(Func, Args, ARet, AErr);
        ALog := Trim(IO.Log.Text);
      finally
        Runner.Free;
        IO.Free;
      end;
    finally
      Prog.Free;
    end;
  finally
    Exprs.Free;
    Names.Free;
  end;
end;

function OpenFglSource(ADb: TAppDb; const ABody: string; AEval: TaParamEval; AOwner: TComponent;
  out AErr: string; ATimeMs: Integer; AMaxRows: Integer): TDataSet;
var
  R: TaFglResult;
  Ret: TVariantArray;
  Ds: TaFglDataSet;
  T0: QWord;
  Lg: string;
begin
  Result := nil;
  R := TaFglResult.Create;
  try
    R.MaxRows := AMaxRows;
    T0 := GetTickCount64;
    if not RunCall(ADb, ABody, AEval, R, Ret, AErr, ATimeMs, Lg) then Exit;
    if R.ColNames.Count = 0 then
    begin
      AErr := 'Program nije definirao stupce (COLUMNS) niti vratio retke (EMIT)';
      Exit;
    end;
    Ds := TaFglDataSet.Create(AOwner);
    Ds.FRunMs := Integer(GetTickCount64 - T0);
    Ds.FLog := Lg;
    Ds.LoadFrom(R);
    Result := Ds;
  finally
    R.Free;
  end;
end;

function CallFglValue(ADb: TAppDb; const ACall: string; AEval: TaParamEval; out AValue: Variant;
  out AErr: string): Boolean;
var
  Ret: TVariantArray;
  Lg: string;
begin
  AValue := Null;
  Result := RunCall(ADb, ACall, AEval, nil, Ret, AErr, DefaultSourceTimeMs, Lg);
  if Result and (Length(Ret) > 0) then AValue := Ret[0];
end;

function OpenSource(ADb: TAppDb; const ASource: string; AEval: TaParamEval; AOwner: TComponent;
  out AErr: string): TDataSet;
var
  D: TaSourceDef;
begin
  Result := nil;
  AErr := '';
  D := ParseSource(ASource);
  case D.Kind of
    skFgl: Result := OpenFglSource(ADb, D.Body, AEval, AOwner, AErr);
    skList: Result := OpenListSource(D.Body, AOwner);
    skSql:
      try
        Result := ADb.NewQuery(D.Body);
        Result.Open;
      except
        on E: Exception do
        begin
          AErr := E.Message;
          FreeAndNil(Result);
        end;
      end;
    skTable:
      try
        Result := ADb.NewQuery('SELECT * FROM ' + ADb.SourceFrom(D.Body));
        Result.Open;
      except
        on E: Exception do
        begin
          AErr := E.Message;
          FreeAndNil(Result);
        end;
      end;
  else
    AErr := 'Izvor ne vraca retke: ' + ASource;
  end;
end;

function EvalSourceValue(ADb: TAppDb; const ASource: string; AEval: TaParamEval; out AValue: Variant;
  out AErr: string): Boolean;
var
  D: TaSourceDef;
begin
  AValue := Null;
  AErr := '';
  D := ParseSource(ASource);
  case D.Kind of
    skFglValue: Result := CallFglValue(ADb, D.Body, AEval, AValue, AErr);
    skExpr:
      begin
        Result := Assigned(AEval) and AEval(D.Body, AValue);
        if not Result then AErr := 'Izraz se ne moze izracunati';
      end;
  else
    Result := False;
    AErr := 'Izvor nije vrijednost: ' + ASource;
  end;
end;

{ ---------------- funkcija Fgl() u izrazima ---------------- }

function FglHookImpl(const AName: string; const A: array of Variant; N: Integer): Variant;
var
  Db: TAppDb;
  Call, Err: string;
  I: Integer;
  Prog: TaFglProgram;
  Func: string;
  Args: TVariantArray;
  Ret: TVariantArray;
  IO: TaFglSourceIO;
  Runner: TaFglRunner;
begin
  Result := Null;
  Db := ActiveStoreDb;
  if (Db = nil) or not Db.Connected then raise EExpr.Create('Fgl: baza nije otvorena');
  Call := VarToStr(A[0]);
  if not PrepareCall(Db, Call, Prog, Func, Err) then raise EExpr.Create('Fgl: ' + Err);
  try
    SetLength(Args, N - 1);
    for I := 1 to N - 1 do Args[I - 1] := A[I];
    IO := TaFglSourceIO.Create;
    Runner := TaFglRunner.Create(Prog, Db, IO);
    try
      Runner.TimeLimitMs := DefaultSourceTimeMs;
      if not Runner.CallFunc(Func, Args, Ret, Err) then raise EExpr.Create('Fgl: ' + Err);
    finally
      Runner.Free;
      IO.Free;
    end;
  finally
    Prog.Free;
  end;
  if Length(Ret) > 0 then Result := Ret[0];
end;

procedure InstallFglHook;
begin
  FglHook := @FglHookImpl;
end;

initialization
  InstallFglHook;

end.
