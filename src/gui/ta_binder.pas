unit ta_binder;
{ TaFormBinder: "Access" ponasanje na bilo kojim kontrolama (LCL, JVCL, RX). Ne nasljeduje kontrole, nego se vezuje uz
  TDataSource i uz svaku kontrolu po jedna stavka zbirke Bindings:
    FieldName      polje; kontrole s DataSource/DataField (TRxDB*, TJvDB*, TDB*) vezu dobiju same (RTTI)
    Expression     izracunato: izraz jezika TyphAccessa, npr. [kolicina] * [cijena]; uz FieldName se rezultat
                   upisuje u polje dok je zapis u uredjivanju, bez FieldName samo se prikaze
    Rule           pravilo provjere, npr. [kolicina] > 0 ; RuleMessage je poruka; neispunjeno pravilo oboja
                   kontrolu, a Post se odbija (EBinderValidation)
    DefaultValue   izraz za zadanu vrijednost polja pri unosu novog zapisa
    VisibleIf, EnabledIf   izraz koji prikazuje / omogucuje kontrolu
    CondFormat     uvjetno oblikovanje: [iznos] > 1000 => #C00000 #FFE9E9 bold
    Format         oblik prikaza ( #,##0.00 ) za kontrole s DisplayFormat/DecimalPlaces
  Izrazi vide polja tekuceg zapisa kao [ime_polja] i sve funkcije jezika (DLookup, Zaokruzi, IIf...).
  Locale = blCroatian postavlja hrvatske oblike brojeva i datuma (1.234,50  31.12.2026.). }

{$mode objfpc}{$H+}

interface

uses
  ta_bindengine,
  Classes, SysUtils, Math, Variants, TypInfo, DB, Controls, Graphics, Spin, ta_meta, ta_expr, ta_exprdb, ta_condfmt, ta_components, ta_edit, ta_source, ta_lovdlg, Forms;

type
  EBinderValidation = class(Exception);
  { da se TDataSource moze koristiti bez unita DB }
  TaDataSource = TDataSource;

  TaBinderLocale = (blCroatian, blSystem);

  TaFormBinder = class;

  TaBinding = class(TCollectionItem)
  private
    FControl: TControl;
    FFieldName, FExpression, FRule, FRuleMessage, FDefaultValue, FVisibleIf, FEnabledIf, FCondFormat, FFormat: string;
    FFailed: Boolean;
    procedure SetControl(AValue: TControl);
    procedure SetFieldName(const AValue: string);
    procedure SetFormat(const AValue: string);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(ASource: TPersistent); override;
    { pravilo je u zadnjoj provjeri bilo neispunjeno }
    property Failed: Boolean read FFailed;
  published
    property Control: TControl read FControl write SetControl;
    property FieldName: string read FFieldName write SetFieldName;
    property Expression: string read FExpression write FExpression;
    property Rule: string read FRule write FRule;
    property RuleMessage: string read FRuleMessage write FRuleMessage;
    property DefaultValue: string read FDefaultValue write FDefaultValue;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property CondFormat: string read FCondFormat write FCondFormat;
    property Format: string read FFormat write SetFormat;
  end;

  TaBindings = class(TOwnedCollection)
  private
    function GetItem(AIndex: Integer): TaBinding;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TaBinding;
    function ForControl(AControl: TControl): TaBinding;
    property Items[AIndex: Integer]: TaBinding read GetItem; default;
  end;

  TaValidationEvent = procedure(Sender: TObject; ABinding: TaBinding; const AMessage: string; var ARaise: Boolean) of object;

  TBinderLink = class(TDataLink)
  public
    Binder: TaFormBinder;
  protected
    procedure ActiveChanged; override;
    procedure DataSetChanged; override;
    procedure RecordChanged(AField: TField); override;
    procedure EditingChanged; override;
  end;

  TStyleRec = record
    Ctl: TControl;
    Color, FontColor: TColor;
    FontStyle: TFontStyles;
  end;

  { druga veza na isti izvor, registrirana POSLIJE veza kontrola: obavijesti stizu redom registracije, pa ona
    ispravlja ono sto kontrole same postave pri pomaku zapisa (RX spin ponovno postavlja decimale iz polja) }
  TBinderLateLink = class(TDataLink)
  public
    Binder: TaFormBinder;
  protected
    procedure DataSetChanged; override;
    procedure RecordChanged(AField: TField); override;
  end;

  TaFormBinder = class(TComponent)
  private
    FLate: TBinderLateLink;
    FStyles: array of TStyleRec;
    FBindings: TaBindings;
    FLink: TBinderLink;
    FDatabase: TaDatabase;
    FLocale: TaBinderLocale;
    FBusy, FInsertDone, FLocaleDone: Boolean;
    FOldBeforePost: TDataSetNotifyEvent;
    FHooked: TDataSet;
    FErrors: TStringList;
    FOnValidationFailed: TaValidationEvent;
    FOnRefreshed: TNotifyEvent;
    function GetDataSource: TDataSource;
    procedure SetDataSource(AValue: TDataSource);
    procedure SetDatabase(AValue: TaDatabase);
    procedure SetBindings(AValue: TaBindings);
    procedure HookDataSet;
    procedure UnhookDataSet;
    procedure DoBeforePost(ADataSet: TDataSet);
    procedure ApplyLocale;
    procedure ConnectControls;
    procedure LovRequest(Sender: TObject);
    function LovCheck(B: TaBinding): string;
    procedure FormatFields;
    procedure FixSpins;
    function Eval(const AExpr: string; out AErr: string): Variant;
    function Truthy(const V: Variant): Boolean;
    procedure ApplyDefaults;
    function StyleIndex(AControl: TControl): Integer;
    procedure SetControlValue(AControl: TControl; const V: Variant);
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { ponovo izracuna izracunata polja, vidljivost, boje i pravila za tekuci zapis }
    { poveze kontrole i skup podataka (pri ucitavanju forme to se radi samo; pozovi nakon sastavljanja u kodu) }
    procedure Activate;
    procedure Refresh;
    { provjeri sva pravila tekuceg zapisa; Errors dobiva poruke neispunjenih }
    function Validate: Boolean;
    property Errors: TStringList read FErrors;
  published
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property Database: TaDatabase read FDatabase write SetDatabase;
    property Bindings: TaBindings read FBindings write SetBindings;
    property Locale: TaBinderLocale read FLocale write FLocale default blCroatian;
    { neispunjeno pravilo pri Post: dogadjaj moze postaviti ARaise := False da dopusti spremanje }
    property OnValidationFailed: TaValidationEvent read FOnValidationFailed write FOnValidationFailed;
    property OnRefreshed: TNotifyEvent read FOnRefreshed write FOnRefreshed;
  end;

{ hrvatski oblici (1.234,50  31.12.2026.); pozovi prije stvaranja formi }
procedure ApplyCroatianLocale;

implementation

uses
  ta_i18n;


const
  RuleBad = RuleBadColor;      { svijetlocrvena pozadina neispravne kontrole (BGR), zajednicko s runnerom }

{ ---------------- RTTI pomocnici ---------------- }

function HasProp(AObj: TObject; const AName: string): Boolean;
begin
  Result := GetPropInfo(AObj, AName) <> nil;
end;

function PropKind(AObj: TObject; const AName: string): TTypeKind;
var
  PI: PPropInfo;
begin
  PI := GetPropInfo(AObj, AName);
  if PI = nil then Result := tkUnknown else Result := PI^.PropType^.Kind;
end;

{ ---------------- TaBinding ---------------- }

constructor TaBinding.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
end;

procedure TaBinding.Assign(ASource: TPersistent);
var
  B: TaBinding;
begin
  if ASource is TaBinding then
  begin
    B := TaBinding(ASource);
    FControl := B.FControl; FFieldName := B.FFieldName; FExpression := B.FExpression; FRule := B.FRule;
    FRuleMessage := B.FRuleMessage; FDefaultValue := B.FDefaultValue; FVisibleIf := B.FVisibleIf;
    FEnabledIf := B.FEnabledIf; FCondFormat := B.FCondFormat; FFormat := B.FFormat;
    Changed(False);
  end
  else inherited Assign(ASource);
end;

function TaBinding.GetDisplayName: string;
begin
  if FControl <> nil then Result := FControl.Name else Result := inherited GetDisplayName;
  if FFieldName <> '' then Result := Result + ' -> ' + FFieldName;
end;

procedure TaBinding.SetControl(AValue: TControl);
begin
  if FControl = AValue then Exit;
  FControl := AValue;
  if (AValue <> nil) and (Collection <> nil) and (Collection.Owner is TComponent) then AValue.FreeNotification(TComponent(Collection.Owner));
  Changed(False);
end;

procedure TaBinding.SetFieldName(const AValue: string);
begin
  if FFieldName = AValue then Exit;
  FFieldName := AValue;
  Changed(False);
end;

procedure TaBinding.SetFormat(const AValue: string);
begin
  if FFormat = AValue then Exit;
  FFormat := AValue;
  Changed(False);
end;

constructor TaBindings.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TaBinding);
end;

