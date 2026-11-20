unit ta_pagesetup;
{ Postavke stranice izvjesca: papir, orijentacija, margine, a za naljepnice i
  velicina naljepnice, broj stupaca te razmaci (kao kod Avery/Herma araka).
  Sve se upisuje u milimetrima; definicija cuva piksele (96 dpi). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, Graphics, Math, ta_reportdef;

{ otvara dijalog nad definicijom; True = primijenjeno (poziv treba spremiti poništenje prije) }
function RunPageSetup(AOwner: TComponent; ADef: TaReportDef): Boolean;

{ isto bez dijaloga (testovi): sve mjere u mm }

function ApplyPageSetupMm(ADef: TaReportDef; APageW, APageH, AMarL, AMarT, AMarR, AMarB: Double;
  ACols: Integer; ALabW, ALabH, AGapH, AGapV: Double; out AErr: string): Boolean;

function MmToPx(AMm: Double): Integer;
function PxToMm(APx: Integer): Double;

implementation

uses
  ta_i18n;


type
  TPaper = record Name: string; W, H: Double; end;
  TLabelPreset = record
    Name: string;
    Cols: Integer;
    W, H, GapH, GapV, MarL, MarT: Double;
  end;

const
  Papers: array[0..6] of TPaper = (
    (Name: 'A4 (210 × 297)'; W: 210; H: 297),
    (Name: 'A5 (148 × 210)'; W: 148; H: 210),
    (Name: 'A6 (105 × 148)'; W: 105; H: 148),
    (Name: 'A3 (297 × 420)'; W: 297; H: 420),
    (Name: 'Letter (215,9 × 279,4)'; W: 215.9; H: 279.4),
    (Name: 'Legal (215,9 × 355,6)'; W: 215.9; H: 355.6),
    (Name: 'Prilagođeno'; W: 0; H: 0));

  LabelPresets: array[0..9] of TLabelPreset = (
    (Name: 'Običan izvještaj (bez naljepnica)'; Cols: 1; W: 0; H: 0; GapH: 0; GapV: 0; MarL: 0; MarT: 0),
    (Name: '63,5 × 38,1 mm, 3 × 7 (Avery L7160)'; Cols: 3; W: 63.5; H: 38.1; GapH: 2.5; GapV: 0; MarL: 7.2; MarT: 15.1),
    (Name: '99,1 × 38,1 mm, 2 × 7 (Avery L7163)'; Cols: 2; W: 99.1; H: 38.1; GapH: 2.5; GapV: 0; MarL: 4.65; MarT: 15.1),
    (Name: '99,1 × 33,9 mm, 2 × 8 (Avery L7162)'; Cols: 2; W: 99.1; H: 33.9; GapH: 2.5; GapV: 0; MarL: 4.65; MarT: 12.9),
    (Name: '70 × 37 mm, 3 × 8, bez margina'; Cols: 3; W: 70; H: 37; GapH: 0; GapV: 0; MarL: 0; MarT: 0),
    (Name: '70 × 50,8 mm, 3 × 5, bez margina'; Cols: 3; W: 70; H: 50.8; GapH: 0; GapV: 0; MarL: 0; MarT: 0),
    (Name: '105 × 74 mm, 2 × 4, bez margina'; Cols: 2; W: 105; H: 74; GapH: 0; GapV: 0; MarL: 0; MarT: 0),
    (Name: '105 × 57 mm, 2 × 5, bez margina'; Cols: 2; W: 105; H: 57; GapH: 0; GapV: 0; MarL: 0; MarT: 0),
    (Name: '105 × 35 mm, 2 × 8, bez margina'; Cols: 2; W: 105; H: 35; GapH: 0; GapV: 0; MarL: 0; MarT: 0),
    (Name: 'Prilagođeno'; Cols: 0; W: 0; H: 0; GapH: 0; GapV: 0; MarL: 0; MarT: 0));

function MmToPx(AMm: Double): Integer;
begin
  Result := Round(AMm * 96 / 25.4);
end;

function PxToMm(APx: Integer): Double;
begin
  Result := APx * 25.4 / 96;
end;

function SectionUsed(ADef: TaReportDef; ASec: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to ADef.Count - 1 do
    if SameText(ADef[I].Section, SectionNames[ASec]) then Exit(True);
end;

function ApplyPageSetupMm(ADef: TaReportDef; APageW, APageH, AMarL, AMarT, AMarR, AMarB: Double;
  ACols: Integer; ALabW, ALabH, AGapH, AGapV: Double; out AErr: string): Boolean;
var
  Pw, Ph, Ml, Mt, Mr, Mb, Gh, Gv, Lw, Lh, Cw: Integer;
begin
  Result := False;
  AErr := '';
  if (APageW < 30) or (APageH < 30) then begin AErr := Tr('The paper is too small (at least 30 mm).'); Exit; end;
  if (AMarL < 0) or (AMarT < 0) or (AMarR < 0) or (AMarB < 0) or (AGapH < 0) or (AGapV < 0) then
  begin AErr := Tr('Margins and spacing must not be negative.'); Exit; end;
  if ACols < 1 then begin AErr := 'Broj stupaca mora biti barem 1.'; Exit; end;
  Pw := MmToPx(APageW); Ph := MmToPx(APageH);
  Ml := MmToPx(AMarL); Mt := MmToPx(AMarT); Mr := MmToPx(AMarR); Mb := MmToPx(AMarB);
  Gh := MmToPx(AGapH); Gv := MmToPx(AGapV);
  if Ml + Mr + 20 > Pw then begin AErr := Tr('The left and right margins leave no room for content.'); Exit; end;
  if Mt + Mb + 20 > Ph then begin AErr := Tr('The top and bottom margins leave no room for content.'); Exit; end;
  if ACols > 1 then
  begin
    if (ALabW <= 0) or (ALabH <= 0) then begin AErr := Tr('Enter the label width and height.'); Exit; end;
    Lw := MmToPx(ALabW); Lh := MmToPx(ALabH);
    { desna margina je ostatak lista nakon svih naljepnica }
    Mr := Pw - Ml - ACols * Lw - (ACols - 1) * Gh;
    if Mr < 0 then
    begin
      AErr := Format(Tr('The labels (%d x %s mm with spacing %s) do not fit the paper width.'),
        [ACols, FormatFloat('0.#', ALabW), FormatFloat('0.#', AGapH)]);
      Exit;
    end;
    Cw := Lw;
    if Cw < 8 then begin AErr := 'Naljepnica je preuska.'; Exit; end;
    if Lh + Mt + Mb > Ph then begin AErr := Tr('The label is taller than the page.'); Exit; end;
    ADef.Heights[SecDetail] := Lh;
    ADef.RowGap := Gv;
    { prazni odjeljci (zaglavlje, podnozje) kradu mjesto naljepnicama }
    for Cw := SecReportHeader to SecReportFooter do
      if Cw in [SecReportHeader, SecPageHeader, SecPageFooter, SecReportFooter] then
        if not SectionUsed(ADef, Cw) then ADef.Heights[Cw] := 0;
  end
  else
    ADef.RowGap := 0;
  ADef.PageWidth := Pw; ADef.PageHeight := Ph;
  ADef.MarginLeft := Ml; ADef.MarginTop := Mt; ADef.MarginRight := Mr; ADef.MarginBottom := Mb;
  ADef.Columns := ACols;
  ADef.ColumnGap := Gh;
  Result := True;
end;

function ParseMm(const S: string; ADefault: Double): Double;
var
  T: string;
  Fs: TFormatSettings;
begin
  { ulaz moze imati zarez ili tocku bez obzira na postavke sustava }
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  T := StringReplace(Trim(S), ',', '.', [rfReplaceAll]);
  if T = '' then Exit(0);
  Result := StrToFloatDef(T, ADefault, Fs);
end;

function FmtMm(AValue: Double): string;
begin
  Result := StringReplace(FormatFloat('0.#', AValue), '.', ',', []);
end;

type
  TSetupForm = class(TForm)
  public
    Def: TaReportDef;
    PaperBox, LabelBox: TComboBox;
    Landscape: TCheckBox;
    EW, EH, EML, EMT, EMR, EMB, ECols, ELW, ELH, EGH, EGV: TEdit;
    Info: TLabel;
    Busy: Boolean;
    procedure PaperChange(Sender: TObject);
    procedure LabelChange(Sender: TObject);
    procedure AnyChange(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure Refresh;
  end;

procedure TSetupForm.Refresh;
var
  Pw, Ph, Mt, Mb, Lh, Gv, Rows, Cols: Double;
begin
  Pw := ParseMm(EW.Text, 210); Ph := ParseMm(EH.Text, 297);
  Mt := ParseMm(EMT.Text, 0); Mb := ParseMm(EMB.Text, 0);
  Lh := ParseMm(ELH.Text, 0); Gv := ParseMm(EGV.Text, 0);
  Cols := StrToIntDef(Trim(ECols.Text), 1);
  if (Cols > 1) and (Lh > 0) then
  begin
    Rows := Int((Ph - Mt - Mb + Gv + 0.01) / (Lh + Gv));
    Info.Caption := Format(Tr('%d x %d = %d labels fit on a page.'), [Round(Cols), Round(Rows), Round(Cols * Rows)]);
  end
  else Info.Caption := Tr('Contents: ') + FmtMm(Pw - ParseMm(EML.Text, 0) - ParseMm(EMR.Text, 0)) + ' × ' + FmtMm(Ph - Mt - Mb) + Tr(' mm.');
end;

procedure TSetupForm.PaperChange(Sender: TObject);
var
  W, H: Double;
begin
  if Busy then Exit;
  if (PaperBox.ItemIndex < 0) or (Papers[PaperBox.ItemIndex].W = 0) then Exit;
  W := Papers[PaperBox.ItemIndex].W; H := Papers[PaperBox.ItemIndex].H;
  if Landscape.Checked then begin EW.Text := FmtMm(H); EH.Text := FmtMm(W); end
  else begin EW.Text := FmtMm(W); EH.Text := FmtMm(H); end;
  Refresh;
end;

procedure TSetupForm.LabelChange(Sender: TObject);
var
  P: TLabelPreset;
begin
  if Busy then Exit;
  if LabelBox.ItemIndex < 0 then Exit;
  P := LabelPresets[LabelBox.ItemIndex];
  if P.Cols = 0 then Exit;
  Busy := True;
  try
    { gotove naljepnice su za A4 uspravno }
    PaperBox.ItemIndex := 0; Landscape.Checked := False;
    EW.Text := '210'; EH.Text := '297';
    ECols.Text := IntToStr(P.Cols);
    if P.Cols > 1 then
    begin
      ELW.Text := FmtMm(P.W); ELH.Text := FmtMm(P.H);
      EGH.Text := FmtMm(P.GapH); EGV.Text := FmtMm(P.GapV);
      EML.Text := FmtMm(P.MarL); EMT.Text := FmtMm(P.MarT);
      EMB.Text := '0'; EMR.Text := '0';
    end;
  finally
    Busy := False;
  end;
  Refresh;
end;

procedure TSetupForm.AnyChange(Sender: TObject);
begin
  if Busy then Exit;
  { rucna promjena mjera: ponudeni popisi prelaze na "Prilagođeno" }
  if (Sender = EW) or (Sender = EH) then PaperBox.ItemIndex := High(Papers);
  if (Sender = ECols) or (Sender = ELW) or (Sender = ELH) or (Sender = EGH) or (Sender = EGV) then
    LabelBox.ItemIndex := High(LabelPresets);
  Refresh;
end;

procedure TSetupForm.OkClick(Sender: TObject);
var
  Err: string;
  Cols: Integer;
  Probe: TaReportDef;
begin
  Cols := StrToIntDef(Trim(ECols.Text), 1);
  { isprobaj na kopiji: dijalog ostaje otvoren ako mjere ne stanu }
  Probe := TaReportDef.Create;
  try
    Probe.FromJson(Def.ToJson);
    if not ApplyPageSetupMm(Probe, ParseMm(EW.Text, 210), ParseMm(EH.Text, 297), ParseMm(EML.Text, 0), ParseMm(EMT.Text, 0),
         ParseMm(EMR.Text, 0), ParseMm(EMB.Text, 0), Cols, ParseMm(ELW.Text, 0), ParseMm(ELH.Text, 0),
         ParseMm(EGH.Text, 0), ParseMm(EGV.Text, 0), Err) then
    begin
      ShowMessage(Err);
      Exit;
    end;
  finally
    Probe.Free;
  end;
  ModalResult := mrOk;
end;

function RunPageSetup(AOwner: TComponent; ADef: TaReportDef): Boolean;
var
  F: TSetupForm;
  Y, I, Cols: Integer;
  Err: string;
  Lw: Double;

  function Lbl(const ACap: string; AX, AY: Integer): TLabel;
  begin
    Result := TLabel.Create(F);
    Result.Parent := F;
    Result.Caption := ACap;
    Result.SetBounds(AX, AY + 4, 220, 18);
  end;

  function Ed(AX, AY, AW: Integer; const AText: string): TEdit;
  begin
    Result := TEdit.Create(F);
    Result.Parent := F;
    Result.SetBounds(AX, AY, AW, 26);
    Result.Text := AText;
    Result.OnChange := @F.AnyChange;
  end;

  function Group(const ACap: string; AY: Integer): TLabel;
  begin
    Result := TLabel.Create(F);
    Result.Parent := F;
    Result.Caption := ACap;
    Result.Font.Style := [fsBold];
    Result.SetBounds(16, AY, 400, 18);
  end;

begin
  Result := False;
  F := TSetupForm.CreateNew(AOwner);
  try
    F.Def := ADef;
    F.Busy := True;
    F.Caption := Tr('Page and label settings');
    F.Position := poOwnerFormCenter;
    F.BorderStyle := bsDialog;
    F.ClientWidth := 600;
    F.ClientHeight := 520;

    Y := 14;
    Group(Tr('Paper'), Y); Inc(Y, 24);
    Lbl(Tr('Size:'), 16, Y);
    F.PaperBox := TComboBox.Create(F); F.PaperBox.Parent := F; F.PaperBox.Style := csDropDownList;
    F.PaperBox.SetBounds(240, Y, 250, 26);
    for I := 0 to High(Papers) do F.PaperBox.Items.Add(Papers[I].Name);
    F.PaperBox.OnChange := @F.PaperChange;
    F.Landscape := TCheckBox.Create(F); F.Landscape.Parent := F; F.Landscape.Caption := Tr('Landscape');
    F.Landscape.SetBounds(500, Y + 3, 90, 22);
    F.Landscape.OnChange := @F.PaperChange;
    Inc(Y, 34);
    Lbl(Tr('Width x height (mm):'), 16, Y);
    F.EW := Ed(240, Y, 70, FmtMm(PxToMm(ADef.PageWidth)));
    F.EH := Ed(320, Y, 70, FmtMm(PxToMm(ADef.PageHeight)));
    for I := 0 to High(Papers) - 1 do
      if (Abs(PxToMm(ADef.PageWidth) - Papers[I].W) < 1) and (Abs(PxToMm(ADef.PageHeight) - Papers[I].H) < 1) then
      begin F.EW.Text := FmtMm(Papers[I].W); F.EH.Text := FmtMm(Papers[I].H); end
      else if (Abs(PxToMm(ADef.PageWidth) - Papers[I].H) < 1) and (Abs(PxToMm(ADef.PageHeight) - Papers[I].W) < 1) then
      begin F.EW.Text := FmtMm(Papers[I].H); F.EH.Text := FmtMm(Papers[I].W); end;
    { prepoznaj poznati papir }
    F.PaperBox.ItemIndex := High(Papers);
    for I := 0 to High(Papers) - 1 do
    begin
      if (Abs(PxToMm(ADef.PageWidth) - Papers[I].W) < 1) and (Abs(PxToMm(ADef.PageHeight) - Papers[I].H) < 1) then
        F.PaperBox.ItemIndex := I
      else if (Abs(PxToMm(ADef.PageWidth) - Papers[I].H) < 1) and (Abs(PxToMm(ADef.PageHeight) - Papers[I].W) < 1) then
      begin
        F.PaperBox.ItemIndex := I;
        F.Landscape.Checked := True;
      end;
    end;
    Inc(Y, 40);
    Group(Tr('Margins (mm)'), Y); Inc(Y, 24);
    Lbl(Tr('Left / top:'), 16, Y);
    F.EML := Ed(240, Y, 70, FmtMm(PxToMm(ADef.MarginLeft)));
    F.EMT := Ed(320, Y, 70, FmtMm(PxToMm(ADef.MarginTop)));
    Inc(Y, 34);
    Lbl(Tr('Right / bottom:'), 16, Y);
    F.EMR := Ed(240, Y, 70, FmtMm(PxToMm(ADef.MarginRight)));
    F.EMB := Ed(320, Y, 70, FmtMm(PxToMm(ADef.MarginBottom)));
    Inc(Y, 44);
    Group(Tr('Labels / columns'), Y); Inc(Y, 24);
    Lbl(Tr('Sheet:'), 16, Y);
    F.LabelBox := TComboBox.Create(F); F.LabelBox.Parent := F; F.LabelBox.Style := csDropDownList;
    F.LabelBox.SetBounds(240, Y, 340, 26);
    for I := 0 to High(LabelPresets) do F.LabelBox.Items.Add(LabelPresets[I].Name);
    F.LabelBox.OnChange := @F.LabelChange;
    Inc(Y, 34);
    Cols := ADef.Columns;
    if Cols < 1 then Cols := 1;
    Lbl(Tr('Columns per row:'), 16, Y);
    F.ECols := Ed(240, Y, 70, IntToStr(Cols));
    Inc(Y, 34);
    Lw := PxToMm(ADef.PageWidth - ADef.MarginLeft - ADef.MarginRight - ADef.ColumnGap * (Cols - 1)) / Cols;
    Lbl(Tr('Label w x h (mm):'), 16, Y);
    F.ELW := Ed(240, Y, 70, FmtMm(Lw));
    F.ELH := Ed(320, Y, 70, FmtMm(PxToMm(ADef.Heights[SecDetail])));
    Inc(Y, 34);
    Lbl(Tr('Spacing vert. / horiz. (mm):'), 16, Y);
    F.EGH := Ed(240, Y, 70, FmtMm(PxToMm(ADef.ColumnGap)));
    F.EGV := Ed(320, Y, 70, FmtMm(PxToMm(ADef.RowGap)));
    F.LabelBox.ItemIndex := High(LabelPresets);
    if Cols = 1 then F.LabelBox.ItemIndex := 0;
    Inc(Y, 40);
    F.Info := TLabel.Create(F); F.Info.Parent := F; F.Info.SetBounds(16, Y, 570, 18);
    F.Info.Font.Color := clGray;
    Inc(Y, 22);
    with TLabel.Create(F) do
    begin
      Parent := F; AutoSize := False; WordWrap := True; SetBounds(16, Y, 570, 54); Font.Color := clGray;
      Caption := Tr('Labels: the label height becomes the height of the Detail section, and the right margin is computed from the rest of the sheet. ') +
        Tr('Columns 1 = an ordinary report. Check the sizes of ready-made sheets against the packaging.');
    end;
    Inc(Y, 64);
    with TButton.Create(F) do
    begin
      Parent := F; Caption := Tr('OK'); SetBounds(380, Y, 96, 30); Default := True; OnClick := @F.OkClick;
    end;
    with TButton.Create(F) do
    begin
      Parent := F; Caption := Tr('Cancel'); SetBounds(484, Y, 96, 30); ModalResult := mrCancel; Cancel := True;
    end;
    F.ClientHeight := Y + 46;
    F.Busy := False;
    F.Refresh;
    if F.ShowModal <> mrOk then Exit;
    Result := ApplyPageSetupMm(ADef, ParseMm(F.EW.Text, 210), ParseMm(F.EH.Text, 297), ParseMm(F.EML.Text, 0),
      ParseMm(F.EMT.Text, 0), ParseMm(F.EMR.Text, 0), ParseMm(F.EMB.Text, 0), StrToIntDef(Trim(F.ECols.Text), 1),
      ParseMm(F.ELW.Text, 0), ParseMm(F.ELH.Text, 0), ParseMm(F.EGH.Text, 0), ParseMm(F.EGV.Text, 0), Err);
    if not Result then ShowMessage(Err);
  finally
    F.Free;
  end;
end;

end.
