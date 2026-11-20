unit ta_rowhost;
{ Prikaz neprekidne forme (poglavlje 20 plana): redovi se CRTAJU iz predlozka detalja u jednoj kontroli, a samo trenutni
  red je "ziv" (pravi paneli i kontrole). Mjerenje (tests/rowspike): pravi redovi 40-160 ms po koraku klizanja,
  crtani redovi oko 12 ms. Podaci: TaRowSource (prozor zapisa), stanje: TaRowModel. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Graphics, Types, LCLType, Variants,
  ta_formdef, ta_rowmodel, ta_rowsource, ta_tokens, ta_edit, ta_expr, ta_keymap, ta_bindengine, ta_source, DB;

type
  TaRowCell = record
    Def: TaControlDef;
    Kind: string;       { mala slova: textbox, combobox, checkbox, label, button }
    X, Y, W, H: Integer;
    Field: string;
  end;

  { pravilo izracuna: "cijena,kolicina -> iznos = Zaokruzi([cijena]*[kolicina], 2) ;; ..." (isti zapis kao CalcRules forme) }
  TaRowRule = TaCalcRuleDef;

  TaRowButtonEvent = procedure(Sender: TObject; ADef: TaControlDef; ARow: Integer) of object;
  TaRowActionEvent = procedure(Sender: TObject; AAction: TaKeyAction; var AHandled: Boolean) of object;

  TaRowsView = class(TCustomControl)
  private
    FRules: array of TaRowRule;
    FRaw: array of string;       { sirove vrijednosti zivog reda (prikaz moze biti oblikovan) }
    FRuleDepth: Integer;
    FSource: TaRowSource;
    FModel: TaRowModel;
    FCells: array of TaRowCell;
    FLive: TPanel;
    FLiveCtrls: array of TControl;
    FLiveRow: Integer;
    FBar: TScrollBar;
    FRowHeight: Integer;
    FSelW: Integer;
    FFilling: Boolean;
    FError: string;
    FOnButton: TaRowButtonEvent;
    FOnRowChange: TNotifyEvent;
    FOnDataChange: TNotifyEvent;
    FKeyMap: TaKeyMap;
    FOnAction: TaRowActionEvent;
    FFocusCell: Integer;
    procedure LiveKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function LovCheck: string;
    procedure LiveEnter(Sender: TObject);
    procedure LiveLov(Sender: TObject);
    procedure FocusCell(AIndex: Integer);
    function Tabbable(AList: TList): Integer;
    procedure ParseRules(const ARules: string);
    procedure ApplyRules(const AField: string);
    procedure ShowCell(AIndex: Integer; const ARaw: string; AFocused: Boolean);
    procedure LiveExit(Sender: TObject);
    function RowValue(const AField: string): Variant;
    procedure BarChange(Sender: TObject);
    procedure LiveChanged(Sender: TObject);
    procedure LiveButton(Sender: TObject);
    procedure FillLive;
    procedure PlaceLive;
    procedure SyncBar;
    function CellText(ACell: TaRowCell; ARow: Integer): string;
    procedure DrawCell(ACanvas: TCanvas; const ACell: TaRowCell; ARow, ATop, ALeft: Integer; AFg: TColor);
    function RowAtY(Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { predlozak: kontrole definicije s Section = 'detail' (ako nijedna nema Section, sve kontrole) }
    procedure Setup(ASource: TaRowSource; ADef: TaFormDef; ARowHeight: Integer = 0);
    procedure Reload;
    { crta jedan red (za crtanje i za testove) }
    procedure DrawRow(ACanvas: TCanvas; ARow, ATop: Integer);
    { prelazak na red; prljav red se prvo sprema; False ako spremanje nije uspjelo (fokus ostaje) }
    function GoToRow(ARow: Integer): Boolean;
    procedure ScrollTo(AOffset: Integer);
    { klik misem u koordinatama prikaza (za testove i skripte) }
    procedure ClickAt(X, Y: Integer);
    function CommitRow: Boolean;
    { popis vrijednosti (F9) za celiju s Def.X lov / lovmap / lovvalidate; False ako celija nema popis }
    function ShowLov(ACell: Integer): Boolean;
    procedure CancelRow;
    function DeleteCurrent: Boolean;
    function LiveControl(AIndex: Integer): TControl;
    function CellCount: Integer;
    function CellField(AIndex: Integer): string;
    { za testove i skripte: isto sto korisnik napravi unosom u zivoj kontroli }
    procedure SimulateEdit(AIndex: Integer; const AValue: string);
    { fokus ulazi u kontrolu / izlazi iz nje (prikaz sirove odnosno oblikovane vrijednosti) }
    procedure SimulateEnter(AIndex: Integer);
    procedure SimulateExit(AIndex: Integer);
    { sirova vrijednost celije zivog reda }
    function RawValue(AIndex: Integer): string;
    { tipka u zivom redu: True ako je obradena (Key postaje 0). Sender je kontrola zivog reda. }
    function HandleKey(var Key: Word; Shift: TShiftState; ASender: TObject): Boolean;
    { kontrola zivog reda koja ima fokus (indeks celije), -1 ako nijedna }
    property FocusedCell: Integer read FFocusCell;
    property KeyMap: TaKeyMap read FKeyMap write FKeyMap;
    property OnAction: TaRowActionEvent read FOnAction write FOnAction;
    property Model: TaRowModel read FModel;
    property Source: TaRowSource read FSource;
    property RowHeight: Integer read FRowHeight;
    property SelectorWidth: Integer read FSelW;
    property Error: string read FError;
    property OnButton: TaRowButtonEvent read FOnButton write FOnButton;
    property OnRowChange: TNotifyEvent read FOnRowChange write FOnRowChange;
    { zapis je spremljen ili obrisan (zbrojevi u podnozju se osvjezavaju) }
    property OnDataChange: TNotifyEvent read FOnDataChange write FOnDataChange;
  end;

implementation

{ sirova vrijednost -> prikaz prema Format kontrole }
function FormatRaw(const AFormat, ARaw: string): string;
begin
  Result := ARaw;
  if (ARaw = '') or (AFormat = '') then Exit;
  try
    Result := FormatValue(StrToFloat(StringReplace(ARaw, ',', '.', [])), AFormat);
  except
    Result := ARaw;
  end;
end;


constructor TaRowsView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FModel := TaRowModel.Create;
  FSelW := 20;
  FRowHeight := 30;
  FLiveRow := -1;
  FFocusCell := -1;
  FKeyMap := GlobalKeyMap;
  DoubleBuffered := True;
  FBar := TScrollBar.Create(Self);
  FBar.Parent := Self;
  FBar.Kind := sbVertical;
  FBar.Align := alRight;
  FBar.OnChange := @BarChange;
  FLive := TPanel.Create(Self);
  FLive.Parent := Self;
  FLive.BevelOuter := bvNone;
  FLive.Visible := False;
end;

destructor TaRowsView.Destroy;
begin
  FModel.Free;
  inherited Destroy;
end;

procedure TaRowsView.Setup(ASource: TaRowSource; ADef: TaFormDef; ARowHeight: Integer);
var
  I, N, MaxB: Integer;
  D: TaControlDef;
  AnySection: Boolean;
  K: string;
begin
  FSource := ASource;
  ParseRules(ADef.CalcRules);
  FModel.AllowAdds := ADef.AllowAdds and ASource.CanEdit;
  AnySection := False;
  for I := 0 to ADef.Count - 1 do
    if ADef[I].Section <> '' then AnySection := True;
  SetLength(FCells, 0);
  MaxB := 0;
  for I := 0 to ADef.Count - 1 do
  begin
    D := ADef[I];
    if AnySection and not SameText(D.Section, 'detail') then Continue;
    K := LowerCase(D.Kind);
    if (K <> 'textbox') and (K <> 'combobox') and (K <> 'checkbox') and (K <> 'label') and (K <> 'button') then Continue;
    N := Length(FCells);
    SetLength(FCells, N + 1);
    FCells[N].Def := D;
    FCells[N].Kind := K;
    FCells[N].X := D.Left;
    FCells[N].Y := D.Top;
    FCells[N].W := D.Width;
    FCells[N].H := D.Height;
    FCells[N].Field := D.ControlSource;
    if D.Top + D.Height > MaxB then MaxB := D.Top + D.Height;
  end;
  if ARowHeight > 0 then FRowHeight := ARowHeight else FRowHeight := MaxB + 6;
  if FRowHeight < 24 then FRowHeight := 24;
  { zivi red: po jedna prava kontrola za svaku celiju }
  for I := FLive.ControlCount - 1 downto 0 do FLive.Controls[I].Free;
  SetLength(FLiveCtrls, Length(FCells));
  SetLength(FRaw, Length(FCells));
  for I := 0 to High(FCells) do
  begin
    if FCells[I].Kind = 'checkbox' then
    begin
      FLiveCtrls[I] := TCheckBox.Create(FLive);
      TCheckBox(FLiveCtrls[I]).Caption := '';
      TCheckBox(FLiveCtrls[I]).OnClick := @LiveChanged;
      TCheckBox(FLiveCtrls[I]).OnKeyDown := @LiveKeyDown;
      TCheckBox(FLiveCtrls[I]).OnEnter := @LiveEnter;
    end
    else if FCells[I].Kind = 'label' then
    begin
      FLiveCtrls[I] := TLabel.Create(FLive);
      TLabel(FLiveCtrls[I]).Caption := FCells[I].Def.Caption;
    end
    else if FCells[I].Kind = 'button' then
    begin
      FLiveCtrls[I] := TButton.Create(FLive);
      TButton(FLiveCtrls[I]).Caption := FCells[I].Def.Caption;
      TButton(FLiveCtrls[I]).OnClick := @LiveButton;
      TButton(FLiveCtrls[I]).OnKeyDown := @LiveKeyDown;
      TButton(FLiveCtrls[I]).OnEnter := @LiveEnter;
    end
    else
    begin
      FLiveCtrls[I] := TaEdit.Create(FLive);
      if FCells[I].Kind = 'combobox' then TaEdit(FLiveCtrls[I]).Variant := evCombo
      else if (FCells[I].Def <> nil) and (FCells[I].Def.GetX('lov') <> '') then
      begin
        TaEdit(FLiveCtrls[I]).Variant := evLov;       { polje s gumbom ... }
        TaEdit(FLiveCtrls[I]).OnLov := @LiveLov;
      end;
      TaEdit(FLiveCtrls[I]).OnChange := @LiveChanged;
      TaEdit(FLiveCtrls[I]).OnInnerKeyDown := @LiveKeyDown;
      TaEdit(FLiveCtrls[I]).OnEnter := @LiveEnter;
      TaEdit(FLiveCtrls[I]).OnExit := @LiveExit;
      if (FSource <> nil) and (not FSource.CanEdit) then TaEdit(FLiveCtrls[I]).ReadOnly := True;
    end;
    FLiveCtrls[I].Parent := FLive;
    FLiveCtrls[I].Tag := I;
    FLiveCtrls[I].SetBounds(FCells[I].X, FCells[I].Y, FCells[I].W, FCells[I].H);
  end;
  FLive.Height := FRowHeight;
  Reload;
end;

procedure TaRowsView.Reload;
var
  N: Integer;
begin
  if FSource = nil then Exit;
  N := FSource.Count;
  FModel.SetRecordCount(N);
  FModel.SetViewRows(Height div FRowHeight);
  FSource.Fetch(FModel.Offset, FModel.ViewRows + 40);
  FLiveRow := -1;
  SyncBar;
  PlaceLive;
  Invalidate;
end;

procedure TaRowsView.Resize;
begin
  inherited Resize;
  if (FSource <> nil) and (FRowHeight > 0) then
  begin
    FModel.SetViewRows(Height div FRowHeight);
    SyncBar;
    PlaceLive;
  end;
end;

procedure TaRowsView.SyncBar;
begin
  FBar.OnChange := nil;
  FBar.Min := 0;
  FBar.Max := FModel.RowCount - 1;
  if FBar.Max < 0 then FBar.Max := 0;
  FBar.PageSize := FModel.ViewRows;
  FBar.LargeChange := FModel.ViewRows;
  FBar.Position := FModel.Offset;
  FBar.Visible := FModel.RowCount > FModel.ViewRows;
  FBar.OnChange := @BarChange;
end;

procedure TaRowsView.ScrollTo(AOffset: Integer);
begin
  FModel.ScrollTo(AOffset);
  FSource.Fetch(FModel.Offset, FModel.ViewRows + 40);
  SyncBar;
  PlaceLive;
  Invalidate;
end;

procedure TaRowsView.BarChange(Sender: TObject);
begin
  ScrollTo(FBar.Position);
end;

function TaRowsView.CellText(ACell: TaRowCell; ARow: Integer): string;
var
  V: string;
begin
  Result := '';
  if ACell.Kind = 'label' then
  begin
    if ACell.Field = '' then Result := ACell.Def.Caption
    else if not FModel.IsNewRow(ARow) then Result := FSource.Value(ARow, ACell.Field);
    Exit;
  end;
  if ACell.Kind = 'button' then Exit(ACell.Def.Caption);
  if ACell.Field = '' then Exit;
  if FModel.IsNewRow(ARow) then Exit;
  V := FSource.Value(ARow, ACell.Field);
  Result := FormatRaw(ACell.Def.Format, V);
end;

procedure TaRowsView.DrawCell(ACanvas: TCanvas; const ACell: TaRowCell; ARow, ATop, ALeft: Integer; AFg: TColor);
var
  T: TaThemeTokens;
  R: TRect;
  S: string;
  Tw: Integer;
  Al: Boolean;
begin
  T := ActiveTokens;
  R := Rect(ALeft + ACell.X, ATop + ACell.Y, ALeft + ACell.X + ACell.W, ATop + ACell.Y + ACell.H);
  case ACell.Kind of
    'checkbox':
      begin
        ACanvas.Pen.Color := TokenColor(T.Border);
        ACanvas.Brush.Color := TokenColor(T.Surface);
        ACanvas.Rectangle(R.Left + 2, R.Top + 2, R.Left + 16, R.Top + 16);
        S := CellText(ACell, ARow);
        if (S = '1') or SameText(S, 'true') or SameText(S, 'da') then
        begin
          ACanvas.Pen.Color := TokenColor(T.Accent);
          ACanvas.Pen.Width := 2;
          ACanvas.MoveTo(R.Left + 5, R.Top + 9);
          ACanvas.LineTo(R.Left + 8, R.Top + 13);
          ACanvas.LineTo(R.Left + 13, R.Top + 5);
          ACanvas.Pen.Width := 1;
        end;
      end;
    'label':
      begin
        ACanvas.Brush.Style := bsClear;
        ACanvas.Font.Color := AFg;
        ACanvas.TextRect(R, R.Left + 2, R.Top + 3, CellText(ACell, ARow));
        ACanvas.Brush.Style := bsSolid;
      end;
    'button':
      begin
        ACanvas.Pen.Color := TokenColor(T.Border);
        ACanvas.Brush.Color := TokenColor(T.Soft);
        ACanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, T.RadiusButton, T.RadiusButton);
        ACanvas.Font.Color := AFg;
        S := CellText(ACell, ARow);
        Tw := ACanvas.TextWidth(S);
        ACanvas.Brush.Style := bsClear;
        ACanvas.TextRect(R, R.Left + (R.Right - R.Left - Tw) div 2, R.Top + (R.Bottom - R.Top - ACanvas.TextHeight(S)) div 2, S);
        ACanvas.Brush.Style := bsSolid;
      end;
  else
    begin
      { textbox, combobox }
      ACanvas.Pen.Color := TokenColor(T.Border);
      ACanvas.Brush.Color := TokenColor(T.Surface);
      ACanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, T.RadiusField, T.RadiusField);
      S := CellText(ACell, ARow);
      ACanvas.Font.Color := AFg;
      ACanvas.Brush.Style := bsClear;
      Al := (ACell.Def.Align = 'right') or (ACell.Def.Format <> '');
      if Al then
      begin
        Tw := ACanvas.TextWidth(S);
        ACanvas.TextRect(R, R.Right - Tw - 6, R.Top + (R.Bottom - R.Top - ACanvas.TextHeight(S)) div 2, S);
      end
      else
        ACanvas.TextRect(R, R.Left + 6, R.Top + (R.Bottom - R.Top - ACanvas.TextHeight(S)) div 2, S);
      ACanvas.Brush.Style := bsSolid;
      if ACell.Kind = 'combobox' then
      begin
        ACanvas.Pen.Color := TokenColor(T.TextSoft);
        ACanvas.MoveTo(R.Right - 14, R.Top + (R.Bottom - R.Top) div 2 - 2);
        ACanvas.LineTo(R.Right - 10, R.Top + (R.Bottom - R.Top) div 2 + 2);
        ACanvas.LineTo(R.Right - 6, R.Top + (R.Bottom - R.Top) div 2 - 2);
      end;
    end;
  end;