function TaBindings.GetItem(AIndex: Integer): TaBinding;
begin
  Result := TaBinding(inherited Items[AIndex]);
end;

function TaBindings.Add: TaBinding;
begin
  Result := TaBinding(inherited Add);
end;

function TaBindings.ForControl(AControl: TControl): TaBinding;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Control = AControl then Exit(Items[I]);
  Result := nil;
end;

{ ---------------- veza na skup podataka ---------------- }

procedure TBinderLateLink.DataSetChanged;
begin
  inherited DataSetChanged;
  Binder.FixSpins;
end;

procedure TBinderLateLink.RecordChanged(AField: TField);
begin
  inherited RecordChanged(AField);
  Binder.FixSpins;
end;

procedure TBinderLink.ActiveChanged;
begin
  inherited ActiveChanged;
  Binder.HookDataSet;
  Binder.Refresh;
end;

procedure TBinderLink.DataSetChanged;
begin
  inherited DataSetChanged;
  Binder.Refresh;
end;

procedure TBinderLink.RecordChanged(AField: TField);
begin
  inherited RecordChanged(AField);
  Binder.Refresh;
end;

procedure TBinderLink.EditingChanged;
begin
  inherited EditingChanged;
  Binder.Refresh;
end;

{ ---------------- domacin izraza ---------------- }

