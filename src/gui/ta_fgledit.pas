unit ta_fgledit;
{ Uredjivac 4GL programa blokovima (faza G): palete naredbi, redovi-blokovi uvuceni po strukturi, prekidac Blokovi / Tekst,
  provjera pravim parserom i pokretanje. Model je TaFglBlocks (ta_fglblocks); redak koji se ne dira ostaje isti. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Dialogs, Graphics, ta_meta, ta_fglblocks, ta_editor, ta_fglpalette, ta_fglblockdlg;

type
  TaFglBlockEditor = class(TPanel)
  private
    FBlocks: TaFglBlocks;
    FPalette: TListBox;
    FScroll: TScrollBox;
    FSel: Integer;
    FOnChange: TNotifyEvent;
    FDb: TAppDb;
    FRebuilding: Boolean;
    FBuiltWidth: Integer;
    procedure Changed;
    procedure Rebuild;
    procedure BuildRow(AIndex: Integer; var ARowTop: Integer);
    procedure LineChange(Sender: TObject);
    procedure UpClick(Sender: TObject);
    procedure DownClick(Sender: TObject);
    procedure DelClick(Sender: TObject);
    procedure RowClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure DbBlockClick(Sender: TObject);
    procedure PaletteDblClick(Sender: TObject);
    procedure AsyncRebuild(Data: PtrInt);
    function BaseDepth: Integer;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetText(const AText: string);
    function GetText: string;
    function RowCount: Integer;
    procedure SelectRow(AIndex: Integer);
    { umetne predlozak AIndex iza odabranog retka, uvucen prema mjestu umetanja }
    procedure AddTemplate(AIndex: Integer);
    procedure DeleteRow(AIndex: Integer);
    procedure MoveRow(AFrom, ATo: Integer);
    property Db: TAppDb read FDb write FDb;
    { umetne retke bloka iz palete s popisima iz baze }
    procedure InsertLines(ALines: TStrings);
    property Selected: Integer read FSel;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Model: TaFglBlocks read FBlocks;
    property Palette: TListBox read FPalette;
    function EditOf(AIndex: Integer): TEdit;
  end;

{ Modalni uredjivac programa; ADb za pokretanje. AFile = '' za novi program. }
procedure EditFglProgram(AOwner: TComponent; ADb: TAppDb; const AFile: string);

implementation

uses
  ta_i18n,
  ta_fgl, ta_fglgui;

const
  RowH = 32;
  ClrPlain = $FFF0DC;
  ClrOpen = $CCFFFF;
  ClrMid = $B8F0FF;
  ClrComment = $E6E6E6;

constructor TaFglBlockEditor.Create(AOwner: TComponent);
var
  P: TPanel;
  I, J: Integer;
  B: TButton;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FBlocks := TaFglBlocks.Create;
  FSel := -1;
  P := TPanel.Create(Self);
  P.Parent := Self;
  P.Align := alLeft;
  P.Width := 270;
  P.BevelOuter := bvNone;
  FPalette := TListBox.Create(Self);
  FPalette.Parent := P;
  FPalette.Align := alClient;
  FPalette.OnDblClick := @PaletteDblClick;
  for J := 0 to FglCategoryCount - 1 do
  begin
    FPalette.Items.Add('▸ ' + Tr(FglCategoryName(J)));
    for I := 0 to FglTemplateCount - 1 do
      if FglTemplate(I).Cat = FglCategoryName(J) then
        FPalette.Items.AddObject('    ' + Tr(FglTemplate(I).Name), TObject(PtrInt(I)));
  end;
  P := TPanel.Create(Self);
  P.Parent := TPanel(FPalette.Parent);
  P.Align := alBottom;
  P.Height := 70;
  P.BevelOuter := bvNone;
  B := TButton.Create(Self);
  B.Parent := P;
  B.SetBounds(2, 4, 262, 28);
  B.Caption := Tr('Add the selected block after the row');
  B.OnClick := @AddClick;
  B := TButton.Create(Self);
  B.Parent := P;
  B.SetBounds(2, 36, 262, 28);
  B.Caption := Tr('Block from the database...');
  B.OnClick := @DbBlockClick;
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsSingle;
  FScroll.HorzScrollBar.Visible := False;
end;

destructor TaFglBlockEditor.Destroy;
begin
  FBlocks.Free;
  inherited Destroy;
end;

procedure TaFglBlockEditor.Changed;
begin
  if (not FRebuilding) and Assigned(FOnChange) then FOnChange(Self);
end;

procedure TaFglBlockEditor.SetText(const AText: string);
begin
  FBlocks.LoadText(AText);
  FSel := -1;
  Rebuild;
end;

function TaFglBlockEditor.GetText: string;
begin
  Result := FBlocks.Text;
end;

function TaFglBlockEditor.RowCount: Integer;
begin
  Result := FBlocks.Count;
end;

function TaFglBlockEditor.EditOf(AIndex: Integer): TEdit;
var
  I, J: Integer;
  C: TControl;
begin
  Result := nil;
  for I := 0 to FScroll.ControlCount - 1 do
  begin
    C := FScroll.Controls[I];
    if (C is TPanel) and (TPanel(C).Tag = AIndex) then
      for J := 0 to TPanel(C).ControlCount - 1 do
        if TPanel(C).Controls[J] is TEdit then Exit(TEdit(TPanel(C).Controls[J]));
  end;
end;

procedure TaFglBlockEditor.Resize;
begin
  inherited Resize;
  if (not FRebuilding) and (FBlocks <> nil) and (FScroll <> nil) and (Abs(FScroll.ClientWidth - FBuiltWidth) > 2) and (FScroll.ClientWidth > 0) then Rebuild;
end;

procedure TaFglBlockEditor.Rebuild;
var
  I, RowTop: Integer;
begin
  FRebuilding := True;
  FBuiltWidth := FScroll.ClientWidth;
  FScroll.DisableAutoSizing;
  try
    for I := FScroll.ComponentCount - 1 downto 0 do FScroll.Components[I].Free;
    for I := FScroll.ControlCount - 1 downto 0 do FScroll.Controls[I].Free;
    RowTop := 4;
    for I := 0 to FBlocks.Count - 1 do BuildRow(I, RowTop);
  finally
    FScroll.EnableAutoSizing;
    FRebuilding := False;
  end;
end;

procedure TaFglBlockEditor.BuildRow(AIndex: Integer; var ARowTop: Integer);
var
  Row: TPanel;
  E: TEdit;
  Btn: TButton;
  Ind, W: Integer;
  Clr: TColor;
  K: TaFglKind;

  function SmallBtn(const ACap: string; AX: Integer; AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Row);
    Result.Parent := Row;
    Result.Caption := ACap;
    Result.SetBounds(AX, 3, 28, 26);
    Result.Anchors := [akTop, akRight];
    Result.Tag := AIndex;
    Result.OnClick := AClick;
  end;

begin
  K := FBlocks.Kind(AIndex);
  Row := TPanel.Create(FScroll);
  Row.Parent := FScroll;
  Row.Tag := AIndex;
  Row.Name := 'frow' + IntToStr(AIndex);
  Row.Caption := '';
  Row.BevelOuter := bvNone;
  Row.Anchors := [akLeft, akTop, akRight];
  Row.OnClick := @RowClick;
  case K of
    fkOpen, fkClose: Clr := ClrOpen;
    fkMid: Clr := ClrMid;
    fkComment, fkBlank: Clr := ClrComment;
  else
    Clr := ClrPlain;
  end;
  Row.Color := Clr;
  Ind := FBlocks.Depth(AIndex) * 22;
  Row.SetBounds(4 + Ind, ARowTop, FScroll.ClientWidth - 8 - Ind, RowH);
  if AIndex = FSel then Row.BorderStyle := bsSingle;
  Inc(ARowTop, RowH + 2);
  W := Row.Width;
  E := TEdit.Create(Row);
  E.Parent := Row;
  E.Tag := AIndex;
  E.Name := 'fl' + IntToStr(AIndex);
  E.Text := Trim(FBlocks.Raw(AIndex));
  E.SetBounds(6, 3, W - 6 - 100, 26);
  E.Anchors := [akLeft, akTop, akRight];
  E.Font.Name := 'DejaVu Sans Mono';
  if K in [fkOpen, fkClose, fkMid] then E.Font.Style := [fsBold];
  E.OnChange := @LineChange;
  E.OnEnter := @RowClick;
  SmallBtn('✕', W - 32, @DelClick);
  SmallBtn('↓', W - 62, @DownClick);
  SmallBtn('↑', W - 92, @UpClick);
  if Btn = nil then;
end;

procedure TaFglBlockEditor.AsyncRebuild(Data: PtrInt);
begin
  Rebuild;
end;

procedure TaFglBlockEditor.LineChange(Sender: TObject);
var
  I, D: Integer;
  OldK: TaFglKind;
  OldD: Integer;
begin
  if FRebuilding then Exit;
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FBlocks.Count) then Exit;
  OldK := FBlocks.Kind(I);
  OldD := FBlocks.Depth(I);
  D := OldD;
  FBlocks.SetRaw(I, StringOfChar(' ', 2 * D) + Trim(TEdit(Sender).Text));
  FSel := I;
  Changed;
  { ako je redak postao ili prestao biti pocetak/kraj strukture, uvlake ostalih redaka se mijenjaju }
  if (FBlocks.Kind(I) <> OldK) or (FBlocks.Depth(I) <> OldD) then Application.QueueAsyncCall(@AsyncRebuild, 0);
