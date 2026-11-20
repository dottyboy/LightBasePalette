unit ta_blockedit;
{ Uredjivac blokova za makroe (faza G.2): palette naredbi lijevo, redovi-blokovi desno.
  Model je TaBlockProgram (ta_blocks); ovaj panel samo prikazuje i mijenja njega.
  Blok se premjesta strelicama ili povlacenjem rucke (☰) na drugi redak. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  ta_meta, ta_blocks, ta_exprbuilder;

type
  TaBlockEditor = class(TPanel)
  private
    FProg: TaBlockProgram;
    FDb: TAppDb;
    FPalette: TListBox;
    FScroll: TScrollBox;
    FSel: Integer;
    FOnChange: TNotifyEvent;
    FRebuilding: Boolean;
    FBuiltWidth: Integer;
    FForms, FReports, FMacros, FProcs: TStringList;
    procedure Changed;
    procedure Rebuild;
  protected
    procedure Resize; override;
  private
    procedure BuildRow(AIndex: Integer; var ATop: Integer);
    function RowValues(AKind: TaBlockArg): TStringList;
    procedure ArgChange(Sender: TObject);
    procedure CondChange(Sender: TObject);
    procedure VerbChange(Sender: TObject);
    procedure CommentChange(Sender: TObject);
    procedure UpClick(Sender: TObject);
    procedure DownClick(Sender: TObject);
    procedure DelClick(Sender: TObject);
    procedure RowClick(Sender: TObject);
    procedure BuilderClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure AddIfClick(Sender: TObject);
    procedure AddCommentClick(Sender: TObject);
    procedure AddStopClick(Sender: TObject);
    procedure AddIfBlockClick(Sender: TObject);
    procedure AddWhileClick(Sender: TObject);
    procedure AddRepeatClick(Sender: TObject);
    procedure AddLetClick(Sender: TObject);
    procedure PaletteDblClick(Sender: TObject);
    procedure RowDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure RowDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure AsyncMove(Data: PtrInt);
    function InsertPos: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { baza daje popise formi/izvjesca/makroa za padajuce izbore (moze biti nil) }
    procedure SetDb(ADb: TAppDb);
    procedure SetProcs(AList: TStrings);
    procedure SetText(const AText: string);
    function GetText: string;
    function RowCount: Integer;
    procedure AddVerb(const AVerb: string);
    procedure AddIf;
    procedure AddComment;
    procedure AddStop;
    procedure AddIfBlock;
    procedure AddWhile;
    procedure AddRepeat;
    procedure AddLet;
    procedure DeleteRow(AIndex: Integer);
    procedure MoveRow(AFromIndex, AToIndex: Integer);
    procedure SelectRow(AIndex: Integer);
    property Selected: Integer read FSel;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    { za testove }
    function ArgControl(AIndex: Integer): TControl;
    function CondControl(AIndex: Integer): TControl;
    property Palette: TListBox read FPalette;
    property Program_: TaBlockProgram read FProg;
  end;

implementation

uses
  ta_i18n;


const
  RowH = 36;
  ClrCmd = $FFF0DC;      { svijetlo plava (BGR) }
  ClrIf = $D2E6FF;       { svijetlo narancasta }
  ClrStop = $D4D4FF;     { svijetlo crvena }
  ClrCom = $E6E6E6;      { siva }
  ClrFlow = $CCFFFF;     { svijetlo zuta: uvjeti i petlje }
  ClrLet = $D8F5D8;      { svijetlo zelena: varijable }

constructor TaBlockEditor.Create(AOwner: TComponent);
var
  P: TPanel;
  B: TButton;
  I, J: Integer;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FProg := TaBlockProgram.Create;
  FForms := TStringList.Create;
  FReports := TStringList.Create;
  FMacros := TStringList.Create;
  FProcs := TStringList.Create;
  FSel := -1;
  P := TPanel.Create(Self);
  P.Parent := Self;
  P.Align := alLeft;
  P.Width := 250;
  P.BevelOuter := bvNone;
  FPalette := TListBox.Create(Self);
  FPalette.Parent := P;
  FPalette.Align := alClient;
  FPalette.Hint := Tr('Double-click adds the command after the selected block');
  FPalette.ShowHint := True;
  FPalette.OnDblClick := @PaletteDblClick;
  for J := 0 to BlockCategoryCount - 1 do
  begin
    FPalette.Items.Add('▸ ' + BlockCategoryName(J));
    for I := 0 to BlockVerbCount - 1 do
      if BlockVerbCategory(BlockVerbName(I)) = BlockCategoryName(J) then
        FPalette.Items.Add('    ' + BlockVerbName(I) + '  –  ' + BlockVerbHint(BlockVerbName(I)));
  end;
  { gumbi ispod palete }
  P := TPanel.Create(Self);
  P.Parent := TPanel(FPalette.Parent);
  P.Align := alBottom;
  P.Height := 8 * 30 + 6;
  P.BevelOuter := bvNone;
  B := TButton.Create(Self); B.Parent := P; B.SetBounds(2, 2, 244, 28); B.Caption := Tr('Add command'); B.OnClick := @AddClick;
  B := TButton.Create(Self); B.Parent := P; B.SetBounds(2, 32, 244, 28); B.Caption := Tr('Condition: if ... else'); B.OnClick := @AddIfBlockClick;
  B := TButton.Create(Self); B.Parent := P; B.SetBounds(2, 62, 244, 28); B.Caption := Tr('Loop: while true'); B.OnClick := @AddWhileClick;
  B := TButton.Create(Self); B.Parent := P; B.SetBounds(2, 92, 244, 28); B.Caption := Tr('Loop: repeat n times'); B.OnClick := @AddRepeatClick;
  B := TButton.Create(Self); B.Parent := P; B.SetBounds(2, 122, 244, 28); B.Caption := Tr('Variable (let)'); B.OnClick := @AddLetClick;
  B := TButton.Create(Self); B.Parent := P; B.SetBounds(2, 152, 244, 28); B.Caption := Tr('Short condition'); B.OnClick := @AddIfClick;
  B := TButton.Create(Self); B.Parent := P; B.SetBounds(2, 182, 244, 28); B.Caption := Tr('Comment'); B.OnClick := @AddCommentClick;
  B := TButton.Create(Self); B.Parent := P; B.SetBounds(2, 212, 244, 28); B.Caption := Tr('Stop'); B.OnClick := @AddStopClick;
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsSingle;
  FScroll.HorzScrollBar.Visible := False;
end;

destructor TaBlockEditor.Destroy;
begin
  FProg.Free;
  FForms.Free; FReports.Free; FMacros.Free; FProcs.Free;
  inherited Destroy;
end;

procedure TaBlockEditor.SetDb(ADb: TAppDb);
var
  L: TStringList;
begin
  FDb := ADb;
  FForms.Clear; FReports.Clear; FMacros.Clear;
  if (ADb = nil) or not ADb.Connected then Exit;
  L := ADb.ListObjects('_sys_forms'); try FForms.Assign(L); finally L.Free; end;
  L := ADb.ListObjects('_sys_reports'); try FReports.Assign(L); finally L.Free; end;
  L := ADb.ListObjects('_sys_macros'); try FMacros.Assign(L); finally L.Free; end;
end;

procedure TaBlockEditor.SetProcs(AList: TStrings);
begin
  FProcs.Clear;
  if AList <> nil then FProcs.Assign(AList);
end;

procedure TaBlockEditor.SetText(const AText: string);
begin
  FProg.LoadText(AText);
  FSel := -1;
  Rebuild;
end;

function TaBlockEditor.GetText: string;
begin
  Result := FProg.Text;
end;

function TaBlockEditor.RowCount: Integer;
begin
  Result := FProg.Count;
end;

procedure TaBlockEditor.Changed;
begin
  if (not FRebuilding) and Assigned(FOnChange) then FOnChange(Self);
end;

function TaBlockEditor.RowValues(AKind: TaBlockArg): TStringList;
begin
  case AKind of
    baForm: Result := FForms;
    baReport: Result := FReports;
    baMacro: Result := FMacros;
    baProc: Result := FProcs;
  else
    Result := nil;
  end;
end;

{ pri promjeni sirine redovi se ponovo slazu, da gumbi i polja ostanu uz desni rub }
procedure TaBlockEditor.Resize;
begin
  inherited Resize;
  if (not FRebuilding) and (FProg <> nil) and (FScroll <> nil) and (Abs(FScroll.ClientWidth - FBuiltWidth) > 2) and (FScroll.ClientWidth > 0) then Rebuild;
end;

procedure TaBlockEditor.Rebuild;
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
    for I := 0 to FProg.Count - 1 do BuildRow(I, RowTop);
  finally
    FScroll.EnableAutoSizing;
    FRebuilding := False;
  end;
end;

procedure TaBlockEditor.BuildRow(AIndex: Integer; var ATop: Integer);
var
  B: TaBlock;
  Row: TPanel;
  L: TLabel;
  E: TEdit;
  C: TComboBox;
  Btn: TButton;
  X, W, I, Ind: Integer;
  AK: TaBlockArg;
  Vals: TStringList;
  Clr: TColor;

  function Lbl(const ACaption: string; AX, AW: Integer; ABold: Boolean): TLabel;
  begin
    Result := TLabel.Create(Row);
    Result.Parent := Row;
    Result.Caption := ACaption;
    Result.SetBounds(AX, 9, AW, 18);
    Result.Font.Color := clBlack;
    if ABold then Result.Font.Style := [fsBold];
    Result.Tag := AIndex;
    Result.OnClick := @RowClick;
  end;

  procedure ArgEdit(AX, AW: Integer; AKind: TaBlockArg);
  begin
    Vals := RowValues(AKind);
    if (Vals <> nil) and (Vals.Count > 0) then
    begin
      C := TComboBox.Create(Row);
      C.Parent := Row;
      C.Style := csDropDown;
      C.Items.Assign(Vals);
      C.SetBounds(AX, 4, AW, 28);
      C.Tag := AIndex;
      C.Name := 'arg' + IntToStr(AIndex);
      C.Text := B.Arg;
      C.OnChange := @ArgChange;
    end
    else
    begin
      E := TEdit.Create(Row);
      E.Parent := Row;
      E.SetBounds(AX, 4, AW, 28);
      E.Tag := AIndex;
      E.Name := 'arg' + IntToStr(AIndex);
      E.Text := B.Arg;
      E.OnChange := @ArgChange;
      E.OnEnter := @RowClick;
    end;
  end;

  procedure CondEdit(AX, AW: Integer);
  begin
    E := TEdit.Create(Row);
    E.Parent := Row;
    E.SetBounds(AX, 4, AW, 28);
    E.Tag := AIndex;
    E.Name := 'cond' + IntToStr(AIndex);
    E.Text := B.Cond;
    E.OnChange := @CondChange;
    E.OnEnter := @RowClick;
    Btn := TButton.Create(Row); Btn.Parent := Row; Btn.Caption := 'ƒx'; Btn.SetBounds(AX + AW + 4, 4, 32, 28); Btn.Tag := AIndex; Btn.Name := 'fx' + IntToStr(AIndex); Btn.OnClick := @BuilderClick;
    Btn.Hint := Tr('Expression builder'); Btn.ShowHint := True;
  end;

begin
  B := FProg[AIndex];
  Row := TPanel.Create(FScroll);
  Row.Parent := FScroll;
  Row.Tag := AIndex;
  Row.Name := 'row' + IntToStr(AIndex);
  Row.Caption := '';
  Row.BevelOuter := bvNone;
  Row.Anchors := [akLeft, akTop, akRight];
  Row.OnClick := @RowClick;
  Row.OnDragOver := @RowDragOver;
  Row.OnDragDrop := @RowDragDrop;
  case B.Kind of
    bkIf: Clr := ClrIf;
    bkStop: Clr := ClrStop;
    bkComment, bkBlank: Clr := ClrCom;
    bkIfBlock, bkElse, bkEndIf, bkWhile, bkEndWhile, bkRepeat, bkEndRepeat: Clr := ClrFlow;
    bkLet: Clr := ClrLet;
  else
    Clr := ClrCmd;
  end;
  Row.Color := Clr;
  Ind := FProg.Depth(AIndex) * 24;
  if B.Kind = bkBlank then Row.SetBounds(4 + Ind, ATop, FScroll.ClientWidth - 8 - Ind, 14)
  else Row.SetBounds(4 + Ind, ATop, FScroll.ClientWidth - 8 - Ind, RowH);
  if AIndex = FSel then Row.BorderStyle := bsSingle;
  Inc(ATop, Row.Height + 3);
  W := Row.Width;
  { rucka za povlacenje }
  L := Lbl('☰', 6, 18, False);
  L.Name := 'handle' + IntToStr(AIndex);
  L.Cursor := crSizeAll;
  L.DragMode := dmAutomatic;
  L.Hint := Tr('Drag to another block');
  L.ShowHint := True;
  if B.Kind <> bkBlank then
  begin
    Btn := TButton.Create(Row); Btn.Parent := Row; Btn.Caption := '✕'; Btn.SetBounds(W - 34, 4, 30, 28); Btn.Anchors := [akTop, akRight]; Btn.Tag := AIndex; Btn.OnClick := @DelClick; Btn.Hint := Tr('Delete block'); Btn.ShowHint := True;
    Btn := TButton.Create(Row); Btn.Parent := Row; Btn.Caption := '↓'; Btn.SetBounds(W - 66, 4, 30, 28); Btn.Anchors := [akTop, akRight]; Btn.Tag := AIndex; Btn.OnClick := @DownClick; Btn.Hint := Tr('Down'); Btn.ShowHint := True;
    Btn := TButton.Create(Row); Btn.Parent := Row; Btn.Caption := '↑'; Btn.SetBounds(W - 98, 4, 30, 28); Btn.Anchors := [akTop, akRight]; Btn.Tag := AIndex; Btn.OnClick := @UpClick; Btn.Hint := Tr('Up'); Btn.ShowHint := True;
  end;
  X := 32;
  case B.Kind of
    bkBlank:
      begin
        Lbl('', 32, 10, False);
      end;
    bkStop:
      Lbl(Tr('stop - end the macro'), X, 220, True);
    bkIfBlock:
      begin
        Lbl(Tr('if'), X, 30, True);
        CondEdit(X + 34, 260);
      end;
    bkElse:
      Lbl(Tr('else'), X, 120, True);
    bkEndIf:
      Lbl(Tr('end if'), X, 120, False);
    bkWhile:
      begin
        Lbl(Tr('while'), X, 96, True);
        CondEdit(X + 102, 260);
      end;
    bkEndWhile:
      Lbl(Tr('end loop'), X, 120, False);
    bkRepeat:
      begin
        Lbl(Tr('repeat'), X, 50, True);
        E := TEdit.Create(Row);
        E.Parent := Row;
        E.SetBounds(X + 56, 4, 70, 28);
        E.Tag := AIndex;
        E.Name := 'cond' + IntToStr(AIndex);
        E.Text := B.Cond;
        E.OnChange := @CondChange;
        E.OnEnter := @RowClick;
        Lbl(Tr('times'), X + 132, 40, False);
      end;
    bkEndRepeat:
      Lbl(Tr('end loop'), X, 120, False);
    bkLet:
      begin
        Lbl(Tr('variable'), X, 76, True);
        E := TEdit.Create(Row);
        E.Parent := Row;
        E.SetBounds(X + 82, 4, 110, 28);
        E.Tag := AIndex;
        E.Name := 'arg' + IntToStr(AIndex);
        E.Text := B.Arg;
        E.OnChange := @ArgChange;
        E.OnEnter := @RowClick;
        Lbl('=', X + 198, 14, True);
        CondEdit(X + 216, 240);
      end;
    bkComment:
      begin
        Lbl(B.Mark, X, 24, True);
        E := TEdit.Create(Row);
        E.Parent := Row;
        E.SetBounds(X + 28, 4, W - X - 28 - 108, 28);
        E.Anchors := [akLeft, akTop, akRight];
        E.Tag := AIndex;
        E.Name := 'com' + IntToStr(AIndex);
        E.Text := B.Text;
        E.OnChange := @CommentChange;
        E.OnEnter := @RowClick;
      end;
    bkCommand:
      begin
        Lbl(B.Verb, X, 90, True);
        AK := BlockVerbArg(B.Verb);
        if not BlockVerbKnown(B.Verb) then
        begin
          Lbl(Tr('(unknown command)'), X + 94, 150, False);
          AK := baText;
        end;
        if AK <> baNone then
        begin
          ArgEdit(X + 96, W - X - 96 - 108 - 34, AK);
          if AK in [baExpr] then
          begin
            Btn := TButton.Create(Row); Btn.Parent := Row; Btn.Caption := 'ƒx'; Btn.SetBounds(W - 108 - 34 + 2, 4, 32, 28); Btn.Anchors := [akTop, akRight]; Btn.Tag := AIndex; Btn.Name := 'fx' + IntToStr(AIndex); Btn.OnClick := @BuilderClick;
            Btn.Hint := Tr('Expression builder'); Btn.ShowHint := True;
          end;
        end;
      end;
    bkIf:
      begin
        Lbl(Tr('if'), X, 30, True);
        E := TEdit.Create(Row);
        E.Parent := Row;
        E.SetBounds(X + 34, 4, 190, 28);
        E.Tag := AIndex;
        E.Name := 'cond' + IntToStr(AIndex);
        E.Text := B.Cond;
        E.OnChange := @CondChange;
        E.OnEnter := @RowClick;
        Btn := TButton.Create(Row); Btn.Parent := Row; Btn.Caption := 'ƒx'; Btn.SetBounds(X + 228, 4, 32, 28); Btn.Tag := AIndex; Btn.Name := 'fx' + IntToStr(AIndex); Btn.OnClick := @BuilderClick;
        Btn.Hint := Tr('Expression builder'); Btn.ShowHint := True;
        Lbl(Tr('then'), X + 266, 36, True);
        C := TComboBox.Create(Row);
        C.Parent := Row;
        C.Style := csDropDownList;
        for I := 0 to BlockVerbCount - 1 do C.Items.Add(BlockVerbName(I));
        C.ItemIndex := C.Items.IndexOf(B.Verb);
        C.SetBounds(X + 306, 4, 110, 28);
        C.Tag := AIndex;
        C.Name := 'verb' + IntToStr(AIndex);
        C.OnChange := @VerbChange;
        AK := BlockVerbArg(B.Verb);
        if AK <> baNone then ArgEdit(X + 422, W - X - 422 - 108, AK);
      end;
  end;
end;

procedure TaBlockEditor.ArgChange(Sender: TObject);
var
  I: Integer;
begin
  if FRebuilding then Exit;
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FProg.Count) then Exit;
  if Sender is TEdit then FProg[I].Arg := TEdit(Sender).Text
  else if Sender is TComboBox then FProg[I].Arg := TComboBox(Sender).Text;
  FProg[I].Touch;
  FSel := I;
  Changed;
