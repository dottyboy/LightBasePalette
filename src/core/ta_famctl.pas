unit ta_famctl;
{ Veza izvrsitelja formi (TaFormRunner) i obitelji kontrola. Za vrste TextBox, CheckBox, Button, ToggleButton, Label,
  Hyperlink, MemoBox, RichText, OptionGroup i ListBox stvara komponente obitelji (TaEdit, TaCheck, TaButton, TaLabel,
  TaMemo, TaChoice, TaList) umjesto starih LCL kontrola, a varijanta iz definicije ("variant") radi i u izvrsavanju.
  Kuke u ta_controls (DefOf, ReadControlValue, WriteControlValue, IsBoundControl) znaju za domacine pa ostatak
  izvrsitelja radi bez promjene. Isklucivanje: RunnerUsesFamilies := False (stare kontrole). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, StdCtrls, Menus, ta_formdef, ta_family;

var
  RunnerUsesFamilies: Boolean = True;

{ domacin kojem kontrola (ili njezina unutarnja kontrola) pripada; za obicnu kontrolu ona sama }
function HostOf(C: TControl): TControl;
{ kvacica, prekidac ili toggle gumb (stare ili nove) }
function IsCheckLike(C: TControl): Boolean;
{ jednoredno tekstno polje (staro ili novo, bez padajuceg popisa) }
function IsPlainEdit(C: TControl): Boolean;
{ izbor ili popis s kljucevima (nove obitelji Choice i List) }
function IsKeyedFamily(C: TControl): Boolean;
{ vrijednost kontrole je kljuc stavke (ne prikazani natpis) }
function FamilyHasKeys(C: TControl): Boolean;
{ postavlja samo za citanje / onemogucuje kontrolu obitelji; False ako kontrola nije domacin }
function FamilyLock(C: TControl): Boolean;
{ unutarnja kontrola domacina (na njoj se vide boje i font), inace sama kontrola }
function StyleTarget(C: TControl): TControl;
{ stavke izbora i popisa kao "kljuc=natpis" }
procedure FamilySetItems(C: TControl; AItems: TStrings; AKeyed: Boolean);
function FamilyAddress(C: TControl): string;
procedure FamilySetAddress(C: TControl; const AAddress: string);
procedure FamilySetCaption(C: TControl; const ACaption: string);
procedure FamilySetText(C: TControl; const AText: string);
procedure ApplyFamilyStyle(C: TControl; D: TaControlDef);
{ 'Image', 'Chart' ili 'Barcode' za domacina tih obitelji, inace prazno }
function FamilyKindOf(C: TControl): string;
{ Panel i Pages primaju kontrole (container=naziv) }
function FamilyIsContainer(C: TControl): Boolean;
function FamilyActivePage(C: TControl): Integer;
{ kontrola je na stranici obitelji Pages koja nije aktivna }
function FamilyPageHidden(C: TControl): Boolean;
procedure FamilyShowPages(C: TControl);
{ slika iz polja zapisa u obitelji Image (nil je brise) }
procedure FamilySetPicture(C: TControl; APic: TPicture);
{ podaci grafikona koje je izvrsitelj procitao iz izvora }
procedure FamilySetChartData(C: TControl; ALabels: TStrings; const AValues: array of Double);
{ vrijednost koja se kodira u obitelji Barcode }
procedure FamilySetBarcode(C: TControl; const AValue: string);
function FamilyBarcodeValue(C: TControl): string;
{ dvoklik i izbornik moraju raditi i na unutarnjim kontrolama koje prekrivaju domacina }
procedure FamilySetDblClick(C: TControl; AHandler: TNotifyEvent);
procedure FamilySetPopup(C: TControl; AMenu: TPopupMenu);

type
  TFamilyWireKind = (fwNone, fwInput, fwButton, fwHyperlink, fwKeyed);

{ prikljucuje dogadaje izvrsitelja na domacina i kaze sto je to za kontrola }
function FamilyWire(C: TControl; AChanged, AClick, AHyper, ALov: TNotifyEvent): TFamilyWireKind;
{ domacin sam javlja klik (gumb, poveznica) pa izvrsitelj ne dodaje OnClick radnje }
function FamilyOwnsClick(C: TControl): Boolean;

{ komponenta obitelji za definiciju ili nil (vrsta nije prebacena ili je prebacivanje iskljuceno) }
function FamilyControlFor(AOwner: TComponent; AParent: TWinControl; D: TaControlDef; ADesign: Boolean = False): TControl;
{ dizajner formi: dogadaji misa unutarnjih kontrola domacina idu dizajneru kao da su na domacinu (Sender = domacin) }
procedure FamilyHookMouse(C: TControl; ADown: TMouseEvent; AMove: TMouseMoveEvent; AUp: TMouseEvent);

implementation

uses
  ta_controls, ta_propclass, ta_edit, ta_ownedit, ta_owncombo, ta_owndate, ta_ownspin, ta_ownlov, ta_ownmemo, ta_ownrich, ta_ownlist, ta_owntree, ta_owncalendar, ta_owngrid, ta_check, ta_button, ta_label, ta_memo, ta_choice, ta_list, ta_calendar, ta_progress,
  ta_image, ta_chartbox, ta_barcodebox, ta_filestore, ta_panel, ta_pages;

type
  TCtlCrack = class(TControl)
  public
    property OnDblClick;
    property PopupMenu;
  end;

type
  TPagesWatcher = class
    procedure Switched(Sender: TObject);
  end;

var
  PagesWatcher: TPagesWatcher;

function FamilyIsContainer(C: TControl): Boolean;
begin
  Result := (FamilyKindOf(C) = 'Panel') or (FamilyKindOf(C) = 'Pages');
end;

function FamilyActivePage(C: TControl): Integer;
begin
  if C is ta_pages.TaPages then Result := ta_pages.TaPages(C).ActivePage else Result := 0;
end;

function FamilyPageHidden(C: TControl): Boolean;
begin
  Result := (C.Parent is ta_pages.TaPages) and (DefOf(C) <> nil) and
    (StrToIntDef(DefOf(C).GetX('page'), 0) <> ta_pages.TaPages(C.Parent).ActivePage);
end;

procedure FamilyShowPages(C: TControl);
var
  I: Integer;
  Ch: TControl;
  Nm: string;
begin
  if not (C is ta_pages.TaPages) or (DefOf(C) = nil) then Exit;
  Nm := DefOf(C).Name;
  for I := 0 to TWinControl(C).ControlCount - 1 do
  begin
    Ch := TWinControl(C).Controls[I];
    if (DefOf(Ch) <> nil) and SameText(DefOf(Ch).GetX('container'), Nm) then Ch.Visible := not FamilyPageHidden(Ch);
  end;
end;

procedure TPagesWatcher.Switched(Sender: TObject);
begin
  if Sender is TControl then FamilyShowPages(TControl(Sender));
end;

function FamilyKindOf(C: TControl): string;
begin
  Result := '';
  if C is ta_image.TaImage then Result := 'Image'
  else if C is ta_chartbox.TaChart then Result := 'Chart'
  else if C is ta_barcodebox.TaBarcode then Result := 'Barcode'
  else if C is ta_panel.TaPanel then Result := 'Panel'
  else if C is ta_pages.TaPages then Result := 'Pages';
end;

procedure FamilySetPicture(C: TControl; APic: TPicture);
begin
  if C is ta_image.TaImage then ta_image.TaImage(C).SetPicture(APic);
end;

procedure FamilySetChartData(C: TControl; ALabels: TStrings; const AValues: array of Double);
begin
  if not (C is ta_chartbox.TaChart) then Exit;
  with ta_chartbox.TaChart(C) do
    if Engine is TaChartDataEngine then TaChartDataEngine(Engine).SetData(ALabels, AValues);
end;

procedure FamilySetBarcode(C: TControl; const AValue: string);
begin
  if C is ta_barcodebox.TaBarcode then ta_barcodebox.TaBarcode(C).Text := AValue;
end;

function FamilyBarcodeValue(C: TControl): string;
begin
  Result := '';
  if C is ta_barcodebox.TaBarcode then Result := ta_barcodebox.TaBarcode(C).Text;
end;

procedure DblRecursive(C: TControl; AHandler: TNotifyEvent);
var
  I: Integer;
begin
  TCtlCrack(C).OnDblClick := AHandler;
  if C is TWinControl then
    for I := 0 to TWinControl(C).ControlCount - 1 do DblRecursive(TWinControl(C).Controls[I], AHandler);
end;

procedure FamilySetDblClick(C: TControl; AHandler: TNotifyEvent);
begin
  TCtlCrack(C).OnDblClick := AHandler;
  if (C is TaFamilyHost) and (TaFamilyHost(C).Engine <> nil) and (TaFamilyHost(C).Engine.Inner <> nil) then
    DblRecursive(TaFamilyHost(C).Engine.Inner, AHandler);
end;

procedure PopRecursive(C: TControl; AMenu: TPopupMenu);
var
  I: Integer;
begin
  TCtlCrack(C).PopupMenu := AMenu;
  if C is TWinControl then
    for I := 0 to TWinControl(C).ControlCount - 1 do PopRecursive(TWinControl(C).Controls[I], AMenu);
end;

procedure FamilySetPopup(C: TControl; AMenu: TPopupMenu);
begin
  TCtlCrack(C).PopupMenu := AMenu;
  if (C is TaFamilyHost) and (TaFamilyHost(C).Engine <> nil) and (TaFamilyHost(C).Engine.Inner <> nil) then
    PopRecursive(TaFamilyHost(C).Engine.Inner, AMenu);
end;

{ Rectangle i Line: isti izgled kao stare kontrole (okvir u boji teksta i ispuna boje pozadine; crta je puni pravokutnik) }
procedure LegacyShape(H: ta_image.TaImage; D: TaControlDef);
var
  Fc, Bc: string;
begin
  Fc := D.GetX('foreColor');
  if Fc = '' then Fc := '#000000';
  Bc := D.GetX('backColor');
  H.Variant := imShape;
  with H.Options do
  begin
    Shape := ishRectangle;
    LineColor := Fc;
    if D.Kind = 'Line' then
    begin
      FillColor := Fc;
      LineWidth := 1;
    end
    else
    begin
      if Bc <> '' then FillColor := Bc else FillColor := 'none';
      LineWidth := StrToIntDef(D.GetX('borderWidth'), 1);
    end;
  end;
  H.Options := H.Options;
end;

{ staticka slika u definiciji ("picture": base64 ili file:veza) }
procedure LoadDefPicture(H: TaFamilyHost; D: TaControlDef);
var
  K, Fn: string;
  Pic: TPicture;
begin
  K := D.GetX('picture');
  if (K = '') or not (H is ta_image.TaImage) or (ta_image.TaImage(H).Variant <> imPicture) then Exit;
  Pic := TPicture.Create;
  try
    if Copy(K, 1, 5) = 'file:' then
    begin
      Fn := ResolveFileLink(ActiveStoreDb, Copy(K, 6, MaxInt));
      if (Fn <> '') and FileExists(Fn) then
        try Pic.LoadFromFile(Fn); except end;
    end
    else LoadPictureFromBase64(Pic, K);
    if (Pic.Graphic <> nil) and not Pic.Graphic.Empty then ta_image.TaImage(H).SetPicture(Pic);
  finally
    Pic.Free;
  end;
end;

function HostOf(C: TControl): TControl;
var
  P: TControl;
begin
  Result := C;
  P := C;
  while P <> nil do
  begin
    if P is TaFamilyHost then Exit(P);
    P := P.Parent;
  end;
end;

function IsCheckLike(C: TControl): Boolean;
begin
  Result := (C is TCheckBox) or (C is TToggleBox) or (C is TaCheck) or ((C is TaButton) and (TaButton(C).Variant = bvToggle));
end;

function IsPlainEdit(C: TControl): Boolean;
begin
  Result := (C is TEdit) or ((C is TaEdit) and (TaEdit(C).Variant in [evText, evPassword, evCurrency]));
end;

function IsKeyedFamily(C: TControl): Boolean;
begin
  Result := (C is TaChoice) or (C is TaList) or ((C is TaEdit) and (TaEdit(C).Variant in [evCombo, evDroplist]));
end;

function FamilyHasKeys(C: TControl): Boolean;
begin
  Result := (C is TaChoice) or (C is TaList) or
    ((C is TaEdit) and (TaEdit(C).Variant in [evCombo, evDroplist]) and (TaEdit(C).Options is TaComboOptions) and TaComboOptions(TaEdit(C).Options).Keyed);
end;

function FamilyLock(C: TControl): Boolean;
begin
  Result := True;
  { kao stare kontrole: tekstna polja postaju samo za citanje, ostalo se onemogucuje }
  if C is TaEdit then TaEdit(C).ReadOnly := True
  else if C is TaMemo then TaMemo(C).ReadOnly := True
  else if C is TaFamilyHost then C.Enabled := False
  else Result := False;
end;

function StyleTarget(C: TControl): TControl;
begin
  Result := C;
  if (C is TaFamilyHost) and (TaFamilyHost(C).Engine <> nil) and (TaFamilyHost(C).Engine.Inner <> nil) then
    Result := TaFamilyHost(C).Engine.Inner;
end;

procedure FamilySetItems(C: TControl; AItems: TStrings; AKeyed: Boolean);
begin
  if C is TaChoice then TaChoice(C).Items.Assign(AItems)
  else if C is TaList then TaList(C).Items.Assign(AItems)
  else if (C is TaEdit) and (TaEdit(C).Options is TaComboOptions) then
  begin
    { najprije nacin tumacenja stavki, zatim stavke }
    TaComboOptions(TaEdit(C).Options).Keyed := AKeyed;
    TaComboOptions(TaEdit(C).Options).Search := AKeyed and (DefOf(C) <> nil) and (DefOf(C).GetX('search') = '1');
    TaEdit(C).Options := TaEdit(C).Options;
    TaEdit(C).Items.Assign(AItems);
  end;
end;

function FamilyAddress(C: TControl): string;
begin
  Result := '';
  if (C is TaLabel) and (TaLabel(C).Options is TaHyperlinkOptions) then Result := TaHyperlinkOptions(TaLabel(C).Options).Address;
end;

procedure FamilySetAddress(C: TControl; const AAddress: string);
begin
  if (C is TaLabel) and (TaLabel(C).Options is TaHyperlinkOptions) then TaHyperlinkOptions(TaLabel(C).Options).Address := AAddress;
end;

procedure FamilySetCaption(C: TControl; const ACaption: string);
begin
  if C is TaLabel then TaLabel(C).Caption := ACaption
  else if C is TaButton then TaButton(C).Caption := ACaption
  else C.Caption := ACaption;
end;

procedure FamilySetText(C: TControl; const AText: string);
begin
  if C is TaEdit then TaEdit(C).Text := AText
  else if C is TaLabel then TaLabel(C).Caption := AText
  else if C is TaCheck then TaCheck(C).Checked := (AText = '1') or SameText(AText, 'true')
  else if C is TaMemo then TaMemo(C).Text := AText;
end;

{ ---------------- kuke ---------------- }

function HookDef(C: TControl): TaControlDef;
begin
  if C is TaFamilyHost then Result := TaFamilyHost(C).Def else Result := nil;
end;

function HookRead(C: TControl; out S: string): Boolean;
begin
  Result := True;
  S := '';
  if C is TaEdit then S := TaEdit(C).Text
  else if C is TaCheck then begin if TaCheck(C).Checked then S := '1' else S := '0'; end
  else if C is TaMemo then S := TaMemo(C).Text
  else if C is TaChoice then S := TaChoice(C).Selected
  else if C is TaList then S := TaList(C).Selected
  else if C is TaCalendar then S := TaCalendar(C).Text
  else if (C is TaButton) and (TaButton(C).Variant = bvToggle) then begin if TaButton(C).Checked then S := '1' else S := '0'; end
  else if C is TaProgress then S := FloatToStr(TaProgress(C).Value)
  else Result := False;
end;

function HookWrite(C: TControl; const S: string): Boolean;
begin
  Result := True;
  if C is TaEdit then TaEdit(C).Text := S
  else if C is TaCheck then TaCheck(C).Checked := (S = '1') or SameText(S, 'true')
  else if C is TaMemo then TaMemo(C).Text := S
  else if C is TaChoice then TaChoice(C).Select(S)
  else if C is TaList then TaList(C).Select(S)
  else if C is TaCalendar then TaCalendar(C).Text := S
  else if (C is TaButton) and (TaButton(C).Variant = bvToggle) then TaButton(C).Checked := (S = '1') or SameText(S, 'true')
  else if C is TaProgress then TaProgress(C).Value := StrToFloatDef(S, 0)
  else Result := False;
end;

function HookBound(C: TControl): Boolean;
begin
  Result := (C is TaEdit) or (C is TaCheck) or (C is TaMemo) or (C is TaChoice) or (C is TaList) or (C is TaCalendar) or
    ((C is TaButton) and (TaButton(C).Variant = bvToggle));
end;

function FamilyOwnsClick(C: TControl): Boolean;
begin
  Result := (C is TaButton) or ((C is TaLabel) and (TaLabel(C).Variant = lvHyperlink));
end;

function FamilyWire(C: TControl; AChanged, AClick, AHyper, ALov: TNotifyEvent): TFamilyWireKind;
begin
  Result := fwNone;
  if C is TaButton then
  begin
    TaButton(C).OnClick := AClick;
    if TaButton(C).Variant = bvToggle then TaButton(C).OnChange := AChanged;
    Result := fwButton;
  end
  else if C is TaLabel then
  begin
    if TaLabel(C).Variant = lvHyperlink then
    begin
      TaLabel(C).OnClick := AHyper;
      Result := fwHyperlink;
    end;
  end
  else if (C is TaChoice) or (C is TaList) then
  begin
    TaFamilyHost(C).OnChange := AChanged;
    Result := fwKeyed;
  end
  else if C is TaEdit then
  begin
    TaEdit(C).OnChange := AChanged;
    if TaEdit(C).Variant = evLov then TaEdit(C).OnLov := ALov;
    if TaEdit(C).Variant in [evCombo, evDroplist] then Result := fwKeyed else Result := fwInput;
  end
  else if (C is TaCheck) or (C is TaMemo) or (C is TaCalendar) then
  begin
    TaFamilyHost(C).OnChange := AChanged;
    Result := fwInput;
  end;
end;

{ ---------------- stvaranje ---------------- }

procedure ApplyFamilyStyle(C: TControl; D: TaControlDef);
var
  Fc, Bc: TColor;
  Fn: string;
  Sz, W: Integer;
  T: TControl;
  Bmp: TBitmap;
begin
  Fc := HexToColor(D.GetX('foreColor'), clDefault);
  Bc := HexToColor(D.GetX('backColor'), clDefault);
  Fn := D.GetX('fontName');
  Sz := StrToIntDef(D.GetX('fontSize'), 0);
  if Fn <> '' then C.Font.Name := Fn;
  if Sz > 0 then C.Font.Size := Sz;
  if D.Bold then C.Font.Style := C.Font.Style + [fsBold] else C.Font.Style := C.Font.Style - [fsBold];
  if D.GetX('italic') = '1' then C.Font.Style := C.Font.Style + [fsItalic] else C.Font.Style := C.Font.Style - [fsItalic];
  if (Fc <> clDefault) and not ((C is TaLabel) and (TaLabel(C).Variant = lvHyperlink)) then C.Font.Color := Fc;
  T := StyleTarget(C);
  if (Bc <> clDefault) and not (C is TaButton) then
  begin
    C.Color := Bc;
    T.Color := Bc;
  end;
  if D.GetX('tip') <> '' then begin C.Hint := D.GetX('tip'); C.ShowHint := True; end
  else C.ShowHint := False;
  W := D.Width;
  { stare kvacice su se same sirile do natpisa; ovdje se sirina povecava ako natpis ne stane }
  if (C is TaCheck) and (TaCheck(C).Variant <> cvSwitch) and (D.Caption <> '') then
  begin
    Bmp := TBitmap.Create;
    try
      Bmp.Canvas.Font.Assign(C.Font);
      if Bmp.Canvas.TextWidth(D.Caption) + 26 > W then W := Bmp.Canvas.TextWidth(D.Caption) + 26;
    finally
      Bmp.Free;
    end;
  end;
  C.SetBounds(D.Left, D.Top, W, D.Height);
end;

type
  { prosljedivac dogadaja misa: unutarnja kontrola -> dizajner, s domacinom kao posiljateljem }
  TMouseProxy = class(TComponent)
  public
    Host: TControl;
    FDown, FUp: TMouseEvent;
    FMove: TMouseMoveEvent;
    function ToHost(Sender: TObject; X, Y: Integer): TPoint;
    procedure Down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Move(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Up(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  end;

  TCtlHack = class(TControl);

function TMouseProxy.ToHost(Sender: TObject; X, Y: Integer): TPoint;
begin
  Result := Host.ScreenToClient(TControl(Sender).ClientToScreen(Point(X, Y)));
end;

procedure TMouseProxy.Down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  P := ToHost(Sender, X, Y);
  if Assigned(FDown) then FDown(Host, Button, Shift, P.X, P.Y);
end;

procedure TMouseProxy.Move(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  P := ToHost(Sender, X, Y);
  if Assigned(FMove) then FMove(Host, Shift, P.X, P.Y);
end;

procedure TMouseProxy.Up(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  P := ToHost(Sender, X, Y);
  if Assigned(FUp) then FUp(Host, Button, Shift, P.X, P.Y);
end;

procedure HookRecursive(C: TControl; AProxy: TMouseProxy);
var
  I: Integer;
begin
  TCtlHack(C).OnMouseDown := @AProxy.Down;
  TCtlHack(C).OnMouseMove := @AProxy.Move;
  TCtlHack(C).OnMouseUp := @AProxy.Up;
  if C is TWinControl then
    for I := 0 to TWinControl(C).ControlCount - 1 do HookRecursive(TWinControl(C).Controls[I], AProxy);
end;

procedure FamilyHookMouse(C: TControl; ADown: TMouseEvent; AMove: TMouseMoveEvent; AUp: TMouseEvent);
var
  P: TMouseProxy;
begin
  { sam domacin dobiva iste dogadaje (hvatanje misa pri povlacenju) }
  TCtlHack(C).OnMouseDown := ADown;
  TCtlHack(C).OnMouseMove := AMove;
  TCtlHack(C).OnMouseUp := AUp;
  if not (C is TaFamilyHost) or (TaFamilyHost(C).Engine = nil) or (TaFamilyHost(C).Engine.Inner = nil) then Exit;
  P := TMouseProxy.Create(C);
  P.Host := C;
  P.FDown := ADown; P.FMove := AMove; P.FUp := AUp;
  HookRecursive(TaFamilyHost(C).Engine.Inner, P);
end;

{ pregled u dizajneru: polje se vidi kao [naziv], popisi imaju primjere, sve je samo za citanje }
procedure DesignPreview(H: TaFamilyHost; D: TaControlDef);
var
  Shown: string;
  L: TStringList;
  S: string;
begin
  if D.ControlSource <> '' then Shown := '[' + D.ControlSource + ']' else Shown := '';
  if H is TaEdit then
  begin
    TaEdit(H).Text := Shown;
    if TaEdit(H).Variant in [evText, evPassword, evCurrency, evDate, evSpin, evLov] then TaEdit(H).ReadOnly := True;
  end
  else if H is TaMemo then
  begin
    if TaMemo(H).Variant <> mvRich then TaMemo(H).Text := Shown;
    TaMemo(H).ReadOnly := True;
  end
  else if H is TaLabel then
  begin
    if (TaLabel(H).Variant = lvHyperlink) and (D.Caption = '') then TaLabel(H).Caption := Shown;
  end
  else if (H is TaChoice) or (H is TaList) then
  begin
    L := TStringList.Create;
    try
      S := D.GetX('items');
      if (S = '') and (LowerCase(Copy(Trim(D.RowSource), 1, 5)) = 'list:') then S := Copy(Trim(D.RowSource), 6, MaxInt);
      if (S = '') and (Trim(D.RowSource) <> '') and (Pos('SELECT', UpperCase(TrimLeft(D.RowSource))) <> 1) and
         (Pos('sql:', LowerCase(TrimLeft(D.RowSource))) <> 1) and (Pos('fgl:', LowerCase(TrimLeft(D.RowSource))) <> 1) then
        S := Trim(D.RowSource);
      if S <> '' then
      begin
        L.Delimiter := ';';
        L.StrictDelimiter := True;
        L.DelimitedText := S;
      end
      else
      begin
        L.Add('Stavka 1'); L.Add('Stavka 2'); L.Add('Stavka 3');
      end;
      if H is TaChoice then TaChoice(H).Items.Assign(L) else TaList(H).Items.Assign(L);
    finally
      L.Free;
    end;
  end
  else if H is TaProgress then TaProgress(H).Value := 40
  else if H is ta_chartbox.TaChart then
  begin
    if (ta_chartbox.TaChart(H).Items.Count = 0) and (D.RowSource = '') then
      ta_chartbox.TaChart(H).Items.Text := 'A=4' + LineEnding + 'B=7' + LineEnding + 'C=3' + LineEnding + 'D=6';
  end
  else if H is ta_barcodebox.TaBarcode then
  begin
    if ta_barcodebox.TaBarcode(H).Variant in [bvEan13, bvEan8, bvItf] then
      ta_barcodebox.TaBarcode(H).Text := '4006381333931'
    else
      ta_barcodebox.TaBarcode(H).Text := 'TyphAccess';
  end;
end;

function FamilyControlFor(AOwner: TComponent; AParent: TWinControl; D: TaControlDef; ADesign: Boolean): TControl;
var
  Def: TaControlDef;
  Own: Boolean;
  K: string;
  H: TaFamilyHost;
begin
  Result := nil;
  if not RunnerUsesFamilies then Exit;
  K := D.Kind;
  if not ((K = 'TextBox') or (K = 'ComboBox') or (K = 'CheckBox') or (K = 'Button') or (K = 'ToggleButton') or (K = 'Label') or (K = 'Hyperlink') or
          (K = 'MemoBox') or (K = 'RichText') or (K = 'OptionGroup') or (K = 'ListBox') or (K = 'Calendar') or (K = 'Progress') or
          (K = 'Image') or (K = 'Chart') or (K = 'Barcode') or (K = 'Rectangle') or (K = 'Line') or (K = 'Panel') or (K = 'Pages')) then Exit;
  Def := D;
  Own := False;
  { naziv koji nije ispravan identifikator ostaje prazan (kao kod starih kontrola) }
  if (not IsValidIdent(D.Name)) or ((K = 'TextBox') and (D.GetX('lov') <> '') and (D.GetX('variant') = '')) or
     ((K = 'ComboBox') and (D.GetX('variant') = '')) then
  begin
    Def := CloneControl(D);
    Own := True;
    if not IsValidIdent(D.Name) then Def.Name := '';
    if (K = 'TextBox') and (D.GetX('lov') <> '') and (D.GetX('variant') = '') then Def.SetX('variant', 'lov');
    { ComboBox s popisom: EditFromDef ga i bez varijante pretvara u combo, ali ne znamo je li popis kljucan dok se ne napuni }
    if (K = 'ComboBox') and (D.GetX('variant') = '') then Def.SetX('variant', 'combo');
  end;
  try
    if (K = 'TextBox') or (K = 'ComboBox') then H := EditFromDef(Def, AOwner)
    else if K = 'CheckBox' then H := CheckFromDef(Def, AOwner)
    else if (K = 'Button') or (K = 'ToggleButton') then H := ButtonFromDef(Def, AOwner)
    else if (K = 'Label') or (K = 'Hyperlink') then H := LabelFromDef(Def, AOwner)
    else if (K = 'MemoBox') or (K = 'RichText') then H := MemoFromDef(Def, AOwner)
    else if K = 'OptionGroup' then H := ChoiceFromDef(Def, AOwner)
    else if K = 'ListBox' then H := ListFromDef(Def, AOwner)
    else if K = 'Calendar' then H := CalendarFromDef(Def, AOwner)
    else if (K = 'Image') or (K = 'Rectangle') or (K = 'Line') then H := ImageFromDef(Def, AOwner)
    else if K = 'Panel' then H := PanelFromDef(Def, AOwner)
    else if K = 'Pages' then H := PagesFromDef(Def, AOwner)
    else if K = 'Chart' then H := ChartFromDef(Def, AOwner)
    else if K = 'Barcode' then H := BarcodeFromDef(Def, AOwner)
    else H := ProgressFromDef(Def, AOwner);
  finally
    if Own then Def.Free;
  end;
  H.Parent := AParent;
  H.Def := D;
  if (K = 'Rectangle') or (K = 'Line') then LegacyShape(ta_image.TaImage(H), D);
  if K = 'Pages' then H.OnChange := @PagesWatcher.Switched;
  if H is TaLabel then TaLabel(H).OpenOnClick := False;
  ApplyFamilyStyle(H, D);
  LoadDefPicture(H, D);
  if ADesign then DesignPreview(H, D);
  Result := H;
end;

initialization
  PagesWatcher := TPagesWatcher.Create;
  FamilyDefHook := @HookDef;
  FamilyReadHook := @HookRead;
  FamilyWriteHook := @HookWrite;
  FamilyBoundHook := @HookBound;

end.
