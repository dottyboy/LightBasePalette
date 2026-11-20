program binderdemo;
{ Primjer paleta TyphAccess + JVCL + RX: forma racuna sastavljena u kodu (bez .lfm), da se moze i snimiti.
  Bocni izbornik (TaSideMenu), mreza (TRxDBGrid), polja (TRxDBLookupCombo, TRxDBDateEdit, TRxDBSpinEdit,
  TRxDBCurrEdit, TJvxCurrencyEdit) i TaFormBinder koji daje izracun, pravila, uvjetno oblikovanje i prikaz.
  Bez argumenata prikazuje prozor; s --snimke=mapa izvede scenarij i snimi PNG korake. }
{$mode objfpc}{$H+}
uses
  Interfaces, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics, SysUtils, Classes, DB, Dialogs,
  ZDataset, rxdbgrid, rxdbcurredit, rxdbdateedit, rxdbspinedit, rxlookup, JvBaseEdits, JvPageList,
  ta_meta, ta_components, ta_sidemenu, ta_binder;

type
  TDemo = class
  public
    Fm: TForm;
    Dbc: TaDatabase;
    Binder: TaFormBinder;
    Q, QP: TZQuery;
    Ds, DsP: TDataSource;
    Grid: TRxDBGrid;
    Menu: TaSideMenu;
    cbPartner: TRxDBLookupCombo;
    dtDatum: TRxDBDateEdit;
    edOpis: TEdit;
    spKol: TRxDBSpinEdit;
    ceCijena: TRxDBCurrEdit;
    ceIznos: TJvxCurrencyEdit;
    lblStatus, lblNapomena, lblPoruka: TLabel;
    btNovo, btSpremi, btOdustani: TButton;
    constructor Create;
    procedure Build;
    procedure Fill;
    procedure NovoClick(Sender: TObject);
    procedure SpremiClick(Sender: TObject);
    procedure OdustaniClick(Sender: TObject);
    procedure Failed(Sender: TObject; ABinding: TaBinding; const AMessage: string; var ARaise: Boolean);
    procedure MenuClick(Sender: TObject; AGroup, AItem: Integer; const AAction: string);
    procedure Snap(const AFile: string);
  end;

constructor TDemo.Create;
begin
  Build;
end;

function MkLabel(AParent: TWinControl; const ACap: string; X, Y: Integer): TLabel;
begin
  Result := TLabel.Create(AParent);
  Result.Parent := AParent; Result.Caption := ACap; Result.SetBounds(X, Y, 100, 16);
end;

procedure TDemo.Fill;
begin
  if FileExists('/tmp/binderdemo.db') then DeleteFile('/tmp/binderdemo.db');
  Dbc := TaDatabase.Create(Fm);
  Dbc.FileName := '/tmp/binderdemo.db';
  Dbc.Active := True;
  Dbc.ExecSQL('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(100))');
  Dbc.ExecSQL('CREATE TABLE stavke (id INTEGER PRIMARY KEY AUTOINCREMENT, partner_id INTEGER, datum DATE, opis VARCHAR(200), kolicina REAL, cijena REAL, iznos REAL)');
  Dbc.ExecSQL('INSERT INTO partneri VALUES (1, ''Jadran d.o.o.''), (2, ''Metalac obrt''), (3, ''Kvarner promet'')');
  Dbc.ExecSQL('INSERT INTO stavke (partner_id, datum, opis, kolicina, cijena, iznos) VALUES ' +
    '(1, ''2026-10-12'', ''Podloška M8'', 120, 0.35, 42), (2, ''2026-10-14'', ''Kabel 3x1,5 (m)'', 12.5, 1.2, 15), ' +
    '(3, ''2026-10-20'', ''Alat set'', 3, 480, 1440), (1, ''2026-11-02'', ''Čelična cijev'', 8, 62.5, 500), (2, ''2026-11-05'', ''Brusni disk'', 25, 3.4, 85)');
end;

procedure TDemo.Build;
var
  P: TPanel;
  G: TaSideMenuGroup;
  Pn: TPanel;