end;

procedure TaBlockEditor.CondChange(Sender: TObject);
var
  I: Integer;
begin
  if FRebuilding then Exit;
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FProg.Count) then Exit;
  FProg[I].Cond := TEdit(Sender).Text;
  FProg[I].Touch;
  FSel := I;
  Changed;
end;

procedure TaBlockEditor.VerbChange(Sender: TObject);
var
  I: Integer;
  C: TComboBox;
begin
  if FRebuilding then Exit;
  C := TComboBox(Sender);
  I := C.Tag;
  if (I < 0) or (I >= FProg.Count) or (C.ItemIndex < 0) then Exit;
  FProg[I].Verb := C.Items[C.ItemIndex];
  FProg[I].Touch;
  FSel := I;
  Changed;
  { argument ovisi o naredbi: ponovo iscrtaj kad prode obrada dogadaja }
  Application.QueueAsyncCall(@AsyncMove, -1);
end;

procedure TaBlockEditor.CommentChange(Sender: TObject);
var
  I: Integer;
begin
  if FRebuilding then Exit;
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FProg.Count) then Exit;
  FProg[I].Text := TEdit(Sender).Text;
  FProg[I].Touch;
  FSel := I;
  Changed;
end;

procedure TaBlockEditor.UpClick(Sender: TObject);
begin
  MoveRow(TControl(Sender).Tag, TControl(Sender).Tag - 1);
