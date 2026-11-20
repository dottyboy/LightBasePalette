unit ta_contcomp;
{ TaContinuousForm: neprekidna forma kao komponenta za paletu (poglavlje 20 plana, korak 7).
  Komponenta ima tri odjeljka (visine HeaderHeight, RowHeight, FooterHeight) koji se crtaju u dizajnu kao pojasevi;
  kontrole se bacaju izravno na komponentu, a odjeljak odreduje polozaj (kao u TyphAccess dizajneru):
    zaglavlje  naslovi, filtri, gumbi
    detalj     JEDAN red (predlozak koji se ponavlja za svaki zapis)
    podnozje   zbrojevi (=Sum(iznos), =Count()), gumbi
  Povezivanje kontrola s poljima: kontrola TaEdit ima ControlSource; za ostale (oznake, kvacice) je svojstvo Bindings,
  redak po kontroli: "naziv=polje" (vezano polje), "naziv=sort:polje" (klik na oznaku sortira), "naziv=filter:polje".
  Pri izvodenju se iz panela gradi ista definicija kao u TyphAccessu (TaFormDef) i radi isti kod (TaContinuousBody),
  pa je ponasanje u IDE-u i u TyphAccess dizajneru jednako. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, ta_meta, ta_formdef, ta_edit, ta_components, ta_contform,
  ta_rowhost, ta_keymap;

type
  TaContButtonEvent = procedure(Sender: TObject; const AControlName: string; ARow: Integer) of object;

  TaContinuousForm = class(TCustomPanel)
  private
    FDatabase: TaDatabase;
    FRecordSource: string;
    FHeaderH, FFooterH: Integer;
    FHidden: TList;              { kontrole skrivene dok je tijelo aktivno }
    FBody: TaContinuousBody;
    FDef: TaFormDef;
    FBindings: TStrings;
    FCalcRules, FMasterField, FDetailField, FFilter: string;
    FAllowAdds, FAllowEdits, FAllowDeletes: Boolean;
    FRowHeight: Integer;
    FOnButton: TaContButtonEvent;
    FOnDataChange: TNotifyEvent;
    procedure SetDatabase(AValue: TaDatabase);
    procedure SetBindings(AValue: TStrings);
    procedure SetRowHeight(AValue: Integer);
    procedure SetHeaderH(AValue: Integer);
    procedure SetFooterH(AValue: Integer);
    procedure BodyButton(Sender: TObject; const AControlName: string; ARow: Integer);
    procedure BodyData(Sender: TObject);
    function Binding(const AName, APrefix: string): string;
    procedure AddControls(ADef: TaFormDef);
  protected
    procedure Paint; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { definicija iz panela (isto sto bi dizajner TyphAccessa spremio) }
    function BuildDef: TaFormDef;
    { prikaz zapisa: gradi tijelo iz panela; paneli se skrivaju }
    procedure Open;
    procedure Close;
    function Active: Boolean;
    procedure SetMaster(const AValue: string);
    procedure Refresh;
    property Body: TaContinuousBody read FBody;
  published
    property Database: TaDatabase read FDatabase write SetDatabase;
    property RecordSource: string read FRecordSource write FRecordSource;
    property AllowAdds: Boolean read FAllowAdds write FAllowAdds default True;
    property AllowEdits: Boolean read FAllowEdits write FAllowEdits default True;
    property AllowDeletes: Boolean read FAllowDeletes write FAllowDeletes default True;
    { SQL uvjet koji uvijek vrijedi (uz filtre zaglavlja) }
    property Filter: string read FFilter write FFilter;
    property CalcRules: string read FCalcRules write FCalcRules;
    { podforma: stupac djeteta = vrijednost iz glavne forme (SetMaster) }
    property DetailField: string read FDetailField write FDetailField;
    property RowHeight: Integer read FRowHeight write SetRowHeight default 34;
    property Bindings: TStrings read FBindings write SetBindings;
    property HeaderHeight: Integer read FHeaderH write SetHeaderH default 56;
    property FooterHeight: Integer read FFooterH write SetFooterH default 40;
    property OnButtonClick: TaContButtonEvent read FOnButton write FOnButton;
    property OnDataChange: TNotifyEvent read FOnDataChange write FOnDataChange;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Enabled;
    property Visible;
  end;

implementation

uses
  ta_i18n;


constructor TaContinuousForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAllowAdds := True;
  FAllowEdits := True;
  FAllowDeletes := True;
  FRowHeight := 34;
  FHeaderH := 56;
  FFooterH := 40;
  FBindings := TStringList.Create;
  FHidden := TList.Create;
  BevelOuter := bvNone;
  Caption := '';
  SetBounds(0, 0, 480, 220);
end;

destructor TaContinuousForm.Destroy;
begin
  FreeAndNil(FBody);
  FreeAndNil(FDef);
  FHidden.Free;
  FBindings.Free;
  inherited Destroy;
end;

procedure TaContinuousForm.SetDatabase(AValue: TaDatabase);
begin
  if FDatabase = AValue then Exit;
  FDatabase := AValue;
  if FDatabase <> nil then FDatabase.FreeNotification(Self);
end;

procedure TaContinuousForm.SetBindings(AValue: TStrings);
begin
  FBindings.Assign(AValue);
end;

procedure TaContinuousForm.SetRowHeight(AValue: Integer);
begin
  if AValue < 24 then AValue := 24;
  FRowHeight := AValue;
  Invalidate;
end;

procedure TaContinuousForm.SetHeaderH(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  FHeaderH := AValue;
  Invalidate;
end;

procedure TaContinuousForm.SetFooterH(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  FFooterH := AValue;
  Invalidate;
end;

procedure TaContinuousForm.Paint;
const
  Caps: array[0..2] of string = ('Zaglavlje', 'Detalj (jedan zapis, ponavlja se)', 'Podnožje');
var
  Y, H, I: Integer;
begin
  inherited Paint;
  if FBody <> nil then Exit;
  Canvas.Brush.Color := RGBToColor(244, 244, 246);
  Canvas.FillRect(0, FHeaderH + FRowHeight, Width, Height - FFooterH);
  Canvas.Font.Color := clSilver;
  Canvas.Font.Size := 7;
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(8, FHeaderH + FRowHeight + 6, Tr('other rows (they appear while running)'));
  Canvas.Brush.Style := bsSolid;
  Y := 0;
  for I := 0 to 2 do
  begin
    case I of
      0: begin H := FHeaderH; Canvas.Brush.Color := RGBToColor(235, 240, 250); end;
      1: begin H := FRowHeight; Canvas.Brush.Color := RGBToColor(255, 255, 255); end;
    else
      begin H := FFooterH; Canvas.Brush.Color := RGBToColor(240, 245, 235); end;
    end;
    if I = 2 then Y := Height - H;
    Canvas.FillRect(0, Y, Width, Y + H);
    Canvas.Font.Color := clGray;
    Canvas.Font.Size := 7;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(Width - Canvas.TextWidth(Tr(Caps[I])) - 6, Y + H - 14, Tr(Caps[I]));
    Canvas.Brush.Style := bsSolid;
    if I = 1 then
    begin
      Canvas.Pen.Color := RGBToColor(203, 213, 225);
      Canvas.Line(0, Y + H, Width, Y + H);
    end;
    Inc(Y, H);
  end;
end;

procedure TaContinuousForm.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (AComponent = FDatabase) then
  begin
    Close;
    FDatabase := nil;
  end;
end;

procedure TaContinuousForm.Loaded;
begin
  inherited Loaded;
  if not (csDesigning in ComponentState) then
    if (FDatabase <> nil) and FDatabase.Connected and (FRecordSource <> '') then
      try
        Open;
      except
      end;
end;

{ "naziv=polje", "naziv=sort:polje", "naziv=filter:polje" }
function TaContinuousForm.Binding(const AName, APrefix: string): string;
var
  I: Integer;
  V: string;
begin
  Result := '';
  for I := 0 to FBindings.Count - 1 do
    if SameText(FBindings.Names[I], AName) then
    begin
      V := FBindings.ValueFromIndex[I];
      if APrefix = '' then
      begin
        if (Pos('sort:', LowerCase(V)) <> 1) and (Pos('filter:', LowerCase(V)) <> 1) then Exit(V);
      end
      else if Pos(APrefix + ':', LowerCase(V)) = 1 then Exit(Copy(V, Length(APrefix) + 2, MaxInt));
    end;
end;

procedure TaContinuousForm.AddControls(ADef: TaFormDef);
var
  I, Mid: Integer;
  Sec: string;
  C: TControl;
  D: TaControlDef;
  E: TaEdit;
begin
  for I := 0 to ControlCount - 1 do
  begin
    C := Controls[I];
    if C = FBody then Continue;
    Mid := C.Top + C.Height div 2;
    { prazan prostor izmedju reda i podnozja: kontrole tamo nisu u odjeljku }
    if (Mid >= FHeaderH + FRowHeight) and (Mid < Height - FFooterH) then Continue;
    D := TaControlDef.Create;
    D.Name := C.Name;
    if Mid < FHeaderH then begin Sec := 'header'; D.Top := C.Top; end
    else if Mid >= Height - FFooterH then begin Sec := 'footer'; D.Top := C.Top - (Height - FFooterH); end
    else begin Sec := 'detail'; D.Top := C.Top - FHeaderH; end;
    if D.Top < 0 then D.Top := 0;
    D.Section := Sec;
    D.Left := C.Left;
    D.Width := C.Width;
    D.Height := C.Height;
    if C is TaEdit then
    begin
      E := TaEdit(C);
      if E.Variant in [evCombo, evDroplist] then D.Kind := 'ComboBox' else D.Kind := 'TextBox';
      D.ControlSource := E.ControlSource;
      if D.ControlSource = '' then D.ControlSource := Binding(C.Name, '');
      D.Format := E.Format;
      D.RowSource := E.RowSource;
      if E.Alignment = taRightJustify then D.Align := 'right';
      if Binding(C.Name, 'filter') <> '' then D.SetX('filter', Binding(C.Name, 'filter'));
    end
    else if C is TLabel then
    begin
      D.Kind := 'Label';
      D.Caption := TLabel(C).Caption;
      D.Bold := fsBold in TLabel(C).Font.Style;
      D.ControlSource := Binding(C.Name, '');
      if Binding(C.Name, 'sort') <> '' then D.SetX('sort', Binding(C.Name, 'sort'));
    end
    else if C is TCheckBox then
    begin
      D.Kind := 'CheckBox';
      D.ControlSource := Binding(C.Name, '');
    end
    else if C is TButton then
    begin
      D.Kind := 'Button';
      D.Caption := TButton(C).Caption;
    end
    else
    begin
      D.Free;
      Continue;
    end;
    ADef.Add(D);
  end;
end;

function TaContinuousForm.BuildDef: TaFormDef;
begin
  Result := TaFormDef.Create;
  Result.Name := Name;
  Result.RecordSource := FRecordSource;
  Result.ViewMode := 'continuous';
  Result.AllowAdds := FAllowAdds;
  Result.AllowEdits := FAllowEdits;
  Result.AllowDeletes := FAllowDeletes;
  Result.CalcRules := FCalcRules;
  Result.Filter := FFilter;
  Result.NavButtons := False;
  Result.HeaderHeight := FHeaderH;
  Result.RowHeight := FRowHeight;
  Result.FooterHeight := FFooterH;
  Result.Width := Width;
  Result.Height := Height;
  AddControls(Result);
end;

procedure TaContinuousForm.Open;
var
  D: TaFormDef;
  I: Integer;
begin
  if FDatabase = nil then raise Exception.Create(Tr('TaContinuousForm: Database is not set'));
  if not FDatabase.Connected then raise Exception.Create(Tr('TaContinuousForm: the database is not open'));
  Close;
  D := BuildDef;
  FDef := D;
  begin
    FBody := TaContinuousBody.Create(Self);
    FBody.Parent := Self;
    FBody.Align := alClient;
    FBody.OnButton := @BodyButton;
    FBody.Setup(FDatabase.Db, D);
    FBody.Host.OnDataChange := @BodyData;
    FHidden.Clear;
    for I := 0 to ControlCount - 1 do
      if (Controls[I] <> FBody) and Controls[I].Visible then
      begin
        FHidden.Add(Controls[I]);
        Controls[I].Visible := False;
      end;
    if FDetailField <> '' then FBody.SetMaster(FDetailField, '');
  end;
end;

procedure TaContinuousForm.Close;
var
  I: Integer;
begin
  FreeAndNil(FBody);
  FreeAndNil(FDef);
  for I := 0 to FHidden.Count - 1 do TControl(FHidden[I]).Visible := True;
  FHidden.Clear;
  Invalidate;
end;

function TaContinuousForm.Active: Boolean;
begin
  Result := FBody <> nil;
end;

procedure TaContinuousForm.SetMaster(const AValue: string);
begin
  if FBody <> nil then FBody.SetMaster(FDetailField, AValue);
end;

procedure TaContinuousForm.Refresh;
begin
  if FBody <> nil then
  begin
    FBody.Host.Reload;
    FBody.RefreshFooter;
  end;
end;

procedure TaContinuousForm.BodyButton(Sender: TObject; const AControlName: string; ARow: Integer);
begin
  if Assigned(FOnButton) then FOnButton(Self, AControlName, ARow);
end;

procedure TaContinuousForm.BodyData(Sender: TObject);
begin
  if FBody <> nil then FBody.RefreshFooter;
  if Assigned(FOnDataChange) then FOnDataChange(Self);
end;

end.
