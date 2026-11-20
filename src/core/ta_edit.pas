unit ta_edit;
{ Obitelj Edit (jednoredno polje): jedna komponenta TaEdit, varijanta bira nacin rada:
  text, password, combo, droplist, spin, date, currency. Zajednicka svojstva (izvor, pravilo, oblik,
  vidljivost, tekst, stavke) ostaju pri promjeni varijante; svojstva koja ovise o varijanti nalaze se
  u podobjektu Options (klasa ovisi o varijanti).

  Isto polje radi u CodeTyphonu (paleta, .lfm) i u TyphAccessu (definicija kontrole u JSON-u):
  EditFromDef / EditToDef pretvaraju TaControlDef u TaEdit i natrag. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Graphics, Variants, DB, DBCtrls, ta_family, ta_formdef;

type
  TaEditVariant = (evText, evPassword, evCombo, evDroplist, evSpin, evDate, evCurrency, evLov);

const
  EditVariantNames: array[TaEditVariant] of string = ('text', 'password', 'combo', 'droplist', 'spin', 'date', 'currency', 'lov');
  EditFamily = 'Edit';

type
  { ---------------- opcije po varijanti ---------------- }

  TaEditOptions = class(TPersistent)
  public
    constructor Create; virtual;
    procedure Assign(ASource: TPersistent); override;
  end;

  TaEditOptionsClass = class of TaEditOptions;

  TaPasswordOptions = class(TaEditOptions)
  private
    FPasswordChar: Char;
  public
    constructor Create; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property PasswordChar: Char read FPasswordChar write FPasswordChar default '*';
  end;

  TaComboOptions = class(TaEditOptions)
  private
    FDropDownCount: Integer;
    FAutoComplete, FKeyed, FSearch: Boolean;
  public
    constructor Create; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property DropDownCount: Integer read FDropDownCount write FDropDownCount default 8;
    property AutoComplete: Boolean read FAutoComplete write FAutoComplete default True;
    { stavke su retci "kljuc=natpis": vrijednost polja je kljuc, a popis pokazuje natpise }
    property Keyed: Boolean read FKeyed write FKeyed default False;
    { kljucani popis koji se suzuje tipkanjem (pretrazivi) }
    property Search: Boolean read FSearch write FSearch default False;
  end;

  TaSpinOptions = class(TaEditOptions)
  private
    FDecimalPlaces: Integer;
    FMinValue, FMaxValue, FIncrement: Double;
  public
    constructor Create; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property DecimalPlaces: Integer read FDecimalPlaces write FDecimalPlaces default 0;
    { MinValue = MaxValue = 0: bez granica }
    property MinValue: Double read FMinValue write FMinValue;
    property MaxValue: Double read FMaxValue write FMaxValue;
    property Increment: Double read FIncrement write FIncrement;
  end;

  TaCurrencyOptions = class(TaEditOptions)
  private
    FDecimalPlaces: Integer;
    FSymbol: string;
  public
    constructor Create; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property DecimalPlaces: Integer read FDecimalPlaces write FDecimalPlaces default 2;
    property Symbol: string read FSymbol write FSymbol;
  end;

  TaDateOptions = class(TaEditOptions)
  private
    FDateFormat: string;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    { prazno = sustavni oblik datuma }
    property DateFormat: string read FDateFormat write FDateFormat;
  end;

  { popis vrijednosti (19.5): izvor, preslikavanje stupaca u polja i provjera iz popisa }
  TaLovOptions = class(TaEditOptions)
  private
    FSource, FMap: string;
    FValidate: Boolean;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    { tablica, sql:..., list:... ili fgl:... }
    property Source: string read FSource write FSource;
    { polje_izvora=kontrola;... (bez toga samo vlastito polje) }
    property Map: string read FMap write FMap;
    property Validate: Boolean read FValidate write FValidate default False;
  end;

  { ---------------- pokretaci (LCL) ---------------- }

  TaEditTextEngine = class(TaEngine)
  private
    FEdit: TEdit;
    FMask: string;
    FMaskBusy: Boolean;
    procedure MaskChange(Sender: TObject);
  protected
    procedure Make(APassword: Boolean);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure SetAlignment(AValue: TAlignment); override;
    procedure SetMaxLength(AValue: Integer); override;
    procedure SetMask(const AValue: string); override;
  end;

  TaEditPasswordEngine = class(TaEditTextEngine)
  public
    constructor Create(AHost: TaFamilyHost); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaEditComboEngine = class(TaEngine)
  private
    FCombo: TComboBox;       { zapravo TaComboBox: kljucevi i pretrazivanje }
    FDroplist: Boolean;
    FKeyed, FSearch: Boolean;
    FLast: TStringList;      { zadnje stavke, da se mogu ponovno razvrstati kad se promijeni Keyed }
  public
    destructor Destroy; override;
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaEditDroplistEngine = class(TaEditComboEngine)
  public
    constructor Create(AHost: TaFamilyHost); override;
  end;

  TaEditSpinEngine = class(TaEngine)
  private
    FSpin: TObject;      { TFloatSpinEdit; u unitu da se izbjegne ovisnost u sucelju }
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure SetAlignment(AValue: TAlignment); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaEditDateEngine = class(TaEngine)
  private
    FDate: TObject;      { TDateEdit }
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaEditLovEngine = class(TaEngine)
  private
    FBtn: TObject;       { TEditButton }
    procedure ButtonClick(Sender: TObject);
    procedure KeyDownHook(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
  end;

  TaEditCurrencyEngine = class(TaEditTextEngine)
  private
    FDecimals: Integer;
    FSymbol: string;
    function FormatNumber(AValue: Double): string;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    procedure Commit; override;
  end;

  { ---------------- TaEdit ---------------- }

  TaEdit = class(TaFamilyHost)
  private
    FVariant: TaEditVariant;
    FOptions: array[TaEditVariant] of TaEditOptions;   { po jedna po varijanti: vrijednosti se pamte pri promjeni }
    FItems: TStringList;
    FText: string;
    FReadOnly: Boolean;
    FAlignment: TAlignment;
    FAlignmentSet: Boolean;
    FMaxLength: Integer;
    FMask: string;
    FFormat, FControlSource, FRowSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    FUpdating, FSelfEdit: Boolean;
    FOnLov: TNotifyEvent;
    function GetVariant: TaEditVariant;
    procedure SetVariant(AValue: TaEditVariant);
    function GetOptions: TaEditOptions;
    procedure SetOptions(AValue: TaEditOptions);
    function OptionsClassFor(AVariant: TaEditVariant): TaEditOptionsClass;
    function OptionsStored: Boolean;
    procedure SetItemsList(AValue: TStrings);
    function GetItemsList: TStrings;
    procedure ItemsChanged(Sender: TObject);
    procedure SetReadOnly(AValue: Boolean);
    function EffectiveAlignment: TAlignment;
    procedure SetAlignment(AValue: TAlignment);
    procedure SetMaxLength(AValue: Integer);
    procedure SetMask(const AValue: string);
    procedure SetFormat(const AValue: string);
    function GetDataSource: TDataSource;
    procedure SetDataSource(AValue: TDataSource);
    function GetDataField: string;
    procedure SetDataField(const AValue: string);
    procedure DataChange(Sender: TObject);
    procedure UpdateData(Sender: TObject);
    function ReadOnlyEffective: Boolean;
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    procedure EngineChanged; override;
    procedure EngineExit; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
    function EffectiveAlignmentValue: TAlignment;
    { F9 ili gumb ... na varijanti lov: javlja OnLov }
    procedure RequestLov;
    function Value: System.Variant;
    procedure SetValue(const AValue: System.Variant);
  published
    property Variant: TaEditVariant read GetVariant write SetVariant default evText;
    property Text;
    property Options: TaEditOptions read GetOptions write SetOptions stored OptionsStored;
    property Items: TStrings read GetItemsList write SetItemsList;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property MaxLength: Integer read FMaxLength write SetMaxLength default 0;
    { maska unosa: 9 znamenka, A slovo, X slovo ili znamenka, ostalo su fiksni znakovi (rjecnik: kljuc mask) }
    property Mask: string read FMask write SetMask;
    property Format: string read FFormat write SetFormat;
    property ControlSource: string read FControlSource write FControlSource;
    property RowSource: string read FRowSource write FRowSource;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property CondFormat: string read FCondFormat write FCondFormat;
    { ostali kljucevi definicije koje obitelj ne poznaje, kao key=value retci (da se ne izgube) }
    property Extra: string read FExtra write FExtra;
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property DataField: string read GetDataField write SetDataField;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property TabOrder;
    property PopupMenu;
    property OnEnter;
    property OnExit;
    property OnLov: TNotifyEvent read FOnLov write FOnLov;
  end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

{ vrste definicije koje pripadaju obitelji Edit ('Edit', alias 'TextBox' i 'ComboBox') }
function IsEditKind(const AKind: string): Boolean;
function EditVariantFromName(const AName: string; ADefault: TaEditVariant = evText): TaEditVariant;
function EditFromDef(D: TaControlDef; AOwner: TComponent): TaEdit;
procedure EditToDef(E: TaEdit; D: TaControlDef);
{ tekst .lfm toka komponente (za CodeTyphon) i obrnuto }
function EditToLfm(E: TaEdit): string;
function EditFromLfm(const ALfm: string; AOwner: TComponent): TaEdit;

implementation

uses
  Spin, EditBtn, LResources, Math, DateUtils, StrUtils, ta_controls, ta_mask;

{ ---------------- pomocne ---------------- }

function ParseNumber(const AText: string; out AValue: Double): Boolean;
var
  S: string;
begin
  S := Trim(AText);
  S := StringReplace(S, ' ', '', [rfReplaceAll]);
  if S = '' then Exit(False);
  if DefaultFormatSettings.DecimalSeparator = ',' then
    S := StringReplace(S, '.', '', [rfReplaceAll])
  else
    S := StringReplace(S, ',', '', [rfReplaceAll]);
  Result := TryStrToFloat(S, AValue, DefaultFormatSettings);
end;

function IsEditKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Edit') or SameText(AKind, 'TextBox') or SameText(AKind, 'ComboBox');
end;

function EditVariantFromName(const AName: string; ADefault: TaEditVariant): TaEditVariant;
var
  V: TaEditVariant;
begin
  for V := Low(TaEditVariant) to High(TaEditVariant) do
    if SameText(EditVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

{ ---------------- opcije ---------------- }

constructor TaEditOptions.Create;
begin
  inherited Create;
end;

procedure TaEditOptions.Assign(ASource: TPersistent);
begin
  if not (ASource is TaEditOptions) then inherited Assign(ASource);
end;

constructor TaPasswordOptions.Create;
begin
  inherited Create;
  FPasswordChar := '*';
end;

procedure TaPasswordOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaPasswordOptions then FPasswordChar := TaPasswordOptions(ASource).FPasswordChar
  else inherited Assign(ASource);
end;

constructor TaComboOptions.Create;
begin
  inherited Create;
  FDropDownCount := 8;
  FAutoComplete := True;
end;

procedure TaComboOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaComboOptions then
  begin
    FDropDownCount := TaComboOptions(ASource).FDropDownCount;
    FAutoComplete := TaComboOptions(ASource).FAutoComplete;
    FKeyed := TaComboOptions(ASource).FKeyed;
    FSearch := TaComboOptions(ASource).FSearch;
  end
  else inherited Assign(ASource);
end;

constructor TaSpinOptions.Create;
begin
  inherited Create;
  FDecimalPlaces := 0;
  FIncrement := 1;
end;

procedure TaSpinOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaSpinOptions then
  begin
    FDecimalPlaces := TaSpinOptions(ASource).FDecimalPlaces;
    FMinValue := TaSpinOptions(ASource).FMinValue;
    FMaxValue := TaSpinOptions(ASource).FMaxValue;
    FIncrement := TaSpinOptions(ASource).FIncrement;
  end
  else inherited Assign(ASource);
end;

constructor TaCurrencyOptions.Create;
begin
  inherited Create;
  FDecimalPlaces := 2;
end;

procedure TaCurrencyOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaCurrencyOptions then
  begin
    FDecimalPlaces := TaCurrencyOptions(ASource).FDecimalPlaces;
    FSymbol := TaCurrencyOptions(ASource).FSymbol;
  end
  else inherited Assign(ASource);
end;

procedure TaDateOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaDateOptions then FDateFormat := TaDateOptions(ASource).FDateFormat
  else inherited Assign(ASource);
end;

{ ---------------- pokretac: tekst i lozinka ---------------- }

constructor TaEditTextEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  Make(False);
end;

procedure TaEditTextEngine.Make(APassword: Boolean);
begin
  FEdit := TEdit.Create(nil);
  FEdit.AutoSize := False;
  FEdit.OnChange := @MaskChange;
  AttachInner(FEdit);
  if APassword then FEdit.PasswordChar := '*';
end;

function TaEditTextEngine.GetText: string;
begin
  Result := FEdit.Text;
end;

procedure TaEditTextEngine.SetText(const AValue: string);
begin
  if FEdit.Text <> AValue then FEdit.Text := AValue;
end;

procedure TaEditTextEngine.SetReadOnly(AValue: Boolean);
begin
  FEdit.ReadOnly := AValue;
end;

procedure TaEditTextEngine.SetAlignment(AValue: TAlignment);
begin
  FEdit.Alignment := AValue;
end;

procedure TaEditTextEngine.MaskChange(Sender: TObject);
var
  F: string;
begin
  if FMaskBusy then Exit;
  if FMask <> '' then
  begin
    F := ApplyMask(FMask, FEdit.Text);
    if F <> FEdit.Text then
    begin
      FMaskBusy := True;
      try
        FEdit.Text := F;
        FEdit.SelStart := Length(F);
      finally
        FMaskBusy := False;
      end;
    end;
  end;
  InnerChanged(Sender);
end;

procedure TaEditTextEngine.SetMask(const AValue: string);
begin
  FMask := AValue;
  if FMask <> '' then FEdit.MaxLength := Length(FMask);
  if (FMask <> '') and (ApplyMask(FMask, FEdit.Text) <> FEdit.Text) then FEdit.Text := FEdit.Text;
end;

procedure TaEditTextEngine.SetMaxLength(AValue: Integer);
begin
  FEdit.MaxLength := AValue;
end;

constructor TaEditPasswordEngine.Create(AHost: TaFamilyHost);
begin
  { TaEditTextEngine.Create stvara obicno polje; ovdje samo dodajemo lozinku }
  inherited Create(AHost);
  FEdit.PasswordChar := '*';
end;

procedure TaEditPasswordEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaPasswordOptions then
    if TaPasswordOptions(AOptions).PasswordChar <> #0 then FEdit.PasswordChar := TaPasswordOptions(AOptions).PasswordChar;
end;

{ ---------------- pokretac: combo i padajuci popis ---------------- }

constructor TaEditComboEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FCombo := TaComboBox.Create(nil);
  FCombo.AutoSize := False;
  FCombo.OnChange := @InnerChanged;
  AttachInner(FCombo);
end;

constructor TaEditDroplistEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FDroplist := True;
  FCombo.Style := csDropDownList;
end;

function TaEditComboEngine.GetText: string;
var
  Cb: TaComboBox;
begin
  Cb := TaComboBox(FCombo);
  if FKeyed and (Cb.Keys <> nil) then Exit(Cb.CurrentKey);
  if FDroplist then
  begin
    if FCombo.ItemIndex >= 0 then Result := FCombo.Items[FCombo.ItemIndex] else Result := '';
  end
  else Result := FCombo.Text;
end;

procedure TaEditComboEngine.SetText(const AValue: string);
var
  Cb: TaComboBox;
  I: Integer;
begin
  Cb := TaComboBox(FCombo);
  if FKeyed and (Cb.Keys <> nil) then
  begin
    if FSearch and (Cb.AllKeys <> nil) then Cb.SelectKey(AValue)
    else
    begin
      I := Cb.Keys.IndexOf(AValue);
      FCombo.ItemIndex := I;
      if I < 0 then FCombo.Text := '';
    end;
    Exit;
  end;
  if FDroplist then FCombo.ItemIndex := FCombo.Items.IndexOf(AValue)
  else if FCombo.Text <> AValue then FCombo.Text := AValue;
end;

procedure TaEditComboEngine.SetItems(AItems: TStrings);
var
  Keep: string;
  Cb: TaComboBox;
  Labels, Keys: TStringList;
  I, P: Integer;
  S: string;
begin
  Keep := GetText;
  Cb := TaComboBox(FCombo);
  if FLast = nil then FLast := TStringList.Create;
  if AItems <> FLast then FLast.Assign(AItems);
  if FKeyed then
  begin
    Labels := TStringList.Create;
    Keys := TStringList.Create;
    try
      for I := 0 to AItems.Count - 1 do
      begin
        S := AItems[I];
        P := Pos('=', S);
        if P > 0 then begin Keys.Add(Trim(Copy(S, 1, P - 1))); Labels.Add(Trim(Copy(S, P + 1, MaxInt))); end
        else begin Keys.Add(Trim(S)); Labels.Add(Trim(S)); end;
      end;
      FCombo.Items.Assign(Labels);
      Cb.Keys.Free;
      Cb.Keys := Keys;
      Keys := nil;
    finally
      Labels.Free;
      Keys.Free;
    end;
    if FSearch then Cb.EnableSearch(True)
    else
    begin
      Cb.Search := False;
      FCombo.Style := csDropDownList;
    end;
  end
  else
  begin
    Cb.Keys.Free;
    Cb.Keys := nil;
    Cb.Search := False;
    FCombo.Items.Assign(AItems);
  end;
  SetText(Keep);
end;

procedure TaEditComboEngine.SetReadOnly(AValue: Boolean);
begin
  FCombo.Enabled := (not AValue) and (Host <> nil) and Host.Enabled;
end;

procedure TaEditComboEngine.ApplyOptions(AOptions: TPersistent);
var
  Changed: Boolean;
begin
  if AOptions is TaComboOptions then
  begin
    FCombo.DropDownCount := TaComboOptions(AOptions).DropDownCount;
    FCombo.AutoComplete := TaComboOptions(AOptions).AutoComplete;
    Changed := (FKeyed <> TaComboOptions(AOptions).Keyed) or (FSearch <> TaComboOptions(AOptions).Search);
    FKeyed := TaComboOptions(AOptions).Keyed;
    FSearch := TaComboOptions(AOptions).Search;
    { promjena nacina tumacenja stavki: ponovno razvrstaj ono sto vec jesmo dobili }
    if Changed and (FLast <> nil) then SetItems(FLast);
  end;
end;

destructor TaEditComboEngine.Destroy;
begin
  FLast.Free;
  inherited Destroy;
end;

{ ---------------- pokretac: spin ---------------- }

constructor TaEditSpinEngine.Create(AHost: TaFamilyHost);
var
  S: TFloatSpinEdit;
begin
  inherited Create(AHost);
  S := TFloatSpinEdit.Create(nil);
  S.AutoSize := False;
  S.DecimalPlaces := 0;
  S.MinValue := -1e9;
  S.MaxValue := 1e9;
  S.OnChange := @InnerChanged;
  FSpin := S;
  AttachInner(S);
end;

function TaEditSpinEngine.GetText: string;
begin
  Result := TFloatSpinEdit(FSpin).Text;
end;

procedure TaEditSpinEngine.SetText(const AValue: string);
var
  D: Double;
begin
  if ParseNumber(AValue, D) then TFloatSpinEdit(FSpin).Value := D;
end;

function TaEditSpinEngine.GetValue: Variant;
begin
  Result := TFloatSpinEdit(FSpin).Value;
end;

procedure TaEditSpinEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then TFloatSpinEdit(FSpin).Value := 0
  else TFloatSpinEdit(FSpin).Value := AValue;
end;

procedure TaEditSpinEngine.SetReadOnly(AValue: Boolean);
begin
  TFloatSpinEdit(FSpin).ReadOnly := AValue;
end;

procedure TaEditSpinEngine.SetAlignment(AValue: TAlignment);
begin
  TFloatSpinEdit(FSpin).Alignment := AValue;
end;

procedure TaEditSpinEngine.ApplyOptions(AOptions: TPersistent);
var
  S: TFloatSpinEdit;
  O: TaSpinOptions;
begin
  if not (AOptions is TaSpinOptions) then Exit;
  O := TaSpinOptions(AOptions);
  S := TFloatSpinEdit(FSpin);
  S.DecimalPlaces := O.DecimalPlaces;
  if (O.MinValue = 0) and (O.MaxValue = 0) then
  begin
    S.MinValue := -1e9;
    S.MaxValue := 1e9;
  end
  else
  begin
    S.MinValue := O.MinValue;
    S.MaxValue := O.MaxValue;
  end;
  if O.Increment > 0 then S.Increment := O.Increment;
end;

{ ---------------- pokretac: datum ---------------- }

constructor TaEditDateEngine.Create(AHost: TaFamilyHost);
var
  D: TDateEdit;
begin
  inherited Create(AHost);
  D := TDateEdit.Create(nil);
  D.AutoSize := False;
  D.OnChange := @InnerChanged;
  FDate := D;
  AttachInner(D);
end;

function TaEditDateEngine.GetText: string;
begin
  Result := TDateEdit(FDate).Text;
end;

procedure TaEditDateEngine.SetText(const AValue: string);
var
  D: TDateTime;
begin
  if Trim(AValue) = '' then TDateEdit(FDate).Text := ''
  else if TryStrToDate(AValue, D) then TDateEdit(FDate).Date := D
  else TDateEdit(FDate).Text := AValue;
end;

function TaEditDateEngine.GetValue: Variant;
var
  D: TDateTime;
begin
  if TryStrToDate(TDateEdit(FDate).Text, D) then Result := D else Result := Null;
end;

procedure TaEditDateEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then TDateEdit(FDate).Text := ''
  else TDateEdit(FDate).Date := VarToDateTime(AValue);
end;

procedure TaEditDateEngine.SetReadOnly(AValue: Boolean);
begin
  TDateEdit(FDate).ReadOnly := AValue;
end;

procedure TaEditDateEngine.ApplyOptions(AOptions: TPersistent);
begin
  if (AOptions is TaDateOptions) and (TaDateOptions(AOptions).DateFormat <> '') then
    TDateEdit(FDate).DateFormat := TaDateOptions(AOptions).DateFormat;
end;

{ ---------------- pokretac: popis vrijednosti ---------------- }

procedure TaLovOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaLovOptions then
  begin
    FSource := TaLovOptions(ASource).FSource;
    FMap := TaLovOptions(ASource).FMap;
    FValidate := TaLovOptions(ASource).FValidate;
  end
  else inherited Assign(ASource);
end;

constructor TaEditLovEngine.Create(AHost: TaFamilyHost);
var
  B: TEditButton;
begin
  inherited Create(AHost);
  B := TEditButton.Create(nil);
  B.AutoSize := False;
  B.Button.Caption := '...';
  B.Button.Glyph.Clear;
  B.OnChange := @InnerChanged;
  B.OnButtonClick := @ButtonClick;
  FBtn := B;
  AttachInner(B);
  B.OnKeyDown := @KeyDownHook;
end;

procedure TaEditLovEngine.ButtonClick(Sender: TObject);
begin
  if Host is TaEdit then TaEdit(Host).RequestLov;
end;

procedure TaEditLovEngine.KeyDownHook(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  { F9 samo kad domacin nema vlastitu tipkovnicku mapu (neprekidna forma preuzima tipke preko OnInnerKeyDown) }
  if (Key = 120) and (Shift = []) and not Assigned(Host.OnInnerKeyDown) then
  begin
    if Host is TaEdit then TaEdit(Host).RequestLov;
    Key := 0;
    Exit;
  end;
  InnerKeyDown(Sender, Key, Shift);
end;

function TaEditLovEngine.GetText: string;
begin
  Result := TEditButton(FBtn).Text;
end;

procedure TaEditLovEngine.SetText(const AValue: string);
begin
  if TEditButton(FBtn).Text <> AValue then TEditButton(FBtn).Text := AValue;
end;

procedure TaEditLovEngine.SetReadOnly(AValue: Boolean);
begin
  TEditButton(FBtn).ReadOnly := AValue;
end;

{ ---------------- pokretac: iznos ---------------- }

constructor TaEditCurrencyEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FDecimals := 2;
  FEdit.Alignment := taRightJustify;
end;

function TaEditCurrencyEngine.FormatNumber(AValue: Double): string;
begin
  Result := FormatFloat('#,##0.' + StringOfChar('0', FDecimals), AValue, DefaultFormatSettings);
  if FDecimals <= 0 then Result := FormatFloat('#,##0', AValue, DefaultFormatSettings);
  if FSymbol <> '' then Result := Result + ' ' + FSymbol;
end;

function TaEditCurrencyEngine.GetValue: Variant;
var
  D: Double;
  S: string;
begin
  S := FEdit.Text;
  if (FSymbol <> '') and (Pos(FSymbol, S) > 0) then S := Trim(StringReplace(S, FSymbol, '', [rfReplaceAll]));
  if ParseNumber(S, D) then Result := D else Result := Null;
end;

procedure TaEditCurrencyEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then FEdit.Text := ''
  else FEdit.Text := FormatNumber(AValue);
end;

procedure TaEditCurrencyEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaCurrencyOptions then
  begin
    FDecimals := TaCurrencyOptions(AOptions).DecimalPlaces;
    FSymbol := TaCurrencyOptions(AOptions).Symbol;
  end;
end;

procedure TaEditCurrencyEngine.Commit;
var
  V: Variant;
begin
  V := GetValue;
  if not VarIsNull(V) then
  begin
    FEdit.OnChange := nil;
    try
      FEdit.Text := FormatNumber(V);
    finally
      FEdit.OnChange := @InnerChanged;
    end;
  end;
end;

{ ---------------- TaEdit ---------------- }

constructor TaEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FItems.OnChange := @ItemsChanged;
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FDataLink.OnUpdateData := @UpdateData;
  FVariant := evText;
  FAlignment := taLeftJustify;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaEdit.Destroy;
var
  V: TaEditVariant;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.OnUpdateData := nil;
  FDataLink.Free;
  for V := Low(TaEditVariant) to High(TaEditVariant) do FOptions[V].Free;
  FItems.Free;
  inherited Destroy;
end;

function TaEdit.OptionsClassFor(AVariant: TaEditVariant): TaEditOptionsClass;
begin
  case AVariant of
    evPassword: Result := TaPasswordOptions;
    evCombo, evDroplist: Result := TaComboOptions;
    evSpin: Result := TaSpinOptions;
    evCurrency: Result := TaCurrencyOptions;
    evDate: Result := TaDateOptions;
    evLov: Result := TaLovOptions;
  else
    Result := TaEditOptions;
  end;
end;

function TaEdit.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(EditFamily, EditVariantNames[FVariant]);
  if C = nil then C := FindEngine(EditFamily, 'text');
  Result := C.Create(Self);
end;

function TaEdit.EffectiveAlignmentValue: TAlignment;
begin
  Result := EffectiveAlignment;
end;

procedure TaEdit.RequestLov;
begin
  if Assigned(FOnLov) then FOnLov(Self);
end;

function TaEdit.VariantName: string;
begin
  Result := EditVariantNames[FVariant];
end;

function TaEdit.GetVariant: TaEditVariant;
begin
  Result := FVariant;
end;

procedure TaEdit.SetVariant(AValue: TaEditVariant);
begin
  if AValue = FVariant then Exit;
  { tekst se cuva kroz zamjenu pokretaca }
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaEdit.GetOptions: TaEditOptions;
begin
  if FOptions[FVariant] = nil then FOptions[FVariant] := OptionsClassFor(FVariant).Create;
  Result := FOptions[FVariant];
end;

procedure TaEdit.SetOptions(AValue: TaEditOptions);
begin
  GetOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(GetOptions);
end;

function TaEdit.OptionsStored: Boolean;
begin
  Result := FVariant <> evText;
end;

procedure TaEdit.PushToEngine;
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.ApplyOptions(GetOptions);
    Engine.SetItems(FItems);
    Engine.SetAlignment(EffectiveAlignment);
    Engine.SetMaxLength(FMaxLength);
    Engine.SetMask(FMask);
    Engine.SetFormat(FFormat);
    Engine.SetText(FText);
    Engine.SetReadOnly(ReadOnlyEffective);
  finally
    FUpdating := False;
  end;
end;

function TaEdit.ReadOnlyEffective: Boolean;
begin
  Result := FReadOnly;
end;

procedure TaEdit.SetItemsList(AValue: TStrings);
begin
  FItems.Assign(AValue);
end;

function TaEdit.GetItemsList: TStrings;
begin
  Result := FItems;
end;

procedure TaEdit.ItemsChanged(Sender: TObject);
begin
  if (Engine <> nil) and not (csLoading in ComponentState) then Engine.SetItems(FItems);
end;

procedure TaEdit.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  if Engine <> nil then Engine.SetReadOnly(ReadOnlyEffective);
end;

function TaEdit.EffectiveAlignment: TAlignment;
begin
  if (not FAlignmentSet) and (FVariant = evCurrency) then Result := taRightJustify
  else Result := FAlignment;
end;

procedure TaEdit.SetAlignment(AValue: TAlignment);
begin
  FAlignmentSet := True;
  FAlignment := AValue;
  if Engine <> nil then Engine.SetAlignment(EffectiveAlignment);
end;

procedure TaEdit.SetMask(const AValue: string);
begin
  if FMask = AValue then Exit;
  FMask := AValue;
  if Engine <> nil then Engine.SetMask(AValue);
end;

procedure TaEdit.SetMaxLength(AValue: Integer);
begin
  if FMaxLength = AValue then Exit;
  FMaxLength := AValue;
  if Engine <> nil then Engine.SetMaxLength(AValue);
end;

procedure TaEdit.SetFormat(const AValue: string);
begin
  if FFormat = AValue then Exit;
  FFormat := AValue;
  if Engine <> nil then Engine.SetFormat(AValue);
end;

function TaEdit.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaEdit.RealSetText(const AValue: TCaption);
begin
  FText := AValue;
  if Engine <> nil then
  begin
    FUpdating := True;
    try
      Engine.SetText(AValue);
    finally
      FUpdating := False;
    end;
  end;
end;

function TaEdit.Value: System.Variant;
begin
  if Engine <> nil then Result := Engine.GetValue else Result := Null;
end;

procedure TaEdit.SetValue(const AValue: System.Variant);
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.SetValue(AValue);
  finally
    FUpdating := False;
  end;
end;

procedure TaEdit.EngineChanged;
begin
  if FUpdating then Exit;
  if FDataLink.Active and not ReadOnlyEffective then
  begin
    { prijelaz skupa u izmjenu javlja promjenu zapisa; to ne smije vratiti staru vrijednost u polje }
    FSelfEdit := True;
    try
      if FDataLink.Edit then FDataLink.Modified;
    finally
      FSelfEdit := False;
    end;
  end;
  inherited EngineChanged;
end;

procedure TaEdit.EngineExit;
begin
  if FDataLink.Active then
    try
      FDataLink.UpdateRecord;
    except
      FDataLink.Reset;
      raise;
    end;
  inherited EngineExit;
end;

{ ---------------- podaci ---------------- }

function TaEdit.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaEdit.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaEdit.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaEdit.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaEdit.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaEdit.Loaded;
begin
  inherited Loaded;
  Engine.SetItems(FItems);
  PushToEngine;
end;

procedure TaEdit.DataChange(Sender: TObject);
var
  F: TField;
begin
  if FSelfEdit then Exit;
  F := FDataLink.Field;
  FUpdating := True;
  try
    if F = nil then
    begin
      if not (csDesigning in ComponentState) then Engine.SetText('');
    end
    else if F.IsNull then Engine.SetValue(Null)
    else
      case FVariant of
        evSpin, evCurrency: Engine.SetValue(F.AsFloat);
        evDate: Engine.SetValue(F.AsDateTime);
      else
        Engine.SetText(F.AsString);
      end;
  finally
    FUpdating := False;
  end;
end;

procedure TaEdit.UpdateData(Sender: TObject);
var
  F: TField;
  V: System.Variant;
begin
  F := FDataLink.Field;
  if F = nil then Exit;
  V := Engine.GetValue;
  if VarIsNull(V) or (VarIsStr(V) and (VarToStr(V) = '')) then F.Clear
  else
    case FVariant of
      evSpin, evCurrency: F.AsFloat := V;
      evDate: F.AsDateTime := V;
    else
      F.AsString := VarToStr(V);
    end;
end;

{ ---------------- definicija <-> komponenta ---------------- }

const
  { kljucevi Extra koje obitelj sama poznaje (ostali idu u Extra) }
  OwnKeys = ',variant,tip,locked,visibleIf,enabledIf,condFormat,align,dropDownCount,autoComplete,keyed,search,decimals,min,max,step,symbol,dateFormat,passwordChar,maxLength,mask,items,';

function ExtraWithout(const AExtra: string): string;
var
  L: TStringList;
  I: Integer;
  K: string;
begin
  L := TStringList.Create;
  try
    L.Text := AExtra;
    for I := L.Count - 1 downto 0 do
    begin
      K := L.Names[I];
      if (K <> '') and (Pos(',' + K + ',', OwnKeys) > 0) then L.Delete(I);
    end;
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

function EditFromDef(D: TaControlDef; AOwner: TComponent): TaEdit;
var
  V: TaEditVariant;
  S: string;
  L: TStringList;
  I: Integer;
begin
  Result := TaEdit.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    { vrsta: Edit s varijantom, ili stari nazivi }
    if SameText(D.Kind, 'ComboBox') then V := evCombo else V := evText;
    S := D.GetX('variant');
    if S <> '' then V := EditVariantFromName(S, V);
    Result.Variant := V;
    Result.ControlSource := D.ControlSource;
    Result.RowSource := D.RowSource;
    Result.Format := D.Format;
    Result.ReadOnly := D.GetX('locked') = '1';
    Result.Hint := D.GetX('tip');
    Result.ShowHint := Result.Hint <> '';
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    S := LowerCase(D.Align);
    if S = 'right' then Result.Alignment := taRightJustify
    else if S = 'center' then Result.Alignment := taCenter
    else if S = 'left' then Result.Alignment := taLeftJustify;
    Result.MaxLength := StrToIntDef(D.GetX('maxLength'), 0);
    Result.Mask := D.GetX('mask');
    { popis stavki: list:a;b;c ili vrijednosti iz kljuca items }
    S := D.GetX('items');
    if (S = '') and (Copy(D.RowSource, 1, 5) = 'list:') then S := Copy(D.RowSource, 6, MaxInt);
    if S <> '' then
    begin
      L := TStringList.Create;
      try
        L.Delimiter := ';';
        L.StrictDelimiter := True;
        L.DelimitedText := S;
        Result.Items.Assign(L);
      finally
        L.Free;
      end;
    end;
    { opcije }
    case V of
      evPassword: if D.GetX('passwordChar') <> '' then TaPasswordOptions(Result.Options).PasswordChar := D.GetX('passwordChar')[1];
      evCombo, evDroplist:
        begin
          TaComboOptions(Result.Options).DropDownCount := StrToIntDef(D.GetX('dropDownCount'), 8);
          TaComboOptions(Result.Options).AutoComplete := D.GetX('autoComplete') <> '0';
          TaComboOptions(Result.Options).Keyed := D.GetX('keyed') = '1';
          TaComboOptions(Result.Options).Search := D.GetX('search') = '1';
        end;
      evSpin:
        begin
          TaSpinOptions(Result.Options).DecimalPlaces := StrToIntDef(D.GetX('decimals'), 0);
          TaSpinOptions(Result.Options).MinValue := StrToFloatDef(D.GetX('min'), 0, DefaultFormatSettings);
          TaSpinOptions(Result.Options).MaxValue := StrToFloatDef(D.GetX('max'), 0, DefaultFormatSettings);
          TaSpinOptions(Result.Options).Increment := StrToFloatDef(D.GetX('step'), 1, DefaultFormatSettings);
        end;
      evCurrency:
        begin
          TaCurrencyOptions(Result.Options).DecimalPlaces := StrToIntDef(D.GetX('decimals'), 2);
          TaCurrencyOptions(Result.Options).Symbol := D.GetX('symbol');
        end;
      evDate: TaDateOptions(Result.Options).DateFormat := D.GetX('dateFormat');
      evLov:
        begin
          TaLovOptions(Result.Options).Source := D.GetX('lov');
          TaLovOptions(Result.Options).Map := D.GetX('lovmap');
          TaLovOptions(Result.Options).Validate := D.GetX('lovvalidate') = '1';
        end;
    end;
    Result.SetOptions(Result.Options);
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure EditToDef(E: TaEdit; D: TaControlDef);
var
  O: TaEditOptions;
  Ex: string;
  I: Integer;
  Sep: string;
begin
  D.Kind := 'Edit';
  D.Name := E.Name;
  D.Left := E.Left; D.Top := E.Top; D.Width := E.Width; D.Height := E.Height;
  D.ControlSource := E.ControlSource;
  D.RowSource := E.RowSource;
  D.Format := E.Format;
  case E.EffectiveAlignmentValue of
    taRightJustify: D.Align := 'right';
    taCenter: D.Align := 'center';
  else
    D.Align := '';
  end;
  { Extra: prvo ono sto obitelj ne poznaje, zatim poznati kljucevi }
  D.Extra := E.Extra;
  D.SetX('variant', E.VariantName);
  D.SetX('locked', IfThen(E.ReadOnly, '1', ''));
  D.SetX('tip', E.Hint);
  D.SetX('visibleIf', E.VisibleIf);
  D.SetX('enabledIf', E.EnabledIf);
  D.SetX('condFormat', E.CondFormat);
  D.SetX('maxLength', IfThen(E.MaxLength > 0, IntToStr(E.MaxLength), ''));
  D.SetX('mask', E.Mask);
  if E.Items.Count > 0 then
  begin
    Sep := '';
    Ex := '';
    for I := 0 to E.Items.Count - 1 do
    begin
      Ex := Ex + Sep + E.Items[I];
      Sep := ';';
    end;
    D.SetX('items', Ex);
  end
  else D.SetX('items', '');
  O := E.Options;
  if O is TaPasswordOptions then D.SetX('passwordChar', IfThen(TaPasswordOptions(O).PasswordChar <> '*', String(TaPasswordOptions(O).PasswordChar), ''))
  else if O is TaComboOptions then
  begin
    D.SetX('dropDownCount', IfThen(TaComboOptions(O).DropDownCount <> 8, IntToStr(TaComboOptions(O).DropDownCount), ''));
    D.SetX('autoComplete', IfThen(TaComboOptions(O).AutoComplete, '', '0'));
    D.SetX('keyed', IfThen(TaComboOptions(O).Keyed, '1', ''));
    D.SetX('search', IfThen(TaComboOptions(O).Search, '1', ''));
  end
  else if O is TaSpinOptions then
  begin
    D.SetX('decimals', IfThen(TaSpinOptions(O).DecimalPlaces <> 0, IntToStr(TaSpinOptions(O).DecimalPlaces), ''));
    D.SetX('min', IfThen(TaSpinOptions(O).MinValue <> 0, FloatToStr(TaSpinOptions(O).MinValue, DefaultFormatSettings), ''));
    D.SetX('max', IfThen(TaSpinOptions(O).MaxValue <> 0, FloatToStr(TaSpinOptions(O).MaxValue, DefaultFormatSettings), ''));
    D.SetX('step', IfThen(TaSpinOptions(O).Increment <> 1, FloatToStr(TaSpinOptions(O).Increment, DefaultFormatSettings), ''));
  end
  else if O is TaCurrencyOptions then
  begin
    D.SetX('decimals', IfThen(TaCurrencyOptions(O).DecimalPlaces <> 2, IntToStr(TaCurrencyOptions(O).DecimalPlaces), ''));
    D.SetX('symbol', TaCurrencyOptions(O).Symbol);
  end
  else if O is TaDateOptions then D.SetX('dateFormat', TaDateOptions(O).DateFormat)
  else if O is TaLovOptions then
  begin
    D.SetX('lov', TaLovOptions(O).Source);
    D.SetX('lovmap', TaLovOptions(O).Map);
    D.SetX('lovvalidate', IfThen(TaLovOptions(O).Validate, '1', ''));
  end;
end;

function EditToLfm(E: TaEdit): string;
var
  M: TMemoryStream;
  L: TStringList;
begin
  M := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(M, E);
    M.Position := 0;
    L.LoadFromStream(M);
    Result := L.Text;
  finally
    L.Free;
    M.Free;
  end;
end;

type
  TLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaEdit') then AClass := TaEdit;
end;

function EditFromLfm(const ALfm: string; AOwner: TComponent): TaEdit;
var
  M: TMemoryStream;
  C: TComponent;
  F: TLfmFinder;
begin
  M := TMemoryStream.Create;
  try
    if ALfm <> '' then M.WriteBuffer(ALfm[1], Length(ALfm));
    M.Position := 0;
    C := nil;
    F := TLfmFinder.Create;
    try
      ReadComponentFromTextStream(M, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaEdit;
  finally
    M.Free;
  end;
end;

initialization
  RegisterClass(TaEdit);
  RegisterEngine(EditFamily, 'text', TaEditTextEngine);
  RegisterEngine(EditFamily, 'password', TaEditPasswordEngine);
  RegisterEngine(EditFamily, 'combo', TaEditComboEngine);
  RegisterEngine(EditFamily, 'droplist', TaEditDroplistEngine);
  RegisterEngine(EditFamily, 'spin', TaEditSpinEngine);
  RegisterEngine(EditFamily, 'date', TaEditDateEngine);
  RegisterEngine(EditFamily, 'currency', TaEditCurrencyEngine);
  RegisterEngine(EditFamily, 'lov', TaEditLovEngine);

end.
