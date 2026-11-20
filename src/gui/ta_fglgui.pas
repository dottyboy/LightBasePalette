unit ta_fglgui;
{ Grafički I/O za 4GL programe: izbornici, unos, poruke, otvaranje formi. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs, ExtCtrls, Grids, contnrs, ta_meta,
  Process, Printers, LazFileUtils, FileUtil, ta_formdef, ta_formrun, ta_fgl, ta_reportengine, ta_reportview, ta_script;

type
  TaFglGuiIO = class(TaFglIO)
  private
    FLog: TForm;
    FMemo: TMemo;
    procedure EnsureLog;
  public
    destructor Destroy; override;
    procedure Display(const S: string); override;
    procedure Message(const S: string); override;
    procedure Error(const S: string); override;
    function Ask(const AText: string): Boolean; override;
    function Prompt(const AText: string; var AValue: string): Boolean; override;
    function Menu(const ATitle: string; ANames, AHelps: TStrings): Integer; override;
    function Input(const ATitle: string; ANames, AValues: TStrings; const AFocus: string;
      AReadOnly: Boolean): Boolean; override;
    function Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean; override;
    function InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
      const AFocus: string; AReadOnly: Boolean): Boolean; override;
    function Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
      AEditable: Boolean; var ACurrent: Integer): Boolean; override;
    procedure RunForm(ADb: TAppDb; const AFormName, AFilter: string); override;
    procedure ShowReport(const ATitle: string; APages: TObjectList); override;
    procedure Finish; override;
  end;

{ Tekstualne stranice 4GL izvješća kao crtež za pregled i PDF (monospace). }
function TextPagesToReport(APages: TObjectList): TaRenderedReport;

{ Ucitaj, provjeri i pokreni program. Vraca izlazni kod. }
function RunFglFile(ADb: TAppDb; const AFile: string; AConsole: Boolean): Integer;
{ isto za program u tekstu (uredjivac blokova) }
function RunFglText(ADb: TAppDb; const AText: string; AConsole: Boolean): Integer;

implementation

uses
  ta_i18n;


type
  TGridHelper = class
    procedure Click(Sender: TObject);
  end;

var
  GridTarget: TStringGrid;
  GridHelper: TGridHelper;

procedure TGridHelper.Click(Sender: TObject);
var
  R: Integer;
begin
  if GridTarget = nil then Exit;
  if TComponent(Sender).Tag = 1 then
  begin
    GridTarget.RowCount := GridTarget.RowCount + 1;
    GridTarget.Row := GridTarget.RowCount - 1;
  end
  else if (GridTarget.Row >= 1) and (GridTarget.RowCount > 2) then
  begin
    R := GridTarget.Row;
    GridTarget.DeleteRow(R);
  end
  else if GridTarget.Row >= 1 then
  begin
    for R := 0 to GridTarget.ColCount - 1 do GridTarget.Cells[R, GridTarget.Row] := '';
  end;
end;

destructor TaFglGuiIO.Destroy;
begin
  FLog.Free;
  inherited Destroy;
end;

procedure TaFglGuiIO.EnsureLog;
var
  Pn: TPanel;
  B: TButton;
begin
  if FLog <> nil then Exit;
  FLog := TForm.CreateNew(nil);
  FLog.Caption := Tr('Program output');
  FLog.Position := poScreenCenter;
  FLog.SetBounds(0, 0, 640, 420);
  Pn := TPanel.Create(FLog);
  Pn.Parent := FLog;
  Pn.Align := alBottom;
  Pn.Height := 44;
  Pn.BevelOuter := bvNone;
  B := TButton.Create(FLog);
  B.Parent := Pn;
  B.Caption := Tr('Close');
  B.ModalResult := mrOk;
  B.SetBounds(530, 7, 96, 30);
  FMemo := TMemo.Create(FLog);
  FMemo.Parent := FLog;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoBoth;
end;

procedure TaFglGuiIO.Display(const S: string);
begin
  EnsureLog;
  FMemo.Lines.Add(S);
  if not FLog.Visible then FLog.Show;
  Application.ProcessMessages;
end;

procedure TaFglGuiIO.Message(const S: string);
begin
  ShowMessage(S);
end;

procedure TaFglGuiIO.Error(const S: string);
begin
  MessageDlg(Tr('Error'), S, mtError, [mbOK], 0);
end;

