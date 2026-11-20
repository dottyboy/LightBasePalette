unit ta_formdash;
{ Prikaz forme "nadzorna ploca" (ViewMode = dash): izvor je upit s retkom po mjernoj vrijednosti, kartice su skupine (npr. pogoni).
  Postavka (TaFormDef.Dash), dijelovi odvojeni s " ;; ":
    grupa=Pogon ;; naziv=Uredjaj ;; vrijednost=Vrijednost ;; jedinica=Jedinica ;; stanje=Stanje ;; info=Signal
    ;; serija=SELECT vrijednost FROM ocitanja WHERE uredjaj_id = :id ORDER BY vrijeme DESC, id DESC LIMIT 60 ;; osvjezi=5
  Prekidaci (nije obavezno): uloga=Uloga (redak s vrijednoscu "izvrsni" je prekidac: vrijednost veca od 0 je uklju., cekanje=Cekanje (1 dok naredba
    nije potvrdjena), klik=INSERT ... (:id, :akcija; akcija je "ukljuci" ili "iskljuci"), potvrdi=da|ne (pita prije slanja);
    alarmi=Alarmi (broj otvorenih alarma u retku; skupina s alarmom je crvena i pise koliko ih je).
  Izvor mora imati stupac id (u serija se vraca kao :id). Stanje: tekst koji sadrzi PRENISKO ili PREVISOKO je izvan granica,
  "nema" je bez podataka. Osvjezavanje (sekunde) je nije obavezno. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Dialogs, DB, ta_meta, ta_formdef, ta_owndash;

type
  TaDashBody = class(TPanel)
  private
    FDb: TAppDb;
    FDef: TaFormDef;
    FDash: TaOwnDash;
    FTimer: TTimer;
    FGroupF, FNameF, FValueF, FUnitF, FStateF, FInfoF, FSeriesSql: string;
    FRoleF, FPendingF, FClickSql, FAlertsF: string;
    FConfirm: Boolean;
    FRefresh: Integer;
    procedure Parse(const AValue: string);
    procedure Tick(Sender: TObject);
    procedure ItemClick(Sender: TObject; const AId: string);
    function ReadSeries(const AId: string; out ACount: Integer): TStringList;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Setup(ADb: TAppDb; ADef: TaFormDef);
    procedure Reload;
    property Dash: TaOwnDash read FDash;
  end;

function CheckDashSetting(const ASetting: string): string;

implementation

uses
  ZDataset, ta_types, ta_i18n;

function ValOf(const ASetting, AKey: string): string;
var
  L: TStringList;
  I, P: Integer;
  S: string;
begin
  Result := '';
  L := TStringList.Create;
  try
    S := StringReplace(ASetting, ';;', #1, [rfReplaceAll]);
    L.Delimiter := #1;
    L.StrictDelimiter := True;
    L.DelimitedText := S;
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      P := Pos('=', S);
      if (P > 0) and SameText(Trim(Copy(S, 1, P - 1)), AKey) then Exit(Trim(Copy(S, P + 1, MaxInt)));
    end;
  finally
    L.Free;
  end;
end;

function CheckDashSetting(const ASetting: string): string;
begin
  Result := '';
  if (ValOf(ASetting, 'grupa') = '') or (ValOf(ASetting, 'naziv') = '') or (ValOf(ASetting, 'vrijednost') = '') then
    Result := Tr('The dashboard needs the group, name and value fields.');
end;

constructor TaDashBody.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FDash := TaOwnDash.Create(Self);
  FDash.Parent := Self;
  FDash.Align := alClient;
  FDash.OnItemClick := @ItemClick;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.OnTimer := @Tick;
end;

procedure TaDashBody.Parse(const AValue: string);
begin
  FGroupF := ValOf(AValue, 'grupa');
  FNameF := ValOf(AValue, 'naziv');
  FValueF := ValOf(AValue, 'vrijednost');
  FUnitF := ValOf(AValue, 'jedinica');
  FStateF := ValOf(AValue, 'stanje');
  FInfoF := ValOf(AValue, 'info');
  FSeriesSql := ValOf(AValue, 'serija');
  FRefresh := StrToIntDef(ValOf(AValue, 'osvjezi'), 0);
  FRoleF := ValOf(AValue, 'uloga');
  FPendingF := ValOf(AValue, 'cekanje');
  FClickSql := ValOf(AValue, 'klik');
  FAlertsF := ValOf(AValue, 'alarmi');
  FConfirm := not SameText(ValOf(AValue, 'potvrdi'), 'ne');
end;

procedure TaDashBody.Setup(ADb: TAppDb; ADef: TaFormDef);
begin
  FDb := ADb;
  FDef := ADef;
  Parse(ADef.Dash);
  Reload;
  if FRefresh > 0 then
  begin
    FTimer.Interval := FRefresh * 1000;
    FTimer.Enabled := True;
  end;
end;

procedure TaDashBody.ItemClick(Sender: TObject; const AId: string);
var
  I: Integer;
  It: TaDashItem;
  Act: string;
  Q: TZQuery;
begin
  if (FClickSql = '') or (FDef = nil) or not FDef.AllowEdits then Exit;
  for I := 0 to FDash.ItemCount - 1 do
  begin
    It := FDash.ItemAt(I);
    if (It.Id <> AId) or (It.Kind <> 1) then Continue;
    if It.On then Act := 'iskljuci' else Act := 'ukljuci';
    if FConfirm then
      if MessageDlg(Tr('Send the command?'), Tr(Act) + ': ' + It.Group + ' - ' + It.Name, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
    Q := FDb.NewQuery(FClickSql);
    try
      if Q.Params.FindParam('id') <> nil then Q.ParamByName('id').AsString := AId;
      if Q.Params.FindParam('akcija') <> nil then Q.ParamByName('akcija').AsString := Act;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
    Reload;
    Exit;
  end;
end;

procedure TaDashBody.Tick(Sender: TObject);
begin
  if Visible and (Parent <> nil) then
    try
      Reload;
    except
      FTimer.Enabled := False;
    end;
end;

function TaDashBody.ReadSeries(const AId: string; out ACount: Integer): TStringList;
var
  Q: TZQuery;
begin
  Result := TStringList.Create;
  ACount := 0;
  if FSeriesSql = '' then Exit;
  Q := FDb.NewQuery(FSeriesSql);
  try
    if Q.Params.FindParam('id') <> nil then Q.ParamByName('id').AsString := AId;
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Q.Fields[0].AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  ACount := Result.Count;
end;

procedure TaDashBody.Reload;
var
  Q: TZQuery;
  Ser: TStringList;
  Arr: array of Double;
  I, N, St: Integer;
  Id, S, StateTxt, ValTxt, UnitTxt, InfoTxt: string;
  F: TField;
  D: Double;
  Itm: TaDashItem;
begin
  if FDb = nil then Exit;
  FDash.Clear;
  Q := FDb.NewQuery('SELECT * FROM (' + FDb.SourceSql(FDef.RecordSource) + ')');
  try
    Q.Open;
    while not Q.EOF do
    begin
      if Q.FindField('id') <> nil then Id := Q.FieldByName('id').AsString else Id := IntToStr(Q.RecNo);
      Ser := ReadSeries(Id, N);
      try
        SetLength(Arr, N);
        for I := 0 to N - 1 do
        begin
          { upit vraca najnovije prvo; crta se od starijeg prema novijem }
          S := Ser[N - 1 - I];
          if not TryStrToFloat(S, D, InvariantFS) then
            if not TryStrToFloat(S, D) then D := 0;
          Arr[I] := D;
        end;
      finally
        Ser.Free;
      end;
      F := Q.FindField(FValueF);
      if (F <> nil) and not F.IsNull then
      begin
        if F.DataType in [ftFloat, ftBCD, ftFMTBcd, ftCurrency] then ValTxt := FormatFloat('0.##', F.AsFloat)
        else if TryStrToFloat(F.AsString, D, InvariantFS) then ValTxt := FormatFloat('0.##', D)
        else ValTxt := F.AsString;
      end
      else ValTxt := '';
      UnitTxt := '';
      if (FUnitF <> '') and (Q.FindField(FUnitF) <> nil) then UnitTxt := Q.FieldByName(FUnitF).AsString;
      InfoTxt := '';
      if (FInfoF <> '') and (Q.FindField(FInfoF) <> nil) then InfoTxt := Q.FieldByName(FInfoF).AsString;
      StateTxt := '';
      if (FStateF <> '') and (Q.FindField(FStateF) <> nil) then StateTxt := Q.FieldByName(FStateF).AsString;
      St := 0;
      if (Pos('PRENISKO', StateTxt) > 0) or (Pos('PREVISOKO', StateTxt) > 0) then St := 1
      else if (Pos('nema', LowerCase(StateTxt)) > 0) or (ValTxt = '') then St := 2;
      Itm := FDash.AddItem(Id, Q.FieldByName(FGroupF).AsString, InfoTxt, Q.FieldByName(FNameF).AsString, ValTxt, UnitTxt, St, Arr);
      if (FRoleF <> '') and (Q.FindField(FRoleF) <> nil) and SameText(Q.FieldByName(FRoleF).AsString, 'izvrsni') then
      begin
        Itm.Kind := 1;
        Itm.State := 0;
        F := Q.FindField(FValueF);
        Itm.On := (F <> nil) and not F.IsNull and (F.AsFloat > 0);
        if (FPendingF <> '') and (Q.FindField(FPendingF) <> nil) then Itm.Pending := Q.FieldByName(FPendingF).AsInteger > 0;
      end;
      if (FAlertsF <> '') and (Q.FindField(FAlertsF) <> nil) then Itm.Alerts := Q.FieldByName(FAlertsF).AsInteger;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  FDash.EndUpdate;
end;

end.