end;

procedure TaRowsView.DrawRow(ACanvas: TCanvas; ARow, ATop: Integer);
var
  T: TaThemeTokens;
  Bg: TColor;
  I: Integer;
  Mark: string;
begin
  T := ActiveTokens;
  if ARow = FModel.Current then Bg := TokenColor(T.AccentSoft)
  else if (ARow and 1) = 1 then Bg := TokenColor(T.Soft)
  else Bg := TokenColor(T.Surface);
  ACanvas.Brush.Color := Bg;
  ACanvas.Pen.Style := psClear;
  ACanvas.Rectangle(0, ATop, Width, ATop + FRowHeight + 1);
  ACanvas.Pen.Style := psSolid;
  { birac zapisa }
  ACanvas.Brush.Color := TokenColor(T.Header);
  ACanvas.FillRect(0, ATop, FSelW, ATop + FRowHeight);
  ACanvas.Font.Color := TokenColor(T.TextSoft);
  ACanvas.Brush.Style := bsClear;
  Mark := '';
  if (ARow = FModel.Current) and FModel.Dirty then Mark := '✎'
  else if FModel.IsNewRow(ARow) then Mark := '*'
  else if ARow = FModel.Current then Mark := '▶';
  if Mark <> '' then ACanvas.TextOut(4, ATop + (FRowHeight - ACanvas.TextHeight(Mark)) div 2, Mark);
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := Bg;
  if (ARow = FModel.Current) and (FLiveRow = ARow) then Exit;   { ziv red crta sam sebe }
  for I := 0 to High(FCells) do DrawCell(ACanvas, FCells[I], ARow, ATop, FSelW, TokenColor(T.Text));
