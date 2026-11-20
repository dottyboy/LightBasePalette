unit ta_fglblockdlg;
{ Dijalog "Blok iz baze": izaberes blok iz palete (ta_fglpalette), polja su padajuci popisi iz baze
  (tablice, stupci, programi, forme, varijable i izvjesca iz programa koji se uredjuje),
  pregled pokazuje retke 4GL-a koji ce se umetnuti. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ta_meta, ta_fglpalette;

type
  TfrmPaletteBlock = class(TForm)
  private
    FDb: TAppDb;
    FProgramText: string;
    FList: TListBox;
    FIds: TStringList;           { id bloka po retku popisa ('' za naslov kategorije) }
    FBox: TScrollBox;
    FPreview: TMemo;
    FDesc: TLabel;
    FBlock: TaPBlock;
    FHave: Boolean;
    FValues: TStringList;
    FCtrls: TStringList;
    FUpdating: Boolean;
    procedure ListClick(Sender: TObject);
    procedure SlotChanged(Sender: TObject);
    procedure BuildSlots;
    procedure Sync;
    procedure ShowPreview;
  public
    constructor CreatePicker(AOwner: TComponent; ADb: TAppDb; const AProgramText: string);
    destructor Destroy; override;
    procedure SelectBlock(const AId: string);
    procedure SetSlot(const AName, AValue: string);
    function SlotControl(const AName: string): TControl;
    procedure GetLines(ALines: TStrings);
    property List: TListBox read FList;
    property Preview: TMemo read FPreview;
  end;

{ otvara dijalog; True i ALines = retci za umetanje kad korisnik potvrdi }
function PickPaletteBlock(AOwner: TComponent; ADb: TAppDb; const AProgramText: string; ALines: TStrings): Boolean;

implementation

uses
  ta_i18n;


function PickPaletteBlock(AOwner: TComponent; ADb: TAppDb; const AProgramText: string; ALines: TStrings): Boolean;
var
  D: TfrmPaletteBlock;
begin
  D := TfrmPaletteBlock.CreatePicker(AOwner, ADb, AProgramText);
  try
    Result := (D.ShowModal = mrOk) and D.FHave;
    if Result then D.GetLines(ALines);
  finally
    D.Free;
  end;
end;

constructor TfrmPaletteBlock.CreatePicker(AOwner: TComponent; ADb: TAppDb; const AProgramText: string);
var
  P, Bt: TPanel;
  B: TButton;
  Cats: TStringList;
  I, J: Integer;
  Pb: TaPBlock;
begin
  inherited CreateNew(AOwner);
  FDb := ADb;
  FProgramText := AProgramText;
  FValues := TStringList.Create;
  FCtrls := TStringList.Create;
  FIds := TStringList.Create;
  Caption := Tr('Block from the database');
  SetBounds(0, 0, 820, 560);
  Position := poScreenCenter;
  P := TPanel.Create(Self);
  P.Parent := Self; P.Align := alLeft; P.Width := 260; P.BevelOuter := bvNone;
  FList := TListBox.Create(Self);
  FList.Parent := P; FList.Align := alClient; FList.BorderSpacing.Around := 6;
  FList.OnClick := @ListClick;
  Cats := PaletteCategories;
  try
    for I := 0 to Cats.Count - 1 do
    begin
      FList.Items.Add('▸ ' + Tr(Cats[I]));
      FIds.Add('');
      for J := 0 to PaletteCount - 1 do
      begin
        Pb := PaletteBlock(J);
        if Pb.Cat = Cats[I] then
        begin
          FList.Items.Add('    ' + Tr(Pb.Name));
          FIds.Add(Pb.Id);
        end;
      end;
    end;
  finally
    Cats.Free;
  end;
  Bt := TPanel.Create(Self);
  Bt.Parent := Self; Bt.Align := alBottom; Bt.Height := 44; Bt.BevelOuter := bvNone;
  B := TButton.Create(Self);
  B.Parent := Bt; B.Caption := Tr('Insert block'); B.ModalResult := mrOk; B.SetBounds(12, 8, 140, 30);
  B := TButton.Create(Self);
  B.Parent := Bt; B.Caption := Tr('Cancel'); B.ModalResult := mrCancel; B.SetBounds(162, 8, 120, 30);
  P := TPanel.Create(Self);
  P.Parent := Self; P.Align := alClient; P.BevelOuter := bvNone;
  FDesc := TLabel.Create(Self);
  FDesc.Parent := P; FDesc.Align := alTop; FDesc.AutoSize := False; FDesc.Height := 36;
  FDesc.BorderSpacing.Around := 8; FDesc.WordWrap := True;
  FBox := TScrollBox.Create(Self);
  FBox.Parent := P; FBox.Align := alTop; FBox.Height := 250; FBox.BorderSpacing.Around := 6;
  FPreview := TMemo.Create(Self);
  FPreview.Parent := P; FPreview.Align := alClient; FPreview.BorderSpacing.Around := 6;
  FPreview.ReadOnly := True; FPreview.ScrollBars := ssAutoBoth;
  FDesc.Top := 0;
end;

destructor TfrmPaletteBlock.Destroy;
begin
  FValues.Free;
  FCtrls.Free;
  FIds.Free;
  inherited Destroy;
end;

procedure TfrmPaletteBlock.ListClick(Sender: TObject);
begin
  if (FList.ItemIndex >= 0) and (FList.ItemIndex < FIds.Count) and (FIds[FList.ItemIndex] <> '') then
    SelectBlock(FIds[FList.ItemIndex]);
end;

procedure TfrmPaletteBlock.SelectBlock(const AId: string);
var
  K, I: Integer;
begin
  K := PaletteFind(AId);
  if K < 0 then Exit;
  FBlock := PaletteBlock(K);
  FHave := True;
  FValues.Clear;
  for I := 0 to FIds.Count - 1 do
    if FIds[I] = AId then FList.ItemIndex := I;
  FDesc.Caption := Tr(FBlock.Name) + ': ' + FBlock.Hint;
  BlockDefaults(FDb, FBlock, FValues, FProgramText);
  BuildSlots;
  ShowPreview;
end;

procedure TfrmPaletteBlock.BuildSlots;
var
  I, Y: Integer;
  L: TLabel;
  C: TControl;
begin
  for I := FBox.ControlCount - 1 downto 0 do FBox.Controls[I].Free;
  FCtrls.Clear;
  Y := 4;
  for I := 0 to High(FBlock.Slots) do
  begin
    L := TLabel.Create(FBox);
    L.Parent := FBox; L.Caption := Tr(FBlock.Slots[I].Name); L.SetBounds(8, Y, 400, 18);
    Inc(Y, 20);
    if FBlock.Slots[I].Kind in [pkTekst, pkIzraz] then
    begin
      C := TEdit.Create(FBox);
      C.Parent := FBox; C.SetBounds(12, Y, 480, 26);
      TEdit(C).OnExit := @SlotChanged;
      TEdit(C).OnChange := @SlotChanged;
    end
    else
    begin
      C := TComboBox.Create(FBox);
      C.Parent := FBox; C.SetBounds(12, Y, 480, 28);
      TComboBox(C).Style := csDropDown;
      TComboBox(C).OnChange := @SlotChanged;
    end;
    Inc(Y, 36);
    FCtrls.AddObject(FBlock.Slots[I].Name, C);
  end;
  Sync;
end;

procedure TfrmPaletteBlock.Sync;
var
  I: Integer;
  C: TControl;
  Ch: TStringList;
begin
  FUpdating := True;
  Ch := TStringList.Create;
  try
    for I := 0 to FCtrls.Count - 1 do
    begin
      C := TControl(FCtrls.Objects[I]);
      if C is TEdit then
      begin
        if TEdit(C).Text <> FValues.Values[FCtrls[I]] then TEdit(C).Text := FValues.Values[FCtrls[I]];
      end
      else
      begin
        SlotChoices(FDb, FBlock, FCtrls[I], FValues, FProgramText, Ch);
        TComboBox(C).Items.Assign(Ch);
        TComboBox(C).Text := FValues.Values[FCtrls[I]];
      end;
    end;
  finally
    Ch.Free;
    FUpdating := False;
  end;
end;

procedure TfrmPaletteBlock.SlotChanged(Sender: TObject);
var
  I: Integer;
begin
  if FUpdating then Exit;
  for I := 0 to FCtrls.Count - 1 do
    if TObject(FCtrls.Objects[I]) = Sender then
    begin
      if Sender is TEdit then SetSlot(FCtrls[I], TEdit(Sender).Text)
      else SetSlot(FCtrls[I], TComboBox(Sender).Text);
      Break;
    end;
end;

procedure TfrmPaletteBlock.SetSlot(const AName, AValue: string);
var
  I: Integer;
begin
  FValues.Values[AName] := AValue;
  { utori koji ovise o ovom (stupci o tablici) vracaju se na zadano }
  for I := 0 to High(FBlock.Slots) do
    if SameText(FBlock.Slots[I].Ref, AName) then FValues.Values[FBlock.Slots[I].Name] := '';
  BlockDefaults(FDb, FBlock, FValues, FProgramText);
  Sync;
  ShowPreview;
end;

function TfrmPaletteBlock.SlotControl(const AName: string): TControl;
var
  I: Integer;
begin
  Result := nil;
  I := FCtrls.IndexOf(AName);
  if I >= 0 then Result := TControl(FCtrls.Objects[I]);
end;

procedure TfrmPaletteBlock.GetLines(ALines: TStrings);
begin
  if FHave then RenderBlock(FBlock, FValues, ALines) else ALines.Clear;
end;

procedure TfrmPaletteBlock.ShowPreview;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    GetLines(L);
    FPreview.Lines.Assign(L);
  finally
    L.Free;
  end;
end;

end.
