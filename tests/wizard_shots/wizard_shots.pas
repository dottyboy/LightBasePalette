program wizard_shots;
{ Snimke zaslona carobnjaka (kosturi, blok-carobnjak): wizard_shots [izlazna_mapa]; QT_QPA_PLATFORM=offscreen radi bez zaslona. }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Controls, Classes, SysUtils, Graphics, qt6, qt6widgets,
  ta_meta, ta_tokens, ta_theme, ta_blockwiz, ta_blockdlg, ta_skelwizard, ta_fglblockdlg, ta_formdef, ta_rowsource, ta_rowhost, ta_rowmodel, ta_contform, ta_formrun, ta_formdesign;

function GrabPng(AForm: TForm; const AFile: string): Boolean;
var
  Pix: QPixmapH;
  WS: WideString;
  R: TRect;
begin
  Pix := QPixmap_Create();
  try
    R := Rect(0, 0, AForm.Width, AForm.Height);
    QWidget_grab(TQtWidget(AForm.Handle).Widget, Pix, @R);
    WS := UTF8Decode(AFile);
    Result := QPixmap_save(Pix, @WS, 'PNG');
  finally
    QPixmap_Destroy(Pix);
  end;
end;

var
  Db: TAppDb;
  S: TfrmSkelWizard;
  B: TfrmBlockWizard;
  P: TfrmPaletteBlock;
  Fm: TForm;
  H: TaRowsView;
  CF: TaContinuousBody;
  Rn: TaFormRunner;
  Db2: TAppDb;
  Dsg: TaFormDesigner;
  Dd: TaFormDef;
  Dm, Ds: TaFormDef;
  Cx: TaControlDef;
  Df2: TaFormDef;
  Df: TaFormDef;
  Cd: TaControlDef;
  Src: TaRowSource;
  I: Integer;
  Dir: string;
