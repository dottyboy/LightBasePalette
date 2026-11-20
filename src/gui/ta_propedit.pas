unit ta_propedit;
{ Uredivaci svojstava u stilu Lazarusa za oba dizajnera: padajuci popisi za
  nabrojane vrijednosti i Da/Ne, gumb ... za font, boju, sliku i izraze. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Dialogs, Graphics, ValEdit, ta_meta, ta_formdef, ta_reportdef, ta_controls, ta_wizardgen;

type
  TPropKind = (pkPlain, pkBool, pkEnum, pkFont, pkColor, pkPicture, pkExpr, pkField, pkAnchors, pkIcon, pkItems);

const
  { odabir u popisu dogadjaja: napravi novi makro i otvori ga u uredjivacu blokova }
  NewMacroBlocksItem = '<novi makro blokovima…>';
  { klasa svojstava: nova klasa iz svojstava oznacene kontrole (19.7) }
  NewPropClassItem = '<nova klasa iz ove kontrole…>';

function PropKindOf(const AKey: string): TPropKind;
{ Nazivi polja izvora (tablice ili upita) za padajuci popis. }
function FieldNamesOf(ADb: TAppDb; const ASource: string): TStringList;
type
  { Sve sto uredivaci trebaju znati o okolini odabrane kontrole. Liste su vlasnistvo konteksta. }
  TPropContext = record
    Kind: string;                 { vrsta kontrole; prazno = forma / izvjesce }
    Fields: TStrings;             { polja izvora forme/izvjesca }
    ChildFields: TStrings;        { polja izvora podforme / podizvjesca }
    Sources: TStrings;            { tablice i upiti }
    Forms, Reports, Macros, Procs, Containers, PropClasses: TStrings;
    Siblings: TStrings;           { nazivi ostalih kontrola forme, za sidra uz susjeda }
  end;

{ Postavlja uredivace na redove koji su vec u AGrid. }
procedure ConfigureProps(AGrid: TValueListEditor; const Ctx: TPropContext);
{ Popunjava kontekst; oslobada se s FreeContext. }
procedure FillContext(ADb: TAppDb; var Ctx: TPropContext; const AKind, ASource, ARowSource: string;
  AContainers: TStrings; ASiblings: TStrings = nil);
procedure FreeContext(var Ctx: TPropContext);
{ Imena procedura iz modula (za dogadjaje). }
function ModuleProcedures(ADb: TAppDb): TStringList;
{ Pregled fonta jedne kontrole, npr. "DejaVu Sans, 10 pt, podebljano". }
function FontSummary(D: TaControlDef): string;
{ Dijalog fonta; AVals dobiva FontName, FontSize, Bold, Italic, ForeColor. }
function RunFontDialog(AOwner: TComponent; D: TaControlDef; AVals: TStrings): Boolean;
function RunColorDialog(AOwner: TComponent; const ACur: string; out ANew: string): Boolean;
function RunPictureDialog(AOwner: TComponent; out APath: string): Boolean;
{ Sidrenje uz rubove prozora: kvacice oko pravokutnika i gotovi obrasci. ALetters su slova L, T, R, B. }
function RunAnchorsDialog(AOwner: TComponent; var ALetters: string): Boolean;
{ biranje ikone iz zalihe: pretraga po nazivu i skupini, dvoklik potvrdjuje; prazan naziv = bez ikone }
function RunIconDialog(AOwner: TComponent; var AIcon: string): Boolean;
{ uredjivanje stavki bocnog izbornika (skupine i stavke, jedan redak po stavci) }
function RunItemsDialog(AOwner: TComponent; var AText: string): Boolean;
{ Višeredni unos teksta (pravila oblikovanja, popunjavanje, SQL...). }
function RunTextDialog(AOwner: TComponent; const ATitle, AHint: string; var AValue: string): Boolean;

implementation

uses
  ta_i18n,
  StdCtrls, Controls, ExtCtrls, ComCtrls, ta_icons, ta_iconsdata, ta_iconmap;

type
  TAnchorDlg = class
  public
    Form: TForm;
    Box: array[0..3] of TCheckBox;     { L, T, R, B }
    Info: TLabel;
    procedure PresetClick(Sender: TObject);
    procedure Changed(Sender: TObject);
  end;

procedure TAnchorDlg.Changed(Sender: TObject);
var
  S: string;
begin
  S := '';
  if Box[0].Checked then S := S + 'L';
  if Box[1].Checked then S := S + 'T';
  if Box[2].Checked then S := S + 'R';
  if Box[3].Checked then S := S + 'B';
  if S = 'LT' then Info.Caption := Tr('The control stays in the same place when the window changes.')
  else if (Pos('L', S) > 0) and (Pos('R', S) > 0) and (Pos('T', S) > 0) and (Pos('B', S) > 0) then Info.Caption := Tr('The control stretches in both width and height.')
  else if (Pos('L', S) > 0) and (Pos('R', S) > 0) then Info.Caption := Tr('The control stretches in width.')
  else if (Pos('T', S) > 0) and (Pos('B', S) > 0) then Info.Caption := Tr('The control stretches in height.')
  else if (Pos('R', S) > 0) and (Pos('L', S) = 0) then Info.Caption := Tr('The control follows the right edge.')
  else if (Pos('B', S) > 0) and (Pos('T', S) = 0) then Info.Caption := Tr('The control follows the bottom edge.')
  else if S = '' then Info.Caption := Tr('No anchor: the control moves toward the center when the size changes.')
  else Info.Caption := '';
end;

procedure TAnchorDlg.PresetClick(Sender: TObject);
var
  S: string;
begin
  S := AnchorLetters(TButton(Sender).Hint);
  Box[0].Checked := Pos('L', S) > 0;
  Box[1].Checked := Pos('T', S) > 0;
  Box[2].Checked := Pos('R', S) > 0;
  Box[3].Checked := Pos('B', S) > 0;
  Changed(nil);
end;

type
  TIconDlg = class
    Form: TForm;
    Search: TEdit;
    View: TListView;
    Chosen: string;
    procedure Fill;
    procedure SearchChanged(Sender: TObject);
    procedure Picked(Sender: TObject);
    procedure None(Sender: TObject);
  end;

procedure TIconDlg.Fill;
var
  I: Integer;
  Q: string;
  It: TListItem;
begin
  Q := IconFold(Search.Text);
  View.Items.BeginUpdate;
  try
    View.Items.Clear;
    for I := 0 to IconDataCount - 1 do
      if (Q = '') or (Pos(Q, IconDataName(I)) > 0) or (Pos(Q, IconFold(IconDataGroup(IconDataName(I)))) > 0) then
      begin
        It := View.Items.Add;
        It.Caption := IconDataName(I);
        It.ImageIndex := I;
        if IconDataName(I) = Chosen then begin View.Selected := It; end;
      end;
  finally
    View.Items.EndUpdate;
  end;
end;

procedure TIconDlg.SearchChanged(Sender: TObject);
begin
  Fill;
end;

procedure TIconDlg.Picked(Sender: TObject);
begin
  if View.Selected <> nil then
  begin
    Chosen := View.Selected.Caption;
    Form.ModalResult := mrOk;
  end;
end;

procedure TIconDlg.None(Sender: TObject);
begin
  Chosen := '';
  Form.ModalResult := mrOk;
end;

function RunIconDialog(AOwner: TComponent; var AIcon: string): Boolean;
var
  D: TIconDlg;
begin
  Result := False;
  D := TIconDlg.Create;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Chosen := AIcon;
    D.Form.Caption := Tr('Choose an icon');
    D.Form.Position := poOwnerFormCenter;
    D.Form.BorderStyle := bsDialog;
    D.Form.ClientWidth := 560;
    D.Form.ClientHeight := 440;
    with TLabel.Create(D.Form) do begin Parent := D.Form; SetBounds(12, 14, 60, 18); Caption := Tr('Search:'); end;
    D.Search := TEdit.Create(D.Form);
    D.Search.Parent := D.Form;
    D.Search.SetBounds(70, 10, 300, 26);
    D.Search.OnChange := @D.SearchChanged;
    D.View := TListView.Create(D.Form);
    D.View.Parent := D.Form;
    D.View.SetBounds(12, 44, 536, 340);
    D.View.ViewStyle := vsIcon;
    D.View.LargeImages := IconList(24);
    D.View.OnDblClick := @D.Picked;
    D.Fill;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('No icon'); SetBounds(12, 396, 110, 30); OnClick := @D.None; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('OK'); SetBounds(340, 396, 96, 30); OnClick := @D.Picked; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(444, 396, 96, 30); end;
    if D.Form.ShowModal = mrOk then
    begin
      AIcon := D.Chosen;
      Result := True;
    end;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

function RunItemsDialog(AOwner: TComponent; var AText: string): Boolean;
var
  F: TForm;
  M: TMemo;
begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := Tr('Side menu items');
    F.Position := poOwnerFormCenter;
    F.BorderStyle := bsDialog;
    F.ClientWidth := 560;
    F.ClientHeight := 420;
    with TLabel.Create(F) do
    begin
      Parent := F; SetBounds(12, 8, 536, 90); AutoSize := False; WordWrap := True;
      Caption := Tr('One row per item:') + LineEnding +
        '# Naslov skupine|ikona        skupina koja se sklapa (ikona nije obavezna)' + LineEnding +
        'Natpis|akcija|ikona           stavka; akcija kao na gumbu, npr. openform:Računi, openreport:Pregled, macro:Naziv' + LineEnding +
        'Ako ikone nema, program je bira prema akciji i natpisu.';
    end;
    M := TMemo.Create(F);
    M.Parent := F;
    M.SetBounds(12, 100, 536, 270);
    M.ScrollBars := ssAutoBoth;
    M.Text := AText;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(340, 380, 96, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(444, 380, 96, 30); end;
    if F.ShowModal = mrOk then
    begin
      AText := M.Text;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

function RunAnchorsDialog(AOwner: TComponent; var ALetters: string): Boolean;
const
  Names: array[0..3] of string = ('Lijevo', 'Gore', 'Desno', 'Dolje');
  Presets: array[0..5] of string = (
    'Fiksno (gore-lijevo)|LT', 'Rasteži vodoravno|LTR', 'Rasteži okomito|LTB', 'Rasteži oboje|LTRB',
    'Dolje desno|RB', 'Dolje, vodoravno|LRB');
var
  D: TAnchorDlg;
  I, P: Integer;
  B: TButton;
  Cur: string;
begin
  Result := False;
  D := TAnchorDlg.Create;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Control anchoring');
    D.Form.Position := poOwnerFormCenter;
    D.Form.BorderStyle := bsDialog;
    D.Form.ClientWidth := 440;
    D.Form.ClientHeight := 330;
    with TLabel.Create(D.Form) do
    begin
      Parent := D.Form; SetBounds(16, 10, 400, 18);
      Caption := Tr('To which window edges the control sticks when the window changes:');
    end;
    { pravokutnik forme i kvacice oko kontrole }
    with TShape.Create(D.Form) do
    begin
      Parent := D.Form; SetBounds(50, 48, 180, 120); Brush.Color := $F4F4F4; Pen.Color := $A0A0A0;
    end;
    with TShape.Create(D.Form) do
    begin
      Parent := D.Form; SetBounds(110, 88, 60, 40); Brush.Color := $E0A060; Pen.Color := $804020;
    end;
    for I := 0 to 3 do
    begin
      D.Box[I] := TCheckBox.Create(D.Form);
      D.Box[I].Parent := D.Form;
      D.Box[I].Caption := Tr(Names[I]);
      D.Box[I].OnChange := @D.Changed;
    end;
    D.Box[0].SetBounds(54, 100, 56, 20);    { lijevo }
    D.Box[1].SetBounds(114, 52, 56, 20);    { gore }
    D.Box[2].SetBounds(172, 100, 58, 20);   { desno }
    D.Box[3].SetBounds(114, 140, 56, 20);   { dolje }
    D.Info := TLabel.Create(D.Form);
    D.Info.Parent := D.Form;
    D.Info.SetBounds(16, 180, 410, 36);
    D.Info.AutoSize := False;
    D.Info.WordWrap := True;
    Cur := ALetters;
    if Cur = '' then Cur := 'LT';
    D.Box[0].Checked := Pos('L', Cur) > 0;
    D.Box[1].Checked := Pos('T', Cur) > 0;
    D.Box[2].Checked := Pos('R', Cur) > 0;
    D.Box[3].Checked := Pos('B', Cur) > 0;
    for I := 0 to High(Presets) do
    begin
      P := Pos('|', Presets[I]);
      B := TButton.Create(D.Form);
      B.Parent := D.Form;
      B.Caption := Tr(Copy(Presets[I], 1, P - 1));
      B.Hint := Copy(Presets[I], P + 1, MaxInt);
      B.SetBounds(250 + (I mod 2) * 0, 48 + I * 30, 170, 26);
      B.OnClick := @D.PresetClick;
    end;
    with TButton.Create(D.Form) do
    begin
      Parent := D.Form; Caption := Tr('OK'); ModalResult := mrOk; Default := True; SetBounds(230, 280, 90, 30);
    end;
    with TButton.Create(D.Form) do
    begin
      Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; Cancel := True; SetBounds(330, 280, 90, 30);
    end;
    D.Changed(nil);
    if D.Form.ShowModal = mrOk then
    begin
      Cur := '';
      if D.Box[0].Checked then Cur := Cur + 'L';
      if D.Box[1].Checked then Cur := Cur + 'T';
      if D.Box[2].Checked then Cur := Cur + 'R';
      if D.Box[3].Checked then Cur := Cur + 'B';
      ALetters := Cur;
      Result := True;
    end;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

function RunTextDialog(AOwner: TComponent; const ATitle, AHint: string; var AValue: string): Boolean;
var
  F: TForm;
  M: TMemo;
begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := ATitle;
    F.SetBounds(0, 0, 640, 360);
    F.Position := poOwnerFormCenter;
    with TLabel.Create(F) do begin Parent := F; Caption := AHint; SetBounds(12, 8, 610, 40); WordWrap := True; end;
    M := TMemo.Create(F);
    M.Parent := F;
    M.SetBounds(12, 52, 610, 240);
    M.ScrollBars := ssAutoBoth;
    M.Text := AValue;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(430, 304, 90, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(530, 304, 90, 30); end;
    if F.ShowModal = mrOk then
    begin
      AValue := Trim(M.Text);
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

function PropKindOf(const AKey: string): TPropKind;
begin
  if (AKey = 'Bold') or (AKey = 'Italic') or (AKey = 'Locked') or (AKey = 'ShowText') or (AKey = 'Search') or
     (AKey = 'AllowEdits') or (AKey = 'AllowAdds') or (AKey = 'AllowDeletes') or (AKey = 'Resizable') or
     (AKey = 'Accordion') or (AKey = 'CanMinimize') or (AKey = 'CanMaximize') or (AKey = 'StartMaximized') then Exit(pkBool);
  if (AKey = 'Anchors') or (AKey = 'BorderSpacing') or (AKey = 'AnchorLeft') or (AKey = 'AnchorTop') or (AKey = 'AnchorRight') or
     (AKey = 'AnchorBottom') then Exit(pkAnchors);
  if AKey = 'Icon' then Exit(pkIcon);
  if AKey = 'Items' then Exit(pkItems);
  if (AKey = 'BarType') or (AKey = 'ChartType') or (AKey = 'SizeMode') or (AKey = 'Align') or (AKey = 'Dock') or (AKey = 'View') or
     (AKey = 'FontName') or (AKey = 'FontSize') then Exit(pkEnum);
  if AKey = 'Font' then Exit(pkFont);
  if (AKey = 'ForeColor') or (AKey = 'BackColor') then Exit(pkColor);
  if AKey = 'Picture' then Exit(pkPicture);
  if (AKey = 'ControlSource') or (AKey = 'Source') then Exit(pkField);
  if (AKey = 'VisibleIf') or (AKey = 'EnabledIf') or (AKey = 'CondFormat') or
     (AKey = 'Filter') or (AKey = 'OrderBy') or (AKey = 'CalcFields') or (AKey = 'AutoFill') or (AKey = 'CalcRules') or
     (AKey = 'GridFormat') or (AKey = 'Lov') or (AKey = 'LovMap') or (AKey = 'GridLov') then Exit(pkExpr);
  Result := pkPlain;
end;

function FieldNamesOf(ADb: TAppDb; const ASource: string): TStringList;
var
  L: TaSourceFields;
  I: Integer;
begin
  Result := TStringList.Create;
  if (ADb = nil) or (Trim(ASource) = '') then Exit;
  Inc(ADb.QuietParams);
  try
    try
      L := SourceFieldList(ADb, Trim(ASource));
    except
      Exit;
    end;
  finally
    Dec(ADb.QuietParams);
  end;
  for I := 0 to High(L) do Result.Add(L[I].Name);
end;

function EnumList(const AKey: string): string;
var
  I: Integer;
  S: string;
begin
  if AKey = 'BarType' then Exit('qr,code128,ean13,ean8,code39,itf,pdf417,hub3');
  if AKey = 'ChartType' then Exit('bar,line,pie');
  if AKey = 'SizeMode' then Exit('zoom,stretch,clip');
  if AKey = 'Align' then Exit('left,center,right');
  if AKey = 'Dock' then Exit('none,top,bottom,left,right,client');
  if AKey = 'View' then Exit(',datasheet,split');
  if AKey = 'FontSize' then Exit('8,9,10,11,12,14,16,18,20,24,28,36,48');
  Result := '';
  if AKey = 'FontName' then
  begin
    S := '';
    for I := 0 to Screen.Fonts.Count - 1 do
    begin
      if Screen.Fonts[I] = '' then Continue;
      if S <> '' then S := S + ',';
      S := S + StringReplace(Screen.Fonts[I], ',', ' ', [rfReplaceAll]);
    end;
    Result := S;
  end;
end;

const
  FormatList = '#,##0.00|0.00|0|#,##0|0%|0.00 "€"|dd.mm.yyyy|dd.mm.yyyy hh:nn|hh:nn|yyyy-mm-dd';
  EventKeys = ',OnChange,OnDblClick,OnOpen,OnCurrent,BeforeUpdate,AfterUpdate,BeforeDelete,OnClose,' +
    'BeforeInsert,AfterInsert,AfterDelete,OnError,AfterQuery,OnEnter,OnExit,OnValidate,OnKey,' +
    'FieldOnEnter,FieldOnExit,FieldOnValidate,FieldOnKey,';

function ModuleProcedures(ADb: TAppDb): TStringList;
var
  Mods, Lines: TStringList;
  I, J, P: Integer;
  L, N: string;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
  if ADb = nil then Exit;
  Mods := ADb.ListObjects('_sys_modules');
  Lines := TStringList.Create;
  try
    for I := 0 to Mods.Count - 1 do
    begin
      Lines.Text := ADb.LoadObject('_sys_modules', Mods[I]);
      for J := 0 to Lines.Count - 1 do
      begin
        L := Trim(Lines[J]);
        if LowerCase(Copy(L, 1, 10)) = 'procedure ' then N := Copy(L, 11, MaxInt)
        else Continue;
        P := 1;
        while (P <= Length(N)) and (N[P] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(P);
        N := Copy(N, 1, P - 1);
        if N <> '' then Result.Add(N);
      end;
    end;
  finally
    Lines.Free;
    Mods.Free;
  end;
end;

procedure FillContext(ADb: TAppDb; var Ctx: TPropContext; const AKind, ASource, ARowSource: string;
  AContainers: TStrings; ASiblings: TStrings = nil);
var
  T: TStringList;
  Fd: TaFormDef;
  Rd: TaReportDef;
begin
  Ctx.Kind := AKind;
  Ctx.Fields := FieldNamesOf(ADb, ASource);
  Ctx.Sources := TStringList.Create;
  Ctx.Forms := TStringList.Create;
  Ctx.Reports := TStringList.Create;
  Ctx.Macros := TStringList.Create;
  Ctx.Procs := ModuleProcedures(ADb);
  Ctx.Containers := TStringList.Create;
  Ctx.ChildFields := TStringList.Create;
  Ctx.PropClasses := TStringList.Create;
  if ADb <> nil then
  begin
    T := ADb.ListObjects('_sys_propclasses');
    try Ctx.PropClasses.AddStrings(T); finally T.Free; end;
    T := ADb.UserTables;
    try Ctx.Sources.AddStrings(T); finally T.Free; end;
    T := ADb.ListObjects('_sys_queries');
    try Ctx.Sources.AddStrings(T); finally T.Free; end;
    T := ADb.ListObjects('_sys_forms');
    try Ctx.Forms.AddStrings(T); finally T.Free; end;
    T := ADb.ListObjects('_sys_reports');
    try Ctx.Reports.AddStrings(T); finally T.Free; end;
    T := ADb.ListObjects('_sys_macros');
    try Ctx.Macros.AddStrings(T); finally T.Free; end;
    { polja djeteta: tablica/upit, ili izvor druge forme / izvjesca }
    if Trim(ARowSource) <> '' then
    begin
      if AKind = 'Subform' then
      begin
        if Ctx.Forms.IndexOf(ARowSource) >= 0 then
        begin
          Fd := TaFormDef.Create;
          try
            Fd.FromJson(ADb.LoadObject('_sys_forms', ARowSource));
            T := FieldNamesOf(ADb, Fd.RecordSource);
          finally
            Fd.Free;
          end;
        end
        else T := FieldNamesOf(ADb, ARowSource);
        try Ctx.ChildFields.AddStrings(T); finally T.Free; end;
      end
      else if AKind = 'Subreport' then
      begin
        Rd := TaReportDef.Create;
        try
          if ADb.LoadObject('_sys_reports', ARowSource) <> '' then Rd.FromJson(ADb.LoadObject('_sys_reports', ARowSource));
          T := FieldNamesOf(ADb, Rd.RecordSource);
        finally
          Rd.Free;
        end;
        try Ctx.ChildFields.AddStrings(T); finally T.Free; end;
      end;
    end;
  end;
  if AContainers <> nil then Ctx.Containers.AddStrings(AContainers);
  Ctx.Siblings := TStringList.Create;
  if ASiblings <> nil then Ctx.Siblings.AddStrings(ASiblings);
end;

procedure FreeContext(var Ctx: TPropContext);
begin
  Ctx.Fields.Free; Ctx.ChildFields.Free; Ctx.Sources.Free; Ctx.Forms.Free; Ctx.Reports.Free;
  Ctx.Macros.Free; Ctx.Procs.Free; Ctx.Containers.Free; Ctx.Siblings.Free; Ctx.PropClasses.Free;
end;

function RowSourceIsList(const AKind: string): Boolean;
begin
  Result := (AKind = 'ComboBox') or (AKind = 'ListBox') or (AKind = 'OptionGroup') or (AKind = 'Chart');
end;

procedure ConfigureProps(AGrid: TValueListEditor; const Ctx: TPropContext);
var
  R, I, J: Integer;
  K, Sd: string;
  P: TItemProp;
  Pl, Nm, Sl: TStringList;
  Horiz: Boolean;

  procedure Pick(AItems: TStrings);
  begin
    P.EditStyle := esPickList;
    P.PickList.Clear;
    if AItems <> nil then P.PickList.Assign(AItems);
  end;

  procedure PickCsv(const ACsv: string; ASep: Char = ',');
  begin
    P.EditStyle := esPickList;
    P.PickList.Clear;
    Pl := TStringList.Create;
    try
      Pl.Delimiter := ASep;
      Pl.StrictDelimiter := True;
      Pl.QuoteChar := #0;
      Pl.DelimitedText := ACsv;
      P.PickList.Assign(Pl);
    finally
      Pl.Free;
    end;
  end;

  procedure PickEvents;
  var
    I: Integer;
  begin
    P.EditStyle := esPickList;
    P.PickList.Clear;
    P.PickList.Add('');
    P.PickList.Add(NewMacroBlocksItem);
    if Ctx.Macros <> nil then
      for I := 0 to Ctx.Macros.Count - 1 do P.PickList.Add('macro:' + Ctx.Macros[I]);
    if Ctx.Procs <> nil then P.PickList.AddStrings(Ctx.Procs);
  end;

begin
  for R := 1 to AGrid.RowCount - 1 do
  begin
    K := AGrid.Cells[0, R];
    if K = '' then Continue;
    P := AGrid.ItemProps[K];
    if P = nil then Continue;
    if K = 'LinkMaster' then begin Pick(Ctx.Fields); Continue; end;
    if K = 'LinkChild' then begin Pick(Ctx.ChildFields); Continue; end;
    if K = 'RowSource' then
    begin
      if Ctx.Kind = 'Subform' then
      begin
        P.EditStyle := esPickList;
        P.PickList.Clear;
        if Ctx.Sources <> nil then P.PickList.AddStrings(Ctx.Sources);
        if Ctx.Forms <> nil then P.PickList.AddStrings(Ctx.Forms);
      end
      else if Ctx.Kind = 'Subreport' then Pick(Ctx.Reports)
      else if RowSourceIsList(Ctx.Kind) then P.EditStyle := esEllipsis;
      Continue;
    end;
    if (K = 'AnchorLeft') or (K = 'AnchorRight') or (K = 'AnchorTop') or (K = 'AnchorBottom') then
    begin
      { sidra se biraju u uredjivacu sidrenja (gumb ...), ali se mogu i upisati ('Naziv:strana') }
      P.EditStyle := esEllipsis;
      Continue;
    end;
    if K = 'Container' then begin Pick(Ctx.Containers); Continue; end;
    if (K = 'Variant') and (VariantsForKind(Ctx.Kind) <> '') then begin PickCsv(VariantsForKind(Ctx.Kind)); Continue; end;
    if K = 'PropertyClass' then
    begin
      Pick(Ctx.PropClasses);
      P.PickList.Insert(0, '');
      P.PickList.Add(NewPropClassItem);
      Continue;
    end;
    if K = 'Page' then begin PickCsv('0,1,2,3,4,5,6,7'); Continue; end;
    if K = 'Format' then begin PickCsv(FormatList, '|'); Continue; end;
    if (K = 'OnClick') or (K = 'AutoFill') or (K = 'CalcRules') or (K = 'CondFormat') or (K = 'GridFormat') or
       (K = 'Lov') or (K = 'LovMap') or (K = 'GridLov') then
    begin
      P.EditStyle := esEllipsis;
      Continue;
    end;
    if Pos(',' + K + ',', EventKeys) > 0 then begin PickEvents; Continue; end;
    case PropKindOf(K) of
      pkBool:
        begin
          P.EditStyle := esPickList;
          P.PickList.CommaText := 'True,False';
          P.ReadOnly := False;
        end;
      pkEnum:
        begin
          P.EditStyle := esPickList;
          P.PickList.Clear;
          Pl := TStringList.Create;
          try
            Pl.Delimiter := ',';
            Pl.StrictDelimiter := True;
            Pl.QuoteChar := #0;
            Pl.DelimitedText := EnumList(K);
            P.PickList.Assign(Pl);
          finally
            Pl.Free;
          end;
        end;
      pkFont, pkColor, pkPicture, pkAnchors, pkIcon, pkItems:
        begin
          P.EditStyle := esEllipsis;
          P.ReadOnly := (K = 'Font') or (K = 'Anchors') or (K = 'Icon') or (K = 'Items');
        end;
      pkExpr:
        P.EditStyle := esEllipsis;
      pkField:
        begin
          P.EditStyle := esPickList;
          P.PickList.Clear;
          if K = 'Source' then begin if Ctx.Sources <> nil then P.PickList.Assign(Ctx.Sources); end
          else if Ctx.Fields <> nil then P.PickList.Assign(Ctx.Fields);
        end;
    end;
  end;
end;

function FontSummary(D: TaControlDef): string;
var
  N, Sz: string;
begin
  N := DefGet(D, 'FontName');
  Sz := DefGet(D, 'FontSize');
  if N = '' then N := '(zadani)';
  if Sz = '' then Sz := '(zadana)' else Sz := Sz + ' pt';
  Result := N + ', ' + Sz;
  if StrToBoolDef(DefGet(D, 'Bold'), False) then Result := Result + ', podebljano';
  if StrToBoolDef(DefGet(D, 'Italic'), False) then Result := Result + ', kurziv';
end;

function RunFontDialog(AOwner: TComponent; D: TaControlDef; AVals: TStrings): Boolean;
var
  Fd: TFontDialog;
  Sz: Integer;
begin
  Result := False;
  Fd := TFontDialog.Create(AOwner);
  try
    if DefGet(D, 'FontName') <> '' then Fd.Font.Name := DefGet(D, 'FontName');
    Sz := StrToIntDef(DefGet(D, 'FontSize'), 0);
    if Sz > 0 then Fd.Font.Size := Sz;
    Fd.Font.Style := [];
    if StrToBoolDef(DefGet(D, 'Bold'), False) then Fd.Font.Style := Fd.Font.Style + [fsBold];
    if StrToBoolDef(DefGet(D, 'Italic'), False) then Fd.Font.Style := Fd.Font.Style + [fsItalic];
    Fd.Font.Color := HexToColor(DefGet(D, 'ForeColor'), clWindowText);
    if not Fd.Execute then Exit;
    AVals.Clear;
    AVals.Values['FontName'] := Fd.Font.Name;
    AVals.Values['FontSize'] := IntToStr(Fd.Font.Size);
    AVals.Values['Bold'] := BoolToStr(fsBold in Fd.Font.Style, 'True', 'False');
    AVals.Values['Italic'] := BoolToStr(fsItalic in Fd.Font.Style, 'True', 'False');
    AVals.Values['ForeColor'] := ColorToHex(Fd.Font.Color);
    Result := True;
  finally
    Fd.Free;
  end;
end;

function RunColorDialog(AOwner: TComponent; const ACur: string; out ANew: string): Boolean;
var
  Cd: TColorDialog;
begin
  Result := False;
  ANew := ACur;
  Cd := TColorDialog.Create(AOwner);
  try
    Cd.Color := HexToColor(ACur, clWhite);
    if not Cd.Execute then Exit;
    ANew := ColorToHex(Cd.Color);
    Result := True;
  finally
    Cd.Free;
  end;
end;

function RunPictureDialog(AOwner: TComponent; out APath: string): Boolean;
var
  Od: TOpenDialog;
  Ic: string;
begin
  Result := False;
  APath := '';
  case QuestionDlg('Slika', 'Odakle slika?', mtConfirmation,
    [mrYes, 'Iz zalihe ikona (velika)', mrNo, 'Iz datoteke (PNG, JPG, SVG…)', mrCancel, 'Odustani'], 0) of
    mrYes:
      begin
        Ic := '';
        if not RunIconDialog(AOwner, Ic) then Exit;
        if Ic = '' then Exit;
        APath := 'icon:' + Ic;
        if QuestionDlg('Ikona', 'Izvedba ikone:', mtConfirmation,
          [mrYes, 'Svijetla (za svijetlu podlogu)', mrNo, 'Tamna (za tamnu podlogu)'], 0) = mrNo then APath := APath + ':tamna';
        Exit(True);
      end;
    mrNo: ;
  else
    Exit;
  end;
  Od := TOpenDialog.Create(AOwner);
  try
    Od.Title := Tr('Choose a picture');
    Od.Filter := Tr('Pictures (*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.svg)|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.svg|All files|*');
    if not Od.Execute then Exit;
    APath := Od.FileName;
    Result := True;
  finally
    Od.Free;
  end;
end;

end.
