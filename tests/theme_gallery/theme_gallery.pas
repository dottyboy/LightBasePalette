program theme_gallery;
{ Galerija teme: jedan prozor sa svim obiteljima kontrola, snimljen u PNG za svaku ugradenu temu,
  svijetlu i tamnu varijantu i svaki oblik. Pokretanje: theme_gallery [izlazna_mapa]
  (QT_QPA_PLATFORM=offscreen radi bez zaslona). Izlaz: <tema>_<svijetla|tamna>_<oblik>.png }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Grids, Spin, EditBtn, CheckLst, Classes, SysUtils, Graphics, StrUtils,
  qt6, qt6widgets, ta_tokens, ta_theme, ta_sidemenu, ta_family, ta_edit, ta_editor;

type
  TGalleryForm = class(TForm)
  public
    constructor CreateGallery;
  end;

constructor TGalleryForm.CreateGallery;
var
  Pnl: TPanel;
  Lbl: TLabel;
  Ed: TEdit;
  Cb: TComboBox;
  Sp: TFloatSpinEdit;
  De: TDateEdit;
  Ee: TaEdit;
  Ed4: TaEditor;
  Si: TSpinEdit;
  Btn: TButton;
  Ck: TCheckBox;
  Rb: TRadioButton;
  Pb: TProgressBar;
  Pg: TPageControl;
  Ts: TTabSheet;
  Lb: TListBox;
  Sg: TStringGrid;
  Mm: TMemo;
  Sm: TaSideMenu;
  Gb: TGroupBox;
  G: TaSideMenuGroup;
  X, Y, I: Integer;
  procedure Cap(const AText: string; AX, AY: Integer);
  begin
    Lbl := TLabel.Create(Self);
    Lbl.Parent := Self;
    Lbl.Caption := AText;
    Lbl.SetBounds(AX, AY, 200, 18);
  end;