end;

procedure TaRowsView.Paint;
var
  T: TaThemeTokens;
  I, Row, Y: Integer;
begin
  if FSource = nil then Exit;
  T := ActiveTokens;
  Canvas.Brush.Color := TokenColor(T.Surface);
  Canvas.FillRect(0, 0, Width, Height);
  Canvas.Font.Name := T.FontFamily;
  Canvas.Font.Size := T.FontSize;
  I := 0;
  repeat
    Row := FModel.Offset + I;
    Y := I * FRowHeight;
    if (Row >= FModel.RowCount) or (Y >= Height) then Break;
    DrawRow(Canvas, Row, Y);
    Inc(I);
  until False;
end;

procedure TaRowsView.PlaceLive;
var
  Y: Integer;
begin
  if (FSource = nil) or (FModel.RowCount = 0) or (FModel.Current < FModel.Offset) or
     (FModel.Current >= FModel.Offset + FModel.ViewRows) then
  begin
    FLive.Visible := False;
    Exit;
  end;
  Y := (FModel.Current - FModel.Offset) * FRowHeight;
  FLive.SetBounds(FSelW, Y, Width - FSelW - FBar.Width * Ord(FBar.Visible), FRowHeight);
  if FLiveRow <> FModel.Current then FillLive;
  FLive.Color := TokenColor(ActiveTokens.AccentSoft);
  FLive.Visible := True;
