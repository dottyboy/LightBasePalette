unit ta_anchoreditor;
{ Uredjivac sidrenja i rasporeda kontrole (po uzoru na Lazarusov "Anchor Editor"), za dizajner formi TyphAccessa.
  Jedan dijalog uredjuje sve sto je prije trebalo tipkati: Dock, sidra Lijevo/Gore/Desno/Dolje (uz rub forme ili uz
  susjednu kontrolu, s odabirom strane), razmak od rubova (BorderSpacing, posebno po stranama ili isti sa svih strana)
  i gotove obrasce. Pregled lijevo crta formu, susjede i kontrolu u mjerilu, a strelice pokazuju kamo je koja strana
  vezana; mijenja se uzivo dok mijenjas postavke.
  Vrijednosti u definiciji kontrole ostaju iste kao i do sada (anchors, dock, space, asl/ast/asr/asb), pa stare
  forme rade bez promjene. Funkcija ne zna za dizajner: prima definiciju forme i kontrole, vraca nove vrijednosti. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Controls, Forms, StdCtrls, ExtCtrls, Graphics, Spin, ta_formdef, ta_controls;

type
  { vrijednosti koje dijalog uredjuje, u zapisu definicije }
  TaLayoutValues = record
    Anchors: string;                  { slova L, T, R, B ('' = zadano LT) }
    Dock: string;                     { none, top, bottom, left, right, client }
    Spacing: string;                  { "l,t,r,b" ili '' }
    Side: array[0..3] of string;      { asl, ast, asr, asb: "" ili "Naziv" ili "Naziv:strana" }
  end;

  TaLayoutEditor = class
  private
    FForm: TForm;
    FFormDef: TaFormDef;
    FDef: TaControlDef;
    FPreview: TPaintBox;
    FDock: TComboBox;
    FUse: array[0..3] of TCheckBox;
    FRef, FSideRef: array[0..3] of TComboBox;
    FSpace: array[0..3] of TSpinEdit;
    FAround: TSpinEdit;
    FNames: TStringList;              { 0 = forma, ostalo su susjedi }
    FLoading: Boolean;
    procedure Build(AOwner: TComponent);
    procedure Changed(Sender: TObject);
    procedure DockChanged(Sender: TObject);
    procedure PreviewPaint(Sender: TObject);
    procedure PresetClick(Sender: TObject);
    procedure AroundClick(Sender: TObject);
    procedure FillSideCombo(ASide: Integer);
    procedure SetValues(const V: TaLayoutValues);
  public
    constructor Create(AOwner: TComponent; AFormDef: TaFormDef; ADef: TaControlDef);
    destructor Destroy; override;
    function Execute: Boolean;
    procedure GetValues(out V: TaLayoutValues);
    { za provjere bez prozora }
    property Form: TForm read FForm;
    property Preview: TPaintBox read FPreview;
    property DockBox: TComboBox read FDock;
    function UseBox(ASide: Integer): TCheckBox;
    function RefBox(ASide: Integer): TComboBox;
    function SideBox(ASide: Integer): TComboBox;
    function SpaceBox(ASide: Integer): TSpinEdit;
    property AroundBox: TSpinEdit read FAround;
    procedure ClickPreset(AIndex: Integer);
    procedure ClickAround;
  end;

{ jedna stranica: "Naziv" ili "Naziv:strana" ('' ako je to rub forme bez posebne strane) }
function BuildSideSpec(const ARef, ASide: string): string;
procedure ParseSideSpec(const ASpec: string; out ARef, ASide: string);
{ dijalog: vraca True i vrijednosti u AVals (kljucevi Anchors, Dock, BorderSpacing, AnchorLeft/Top/Right/Bottom) }
function RunLayoutDialog(AOwner: TComponent; AFormDef: TaFormDef; ADef: TaControlDef; AVals: TStrings): Boolean;

implementation

uses
  ta_i18n;


const
  SideTitle: array[0..3] of string = ('Lijevo', 'Gore', 'Desno', 'Dolje');
  DockKeys: array[0..5] of string = ('none', 'top', 'bottom', 'left', 'right', 'client');
  DockTitles: array[0..5] of string = ('Nema (slobodno)', 'Gore (cijela sirina)', 'Dolje (cijela sirina)', 'Lijevo (cijela visina)',
    'Desno (cijela visina)', 'Cijela povrsina');
  { koja strana susjeda je zadana kad se sidro veze uz njega: lijevi rub uz desni rub susjeda itd. }
  DefaultSibSide: array[0..3] of string = ('right', 'bottom', 'left', 'top');

function BuildSideSpec(const ARef, ASide: string): string;
begin
  if (ARef = '') or SameText(ARef, 'forma') then
  begin
    if ASide = '' then Exit('');
    Exit('forma:' + ASide);
  end;
  if ASide = '' then Result := ARef else Result := ARef + ':' + ASide;
end;

procedure ParseSideSpec(const ASpec: string; out ARef, ASide: string);
var
  P: Integer;
begin
  ARef := Trim(ASpec);
  ASide := '';
  P := Pos(':', ARef);
  if P > 0 then
  begin
    ASide := LowerCase(Trim(Copy(ARef, P + 1, MaxInt)));
    ARef := Trim(Copy(ARef, 1, P - 1));
  end;
  if ARef = '' then ARef := 'forma';
  if SameText(ARef, 'roditelj') or SameText(ARef, 'parent') or SameText(ARef, 'form') then ARef := 'forma';
end;

{ ---------------- uredjivac ---------------- }

constructor TaLayoutEditor.Create(AOwner: TComponent; AFormDef: TaFormDef; ADef: TaControlDef);
var
  I: Integer;
  V: TaLayoutValues;
begin
  inherited Create;
  FFormDef := AFormDef;
  FDef := ADef;
  FNames := TStringList.Create;
  FNames.Add('forma');
  for I := 0 to AFormDef.Count - 1 do
    if AFormDef[I] <> ADef then FNames.Add(AFormDef[I].Name);
  Build(AOwner);
  V.Anchors := ADef.GetX('anchors');
  V.Dock := ADef.GetX('dock');
  V.Spacing := ADef.GetX('space');
  V.Side[0] := ADef.GetX('asl'); V.Side[1] := ADef.GetX('ast');
  V.Side[2] := ADef.GetX('asr'); V.Side[3] := ADef.GetX('asb');
  SetValues(V);
end;

destructor TaLayoutEditor.Destroy;
begin
  FForm.Free;
  FNames.Free;
  inherited Destroy;
end;

procedure TaLayoutEditor.FillSideCombo(ASide: Integer);
var
  Horiz: Boolean;
begin
  Horiz := ASide in [0, 2];
  FSideRef[ASide].Items.Clear;
  FSideRef[ASide].Items.Add('(zadano)');
  if Horiz then
  begin
    FSideRef[ASide].Items.Add('lijevi rub'); FSideRef[ASide].Items.Add('sredina'); FSideRef[ASide].Items.Add('desni rub');
  end
  else
  begin
    FSideRef[ASide].Items.Add('gornji rub'); FSideRef[ASide].Items.Add('sredina'); FSideRef[ASide].Items.Add('donji rub');
  end;
end;

procedure TaLayoutEditor.Build(AOwner: TComponent);
var
  I, Y: Integer;
  L: TLabel;
  B: TButton;
  Pr: array[0..5] of string;
  P: Integer;
begin
  FForm := TForm.CreateNew(AOwner);
  FForm.Caption := Tr('Anchoring and layout: ') + FDef.Name;
  FForm.Position := poOwnerFormCenter;
  FForm.BorderStyle := bsDialog;
  FForm.ClientWidth := 800;
  FForm.ClientHeight := 590;
  { pregled }
  L := TLabel.Create(FForm); L.Parent := FForm; L.SetBounds(12, 8, 340, 18);
  L.Caption := Tr('Preview (blue = this control, arrows = anchors)');
  FPreview := TPaintBox.Create(FForm);
  FPreview.Parent := FForm;
  FPreview.SetBounds(12, 30, 380, 330);
  FPreview.OnPaint := @PreviewPaint;
  { gotovi obrasci }
  L := TLabel.Create(FForm); L.Parent := FForm; L.SetBounds(12, 370, 380, 18); L.Caption := Tr('Ready-made layouts:');
  Pr[0] := 'Fiksno (gore-lijevo)|LT'; Pr[1] := 'Rastezi vodoravno|LTR'; Pr[2] := 'Rastezi okomito|LTB';
  Pr[3] := 'Rastezi oboje|LTRB'; Pr[4] := 'Dolje desno|RB'; Pr[5] := 'Dolje, vodoravno|LRB';
  for I := 0 to 5 do
  begin
    P := Pos('|', Pr[I]);
    B := TButton.Create(FForm);
    B.Parent := FForm;
    B.Caption := Copy(Pr[I], 1, P - 1);
    B.Hint := Copy(Pr[I], P + 1, MaxInt);
    B.Tag := I;
    B.SetBounds(12 + (I mod 2) * 190, 392 + (I div 2) * 32, 184, 28);
    B.OnClick := @PresetClick;
  end;
  { Dock }
  L := TLabel.Create(FForm); L.Parent := FForm; L.SetBounds(410, 8, 80, 18); L.Caption := Tr('Dock:');
  FDock := TComboBox.Create(FForm);
  FDock.Parent := FForm; FDock.Style := csDropDownList; FDock.SetBounds(460, 4, 220, 24);
  for I := 0 to 5 do FDock.Items.Add(Tr(DockTitles[I]));
  FDock.OnChange := @DockChanged;
  { po strani }
  Y := 40;
  for I := 0 to 3 do
  begin
    FUse[I] := TCheckBox.Create(FForm);
    FUse[I].Parent := FForm;
    FUse[I].Caption := Tr('Anchor: ') + Tr(SideTitle[I]);
    FUse[I].SetBounds(410, Y, 150, 20);
    FUse[I].Font.Style := [fsBold];
    FUse[I].OnChange := @Changed;
    L := TLabel.Create(FForm); L.Parent := FForm; L.SetBounds(426, Y + 28, 56, 18); L.Caption := Tr('To:');
    FRef[I] := TComboBox.Create(FForm);
    FRef[I].Parent := FForm; FRef[I].Style := csDropDownList; FRef[I].SetBounds(490, Y + 24, 170, 24);
    FRef[I].Items.Assign(FNames);
    FRef[I].OnChange := @Changed;
    L := TLabel.Create(FForm); L.Parent := FForm; L.SetBounds(426, Y + 58, 62, 18); L.Caption := Tr('Side:');
    FSideRef[I] := TComboBox.Create(FForm);
    FSideRef[I].Parent := FForm; FSideRef[I].Style := csDropDownList; FSideRef[I].SetBounds(490, Y + 54, 170, 24);
    FillSideCombo(I);
    FSideRef[I].OnChange := @Changed;
    L := TLabel.Create(FForm); L.Parent := FForm; L.SetBounds(672, Y + 28, 100, 18); L.Caption := Tr('Spacing (px):');
    FSpace[I] := TSpinEdit.Create(FForm);
    FSpace[I].Parent := FForm; FSpace[I].SetBounds(672, Y + 48, 100, 24);
    FSpace[I].MinValue := 0; FSpace[I].MaxValue := 500;
    FSpace[I].OnChange := @Changed;
    Inc(Y, 92);
  end;
  { isti razmak }
  L := TLabel.Create(FForm); L.Parent := FForm; L.SetBounds(410, 412, 200, 18); L.Caption := Tr('Same spacing on all sides:');
  FAround := TSpinEdit.Create(FForm);
  FAround.Parent := FForm; FAround.SetBounds(618, 408, 70, 24); FAround.MinValue := 0; FAround.MaxValue := 500;
  B := TButton.Create(FForm); B.Parent := FForm; B.Caption := Tr('All sides'); B.SetBounds(696, 406, 96, 28); B.OnClick := @AroundClick;
  L := TLabel.Create(FForm); L.Parent := FForm; L.SetBounds(410, 446, 380, 90); L.AutoSize := False; L.WordWrap := True;
  L.Caption := Tr('An anchor to "form" keeps the control at a distance from the window edge. An anchor to another control binds the chosen side ') +
    'uz njezinu stranu (npr. lijevi rub uz desni rub susjeda). Dock ima prednost nad sidrima.';
  with TButton.Create(FForm) do begin Parent := FForm; Caption := Tr('OK'); ModalResult := mrOk; Default := True; SetBounds(590, 548, 96, 32); end;
  with TButton.Create(FForm) do begin Parent := FForm; Caption := Tr('Cancel'); ModalResult := mrCancel; Cancel := True; SetBounds(694, 548, 96, 32); end;
end;

procedure TaLayoutEditor.SetValues(const V: TaLayoutValues);
var
  I, K, Idx: Integer;
  Letters, Ref, Sd, Sp: string;
  L, T, R, B: Integer;
  Pat: string;
begin
  FLoading := True;
  try
    Idx := 0;
    for I := 0 to High(DockKeys) do
      if DockKeys[I] = LowerCase(V.Dock) then Idx := I;
    FDock.ItemIndex := Idx;
    Letters := V.Anchors;
    if Letters = '' then Letters := 'LT';
    for I := 0 to 3 do
    begin
      ParseSideSpec(V.Side[I], Ref, Sd);
      FUse[I].Checked := (Pos('LTRB'[I + 1], Letters) > 0) or (V.Side[I] <> '');
      K := FNames.IndexOf(Ref);
      if K < 0 then K := 0;
      FRef[I].ItemIndex := K;
      { strana: zadano = 0; sa strane lijevo/gore = 1, sredina = 2, desno/dolje = 3 }
      FSideRef[I].ItemIndex := 0;
      if (Sd = 'left') or (Sd = 'top') then FSideRef[I].ItemIndex := 1
      else if Sd = 'center' then FSideRef[I].ItemIndex := 2
      else if (Sd = 'right') or (Sd = 'bottom') then FSideRef[I].ItemIndex := 3;
    end;
    Sp := V.Spacing;
    if ParseSpacing(Sp, L, T, R, B) then
    begin
      FSpace[0].Value := L; FSpace[1].Value := T; FSpace[2].Value := R; FSpace[3].Value := B;
    end
    else for I := 0 to 3 do FSpace[I].Value := 0;
    FAround.Value := FSpace[0].Value;
    Pat := '';
  finally
    FLoading := False;
  end;
  DockChanged(nil);
  FPreview.Invalidate;
end;

procedure TaLayoutEditor.GetValues(out V: TaLayoutValues);
var
  I, K: Integer;
  Sd, Ref: string;
begin
  V.Anchors := '';
  for I := 0 to 3 do
    if FUse[I].Checked then V.Anchors := V.Anchors + 'LTRB'[I + 1];
  { LT je zadano, pa se ne pamti; nijedno se pamti kao (prazno sidro) }
  if V.Anchors = 'LT' then V.Anchors := '';
  V.Dock := DockKeys[Max(FDock.ItemIndex, 0)];
  if V.Dock = 'none' then V.Dock := '';
  V.Spacing := NormalizeSpacing(Format('%d,%d,%d,%d', [FSpace[0].Value, FSpace[1].Value, FSpace[2].Value, FSpace[3].Value]));
  for I := 0 to 3 do
  begin
    V.Side[I] := '';
    if not FUse[I].Checked then Continue;
    Ref := FNames[Max(FRef[I].ItemIndex, 0)];
    K := FSideRef[I].ItemIndex;
    Sd := '';
    if K = 1 then begin if I in [0, 2] then Sd := 'left' else Sd := 'top'; end
    else if K = 2 then Sd := 'center'
    else if K = 3 then begin if I in [0, 2] then Sd := 'right' else Sd := 'bottom'; end;
    if (Ref = 'forma') and (Sd = '') then Continue;                 { obicno sidro uz rub forme }
    V.Side[I] := BuildSideSpec(Ref, Sd);
    { strana jednaka zadanoj za susjeda ne mora se pisati }
    if (Ref <> 'forma') and (Sd = DefaultSibSide[I]) then V.Side[I] := Ref;
  end;
end;

procedure TaLayoutEditor.DockChanged(Sender: TObject);
var
  I: Integer;
  Free_: Boolean;
begin
  Free_ := FDock.ItemIndex <= 0;
  for I := 0 to 3 do
  begin
    FUse[I].Enabled := Free_; FRef[I].Enabled := Free_ and FUse[I].Checked; FSideRef[I].Enabled := Free_ and FUse[I].Checked;
  end;
  FPreview.Invalidate;
end;

procedure TaLayoutEditor.Changed(Sender: TObject);
var
  I: Integer;
begin
  if FLoading then Exit;
  for I := 0 to 3 do
  begin
    FRef[I].Enabled := FUse[I].Checked and (FDock.ItemIndex <= 0);
    FSideRef[I].Enabled := FRef[I].Enabled;
  end;
  FPreview.Invalidate;
end;

procedure TaLayoutEditor.PresetClick(Sender: TObject);
var
  S: string;
  I: Integer;
begin
  S := TButton(Sender).Hint;
  FLoading := True;
  try
    FDock.ItemIndex := 0;
    for I := 0 to 3 do
    begin
      FUse[I].Checked := Pos('LTRB'[I + 1], S) > 0;
      FRef[I].ItemIndex := 0;
      FSideRef[I].ItemIndex := 0;
    end;
  finally
    FLoading := False;
  end;
  DockChanged(nil);
  Changed(nil);
end;

procedure TaLayoutEditor.AroundClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to 3 do FSpace[I].Value := FAround.Value;
  FPreview.Invalidate;
end;

{ crtez: forma u mjerilu, susjedi sivo, ova kontrola plavo, sidra narancastim strelicama }
procedure TaLayoutEditor.PreviewPaint(Sender: TObject);
var
  C: TCanvas;
  Sc: Double;
  Ox, Oy, Fw, Fh, I, K, J: Integer;
  V: TaLayoutValues;
  Me, Rr, Sib: TRect;
  Ref, Sd: string;
  X1, Y1, X2, Y2: Integer;
  D: TaControlDef;

  function Sx(X: Integer): Integer; begin Result := Ox + Round(X * Sc); end;
  function Sy(Y: Integer): Integer; begin Result := Oy + Round(Y * Sc); end;

  procedure Arrow(AX1, AY1, AX2, AY2: Integer);
  var
    Dx, Dy, Ln: Double;
  begin
    C.Pen.Color := $0060E0; C.Pen.Width := 2;
    C.MoveTo(AX1, AY1); C.LineTo(AX2, AY2);
    Dx := AX2 - AX1; Dy := AY2 - AY1; Ln := Sqrt(Dx * Dx + Dy * Dy);
    if Ln < 1 then Exit;
    Dx := Dx / Ln; Dy := Dy / Ln;
    C.Brush.Color := $0060E0;
    C.Polygon([Point(AX2, AY2), Point(Round(AX2 - Dx * 9 + Dy * 5), Round(AY2 - Dy * 9 - Dx * 5)),
      Point(Round(AX2 - Dx * 9 - Dy * 5), Round(AY2 - Dy * 9 + Dx * 5))]);
    C.Pen.Width := 1;
  end;

begin
  C := FPreview.Canvas;
  C.Brush.Color := $F0F0F0;
  C.FillRect(0, 0, FPreview.Width, FPreview.Height);
  Fw := Max(FFormDef.Width, 100); Fh := Max(FFormDef.Height, 100);
  Sc := Min((FPreview.Width - 16) / Fw, (FPreview.Height - 16) / Fh);
  Ox := (FPreview.Width - Round(Fw * Sc)) div 2;
  Oy := (FPreview.Height - Round(Fh * Sc)) div 2;
  C.Brush.Color := clWhite; C.Pen.Color := $808080;
  C.Rectangle(Ox, Oy, Ox + Round(Fw * Sc), Oy + Round(Fh * Sc));
  C.Font.Size := 7;
  { susjedi }
  for I := 0 to FFormDef.Count - 1 do
  begin
    D := FFormDef[I];
    if D = FDef then Continue;
    C.Brush.Color := $E4E4E4; C.Pen.Color := $A0A0A0;
    C.Rectangle(Sx(D.Left), Sy(D.Top), Sx(D.Left + D.Width), Sy(D.Top + D.Height));
    C.Brush.Style := bsClear; C.Font.Color := $606060;
    C.TextOut(Sx(D.Left) + 3, Sy(D.Top) + 2, D.Name);
    C.Brush.Style := bsSolid;
  end;
  GetValues(V);
  { kontrola: s Dockom zauzima rub, inace svoj pravokutnik }
  Me := Rect(FDef.Left, FDef.Top, FDef.Left + FDef.Width, FDef.Top + FDef.Height);
  if V.Dock = 'top' then Me := Rect(0, 0, Fw, FDef.Height)
  else if V.Dock = 'bottom' then Me := Rect(0, Fh - FDef.Height, Fw, Fh)
  else if V.Dock = 'left' then Me := Rect(0, 0, FDef.Width, Fh)
  else if V.Dock = 'right' then Me := Rect(Fw - FDef.Width, 0, Fw, Fh)
  else if V.Dock = 'client' then Me := Rect(0, 0, Fw, Fh);
  C.Brush.Color := $E0A060; C.Pen.Color := $804020; C.Pen.Width := 2;
  C.Rectangle(Sx(Me.Left), Sy(Me.Top), Sx(Me.Right), Sy(Me.Bottom));
  C.Pen.Width := 1;
  C.Brush.Style := bsClear; C.Font.Color := clWhite;
  C.TextOut(Sx(Me.Left) + 3, Sy(Me.Top) + 2, FDef.Name);
  C.Brush.Style := bsSolid;
  if V.Dock <> '' then Exit;
  { sidra }
  for K := 0 to 3 do
  begin
    if not FUse[K].Checked then Continue;
    ParseSideSpec(V.Side[K], Ref, Sd);
    Rr := Rect(0, 0, Fw, Fh);
    if SameText(Ref, 'forma') then
    begin
      { rub forme }
      case K of
        0: begin X1 := Sx(Me.Left); Y1 := (Sy(Me.Top) + Sy(Me.Bottom)) div 2; X2 := Sx(0); Y2 := Y1; end;
        1: begin Y1 := Sy(Me.Top); X1 := (Sx(Me.Left) + Sx(Me.Right)) div 2; Y2 := Sy(0); X2 := X1; end;
        2: begin X1 := Sx(Me.Right); Y1 := (Sy(Me.Top) + Sy(Me.Bottom)) div 2; X2 := Sx(Fw); Y2 := Y1; end;
      else
        begin Y1 := Sy(Me.Bottom); X1 := (Sx(Me.Left) + Sx(Me.Right)) div 2; Y2 := Sy(Fh); X2 := X1; end;
      end;
      Arrow(X1, Y1, X2, Y2);
    end
    else
    begin
      Sib := Rect(0, 0, 0, 0);
      for J := 0 to FFormDef.Count - 1 do
        if SameText(FFormDef[J].Name, Ref) then
          Sib := Rect(FFormDef[J].Left, FFormDef[J].Top, FFormDef[J].Left + FFormDef[J].Width, FFormDef[J].Top + FFormDef[J].Height);
      if Sd = '' then Sd := DefaultSibSide[K];
      case K of
        0: begin X1 := Sx(Me.Left); Y1 := (Sy(Me.Top) + Sy(Me.Bottom)) div 2; Y2 := Y1;
             if Sd = 'left' then X2 := Sx(Sib.Left) else if Sd = 'center' then X2 := (Sx(Sib.Left) + Sx(Sib.Right)) div 2 else X2 := Sx(Sib.Right); end;
        1: begin Y1 := Sy(Me.Top); X1 := (Sx(Me.Left) + Sx(Me.Right)) div 2; X2 := X1;
             if Sd = 'top' then Y2 := Sy(Sib.Top) else if Sd = 'center' then Y2 := (Sy(Sib.Top) + Sy(Sib.Bottom)) div 2 else Y2 := Sy(Sib.Bottom); end;
        2: begin X1 := Sx(Me.Right); Y1 := (Sy(Me.Top) + Sy(Me.Bottom)) div 2; Y2 := Y1;
             if Sd = 'left' then X2 := Sx(Sib.Left) else if Sd = 'center' then X2 := (Sx(Sib.Left) + Sx(Sib.Right)) div 2 else X2 := Sx(Sib.Right); end;
      else
        begin Y1 := Sy(Me.Bottom); X1 := (Sx(Me.Left) + Sx(Me.Right)) div 2; X2 := X1;
          if Sd = 'top' then Y2 := Sy(Sib.Top) else if Sd = 'center' then Y2 := (Sy(Sib.Top) + Sy(Sib.Bottom)) div 2 else Y2 := Sy(Sib.Bottom); end;
      end;
      Arrow(X1, Y1, X2, Y2);
    end;
  end;
end;

function TaLayoutEditor.UseBox(ASide: Integer): TCheckBox;
begin
  Result := FUse[ASide];
end;

function TaLayoutEditor.RefBox(ASide: Integer): TComboBox;
begin
  Result := FRef[ASide];
end;

function TaLayoutEditor.SideBox(ASide: Integer): TComboBox;
begin
  Result := FSideRef[ASide];
end;

function TaLayoutEditor.SpaceBox(ASide: Integer): TSpinEdit;
begin
  Result := FSpace[ASide];
end;

procedure TaLayoutEditor.ClickPreset(AIndex: Integer);
var
  I: Integer;
begin
  for I := 0 to FForm.ControlCount - 1 do
    if (FForm.Controls[I] is TButton) and (FForm.Controls[I].Tag = AIndex) and (TButton(FForm.Controls[I]).Hint <> '') then
    begin
      PresetClick(FForm.Controls[I]);
      Exit;
    end;
end;

procedure TaLayoutEditor.ClickAround;
begin
  AroundClick(nil);
end;

function TaLayoutEditor.Execute: Boolean;
begin
  Result := FForm.ShowModal = mrOk;
end;

function RunLayoutDialog(AOwner: TComponent; AFormDef: TaFormDef; ADef: TaControlDef; AVals: TStrings): Boolean;
var
  E: TaLayoutEditor;
  V: TaLayoutValues;
begin
  Result := False;
  E := TaLayoutEditor.Create(AOwner, AFormDef, ADef);
  try
    if E.Execute then
    begin
      E.GetValues(V);
      AVals.Values['Anchors'] := V.Anchors;
      AVals.Values['Dock'] := V.Dock;
      AVals.Values['BorderSpacing'] := V.Spacing;
      AVals.Values['AnchorLeft'] := V.Side[0];
      AVals.Values['AnchorTop'] := V.Side[1];
      AVals.Values['AnchorRight'] := V.Side[2];
      AVals.Values['AnchorBottom'] := V.Side[3];
      Result := True;
    end;
  finally
    E.Free;
  end;
end;

end.