begin
  inherited CreateNew(Application);
  Caption := 'Galerija teme';
  SetBounds(0, 0, 1000, 860);
  Position := poDesigned;

  Sm := TaSideMenu.Create(Self);
  Sm.Parent := Self;
  Sm.SetBounds(8, 8, 200, 360);
  G := Sm.Groups.Add; G.Caption := 'Računi'; G.IconName := 'invoice';
  with G.Items.Add do begin Caption := 'Stavke računa'; Action := 'x'; end;
  with G.Items.Add do begin Caption := 'Novi račun'; Action := 'y'; end;
  G := Sm.Groups.Add; G.Caption := 'Šifrarnici'; G.IconName := 'database';
  with G.Items.Add do begin Caption := 'Partneri'; Action := 'z'; end;
  Sm.SelectAction('x');

  X := 224; Y := 8;
  Cap('Edit (normalno)', X, Y);
  Ed := TEdit.Create(Self); Ed.Parent := Self; Ed.SetBounds(X, Y + 20, 200, 28); Ed.Text := 'Podloška M8';
  Cap('Edit (onemogućeno)', X + 220, Y);
  Ed := TEdit.Create(Self); Ed.Parent := Self; Ed.SetBounds(X + 220, Y + 20, 200, 28); Ed.Text := 'Samo za čitanje'; Ed.Enabled := False;
  Cap('Combo (popis)', X + 440, Y);
  Cb := TComboBox.Create(Self); Cb.Parent := Self; Cb.SetBounds(X + 440, Y + 20, 200, 28);
  Cb.Style := csDropDownList; Cb.Items.Add('Zagreb'); Cb.Items.Add('Split'); Cb.Items.Add('Rijeka'); Cb.ItemIndex := 0;

  Y := 64;
  Cap('Decimalni (spin)', X, Y);
  Sp := TFloatSpinEdit.Create(Self); Sp.Parent := Self; Sp.SetBounds(X, Y + 20, 140, 28); Sp.DecimalPlaces := 2; Sp.Value := 2.51;
  Cap('Cijeli (spin)', X + 160, Y);
  Si := TSpinEdit.Create(Self); Si.Parent := Self; Si.SetBounds(X + 160, Y + 20, 120, 28); Si.Value := 12;
  Cap('Datum', X + 300, Y);
  De := TDateEdit.Create(Self); De.Parent := Self; De.SetBounds(X + 300, Y + 20, 130, 28); De.Date := EncodeDate(2026, 10, 12);
  Cap('Combo (uređivanje)', X + 440, Y);
  Cb := TComboBox.Create(Self); Cb.Parent := Self; Cb.SetBounds(X + 440, Y + 20, 200, 28); Cb.Items.Add('Prvi'); Cb.Text := 'Upis';

  Y := 120;
  Cap('Gumbi', X, Y);
  Btn := TButton.Create(Self); Btn.Parent := Self; Btn.SetBounds(X, Y + 20, 100, 30); Btn.Caption := 'Novo';
  Btn := TButton.Create(Self); Btn.Parent := Self; Btn.SetBounds(X + 110, Y + 20, 100, 30); Btn.Caption := 'Spremi'; Btn.Default := True;
  Btn := TButton.Create(Self); Btn.Parent := Self; Btn.SetBounds(X + 220, Y + 20, 100, 30); Btn.Caption := 'Odustani'; Btn.Enabled := False;
  Cap('Check i radio', X + 340, Y);
  Ck := TCheckBox.Create(Self); Ck.Parent := Self; Ck.SetBounds(X + 340, Y + 20, 130, 22); Ck.Caption := 'Aktivan'; Ck.Checked := True;
  Ck := TCheckBox.Create(Self); Ck.Parent := Self; Ck.SetBounds(X + 340, Y + 44, 130, 22); Ck.Caption := 'Neaktivan';
  Rb := TRadioButton.Create(Self); Rb.Parent := Self; Rb.SetBounds(X + 480, Y + 20, 130, 22); Rb.Caption := 'Opcija A'; Rb.Checked := True;
  Rb := TRadioButton.Create(Self); Rb.Parent := Self; Rb.SetBounds(X + 480, Y + 44, 130, 22); Rb.Caption := 'Opcija B';

  Y := 196;
  Cap('Progres', X, Y);
  Pb := TProgressBar.Create(Self); Pb.Parent := Self; Pb.SetBounds(X, Y + 20, 300, 22); Pb.Position := 65;

  Pg := TPageControl.Create(Self); Pg.Parent := Self; Pg.SetBounds(X + 340, Y, 430, 120);
  for I := 1 to 3 do
  begin
    Ts := TTabSheet.Create(Pg); Ts.PageControl := Pg; Ts.Caption := 'Kartica ' + IntToStr(I);
  end;

  Y := 332;
  Lb := TListBox.Create(Self); Lb.Parent := Self; Lb.SetBounds(X, Y, 180, 140);
  Lb.Items.Add('Prvi redak'); Lb.Items.Add('Drugi redak (odabran)'); Lb.Items.Add('Treći redak'); Lb.ItemIndex := 1;
  Sg := TStringGrid.Create(Self); Sg.Parent := Self; Sg.SetBounds(X + 200, Y, 570, 140);
  Sg.ColCount := 4; Sg.RowCount := 5; Sg.FixedRows := 1; Sg.FixedCols := 0;
  Sg.Cells[0, 0] := 'Opis'; Sg.Cells[1, 0] := 'Količina'; Sg.Cells[2, 0] := 'Cijena'; Sg.Cells[3, 0] := 'Iznos';
  for I := 1 to 4 do
  begin
    Sg.Cells[0, I] := 'Artikl ' + IntToStr(I); Sg.Cells[1, I] := IntToStr(I * 3);
    Sg.Cells[2, I] := '12,50'; Sg.Cells[3, I] := FormatFloat('#,##0.00', I * 37.5);
  end;

  Cap('Obitelj Edit: text, password, combo, droplist, spin, date, currency', X, 596);
  for I := 0 to 6 do
  begin
    Ee := TaEdit.Create(Self); Ee.Parent := Self;
    Ee.SetBounds(X + I * 110, 620, 104, 28);
    Ee.Variant := TaEditVariant(I);
    if I in [2, 3] then begin Ee.Items.Add('Zagreb'); Ee.Items.Add('Split'); Ee.Text := 'Zagreb'; end
    else if I = 4 then Ee.SetValue(2.51)
    else if I = 5 then Ee.SetValue(EncodeDate(2026, 11, 10))
    else if I = 6 then Ee.SetValue(1234.5)
    else Ee.Text := 'Tekst';
  end;
  Ed4 := TaEditor.Create(Self); Ed4.Parent := Self; Ed4.SetBounds(X, 656, 770, 90);
  Ed4.Variant := ewFgl;
  Ed4.Text := '{ Popis partnera }' + LineEnding + 'FUNCTION PopisPartnera(grad, aktivan)' + LineEnding +
    '  DEFINE grad TEXT' + LineEnding + '  COLUMNS id INTEGER, naziv TEXT  -- stupci' + LineEnding +
    '  DECLARE c CURSOR FOR SELECT id, naziv FROM partneri WHERE grad = $grad' + LineEnding +
    '  IF aktivan = 1 THEN EMIT 1, "Alfa" END IF' + LineEnding + 'END FUNCTION';
  Ed4.AddError(5, 0, 'primjer greške');
  Gb := TGroupBox.Create(Self); Gb.Parent := Self; Gb.Caption := 'Grupa'; Gb.SetBounds(8, 384, 200, 130);
  Mm := TMemo.Create(Self); Mm.Parent := Self; Mm.SetBounds(X, 488, 770, 100);
  Mm.Lines.Text := 'Memo: višeredni tekst.' + LineEnding + 'Druga linija s brojevima 1.234,56 i znakovima čćšđž.';
  Pnl := TPanel.Create(Self); Pnl.Parent := Gb; Pnl.Align := alClient; Pnl.Caption := 'Panel';