begin
  Application.Initialize;
  Dir := 'out';
  if ParamCount >= 1 then Dir := ParamStr(1);
  ForceDirectories(Dir);
  Application.Scaled := False;
  ApplySavedTheme;
  Db := TAppDb.Create;
  if FileExists('/tmp/ta_shots.db') then DeleteFile('/tmp/ta_shots.db');
  Db.Open('/tmp/ta_shots.db');
  Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
  Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, partner_id INTEGER, broj VARCHAR(20), datum DATE, iznos DECIMAL(12,2), placen BOOLEAN, FOREIGN KEY (partner_id) REFERENCES partneri(id))');
  S := TfrmSkelWizard.CreateWizard(nil, Db, '');
  S.Show;
  S.UseData('racuni');
  S.SelectSkeleton('Master-detalj');
  Application.ProcessMessages;
  WriteLn(StdErr, 'DONE skeleton');
  WriteLn('skeleton ', GrabPng(S, Dir + '/kosturi.png'));
  S.Free;
  B := TfrmBlockWizard.CreateWizard(nil, Db, '');
  B.Show;
  B.Configure('partneri', blFormAndTable, True);
  Application.ProcessMessages;
  WriteLn(StdErr, 'DONE block');
  WriteLn('block ', GrabPng(B, Dir + '/blok.png'));
  B.Free;
  P := TfrmPaletteBlock.CreatePicker(nil, Db, 'MAIN'#10'  DEFINE grad TEXT'#10'END MAIN');
  P.Show;
  P.SelectBlock('otvorifilter');
  Application.ProcessMessages;
  WriteLn(StdErr, 'DONE palette');
  WriteLn('palette ', GrabPng(P, Dir + '/blok_iz_baze.png'));
  P.Free;
  { neprekidna forma }
  Db.Conn.ExecuteDirect('CREATE TABLE partneri2 (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER, iznos DECIMAL(12,2))');
  Db.Conn.ExecuteDirect('BEGIN');
  for I := 1 to 60 do
    Db.Conn.ExecuteDirect('INSERT INTO partneri2 (naziv, grad, aktivan, iznos) VALUES (''Partner ' + IntToStr(I) + ' d.o.o.'', ''Zagreb'', ' + IntToStr(I mod 2) + ', ' + IntToStr(I * 137) + '.5)');
  Db.Conn.ExecuteDirect('COMMIT');
  Df := TaFormDef.Create;
  Df.AllowAdds := True; Df.AllowEdits := True;
  Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.ControlSource := 'naziv'; Cd.Left := 4; Cd.Top := 4; Cd.Width := 200; Cd.Height := 26; Df.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'ComboBox'; Cd.ControlSource := 'grad'; Cd.Left := 210; Cd.Top := 4; Cd.Width := 130; Cd.Height := 26; Df.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'CheckBox'; Cd.ControlSource := 'aktivan'; Cd.Left := 346; Cd.Top := 4; Cd.Width := 24; Cd.Height := 26; Df.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.ControlSource := 'iznos'; Cd.Format := '#,##0.00'; Cd.Left := 376; Cd.Top := 4; Cd.Width := 110; Cd.Height := 26; Df.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'Button'; Cd.Caption := 'PDF'; Cd.Left := 492; Cd.Top := 4; Cd.Width := 60; Cd.Height := 26; Df.Add(Cd);
  Src := TaRowSource.Create(Db, 'partneri2');
  Fm := TForm.CreateNew(nil);
  Fm.SetBounds(0, 0, 600, 316);
  H := TaRowsView.Create(Fm);
  H.Parent := Fm;
  H.Align := alClient;
  Fm.Show;
  H.Setup(Src, Df);
  H.GoToRow(2);
  H.SimulateEdit(0, 'Partner 3 izmijenjen');
  Application.ProcessMessages;
  WriteLn(StdErr, 'DONE rows');
  WriteLn('rows ', GrabPng(Fm, Dir + '/neprekidna_forma.png'));
  H.CancelRow;
  Fm.Free;
  Src.Free;
  Df.Free;
  { zaglavlje + redovi + podnozje }
  Df2 := TaFormDef.Create;
  Df2.RecordSource := 'partneri2'; Df2.AllowAdds := True; Df2.AllowEdits := True;
  Cd := TaControlDef.Create; Cd.Kind := 'Label'; Cd.Caption := 'Naziv'; Cd.Section := 'header'; Cd.Left := 4; Cd.Top := 4; Cd.Width := 200; Cd.Height := 20; Cd.SetX('sort', 'naziv'); Df2.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.Name := 'fNaziv'; Cd.Section := 'header'; Cd.Left := 4; Cd.Top := 26; Cd.Width := 200; Cd.Height := 24; Cd.SetX('filter', 'naziv'); Df2.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'Label'; Cd.Caption := 'Iznos'; Cd.Section := 'header'; Cd.Left := 376; Cd.Top := 4; Cd.Width := 110; Cd.Height := 20; Cd.SetX('sort', 'iznos'); Df2.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.Name := 'fIznos'; Cd.Section := 'header'; Cd.Left := 376; Cd.Top := 26; Cd.Width := 110; Cd.Height := 24; Cd.SetX('filter', 'iznos'); Df2.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.ControlSource := 'naziv'; Cd.Section := 'detail'; Cd.Left := 4; Cd.Top := 4; Cd.Width := 200; Cd.Height := 26; Df2.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.ControlSource := 'grad'; Cd.Section := 'detail'; Cd.Left := 210; Cd.Top := 4; Cd.Width := 130; Cd.Height := 26; Df2.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.ControlSource := 'iznos'; Cd.Format := '#,##0.00'; Cd.Section := 'detail'; Cd.Left := 376; Cd.Top := 4; Cd.Width := 110; Cd.Height := 26; Df2.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'Label'; Cd.Caption := 'Ukupno'; Cd.Section := 'footer'; Cd.Left := 210; Cd.Top := 4; Cd.Width := 80; Cd.Height := 20; Df2.Add(Cd);
  Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.Name := 'zb'; Cd.ControlSource := '=Sum(iznos)'; Cd.Format := '#,##0.00'; Cd.Section := 'footer'; Cd.Left := 376; Cd.Top := 4; Cd.Width := 110; Cd.Height := 24; Df2.Add(Cd);
  Fm := TForm.CreateNew(nil);
  Fm.SetBounds(0, 0, 600, 360);
  CF := TaContinuousBody.Create(Fm);
  CF.Parent := Fm;
  CF.Align := alClient;
  Fm.Show;
  CF.Setup(Db, Df2);
  CF.ClickHeader('Naziv');
  CF.ClickHeader('Naziv');
  CF.TypeFilter('fIznos', '>1000');
  Application.ProcessMessages;
  WriteLn(StdErr, 'DONE cont');
  WriteLn('cont ', GrabPng(Fm, Dir + '/neprekidna_zaglavlje_podnozje.png'));
  Fm.Free;
  Df2.Free;
  { dizajner neprekidne forme: tri odjeljka }
  Dd := TaFormDef.Create;
  Dd.Name := 'DizNep'; Dd.RecordSource := 'partneri2'; Dd.ViewMode := 'continuous';
  Dd.HeaderHeight := 56; Dd.RowHeight := 34; Dd.FooterHeight := 40; Dd.Width := 560; Dd.Height := 300;
  Cx := TaControlDef.Create; Cx.Kind := 'Label'; Cx.Name := 'hn'; Cx.Caption := 'Naziv'; Cx.Section := 'header'; Cx.Left := 8; Cx.Top := 4; Cx.Width := 200; Cx.Height := 20; Dd.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.Name := 'tn'; Cx.ControlSource := 'naziv'; Cx.Section := 'detail'; Cx.Left := 8; Cx.Top := 4; Cx.Width := 200; Cx.Height := 26; Dd.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.Name := 'ti'; Cx.ControlSource := 'iznos'; Cx.Section := 'detail'; Cx.Left := 214; Cx.Top := 4; Cx.Width := 110; Cx.Height := 26; Dd.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.Name := 'zi'; Cx.ControlSource := '=Sum(iznos)'; Cx.Section := 'footer'; Cx.Left := 214; Cx.Top := 4; Cx.Width := 110; Cx.Height := 24; Dd.Add(Cx);
  Dsg := TaFormDesigner.CreateDesigner(nil, Db, Dd);
  Dsg.Show;
  Application.ProcessMessages;
  WriteLn(StdErr, 'DONE dizajner');
  WriteLn('dizajner ', GrabPng(Dsg, Dir + '/dizajner_neprekidna.png'));
  Dsg.Free;
  { racun s neprekidnom podformom stavki }
  Db2 := TAppDb.Create;
  if FileExists('/tmp/ta_shots2.db') then DeleteFile('/tmp/ta_shots2.db');
  Db2.Open('/tmp/ta_shots2.db');
  Db2.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, broj VARCHAR(20), kupac VARCHAR(40))');
  Db2.Conn.ExecuteDirect('CREATE TABLE stavke (id INTEGER PRIMARY KEY, racun_id INTEGER NOT NULL, opis VARCHAR(40), kolicina INTEGER, iznos DECIMAL(12,2), FOREIGN KEY (racun_id) REFERENCES racuni(id))');
  Db2.Conn.ExecuteDirect('INSERT INTO racuni VALUES (1, ''R-2026-001'', ''Alfa d.o.o.'')');
  Db2.Conn.ExecuteDirect('INSERT INTO stavke (racun_id, opis, kolicina, iznos) VALUES (1, ''Usluga razvoja'', 10, 1500), (1, ''Licenca'', 2, 480.5), (1, ''Podrska'', 12, 960)');
  Ds := TaFormDef.Create;
  Ds.Name := 'StavkeRacuna'; Ds.RecordSource := 'stavke'; Ds.ViewMode := 'continuous'; Ds.AllowAdds := True; Ds.AllowEdits := True; Ds.Width := 520; Ds.Height := 200;
  Cx := TaControlDef.Create; Cx.Kind := 'Label'; Cx.Caption := 'Opis'; Cx.Section := 'header'; Cx.Left := 4; Cx.Top := 4; Cx.Width := 200; Cx.Height := 20; Cx.SetX('sort', 'opis'); Ds.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'Label'; Cx.Caption := 'Kol.'; Cx.Section := 'header'; Cx.Left := 210; Cx.Top := 4; Cx.Width := 60; Cx.Height := 20; Ds.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'Label'; Cx.Caption := 'Iznos'; Cx.Section := 'header'; Cx.Left := 276; Cx.Top := 4; Cx.Width := 120; Cx.Height := 20; Cx.SetX('sort', 'iznos'); Ds.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.ControlSource := 'opis'; Cx.Section := 'detail'; Cx.Left := 4; Cx.Top := 4; Cx.Width := 200; Cx.Height := 26; Ds.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.ControlSource := 'kolicina'; Cx.Section := 'detail'; Cx.Left := 210; Cx.Top := 4; Cx.Width := 60; Cx.Height := 26; Ds.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.ControlSource := 'iznos'; Cx.Format := '#,##0.00'; Cx.Section := 'detail'; Cx.Left := 276; Cx.Top := 4; Cx.Width := 120; Cx.Height := 26; Ds.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'Label'; Cx.Caption := 'Ukupno'; Cx.Section := 'footer'; Cx.Left := 210; Cx.Top := 4; Cx.Width := 60; Cx.Height := 20; Ds.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.ControlSource := '=Sum(iznos)'; Cx.Format := '#,##0.00'; Cx.Section := 'footer'; Cx.Left := 276; Cx.Top := 4; Cx.Width := 120; Cx.Height := 24; Ds.Add(Cx);
  Db2.SaveObject('_sys_forms', 'StavkeRacuna', Ds.ToJson);
  Ds.Free;
  Dm := TaFormDef.Create;
  Dm.Name := 'Racun'; Dm.RecordSource := 'racuni'; Dm.Width := 560; Dm.Height := 380; Dm.AllowEdits := True;
  Cx := TaControlDef.Create; Cx.Kind := 'Label'; Cx.Name := 'l1'; Cx.Caption := 'Broj'; Cx.Left := 12; Cx.Top := 14; Cx.Width := 60; Cx.Height := 22; Dm.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.Name := 'txtBroj'; Cx.ControlSource := 'broj'; Cx.Left := 76; Cx.Top := 10; Cx.Width := 160; Cx.Height := 26; Dm.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'Label'; Cx.Name := 'l2'; Cx.Caption := 'Kupac'; Cx.Left := 250; Cx.Top := 14; Cx.Width := 60; Cx.Height := 22; Dm.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.Name := 'txtKupac'; Cx.ControlSource := 'kupac'; Cx.Left := 314; Cx.Top := 10; Cx.Width := 220; Cx.Height := 26; Dm.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'Subform'; Cx.Name := 'Stavke'; Cx.RowSource := 'StavkeRacuna'; Cx.LinkMaster := 'id'; Cx.LinkChild := 'racun_id'; Cx.Left := 12; Cx.Top := 50; Cx.Width := 536; Cx.Height := 240; Dm.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'Label'; Cx.Name := 'l3'; Cx.Caption := 'Ukupno racun'; Cx.Left := 250; Cx.Top := 304; Cx.Width := 110; Cx.Height := 22; Dm.Add(Cx);
  Cx := TaControlDef.Create; Cx.Kind := 'TextBox'; Cx.Name := 'txtUk'; Cx.ControlSource := '=SubSum("Stavke", "iznos")'; Cx.Format := '#,##0.00'; Cx.Left := 364; Cx.Top := 300; Cx.Width := 170; Cx.Height := 26; Dm.Add(Cx);
  WriteLn(StdErr, 'M1 create');
  Rn := TaFormRunner.CreateRunner(nil, Db2, Dm);
  WriteLn(StdErr, 'M2 created');
  Rn.Show;
  WriteLn(StdErr, 'M3 shown');
  Application.ProcessMessages;
  WriteLn(StdErr, 'M4 processed');
  WriteLn('racun ', GrabPng(Rn, Dir + '/racun_podforma.png'));
  Rn.Free;
  Db2.Close;
  Db2.Free;
  Db.Close;
  Db.Free;
end.