type
  TBinderHost = class(TaExprHost)
  public
    Binder: TaFormBinder;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
  end;

function TBinderHost.FieldValue(const AName: string): Variant;
var
  F: TField;
begin
  Result := Null;
  if (Binder.DataSource = nil) or (Binder.DataSource.DataSet = nil) or not Binder.DataSource.DataSet.Active then Exit;
  F := Binder.DataSource.DataSet.FindField(AName);
  if (F <> nil) and not F.IsNull then Result := F.Value;
end;

function TBinderHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TBinderHost.Variable(const AName: string): Variant;
begin
  Result := FieldValue(AName);
end;

function TBinderHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  if (Binder.FDatabase <> nil) and Binder.FDatabase.Connected then
    Result := DbDomain(Binder.FDatabase.Db, AFunc, AExpr, ADomain, ACriteria)
  else Result := Null;
end;

{ ---------------- TaFormBinder ---------------- }

constructor TaFormBinder.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBindings := TaBindings.Create(Self);
  FLink := TBinderLink.Create;
  FLink.Binder := Self;
  FLate := TBinderLateLink.Create;
  FLate.Binder := Self;
  FErrors := TStringList.Create;
  FLocale := blCroatian;
end;

destructor TaFormBinder.Destroy;
begin
  UnhookDataSet;
  FLate.Free;
  FLink.Free;
  FBindings.Free;
  FErrors.Free;
  inherited Destroy;
end;

function TaFormBinder.GetDataSource: TDataSource;
begin
  Result := FLink.DataSource;
end;

procedure TaFormBinder.SetDataSource(AValue: TDataSource);
begin
  if FLink.DataSource = AValue then Exit;
  UnhookDataSet;
  FLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
  ConnectControls;
end;

procedure TaFormBinder.SetDatabase(AValue: TaDatabase);
begin
  if FDatabase = AValue then Exit;
  FDatabase := AValue;
  if FDatabase <> nil then FDatabase.FreeNotification(Self);
end;

procedure TaFormBinder.SetBindings(AValue: TaBindings);
begin
  FBindings.Assign(AValue);
end;

procedure TaFormBinder.Notification(AComponent: TComponent; AOperation: TOperation);
var
  I: Integer;
begin
  inherited Notification(AComponent, AOperation);
  if AOperation <> opRemove then Exit;
  if AComponent = FDatabase then FDatabase := nil;
  if (FLink <> nil) and (AComponent = FLink.DataSource) then begin UnhookDataSet; FLink.DataSource := nil; end;
  if FBindings <> nil then
    for I := 0 to FBindings.Count - 1 do
      if FBindings[I].FControl = AComponent then FBindings[I].FControl := nil;
  for I := High(FStyles) downto 0 do
    if FStyles[I].Ctl = AComponent then
    begin
      FStyles[I] := FStyles[High(FStyles)];
      SetLength(FStyles, High(FStyles));
    end;
end;

procedure TaFormBinder.Loaded;
begin
  inherited Loaded;
  Activate;
end;

procedure TaFormBinder.Activate;
begin
  if csDesigning in ComponentState then Exit;
  ApplyLocale;
  ConnectControls;
  { kasna veza: tek sad, nakon sto su kontrole registrirale svoje }
  FLate.DataSource := nil;
  FLate.DataSource := FLink.DataSource;
  HookDataSet;
  Refresh;
  FixSpins;
end;

{ hrvatski oblici brojeva i datuma u globalnim postavkama programa. Kontrole (npr. spin) pamte oblike pri stvaranju,
  pa je najbolje pozvati ovo u .lpr prije Application.CreateForm; binder to ponovi pri pokretanju ako nije vec }