end;

function GrabPng(AForm: TForm; const AFile: string): Boolean;
var
  Pix: QPixmapH;
  WS: WideString;
  R: TRect;
begin
  Result := False;
  Pix := QPixmap_Create();
  try
    R := Rect(0, 0, AForm.Width, AForm.Height);
    QWidget_grab(TQtWidget(AForm.Handle).Widget, Pix, @R);
    WS := UTF8Decode(AFile);
    Result := QPixmap_save(Pix, @WS, 'PNG');
  finally
    QPixmap_Destroy(Pix);
  end;
end;

var
  F: TGalleryForm;
  Dir, Name: string;
  I, K, N, Ok: Integer;
  Sh: TaShape;
  T: TaThemeTokens;
begin
  Application.Initialize;
  Dir := 'out';
  if ParamCount >= 1 then Dir := ParamStr(1);
  ForceDirectories(Dir);
  Application.Scaled := False;
  ApplySavedTheme;
  F := TGalleryForm.CreateGallery;
  F.Show;
  Ok := 0; N := 0;
  for I := 0 to BuiltinThemeCount - 1 do
    for K := 0 to 1 do
      for Sh := Low(TaShape) to High(TaShape) do
      begin
        T := BuiltinTokens(I, K = 1, Sh);
        SetThemeTokens(T, False);
        F.Invalidate;
        Application.ProcessMessages;
        Name := StringReplace(LowerCase(BuiltinThemeName(I)), ' ', '_', [rfReplaceAll]);
        Name := Name + '_' + IfThen(K = 1, 'tamna', 'svijetla') + '_' + ShapeNames[Sh] + '.png';
        Inc(N);
        if GrabPng(F, IncludeTrailingPathDelimiter(Dir) + Name) then Inc(Ok);
      end;
  WriteLn(Ok, ' od ', N, ' snimki spremljeno u ', Dir);
  F.Free;
  if Ok <> N then Halt(1);
end.
