unit ta_screens;
{ Snimke zaslona za priručnik: --screenshots=mapa otvara nacrtane prizore (glavni prozor, dizajneri,
  pregled izvješća, dijalozi) na demo bazi, svaki iscrta u sliku i zatvori. Radi i bez zaslona
  (QT_QPA_PLATFORM=offscreen), pa su slike uvijek iste veličine i bez okolnih prozora. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, Graphics, Dialogs, ta_meta;

type
  { glavni prozor otvara tablicu u mrezi prije snimke }
  TShotPrepare = procedure(const ATable: string) of object;

{ Snima sve prizore u ADir; vraca broj spremljenih slika. AMain je glavni prozor (snima se prvi). }
function RunScreenshots(AMain: TForm; ADb: TAppDb; const ADir: string; ALog: TStrings; APrepare: TShotPrepare = nil): Integer;
{ Pokrece snimanje tek kad se glavni prozor iscrta (iz petlje poruka) i zatim zavrsava program. }
procedure ScheduleScreenshots(AMain: TForm; ADb: TAppDb; const ADir: string; APrepare: TShotPrepare = nil);

implementation

uses
  ta_i18n,
  StdCtrls, CheckLst, ComCtrls, ta_formdef, ta_reportdef, ta_formdesign, ta_reportdesign, ta_querydesign, ta_qbe, ta_formrun, ta_tasks,
  ta_audit, ta_taskdlg, ta_auditdlg, ta_bizdlg, ta_querywiz, ta_importdlg, ta_catalogdlg, ta_fiscalhook,
  ta_catalog, ta_companydlg, ta_propdlgs, ta_filestoredlg, ta_wizards, ta_crosstabdlg, ta_datatoolsdlg, ta_appdlg;

const
  ShotW = 1100;
  ShotH = 720;

type
  TShooter = class
  public
    Dir, Name: string;
    Phase: Integer;
    Saved: Integer;
    Main: TForm;
    Timer: TTimer;
    Log: TStrings;
    Target: TForm;
    Resize: Boolean;
    W, H: Integer;
    procedure Tick(Sender: TObject);
    procedure Arm(const AName: string; AResize: Boolean = True; AW: Integer = ShotW; AH: Integer = ShotH);
    function TopForm: TCustomForm;
  end;

procedure PrepareScene(const AName: string; AF: TCustomForm); forward;

var
  GShooter: TShooter = nil;

function TShooter.TopForm: TCustomForm;
var
  I: Integer;
begin
  Result := nil;
  if Target <> nil then Exit(Target);
  for I := Screen.CustomFormCount - 1 downto 0 do
    if (Screen.CustomForms[I] <> Main) and (Screen.CustomForms[I].Visible) then
      Exit(Screen.CustomForms[I]);
end;

procedure TShooter.Tick(Sender: TObject);
var
  F: TCustomForm;
  Bmp: TBitmap;
  Png: TPortableNetworkGraphic;
begin
  Timer.Enabled := False;
  F := nil;
  if Name = '' then Exit;
  if Name = 'glavni' then F := Main else F := TopForm;
  if F = nil then
  begin
    Log.Add(Tr('ERROR ') + Name + ': nema prozora za snimanje');
    Name := '';
    Exit;
  end;
  if Phase = 0 then
  begin
    if not Resize then PrepareScene(Name, F);
    { prva faza: velicina (dijalozi ostaju svoje velicine); druga faza: slika nakon sto se sve iscrta }
    if Resize then F.SetBounds(F.Left, F.Top, W, H);
    Application.ProcessMessages;
    Phase := 1;
    Timer.Interval := 500;
    Timer.Enabled := True;
    Exit;
  end;
  Application.ProcessMessages;
  try
    Bmp := F.GetFormImage;
    try
      Png := TPortableNetworkGraphic.Create;
      try
        Png.Assign(Bmp);
        Png.SaveToFile(IncludeTrailingPathDelimiter(Dir) + Name + '.png');
        Inc(Saved);
        Log.Add('snimljeno: ' + Name + '.png (' + IntToStr(Bmp.Width) + 'x' + IntToStr(Bmp.Height) + ')');
      finally
        Png.Free;
      end;
    finally
      Bmp.Free;
    end;
  except
    on E: Exception do Log.Add(Tr('ERROR ') + Name + ': ' + E.Message);
  end;
  Name := '';
  if F <> Main then F.ModalResult := mrCancel;
end;

procedure TShooter.Arm(const AName: string; AResize: Boolean = True; AW: Integer = ShotW; AH: Integer = ShotH);
begin
  Name := AName;
  Resize := AResize;
  W := AW;
  H := AH;
  Phase := 0;
  Timer.Interval := 700;
  Timer.Enabled := True;
end;


{ ---- pretpopunjavanje dijaloga prije snimke: trazi kontrole po vrsti i redoslijedu izrade ---- }

function NthOf(AF: TCustomForm; AClass: TClass; N: Integer): TComponent;
var
  I, K: Integer;
begin
  Result := nil;
  K := 0;
  for I := 0 to AF.ComponentCount - 1 do
    if AF.Components[I].InheritsFrom(AClass) then
    begin
      if K = N then Exit(AF.Components[I]);
      Inc(K);
    end;
end;

procedure CheckItems(L: TCheckListBox; const AWanted: array of string);
var
  I, J: Integer;
begin
  if L = nil then Exit;
  for I := 0 to L.Count - 1 do
    for J := 0 to High(AWanted) do
      if SameText(L.Items[I], AWanted[J]) or (Pos(LowerCase(AWanted[J]), LowerCase(L.Items[I])) = Length(L.Items[I]) - Length(AWanted[J]) + 1) then
      begin
        L.Checked[I] := True;
        Break;
      end;
  if Assigned(L.OnClickCheck) then L.OnClickCheck(L);
end;

procedure PickCombo(C: TComboBox; const AText: string);
var
  I: Integer;
begin
  if C = nil then Exit;
  I := C.Items.IndexOf(AText);
  if I < 0 then Exit;
  C.ItemIndex := I;
  if Assigned(C.OnChange) then C.OnChange(C);
end;

procedure SetEdit(E: TComponent; const AText: string);
begin
  if E is TEdit then TEdit(E).Text := AText;
end;

procedure PressButton(AF: TCustomForm; const ACaption: string);
var
  I: Integer;
begin
  for I := 0 to AF.ComponentCount - 1 do
    if (AF.Components[I] is TButton) and (TButton(AF.Components[I]).Caption = ACaption) then
    begin
      TButton(AF.Components[I]).Click;
      Exit;
    end;
end;

procedure PrepareScene(const AName: string; AF: TCustomForm);
begin
  if AName = 'carobnjak-upita' then
  begin
    CheckItems(TCheckListBox(NthOf(AF, TCheckListBox, 0)), ['transakcija', 'kategorija_troska']);
    CheckItems(TCheckListBox(NthOf(AF, TCheckListBox, 1)), ['kategorija_troska.naziv', 'transakcija.iznos']);
    PickCombo(TComboBox(NthOf(AF, TComboBox, 0)), 'Zbirni (grupiraj i zbroji brojeve)');
    SetEdit(NthOf(AF, TEdit, 0), 'Rashodi po kategorijama');
  end
  else if AName = 'unakrsni-upit' then
  begin
    PickCombo(TComboBox(NthOf(AF, TComboBox, 0)), 'transakcija');
    PickCombo(TComboBox(NthOf(AF, TComboBox, 1)), 'novcanik_id');
    PickCombo(TComboBox(NthOf(AF, TComboBox, 3)), 'kategorija_id');
    PickCombo(TComboBox(NthOf(AF, TComboBox, 3)), 'iznos');
    SetEdit(NthOf(AF, TEdit, 0), 'Iznosi po novčaniku i kategoriji');
    PressButton(AF, Tr('Show SQL'));
  end
  else if AName = 'alati-za-podatke' then
  begin
    PickCombo(TComboBox(NthOf(AF, TComboBox, 0)), 'transakcija');
    SetEdit(NthOf(AF, TEdit, 0), 'Konzum');
    SetEdit(NthOf(AF, TEdit, 1), 'Konzum d.d.');
    PressButton(AF, 'Prebroji');
  end
  else if AName = 'pravila-izracuna' then
    PressButton(AF, Tr('Template: price <-> amount'))
  else if AName = 'carobnjak-forme' then
  begin
    PickCombo(TComboBox(NthOf(AF, TComboBox, 0)), 'transakcija');
    PressButton(AF, 'Sva');
  end
  else if AName = 'carobnjak-izvjesca' then
  begin
    PickCombo(TComboBox(NthOf(AF, TComboBox, 0)), 'transakcija');
    PressButton(AF, 'Sva');
    PickCombo(TComboBox(NthOf(AF, TComboBox, 2)), 'kategorija_id');
  end;
end;

function LoadForm(ADb: TAppDb; const AName: string): TaFormDef;
begin
  Result := TaFormDef.Create;
  Result.FromJson(ADb.LoadObject('_sys_forms', AName));
  Result.Name := AName;
end;

function LoadReport(ADb: TAppDb; const AName: string): TaReportDef;
begin
  Result := TaReportDef.Create;
  Result.FromJson(ADb.LoadObject('_sys_reports', AName));
  Result.Name := AName;
end;

function FirstOf(ADb: TAppDb; const ATable: string): string;
var
  L: TStringList;
begin
  L := ADb.ListObjects(ATable);
  try
    if L.Count > 0 then Result := L[0] else Result := '';
  finally
    L.Free;
  end;
end;

const
  { carobnjaci se prije snimke popune (PrepareScene) da pokazu stvarno stanje }
  DialogScenes: array[0..16] of string = (
    'uvoz', 'planer-zadataka', 'revizijski-trag', 'poslovni-predlosci',
    'fiskalizacija', 'podaci-o-tvrtki', 'katalog-domena', 'pohrana-datoteka', 'snimka-sheme',
    'carobnjak-upita', 'unakrsni-upit', 'alati-za-podatke', 'carobnjak-forme', 'carobnjak-izvjesca', 'pravila-izracuna', 'poredak-izvjesca', 'poredci-izvjesca');

{ podaci koje dijalozi pokazuju: zadatak u planeru, zapisi revizije, podaci o tvrtki, CSV za uvoz }
procedure PrepareDialogData(ADb: TAppDb; const ADir: string);
var
  T: TaTask;
  L: TStringList;
begin
  T.Name := 'Noćna kopija';
  T.Kind := 'backup';
  T.Arg := '~/kopije';
  T.Arg2 := '10';
  T.Schedule := 'dnevno 02:00';
  T.Enabled := True;
  T.LastRun := 0;
  T.LastResult := '';
  SaveTask(ADb, T);
  T.Name := 'Tjedni izvoz transakcija';
  T.Kind := 'export_csv';
  T.Arg := 'transakcija';
  T.Arg2 := '~/izvozi';
  T.Schedule := 'tjedno pon 08:00';
  SaveTask(ADb, T);
  if ADb.UserTables.IndexOf('transakcija') >= 0 then
  begin
    AuditSetUser(ADb, 'ana');
    AuditEnable(ADb, 'transakcija');
    ADb.Conn.ExecuteDirect('UPDATE transakcija SET iznos = -45 WHERE sifra = 3');
    AuditSetUser(ADb, 'marko');
    ADb.Conn.ExecuteDirect('UPDATE transakcija SET svrha = ''Gorivo i cestarina'' WHERE sifra = 5');
    ADb.Conn.ExecuteDirect('DELETE FROM transakcija WHERE sifra = 6');
  end;
  ADb.SaveSetting('firma.naziv', 'Kvaka d.o.o.');
  ADb.SaveSetting('firma.adresa', 'Ilica 12');
  ADb.SaveSetting('firma.mjesto', '10000 Zagreb');
  ADb.SaveSetting('firma.oib', '12345678903');
  ADb.SaveSetting('firma.iban', 'HR1210010051863000160');
  L := TStringList.Create;
  try
    L.Add('Šifra;Naziv;Cijena;Datum;Aktivan');
    L.Add('1;Kava 250 g;4,50;01.03.2026;da');
    L.Add('2;Čaj zeleni;3,20;05.03.2026;da');
    L.Add('3;Med bagremov;7,80;12.03.2026;ne');
    L.Add('4;Keksi;2,10;15.03.2026;da');
    L.SaveToFile('/tmp/uvoz-demo.csv');
  finally
    L.Free;
  end;
end;

procedure EnsureDemoQuery(ADb: TAppDb);
var
  T: TStringList;
  D: TaQbeDesign;
  Sql, Err: string;
begin
  if FirstOf(ADb, '_sys_queries') <> '' then Exit;
  T := ADb.UserTables;
  try
    if (T.IndexOf('transakcija') >= 0) and (T.IndexOf('kategorija_troska') >= 0) then
    begin
      { zbirni upit napravljen u rešetki: rashodi po kategorijama }
      D := TaQbeDesign.Create;
      try
        D.Tables.Add('transakcija');
        D.Tables.Add('kategorija_troska');
        D.AddColumn('kategorija_troska.naziv', 'Kategorija', True, 'group', '');
        D.AddColumn('transakcija.iznos', 'Ukupno', True, 'sum', 'asc');
        D.AddColumn('transakcija.iznos', 'Samo rashodi', False, 'where', '');
        D.Cols[2].Crit := '<0';
        if BuildQbeSql(ADb, D, Sql, Err) then
          ADb.SaveObject('_sys_queries', 'Rashodi po kategorijama', QbeSqlWithDesign(Sql, D))
        else
          ADb.SaveObject('_sys_queries', 'Rashodi po kategorijama', 'SELECT * FROM transakcija');
      finally
        D.Free;
      end;
    end
    else if T.Count > 0 then
      ADb.SaveObject('_sys_queries', 'Pregled ' + T[0], 'SELECT * FROM ' + ADb.QuoteId(T[0]));
  finally
    T.Free;
  end;
end;

function RunScreenshots(AMain: TForm; ADb: TAppDb; const ADir: string; ALog: TStrings; APrepare: TShotPrepare): Integer;
var
  S: TShooter;
  Fn, Rn, Qn: string;
  Fd: TaFormDef;
  Rd: TaReportDef;
  Ds: TaFormDesigner;
  Rs: TaReportDesigner;
  Qs: TaQueryDesigner;
  Rn2: TaFormRunner;
  I, Cd: Integer;
  Txt: string;
  Fl: TStringList;
  Dom: TCatDomain;
begin
  ForceDirectories(ADir);
  S := TShooter.Create;
  GShooter := S;
  try
    S.Dir := ADir;
    S.Main := AMain;
    S.Log := ALog;
    S.Timer := TTimer.Create(nil);
    S.Timer.Enabled := False;
    S.Timer.OnTimer := @S.Tick;
    EnsureDemoQuery(ADb);
    Fn := FirstOf(ADb, '_sys_forms');
    Rn := FirstOf(ADb, '_sys_reports');
    Qn := FirstOf(ADb, '_sys_queries');

    if Assigned(APrepare) then
    begin
      if ADb.UserTables.IndexOf('transakcija') >= 0 then APrepare('transakcija')
      else if ADb.UserTables.Count > 0 then APrepare(ADb.UserTables[0]);
      Application.ProcessMessages;
    end;
    S.Arm('glavni');
    while S.Name <> '' do begin Application.ProcessMessages; Sleep(20); end;

    if Fn <> '' then
    begin
      Fd := LoadForm(ADb, Fn);
      Ds := TaFormDesigner.CreateDesigner(AMain, ADb, Fd);
      try
        S.Target := Ds;
        S.Arm('dizajner-forme');
        Ds.ShowModal;
      finally
        S.Target := nil;
        Ds.Free;
      end;
    end;
    if Rn <> '' then
    begin
      Rd := LoadReport(ADb, Rn);
      Rs := TaReportDesigner.CreateDesigner(AMain, ADb, Rd);
      try
        S.Target := Rs;
        S.Arm('dizajner-izvjesca');
        Rs.ShowModal;
      finally
        S.Target := nil;
        Rs.Free;
      end;
    end;
    if Qn <> '' then
    begin
      Qs := TaQueryDesigner.CreateDesigner(AMain, ADb, Qn);
      try
        S.Target := Qs;
        S.Arm('dizajner-upita');
        Qs.ShowModal;
      finally
        S.Target := nil;
        Qs.Free;
      end;
    end;
    if Rn <> '' then
    begin
      Rd := LoadReport(ADb, Rn);
      try
        S.Target := nil;
        Rd.SortOptions := 'Po unosu=sifra ;; Po iznosu=iznos DESC ;; Po datumu=datum';
        S.Arm('pregled-izvjesca');
        ShowReportPreview(AMain, ADb, Rd);
      finally
        S.Target := nil;
        Rd.Free;
      end;
    end;

    { ---- forma u radu i dijalozi ---- }
    if Fn <> '' then
    begin
      Fd := LoadForm(ADb, 'Transakcije');
      if ADb.LoadObject('_sys_forms', 'Transakcije') = '' then Fd := LoadForm(ADb, Fn);
      Rn2 := TaFormRunner.CreateRunner(AMain, ADb, Fd);
      try
        S.Arm('forma-unos', True, 900, 310);
        Rn2.ShowModal;
      finally
        Rn2.Free;
      end;
    end;
    PrepareDialogData(ADb, ADir);
    for I := 0 to High(DialogScenes) do
    begin
      S.Arm(DialogScenes[I], False);
      try
        case I of
          0: begin ImportPresetFile := '/tmp/uvoz-demo.csv'; RunImportDialog(AMain, ADb); ImportPresetFile := ''; end;
          1: RunTaskPlanner(AMain, ADb);
          2: RunAuditViewer(AMain, ADb);
          3: RunBusinessTemplates(AMain, ADb);
          4: if Assigned(FiscalSetupHook) then FiscalSetupHook(AMain, ADb);
          5: RunCompanyProfile(AMain, ADb);
          6: Cd := ChooseCatalogDomain(AMain, True, Dom);
          7: RunFileStoreDialog(AMain, ADb);
          8: RunCatalogSnapshot(AMain, ADb);
          9: Txt := RunQueryWizard(AMain, ADb);
          10: Txt := RunCrosstabWizard(AMain, ADb);
          11: Txt := RunDataTools(AMain, ADb);
          12: Txt := RunFormWizard(AMain, ADb);
          13: Txt := RunReportWizard(AMain, ADb);
          16: begin Fl := TStringList.Create; Fl.CommaText := 'sifra,naziv,cijena,nabavna,marza'; Txt := 'Po unosu=id ;; Po šifri=sifra ;; Po marži=marza DESC ;; Po cijeni=cijena DESC'; RunSortOptionsBuilder(AMain, Fl, Txt); Fl.Free; end;
          15: begin Fl := TStringList.Create; Fl.CommaText := 'kupac,iznos,datum,id'; Txt := 'kupac, iznos DESC'; RunSortBuilder(AMain, Fl, Txt); Fl.Free; end;
          14: begin Fl := TStringList.Create; Fl.CommaText := 'kolicina,cijena,rabat,pdv_stopa,iznos'; Txt := ''; RunCalcRulesBuilder(AMain, Fl, Txt); Fl.Free; end;
        end;
      except
        on E: Exception do ALog.Add(Tr('ERROR ') + DialogScenes[I] + ': ' + E.Message);
      end;
    end;
    DeleteFile('/tmp/uvoz-demo.csv');
    Result := S.Saved;
  finally
    GShooter := nil;
    S.Timer.Free;
    S.Free;
  end;
end;

type
  TShotStarter = class
  public
    Main: TForm;
    Db: TAppDb;
    Dir: string;
    Timer: TTimer;
    Prepare: TShotPrepare;
    procedure Go(Sender: TObject);
  end;

var
  GStarter: TShotStarter = nil;

procedure TShotStarter.Go(Sender: TObject);
var
  Log: TStringList;
begin
  Timer.Enabled := False;
  Log := TStringList.Create;
  try
    RunScreenshots(Main, Db, Dir, Log, Prepare);
    WriteLn(Log.Text);
  finally
    Log.Free;
  end;
  Application.Terminate;
end;

procedure ScheduleScreenshots(AMain: TForm; ADb: TAppDb; const ADir: string; APrepare: TShotPrepare);
begin
  GStarter := TShotStarter.Create;
  GStarter.Main := AMain;
  GStarter.Db := ADb;
  GStarter.Dir := ADir;
  GStarter.Prepare := APrepare;
  GStarter.Timer := TTimer.Create(AMain);
  GStarter.Timer.Interval := 1200;
  GStarter.Timer.OnTimer := @GStarter.Go;
  GStarter.Timer.Enabled := True;
end;

end.