end;

procedure TaBlockEditor.DownClick(Sender: TObject);
begin
  MoveRow(TControl(Sender).Tag, TControl(Sender).Tag + 1);
end;

procedure TaBlockEditor.DelClick(Sender: TObject);
begin
  DeleteRow(TControl(Sender).Tag);
end;

procedure TaBlockEditor.RowClick(Sender: TObject);
begin
  if FRebuilding then Exit;
  if Sender is TControl then SelectRow(TControl(Sender).Tag);
end;

procedure TaBlockEditor.BuilderClick(Sender: TObject);
var
  I: Integer;
  S: string;
  E: TControl;
begin
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FProg.Count) or (FDb = nil) then Exit;
  if FProg[I].Kind in [bkIf, bkIfBlock, bkWhile, bkRepeat, bkLet] then S := FProg[I].Cond else S := FProg[I].Arg;
  if EditExpression(Self, FDb, '', 'Izraz', S) then
  begin
    if FProg[I].Kind in [bkIf, bkIfBlock, bkWhile, bkRepeat, bkLet] then
    begin
      FProg[I].Cond := S;
      E := CondControl(I);
    end
    else
    begin
      FProg[I].Arg := S;
      E := ArgControl(I);
    end;
    FProg[I].Touch;
    if E is TEdit then TEdit(E).Text := S;
    Changed;
  end;