begin
  Fm := TForm.CreateNew(nil);
  Fm.Caption := 'TyphAccess + JVCL + RX: račun';
  Fm.SetBounds(0, 0, 1020, 620);
  Fm.Color := $F7F3EF;
  Fill;
  Q := Dbc.NewQuery('SELECT * FROM stavke ORDER BY id'); Q.Open;
  QP := Dbc.NewQuery('SELECT * FROM partneri ORDER BY naziv'); QP.Open;
  Ds := TDataSource.Create(Fm); Ds.DataSet := Q;
  DsP := TDataSource.Create(Fm); DsP.DataSet := QP;

  { bocni izbornik: skupine i stavke kao u TJvXPBar-u, puni se u kodu (u IDE-u kroz Groups) }
  Menu := TaSideMenu.Create(Fm);
  Menu.Parent := Fm; Menu.Align := alLeft; Menu.Width := 210;
  G := Menu.Groups.Add; G.Caption := 'Računi'; G.IconName := 'invoice';
  with G.Items.Add do begin Caption := 'Stavke računa'; Action := 'openform:Stavke'; end;
  with G.Items.Add do begin Caption := 'Novi račun'; Action := 'openform:NoviRacun'; end;
  with G.Items.Add do begin Caption := 'Neplaćeni'; Action := 'openreport:Neplaceni'; end;
  G := Menu.Groups.Add; G.Caption := 'Sustavi'; G.IconName := 'chart';
  with G.Items.Add do begin Caption := 'Kartice sustava'; Action := 'openreport:Sustavi: kartice'; end;
  with G.Items.Add do begin Caption := 'Grafikoni'; Action := 'openreport:Sustavi: grafikoni'; end;
  G := Menu.Groups.Add; G.Caption := 'Šifrarnici'; G.IconName := 'database';
  with G.Items.Add do begin Caption := 'Partneri'; Action := 'openform:Partneri'; end;
  Menu.OnItemClick := @MenuClick;
  Menu.Accordion := True;

  Pn := TPanel.Create(Fm); Pn.Parent := Fm; Pn.Align := alClient; Pn.BevelOuter := bvNone; Pn.Color := $F7F3EF;
  with TLabel.Create(Pn) do
  begin
    Parent := Pn; SetBounds(18, 12, 600, 28); Caption := 'Stavke računa'; Font.Size := 16; Font.Style := [fsBold]; Font.Color := $7A4B1F;
  end;

  Grid := TRxDBGrid.Create(Pn);
  Grid.Parent := Pn; Grid.SetBounds(18, 48, 780, 200);
  Grid.DataSource := Ds;
  Grid.AutoFillColumns := False;
  with Grid.Columns.Add do begin FieldName := 'id'; Title.Caption := 'Br.'; Width := 40; end;
  with Grid.Columns.Add do begin FieldName := 'datum'; Title.Caption := 'Datum'; Width := 90; end;
  with Grid.Columns.Add do begin FieldName := 'opis'; Title.Caption := 'Opis'; Width := 230; end;
  with Grid.Columns.Add do begin FieldName := 'kolicina'; Title.Caption := 'Količina'; Width := 80; end;
  with Grid.Columns.Add do begin FieldName := 'cijena'; Title.Caption := 'Cijena'; Width := 90; end;
  with Grid.Columns.Add do
  begin
    FieldName := 'iznos'; Title.Caption := 'Iznos'; Width := 110;
    Footer.ValueType := fvtSum; Footer.FieldName := 'iznos'; Footer.DisplayFormat := '#,##0.00';
  end;
  Grid.OptionsRx := Grid.OptionsRx + [rdgFooterRows];
  Grid.FooterOptions.Active := True;
  Grid.FooterOptions.RowCount := 1;

  P := TPanel.Create(Pn); P.Parent := Pn; P.SetBounds(18, 264, 780, 220); P.BevelOuter := bvLowered; P.Color := $FFFFFF;
  MkLabel(P, 'Partner', 16, 14);
  cbPartner := TRxDBLookupCombo.Create(P); cbPartner.Parent := P; cbPartner.SetBounds(16, 32, 260, 24);
  MkLabel(P, 'Datum', 300, 14);
  dtDatum := TRxDBDateEdit.Create(P); dtDatum.Parent := P; dtDatum.SetBounds(300, 32, 130, 24);
  MkLabel(P, 'Opis', 16, 70);
  edOpis := TEdit.Create(P); edOpis.Parent := P; edOpis.SetBounds(16, 88, 414, 24);
  MkLabel(P, 'Količina', 460, 14);
  spKol := TRxDBSpinEdit.Create(P); spKol.Parent := P; spKol.SetBounds(460, 32, 100, 24);
  MkLabel(P, 'Cijena', 580, 14);
  ceCijena := TRxDBCurrEdit.Create(P); ceCijena.Parent := P; ceCijena.SetBounds(580, 32, 170, 24);
  MkLabel(P, 'Iznos (izračun)', 460, 70);
  ceIznos := TJvxCurrencyEdit.Create(P); ceIznos.Parent := P; ceIznos.SetBounds(460, 88, 170, 24); ceIznos.ReadOnly := True; ceIznos.ButtonWidth := 0;
  lblStatus := TLabel.Create(P); lblStatus.Parent := P; lblStatus.SetBounds(640, 90, 130, 22); lblStatus.AutoSize := False;
  lblStatus.Alignment := taCenter; lblStatus.Layout := tlCenter; lblStatus.Transparent := False; lblStatus.Caption := '';
  lblNapomena := TLabel.Create(P); lblNapomena.Parent := P; lblNapomena.SetBounds(16, 128, 740, 20);
  lblNapomena.Caption := 'Veliki iznos (> 1.000 €): potrebno odobrenje voditelja.'; lblNapomena.Font.Color := $0000C0; lblNapomena.Font.Style := [fsBold];
  lblPoruka := TLabel.Create(P); lblPoruka.Parent := P; lblPoruka.SetBounds(16, 190, 740, 20); lblPoruka.Font.Color := $0000C0;

  btNovo := TButton.Create(P); btNovo.Parent := P; btNovo.SetBounds(16, 152, 100, 30); btNovo.Caption := 'Novo'; btNovo.OnClick := @NovoClick;
  btSpremi := TButton.Create(P); btSpremi.Parent := P; btSpremi.SetBounds(124, 152, 100, 30); btSpremi.Caption := 'Spremi'; btSpremi.OnClick := @SpremiClick;
  btOdustani := TButton.Create(P); btOdustani.Parent := P; btOdustani.SetBounds(232, 152, 100, 30); btOdustani.Caption := 'Odustani'; btOdustani.OnClick := @OdustaniClick;

  { ---- TaFormBinder: sve ponasanje je u ovih nekoliko redaka ---- }
  Binder := TaFormBinder.Create(Fm);
  Binder.Database := Dbc;
  Binder.DataSource := Ds;
  Binder.OnValidationFailed := @Failed;
  with Binder.Bindings.Add do begin Control := cbPartner; FieldName := 'partner_id'; end;
  with Binder.Bindings.Add do begin Control := dtDatum; FieldName := 'datum'; DefaultValue := 'Date()'; end;
  with Binder.Bindings.Add do begin Control := edOpis; FieldName := 'opis'; Rule := 'Len(Trim(Nz([opis], ""))) > 0'; RuleMessage := 'Opis je obavezan.'; end;
  with Binder.Bindings.Add do
  begin
    Control := spKol; FieldName := 'kolicina'; Format := '0.##'; Rule := '[kolicina] > 0'; RuleMessage := 'Količina mora biti veća od nule.';
  end;
  with Binder.Bindings.Add do
  begin
    Control := ceCijena; FieldName := 'cijena'; Format := '#,##0.00'; Rule := '[cijena] >= 0'; RuleMessage := 'Cijena ne smije biti negativna.';
    EnabledIf := 'Nz([kolicina], 0) > 0';
  end;
  with Binder.Bindings.Add do
  begin
    Control := ceIznos; FieldName := 'iznos'; Format := '#,##0.00';
    Expression := 'Zaokruzi(Nz([kolicina], 0) * Nz([cijena], 0), 2)';
    CondFormat := '[iznos] > 1000 => #C00000 #FFE9E9 bold';
  end;
  with Binder.Bindings.Add do
  begin
    Control := lblStatus;
    Expression := 'IIf(Nz([iznos], 0) > 1000, "VELIKI", "obični")';
    CondFormat := '[iznos] > 1000 => #FFFFFF #C00000 bold ;; [iznos] > 100 => #7A4B1F #FFE9B8';
  end;
  with Binder.Bindings.Add do begin Control := lblNapomena; VisibleIf := 'Nz([iznos], 0) > 1000'; end;
  Binder.Activate;
  { vezu padajuceg popisa partnera postavlja se izravno (RX ima vlastita svojstva) }
  cbPartner.LookupSource := DsP; cbPartner.LookupField := 'id'; cbPartner.LookupDisplay := 'naziv';
