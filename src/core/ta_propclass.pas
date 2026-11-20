unit ta_propclass;
{ Klase svojstava i biblioteka objekata (poglavlje 19.7).
  Klasa svojstava je imenovan skup svojstava ("PoljeIznosa": Format #,##0.00, Align right, ForeColor ...). Kontrola je
  referencira svojstvom PropertyClass (Extra kljuc class); vlastita svojstva kontrole nadjacavaju klasu (klasa popunjava
  samo prazno). Pohranjena je u bazi aplikacije (objekti _sys_propclasses) kao jednostavan JSON "svojstvo": "vrijednost".
  Grupa kontrola (adresni blok, zaglavlje racuna) je imenovan skup kontrola koji se umece u formu (objekti _sys_ctlgroups).
  Biblioteka se moze izvesti u datoteku i uvesti u drugi projekt. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, ta_meta, ta_formdef, ta_controls;

const
  PropClassKind = '_sys_propclasses';
  ControlGroupKind = '_sys_ctlgroups';

{ svojstva koja klasa smije nositi (ne ukljucuje naziv, polozaj, izvor podataka) }
function PropClassNames: TStringList;
function PropClassList(ADb: TAppDb): TStringList;
{ AProps: Svojstvo=Vrijednost }
function PropClassLoad(ADb: TAppDb; const AName: string; AProps: TStrings): Boolean;
procedure PropClassSave(ADb: TAppDb; const AName: string; AProps: TStrings);
procedure PropClassDelete(ADb: TAppDb; const AName: string);
{ napuni AProps vrijednostima kontrole za svojstva iz ANames (samo neprazna) }
procedure PropClassCapture(D: TaControlDef; ANames, AProps: TStrings);
{ upisuje u kontrolu ono sto ona sama nema; vraca koliko je svojstava upisano }
function PropClassApply(D: TaControlDef; AProps: TStrings): Integer;
{ svim kontrolama forme s PropertyClass primjeni klasu iz baze; vraca broj upisanih svojstava }
function ApplyPropClasses(AForm: TaFormDef; ADb: TAppDb): Integer;

{ grupe kontrola }
function ControlGroupList(ADb: TAppDb): TStringList;
procedure ControlGroupSave(ADb: TAppDb; const AName: string; ADefs: TList);
{ umece kopije kontrola u formu pomaknute za ADX, ADY; nazivi dobivaju prefiks i brojku ako se sudaraju }
function ControlGroupInsert(ADb: TAppDb; const AName: string; ATarget: TaFormDef; ADX, ADY: Integer;
  const APrefix: string = ''): Integer;
procedure ControlGroupDelete(ADb: TAppDb; const AName: string);

{ biblioteka u datoteku: klase svojstava i grupe kontrola }
function LibraryExport(ADb: TAppDb; const AFile: string): Boolean;
{ vraca koliko je objekata uvezeno; AOverwrite = false preskace postojece }
function LibraryImport(ADb: TAppDb; const AFile: string; AOverwrite: Boolean): Integer;

function CloneControl(S: TaControlDef): TaControlDef;

implementation

const
  Capturable = 'Format,Align,Bold,Italic,Locked,Tip,FontName,FontSize,ForeColor,BackColor,BorderWidth,CondFormat,VisibleIf,EnabledIf,Icon';

function PropClassNames: TStringList;
begin
  Result := TStringList.Create;
  Result.CommaText := Capturable;
end;

function PropClassList(ADb: TAppDb): TStringList;
begin
  Result := ADb.ListObjects(PropClassKind);
end;

function PropClassLoad(ADb: TAppDb; const AName: string; AProps: TStrings): Boolean;
var
  S: string;
  J: TJSONData;
  O: TJSONObject;
  I: Integer;
begin
  Result := False;
  AProps.Clear;
  S := ADb.LoadObject(PropClassKind, AName);
  if Trim(S) = '' then Exit;
  try
    J := GetJSON(S);
  except
    Exit;
  end;
  try
    if not (J is TJSONObject) then Exit;
    O := TJSONObject(J);
    for I := 0 to O.Count - 1 do AProps.Values[O.Names[I]] := O.Items[I].AsString;
    Result := True;
  finally
    J.Free;
  end;
end;

procedure PropClassSave(ADb: TAppDb; const AName: string; AProps: TStrings);
var
  O: TJSONObject;
  I: Integer;
begin
  O := TJSONObject.Create;
  try
    for I := 0 to AProps.Count - 1 do
      if AProps.Names[I] <> '' then O.Add(AProps.Names[I], AProps.ValueFromIndex[I]);
    ADb.SaveObject(PropClassKind, AName, O.AsJSON);
  finally
    O.Free;
  end;
end;

procedure PropClassDelete(ADb: TAppDb; const AName: string);
begin
  ADb.DeleteObject(PropClassKind, AName);
end;

procedure PropClassCapture(D: TaControlDef; ANames, AProps: TStrings);
var
  I: Integer;
  V: string;
begin
  AProps.Clear;
  for I := 0 to ANames.Count - 1 do
  begin
    V := DefGet(D, ANames[I]);
    if (V <> '') and (V <> 'False') then AProps.Values[ANames[I]] := V;
  end;
end;

function PropClassApply(D: TaControlDef; AProps: TStrings): Integer;
var
  I: Integer;
  K, Cur: string;
begin
  Result := 0;
  for I := 0 to AProps.Count - 1 do
  begin
    K := AProps.Names[I];
    if K = '' then Continue;
    Cur := DefGet(D, K);
    if (Cur = '') or (Cur = 'False') then
    begin
      DefSet(D, K, AProps.ValueFromIndex[I]);
      Inc(Result);
    end;
  end;
end;

function ApplyPropClasses(AForm: TaFormDef; ADb: TAppDb): Integer;
var
  I: Integer;
  Cn: string;
  Cache: TStringList;
  Props: TStringList;
  Idx: Integer;
begin
  Result := 0;
  if (AForm = nil) or (ADb = nil) or not ADb.Connected then Exit;
  Cache := TStringList.Create;      { naziv klase -> popis svojstava (objekt) }
  try
    for I := 0 to AForm.Count - 1 do
    begin
      Cn := Trim(AForm[I].GetX('class'));
      if Cn = '' then Continue;
      Idx := Cache.IndexOf(Cn);
      if Idx < 0 then
      begin
        Props := TStringList.Create;
        if not PropClassLoad(ADb, Cn, Props) then Props.Clear;
        Idx := Cache.AddObject(Cn, Props);
      end;
      Result := Result + PropClassApply(AForm[I], TStringList(Cache.Objects[Idx]));
    end;
  finally
    for I := 0 to Cache.Count - 1 do Cache.Objects[I].Free;
    Cache.Free;
  end;
end;

function CloneControl(S: TaControlDef): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := S.Kind; Result.Name := S.Name; Result.Caption := S.Caption;
  Result.ControlSource := S.ControlSource; Result.RowSource := S.RowSource; Result.OnClick := S.OnClick;
  Result.LinkMaster := S.LinkMaster; Result.LinkChild := S.LinkChild;
  Result.Section := S.Section; Result.Align := S.Align; Result.Format := S.Format; Result.Bold := S.Bold;
  Result.Left := S.Left; Result.Top := S.Top; Result.Width := S.Width; Result.Height := S.Height;
  Result.Extra := S.Extra;
end;

function ControlGroupList(ADb: TAppDb): TStringList;
begin
  Result := ADb.ListObjects(ControlGroupKind);
end;

procedure ControlGroupSave(ADb: TAppDb; const AName: string; ADefs: TList);
var
  F: TaFormDef;
  I, MinL, MinT: Integer;
begin
  F := TaFormDef.Create;
  try
    MinL := MaxInt; MinT := MaxInt;
    for I := 0 to ADefs.Count - 1 do
    begin
      if TaControlDef(ADefs[I]).Left < MinL then MinL := TaControlDef(ADefs[I]).Left;
      if TaControlDef(ADefs[I]).Top < MinT then MinT := TaControlDef(ADefs[I]).Top;
    end;
    for I := 0 to ADefs.Count - 1 do
      with F.Add(CloneControl(TaControlDef(ADefs[I]))) do
      begin
        { polozaj je u grupi relativan prema lijevom gornjem kutu }
        Left := Left - MinL;
        Top := Top - MinT;
      end;
    F.Name := AName;
    ADb.SaveObject(ControlGroupKind, AName, F.ToJson);
  finally
    F.Free;
  end;
end;

function ControlGroupInsert(ADb: TAppDb; const AName: string; ATarget: TaFormDef; ADX, ADY: Integer;
  const APrefix: string): Integer;
var
  F: TaFormDef;
  I, N: Integer;
  C: TaControlDef;
  Nm: string;
begin
  Result := 0;
  F := TaFormDef.Create;
  try
    F.FromJson(ADb.LoadObject(ControlGroupKind, AName));
    for I := 0 to F.Count - 1 do
    begin
      C := CloneControl(F[I]);
      C.Left := C.Left + ADX;
      C.Top := C.Top + ADY;
      Nm := APrefix + C.Name;
      N := 1;
      while ATarget.IndexOfName(Nm) >= 0 do
      begin
        Inc(N);
        Nm := APrefix + C.Name + IntToStr(N);
      end;
      C.Name := Nm;
      ATarget.Add(C);
      Inc(Result);
    end;
  finally
    F.Free;
  end;
end;

procedure ControlGroupDelete(ADb: TAppDb; const AName: string);
begin
  ADb.DeleteObject(ControlGroupKind, AName);
end;

function LibraryExport(ADb: TAppDb; const AFile: string): Boolean;
var
  O, Cls, Grp: TJSONObject;
  L: TStringList;
  I: Integer;
  SL: TStringList;
begin
  Result := False;
  O := TJSONObject.Create;
  try
    Cls := TJSONObject.Create;
    Grp := TJSONObject.Create;
    L := PropClassList(ADb);
    try
      for I := 0 to L.Count - 1 do Cls.Add(L[I], ADb.LoadObject(PropClassKind, L[I]));
    finally
      L.Free;
    end;
    L := ControlGroupList(ADb);
    try
      for I := 0 to L.Count - 1 do Grp.Add(L[I], ADb.LoadObject(ControlGroupKind, L[I]));
    finally
      L.Free;
    end;
    O.Add('format', 'typhaccess-library');
    O.Add('version', 1);
    O.Add('propClasses', Cls);
    O.Add('controlGroups', Grp);
    SL := TStringList.Create;
    try
      SL.Text := O.FormatJSON;
      try
        SL.SaveToFile(AFile);
        Result := True;
      except
        Result := False;
      end;
    finally
      SL.Free;
    end;
  finally
    O.Free;
  end;
end;

function LibraryImport(ADb: TAppDb; const AFile: string; AOverwrite: Boolean): Integer;
var
  SL: TStringList;
  J: TJSONData;
  Sec: TJSONData;
  I, K: Integer;
  Kinds: array[0..1] of string;
  Keys: array[0..1] of string;
begin
  Result := 0;
  if not FileExists(AFile) then Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(AFile);
    try
      J := GetJSON(SL.Text);
    except
      Exit;
    end;
  finally
    SL.Free;
  end;
  try
    if not (J is TJSONObject) or (TJSONObject(J).Get('format', '') <> 'typhaccess-library') then Exit;
    Kinds[0] := PropClassKind; Keys[0] := 'propClasses';
    Kinds[1] := ControlGroupKind; Keys[1] := 'controlGroups';
    for K := 0 to 1 do
    begin
      Sec := TJSONObject(J).Find(Keys[K]);
      if not (Sec is TJSONObject) then Continue;
      for I := 0 to TJSONObject(Sec).Count - 1 do
      begin
        if (not AOverwrite) and (ADb.LoadObject(Kinds[K], TJSONObject(Sec).Names[I]) <> '') then Continue;
        ADb.SaveObject(Kinds[K], TJSONObject(Sec).Names[I], TJSONObject(Sec).Items[I].AsString);
        Inc(Result);
      end;
    end;
  finally
    J.Free;
  end;
end;

end.