end;

procedure TaFglBlockEditor.RowClick(Sender: TObject);
begin
  if FRebuilding then Exit;
  if Sender is TControl then SelectRow(TControl(Sender).Tag);
end;

procedure TaFglBlockEditor.SelectRow(AIndex: Integer);
var
  I: Integer;
begin
  if (AIndex < 0) or (AIndex >= FBlocks.Count) then Exit;
  FSel := AIndex;
  for I := 0 to FScroll.ControlCount - 1 do
    if FScroll.Controls[I] is TPanel then
      if TPanel(FScroll.Controls[I]).Tag = AIndex then TPanel(FScroll.Controls[I]).BorderStyle := bsSingle
      else TPanel(FScroll.Controls[I]).BorderStyle := bsNone;
end;

procedure TaFglBlockEditor.UpClick(Sender: TObject);
begin
  MoveRow(TControl(Sender).Tag, TControl(Sender).Tag - 1);
end;

procedure TaFglBlockEditor.DownClick(Sender: TObject);
begin
  MoveRow(TControl(Sender).Tag, TControl(Sender).Tag + 1);
end;

procedure TaFglBlockEditor.DelClick(Sender: TObject);
begin
  DeleteRow(TControl(Sender).Tag);
end;

{ uvlaka novog retka: unutar odabranog otvaraca/srednjeg dijela, inace u razini odabranog retka }
function TaFglBlockEditor.BaseDepth: Integer;
begin
  if (FSel < 0) or (FSel >= FBlocks.Count) then Exit(0);
  case FBlocks.Kind(FSel) of
    fkOpen, fkMid: Result := FBlocks.Depth(FSel) + 1;
  else
    Result := FBlocks.Depth(FSel);
  end;