end;

procedure TDemo.NovoClick(Sender: TObject);
begin
  lblPoruka.Caption := '';
  Q.Append;
end;

procedure TDemo.SpremiClick(Sender: TObject);
begin
  try
    Q.Post;
    lblPoruka.Caption := '';
  except
    on E: EBinderValidation do lblPoruka.Caption := 'Nije spremljeno: ' + E.Message;
  end;
end;

procedure TDemo.OdustaniClick(Sender: TObject);
begin
  Q.Cancel; lblPoruka.Caption := '';
end;

procedure TDemo.Failed(Sender: TObject; ABinding: TaBinding; const AMessage: string; var ARaise: Boolean);
begin
  ARaise := True;
end;

procedure TDemo.MenuClick(Sender: TObject; AGroup, AItem: Integer; const AAction: string);
begin
  Fm.Caption := 'TyphAccess + JVCL + RX: ' + AAction;
end;

procedure TDemo.Snap(const AFile: string);
var
  B: TBitmap;
  Png: TPortableNetworkGraphic;
begin
  Application.ProcessMessages;
  B := TBitmap.Create;
  Png := TPortableNetworkGraphic.Create;
  try
    B.SetSize(Fm.ClientWidth, Fm.ClientHeight);
    Fm.PaintTo(B.Canvas, 0, 0);
    Png.Assign(B);
    Png.SaveToFile(AFile);
  finally
    Png.Free; B.Free;
  end;
