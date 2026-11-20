unit ta_auditdlg;
{ Revizijski trag: odabir pracenih tablica i pregled zapisa o promjenama. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, DBGrids, DB, CheckLst,
  ZDataset, ta_meta, ta_audit, ta_params, ta_gridview, ta_family;

{ ATable / AKey nisu obavezni: otvaraju pregled vec filtriran na tablicu i zapis. }
procedure RunAuditViewer(AOwner: TComponent; ADb: TAppDb; const ATable: string = '';
  const AKey: string = '');

implementation

uses
  ta_i18n;


type
  TAuditDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    Tables: TCheckListBox;
    TblBox, ActBox: TComboBox;
    UserEdit, KeyEdit, FromEdit, ToEdit: TEdit;
    Grid: TaGridView;
    Source: TDataSource;
    Query: TZQuery;
    CountLbl: TLabel;
    procedure RefreshClick(Sender: TObject);
    procedure PurgeClick(Sender: TObject);
    procedure TableCheck(Sender: TObject);
    procedure Reload;
    function IsoDate(const S: string): string;
  end;

function TAuditDlg.IsoDate(const S: string): string;
begin
  Result := '';
  if Trim(S) = '' then Exit;
  Result := ParamLiteral(S);
  if (Result <> '') and (Result[1] = '''') then Result := Copy(Result, 2, Length(Result) - 2)
  else Result := '';
end;

procedure TAuditDlg.Reload;
var
  T, A: string;
  I: Integer;
begin
  T := '';
  if TblBox.ItemIndex > 0 then T := TblBox.Text;
  A := '';
  case ActBox.ItemIndex of
    1: A := 'I';
    2: A := 'U';
    3: A := 'D';
  end;
  Source.DataSet := nil;
  FreeAndNil(Query);
  Query := AuditQuery(Db, T, Trim(UserEdit.Text), A, Trim(KeyEdit.Text),
    IsoDate(FromEdit.Text), IsoDate(ToEdit.Text), 2000);
  Source.DataSet := Query;
  { sirine stupaca: vrijeme i radnja moraju stati cijeli, staro/novo dobiju ostatak }
  for I := 0 to Grid.ColCount - 1 do
    if SameText(Grid.ColFieldName(I), 'id') then Grid.SetColWidth(I, 40)
    else if SameText(Grid.ColFieldName(I), 'vrijeme') then Grid.SetColWidth(I, 150)
    else if SameText(Grid.ColFieldName(I), 'korisnik') then Grid.SetColWidth(I, 90)
    else if SameText(Grid.ColFieldName(I), 'tablica') then Grid.SetColWidth(I, 110)
    else if SameText(Grid.ColFieldName(I), 'zapis') then Grid.SetColWidth(I, 50)
    else if SameText(Grid.ColFieldName(I), 'radnja') then Grid.SetColWidth(I, 90)
    else if SameText(Grid.ColFieldName(I), 'polje') then Grid.SetColWidth(I, 80)
    else if SameText(Grid.ColFieldName(I), 'staro') or SameText(Grid.ColFieldName(I), 'novo') then Grid.SetColWidth(I, 200);
  for I := 0 to Grid.ColCount - 1 do Grid.SetColTitle(I, Tr(Grid.ColFieldName(I)));
  CountLbl.Caption := IntToStr(Query.RecordCount) + Tr(' records (newest first, at most 2000)');
end;

procedure TAuditDlg.RefreshClick(Sender: TObject);
begin
  Reload;
end;

procedure TAuditDlg.PurgeClick(Sender: TObject);
var
  S: string;
  N, Del: Integer;
begin
  S := '365';
  if not InputQuery(Tr('Audit trail'), Tr('Delete records older than (days):'), S) then Exit;
  N := StrToIntDef(Trim(S), -1);
  if N < 0 then begin ShowMessage(Tr('Enter a number of days.')); Exit; end;
  if MessageDlg(Tr('Delete records older than ') + IntToStr(N) + Tr(' days? This cannot be undone.'),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Del := AuditPurge(Db, N);
  ShowMessage(Tr('Records deleted: ') + IntToStr(Del));
  Reload;
end;

procedure TAuditDlg.TableCheck(Sender: TObject);
var
  I: Integer;
begin
  I := Tables.ItemIndex;
  if I < 0 then Exit;
  try
    if Tables.Checked[I] then AuditEnable(Db, Tables.Items[I])
    else AuditDisable(Db, Tables.Items[I]);
  except
    on E: Exception do
    begin
      ShowMessage(Tr('Failed: ') + E.Message);
      Tables.Checked[I] := AuditEnabled(Db, Tables.Items[I]);
    end;
  end;
end;

procedure RunAuditViewer(AOwner: TComponent; ADb: TAppDb; const ATable: string; const AKey: string);
var
  D: TAuditDlg;
  L: TStringList;
  I: Integer;
  P: TPanel;
begin
  D := TAuditDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('Audit trail');
    D.Form.SetBounds(0, 0, 1180, 700);
    D.Form.Position := poOwnerFormCenter;
    D.Source := TDataSource.Create(D.Form);
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Tracks changes in tables'); SetBounds(14, 10, 220, 18); end;
    D.Tables := TCheckListBox.Create(D.Form);
    D.Tables.Parent := D.Form;
    D.Tables.SetBounds(14, 32, 220, 590);
    L := ADb.UserTables;
    try
      for I := 0 to L.Count - 1 do
      begin
        D.Tables.Items.Add(L[I]);
        D.Tables.Checked[I] := AuditEnabled(ADb, L[I]);
      end;
      D.TblBox := TComboBox.Create(D.Form);
      D.TblBox.Parent := D.Form;
      D.TblBox.Style := csDropDownList;
      D.TblBox.SetBounds(252, 32, 170, 26);
      D.TblBox.Items.Add(Tr('(all tables)'));
      D.TblBox.Items.AddStrings(L);
    finally
      L.Free;
    end;
    D.Tables.OnClickCheck := @D.TableCheck;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Table'); SetBounds(252, 10, 100, 18); end;
    D.TblBox.ItemIndex := 0;
    if ATable <> '' then D.TblBox.ItemIndex := D.TblBox.Items.IndexOf(ATable);
    if D.TblBox.ItemIndex < 0 then D.TblBox.ItemIndex := 0;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('User'); SetBounds(432, 10, 100, 18); end;
    D.UserEdit := TEdit.Create(D.Form); D.UserEdit.Parent := D.Form; D.UserEdit.SetBounds(432, 32, 120, 26);
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Action'); SetBounds(562, 10, 100, 18); end;
    D.ActBox := TComboBox.Create(D.Form);
    D.ActBox.Parent := D.Form;
    D.ActBox.Style := csDropDownList;
    D.ActBox.SetBounds(562, 32, 120, 26);
    D.ActBox.Items.CommaText := '"(sve)",dodano,izmijenjeno,obrisano';
    D.ActBox.ItemIndex := 0;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Record (id)'); SetBounds(692, 10, 100, 18); end;
    D.KeyEdit := TEdit.Create(D.Form); D.KeyEdit.Parent := D.Form; D.KeyEdit.SetBounds(692, 32, 80, 26);
    D.KeyEdit.Text := AKey;
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('From date'); SetBounds(782, 10, 100, 18); end;
    D.FromEdit := TEdit.Create(D.Form); D.FromEdit.Parent := D.Form; D.FromEdit.SetBounds(782, 32, 100, 26);
    with TLabel.Create(D.Form) do begin Parent := D.Form; Caption := Tr('To date'); SetBounds(892, 10, 100, 18); end;
    D.ToEdit := TEdit.Create(D.Form); D.ToEdit.Parent := D.Form; D.ToEdit.SetBounds(892, 32, 100, 26);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Show'); SetBounds(1004, 30, 90, 28); OnClick := @D.RefreshClick; end;
    D.Grid := TaGridView.Create(D.Form, D.Form, gkMain, PreferredProvider = 'own', True, D.Source);
    D.Grid.Control.Align := alNone;
    D.Grid.Control.SetBounds(252, 68, 914, 554);
    D.CountLbl := TLabel.Create(D.Form);
    D.CountLbl.Parent := D.Form;
    D.CountLbl.SetBounds(252, 632, 500, 18);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Delete old records...'); SetBounds(770, 626, 190, 30); OnClick := @D.PurgeClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Close'); ModalResult := mrCancel; SetBounds(1066, 626, 100, 30); end;
    P := nil;
    if P <> nil then P.Free;
    D.Reload;
    D.Form.ShowModal;
  finally
    D.Source.DataSet := nil;
    D.Query.Free;
    D.Form.Free;
    D.Free;
  end;
end;

end.