end;

procedure TaFglBlockEditor.AddTemplate(AIndex: Integer);
var
  L: TStringList;
  I, At, D: Integer;
begin
  if (AIndex < 0) or (AIndex >= FglTemplateCount) then Exit;
  L := TStringList.Create;
  try
    FglTemplateLines(AIndex, L);
    D := BaseDepth;
    if (FSel < 0) or (FSel >= FBlocks.Count) then At := FBlocks.Count else At := FSel + 1;
    for I := 0 to L.Count - 1 do
      FBlocks.InsertLine(At + I, StringOfChar(' ', 2 * D) + L[I]);
    FSel := At;
  finally
    L.Free;
  end;
  Rebuild;
  Changed;
end;

procedure TaFglBlockEditor.InsertLines(ALines: TStrings);
var
  I, At, D: Integer;
begin
  D := BaseDepth;
  if (FSel < 0) or (FSel >= FBlocks.Count) then At := FBlocks.Count else At := FSel + 1;
  for I := 0 to ALines.Count - 1 do
    FBlocks.InsertLine(At + I, StringOfChar(' ', 2 * D) + ALines[I]);
  FSel := At;
  Rebuild;
  Changed;
end;

procedure TaFglBlockEditor.DbBlockClick(Sender: TObject);
var
  L: TStringList;
