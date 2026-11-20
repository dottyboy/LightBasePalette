unit ta_catalogdlg;
{ Dijalozi kataloga shema: biblioteka polja (za novu tablicu), cijela tablica iz
  kataloga i izbor domene za primjer-bazu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, StdCtrls, ExtCtrls, CheckLst, Dialogs, contnrs,
  ta_meta, ta_types, ta_catalog;

{ Polja iz biblioteke; tip, format, provjera, oznaka i opis dolaze iz kataloga. }
function PickCatalogFields(AOwner: TComponent; out AFields: TFieldDefs2): Boolean;
{ Cijela tablica iz kataloga. Veze se zadrze samo kad ciljna tablica vec postoji u ADb. }
function PickCatalogTable(AOwner: TComponent; ADb: TAppDb; out AName: string;
  out AFields: TFieldDefs2): Boolean;
{ 0 = odustao, 1 = nova baza, 2 = dodaj u otvorenu bazu }
function ChooseCatalogDomain(AOwner: TComponent; AHasDb: Boolean; out ADomain: TCatDomain): Integer;
{ Snimka sheme otvorene baze u datoteku domene kataloga (JSON). True ako je datoteka spremljena. }
function RunCatalogSnapshot(AOwner: TComponent; ADb: TAppDb): Boolean;

implementation

uses
  ta_i18n;


function FieldText(F: TCatField): string;
begin
  Result := F.Caption + '  (' + F.Name + ')' + LineEnding +
    '  tip: ' + F.TypeName;
  if F.Decimals >= 0 then Result := Result + ', ' + IntToStr(F.Decimals) + ' decimala';
  Result := Result + '   uloga: ' + F.Role + LineEnding;
  if F.Descr <> '' then Result := Result + '  ' + F.Descr + LineEnding;
  if F.DefaultExpr <> '' then Result := Result + '  zadano: ' + F.DefaultExpr + LineEnding;
  if F.Choices <> '' then Result := Result + Tr('  allowed: ') + StringReplace(F.Choices, ',', ', ', [rfReplaceAll]) + LineEnding
  else if F.Validation <> '' then Result := Result + '  provjera: ' + F.Validation + LineEnding;
  if F.RefTable <> '' then Result := Result + '  veza na: ' + F.RefTable + '.' + F.RefField + LineEnding;
end;

type
  TFieldPicker = class
  public
    Form: TForm;
    Search: TEdit;
    Roles: TComboBox;
    List: TCheckListBox;
    Details: TMemo;
    Items: TList;
    Checked: TStringList;
    procedure Refilter(Sender: TObject);
    procedure ShowDetails(Sender: TObject);
    procedure CheckClick(Sender: TObject);
  end;

procedure TFieldPicker.Refilter(Sender: TObject);
var
  I: Integer;
  C: TCatConcept;
  Role: string;
begin
  Items.Clear;
  List.Items.Clear;
  Role := '';
  if Roles.ItemIndex > 0 then Role := Roles.Text;
  Catalog.SearchConcepts(Search.Text, Role, Items);
  for I := 0 to Items.Count - 1 do
  begin
    C := TCatConcept(Items[I]);
    List.Items.Add(C.Def.Caption + '  —  ' + C.Key + '  [' + C.Def.TypeName + ', ' + C.Def.Role + ']');
    List.Checked[I] := Checked.IndexOf(C.Key) >= 0;
  end;
  Details.Clear;
end;

procedure TFieldPicker.ShowDetails(Sender: TObject);
var
  C: TCatConcept;
  I: Integer;
  S: string;
begin
  if (List.ItemIndex < 0) or (List.ItemIndex >= Items.Count) then Exit;
  C := TCatConcept(Items[List.ItemIndex]);
  S := FieldText(C.Def) + LineEnding + 'Pojavljuje se u:' + LineEnding;
  for I := 0 to C.Where.Count - 1 do S := S + '  • ' + C.Where[I] + LineEnding;
  Details.Text := S;
end;

procedure TFieldPicker.CheckClick(Sender: TObject);
var
  C: TCatConcept;
  K: Integer;
begin
  if (List.ItemIndex < 0) or (List.ItemIndex >= Items.Count) then Exit;
  C := TCatConcept(Items[List.ItemIndex]);
  K := Checked.IndexOf(C.Key);
  if List.Checked[List.ItemIndex] then
  begin
    if K < 0 then Checked.Add(C.Key);
  end
  else if K >= 0 then Checked.Delete(K);
end;

function PickCatalogFields(AOwner: TComponent; out AFields: TFieldDefs2): Boolean;
var
  P: TFieldPicker;
  Pn: TPanel;
  I, N: Integer;
  C: TCatConcept;
  Lb: TLabel;
begin
  Result := False;
  SetLength(AFields, 0);
  P := TFieldPicker.Create;
  P.Items := TList.Create;
  P.Checked := TStringList.Create;
  P.Form := TForm.CreateNew(AOwner);
  try
    P.Form.Caption := Tr('Fields from the catalog');
    P.Form.SetBounds(0, 0, 820, 560);
    P.Form.Position := poOwnerFormCenter;
    Pn := TPanel.Create(P.Form); Pn.Parent := P.Form; Pn.Align := alTop; Pn.Height := 40; Pn.BevelOuter := bvNone;
    Lb := TLabel.Create(P.Form); Lb.Parent := Pn; Lb.Caption := Tr('Search:'); Lb.SetBounds(8, 12, 40, 18);
    P.Search := TEdit.Create(P.Form); P.Search.Parent := Pn; P.Search.SetBounds(52, 7, 260, 26);
    P.Search.OnChange := @P.Refilter;
    Lb := TLabel.Create(P.Form); Lb.Parent := Pn; Lb.Caption := Tr('Role:'); Lb.SetBounds(330, 12, 44, 18);
    P.Roles := TComboBox.Create(P.Form); P.Roles.Parent := Pn; P.Roles.Style := csDropDownList;
    P.Roles.SetBounds(378, 7, 180, 26);
    P.Roles.Items.Add('(sve uloge)');
    for I := 0 to High(CatRoles) do P.Roles.Items.Add(CatRoles[I]);
    P.Roles.ItemIndex := 0;
    P.Roles.OnChange := @P.Refilter;
    Pn := TPanel.Create(P.Form); Pn.Parent := P.Form; Pn.Align := alBottom; Pn.Height := 42; Pn.BevelOuter := bvNone;
    with TButton.Create(P.Form) do begin Parent := Pn; Caption := Tr('Add selected'); ModalResult := mrOk; SetBounds(520, 6, 140, 30); end;
    with TButton.Create(P.Form) do begin Parent := Pn; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(668, 6, 130, 30); end;
    P.Details := TMemo.Create(P.Form);
    P.Details.Parent := P.Form;
    P.Details.Align := alRight;
    P.Details.Width := 340;
    P.Details.ReadOnly := True;
    P.Details.ScrollBars := ssAutoVertical;
    with TSplitter.Create(P.Form) do begin Parent := P.Form; Align := alRight; end;
    P.List := TCheckListBox.Create(P.Form);
    P.List.Parent := P.Form;
    P.List.Align := alClient;
    P.List.OnSelectionChange := nil;
    P.List.OnClick := @P.ShowDetails;
    P.List.OnClickCheck := @P.CheckClick;
    P.Refilter(nil);
    if P.Form.ShowModal <> mrOk then Exit;
    N := 0;
    for I := 0 to P.Checked.Count - 1 do
    begin
      C := Catalog.FindConcept(P.Checked[I]);
      if C = nil then Continue;
      SetLength(AFields, N + 1);
      CatalogFieldDef(C.Def, AFields[N]);
      Inc(N);
    end;
    Result := N > 0;
  finally
    P.Form.Free;
    P.Items.Free;
    P.Checked.Free;
    P.Free;
  end;
end;

{ ---------------- cijela tablica ---------------- }

type
  TTablePicker = class
  public
    Form: TForm;
    Domains: TComboBox;
    Tables: TListBox;
    Details: TMemo;
    procedure DomainChange(Sender: TObject);
    procedure TableClick(Sender: TObject);
    function CurDomain: TCatDomain;
    function CurTable: TCatTable;
  end;

function TTablePicker.CurDomain: TCatDomain;
begin
  Result := nil;
  if (Domains.ItemIndex >= 0) and (Domains.ItemIndex < Catalog.Domains.Count) then
    Result := TCatDomain(Catalog.Domains[Domains.ItemIndex]);
end;

function TTablePicker.CurTable: TCatTable;
var
  D: TCatDomain;
begin
  Result := nil;
  D := CurDomain;
  if (D <> nil) and (Tables.ItemIndex >= 0) then Result := TCatTable(D.Tables[Tables.ItemIndex]);
end;

procedure TTablePicker.DomainChange(Sender: TObject);
var
  D: TCatDomain;
  I: Integer;
begin
  Tables.Items.Clear;
  D := CurDomain;
  if D = nil then Exit;
  for I := 0 to D.Tables.Count - 1 do Tables.Items.Add(TCatTable(D.Tables[I]).Caption + '  (' + TCatTable(D.Tables[I]).Name + ')');
  Details.Text := D.Descr;
  if Tables.Items.Count > 0 then begin Tables.ItemIndex := 0; TableClick(nil); end;
end;

procedure TTablePicker.TableClick(Sender: TObject);
var
  T: TCatTable;
  I: Integer;
  S: string;
begin
  T := CurTable;
  if T = nil then Exit;
  S := T.Descr + LineEnding + LineEnding;
  for I := 0 to T.Fields.Count - 1 do S := S + FieldText(TCatField(T.Fields[I]));
  Details.Text := S;
end;

function PickCatalogTable(AOwner: TComponent; ADb: TAppDb; out AName: string;
  out AFields: TFieldDefs2): Boolean;
var
  P: TTablePicker;
  Pn: TPanel;
  I: Integer;
  T: TCatTable;
  F: TCatField;
  Ex: TStringList;
begin
  Result := False;
  AName := '';
  SetLength(AFields, 0);
  P := TTablePicker.Create;
  P.Form := TForm.CreateNew(AOwner);
  try
    P.Form.Caption := Tr('Table from the catalog');
    P.Form.SetBounds(0, 0, 860, 540);
    P.Form.Position := poOwnerFormCenter;
    Pn := TPanel.Create(P.Form); Pn.Parent := P.Form; Pn.Align := alTop; Pn.Height := 40; Pn.BevelOuter := bvNone;
    with TLabel.Create(P.Form) do begin Parent := Pn; Caption := Tr('Domain:'); SetBounds(8, 12, 56, 18); end;
    P.Domains := TComboBox.Create(P.Form); P.Domains.Parent := Pn; P.Domains.Style := csDropDownList;
    P.Domains.SetBounds(68, 7, 320, 26);
    for I := 0 to Catalog.Domains.Count - 1 do P.Domains.Items.Add(TCatDomain(Catalog.Domains[I]).Title);
    P.Domains.OnChange := @P.DomainChange;
    Pn := TPanel.Create(P.Form); Pn.Parent := P.Form; Pn.Align := alBottom; Pn.Height := 42; Pn.BevelOuter := bvNone;
    with TButton.Create(P.Form) do begin Parent := Pn; Caption := Tr('Take table'); ModalResult := mrOk; SetBounds(560, 6, 130, 30); end;
    with TButton.Create(P.Form) do begin Parent := Pn; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(698, 6, 130, 30); end;
    P.Details := TMemo.Create(P.Form);
    P.Details.Parent := P.Form;
    P.Details.Align := alRight;
    P.Details.Width := 460;
    P.Details.ReadOnly := True;
    P.Details.ScrollBars := ssAutoVertical;
    with TSplitter.Create(P.Form) do begin Parent := P.Form; Align := alRight; end;
    P.Tables := TListBox.Create(P.Form);
    P.Tables.Parent := P.Form;
    P.Tables.Align := alClient;
    P.Tables.OnClick := @P.TableClick;
    if P.Domains.Items.Count > 0 then begin P.Domains.ItemIndex := 0; P.DomainChange(nil); end;
    if P.Form.ShowModal <> mrOk then Exit;
    T := P.CurTable;
    if T = nil then Exit;
    Ex := ADb.UserTables;
    try
      for I := 0 to Ex.Count - 1 do Ex[I] := LowerCase(Ex[I]);
      SetLength(AFields, T.Fields.Count);
      for I := 0 to T.Fields.Count - 1 do
      begin
        F := TCatField(T.Fields[I]);
        CatalogFieldDef(F, AFields[I]);
        { veza ostaje samo ako ciljna tablica vec postoji }
        if (F.RefTable <> '') and (Ex.IndexOf(LowerCase(F.RefTable)) >= 0) then
        begin
          AFields[I].RefTable := F.RefTable;
          AFields[I].RefField := F.RefField;
          AFields[I].OnDelete := UpperCase(F.OnDelete);
        end;
      end;
    finally
      Ex.Free;
    end;
    AName := T.Name;
    Result := True;
  finally
    P.Form.Free;
    P.Free;
  end;
end;

{ ---------------- domena za primjer-bazu ---------------- }

type
  TDomainPicker = class
  public
    List: TListBox;
    Details: TMemo;
    procedure Click(Sender: TObject);
  end;

procedure TDomainPicker.Click(Sender: TObject);
var
  D: TCatDomain;
  T: TCatTable;
  I, Rows: Integer;
  S: string;
begin
  if List.ItemIndex < 0 then Exit;
  D := TCatDomain(Catalog.Domains[List.ItemIndex]);
  S := D.Descr + LineEnding + LineEnding + 'Tablice:' + LineEnding;
  Rows := 0;
  for I := 0 to D.Tables.Count - 1 do
  begin
    T := TCatTable(D.Tables[I]);
    S := S + '  • ' + T.Caption + ' (' + IntToStr(T.Fields.Count) + ' polja, ' + IntToStr(T.Rows.Count) + ' primjera)' + LineEnding;
    Inc(Rows, T.Rows.Count);
  end;
  S := S + LineEnding + 'Dobiva se i po jedna forma za svaku tablicu' + LineEnding + Tr('and a list (report) for the main tables.');
  Details.Text := S;
end;

function ChooseCatalogDomain(AOwner: TComponent; AHasDb: Boolean; out ADomain: TCatDomain): Integer;
var
  F: TForm;
  P: TDomainPicker;
  Pn: TPanel;
  B: TButton;
  I: Integer;
  R: TModalResult;
begin
  Result := 0;
  ADomain := nil;
  P := TDomainPicker.Create;
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := Tr('Sample database from the catalog');
    F.SetBounds(0, 0, 820, 480);
    F.Position := poOwnerFormCenter;
    Pn := TPanel.Create(F); Pn.Parent := F; Pn.Align := alBottom; Pn.Height := 42; Pn.BevelOuter := bvNone;
    B := TButton.Create(F); B.Parent := Pn; B.Caption := Tr('New database...'); B.ModalResult := 101; B.SetBounds(360, 6, 140, 30);
    B := TButton.Create(F); B.Parent := Pn; B.Caption := Tr('Add to the open database'); B.ModalResult := 102;
    B.SetBounds(508, 6, 170, 30); B.Enabled := AHasDb;
    B := TButton.Create(F); B.Parent := Pn; B.Caption := Tr('Cancel'); B.ModalResult := mrCancel; B.Cancel := True; B.SetBounds(686, 6, 110, 30);
    P.Details := TMemo.Create(F);
    P.Details.Parent := F;
    P.Details.Align := alRight;
    P.Details.Width := 400;
    P.Details.ReadOnly := True;
    P.Details.ScrollBars := ssAutoVertical;
    with TSplitter.Create(F) do begin Parent := F; Align := alRight; end;
    P.List := TListBox.Create(F);
    P.List.Parent := F;
    P.List.Align := alClient;
    P.List.OnClick := @P.Click;
    for I := 0 to Catalog.Domains.Count - 1 do
      P.List.Items.Add(TCatDomain(Catalog.Domains[I]).Title + '  (' + IntToStr(TCatDomain(Catalog.Domains[I]).Tables.Count) + ' tablica)');
    if P.List.Items.Count > 0 then begin P.List.ItemIndex := 0; P.Click(nil); end;
    R := F.ShowModal;
    if (R = 101) or (R = 102) then
    begin
      if P.List.ItemIndex >= 0 then
      begin
        ADomain := TCatDomain(Catalog.Domains[P.List.ItemIndex]);
        Result := R - 100;
      end;
    end;
  finally
    F.Free;
    P.Free;
  end;
end;


type
  TSnapDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    Tables: TCheckListBox;
    IdEdit, TitleEdit, DescrEdit, SampleEdit: TEdit;
    Saved: Boolean;
    procedure SaveClick(Sender: TObject);
    procedure AllClick(Sender: TObject);
  end;

procedure TSnapDlg.AllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to Tables.Count - 1 do Tables.Checked[I] := True;
end;

procedure TSnapDlg.SaveClick(Sender: TObject);
var
  Sel, Log, Probs: TStringList;
  I, Rows: Integer;
  Json: string;
  Cat: TaCatalog;
  D: TSaveDialog;
  Env: string;
begin
  Sel := TStringList.Create;
  Log := TStringList.Create;
  Probs := TStringList.Create;
  try
    for I := 0 to Tables.Count - 1 do
      if Tables.Checked[I] then Sel.Add(Tables.Items[I]);
    if Sel.Count = 0 then begin ShowMessage(Tr('Select at least one table.')); Exit; end;
    if Trim(IdEdit.Text) = '' then begin ShowMessage(Tr('Enter a domain code (e.g. my_domain).')); Exit; end;
    if Trim(TitleEdit.Text) = '' then begin ShowMessage(Tr('Enter a domain title.')); Exit; end;
    Rows := StrToIntDef(Trim(SampleEdit.Text), 0);
    if Rows < 0 then Rows := 0;
    try
      Json := SnapshotToCatalogJson(Db, Trim(IdEdit.Text), Trim(TitleEdit.Text),
        IfThen(Trim(DescrEdit.Text) <> '', Trim(DescrEdit.Text), Tr('The domain was made from a database snapshot; complete the description.')), Sel, Rows, Log);
      { provjera: ista kao za ugrađene domene }
      Cat := TaCatalog.Create;
      try
        Cat.AddJson(Json, 'snimka');
        Cat.BuildIndex;
        if ValidateCatalog(Cat, Probs) > 0 then
        begin
          ShowMessage(Tr('The snapshot has problems and was not saved:') + LineEnding + Probs.Text);
          Exit;
        end;
      finally
        Cat.Free;
      end;
    except
      on E: Exception do begin ShowMessage(Tr('Snapshot failed: ') + E.Message); Exit; end;
    end;
    D := TSaveDialog.Create(nil);
    try
      D.Title := Tr('Save catalog domain');
      D.Filter := 'Domena kataloga (*.json)|*.json';
      D.DefaultExt := 'json';
      D.FileName := SnapIdent(Trim(IdEdit.Text)) + '.json';
      Env := GetEnvironmentVariable('TYPHACCESS_CATALOG');
      if Env <> '' then D.InitialDir := Env
      else D.InitialDir := ExtractFilePath(ParamStr(0)) + 'catalog';
      D.Options := D.Options + [ofOverwritePrompt];
      if not D.Execute then Exit;
      Probs.Text := Json;
      Probs.SaveToFile(D.FileName);
      Saved := True;
      ShowMessage(Tr('Saved: ') + D.FileName + LineEnding + LineEnding +
        Tr('Complete the descriptions of fields and tables by hand. The program loads the file from the catalog/ folder next to the program (or from the folder in ') +
        Tr('TYPHACCESS_CATALOG) at the next start.') + LineEnding + LineEnding + Log.Text);
      Form.ModalResult := mrOk;
    finally
      D.Free;
    end;
  finally
    Sel.Free;
    Log.Free;
    Probs.Free;
  end;
end;

function RunCatalogSnapshot(AOwner: TComponent; ADb: TAppDb): Boolean;
var
  D: TSnapDlg;
  T: TStringList;
  I: Integer;

  procedure Lbl(const ACap: string; X, Y: Integer);
  begin
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := ACap; SetBounds(X, Y, 150, 18); end;
  end;

  function Ed(Y, W: Integer): TEdit;
  begin
    Result := TEdit.Create(D.Form);
    Result.Parent := D.Form;
    Result.SetBounds(170, Y, W, 26);
  end;

begin
  D := TSnapDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Schema snapshot into the catalog');
    D.Form.SetBounds(0, 0, 620, 560);
    D.Form.Position := poOwnerFormCenter;
    Lbl(Tr('Domain code'), 14, 16);
    D.IdEdit := Ed(12, 200);
    D.IdEdit.Text := SnapIdent(ChangeFileExt(ExtractFileName(ADb.Conn.Database), ''));
    Lbl(Tr('Title'), 14, 52);
    D.TitleEdit := Ed(48, 420);
    D.TitleEdit.Text := ChangeFileExt(ExtractFileName(ADb.Conn.Database), '');
    Lbl(Tr('Description'), 14, 88);
    D.DescrEdit := Ed(84, 420);
    Lbl(Tr('Samples per table'), 14, 124);
    D.SampleEdit := Ed(120, 80);
    D.SampleEdit.Text := '0';
    Lbl(Tr('Tables in the snapshot:'), 14, 160);
    D.Tables := TCheckListBox.Create(D.Form);
    D.Tables.Parent := D.Form;
    D.Tables.SetBounds(14, 182, 580, 300);
    T := ADb.UserTables;
    try
      for I := 0 to T.Count - 1 do
      begin
        D.Tables.Items.Add(T[I]);
        D.Tables.Checked[I] := True;
      end;
    finally
      T.Free;
    end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Select all'); SetBounds(14, 492, 110, 30); OnClick := @D.AllClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Save...'); SetBounds(380, 492, 100, 30); OnClick := @D.SaveClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(490, 492, 100, 30); end;
    D.Form.ShowModal;
    Result := D.Saved;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

end.