end;

function TaBlockEditor.InsertPos: Integer;
begin
  if (FSel >= 0) and (FSel < FProg.Count) then Result := FSel + 1 else Result := FProg.Count;
end;

procedure TaBlockEditor.AddVerb(const AVerb: string);
var
  P: Integer;
begin
  P := InsertPos;
  FProg.Insert(P, NewCommandBlock(AVerb, ''));
  FSel := P;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.AddIf;
var
  P: Integer;
begin
  P := InsertPos;
  FProg.Insert(P, NewIfBlock('', 'msg', ''));
  FSel := P;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.AddComment;
var
  P: Integer;
begin
  P := InsertPos;
  FProg.Insert(P, NewCommentBlock(''));
  FSel := P;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.AddStop;
var
  P: Integer;
begin
  P := InsertPos;
  FProg.Insert(P, NewStopBlock);
  FSel := P;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.AddIfBlock;
var
  P: Integer;
begin
  P := InsertPos;
  FProg.Insert(P, NewStructBlock(bkIfBlock, ''));
  FProg.Insert(P + 1, NewStructBlock(bkElse, ''));
  FProg.Insert(P + 2, NewStructBlock(bkEndIf, ''));
  FSel := P;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.AddWhile;
var
  P: Integer;
begin
  P := InsertPos;
  FProg.Insert(P, NewStructBlock(bkWhile, ''));
  FProg.Insert(P + 1, NewStructBlock(bkEndWhile, ''));
  FSel := P;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.AddRepeat;