begin
  if FDb = nil then begin ShowMessage(Tr('There is no open database.')); Exit; end;
  L := TStringList.Create;
  try
    if PickPaletteBlock(Self, FDb, FBlocks.Text, L) then InsertLines(L);
  finally
    L.Free;
  end;
end;

procedure TaFglBlockEditor.AddClick(Sender: TObject);
begin
  PaletteDblClick(Sender);
end;

procedure TaFglBlockEditor.PaletteDblClick(Sender: TObject);
begin
  if FPalette.ItemIndex < 0 then Exit;
  if Pos('▸', Trim(FPalette.Items[FPalette.ItemIndex])) = 1 then Exit;
  AddTemplate(PtrInt(FPalette.Items.Objects[FPalette.ItemIndex]));
end;

procedure TaFglBlockEditor.DeleteRow(AIndex: Integer);
var
  Cl: Integer;
begin
  if (AIndex < 0) or (AIndex >= FBlocks.Count) then Exit;
  { brisanje pocetka strukture brise i njezin kraj (sadrzaj ostaje) }
  if FBlocks.Kind(AIndex) = fkOpen then
  begin
    Cl := FBlocks.CloserOf(AIndex);
    if Cl >= 0 then FBlocks.DeleteLine(Cl);
  end;
  FBlocks.DeleteLine(AIndex);
  if FSel >= FBlocks.Count then FSel := FBlocks.Count - 1;
  Rebuild;
  Changed;
end;

procedure TaFglBlockEditor.MoveRow(AFrom, ATo: Integer);
begin
  if (AFrom < 0) or (AFrom >= FBlocks.Count) or (ATo < 0) or (ATo >= FBlocks.Count) or (AFrom = ATo) then Exit;
  FBlocks.MoveLine(AFrom, ATo);
  FSel := ATo;
  Rebuild;
  Changed;
end;

{ ---------------- dijalog ---------------- }

type
  TFglDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    Memo: TaEditor;
    Blocks: TaFglBlockEditor;
    Status: TLabel;
    ModeBtn: TButton;
    FileName: string;
    Dirty: Boolean;
    procedure ModeClick(Sender: TObject);
    procedure SyncText;
    procedure NewClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SaveAsClick(Sender: TObject);
    procedure FromDbClick(Sender: TObject);
    procedure ToDbClick(Sender: TObject);
    procedure CheckClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure EditChanged(Sender: TObject);
    procedure SetFile(const AName: string);
    function DoCheck: Boolean;
    function SaveTo(const AName: string): Boolean;
  end;

procedure TFglDlg.SyncText;
begin
  if Blocks.Visible then Memo.Text := Blocks.GetText;
end;

procedure TFglDlg.SetFile(const AName: string);
begin
  FileName := AName;
  if AName = '' then Form.Caption := Tr('4GL program (new)')
  else if Copy(AName, 1, 3) = 'db:' then Form.Caption := Tr('4GL program in the database: ') + Copy(AName, 4, MaxInt)
  else Form.Caption := Tr('4GL program: ') + AName;
end;

procedure TFglDlg.EditChanged(Sender: TObject);
begin
  Dirty := True;
end;

procedure TFglDlg.ModeClick(Sender: TObject);
begin
  if Blocks.Visible then
  begin
    Memo.Text := Blocks.GetText;
    Blocks.Visible := False;
    Memo.Visible := True;
    ModeBtn.Caption := Tr('Blocks');
  end
  else
  begin
    Blocks.SetText(Memo.Text);
    Memo.Visible := False;
    Blocks.SetBounds(10, 46, Form.ClientWidth - 20, Form.ClientHeight - 100);
    Blocks.Visible := True;
    ModeBtn.Caption := Tr('Text');
  end;
end;

function TFglDlg.DoCheck: Boolean;
var
  P: TaFglProgram;
  Lg, Pr: TStringList;
