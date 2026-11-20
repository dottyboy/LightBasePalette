unit ta_bizdlg;
{ Business templates dialog: pick one, choose options, apply. The log of what was
  created stays visible, so several templates can be applied one after another. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Graphics, ta_meta, ta_bizgen;

{ True when at least one template was applied. }
function RunBusinessTemplates(AOwner: TComponent; ADb: TAppDb): Boolean;

implementation

uses
  ta_i18n;


type
  TBizDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    List: TListBox;
    Desc: TLabel;
    DocBox: TComboBox;
    SampleCk, MenuCk: TCheckBox;
    LogMemo: TMemo;
    Entries: TStringList;
    Applied: Boolean;
    procedure ListClick(Sender: TObject);
    procedure ApplyClick(Sender: TObject);
    function IdOf(AIndex: Integer): string;
    function NeedsType(AIndex: Integer): Boolean;
  end;

function TBizDlg.IdOf(AIndex: Integer): string;
begin
  Result := Copy(Entries[AIndex], 1, Pos('|', Entries[AIndex]) - 1);
end;

function TBizDlg.NeedsType(AIndex: Integer): Boolean;
begin
  Result := Copy(Entries[AIndex], Length(Entries[AIndex]), 1) = '1';
end;

procedure TBizDlg.ListClick(Sender: TObject);
var
  S: string;
  P: Integer;
begin
  if List.ItemIndex < 0 then Exit;
  S := Entries[List.ItemIndex];
  P := Pos('|', S);
  S := Copy(S, P + 1, MaxInt);
  P := Pos('|', S);
  S := Copy(S, P + 1, MaxInt);
  Desc.Caption := Tr(Copy(S, 1, Length(S) - 2));
  DocBox.Enabled := NeedsType(List.ItemIndex);
end;

procedure TBizDlg.ApplyClick(Sender: TObject);
var
  Log: TStringList;
  Ok: Boolean;
  DocType: string;
begin
  if List.ItemIndex < 0 then begin ShowMessage(Tr('Choose a template.')); Exit; end;
  Log := TStringList.Create;
  try
    DocType := '';
    if NeedsType(List.ItemIndex) then DocType := DocBox.Text;
    Ok := ApplyBizTemplate(Db, IdOf(List.ItemIndex), DocType, SampleCk.Checked, Log);
    if Ok and MenuCk.Checked then BuildAppSwitchboard(Db, Log);
    LogMemo.Lines.Add('— ' + Copy(Entries[List.ItemIndex], Pos('|', Entries[List.ItemIndex]) + 1,
      Pos('|', Copy(Entries[List.ItemIndex], Pos('|', Entries[List.ItemIndex]) + 1, MaxInt)) - 1) + ' —');
    LogMemo.Lines.AddStrings(Log);
    if Ok then Applied := True;
  finally
    Log.Free;
  end;
end;

function RunBusinessTemplates(AOwner: TComponent; ADb: TAppDb): Boolean;
var
  D: TBizDlg;
  I, P: Integer;
  S: string;
  Types: TStringList;
begin
  D := TBizDlg.Create;
  D.Db := ADb;
  D.Entries := BizTemplates;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Business templates');
    D.Form.SetBounds(0, 0, 860, 600);
    D.Form.Position := poOwnerFormCenter;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Template'); SetBounds(14, 10, 200, 18); end;
    D.List := TListBox.Create(D.Form);
    D.List.Parent := D.Form;
    D.List.SetBounds(14, 30, 330, 200);
    for I := 0 to D.Entries.Count - 1 do
    begin
      S := Copy(D.Entries[I], Pos('|', D.Entries[I]) + 1, MaxInt);
      P := Pos('|', S);
      D.List.Items.Add(Tr(Copy(S, 1, P - 1)));
    end;
    D.List.OnClick := @D.ListClick;
    D.Desc := TLabel.Create(D.Form);
    D.Desc.Parent := D.Form;
    D.Desc.SetBounds(360, 30, 480, 70);
    D.Desc.WordWrap := True;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Document type:'); SetBounds(360, 112, 130, 18); end;
    D.DocBox := TComboBox.Create(D.Form);
    D.DocBox.Parent := D.Form;
    D.DocBox.SetBounds(496, 108, 200, 26);
    D.DocBox.Style := csDropDownList;
    Types := DocumentTypes;
    try
      D.DocBox.Items.Assign(Types);
    finally
      Types.Free;
    end;
    D.DocBox.ItemIndex := 0;
    D.DocBox.Enabled := False;
    D.SampleCk := TCheckBox.Create(D.Form);
    D.SampleCk.Parent := D.Form;
    D.SampleCk.Caption := Tr('Enter sample data (for trying out)');
    D.SampleCk.SetBounds(360, 146, 460, 22);
    D.MenuCk := TCheckBox.Create(D.Form);
    D.MenuCk.Parent := D.Form;
    D.MenuCk.Caption := Tr('Make a main menu from all forms and reports');
    D.MenuCk.SetBounds(360, 174, 460, 22);
    D.MenuCk.Checked := True;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Apply template'); SetBounds(360, 202, 200, 30); OnClick := @D.ApplyClick; end;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('What was created'); SetBounds(14, 244, 200, 18); end;
    D.LogMemo := TMemo.Create(D.Form);
    D.LogMemo.Parent := D.Form;
    D.LogMemo.SetBounds(14, 264, 826, 270);
    D.LogMemo.ReadOnly := True;
    D.LogMemo.ScrollBars := ssAutoVertical;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(740, 548, 100, 30); end;
    if D.List.Items.Count > 0 then
    begin
      D.List.ItemIndex := 0;
      D.ListClick(nil);
    end;
    D.Form.ShowModal;
    Result := D.Applied;
  finally
    D.Form.Free;
    D.Entries.Free;
    D.Free;
  end;
end;

end.