var
  P: Integer;
begin
  P := InsertPos;
  FProg.Insert(P, NewStructBlock(bkRepeat, '3'));
  FProg.Insert(P + 1, NewStructBlock(bkEndRepeat, ''));
  FSel := P;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.AddLet;
var
  P: Integer;
begin
  P := InsertPos;
  FProg.Insert(P, NewLetBlock('', ''));
  FSel := P;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.AddIfBlockClick(Sender: TObject);
begin
  AddIfBlock;
end;

procedure TaBlockEditor.AddWhileClick(Sender: TObject);
begin
  AddWhile;
end;

procedure TaBlockEditor.AddRepeatClick(Sender: TObject);
begin
  AddRepeat;
end;

procedure TaBlockEditor.AddLetClick(Sender: TObject);
begin
  AddLet;
end;

procedure TaBlockEditor.DeleteRow(AIndex: Integer);
var
  Op, El, En: TIntArray;
  Err: string;
begin
  if (AIndex < 0) or (AIndex >= FProg.Count) then Exit;
  { brisanje pocetka bloka brise i njegov else / kraj (sadrzaj ostaje) }
  if (FProg[AIndex].Kind in [bkIfBlock, bkWhile, bkRepeat]) and FProg.Match(Op, El, En, Err) then
  begin
    FProg.Delete(En[AIndex]);
    if El[AIndex] >= 0 then FProg.Delete(El[AIndex]);
  end;
  FProg.Delete(AIndex);
  if FSel >= FProg.Count then FSel := FProg.Count - 1;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.MoveRow(AFromIndex, AToIndex: Integer);