begin
  SyncText;
  P := TaFglProgram.Create;
  Lg := TStringList.Create;
  try
    Result := False;
    try
      P.LoadText(Memo.Text, 'program');
      Result := P.CheckProgram(Lg) = 0;
    except
      on E: Exception do Lg.Add(E.Message);
    end;
    Pr := Blocks.Model.Problems;
    try
      if Blocks.Visible and (Pr.Count > 0) then begin Result := False; Lg.AddStrings(Pr); end;
    finally
      Pr.Free;
    end;
    Memo.SetErrorsFromLog(Lg);
    AnnotateLog(Memo.Text, Lg);
    if Result then
    begin
      Status.Caption := Tr('The program is valid.');
      Status.Font.Color := clGreen;
    end
    else
    begin
      Status.Caption := Trim(Lg.Text);
      Status.Font.Color := clMaroon;
    end;
  finally
    Lg.Free;
    P.Free;
  end;
end;

procedure TFglDlg.CheckClick(Sender: TObject);
begin
  DoCheck;
end;

procedure TFglDlg.RunClick(Sender: TObject);
begin
  if not DoCheck then Exit;
  RunFglText(Db, Memo.Text, False);
end;

function TFglDlg.SaveTo(const AName: string): Boolean;
begin
  Result := False;
  SyncText;
  try
    if Copy(AName, 1, 3) = 'db:' then Db.SaveObject('_sys_programs', Copy(AName, 4, MaxInt), Memo.Text)
    else Memo.Lines.SaveToFile(AName);
    SetFile(AName);
    Dirty := False;
    Status.Caption := Tr('Saved: ') + AName;
    Status.Font.Color := clGreen;
    Result := True;
  except
    on E: Exception do ShowMessage(Tr('Saving failed: ') + E.Message);
  end;
end;

{ izbor jednog naziva s popisa }
function PickName(AOwner: TComponent; const ATitle: string; AItems: TStrings): string;
var
  F: TForm;
  L: TListBox;
  B: TButton;
begin
  Result := '';
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := ATitle;
    F.Position := poOwnerFormCenter;
    F.SetBounds(0, 0, 420, 420);
    L := TListBox.Create(F);
    L.Parent := F;
    L.SetBounds(10, 10, 400, 330);
    L.Items.Assign(AItems);
    L.ItemIndex := 0;
    B := TButton.Create(F); B.Parent := F; B.Caption := Tr('OK'); B.SetBounds(220, 360, 90, 30); B.ModalResult := mrOk; B.Default := True;
    B := TButton.Create(F); B.Parent := F; B.Caption := Tr('Cancel'); B.SetBounds(320, 360, 90, 30); B.ModalResult := mrCancel; B.Cancel := True;
    if (F.ShowModal = mrOk) and (L.ItemIndex >= 0) then Result := L.Items[L.ItemIndex];
  finally
    F.Free;
  end;
end;

procedure TFglDlg.FromDbClick(Sender: TObject);
var
  L: TStringList;
  N: string;