end;

type
  { vrijednosti polja trenutnog reda za izraze pravila }
  TaRowExprHost = class(TaExprHost)
  public
    View: TaRowsView;
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
  end;

function TaRowExprHost.FieldValue(const AName: string): Variant;
begin
  Result := View.RowValue(AName);
end;

function TaRowExprHost.Aggregate(const AFunc, AField: string): Variant;
var
  S: string;
begin
  S := View.Source.Aggregate(AFunc, AField);
  if S = '' then Result := Null
  else
    try
      Result := StrToFloat(StringReplace(S, ',', '.', []));
    except
      Result := S;
    end;
end;

function TaRowExprHost.Variable(const AName: string): Variant;
begin
  Result := Null;
end;

function TaRowsView.RowValue(const AField: string): Variant;
var
  I: Integer;
  S: string;
  D: Double;
begin
  S := '';
  if FSource.HasPending(AField) then S := FSource.Pending(AField)
  else
  begin
    { nepromijenjena vrijednost iz reda; pravo ime stupca (velika/mala slova) }
    for I := 0 to FSource.Columns.Count - 1 do
      if SameText(FSource.Columns[I], AField) then
        if not FModel.IsNewRow(FModel.Current) then S := FSource.Value(FModel.Current, FSource.Columns[I]);
  end;
  if S = '' then Exit(Null);
  if TryStrToFloat(StringReplace(S, ',', '.', []), D, DefaultFormatSettings) then Result := D
  else Result := S;