begin
  if (AFromIndex < 0) or (AFromIndex >= FProg.Count) or (AToIndex < 0) or (AToIndex >= FProg.Count) or (AFromIndex = AToIndex) then Exit;
  FProg.Move(AFromIndex, AToIndex);
  FSel := AToIndex;
  Rebuild;
  Changed;
end;

procedure TaBlockEditor.SelectRow(AIndex: Integer);
var
  I: Integer;
begin
  if (AIndex < 0) or (AIndex >= FProg.Count) or (AIndex = FSel) then Exit;
  FSel := AIndex;
  for I := 0 to FScroll.ControlCount - 1 do
    if FScroll.Controls[I] is TPanel then
      if TPanel(FScroll.Controls[I]).Tag = AIndex then TPanel(FScroll.Controls[I]).BorderStyle := bsSingle
      else TPanel(FScroll.Controls[I]).BorderStyle := bsNone;
end;

procedure TaBlockEditor.AddClick(Sender: TObject);
var
  S: string;
  P: Integer;
begin
  if FPalette.ItemIndex < 0 then
  begin
    ShowMessage(Tr('Choose a command from the list on the left.'));
    Exit;
  end;
  S := Trim(FPalette.Items[FPalette.ItemIndex]);
  if Pos('▸', S) = 1 then Exit;       { naslov kategorije }
  P := Pos(' ', S);
  if P > 0 then S := Copy(S, 1, P - 1);
  AddVerb(S);