end;

var
  D: TDemo;
  Dir, Msg: string;
  I: Integer;
begin
  Application.Initialize;
  ApplyCroatianLocale;       { prije stvaranja kontrola: one pamte oblike pri stvaranju }
  D := TDemo.Create;
  Dir := '';
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, 9) = '--snimke=' then Dir := Copy(ParamStr(I), 10, MaxInt);
  if Dir = '' then
  begin
    D.Fm.Position := poScreenCenter;
    D.Fm.Show;
    Application.Run;
    Exit;
  end;
  ForceDirectories(Dir);
  D.Fm.Show;
  Application.ProcessMessages;
  D.Q.First;
  D.Menu.ClickRow(1);
  D.Snap(Dir + '/1_pocetak.png');
  { novi zapis: zadani datum, izracun i uvjetno oblikovanje dok se upisuje }
  D.Q.Append;
  D.Q.FieldByName('partner_id').AsInteger := 3;
  D.Q.FieldByName('opis').AsString := 'Alat set Profi';
  D.Q.FieldByName('kolicina').AsFloat := 2.51;
  D.Q.FieldByName('cijena').AsFloat := 480;
  D.Snap(Dir + '/2_veliki_iznos.png');
  WriteLn('iznos=', D.Q.FieldByName('iznos').AsFloat:0:2, ' datum=', D.Q.FieldByName('datum').AsString);
  { kvar: kolicina 0 -> pravilo, polje crveno, Post se odbija }
  D.Q.FieldByName('kolicina').AsFloat := 0;
  D.SpremiClick(nil);
  D.Snap(Dir + '/3_pravilo.png');
  WriteLn('poruka=', D.lblPoruka.Caption);
  { ispravak i spremanje }
  D.Q.FieldByName('kolicina').AsFloat := 2.51;
  D.SpremiClick(nil);
  D.Q.Last;
  D.Snap(Dir + '/4_spremljeno.png');
  WriteLn('redaka=', D.Q.RecordCount, ' zadnji iznos=', D.Q.FieldByName('iznos').AsFloat:0:2);
  D.Fm.Free;
end.