end;

procedure TaRowsView.ParseRules(const ARules: string);
var
  Defs: TaCalcRuleDefs;
  I: Integer;
begin
  Defs := ParseCalcRuleDefs(ARules);
  SetLength(FRules, Length(Defs));
  for I := 0 to High(Defs) do FRules[I] := Defs[I];
end;

function RuleTriggers(const ARule: TaCalcRuleDef; const AField: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(ARule.Triggers) do
    if SameText(ARule.Triggers[I], AField) then Exit(True);
end;

{ prikaz celije: u fokusu sirova vrijednost, inace oblikovana }
procedure TaRowsView.ShowCell(AIndex: Integer; const ARaw: string; AFocused: Boolean);
var
  Txt: string;
begin
  FRaw[AIndex] := ARaw;
  Txt := ARaw;
  if not AFocused then Txt := FormatRaw(FCells[AIndex].Def.Format, ARaw);
  FFilling := True;
  try
    if FLiveCtrls[AIndex] is TaEdit then
    begin
      if TaEdit(FLiveCtrls[AIndex]).Text <> Txt then TaEdit(FLiveCtrls[AIndex]).Text := Txt;
    end
    else if FLiveCtrls[AIndex] is TCheckBox then
      TCheckBox(FLiveCtrls[AIndex]).Checked := (ARaw = '1') or SameText(ARaw, 'true') or SameText(ARaw, 'da')
    else if (FLiveCtrls[AIndex] is TLabel) and (FCells[AIndex].Field <> '') then TLabel(FLiveCtrls[AIndex]).Caption := Txt;
  finally
    FFilling := False;
  end;
end;

procedure TaRowsView.ApplyRules(const AField: string);
var
  I, K: Integer;
  H: TaRowExprHost;
  Eng: TaBindingEngine;
  S: string;
  IsNum: Boolean;
begin
  if (Length(FRules) = 0) or (FRuleDepth >= 4) then Exit;
  Inc(FRuleDepth);
  H := TaRowExprHost.Create;
  H.View := Self;
  Eng := TaBindingEngine.Create(H);
  try
    for I := 0 to High(FRules) do
      if RuleTriggers(FRules[I], AField) then
      begin
        if not Eng.CalcRuleStored(FRules[I], S, IsNum) then S := '';
        if not FSource.Editing then Continue;
        FSource.SetValue(FRules[I].Target, S);
        { celija s tim poljem u zivom redu }
        for K := 0 to High(FCells) do
          if SameText(FCells[K].Field, FRules[I].Target) then ShowCell(K, S, K = FFocusCell);
        { lancano: izracunato polje moze biti okidac drugom pravilu }
        ApplyRules(FRules[I].Target);
      end;
  finally
    Eng.Free;
    H.Free;
    Dec(FRuleDepth);
  end;
end;

procedure TaRowsView.LiveExit(Sender: TObject);
var
  I: Integer;
begin
  if not (Sender is TControl) then Exit;
  I := TControl(Sender).Tag;
  if (I < 0) or (I > High(FCells)) then Exit;
  if FFocusCell = I then FFocusCell := -1;
  if FCells[I].Def.Format <> '' then ShowCell(I, FRaw[I], False);
end;

procedure TaRowsView.SimulateEnter(AIndex: Integer);
begin
  LiveEnter(FLiveCtrls[AIndex]);
end;

procedure TaRowsView.SimulateExit(AIndex: Integer);
begin
  LiveExit(FLiveCtrls[AIndex]);
end;

function TaRowsView.RawValue(AIndex: Integer): string;
begin
  Result := FRaw[AIndex];
end;

procedure TaRowsView.FillLive;
var
  I: Integer;
  V: string;
begin
  for I := 0 to High(FCells) do
  begin
    V := '';
    if (FCells[I].Field <> '') and not FModel.IsNewRow(FModel.Current) then
      V := FSource.Value(FModel.Current, FCells[I].Field);
    ShowCell(I, V, False);
  end;
  FLiveRow := FModel.Current;
end;

procedure TaRowsView.LiveEnter(Sender: TObject);
var
  I: Integer;
begin
  if not (Sender is TControl) then Exit;
  I := TControl(Sender).Tag;
  FFocusCell := I;
  if (I >= 0) and (I <= High(FCells)) and (FCells[I].Def.Format <> '') then ShowCell(I, FRaw[I], True);
end;

procedure TaRowsView.LiveLov(Sender: TObject);
begin
  ShowLov(TControl(Sender).Tag);
end;

procedure TaRowsView.LiveKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  HandleKey(Key, Shift, Sender);
end;

{ indeksi celija koje primaju fokus (oznake ne primaju) }
function TaRowsView.Tabbable(AList: TList): Integer;
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to High(FCells) do
    if FCells[I].Kind <> 'label' then AList.Add(Pointer(PtrInt(I)));
  Result := AList.Count;
end;

procedure TaRowsView.FocusCell(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex > High(FLiveCtrls)) then Exit;
  FFocusCell := AIndex;
  if FLive.Visible and FLiveCtrls[AIndex].Visible and (GetParentForm(Self) <> nil) and GetParentForm(Self).Visible then
    try
      if FLiveCtrls[AIndex] is TWinControl then TWinControl(FLiveCtrls[AIndex]).SetFocus;
    except
    end;
end;

function TaRowsView.HandleKey(var Key: Word; Shift: TShiftState; ASender: TObject): Boolean;
var
  A: TaKeyAction;
  Tab: TList;
  Idx, P, NR, NC, Cell, Target: Integer;
  IsCombo, Handled: Boolean;
begin
  Result := False;
  if (FSource = nil) or (FKeyMap = nil) then Exit;
  A := FKeyMap.Resolve(Key, Shift);
  if A = kaNone then Exit;
  Cell := FFocusCell;
  if (ASender is TControl) and (TControl(ASender).Parent = FLive) then Cell := TControl(ASender).Tag;
  { u padajucem popisu strelice i stranice pripadaju popisu; na gumbu Enter i razmak pripadaju gumbu }
  IsCombo := (ASender is TaEdit) and (TaEdit(ASender).Variant in [evCombo, evDropList]);
  if IsCombo and (A in [kaNextRow, kaPrevRow, kaPageDown, kaPageUp]) then Exit;
  if (ASender is TButton) and ((Key = VK_RETURN) or (Key = VK_SPACE)) then Exit;
  Tab := TList.Create;
  try
    Tabbable(Tab);
    Idx := Tab.IndexOf(Pointer(PtrInt(Cell)));
    if Idx < 0 then Idx := 0;
    Handled := True;
    case A of
      kaNextField, kaPrevField:
        begin
          if Tab.Count = 0 then Exit;
          if FModel.TabTarget(FModel.Current, Idx, Tab.Count, A = kaPrevField, NR, NC) then
          begin
            if NR <> FModel.Current then
              if not GoToRow(NR) then begin Key := 0; Exit(True); end;
            FocusCell(PtrInt(Tab[NC]));
          end
          else if (A = kaNextField) and FModel.Dirty then
          begin
            { Tab s kraja zadnjeg reda sprema zapis, a fokus ide na novi prazan red }
            if CommitRow and (FModel.NewRow >= 0) then
              if GoToRow(FModel.NewRow) then FocusCell(PtrInt(Tab[0]));
          end;
        end;
      kaNextRow, kaPrevRow, kaPageDown, kaPageUp, kaFirstRecord, kaLastRecord, kaNewRecord:
        begin
          case A of
            kaNextRow: Target := FModel.Current + 1;
            kaPrevRow: Target := FModel.Current - 1;
            kaPageDown: Target := FModel.Current + FModel.ViewRows;
            kaPageUp: Target := FModel.Current - FModel.ViewRows;
            kaFirstRecord: Target := 0;
            kaLastRecord: if FModel.RecordCount > 0 then Target := FModel.RecordCount - 1 else Target := 0;
          else
            Target := FModel.NewRow;
          end;
          if Target < 0 then Target := 0;
          if Target >= FModel.RowCount then Target := FModel.RowCount - 1;
          if (A = kaNewRecord) and (FModel.NewRow < 0) then begin Key := 0; Exit(True); end;
          if GoToRow(Target) then
            if Tab.Count > 0 then
            begin
              if A = kaNewRecord then FocusCell(PtrInt(Tab[0])) else FocusCell(PtrInt(Tab[Idx]));
            end;
        end;
      kaLov: if not ShowLov(Cell) then Exit;
      kaSaveRow: CommitRow;
      kaCancelRow: CancelRow;
      kaDeleteRow: DeleteCurrent;
      kaCloseForm:
        if Assigned(FOnAction) then FOnAction(Self, kaCloseForm, Handled);
      kaCancelOrClose:
        if FModel.Dirty then CancelRow
        else if Assigned(FOnAction) then FOnAction(Self, kaCloseForm, Handled);
    end;
    Key := 0;
    Result := True;
  finally
    Tab.Free;
  end;
end;

function TaRowsView.LiveControl(AIndex: Integer): TControl;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex <= High(FLiveCtrls)) then Result := FLiveCtrls[AIndex];
end;