end;

procedure TaBlockEditor.AddIfClick(Sender: TObject);
begin
  AddIf;
end;

procedure TaBlockEditor.AddCommentClick(Sender: TObject);
begin
  AddComment;
end;

procedure TaBlockEditor.AddStopClick(Sender: TObject);
begin
  AddStop;
end;

procedure TaBlockEditor.PaletteDblClick(Sender: TObject);
begin
  AddClick(Sender);
end;

procedure TaBlockEditor.RowDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := (Source is TLabel) and (Copy(TLabel(Source).Name, 1, 6) = 'handle');
end;

procedure TaBlockEditor.RowDragDrop(Sender, Source: TObject; X, Y: Integer);
begin
  if not ((Source is TLabel) and (Copy(TLabel(Source).Name, 1, 6) = 'handle')) then Exit;
  { prepisujemo kontrole koje trenutno vuku, pa premjestaj ide tek nakon dogadaja }
  Application.QueueAsyncCall(@AsyncMove, TLabel(Source).Tag * 10000 + TControl(Sender).Tag + 1);
end;

procedure TaBlockEditor.AsyncMove(Data: PtrInt);
begin
  if Data < 0 then
  begin
    Rebuild;
    Exit;
  end;
  MoveRow(Data div 10000, (Data mod 10000) - 1);
end;

function FindIn(AParent: TWinControl; const AName: string): TControl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AParent.ControlCount - 1 do
  begin
    if AParent.Controls[I].Name = AName then Exit(AParent.Controls[I]);
    if AParent.Controls[I] is TWinControl then
    begin
      Result := FindIn(TWinControl(AParent.Controls[I]), AName);
      if Result <> nil then Exit;
    end;
  end;
end;

function TaBlockEditor.ArgControl(AIndex: Integer): TControl;
begin
  Result := FindIn(FScroll, 'arg' + IntToStr(AIndex));
end;

function TaBlockEditor.CondControl(AIndex: Integer): TControl;
begin
  Result := FindIn(FScroll, 'cond' + IntToStr(AIndex));
end;

end.