function TaFglGuiIO.Ask(const AText: string): Boolean;
begin
  Result := MessageDlg(Tr('Question'), AText, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

function TaFglGuiIO.Prompt(const AText: string; var AValue: string): Boolean;
begin
  Result := InputQuery(Tr('Input'), AText, AValue);
end;

function TaFglGuiIO.Menu(const ATitle: string; ANames, AHelps: TStrings): Integer;
var
  F: TForm;
  B: TButton;
  I: Integer;
  R: TModalResult;
begin
  F := TForm.CreateNew(nil);
  try
    F.Caption := ATitle;
    F.Position := poScreenCenter;
    F.BorderStyle := bsDialog;
    for I := 0 to ANames.Count - 1 do
    begin
      B := TButton.Create(F);
      B.Parent := F;
      B.Caption := ANames[I];
      B.Hint := AHelps[I];
      B.ShowHint := AHelps[I] <> '';
      B.ModalResult := 100 + I;
      B.SetBounds(14, 14 + I * 42, 320, 36);
    end;
    F.ClientWidth := 348;
    F.ClientHeight := 28 + ANames.Count * 42;
    { Esc zatvara izbornik }
    B := TButton.Create(F);
    B.Parent := F;
    B.Cancel := True;
    B.ModalResult := mrCancel;
    B.SetBounds(-100, -100, 1, 1);
    R := F.ShowModal;
    if R >= 100 then Result := R - 100 else Result := -1;
  finally
    F.Free;
  end;
end;

{ Polja zaslona: oznaka (* kad je obavezno), LOOKUP kao padajuci popis, READONLY. }
function FieldsDialog(const ATitle, AHint: string; AFields: TObjectList; AValues: TStrings;
  const AFocus: string; AReadOnly: Boolean): Boolean;
var
  F: TForm;
  Sb: TScrollBox;
  Pn: TPanel;
  Ok, Cancel: TButton;
  Edits: array of TEdit;
  Combos: array of TComboBox;
  Lb: TLabel;
  Fld: TaFglField;
  I, K, Y, H: Integer;
  Cap: string;
begin
  Result := False;
  F := TForm.CreateNew(nil);
  try
    F.Caption := ATitle;
    F.Position := poScreenCenter;
    F.BorderStyle := bsDialog;
    Y := 8;
    Sb := TScrollBox.Create(F);
    Sb.Parent := F;
    Sb.Align := alClient;
    Sb.BorderStyle := bsNone;
    if AHint <> '' then
    begin
      Lb := TLabel.Create(F);
      Lb.Parent := Sb;
      Lb.Caption := AHint;
      Lb.WordWrap := True;
      Lb.SetBounds(14, Y, 372, 32);
      Inc(Y, 40);
    end;
    SetLength(Edits, AFields.Count);
    SetLength(Combos, AFields.Count);
    for I := 0 to AFields.Count - 1 do
    begin
      Fld := TaFglField(AFields[I]);
      Cap := Fld.Caption;
      if Fld.Required then Cap := Cap + ' *';
      Lb := TLabel.Create(F);
      Lb.Parent := Sb;
      Lb.Caption := Cap;
      Lb.SetBounds(14, Y, 372, 18);
      if Fld.LookupKeys <> nil then
      begin
        Combos[I] := TComboBox.Create(F);
        Combos[I].Parent := Sb;
        Combos[I].Style := csDropDownList;
        Combos[I].Items.AddStrings(Fld.LookupLabels);
        K := Fld.LookupKeys.IndexOf(AValues[I]);
        Combos[I].ItemIndex := K;
        Combos[I].Enabled := not (AReadOnly or Fld.ReadOnly);
        Combos[I].SetBounds(14, Y + 20, 372, 26);
        if Fld.Hint <> '' then begin Combos[I].Hint := Fld.Hint; Combos[I].ShowHint := True; end;
      end
      else
      begin
        Edits[I] := TEdit.Create(F);
        Edits[I].Parent := Sb;
        Edits[I].SetBounds(14, Y + 20, 372, 26);
        Edits[I].Text := AValues[I];
        Edits[I].ReadOnly := AReadOnly or Fld.ReadOnly;
        if Fld.Hint <> '' then begin Edits[I].Hint := Fld.Hint; Edits[I].ShowHint := True; end;
      end;
      Inc(Y, 54);
    end;
    Pn := TPanel.Create(F);
    Pn.Parent := F;
    Pn.Align := alBottom;
    Pn.Height := 44;
    Pn.BevelOuter := bvNone;
    Ok := TButton.Create(F);
    Ok.Parent := Pn;
    Ok.Caption := Tr('OK');
    Ok.ModalResult := mrOk;
    Ok.Default := True;
    Ok.SetBounds(194, 7, 96, 30);
    Cancel := TButton.Create(F);
    Cancel.Parent := Pn;
    Cancel.Caption := Tr('Cancel');
    Cancel.ModalResult := mrCancel;
    Cancel.Cancel := True;
    Cancel.SetBounds(298, 7, 96, 30);
    F.ClientWidth := 408;
    H := Y + 52;
    if H > 560 then H := 560;
    F.ClientHeight := H;
    for I := 0 to AFields.Count - 1 do
      if SameText(TaFglField(AFields[I]).Name, AFocus) then
      begin
        if Edits[I] <> nil then F.ActiveControl := Edits[I] else F.ActiveControl := Combos[I];
        Break;
      end;
    if F.ShowModal = mrOk then
    begin
      if not AReadOnly then
        for I := 0 to AFields.Count - 1 do
        begin
          Fld := TaFglField(AFields[I]);
          if Fld.ReadOnly then Continue;
          if Combos[I] <> nil then
          begin
            if Combos[I].ItemIndex >= 0 then AValues[I] := Fld.LookupKeys[Combos[I].ItemIndex]
            else AValues[I] := '';
          end
          else AValues[I] := Edits[I].Text;
        end;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

function SimpleFields(ANames: TStrings): TObjectList;
var
  I: Integer;
  Fld: TaFglField;
begin
  Result := TObjectList.Create(True);
  for I := 0 to ANames.Count - 1 do
  begin
    Fld := TaFglField.Create;
    Fld.Name := ANames[I];
    Fld.Caption := ANames[I];
    Result.Add(Fld);
  end;
end;

function TaFglGuiIO.Input(const ATitle: string; ANames, AValues: TStrings; const AFocus: string;
  AReadOnly: Boolean): Boolean;
var
  Fl: TObjectList;
begin
  Fl := SimpleFields(ANames);
  try
    Result := FieldsDialog(ATitle, '', Fl, AValues, AFocus, AReadOnly);
  finally
    Fl.Free;
  end;
end;

function TaFglGuiIO.InputFields(const ATitle: string; AFields: TObjectList; AValues: TStrings;
  const AFocus: string; AReadOnly: Boolean): Boolean;
begin
  Result := FieldsDialog(ATitle, '', AFields, AValues, AFocus, AReadOnly);
end;

function TaFglGuiIO.Construct(const ATitle: string; AColumns, AValues: TStrings): Boolean;
var
  Fl: TObjectList;
begin
  Fl := SimpleFields(AColumns);
  try
    Result := FieldsDialog(ATitle,
      Tr('Example conditions: A* (starts with A), >5, 3:7 (from-to), a|b (or). An empty field = no condition.'),
      Fl, AValues, '', False);
  finally
    Fl.Free;
  end;
end;

{ Mreza za INPUT/DISPLAY ARRAY. Uredivanje: dodaj/obrisi redak; prazni redci se odbacuju. }
function TaFglGuiIO.Grid(const ATitle: string; AFields: TObjectList; ARows: TObjectList;
  AEditable: Boolean; var ACurrent: Integer): Boolean;
var
  F: TForm;
  G: TStringGrid;
  Pn: TPanel;
  Ok, Cancel, Add, Del: TButton;
  I, J, N: Integer;
  Row: TStringList;
  Empty: Boolean;
  Fld: TaFglField;
begin
  Result := False;
  F := TForm.CreateNew(nil);
  try
    F.Caption := ATitle;
    F.Position := poScreenCenter;
    F.SetBounds(0, 0, 720, 460);
    Pn := TPanel.Create(F);
    Pn.Parent := F;
    Pn.Align := alBottom;
    Pn.Height := 44;
    Pn.BevelOuter := bvNone;
    G := TStringGrid.Create(F);
    G.Parent := F;
    G.Align := alClient;
    G.FixedRows := 1;
    G.FixedCols := 0;
    G.ColCount := AFields.Count;
    G.RowCount := 1 + ARows.Count + Ord(AEditable);
    G.Options := G.Options + [goRowSelect] - [goRangeSelect];
    if AEditable then G.Options := G.Options + [goEditing] - [goRowSelect];
    for J := 0 to AFields.Count - 1 do
    begin
      Fld := TaFglField(AFields[J]);
      G.Cells[J, 0] := Fld.Caption;
      G.ColWidths[J] := 140;
    end;
    for I := 0 to ARows.Count - 1 do
      for J := 0 to AFields.Count - 1 do
        G.Cells[J, I + 1] := TStringList(ARows[I])[J];
    if ARows.Count > 0 then G.Row := 1;
    Ok := TButton.Create(F);
    Ok.Parent := Pn;
    Ok.Caption := Tr('OK');
    Ok.ModalResult := mrOk;
    Ok.Default := True;
    Ok.SetBounds(F.ClientWidth - 220, 7, 96, 30);
    Ok.Anchors := [akRight, akBottom];
    Cancel := TButton.Create(F);
    Cancel.Parent := Pn;
    Cancel.Caption := Tr('Cancel');
    Cancel.ModalResult := mrCancel;
    Cancel.Cancel := True;
    Cancel.SetBounds(F.ClientWidth - 116, 7, 96, 30);
    Cancel.Anchors := [akRight, akBottom];
    if AEditable then
    begin
      Add := TButton.Create(F);
      Add.Parent := Pn;
      Add.Caption := Tr('Add row');
      Add.SetBounds(12, 7, 110, 30);
      Del := TButton.Create(F);
      Del.Parent := Pn;
      Del.Caption := Tr('Delete row');
      Del.SetBounds(130, 7, 110, 30);
      Add.Tag := 1;
      Del.Tag := 2;
      Add.OnClick := @GridHelper.Click;
      Del.OnClick := @GridHelper.Click;
      GridTarget := G;
    end;
    if F.ShowModal = mrOk then
    begin
      ARows.Clear;
      for I := 1 to G.RowCount - 1 do
      begin
        Empty := True;
        Row := TStringList.Create;
        for J := 0 to AFields.Count - 1 do
        begin
          Row.Add(G.Cells[J, I]);
          if Trim(G.Cells[J, I]) <> '' then Empty := False;
        end;
        if Empty then Row.Free else ARows.Add(Row);
      end;
      N := G.Row;
      if (N >= 1) and (N <= ARows.Count) then ACurrent := N else ACurrent := 0;
      Result := True;
    end;
  finally
    GridTarget := nil;
    F.Free;
  end;
end;

procedure TaFglGuiIO.RunForm(ADb: TAppDb; const AFormName, AFilter: string);
var
  D: TaFormDef;
  R: TaFormRunner;
begin
  D := TaFormDef.Create;
  D.FromJson(ADb.LoadObject('_sys_forms', AFormName));
  D.Name := AFormName;
  if Trim(AFilter) <> '' then
  begin
    if Trim(D.Filter) <> '' then D.Filter := '(' + D.Filter + ') AND (' + AFilter + ')'
    else D.Filter := AFilter;
  end;
  R := TaFormRunner.CreateRunner(nil, ADb, D);
  try
    R.ShowModal;
  finally
    R.Free;
  end;
end;

function TextPagesToReport(APages: TObjectList): TaRenderedReport;
const
  LineH = 16;
var
  P, L: Integer;
  Pg: TaRPage;
  It: TaRItem;
  Lines: TStringList;
begin
  Result := TaRenderedReport.Create;
  for P := 0 to APages.Count - 1 do
  begin
    Pg := TaRPage.Create;
    Result.Pages.Add(Pg);
    Lines := TStringList(APages[P]);
    for L := 0 to Lines.Count - 1 do
    begin
      if Trim(Lines[L]) = '' then Continue;
      It := TaRItem.Create;
      It.Kind := 'Text';
      It.Text := TrimRight(Lines[L]);
      It.Mono := True;
      It.X := DefPageMargin;
      It.Y := DefPageMargin + L * LineH;
      It.W := DefPageW - 2 * DefPageMargin;
      It.H := LineH;
      It.PageNo := P + 1;
      Pg.Items.Add(It);
    end;
  end;
end;

function FglPdfFromPages(APages: TObjectList; const AFile: string; out AErr: string): Boolean;
var
  Rep: TaRenderedReport;
begin
  Rep := TextPagesToReport(APages);
  try
    Result := ExportPdf(Rep, AFile, AErr);
  finally
    Rep.Free;
  end;
end;

{ Ispis: PDF pa CUPS "lp" (Linux); bez lp-a ide LCL ispis na zadani pisač. }
function FglPrintFromPages(APages: TObjectList; const APrinter: string; out AErr: string): Boolean;
var
  Rep: TaRenderedReport;
  Tmp, Lp: string;
  P: TProcess;
  Buf: array[0..1023] of Char;
  N, K: Integer;
begin
  Result := False;
  AErr := '';
  Rep := TextPagesToReport(APages);
  try
    Lp := FindDefaultExecutablePath('lp');
    if Lp <> '' then
    begin
      Tmp := GetTempFileName('', 'tafgl') + '.pdf';
      try
        if not ExportPdf(Rep, Tmp, AErr) then Exit;
        P := TProcess.Create(nil);
        try
          P.Executable := Lp;
          if APrinter <> '' then begin P.Parameters.Add('-d'); P.Parameters.Add(APrinter); end;
          P.Parameters.Add(Tmp);
          P.Options := [poWaitOnExit, poUsePipes, poStderrToOutput];
          P.Execute;
          Result := P.ExitStatus = 0;
          if not Result then
          begin
            N := P.Output.Read(Buf, SizeOf(Buf) - 1);
            if N < 0 then N := 0;
            Buf[N] := #0;
            AErr := Trim(string(PChar(@Buf[0])));
            if AErr = '' then AErr := 'lp je vratio ' + IntToStr(P.ExitStatus);
          end;
        finally
          P.Free;
        end;
      finally
        DeleteFile(Tmp);
      end;
    end
    else
    begin
      try
        if APrinter <> '' then
        begin
          K := Printer.Printers.IndexOf(APrinter);
          if K < 0 then begin AErr := Tr('There is no printer ') + APrinter; Exit; end;
          Printer.PrinterIndex := K;
        end;
        PrintReport(Rep);
        Result := True;
      except
        on E: Exception do AErr := E.Message;
      end;
    end;
  finally
    Rep.Free;
  end;
end;

procedure TaFglGuiIO.ShowReport(const ATitle: string; APages: TObjectList);
var
  Pv: TaReportPreview;
begin
  Pv := TaReportPreview.CreatePreview(nil, TextPagesToReport(APages), ATitle);
  try
    Pv.ShowModal;
  finally
    Pv.Free;
  end;
end;

procedure TaFglGuiIO.Finish;
begin
  if FLog = nil then Exit;
  FLog.Hide;
  FLog.Caption := Tr('End of program');
  FLog.ShowModal;
end;

function RunFglFile(ADb: TAppDb; const AFile: string; AConsole: Boolean): Integer;
var
  P: TaFglProgram;
  Lg: TStringList;
  IO: TaFglIO;
  R: TaFglRunner;
begin
  Result := 1;
  P := TaFglProgram.Create;
  Lg := TStringList.Create;
  try
    try
      P.LoadFile(AFile);
    except
      on E: Exception do
      begin
        WriteLn(E.Message);
        Exit;
      end;
    end;
    if P.CheckProgram(Lg) > 0 then
    begin
      WriteLn(Lg.Text);
      Exit;
    end;
    if AConsole then IO := TaFglConsoleIO.Create else IO := TaFglGuiIO.Create;
    try
      R := TaFglRunner.Create(P, ADb, IO);
      try
        Result := R.Run;
      finally
        R.Free;
      end;
    finally
      IO.Free;
    end;
  finally
    Lg.Free;
    P.Free;
  end;
end;


function RunFglText(ADb: TAppDb; const AText: string; AConsole: Boolean): Integer;
var
  P: TaFglProgram;
  Lg: TStringList;
  IO: TaFglIO;
  R: TaFglRunner;
begin
  Result := 1;
  P := TaFglProgram.Create;
  Lg := TStringList.Create;
  try
    try
      P.LoadText(AText, 'program');
    except
      on E: Exception do
      begin
        WriteLn(E.Message);
        Exit;
      end;
    end;
    if P.CheckProgram(Lg) > 0 then
    begin
      WriteLn(Lg.Text);
      Exit;
    end;
    if AConsole then IO := TaFglConsoleIO.Create else IO := TaFglGuiIO.Create;
    try
      R := TaFglRunner.Create(P, ADb, IO);
      try
        Result := R.Run;
      finally
        R.Free;
      end;
    finally
      IO.Free;
    end;
  finally
    Lg.Free;
    P.Free;
  end;
end;

function RunFglTextHook(ADb: TAppDb; const AText: string): Integer;
begin
  Result := RunFglText(ADb, AText, False);
end;

initialization
  OnRunFglText := @RunFglTextHook;
  GridHelper := TGridHelper.Create;
  FglPdfHook := @FglPdfFromPages;
  FglPrintHook := @FglPrintFromPages;

finalization
  GridHelper.Free;

end.