function TaRowsView.CellCount: Integer;
begin
  Result := Length(FCells);
end;

function TaRowsView.CellField(AIndex: Integer): string;
begin
  Result := FCells[AIndex].Field;
end;

procedure TaRowsView.LiveChanged(Sender: TObject);
var
  I: Integer;
  V: string;
begin
  if FFilling then Exit;
  I := TControl(Sender).Tag;
  if (I < 0) or (I > High(FCells)) or (FCells[I].Field = '') then Exit;
  if Sender is TCheckBox then
  begin
    if TCheckBox(Sender).Checked then V := '1' else V := '0';
  end
  else V := TaEdit(Sender).Text;
  if not FSource.Editing then
  begin
    if FModel.IsNewRow(FModel.Current) then
    begin
      if not FSource.BeginNew then begin FError := FSource.Error; Exit; end;
    end
    else if not FSource.BeginEdit(FModel.Current) then begin FError := FSource.Error; Exit; end;
  end;
  FRaw[I] := V;
  FSource.SetValue(FCells[I].Field, V);
  FModel.MarkDirty;
  ApplyRules(FCells[I].Field);
  Invalidate;
end;

procedure TaRowsView.LiveButton(Sender: TObject);
var
  I: Integer;
begin
  I := TControl(Sender).Tag;
  if Assigned(FOnButton) and (I >= 0) and (I <= High(FCells)) then FOnButton(Self, FCells[I].Def, FModel.Current);