procedure ApplyCroatianLocale;
begin
  DefaultFormatSettings.DecimalSeparator := ',';
  DefaultFormatSettings.ThousandSeparator := '.';
  DefaultFormatSettings.DateSeparator := '.';
  DefaultFormatSettings.ShortDateFormat := 'dd.mm.yyyy';
  DefaultFormatSettings.LongDateFormat := 'dd. mmmm yyyy.';
  DefaultFormatSettings.CurrencyString := '€';
  DefaultFormatSettings.CurrencyFormat := 3;       { 1.234,50 € }
  DefaultFormatSettings.CurrencyDecimals := 2;
end;

procedure TaFormBinder.ApplyLocale;
begin
  if FLocaleDone or (FLocale <> blCroatian) then Exit;
  FLocaleDone := True;
  ApplyCroatianLocale;
end;

{ kontrole s DataSource/DataField dobiju vezu same (RTTI), oblik prikaza ide u DisplayFormat/DecimalPlaces }
{ najvise decimala iz oblika (0 i # iza tocke) i najmanje (samo 0): '0.##' -> 2 i 0, '#,##0.00' -> 2 i 2 }
function DecimalsOf(const AFormat: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := Pos('.', AFormat);
  if P = 0 then Exit;
  Inc(P);
  while (P <= Length(AFormat)) and (AFormat[P] in ['0', '#']) do begin Inc(Result); Inc(P); end;
end;

function MinDecimalsOf(const AFormat: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := Pos('.', AFormat);
  if P = 0 then Exit;
  Inc(P);
  while (P <= Length(AFormat)) and (AFormat[P] in ['0', '#']) do begin if AFormat[P] = '0' then Inc(Result); Inc(P); end;
end;

{ koliko decimala vrijednost stvarno treba, od AMin do AMax (2,5 -> 1; 2,51 -> 2; 3 -> 0) }
function SignificantDecimals(AValue: Double; AMin, AMax: Integer): Integer;
var
  N: Integer;
  Scaled: Double;
begin
  Result := AMax;
  Scaled := Abs(AValue) * IntPower(10, AMax);
  Scaled := Round(Scaled);
  N := AMax;
  while (N > AMin) and (Frac(Scaled / 10) = 0) do begin Scaled := Scaled / 10; Dec(N); end;
  Result := N;
end;

procedure TaFormBinder.FixSpins;
var
  I, Want: Integer;
  B: TaBinding;
  Sp: TCustomFloatSpinEdit;
  V: Double;
  Stale: Boolean;
begin
  for I := 0 to FBindings.Count - 1 do
  begin
    B := FBindings[I];
    if (B.FFormat = '') or not (B.FControl is TCustomFloatSpinEdit) then Continue;
    Sp := TCustomFloatSpinEdit(B.FControl);
    V := Sp.Value;
    { '0.##': decimale prema vrijednosti (2,51 -> 2, 3 -> 0); '0.00': uvijek dvije }
    Want := SignificantDecimals(V, MinDecimalsOf(B.FFormat), DecimalsOf(B.FFormat));
    if Sp.DecimalPlaces <> Want then Sp.DecimalPlaces := Want;
    { tekst nastao prije hrvatskih oblika ima staru tocku: ponovno ga prikazi }
    Stale := (DefaultFormatSettings.DecimalSeparator <> '.') and (Pos('.', Sp.Text) > 0);
    if Stale then begin Sp.Value := V + 1; Sp.Value := V; end;
  end;
end;

procedure TaFormBinder.FormatFields;
var
  I: Integer;
  DS: TDataSet;
  F: TField;
  B: TaBinding;
begin
  if (FLink.DataSource = nil) or (FLink.DataSource.DataSet = nil) or not FLink.DataSource.DataSet.Active then Exit;
  DS := FLink.DataSource.DataSet;
  if FLocale = blCroatian then
    for I := 0 to DS.FieldCount - 1 do
    begin
      F := DS.Fields[I];
      if (F is TDateTimeField) and (TDateTimeField(F).DisplayFormat = '') then
        if F.DataType = ftDate then TDateTimeField(F).DisplayFormat := 'dd.mm.yyyy'
        else if F.DataType = ftDateTime then TDateTimeField(F).DisplayFormat := 'dd.mm.yyyy hh:nn';
    end;
  { Format stavke vrijedi i za prikaz polja u mrezi }
  for I := 0 to FBindings.Count - 1 do
  begin
    B := FBindings[I];
    if (B.FFieldName = '') or (B.FFormat = '') then Continue;
    F := DS.FindField(B.FFieldName);
    if (F is TNumericField) then TNumericField(F).DisplayFormat := B.FFormat;

  end;
end;

procedure TaFormBinder.ConnectControls;
var
  I, P, Dec: Integer;
  B: TaBinding;
  C: TControl;
  Fmt: string;
begin
  if csDesigning in ComponentState then Exit;
  FormatFields;
  for I := 0 to FBindings.Count - 1 do
  begin
    B := FBindings[I];
    C := B.FControl;
    if C = nil then Continue;
    if (C is TaEdit) and (TaEdit(C).Variant = evLov) and not Assigned(TaEdit(C).OnLov) then TaEdit(C).OnLov := @LovRequest;
    if (B.FFieldName <> '') and (FLink.DataSource <> nil) and (PropKind(C, 'DataSource') = tkClass) and HasProp(C, 'DataField') then
    begin
      SetObjectProp(C, 'DataSource', FLink.DataSource);
      SetStrProp(C, 'DataField', B.FFieldName);
    end;
    if B.FFormat <> '' then
    begin
      Fmt := B.FFormat;
      if PropKind(C, 'DisplayFormat') in [tkAString, tkString, tkLString, tkWString, tkUString] then SetStrProp(C, 'DisplayFormat', Fmt);
      P := Pos('.', Fmt);
      if C is TCustomFloatSpinEdit then Continue;        { decimale spina vodi FixSpins prema vrijednosti }
      if (P = 0) and HasProp(C, 'DecimalPlaces') and (PropKind(C, 'DecimalPlaces') = tkInteger) then SetOrdProp(C, 'DecimalPlaces', 0);
      if (P > 0) and HasProp(C, 'DecimalPlaces') and (PropKind(C, 'DecimalPlaces') = tkInteger) then
      begin
        Dec := 0;
        Inc(P);
        while (P <= Length(Fmt)) and (Fmt[P] in ['0', '#']) do begin Inc(Dec); Inc(P); end;
        SetOrdProp(C, 'DecimalPlaces', Dec);
      end;
    end;
  end;
end;

procedure TaFormBinder.HookDataSet;
begin
  if csDesigning in ComponentState then Exit;
  if (FLink.DataSource = nil) or (FLink.DataSource.DataSet = nil) then Exit;
  if FHooked = FLink.DataSource.DataSet then Exit;
  UnhookDataSet;
  FHooked := FLink.DataSource.DataSet;
  FOldBeforePost := FHooked.BeforePost;
  FHooked.BeforePost := @DoBeforePost;
end;

procedure TaFormBinder.UnhookDataSet;
begin
  if FHooked <> nil then
  begin
    if TMethod(FHooked.BeforePost).Data = Pointer(Self) then FHooked.BeforePost := FOldBeforePost;
    FHooked := nil;
  end;
end;

{ polje izvora koje popunjava kontrola s nazivom AName prema mapi "izvor=kontrola;..." }
function LovOwnField(const AMap, AName, ADefault: string): string;
var
  P: TStringList;
  I: Integer;
begin
  Result := ADefault;
  P := TStringList.Create;
  try
    P.Delimiter := ';'; P.StrictDelimiter := True;
    P.DelimitedText := AMap;
    for I := 0 to P.Count - 1 do
      if SameText(Trim(P.ValueFromIndex[I]), AName) then Exit(Trim(P.Names[I]));
  finally
    P.Free;
  end;
end;

function TaFormBinder.LovCheck(B: TaBinding): string;
var
  E: TaEdit;
  O: TaLovOptions;
  Ds: TDataSet;
  Err, Fld, Txt: string;
begin
  Result := '';
  if not (B.FControl is TaEdit) then Exit;
  E := TaEdit(B.FControl);
  if E.Variant <> evLov then Exit;
  O := TaLovOptions(E.Options);
  Txt := Trim(E.Text);
  if not O.Validate or (Txt = '') or (O.Source = '') then Exit;
  if (FDatabase = nil) or not FDatabase.Connected then Exit;
  Ds := OpenSource(FDatabase.Db, O.Source, nil, nil, Err);
  if Ds = nil then Exit('Popis vrijednosti: ' + Err);
  try
    Fld := B.FFieldName;
    if O.Map <> '' then
      Fld := LovOwnField(O.Map, E.Name, Fld);
    if Ds.FindField(Fld) = nil then Exit('Popis vrijednosti nema polje ' + Fld);
    if not Ds.Locate(Fld, Txt, [loCaseInsensitive]) then
      Result := B.FFieldName + ': vrijednosti "' + Txt + '" nema u popisu';
  finally
    Ds.Free;
  end;
end;

procedure TaFormBinder.LovRequest(Sender: TObject);
var
  E: TaEdit;
  O: TaLovOptions;
  Ds: TDataSet;
  Err, Title: string;
  Parts: TStringList;
  I: Integer;
  F: TField;
  Tgt: TComponent;
  Own: string;
  B: TaBinding;
begin
  E := TaEdit(Sender);
  O := TaLovOptions(E.Options);
  if (O.Source = '') or (FDatabase = nil) or not FDatabase.Connected then Exit;
  Ds := OpenSource(FDatabase.Db, O.Source, nil, nil, Err);
  if Ds = nil then Exit;
  Parts := TStringList.Create;
  try
    Title := E.Name;
    if not RunLov(nil, Ds, Title, Trim(E.Text)) then Exit;
    Parts.Delimiter := ';'; Parts.StrictDelimiter := True;
    Parts.DelimitedText := O.Map;
    if Parts.Count = 0 then
    begin
      B := FBindings.ForControl(E);
      if B <> nil then Parts.Add(B.FFieldName + '=' + E.Name);
    end;
    for I := 0 to Parts.Count - 1 do
    begin
      F := Ds.FindField(Trim(Parts.Names[I]));
      if (F = nil) or (E.Owner = nil) then Continue;
      Tgt := E.Owner.FindComponent(Trim(Parts.ValueFromIndex[I]));
      if Tgt = nil then Continue;
      if Tgt is TaEdit then begin TaEdit(Tgt).Engine.SetText(F.AsString); TaEdit(Tgt).LeaveField; end
      else if (Tgt is TControl) and HasProp(Tgt, 'Text') then SetStrProp(Tgt, 'Text', F.AsString);
    end;
  finally
    Parts.Free;
    Ds.Free;
  end;
end;

procedure TaFormBinder.DoBeforePost(ADataSet: TDataSet);
var
  I: Integer;
  B: TaBinding;
  DoRaise: Boolean;
  LMsg: string;
begin
  for I := 0 to FBindings.Count - 1 do
  begin
    LMsg := LovCheck(FBindings[I]);
    if LMsg <> '' then
    begin
      DoRaise := True;
      if Assigned(FOnValidationFailed) then FOnValidationFailed(Self, FBindings[I], LMsg, DoRaise);
      if DoRaise then raise EBinderValidation.Create(LMsg);
      Break;
    end;
  end;
  if not Validate then
  begin
    for I := 0 to FBindings.Count - 1 do
    begin
      B := FBindings[I];
      if not B.FFailed then Continue;
      DoRaise := True;
      if Assigned(FOnValidationFailed) then FOnValidationFailed(Self, B, FErrors[0], DoRaise);
      if DoRaise then raise EBinderValidation.Create(FErrors[0]);
      Break;
    end;
  end;
  if Assigned(FOldBeforePost) then FOldBeforePost(ADataSet);
end;

{ ---------------- izrazi ---------------- }

function TaFormBinder.Eval(const AExpr: string; out AErr: string): Variant;
var
  H: TBinderHost;
  Saved: TAppDb;
begin
  AErr := '';
  H := TBinderHost.Create;
  Saved := ActiveDb;
  try
    H.Binder := Self;
    if (FDatabase <> nil) and FDatabase.Connected then ActiveDb := FDatabase.Db;
    Result := EvalExprEx(AExpr, H, AErr);
  finally
    ActiveDb := Saved;
    H.Free;
  end;
end;

function TaFormBinder.Truthy(const V: Variant): Boolean;
begin
  if VarIsNull(V) or VarIsEmpty(V) then Exit(False);
  if VarIsType(V, varBoolean) then Exit(Boolean(V));
  if VarIsNumeric(V) then Exit(Double(V) <> 0);
  Result := VarToStr(V) <> '';
end;

{ vrijednost u kontrolu: Value (broj) ako postoji, inace Checked ili Text/Caption }
procedure TaFormBinder.SetControlValue(AControl: TControl; const V: Variant);
var
  Fs: TFormatSettings;
  S: string;
begin
  if VarIsNull(V) then S := '' else S := VarToStr(V);
  if (PropKind(AControl, 'Value') = tkFloat) and not VarIsNull(V) and VarIsNumeric(V) then
  begin
    if (Abs(GetFloatProp(AControl, 'Value') - Double(V)) > 1e-9) then SetFloatProp(AControl, 'Value', Double(V))
    else if HasProp(AControl, 'Text') and (GetStrProp(AControl, 'Text') = '') then
    begin
      { vrijednost je ista (0), ali polje je prazno: prisili ponovni prikaz }
      SetFloatProp(AControl, 'Value', Double(V) + 1);
      SetFloatProp(AControl, 'Value', Double(V));
    end;
    Exit;
  end;
  if (PropKind(AControl, 'Checked') = tkBool) and VarIsType(V, varBoolean) then begin SetOrdProp(AControl, 'Checked', Ord(Boolean(V))); Exit; end;
  { kvacica uz brojcano polje (0/1): oznacena = 1, prazna = 0 }
  if PropKind(AControl, 'Checked') = tkBool then
  begin
    if VarIsNull(V) then SetOrdProp(AControl, 'Checked', 0)
    else if VarIsNumeric(V) then begin SetOrdProp(AControl, 'Checked', Ord(Double(V) <> 0)); Exit; end;
    Exit;
  end;
  if VarIsNumeric(V) and not VarIsType(V, varBoolean) then
  begin
    { broj kao tekst bez nametnutih decimala i tisucica (kao u runneru); oblik daje Format }
    Fs := DefaultFormatSettings;
    S := FloatToStrF(Double(V), ffGeneral, 15, 0, Fs);
  end;
  if HasProp(AControl, 'Text') and (PropKind(AControl, 'Text') in [tkAString, tkString, tkLString, tkWString, tkUString]) then
  begin
    if GetStrProp(AControl, 'Text') <> S then SetStrProp(AControl, 'Text', S);
  end
  else if AControl.Caption <> S then AControl.Caption := S;
end;

{ vrijednost izraza u polje: datum u tekstualno polje ide kao ISO (yyyy-mm-dd), kako baza cuva datume }
procedure StoreField(F: TField; const V: Variant);
begin
  if VarIsType(V, varDate) and (F.DataType in [ftString, ftWideString, ftMemo, ftWideMemo, ftFixedChar]) then
    F.AsString := FormatDateTime('yyyy-mm-dd', TDateTime(V))
  else F.Value := V;
end;

{ zapis izvornog izgleda kontrole (dodaje se pri prvom susretu) }
function TaFormBinder.StyleIndex(AControl: TControl): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FStyles) do
    if FStyles[I].Ctl = AControl then Exit(I);
  Result := Length(FStyles);
  SetLength(FStyles, Result + 1);
  FStyles[Result].Ctl := AControl;
  FStyles[Result].Color := AControl.Color;
  FStyles[Result].FontColor := AControl.Font.Color;
  FStyles[Result].FontStyle := AControl.Font.Style;
end;

procedure TaFormBinder.ApplyDefaults;
var
  I: Integer;
  B: TaBinding;
  F: TField;
  V: Variant;
  DefEng: TaBindingEngine;
  DefHost: TBinderHost;
begin
  DefHost := TBinderHost.Create;
  DefHost.Binder := Self;
  DefEng := TaBindingEngine.Create(DefHost);
  try
  for I := 0 to FBindings.Count - 1 do
  begin
    B := FBindings[I];
    if (B.FDefaultValue = '') or (B.FFieldName = '') then Continue;
    F := FLink.DataSource.DataSet.FindField(B.FFieldName);
    if (F = nil) or not F.IsNull then Continue;
    if DefEng.DefaultValue(B.FDefaultValue, V) then StoreField(F, V);
  end;
  finally
    DefEng.Free;
    DefHost.Free;
  end;
end;

{ ---------------- osvjezavanje ---------------- }

procedure TaFormBinder.Refresh;
var
  I: Integer;
  B: TaBinding;
  C: TControl;
  V: Variant;
  Err: string;
  DS: TDataSet;
  Rules: TCondRules;
  R: TCondRule;
  H: TBinderHost;
  F: TField;
  Editing: Boolean;
  SI: Integer;
  ResetDone, FailedCtl: TList;
  Eng: TaBindingEngine;
  EngHost: TBinderHost;
  EngSaved: TAppDb;
  Ok, Vb, ErrShow: Boolean;
  St: TaBindStyle;
begin
  if FBusy or (csDesigning in ComponentState) or (csLoading in ComponentState) then Exit;
  if (FLink.DataSource = nil) or (FLink.DataSource.DataSet = nil) or not FLink.DataSource.DataSet.Active then Exit;
  DS := FLink.DataSource.DataSet;
  FBusy := True;
  ResetDone := TList.Create;
  FailedCtl := TList.Create;
  EngHost := TBinderHost.Create;
  EngHost.Binder := Self;
  Eng := TaBindingEngine.Create(EngHost);
  EngSaved := ActiveDb;
  if (FDatabase <> nil) and FDatabase.Connected then ActiveDb := FDatabase.Db;
  try
    { zadane vrijednosti jednom po novom zapisu }
    if DS.State = dsInsert then
    begin
      if not FInsertDone then begin FInsertDone := True; ApplyDefaults; end;
    end
    else FInsertDone := False;
    Editing := DS.State in [dsEdit, dsInsert];
    for I := 0 to FBindings.Count - 1 do
    begin
      B := FBindings[I];
      C := B.FControl;
      { izracunato polje: pise se u polje dok se zapis ureduje, inace samo prikaz }
      if B.FExpression <> '' then
      begin
        V := Eval(B.FExpression, Err);
        ErrShow := Err <> '';
        if ErrShow then V := Null;
        if B.FFieldName <> '' then
        begin
          F := DS.FindField(B.FFieldName);
          if (F <> nil) and Editing and not VarIsNull(V) then
          begin
            if F.IsNull or (VarToStr(F.Value) <> VarToStr(V)) then
              if not (F.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd]) or F.IsNull or (Abs(F.AsFloat - Double(V)) > 1e-9) then StoreField(F, V);
          end;
        end;
        if (C <> nil) and (PropKind(C, 'DataField') = tkUnknown) then
        begin
          { kontrola bez veze na bazu: prikaz izracuna (ili vrijednosti polja); neispravan izraz je #Err kao u runneru }
          { prikaz izracuna je samo za citanje i oblikovan prema Format (kao u runneru) }
          if HasProp(C, 'ReadOnly') and (PropKind(C, 'ReadOnly') = tkBool) then SetOrdProp(C, 'ReadOnly', 1);
          if ErrShow then SetControlValue(C, '#Err')
          else if (PropKind(C, 'Value') <> tkFloat) and (PropKind(C, 'Checked') <> tkBool) and not VarIsNull(V) then
            { tekst oblikovan istom funkcijom kao u runneru (Format, datumi, logicke vrijednosti) }
            SetControlValue(C, FormatValue(V, B.FFormat))
          else if (B.FFieldName <> '') and not VarIsNull(V) then SetControlValue(C, V)
          else if B.FFieldName = '' then SetControlValue(C, V)
          else SetControlValue(C, Null);
        end;
      end
      else if (C <> nil) and (B.FFieldName <> '') and (PropKind(C, 'DataField') = tkUnknown) then
      begin
        { kontrola bez veze na bazu: samo prikaz vrijednosti polja }
        F := DS.FindField(B.FFieldName);
        if F <> nil then
          if F.IsNull then SetControlValue(C, Null) else SetControlValue(C, F.Value);
      end;
      if C = nil then Continue;
      if B.FVisibleIf <> '' then
      begin
        Vb := Eng.Condition(B.FVisibleIf, Ok);
        if Ok then C.Visible := Vb;
      end;
      if B.FEnabledIf <> '' then
      begin
        Vb := Eng.Condition(B.FEnabledIf, Ok);
        if Ok then C.Enabled := Vb;
      end;
      { izvorni izgled kontrole pamti se prije prve izmjene; vise stavki na istoj kontroli se zbraja }
      SI := StyleIndex(C);
      if ResetDone.IndexOf(C) < 0 then
      begin
        ResetDone.Add(C);
        C.Color := FStyles[SI].Color; C.Font.Color := FStyles[SI].FontColor; C.Font.Style := FStyles[SI].FontStyle;
      end;
      if B.FCondFormat <> '' then
      begin
        St := Eng.Style(B.FCondFormat);
        if St.Matched then
        begin
          if (St.Fore <> '') then C.Font.Color := RGBToColor(StrToInt('$' + Copy(St.Fore, 2, 2)), StrToInt('$' + Copy(St.Fore, 4, 2)), StrToInt('$' + Copy(St.Fore, 6, 2)));
          if (St.Back <> '') then C.Color := RGBToColor(StrToInt('$' + Copy(St.Back, 2, 2)), StrToInt('$' + Copy(St.Back, 4, 2)), StrToInt('$' + Copy(St.Back, 6, 2)));
          if St.Bold then C.Font.Style := C.Font.Style + [fsBold];
        end;
      end;
      { pravilo: neispunjeno oboja kontrolu (a Post se odbija pri spremanju) }
      if B.FRule <> '' then
      begin
        B.FFailed := Eng.RuleFailed(B.FRule);
        if B.FFailed then FailedCtl.Add(C);
      end;
    end;
    { neispunjeno pravilo ima prednost nad uvjetnim oblikovanjem }
    for I := 0 to FailedCtl.Count - 1 do TControl(FailedCtl[I]).Color := RuleBad;
  finally
    ActiveDb := EngSaved;
    Eng.Free;
    EngHost.Free;
    ResetDone.Free;
    FailedCtl.Free;
    FBusy := False;
  end;
  if Assigned(FOnRefreshed) then FOnRefreshed(Self);
end;

function TaFormBinder.Validate: Boolean;
var
  I: Integer;
  B: TaBinding;
  VEng: TaBindingEngine;
  VHost: TBinderHost;
  VSaved: TAppDb;
begin
  FErrors.Clear;
  Result := True;
  if (FLink.DataSource = nil) or (FLink.DataSource.DataSet = nil) then Exit;
  VHost := TBinderHost.Create;
  VHost.Binder := Self;
  VEng := TaBindingEngine.Create(VHost);
  VSaved := ActiveDb;
  if (FDatabase <> nil) and FDatabase.Connected then ActiveDb := FDatabase.Db;
  try
  for I := 0 to FBindings.Count - 1 do
  begin
    B := FBindings[I];
    B.FFailed := False;
    if B.FRule = '' then Continue;
    if VEng.RuleFailed(B.FRule) then
    begin
      B.FFailed := True;
      Result := False;
      if B.FRuleMessage <> '' then FErrors.Add(B.FRuleMessage) else FErrors.Add(Tr('The rule is not satisfied: ') + B.FRule);
    end;
  end;
  finally
    ActiveDb := VSaved;
    VEng.Free;
    VHost.Free;
  end;
end;

end.