begin
  if Dirty and (MessageDlg(Tr('Discard unsaved changes?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  L := Db.ListObjects('_sys_programs');
  try
    if L.Count = 0 then begin ShowMessage(Tr('There are no saved 4GL programs in the database.')); Exit; end;
    N := PickName(Form, '4GL programi u bazi', L);
  finally
    L.Free;
  end;
  if N = '' then Exit;
  Memo.Text := Db.LoadObject('_sys_programs', N);
  if Blocks.Visible then Blocks.SetText(Memo.Text);
  SetFile('db:' + N);
  Dirty := False;
end;

procedure TFglDlg.ToDbClick(Sender: TObject);
var
  N: string;
begin
  N := '';
  if Copy(FileName, 1, 3) = 'db:' then N := Copy(FileName, 4, MaxInt);
  if not InputQuery(Tr('Save to the database'), Tr('Program name:'), N) then Exit;
  N := Trim(N);
  if N = '' then Exit;
  SaveTo('db:' + N);
end;

procedure TFglDlg.SaveClick(Sender: TObject);
begin
  if FileName = '' then SaveAsClick(Sender) else SaveTo(FileName);
end;

procedure TFglDlg.SaveAsClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(nil);
  try
    D.Filter := '4GL program (*.4gl)|*.4gl';
    D.DefaultExt := '4gl';
    D.Options := D.Options + [ofOverwritePrompt];
    if FileName <> '' then D.FileName := FileName;
    if D.Execute then SaveTo(D.FileName);
  finally
    D.Free;
  end;
end;

procedure TFglDlg.NewClick(Sender: TObject);
begin
  if Dirty and (MessageDlg(Tr('Discard unsaved changes?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  Memo.Text := 'MAIN' + LineEnding + '  DISPLAY "Pozdrav"' + LineEnding + 'END MAIN' + LineEnding;
  if Blocks.Visible then Blocks.SetText(Memo.Text);
  SetFile('');
  Dirty := False;
end;

procedure TFglDlg.OpenClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  if Dirty and (MessageDlg(Tr('Discard unsaved changes?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  D := TOpenDialog.Create(nil);
  try
    D.Filter := Tr('4GL program (*.4gl)|*.4gl|All files|*');
    if not D.Execute then Exit;
    Memo.Lines.LoadFromFile(D.FileName);
    if Blocks.Visible then Blocks.SetText(Memo.Text);
    SetFile(D.FileName);
    Dirty := False;
  finally
    D.Free;
  end;
end;

procedure EditFglProgram(AOwner: TComponent; ADb: TAppDb; const AFile: string);
var
  D: TFglDlg;

  function Bt(const ACap: string; X, W: Integer; AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(D.Form);
    Result.Parent := D.Form;
    Result.Caption := ACap;
    Result.SetBounds(X, 8, W, 30);
    Result.OnClick := AClick;
  end;

begin
  D := TFglDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.SetBounds(0, 0, 1100, 720);
    D.Form.Position := poOwnerFormCenter;
    Bt(Tr('New item'), 10, 70, @D.NewClick);
    Bt(Tr('Open...'), 84, 90, @D.OpenClick);
    Bt(Tr('Save'), 178, 90, @D.SaveClick);
    Bt(Tr('Save as…'), 272, 110, @D.SaveAsClick);
    Bt(Tr('Check'), 392, 90, @D.CheckClick);
    Bt(Tr('Run'), 486, 90, @D.RunClick);
    D.ModeBtn := Bt(Tr('Blocks'), 590, 90, @D.ModeClick);
    Bt(Tr('From database…'), 690, 100, @D.FromDbClick);
    Bt(Tr('To database…'), 794, 100, @D.ToDbClick);
    D.Memo := TaEditor.Create(D.Form);
    D.Memo.Parent := D.Form;
    D.Memo.Variant := ewFgl;
    D.Memo.SetBounds(10, 46, 1080, 620);
    D.Memo.Anchors := [akLeft, akTop, akRight, akBottom];
    if ADb <> nil then D.Memo.LoadWordsFromDb(ADb);
    D.Memo.OnChange := @D.EditChanged;
    D.Blocks := TaFglBlockEditor.Create(D.Form);
    D.Blocks.Parent := D.Form;
    D.Blocks.SetBounds(10, 46, 1080, 620);
    D.Blocks.Anchors := [akLeft, akTop, akRight, akBottom];
    D.Blocks.OnChange := @D.EditChanged;
    D.Blocks.Db := ADb;
    D.Blocks.Visible := False;
    D.Status := TLabel.Create(D.Form);
    D.Status.Parent := D.Form;
    D.Status.SetBounds(10, 672, 1080, 40);
    D.Status.Anchors := [akLeft, akBottom, akRight];
    D.Status.WordWrap := True;
    if (Copy(AFile, 1, 3) = 'db:') and (ADb.LoadObject('_sys_programs', Copy(AFile, 4, MaxInt)) <> '') then
    begin
      D.Memo.Text := ADb.LoadObject('_sys_programs', Copy(AFile, 4, MaxInt));
      D.SetFile(AFile);
    end
    else if (AFile <> '') and FileExists(AFile) then
    begin
      D.Memo.Lines.LoadFromFile(AFile);
      D.SetFile(AFile);
    end
    else
    begin
      D.Memo.Text := 'MAIN' + LineEnding + '  DISPLAY "Pozdrav"' + LineEnding + 'END MAIN' + LineEnding;
      D.SetFile('');
    end;
    D.Dirty := False;
    D.ModeClick(nil);       { počinje u prikazu blokova }
    D.Dirty := False;
    D.Form.ShowModal;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

end.