end;

procedure TaRowsView.SimulateEdit(AIndex: Integer; const AValue: string);
begin
  if FLiveCtrls[AIndex] is TaEdit then TaEdit(FLiveCtrls[AIndex]).Text := AValue
  else if FLiveCtrls[AIndex] is TCheckBox then TCheckBox(FLiveCtrls[AIndex]).Checked := AValue = '1';
  { programsko postavljanje teksta ne javlja OnChange kao tipkanje, pa se javi izravno }
  LiveChanged(FLiveCtrls[AIndex]);
end;

{ polje izvora koje popunjava celija: iz lovmap (izvor=kontrola;...), inace njezino polje }
function LovFieldFor(ADef: TaControlDef): string;
var
  P: TStringList;
  I: Integer;
begin
  Result := ADef.ControlSource;
  P := TStringList.Create;
  try
    P.Delimiter := ';'; P.StrictDelimiter := True;
    P.DelimitedText := ADef.GetX('lovmap');
    for I := 0 to P.Count - 1 do
      if SameText(Trim(P.ValueFromIndex[I]), ADef.Name) then Exit(Trim(P.Names[I]));
  finally
    P.Free;
  end;
end;

{ lovvalidate: vrijednost upisana u red mora postojati u popisu }
function TaRowsView.LovCheck: string;
var
  I: Integer;
  D: TaControlDef;
  Ds: TDataSet;
  Err, Fld, V: string;
begin
  Result := '';
  for I := 0 to High(FCells) do
  begin
    D := FCells[I].Def;
    if (D = nil) or (D.GetX('lov') = '') or (D.GetX('lovvalidate') <> '1') or (D.ControlSource = '') then Continue;
    if not FSource.HasPending(D.ControlSource) then Continue;
    V := Trim(FSource.Pending(D.ControlSource));
    if V = '' then Continue;
    Ds := OpenSource(FSource.Db, D.GetX('lov'), nil, nil, Err);
    if Ds = nil then Exit('Popis vrijednosti: ' + Err);
    try
      Fld := LovFieldFor(D);
      if Ds.FindField(Fld) = nil then Exit('Popis vrijednosti nema polje ' + Fld);
      if not Ds.Locate(Fld, V, [loCaseInsensitive]) then
        Exit(D.ControlSource + ': vrijednosti "' + V + '" nema u popisu');
    finally
      Ds.Free;
    end;
  end;
end;

function TaRowsView.ShowLov(ACell: Integer): Boolean;
var
  D: TaControlDef;
  Ds: TDataSet;
  Err: string;
  Parts: TStringList;
  I, J: Integer;
  F: TField;
begin
  Result := False;
  if (ACell < 0) or (ACell > High(FCells)) or (FSource = nil) then Exit;
  D := FCells[ACell].Def;
  if (D = nil) or (D.GetX('lov') = '') or (not FSource.CanEdit) then Exit;
  Result := True;
  Ds := OpenSource(FSource.Db, D.GetX('lov'), nil, nil, Err);
  if Ds = nil then begin FError := 'Popis vrijednosti: ' + Err; Exit; end;
  Parts := TStringList.Create;
  try
    if not PickLov(nil, Ds, D.Name, RawValue(ACell)) then Exit;
    Parts.Delimiter := ';'; Parts.StrictDelimiter := True;
    Parts.DelimitedText := D.GetX('lovmap');
    if Parts.Count = 0 then Parts.Add(D.ControlSource + '=' + D.Name);
    for I := 0 to Parts.Count - 1 do
    begin
      F := Ds.FindField(Trim(Parts.Names[I]));
      if F = nil then Continue;
      for J := 0 to High(FCells) do
        if (FCells[J].Def <> nil) and SameText(FCells[J].Def.Name, Trim(Parts.ValueFromIndex[I])) then
        begin
          SimulateEdit(J, F.AsString);
          Break;
        end;
    end;
  finally
    Parts.Free;
    Ds.Free;
  end;
