unit ta_modeditor;
{ Editors for script modules (PascalScript) and macros. Both check what has
  been typed before saving and point to the offending line. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Graphics,
  ta_meta, ta_expr, ta_script, ta_blocks, ta_blockedit, ta_editor;

{ True when the module / macro was saved. }
function EditModule(AOwner: TComponent; ADb: TAppDb; const AName: string): Boolean;
function EditMacro(AOwner: TComponent; ADb: TAppDb; const AName: string; AStartBlocks: Boolean = False): Boolean;
{ Napravi makro (prazan, s komentarom) za dogadjaj i vrati njegov jedinstveni naziv. }
function CreateEventMacro(ADb: TAppDb; const AForm, AEvent: string): string;
{ Empty when every line of a macro is well formed. }
function CheckMacroText(const AText: string): string;

implementation

uses
  ta_i18n;


function CheckMacroText(const AText: string): string;
var
  Prog: TaBlockProgram;
  Pr: TStringList;
  I: Integer;
  B: TaBlock;
  Err: string;
begin
  Result := '';
  Prog := TaBlockProgram.Create;
  try
    Prog.LoadText(AText);
    Pr := Prog.Problems;
    try
      if Pr.Count > 0 then Exit(Pr[0]);
    finally
      Pr.Free;
    end;
    for I := 0 to Prog.Count - 1 do
    begin
      B := Prog[I];
      if not (B.Kind in [bkIf, bkIfBlock, bkWhile, bkRepeat, bkLet]) then Continue;
      Err := CheckExpr(B.Cond);
      if Err <> '' then
      begin
        if B.Kind = bkLet then Exit(Format(Tr('Row %d: the expression is not valid (%s).'), [I + 1, Err]));
        Exit(Format(Tr('Row %d: the condition is not valid (%s).'), [I + 1, Err]));
      end;
    end;
  finally
    Prog.Free;
  end;
end;

type
  TEditorDlg = class
  public
    Db: TAppDb;
    IsMacro: Boolean;
    Name: string;
    Form: TForm;
    Memo: TaEditor;
    Blocks: TaBlockEditor;
    HelpBox: TListBox;
    HelpLabel: TLabel;
    ModeBtn: TButton;
    Status: TLabel;
    Saved: Boolean;
    procedure ModeClick(Sender: TObject);
    procedure SyncText;
    procedure CheckClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    function RunCheck: Boolean;
  end;

{ u prikazu blokova tekst makroa dolazi iz blokova }
procedure TEditorDlg.SyncText;
begin
  if (Blocks <> nil) and Blocks.Visible then Memo.Text := Blocks.GetText;
end;

procedure TEditorDlg.ModeClick(Sender: TObject);
begin
  if Blocks.Visible then
  begin
    Memo.Text := Blocks.GetText;
    Blocks.Visible := False;
    Blocks.SetBounds(10, 10, 640, 540);
    Memo.Visible := True;
    HelpBox.Visible := True;
    HelpLabel.Visible := True;
    ModeBtn.Caption := Tr('Blocks');
  end
  else
  begin
    Blocks.SetText(Memo.Text);
    Memo.Visible := False;
    { paleta blokova zamjenjuje popis akcija, pa blokovi dobiju cijelu sirinu }
    HelpBox.Visible := False;
    HelpLabel.Visible := False;
    Blocks.SetBounds(10, 10, Form.ClientWidth - 20, 540);
    Blocks.Visible := True;
    ModeBtn.Caption := Tr('Text');
  end;
end;

function TEditorDlg.RunCheck: Boolean;
var
  Err: string;
begin
  SyncText;
  if IsMacro then
  begin
    Err := CheckMacroText(Memo.Text);
    Result := Err = '';
    if Result then Status.Caption := Tr('The macro is valid.') else Status.Caption := Err;
  end
  else
  begin
    Result := Scripts(Db).Check(Name, Memo.Text, Err);
    if Result then Status.Caption := Tr('The module compiles successfully.')
    else Status.Caption := Tr('Error ') + Trim(Err);
  end;
  if Result then Status.Font.Color := clGreen else Status.Font.Color := clMaroon;
end;

procedure TEditorDlg.CheckClick(Sender: TObject);
begin
  RunCheck;
end;

procedure TEditorDlg.SaveClick(Sender: TObject);
var
  Kind: string;
begin
  if IsMacro then Kind := '_sys_macros' else Kind := '_sys_modules';
  SyncText;
  if not RunCheck then
    if MessageDlg(Tr('There are errors. Save anyway?'), mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  Db.SaveObject(Kind, Name, Memo.Text);
  Saved := True;
  Status.Caption := Tr('Saved.');
  Status.Font.Color := clGreen;
end;

function RunEditor(AOwner: TComponent; ADb: TAppDb; const AName: string; AMacro: Boolean; AStartBlocks: Boolean): Boolean;
var
  D: TEditorDlg;
  Help: TListBox;
  H: TStringList;
  Kind: string;
begin
  D := TEditorDlg.Create;
  D.Db := ADb;
  D.IsMacro := AMacro;
  D.Name := AName;
  D.Form := TForm.CreateNew(AOwner);
  try
    if AMacro then begin D.Form.Caption := Tr('Macro: ') + AName; Kind := '_sys_macros'; end
    else begin D.Form.Caption := Tr('Module: ') + AName; Kind := '_sys_modules'; end;
    D.Form.SetBounds(0, 0, 1000, 640);
    D.Form.Position := poOwnerFormCenter;
    D.Memo := TaEditor.Create(D.Form);
    D.Memo.Parent := D.Form;
    if AMacro then D.Memo.Variant := ewText else D.Memo.Variant := ewPascal;
    D.Memo.SetBounds(10, 10, 640, 540);
    D.Memo.Anchors := [akLeft, akTop, akRight, akBottom];
    D.Memo.Text := ADb.LoadObject(Kind, AName);
    if AMacro then
    begin
      D.Blocks := TaBlockEditor.Create(D.Form);
      D.Blocks.Parent := D.Form;
      D.Blocks.SetBounds(10, 10, 640, 540);
      D.Blocks.Anchors := [akLeft, akTop, akRight, akBottom];
      D.Blocks.SetDb(ADb);
      D.Blocks.Visible := False;
    end;
    if (D.Memo.Text = '') and not AMacro then
      D.Memo.Text := Tr('{ Modules contain only procedures and functions. }') + LineEnding +
        'procedure Hello;' + LineEnding + 'begin' + LineEnding + '  Msg(''Hello'');' + LineEnding + 'end;' + LineEnding + LineEnding +
        Tr('{ Trigger example: enter the procedure name in the form (OnExit, OnValidate, BeforeInsert, OnError...) or on a control. }') + LineEnding +
        Tr('{ CancelEvent rejects the action; EventInfo gives eventControl, eventValue, eventKey and eventMessage. }') + LineEnding +
        'procedure RejectNegative;' + LineEnding + 'begin' + LineEnding +
        '  if GetNumber(EventInfo(''eventControl'')) < 0 then' + LineEnding + '  begin' + LineEnding +
        '    Msg(''' + Tr('The value must not be negative.') + ''');' + LineEnding + '    CancelEvent;' + LineEnding + '  end;' + LineEnding + 'end;';
    D.HelpLabel := TLabel.Create(D.Form);
    with D.HelpLabel do
    begin
      Parent := D.Form;
      if AMacro then Caption := Tr('Actions') else Caption := Tr('Functions in scripts');
      SetBounds(662, 10, 300, 18);
    end;
    Help := TListBox.Create(D.Form);
    Help.Parent := D.Form;
    Help.SetBounds(662, 32, 326, 518);
    Help.Anchors := [akTop, akRight, akBottom];
    D.HelpBox := Help;
    if AMacro then H := MacroHelpLines else H := ScriptHelpLines;
    try
      Help.Items.Assign(H);
    finally
      H.Free;
    end;
    D.Status := TLabel.Create(D.Form);
    D.Status.Parent := D.Form;
    D.Status.SetBounds(10, 562, 640, 36);
    D.Status.Anchors := [akLeft, akBottom];
    D.Status.WordWrap := True;
    if AMacro then
    begin
      D.ModeBtn := TButton.Create(D.Form);
      D.ModeBtn.Parent := D.Form;
      D.ModeBtn.Caption := Tr('Blocks');
      D.ModeBtn.SetBounds(662, 530, 100, 30);
      D.ModeBtn.Anchors := [akRight, akBottom];
      D.ModeBtn.OnClick := @D.ModeClick;
      D.ModeBtn.Hint := Tr('Switch between text and blocks (same macro)');
      D.ModeBtn.ShowHint := True;
    end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Check'); SetBounds(662, 566, 100, 30); Anchors := [akRight, akBottom]; OnClick := @D.CheckClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Save'); SetBounds(772, 566, 100, 30); Anchors := [akRight, akBottom]; OnClick := @D.SaveClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(882, 566, 100, 30); Anchors := [akRight, akBottom]; end;
    if AMacro and AStartBlocks then D.ModeClick(nil);
    D.Form.ShowModal;
    Result := D.Saved;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

function EditModule(AOwner: TComponent; ADb: TAppDb; const AName: string): Boolean;
begin
  Result := RunEditor(AOwner, ADb, AName, False, False);
end;

function EditMacro(AOwner: TComponent; ADb: TAppDb; const AName: string; AStartBlocks: Boolean): Boolean;
begin
  Result := RunEditor(AOwner, ADb, AName, True, AStartBlocks);
end;

{ naziv bez znakova koji smetaju u imenu makra: slova, brojke i podvlaka }
function CreateEventMacro(ADb: TAppDb; const AForm, AEvent: string): string;
var
  Base: string;
  I, N: Integer;
begin
  Base := '';
  for I := 1 to Length(AForm + '_' + AEvent) do
    if (AForm + '_' + AEvent)[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then Base := Base + (AForm + '_' + AEvent)[I]
    else Base := Base + '_';
  if Trim(Base) = '' then Base := 'Makro';
  Result := Base;
  N := 1;
  while ADb.LoadObject('_sys_macros', Result) <> '' do
  begin
    Inc(N);
    Result := Base + '_' + IntToStr(N);
  end;
  ADb.SaveObject('_sys_macros', Result, '# Makro za dogadjaj ' + AEvent + ' (forma ' + AForm + ')' + LineEnding);
end;

end.
