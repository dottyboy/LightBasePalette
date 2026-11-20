unit ta_taskdlg;
{ Planer zadataka: popis zadataka, uredivanje, izvrsavanje odmah. Ovdje se
  registrira i PDF izvoz izvjesca za zadatke. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ta_meta, ta_tasks;

procedure RunTaskPlanner(AOwner: TComponent; ADb: TAppDb);
{ Izvrsava zadatke koji su na redu (poziva mjerac i --run-tasks). }
function RunDueTasksNow(ADb: TAppDb; ALog: TStrings): Integer;

implementation

uses
  ta_i18n,
  ta_reportdef, ta_reportengine, ta_reportview;

const
  KindTitles: array[0..4] of string = (
    'Sigurnosna kopija baze', 'Izvješće u PDF', 'Izvoz u CSV', 'SQL naredba', 'Makro');

function PdfExport(ADb: TAppDb; const AReport, AFile: string; out AErr: string): Boolean;
var
  Js: string;
  Rd: TaReportDef;
  Eng: TaReportEngine;
  Rr: TaRenderedReport;
begin
  Result := False;
  Js := ADb.LoadObject('_sys_reports', AReport);
  if Js = '' then begin AErr := Tr('There is no report: ') + AReport; Exit; end;
  Rd := TaReportDef.Create;
  try
    Rd.FromJson(Js);
    Rd.Name := AReport;
    ADb.ClearParams;
    Eng := TaReportEngine.Create(ADb, Rd);
    try
      Rr := Eng.Render;
      try
        Result := ExportPdf(Rr, AFile, AErr);
      finally
        Rr.Free;
      end;
    finally
      Eng.Free;
    end;
  finally
    Rd.Free;
  end;
end;

function RunDueTasksNow(ADb: TAppDb; ALog: TStrings): Integer;
begin
  Result := RunDueTasks(ADb, Now, ALog);
end;

type
  TTaskDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    List: TListBox;
    NameEdit, Arg1Edit, Arg2Edit, SchedEdit: TEdit;
    KindBox: TComboBox;
    Arg1Lbl, Arg2Lbl, Info: TLabel;
    EnabledCk, AutoCk: TCheckBox;
    Tasks: TaTasks;
    procedure Reload(const ASelect: string);
    procedure ListClick(Sender: TObject);
    procedure KindChange(Sender: TObject);
    procedure NewClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure AutoClick(Sender: TObject);
    function Collect(out ATask: TaTask): Boolean;
  end;

procedure TTaskDlg.Reload(const ASelect: string);
var
  I: Integer;
  S: string;
begin
  Tasks := LoadTasks(Db);
  List.Items.Clear;
  for I := 0 to High(Tasks) do
  begin
    S := Tasks[I].Name;
    if not Tasks[I].Enabled then S := S + Tr('  (off)');
    List.Items.Add(S);
  end;
  for I := 0 to High(Tasks) do
    if SameText(Tasks[I].Name, ASelect) then List.ItemIndex := I;
  { bez izricitog odabira otvara se prvi zadatak, da obrazac nije prazan }
  if (List.ItemIndex < 0) and (ASelect = '') and (Length(Tasks) > 0) then List.ItemIndex := 0;
  ListClick(nil);
end;

procedure TTaskDlg.KindChange(Sender: TObject);
begin
  case KindBox.ItemIndex of
    0: begin Arg1Lbl.Caption := Tr('Folder for copies'); Arg2Lbl.Caption := Tr('Keep the last (count)'); end;
    1: begin Arg1Lbl.Caption := Tr('Report'); Arg2Lbl.Caption := Tr('Folder for PDF'); end;
    2: begin Arg1Lbl.Caption := Tr('Table or query'); Arg2Lbl.Caption := Tr('Folder for CSV'); end;
    3: begin Arg1Lbl.Caption := Tr('SQL statement'); Arg2Lbl.Caption := Tr('(not needed)'); end;
    4: begin Arg1Lbl.Caption := Tr('Macro name'); Arg2Lbl.Caption := Tr('(not needed)'); end;
  end;
  Arg2Edit.Enabled := KindBox.ItemIndex < 3;
end;

procedure TTaskDlg.ListClick(Sender: TObject);
var
  I, K: Integer;
  T: TaTask;
begin
  I := List.ItemIndex;
  if (I < 0) or (I > High(Tasks)) then
  begin
    NameEdit.Text := ''; NameEdit.ReadOnly := False;
    KindBox.ItemIndex := 0; KindChange(nil);
    Arg1Edit.Text := ''; Arg2Edit.Text := ''; SchedEdit.Text := 'dnevno 02:00';
    EnabledCk.Checked := True;
    Info.Caption := '';
    Exit;
  end;
  T := Tasks[I];
  NameEdit.Text := T.Name;
  NameEdit.ReadOnly := True;
  KindBox.ItemIndex := 0;
  for K := 0 to High(TaskKinds) do
    if TaskKinds[K] = T.Kind then KindBox.ItemIndex := K;
  KindChange(nil);
  Arg1Edit.Text := T.Arg;
  Arg2Edit.Text := T.Arg2;
  SchedEdit.Text := T.Schedule;
  EnabledCk.Checked := T.Enabled;
  if T.LastRun = 0 then Info.Caption := Tr('Not run yet.')
  else Info.Caption := Tr('Last: ') + FormatDateTime('dd.mm.yyyy hh:nn', T.LastRun) + '  -  ' + T.LastResult;
end;

function TTaskDlg.Collect(out ATask: TaTask): Boolean;
var
  Sch: TSchedule;
  Err: string;
begin
  Result := False;
  ATask.Name := Trim(NameEdit.Text);
  if ATask.Name = '' then begin ShowMessage(Tr('Enter a task name.')); Exit; end;
  ATask.Kind := TaskKinds[KindBox.ItemIndex];
  ATask.Arg := Trim(Arg1Edit.Text);
  ATask.Arg2 := Trim(Arg2Edit.Text);
  ATask.Schedule := Trim(SchedEdit.Text);
  ATask.Enabled := EnabledCk.Checked;
  ATask.LastRun := 0;
  ATask.LastResult := '';
  if not ParseSchedule(ATask.Schedule, Sch, Err) then begin ShowMessage(Err); Exit; end;
  Result := True;
end;

procedure TTaskDlg.NewClick(Sender: TObject);
begin
  List.ItemIndex := -1;
  ListClick(nil);
  NameEdit.SetFocus;
end;

procedure TTaskDlg.SaveClick(Sender: TObject);
var
  T: TaTask;
  I: Integer;
begin
  if not Collect(T) then Exit;
  I := List.ItemIndex;
  if (I >= 0) and (I <= High(Tasks)) and SameText(Tasks[I].Name, T.Name) then
  begin
    T.LastRun := Tasks[I].LastRun;
    T.LastResult := Tasks[I].LastResult;
  end
  else T.LastRun := Now;       { novi zadatak se ne izvrsava za prosla vremena }
  SaveTask(Db, T);
  Reload(T.Name);
end;

procedure TTaskDlg.DeleteClick(Sender: TObject);
var
  I: Integer;
begin
  I := List.ItemIndex;
  if (I < 0) or (I > High(Tasks)) then Exit;
  if MessageDlg(Tr('Delete task "') + Tasks[I].Name + '"?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  DeleteTask(Db, Tasks[I].Name);
  Reload('');
end;

procedure TTaskDlg.RunClick(Sender: TObject);
var
  T: TaTask;
  Msg: string;
  I: Integer;
  Ok: Boolean;
begin
  I := List.ItemIndex;
  if (I < 0) or (I > High(Tasks)) then begin ShowMessage(Tr('Choose a saved task.')); Exit; end;
  T := Tasks[I];
  Ok := RunTask(Db, T, Msg);
  T.LastRun := Now;
  if Ok then T.LastResult := 'OK: ' + Msg else T.LastResult := Tr('ERROR: ') + Msg;
  SaveTask(Db, T);
  Reload(T.Name);
end;

procedure TTaskDlg.AutoClick(Sender: TObject);
begin
  if AutoCk.Checked then Db.SaveSetting('tasks.auto', '1') else Db.SaveSetting('tasks.auto', '0');
end;

procedure RunTaskPlanner(AOwner: TComponent; ADb: TAppDb);
var
  D: TTaskDlg;
  I: Integer;

  function Lbl(const ACap: string; X, Y: Integer): TLabel;
  begin
    Result := TLabel.Create(D.Form);
    Result.Parent := D.Form;
    Result.Caption := ACap;
    Result.SetBounds(X, Y, 300, 18);
  end;

  function Ed(X, Y, W: Integer): TEdit;
  begin
    Result := TEdit.Create(D.Form);
    Result.Parent := D.Form;
    Result.SetBounds(X, Y, W, 26);
  end;

begin
  D := TTaskDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Task scheduler');
    D.Form.SetBounds(0, 0, 900, 540);
    D.Form.Position := poOwnerFormCenter;
    Lbl(Tr('Tasks'), 14, 10);
    D.List := TListBox.Create(D.Form);
    D.List.Parent := D.Form;
    D.List.SetBounds(14, 32, 260, 400);
    D.List.OnClick := @D.ListClick;
    Lbl(Tr('Name'), 296, 10);
    D.NameEdit := Ed(296, 32, 300);
    Lbl(Tr('Type'), 296, 66);
    D.KindBox := TComboBox.Create(D.Form);
    D.KindBox.Parent := D.Form;
    D.KindBox.Style := csDropDownList;
    D.KindBox.SetBounds(296, 88, 300, 26);
    for I := 0 to High(KindTitles) do D.KindBox.Items.Add(Tr(KindTitles[I]));
    D.KindBox.OnChange := @D.KindChange;
    D.Arg1Lbl := Lbl('', 296, 122);
    D.Arg1Edit := Ed(296, 144, 580);
    D.Arg2Lbl := Lbl('', 296, 178);
    D.Arg2Edit := Ed(296, 200, 580);
    Lbl(Tr('Layout'), 296, 234);
    D.SchedEdit := Ed(296, 256, 300);
    Lbl(Tr('every 30 min   |   daily 02:00   |   weekly mon 08:00   |   monthly 1 03:00'), 296, 286);
    D.EnabledCk := TCheckBox.Create(D.Form);
    D.EnabledCk.Parent := D.Form;
    D.EnabledCk.Caption := Tr('The task is on');
    D.EnabledCk.SetBounds(296, 314, 300, 22);
    D.Info := Lbl('', 296, 346);
    D.Info.AutoSize := False;
    D.Info.SetBounds(296, 346, 580, 60);
    D.Info.WordWrap := True;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('New item'); SetBounds(296, 414, 90, 30); OnClick := @D.NewClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Save'); SetBounds(394, 414, 90, 30); OnClick := @D.SaveClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Delete'); SetBounds(492, 414, 90, 30); OnClick := @D.DeleteClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Run now'); SetBounds(590, 414, 120, 30); OnClick := @D.RunClick; end;
    D.AutoCk := TCheckBox.Create(D.Form);
    D.AutoCk.Parent := D.Form;
    D.AutoCk.Caption := Tr('Run tasks automatically while the application is open (or with the --run-tasks command)');
    D.AutoCk.SetBounds(14, 460, 700, 22);
    D.AutoCk.Checked := ADb.LoadSetting('tasks.auto') <> '0';
    D.AutoCk.OnClick := @D.AutoClick;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(776, 458, 100, 30); end;
    D.Reload('');
    D.Form.ShowModal;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

initialization
  TaskPdfHook := @PdfExport;

end.