end;

function TaRowsView.CommitRow: Boolean;
var
  Key: string;
  Idx: Integer;
  WasNew: Boolean;
begin
  FError := '';
  if not FModel.Dirty then Exit(True);
  FError := LovCheck;
  if FError <> '' then Exit(False);
  WasNew := FSource.IsNew;
  if not FSource.Post then
  begin
    FError := FSource.Error;
    Exit(False);
  end;
  Key := FSource.PostedKey;
  FModel.RecordPosted;
  FSource.Fetch(FModel.Offset, FModel.ViewRows + 40);
  if WasNew then
  begin
    FModel.SetRecordCount(FSource.Count);
    Idx := FSource.IndexOfKey(Key);
    if Idx >= 0 then FModel.MoveTo(Idx, WasNew);
  end;
  FLiveRow := -1;
  SyncBar;
  PlaceLive;
  Invalidate;
  Result := True;
  if Assigned(FOnDataChange) then FOnDataChange(Self);
end;

procedure TaRowsView.CancelRow;
begin
  FSource.Cancel;
  FModel.MarkClean;
  FLiveRow := -1;
  PlaceLive;
  Invalidate;
end;

function TaRowsView.GoToRow(ARow: Integer): Boolean;
var
  Np: Boolean;
  Key: string;
  Idx: Integer;
  ToNew: Boolean;
begin
  Result := True;
  if ARow = FModel.Current then Exit;
  if FModel.Dirty then
  begin
    { cilj je zapis, ne pozicija: spremanje moze promijeniti poredak (sortiranje po izmijenjenom polju) }
    ToNew := FModel.IsNewRow(ARow);
    Key := '';
    if not ToNew then Key := FSource.KeyOf(ARow);
    if not CommitRow then Exit(False);
    if ToNew then ARow := FModel.NewRow
    else if Key <> '' then
    begin
      Idx := FSource.IndexOfKey(Key);
      if Idx >= 0 then ARow := Idx;
    end;
    if ARow = FModel.Current then begin FillLive; Exit; end;
  end;
  FModel.MoveTo(ARow, Np);
  FSource.Fetch(FModel.Offset, FModel.ViewRows + 40);
  FLiveRow := -1;
  SyncBar;
  PlaceLive;
  Invalidate;
  if Assigned(FOnRowChange) then FOnRowChange(Self);
end;

function TaRowsView.DeleteCurrent: Boolean;
begin
  Result := False;
  FError := '';
  if FModel.IsNewRow(FModel.Current) then Exit;
  if FSource.Editing then CancelRow;
  if not FSource.Delete(FModel.Current) then begin FError := FSource.Error; Exit; end;
  FModel.RecordDeleted;
  FSource.Fetch(FModel.Offset, FModel.ViewRows + 40);
  FLiveRow := -1;
  SyncBar;
  PlaceLive;
  Invalidate;
  Result := True;
  if Assigned(FOnDataChange) then FOnDataChange(Self);
end;

function TaRowsView.RowAtY(Y: Integer): Integer;
begin
  Result := FModel.Offset + Y div FRowHeight;
  if Result >= FModel.RowCount then Result := -1;
end;

procedure TaRowsView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R, I: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  R := RowAtY(Y);
  if R < 0 then Exit;
  { klik na crtani gumb: red postaje trenutni, a zatim se izvrsi radnja }
  if GoToRow(R) then
    for I := 0 to High(FCells) do
      if (FCells[I].Kind <> 'button') and (X >= FSelW + FCells[I].X) and (X < FSelW + FCells[I].X + FCells[I].W) then
        FocusCell(I);
  if FModel.Current = R then
    for I := 0 to High(FCells) do
      if (FCells[I].Kind = 'button') and (X >= FSelW + FCells[I].X) and (X < FSelW + FCells[I].X + FCells[I].W) and
         (Y - (R - FModel.Offset) * FRowHeight >= FCells[I].Y) and
         (Y - (R - FModel.Offset) * FRowHeight < FCells[I].Y + FCells[I].H) then
        if Assigned(FOnButton) then FOnButton(Self, FCells[I].Def, R);
end;

procedure TaRowsView.ClickAt(X, Y: Integer);
begin
  MouseDown(mbLeft, [], X, Y);
end;

function TaRowsView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  if WheelDelta > 0 then FModel.ScrollBy(-3) else FModel.ScrollBy(3);
  FSource.Fetch(FModel.Offset, FModel.ViewRows + 40);
  SyncBar;
  PlaceLive;
  Invalidate;
  Result := True;
end;

end.
