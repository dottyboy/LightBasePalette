unit ta_letterdlg;
{ Uredjivac dopisa (tekst s poljima + tablica), pregled, izvoz u Word i PDF. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Graphics,
  ta_meta, ta_letter, ta_reportengine, ta_reportview, ta_propedit;

{ True ako je dopis spremljen. ANew = True: naziv se jos moze mijenjati. }
function EditLetter(AOwner: TComponent; ADb: TAppDb; const AName: string; ANew: Boolean): Boolean;
{ Pregled svih dopisa (ili jednog: AKey = vrijednost prvog polja primatelja). }
procedure PreviewLetter(AOwner: TComponent; ADb: TAppDb; const AName: string; const AKey: string = '');
{ "Naziv > datoteka.docx|.pdf" (makro exportletter; AKey se moze dodati kao Naziv@kljuc) }
function ExportLetterNamed(ADb: TAppDb; const AArg: string; out AErr: string): Boolean;
{ ucitaj spremljeni dopis; nil ako ga nema }
function LoadLetter(ADb: TAppDb; const AName: string): TaLetterDef;

implementation

uses
  ta_i18n;


function LoadLetter(ADb: TAppDb; const AName: string): TaLetterDef;
var
  Js: string;
begin
  Result := nil;
  Js := ADb.LoadObject('_sys_letters', AName);
  if Js = '' then Exit;
  Result := TaLetterDef.Create;
  Result.FromJson(Js);
  Result.Name := AName;
end;

procedure PreviewLetter(AOwner: TComponent; ADb: TAppDb; const AName: string; const AKey: string);
var
  D: TaLetterDef;
  Rep: TaRenderedReport;
  Err: string;
  Pv: TaReportPreview;
begin
  D := LoadLetter(ADb, AName);
  if D = nil then begin ShowMessage(Tr('There is no letter: ') + AName); Exit; end;
  try
    ADb.ClearParams;
    Rep := RenderLetters(ADb, D, Err, AKey);
    if Rep = nil then begin ShowMessage(Tr('The letter cannot be composed: ') + Err); Exit; end;
    if Rep.PageCount = 0 then
    begin
      Rep.Free;
      ShowMessage(Tr('There is no letter to print (no recipient satisfies the filter).'));
      Exit;
    end;
    Pv := TaReportPreview.CreatePreview(AOwner, Rep, 'Dopis: ' + AName);
    try
      Pv.ShowModal;
    finally
      Pv.Free;
    end;
  finally
    D.Free;
  end;
end;

function ExportLetterNamed(ADb: TAppDb; const AArg: string; out AErr: string): Boolean;
var
  P, K: Integer;
  Nm, Key, Dest, Ext: string;
  D: TaLetterDef;
  Rep: TaRenderedReport;
begin
  Result := False;
  AErr := '';
  P := Pos('>', AArg);
  if P = 0 then begin AErr := 'Oblik je: dopis > datoteka.docx (ili .pdf)'; Exit; end;
  Nm := Trim(Copy(AArg, 1, P - 1));
  Dest := Trim(Copy(AArg, P + 1, MaxInt));
  Key := '';
  K := Pos('@', Nm);
  if K > 0 then begin Key := Trim(Copy(Nm, K + 1, MaxInt)); Nm := Trim(Copy(Nm, 1, K - 1)); end;
  D := LoadLetter(ADb, Nm);
  if D = nil then begin AErr := Tr('There is no letter: ') + Nm; Exit; end;
  try
    ForceDirectories(ExtractFilePath(ExpandFileName(Dest)));
    Ext := LowerCase(ExtractFileExt(Dest));
    ADb.ClearParams;
    if Ext = '.pdf' then
    begin
      Rep := RenderLetters(ADb, D, AErr, Key);
      if Rep = nil then Exit;
      try
        Result := ExportPdf(Rep, Dest, AErr);
      finally
        Rep.Free;
      end;
    end
    else if Ext = '.html' then
    begin
      Rep := RenderLetters(ADb, D, AErr, Key);
      if Rep = nil then Exit;
      try
        Result := ExportHtml(Rep, Dest);
        if not Result then AErr := Tr('The file was not saved.');
      finally
        Rep.Free;
      end;
    end
    else Result := ExportLettersDocx(ADb, D, Dest, AErr, Key);
  finally
    D.Free;
  end;
end;

{ ---------------- uredjivac ---------------- }

type
  TLetterDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    Name, Source, Filter, TotalField, TotalLabel, FontPx: TEdit;
    SrcBox: TComboBox;
    Detail, Cols, Body: TMemo;
    InsBox: TComboBox;
    Saved: Boolean;
    IsNew: Boolean;
    procedure SrcChange(Sender: TObject);
    procedure InsertChange(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure WordClick(Sender: TObject);
    procedure PdfClick(Sender: TObject);
    function ToDef: TaLetterDef;
    function Save: Boolean;
    procedure RefreshFields;
  end;

function TLetterDlg.ToDef: TaLetterDef;
begin
  Result := TaLetterDef.Create;
  Result.Name := Trim(Name.Text);
  Result.Source := Trim(SrcBox.Text);
  Result.Filter := Trim(Filter.Text);
  Result.DetailSql := Trim(Detail.Text);
  Result.Columns := Trim(Cols.Text);
  Result.Body := Body.Text;
  Result.TotalField := Trim(TotalField.Text);
  Result.TotalLabel := Trim(TotalLabel.Text);
  if Result.TotalLabel = '' then Result.TotalLabel := 'Ukupno';
  Result.FontPx := StrToIntDef(Trim(FontPx.Text), 15);
  if (Result.FontPx < 8) or (Result.FontPx > 40) then Result.FontPx := 15;
end;

function TLetterDlg.Save: Boolean;
var
  D: TaLetterDef;
begin
  Result := False;
  D := ToDef;
  try
    if D.Name = '' then begin ShowMessage(Tr('Enter a letter name.')); Exit; end;
    if IsNew and (Db.LoadObject('_sys_letters', D.Name) <> '') then
      if MessageDlg(Tr('A letter with that name already exists. Overwrite it?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
    Db.SaveObject('_sys_letters', D.Name, D.ToJson);
    IsNew := False;
    Name.ReadOnly := True;
    Form.Caption := Tr('Letter: ') + D.Name + Tr(' (saved)');
    Saved := True;
    Result := True;
  finally
    D.Free;
  end;
end;

procedure TLetterDlg.SaveClick(Sender: TObject);
begin
  Save;
end;

{ pregled radi nad onim sto je trenutno upisano (privremeno spremanje pod istim nazivom) }
procedure TLetterDlg.PreviewClick(Sender: TObject);
begin
  if not Save then Exit;
  PreviewLetter(Form, Db, Trim(Name.Text));
end;

procedure TLetterDlg.WordClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  Err: string;
begin
  if not Save then Exit;
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter := 'Word dokument (*.docx)|*.docx';
    Dlg.DefaultExt := 'docx';
    Dlg.FileName := Trim(Name.Text) + '.docx';
    Dlg.Options := Dlg.Options + [ofOverwritePrompt];
    if not Dlg.Execute then Exit;
    if ExportLetterNamed(Db, Trim(Name.Text) + ' > ' + Dlg.FileName, Err) then ShowMessage(Tr('Saved: ') + Dlg.FileName)
    else ShowMessage(Tr('Export failed: ') + Err);
  finally
    Dlg.Free;
  end;
end;

procedure TLetterDlg.PdfClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  Err: string;
begin
  if not Save then Exit;
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter := 'PDF (*.pdf)|*.pdf';
    Dlg.DefaultExt := 'pdf';
    Dlg.FileName := Trim(Name.Text) + '.pdf';
    Dlg.Options := Dlg.Options + [ofOverwritePrompt];
    if not Dlg.Execute then Exit;
    if ExportLetterNamed(Db, Trim(Name.Text) + ' > ' + Dlg.FileName, Err) then ShowMessage(Tr('Saved: ') + Dlg.FileName)
    else ShowMessage(Tr('Export failed: ') + Err);
  finally
    Dlg.Free;
  end;
end;

{ polja izvora i posebne oznake za umetanje u tekst }
procedure TLetterDlg.RefreshFields;
var
  F: TStringList;
  I: Integer;
begin
  InsBox.Items.Clear;
  InsBox.Items.Add('(umetni polje ili oznaku…)');
  F := FieldNamesOf(Db, Trim(SrcBox.Text));
  try
    for I := 0 to F.Count - 1 do InsBox.Items.Add('[' + F[I] + ']');
  finally
    F.Free;
  end;
  InsBox.Items.Add('[tablica]');
  InsBox.Items.Add('[ukupno]');
  InsBox.Items.Add('[stavki]');
  InsBox.Items.Add('[datum]');
  InsBox.Items.Add('[vrijeme]');
  InsBox.Items.Add('[korisnik]');
  InsBox.Items.Add('[firma_naziv]');
  InsBox.Items.Add('[firma_adresa]');
  InsBox.Items.Add('[firma_mjesto]');
  InsBox.Items.Add('[firma_iban]');
  InsBox.Items.Add('{izraz}');
  InsBox.ItemIndex := 0;
end;

procedure TLetterDlg.SrcChange(Sender: TObject);
begin
  RefreshFields;
end;

procedure TLetterDlg.InsertChange(Sender: TObject);
var
  T: string;
begin
  if InsBox.ItemIndex <= 0 then Exit;
  T := InsBox.Items[InsBox.ItemIndex];
  Body.SelText := T;
  Body.SetFocus;
  InsBox.ItemIndex := 0;
end;

function EditLetter(AOwner: TComponent; ADb: TAppDb; const AName: string; ANew: Boolean): Boolean;
var
  D: TLetterDlg;
  Def: TaLetterDef;
  T: TStringList;
  Tmp: TStringList;

  function L_(const ACap: string; X, Y: Integer): TLabel;
  begin
    Result := TLabel.Create(D.Form);
    Result.Parent := D.Form;
    Result.Caption := ACap;
    Result.SetBounds(X, Y, 360, 18);
  end;

  function Ed(X, Y, W: Integer): TEdit;
  begin
    Result := TEdit.Create(D.Form);
    Result.Parent := D.Form;
    Result.SetBounds(X, Y, W, 26);
  end;

  function Mm(X, Y, W, H: Integer): TMemo;
  begin
    Result := TMemo.Create(D.Form);
    Result.Parent := D.Form;
    Result.SetBounds(X, Y, W, H);
    Result.ScrollBars := ssAutoBoth;
    Result.WordWrap := False;
    Result.Font.Name := 'DejaVu Sans Mono';
    Result.Font.Size := 10;
  end;

  function Bt(const ACap: string; X: Integer; AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(D.Form);
    Result.Parent := D.Form;
    Result.Caption := ACap;
    Result.SetBounds(X, 634, 110, 32);
    Result.OnClick := AClick;
  end;

begin
  D := TLetterDlg.Create;
  D.Db := ADb;
  D.IsNew := ANew;
  D.Form := TForm.CreateNew(AOwner);
  Tmp := TStringList.Create;
  try
    D.Form.Caption := Tr('Letter: ') + AName;
    D.Form.SetBounds(0, 0, 1060, 690);
    D.Form.Position := poOwnerFormCenter;
    L_(Tr('Letter name'), 12, 8);
    D.Name := Ed(12, 28, 250);
    L_(Tr('Recipients (one letter per row)'), 280, 8);
    D.SrcBox := TComboBox.Create(D.Form);
    D.SrcBox.Parent := D.Form;
    D.SrcBox.SetBounds(280, 28, 250, 26);
    T := ADb.UserTables;
    try D.SrcBox.Items.AddStrings(T); finally T.Free; end;
    T := ADb.ListObjects('_sys_queries');
    try D.SrcBox.Items.AddStrings(T); finally T.Free; end;
    D.SrcBox.OnChange := @D.SrcChange;
    D.SrcBox.OnExit := @D.SrcChange;
    L_(Tr('Filter (SQL condition; empty = all)'), 548, 8);
    D.Filter := Ed(548, 28, 490);
    L_('SQL stavki ({polje} = polje primatelja)', 12, 62);
    D.Detail := Mm(12, 82, 518, 100);
    L_(Tr('Table columns: field|Title|format|alignment|share'), 12, 190);
    D.Cols := Mm(12, 210, 518, 90);
    L_(Tr('Column sum'), 12, 308);
    D.TotalField := Ed(12, 328, 150);
    L_(Tr('Sum name'), 180, 308);
    D.TotalLabel := Ed(180, 328, 150);
    L_(Tr('Font size (px)'), 350, 308);
    D.FontPx := Ed(350, 328, 80);
    L_(Tr('Letter text (line start: > right, ^ center, # bold)'), 548, 62);
    D.InsBox := TComboBox.Create(D.Form);
    D.InsBox.Parent := D.Form;
    D.InsBox.Style := csDropDownList;
    D.InsBox.SetBounds(548, 82, 300, 26);
    D.InsBox.OnChange := @D.InsertChange;
    D.Body := Mm(548, 114, 490, 506);
    D.Body.WordWrap := True;
    D.Body.Font.Name := 'DejaVu Sans';
    D.Body.Font.Size := 10;
    L_(Tr('Help:'), 12, 366);
    with TMemo.Create(D.Form) do
    begin
      Parent := D.Form;
      SetBounds(12, 386, 518, 234);
      ReadOnly := True;
      ScrollBars := ssAutoVertical;
      Text := Tr('Each recipient (source row) gets their own letter on a new page.') + LineEnding + LineEnding +
        '[polje]  vrijednost polja primatelja, npr. [naziv]; s oblikom: [dug|0.00]' + LineEnding +
        '{izraz}  izraz, npr. {Zaokruzi([dug] * 1.1, 2)}' + LineEnding +
        '[tablica]  (sama u retku) tablica stavki iz SQL-a' + LineEnding +
        '[ukupno]  zbroj stupca "Zbroj stupca";  [stavki]  broj stavki' + LineEnding +
        '[datum] [vrijeme] [korisnik]' + LineEnding +
        '[firma_naziv] [firma_adresa] [firma_mjesto] [firma_iban]  (Aplikacija > Podaci o tvrtki)' + LineEnding + LineEnding +
        'SQL stavki, primjer:' + LineEnding +
        'SELECT broj, datum, iznos FROM racuni' + LineEnding +
        'WHERE partner_id = {id} AND placeno = 0' + LineEnding +
        'ORDER BY datum' + LineEnding + LineEnding +
        Tr('Columns, example:') + LineEnding +
        'broj|Broj računa||left|2' + LineEnding +
        'datum|Datum||left|2' + LineEnding +
        'iznos|Iznos|0.00|right|1';
    end;
    Bt(Tr('Preview'), 548, @D.PreviewClick);
    Bt('Word…', 664, @D.WordClick);
    Bt('PDF…', 780, @D.PdfClick);
    Bt(Tr('Save'), 12, @D.SaveClick);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(128, 634, 110, 32); end;
    { vrijednosti }
    Def := LoadLetter(ADb, AName);
    if Def = nil then
    begin
      Def := TaLetterDef.Create;
      Def.Name := AName;
      Def.Body := '#>[firma_naziv]' + LineEnding + '>[firma_mjesto], [datum]' + LineEnding + LineEnding + '#[naziv]' + LineEnding + LineEnding +
        Tr('Dear Sir or Madam,') + LineEnding + LineEnding + Tr('Write the text of the letter here.') + LineEnding + LineEnding + Tr('Yours sincerely,') + LineEnding + '[firma_naziv]';
    end;
    try
      D.Name.Text := Def.Name;
      D.Name.ReadOnly := not ANew;
      D.SrcBox.Text := Def.Source;
      D.Filter.Text := Def.Filter;
      D.Detail.Text := Def.DetailSql;
      D.Cols.Text := Def.Columns;
      D.TotalField.Text := Def.TotalField;
      D.TotalLabel.Text := Def.TotalLabel;
      D.FontPx.Text := IntToStr(Def.FontPx);
      D.Body.Text := Def.Body;
    finally
      Def.Free;
    end;
    D.RefreshFields;
    D.Form.ShowModal;
    Result := D.Saved;
  finally
    Tmp.Free;
    D.Form.Free;
    D.Free;
  end;
end;

end.
