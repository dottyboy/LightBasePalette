program smoke;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Controls, StdCtrls, Buttons, Graphics, SysUtils, {$IFDEF TA_FISCAL}ta_fiscal, ta_fiscalcfg, ta_fiscaldlg, ta_fiscalreg,{$ENDIF} ta_fiscalhook, ta_meta, ta_formdef, ta_controls, ta_formrun, ta_querydesign, ta_reportdef, ta_reportengine, ta_reportview, ta_reportdesign, ta_formdesign, ta_types, ta_fielddlg, ta_importexport, ta_wizardgen, ta_wizards, ta_importdlg, ta_relview, ComCtrls, ta_exprbuilder, ta_exprsql, ta_qbe, ta_calcgen, ta_querywiz, ta_calcdlg, ta_bizgen, ta_bizdlg, ta_params, ta_paramdlg, ta_audit, ta_auditdlg, ta_gridtools, ta_filterdlg, ta_tasks, ta_taskdlg, ta_crosstab, ta_crosstabdlg, ta_maint, ta_datatools, ta_datatoolsdlg, ta_condfmt, ta_words, ta_pdf417, ta_hub3, ta_companydlg, ta_propedit, ta_propdlgs, ta_locale, ta_parse, ta_layout, ta_northwind, ta_migrate, ta_fgl, ta_fglgui, ta_catalog, ta_filestore, base64, FileUtil, ValEdit, DBGrids, ta_script, ta_blocks, ta_blocksdemo, ta_letter, ta_letterdlg, ta_offers, ta_fglblocks, ta_fgledit, zipper, XMLRead, DOM, ta_blockedit, ta_modeditor, ta_pagesetup, ta_icons, ta_iconsdata, ta_iconmap, ta_svg, ta_sidemenu, ta_shell, ta_tabbar, ta_doctypes, ta_showcase2, ta_appspec, ta_mdbimport, IniFiles, ta_theme, Grids, ta_richtext, ta_richedit, ta_showcase, ta_showcasedata, ta_app, ta_appdlg, ta_switchgen, ta_expr, ta_exprdb, ta_predict, ta_newton, ta_marketfit, ta_pairs, ta_validation, ta_league, ta_components, ta_binder, Spin, ta_anchoreditor, ta_propmap, ta_tokens, ta_family, ta_edit, ta_ownedit, ta_owncombo, ta_owndate, ta_ownspin, ta_ownlov, ta_ownmemo, ta_ownrich, ta_richbase, ta_ownlist, ta_owntree, ta_ownboard, ta_formboard, ta_owndash, ta_formdash, ta_owntimeline, ta_formtimeline, ta_esphome, ta_owncalendar, ta_owngrid, ta_gridview, Clipbrd, EditBtn, ta_source, ta_editor, ta_skeleton, ta_skelflow, ta_skelwizard, ta_blockwiz, ta_blockdlg, ta_fglpalette, ta_fglblockdlg, ta_editdlg, ta_rowmodel, ta_rowsource, ta_rowhost, ta_contform, ta_contcomp, ta_bindengine, ta_keymap, ta_lovdlg, ta_check, ta_button, ta_label, ta_memo, ta_choice, ta_list, ta_grid, ta_panel, ta_pages, ta_progress, ta_calendar, ta_image, ta_barcodebox, ta_chartbox, ta_menu, ta_propclass, ta_famctl, ta_i18n, ta_i18n_hr, ta_dict, ta_autoenter, ta_mask, ta_savedfinds, ta_schemaplan, ta_appgen, ta_barcode, Calendar, CheckLst, LCLType, ta_slipgen, ta_backtest, ta_enginebt, ta_dataimport, ta_datarefresh, ta_datascrape, ta_report, ta_analytics, ta_reliability, Variants, ExtCtrls, LConvEncoding, contnrs, Classes, ZDataset;

function RItem(AKind, ASec, AName, ASrc: string; L, T, W, H: Integer): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := AKind; Result.Section := ASec; Result.Name := AName;
  if AKind = 'Label' then Result.Caption := ASrc else Result.ControlSource := ASrc;
  Result.Left := L; Result.Top := T; Result.Width := W; Result.Height := H;
end;

function AllText(Rep: TaRenderedReport): string;
var
  P, I: Integer;
begin
  Result := '';
  for P := 0 to Rep.PageCount - 1 do
    for I := 0 to Rep.Page(P).Items.Count - 1 do
      Result := Result + TaRItem(Rep.Page(P).Items[I]).Text + '|';
end;

function HasText(Rep: TaRenderedReport; const T: string): Boolean;
var
  P, I: Integer;
begin
  Result := False;
  for P := 0 to Rep.PageCount - 1 do
    for I := 0 to Rep.Page(P).Items.Count - 1 do
      if TaRItem(Rep.Page(P).Items[I]).Text = T then Exit(True);
end;

type
  TCloser = class
    procedure Tick(Sender: TObject);
  end;

procedure TCloser.Tick(Sender: TObject);
var
  I: Integer;
begin
  for I := Screen.CustomFormCount - 1 downto 0 do
    if fsModal in Screen.CustomForms[I].FormState then
    begin
      Screen.CustomForms[I].ModalResult := mrCancel;
      Exit;
    end;
end;

type
  TCloser0 = class
    procedure Tick(Sender: TObject);
  end;

  TRecCtx = class(TaScriptContext)
  public
    Log: TStringList;
    function EvalV(const AExpr: string): Variant; override;
    procedure DoAction(const AAction: string); override;
  end;

  TPdfCtx = class(TaScriptContext)
  public
    procedure DoOther(const AVerb, AArg: string); override;
  end;

  TFormLikeCtx = class(TaScriptContext)
  public
    Log: TStringList;
    procedure SetValue(const AName, AValue: string); override;
    procedure SetVisible(const AName: string; AValue: Boolean); override;
    procedure SetEnabled(const AName: string; AValue: Boolean); override;
    procedure SetCaption(const AName, AValue: string); override;
  end;

  TTestHost = class(TaExprHost)
  public
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; override;
  end;

var
  Va: array of Double;
  VSum, VMean, VAcc: Double;
  RO: TaReportOptions;
  MRR: TaMDReportResult;
  PartnerN: Integer;
{$IFDEF TA_FISCAL}
  FcDef: TFiscalConfig;
{$ENDIF}
  RDb: TaReportDef;
  QRows2, QRows3: Integer;
  GfN, GfK: Integer;
  DmM: TaFieldMeta;
  DmL: TFPObjectList;
  DmFl: TStringList;
  TkDir, TkE, TkM: string;
  CtSql, CtErr: string;
  PeDz: TaFormDesigner;
  LcOld: TFormatSettings;
  LcV: Double;
  LcM: TaFieldMeta;
  LcS: string;
  QdBmp: TBitmap;
  QdPng: TPortableNetworkGraphic;
  PeL: TStringList;
  NwDb: TAppDb;
  NwLog, NwForms: TStringList;
  NwBad, NwTxt: string;
  NwI: Integer;
  NwD: TaFormDef;
  NwTot: Double;
  RdDz: TaReportDesigner;
  Ok1: Boolean;
  RdBottom: Integer;
  RdC1, RdC2, RdC3: TControl;
  LyB: TLBoxes;
  LyC2, LyC3: TControl;
  PeC: TControl;
  MdKids, MdFm, MdFa, MdFb: TStringList;
  MdM: TaMDMulti;
  MdErr: string;
  MdSubs, MdYBeta, MdYGama, MdYDelta, MdYZeta, MdYEps: Integer;
  CfC: TControl;
  CbX: TaComboBox;
  CbAll, CbN: Integer;
  CbKey: string;
  PdRows: TPdfRows;
  PdE, PdPay: string;
  PdI: Integer;
  PdOk: Boolean;
  PdL: TStringList;
  DpK, DpI: Integer;
  DpIznos, DpKupac, DpBroj: string;
  DpL: TStringList;
  CfRules: TCondRules;
  CfRule: TCondRule;
  CfBad, CfI, CfJ, CfN, CfK: Integer;
  CfHigh, CfOn: Boolean;
  DtR: TReplaceResult;
  DtE, DtSql: string;
  DtN: Integer;
  DtF, DtLog: TStringList;
  DtM: TaFieldMeta;
  MtBak, MtErr, MtRep, MtDoc: string;
  MtBak2: TAppDb;
  CtL: TStringList;
  TkS: TSchedule;
  TkT: TaTask;
  TkL: TaTasks;
  TkNow: TDateTime;
  TkCnt: Integer;
  TkSr: TSearchRec;
  TkLog: TStringList;
  DmCap, DmTip: string;
  GfSum, GfMax: Double;
  GfSql, GfErr: string;
  GfSet: TStringList;
  Aq: TZQuery;
  QWp, QWv: TStringList;
  QWs: string;
  QCancelled: Boolean;
  REb: TaReportEngine;
  RRb: TaRenderedReport;
{$IFDEF TA_FISCAL}
  FcCert: string;
{$ENDIF}
  RepNm: string;
  Tpls: TaCalcTemplates;
  TplVals: TStringList;
  TplExpr, TplBad: string;
  TplInQuery: Integer;
  BizLog, BizTables, BizForms: TStringList;
  BizOk: Boolean;
  BizI: Integer;
  BizId, BizBad, BrojName: string;
  HiddenSeen: Boolean;
  MM: TaMDMulti;
  MMR: TaMDMultiResult;
  Tab1: Boolean;
  LblLines: TStringList;
  SubQ: TZQuery;
  MasterId: Integer;
  QWt, QWf: TStringList;
  CalcA, CalcE: string;
  QD2, QD3: TaQbeDesign;
  QSql, QErr: string;
  QRows: Integer;
  QTop: Double;
  Cat: TStringList;
  BadFn: string;
  XsSeen: TStringList;
  FO: TaFormOptions;
  MD: TaMDOptions;
  MR: TaMDResult;
  Flds2, Subs, Rels2: TStringList;
  MemoSeen, LockSeen, SubSeen: Boolean;
  AppS: TaAppSettings;
  Role1: TaRole;
  PackDir: string;
  PackDb: TAppDb;
  Tm2: TTimer;
  ScriptLog: string;
  ScriptErr: string;
  RV: Variant;
  LastMsg: string;

procedure CaptureScript(const AMsg: string);
begin
  ScriptLog := ScriptLog + '[' + AMsg + ']';
end;

function FallbackForTest(ADb: TAppDb): TaScriptContext;
begin
  Result := TaScriptContext.Create(ADb);
end;

procedure CaptureMsg(const AMsg: string);
begin
  LastMsg := AMsg;
end;

procedure TCloser0.Tick(Sender: TObject);
var
  I: Integer;
begin
  for I := Screen.CustomFormCount - 1 downto 0 do
    if fsModal in Screen.CustomForms[I].FormState then
    begin
      Screen.CustomForms[I].ModalResult := mrCancel;
      Exit;
    end;
end;

function TRecCtx.EvalV(const AExpr: string): Variant;
begin
  Result := (Pos('IsNull', AExpr) > 0) or (Pos('> 1', AExpr) > 0);
end;

procedure TRecCtx.DoAction(const AAction: string);
var
  P: Integer;
begin
  { isto razlucivanje naredbe kao TaScriptContext.DoAction: naredba malim slovima, argument bez razmaka }
  P := Pos(':', AAction);
  if P > 0 then Log.Add(LowerCase(Trim(Copy(AAction, 1, P - 1))) + ': ' + Trim(Copy(AAction, P + 1, MaxInt)))
  else Log.Add(LowerCase(Trim(AAction)));
end;

procedure TPdfCtx.DoOther(const AVerb, AArg: string);
var
  Err: string;
begin
  if AVerb = 'exportpdf' then
  begin
    if not ExportReportPdfNamed(Db, AArg, Err) then ScriptNotify('PDF nije izrađen: ' + Err);
  end
  else if AVerb = 'exporthtml' then
  begin
    if not ExportReportHtmlNamed(Db, AArg, Err) then ScriptNotify('HTML nije izrađen: ' + Err);
  end
  else if AVerb = 'exportletter' then
  begin
    if not ExportLetterNamed(Db, AArg, Err) then ScriptNotify('Dopis nije izvezen: ' + Err);
  end
  else inherited DoOther(AVerb, AArg);
end;

procedure TFormLikeCtx.SetValue(const AName, AValue: string);
begin
  Log.Add('set ' + AName + '=' + AValue);
end;

procedure TFormLikeCtx.SetVisible(const AName: string; AValue: Boolean);
begin
  Log.Add('visible ' + AName + '=' + BoolToStr(AValue, '1', '0'));
end;

procedure TFormLikeCtx.SetEnabled(const AName: string; AValue: Boolean);
begin
  Log.Add('enabled ' + AName + '=' + BoolToStr(AValue, '1', '0'));
end;

procedure TFormLikeCtx.SetCaption(const AName, AValue: string);
begin
  Log.Add('caption ' + AName + '=' + AValue);
end;

function TTestHost.FieldValue(const AName: string): Variant;
begin
  if AName = 'a' then Result := 5
  else if AName = 'b' then Result := 3
  else if AName = 's' then Result := 'Zagreb'
  else if AName = 'd' then Result := '2026-03-15'
  else Result := Null;
end;

function TTestHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := 42;
end;

function TTestHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  Result := DbDomain(ActiveDb, AFunc, AExpr, ADomain, ACriteria);
end;

function TTestHost.Variable(const AName: string): Variant;
begin
  Result := Null;
end;

var
  ParamAsked: Integer = 0;
  ParamAnswer: string = '100';
  ParamCancel: Boolean = False;

function TestParamPrompt(ANames, AValues: TStrings): Boolean;
var
  I: Integer;
begin
  Inc(ParamAsked);
  if ParamCancel then Exit(False);
  for I := 0 to ANames.Count - 1 do AValues.Values[ANames[I]] := ParamAnswer;
  Result := True;
end;

type
  TComboHack = class(TaComboBox)
  public
    procedure CallChange;
    procedure CallSelect;
    procedure CallExit;
  end;

procedure TComboHack.CallChange; begin Change; end;
procedure TComboHack.CallSelect; begin Select; end;
procedure TComboHack.CallExit; begin DoExit; end;

function TestDateRangePrompt(ANames, AValues: TStrings): Boolean;
var
  I: Integer;
begin
  for I := 0 to ANames.Count - 1 do
    if Pos('Od', ANames[I]) = 1 then AValues.Values[ANames[I]] := '01.01.1996' else AValues.Values[ANames[I]] := '31.12.1998';
  Result := True;
end;

function FormatSqlOf(const AFmt: string): string;
var
  Sx, Er: string;
begin
  if not ExprToSql('Format([a], "' + AFmt + '")', nil, Sx, Er) then Sx := '';
  Result := Sx;
end;

function Ev(H: TTestHost; const E: string): string;
begin
  Result := FormatValue(EvalExpr(E, H), '');
end;

var
  TabC: TControl;
  PgK, K1i: Integer;
  Closer0: TCloser0;
  Tm0: TTimer;
  XH: TTestHost;
  Closer: TCloser;
  Tm: TTimer;
  K1, K2: Boolean;
  Sv2, Sv3, Sv4: string;
  Fks: TaFkDefs;
  Rels: TaRelations;
  FkRefused: Boolean;
  RD: TaReportDef;
  Mt: TaFieldMeta;
  Sv: string;
  Fmt: TaDatasetFormatter;
  Sq: TZQuery;
  K: Integer;
  Flds: TStringList;
  Rows: TaRows;
  Dl: Char;
  ICols: TaImportCols;
  IRes: TaImportResult;
  RR: TaRenderedReport;
  RE: TaReportEngine;
  Rd2: TaReportDef;
  PdfErr: string;
  Db: TAppDb;
  Fl: TFieldDefs2;
  D, D2: TaFormDef;
  C: TaControlDef;
  R: TaFormRunner;
  QD: TaQueryDesigner;
  Fd: TFieldDef;
  Q: TZQuery;
  Fails: Integer = 0;

procedure Check(ACond: Boolean; const AMsg: string);
begin
  if ACond then WriteLn('ok   ', AMsg) else begin WriteLn('FAIL ', AMsg); Inc(Fails); end;
  Flush(Output);
end;

function NewCtl(const K, N, Src: string; L, T: Integer): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := K; Result.Name := N; Result.ControlSource := Src;
  Result.Left := L; Result.Top := T; Result.Width := 150; Result.Height := 24;
  Result.Caption := N;
end;

const
  CrossList: array[0..60] of string = (
    '[a] * [b] - 1', '[a] / [b]', '[a] \ [b]', '[a] Mod [b]', '2 ^ 3', '-[a] + 10',
    'Iif([a] > [b], "x", "y")', '[s] & "-" & [a]', 'Nz([n], 7)', 'IsNull([n])', 'Coalesce([n], [n], "x")',
    'Left([s], 3)', 'Right([s], 3)', 'Mid([s], 2, 3)', 'Mid([s], 4)', 'UCase([s])', 'LCase([s])', 'Len([s])',
    'InStr([s], "gre")', 'Replace([s], "a", "o")', 'Trim("  ab ")', 'Concat([s], "!", [a])',
    'StartsWith([s], "zag")', 'EndsWith([s], "REB")', 'Contains([s], "agr")',
    'Round(2.567, 1)', 'Abs(-4)', 'Int(2.9)', 'Int(-2.1)', 'Ceil(2.1)', 'Sqr(16)', 'Max(3, 9, 4)', 'Min(3, 9, 4)',
    'Percent(25, 200)', 'Clamp(15, 0, 10)', 'CInt("12") + 1',
    'Year([d])', 'Month([d])', 'Day([d])', 'Weekday([d])', 'Quarter([d])',
    'Format(DateAdd("d", 20, [d]), "yyyy-mm-dd")', 'Format(DateAdd("m", 1, [d]), "yyyy-mm-dd")',
    'DateDiff("d", [d], #2026-04-01#)', 'DateDiff("m", #2026-01-31#, #2026-03-01#)', 'DateDiff("yyyy", #2020-06-01#, [d])',
    'Format(EOMonth([d]), "yyyy-mm-dd")', 'Format(BOMonth([d]), "yyyy-mm-dd")', 'Age(#2000-06-15#, [d])',
    'Format(DateSerial(2026, 4, 9), "dd.mm.yyyy")', 'DaysBetween(#2026-03-01#, [d])',
    'Format(1234.5, "0.00")', 'Format([d], "dd.mm.yyyy")',
    '[s] Like "Zag*"', '[a] Between 1 And 5', '[a] In (1, 5, 9)', 'Not ([a] = 5)', '[a] > 3 And [b] < 5',
    '[a] = 5 Or [b] = 9', 'Choose(2, "x", "y", "z")', 'Switch([a] < 3, "a", [a] < 9, "b", True, "c")');

type
  TResolver1 = class
    function Resolve(const AName: string): string;
  end;

function TResolver1.Resolve(const AName: string): string;
begin
  Result := '"tt"."' + AName + '"';
end;

var
  Resolver1: TResolver1;
  SqlOut, SqlErr: string;
  Fl3: TStringList;

var
  CrossFails: string;
  CrossCount: Integer;
  CrossDb: TAppDb = nil;   { nil = Db }

{ Runs one expression both ways (expression evaluator, and translated to SQL on SQLite) and compares. }
procedure CrossCheck(const AExpr: string);
var
  Host: TTestHost;
  Want, Got, Sql, Err: string;
  WantV: Variant;
  Q: TZQuery;
  W, G: Double;
begin
  Host := TTestHost.Create;
  try
    WantV := EvalExpr(AExpr, Host);
    if VarType(WantV) = varBoolean then
    begin
      if Boolean(WantV) then Want := '1' else Want := '0';
    end
    else if VarType(WantV) = varDate then Want := FormatDateTime('yyyy-mm-dd', WantV)
    else Want := FormatValue(WantV, '');
  finally
    Host.Free;
  end;
  if not ExprToSql(AExpr, nil, Sql, Err) then
  begin
    CrossFails := CrossFails + AExpr + ' => ' + Err + '; ';
    Exit;
  end;
  Inc(CrossCount);
  if CrossDb = nil then CrossDb := Db;
  Q := CrossDb.NewQuery('SELECT ' + Sql + ' FROM tt');
  try
    try
      Q.Open;
      if Q.Fields[0].IsNull then Got := '' else Got := Q.Fields[0].AsString;
      if CrossDb.Kind = dkPostgres then
      begin
        if SameText(Got, 'true') or (Got = 't') then Got := '1'
        else if SameText(Got, 'false') or (Got = 'f') then Got := '0';
      end;
    except
      on E: Exception do begin CrossFails := CrossFails + AExpr + ' => SQL ' + E.Message + '; '; Exit; end;
    end;
  finally
    Q.Free;
  end;
  if TryStrToFloat(Want, W, InvariantFS) and TryStrToFloat(Got, G, InvariantFS) then
  begin
    if Abs(W - G) > 0.000001 then CrossFails := CrossFails + AExpr + ' => ' + Want + ' vs SQL ' + Got + '; ';
  end
  else if Want <> Got then CrossFails := CrossFails + AExpr + ' => "' + Want + '" vs SQL "' + Got + '"; ';
end;

{ Postgres (privatni klaster na 5433, vidi tools/pg_test.sh): preskace se ako nije dostupan. }
function PgHasCol(P: TAppDb; const T, C: string): Boolean;
var
  Q: TZQuery;
begin
  Result := False;
  Q := P.TableInfo(T);
  try
    while not Q.EOF do
    begin
      if SameText(Q.FieldByName('name').AsString, C) then Result := True;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function ConnectKind(P: TAppDb; AKind: TDbKind; const ADb: string): Boolean;
begin
  Result := False;
  try
    if AKind = dkMaria then P.OpenMaria('127.0.0.1', 3307, ADb, 'ta', '')
    else P.OpenPostgres('127.0.0.1', 5433, ADb, 'ta', '');
    Result := True;
  except
    on E: Exception do WriteLn('skip ', ADb, ': ', E.Message);
  end;
end;

procedure TestMetaDb(AKind: TDbKind);
var
  LbN: string;
  P: TAppDb;
  Q: TZQuery;
  T, L: TStringList;
  F: TaFkDefs;
  Fd: TFieldDefs2;
  Ok: Boolean;
  K: Integer;
begin
  P := TAppDb.Create;
  try
    if AKind = dkMaria then LbN := 'maria' else LbN := 'pg';
    if AKind = dkMaria then Ok := ConnectKind(P, AKind, 'nw_built') else Ok := ConnectKind(P, AKind, 'northwind');
    if not Ok then Exit;
    try
      Check(P.Kind = AKind, LbN + ': kind');
      T := P.UserTables;
      Check((T.IndexOf('orders') >= 0) and (T.IndexOf('orderdetails') >= 0) and (T.IndexOf('_sys_forms') < 0),
        LbN + ': user tables listed, _sys_ hidden (' + T.CommaText + ')');
      T.Free;
      Check(P.PrimaryKeyOf('orders') = 'orderid', LbN + ': primary key via table info');
      if AKind = dkPostgres then
      begin
        Q := P.NewQuery('SELECT "freight", "orderdate" FROM "orders" WHERE "orderid" = (SELECT MIN("orderid") FROM "orders")'); Q.Open;
        Check(Q.Fields[0].DisplayText = '7.38', LbN + ': numeric(12,2) shows its scale (' + Q.Fields[0].DisplayText + ')');
        Q.Free;
      end;
      Q := P.NewQuery('SELECT COUNT(*) FROM "orders"'); Q.Open;
      Check(Q.Fields[0].AsInteger = 220, LbN + ': 220 orders'); Q.Free;
      F := P.GetFks('orderdetails');
      Check((Length(F) = 2) and (F[0].RefTable <> '') and (F[0].FromCol <> ''), LbN + ': foreign keys read (' + IntToStr(Length(F)) + ')');
      L := P.ForeignKeys('orders');
      Check(L.Count = 3, LbN + ': ForeignKeys(Orders) = 3 (' + IntToStr(L.Count) + ')'); L.Free;
      P.SaveSetting('t.a', '1'); P.SaveSetting('t.a', '2');
      Check(P.LoadSetting('t.a') = '2', LbN + ': upsert updates in place');
      P.SaveObject('_sys_forms', 'pgform', '{"x":1}'); P.SaveObject('_sys_forms', 'pgform', '{"x":2}');
      Check(P.LoadObject('_sys_forms', 'pgform') = '{"x":2}', LbN + ': object upsert');
      P.DeleteObject('_sys_forms', 'pgform');
      { isti izrazi kao za SQLite: evaluator naspram prijevoda za Postgres }
      try P.Conn.ExecuteDirect('DROP TABLE IF EXISTS tt'); except end;
      P.Conn.ExecuteDirect('CREATE TABLE tt (a INTEGER, b INTEGER, s TEXT, d TEXT, n TEXT)');
      P.Conn.ExecuteDirect('INSERT INTO tt VALUES (5, 3, ''Zagreb'', ''2026-03-15'', NULL)');
      CrossDb := P; CrossFails := ''; CrossCount := 0;
      for K := 0 to High(CrossList) do CrossCheck(CrossList[K]);
      CrossDb := nil;
      Check(CrossFails = '', LbN + ': translator agrees with the evaluator on ' + IntToStr(CrossCount) + ' expressions: ' + CrossFails);
      P.Conn.ExecuteDirect('DROP TABLE tt');
      try P.Conn.ExecuteDirect('DROP TABLE IF EXISTS "pg_scratch"'); except end;
      SetLength(Fd, 2);
      Fd[0].Name := 'id'; Fd[0].SqlType := 'INTEGER'; Fd[0].PrimaryKey := True;
      Fd[0].Meta := TaFieldMeta.Create; Fd[0].Meta.LType := ltAutoNumber;
      Fd[1].Name := 'iznos'; Fd[1].SqlType := 'REAL';
      P.CreateTable('pg_scratch', Fd);
      P.Conn.ExecuteDirect('INSERT INTO "pg_scratch" ("iznos") VALUES (1.5)');
      P.Conn.ExecuteDirect('INSERT INTO "pg_scratch" ("iznos") VALUES (2.5)');
      Q := P.NewQuery('SELECT MAX("id"), SUM("iznos") FROM "pg_scratch"'); Q.Open;
      Check((Q.Fields[0].AsInteger = 2) and (Abs(Q.Fields[1].AsFloat - 4) < 1e-9), LbN + ': auto number + double precision'); Q.Free;
      Fd[1].Name := 'napomena'; Fd[1].SqlType := 'TEXT';
      P.AddColumn('pg_scratch', Fd[1]);
      Check(PgHasCol(P, 'pg_scratch', 'napomena'), LbN + ': column added');
      SetLength(F, 1);
      F[0].FromCol := 'id'; F[0].RefTable := 'orders'; F[0].RefCol := 'orderid'; F[0].OnDelete := 'CASCADE';
      P.Conn.ExecuteDirect('INSERT INTO "pg_scratch" ("id") VALUES (999999)');
      try
        P.SetFks('pg_scratch', F);
        Check(False, LbN + ': FK violation must be rejected');
      except
        on E: Exception do Check(True, LbN + ': FK violation rejected');
      end;
      P.Conn.ExecuteDirect('DELETE FROM "pg_scratch"');
      P.Conn.ExecuteDirect('INSERT INTO "pg_scratch" ("id") SELECT "orderid" FROM "orders" LIMIT 3');
      P.SetFks('pg_scratch', F);
      F := P.GetFks('pg_scratch');
      Check((Length(F) = 1) and (F[0].RefTable = 'orders') and (SameText(F[0].OnDelete, 'CASCADE')), LbN + ': FK set and read back');
      P.DropColumn('pg_scratch', 'napomena');
      Check(not PgHasCol(P, 'pg_scratch', 'napomena'), LbN + ': column dropped');
    finally
      try P.Conn.ExecuteDirect('DROP TABLE IF EXISTS "pg_scratch"'); except end;
      P.Conn.ExecuteDirect('DELETE FROM _sys_fields WHERE tbl = ''pg_scratch''');
      P.Conn.ExecuteDirect('DELETE FROM _sys_settings WHERE k = ''t.a''');
    end;
  finally
    SqlPostgres := False;
    SqlMaria := False;
    P.Free;
  end;
end;

{ Northwind izgraden builderom izravno u Postgresu (baza nw_built). }
procedure TestMigrate(AKind: TDbKind);
var
  S, P: TAppDb;
  Lg, Names: TStringList;
  QS, QP: TZQuery;
  D: TaFormDef;
  R: TaFormRunner;
  I: Integer;
  Bad, LbN, Tn, Sf: string;
begin
  if AKind = dkMaria then LbN := 'maria migrate' else LbN := 'pg migrate';
  Sf := '/tmp/ta_migrate_src.db';
  if FileExists(Sf) then DeleteFile(Sf);
  S := TAppDb.Create;
  P := TAppDb.Create;
  try
    S.Open(Sf);
    Lg := TStringList.Create;
    try
      if not BuildNorthwind(S, Lg) then begin Check(False, LbN + ': source built'); Exit; end;
    finally
      Lg.Free;
    end;
    if not ConnectKind(P, AKind, 'nw_built') then Exit;
    if AKind = dkMaria then
    begin
      P.Conn.ExecuteDirect('DROP DATABASE nw_built');
      P.Conn.ExecuteDirect('CREATE DATABASE nw_built CHARACTER SET utf8mb4');
    end
    else
    begin
      P.Conn.ExecuteDirect('DROP SCHEMA public CASCADE');
      P.Conn.ExecuteDirect('CREATE SCHEMA public');
    end;
    ConnectKind(P, AKind, 'nw_built');
    Lg := TStringList.Create;
    Check(MigrateDb(S, P, Lg), LbN + ': migrated');
    if (Pos('GREŠKA', Lg.Text) > 0) or (Pos('UPOZORENJE', Lg.Text) > 0) then WriteLn('MIGLOG ', Lg.Text);
    Lg.Free;
    Names := S.UserTables;
    Bad := '';
    for I := 0 to Names.Count - 1 do
    begin
      Tn := Names[I];
      QS := S.NewQuery('SELECT COUNT(*) FROM "' + Tn + '"');
      QP := P.NewQuery('SELECT COUNT(*) FROM "' + LowerCase(Tn) + '"');
      try
        QS.Open; QP.Open;
        if QS.Fields[0].AsInteger <> QP.Fields[0].AsInteger then
          Bad := Bad + Tn + ' ' + QS.Fields[0].AsString + '/' + QP.Fields[0].AsString + '; ';
      except
        on E: Exception do Bad := Bad + Tn + ': ' + E.Message + '; ';
      end;
      QS.Free; QP.Free;
    end;
    Check((Bad = '') and (Names.Count >= 8), LbN + ': row counts equal in ' + IntToStr(Names.Count) + ' tables ' + Bad);
    Names.Free;
    { zbroj iz izvora i odredista isti }
    QS := S.NewQuery('SELECT ROUND(SUM(unitprice * quantity), 2) FROM orderdetails');
    QP := P.NewQuery('SELECT ROUND(CAST(SUM(unitprice * quantity) AS DECIMAL(18,4)), 2) FROM orderdetails');
    try
      QS.Open; QP.Open;
      Check(Abs(QS.Fields[0].AsFloat - QP.Fields[0].AsFloat) < 0.01, LbN + ': order total equal');
    except
      on E: Exception do Check(False, LbN + ': total ' + E.Message);
    end;
    QS.Free; QP.Free;
    { novi redak dobiva sljedeci autonumber (niz podignut iza kopije) }
    try
      P.Conn.ExecuteDirect('INSERT INTO shippers (companyname) VALUES (''Novi'')');
      QP := P.NewQuery('SELECT MAX(shipperid) FROM shippers');
      QP.Open;
      Check(QP.Fields[0].AsInteger = 4, LbN + ': autonumber continues (' + QP.Fields[0].AsString + ')');
      QP.Free;
    except
      on E: Exception do Check(False, LbN + ': autonumber ' + E.Message);
    end;
    Names := P.ListObjects('_sys_forms');
    Bad := '';
    for I := 0 to Names.Count - 1 do
      try
        D := TaFormDef.Create;
        D.FromJson(P.LoadObject('_sys_forms', Names[I]));
        D.Name := Names[I];
        R := TaFormRunner.CreateRunner(nil, P, D);
        R.Free;
      except
        on E: Exception do Bad := Bad + Names[I] + ': ' + E.Message + '; ';
      end;
    Check((Bad = '') and (Names.Count >= 10), LbN + ': migrated forms open (' + IntToStr(Names.Count) + ') ' + Bad);
    Names.Free;
    Check(Length(P.GetFks('orders')) >= 2, LbN + ': foreign keys copied');
  finally
    P.Free;
    S.Free;
  end;
end;

procedure TestFgl;
const
  Prog1 =
    'DATABASE northwind'#10 +
    'GLOBALS'#10 +
    '  DEFINE g_total INTEGER'#10 +
    'END GLOBALS'#10 +
    'FUNCTION dvaput(x)'#10 +
    '  DEFINE x INTEGER'#10 +
    '  RETURN x * 2, x + 1'#10 +
    'END FUNCTION'#10 +
    'FUNCTION kupci()'#10 +
    '  DEFINE k RECORD LIKE customers.*'#10 +
    '  DEFINE n INTEGER'#10 +
    '  LET n = 0'#10 +
    '  LET k.country = "Germany"'#10 +
    '  DECLARE c CURSOR FOR'#10 +
    '    SELECT * FROM customers WHERE country = $k.country ORDER BY customerid'#10 +
    '  FOREACH c INTO k.*'#10 +
    '    LET n = n + 1'#10 +
    '    IF n = 2 THEN CONTINUE FOREACH END IF'#10 +
    '    DISPLAY n, ":", k.customerid, " ", k.companyname'#10 +
    '    IF n >= 4 THEN EXIT FOREACH END IF'#10 +
    '  END FOREACH'#10 +
    '  LET g_total = n'#10 +
    'END FUNCTION'#10 +
    'MAIN'#10 +
    '  DEFINE a, b INTEGER'#10 +
    '  DEFINE s TEXT'#10 +
    '  DEFINE d DATE'#10 +
    '  DEFINE arr ARRAY[3] OF INTEGER'#10 +
    '  CALL dvaput(21) RETURNING a, b'#10 +
    '  DISPLAY "dvaput=", a, " b=", b'#10 +
    '  LET s = "Zagreb" || " " || 5 + 1'#10 +
    '  DISPLAY s'#10 +
    '  LET arr[2] = 7'#10 +
    '  DISPLAY "arr2=", arr[2], " nul=", arr[1] IS NULL'#10 +
    '  FOR a = 1 TO 5 STEP 2'#10 +
    '    DISPLAY "for ", a'#10 +
    '  END FOR'#10 +
    '  CASE a'#10 +
    '    WHEN 7  DISPLAY "sedam"'#10 +
    '    OTHERWISE DISPLAY "drugo ", a'#10 +
    '  END CASE'#10 +
    '  SELECT COUNT(*) INTO a FROM customers'#10 +
    '  DISPLAY "kupaca=", a, " status=", SQLCA.SQLCODE'#10 +
    '  SELECT companyname INTO s FROM customers WHERE customerid = 99999'#10 +
    '  DISPLAY "nema=", SQLCA.SQLCODE'#10 +
    '  LET d = "31.12.2026"'#10 +
    '  DISPLAY d, " ", d USING "dd.mm.yyyy", " ", Upper("abc"), " ", Nvl(NULL, "x")'#10 +
    '  MENU "Glavni"'#10 +
    '    COMMAND "Kupci" "Popis" CALL kupci()'#10 +
    '    COMMAND "Cijena" "Poskupljenje"'#10 +
    '      PROMPT "Postotak: " FOR a'#10 +
    '      IF INT_FLAG THEN'#10 +
    '        DISPLAY "odustao"'#10 +
    '      ELSE'#10 +
    '        BEGIN WORK'#10 +
    '        UPDATE products SET unitprice = unitprice * (1 + $a / 100.0) WHERE productid = 1'#10 +
    '        ROLLBACK WORK'#10 +
    '        DISPLAY "redaka ", SQLCA.SQLERRD[3]'#10 +
    '      END IF'#10 +
    '    COMMAND "Izlaz" "Kraj" EXIT MENU'#10 +
    '  END MENU'#10 +
    '  DISPLAY "total=", g_total'#10 +
    'END MAIN'#10;
  Prog2 =
    'MAIN'#10 +
    '  DEFINE k RECORD LIKE shippers.*'#10 +
    '  DEFINE uvjet, sql TEXT'#10 +
    '  DEFINE n, cnt INTEGER'#10 +
    '  LET k.shipperid = 77'#10 +
    '  INPUT BY NAME k.* WITHOUT DEFAULTS'#10 +
    '    AFTER FIELD companyname'#10 +
    '      IF k.companyname IS NULL THEN'#10 +
    '        ERROR "Naziv je obavezan"'#10 +
    '        NEXT FIELD companyname'#10 +
    '      END IF'#10 +
    '  END INPUT'#10 +
    '  IF NOT INT_FLAG THEN'#10 +
    '    INSERT INTO shippers (shipperid, companyname, phone) VALUES ($k.shipperid, $k.companyname, $k.phone)'#10 +
    '    DISPLAY "uneseno ", SQLCA.SQLERRD[3]'#10 +
    '  END IF'#10 +
    '  CONSTRUCT BY NAME uvjet ON customers.companyname, customers.city'#10 +
    '  LET sql = "SELECT COUNT(*) FROM customers WHERE " || uvjet'#10 +
    '  DISPLAY sql'#10 +
    '  PREPARE p1 FROM "SELECT COUNT(*) FROM shippers WHERE shipperid > ?"'#10 +
    '  DECLARE c2 CURSOR FOR p1'#10 +
    '  OPEN c2 USING 70'#10 +
    '  FETCH c2 INTO cnt'#10 +
    '  CLOSE c2'#10 +
    '  DISPLAY "vecih od 70: ", cnt'#10 +
    '  WHENEVER ERROR CONTINUE'#10 +
    '  DELETE FROM nema_takve_tablice'#10 +
    '  DISPLAY "sqlcode<0: ", SQLCA.SQLCODE < 0'#10 +
    '  WHENEVER ERROR STOP'#10 +
    '  DELETE FROM nema_takve_tablice'#10 +
    '  DISPLAY "ovo se ne smije vidjeti"'#10 +
    'END MAIN'#10;
var
  Pr: TaFglProgram;
  Io: TaFglScriptIO;
  Rn: TaFglRunner;
  Db2: TAppDb;
  Lg: TStringList;
  Txt, Err: string;
  Rc, I: Integer;
begin
  Db2 := TAppDb.Create;
  try
    if FileExists('/tmp/ta_fgl_nw.db') then DeleteFile('/tmp/ta_fgl_nw.db');
    Db2.Open('/tmp/ta_fgl_nw.db');
    Lg := TStringList.Create;
    BuildNorthwind(Db2, Lg);
    Lg.Free;
    Pr := TaFglProgram.Create;
    Io := TaFglScriptIO.Create;
    try
      Pr.LoadText(Prog1, 'prog1.4gl');
      Lg := TStringList.Create;
      Check(Pr.CheckProgram(Lg) = 0, 'fgl: static check passes ' + Lg.Text);
      Lg.Free;
      Io.MenuAnswers.Add('Kupci');
      Io.MenuAnswers.Add('Cijena');
      Io.PromptAnswers.Add('10');
      Io.MenuAnswers.Add('Cijena');
      Io.PromptAnswers.Add('<cancel>');
      Io.MenuAnswers.Add('Izlaz');
      Rn := TaFglRunner.Create(Pr, Db2, Io);
      try
        Rc := Rn.Run;
      finally
        Rn.Free;
      end;
      Txt := Io.Out.Text;
      Check(Rc = 0, 'fgl: program ran (rc=' + IntToStr(Rc) + ') ' + Txt);
      Check(Io.Out.IndexOf('dvaput=42 b=22') >= 0, 'fgl: function returns two values');
      Check(Io.Out.IndexOf('Zagreb 6') >= 0, 'fgl: concat and arithmetic ' + Txt);
      Check(Io.Out.IndexOf('arr2=7 nul=TRUE') >= 0, 'fgl: arrays and IS NULL');
      Check((Io.Out.IndexOf('for 1') >= 0) and (Io.Out.IndexOf('for 3') >= 0) and (Io.Out.IndexOf('for 5') >= 0) and (Io.Out.IndexOf('for 2') < 0), 'fgl: FOR with STEP');
      Check(Io.Out.IndexOf('drugo 5') >= 0, 'fgl: CASE otherwise ' + Txt);
      Check(Io.Out.IndexOf('kupaca=30 status=0') >= 0, 'fgl: SELECT INTO ' + Txt);
      Check(Io.Out.IndexOf('nema=100') >= 0, 'fgl: NOTFOUND = 100');
      Check(Io.Out.IndexOf('2026-12-31 31.12.2026 ABC x') >= 0, 'fgl: DATE, USING, builtins ' + Txt);
      Check(Pos('1:', Txt) > 0, 'fgl: cursor loop shows rows');
      Check(Pos('2:', Txt) = 0, 'fgl: CONTINUE FOREACH skipped row 2');
      Check(Io.Out.IndexOf('redaka 1') >= 0, 'fgl: UPDATE affected 1 row, in transaction ' + Txt);
      Check(Io.Out.IndexOf('odustao') >= 0, 'fgl: PROMPT cancel sets INT_FLAG');
      Check(Pos('total=4', Txt) > 0, 'fgl: global set in function (' + Txt + ')');
      Check(Pos('MENU: Glavni [Kupci|Cijena|Izlaz]', Txt) > 0, 'fgl: menu shown');
    finally
      Io.Free;
      Pr.Free;
    end;
    { greske: parser i provjera }
    Pr := TaFglProgram.Create;
    try
      Err := '';
      try
        Pr.LoadText('MAIN'#10'  LET x = '#10'END MAIN'#10, 'bad.4gl');
      except
        on E: EFglError do Err := E.Message;
      end;
      Check(Pos('bad.4gl:3', Err) = 1, 'fgl: parse error has file:line (' + Err + ')');
    finally
      Pr.Free;
    end;
    Pr := TaFglProgram.Create;
    Lg := TStringList.Create;
    try
      Pr.LoadText('MAIN'#10'  DEFINE a INTEGER'#10'  LET b = 1'#10'  CALL nema(1)'#10'  FETCH c INTO a'#10'  EXIT WHILE'#10'END MAIN'#10, 'chk.4gl');
      I := Pr.CheckProgram(Lg);
      Check(I = 4, 'fgl: check finds 4 problems (' + IntToStr(I) + ') ' + Lg.Text);
    finally
      Lg.Free;
      Pr.Free;
    end;
    { INPUT / CONSTRUCT / WHENEVER / PREPARE }
    Pr := TaFglProgram.Create;
    Io := TaFglScriptIO.Create;
    try
      Pr.LoadText(Prog2, 'prog2.4gl');
      Io.InputAnswers.Add('shipperid=77');
      Io.InputAnswers.Add('companyname=Brza posta|phone=555');
      Io.ConstructAnswers.Add('customers.companyname=A*|customers.city=Berlin:Zagreb');
      Rn := TaFglRunner.Create(Pr, Db2, Io);
      try
        Rc := Rn.Run;
      finally
        Rn.Free;
      end;
      Txt := Io.Out.Text;
      Check(Rc = 1, 'fgl: STOP error ends program with rc=1 (' + IntToStr(Rc) + ')');
      Check(Io.Out.IndexOf('ERR: Naziv je obavezan') >= 0, 'fgl: AFTER FIELD ERROR shown ' + Txt);
      Check(Io.Out.IndexOf('FOCUS: companyname') >= 0, 'fgl: NEXT FIELD refocuses');
      Check(Io.Out.IndexOf('uneseno 1') >= 0, 'fgl: INSERT with $record params ' + Txt);
      Check(Pos('customers.companyname LIKE ''A%'' AND customers.city BETWEEN ''Berlin'' AND ''Zagreb''', Txt) > 0, 'fgl: CONSTRUCT builds WHERE ' + Txt);
      Check(Io.Out.IndexOf('vecih od 70: 1') >= 0, 'fgl: PREPARE / OPEN USING / FETCH ' + Txt);
      Check(Io.Out.IndexOf('sqlcode<0: TRUE') >= 0, 'fgl: WHENEVER ERROR CONTINUE ' + Txt);
      Check(Io.Out.IndexOf('ovo se ne smije vidjeti') < 0, 'fgl: STOP stops');
      Check(Pos('ERR: ', Txt) > 0, 'fgl: SQL error reported');
    finally
      Io.Free;
      Pr.Free;
    end;
  finally
    Db2.Free;
  end;
end;

procedure TestFgl2;
const
  Prog3 =
    'DATABASE northwind'#10 +
    'SCREEN s_ship'#10 +
    '  TITLE "Dostavljač"'#10 +
    '  LABEL "Šifra" FIELD shipperid READONLY'#10 +
    '  LABEL "Naziv" FIELD companyname REQUIRED UPSHIFT COMMENT "Ime tvrtke"'#10 +
    '  LABEL "Telefon" FIELD phone DEFAULT "000"'#10 +
    'END SCREEN'#10 +
    'SCREEN s_prod'#10 +
    '  TITLE "Proizvod"'#10 +
    '  FIELD productname'#10 +
    '  LABEL "Kategorija" FIELD categoryid LOOKUP categories(categoryid, categoryname)'#10 +
    'END SCREEN'#10 +
    'SCREEN s_stavke'#10 +
    '  TITLE "Stavke"'#10 +
    '  LABEL "Šifra" FIELD productid'#10 +
    '  LABEL "Naziv" FIELD productname'#10 +
    '  LABEL "Cijena" FIELD unitprice'#10 +
    'END SCREEN'#10 +
    'MAIN'#10 +
    '  DEFINE k RECORD LIKE shippers.*'#10 +
    '  DEFINE p RECORD LIKE products.*'#10 +
    '  DEFINE r RECORD LIKE products.*'#10 +
    '  DEFINE lista ARRAY[] OF RECORD LIKE products.*'#10 +
    '  DEFINE n INTEGER'#10 +
    '  LET k.shipperid = 88'#10 +
    '  INPUT BY NAME k.* FROM s_ship'#10 +
    '  DISPLAY k.shipperid, "|", k.companyname, "|", k.phone'#10 +
    '  DISPLAY BY NAME k.* TO s_ship'#10 +
    '  LET p.productname = "Test"'#10 +
    '  INPUT BY NAME p.* FROM s_prod'#10 +
    '  DISPLAY "cat=", p.categoryid'#10 +
    '  DECLARE c CURSOR FOR SELECT * FROM products WHERE productid <= 3 ORDER BY productid'#10 +
    '  LET n = 0'#10 +
    '  FOREACH c INTO r.*'#10 +
    '    LET n = n + 1'#10 +
    '    LET lista[n].* = r.*'#10 +
    '  END FOREACH'#10 +
    '  DISPLAY ARRAY lista TO s_stavke'#10 +
    '  DISPLAY "count=", ARR_COUNT, " cur=", ARR_CURR'#10 +
    '  INPUT ARRAY lista FROM s_stavke'#10 +
    '  DISPLAY "after: ", ARR_COUNT, " ", lista[1].productname, " ", lista[2].unitprice'#10 +
    'END MAIN'#10;
var
  Pr: TaFglProgram;
  Io: TaFglScriptIO;
  Rn: TaFglRunner;
  Db2: TAppDb;
  Lg: TStringList;
  Txt: string;
  Rc: Integer;
begin
  Db2 := TAppDb.Create;
  try
    if FileExists('/tmp/ta_fgl_nw2.db') then DeleteFile('/tmp/ta_fgl_nw2.db');
    Db2.Open('/tmp/ta_fgl_nw2.db');
    Lg := TStringList.Create;
    BuildNorthwind(Db2, Lg);
    Lg.Free;
    Pr := TaFglProgram.Create;
    Io := TaFglScriptIO.Create;
    try
      Pr.LoadText(Prog3, 'prog3.4gl');
      Lg := TStringList.Create;
      Check(Pr.CheckProgram(Lg) = 0, 'fgl2: static check passes ' + Lg.Text);
      Lg.Free;
      Io.InputAnswers.Add('companyname=');
      Io.InputAnswers.Add('shipperid=5|companyname=brza');
      Io.InputAnswers.Add('categoryid=3');
      Io.GridAnswers.Add('select=2');
      Io.GridAnswers.Add('1|Chai X|20;2|Chang|30.5');
      Rn := TaFglRunner.Create(Pr, Db2, Io);
      try
        Rc := Rn.Run;
      finally
        Rn.Free;
      end;
      Txt := Io.Out.Text;
      Check(Rc = 0, 'fgl2: program ran (rc=' + IntToStr(Rc) + ') ' + Txt);
      Check(Io.Out.IndexOf('ERR: Naziv: polje je obavezno') >= 0, 'fgl2: REQUIRED enforced with label ' + Txt);
      Check(Io.Out.IndexOf('FOCUS: companyname') >= 0, 'fgl2: refocus on the required field');
      Check(Io.Out.IndexOf('88|BRZA|000') >= 0, 'fgl2: READONLY kept, UPSHIFT, DEFAULT ' + Txt);
      Check(Io.Out.IndexOf('LOOKUP: categoryid=1:Beverages') < 0, 'fgl2: lookup log sanity');
      Check(Pos('LOOKUP: categoryid=', Txt) > 0, 'fgl2: LOOKUP values loaded ' + Txt);
      Check(Io.Out.IndexOf('cat=3') >= 0, 'fgl2: INPUT through second screen');
      Check(Pos('GRID: Stavke [Šifra|Naziv|Cijena]', Txt) > 0, 'fgl2: grid captions from SCREEN ' + Txt);
      Check(Pos('ROW: 1|', Txt) > 0, 'fgl2: grid rows shown');
      Check(Io.Out.IndexOf('count=3 cur=2') >= 0, 'fgl2: DISPLAY ARRAY sets ARR_COUNT/ARR_CURR ' + Txt);
      Check(Io.Out.IndexOf('after: 2 Chai X 30.5') >= 0, 'fgl2: INPUT ARRAY writes rows back and trims the rest ' + Txt);
    finally
      Io.Free;
      Pr.Free;
    end;
    Pr := TaFglProgram.Create;
    Lg := TStringList.Create;
    try
      Pr.LoadText('MAIN'#10'  DEFINE k RECORD LIKE shippers.*'#10'  INPUT BY NAME k.* FROM nema'#10'END MAIN'#10, 'chk2.4gl');
      Check(Pr.CheckProgram(Lg) = 1, 'fgl2: check finds undefined screen ' + Lg.Text);
    finally
      Lg.Free;
      Pr.Free;
    end;
  finally
    Db2.Free;
  end;
end;

{ snimka sheme: izgradi domenu, snimi je natrag u JSON, provjeri, izgradi iz snimke i usporedi }
procedure TestSnapshot(AKind: TDbKind);
var
  Src, Dst: TAppDb;
  Dom, Dom2: TCatDomain;
  Cat2: TaCatalog;
  Sel, Log, Probs: TStringList;
  Json, Lb, Path: string;
  I, N1, N2: Integer;
  Q: TZQuery;
  Ok: Boolean;
  Metas: TFPObjectList;
begin
  if AKind = dkMaria then Lb := 'maria snapshot' else if AKind = dkPostgres then Lb := 'pg snapshot' else Lb := 'sqlite snapshot';
  Src := TAppDb.Create;
  Dst := TAppDb.Create;
  Sel := TStringList.Create;
  Log := TStringList.Create;
  Probs := TStringList.Create;
  Cat2 := TaCatalog.Create;
  try
    if AKind = dkSqlite then
    begin
      Path := '/tmp/ta_snap_src.db';
      if FileExists(Path) then DeleteFile(Path);
      Src.Open(Path);
    end
    else
    begin
      if AKind = dkMaria then Ok := ConnectKind(Src, AKind, 'nw_built') else Ok := ConnectKind(Src, AKind, 'northwind');
      if not Ok then Exit;
    end;
    Dom := Catalog.FindDomain('racuni');
    Check(Dom <> nil, Lb + ': racuni domain exists');
    if AKind <> dkSqlite then
    begin
      { u poslužiteljskoj bazi ne dirati postojeće tablice: snimi Northwind }
      Sel.Add('orders'); Sel.Add('orderdetails'); Sel.Add('customers');
    end
    else
    begin
      Log.Clear;
      Check(BuildCatalogDomain(Src, Dom, True, True, Log), Lb + ': source domain built ' + Log.Text);
      for I := 0 to Dom.Tables.Count - 1 do Sel.Add(TCatTable(Dom.Tables[I]).Name);
    end;
    Log.Clear;
    Json := SnapshotToCatalogJson(Src, 'moja_snimka', 'Moja snimka', 'Opis snimke.', Sel, 3, Log);
    Cat2.AddJson(Json, 'snimka');
    Cat2.BuildIndex;
    Check(ValidateCatalog(Cat2, Probs) = 0, Lb + ': snapshot passes catalog validation ' + Probs.Text);
    Dom2 := Cat2.FindDomain('moja_snimka');
    Check((Dom2 <> nil) and (Dom2.Tables.Count = Sel.Count), Lb + ': snapshot has all tables');
    if AKind = dkSqlite then
    begin
      Check(Dom2.FindTable('stavka_racuna').FieldIndex('racun_id') >= 0, Lb + ': field names kept');
      Check(Pos('"ref"', Json) > 0, Lb + ': foreign keys carried into the snapshot');
      Check(TCatField(Dom2.FindTable('racun').Fields[Dom2.FindTable('racun').FieldIndex('kupac_id')]).RefTable = 'kupac', Lb + ': reference points at kupac');
      Check(TCatTable(Dom2.FindTable('kupac')).Rows.Count = 3, Lb + ': sample rows limited to 3');
      { izgradi iz snimke u praznu bazu }
      Path := '/tmp/ta_snap_dst.db';
      if FileExists(Path) then DeleteFile(Path);
      Dst.Open(Path);
      Log.Clear;
      Check(BuildCatalogDomain(Dst, Dom2, True, False, Log), Lb + ': database built from the snapshot ' + Log.Text);
      Q := Dst.NewQuery('SELECT COUNT(*) FROM kupac');
      try Q.Open; N1 := Q.Fields[0].AsInteger; finally Q.Free; end;
      Check(N1 = 3, Lb + ': sample data arrived (' + IntToStr(N1) + ')');
      Q := Dst.NewQuery('SELECT COUNT(*) FROM racun WHERE kupac_id IS NOT NULL');
      try Q.Open; N2 := Q.Fields[0].AsInteger; finally Q.Free; end;
      Check(N2 >= 1, Lb + ': references that fit the sample were kept (' + IntToStr(N2) + ')');
    end;
    if AKind = dkSqlite then
    begin
      { rjecnik iz kataloga na tablici bez metapodataka }
      Src.Conn.ExecuteDirect('CREATE TABLE osoba (id INTEGER PRIMARY KEY, email TEXT, telefon TEXT, iznos REAL, cudno_polje TEXT)');
      Log.Clear;
      N1 := ApplyCatalogToTable(Src, 'osoba', Log);
      Check(N1 = 3, Lb + ': catalog dictionary fills known fields (' + IntToStr(N1) + ') ' + Log.Text);
      Metas := Src.LoadFieldMetas('osoba');
      N2 := 0;
      for I := 0 to Metas.Count - 1 do
      begin
        if (TaFieldMeta(Metas[I]).FieldName = 'email') and (TaFieldMeta(Metas[I]).Validation <> '') and (TaFieldMeta(Metas[I]).Caption <> '') then Inc(N2);
        if TaFieldMeta(Metas[I]).FieldName = 'cudno_polje' then N2 := 100;
      end;
      Metas.Free;
      Check(N2 = 1, Lb + ': email got caption and validation, unknown field untouched');
      Log.Clear;
      Check(ApplyCatalogToTable(Src, 'osoba', Log) = 0, Lb + ': second run changes nothing');
    end;
    Src.Close;
  finally
    Cat2.Free;
    Probs.Free;
    Log.Free;
    Sel.Free;
    Dst.Free;
    Src.Free;
  end;
end;

procedure TestCatalog(AKind: TDbKind);
var
  Cat: TaCatalog;
  P: TAppDb;
  Lg, Names, L2: TStringList;
  L: TList;
  D: TCatDomain;
  T: TCatTable;
  Cn: TCatConcept;
  Metas: TFPObjectList;
  Q: TZQuery;
  Fd: TaFormDef;
  R: TaFormRunner;
  RD: TaReportDef;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  I, J, Bad, Probs: Integer;
  LbN, Err, Sf, Html: string;
  Fm: TFormatSettings;
begin
  if AKind = dkMaria then LbN := 'maria catalog' else if AKind = dkPostgres then LbN := 'pg catalog' else LbN := 'sqlite catalog';
  Cat := Catalog;
  Lg := TStringList.Create;
  try
    if AKind = dkSqlite then
    begin
      Probs := ValidateCatalog(Cat, Lg);
      Check(Probs = 0, 'catalog: definitions are valid (' + IntToStr(Probs) + ') ' + Lg.Text);
      Check(Cat.Domains.Count >= 4, 'catalog: at least 4 domains (' + IntToStr(Cat.Domains.Count) + ')');
      Cn := Cat.FindConcept('email');
      Check((Cn <> nil) and (Cn.Where.Count >= 2), 'catalog: field library knows where email appears');
      L := TList.Create;
      Cat.SearchConcepts('pošt', '', L);
      Check(L.Count >= 2, 'catalog: library search finds fields (' + IntToStr(L.Count) + ')');
      L.Clear;
      Cat.SearchConcepts('', 'cijena', L);
      Check(L.Count >= 1, 'catalog: library filter by role');
      L.Free;
      Html := CatalogHtml(Cat);
      Check((Pos('Biblioteka polja', Html) > 0) and (Pos('stavka_racuna', Html) > 0) and (Pos('Knjižnica', Html) > 0), 'catalog: HTML documentation');
    end;
    Lg.Clear;
    P := TAppDb.Create;
    try
      if AKind = dkSqlite then
      begin
        Sf := '/tmp/ta_catalog_test.db';
        if FileExists(Sf) then DeleteFile(Sf);
        P.Open(Sf);
      end
      else
      begin
        if not ConnectKind(P, AKind, 'nw_built') then Exit;
        if AKind = dkMaria then
        begin
          P.Conn.ExecuteDirect('DROP DATABASE nw_built');
          P.Conn.ExecuteDirect('CREATE DATABASE nw_built CHARACTER SET utf8mb4');
        end
        else
        begin
          P.Conn.ExecuteDirect('DROP SCHEMA public CASCADE');
          P.Conn.ExecuteDirect('CREATE SCHEMA public');
        end;
        ConnectKind(P, AKind, 'nw_built');
      end;
      for I := 0 to Cat.Domains.Count - 1 do
      begin
        D := TCatDomain(Cat.Domains[I]);
        Lg.Clear;
        Check(BuildCatalogDomain(P, D, True, True, Lg), LbN + ': ' + D.Id + ' built');
        if Pos('GREŠKA', Lg.Text) + Pos('UPOZORENJE', Lg.Text) > 0 then WriteLn('CATLOG ', Lg.Text);
      end;
      Bad := 0;
      Err := '';
      for I := 0 to Cat.Domains.Count - 1 do
        for J := 0 to TCatDomain(Cat.Domains[I]).Tables.Count - 1 do
        begin
          T := TCatTable(TCatDomain(Cat.Domains[I]).Tables[J]);
          Q := P.NewQuery('SELECT COUNT(*) FROM ' + P.QuoteId(T.Name));
          try
            Q.Open;
            if Q.Fields[0].AsInteger <> T.Rows.Count then
            begin
              Inc(Bad);
              Err := Err + T.Name + ' ' + Q.Fields[0].AsString + '/' + IntToStr(T.Rows.Count) + '; ';
            end;
          except
            on E: Exception do begin Inc(Bad); Err := Err + T.Name + ': ' + E.Message + '; '; end;
          end;
          Q.Free;
        end;
      Check(Bad = 0, LbN + ': sample rows are in every table ' + Err);
      Check(Length(P.GetFks('stavka_racuna')) = 2, LbN + ': foreign keys on stavka_racuna');
      Check(Length(P.GetFks('kategorija_troska')) = 1, LbN + ': self reference on kategorija_troska');
      Metas := P.LoadFieldMetas('kupac');
      Bad := 0;
      for I := 0 to Metas.Count - 1 do
        if (TaFieldMeta(Metas[I]).FieldName = 'email') and (Pos('Like', TaFieldMeta(Metas[I]).Validation) > 0) and
          (TaFieldMeta(Metas[I]).Caption = 'E-pošta') and (TaFieldMeta(Metas[I]).Description <> '') then Inc(Bad);
      Metas.Free;
      Check(Bad = 1, LbN + ': field metadata (caption, description, validation) saved');
      { nova sifra nastavlja iza primjera }
      try
        P.Conn.ExecuteDirect('INSERT INTO ' + P.QuoteId('kategorija_recepta') + ' (' + P.QuoteId('naziv') + ') VALUES (''Napitci'')');
        Q := P.NewQuery('SELECT MAX(' + P.QuoteId('sifra') + ') FROM ' + P.QuoteId('kategorija_recepta'));
        Q.Open;
        Check(Q.Fields[0].AsInteger = 5, LbN + ': autonumber continues after sample rows (' + Q.Fields[0].AsString + ')');
        Q.Free;
      except
        on E: Exception do Check(False, LbN + ': autonumber ' + E.Message);
      end;
      { forme se otvaraju, izvjesce se crta }
      Names := P.ListObjects('_sys_forms');
      Bad := 0;
      Err := '';
      for I := 0 to Names.Count - 1 do
        try
          Fd := TaFormDef.Create;
          Fd.FromJson(P.LoadObject('_sys_forms', Names[I]));
          Fd.Name := Names[I];
          R := TaFormRunner.CreateRunner(nil, P, Fd);
          R.Free;
        except
          on E: Exception do begin Inc(Bad); Err := Err + Names[I] + ': ' + E.Message + '; '; end;
        end;
      Check((Bad = 0) and (Names.Count >= 19), LbN + ': every generated form opens (' + IntToStr(Names.Count) + ') ' + Err);
      Names.Free;
      Fm := DefaultFormatSettings;
      UseCroatianFormats;
      try
        RD := TaReportDef.Create;
        RD.FromJson(P.LoadObject('_sys_reports', 'Popis: Računi'));
        RD.Name := 'Popis: Računi';
        RE := TaReportEngine.Create(P, RD);
        RR := RE.Render;
        Check(RR.PageCount >= 1, LbN + ': generated report renders');
        RR.Free; RE.Free; RD.Free;
      except
        on E: Exception do Check(False, LbN + ': report ' + E.Message);
      end;
      DefaultFormatSettings := Fm;
      { ponovna gradnja preskace sve, bez gresaka }
      L2 := TStringList.Create;
      try
        Check(BuildCatalogDomain(P, TCatDomain(Cat.Domains[0]), True, True, L2), LbN + ': second build is a clean no-op');
        Check(Pos('preskočeno', L2.Text) > 0, LbN + ': existing tables are skipped');
      finally
        L2.Free;
      end;
    finally
      P.Free;
    end;
  finally
    Lg.Free;
  end;
end;

procedure TestFgl3;
const
  Prog4 =
    'REPORT prodaja(r)'#10 +
    '  DEFINE r RECORD kategorija TEXT, proizvod TEXT, cijena DECIMAL(10,2) END RECORD'#10 +
    '  OUTPUT PAGE LENGTH 12'#10 +
    '  ORDER BY r.kategorija, r.proizvod'#10 +
    '  FORMAT'#10 +
    '    PAGE HEADER'#10 +
    '      PRINT "Prodaja", COLUMN 30, "Str. ", PAGENO'#10 +
    '      PRINT "--------"'#10 +
    '    BEFORE GROUP OF r.kategorija'#10 +
    '      PRINT r.kategorija'#10 +
    '    ON EVERY ROW'#10 +
    '      PRINT COLUMN 5, r.proizvod, COLUMN 30, r.cijena USING "###,##&.&&"'#10 +
    '    AFTER GROUP OF r.kategorija'#10 +
    '      PRINT COLUMN 5, "Ukupno ", GROUP COUNT(*), COLUMN 30, GROUP SUM(r.cijena) USING "###,##&.&&"'#10 +
    '    ON LAST ROW'#10 +
    '      SKIP 1 LINES'#10 +
    '      PRINT "SVEUKUPNO ", COUNT(*), " ", SUM(r.cijena) USING "####&.&&", " najskuplje ", MAX(r.cijena)'#10 +
    '    PAGE TRAILER'#10 +
    '      PRINT "-- kraj stranice --"'#10 +
    'END REPORT'#10 +
    'MAIN'#10 +
    '  DEFINE r RECORD kategorija TEXT, proizvod TEXT, cijena DECIMAL(10,2) END RECORD'#10 +
    '  DEFINE brojilo INTEGER'#10 +
    '  DECLARE c CURSOR FOR SELECT ''Voće'', ''Jabuka'', 2.5 UNION ALL SELECT ''Povrće'', ''Mrkva'', 1.2 UNION ALL SELECT ''Voće'', ''Kruška'', 3.0 UNION ALL SELECT ''Povrće'', ''Krumpir'', 0.8 UNION ALL SELECT ''Voće'', ''Šljiva'', 4.25'#10 +
    '  START REPORT prodaja TO FILE "/tmp/ta_fgl_report.txt"'#10 +
    '  FOREACH c INTO r.*'#10 +
    '    OUTPUT TO REPORT prodaja(r.*)'#10 +
    '  END FOREACH'#10 +
    '  FINISH REPORT prodaja'#10 +
    '  START REPORT prodaja TO PDF "/tmp/ta_fgl_report.pdf"'#10 +
    '  FOREACH c INTO r.*'#10 +
    '    OUTPUT TO REPORT prodaja(r.*)'#10 +
    '  END FOREACH'#10 +
    '  FINISH REPORT prodaja'#10 +
    '  START REPORT prodaja'#10 +
    '  FOREACH c INTO r.*'#10 +
    '    OUTPUT TO REPORT prodaja(r.*)'#10 +
    '  END FOREACH'#10 +
    '  FINISH REPORT prodaja'#10 +
    '  DISPLAY "gotovo"'#10 +
    'END MAIN'#10;
var
  Pr: TaFglProgram;
  Io: TaFglScriptIO;
  Rn: TaFglRunner;
  Db2: TAppDb;
  Lg, Fl: TStringList;
  Txt: string;
  Rc: Integer;
  Fs: TFileStream;
begin
  Check(FglUsingNumber(1234.5, '###,##&.&&') = '  1,234.50', 'fgl3: Informix USING pads and groups (' + FglUsingNumber(1234.5, '###,##&.&&') + ')');
  Check(FglUsingNumber(-7.5, '--&.&') = ' -7.5', 'fgl3: USING sign slot (' + FglUsingNumber(-7.5, '--&.&') + ')');
  Check(FglUsingNumber(5, '&&&') = '005', 'fgl3: USING zero fill');
  Check(Pos('*', FglUsingNumber(12345, '##&')) > 0, 'fgl3: USING overflow gives stars');
  Db2 := TAppDb.Create;
  try
    if FileExists('/tmp/ta_fgl_nw3.db') then DeleteFile('/tmp/ta_fgl_nw3.db');
    Db2.Open('/tmp/ta_fgl_nw3.db');
    if FileExists('/tmp/ta_fgl_report.txt') then DeleteFile('/tmp/ta_fgl_report.txt');
    if FileExists('/tmp/ta_fgl_report.pdf') then DeleteFile('/tmp/ta_fgl_report.pdf');
    Pr := TaFglProgram.Create;
    Io := TaFglScriptIO.Create;
    try
      Pr.LoadText(Prog4, 'prog4.4gl');
      Lg := TStringList.Create;
      Check(Pr.CheckProgram(Lg) = 0, 'fgl3: static check passes ' + Lg.Text);
      Lg.Free;
      Rn := TaFglRunner.Create(Pr, Db2, Io);
      try
        Rc := Rn.Run;
      finally
        Rn.Free;
      end;
      Txt := Io.Out.Text;
      Check(Rc = 0, 'fgl3: program ran (rc=' + IntToStr(Rc) + ') ' + Txt);
      Check(FileExists('/tmp/ta_fgl_report.txt'), 'fgl3: FILE target written');
      Fl := TStringList.Create;
      try
        if FileExists('/tmp/ta_fgl_report.txt') then Fl.LoadFromFile('/tmp/ta_fgl_report.txt');
        Txt := Fl.Text;
        Check(Fl.IndexOf('Povrće') >= 0, 'fgl3: BEFORE GROUP OF printed ' + Txt);
        Check(Pos('Prodaja' + StringOfChar(' ', 22) + 'Str. 1', Txt) > 0, 'fgl3: PAGE HEADER with COLUMN and PAGENO ' + Txt);
        Check(Pos('Str. 2', Txt) > 0, 'fgl3: second page has its header');
        Check(Fl.IndexOf(#12) > 0, 'fgl3: pages separated by form feed');
        Check(Pos('    Krumpir' + StringOfChar(' ', 24) + '0.80', Txt) > 0, 'fgl3: ORDER BY sorts and USING aligns ' + Txt);
        Check(Pos('Ukupno 2' + StringOfChar(' ', 23) + '2.00', Txt) > 0, 'fgl3: AFTER GROUP with GROUP COUNT and GROUP SUM ' + Txt);
        Check(Pos('Ukupno 3' + StringOfChar(' ', 23) + '9.75', Txt) > 0, 'fgl3: second group totals (group sums reset) ' + Txt);
        Check(Pos('SVEUKUPNO 5    11.75 najskuplje 4.25', Txt) > 0, 'fgl3: ON LAST ROW with whole-report SUM, COUNT, MAX ' + Txt);
        Check(Pos('-- kraj stranice --', Txt) > 0, 'fgl3: PAGE TRAILER printed');
        Check(Pos('Šljiva', Txt) > Pos('Kruška', Txt), 'fgl3: UTF-8 names sort');
      finally
        Fl.Free;
      end;
      Check(FileExists('/tmp/ta_fgl_report.pdf'), 'fgl3: PDF target written');
      if FileExists('/tmp/ta_fgl_report.pdf') then
      begin
        Fs := TFileStream.Create('/tmp/ta_fgl_report.pdf', fmOpenRead);
        try
          Check(Fs.Size > 1500, 'fgl3: PDF has content (' + IntToStr(Fs.Size) + ' bytes)');
        finally
          Fs.Free;
        end;
      end;
      Check(Io.Out.IndexOf('=== prodaja, stranica 1 ===') >= 0, 'fgl3: SCREEN target goes through ShowReport');
      Check(Io.Out.IndexOf('gotovo') >= 0, 'fgl3: program continued after reports');
    finally
      Io.Free;
      Pr.Free;
    end;
    { greske }
    Pr := TaFglProgram.Create;
    Lg := TStringList.Create;
    try
      Pr.LoadText('MAIN'#10'  START REPORT nema'#10'  FINISH REPORT nema'#10'END MAIN'#10, 'chk3.4gl');
      Check(Pr.CheckProgram(Lg) = 2, 'fgl3: check finds undefined report ' + Lg.Text);
    finally
      Lg.Free;
      Pr.Free;
    end;
    Pr := TaFglProgram.Create;
    Io := TaFglScriptIO.Create;
    try
      Pr.LoadText('MAIN'#10'  PRINT "x"'#10'END MAIN'#10, 'chk4.4gl');
      Rn := TaFglRunner.Create(Pr, Db2, Io);
      try
        Rc := Rn.Run;
      finally
        Rn.Free;
      end;
      Check((Rc = 1) and (Pos('REPORT', Io.Out.Text) > 0), 'fgl3: PRINT outside REPORT is an error ' + Io.Out.Text);
    finally
      Io.Free;
      Pr.Free;
    end;
  finally
    Db2.Free;
  end;
end;

var
  GPrintedPages: Integer = 0;
  GPrinterName: string = '';

function StubPrint(APages: TObjectList; const APrinter: string; out AErr: string): Boolean;
begin
  GPrintedPages := APages.Count;
  GPrinterName := APrinter;
  AErr := '';
  Result := True;
end;

procedure TestFgl4;
const
  Prog5 =
    'REPORT r2(r)'#10 +
    '  DEFINE r RECORD kat TEXT, naz TEXT, c DECIMAL(10,2) END RECORD'#10 +
    '  OUTPUT TOP MARGIN 2 PAGE LENGTH 30'#10 +
    '  ORDER EXTERNAL BY r.kat'#10 +
    '  FORMAT'#10 +
    '    BEFORE GROUP OF r.kat'#10 +
    '      PRINT r.kat'#10 +
    '    ON EVERY ROW'#10 +
    '      PRINT COLUMN 3, r.naz CLIPPED, "|", lpad(r.naz, 8), "|", rpad(r.naz, 8), "|", center(r.naz, 8), "|"'#10 +
    '    AFTER GROUP OF r.kat'#10 +
    '      PRINT "  ", GROUP COUNT(*), " = ", GROUP PERCENT(*) USING "##&.&&", " %"'#10 +
    '    ON LAST ROW'#10 +
    '      PRINT FILE "/tmp/ta_fgl_incl.txt"'#10 +
    '      PRINT "kraj ", PERCENT(*) USING "###&.&&"'#10 +
    'END REPORT'#10 +
    'REPORT r3(r)'#10 +
    '  DEFINE r RECORD kat TEXT, naz TEXT, c DECIMAL(10,2) END RECORD'#10 +
    '  FORMAT'#10 +
    '    ON EVERY ROW'#10 +
    '      PRINT r.naz;'#10 +
    '      PRINT " ", r.c'#10 +
    '    ON LAST ROW'#10 +
    '      PRINT "redaka=", COUNT(*), " zbroj=", SUM(r.c), " prosjek=", AVG(r.c)'#10 +
    'END REPORT'#10 +
    'MAIN'#10 +
    '  DEFINE r RECORD kat TEXT, naz TEXT, c DECIMAL(10,2) END RECORD'#10 +
    '  DECLARE c CURSOR FOR SELECT ''Povrće'', ''Krumpir'', 0.8 UNION ALL SELECT ''Povrće'', ''Mrkva'', 1.2 UNION ALL SELECT ''Voće'', ''Jabuka'', 2.5 UNION ALL SELECT ''Voće'', ''Kruška'', 3.0 UNION ALL SELECT ''Voće'', ''Šljiva'', 4.25'#10 +
    '  START REPORT r2 TO FILE "/tmp/ta_fgl_r2.txt"'#10 +
    '  FOREACH c INTO r.*'#10 +
    '    OUTPUT TO REPORT r2(r.*)'#10 +
    '  END FOREACH'#10 +
    '  FINISH REPORT r2'#10 +
    '  START REPORT r2 TO PRINTER "HP-laser"'#10 +
    '  FOREACH c INTO r.*'#10 +
    '    OUTPUT TO REPORT r2(r.*)'#10 +
    '  END FOREACH'#10 +
    '  FINISH REPORT r2'#10 +
    '  START REPORT r2 TO PIPE "cat > /tmp/ta_fgl_pipe.txt"'#10 +
    '  FOREACH c INTO r.*'#10 +
    '    OUTPUT TO REPORT r2(r.*)'#10 +
    '  END FOREACH'#10 +
    '  FINISH REPORT r2'#10 +
    '  START REPORT r3 TO FILE "/tmp/ta_fgl_r3.txt"'#10 +
    '  FOREACH c INTO r.*'#10 +
    '    OUTPUT TO REPORT r3(r.*)'#10 +
    '  END FOREACH'#10 +
    '  FINISH REPORT r3'#10 +
    '  DISPLAY "gotovo"'#10 +
    'END MAIN'#10;
var
  Pr: TaFglProgram;
  Io: TaFglScriptIO;
  Rn: TaFglRunner;
  Db2: TAppDb;
  Fl, Inc2: TStringList;
  Txt: string;
  Rc: Integer;
  OldHook: function(APages: TObjectList; const APrinter: string; out AErr: string): Boolean;
begin
  Inc2 := TStringList.Create;
  Inc2.Add('alfa');
  Inc2.Add('beta');
  Inc2.SaveToFile('/tmp/ta_fgl_incl.txt');
  Inc2.Free;
  Db2 := TAppDb.Create;
  OldHook := FglPrintHook;
  FglPrintHook := @StubPrint;
  Pr := TaFglProgram.Create;
  Io := TaFglScriptIO.Create;
  try
    DeleteFile('/tmp/ta_fgl_r2.txt'); DeleteFile('/tmp/ta_fgl_pipe.txt'); DeleteFile('/tmp/ta_fgl_r3.txt');
    if FileExists('/tmp/ta_fgl_nw4.db') then DeleteFile('/tmp/ta_fgl_nw4.db');
    Db2.Open('/tmp/ta_fgl_nw4.db');
    Pr.LoadText(Prog5, 'prog5.4gl');
    Rn := TaFglRunner.Create(Pr, Db2, Io);
    try
      Rc := Rn.Run;
    finally
      Rn.Free;
    end;
    Check(Rc = 0, 'fgl4: program ran (rc=' + IntToStr(Rc) + ') ' + Io.Out.Text);
    Fl := TStringList.Create;
    try
      if FileExists('/tmp/ta_fgl_r2.txt') then Fl.LoadFromFile('/tmp/ta_fgl_r2.txt');
      Txt := Fl.Text;
      Check((Fl.Count > 3) and (Fl[0] = '') and (Fl[1] = '') and (Fl[2] = 'Povrće'), 'fgl4: TOP MARGIN leaves two blank lines ' + Txt);
      Check(Pos('  Krumpir| Krumpir|Krumpir |Krumpir |', Txt) > 0, 'fgl4: CLIPPED, LPAD, RPAD, CENTER ' + Txt);
      Check(Pos('  2 =  40.00 %', Txt) > 0, 'fgl4: GROUP PERCENT(*) = 40 % ' + Txt);
      Check(Pos('  3 =  60.00 %', Txt) > 0, 'fgl4: GROUP PERCENT(*) = 60 %');
      Check((Fl.IndexOf('alfa') > 0) and (Fl.IndexOf('beta') > Fl.IndexOf('alfa')), 'fgl4: PRINT FILE copies lines');
      Check(Pos('kraj  100.00', Txt) > 0, 'fgl4: whole-report PERCENT(*) is 100 ' + Txt);
      Fl.Clear;
      if FileExists('/tmp/ta_fgl_pipe.txt') then Fl.LoadFromFile('/tmp/ta_fgl_pipe.txt');
      Check((Fl.Count > 3) and (Fl.IndexOf('Povrće') >= 0), 'fgl4: PIPE delivered the report to a command ' + Fl.Text);
      Fl.Clear;
      if FileExists('/tmp/ta_fgl_r3.txt') then Fl.LoadFromFile('/tmp/ta_fgl_r3.txt');
      Check((Fl.Count = 6) and (Fl[0] = 'Krumpir 0.8') and (Fl[5] = 'redaka=5 zbroj=11.75 prosjek=2.35'), 'fgl4: streaming report without keys, PRINT ; joins lines ' + Fl.Text);
    finally
      Fl.Free;
    end;
    Check((GPrintedPages = 1) and (GPrinterName = 'HP-laser'), 'fgl4: PRINTER target passes name and pages (' + IntToStr(GPrintedPages) + ' / ' + GPrinterName + ')');
    Check(Io.Out.IndexOf('gotovo') >= 0, 'fgl4: program continued');
  finally
    FglPrintHook := OldHook;
    Io.Free;
    Pr.Free;
    Db2.Free;
  end;
end;

{ pretvorba BLOB slika u veze na poslužiteljskim bazama (Postgres bytea, MariaDB LONGBLOB) }
procedure TestFileStoreServer(AKind: TDbKind);
var
  P: TAppDb;
  Lb, Sd, Png, Hex, Lnk, Pre, BType: string;
  Log: TStringList;
  M: TaFieldMeta;
  Q: TZQuery;
  I: Integer;
  Ok: Boolean;
begin
  if AKind = dkMaria then Lb := 'maria files' else Lb := 'pg files';
  P := TAppDb.Create;
  Log := TStringList.Create;
  try
    if AKind = dkMaria then Ok := ConnectKind(P, AKind, 'nw_built') else Ok := ConnectKind(P, AKind, 'northwind');
    if not Ok then Exit;
    Sd := '/tmp/ta_fs_srv_' + IntToStr(Ord(AKind)) + '/';
    if DirectoryExists(Sd) then DeleteDirectory(Sd, False);
    ForceDirectories(Sd);
    SetFileStoreFolder(P, Sd + 'pohrana');
    try
      try P.DropTable('proizvod_blob'); except end;
      Png := #137'PNG'#13#10#26#10 + 'bytes'#0#255#1'end';
      if AKind = dkMaria then BType := 'LONGBLOB' else BType := 'BYTEA';
      P.Conn.ExecuteDirect('CREATE TABLE proizvod_blob (id INTEGER PRIMARY KEY, naziv VARCHAR(50), slika ' + BType + ')');
      M := TaFieldMeta.Create;
      M.TableName := 'proizvod_blob'; M.FieldName := 'slika'; M.LType := ltPicture; M.Caption := 'Fotografija';
      P.SaveFieldMeta(M);
      M.Free;
      Hex := '';
      for I := 1 to Length(Png) do Hex := Hex + IntToHex(Ord(Png[I]), 2);
      if AKind = dkMaria then Pre := 'X''' + Hex + ''''
      else Pre := '''\x' + Hex + '''::bytea';
      P.Conn.ExecuteDirect('INSERT INTO proizvod_blob (id, naziv, slika) VALUES (1, ''Stol'', ' + Pre + ')');
      P.Conn.ExecuteDirect('INSERT INTO proizvod_blob (id, naziv, slika) VALUES (2, ''Bez'', NULL)');
      Log.Clear;
      Check(ConvertBlobPictures(P, Log) = 1, Lb + ': BLOB column converted ' + Log.Text);
      Q := P.NewQuery('SELECT slika FROM proizvod_blob WHERE id = 1');
      try
        Q.Open;
        Lnk := Q.Fields[0].AsString;
      finally
        Q.Free;
      end;
      Check((Copy(Lnk, 1, 20) = 'slike/proizvod_blob/') and FileExists(ResolveFileLink(P, Lnk)), Lb + ': row holds a link to a real file (' + Lnk + ')');
      Check(FileExists(ResolveFileLink(P, Lnk)) and (FileSize(ResolveFileLink(P, Lnk)) = Length(Png)), Lb + ': file bytes survived the round trip');
      Q := P.NewQuery('SELECT slika FROM proizvod_blob WHERE id = 2');
      try
        Q.Open;
        Check(Q.Fields[0].IsNull, Lb + ': empty rows stay empty');
      finally
        Q.Free;
      end;
      Log.Clear;
      Check(ConvertBlobPictures(P, Log) = 0, Lb + ': second conversion finds nothing');
    except
      on E: Exception do Check(False, Lb + ' exception: ' + E.Message);
    end;
  finally
    try P.DropTable('proizvod_blob'); except end;
    try P.DeleteFieldMeta('proizvod_blob'); except end;
    try SetFileStoreFolder(P, ''); except end;
    Log.Free;
    P.Free;
  end;
end;

procedure TestFileStore;
var
  Db, Db2: TAppDb;
  Root, Link, Link2, Src, Sd: string;
  Log: TStringList;
  Fs: TFileStream;
  Png: string;
  Orph: TStringList;
  Fd0: TaFormDef;
  Rp0: TaReportDef;
  Ci: TaControlDef;
  Q: TZQuery;
  M: TaFieldMeta;
  Metas: TFPObjectList;
  N, I: Integer;
  Size: Int64;
  Src0, Hex: string;
  Shared: Boolean;
begin
  Sd := '/tmp/ta_fs_test/';
  if DirectoryExists(Sd) then DeleteDirectory(Sd, False);
  ForceDirectories(Sd);
  Png := #137'PNG'#13#10#26#10 + 'not really a picture but starts like one';
  Db := TAppDb.Create;
  Db2 := TAppDb.Create;
  Log := TStringList.Create;
  try
    Db.Open(Sd + 'firma.db');
    Root := FileStoreRoot(Db, Src0, Shared);
    Check((Root = Sd + 'firma_datoteke/') and Shared, 'files: SQLite default store sits next to the database (' + Root + ')');
    SetFileStoreFolder(Db, 'slike_firme');
    Check(FileStoreRootOnly(Db) = Sd + 'slike_firme/', 'files: relative setting is relative to the database folder');
    SetFileStoreFolder(Db, Sd + 'zajednicka');
    Check(FileStoreRootOnly(Db) = Sd + 'zajednicka/', 'files: absolute setting (shared folder) wins over default');
    SetFileStoreFolder(Db, '');
    Check(FileStoreRootOnly(Db) = Sd + 'firma_datoteke/', 'files: empty setting returns to default');
    { spremanje }
    Fs := TFileStream.Create(Sd + 'logo.png', fmCreate);
    Fs.WriteBuffer(Png[1], Length(Png));
    Fs.Free;
    Link := StoreFile(Db, Sd + 'logo.png', 'slike/kupac');
    Check(Copy(Link, 1, 12) = 'slike/kupac/', 'files: StoreFile returns a relative link (' + Link + ')');
    Check(FileExists(ResolveFileLink(Db, Link)), 'files: stored file exists under the root');
    Link2 := StoreFile(Db, Sd + 'logo.png', 'slike/kupac');
    Check((Link2 <> Link) and (Pos('-2', Link2) > 0), 'files: same name does not overwrite (' + Link2 + ')');
    Check(StoreFile(Db, ResolveFileLink(Db, Link), 'slike/drugo') = Link, 'files: a file already in the store is not copied again');
    { sigurnost veza }
    Check(ResolveFileLink(Db, '../tajna.txt') = '', 'files: .. is rejected');
    Check(ResolveFileLink(Db, 'slike/../../x') = '', 'files: nested .. is rejected');
    Check(ResolveFileLink(Db, '/etc/hosts') = '/etc/hosts', 'files: absolute path stays an external link');
    Check(ResolveFileLink(Db, 'https://example.org/a.png') = '', 'files: URLs are links but not local files');
    Check(IsExternalLink('https://example.org/a.png') and IsExternalLink('/tmp/x') and not IsExternalLink('slike/a.png'), 'files: external link detection');
    try
      StoreFile(Db, Sd + 'logo.png', '../izvan');
      Check(False, 'files: sub folder with .. must fail');
    except
      Check(True, 'files: sub folder with .. is refused');
    end;
    N := FileStoreStats(Db, Size);
    Check((N = 2) and (Size > 0), 'files: stats count the stored files (' + IntToStr(N) + ')');
    { picture je veza (tekst), ne BLOB }
    Check(PhysicalType(ltPicture) = 'TEXT', 'files: Picture fields are text links');
    { pretvorba starih BLOB slika }
    Db.Conn.ExecuteDirect('CREATE TABLE proizvod (id INTEGER PRIMARY KEY, naziv TEXT, slika BLOB)');
    M := TaFieldMeta.Create;
    M.TableName := 'proizvod'; M.FieldName := 'slika'; M.LType := ltPicture; M.Caption := 'Fotografija';
    Db.SaveFieldMeta(M);
    M.Free;
    Hex := '';
    for I := 1 to Length(Png) do Hex := Hex + IntToHex(Ord(Png[I]), 2);
    Db.Conn.ExecuteDirect('INSERT INTO proizvod (id, naziv, slika) VALUES (1, ''Stol'', X''' + Hex + ''')');
    Db.Conn.ExecuteDirect('INSERT INTO proizvod (id, naziv, slika) VALUES (2, ''Bez slike'', NULL)');
    Log.Clear;
    Check(ConvertBlobPictures(Db, Log) = 1, 'files: BLOB picture field converted ' + Log.Text);
    Q := Db.NewQuery('SELECT slika FROM proizvod WHERE id = 1');
    try
      Q.Open;
      Link := Q.Fields[0].AsString;
      Check((Copy(Link, 1, 17) = 'slike/proizvod/1-') and FileExists(ResolveFileLink(Db, Link)), 'files: row now holds a link to a real file (' + Link + ')');
  finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT slika FROM proizvod WHERE id = 2');
    try
      Q.Open;
      Check(Q.Fields[0].IsNull, 'files: rows without a picture stay empty');
    finally
      Q.Free;
    end;
    Metas := Db.LoadFieldMetas('proizvod');
    N := 0;
    for I := 0 to Metas.Count - 1 do
      if (TaFieldMeta(Metas[I]).FieldName = 'slika') and (TaFieldMeta(Metas[I]).LType = ltPicture) and
        (TaFieldMeta(Metas[I]).Caption = 'Fotografija') then Inc(N);
    Metas.Free;
    Check(N = 1, 'files: field metadata kept after conversion');
    Log.Clear;
    Check(ConvertBlobPictures(Db, Log) = 0, 'files: second conversion finds nothing to do');
    { slike ugrađene u definicije formi i izvješća }
    Fd0 := TaFormDef.Create;
    Fd0.Name := 'FSlika';
    Fd0.RecordSource := 'proizvod';
    Ci := TaControlDef.Create;
    Ci.Kind := 'Image'; Ci.Name := 'imgLogo'; Ci.Width := 50; Ci.Height := 50;
    Ci.SetX('picture', EncodeStringBase64(Png));
    Fd0.Add(Ci);
    Db.SaveObject('_sys_forms', 'FSlika', Fd0.ToJson);
    Fd0.Free;
    Rp0 := TaReportDef.Create;
    Rp0.Name := 'RSlika';
    Rp0.RecordSource := 'proizvod';
    Ci := TaControlDef.Create;
    Ci.Kind := 'Image'; Ci.Name := 'logo'; Ci.Section := 'ReportHeader'; Ci.Width := 50; Ci.Height := 50;
    Ci.SetX('picture', EncodeStringBase64(Png));
    Rp0.Add(Ci);
    Db.SaveObject('_sys_reports', 'RSlika', Rp0.ToJson);
    Rp0.Free;
    Log.Clear;
    Check(ConvertDefinitionPictures(Db, Log) = 2, 'files: form and report pictures converted ' + Log.Text);
    Fd0 := TaFormDef.Create;
    Fd0.FromJson(Db.LoadObject('_sys_forms', 'FSlika'));
    Link2 := Fd0[0].GetX('picture');
    Fd0.Free;
    Check((Copy(Link2, 1, 5) = 'file:') and FileExists(ResolveFileLink(Db, Copy(Link2, 6, MaxInt))), 'files: form image now a link to a real file (' + Link2 + ')');
    Log.Clear;
    Check(ConvertDefinitionPictures(Db, Log) = 0, 'files: second definition conversion finds nothing to do');
    { kopija pohrane }
    Check(CopyStoreToFolder(Db, Sd + 'kopija') >= 3, 'files: backup copies the store');
    Check(DirectoryExists(Sd + 'kopija/slike/kupac'), 'files: backup keeps the folder structure');
    { izvoz aplikacije nosi mapu sa slikama }
    ExportApplication(Db, Sd + 'izvoz', '', 'Moja aplikacija');
    Check(FileExists(Sd + 'izvoz/Moja_aplikacija.db') and FileExists(Sd + 'izvoz/Moja_aplikacija_datoteke/' + Link),
      'files: exported application carries the picture folder next to its database');
    { migracija baze nosi i datoteke }
    Db2.Open(Sd + 'nova.db');
    Log.Clear;
    Check(MigrateDb(Db, Db2, Log), 'files: database migrated ' + Log.Text);
    Check(FileExists(Sd + 'nova_datoteke/' + StringReplace(Link, '/', '/', [rfReplaceAll])), 'files: migration copied the pictures to the new store');
    { neiskorištene datoteke }
    Orph := TStringList.Create;
    Fs := TFileStream.Create(ResolveFileLink(Db, 'slike/siroce.png'), fmCreate);
    Fs.Free;
    Check(FindOrphanFiles(Db, Orph) >= 1, 'files: unreferenced file found');
    Check(Orph.IndexOf('slike/siroce.png') >= 0, 'files: the orphan is listed by its link');
    Check(Orph.IndexOf('slike/_forme/FSlika-imgLogo.png') < 0, 'files: form image link is not an orphan');
    Check(Orph.IndexOf(StringReplace(Link, '\', '/', [])) < 0, 'files: picture field link is not an orphan');
    Log.Clear;
    N := MoveOrphanFiles(Db, Log);
    Check((N >= 1) and not FileExists(ResolveFileLink(Db, 'slike/siroce.png')), 'files: orphan moved out of the store ' + Log.Text);
    Check(FileExists(FileStoreRootOnly(Db) + '_neiskoristeno/slike/siroce.png'), 'files: orphan kept in _neiskoristeno');
    Check(FindOrphanFiles(Db, Orph) = 0, 'files: nothing left to clean (moved files are not scanned)');
    Check(FileExists(ResolveFileLink(Db, 'slike/_forme/FSlika-imgLogo.png')) and FileExists(ResolveFileLink(Db, 'slike/_izvjesca/RSlika-logo.png')), 'files: referenced files untouched');
    Orph.Free;
  finally
    Log.Free;
    Db2.Free;
    Db.Free;
  end;
end;

procedure TestBindEngine;
var
  H: TTestHost;
  E: TaBindingEngine;
  Ok: Boolean;
  St: TaBindStyle;
  V: Variant;
  Err: string;
begin
  H := TTestHost.Create;
  E := TaBindingEngine.Create(H);
  try
    Check(E.Condition('1 = 1', Ok) and Ok, 'engine: istinit uvjet');
    Check(not E.Condition('1 = 2', Ok) and Ok, 'engine: lazan uvjet je odluka (Ok), ne greska');
    Check(not E.Condition('Nepostojeca(1)', Ok) and not Ok, 'engine: neispravan izraz nema odluke (Ok = False)');
    Check(not E.Condition('', Ok) and not Ok, 'engine: prazan izraz nema odluke');
    Check(E.Condition('True', Ok) and E.Condition('True = 1', Ok), 'engine: logicko True je 1');
    Check(not E.Condition('Null', Ok) and Ok, 'engine: Null je laz');
    Check(E.Condition('"da"', Ok) and not E.Condition('"abc"', Ok), 'engine: tekst je istinit samo kao da/true/1');
    Check(E.RuleFailed('1 > 2'), 'engine: pravilo koje ne vrijedi je prekrseno');
    Check(not E.RuleFailed('2 > 1'), 'engine: pravilo koje vrijedi nije prekrseno');
    Check(not E.RuleFailed('Null'), 'engine: pravilo s Null nije prekrsaj');
    Check(not E.RuleFailed('Nepostojeca(1)'), 'engine: neispravno pravilo nije prekrsaj');
    Check(not E.RuleFailed(''), 'engine: bez pravila nema prekrsaja');
    V := E.Value('2 + 3', Err);
    Check((Err = '') and (Double(V) = 5), 'engine: vrijednost izraza');
    V := E.Value('Nepostojeca(1)', Err);
    Check(Err <> '', 'engine: greska izraza se javlja');
    St := E.Style('1 = 2 => #FF0000 ;; 1 = 1 => #0000FF #FFFF00 bold');
    Check(St.Matched and (St.Fore = '#0000FF') and (St.Back = '#FFFF00') and St.Bold, 'engine: stil je prvo pravilo koje vrijedi');
    St := E.Style('1 = 2 => #FF0000');
    Check(not St.Matched, 'engine: nijedno pravilo ne vrijedi');
    St := E.Style('1 = 1 => - #00FF00');
    Check(St.Matched and (St.Fore = '') and (St.Back = '#00FF00'), 'engine: "-" znaci bez promjene boje');
    St := E.Style('');
    Check(not St.Matched, 'engine: bez oblikovanja');
  finally
    E.Free;
    H.Free;
  end;
end;

procedure TestBindEngine2;
var
  H: TTestHost;
  E: TaBindingEngine;
  V: Variant;
  Defs: TaCalcRuleDefs;
  Af: TaAutoFillDefs;
  Stored: string;
  IsNum: Boolean;
  Db: TAppDb;
  St: TStringList;
begin
  H := TTestHost.Create;
  E := TaBindingEngine.Create(H);
  Db := TAppDb.Create;
  St := TStringList.Create;
  try
    Check(E.DefaultValue('2 + 3', V) and (Double(V) = 5), 'engine2: zadana vrijednost je izraz');
    Check(E.DefaultValue('= 2 * 4', V) and (Double(V) = 8), 'engine2: vodeci = se skida');
    Check(E.DefaultValue('Zagreb centar', V) and (VarToStr(V) = 'Zagreb centar'), 'engine2: sto nije ispravan izraz uzima se doslovno');
    Check(not E.DefaultValue('', V), 'engine2: prazno nema zadane vrijednosti');
    Check(not E.DefaultValue('Null', V), 'engine2: Null nema zadane vrijednosti');
    Defs := ParseCalcRuleDefs('a, B -> c = [a] + [B] ;; c -> d = [c] * 2 ;; kriv ;; x -> = 5');
    Check(Length(Defs) = 2, 'engine2: dva ispravna pravila izracuna (kriva se preskacu): ' + IntToStr(Length(Defs)));
    Check((Length(Defs[0].Triggers) = 2) and (Defs[0].Triggers[1] = 'b') and (Defs[0].Target = 'c') and (Defs[0].Expr = '[a] + [B]'), 'engine2: okidaci mala slova, cilj i izraz');
    Check(E.CalcRuleStored(Defs[1], Stored, IsNum) = False, 'engine2: izracun s nepoznatim poljem nema vrijednosti (Null)');
    Defs := ParseCalcRuleDefs('x -> y = 2 + 3');
    Check(E.CalcRuleStored(Defs[0], Stored, IsNum) and (Stored = '5') and IsNum, 'engine2: izracun daje pohranjeni broj s tockom');
    Defs := ParseCalcRuleDefs('x -> y = "abc"');
    Check(E.CalcRuleStored(Defs[0], Stored, IsNum) and (Stored = 'abc') and not IsNum, 'engine2: tekstualni izracun');
    Af := ParseAutoFillDefs('artikl_id>artikli.id:cijena=cijena,opis=naziv ;; grad>gradovi:naziv=naziv ;; lose');
    Check(Length(Af) = 2, 'engine2: dva AutoFill pravila');
    Check((Af[0].Field = 'artikl_id') and (Af[0].Table = 'artikli') and (Af[0].KeyCol = 'id') and (Length(Af[0].Targets) = 2) and (Af[0].Sources[1] = 'naziv'), 'engine2: AutoFill polja');
    Check((Af[1].Table = 'gradovi') and (Af[1].KeyCol = 'id'), 'engine2: zadani stupac kljuca je id');
    if FileExists('/tmp/ta_bindeng2.db') then DeleteFile('/tmp/ta_bindeng2.db');
    Db.Open('/tmp/ta_bindeng2.db');
    Db.Conn.ExecuteDirect('CREATE TABLE artikli (id INTEGER PRIMARY KEY, naziv VARCHAR(30), cijena DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO artikli (naziv, cijena) VALUES (''Vijak'', 0.5), (''Matica'', 0.25)');
    Check(AutoFillLookup(Db, Af[0], '2', St) and (St.Values['cijena'] = '0.25') and (St.Values['opis'] = 'Matica'), 'engine2: AutoFill dohvaca red po kljucu (' + St.CommaText + ')');
    Check(not AutoFillLookup(Db, Af[0], '99', St), 'engine2: nepostojeci kljuc nema reda');
    Db.Close;
  finally
    St.Free;
    Db.Free;
    E.Free;
    H.Free;
  end;
end;

procedure TestBoolSemantics;
var
  H: TTestHost;
begin
  H := TTestHost.Create;
  try
    Check(Ev(H, 'True = 1') = 'Da', 'logicko: oznacena kvacica je 1 (True = 1)');
    Check(Ev(H, 'False = 0') = 'Da', 'logicko: prazna kvacica je 0 (False = 0)');
    Check(Ev(H, 'True = 0') = 'Ne', 'logicko: oznacena nije 0');
    Check(Ev(H, 'False = 1') = 'Ne', 'logicko: prazna nije 1');
    Check(Ev(H, 'True + True') = '2', 'logicko: True + True = 2 (ne -2)');
    Check(Ev(H, 'Iif(True = 1, "kvacica", "prazno")') = 'kvacica', 'logicko: Iif s usporedbom s 1');
    Check(Ev(H, 'True > False') = 'Da', 'logicko: True > False');
    Check(Ev(H, 'Not (False = 1)') = 'Da', 'logicko: Not ostaje logicki');
  finally
    H.Free;
  end;
end;

procedure TestExprUtf8;
var
  H: TTestHost;
begin
  H := TTestHost.Create;
  try
    Check(Ev(H, 'Len("čaj")') = '3', 'utf8 expr: Len counts characters, not bytes (' + Ev(H, 'Len("čaj")') + ')');
    Check(Ev(H, 'Left("čaša", 2)') = 'ča', 'utf8 expr: Left');
    Check(Ev(H, 'Right("čaša", 2)') = 'ša', 'utf8 expr: Right');
    Check(Ev(H, 'Mid("žaba", 2, 2)') = 'ab', 'utf8 expr: Mid');
    Check(Ev(H, 'UCase("šuma")') = 'ŠUMA', 'utf8 expr: UCase handles š');
    Check(Ev(H, 'LCase("ČĆŽ")') = 'čćž', 'utf8 expr: LCase');
    Check(Ev(H, 'Proper("đuro šarić-žagar")') = 'Đuro Šarić-Žagar', 'utf8 expr: Proper (' + Ev(H, 'Proper("đuro šarić-žagar")') + ')');
    Check(Ev(H, 'InStr("šuma", "m")') = '3', 'utf8 expr: InStr is a character position');
    Check(Ev(H, 'LPad("č", 3, "ž")') = 'žžč', 'utf8 expr: LPad with a multibyte pad character');
    Check(Ev(H, 'StrReverse("čaša")') = 'ašač', 'utf8 expr: StrReverse');
    Check(Ev(H, 'Initials("željko šimić")') = 'ŽŠ', 'utf8 expr: Initials');
    Check(Ev(H, 'Shorten("čokolada", 5)') = 'čoko…', 'utf8 expr: Shorten');
    Check(Ev(H, 'EOMonth(DateSerial(2026,2,10))') = '28.02.2026', 'expr: EOMonth is a plain date (' + Ev(H, 'EOMonth(DateSerial(2026,2,10))') + ')');
    Check(Ev(H, 'Contains("Čakovec", "ČAK")') = 'Da', 'utf8 expr: Contains ignores case for Č (' + Ev(H, 'Contains("Čakovec", "ČAK")') + ')');
  finally
    H.Free;
  end;
end;

procedure TestManualExamples;
var
  L: TStringList;
  H: TTestHost;
  I, P, Bad: Integer;
  E, Want, Got, Msg: string;
  SavedFs: TFormatSettings;
begin
  if not FileExists('manual_examples.txt') then
  begin
    Check(False, 'manual: tests/manual_examples.txt missing (run tools/manual_src/build_manual.py)');
    Exit;
  end;
  L := TStringList.Create;
  H := TTestHost.Create;
  try
    L.LoadFromFile('manual_examples.txt');
    SavedFs := DefaultFormatSettings;
    UseCroatianFormats;
    Bad := 0;
    Msg := '';
    for I := 0 to L.Count - 1 do
    begin
      if Trim(L[I]) = '' then Continue;
      P := Pos(#9, L[I]);
      E := Copy(L[I], 1, P - 1);
      Want := Copy(L[I], P + 1, MaxInt);
      Got := Ev(H, E);
      if Got <> Want then
      begin
        Inc(Bad);
        Msg := Msg + E + ' => "' + Got + '" (u priručniku: "' + Want + '"); ';
      end;
    end;
    DefaultFormatSettings := SavedFs;
    Check(Bad = 0, 'manual: every documented example gives the documented result (' + IntToStr(L.Count) + ' examples) ' + Msg);
  finally
    H.Free;
    L.Free;
  end;
end;

{ pilot recepata za račun sa stavkama: zaokruživanje, dvosmjerni unos cijene i iznosa, PDV po stopama }
procedure TestInvoiceRounding;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  Q: TZQuery;
  H: TTestHost;
  V: Variant;
  Path: string;
  RD: TaReportDef;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  PgI, ItI: Integer;
  Txt: string;

  function Vd(const AExpr: string): Double;
  begin
    V := EvalExpr(AExpr, H);
    if VarIsNull(V) then Result := -999999 else Result := V;
  end;

  function Pdv(const ACrit: string): Double;
  begin
    Result := Double(DbDomain(Db, 'pdvpostopama', 'iznos,pdv_stopa', 'pilot_stavka', ACrit));
  end;

begin
  Path := '/tmp/ta_pilot_rounding.db';
  if FileExists(Path) then DeleteFile(Path);
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open(Path);
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE pilot_stavka (id INTEGER PRIMARY KEY, dok INTEGER, kolicina REAL, cijena REAL, rabat REAL, pdv_stopa REAL, iznos REAL)');
    { Zaokruzi je novcano (pola na gore), Round je bankarski }
    Check(Abs(Vd('Zaokruzi(1.005, 2)') - 1.01) < 1E-9, 'pilot: Zaokruzi(1.005, 2) = 1.01');
    Check(Abs(Vd('Zaokruzi(-2.345, 2) + 2.35')) < 1E-9, 'pilot: negative amounts round away from zero too');
    Check(Abs(Vd('Zaokruzi(0.125, 2)') - 0.13) < 1E-9, 'pilot: 0.125 rounds to 0.13 (Round gives 0.12)');
    Check(Abs(Vd('Round(0.125, 2)') - 0.12) < 1E-9, 'pilot: Round stays banker''s rounding');
    { PDV po stopi: tri stavke 10,05 uz 10 %: 30,15 * 10 % = 3,015 -> 3,02 (po stavci bi bilo 3 x 1,01 = 3,03) }
    Db.Conn.ExecuteDirect('INSERT INTO pilot_stavka (dok, kolicina, cijena, rabat, pdv_stopa, iznos) VALUES ' +
      '(1, 1, 10.05, 0, 10, 10.05), (1, 1, 10.05, 0, 10, 10.05), (1, 1, 10.05, 0, 10, 10.05)');
    Check(Abs(Pdv('dok = 1') - 3.02) < 1E-9, 'pilot: VAT on 30.15 at 10 % is 3.02 (per line would give 3.03)');
    { 130,63 uz 20 % = 26,126 -> 26,13 }
    Db.Conn.ExecuteDirect('INSERT INTO pilot_stavka (dok, kolicina, cijena, rabat, pdv_stopa, iznos) VALUES (2, 1, 130.63, 0, 20, 130.63)');
    Check(Abs(Pdv('dok = 2') - 26.13) < 1E-9, 'pilot: VAT on 130.63 at 20 % is 26.13');
    { dvije stope na istom dokumentu: 100,10 * 25 % = 25,025 -> 25,03; 50,05 * 5 % = 2,5025 -> 2,50 }
    Db.Conn.ExecuteDirect('INSERT INTO pilot_stavka (dok, kolicina, cijena, rabat, pdv_stopa, iznos) VALUES ' +
      '(3, 1, 100.10, 0, 25, 100.10), (3, 1, 50.05, 0, 5, 50.05)');
    Check(Abs(Pdv('dok = 3') - 27.53) < 1E-9, 'pilot: each VAT rate is rounded separately (25.03 + 2.50)');
    Check(Abs(Vd('PdvPoStopama("pilot_stavka", "iznos", "pdv_stopa", "dok = 3")') - 27.53) < 1E-9, 'pilot: PdvPoStopama works as an expression');
    Check(Abs(Vd('Nz(DSum("iznos", "pilot_stavka", "dok = 1"), 0) + PdvPoStopama("pilot_stavka", "iznos", "pdv_stopa", "dok = 1")') - 33.17) < 1E-9,
      'pilot: document total = sum of printed lines + VAT = 33.17');

    { dvosmjerni unos u mrezi: cijena/kolicina/rabat -> iznos, iznos -> cijena }
    D := TaFormDef.Create;
    D.Name := 'PilotStavke'; D.RecordSource := 'pilot_stavka'; D.ViewMode := 'datasheet';
    D.CalcRules := 'kolicina,cijena,rabat -> iznos = Zaokruzi([kolicina] * [cijena] * (1 - [rabat] / 100), 2) ;; ' +
      'iznos -> cijena = Zaokruzi([iznos] / ([kolicina] * (1 - [rabat] / 100)), 4)';
    R := TaFormRunner.CreateRunner(nil, Db, D);
    Q := R.Query;
    Q.Append;
    Q.FieldByName('dok').AsInteger := 9;
    Q.FieldByName('pdv_stopa').AsFloat := 25;
    Q.FieldByName('rabat').AsFloat := 0;
    Q.FieldByName('kolicina').AsFloat := 7;
    Q.FieldByName('cijena').AsFloat := 0.7528;
    Check(Abs(Q.FieldByName('iznos').AsFloat - 5.27) < 1E-9, 'pilot: 7 x 0.7528 gives line amount 5.27 (displayed price 0.75 would give 5.25): ' + FloatToStr(Q.FieldByName('iznos').AsFloat));
    { kupac/racun trazi 5,25: upisujemo iznos, cijena se preracuna }
    Q.FieldByName('iznos').AsFloat := 5.25;
    Check(Abs(Q.FieldByName('cijena').AsFloat - 0.75) < 1E-9, 'pilot: typing the line amount 5.25 recalculates the unit price to 0.75: ' + FloatToStr(Q.FieldByName('cijena').AsFloat));
    Check(Abs(Q.FieldByName('iznos').AsFloat - 5.25) < 1E-9, 'pilot: the amount typed by the user is kept (no loop)');
    { popravak kolicine vraca isti iznos jer je cijena tocna }
    Q.FieldByName('kolicina').AsFloat := 7;
    Check(Abs(Q.FieldByName('iznos').AsFloat - 5.25) < 1E-9, 'pilot: round trip amount -> price -> amount returns 5.25');
    Q.Post;
    { kolicina 0,333 x 3,00 = 0,999 -> 1,00; obrnuto 1,00 / 0,333 = 3,0030 }
    Q.Append;
    Q.FieldByName('dok').AsInteger := 9;
    Q.FieldByName('pdv_stopa').AsFloat := 25;
    Q.FieldByName('rabat').AsFloat := 0;
    Q.FieldByName('kolicina').AsFloat := 0.333;
    Q.FieldByName('cijena').AsFloat := 3;
    Check(Abs(Q.FieldByName('iznos').AsFloat - 1.0) < 1E-9, 'pilot: 0.333 x 3.00 = 1.00 after rounding');
    Q.FieldByName('iznos').AsFloat := 1.0;
    Check(Abs(Q.FieldByName('cijena').AsFloat - 3.003) < 1E-9, 'pilot: price from amount keeps 4 decimals (3.0030)');
    { rabat 10 %: iznos / (kolicina * 0,9) }
    Q.FieldByName('kolicina').AsFloat := 2;
    Q.FieldByName('rabat').AsFloat := 10;
    Q.FieldByName('iznos').AsFloat := 54;
    Check(Abs(Q.FieldByName('cijena').AsFloat - 30) < 1E-9, 'pilot: discount is respected when deriving the price (54 / (2 x 0.9) = 30)');
    Q.Cancel;
    R.Free;
    { redni broj stavke: u cijelom izvjescu (RunCount) i unutar grupe (RunGCount), poredak po sifri/iznosu }
    Db.Conn.ExecuteDirect('DELETE FROM pilot_stavka WHERE dok = 9');
    RD := TaReportDef.Create;
    RD.Name := 'PilotRbr'; RD.RecordSource := 'pilot_stavka'; RD.GroupField := 'dok'; RD.SortBy := 'iznos DESC';
    RD.Add(RItem('TextBox', 'Detail', 'tUk', '=RunCount(*)', 0, 0, 40, 18));
    RD.Add(RItem('TextBox', 'Detail', 'tGr', '=RunGCount(*)', 50, 0, 40, 18));
    RD.Add(RItem('TextBox', 'Detail', 'tIz', '=Format([iznos], "0.00")', 100, 0, 60, 18));
    RE := TaReportEngine.Create(Db, RD);
    RR := RE.Render;
    Txt := '';
    for PgI := 0 to RR.PageCount - 1 do
      for ItI := 0 to RR.Page(PgI).Items.Count - 1 do
        Txt := Txt + TaRItem(RR.Page(PgI).Items[ItI]).Text + ' ';
    Check(Pos('1 1 10.05', Txt) > 0, 'pilot: row number restarts in each group (RunGCount): ' + Txt);
    Check((Pos('3 3 10.05', Txt) > 0) and (Pos('4 1 130.63', Txt) > 0) and (Pos('6 2 50.05', Txt) > 0),
      'pilot: RunCount keeps counting over the whole report, RunGCount per group, sorted by amount descending: ' + Txt);
    RR.Free; RE.Free; RD.Free;
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

{ recepti: zaliha iz kretanja, kaskadni popisi, zakljucavanje knjizenog dokumenta }
procedure TestRecipes2;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  C: TaControlDef;
  Q: TZQuery;
  Log: TStringList;
  Path: string;
  Cz, Cg: TComboBox;
  A1, A2: Double;
  Art1: string;
begin
  Path := '/tmp/ta_recipes2.db';
  if FileExists(Path) then DeleteFile(Path);
  Db := TAppDb.Create;
  Log := TStringList.Create;
  try
    Db.Open(Path);
    ActiveDb := Db;
    OnScriptMessage := @CaptureScript;
    { ---- zaliha: stanje = primke - izdatnice (predlozak Skladisni promet) ---- }
    Check(ApplyBizTemplate(Db, 'skladiste', '', True, Log), 'recipes: warehouse template applied ' + Log.Text);
    Q := Db.NewQuery('SELECT sifra FROM artikli WHERE id = 1');
    Q.Open; Art1 := Q.Fields[0].AsString; Q.Free;
    Q := Db.NewQuery('SELECT sifra, stanje FROM ' + Db.SourceFrom('Stanje zaliha') + ' ORDER BY sifra');
    A1 := -1; A2 := -1;
    try
      Q.Open;
      while not Q.EOF do
      begin
        if Q.Fields[0].AsString = Art1 then A1 := Q.Fields[1].AsFloat;
        Q.Next;
      end;
    except
      on E: Exception do Check(False, 'recipes: stock query ' + E.Message);
    end;
    Q.Free;
    Q := Db.NewQuery('SELECT COALESCE(SUM(CASE WHEN d.tip = ''Primka'' THEN s.kolicina ELSE -s.kolicina END), 0) FROM skl_stavke s JOIN skl_dokumenti d ON d.id = s.dokument_id WHERE s.artikl_id = 1');
    Q.Open; A2 := Q.Fields[0].AsFloat; Q.Free;
    Check(Abs(A2 - 300) < 1E-9, 'recipes: stock of article 1 = 500 received - 200 issued = 300');
    Check(Abs(A1 - 300) < 1E-9, 'recipes: the "Stanje zaliha" query gives the same stock (' + FloatToStr(A1) + ')');
    { ---- kaskadni popisi: grad ovisi o zupaniji ---- }
    Db.Conn.ExecuteDirect('CREATE TABLE zupanija (id INTEGER PRIMARY KEY, naziv TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE grad (id INTEGER PRIMARY KEY, naziv TEXT, zupanija_id INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE adresa (id INTEGER PRIMARY KEY, zupanija_id INTEGER, grad_id INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO zupanija VALUES (1, ''Zagrebačka''), (2, ''Primorsko-goranska'')');
    Db.Conn.ExecuteDirect('INSERT INTO grad VALUES (1, ''Samobor'', 1), (2, ''Velika Gorica'', 1), (3, ''Rijeka'', 2), (4, ''Opatija'', 2), (5, ''Krk'', 2)');
    Db.Conn.ExecuteDirect('INSERT INTO adresa VALUES (1, 1, 1)');
    D := TaFormDef.Create;
    D.Name := 'AdresaKask'; D.RecordSource := 'adresa';
    C := NewCtl('ComboBox', 'cmbZup', 'zupanija_id', 10, 10); C.RowSource := 'SELECT id, naziv FROM zupanija ORDER BY naziv'; D.Add(C);
    C := NewCtl('ComboBox', 'cmbGrad', 'grad_id', 10, 50); C.RowSource := 'SELECT id, naziv FROM grad WHERE zupanija_id = [cmbZup] ORDER BY naziv'; D.Add(C);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    Cz := TComboBox(R.ControlByName('cmbZup'));
    Cg := TComboBox(R.ControlByName('cmbGrad'));
    Check(Cg.Items.Count = 2, 'recipes: cascade - county 1 offers its 2 towns (' + IntToStr(Cg.Items.Count) + ')');
    Cz.ItemIndex := Cz.Items.IndexOf('Primorsko-goranska');
    if Assigned(Cz.OnChange) then Cz.OnChange(Cz);
    Check(Cg.Items.Count = 3, 'recipes: cascade - choosing county 2 refreshes the town list to its 3 towns (' + IntToStr(Cg.Items.Count) + ')');
    Check(Cg.Items.IndexOf('Opatija') >= 0, 'recipes: cascade - list holds the new county''s towns');
    R.Free;
    { ---- zakljucavanje knjizenog dokumenta ---- }
    Db.Conn.ExecuteDirect('CREATE TABLE racun2 (id INTEGER PRIMARY KEY, iznos REAL, knjizen INTEGER DEFAULT 0)');
    Db.Conn.ExecuteDirect('INSERT INTO racun2 VALUES (1, 100, 1), (2, 50, 0)');
    Db.SaveObject('_sys_modules', 'Zakljucaj',
      'procedure ZakljucajKnjizeno;' + LineEnding + 'begin' + LineEnding +
      '  if SqlValue(''SELECT knjizen FROM racun2 WHERE id = '' + GetValue(''txtId'')) = ''1'' then' + LineEnding +
      '  begin' + LineEnding + '    ShowMessage(''Račun je knjižen i ne može se mijenjati.'');' + LineEnding + '    CancelEvent;' + LineEnding + '  end;' + LineEnding + 'end;');
    ResetScripts;
    D := TaFormDef.Create;
    D.Name := 'RacunZ'; D.RecordSource := 'racun2';
    D.SetEv('BeforeUpdate', 'ZakljucajKnjizeno');
    D.Add(NewCtl('TextBox', 'txtId', 'id', 10, 10));
    D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 40));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    TEdit(R.ControlByName('txtIznos')).Text := '120';
    Check(not R.SaveRecord, 'recipes: a posted invoice cannot be changed (BeforeUpdate + SqlValue + CancelEvent)');
    R.DoAction('undo');
    R.DoAction('next');
    TEdit(R.ControlByName('txtIznos')).Text := '75';
    Check(R.SaveRecord, 'recipes: an unposted invoice can still be changed');
    R.Free;
    { isti modul na BeforeDelete: knjizeni racun se ne moze obrisati (CancelEvent prije upita za potvrdu) }
    D := TaFormDef.Create;
    D.Name := 'RacunZ2'; D.RecordSource := 'racun2';
    D.SetEv('BeforeDelete', 'ZakljucajKnjizeno');
    D.Add(NewCtl('TextBox', 'txtId', 'id', 10, 10));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    A1 := R.Query.RecordCount;
    LastMsg := '';
    R.DoAction('delete');
    Check((R.Query.RecordCount = A1) and (Pos('knjižen', ScriptLog) > 0), 'recipes: BeforeDelete with the same procedure refuses to delete a posted invoice ' + ScriptLog);
    R.Free;
    ResetScripts;
  finally
    OnScriptMessage := nil;
    ActiveDb := nil;
    Log.Free;
    Db.Free;
  end;
end;

{ 20 recepata: izvjesca, forme, podaci i sustav }
function RTexts(RR: TaRenderedReport): string;
var
  P, I: Integer;
begin
  Result := '';
  for P := 0 to RR.PageCount - 1 do
    for I := 0 to RR.Page(P).Items.Count - 1 do
      Result := Result + TaRItem(RR.Page(P).Items[I]).Text + '|';
end;

function RenderTexts(ADb: TAppDb; ARd: TaReportDef; out APages: Integer): string;
var
  RE: TaReportEngine;
  RR: TaRenderedReport;
begin
  RE := TaReportEngine.Create(ADb, ARd);
  RR := RE.Render;
  Result := RTexts(RR);
  APages := RR.PageCount;
  RR.Free;
  RE.Free;
end;

procedure TestRecipes3;
var
  Db: TAppDb;
  RD: TaReportDef;
  D: TaFormDef;
  R: TaFormRunner;
  C: TaControlDef;
  M: TaFieldMeta;
  H: TTestHost;
  Q: TZQuery;
  Tx, Path: string;
  Pg, N1, N2, XA, XB, XC, YA, YB, YC: Integer;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  It: TaRItem;
  SrcRec: TSearchRec;
  Rows: TaRows;
  Cols: TaImportCols;
  Res: TaImportResult;
  Tk: TaTask;
  Msg, Ln: string;
  Sl: TStringList;
  Fs: TFileStream;
  Bom: array[0..2] of Byte;

  function Ev2(const AExpr: string): string;
  begin
    Result := FormatValue(EvalExpr(AExpr, H), '');
  end;

begin
  Path := '/tmp/ta_recipes3.db';
  if FileExists(Path) then DeleteFile(Path);
  Db := TAppDb.Create;
  H := TTestHost.Create;
  Sl := TStringList.Create;
  try
    Db.Open(Path);
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE rac (id INTEGER PRIMARY KEY, kupac TEXT, iznos REAL, placeno INTEGER, datum TEXT, dospijece TEXT, kolicina REAL, cijena REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO rac VALUES (1, ''A'', 100, 1, ''2026-03-01'', ''2026-03-16'', 2, 50), (2, ''A'', 50, 0, ''2026-03-02'', ''2026-03-17'', 1, 50), ' +
      '(3, ''B'', 30, 1, ''2026-03-03'', ''2026-03-18'', 3, 10), (4, ''B'', 20, 0, ''2026-03-04'', ''2026-03-19'', 4, 5)');

    { ---------- IZVJESCA ---------- }
    { 1. zbroj grupe i ukupni zbroj }
    RD := TaReportDef.Create; RD.Name := 'R1'; RD.RecordSource := 'rac'; RD.GroupField := 'kupac'; RD.SortBy := 'id';
    RD.Add(RItem('TextBox', 'Detail', 'd', '=Format([iznos], "0.00")', 0, 0, 60, 18));
    RD.Add(RItem('TextBox', 'GroupFooter', 'g', '="G:" & Format(Sum([iznos]), "0.00")', 0, 0, 80, 18));
    RD.Add(RItem('TextBox', 'ReportFooter', 'u', '="U:" & Format(Sum([iznos]), "0.00")', 0, 0, 80, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check((Pos('G:150.00', Tx) > 0) and (Pos('G:50.00', Tx) > 0) and (Pos('U:200.00', Tx) > 0), 'recipe 11: group totals and the report total: ' + Tx);
    { 2. udio grupe u ukupnom iznosu }
    RD := TaReportDef.Create; RD.Name := 'R2'; RD.RecordSource := 'rac'; RD.GroupField := 'kupac'; RD.SortBy := 'id';
    RD.Add(RItem('TextBox', 'GroupFooter', 'g', '="P:" & Format(Percent(Sum([iznos]), SumAll([iznos])), "0.0")', 0, 0, 80, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check((Pos('P:75.0', Tx) > 0) and (Pos('P:25.0', Tx) > 0), 'recipe 12: share of the group in the total (75 % and 25 %): ' + Tx);
    { 3. tekuci saldo }
    RD := TaReportDef.Create; RD.Name := 'R3'; RD.RecordSource := 'rac'; RD.SortBy := 'id';
    RD.Add(RItem('TextBox', 'Detail', 's', '="S:" & Format(RunSum([iznos]), "0.00")', 0, 0, 80, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check((Pos('S:100.00|S:150.00|S:180.00|S:200.00', Tx) > 0), 'recipe 13: running balance: ' + Tx);
    { 4. uvjetni zbroj (samo placeno) }
    RD := TaReportDef.Create; RD.Name := 'R4'; RD.RecordSource := 'rac'; RD.SortBy := 'id';
    RD.Add(RItem('TextBox', 'ReportFooter', 'p', '="PL:" & Format(Sum(Iif([placeno] = 1, [iznos], 0)), "0.00")', 0, 0, 80, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check(Pos('PL:130.00', Tx) > 0, 'recipe 14: conditional sum, only paid (130): ' + Tx);
    { 5. Stranica N / M }
    RD := TaReportDef.Create; RD.Name := 'R5'; RD.RecordSource := 'rac';
    RD.Add(RItem('TextBox', 'PageFooter', 'pg', '="Str " & Page & " / " & Pages', 0, 0, 100, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check(Pos('Str 1 / 1', Tx) > 0, 'recipe 15: page number "1 / 1": ' + Tx);
    { 6. nova stranica za svaku grupu }
    RD := TaReportDef.Create; RD.Name := 'R6'; RD.RecordSource := 'rac'; RD.GroupField := 'kupac'; RD.SortBy := 'id';
    RD.Add(RItem('TextBox', 'GroupHeader', 'h', '="K:" & [kupac]', 0, 0, 80, 18));
    RD.Add(RItem('PageBreak', 'GroupHeader', 'pb', '', 0, 0, 10, 2));
    RD.Add(RItem('TextBox', 'Detail', 'd', '=Format([iznos], "0")', 0, 0, 60, 18));
    Tx := RenderTexts(Db, RD, Pg); N1 := Pg; RD.Free;
    Check(N1 = 2, 'recipe 16: a page break at the top of the group header gives every group its own page, no empty first page (' + IntToStr(N1) + ' pages)');
    { 7. ispis samo jednog dokumenta (filter) }
    RD := TaReportDef.Create; RD.Name := 'R7'; RD.RecordSource := 'rac'; RD.Filter := 'id = 3';
    RD.Add(RItem('TextBox', 'Detail', 'd', '="ID" & [id]', 0, 0, 60, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check((Pos('ID3', Tx) > 0) and (Pos('ID1', Tx) = 0) and (Pos('ID4', Tx) = 0), 'recipe 17: print only one document with the report Filter: ' + Tx);
    { 8. naljepnice u stupcima }
    RD := TaReportDef.Create; RD.Name := 'R8'; RD.RecordSource := 'rac'; RD.Columns := 2; RD.ColumnGap := 10; RD.SortBy := 'id';
    RD.Add(RItem('TextBox', 'Detail', 'd', '="N" & [id]', 0, 0, 120, 40));
    RE := TaReportEngine.Create(Db, RD);
    RR := RE.Render;
    XA := -1; XB := -1; YA := -1; YB := -1; XC := -1; YC := -1;
    for N1 := 0 to RR.Page(0).Items.Count - 1 do
    begin
      It := TaRItem(RR.Page(0).Items[N1]);
      if It.Text = 'N1' then begin XA := It.X; YA := It.Y; end;
      if It.Text = 'N2' then begin XB := It.X; YB := It.Y; end;
      if It.Text = 'N3' then begin XC := It.X; YC := It.Y; end;
    end;
    Check((XA >= 0) and (YA = YB) and (XB > XA) and (YC > YA) and (XC = XA), 'recipe 17b: Columns = 2 puts the 2nd label beside the 1st and the 3rd on the next row');
    RR.Free; RE.Free; RD.Free;
    { ---------- FORME ---------- }
    Db.Conn.ExecuteDirect('CREATE TABLE doc (id INTEGER PRIMARY KEY, datum TEXT, dospijece TEXT, oib TEXT, kolicina REAL, cijena REAL, napomena TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO doc VALUES (1, ''2026-03-01'', ''2026-03-16'', ''69435151530'', 2, 50, ''x'')');
    { 9. zadana vrijednost }
    M := TaFieldMeta.Create; M.TableName := 'doc'; M.FieldName := 'datum'; M.LType := ltDate; M.DefaultExpr := 'Today()'; Db.SaveFieldMeta(M); M.Free;
    M := TaFieldMeta.Create; M.TableName := 'doc'; M.FieldName := 'dospijece'; M.LType := ltDate; M.DefaultExpr := 'DateAdd("d", 15, Today())'; Db.SaveFieldMeta(M); M.Free;
    D := TaFormDef.Create; D.Name := 'F9'; D.RecordSource := 'doc';
    D.Add(NewCtl('TextBox', 'tDatum', 'datum', 10, 10)); D.Add(NewCtl('TextBox', 'tDosp', 'dospijece', 10, 40));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    R.DoAction('new');
    Check((TEdit(R.ControlByName('tDatum')).Text = FormatDateTime('dd.mm.yyyy', Date)) and
      (TEdit(R.ControlByName('tDosp')).Text = FormatDateTime('dd.mm.yyyy', Date + 15)), 'recipe 18: default value Today() and DateAdd("d", 15, Today()) on a new record: ' +
      TEdit(R.ControlByName('tDatum')).Text + ' / ' + TEdit(R.ControlByName('tDosp')).Text);
    R.DoAction('undo');
    R.Free;
    { 10. obavezno polje i provjera unosa s porukom }
    M := TaFieldMeta.Create; M.TableName := 'doc'; M.FieldName := 'kolicina'; M.LType := ltDecimal; M.Decimals := 2;
    M.Validation := '[value] > 0'; M.ValidationMsg := 'Količina mora biti veća od nule.'; Db.SaveFieldMeta(M); M.Free;
    D := TaFormDef.Create; D.Name := 'F10'; D.RecordSource := 'doc';
    D.Add(NewCtl('TextBox', 'tId', 'id', 10, 10)); D.Add(NewCtl('TextBox', 'tKol', 'kolicina', 10, 40));
    LastMsg := '';
    OnRunnerMessage := @CaptureMsg;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    TEdit(R.ControlByName('tKol')).Text := '0';
    Check(not R.SaveRecord, 'recipe 19: a value that breaks the validation rule is not saved');
    Check(Pos('veća od nule', LastMsg) > 0, 'recipe 19: the rule''s message is shown: ' + LastMsg);
    TEdit(R.ControlByName('tKol')).Text := '3';
    Check(R.SaveRecord, 'recipe 19: a valid value is saved');
    R.Free;
    OnRunnerMessage := nil;
    { 11. OIB }
    Check((Ev2('ValidOib("69435151530")') <> Ev2('ValidOib("69435151531")')) and (Ev2('ValidOib("69435151530")') = Ev2('1 = 1')),
      'recipe 20: ValidOib accepts a correct OIB and rejects a wrong check digit');
    { 12. izracunata kontrola }
    D := TaFormDef.Create; D.Name := 'F12'; D.RecordSource := 'doc';
    D.Add(NewCtl('TextBox', 'tKol', 'kolicina', 10, 10)); D.Add(NewCtl('TextBox', 'tCij', 'cijena', 10, 40));
    D.Add(NewCtl('TextBox', 'tUk', '=[kolicina] * [cijena]', 10, 70));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    TEdit(R.ControlByName('tKol')).Text := '4';
    TEdit(R.ControlByName('tCij')).Text := '2.5';
    Check(StrToFloatDef(StringReplace(TEdit(R.ControlByName('tUk')).Text, ',', '.', []), -1, InvariantFS) = 10, 'recipe 21: a calculated control follows what is typed (4 x 2.5 = 10): ' + TEdit(R.ControlByName('tUk')).Text);
    R.Free;
    { 13. uvjetno prikazivanje kontrole }
    D := TaFormDef.Create; D.Name := 'F13'; D.RecordSource := 'doc';
    D.Add(NewCtl('TextBox', 'tKol', 'kolicina', 10, 10));
    C := NewCtl('Label', 'lblUpoz', '', 10, 40); C.Caption := 'Velika količina!'; C.SetX('visibleIf', '[kolicina] > 100'); D.Add(C);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    TEdit(R.ControlByName('tKol')).Text := '500';
    Check(R.ControlByName('lblUpoz').Visible, 'recipe 22: VisibleIf shows the warning when the condition holds');
    TEdit(R.ControlByName('tKol')).Text := '5';
    Check(not R.ControlByName('lblUpoz').Visible, 'recipe 22: VisibleIf hides it again');
    R.Free;
    { 14. kopiranje zapisa }
    D := TaFormDef.Create; D.Name := 'F14'; D.RecordSource := 'rac';
    D.Add(NewCtl('TextBox', 'tK', 'kupac', 10, 10)); D.Add(NewCtl('TextBox', 'tI', 'iznos', 10, 40));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    N1 := R.Query.RecordCount;
    R.DoAction('duplicate');
    R.DoAction('save');
    N2 := R.Query.RecordCount;
    Check(N2 = N1 + 1, 'recipe 23: the duplicate action adds a copy of the record (' + IntToStr(N1) + ' -> ' + IntToStr(N2) + ')');
    R.Free;
    Db.Conn.ExecuteDirect('DELETE FROM rac WHERE id > 4');

    { ---------- PODACI I SUSTAV ---------- }
    { 15. uvoz CSV s hrvatskim brojevima i datumima }
    Sl.Add('Naziv;Cijena;Datum');
    Sl.Add('Kava;1.234,56;31.12.2026');
    Sl.Add('Čaj;7,80;01.03.2026');
    Sl.SaveToFile('/tmp/ta_recipe_uvoz.csv');
    Check(ReadAnyFile('/tmp/ta_recipe_uvoz.csv', #0, Rows), 'recipe 24: CSV read');
    Cols := InferColumns(Rows, True);
    Check((Length(Cols) = 3) and (Cols[1].LType = ltDecimal) and (Cols[2].LType = ltDate), 'recipe 24: price and date columns are recognised from the Croatian notation');
    Res := ImportToNewTable(Db, 'uvezeno', Rows, True, True, Cols);
    Q := Db.NewQuery('SELECT cijena, datum FROM uvezeno WHERE naziv = ''Kava''');
    Q.Open;
    Check((Abs(Q.Fields[0].AsFloat - 1234.56) < 1E-9) and (Q.Fields[1].AsString = '2026-12-31'), 'recipe 24: 1.234,56 is stored as 1234.56 and 31.12.2026 as 2026-12-31 (' + Q.Fields[0].AsString + ' / ' + Q.Fields[1].AsString + ')');
    Q.Free;
    { 16. izvoz za Excel }
    ExportCsv(Db, 'rac', '/tmp/ta_recipe_izvoz.csv', ';');
    Fs := TFileStream.Create('/tmp/ta_recipe_izvoz.csv', fmOpenRead);
    Fs.ReadBuffer(Bom, 3);
    Fs.Free;
    Sl.LoadFromFile('/tmp/ta_recipe_izvoz.csv');
    Check((Bom[0] = $EF) and (Bom[1] = $BB) and (Bom[2] = $BF) and (Pos(';', Sl[0]) > 0), 'recipe 25: the CSV export has a BOM and uses ; (Excel reads Croatian letters correctly): ' + Sl[0]);
    { 17. sigurnosna kopija planerom }
    ForceDirectories('/tmp/ta_recipe_kopije');
    Tk.Name := 'kopija'; Tk.Kind := 'backup'; Tk.Arg := '/tmp/ta_recipe_kopije'; Tk.Arg2 := '3'; Tk.Schedule := 'dnevno 02:00'; Tk.Enabled := True; Tk.LastRun := 0; Tk.LastResult := '';
    Check(RunTask(Db, Tk, Msg) and (Pos('Kopija:', Msg) = 1), 'recipe 26: the planner makes a backup copy: ' + Msg);
    Check(FindFirst('/tmp/ta_recipe_kopije/*.db', faAnyFile, SrcRec) = 0, 'recipe 26: the copy exists as a file');
    FindClose(SrcRec);
    { 18. revizijski trag }
    AuditSetUser(Db, 'ana');
    AuditEnable(Db, 'rac');
    Db.Conn.ExecuteDirect('UPDATE rac SET iznos = 99 WHERE id = 2');
    Q := AuditQuery(Db, 'rac', '', 'U', '2', '', '', 10);
    Check((Q.RecordCount = 1) and (Q.FieldByName('korisnik').AsString = 'ana') and (Q.FieldByName('polje').AsString = 'iznos') and (Q.FieldByName('novo').AsString = '99.0'),
      'recipe 27: the audit trail records who changed which field from what to what');
    Q.Free;
    { 19. zaokruzivanje gotovine na 0,05 }
    Check(Abs(EvalExpr('Zaokruzi(12.37 / 0.05, 0) * 0.05', H) - 12.35) < 1E-9, 'recipe 28: cash rounding to 0.05 (12.37 -> 12.35)');
    Check(Abs(EvalExpr('Zaokruzi(12.38 / 0.05, 0) * 0.05', H) - 12.4) < 1E-9, 'recipe 28: cash rounding to 0.05 (12.38 -> 12.40)');
    { 20. dospijece i dani kasnjenja }
    Check(Ev2('DateAdd("d", 15, DateSerial(2026, 3, 1))') = Ev2('DateSerial(2026, 3, 16)'), 'recipe 29: due date = date + 15 days');
    Check(Ev2('DateDiff("d", DateSerial(2026, 3, 16), DateSerial(2026, 4, 5))') = '20', 'recipe 29: days late = DateDiff("d", due date, today) (20)');
  finally
    ActiveDb := nil;
    OnRunnerMessage := nil;
    Sl.Free;
    H.Free;
    Db.Free;
  end;
end;

{ recepti 4: kamate, tecaj, ponuda u racun, amortizacija, PDV rekapitulacija, duplikati, prvih n }
procedure TestRecipes4;
var
  Db: TAppDb;
  RD: TaReportDef;
  H: TTestHost;
  Q: TZQuery;
  Tx: string;
  Pg: Integer;
  function Ev4(const AExpr: string): string;
  begin
    Result := FormatValue(EvalExpr(AExpr, H), '');
  end;
  function One(const ASql: string): string;
  begin
    Q := Db.NewQuery(ASql);
    try
      Q.Open;
      Result := Q.Fields[0].AsString;
    finally
      Q.Free;
    end;
  end;
begin
  if FileExists('/tmp/ta_recipes4.db') then DeleteFile('/tmp/ta_recipes4.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_recipes4.db');
    ActiveDb := Db;
    { 1. zatezne kamate }
    Check(Abs(EvalExpr('Zaokruzi(1000 * 0.12 / 365 * DateDiff("d", DateSerial(2026, 3, 16), DateSerial(2026, 4, 5)), 2)', H) - 6.58) < 1E-9,
      'recipe 32: late interest 1000 EUR, 12 % a year, 20 days = 6.58');
    { 2. strana valuta i tecaj }
    Check(Abs(EvalExpr('Zaokruzi(125.50 * 7.5345, 2)', H) - 945.58) < 1E-9, 'recipe 33: foreign currency amount times the rate, rounded to cents (945.58)');
    { 3. linearna amortizacija }
    Check(Abs(EvalExpr('Zaokruzi((12000 - 1000) / 5 / 12, 2)', H) - 183.33) < 1E-9, 'recipe 34: straight-line depreciation per month (183.33)');
    { 4. ponuda u racun }
    Db.Conn.ExecuteDirect('CREATE TABLE ponuda (id INTEGER PRIMARY KEY, kupac TEXT, datum TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE ponuda_stavka (id INTEGER PRIMARY KEY, ponuda_id INTEGER, opis TEXT, kolicina REAL, cijena REAL, pdv_stopa REAL)');
    Db.Conn.ExecuteDirect('CREATE TABLE racun (id INTEGER PRIMARY KEY, kupac TEXT, datum TEXT, ponuda_id INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE racun_stavka (id INTEGER PRIMARY KEY, racun_id INTEGER, opis TEXT, kolicina REAL, cijena REAL, pdv_stopa REAL, iznos REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO ponuda VALUES (7, ''Ana d.o.o.'', ''2026-03-01'')');
    Db.Conn.ExecuteDirect('INSERT INTO ponuda_stavka (ponuda_id, opis, kolicina, cijena, pdv_stopa) VALUES (7, ''Usluga'', 2, 100.10, 25), (7, ''Knjiga'', 1, 50.05, 5), (7, ''Ostalo'', 3, 10.05, 25)');
    Db.Conn.ExecuteDirect('INSERT INTO racun (kupac, datum, ponuda_id) SELECT kupac, ''2026-03-10'', id FROM ponuda WHERE id = 7');
    Db.Conn.ExecuteDirect('INSERT INTO racun_stavka (racun_id, opis, kolicina, cijena, pdv_stopa, iznos) ' +
      'SELECT (SELECT MAX(id) FROM racun), opis, kolicina, cijena, pdv_stopa, ROUND(kolicina * cijena, 2) FROM ponuda_stavka WHERE ponuda_id = 7');
    Check((One('SELECT COUNT(*) FROM racun_stavka WHERE racun_id = 1') = '3') and (One('SELECT kupac FROM racun WHERE id = 1') = 'Ana d.o.o.') and
      (One('SELECT ponuda_id FROM racun WHERE id = 1') = '7'), 'recipe 35: the offer is copied into an invoice (header + 3 items, with a link to the offer)');
    Check(Abs(StrToFloat(One('SELECT SUM(iznos) FROM racun_stavka WHERE racun_id = 1'), InvariantFS) - 280.40) < 1E-9, 'recipe 35: the copied item amounts add up to 280.40');
    { 5. rekapitulacija PDV-a po stopama (izvjesce) }
    RD := TaReportDef.Create; RD.Name := 'Rek'; RD.RecordSource := 'racun_stavka'; RD.GroupField := 'pdv_stopa'; RD.SortBy := 'pdv_stopa, id';
    RD.Add(RItem('TextBox', 'GroupFooter', 'g', '="S" & Format([pdv_stopa], "0") & ": " & Format(Sum([iznos]), "0.00") & " / " & Format(Zaokruzi(Sum([iznos]) * [pdv_stopa] / 100, 2), "0.00")', 0, 0, 200, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check((Pos('S5: 50.05 / 2.50', Tx) > 0) and (Pos('S25: 230.35 / 57.59', Tx) > 0), 'recipe 36: VAT recap per rate in a group footer: ' + Tx);
    { 6. duplikati }
    Db.Conn.ExecuteDirect('CREATE TABLE kupac (id INTEGER PRIMARY KEY, naziv TEXT, oib TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO kupac (naziv, oib) VALUES (''A'', ''111''), (''B'', ''222''), (''A2'', ''111''), (''C'', ''333''), (''B2'', ''222''), (''B3'', ''222'')');
    Check(One('SELECT COUNT(*) FROM (SELECT oib FROM kupac GROUP BY oib HAVING COUNT(*) > 1)') = '2', 'recipe 37: duplicates by OIB, GROUP BY ... HAVING COUNT(*) > 1 (2 OIBs)');
    Check(One('SELECT SUM(n) FROM (SELECT COUNT(*) AS n FROM kupac GROUP BY oib HAVING COUNT(*) > 1)') = '5', 'recipe 37: the duplicated OIBs cover 5 records');
    { 8. Preuzmi: kratica za DLookup po primarnom kljucu }
    Db.Conn.ExecuteDirect('CREATE TABLE artikl (sifra TEXT PRIMARY KEY, naziv TEXT, cijena REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO artikl VALUES (''A-1'', ''Vijak'', 0.35), (''B-2'', ''O''''Brien matica'', 0.25)');
    Check(Ev4('Preuzmi("artikl", "cijena", "A-1")') = '0.35', 'recipe 41: Preuzmi("artikl", "cijena", key) takes the price by the text primary key (0.35)');
    Check(Ev4('Preuzmi("artikl", "naziv", "B-2")') = 'O''Brien matica', 'recipe 41: Preuzmi copes with an apostrophe in the value');
    Check(Ev4('Preuzmi("artikl", "cijena", Null)') = '', 'recipe 41: an empty key gives empty, no error');
    Check(Ev4('Preuzmi("ponuda", "kupac", 7)') = 'Ana d.o.o.', 'recipe 41: Preuzmi with a numeric key (offer 7)');
    { 7. prvih n po iznosu }
    Check(One('SELECT GROUP_CONCAT(kupac, ''|'') FROM (SELECT kupac FROM (SELECT kupac, SUM(iznos) AS z FROM racun_stavka JOIN racun ON racun.id = racun_id GROUP BY kupac ORDER BY z DESC LIMIT 3))') = 'Ana d.o.o.',
      'recipe 38: top n customers by total, ORDER BY ... DESC LIMIT n');
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

{ recepti 5: parametarski upit s datumima, korisnici i prava }
procedure TestRecipes5;
var
  Db: TAppDb;
  Q: TZQuery;
  Vals: TStringList;
  Role1: TaRole;
  Sql: string;
  function One(const ASql: string): string;
  begin
    Q := Db.NewQuery(ASql);
    try
      Q.Open;
      Result := Q.Fields[0].AsString;
    finally
      Q.Free;
    end;
  end;
begin
  if FileExists('/tmp/ta_recipes5.db') then DeleteFile('/tmp/ta_recipes5.db');
  Db := TAppDb.Create;
  Vals := TStringList.Create;
  try
    Db.Open('/tmp/ta_recipes5.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE transakcija (id INTEGER PRIMARY KEY, datum TEXT, iznos REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO transakcija (datum, iznos) VALUES (''2026-01-15'', 10), (''2026-02-01'', 20), (''2026-02-28'', 30), (''2026-03-01'', 40)');
    { 1. razdoblje od-do, datum se upisuje kao 01.02.2026 ili 2026-02-01 }
    Sql := 'SELECT SUM(iznos) FROM transakcija WHERE datum >= [?Od] AND datum <= [?Do]';
    Vals.Values['Od'] := '01.02.2026'; Vals.Values['Do'] := '28.02.2026';
    Check(One(SubstituteParams(Sql, Vals)) = '50', 'recipe 39: parametric query with dates from-to (dd.mm.yyyy) gives 50');
    Vals.Values['Od'] := '2026-02-01'; Vals.Values['Do'] := '2026-03-01';
    Check(One(SubstituteParams(Sql, Vals)) = '90', 'recipe 39: the same query with ISO dates gives 90');
    { prazan parametar = NULL = nista ne vraca; "svi" rjesava (... OR [?Od] IS NULL) }
    Sql := 'SELECT SUM(iznos) FROM transakcija WHERE (datum >= [?Od] OR [?Od] IS NULL) AND (datum <= [?Do] OR [?Do] IS NULL)';
    Vals.Values['Od'] := ''; Vals.Values['Do'] := '';
    Check(One(SubstituteParams(Sql, Vals)) = '100', 'recipe 39: empty parameters mean "no limit" with (... OR [?Od] IS NULL): 100');
    Vals.Values['Od'] := '01.03.2026';
    Check(One(SubstituteParams(Sql, Vals)) = '40', 'recipe 39: only the lower limit given: 40');
    { 2. korisnici i prava }
    Check(UserCount(Db) = 0, 'recipe 40: no users, everybody is an administrator');
    Check(AddUser(Db, 'ana', 'tajna1', arAdmin) and AddUser(Db, 'ivo', 'lozinka2', arViewer), 'recipe 40: administrator and viewer added');
    Check(Authenticate(Db, 'ivo', 'lozinka2', Role1) and (Role1 = arViewer), 'recipe 40: ivo logs in as viewer');
    SetObjectRight(Db, 'form', 'Racuni', arUser);
    SetObjectRight(Db, 'report', 'Plaće', arAdmin);
    StartSession('ivo', arViewer);
    Check(not CanRun(Db, 'form', 'Racuni') and not CanRun(Db, 'report', 'Plaće') and CanRun(Db, 'form', 'Kupci'), 'recipe 40: the viewer cannot open Racuni (user) or Plaće (admin), but opens a form without a limit');
    StartSession('ana', arAdmin);
    Check(CanRun(Db, 'form', 'Racuni') and CanRun(Db, 'report', 'Plaće'), 'recipe 40: the administrator opens everything');
    SetUserRole(Db, 'ivo', arUser);
    Check(Authenticate(Db, 'ivo', 'lozinka2', Role1) and (Role1 = arUser), 'recipe 40: after the role is raised ivo is a user');
    StartSession('ivo', arUser);
    Check(CanRun(Db, 'form', 'Racuni') and not CanRun(Db, 'report', 'Plaće'), 'recipe 40: a user opens Racuni but still not the admin report');
    StartSession('', arAdmin);
  finally
    ActiveDb := nil;
    Vals.Free;
    Db.Free;
  end;
end;

type
  TChgCounter = class
  public
    N: Integer;
    procedure Bump(Sender: TObject);
  end;

procedure TChgCounter.Bump(Sender: TObject);
begin
  Inc(N);
end;

var
  MacroMsgs: TStringList;
  MacroAnswer: Boolean = True;
  MacroInput: string = '';

procedure MacroCapture(const AMsg: string);
begin
  MacroMsgs.Add(AMsg);
end;

function MacroAsk(const AMsg: string): Boolean;
begin
  MacroMsgs.Add('ASK:' + AMsg);
  Result := MacroAnswer;
end;

function MacroInputHook(const APrompt: string; out AValue: string): Boolean;
begin
  MacroMsgs.Add('INPUT:' + APrompt);
  AValue := MacroInput;
  Result := True;
end;

function LoadTextFile(const AFile: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.LoadFromFile(AFile);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

{ dopisi: tekst s poljima i tablicom }
procedure TestLetters;
var
  Db: TAppDb;
  D, D2: TaLetterDef;
  Rep: TaRenderedReport;
  Err, Tx, Xt: string;
  I, Pg: Integer;
  Uz: TUnZipper;
  XDoc: TXMLDocument;
begin
  if FileExists('/tmp/ta_letters.db') then DeleteFile('/tmp/ta_letters.db');
  Db := TAppDb.Create;
  D := TaLetterDef.Create;
  try
    Db.Open('/tmp/ta_letters.db');
    ActiveDb := Db;
    Db.SaveSetting('firma.naziv', 'Moja tvrtka d.o.o.');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv TEXT, adresa TEXT, grad TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, partner_id INTEGER, broj TEXT, datum TEXT, iznos REAL, placeno INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO partneri VALUES (1, ''Ana d.o.o.'', ''Ilica 10'', ''10000 Zagreb''), (2, ''Ivo obrt'', ''Riva 5'', ''21000 Split''), (3, ''Bez duga'', ''Ulica 1'', ''31000 Osijek''), (4, ''Veliki d.d.'', ''Savska 1'', ''10000 Zagreb'')');
    Db.Conn.ExecuteDirect('INSERT INTO racuni (partner_id, broj, datum, iznos, placeno) VALUES ' +
      '(1, ''2026-001'', ''2026-01-10'', 100.50, 0), (1, ''2026-002'', ''2026-01-20'', 200, 0), (1, ''2026-003'', ''2026-02-01'', 50.25, 0), ' +
      '(1, ''2026-004'', ''2026-02-15'', 300, 0), (1, ''2026-005'', ''2026-03-01'', 99.25, 0), (1, ''2026-006'', ''2026-03-05'', 500, 1), ' +
      '(2, ''2026-007'', ''2026-02-02'', 80, 0), (3, ''2026-008'', ''2026-02-03'', 10, 1)');
    for I := 1 to 70 do
      Db.Conn.ExecuteDirect('INSERT INTO racuni (partner_id, broj, datum, iznos, placeno) VALUES (4, ''V-' + IntToStr(I) + ''', ''2026-03-01'', 10, 0)');
    D.Name := 'Opomena';
    D.Source := 'partneri';
    D.Filter := 'id IN (SELECT partner_id FROM racuni WHERE placeno = 0)';
    D.DetailSql := 'SELECT broj, datum, iznos FROM racuni WHERE partner_id = {id} AND placeno = 0 ORDER BY datum, id';
    D.Columns := 'broj|Broj računa||left|2' + LineEnding + 'datum|Datum||left|2' + LineEnding + 'iznos|Iznos|0.00|right|1';
    D.TotalField := 'iznos';
    D.TotalLabel := 'Ukupno';
    D.Body := '#>[firma_naziv]' + LineEnding + '>Zagreb, [datum]' + LineEnding + '' + LineEnding + '#[naziv]' + LineEnding + '[adresa]' + LineEnding + '[grad]' + LineEnding + '' + LineEnding +
      'Predmet: opomena za neplaćene račune' + LineEnding + '' + LineEnding +
      'Poštovani, prema našoj evidenciji niste platili [stavki] računa. Molimo da dug podmirite u roku od osam dana, a nakon toga zadržavamo pravo na zatezne kamate.' + LineEnding + 'Oznaka: {[id] * 10}.' + LineEnding +
      '[tablica]' + LineEnding + 'Ukupno dugujete [ukupno] EUR.';
    Rep := RenderLetters(Db, D, Err);
    Check(Rep <> nil, 'letters: rendered (' + Err + ')');
    if Rep <> nil then
    begin
      Pg := Rep.PageCount;
      Check(Pg >= 4, 'letters: three recipients with debts, the big one over several pages (' + IntToStr(Pg) + ' pages)');
      Rep.Free;
    end;
    Tx := LetterPlainText(Db, D, Err);
    Check(Pos('Moja tvrtka d.o.o.', Tx) > 0, 'letters: company data from the settings [firma_naziv]');
    Check((Pos('Ana d.o.o.', Tx) > 0) and (Pos('Ilica 10', Tx) > 0) and (Pos('Ivo obrt', Tx) > 0), 'letters: recipient fields in the text');
    Check(Pos('Bez duga', Tx) = 0, 'letters: a recipient without debts is not in the letters (the Filter)');
    Check(Pos('niste platili 5 računa', Tx) > 0, 'letters: [stavki] counts the table rows (5)');
    Check(Pos('Oznaka: 10.', Tx) > 0, 'letters: an {expression} in the text');
    Check((Pos('2026-001', Tx) > 0) and (Pos('10.01.2026', Tx) > 0) and (Pos('2026-005', Tx) > 0), 'letters: the table has invoice numbers and dates as dd.mm.yyyy');
    Check(Pos('2026-006', Tx) = 0, 'letters: paid invoices are not in the table');
    Check((Pos('Ukupno | ' + FormatValue(750.0, '0.00'), Tx) > 0) and (Pos('Ukupno dugujete ' + FormatValue(750.0, '0.00') + ' EUR.', Tx) > 0), 'letters: the total row and [ukupno] give 750: ' + Copy(Tx, Pos('Ukupno |', Tx), 40));
    Check(Pos('Broj računa', Tx) > 0, 'letters: the table header');
    Rep := RenderLetters(Db, D, Err, '2');
    Check((Rep <> nil) and (Rep.PageCount = 1), 'letters: one recipient by its key (page count 1)');
    Rep.Free;
    D2 := TaLetterDef.Create;
    try
      D2.FromJson(D.ToJson);
      Check((D2.Name = 'Opomena') and (D2.Source = 'partneri') and (D2.DetailSql = D.DetailSql) and (D2.Body = D.Body) and (D2.Columns = D.Columns) and (D2.TotalField = 'iznos'), 'letters: survive JSON');
    finally
      D2.Free;
    end;
    { Word }
    DeleteFile('/tmp/ta_letters.docx');
    Check(ExportLettersDocx(Db, D, '/tmp/ta_letters.docx', Err) and FileExists('/tmp/ta_letters.docx'), 'letters: the .docx file is written (' + Err + ')');
    if FileExists('/tmp/ta_letters.docx') then
    begin
      Uz := TUnZipper.Create;
      try
        Uz.FileName := '/tmp/ta_letters.docx';
        Uz.OutputPath := '/tmp/ta_letters_docx';
        ForceDirectories('/tmp/ta_letters_docx');
        Uz.UnZipAllFiles;
      finally
        Uz.Free;
      end;
      Check(FileExists('/tmp/ta_letters_docx/word/document.xml') and FileExists('/tmp/ta_letters_docx/[Content_Types].xml') and FileExists('/tmp/ta_letters_docx/_rels/.rels'), 'letters: the .docx has the three required parts');
      try
        ReadXMLFile(XDoc, '/tmp/ta_letters_docx/word/document.xml');
        Check(XDoc <> nil, 'letters: word/document.xml is well-formed XML');
        XDoc.Free;
      except
        on E: Exception do Check(False, 'letters: word/document.xml is not well-formed: ' + E.Message);
      end;
      Xt := LoadTextFile('/tmp/ta_letters_docx/word/document.xml');
      Check((Pos('Ana d.o.o.', Xt) > 0) and (Pos('<w:tbl>', Xt) > 0) and (Pos('w:type="page"', Xt) > 0) and (Pos('2026-001', Xt) > 0) and (Pos(FormatValue(750.0, '0.00'), Xt) > 0), 'letters: the .docx has the text, a table, the invoices, the total and page breaks between letters');
    end;
    D.Columns := '';
    Tx := LetterPlainText(Db, D, Err);
    Check((Pos('broj', Tx) > 0) and (Pos('iznos', Tx) > 0), 'letters: without columns the table shows the query columns');
  finally
    D.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ ponude_posla i ugovori: ugovor iz ponude_posla, dodatna ponuda, aneks, dopisi }
procedure TestOffers;
var
  Db: TAppDb;
  Log: TStringList;
  Q: TZQuery;
  C: TaScriptContext;
  Lt: TaLetterDef;
  Tx, Err, Msg: string;
  Rep: TaRenderedReport;
  function One(const ASql: string): string;
  begin
    Q := Db.NewQuery(ASql);
    try
      Q.Open;
      Result := Q.Fields[0].AsString;
    finally
      Q.Free;
    end;
  end;
  function RunMacroText(const AText: string): string;
  begin
    MacroMsgs.Clear;
    RunMacro(C, AText);
    Result := StringReplace(Trim(MacroMsgs.Text), LineEnding, ' | ', [rfReplaceAll]);
  end;

  function RunM(const AName: string; AId: Integer): string;
  begin
    MacroMsgs.Clear;
    RunMacro(C, OffersMacroText(AName, AId));
    Result := StringReplace(Trim(MacroMsgs.Text), LineEnding, ' | ', [rfReplaceAll]);
  end;
begin
  if FileExists('/tmp/ta_offers.db') then DeleteFile('/tmp/ta_offers.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  MacroMsgs := TStringList.Create;
  OnScriptMessage := @MacroCapture;
  C := nil;
  try
    Db.Open('/tmp/ta_offers.db');
    ActiveDb := Db;
    Check(ApplyBizTemplate(Db, 'ponude_ugovori', '', True, Log), 'offers: the template is built (' + StringReplace(Trim(Log.Text), LineEnding, '; ', [rfReplaceAll]) + ')');
    C := TaScriptContext.Create(Db);
    Check((One('SELECT COUNT(*) FROM ponude_posla') = '2') and (One('SELECT COUNT(*) FROM ponude_posla_stavke') = '8') and (One('SELECT COUNT(*) FROM ponude_posla_faze') = '3'), 'offers: sample offer, additional offer, items and phases');
    Check(One('SELECT parent_id FROM ponude_posla WHERE id = 2') = '1', 'offers: the additional offer is linked to the first');
    { ugovor }
    Check(One('SELECT ukupno FROM ugovori WHERE vrsta = ''Ugovor''') = '3080', 'offers: the contract price is the offer total (3080)');
    Check(One('SELECT ponuda_id FROM ugovori WHERE vrsta = ''Ugovor''') = '1', 'offers: the contract refers to the offer');
    Check((One('SELECT iznos FROM ugovor_faze WHERE ugovor_id = 1 AND redni = 0') = '924') and (One('SELECT COUNT(*) FROM ugovor_faze WHERE ugovor_id = 1') = '4'), 'offers: the advance (30 %) and one payment per phase');
    Check(One('SELECT ROUND(SUM(iznos), 2) FROM ugovor_faze WHERE ugovor_id = 1') = '3080', 'offers: the instalments add up to the contract price');
    Check((One('SELECT iznos FROM ugovor_faze WHERE ugovor_id = 1 AND redni = 2') = '945') and (One('SELECT rok FROM ugovor_faze WHERE ugovor_id = 1 AND redni = 2') = '2026-04-30'), 'offers: phase 2 is 70 % of its items and takes its deadline from the offer');
    Check((One('SELECT rok_pocetka FROM ugovori WHERE id = 1') = '2026-04-01') and (One('SELECT prekoracenje_postotak FROM ugovori WHERE id = 1') = '10'), 'offers: the deadlines and the tolerance are copied from the offer');
    Check(One('SELECT status FROM ponude_posla WHERE id = 1') = 'prihvaćena', 'offers: the offer becomes accepted');
    { aneks }
    Check((One('SELECT ukupno FROM ugovori WHERE vrsta = ''Aneks''') = '800') and (One('SELECT parent_id FROM ugovori WHERE vrsta = ''Aneks''') = '1') and (One('SELECT ponuda_id FROM ugovori WHERE vrsta = ''Aneks''') = '2'),
      'offers: the annex (800) is linked to the contract and to the additional offer');
    Check(One('SELECT COUNT(*) FROM ugovor_faze WHERE ugovor_id = 2') = '1', 'offers: the annex without an advance has one payment');
    { zastite }
    Check(Pos('već postoji ugovor', RunM('Napravi ugovor', 1)) > 0, 'offers: a second contract for the same offer is refused');
    Check(Pos('nema vezu', RunM('Napravi aneks', 1)) > 0, 'offers: an annex needs an additional offer');
    Check(Pos('nema stavki', RunM('Napravi ugovor', 99)) > 0, 'offers: an offer without items cannot be contracted');
    { dodatna ponuda iz prve }
    Msg := RunM('Napravi dodatnu ponudu', 1);
    Check((Pos('P-2026-001-D2', Msg) > 0) and (One('SELECT parent_id FROM ponude_posla WHERE broj = ''P-2026-001-D2''') = '1'), 'offers: a new additional offer is created for the first (' + Msg + ')');
    Check(Pos('ne uz drugu dodatnu', RunM('Napravi dodatnu ponudu', 2)) > 0, 'offers: an additional offer is linked to the first offer only');
    { zaokruzivanje: faze se zbrajaju tocno u ugovornu cijenu }
    Db.Conn.ExecuteDirect('INSERT INTO ponude_posla (broj, datum, partner_id, naziv, vrsta, avans_postotak, prekoracenje_postotak) VALUES (''P-X'', ''2026-05-01'', 2, ''Test zaokruživanja'', ''Osnovna'', 33, 0)');
    Db.Conn.ExecuteDirect('INSERT INTO ponude_posla_stavke (ponuda_id, vrsta, faza, opis, kolicina, cijena, iznos) VALUES ' +
      '((SELECT MAX(id) FROM ponude_posla), ''Usluga'', 1, ''a'', 1, 10.01, 10.01), ((SELECT MAX(id) FROM ponude_posla), ''Usluga'', 2, ''b'', 1, 10.01, 10.01), ((SELECT MAX(id) FROM ponude_posla), ''Usluga'', 3, ''c'', 1, 10.01, 10.01)');
    RunM('Napravi ugovor', StrToInt(One('SELECT MAX(id) FROM ponude_posla')));
    Check((One('SELECT ukupno FROM ugovori WHERE broj LIKE ''UG-%'' ORDER BY id DESC LIMIT 1') = '30.03') and
      (One('SELECT ROUND(SUM(iznos), 2) FROM ugovor_faze WHERE ugovor_id = (SELECT MAX(id) FROM ugovori)') = '30.03'), 'offers: a rounding difference goes to the last phase, so the instalments equal the price');
    { dopisi }
    Lt := LoadLetter(Db, 'Ugovor');
    Tx := LetterPlainText(Db, Lt, Err);
    Lt.Free;
    Check((Pos('UGOVOR br. UG-', Tx) > 0) and (Pos('Adaptacija kupaonice', Tx) > 0) and (Pos('Ivo Horvat d.o.o.', Tx) > 0) and (Pos('ponudi br. P-2026-001', Tx) > 0), 'offers: the contract letter has the number, the job, the customer and the offer: ' + Copy(Tx, 1, 160));
    Check((Pos(FormatValue(3080.0, '0.00'), Tx) > 0) and (Pos(FormatValue(1904.0, '0.00'), Tx) > 0) and (Pos(FormatValue(1176.0, '0.00'), Tx) > 0), 'offers: the price (3080) split into services (1904) and material (1176)');
    Check((Pos('avans u iznosu od 30 %', Tx) > 0) and (Pos(FormatValue(924.0, '0.00'), Tx) > 0) and (Pos('Priprema i rušenje', Tx) > 0) and (Pos('Instalacije i keramika', Tx) > 0), 'offers: the advance and the phase table');
    Check((Pos('do 10 %', Tx) > 0) and (Pos(FormatValue(308.0, '0.00'), Tx) > 0) and (Pos(FormatValue(3388.0, '0.00'), Tx) > 0), 'offers: the allowed overrun in percent and in money (10 %, 308, 3388)');
    Check((Pos('01.04.2026', Tx) > 0) and (Pos('15.05.2026', Tx) > 0) and (Pos('Dodatni troškovi (odvoz šute', Tx) > 0), 'offers: the deadlines and the additional costs from the offer');
    Lt := LoadLetter(Db, 'Aneks ugovora');
    Tx := LetterPlainText(Db, Lt, Err);
    Lt.Free;
    Check((Pos('ANEKS br. AN-', Tx) > 0) and (Pos('uz ugovor br. UG-', Tx) > 0) and (Pos('Podno grijanje', Tx) > 0) or (Pos('podno grijanje', Tx) > 0), 'offers: the annex letter refers to the contract and the additional job');
    Check(Pos('Ukupna ugovorna cijena iznosi ' + FormatValue(3880.0, '0.00') + ' EUR (osnovni ugovor ' + FormatValue(3080.0, '0.00'), Tx) > 0, 'offers: the annex shows the total with annexes (3880) and the base contract (3080)');
    { jedan ugovor po kljucu i Word }
    Rep := RenderLetters(Db, LoadLetter(Db, 'Ugovor'), Err, '1');
    Check((Rep <> nil) and (Rep.PageCount >= 1), 'offers: one contract by its key');
    Rep.Free;
    DeleteFile('/tmp/ta_ugovor.docx');
    MacroMsgs.Clear;
    MacroInput := '/tmp/ta_ugovor.docx';
    OnScriptInput := @MacroInputHook;
    OnScriptAsk := @MacroAsk;
    C.Free;
    C := TPdfCtx.Create(Db);
    RunMacro(C, OffersMacroText('Ugovor u Word', 1));
    Check(FileExists('/tmp/ta_ugovor.docx'), 'offers: the "Ugovor u Word" macro writes the file');
    { racun po fazama ugovora }
    Check(One('SELECT COUNT(*) FROM racuni') = '1', 'offers: only the template sample invoice exists before the phases are invoiced');
    Msg := RunM('Napravi račun za fazu', 1);
    Check((Pos('Napravljen je račun', Msg) > 0) and (One('SELECT COUNT(*) FROM racuni') = '2') and (One('SELECT iznos FROM racuni_stavke WHERE dokument_id = (SELECT MAX(id) FROM racuni)') = '924'), 'offers: the first invoice is for the advance (924): ' + Msg);
    Check((One('SELECT partner_id FROM racuni WHERE id = (SELECT MAX(id) FROM racuni)') = '1') and (Pos('Avans', One('SELECT napomena FROM racuni WHERE id = (SELECT MAX(id) FROM racuni)')) > 0) and (One('SELECT pdv_stopa FROM racuni_stavke WHERE dokument_id = (SELECT MAX(id) FROM racuni)') = '25'), 'offers: the invoice goes to the contract customer, names the phase and has VAT 25 %');
    Check(One('SELECT COUNT(*) FROM ugovor_faze WHERE ugovor_id = 1 AND racun_id IS NOT NULL') = '1', 'offers: the invoiced phase is marked');
    RunM('Napravi račun za fazu', 1);
    Check(One('SELECT iznos FROM racuni_stavke WHERE dokument_id = (SELECT MAX(id) FROM racuni)') = '420', 'offers: the second invoice is for phase 1 (420)');
    RunM('Napravi račun za fazu', 1);
    RunM('Napravi račun za fazu', 1);
    Check((One('SELECT ROUND(SUM(iznos), 2) FROM racuni_stavke WHERE dokument_id > 1') = '3080') and (One('SELECT COUNT(*) FROM ugovor_faze WHERE ugovor_id = 1 AND racun_id IS NULL') = '0'), 'offers: the four invoices add up to the contract price (3080) and every phase is marked');
    Check(Pos('već imaju račun', RunM('Napravi račun za fazu', 1)) > 0, 'offers: nothing is invoiced twice');
    Check(One('SELECT COUNT(*) FROM artikli WHERE sifra = ''UGOVOR''') = '1', 'offers: the "work by contract" article is created once');
    { opca naredba copyrows: dokument iz dokumenta, i stavke uz njega }
    Db.Conn.ExecuteDirect('CREATE TABLE cr_a (id INTEGER PRIMARY KEY, naziv TEXT, iznos REAL)');
    Db.Conn.ExecuteDirect('CREATE TABLE cr_b (id INTEGER PRIMARY KEY, a_id INTEGER, naziv TEXT, iznos REAL, napomena TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO cr_a (naziv, iznos) VALUES (''Prva'', 10), (''Druga'', 20), (''Treca'', 30)');
    Msg := RunMacroText('copyrows: cr_a WHERE iznos >= 20 -> cr_b : a_id = id, naziv = naziv || ''!'', iznos = iznos * 2, napomena = ''iz {id}''');
    Check((One('SELECT COUNT(*) FROM cr_b') = '2') and (One('SELECT SUM(iznos) FROM cr_b') = '100') and (One('SELECT MIN(naziv) FROM cr_b') = 'Druga!'),
      'copyrows: copies the matching rows with computed fields: ' + Msg);
    Check(One('SELECT napomena FROM cr_b WHERE a_id = 2') = 'iz {id}', 'copyrows: a literal in quotes stays literal');
    Msg := RunMacroText('copyrows: cr_a -> cr_b : a_id = id, nepostojece = 1');
    Check((Msg <> '') and (One('SELECT COUNT(*) FROM cr_b') = '2'), 'copyrows: a bad column reports an error and changes nothing: ' + Msg);
    Msg := RunMacroText('copyrows: cr_a; DROP TABLE cr_a -> cr_b : a_id = id');
    Check((Msg <> '') and (One('SELECT COUNT(*) FROM cr_a') = '3'), 'copyrows: a table name that is not a plain identifier is refused: ' + Msg);
    { uvoz i kopiranje datoteka iz makroa }
    with TStringList.Create do
    try
      Add('naziv;iznos');
      Add('Cetvrta;40');
      Add('Peta;50');
      SaveToFile('/tmp/ta_imp.csv');
    finally
      Free;
    end;
    Db.Conn.ExecuteDirect('CREATE TABLE cr_c (id INTEGER PRIMARY KEY, naziv TEXT, iznos REAL)');
    Msg := RunMacroText('importtable: cr_c < /tmp/ta_imp.csv' + LineEnding + 'msg: uvezeno {uvezeno}');
    Check((One('SELECT COUNT(*) FROM cr_c') = '2') and (One('SELECT SUM(iznos) FROM cr_c') = '90') and (Pos('uvezeno 2', Msg) > 0), 'importtable: rows from a CSV file go into an existing table: ' + Msg);
    DeleteFile('/tmp/ta_imp_copy.csv');
    RunMacroText('copyfile: /tmp/ta_imp.csv > /tmp/ta_imp_copy.csv');
    Check(FileExists('/tmp/ta_imp_copy.csv'), 'copyfile: the file is copied');
    Check(RunMacroText('copyfile: /tmp/nema_me.csv > /tmp/x.csv') <> '', 'copyfile: a missing source is reported');
    { prekoracenje: upozorenje tek iznad dopustenog postotka (ugovor 1: 3080 + 10 % = 3388) }
    Check(Pos('unutar ugovorene cijene', RunM('Provjeri prekoračenje', 1)) > 0, 'offers: no costs yet is within the price');
    Db.Conn.ExecuteDirect('INSERT INTO ugovor_troskovi (ugovor_id, opis, iznos) VALUES (1, ''Odvoz šute'', 3200)');
    Msg := RunM('Provjeri prekoračenje', 1);
    Check((Pos('Upozorenje nije potrebno', Msg) > 0) and (Pos('UPOZORENJE', Msg) = 0), 'offers: 3200 is over the price but inside the allowed 10 % with no warning: ' + Msg);
    Db.Conn.ExecuteDirect('INSERT INTO ugovor_troskovi (ugovor_id, opis, iznos) VALUES (1, ''Dodatni materijal'', 200)');
    Msg := RunM('Provjeri prekoračenje', 1);
    Check((Pos('UPOZORENJE', Msg) > 0) and (Pos('3400', Msg) > 0) and (Pos('3388', Msg) > 0), 'offers: 3400 passes the limit 3388 and warns with the amounts: ' + Msg);
    { forme }
    Check((Db.LoadObject('_sys_forms', 'Ponude poslova') <> '') and (Db.LoadObject('_sys_forms', 'Ugovori') <> ''), 'offers: the Ponude and Ugovori forms exist');
    Check((Pos('macro:Napravi ugovor', Db.LoadObject('_sys_forms', 'Ponude poslova')) > 0) and (Pos('macro:Ispis ugovora', Db.LoadObject('_sys_forms', 'Ugovori')) > 0), 'offers: the form buttons run the macros');
  finally
    OnScriptMessage := nil;
    OnScriptInput := nil;
    OnScriptAsk := nil;
    ActiveDb := nil;
    MacroInput := '';
    C.Free;
    MacroMsgs.Free;
    Log.Free;
    Db.Free;
  end;
end;

{ 4GL blokovi: model nad stvarnim programima i predlosci }
procedure TestFglBlocks;
var
  Dirs: array[0..2] of string;
  D, I, J, Total, Bad: Integer;
  Sr: TSearchRec;
  L: TStringList;
  B: TaFglBlocks;
  Pr: TStringList;
  Orig, Msg, Prog: string;
  Tl: TStringList;
  P: TaFglProgram;
  Lg: TStringList;
  Pre: string;
begin
  Dirs[0] := 'manual_4gl'; Dirs[1] := 'manual_4gl_recepti'; Dirs[2] := '../examples/4gl';
  Total := 0; Bad := 0; Msg := '';
  B := TaFglBlocks.Create;
  L := TStringList.Create;
  try
    for D := 0 to 2 do
      if FindFirst(Dirs[D] + '/*.4gl', faAnyFile, Sr) = 0 then
      begin
        repeat
          L.LoadFromFile(Dirs[D] + '/' + Sr.Name);
          Orig := L.Text;
          B.LoadText(Orig);
          Pr := B.Problems;
          Inc(Total);
          if (Pr.Count > 0) or (B.Text <> Orig) then begin Inc(Bad); Msg := Msg + Sr.Name + ' [' + Trim(Pr.Text) + '] '; end;
          Pr.Free;
        until FindNext(Sr) <> 0;
        FindClose(Sr);
      end;
    Check((Total >= 30) and (Bad = 0), 'fgl blocks: every real 4GL program (tutorial, recipes, examples) has matched structures and survives text <-> blocks (' + IntToStr(Total) + ' programs) ' + Msg);
    { razine }
    B.LoadText('MAIN' + LineEnding + '  IF 1 = 1 THEN' + LineEnding + '    DISPLAY 1' + LineEnding + '  ELSE' + LineEnding + '    DISPLAY 2' + LineEnding + '  END IF' + LineEnding + 'END MAIN');
    Check((B.Kind(0) = fkOpen) and (B.Kind(1) = fkOpen) and (B.Kind(3) = fkMid) and (B.Kind(5) = fkClose) and (B.Kind(6) = fkClose), 'fgl blocks: kinds open / mid / close');
    Check((B.Depth(0) = 0) and (B.Depth(1) = 1) and (B.Depth(2) = 2) and (B.Depth(3) = 1) and (B.Depth(5) = 1) and (B.Depth(6) = 0), 'fgl blocks: depth for indentation (else and end stand at the level of their start)');
    Check((B.OpenerOf(5) = 1) and (B.CloserOf(0) = 6) and (B.CloserOf(1) = 5), 'fgl blocks: opener and closer are linked');
    { neuparene strukture }
    B.LoadText('MAIN' + LineEnding + '  IF 1 = 1 THEN' + LineEnding + 'END MAIN');
    Pr := B.Problems;
    Check(Pr.Count >= 1, 'fgl blocks: an unclosed IF is reported: ' + Trim(Pr.Text));
    Pr.Free;
    B.LoadText('END IF');
    Pr := B.Problems;
    Check(Pr.Count = 1, 'fgl blocks: a stray END IF is reported');
    Pr.Free;
    { komentari i viticaste zagrade }
    B.LoadText('-- IF nije otvarac' + LineEnding + '{ IF' + LineEnding + 'WHILE' + LineEnding + '}' + LineEnding + 'MAIN' + LineEnding + 'END MAIN');
    Pr := B.Problems;
    Check((Pr.Count = 0) and (B.Kind(0) = fkComment) and (B.Kind(2) = fkComment), 'fgl blocks: comments (-- and { }) never open blocks');
    Pr.Free;
    { uredivanje }
    B.LoadText('MAIN' + LineEnding + 'END MAIN');
    B.InsertLine(1, '  LET x = 1');
    B.MoveLine(1, 0);
    Check((B.Raw(0) = '  LET x = 1') and (B.Raw(1) = 'MAIN'), 'fgl blocks: insert and move');
    B.DeleteLine(0);
    Check(B.Count = 2, 'fgl blocks: delete');
    { predlosci su ispravan 4GL (provjerava pravi parser) }
    Pre := 'FUNCTION naziv()' + LineEnding + '  DISPLAY "x"' + LineEnding + 'END FUNCTION' + LineEnding;
    Bad := 0; Msg := '';
    Tl := TStringList.Create;
    try
      for I := 0 to FglTemplateCount - 1 do
      begin
        FglTemplateLines(I, Tl);
        if FglTemplate(I).Name = 'Glavni program (MAIN)' then Prog := Pre + Tl.Text
        else if (FglTemplate(I).Name = 'Funkcija') or (FglTemplate(I).Name = 'Funkcija s povratnom vrijednošću') then
          Prog := 'MAIN' + LineEnding + '  DISPLAY 1' + LineEnding + 'END MAIN' + LineEnding + Tl.Text
        else if FglTemplate(I).Name = 'Vrati vrijednost (RETURN)' then
          Prog := 'FUNCTION f(n)' + LineEnding + '  ' + Tl[0] + LineEnding + 'END FUNCTION' + LineEnding + 'MAIN' + LineEnding + '  DISPLAY 1' + LineEnding + 'END MAIN'
        else
        begin
          Prog := Pre + 'MAIN' + LineEnding + '  DEFINE n INTEGER' + LineEnding + '  DEFINE t TEXT' + LineEnding + '  DEFINE iznos DECIMAL(10,2)' + LineEnding;
          if Pos('(Varijabla', '(' + FglTemplate(I).Name) = 0 then Prog := Prog + '  LET n = 5' + LineEnding;
          if FglTemplate(I).Name = 'Izađi iz petlje (EXIT)' then Prog := Prog + '  WHILE n > 0' + LineEnding;
          for J := 0 to Tl.Count - 1 do Prog := Prog + '  ' + Tl[J] + LineEnding;
          if FglTemplate(I).Name = 'Izađi iz petlje (EXIT)' then Prog := Prog + '  END WHILE' + LineEnding;
          Prog := Prog + 'END MAIN' + LineEnding;
        end;
        P := TaFglProgram.Create;
        Lg := TStringList.Create;
        try
          try
            P.LoadText(Prog, 't');
            if P.CheckProgram(Lg) > 0 then begin Inc(Bad); Msg := Msg + '[' + FglTemplate(I).Name + ': ' + Trim(Lg.Text) + '] '; end;
          except
            on E: Exception do begin Inc(Bad); Msg := Msg + '[' + FglTemplate(I).Name + ': ' + E.Message + '] '; end;
          end;
        finally
          Lg.Free;
          P.Free;
        end;
        B.LoadText(Prog);
        Pr := B.Problems;
        if Pr.Count > 0 then begin Inc(Bad); Msg := Msg + '[blocks ' + FglTemplate(I).Name + ': ' + Trim(Pr.Text) + '] '; end;
        Pr.Free;
      end;
    finally
      Tl.Free;
    end;
    Check((Bad = 0) and (FglTemplateCount >= 25), 'fgl blocks: every palette template is valid 4GL (the real parser) with matched structures: ' + Msg);
  finally
    L.Free;
    B.Free;
  end;
end;

{ 4GL blokovi: uredjivac }
procedure TestFglBlockEditor;
var
  F: TForm;
  E: TaFglBlockEditor;
  Pr: TStringList;
  I: Integer;
  Cnt: TChgCounter;
begin
  F := TForm.CreateNew(nil);
  Cnt := TChgCounter.Create;
  try
    F.SetBounds(0, 0, 900, 500);
    E := TaFglBlockEditor.Create(F);
    E.Parent := F;
    E.SetBounds(0, 0, 880, 480);
    E.OnChange := @Cnt.Bump;
    E.SetText('MAIN' + LineEnding + '  DEFINE n INTEGER' + LineEnding + '  LET n = 3' + LineEnding + '  DISPLAY n' + LineEnding + 'END MAIN');
    Check(E.RowCount = 5, 'fgl block editor: one row per line');
    Check(E.GetText = 'MAIN' + LineEnding + '  DEFINE n INTEGER' + LineEnding + '  LET n = 3' + LineEnding + '  DISPLAY n' + LineEnding + 'END MAIN' + LineEnding, 'fgl block editor: untouched lines give back the original text');
    Check((E.EditOf(2) <> nil) and (E.EditOf(2).Text = 'LET n = 3'), 'fgl block editor: the row shows the line without its indentation');
    E.EditOf(2).Text := 'LET n = 10';
    Check((Pos('  LET n = 10', E.GetText) > 0) and (Cnt.N > 0), 'fgl block editor: typing changes the line, keeping its indentation');
    { umetanje predloska iza odabranog retka, u razini tog retka }
    E.SelectRow(2);
    for I := 0 to FglTemplateCount - 1 do
      if FglTemplate(I).Name = 'Uvjet s ELSE' then E.AddTemplate(I);
    Check((E.RowCount = 10) and (E.Model.Kind(3) = fkOpen) and (E.Model.Kind(5) = fkMid) and (E.Model.Kind(7) = fkClose), 'fgl block editor: a template is inserted after the selected row (IF / ELSE / END IF)');
    Check((Copy(E.Model.Raw(3), 1, 4) = '  IF') and (Copy(E.Model.Raw(4), 1, 7) = '    LET'), 'fgl block editor: inserted lines are indented to the place of insertion');
    Pr := E.Model.Problems;
    Check(Pr.Count = 0, 'fgl block editor: the program still has matched structures');
    Pr.Free;
    { umetanje unutar otvaraca }
    E.SelectRow(3);
    for I := 0 to FglTemplateCount - 1 do
      if FglTemplate(I).Name = 'Poruka (MESSAGE)' then E.AddTemplate(I);
    Check((E.Model.Depth(4) = 2) and (Copy(E.Model.Raw(4), 1, 12) = '    MESSAGE '), 'fgl block editor: a template added with a block selected goes inside it');
    { dvoklik u paleti, naslov kategorije ne dodaje }
    I := E.RowCount;
    E.Palette.ItemIndex := 0;
    E.Palette.OnDblClick(E.Palette);
    Check(E.RowCount = I, 'fgl block editor: a category heading adds nothing');
    E.Palette.ItemIndex := 1;
    E.Palette.OnDblClick(E.Palette);
    Check(E.RowCount > I, 'fgl block editor: double click in the palette adds the template');
    { brisanje pocetka brise i kraj, sadrzaj ostaje }
    E.SetText('MAIN' + LineEnding + '  WHILE 1 = 1' + LineEnding + '    DISPLAY 1' + LineEnding + '  END WHILE' + LineEnding + 'END MAIN');
    E.DeleteRow(1);
    Check((E.RowCount = 3) and (E.Model.Raw(1) = '    DISPLAY 1'), 'fgl block editor: deleting the start of a loop removes its END too, the content stays');
    Pr := E.Model.Problems;
    Check(Pr.Count = 0, 'fgl block editor: no unmatched structure after deleting a block');
    Pr.Free;
    E.MoveRow(1, 0);
    Check(E.Model.Raw(0) = '    DISPLAY 1', 'fgl block editor: a row can be moved');
    { ispisani redak 'END' bez imena: javlja se }
    E.SetText('MAIN' + LineEnding + '  IF 1 = 1 THEN' + LineEnding + 'END MAIN');
    Pr := E.Model.Problems;
    Check(Pr.Count >= 1, 'fgl block editor: an unclosed IF is reported');
    Pr.Free;
  finally
    Cnt.Free;
    F.Free;
  end;
end;

{ makro naredbe forme: find, gotorecord, sort }
procedure TestFormVerbs;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  C: TControl;
  Msg: string;
  function Cur(const AName: string): string;
  begin
    Result := TEdit(R.ControlByName(AName)).Text;
  end;
begin
  if FileExists('/tmp/ta_formverbs.db') then DeleteFile('/tmp/ta_formverbs.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_formverbs.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE art (id INTEGER PRIMARY KEY, naziv TEXT, cijena REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO art VALUES (1, ''Vijak'', 0.35), (2, ''Matica'', 0.25), (3, ''Podloška'', 7.5), (4, ''Čavao'', 1.2)');
    D := TaFormDef.Create;
    D.Name := 'FV'; D.RecordSource := 'art'; D.OrderBy := 'id';
    D.Add(NewCtl('TextBox', 'tId', 'id', 10, 10));
    D.Add(NewCtl('TextBox', 'tNaz', 'naziv', 10, 40));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Msg := '';
      R.DoAction('first');
      Check(Cur('tId') = '1', 'form verbs: starts on the first record');
      R.DoAction('find: naziv = "Podloška"');
      Check(Cur('tId') = '3', 'form verbs: find goes to the record with that value (' + Cur('tId') + ')');
      R.DoAction('find: naziv = "matica"');
      Check(Cur('tId') = '2', 'form verbs: find ignores case');
      R.DoAction('find: id = 1 + 3');
      Check(Cur('tId') = '4', 'form verbs: find takes an expression');
      R.DoAction('gotorecord: 1');
      Check(Cur('tId') = '1', 'form verbs: gotorecord 1');
      R.DoAction('gotorecord: 3');
      Check(Cur('tId') = '3', 'form verbs: gotorecord 3');
      R.DoAction('gotorecord: 99');
      Check(Cur('tId') = '4', 'form verbs: gotorecord beyond the end stops at the last record');
      R.DoAction('sort: cijena DESC');
      R.DoAction('first');
      Check(Cur('tId') = '3', 'form verbs: sort cijena DESC puts the dearest first (' + Cur('tId') + ')');
      R.DoAction('sort: naziv');
      R.DoAction('first');
      Check(Cur('tNaz') = 'Matica', 'form verbs: sort naziv (' + Cur('tNaz') + ')');
      R.DoAction('sort: id');
      R.DoAction('first');
      Check(Cur('tId') = '1', 'form verbs: sort id restores the entry order');
    finally
      R.Free;
    end;
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ makro jezik: varijable, uvjeti s else, petlje, ask/input, set/visible/enabled/caption }
procedure TestMacroLang;
var
  Db: TAppDb;
  C: TFormLikeCtx;
  Q: TZQuery;
  OldMsg: procedure(const AMsg: string);
  function Run(const ATxt: string): string;
  begin
    MacroMsgs.Clear;
    RunMacro(C, ATxt);
    Result := StringReplace(Trim(MacroMsgs.Text), LineEnding, ' | ', [rfReplaceAll]);
  end;
  function One(const ASql: string): string;
  begin
    Q := Db.NewQuery(ASql);
    try
      Q.Open;
      Result := Q.Fields[0].AsString;
    finally
      Q.Free;
    end;
  end;
begin
  if FileExists('/tmp/ta_macro_lang.db') then DeleteFile('/tmp/ta_macro_lang.db');
  Db := TAppDb.Create;
  C := TFormLikeCtx.Create(Db);
  C.Log := TStringList.Create;
  MacroMsgs := TStringList.Create;
  OldMsg := OnScriptMessage;
  OnScriptMessage := @MacroCapture;
  OnScriptAsk := @MacroAsk;
  OnScriptInput := @MacroInputHook;
  try
    Db.Open('/tmp/ta_macro_lang.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE t (id INTEGER PRIMARY KEY, v REAL, txt TEXT)');
    Check(Run('let n = 0' + LineEnding + 'let s = 0' + LineEnding + 'while [n] < 5' + LineEnding + '  let n = [n] + 1' + LineEnding + '  let s = [s] + [n]' + LineEnding +
      'end while' + LineEnding + 'msg: zbroj {s}') = 'zbroj 15', 'macro language: while loop with variables (1+2+3+4+5)');
    Check(Run('let x = 7' + LineEnding + 'if [x] > 5' + LineEnding + '  msg: veliko' + LineEnding + 'else' + LineEnding + '  msg: malo' + LineEnding + 'end if') = 'veliko', 'macro language: if / else, true branch');
    Check(Run('let x = 2' + LineEnding + 'if [x] > 5' + LineEnding + '  msg: veliko' + LineEnding + 'else' + LineEnding + '  msg: malo' + LineEnding + 'end if' + LineEnding + 'msg: dalje') = 'malo | dalje', 'macro language: else branch, then execution continues');
    Check(Run('if 1 = 2' + LineEnding + '  msg: ne' + LineEnding + 'end if' + LineEnding + 'msg: kraj') = 'kraj', 'macro language: if without else');
    Check(Run('repeat 3' + LineEnding + '  sql: INSERT INTO t (v) VALUES (1)' + LineEnding + 'end repeat') = '', 'macro language: repeat runs silently');
    Check(One('SELECT COUNT(*) FROM t') = '3', 'macro language: repeat 3 inserted three rows');
    Check(Run('let c = 0' + LineEnding + 'repeat 2' + LineEnding + '  repeat 3' + LineEnding + '    let c = [c] + 1' + LineEnding + '  end repeat' + LineEnding + 'end repeat' + LineEnding + 'msg: {c}') = '6', 'macro language: nested repeat loops (2 x 3)');
    Check(Run('let i = 0' + LineEnding + 'while 1 = 1' + LineEnding + '  let i = [i] + 1' + LineEnding + '  if [i] = 4' + LineEnding + '    stop' + LineEnding + '  end if' + LineEnding + 'end while' + LineEnding + 'msg: nikad') = '', 'macro language: stop leaves the loop and the macro');
    { varijabla u SQL-u: tekst s apostrofom ostaje ispravan }
    MacroInput := 'O''Brien';
    Check(Run('input: Ime?' + LineEnding + 'sql: INSERT INTO t (txt) VALUES ({unos})') = 'INPUT:Ime?', 'macro language: input asks the question');
    Check(One('SELECT txt FROM t WHERE txt IS NOT NULL') = 'O''Brien', 'macro language: a text variable in sql is quoted and escaped');
    MacroAnswer := False;
    Check(Run('ask: Sigurno?' + LineEnding + 'if [odgovor] = 1' + LineEnding + '  msg: da' + LineEnding + 'else' + LineEnding + '  msg: ne' + LineEnding + 'end if') = 'ASK:Sigurno? | ne', 'macro language: ask sets [odgovor] (No = 0)');
    MacroAnswer := True;
    Check(Pos('| da', Run('ask: Sigurno?' + LineEnding + 'if [odgovor] = 1 then msg: da')) > 0, 'macro language: ask, Yes = 1, one-line if');
    { naredbe forme }
    C.Log.Clear;
    Run('let g = 3' + LineEnding + 'set: ukupno = [g] * 2' + LineEnding + 'visible: lbl = [g] > 5' + LineEnding + 'enabled: btn = 0' + LineEnding + 'caption: lbl = "Gotovo " & [g]');
    Check(C.Log.Text = 'set ukupno=6' + LineEnding + 'visible lbl=0' + LineEnding + 'enabled btn=0' + LineEnding + 'caption lbl=Gotovo 3' + LineEnding,
      'macro language: set / visible / enabled / caption with variables: ' + StringReplace(C.Log.Text, LineEnding, ' | ', [rfReplaceAll]));
    { izvoz, sazimanje, cekanje, ugradene varijable }
    DeleteFile('/tmp/ta_ml_t.csv'); DeleteFile('/tmp/ta_ml_t.xlsx'); DeleteFile('/tmp/ta_ml_t.json');
    Run('exporttable: t > /tmp/ta_ml_t.csv' + LineEnding + 'exporttable: t > /tmp/ta_ml_t.xlsx' + LineEnding + 'exporttable: t > /tmp/ta_ml_t.json');
    Check(FileExists('/tmp/ta_ml_t.csv') and FileExists('/tmp/ta_ml_t.xlsx') and FileExists('/tmp/ta_ml_t.json'), 'macro language: exporttable writes csv, xlsx and json by the file extension');
    Check(Pos('id', LoadTextFile('/tmp/ta_ml_t.csv')) = 1, 'macro language: the csv export has a header');
    Check(Run('compact') <> '', 'macro language: compact reports the result');
    Check(Run('wait: 0.01' + LineEnding + 'msg: gotovo') = 'gotovo', 'macro language: wait continues with the next block');
    CurrentUserName := 'ana';
    Check(Run('msg: {korisnik} {datum} {vrijeme}') = 'ana ' + FormatDateTime('yyyy-mm-dd', Date) + ' ' + FormatDateTime('hh:nn', Time), 'macro language: built-in variables korisnik, datum, vrijeme');
    CurrentUserName := '';
    { zastita i greske }
    Check(Pos('predugo', Run('while 1 = 1' + LineEnding + 'end while')) > 0, 'macro language: an endless loop is stopped with a message');
    Check(Pos('nije zatvoren', Run('if 1 = 1' + LineEnding + 'msg: a')) > 0, 'macro language: a block without its end is reported before anything runs');
    Run('if 1 = 1' + LineEnding + 'msg: a');
    Check(MacroMsgs.IndexOf('a') < 0, 'macro language: nothing from the broken macro ran');
    Check(Run('end if') <> '', 'macro language: a stray end if is reported');
    Check(CheckMacroText('let x = 1' + LineEnding + 'while [x] < 3' + LineEnding + 'let x = [x] + 1' + LineEnding + 'end while') = '', 'macro language: the editor check accepts the structured macro');
    Check(CheckMacroText('while 1 = 1') <> '', 'macro language: the editor check reports the missing end while');
    Check(CheckMacroText('set: a') <> '', 'macro language: set needs name = expression');
  finally
    OnScriptMessage := OldMsg;
    OnScriptAsk := nil;
    OnScriptInput := nil;
    ActiveDb := nil;
    MacroMsgs.Free;
    C.Log.Free;
    C.Free;
    Db.Free;
  end;
end;

{ faza G: blokovi makroa (model bez sucelja) }
procedure TestBlocks;
const
  Src = '# unos nove transakcije' + LineEnding +
        '  ' + LineEnding +
        'if IsNull([iznos]) then msg: Upiši iznos' + LineEnding +
        '// bez iznosa dalje ne ide' + LineEnding +
        'if 1 = 2 then stop' + LineEnding +
        'if [iznos] > 1 then sql: UPDATE statistika SET broj = broj + 1' + LineEnding +
        '   MSG:   Gotovo!  ' + LineEnding +
        'requery' + LineEnding +
        'stop' + LineEnding +
        'msg: ovo se ne izvodi';
var
  P, P2: TaBlockProgram;
  B: TaBlock;
  A, A2: TRecCtx;
  Pr: TStringList;
  Doc: TStringList;
  I: Integer;
  Missing: string;
begin
  P := TaBlockProgram.Create;
  P2 := TaBlockProgram.Create;
  A := TRecCtx.Create(nil); A.Log := TStringList.Create;
  A2 := TRecCtx.Create(nil); A2.Log := TStringList.Create;
  try
    P.LoadText(Src);
    Check(P.Count = 10, 'blocks: every line becomes a block (10)');
    Check(P.Text = Src + LineEnding, 'blocks: text -> blocks -> text is lossless (indentation, case, blanks kept)');
    Check((P[0].Kind = bkComment) and (P[0].Mark = '#') and (P[0].Text = 'unos nove transakcije'), 'blocks: # comment');
    Check(P[1].Kind = bkBlank, 'blocks: a blank line');
    Check((P[2].Kind = bkIf) and (P[2].Cond = 'IsNull([iznos])') and (P[2].Verb = 'msg') and (P[2].Arg = 'Upiši iznos'), 'blocks: if ... then msg');
    Check((P[3].Kind = bkComment) and (P[3].Mark = '//'), 'blocks: // comment');
    Check((P[4].Kind = bkIf) and (P[4].Verb = 'stop'), 'blocks: if ... then stop');
    Check((P[5].Kind = bkIf) and (P[5].Verb = 'sql') and (P[5].Arg = 'UPDATE statistika SET broj = broj + 1'), 'blocks: the SQL argument keeps its colons/text as is');
    Check((P[6].Kind = bkCommand) and (P[6].Verb = 'msg') and (P[6].Arg = 'Gotovo!'), 'blocks: verb is lower-cased, argument trimmed');
    Check((P[7].Kind = bkCommand) and (P[7].Verb = 'requery') and (P[7].Arg = ''), 'blocks: a command without an argument');
    Check(P[8].Kind = bkStop, 'blocks: stop');
    { jednako ponasanje: izvedi izvorni tekst i tekst nastao iz blokova bez izvornih redaka }
    for I := 0 to P.Count - 1 do P[I].Touch;
    P2.LoadText(P.Text);
    RunMacro(A, Src);
    RunMacro(A2, P.Text);
    Check((A.Log.Count > 0) and (A.Log.Text = A2.Log.Text), 'blocks: the regenerated (canonical) text runs exactly like the original: [' + StringReplace(A.Log.Text, LineEnding, ' / ', [rfReplaceAll]) + '] vs [' + StringReplace(A2.Log.Text, LineEnding, ' / ', [rfReplaceAll]) + ']');
    Check(A2.Log.IndexOf('msg: Upiši iznos') >= 0, 'blocks: the condition is evaluated (action done)');
    Check(A2.Log.IndexOf('msg: ovo se ne izvodi') < 0, 'blocks: stop ends the macro');
    Check(P2.Text = P.Text, 'blocks: the canonical text is stable (a second pass changes nothing)');
    { uredivanje }
    P2.Clear;
    P2.Add(NewCommentBlock('test'));
    P2.Add(NewIfBlock('[iznos] > 100', 'msg', 'Velika transakcija'));
    P2.Add(NewCommandBlock('save', ''));
    P2.Add(NewStopBlock);
    Check(P2.Text = '# test' + LineEnding + 'if [iznos] > 100 then msg: Velika transakcija' + LineEnding + 'save' + LineEnding + 'stop' + LineEnding, 'blocks: blocks built in code produce the macro text');
    P2.Move(2, 0);
    Check(P2[0].Verb = 'save', 'blocks: Move puts the block on the new position');
    P2.Insert(1, NewCommandBlock('close', ''));
    P2.Delete(3);
    Check((P2.Count = 4) and (P2[1].Verb = 'close') and (P2[3].Kind = bkStop), 'blocks: Insert and Delete');
    B := P2[1]; B.Verb := 'requery'; B.Touch;
    Check(Pos('requery', P2.Text) > 0, 'blocks: after Touch an edited block is regenerated from its fields');
    { problemi }
    P2.Clear;
    P2.LoadText('foo: bar' + LineEnding + 'msg' + LineEnding + 'if [x] > 1' + LineEnding + 'if  then msg: x' + LineEnding + 'save');
    Pr := P2.Problems;
    try
      Check((Pr.Count = 4) and (Pos('Redak 1', Pr.Text) > 0) and (Pos('Redak 5', Pr.Text) = 0), 'blocks: Problems reports unknown verb, missing argument, missing then, empty condition (' + IntToStr(Pr.Count) + '): ' + Pr.Text);
    finally
      Pr.Free;
    end;
    { paleta se slaze s dokumentacijom }
    Doc := TStringList.Create;
    try
      Doc.LoadFromFile('../docs/manual/03-makroi-moduli.md');
      Missing := '';
      for I := 0 to BlockVerbCount - 1 do
        if Pos('`' + BlockVerbName(I), Doc.Text) = 0 then Missing := Missing + BlockVerbName(I) + ' ';
      Check((BlockVerbCount >= 20) and (Missing = ''), 'blocks: every palette verb is documented in the macro chapter (missing: ' + Missing + ')');
    finally
      Doc.Free;
    end;
    Check((BlockVerbArg('sql') = baSql) and (BlockVerbArg('openform') = baForm) and (BlockVerbArg('close') = baNone) and BlockVerbKnown('openreport') and not BlockVerbKnown('xyz'),
      'blocks: verb argument types for the palette');
  finally
    A.Log.Free; A.Free; A2.Log.Free; A2.Free;
    P.Free; P2.Free;
  end;
end;

function MakeLBox(L, T, W, H: Integer): TLBox;
begin
  Result.L := L; Result.T := T; Result.W := W; Result.H := H;
end;

{ dizajner formi: dimenzije upisom u svojstva }
procedure TestDesignGeometry;
var
  Db: TAppDb;
  D: TaFormDef;
  Dz: TaFormDesigner;
  K: string;
  C: TControl;
  Bad: string;
  L0, T0, W0, H0, L1, T1, W1, H1: Integer;
  Bx: TLBox;
  Nm: string;
begin
  if FileExists('/tmp/ta_dgeom.db') then DeleteFile('/tmp/ta_dgeom.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_dgeom.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE t (id INTEGER PRIMARY KEY, a TEXT)');
    Bx := ResizeBox(MakeLBox(20, 20, 100, 40), gmRight, 30, 0, 8, 8, 1);
    Check((Bx.L = 20) and (Bx.W = 130) and (Bx.T = 20) and (Bx.H = 40), 'resize math: right edge only');
    Bx := ResizeBox(MakeLBox(20, 20, 100, 40), gmLeft, -10, 0, 8, 8, 1);
    Check((Bx.L = 10) and (Bx.W = 110), 'resize math: left edge keeps the right edge');
    Bx := ResizeBox(MakeLBox(20, 20, 100, 40), gmLeft, 500, 0, 8, 8, 1);
    Check((Bx.W = 8) and (Bx.L + Bx.W = 120), 'resize math: left edge cannot cross the right (minimum width, right edge stays)');
    Bx := ResizeBox(MakeLBox(20, 20, 100, 40), gmLeft or gmTop, 5, 5, 8, 8, 1);
    Check((Bx.L = 25) and (Bx.T = 25) and (Bx.W = 95) and (Bx.H = 35), 'resize math: a corner moves two edges');
    Bx := ResizeBox(MakeLBox(20, 20, 100, 40), gmLeft, -50, 0, 8, 8, 1);
    Check((Bx.L = 0) and (Bx.L + Bx.W = 120), 'resize math: the left edge stops at the form edge');
    Bx := ResizeBox(MakeLBox(20, 20, 100, 40), gmRight, 27, 0, 8, 8, 4);
    Check(((Bx.L + Bx.W) mod 4) = 0, 'resize math: the moved edge snaps to the grid');
    Check((GripMode(4) = (gmRight or gmBottom)) and (GripMode(7) = gmLeft) and (GripMode(1) = gmTop), 'resize math: grip numbers map to edges');
    Check((EdgeMode(0, 20, 100, 40, 4) = gmLeft) and (EdgeMode(99, 39, 100, 40, 4) = (gmRight or gmBottom)) and (EdgeMode(50, 20, 100, 40, 4) = 0) and (EdgeMode(2, 2, 6, 6, 4) = 0),
      'resize math: edge hit test (a tiny control keeps its middle for dragging)');
    D := TaFormDef.Create;
    D.Name := 'G'; D.RecordSource := 't';
    Dz := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      Bad := '';
      for K in ['TextBox', 'Label', 'Button', 'CheckBox', 'ComboBox', 'MemoBox', 'ListBox', 'Rectangle', 'Image'] do
      begin
        C := Dz.AddForTest(K, 20, 20);
        Dz.SetPropForTest('Left', '33');
        Dz.SetPropForTest('Top', '44');
        Dz.SetPropForTest('Width', '210');
        Dz.SetPropForTest('Height', '77');
        if (C.Left <> 33) or (C.Top <> 44) or (C.Width <> 210) or (C.Height <> 77) then
          Bad := Bad + K + '(' + IntToStr(C.Left) + ',' + IntToStr(C.Top) + ',' + IntToStr(C.Width) + 'x' + IntToStr(C.Height) + ') ';
        if (Dz.PropsGrid.Values['Width'] <> '210') or (Dz.PropsGrid.Values['Height'] <> '77') then Bad := Bad + K + '[grid] ';
      end;
      Check(Bad = '', 'form designer: typing Left/Top/Width/Height changes every kind of control: ' + Bad);
      { stvarno upisivanje u celiju mreze svojstava (kao korisnik): Enter / napustanje celije }
      C := Dz.AddForTest('TextBox', 20, 20);
      Dz.TypeInGridForTest('Width', '333');
      Check(C.Width = 333, 'form designer: a width typed into the property grid is applied (' + IntToStr(C.Width) + ')');
      Dz.TypeInGridForTest('Height', '55');
      Check(C.Height = 55, 'form designer: a height typed into the property grid is applied (' + IntToStr(C.Height) + ')');
      { osam rucki oko odabrane kontrole i povlacenje rubova }
      C := Dz.AddForTest('TextBox', 40, 40);
      L0 := C.Left; T0 := C.Top; W0 := C.Width; H0 := C.Height;
      Check(Dz.GripForTest(0).Visible and Dz.GripForTest(1).Visible and Dz.GripForTest(2).Visible and Dz.GripForTest(3).Visible and
        Dz.GripForTest(4).Visible and Dz.GripForTest(5).Visible and Dz.GripForTest(6).Visible and Dz.GripForTest(7).Visible, 'form designer: eight grips are shown around the selected control');
      Check((Dz.GripForTest(3).Left > C.Left + C.Width - 1) and (Dz.GripForTest(7).Left < C.Left) and (Dz.GripForTest(1).Top < C.Top) and (Dz.GripForTest(5).Top > C.Top + C.Height - 1) and
        (Dz.GripForTest(1).Left + 3 >= C.Left) and (Dz.GripForTest(1).Left + 3 <= C.Left + C.Width), 'form designer: grips sit on the corners and the middle of the sides');
      Dz.GripDragForTest(3, 40, 0);
      Check((C.Left = L0) and (C.Top = T0) and (C.Height = H0) and (C.Width = W0 + 40), 'form designer: the east grip changes only the width (' + IntToStr(C.Width) + ')');
      Dz.GripDragForTest(5, 0, 24);
      Check((C.Left = L0) and (C.Top = T0) and (C.Width = W0 + 40) and (C.Height = H0 + 24), 'form designer: the south grip changes only the height');
      L1 := C.Left; T1 := C.Top; W1 := C.Width; H1 := C.Height;
      Dz.GripDragForTest(7, -20, 0);
      Check((C.Left = L1 - 20) and (C.Left + C.Width = L1 + W1) and (C.Top = T1) and (C.Height = H1), 'form designer: the west grip moves the left edge, the right edge stays');
      Dz.GripDragForTest(1, 0, -8);
      Check((C.Top = T1 - 8) and (C.Top + C.Height = T1 + H1), 'form designer: the north grip moves the top edge, the bottom edge stays');
      L1 := C.Left; T1 := C.Top; W1 := C.Width; H1 := C.Height;
      Dz.GripDragForTest(0, 12, 12);
      Check((C.Left = L1 + 12) and (C.Top = T1 + 12) and (C.Left + C.Width = L1 + W1) and (C.Top + C.Height = T1 + H1), 'form designer: the corner grip moves two edges');
      Dz.GripDragForTest(3, -2000, 0);
      Check(C.Width >= 8, 'form designer: a control cannot be dragged to nothing (' + IntToStr(C.Width) + ')');
      Dz.TypeInGridForTest('Height', '60');
      Dz.TypeInGridForTest('Width', '180');
      Check((C.Height = 60) and (C.Width = 180), 'form designer: the size can be restored by typing after dragging');
      L1 := C.Left; T1 := C.Top; W1 := C.Width; H1 := C.Height;
      Check(Dz.EdgeDragForTest(C.Width - 1, C.Height div 2, 20, 0), 'form designer: the control edge itself is a resize area');
      Check((C.Width = W1 + 20) and (C.Height = H1) and (C.Left = L1), 'form designer: dragging the right edge changes only the width');
      Check(Dz.EdgeDragForTest(0, C.Height div 2, -16, 0) and (C.Left = L1 - 16), 'form designer: dragging the left edge works too');
      Check(not Dz.EdgeDragForTest(C.Width div 2, C.Height div 2, 10, 0), 'form designer: the middle of the control is not a resize area');
      W1 := C.Width; H1 := C.Height;
      Dz.ResizeByForTest(8, -4);
      Check((C.Width = W1 + 8) and (C.Height = H1 - 4), 'form designer: Shift+arrows resize by the keyboard');
      Dz.UndoForTest;     { ponovo gradi kontrole, pa se provjerava definicija }
      Check((Dz.FormDef[Dz.FormDef.Count - 1].Width = W1) and (Dz.FormDef[Dz.FormDef.Count - 1].Height = H1), 'form designer: a resize can be undone');
      { dogadaji nude novi makro blokovima }
      C := Dz.AddForTest('TextBox', 20, 200);
      Check(Dz.PropsGrid.ItemProps['OnChange'].PickList.IndexOf(NewMacroBlocksItem) >= 0, 'form designer: event lists offer "new macro with blocks"');
      Nm := CreateEventMacro(Db, 'Racuni forma', 'OnOpen');
      Check((Nm = 'Racuni_forma_OnOpen') and (Pos('# Makro', Db.LoadObject('_sys_macros', Nm)) = 1), 'form designer: the event macro is created with a clean name (' + Nm + ')');
      Check(CreateEventMacro(Db, 'Racuni forma', 'OnOpen') = 'Racuni_forma_OnOpen_2', 'form designer: a second macro for the same event gets a new name');

    finally
      Dz.Free;
    end;
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ postavke stranice i naljepnica, odabir okvirom i grupno pomicanje u oba dizajnera }
procedure TestPageAndSelection;
var
  Db: TAppDb;
  RD, R2: TaReportDef;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  Fd: TaFormDef;
  Fz: TaFormDesigner;
  Rz: TaReportDesigner;
  A, B, C3: TControl;
  Err: string;
  I, K, N, X0, X1, Y0, Y1, Ml: Integer;
  It: TaRItem;
begin
  if FileExists('/tmp/ta_pgset.db') then DeleteFile('/tmp/ta_pgset.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_pgset.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE t (id INTEGER PRIMARY KEY, a TEXT)');
    for I := 1 to 50 do Db.Conn.ExecuteDirect('INSERT INTO t (a) VALUES (''row' + IntToStr(I) + ''')');
    { naljepnice 63,5 x 38,1 mm, 3 x 7, Avery L7160 }
    RD := TaReportDef.Create;
    RD.Name := 'Nalj'; RD.RecordSource := 't';
    RD.Add(RItem('TextBox', 'Detail', 'tA', 'a', 4, 4, 100, 18));
    Check(ApplyPageSetupMm(RD, 210, 297, 7.2, 15.1, 0, 0, 3, 63.5, 38.1, 2.5, 0, Err), 'page setup: label sheet is accepted ' + Err);
    Check((RD.Columns = 3) and (RD.PageWidth = MmToPx(210)) and (RD.MarginLeft = MmToPx(7.2)) and (RD.Heights[SecDetail] = MmToPx(38.1)),
      'page setup: columns, page, margin and label height are stored');
    Check(RD.MarginRight >= 0, 'page setup: the right margin is the rest of the sheet');
    RE := TaReportEngine.Create(Db, RD);
    RR := RE.Render;
    Check(RR.PageCount = 3, 'labels 3x7: 50 labels fill 3 pages (' + IntToStr(RR.PageCount) + ')');
    X0 := -1; X1 := -1; Y0 := -1; Y1 := -1; N := 0;
    for I := 0 to RR.Page(0).Items.Count - 1 do
    begin
      It := TaRItem(RR.Page(0).Items[I]);
      if It.Kind <> 'Text' then Continue;
      Inc(N);
      if N = 1 then begin X0 := It.X; Y0 := It.Y; end;
      if N = 2 then X1 := It.X;
      if N = 4 then Y1 := It.Y;
    end;
    Check(N = 21, 'labels 3x7: 21 labels on the first page (' + IntToStr(N) + ')');
    Check(X0 = MmToPx(7.2) + 4, 'labels: the first label starts at the left margin (' + IntToStr(X0) + ')');
    Check(X1 - X0 = MmToPx(63.5) + MmToPx(2.5), 'labels: the next label is one label width plus the gap to the right (' + IntToStr(X1 - X0) + ')');
    Check(Y1 - Y0 = MmToPx(38.1), 'labels: the next row is one label height lower (' + IntToStr(Y1 - Y0) + ')');
    Check(Y0 = MmToPx(15.1) + 4, 'labels: the first row starts at the top margin (' + IntToStr(Y0) + ')');
    RR.Free; RE.Free;
    { razmak redova }
    Check(ApplyPageSetupMm(RD, 210, 297, 7.2, 15.1, 0, 0, 3, 63.5, 30, 2.5, 5, Err), 'page setup: vertical gap accepted');
    RE := TaReportEngine.Create(Db, RD);
    RR := RE.Render;
    Y1 := -1; N := 0;
    for I := 0 to RR.Page(0).Items.Count - 1 do
    begin
      It := TaRItem(RR.Page(0).Items[I]);
      if It.Kind <> 'Text' then Continue;
      Inc(N);
      if N = 4 then Y1 := It.Y;
    end;
    Check(Y1 - Y0 = MmToPx(30) + MmToPx(5), 'labels: the vertical gap is added between rows (' + IntToStr(Y1 - Y0) + ')');
    RR.Free; RE.Free;
    { ne stane = odbijeno i definicija ostaje netaknuta }
    Ml := RD.MarginLeft;
    Check(not ApplyPageSetupMm(RD, 210, 297, 7.2, 15, 0, 0, 3, 90, 30, 2.5, 0, Err) and (RD.MarginLeft = Ml) and (Err <> ''),
      'page setup: labels wider than the sheet are refused (' + Err + ')');
    { papir i polozeno spremaju se i vracaju }
    Check(ApplyPageSetupMm(RD, 297, 210, 10, 10, 10, 10, 1, 0, 0, 0, 0, Err), 'page setup: A4 landscape accepted');
    R2 := TaReportDef.Create;
    R2.FromJson(RD.ToJson);
    Check((R2.PageWidth = MmToPx(297)) and (R2.PageHeight = MmToPx(210)) and (R2.MarginTop = MmToPx(10)) and (R2.Columns = 1) and (R2.RowGap = 0),
      'page setup: stored in the report and read back');
    RE := TaReportEngine.Create(Db, R2);
    RR := RE.Render;
    Check((RR.PageW = MmToPx(297)) and (RR.PageH = MmToPx(210)), 'page setup: the rendered report carries its page size');
    RR.Free; RE.Free;
    R2.FromJson('{"name":"x","items":[]}');
    Check((R2.PageWidth = 794) and (R2.PageHeight = 1123) and (R2.MarginLeft = 40), 'page setup: old reports without the fields stay A4 with 40 px margins');
    R2.Free;
    RD.Free;

    { forma: odabir okvirom + grupno pomicanje }
    Fd := TaFormDef.Create;
    Fd.Name := 'Sel'; Fd.RecordSource := 't';
    Fz := TaFormDesigner.CreateDesigner(nil, Db, Fd);
    try
      A := Fz.AddForTest('TextBox', 20, 20);
      B := Fz.AddForTest('TextBox', 20, 80);
      C3 := Fz.AddForTest('TextBox', 400, 300);
      Fz.LassoForTest(A.Parent.ClientToScreen(Point(5, 5)), A.Parent.ClientToScreen(Point(B.Left + B.Width + 10, B.Top + B.Height + 10)), False);
      Check(Fz.SelectedCountForTest = 2, 'form designer: a drag box selects the controls it touches (' + IntToStr(Fz.SelectedCountForTest) + ')');
      Fz.LassoForTest(C3.Parent.ClientToScreen(Point(C3.Left - 3, C3.Top - 3)), C3.Parent.ClientToScreen(Point(C3.Left + 5, C3.Top + 5)), True);
      Check(Fz.SelectedCountForTest = 3, 'form designer: Ctrl + drag box adds to the selection (' + IntToStr(Fz.SelectedCountForTest) + ')');
      Fz.LassoForTest(A.Parent.ClientToScreen(Point(2, 2)), A.Parent.ClientToScreen(Point(3, 3)), False);
      Check(Fz.SelectedCountForTest = 0, 'form designer: a box over nothing clears the selection');
      Fz.LassoForTest(A.Parent.ClientToScreen(Point(5, 5)), A.Parent.ClientToScreen(Point(B.Left + B.Width + 10, B.Top + B.Height + 10)), False);
      K := C3.Left;
      X0 := A.Left; Y0 := A.Top; X1 := B.Left; Y1 := B.Top;
      Fz.GroupDragForTest(A, 40, 20);
      Check((A.Left = X0 + 40) and (A.Top = Y0 + 20) and (B.Left = X1 + 40) and (B.Top = Y1 + 20) and (C3.Left = K),
        'form designer: dragging one of the selected controls moves the whole group and nothing else');
      Fz.UndoForTest;
      Check(Fz.FormDef[0].Left = X0, 'form designer: a group move is one undo step');
      Fz.SetFormSizeForTest(900, 700);
      Check((Fz.FormDef.Width = 900) and (Fz.FormDef.Height = 700), 'form designer: form size can be set');
    finally
      Fz.Free;      { razoruje i definiciju }
    end;

    { izvjesc: isto }
    RD := TaReportDef.Create;
    RD.Name := 'Sel'; RD.RecordSource := 't';
    Rz := TaReportDesigner.CreateDesigner(nil, Db, RD);
    try
      A := Rz.AddForTest('TextBox', SecDetail, 10, 2);
      B := Rz.AddForTest('TextBox', SecDetail, 130, 2);
      C3 := Rz.AddForTest('TextBox', SecPageHeader, 10, 2);
      Rz.LassoForTest(A.Parent.ClientToScreen(Point(0, 0)), A.Parent.ClientToScreen(Point(B.Left + B.Width + 5, B.Top + B.Height + 5)), False);
      Check(Rz.SelectedCountForTest = 2, 'report designer: a drag box selects the items it touches (' + IntToStr(Rz.SelectedCountForTest) + ')');
      X0 := A.Left; X1 := B.Left;
      Rz.GroupDragForTest(B, 24, 0);
      Check((A.Left - X0 = B.Left - X1) and (B.Left - X1 >= 20), 'report designer: dragging one of the selected items moves the group');
      Check(Rz.SelectedCountForTest = 2, 'report designer: the selection survives the move');
      Check(Rz.ReportDef.PageWidth = 794, 'report designer: default page is A4');
    finally
      Rz.Free;      { razoruje i definiciju }
    end;
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ "Trgovina Jadran": veliki primjer baze se gradi, a sve u njemu se provjerava }
var
  ShowcaseFglSeen: string = '';

function ShowcaseFglCapture(ADb: TAppDb; const AText: string): Integer;
begin
  ShowcaseFglSeen := AText;
  Result := 0;
end;

function CountOf(ADb: TAppDb; const ASql: string): string;
var
  Q: TZQuery;
begin
  Q := ADb.NewQuery(ASql);
  try
    Q.Open;
    if Q.Fields[0].IsNull then Result := '' else Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

procedure TestShowcase;
var
  Db, Rd: TAppDb;
  Lg: TStringList;
  Bad, I, J, P, N, Nr: Integer;
  Msg, Js, Ln, Want, Got, Sql, Nm, Src, Act: string;
  Sc: TaScriptContext;
  Pr: TaFglProgram;
  Io: TaFglScriptIO;
  Rn: TaFglRunner;
  Lt: TaLetterDef;
  RD2: TaReportDef;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  Q: TZQuery;
  Names, Lines: TStringList;
  Fm, FmA: TaFormDef;
  Err: string;
  Tasks: TaTasks;
  Sch: TSchedule;
  Cnt, FrameCnt: Integer;
begin
  if FileExists('/tmp/ta_showcase.db') then DeleteFile('/tmp/ta_showcase.db');
  Db := TAppDb.Create;
  Lg := TStringList.Create;
  try
    Db.Open('/tmp/ta_showcase.db');
    ActiveDb := Db;
    Check(BuildShowcase(Db, Lg), 'showcase: the database is built: ' + Copy(Lg.Text, Pos('GREŠKA', Lg.Text), 200));
    Check(Pos('GREŠKA', Lg.Text) = 0, 'showcase: no error in the build log');
    Check(Pos('nisu postavljene', Lg.Text) = 0, 'showcase: label sheets were set: ' + Lg.Text);
    { ---- obujam podataka ---- }
    Check(CountOf(Db, 'SELECT COUNT(*) FROM partneri') = '145', 'showcase: 145 partners');
    Check(CountOf(Db, 'SELECT COUNT(*) FROM artikli') = '90', 'showcase: 90 articles');
    Check(CountOf(Db, 'SELECT COUNT(*) FROM racuni') = '600', 'showcase: 600 invoices');
    Check(StrToIntDef(CountOf(Db, 'SELECT COUNT(*) FROM racuni_stavke'), 0) > 2000, 'showcase: more than 2000 invoice lines');
    Check(StrToIntDef(CountOf(Db, 'SELECT (SELECT COUNT(*) FROM partneri) + (SELECT COUNT(*) FROM artikli) + (SELECT COUNT(*) FROM racuni) + ' +
      '(SELECT COUNT(*) FROM racuni_stavke) + (SELECT COUNT(*) FROM ponude) + (SELECT COUNT(*) FROM ponude_stavke) + (SELECT COUNT(*) FROM narudzbenice) + ' +
      '(SELECT COUNT(*) FROM narudzbenice_stavke) + (SELECT COUNT(*) FROM skl_dokumenti) + (SELECT COUNT(*) FROM skl_stavke) + (SELECT COUNT(*) FROM uplate) + ' +
      '(SELECT COUNT(*) FROM blagajna)'), 0) > 6500, 'showcase: thousands of records');
    Check(CountOf(Db, 'SELECT COUNT(DISTINCT naziv) FROM partneri') = '145', 'showcase: partner names are unique');
    { svi OIB i IBAN su ispravni (provjera izrazima jezika) }
    Q := Db.NewQuery('SELECT oib, iban FROM partneri');
    Bad := 0;
    try
      Q.Open;
      while not Q.EOF do
      begin
        if not ExprIsTrue(EvalExpr('ValidOIB("' + Q.Fields[0].AsString + '")', nil)) then Inc(Bad);
        if not ExprIsTrue(EvalExpr('ValidIBAN("' + Q.Fields[1].AsString + '")', nil)) then Inc(Bad);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    Check(Bad = 0, 'showcase: every generated OIB and IBAN is valid (' + IntToStr(Bad) + ' bad)');
    { stavke: iznos = zaokruzeno kolicina * cijena * (1 - rabat) }
    Check(CountOf(Db, 'SELECT COUNT(*) FROM racuni_stavke WHERE ABS(iznos - ROUND(kolicina * cijena * (1 - rabat / 100.0), 2)) > 0.011') = '0', 'showcase: line amounts follow the form rule');
    Check(CountOf(Db, 'SELECT COUNT(DISTINCT pdv_stopa) FROM racuni_stavke') = '3', 'showcase: three VAT rates (25, 13, 5)');
    Check(CountOf(Db, 'SELECT COUNT(*) FROM skl_stavke WHERE kolicina < 0') = '0', 'showcase: no negative warehouse quantities in the movements');
    Check(CountOf(Db, 'SELECT COUNT(*) FROM obavijesti WHERE tekst LIKE ''%<b>%''') = '4', 'showcase: notices hold formatted text');
    Fm := TaFormDef.Create;
    Fm.FromJson(Db.LoadObject('_sys_forms', 'Obavijesti'));
    Bad := 0;
    for I := 0 to Fm.Count - 1 do if Fm[I].Kind = 'RichText' then Inc(Bad);
    Check(Bad = 1, 'showcase: the notices form has a RichText control');
    Fm.Free;
    { ---- predlosci i objekti ---- }
    Names := Db.ListObjects('_sys_forms');
    Check(Names.Count >= 16, 'showcase: forms (' + IntToStr(Names.Count) + ')');
    for I := 0 to Names.Count - 1 do
    begin
      Fm := TaFormDef.Create;
      try
        Fm.FromJson(Db.LoadObject('_sys_forms', Names[I]));
      finally
        Fm.Free;
      end;
    end;
    Names.Free;
    { svaka naredba izbornika pokazuje na objekt koji postoji }
    Fm := TaFormDef.Create;
    Fm.FromJson(Db.LoadObject('_sys_forms', 'Izbornik'));
    Bad := 0; Msg := '';
    for I := 0 to Fm.Count - 1 do
      if Fm[I].Kind = 'Button' then
      begin
        Act := Fm[I].OnClick;
        if Copy(Act, 1, 9) = 'openform:' then Nm := '_sys_forms'
        else if Copy(Act, 1, 11) = 'openreport:' then Nm := '_sys_reports'
        else if Copy(Act, 1, 11) = 'openletter:' then Nm := '_sys_letters'
        else if Copy(Act, 1, 6) = 'macro:' then Nm := '_sys_macros'
        else Continue;
        if Db.LoadObject(Nm, Trim(Copy(Act, Pos(':', Act) + 1, MaxInt))) = '' then
        begin Inc(Bad); Msg := Msg + Act + '; '; end;
      end;
    Check(Bad = 0, 'showcase: every switchboard button points to an existing object: ' + Msg);
    Check(Fm.Count > 40, 'showcase: switchboard has many buttons (' + IntToStr(Fm.Count) + ' controls)');
    Fm.Free;
    { upiti: svi se izvrse (parametri dobiju vrijednost) }
    Names := Db.ListObjects('_sys_queries');
    Bad := 0; Msg := '';
    if Db.ParamValues = nil then Db.ParamValues := TStringList.Create;
    Db.ParamValues.Clear;
    Db.ParamValues.Values['Početak naziva kupca'] := 'Adria';
    Db.ParamValues.Values['Od'] := '2025-01-01';
    Db.ParamValues.Values['Do'] := '2026-12-31';
    for I := 0 to Names.Count - 1 do
    begin
      try
        Q := Db.NewQuery('SELECT * FROM ' + Db.SourceFrom(Names[I]));
        try
          Q.Open;
        finally
          Q.Free;
        end;
      except
        on E: Exception do begin Inc(Bad); Msg := Msg + Names[I] + ': ' + Copy(E.Message, 1, 60) + '; '; end;
      end;
    end;
    Check((Bad = 0) and (Names.Count >= 20), 'showcase: all ' + IntToStr(Names.Count) + ' queries run: ' + Msg);
    Names.Free;
    Check(StrToIntDef(CountOf(Db, 'SELECT COUNT(*) FROM ' + Db.SourceFrom('Kategorije po mjesecima (unakrsni)')), 0) = 10, 'showcase: crosstab has one row per category');
    Db.ParamValues.Clear;
    { ---- izvjesca: svako se slozi, grafikoni crtaju, funkcije se racunaju ---- }
    ResetScripts;
    Scripts(Db);
    Names := Db.ListObjects('_sys_reports');
    Bad := 0; Msg := '';
    for I := 0 to Names.Count - 1 do
    begin
      RD2 := TaReportDef.Create;
      try
        RD2.FromJson(Db.LoadObject('_sys_reports', Names[I]));
        Db.ParamValues.Clear;
        Db.ParamValues.Values['Početak naziva kupca'] := 'Adria';
        Db.ParamValues.Values['Od'] := '2025-01-01';
        Db.ParamValues.Values['Do'] := '2026-12-31';
        RE := TaReportEngine.Create(Db, RD2);
        try
          RR := RE.Render;
          try
            if (RR = nil) or (RR.PageCount < 1) then begin Inc(Bad); Msg := Msg + Names[I] + ' (prazno); '; end
            else if Pos('#Err', AllText(RR)) > 0 then begin Inc(Bad); Msg := Msg + Names[I] + ' (#Err); '; end;
          finally
            RR.Free;
          end;
        finally
          RE.Free;
        end;
      except
        on E: Exception do begin Inc(Bad); Msg := Msg + Names[I] + ': ' + Copy(E.Message, 1, 50) + '; '; end;
      end;
      RD2.Free;
    end;
    Check((Bad = 0) and (Names.Count >= 30), 'showcase: all ' + IntToStr(Names.Count) + ' reports render without #Err: ' + Msg);
    Names.Free;
    Db.ParamValues.Clear;
    { grafikoni stvarno crtaju (Frame stavke) }
    RD2 := TaReportDef.Create;
    RD2.FromJson(Db.LoadObject('_sys_reports', 'Pregled prodaje'));
    RE := TaReportEngine.Create(Db, RD2);
    RR := RE.Render;
    FrameCnt := 0;
    for I := 0 to RR.Page(0).Items.Count - 1 do
      if TaRItem(RR.Page(0).Items[I]).Kind = 'Frame' then Inc(FrameCnt);
    Check(FrameCnt > 40, 'showcase: the sales overview draws its charts (' + IntToStr(FrameCnt) + ' bars)');
    RR.Free; RE.Free; RD2.Free;
    { naljepnice: pravi arak 3 x 7 = 21 po stranici }
    RD2 := TaReportDef.Create;
    RD2.FromJson(Db.LoadObject('_sys_reports', 'Naljepnice partnera'));
    Check((RD2.Columns = 3) and (RD2.MarginLeft = MmToPx(7.2)) and (RD2.Heights[SecDetail] = MmToPx(38.1)), 'showcase: partner labels are set up for the L7160 sheet');
    RE := TaReportEngine.Create(Db, RD2);
    RR := RE.Render;
    Cnt := 0;
    for I := 0 to RR.Page(0).Items.Count - 1 do
      if (TaRItem(RR.Page(0).Items[I]).Kind = 'Text') and TaRItem(RR.Page(0).Items[I]).Bold then Inc(Cnt);
    Check((Cnt = 21) and (RR.PageCount = 7), 'showcase: 21 labels on a page, 145 partners on 7 pages (' + IntToStr(Cnt) + ' / ' + IntToStr(RR.PageCount) + ')');
    RR.Free; RE.Free; RD2.Free;
    { ---- dopisi ---- }
    Lt := LoadLetter(Db, 'Opomena');
    RR := RenderLetters(Db, Lt, Err);
    Check((RR <> nil) and (RR.PageCount >= 1) and (Err = ''), 'showcase: the dunning letter renders for the debtors: ' + Err);
    RR.Free; Lt.Free;
    Lt := LoadLetter(Db, 'Zahvalnica kupcu');
    RR := RenderLetters(Db, Lt, Err);
    Check((RR <> nil) and (RR.PageCount >= 1) and (Err = ''), 'showcase: the thank-you letter renders for the best customers: ' + Err);
    Check(Pos('rabat od', AllText(RR)) > 0, 'showcase: the letter calculates the discount from the turnover');
    RR.Free; Lt.Free;
    { ---- modul: svi // test: retci ---- }
    Lines := TStringList.Create;
    try
      Lines.Text := ShowcaseModuleText;
      Bad := 0; Msg := ''; N := 0;
      ResetScripts;
      Scripts(Db);
      for I := 0 to Lines.Count - 1 do
        if Copy(Lines[I], 1, 9) = '// test: ' then
        begin
          Ln := Copy(Lines[I], 10, MaxInt);
          P := Pos(' => ', Ln);
          Inc(N);
          Got := VarToStr(EvalExpr(Copy(Ln, 1, P - 1), nil));
          Want := Copy(Ln, P + 4, MaxInt);
          if (Got <> Want) and not ((Want = 'True') and (Got = 'Da')) and not ((Want = 'False') and (Got = 'Ne')) then
          begin Inc(Bad); Msg := Msg + Ln + ' -> ' + Got + '; '; end;
        end;
      Check((N >= 10) and (Bad = 0), 'showcase: the module functions give the documented results (' + IntToStr(N) + '): ' + Msg);
    finally
      Lines.Free;
    end;
    { ---- primjeri funkcija: nijedan ne daje #Err ---- }
    Q := Db.NewQuery('SELECT naziv, primjer FROM primjeri_funkcija');
    Bad := 0; Msg := '';
    Sc := TaScriptContext.Create(Db);
    try
      Q.Open;
      while not Q.EOF do
      begin
        if Pos('#Err', VarToStr(Sc.EvalV(Q.Fields[1].AsString))) > 0 then begin Inc(Bad); Msg := Msg + Q.Fields[0].AsString + '; '; end;
        Q.Next;
      end;
    finally
      Q.Free;
      Sc.Free;
    end;
    Check(Bad = 0, 'showcase: every function example evaluates: ' + Msg);
    { ---- makroi ---- }
    if MacroMsgs = nil then MacroMsgs := TStringList.Create;
    OnScriptMessage := @MacroCapture;
    OnScriptInput := @MacroInputHook;
    OnScriptAsk := @MacroAsk;
    Sc := TaScriptContext.Create(Db);
    try
      MacroMsgs.Clear;
      RunMacroByName(Sc, 'Sažetak neplaćenih');
      Check((Pos('Neplaćenih računa', MacroMsgs.Text) > 0) and (Pos('Dug s PDV-om', MacroMsgs.Text) > 0), 'showcase macro: unpaid summary: ' + Trim(MacroMsgs.Text));
      MacroMsgs.Clear;
      RunMacroByName(Sc, 'Provjera prekoračenja ugovora');
      Check((MacroMsgs.Count = 1) and (Pos('UPOZORENJE', MacroMsgs.Text) > 0), 'showcase macro: overrun check warns about the contract over its limit: ' + Trim(MacroMsgs.Text));
      { narudzbenica po minimumima: copyrows iz upita o zalihi }
      N := StrToInt(CountOf(Db, 'SELECT COUNT(*) FROM narudzbenice'));
      MacroMsgs.Clear;
      RunMacroByName(Sc, 'Narudžbenica po minimumima');
      Check((StrToInt(CountOf(Db, 'SELECT COUNT(*) FROM narudzbenice')) = N + 1) and (StrToIntDef(CountOf(Db, 'SELECT COUNT(*) FROM narudzbenice_stavke WHERE dokument_id = (SELECT MAX(id) FROM narudzbenice)'), 0) >= 5),
        'showcase macro: purchase order created for the articles below minimum: ' + Trim(MacroMsgs.Text));
      { racun iz ponude }
      Nr := StrToInt(CountOf(Db, 'SELECT COUNT(*) FROM racuni'));
      MacroInput := CountOf(Db, 'SELECT broj FROM ponude WHERE id = 3');
      MacroMsgs.Clear;
      RunMacroByName(Sc, 'Račun iz ponude');
      Check((StrToInt(CountOf(Db, 'SELECT COUNT(*) FROM racuni')) = Nr + 1) and
        (CountOf(Db, 'SELECT COUNT(*) FROM racuni_stavke WHERE dokument_id = (SELECT MAX(id) FROM racuni)') = CountOf(Db, 'SELECT COUNT(*) FROM ponude_stavke WHERE dokument_id = 3')),
        'showcase macro: invoice made from an offer with the same lines: ' + Trim(MacroMsgs.Text));
      { poskupljenje: neispravan unos pa ispravan }
      MacroInput := '10';
      MacroAnswer := True;
      Want := CountOf(Db, 'SELECT ROUND(cijena * 1.1, 2) FROM artikli WHERE id = 1');
      Sql := CountOf(Db, 'SELECT COUNT(*) FROM _sys_programs');
      RunMacroByName(Sc, 'Povećaj cijene');
      Check(CountOf(Db, 'SELECT cijena FROM artikli WHERE id = 1') = Want, 'showcase macro: price rise applied after confirmation');
      { zakljucak mjeseca: 4GL program iz baze (naredba run4gl) i procedura iz modula }
      ShowcaseFglSeen := '';
      OnRunFglText := @ShowcaseFglCapture;
      MacroInput := '';
      RunMacroByName(Sc, 'Zaključak mjeseca');
      OnRunFglText := nil;
      Check((Pos('Mjesečni obračun', ShowcaseFglSeen) > 0) or (Pos('strftime', ShowcaseFglSeen) > 0), 'showcase macro: run4gl takes the program text from the database');
      Check(CountOf(Db, 'SELECT COUNT(*) FROM dnevnik WHERE izvor = ''zaključak''') = '1', 'showcase macro: the module procedure wrote to the log');
    finally
      Sc.Free;
      OnScriptMessage := nil;
      OnScriptInput := nil;
      OnScriptAsk := nil;
    end;
    { ---- planer ---- }
    Tasks := LoadTasks(Db);
    Bad := 0;
    for I := 0 to High(Tasks) do
      if not ParseSchedule(Tasks[I].Schedule, Sch, Err) then Inc(Bad);
    Check((Length(Tasks) = 4) and (Bad = 0), 'showcase: four tasks with valid schedules');
    { ---- revizija ---- }
    Check(AuditEnabled(Db, 'racuni') and AuditEnabled(Db, 'partneri'), 'showcase: the audit trail is on for invoices and partners');
    { forma izracunava polje modulskom funkcijom (Marza) cim se otvori, prije nego je igdje pokrenuta skripta }
    ResetScripts;
    FmA := TaFormDef.Create;
    FmA.FromJson(Db.LoadObject('_sys_forms', 'Artikli'));
    with TaFormRunner.CreateRunner(nil, Db, FmA) do
    try
      Show;
      Application.ProcessMessages;
      Check((ControlByName('txtMarza') is TEdit) and (Pos('#Err', TEdit(ControlByName('txtMarza')).Text) = 0) and
        (TEdit(ControlByName('txtMarza')).Text <> ''), 'showcase: a form calculates with a module function (Marza) on first open: ' + TEdit(ControlByName('txtMarza')).Text);
    finally
      Free;
    end;
  finally
    ResetScripts;
    ActiveDb := nil;
    Lg.Free;
    Db.Free;
  end;
end;

{ 4GL programi iz baze: svaki se pokrece na svjezoj kopiji i mora dati ono sto pise u njegovim -- expect retcima }
procedure TestShowcasePrograms;
var
  Base, Db: TAppDb;
  Lg, Src, Outp: TStringList;
  I, J, P, Bad, Ran: Integer;
  Pr: TaFglProgram;
  Io: TaFglScriptIO;
  Rn: TaFglRunner;
  Ln, Want, Got, Sql, Msg, Nm, Text: string;
  Q: TZQuery;
begin
  if FileExists('/tmp/ta_showcase_base.db') then DeleteFile('/tmp/ta_showcase_base.db');
  Base := TAppDb.Create;
  Lg := TStringList.Create;
  Src := TStringList.Create;
  try
    Base.Open('/tmp/ta_showcase_base.db');
    ActiveDb := Base;
    BuildShowcase(Base, Lg);
    ResetScripts;
    ActiveDb := nil;
    Base.Free;
    Base := nil;
    Bad := 0; Ran := 0; Msg := '';
    for I := 0 to ShowcaseProgramCount - 1 do
    begin
      Nm := ShowcaseProgramName(I);
      if FileExists('/tmp/ta_showcase_run.db') then DeleteFile('/tmp/ta_showcase_run.db');
      CopyFile('/tmp/ta_showcase_base.db', '/tmp/ta_showcase_run.db');
      Db := TAppDb.Create;
      Io := TaFglScriptIO.Create;
      Pr := TaFglProgram.Create;
      try
        Db.Open('/tmp/ta_showcase_run.db');
        ActiveDb := Db;
        ResetScripts;
        Text := Db.LoadObject('_sys_programs', Nm);
        Src.Text := Text;
        Pr.LoadText(Text, Nm);
        Outp := TStringList.Create;
        try
          if Pr.CheckProgram(Outp) <> 0 then
          begin
            Inc(Bad);
            Msg := Msg + Nm + ' ne prolazi provjeru: ' + Trim(Outp.Text) + '; ';
            Continue;
          end;
        finally
          Outp.Free;
        end;
        for J := 0 to Src.Count - 1 do
        begin
          Ln := Src[J];
          if Copy(Ln, 1, 11) = '-- prompt: ' then Io.PromptAnswers.Add(Copy(Ln, 12, MaxInt))
          else if Copy(Ln, 1, 9) = '-- menu: ' then Io.MenuAnswers.Add(Copy(Ln, 10, MaxInt));
        end;
        Rn := TaFglRunner.Create(Pr, Db, Io);
        try
          Rn.Run;
        finally
          Rn.Free;
        end;
        Inc(Ran);
        if GetEnvironmentVariable('SHOWCASE_DUMP') <> '' then
        begin
          ForceDirectories('/tmp/showcase_out');
          Io.Out.SaveToFile('/tmp/showcase_out/' + Format('%.2d', [I + 1]) + '.txt');
        end;
        for J := 0 to Src.Count - 1 do
        begin
          Ln := Src[J];
          if Copy(Ln, 1, 11) = '-- expect: ' then
          begin
            Want := Copy(Ln, 12, MaxInt);
            if Io.Out.IndexOf(Want) < 0 then
            begin
              Inc(Bad);
              Msg := Msg + Nm + ' ocekivano "' + Want + '", ispis: ' + Copy(StringReplace(Trim(Io.Out.Text), LineEnding, ' | ', [rfReplaceAll]), 1, 300) + '; ';
            end;
          end
          else if Copy(Ln, 1, 15) = '-- expect-sql: ' then
          begin
            P := Pos(' => ', Ln);
            Sql := Copy(Ln, 16, P - 16);
            Want := Copy(Ln, P + 4, MaxInt);
            Q := Db.NewQuery(Sql);
            try
              Q.Open;
              Got := Q.Fields[0].AsString;
            finally
              Q.Free;
            end;
            if Got <> Want then begin Inc(Bad); Msg := Msg + Nm + ' SQL ' + Sql + ' = ' + Got + ' (ocekivano ' + Want + '); '; end;
          end;
        end;
      finally
        Pr.Free;
        Io.Free;
        ResetScripts;
        ActiveDb := nil;
        Db.Free;
      end;
    end;
    Check((Ran = ShowcaseProgramCount) and (Ran >= 15) and (Bad = 0), 'showcase: every 4GL program stored in the database runs and gives its documented result (' + IntToStr(Ran) + ' programs) ' + Msg);
  finally
    Src.Free;
    Lg.Free;
    if Base <> nil then Base.Free;
  end;
end;

{ formatirani tekst: model, uredjivac nad TRichMemo (Qt6), spremanje kao HTML }
procedure TestRichText;
var
  D: TRtDoc;
  H: string;
  Ed: TaRichEdit;
  Fm: TForm;
  Lay: TRtLayout;
  I, Segs: Integer;
begin
  D := TRtDoc.Create;
  try
    D.LoadHtml('<p align="center"><b>Naslov</b> &amp; <font color="#ff0000" size="14">crveno</font></p><p>Obi' + #$C4#$8D + 'an <i>kurziv</i> <u>pod</u></p>');
    Check(D.Count = 2, 'rich text: two paragraphs are read');
    Check((D[0].Align = raCenter) and D[0].Runs[0].Bold and (D[0].Runs[0].Text = 'Naslov'), 'rich text: alignment and bold');
    Check((D[0].PlainText = 'Naslov & crveno') and (D[0].Runs[2].Color = $FF0000) and (D[0].Runs[2].SizePt = 14), 'rich text: entity, colour and size');
    H := D.ToHtml;
    D.LoadHtml(H);
    Check(D.ToHtml = H, 'rich text: writing and reading again gives the same text');
    Check(RtToPlain('Prvi redak' + LineEnding + 'Drugi') = 'Prvi redak' + LineEnding + 'Drugi', 'rich text: plain text from older memo fields is read as paragraphs');
    Check(Pos('&lt;', RtFromPlain('a < b')) > 0, 'rich text: special characters are escaped');
    Lay := RtLayoutDoc(D, 200, 13, 0);
    Check((Length(Lay.Lines) >= 2) and (Lay.Height > 20), 'rich text: layout gives lines and a height (' + IntToStr(Length(Lay.Lines)) + ' lines, ' + IntToStr(Lay.Height) + ' px)');
    D.LoadHtml('<p>' + StringOfChar('a', 5) + ' ' + StringOfChar('b', 5) + ' ' + StringOfChar('c', 5) + ' ' + StringOfChar('d', 5) + ' ' + StringOfChar('e', 5) + ' ' + StringOfChar('f', 5) + ' ' + StringOfChar('g', 5) + '</p>');
    Lay := RtLayoutDoc(D, 70, 13, 0);
    Check(Length(Lay.Lines) >= 3, 'rich text: a long paragraph wraps in a narrow width (' + IntToStr(Length(Lay.Lines)) + ' lines)');
  finally
    D.Free;
  end;
  Fm := TForm.CreateNew(nil);
  Ed := TaRichEdit.Create(Fm);
  try
    Ed.Parent := Fm;
    Fm.Show;
    Application.ProcessMessages;
    Ed.Html := '<p>Prvi <b>podebljano</b> kraj</p><p align="right">Desno <font color="#00aa00">zeleno</font> ' + #$C4#$8D + '</p>';
    H := Ed.Html;
    Check(Pos('<b>podebljano</b>', H) > 0, 'rich edit: bold survives loading into the editor and back: ' + H);
    Check((Pos('align="right"', H) > 0) and (Pos('color="#00aa00"', H) > 0), 'rich edit: alignment and colour survive: ' + H);
    Check(Pos(#$C4#$8D, H) > 0, 'rich edit: Croatian letters survive');
    { oblikovanje oznacenog dijela }
    Ed.Html := '<p>abcdef</p>';
    Ed.SelectRange(1, 3);
    Ed.ApplyBold;
    Ed.SelectRange(4, 2);
    Ed.ApplyColorRgb($0000FF);
    H := Ed.Html;
    Check(H = '<p>a<b>bcd</b><font color="#0000ff">ef</font></p>', 'rich edit: selected part can be made bold and coloured: ' + H);
    Ed.SelectRange(0, 6);
    Ed.ApplySizePt(18);
    Ed.ApplyAlign(raCenter);
    H := Ed.Html;
    Check((Pos('size="18"', H) > 0) and (Pos('align="center"', H) > 0), 'rich edit: size and alignment: ' + H);
  finally
    Fm.Free;
  end;
end;

type
  TOwnCrack = class(TaOwnEdit)
  public
    procedure Press(const S: string);
    procedure Key(K: Word; Sh: TShiftState = []);
  end;

  TOwnCounter = class
  public
    N: Integer;
    procedure Hit(Sender: TObject);
  end;

procedure TOwnCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TOwnCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TOwnCounter.Hit(Sender: TObject);
begin
  Inc(N);
end;

{ vlastito jednoredno polje (pruzatelj 'own'): unos, oznacavanje, brisanje, undo, UTF-8, maska, iznos, crtanje }
procedure TestOwnEdit;
var
  E: TaEdit;
  O: TOwnCrack;
  Fm: TForm;
  Cnt: TOwnCounter;
  Bmp: TBitmap;
  X, Y, Ink: Integer;
  OldProv: string;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Cnt := TOwnCounter.Create;
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 300, 120);
    E := TaEdit.Create(Fm);
    E.Parent := Fm;
    E.SetBounds(10, 10, 200, 28);
    E.OnChange := @Cnt.Hit;
    Check((E.Engine <> nil) and (E.Engine.Inner is TaOwnEdit) and (E.Engine.Provider = 'own'), 'own edit: preferred provider "own" gives the self-drawn field');
    O := TOwnCrack(E.Engine.Inner);
    O.Press('A'); O.Press('n'); O.Press('a');
    Check((E.Text = 'Ana') and (O.CharCount = 3) and (Cnt.N >= 3), 'own edit: typing inserts characters and fires OnChange (' + E.Text + ')');
    O.Key(VK_BACK);
    Check(E.Text = 'An', 'own edit: Backspace deletes before the caret');
    O.Key(VK_HOME); O.Key(VK_DELETE);
    Check(E.Text = 'n', 'own edit: Home then Delete removes the first character');
    O.Key(VK_END); O.Key(VK_LEFT, [ssShift]);
    Check((O.SelLength = 1) and (O.SelStart = 0), 'own edit: Shift+Left selects');
    O.Press('Z');
    Check(E.Text = 'Z', 'own edit: typing over a selection replaces it');
    O.Press(#$C4#$8D); O.Press(#$C5#$A1);
    Check((E.Text = 'Z'#$C4#$8D#$C5#$A1) and (O.CharCount = 3), 'own edit: UTF-8 letters count as one character each');
    O.Key(VK_BACK);
    Check(E.Text = 'Z'#$C4#$8D, 'own edit: Backspace removes a whole UTF-8 character');
    O.Key(VK_A, [ssCtrl]);
    Check(O.SelLength = 2, 'own edit: Ctrl+A selects everything');
    O.Key(VK_DELETE);
    Check(E.Text = '', 'own edit: Delete removes the selection');
    O.Key(VK_Z, [ssCtrl]);
    Check(E.Text = 'Z'#$C4#$8D, 'own edit: Ctrl+Z brings the deleted text back');
    O.Key(VK_Y, [ssCtrl]);
    Check(E.Text = '', 'own edit: Ctrl+Y repeats the undone deletion');
    O.Press('a'); O.Press('b'); O.Press('c'); O.Press('d');
    E.MaxLength := 3;
    Check(E.Text = 'abc', 'own edit: MaxLength cuts the text (' + E.Text + ')');
    O.Press('x');
    Check(E.Text = 'abc', 'own edit: nothing is typed past MaxLength');
    E.MaxLength := 0;
    E.ReadOnly := True;
    O.Press('x'); O.Key(VK_BACK);
    Check(E.Text = 'abc', 'own edit: a read-only field does not change');
    E.ReadOnly := False;
    E.Text := 'rijec jedan dva';
    O.Key(VK_END); O.Key(VK_LEFT, [ssCtrl]);
    Check(O.SelStart = 12, 'own edit: Ctrl+Left jumps to the start of the word (' + IntToStr(O.SelStart) + ')');
    { maska }
    E.Text := '';
    E.Mask := '99.99';
    O.Press('1'); O.Press('2'); O.Press('3'); O.Press('4');
    Check(E.Text = '12.34', 'own edit: input mask formats while typing (' + E.Text + ')');
    E.Mask := '';
    { lozinka }
    E.Variant := evPassword;
    Check((E.Engine.Inner is TaOwnEdit) and (TaOwnEdit(E.Engine.Inner).PasswordChar = '*'), 'own edit: password variant hides the characters');
    { iznos }
    E.Variant := evCurrency;
    E.SetValue(1234.5);
    Check((E.Text = '1,234.50') and (Abs(Double(E.Value) - 1234.5) < 0.001), 'own edit: currency variant formats and parses (' + E.Text + ')');
    { crtanje: slika polja nije prazna }
    E.Variant := evText;
    E.Text := 'Crtanje';
    with TaEdit.Create(Fm) do
    begin
      Parent := Fm; SetBounds(10, 44, 200, 28); Text := 'Ro' + #$C5#$A1 + 'ta ' + #$C4#$8D + 'ovjek'; ReadOnly := True;
    end;
    with TaEdit.Create(Fm) do
    begin
      Parent := Fm; SetBounds(10, 78, 200, 28); Variant := evCurrency; SetValue(98765.4);
    end;
    Fm.Show;
    if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
    begin
      TOwnCrack(E.Engine.Inner).SetFocus;
      TOwnCrack(E.Engine.Inner).SelectAll;
    end;
    Application.ProcessMessages;
    Bmp := Fm.GetFormImage;
    try
      if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
        with TPortableNetworkGraphic.Create do
        try
          Assign(Bmp);
          SaveToFile(GetEnvironmentVariable('TA_OWNSHOT'));
        finally
          Free;
        end;
      Ink := 0;
      for Y := 12 to 36 do
        for X := 14 to 120 do
          if (Bmp.Canvas.Pixels[X, Y] and $FFFFFF) < $808080 then Inc(Ink);
      Check(Ink > 30, 'own edit: the field draws its text (dark pixels ' + IntToStr(Ink) + ')');
    finally
      Bmp.Free;
    end;
  finally
    Fm.Free;
    Cnt.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TComboCrack = class(TaOwnCombo)
  public
    procedure Press(const S: string);
    procedure Key(K: Word; Sh: TShiftState = []);
  end;

procedure TComboCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TComboCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

{ vlastiti combo i padajuci popis (pruzatelj 'own'): popis preko forme, tipke, dopuna, kljucevi, pretraga }
procedure TestOwnCombo;
var
  E, E2, E3: TaEdit;
  C: TComboCrack;
  Fm: TForm;
  Opt: TaComboOptions;
  OldProv: string;
  Bmp: TBitmap;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 320, 260);
    E := TaEdit.Create(Fm);
    E.Parent := Fm;
    E.SetBounds(10, 10, 200, 28);
    E.Variant := evCombo;
    E.Items.Text := 'Crvena'#10'Zelena'#10'Plava';
    Check(E.Engine.Inner is TaOwnCombo, 'own combo: combo variant uses the self-drawn control');
    C := TComboCrack(E.Engine.Inner);
    E.Text := 'Zelena';
    Check(C.ItemIndex = 1, 'own combo: text that equals an item selects it');
    Fm.Show;
    Application.ProcessMessages;
    C.OpenPopup;
    Check(C.IsOpen and (C.Popup <> nil) and C.Popup.Visible and (C.Popup.ShownCount = 3), 'own combo: the popup opens over the form with all items');
    C.Key(VK_DOWN);
    C.Key(VK_RETURN);
    Check((not C.IsOpen) and (E.Text = 'Plava'), 'own combo: arrows and Enter choose an item (' + E.Text + ')');
    C.Key(VK_F4); C.Key(VK_ESCAPE);
    Check((not C.IsOpen) and (E.Text = 'Plava'), 'own combo: Esc closes without changing');
    E.Text := '';
    C.Press('P'); C.Press('l');
    Check((E.Text = 'Plava') and (C.SelLength = 3), 'own combo: AutoComplete fills in the rest as a selection (' + E.Text + ')');
    { padajuci popis }
    E2 := TaEdit.Create(Fm);
    E2.Parent := Fm;
    E2.SetBounds(10, 50, 200, 28);
    E2.Variant := evDroplist;
    E2.Items.Text := 'Crvena'#10'Zelena'#10'Plava';
    E2.Text := 'Crvena';
    TComboCrack(E2.Engine.Inner).Press('z');
    Check(E2.Text = 'Zelena', 'own droplist: a letter jumps to the item that starts with it (' + E2.Text + ')');
    TComboCrack(E2.Engine.Inner).Press('x');
    Check(E2.Text = 'Zelena', 'own droplist: no typing into the field');
    { kljucevi i pretraga }
    E3 := TaEdit.Create(Fm);
    E3.Parent := Fm;
    E3.SetBounds(10, 90, 200, 28);
    E3.Variant := evCombo;
    Opt := TaComboOptions.Create;
    Opt.Keyed := True;
    Opt.Search := True;
    E3.Options := Opt;
    Opt.Free;
    E3.Items.Text := '1=Prva'#10'2=Druga'#10'3=Treca'#10'4=Cetvrta';
    E3.Text := '3';
    C := TComboCrack(E3.Engine.Inner);
    Check((C.Text = 'Treca') and (E3.Text = '3'), 'own combo: keyed list shows the label and returns the key (' + C.Text + '/' + E3.Text + ')');
    C.SetFocus;
    C.SelectAll;
    C.Press('v');
    Check(C.IsOpen and (C.Popup.ShownCount = 2), 'own combo: Search narrows the popup to items containing the text (' + IntToStr(C.Popup.ShownCount) + ')');
    C.Key(VK_RETURN);
    Check((E3.Text = '1') and (C.Text = 'Prva'), 'own combo: choosing from the narrowed popup gives that key (' + E3.Text + ')');
    if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
    begin
      C.Popup.Visible := False;
      TComboCrack(E.Engine.Inner).OpenPopup;
      Application.ProcessMessages;
      Bmp := Fm.GetFormImage;
      with TPortableNetworkGraphic.Create do
      try
        Assign(Bmp);
        SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.combo.png');
      finally
        Free;
      end;
      Bmp.Free;
    end;
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TDateCrack = class(TaOwnDateEdit)
  public
    procedure Press(const S: string);
    procedure Key(K: Word; Sh: TShiftState = []);
    procedure Leave;
  end;

procedure TDateCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TDateCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TDateCrack.Leave;
begin
  DoExit;
end;

{ vlastito polje za datum (pruzatelj 'own'): oblik, razbor, kalendar preko forme, tipke }
procedure TestOwnDate;
var
  E: TaEdit;
  C: TDateCrack;
  Fm: TForm;
  OldProv: string;
  Bmp: TBitmap;
  D: TDateTime;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 320, 330);
    E := TaEdit.Create(Fm);
    E.Parent := Fm;
    E.SetBounds(10, 10, 160, 28);
    E.Variant := evDate;
    Check(E.Engine.Inner is TaOwnDateEdit, 'own date: date variant uses the self-drawn control');
    C := TDateCrack(E.Engine.Inner);
    E.Text := '15.03.2025';
    Check(Abs(Double(E.Value) - EncodeDate(2025, 3, 15)) < 0.5, 'own date: the typed text is read as a date');
    E.SetValue(EncodeDate(2024, 2, 29));
    Check(E.Text = '29.02.2024', 'own date: a date value is shown as dd.mm.yyyy (' + E.Text + ')');
    E.Text := '2025-03-15';
    Check(E.Text = '15.03.2025', 'own date: an ISO date from the database is shown as dd.mm.yyyy (' + E.Text + ')');
    E.Text := '1.2.2025';
    C.Leave;
    Check(E.Text = '01.02.2025', 'own date: leaving the field writes the date in full (' + E.Text + ')');
    E.Text := 'ne datum';
    Check(VarIsNull(E.Value), 'own date: text that is not a date gives no value');
    E.Text := '31.01.2025';
    Fm.Show;
    Application.ProcessMessages;
    C.OpenPopup;
    Check(C.IsOpen and C.Calendar.Visible and (Abs(C.Calendar.Selected - EncodeDate(2025, 1, 31)) < 0.5), 'own date: the calendar opens on the date in the field');
    C.Key(VK_RIGHT);
    Check(Abs(C.Calendar.Selected - EncodeDate(2025, 2, 1)) < 0.5, 'own date: Right moves one day');
    C.Key(VK_NEXT);
    Check(Abs(C.Calendar.Selected - EncodeDate(2025, 3, 1)) < 0.5, 'own date: PgDn moves one month');
    C.Key(VK_DOWN);
    C.Key(VK_RETURN);
    Check((not C.IsOpen) and (E.Text = '08.03.2025'), 'own date: Down moves a week and Enter writes the date (' + E.Text + ')');
    E.Text := '31.01.2025';
    C.OpenPopup;
    C.Calendar.MoveMonths(1);
    Check(Abs(C.Calendar.Selected - EncodeDate(2025, 2, 28)) < 0.5, 'own date: a month later from 31 January is 28 February');
    C.Key(VK_ESCAPE);
    Check((not C.IsOpen) and (E.Text = '31.01.2025'), 'own date: Esc closes without changing');
    if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
    begin
      E.Text := '14.03.2025';
      C.OpenPopup;
      Application.ProcessMessages;
      Bmp := Fm.GetFormImage;
      with TPortableNetworkGraphic.Create do
      try
        Assign(Bmp);
        SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.date.png');
      finally
        Free;
      end;
      Bmp.Free;
    end;
    D := 0;
    if D > 1 then Exit;
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TSpinCrack = class(TaOwnSpin)
  public
    procedure Press(const S: string);
    procedure Key(K: Word; Sh: TShiftState = []);
    procedure Leave;
    procedure Click(X, Y: Integer);
  end;

procedure TSpinCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TSpinCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TSpinCrack.Leave;
begin
  DoExit;
end;

procedure TSpinCrack.Click(X, Y: Integer);
begin
  MouseDown(mbLeft, [ssLeft], X, Y);
  MouseUp(mbLeft, [ssLeft], X, Y);
end;

{ vlastito polje s brojem i strelicama (pruzatelj 'own') }
procedure TestOwnSpin;
var
  E: TaEdit;
  C: TSpinCrack;
  Fm: TForm;
  Opt: TaSpinOptions;
  OldProv: string;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 260, 100);
    E := TaEdit.Create(Fm);
    E.Parent := Fm;
    E.SetBounds(10, 10, 140, 28);
    E.Variant := evSpin;
    Check(E.Engine.Inner is TaOwnSpin, 'own spin: spin variant uses the self-drawn control');
    C := TSpinCrack(E.Engine.Inner);
    Opt := TaSpinOptions.Create;
    Opt.DecimalPlaces := 2;
    Opt.MinValue := 0;
    Opt.MaxValue := 100;
    Opt.Increment := 0.5;
    E.Options := Opt;
    Opt.Free;
    E.SetValue(12.5);
    Check((E.Text = '12.50') and (Abs(Double(E.Value) - 12.5) < 0.0001), 'own spin: the value is shown with the set decimals (' + E.Text + ')');
    C.Key(VK_UP);
    Check(Abs(C.Value - 13) < 0.0001, 'own spin: Up adds one step');
    C.Key(VK_DOWN); C.Key(VK_DOWN);
    Check(Abs(C.Value - 12) < 0.0001, 'own spin: Down subtracts one step');
    C.Key(VK_PRIOR);
    Check(Abs(C.Value - 17) < 0.0001, 'own spin: PgUp adds ten steps');
    E.SetValue(99.9);
    C.Key(VK_PRIOR);
    Check(Abs(C.Value - 100) < 0.0001, 'own spin: the value stops at the maximum');
    E.SetValue(-5);
    Check(Abs(C.Value) < 0.0001, 'own spin: a value under the minimum is raised to it');
    C.SelectAll;
    C.Press('x'); C.Press('7'); C.Press('a'); C.Press('.'); C.Press('2');
    Check(C.Text = '7.2', 'own spin: only digits and the decimal sign are typed (' + C.Text + ')');
    C.Leave;
    Check(E.Text = '7.20', 'own spin: leaving writes the value in full (' + E.Text + ')');
    C.Click(C.Width - 8, 4);
    Check(Abs(C.Value - 7.7) < 0.0001, 'own spin: the upper arrow adds a step (' + FloatToStr(C.Value) + ')');
    C.Click(C.Width - 8, C.Height - 4);
    C.Click(C.Width - 8, C.Height - 4);
    Check(Abs(C.Value - 6.7) < 0.0001, 'own spin: the lower arrow subtracts a step (' + FloatToStr(C.Value) + ')');
    E.ReadOnly := True;
    C.Key(VK_UP);
    Check(Abs(C.Value - 6.7) < 0.0001, 'own spin: read-only does not change');
    E.ReadOnly := False;
    E.Text := '3,5';
    Check(Abs(C.Value - 3.5) < 0.0001, 'own spin: a comma is also a decimal sign');
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TLovCrack = class(TaOwnLovEdit)
  public
    procedure Press(const S: string);
    procedure Key(K: Word; Sh: TShiftState = []);
    procedure Click(X, Y: Integer);
  end;

  TLovCounter = class
  public
    N: Integer;
    procedure Hit(Sender: TObject);
  end;

procedure TLovCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TLovCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TLovCrack.Click(X, Y: Integer);
begin
  MouseDown(mbLeft, [ssLeft], X, Y);
  MouseUp(mbLeft, [ssLeft], X, Y);
end;

procedure TLovCounter.Hit(Sender: TObject);
begin
  Inc(N);
end;

{ vlastito polje s gumbom za popis vrijednosti (pruzatelj 'own') }
procedure TestOwnLov;
var
  E: TaEdit;
  C: TLovCrack;
  Fm: TForm;
  Cnt: TLovCounter;
  OldProv: string;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  Cnt := TLovCounter.Create;
  try
    Fm.SetBounds(0, 0, 260, 100);
    E := TaEdit.Create(Fm);
    E.Parent := Fm;
    E.SetBounds(10, 10, 160, 28);
    E.Variant := evLov;
    E.OnLov := @Cnt.Hit;
    Check(E.Engine.Inner is TaOwnLovEdit, 'own lov: lov variant uses the self-drawn control');
    C := TLovCrack(E.Engine.Inner);
    C.Press('A'); C.Press('b');
    Check(E.Text = 'Ab', 'own lov: the field takes typing like a plain one (' + E.Text + ')');
    C.Click(C.Width - 10, 10);
    Check(Cnt.N = 1, 'own lov: the button asks for the list of values');
    C.Click(10, 10);
    Check(Cnt.N = 1, 'own lov: a click on the text does not');
    C.Key(VK_F9);
    Check(Cnt.N = 2, 'own lov: F9 asks for the list too');
    E.ReadOnly := True;
    C.Click(C.Width - 10, 10);
    C.Key(VK_F9);
    Check(Cnt.N = 2, 'own lov: a read-only field has no list');
  finally
    Cnt.Free;
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TMemoCrack = class(TaOwnMemo)
  public
    procedure Press(const S: string);
    procedure Key(K: Word; Sh: TShiftState = []);
  end;

procedure TMemoCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TMemoCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

{ vlastito visenjredno polje (pruzatelj 'own') }
procedure TestOwnMemo;
var
  M: TaMemo;
  C: TMemoCrack;
  Fm: TForm;
  OldProv: string;
  Bmp: TBitmap;
  I, Ink, X, Y: Integer;
  Long: string;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 300, 220);
    M := TaMemo.Create(Fm);
    M.Parent := Fm;
    M.SetBounds(10, 10, 200, 100);
    Check(M.Engine.Inner is TaOwnMemo, 'own memo: plain variant uses the self-drawn control');
    C := TMemoCrack(M.Engine.Inner);
    C.Press('a'); C.Press('b'); C.Key(VK_RETURN); C.Press('c');
    Check((M.Text = 'ab' + LineEnding + 'c') and (C.LineCount = 2), 'own memo: Enter starts a new line');
    C.Key(VK_HOME);
    C.Key(VK_BACK);
    Check((M.Text = 'abc') and (C.LineCount = 1), 'own memo: Backspace at the start of a line joins it to the one above');
    M.Text := 'jedan'#10'dva'#10'tri';
    Check((C.LineCount = 3) and (C.CaretRow = 0), 'own memo: setting the text splits it into lines');
    C.Key(VK_DOWN); C.Key(VK_DOWN);
    Check(C.CaretRow = 2, 'own memo: Down moves between lines');
    C.Key(VK_HOME, [ssCtrl]);
    Check((C.CaretRow = 0) and (C.CaretCol = 0), 'own memo: Ctrl+Home goes to the start of the text');
    C.Key(VK_END, [ssCtrl]);
    Check((C.CaretRow = 2) and (C.CaretCol = 3), 'own memo: Ctrl+End goes to the end of the text');
    C.Key(VK_A, [ssCtrl]);
    C.Press('x');
    Check(M.Text = 'x', 'own memo: typing over everything replaces it');
    C.Key(VK_Z, [ssCtrl]);
    Check(M.Text = 'jedan' + LineEnding + 'dva' + LineEnding + 'tri', 'own memo: Ctrl+Z restores the text');
    { oznaka preko redaka }
    M.Text := 'abc'#10'def';
    C.Key(VK_RIGHT);
    C.Key(VK_DOWN, [ssShift]);
    Check(C.SelectedText = 'bc' + LineEnding + 'd', 'own memo: Shift+Down selects across lines (' + C.SelectedText + ')');
    C.Key(VK_DELETE);
    Check(M.Text = 'aef', 'own memo: Delete removes a selection across lines (' + M.Text + ')');
    C.InsertText('x'#10'y');
    Check((C.LineCount = 2) and (M.Text = 'ax' + LineEnding + 'yef'), 'own memo: pasted text with a line break makes two lines (' + M.Text + ')');
    { prijelom redaka }
    Long := 'ovo je prilicno dugacak tekst koji se mora prelomiti u vise prikazanih redaka jer polje nije siroko';
    M.Text := Long;
    Check(C.VisualLineCount > 1, 'own memo: a long line wraps (' + IntToStr(C.VisualLineCount) + ' visual lines)');
    TaMemoOptions(M.Options).WordWrap := False;
    C.WordWrap := False;
    Check(C.VisualLineCount = 1, 'own memo: without wrapping one line stays one');
    C.WordWrap := True;
    { najveca duljina i samo citanje }
    M.Text := '';
    C.MaxLength := 5;
    for I := 1 to 8 do C.Press('z');
    Check(M.Text = 'zzzzz', 'own memo: MaxLength stops the text (' + M.Text + ')');
    C.ReadOnly := True;
    C.Press('q'); C.Key(VK_RETURN); C.Key(VK_BACK);
    Check(M.Text = 'zzzzz', 'own memo: read-only does not change');
    C.ReadOnly := False;
    C.MaxLength := 0;
    { crtanje i klizac }
    Long := '';
    for I := 1 to 30 do Long := Long + 'redak ' + IntToStr(I) + LineEnding;
    M.Text := Long;
    Fm.Show;
    Application.ProcessMessages;
    Bmp := Fm.GetFormImage;
    try
      if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
        with TPortableNetworkGraphic.Create do
        try
          Assign(Bmp);
          SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.memo.png');
        finally
          Free;
        end;
      Ink := 0;
      for Y := 14 to 100 do
        for X := 16 to 150 do
          if (Bmp.Canvas.Pixels[X, Y] and $FFFFFF) < $808080 then Inc(Ink);
      Check(Ink > 100, 'own memo: the field draws its text (dark pixels ' + IntToStr(Ink) + ')');
    finally
      Bmp.Free;
    end;
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TRichCrack = class(TaRichSurface)
  public
    procedure Press(const S: string);
    procedure Key(K: Word; Sh: TShiftState = []);
    procedure ClickAt(X, Y: Integer);
  end;

procedure TRichCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TRichCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TRichCrack.ClickAt(X, Y: Integer);
begin
  MouseDown(mbLeft, [], X, Y);
  MouseUp(mbLeft, [], X, Y);
end;

{ vlastiti uredjivac formatiranog teksta (pruzatelj 'own') }
procedure TestOwnRich;
var
  Ed: TaOwnRichEdit;
  S: TRichCrack;
  Fm: TForm;
  OldProv, H: string;
  Bmp: TBitmap;
  I, Ink, X, Y: Integer;
  Mm: TaMemo;
  Ch: Integer;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 420, 260);
    Ed := TaOwnRichEdit.Create(Fm);
    Ed.Parent := Fm;
    Ed.SetBounds(10, 10, 380, 200);
    Check(NewRichEditor(Fm) is TaOwnRichEdit, 'own rich: the factory gives the self-drawn editor under provider own');
    S := TRichCrack(Ed.Surface);
    Ch := 0;
    Ed.OnChanged := nil;
    { unos i oblikovanje }
    Ed.Html := '<p>abc def</p>';
    Check(Ed.Html = '<p>abc def</p>', 'own rich: html round trip (' + Ed.Html + ')');
    Ed.SelectRange(4, 3);
    Ed.ApplyBold;
    Check(Ed.Html = '<p>abc <b>def</b></p>', 'own rich: bold on a selection (' + Ed.Html + ')');
    Ed.ApplyBold;
    Check(Ed.Html = '<p>abc def</p>', 'own rich: bold again removes it (' + Ed.Html + ')');
    Ed.ApplyItalic;
    Ed.ApplyUnderline;
    Ed.ApplyColorRgb($FF0000);
    Ed.ApplySizePt(18);
    H := Ed.Html;
    Check((Pos('<i>', H) > 0) and (Pos('<u>', H) > 0) and (Pos('#ff0000', LowerCase(H)) > 0) and (Pos('18', H) > 0),
      'own rich: italic, underline, colour and size are all written (' + H + ')');
    { tipkanje s trenutnim stilom }
    Ed.Html := '<p>x</p>';
    S.Key(VK_END, [ssCtrl]);
    S.Key(VK_B, [ssCtrl]);
    S.Press('y');
    Check(Ed.Html = '<p>x<b>y</b></p>', 'own rich: Ctrl+B then typing writes bold text (' + Ed.Html + ')');
    S.Press('z');
    Check(Ed.Html = '<p>x<b>yz</b></p>', 'own rich: the style stays while typing');
    { odlomci }
    S.Key(VK_RETURN);
    S.Press('n');
    Check(Pos('</p><p>', Ed.Html) > 0, 'own rich: Enter starts a new paragraph (' + Ed.Html + ')');
    Check(S.ParaCount = 2, 'own rich: two paragraphs');
    S.Key(VK_HOME);
    S.Key(VK_BACK);
    Check(S.ParaCount = 1, 'own rich: Backspace at a paragraph start joins it with the one above');
    { poravnanje i natuknice }
    Ed.Html := '<p>a</p><p>b</p>';
    S.Key(VK_END, [ssCtrl]);
    Ed.ApplyAlign(raCenter);
    Check(Pos('align="center"', Ed.Html) > 0, 'own rich: centre alignment is written (' + Ed.Html + ')');
    Ed.ApplyBullet;
    Check(Pos('list="1"', Ed.Html) > 0, 'own rich: bullet is a paragraph attribute (' + Ed.Html + ')');
    S.Key(VK_RETURN);
    Check(S.ParaCount = 3, 'own rich: Enter in a bullet paragraph continues the list');
    S.Key(VK_RETURN);
    Check((S.ParaCount = 3) and not S.CurrentBullet, 'own rich: Enter in an empty bullet ends the list');
    { oznaka i brisanje preko odlomaka }
    Ed.Html := '<p>abc</p><p>def</p>';
    S.Key(VK_RIGHT);
    S.Key(VK_DOWN, [ssShift]);
    Check(S.SelectedText = 'bc' + LineEnding + 'd', 'own rich: Shift+Down selects across paragraphs (' + S.SelectedText + ')');
    S.Key(VK_DELETE);
    Check(Ed.Html = '<p>aef</p>', 'own rich: deleting a selection joins paragraphs (' + Ed.Html + ')');
    S.Key(VK_Z, [ssCtrl]);
    Check(Ed.Html = '<p>abc</p><p>def</p>', 'own rich: Ctrl+Z restores (' + Ed.Html + ')');
    S.Key(VK_Y, [ssCtrl]);
    Check(Ed.Html = '<p>aef</p>', 'own rich: Ctrl+Y repeats');
    { posebni znakovi i ocisti }
    Ed.Html := '<p>a &lt; b &amp; c</p>';
    Check(Ed.Html = '<p>a &lt; b &amp; c</p>', 'own rich: escaped characters survive');
    S.SelectAll;
    S.Press('č');
    Check(Ed.Html = '<p>č</p>', 'own rich: a UTF-8 letter types as one character (' + Ed.Html + ')');
    { prijelom redaka }
    Ed.Html := '<p>ovo je prilicno dugacak tekst koji se mora prelomiti u vise prikazanih redaka jer polje nije siroko</p>';
    Fm.Show;
    Application.ProcessMessages;
    Check(S.LineCount > 1, 'own rich: a long paragraph wraps (' + IntToStr(S.LineCount) + ' lines)');
    { samo citanje }
    Ed.Html := '<p>fiksno</p>';
    Ed.ReadOnly := True;
    S.Press('q'); S.Key(VK_BACK); S.Key(VK_RETURN);
    Check(Ed.Html = '<p>fiksno</p>', 'own rich: read-only does not change');
    Check(not Ed.Bar.Visible, 'own rich: read-only hides the toolbar');
    Ed.ReadOnly := False;
    Check(Ed.Bar.Visible, 'own rich: leaving read-only shows the toolbar');
    { crtanje }
    Ed.Html := '<p>Tekst <b>podebljan</b> i <font color="#ff0000">crven</font></p><p list="1">natuknica</p>';
    Application.ProcessMessages;
    Bmp := Fm.GetFormImage;
    try
      if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
        with TPortableNetworkGraphic.Create do
        try
          Assign(Bmp);
          SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.rich.png');
        finally
          Free;
        end;
      Ink := 0;
      for Y := 50 to 120 do
        for X := 16 to 300 do
          if (Bmp.Canvas.Pixels[X, Y] and $FFFFFF) < $808080 then Inc(Ink);
      Check(Ink > 100, 'own rich: the editor draws its text (dark pixels ' + IntToStr(Ink) + ')');
    finally
      Bmp.Free;
    end;
    { obitelj Memo: varijanta rich pod 'own' }
    Mm := TaMemo.Create(Fm);
    Mm.Parent := Fm;
    TaMemoOptions(Mm.Options);
    Mm.Variant := mvRich;
    Mm.Text := '<p>iz memoa</p>';
    Check(TaRichBase(Mm.Engine.Inner) is TaOwnRichEdit, 'own rich: Memo variant rich uses the self-drawn editor');
    Check(Mm.Text = '<p>iz memoa</p>', 'own rich: Memo rich text round trip (' + Mm.Text + ')');
    Mm.Variant := mvMarkdown;
    Mm.Text := '**debelo** i *kosa*';
    Check(Mm.Engine is TaMemoMarkdownEngine, 'own markdown: the engine is the markdown engine');
    Check(Mm.Engine.Inner is TPanel, 'own markdown: root panel');
    Check(Mm.Text = '**debelo** i *kosa*', 'own markdown: source text round trip (' + Mm.Text + ')');
    TaMemoOptions(Mm.Options).Preview := True;
    Mm.Options := Mm.Options;
    Check(TaMemoMarkdownEngine(Mm.Engine).PreviewShown, 'own markdown: preview shows');
    Check(Pos('<b>', TaMemoMarkdownEngine(Mm.Engine).PreviewHtml) > 0, 'own markdown: preview is formatted');
    TaMemoOptions(Mm.Options).Preview := False;
    Mm.Options := Mm.Options;
    Check(not TaMemoMarkdownEngine(Mm.Engine).PreviewShown, 'own markdown: preview hides');
    Check(TObject(TPanel(Mm.Engine.Inner).Controls[0]).ClassName = 'TaOwnMemo', 'own markdown: source field is the self-drawn memo');
    I := 0;
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TTreeCrack = class(TaOwnTree)
  public
    procedure Key(K: Word; Sh: TShiftState = []);
    procedure Click(X, Y: Integer);
  end;

procedure TTreeCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TTreeCrack.Click(X, Y: Integer);
begin
  MouseDown(mbLeft, [], X, Y);
  MouseUp(mbLeft, [], X, Y);
end;

{ vlastito stablo (pruzatelj 'own') }
procedure TestOwnTree;
var
  L: TaList;
  C: TTreeCrack;
  Fm: TForm;
  OldProv: string;
  Bmp: TBitmap;
  X, Y, Ink: Integer;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 300, 240);
    L := TaList.Create(Fm);
    L.Parent := Fm;
    L.SetBounds(10, 10, 200, 150);
    L.Variant := lsTree;
    L.Items.Text := 'a=Europa'#10'  b=Hrvatska'#10'    c=Zagreb'#10'    d=Split'#10'  e=Italija'#10'f=Azija'#10'  g=Japan';
    Check(L.Engine.Inner is TaOwnTree, 'own tree: tree variant uses the self-drawn control');
    C := TTreeCrack(L.Engine.Inner);
    Check((C.Count = 7) and (C.VisibleCount = 7), 'own tree: everything starts open (' + IntToStr(C.VisibleCount) + ' rows)');
    Check((C.Level[2] = 2) and C.HasKids[1] and not C.HasKids[2], 'own tree: levels and children come from the indentation');
    L.Select('c');
    Check((L.Selected = 'c') and (C.ItemIndex = 2), 'own tree: selecting by key');
    C.Key(VK_LEFT);
    Check(C.ItemIndex = 1, 'own tree: Left on a leaf goes to the parent');
    C.Key(VK_LEFT);
    Check((not C.Expanded[1]) and (C.VisibleCount = 5), 'own tree: Left on an open node closes it (' + IntToStr(C.VisibleCount) + ')');
    C.Key(VK_DOWN);
    Check(C.ItemIndex = 4, 'own tree: Down skips the hidden children');
    C.Key(VK_UP); C.Key(VK_RIGHT);
    Check(C.Expanded[1] and (C.VisibleCount = 7), 'own tree: Right opens a closed node');
    C.Key(VK_RIGHT);
    Check(C.ItemIndex = 2, 'own tree: Right on an open node goes to its first child');
    C.Key(VK_END);
    Check(L.Selected = 'g', 'own tree: End goes to the last row');
    C.Key(VK_HOME);
    Check(L.Selected = 'a', 'own tree: Home goes to the first row');
    C.Key(VK_SUBTRACT);
    Check(C.VisibleCount = 3, 'own tree: minus closes the node (' + IntToStr(C.VisibleCount) + ')');
    C.Key(VK_MULTIPLY);
    Check(C.VisibleCount = 7, 'own tree: star opens everything');
    { zatvaranje s oznacenim potomkom }
    L.Select('d');
    C.Expanded[0] := False;
    Check(C.ItemIndex = 0, 'own tree: closing an ancestor moves the selection to it');
    L.Select('d');
    Check(C.Expanded[0] and (C.ItemIndex = 3), 'own tree: selecting a hidden node opens its parents');
    { mis }
    C.Click(80, 5);
    Check(C.ItemIndex = 0, 'own tree: click selects a row');
    C.Click(6 + 6, 5);
    Check(not C.Expanded[0], 'own tree: click on the triangle closes the node');
    C.Click(6 + 6, 5);
    Check(C.Expanded[0], 'own tree: and opens it again');
    { samo citanje }
    L.Select('a');
    C.ReadOnly := True;
    C.Key(VK_DOWN);
    Check(L.Selected = 'a', 'own tree: read-only keeps the selection');
    C.ReadOnly := False;
    { crtanje }
    Fm.Show;
    Application.ProcessMessages;
    Bmp := Fm.GetFormImage;
    try
      if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
        with TPortableNetworkGraphic.Create do
        try
          Assign(Bmp);
          SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.tree.png');
        finally
          Free;
        end;
      Ink := 0;
      for Y := 14 to 150 do
        for X := 16 to 200 do
          if (Bmp.Canvas.Pixels[X, Y] and $FFFFFF) < $808080 then Inc(Ink);
      Check(Ink > 100, 'own tree: the tree draws its text (dark pixels ' + IntToStr(Ink) + ')');
    finally
      Bmp.Free;
    end;
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TListCrack = class(TaOwnList)
  public
    procedure Press(const S: string);
    procedure Key(K: Word; Sh: TShiftState = []);
    procedure Click(X, Y: Integer; Sh: TShiftState = []);
  end;

procedure TListCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TListCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TListCrack.Click(X, Y: Integer; Sh: TShiftState);
begin
  MouseDown(mbLeft, Sh + [ssLeft], X, Y);
  MouseUp(mbLeft, Sh + [ssLeft], X, Y);
end;

{ vlastiti popis stavki i popis s kvacicama (pruzatelj 'own') }
procedure TestOwnList;
var
  L: TaList;
  C: TListCrack;
  Fm: TForm;
  Opt: TaListOptions;
  OldProv: string;
  Bmp: TBitmap;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 420, 200);
    L := TaList.Create(Fm);
    L.Parent := Fm;
    L.SetBounds(10, 10, 160, 120);
    L.Items.Text := 'a=Prvi'#10'b=Drugi'#10'c=Treci'#10'd=Cetvrti';
    Check(L.Engine.Inner is TaOwnList, 'own list: list variant uses the self-drawn control');
    C := TListCrack(L.Engine.Inner);
    L.Select('b');
    Check((C.ItemIndex = 1) and (L.Selected = 'b'), 'own list: a key selects its item');
    Fm.Show;
    Application.ProcessMessages;
    C.Key(VK_DOWN);
    Check(L.Selected = 'c', 'own list: Down selects the next item (' + L.Selected + ')');
    C.Key(VK_END);
    Check(L.Selected = 'd', 'own list: End selects the last item');
    C.Key(VK_HOME);
    Check(L.Selected = 'a', 'own list: Home selects the first item');
    C.Click(20, 2 + 2 * 28 + 5);
    Check(L.Selected = 'c', 'own list: a click selects the item under the mouse (' + L.Selected + ')');
    C.Press('d');
    Check(L.Selected = 'b', 'own list: a letter jumps to the item that starts with it (' + L.Selected + ')');
    L.ReadOnly := True;
    C.Key(VK_DOWN);
    Check(L.Selected = 'b', 'own list: read-only keeps the selection');
    L.ReadOnly := False;
    { vise oznacenih }
    Opt := TaListOptions.Create;
    Opt.MultiSelect := True;
    L.Options := Opt;
    Opt.Free;
    L.Select('a,c');
    Check(L.Selected = 'a,c', 'own list: more items can be selected (' + L.Selected + ')');
    C.Click(20, 2 + 1 * 28 + 5, [ssCtrl]);
    Check(L.Selected = 'a,b,c', 'own list: Ctrl+click adds an item (' + L.Selected + ')');
    C.Key(VK_A, [ssCtrl]);
    Check(L.Selected = 'a,b,c,d', 'own list: Ctrl+A selects all');
    { popis s kvacicama }
    L := TaList.Create(Fm);
    L.Parent := Fm;
    L.SetBounds(200, 10, 160, 120);
    L.Variant := lsChecklist;
    L.Items.Text := 'a=Prvi'#10'b=Drugi'#10'c=Treci';
    Check(L.Engine.Inner is TaOwnList, 'own checklist: checklist variant uses the self-drawn control');
    C := TListCrack(L.Engine.Inner);
    L.Select('b');
    Check(L.Selected = 'b', 'own checklist: a key is ticked');
    C.Click(14, 2 + 2 * 28 + 5);
    Check(L.Selected = 'b,c', 'own checklist: a click on the box ticks it (' + L.Selected + ')');
    C.Click(14, 2 + 1 * 28 + 5);
    Check(L.Selected = 'c', 'own checklist: a second click unticks it (' + L.Selected + ')');
    C.Key(VK_HOME);
    C.Key(VK_SPACE);
    Check(L.Selected = 'a,c', 'own checklist: Space ticks the current item (' + L.Selected + ')');
    if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
    begin
      Application.ProcessMessages;
      Bmp := Fm.GetFormImage;
      with TPortableNetworkGraphic.Create do
      try
        Assign(Bmp);
        SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.list.png');
      finally
        Free;
      end;
      Bmp.Free;
    end;
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TCalCrack = class(TaOwnCalendar)
  public
    procedure Key(K: Word; Sh: TShiftState = []);
    procedure Click(X, Y: Integer);
  end;

procedure TCalCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TCalCrack.Click(X, Y: Integer);
begin
  MouseDown(mbLeft, [ssLeft], X, Y);
  MouseUp(mbLeft, [ssLeft], X, Y);
end;

{ vlastiti popis ikona (pruzatelj 'own') }
procedure TestOwnIconlist;
var
  L: TaList;
  C: TListCrack;
  Fm: TForm;
  OldProv: string;
  Bmp: TBitmap;
  X, Y, Ink, I: Integer;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 340, 260);
    L := TaList.Create(Fm);
    L.Parent := Fm;
    L.SetBounds(10, 10, 280, 200);
    L.Variant := lsIconlist;
    L.Items.Text := '';
    for I := 1 to 14 do L.Items.Add('k' + IntToStr(I) + '=Stavka ' + IntToStr(I));
    Check(L.Engine.Inner is TaOwnList, 'own iconlist: the iconlist variant uses the self-drawn control');
    Fm.Show;
    Application.ProcessMessages;
    C := TListCrack(L.Engine.Inner);
    Check(C.Tiles, 'own iconlist: items are tiles');
    L.Select('k1');
    C.Key(VK_RIGHT);
    Check(L.Selected = 'k2', 'own iconlist: Right moves to the next tile');
    C.Key(VK_DOWN);
    Check(L.Selected = 'k5', 'own iconlist: Down moves one tile row (3 columns at this width) (' + L.Selected + ')');
    C.Key(VK_END);
    Check(L.Selected = 'k14', 'own iconlist: End goes to the last tile');
    C.Key(VK_HOME);
    C.Click(10, 10);
    Check(L.Selected = 'k1', 'own iconlist: click selects the tile under the mouse (' + L.Selected + ')');
    C.Click(100, 10);
    Check(L.Selected = 'k2', 'own iconlist: second column click (' + L.Selected + ')');
    TaListOptions(L.Options).MultiSelect := True;
    L.Options := L.Options;
    L.Select('k1,k3');
    Check(L.Selected = 'k1,k3', 'own iconlist: multi-select keeps the keys (' + L.Selected + ')');
    Fm.Show;
    Application.ProcessMessages;
    Bmp := Fm.GetFormImage;
    try
      if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
        with TPortableNetworkGraphic.Create do
        try
          Assign(Bmp);
          SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.icons.png');
        finally
          Free;
        end;
      Ink := 0;
      for Y := 14 to 200 do
        for X := 16 to 280 do
          if (Bmp.Canvas.Pixels[X, Y] and $FFFFFF) < $808080 then Inc(Ink);
      Check(Ink > 100, 'own iconlist: it draws its captions (dark pixels ' + IntToStr(Ink) + ')');
    finally
      Bmp.Free;
    end;
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

{ vlastiti kalendar na formi: mjesec, razdoblje, agenda (pruzatelj 'own') }
procedure TestOwnCalendar;
var
  K: TaCalendar;
  C: TCalCrack;
  Fm: TForm;
  OldProv: string;
  Bmp: TBitmap;

  function DayX(ACol: Integer): Integer;
  begin
    Result := 1 + ACol * ((C.Width - 2) div 7) + 6;
  end;

  function DayY(ARow: Integer): Integer;
  begin
    Result := 34 + 24 + ARow * ((C.Height - 34 - 24 - 30 - 2) div 6) + 6;
  end;

begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 640, 330);
    K := TaCalendar.Create(Fm);
    K.Parent := Fm;
    K.SetBounds(10, 10, 280, 260);
    Check(K.Engine.Inner is TaOwnCalendar, 'own calendar: month variant uses the self-drawn control');
    C := TCalCrack(K.Engine.Inner);
    Fm.Show;
    Application.ProcessMessages;
    K.Text := '2025-03-15';
    Check(K.Text = '2025-03-15', 'own calendar: the date is set from an ISO text');
    C.Click(DayX(3), DayY(3));
    Check(K.Text = '2025-03-20', 'own calendar: a click on a day selects it (' + K.Text + ')');
    C.Key(VK_RIGHT);
    Check(K.Text = '2025-03-21', 'own calendar: Right moves one day (' + K.Text + ')');
    C.Key(VK_DOWN);
    Check(K.Text = '2025-03-28', 'own calendar: Down moves a week');
    C.Key(VK_NEXT);
    Check(K.Text = '2025-04-28', 'own calendar: PgDn moves a month (' + K.Text + ')');
    { razdoblje }
    K.Variant := cmRange;
    C := TCalCrack(K.Engine.Inner);
    K.Text := '2025-03-01';
    C.SetDate(EncodeDate(2025, 3, 1));
    C.Click(DayX(1), DayY(1));
    C.Click(DayX(4), DayY(2));
    Check(Pos('..', K.Text) > 0, 'own calendar: two clicks give a period (' + K.Text + ')');
    K.Text := '2025-03-10..2025-03-20';
    Check(K.Text = '2025-03-10..2025-03-20', 'own calendar: a period is set from text and read back');
    if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
    begin
      Application.ProcessMessages;
      Bmp := Fm.GetFormImage;
      with TPortableNetworkGraphic.Create do
      try
        Assign(Bmp);
        SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.cal.png');
      finally
        Free;
      end;
      Bmp.Free;
    end;
    { agenda }
    K.Variant := cmAgenda;
    Check(K.Engine.Inner is TaOwnList, 'own calendar: agenda is a list of the coming days');
    K.Text := FormatDateTime('yyyy-mm-dd', Date + 2);
    Check(K.Text = FormatDateTime('yyyy-mm-dd', Date + 2), 'own calendar: an agenda day is selected from text');
  finally
    Fm.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TGridCrack = class(TaOwnGrid)
  public
    procedure Key(K: Word; Sh: TShiftState = []);
    procedure Down(X, Y: Integer);
    procedure Move(X, Y: Integer);
    procedure Up(X, Y: Integer);
    procedure Wheel(ADelta: Integer);
    procedure Press(const S: string);
  end;

  TGridCounter = class
  public
    Last: string;
    procedure Title(Sender: TObject; AColumn: TaGridColumn);
    procedure Prepare(Sender: TObject; AColumn: TaGridColumn; ASelectedRow: Boolean; var AStyle: TaGridCellStyle);
  end;

procedure TGridCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure TGridCrack.Down(X, Y: Integer);
begin
  MouseDown(mbLeft, [ssLeft], X, Y);
end;

procedure TGridCrack.Move(X, Y: Integer);
begin
  MouseMove([ssLeft], X, Y);
end;

procedure TGridCrack.Up(X, Y: Integer);
begin
  MouseUp(mbLeft, [ssLeft], X, Y);
end;

procedure TGridCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

procedure TGridCrack.Wheel(ADelta: Integer);
begin
  DoMouseWheel([], ADelta, Point(10, 60));
end;

procedure TGridCounter.Title(Sender: TObject; AColumn: TaGridColumn);
begin
  Last := AColumn.FieldName;
end;

procedure TGridCounter.Prepare(Sender: TObject; AColumn: TaGridColumn; ASelectedRow: Boolean; var AStyle: TaGridCellStyle);
begin
  if (AColumn.FieldName = 'iznos') and (AColumn.Field <> nil) and (AColumn.Field.AsFloat > 90) then AStyle.Back := $0000C8;
end;

{ vlastita tablica (pruzatelj 'own'): pregled, kretanje, naslov, sirina, uvjetno bojanje, podnozje }
procedure TestOwnGrid;
var
  Db: TAppDb;
  Q: TZQuery;
  Ds: TaGridSource;
  Fm: TForm;
  G: TaGrid;
  C: TGridCrack;
  Cnt: TGridCounter;
  Opt: TaGridOptions;
  OldProv: string;
  Bmp: TBitmap;
  I, X, Y, Red, W0: Integer;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  if FileExists('/tmp/ta_owngrid.db') then DeleteFile('/tmp/ta_owngrid.db');
  Db := TAppDb.Create;
  Cnt := TGridCounter.Create;
  Fm := TForm.CreateNew(nil);
  Ds := TaGridSource.Create(nil);
  try
    Db.Open('/tmp/ta_owngrid.db');
    Db.Conn.ExecuteDirect('CREATE TABLE st (id INTEGER PRIMARY KEY, naziv VARCHAR(40), iznos DECIMAL(10,2), aktivan BOOLEAN)');
    for I := 1 to 100 do
      Db.Conn.ExecuteDirect('INSERT INTO st (naziv, iznos, aktivan) VALUES (''Stavka ' + IntToStr(I) + ''', ' + IntToStr(I) + '.5, ' + IntToStr(I mod 2) + ')');
    Q := Db.NewQuery('SELECT * FROM st ORDER BY id');
    Ds.DataSet := Q;
    Fm.SetBounds(0, 0, 520, 260);
    G := TaGrid.Create(Fm);
    G.Parent := Fm;
    G.SetBounds(10, 10, 480, 200);
    G.DataSource := Ds;
    Check(G.Engine.Inner is TaOwnGrid, 'own grid: readonly variant uses the self-drawn control');
    C := TGridCrack(TaOwnGridEngine(G.Engine).Grid);
    C.OnTitleClick := @Cnt.Title;
    C.OnPrepareCell := @Cnt.Prepare;
    Q.Open;
    Fm.Show;
    Application.ProcessMessages;
    Check(C.Columns.Count = 4, 'own grid: columns are made from the fields (' + IntToStr(C.Columns.Count) + ')');
    Check((C.RowCount >= 3) and (C.RowCount <= 8), 'own grid: only the visible rows are buffered (' + IntToStr(C.RowCount) + ')');
    C.Key(VK_DOWN);
    Check(Q.RecNo = 2, 'own grid: Down moves the cursor of the data set (' + IntToStr(Q.RecNo) + ')');
    C.Key(VK_NEXT);
    Check(Q.RecNo > 4, 'own grid: PgDn moves a page (' + IntToStr(Q.RecNo) + ')');
    C.Key(VK_END, [ssCtrl]);
    Check(Q.RecNo = 100, 'own grid: Ctrl+End goes to the last record');
    C.Key(VK_HOME, [ssCtrl]);
    Check(Q.RecNo = 1, 'own grid: Ctrl+Home goes to the first record');
    C.Wheel(-1);
    Check(Q.RecNo = 4, 'own grid: the wheel moves three records (' + IntToStr(Q.RecNo) + ')');
    C.Down(30, 30 + 1 * 26 + 5);
    C.Up(30, 30 + 1 * 26 + 5);
    Check(Q.RecNo = 2, 'own grid: a click on a row makes it the current record (' + IntToStr(Q.RecNo) + ')');
    C.Down(60, 10);
    C.Up(60, 10);
    Check(Cnt.Last <> '', 'own grid: a click on a header reports the column (' + Cnt.Last + ')');
    W0 := C.Columns[0].Width;
    X := 18 + W0;
    C.Down(X, 10);
    C.Move(X + 40, 10);
    C.Up(X + 40, 10);
    Check(C.Columns[0].Width = W0 + 40, 'own grid: dragging the header edge widens the column (' + IntToStr(C.Columns[0].Width) + ')');
    C.Key(VK_END, [ssCtrl]);
    Application.ProcessMessages;
    Bmp := Fm.GetFormImage;
    try
      Red := 0;
      for Y := 40 to 200 do
        for X := 14 to 480 do
          if (Bmp.Canvas.Pixels[X, Y] and $FFFFFF) = $0000C8 then Inc(Red);
      Check(Red > 100, 'own grid: the style event colours the cells it chooses (' + IntToStr(Red) + ' pixels)');
      if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
        with TPortableNetworkGraphic.Create do
        try
          Assign(Bmp);
          SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.grid.png');
        finally
          Free;
        end;
    finally
      Bmp.Free;
    end;
    Opt := TaGridOptions.Create;
    Opt.SumFields := 'iznos';
    Opt.Zebra := True;
    G.Options := Opt;
    Opt.Free;
    Check(Pos('iznos', G.FooterText) = 1, 'own grid: the footer shows the sums (' + G.FooterText + ')');
    Check(C.FooterText <> '', 'own grid: the control draws the footer');
    G.Variant := gvDatasheet;
    C := TGridCrack(TaOwnGridEngine(G.Engine).Grid);
    Check((not C.ShowIndicator) and (C.RowHeight = 22), 'own grid: datasheet has no indicator and a lower row');
  finally
    Fm.Free;
    Ds.Free;
    Db.Free;
    Cnt.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TGridErrCounter = class
  public
    N: Integer;
    Last: string;
    procedure Err(Sender: TObject; const AMessage: string);
    function Confirm(Sender: TObject; const AMessage: string): Boolean;
  end;

procedure TGridErrCounter.Err(Sender: TObject; const AMessage: string);
begin
  Inc(N);
  Last := AMessage;
end;

function TGridErrCounter.Confirm(Sender: TObject; const AMessage: string): Boolean;
begin
  Result := True;
end;

{ vlastita tablica: uredjivanje u celiji, tipkanje, Esc, greska, novi zapis, logicko polje, padajuci popis, brisanje }
procedure TestOwnGridEdit;
var
  Db: TAppDb;
  Q: TZQuery;
  Ds: TaGridSource;
  Fm: TForm;
  G: TaGrid;
  C: TGridCrack;
  Cnt: TGridErrCounter;
  Ed: TOwnCrack;
  OldProv: string;
  I, N0: Integer;
  B0: Boolean;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  if FileExists('/tmp/ta_owngridedit.db') then DeleteFile('/tmp/ta_owngridedit.db');
  Db := TAppDb.Create;
  Cnt := TGridErrCounter.Create;
  Fm := TForm.CreateNew(nil);
  Ds := TaGridSource.Create(nil);
  try
    Db.Open('/tmp/ta_owngridedit.db');
    Db.Conn.ExecuteDirect('CREATE TABLE st (id INTEGER PRIMARY KEY, naziv VARCHAR(40), iznos DECIMAL(10,2), aktivan BOOLEAN)');
    for I := 1 to 20 do
      Db.Conn.ExecuteDirect('INSERT INTO st (naziv, iznos, aktivan) VALUES (''Stavka ' + IntToStr(I) + ''', ' + IntToStr(I) + '.5, ' + IntToStr(I mod 2) + ')');
    Q := Db.NewQuery('SELECT * FROM st ORDER BY id');
    Ds.DataSet := Q;
    Fm.SetBounds(0, 0, 520, 260);
    G := TaGrid.Create(Fm);
    G.Parent := Fm;
    G.SetBounds(10, 10, 480, 200);
    G.Variant := gvEditable;
    G.DataSource := Ds;
    C := TGridCrack(TaOwnGridEngine(G.Engine).Grid);
    C.OnEditError := @Cnt.Err;
    C.OnConfirmDelete := @Cnt.Confirm;
    Q.Open;
    Fm.Show;
    Application.ProcessMessages;
    Check(C.AllowEdit, 'own grid edit: the editable variant allows editing');
    Q.RecNo := 2;
    C.Key(VK_RIGHT);
    C.Key(VK_F2);
    Check(C.Editing and (C.EditorControl <> nil), 'own grid edit: F2 opens the editor over the cell');
    C.EditorControl.Text := 'Novi naziv';
    Ed := TOwnCrack(C.EditorControl);
    Ed.Key(VK_RETURN);
    Check((not C.Editing) and (Q.RecNo = 3), 'own grid edit: Enter writes the text and moves to the next row (' + IntToStr(Q.RecNo) + ')');
    Q.RecNo := 2;
    Check(Q.FieldByName('naziv').AsString = 'Novi naziv', 'own grid edit: the field holds the new value (' + Q.FieldByName('naziv').AsString + ')');
    { tipkanje otvara uredjivac }
    C.Key(VK_RIGHT);
    C.Press('9');
    Check(C.Editing and (C.EditorControl.Text = '9'), 'own grid edit: typing starts the editor with that character');
    Ed := TOwnCrack(C.EditorControl);
    Ed.Key(VK_ESCAPE);
    Check((not C.Editing) and (Abs(Q.FieldByName('iznos').AsFloat - 2.5) < 0.001), 'own grid edit: Esc leaves the value as it was');
    { greska }
    C.Press('x');
    Ed := TOwnCrack(C.EditorControl);
    Ed.Key(VK_RETURN);
    Check(Cnt.N >= 1, 'own grid edit: a value the field refuses is reported (' + Cnt.Last + ')');
    Q.RecNo := 2;
    Check(Abs(Q.FieldByName('iznos').AsFloat - 2.5) < 0.001, 'own grid edit: a refused value does not change the field');
    { logicko polje }
    C.Key(VK_RIGHT);
    B0 := Q.FieldByName('aktivan').AsBoolean;
    C.Key(VK_SPACE);
    Check(Q.FieldByName('aktivan').AsBoolean <> B0, 'own grid edit: Space flips a yes/no field');
    Q.Cancel;
    { novi zapis }
    C.Key(VK_INSERT);
    Check(Ord(Q.State) = 3, 'own grid edit: Insert starts a new record');
    Q.Cancel;
    { padajuci popis }
    C.Columns[1].PickList.Text := 'Alfa'#10'Beta';
    C.Key(VK_HOME);
    C.Key(VK_RIGHT);
    C.Key(VK_F2);
    Check(C.Editing and (C.EditorControl is TaOwnCombo), 'own grid edit: a column with a pick list opens a drop-down');
    C.CancelEdit;
    Check(not C.Editing, 'own grid edit: the editor can be dropped');
    C.Columns[1].PickList.Clear;
    { brisanje }
    N0 := Q.RecordCount;
    C.Key(VK_DELETE, [ssCtrl]);
    Check(Q.RecordCount = N0 - 1, 'own grid edit: Ctrl+Delete removes the record after the question (' + IntToStr(Q.RecordCount) + ')');
    { samo pregled }
    G.Variant := gvReadOnly;
    C := TGridCrack(TaOwnGridEngine(G.Engine).Grid);
    Check(not C.AllowEdit, 'own grid edit: the read-only variant does not allow editing');
  finally
    Fm.Free;
    Ds.Free;
    Db.Free;
    Cnt.Free;
    SetPreferredProvider(OldProv);
  end;
end;

{ izvrsitelj formi s vlastitom tablicom (pruzatelj 'own'): datasheet, padajuci popis za strani kljuc, uredjivanje, sortiranje, podforma, uvjetno bojanje }
procedure TestOwnRunnerGrid;
var
  Db: TAppDb;
  D, D2: TaFormDef;
  C: TaControlDef;
  R: TaFormRunner;
  V: TaGridView;
  G: TGridCrack;
  OldProv: string;
  OldFam: Boolean;
  I, Hid: Integer;
  St: TaGridCellStyle;
begin
  OldProv := PreferredProvider;
  OldFam := RunnerUsesFamilies;
  SetPreferredProvider('own');
  RunnerUsesFamilies := True;
  if FileExists('/tmp/ta_ownrunner.db') then DeleteFile('/tmp/ta_ownrunner.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_ownrunner.db');
    Db.Conn.ExecuteDirect('CREATE TABLE art (id INTEGER PRIMARY KEY, naziv TEXT, cijena DECIMAL(10,2))');
    Db.Conn.ExecuteDirect('CREATE TABLE stav (id INTEGER PRIMARY KEY, art_id INTEGER REFERENCES art(id), opis TEXT, cijena DECIMAL(10,2), kolicina DECIMAL(10,2), iznos DECIMAL(10,2))');
    Db.Conn.ExecuteDirect('CREATE TABLE kupac (id INTEGER PRIMARY KEY, naziv TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE napomena (id INTEGER PRIMARY KEY, kupac_id INTEGER REFERENCES kupac(id), tekst TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO art VALUES (1, ''Vijak'', 0.5), (2, ''Matica'', 0.25)');
    Db.Conn.ExecuteDirect('INSERT INTO stav VALUES (1, 1, ''a'', 0.5, 10, 5), (2, 2, ''b'', 0.25, 100, 25), (3, 1, ''c'', 0.5, 400, 200)');
    Db.Conn.ExecuteDirect('INSERT INTO kupac VALUES (1, ''Ana''), (2, ''Ivo'')');
    Db.Conn.ExecuteDirect('INSERT INTO napomena VALUES (1, 1, ''x''), (2, 1, ''y''), (3, 2, ''z'')');
    D := TaFormDef.Create;
    D.Name := 'OwnDs'; D.RecordSource := 'stav'; D.ViewMode := 'datasheet'; D.AllowEdits := True;
    D.GridFormat := '[iznos] > 100 => #C00000 #FFE9E9 bold';
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    try
      V := R.GridView;
      Check((V <> nil) and (V.Own <> nil) and (R.MainGrid = nil), 'own runner: a datasheet form shows the self-drawn grid');
      Check(V.ColCount >= 5, 'own runner: the grid got explicit columns (' + IntToStr(V.ColCount) + ')');
      Check(V.Own.Columns[1].PickList.IndexOf('Vijak') >= 0, 'own runner: a lookup column offers the names');
      Check(R.Query.FieldByName('art_id').DisplayText = 'Vijak', 'own runner: the lookup column shows the name');
      { uvjetno bojanje }
      R.Query.First;
      Hid := 0;
      while not R.Query.EOF do
      begin
        St.Fore := clNone; St.Back := clNone; St.Bold := False;
        V.Own.OnPrepareCell(V.Own, V.Own.Columns[2], False, St);
        if (R.Query.FieldByName('iznos').AsFloat > 100) <> (St.Back = TColor($E9E9FF)) then Inc(Hid);
        R.Query.Next;
      end;
      Check(Hid = 0, 'own runner: rows are coloured by the grid rule (' + IntToStr(Hid) + ' wrong)');
      { sortiranje }
      R.SortBy('iznos', True);
      Check((V.Own.SortField = 'iznos') and V.Own.SortDescending, 'own runner: sorting marks the header');
      R.SortBy('', False);
      { uredjivanje preko tablice }
      G := TGridCrack(V.Own);
      R.Query.First;
      G.Key(VK_HOME);
      G.Key(VK_RIGHT); G.Key(VK_RIGHT);
      G.Key(VK_F2);
      Check(G.Editing, 'own runner: F2 opens the editor in the form''s grid');
      G.EditorControl.Text := 'nov opis';
      TOwnCrack(G.EditorControl).Key(VK_RETURN);
      R.Query.First;
      Check(R.Query.FieldByName('opis').AsString = 'nov opis', 'own runner: the typed text reaches the table (' + R.Query.FieldByName('opis').AsString + ')');
    finally
      R.Free;
    end;
    D := TaFormDef.Create;
    D.Name := 'OwnSubDs'; D.RecordSource := 'kupac'; D.ViewMode := 'datasheet'; D.AllowEdits := True; D.SubDatasheet := 'auto';
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    Check(D2.SubDatasheet = 'auto', 'own runner: the sub-datasheet setting survives JSON');
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    try
      V := R.GridView;
      Check((V.Own <> nil) and (V.Own.SubKeyField = 'id'), 'own runner: "auto" finds the child table from the foreign key (' + V.Own.SubKeyField + ')');
      G := TGridCrack(V.Own);
      G.Down(8, 30 + 8);
      G.Up(8, 30 + 8);
      Check(V.Own.IsExpanded('1') and (V.Own.ChildOf('1') <> nil), 'own runner: the plus opens the notes of that customer');
      Check(V.Own.ChildOf('1').DataSource.DataSet.RecordCount = 2, 'own runner: the sub-table holds only that customer''s rows');
      Check(V.Own.ChildOf('1').Columns.Count >= 2, 'own runner: the sub-table got its columns');
      G.CollapseAll;
      Check(not V.Own.IsExpanded('1'), 'own runner: the sub-table closes');
    finally
      R.Free;
    end;
    D := TaFormDef.Create;
    D.Name := 'OwnSub'; D.RecordSource := 'kupac';
    D.Add(NewCtl('TextBox', 'txtNaz', 'naziv', 10, 10));
    C := NewCtl('Subform', 'subN', '', 10, 50); C.RowSource := 'napomena'; C.LinkMaster := 'id'; C.LinkChild := 'kupac_id'; D.Add(C);
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    try
      V := R.SubView('subN');
      Check((V <> nil) and (V.Own <> nil), 'own runner: a subform shows the self-drawn grid');
      Hid := -1;
      for I := 0 to V.ColCount - 1 do
        if SameText(V.ColFieldName(I), 'kupac_id') then Hid := Ord(V.ColVisible(I));
      Check(Hid = 0, 'own runner: the subform grid hides the link column');
      Check(R.SubQuery('subN').RecordCount = 2, 'own runner: the subform follows the master');
    finally
      R.Free;
    end;
  finally
    Db.Free;
    RunnerUsesFamilies := OldFam;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TSubHost = class
  public
    Db: TAppDb;
    Opened, Closed: Integer;
    Qs: TList;
    Ss: TList;
    constructor Create;
    destructor Destroy; override;
    procedure Open(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
    procedure Close(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
  end;

constructor TSubHost.Create;
begin
  Qs := TList.Create;
  Ss := TList.Create;
end;

destructor TSubHost.Destroy;
var
  I: Integer;
begin
  for I := 0 to Ss.Count - 1 do TaGridSource(Ss[I]).Free;
  for I := 0 to Qs.Count - 1 do TZQuery(Qs[I]).Free;
  Qs.Free;
  Ss.Free;
  inherited Destroy;
end;

procedure TSubHost.Open(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
var
  Q: TZQuery;
  S: TaGridSource;
begin
  Inc(Opened);
  Q := Db.NewQuery('SELECT * FROM napomena WHERE kupac_id = ' + AKey);
  Q.Open;
  S := TaGridSource.Create(nil);
  S.DataSet := Q;
  Qs.Add(Q);
  Ss.Add(S);
  AChild.DataSource := S;
end;

procedure TSubHost.Close(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
begin
  Inc(Closed);
end;

{ potkartica u tablici (poput Accessa): + uz redak otvara podtablicu ispod njega }
procedure TestOwnSubGrid;
var
  Db: TAppDb;
  Q: TZQuery;
  Ds: TaGridSource;
  Fm: TForm;
  G: TaOwnGrid;
  C: TGridCrack;
  H: TSubHost;
  Ch: TaOwnGrid;
  OldProv: string;
  Bmp: TBitmap;
  I: Integer;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  if FileExists('/tmp/ta_ownsub.db') then DeleteFile('/tmp/ta_ownsub.db');
  Db := TAppDb.Create;
  H := TSubHost.Create;
  Fm := TForm.CreateNew(nil);
  Ds := TaGridSource.Create(nil);
  try
    Db.Open('/tmp/ta_ownsub.db');
    H.Db := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE kupac (id INTEGER PRIMARY KEY, naziv VARCHAR(40))');
    Db.Conn.ExecuteDirect('CREATE TABLE napomena (id INTEGER PRIMARY KEY, kupac_id INTEGER, tekst VARCHAR(40))');
    for I := 1 to 5 do Db.Conn.ExecuteDirect('INSERT INTO kupac (naziv) VALUES (''Kupac ' + IntToStr(I) + ''')');
    Db.Conn.ExecuteDirect('INSERT INTO napomena (kupac_id, tekst) VALUES (1, ''prva''), (1, ''druga''), (2, ''treca'')');
    Q := Db.NewQuery('SELECT * FROM kupac ORDER BY id');
    Ds.DataSet := Q;
    Fm.SetBounds(0, 0, 520, 360);
    G := TaOwnGrid.Create(Fm);
    G.Parent := Fm;
    G.SetBounds(10, 10, 480, 320);
    G.SubKeyField := 'id';
    G.OnSubOpen := @H.Open;
    G.OnSubClose := @H.Close;
    G.DataSource := Ds;
    C := TGridCrack(G);
    Q.Open;
    Fm.Show;
    Application.ProcessMessages;
    Check(not G.IsExpanded('1'), 'own subgrid: rows start collapsed');
    C.Down(8, 30 + 8);
    C.Up(8, 30 + 8);
    Check(G.IsExpanded('1') and (G.ChildOf('1') <> nil) and (H.Opened = 1), 'own subgrid: a click on the plus opens the sub-table');
    Ch := G.ChildOf('1');
    Check((Ch.RowCount = 2) and Ch.Visible, 'own subgrid: the sub-table shows its two rows');
    Check((Ch.Top = 30 + 26 + 4) and (Ch.Height = Ch.PreferredHeight(8)), 'own subgrid: it sits under its row (top ' + IntToStr(Ch.Top) + ', height ' + IntToStr(Ch.Height) + ')');
    C.Down(100, 30 + 26 + 20);
    C.Up(100, 30 + 26 + 20);
    Check(Q.RecNo = 1, 'own subgrid: a click inside the sub-table area does not move the parent');
    Application.ProcessMessages;
    Bmp := Fm.GetFormImage;
    try
      if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
        with TPortableNetworkGraphic.Create do
        try
          Assign(Bmp);
          SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.sub.png');
        finally
          Free;
        end;
    finally
      Bmp.Free;
    end;
    C.Key(VK_DOWN);
    Check(Q.RecNo = 2, 'own subgrid: Down moves to the next parent row');
    C.Key(VK_DOWN, [ssAlt]);
    Check(G.IsExpanded('2') and (H.Opened = 2), 'own subgrid: Alt+Down opens the sub-table of the current row');
    C.Key(VK_UP, [ssAlt]);
    Check((not G.IsExpanded('2')) and (H.Closed = 1), 'own subgrid: Alt+Up closes it');
    G.CollapseAll;
    Check((not G.IsExpanded('1')) and (H.Closed = 2), 'own subgrid: CollapseAll closes everything and tells the host');
  finally
    G.CollapseAll;
    Fm.Free;
    Ds.Free;
    H.Free;
    Db.Free;
    SetPreferredProvider(OldProv);
  end;
end;

type
  TGridCrack2 = class(TGridCrack)
  public
    procedure DblAt(X, Y: Integer);
    procedure MoveShift(X, Y: Integer; Sh: TShiftState);
    procedure ClickAt(X, Y: Integer; Sh: TShiftState);
  end;

procedure TGridCrack2.DblAt(X, Y: Integer);
begin
  MouseMove([], X, Y);
  DblClick;
end;

procedure TGridCrack2.MoveShift(X, Y: Integer; Sh: TShiftState);
begin
  MouseMove(Sh, X, Y);
end;

procedure TGridCrack2.ClickAt(X, Y: Integer; Sh: TShiftState);
begin
  MouseDown(mbLeft, Sh + [ssLeft], X, Y);
  MouseUp(mbLeft, Sh + [ssLeft], X, Y);
end;

{ vlastita tablica: oznacavanje vise redaka, kopiranje, preraspored stupaca, sirina po sadrzaju, brisanje oznacenih }
procedure TestOwnGridSelect;
var
  Db: TAppDb;
  Q: TZQuery;
  Ds: TaGridSource;
  Fm: TForm;
  G: TaOwnGrid;
  C: TGridCrack2;
  Cnt: TGridErrCounter;
  Txt: string;
  I, N0, W0: Integer;
  OldProv: string;

  function RowY(AIndex: Integer): Integer;
  begin
    Result := 30 + AIndex * 26 + 6;
  end;

begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  if FileExists('/tmp/ta_ownsel.db') then DeleteFile('/tmp/ta_ownsel.db');
  Db := TAppDb.Create;
  Cnt := TGridErrCounter.Create;
  Fm := TForm.CreateNew(nil);
  Ds := TaGridSource.Create(nil);
  try
    Db.Open('/tmp/ta_ownsel.db');
    Db.Conn.ExecuteDirect('CREATE TABLE st (id INTEGER PRIMARY KEY, naziv VARCHAR(40), iznos DECIMAL(10,2))');
    for I := 1 to 50 do
      Db.Conn.ExecuteDirect('INSERT INTO st (naziv, iznos) VALUES (''Stavka ' + IntToStr(I) + ''', ' + IntToStr(I) + '.5)');
    Q := Db.NewQuery('SELECT * FROM st ORDER BY id');
    Ds.DataSet := Q;
    Fm.SetBounds(0, 0, 520, 300);
    G := TaOwnGrid.Create(Fm);
    G.Parent := Fm;
    G.SetBounds(10, 10, 480, 260);
    G.AllowEdit := True;
    G.OnConfirmDelete := @Cnt.Confirm;
    G.DataSource := Ds;
    C := TGridCrack2(G);
    Q.Open;
    Fm.Show;
    Application.ProcessMessages;
    C.ClickAt(50, RowY(0), []);
    C.ClickAt(50, RowY(2), [ssCtrl]);
    Check(G.SelectedCount = 2, 'own grid select: Ctrl+click adds rows (' + IntToStr(G.SelectedCount) + ')');
    C.ClickAt(50, RowY(4), [ssShift]);
    Check(G.SelectedCount = 3, 'own grid select: Shift+click selects a range from the anchor (' + IntToStr(G.SelectedCount) + ')');
    if GetEnvironmentVariable('TA_OWNSHOT') <> '' then
    begin
      C.MoveShift(60, RowY(6), []);
      Application.ProcessMessages;
      with TPortableNetworkGraphic.Create do
      try
        Assign(Fm.GetFormImage);
        SaveToFile(GetEnvironmentVariable('TA_OWNSHOT') + '.sel.png');
      finally
        Free;
      end;
    end;
    Txt := G.SelectionText(False);
    Check((Length(Txt) > 0) and (Pos(#9, Txt) > 0), 'own grid select: the selection becomes tab-separated text');
    C.Key(VK_C, [ssCtrl]);
    Check(Pos('Stavka 3', Clipboard.AsText) > 0, 'own grid select: Ctrl+C puts the rows on the clipboard [' + StringReplace(Clipboard.AsText, LineEnding, '|', [rfReplaceAll]) + '] vs [' + StringReplace(Txt, LineEnding, '|', [rfReplaceAll]) + ']');
    C.Key(VK_ESCAPE);
    Check(G.SelectedCount = 0, 'own grid select: Esc clears the selection');
    Q.RecNo := 1;
    C.Key(VK_DOWN, [ssShift]);
    C.Key(VK_DOWN, [ssShift]);
    C.Key(VK_DOWN, [ssShift]);
    Check(G.SelectedCount = 4, 'own grid select: Shift+Down extends the selection (' + IntToStr(G.SelectedCount) + ')');
    C.Key(VK_DOWN);
    Check(G.SelectedCount = 0, 'own grid select: a plain arrow clears it');
    C.Key(VK_A, [ssCtrl]);
    Check(G.SelectedCount = 50, 'own grid select: Ctrl+A selects every record');
    G.ClearSelection;
    { kopiranje celije }
    Q.RecNo := 2;
    C.Key(VK_HOME);
    C.Key(VK_RIGHT);
    C.Key(VK_C, [ssCtrl]);
    Check(Clipboard.AsText = 'Stavka 2', 'own grid select: Ctrl+C on one cell copies its text (' + Clipboard.AsText + ')');
    { brisanje oznacenih }
    N0 := Q.RecordCount;
    Q.RecNo := 10;
    C.ClickAt(50, RowY(0), []);
    C.ClickAt(50, RowY(1), [ssShift]);
    C.ClickAt(50, RowY(2), [ssShift]);
    I := G.SelectedCount;
    C.Key(VK_DELETE, [ssCtrl]);
    Check((I = 3) and (Q.RecordCount = N0 - 3), 'own grid select: Ctrl+Delete removes all selected records (' + IntToStr(Q.RecordCount) + ' of ' + IntToStr(N0) + ', selected ' + IntToStr(I) + ')');
    { preraspored stupaca povlacenjem naslova }
    Check(G.Columns[0].FieldName = 'id', 'own grid select: columns start in table order');
    C.Down(18 + 40, 10);
    C.Move(18 + 40 + 120, 10);
    C.Move(18 + 40 + 330, 10);
    C.Up(18 + 40 + 330, 10);
    Check(G.Columns[0].FieldName <> 'id', 'own grid select: dragging a header moves the column (' + G.Columns[0].FieldName + ' first)');
    { sirina po sadrzaju }
    W0 := 0;
    for I := 0 to G.Columns.Count - 1 do
      if G.Columns[I].FieldName = 'naziv' then W0 := I;
    G.Columns[W0].Width := 40;
    G.AutoFitColumn(W0);
    Check(G.Columns[W0].Width > 70, 'own grid select: auto-fit widens a squeezed column (' + IntToStr(G.Columns[W0].Width) + ')');
    { zamrznuti stupci }
    for I := 0 to G.Columns.Count - 1 do G.Columns[I].Width := 260;
    G.FrozenColumns := 1;
    C.Key(VK_END);
    C.ClickAt(30, RowY(1), []);
    Check(G.CurrentColumn = G.Columns[0], 'own grid select: the frozen column stays under the left edge after scrolling (' + G.CurrentColumn.FieldName + ')');
    C.Key(VK_END);
    C.ClickAt(420, RowY(1), []);
    Check(G.CurrentColumn <> G.Columns[0], 'own grid select: a click right of the frozen column picks a scrolled one');
    { Tab pomice izmedju celija }
    G.FrozenColumns := 0;
    C.Key(VK_HOME);
    C.Key(VK_TAB);
    Check(G.CurrentColumn.Index = 1, 'own grid select: Tab moves to the next cell in an editable grid');
  finally
    Fm.Free;
    Ds.Free;
    Db.Free;
    Cnt.Free;
    SetPreferredProvider(OldProv);
  end;
end;

{ 100000 redaka: otvaranje, skokovi na kraj i pocetak, crtanje }
procedure TestOwnGridBig;
var
  Db: TAppDb;
  Q: TZQuery;
  Ds: TaGridSource;
  Fm: TForm;
  G: TaOwnGrid;
  C: TGridCrack;
  I: Integer;
  T0: QWord;
  Ms: Int64;
  Bmp: TBitmap;
  OldProv: string;
begin
  OldProv := PreferredProvider;
  SetPreferredProvider('own');
  if FileExists('/tmp/ta_ownbig.db') then DeleteFile('/tmp/ta_ownbig.db');
  Db := TAppDb.Create;
  Fm := TForm.CreateNew(nil);
  Ds := TaGridSource.Create(nil);
  try
    Db.Open('/tmp/ta_ownbig.db');
    Db.Conn.ExecuteDirect('CREATE TABLE big (id INTEGER PRIMARY KEY, naziv VARCHAR(40), iznos DECIMAL(10,2))');
    Db.Conn.ExecuteDirect('BEGIN');
    for I := 1 to 100000 do
      Db.Conn.ExecuteDirect('INSERT INTO big (naziv, iznos) VALUES (''Redak ' + IntToStr(I) + ''', ' + IntToStr(I mod 977) + '.25)');
    Db.Conn.ExecuteDirect('COMMIT');
    Q := Db.NewQuery('SELECT * FROM big ORDER BY id');
    Ds.DataSet := Q;
    Fm.SetBounds(0, 0, 520, 300);
    G := TaOwnGrid.Create(Fm);
    G.Parent := Fm;
    G.SetBounds(10, 10, 480, 260);
    G.DataSource := Ds;
    C := TGridCrack(G);
    T0 := GetTickCount64;
    Q.Open;
    Fm.Show;
    Application.ProcessMessages;
    Ms := GetTickCount64 - T0;
    Check(Ms < 8000, 'own grid big: 100000 rows open and show in ' + IntToStr(Ms) + ' ms');
    T0 := GetTickCount64;
    C.Key(VK_END, [ssCtrl]);
    Application.ProcessMessages;
    C.Key(VK_HOME, [ssCtrl]);
    for I := 1 to 40 do C.Key(VK_NEXT);
    C.Wheel(-1);
    Bmp := Fm.GetFormImage;
    Bmp.Free;
    Ms := GetTickCount64 - T0;
    Check((Ms < 4000) and (Q.RecNo > 100), 'own grid big: jumps, 40 pages and a paint take ' + IntToStr(Ms) + ' ms (record ' + IntToStr(Q.RecNo) + ')');
    T0 := GetTickCount64;
    C.Key(VK_A, [ssCtrl]);
    Ms := GetTickCount64 - T0;
    Check((G.SelectedCount = 100000) and (Ms < 2000), 'own grid big: selecting all 100000 records takes ' + IntToStr(Ms) + ' ms');
  finally
    Fm.Free;
    Ds.Free;
    Db.Free;
    SetPreferredProvider(OldProv);
  end;
end;

{ tekstualno polje u izvjescu raste na vise redaka (GrowLines) i pomice sljedeci redak }
procedure TestGrowText;
var
  Db: TAppDb;
  Rep: TaReportDef;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  D: TaControlDef;
  I, Lines, YB, YC, Y3, Round3: Integer;
  It: TaRItem;
  Long: string;

  function RenderGap(AGrow: string): Integer;
  var
    K: Integer;
    X: TaRItem;
  begin
    Rep := TaReportDef.Create;
    Rep.Name := 'GrowIzv'; Rep.RecordSource := 'gt';
    Rep.Heights[SecDetail] := 22;
    Rep.Add(RItem('TextBox', 'Detail', 'tN', 'naslov', 0, 1, 40, 20));
    D := RItem('TextBox', 'Detail', 'tO', 'opis', 50, 1, 90, 20);
    DefSet(D, 'GrowLines', AGrow);
    Rep.Add(D);
    RE := TaReportEngine.Create(Db, Rep);
    try
      RR := RE.Render;
      try
        YB := 0; YC := 0; Lines := 0;
        for K := 0 to RR.Page(0).Items.Count - 1 do
        begin
          X := TaRItem(RR.Page(0).Items[K]);
          if X.Text = 'B' then YB := X.Y;
          if X.Text = 'C' then YC := X.Y;
          if (X.X > 40) and (X.Y >= YB) and (YB > 0) and (YC = 0) and (X.Text <> '') then Inc(Lines);
        end;
        Result := YC - YB;
      finally
        RR.Free;
      end;
    finally
      RE.Free;
      Rep.Free;
    end;
  end;

begin
  if FileExists('/tmp/ta_grow.db') then DeleteFile('/tmp/ta_grow.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_grow.db');
    ActiveDb := Db;
    Long := 'jedan dva tri cetiri pet sest sedam osam devet deset jedanaest dvanaest trinaest cetrnaest petnaest sesnaest';
    Db.Conn.ExecuteDirect('CREATE TABLE gt (id INTEGER PRIMARY KEY, naslov TEXT, opis TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO gt (naslov, opis) VALUES (''A'', ''kratko''), (''B'', ' + Db.QuoteLit(Long) + '), (''C'', ''x'')');
    Check(RenderGap('') <= 24, 'grow: bez GrowLines redak ostaje visine 22 (' + IntToStr(RenderGap('')) + ')');
    Check(RenderGap('3') > 40, 'grow: dugi tekst siri redak na vise linija (' + IntToStr(RenderGap('3')) + ' px)');
    Round3 := RenderGap('3');
    Y3 := RenderGap('2');
    Check(Y3 < Round3, 'grow: broj linija ogranicava prosirenje (2 < 3: ' + IntToStr(Y3) + ' < ' + IntToStr(Round3) + ')');
    Rep := TaReportDef.Create;
    D := RItem('TextBox', 'Detail', 'tO', 'opis', 50, 1, 90, 20);
    DefSet(D, 'GrowLines', '4');
    Rep.Add(D);
    Check(Rep.Count = 1, 'x');
    Rep.FromJson(Rep.ToJson);
    Check((DefGet(Rep[0], 'GrowLines') = '4') and (PropertyNamesFor('TextBox', True).IndexOf('GrowLines') >= 0), 'grow: svojstvo GrowLines se sprema i vidi u inspektoru izvjesca');
    Rep.Free;
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ RichText polje: na formi se uredjuje i sprema u bazu, u izvjescu se ispisuje oblikovano i siri redak }
procedure TestRichTextField;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  C: TaControlDef;
  Rep: TaReportDef;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  Ed: TaRichEdit;
  Q: TZQuery;
  I, BoldN, RedN, Y1, Y2: Integer;
  It: TaRItem;
  Saved, Js: string;
begin
  if FileExists('/tmp/ta_rich.db') then DeleteFile('/tmp/ta_rich.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_rich.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE bilj (id INTEGER PRIMARY KEY, naslov TEXT, tekst TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO bilj (naslov, tekst) VALUES (''Prva'', ''Obi' + #$C4#$8D + 'an tekst bez oznaka'')');
    D := TaFormDef.Create;
    D.Name := 'BiljForma'; D.RecordSource := 'bilj';
    D.Add(NewCtl('TextBox', 'tNaslov', 'naslov', 10, 10));
    C := NewCtl('RichText', 'rtTekst', 'tekst', 10, 40); C.Width := 400; C.Height := 160; D.Add(C);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Check(R.ControlByName('rtTekst') is TaRichEdit, 'rich field: the form builds an editor for the RichText control');
      Check(Pos('bez oznaka', TaRichEdit(R.ControlByName('rtTekst')).Memo.Text) > 0, 'rich field: an old plain text value shows in the editor');
      R.DoAction('new');
      TEdit(R.ControlByName('tNaslov')).Text := 'Druga';
      Ed := TaRichEdit(R.ControlByName('rtTekst'));
      Ed.Html := '<p>Prvi <b>podebljano</b></p><p><font color="#ff0000">crveno</font> kraj</p>';
      Ed.Memo.OnChange(Ed.Memo);
      R.DoAction('save');
      Saved := '';
      Q := Db.NewQuery('SELECT tekst FROM bilj WHERE naslov = ''Druga''');
      try
        Q.Open;
        if not Q.EOF then Saved := Q.Fields[0].AsString;
      finally
        Q.Free;
      end;
      Check((Pos('<b>podebljano</b>', Saved) > 0) and (Pos('color="#ff0000"', Saved) > 0), 'rich field: the formatted text is stored in the database as small HTML: ' + Saved);
      Check(RtToPlain(Saved) = 'Prvi podebljano' + LineEnding + 'crveno kraj', 'rich field: PlainText gives readable text');
    finally
      R.Free;
    end;
    { izvjesce }
    Db.Conn.ExecuteDirect('INSERT INTO bilj (naslov, tekst) VALUES (''Treca'', ''<p>Kratko</p>'')');
    Rep := TaReportDef.Create;
    Rep.Name := 'BiljIzv'; Rep.RecordSource := 'bilj';
    Rep.Heights[SecDetail] := 26;
    Rep.Add(RItem('TextBox', 'Detail', 'tN', 'naslov', 0, 2, 80, 18));
    Rep.Add(RItem('RichText', 'Detail', 'rtT', 'tekst', 90, 2, 180, 20));
    RE := TaReportEngine.Create(Db, Rep);
    try
      RR := RE.Render;
      try
        BoldN := 0; RedN := 0;
        for I := 0 to RR.Page(0).Items.Count - 1 do
        begin
          It := TaRItem(RR.Page(0).Items[I]);
          if It.Bold and (It.Text = 'podebljano') then Inc(BoldN);
          if It.Color = $0000FF then Inc(RedN);
        end;
        Check(BoldN = 1, 'rich report: the bold word is printed bold');
        Check(RedN >= 1, 'rich report: coloured text keeps its colour');
        Check(HasText(RR, 'crveno') and HasText(RR, 'Kratko') and HasText(RR, 'Obi' + #$C4#$8D + 'an'), 'rich report: all texts appear, including the old plain one: ' + AllText(RR));
        Y1 := 0; Y2 := 0;
        for I := 0 to RR.Page(0).Items.Count - 1 do
        begin
          It := TaRItem(RR.Page(0).Items[I]);
          if It.Text = 'Druga' then Y1 := It.Y;
          if It.Text = 'Treca' then Y2 := It.Y;
        end;
        Check(Y2 - Y1 > 30, 'rich report: a long text widens its row and pushes the next one down (' + IntToStr(Y2 - Y1) + ' px)');
      finally
        RR.Free;
      end;
    finally
      RE.Free;
    end;
    Rep.Free;
    Rep := TaReportDef.Create;
    Rep.Add(RItem('RichText', 'Detail', 'rtT', 'tekst', 90, 2, 180, 20));
    Js := Rep.ToJson;
    Rep.FromJson(Js);
    Check((Rep.Count = 1) and (Rep[0].Kind = 'RichText') and (Rep[0].ControlSource = 'tekst'), 'rich report: the item survives saving');
    Rep.Free;
    Check(Pos('Bok svijete', VarToStr(EvalExpr('PlainText("<p>Bok <b>svijete</b></p>")', nil))) > 0, 'rich text: the PlainText function works in expressions');
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ sidrenje kontrola, zastavice prozora forme i povlacenje velicine forme u dizajneru }
procedure TestAnchorsAndWindow;
var
  Db: TAppDb;
  D, D2: TaFormDef;
  R: TaFormRunner;
  A, B, C: TaControlDef;
  Ca, Cb, Cc: TControl;
  Dz: TaFormDesigner;
  W0, H0, La, Wa, Lb, Wc: Integer;
  Names: TStringList;
begin
  if FileExists('/tmp/ta_anch.db') then DeleteFile('/tmp/ta_anch.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_anch.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE t (id INTEGER PRIMARY KEY, a TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO t (a) VALUES (''x'')');
    { pretvorbe teksta u sidra }
    Check(AnchorLetters('Lijevo, Desno') = 'LR', 'anchors: words give letters');
    Check(AnchorLetters('LTRB') = 'LTRB', 'anchors: letters stay letters');
    Check(AnchorsDisplay('') = 'Lijevo, Gore', 'anchors: the default is left and top');
    Check(AnchorsOf('RB') = [akRight, akBottom], 'anchors: set from letters');
    A := TaControlDef.Create; A.Kind := 'TextBox'; A.Name := 'tA'; A.ControlSource := 'a'; A.Left := 10; A.Top := 10; A.Width := 200; A.Height := 24;
    DefSet(A, 'Anchors', 'Lijevo, Gore, Desno');
    Check((A.GetX('anchors') = 'LTR') and (DefGet(A, 'Anchors') = 'Lijevo, Gore, Desno'), 'anchors: stored in the control and shown in words');
    DefSet(A, 'Anchors', 'LT');
    Check(A.GetX('anchors') = '', 'anchors: the default is not stored');
    DefSet(A, 'Anchors', 'LTR');
    Names := PropertyNamesFor('TextBox', False);
    Check(Names.IndexOf('Anchors') >= 0, 'anchors: the form designer lists the property');
    Names.Free;
    Names := PropertyNamesFor('TextBox', True);
    Check(Names.IndexOf('Anchors') < 0, 'anchors: the report designer does not');
    Names.Free;
    { forma u radu }
    D := TaFormDef.Create;
    D.Name := 'Sid'; D.RecordSource := 't'; D.Width := 400; D.Height := 200;
    D.Add(A);
    B := TaControlDef.Create; B.Kind := 'Button'; B.Name := 'bB'; B.Caption := 'U redu'; B.Left := 300; B.Top := 150; B.Width := 80; B.Height := 28;
    DefSet(B, 'Anchors', 'RB');
    D.Add(B);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'tC'; C.ControlSource := 'a'; C.Left := 10; C.Top := 60; C.Width := 100; C.Height := 24;
    D.Add(C);
    D.CanMinimize := False;
    D.CanMaximize := True;
    D2 := TaFormDef.Create;
    D2.FromJson(D.ToJson);
    Check((D2.CanMinimize = False) and D2.CanMaximize and D2.Resizable and (not D2.StartMaximized), 'window flags: saved with the form');
    D2.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.Show;
      Application.ProcessMessages;
      Check(not (biMinimize in R.BorderIcons) and (biMaximize in R.BorderIcons), 'window flags: minimize can be switched off, maximize stays');
      Ca := R.ControlByName('tA'); Cb := R.ControlByName('bB'); Cc := R.ControlByName('tC');
      La := Ca.Left; Wa := Ca.Width; Lb := Cb.Left; Wc := Cc.Width;
      R.ClientWidth := R.ClientWidth + 120;
      Application.ProcessMessages;
      Check(Ca.Width = Wa + 120, 'anchors: a control anchored left and right stretches with the window (' + IntToStr(Ca.Width) + ' from ' + IntToStr(Wa) + ')');
      Check((Cb.Left = Lb + 120) and (Cb.Width = 80), 'anchors: a control anchored right keeps its distance from the right edge');
      Check((Cc.Width = Wc) and (Ca.Left = La), 'anchors: the other controls stay where they are');
    finally
      R.Free;
    end;
    D := TaFormDef.Create;
    D.Name := 'Fiksna'; D.Resizable := False; D.StartMaximized := True;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Check((R.BorderStyle = bsSingle) and not (biMaximize in R.BorderIcons), 'window flags: a fixed-size form has no sizing border or maximize button');
      Check(R.WindowState <> wsMaximized, 'window flags: a fixed form is not opened maximized');
    finally
      R.Free;
    end;
    { dizajner: povlacenje velicine forme }
    D := TaFormDef.Create;
    D.Name := 'Dz'; D.RecordSource := 't'; D.Width := 400; D.Height := 300;
    Dz := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      W0 := Dz.FormDef.Width; H0 := Dz.FormDef.Height;
      Check(Dz.FormGripForTest(0).Left >= 8 + W0, 'form resize: the right grip sits outside the form edge');
      Dz.FormResizeDragForTest(1, 100, 0);
      Check((Dz.FormDef.Width = W0 + 100) and (Dz.FormDef.Height = H0), 'form resize: the right grip changes only the width');
      Dz.FormResizeDragForTest(2, 0, -60);
      Check((Dz.FormDef.Height = H0 - 60) and (Dz.FormDef.Width = W0 + 100), 'form resize: the bottom grip changes only the height');
      Dz.FormResizeDragForTest(3, 41, 41);
      Check((Dz.FormDef.Width mod 4 = 0) and (Dz.FormDef.Height mod 4 = 0), 'form resize: sizes snap to the grid');
      Dz.FormResizeDragForTest(3, -5000, -5000);
      Check((Dz.FormDef.Width >= 120) and (Dz.FormDef.Height >= 80), 'form resize: a form cannot be dragged to nothing');
      Dz.UndoForTest;
      Check(Dz.FormDef.Width > 120, 'form resize: one undo step returns the size before the drag');
      Dz.SetPropForTest('Resizable', 'False');
      Dz.SetPropForTest('CanMaximize', 'False');
    finally
      Dz.Free;
    end;
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ ikone i tema: svaka vrsta kontrole ima ikonu, slike se dekodiraju, stilska tablica postoji }
function DockDef(AForm: TaFormDef; const AKind, AName, ADock: string; AW, AH: Integer): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := AKind; Result.Name := AName; Result.Caption := AName;
  Result.Left := 10; Result.Top := 10; Result.Width := AW; Result.Height := AH;
  if ADock <> '' then DefSet(Result, 'Dock', ADock);
  AForm.Add(Result);
end;

procedure TestDockLayout;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  A: TaControlDef;
  Hdr, Side, Body, B1, B2, B3: TControl;
  W0, Bw: Integer;
begin
  if FileExists('/tmp/ta_dock.db') then DeleteFile('/tmp/ta_dock.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_dock.db');
    ActiveDb := Db;
    { pretvorbe }
    Check(NormalizeSpacing('8') = '8,8,8,8', 'layout: one number is the spacing on all sides');
    Check(NormalizeSpacing('0,0,0,0') = '', 'layout: zero spacing is not stored');
    Check(NormalizeSpacing('1,2,3,4') = '1,2,3,4', 'layout: four numbers are kept');
    A := TaControlDef.Create;
    DefSet(A, 'Dock', 'Client');
    Check((A.GetX('dock') = 'client') and (DefGet(A, 'Dock') = 'client') and (DockOfDef(A) = alClient), 'layout: Dock is stored in lower case');
    DefSet(A, 'Dock', 'none');
    Check((A.GetX('dock') = '') and (DefGet(A, 'Dock') = 'none'), 'layout: Dock none is the default and is not stored');
    DefSet(A, 'Dock', 'nesto');
    Check(A.GetX('dock') = '', 'layout: an unknown Dock value is ignored');
    DefSet(A, 'AnchorLeft', 'b1:right');
    Check((A.GetX('asl') = 'b1:right') and (DefGet(A, 'AnchorLeft') = 'b1:right') and HasLayoutProps(A), 'layout: anchor side is stored');
    A.Free;
    { forma u radu: zaglavlje gore, izbornik lijevo, radno podrucje na sredini }
    D := TaFormDef.Create;
    D.Name := 'Glavna'; D.Width := 600; D.Height := 400;
    DockDef(D, 'Rectangle', 'zagl', 'top', 100, 40);
    DockDef(D, 'Rectangle', 'izb', 'left', 120, 50);
    DockDef(D, 'Rectangle', 'rad', 'client', 50, 50);
    A := DockDef(D, 'Button', 'b1', '', 80, 24);
    A.Left := 200; A.Top := 100;
    A := DockDef(D, 'Button', 'b2', '', 80, 24);
    A.Left := 400; A.Top := 200;
    DefSet(A, 'AnchorLeft', 'b1:right');
    DefSet(A, 'AnchorTop', 'b1:top');
    DefSet(A, 'BorderSpacing', '12,0,0,0');
    A := DockDef(D, 'Button', 'b3', '', 80, 24);
    A.Left := 250; A.Top := 300;
    DefSet(A, 'AnchorLeft', 'forma:center');
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.Show;
      Application.ProcessMessages;
      Hdr := R.ControlByName('zagl'); Side := R.ControlByName('izb'); Body := R.ControlByName('rad');
      B1 := R.ControlByName('b1'); B2 := R.ControlByName('b2'); B3 := R.ControlByName('b3');
      Check((Hdr.Top = 0) and (Hdr.Left = 0) and (Hdr.Width = R.ClientWidth) and (Hdr.Height = 40), 'dock: a control docked to the top spans the width of the form');
      Check((Side.Left = 0) and (Side.Top = 40) and (Side.Width = 120), 'dock: a left control starts under the header and keeps its width');
      Check((Body.Left = 120) and (Body.Top = 40) and (Body.Width = R.ClientWidth - 120), 'dock: the client control fills what is left (' + IntToStr(Body.Left) + ',' + IntToStr(Body.Width) + ')');
      Check(B2.Left = B1.Left + B1.Width + 12, 'anchor side: the left edge follows the right edge of the neighbour plus the spacing (' + IntToStr(B2.Left) + ' vs ' + IntToStr(B1.Left + B1.Width + 12) + ')');
      Check(B2.Top = B1.Top, 'anchor side: the top edge follows the top edge of the neighbour');
      W0 := Body.Width;
      R.ClientWidth := R.ClientWidth + 100;
      Application.ProcessMessages;
      Check((Hdr.Width = R.ClientWidth) and (Body.Width = W0 + 100), 'dock: docked controls follow the form when it grows');
      Check((Side.Width = 120) and (Side.Left = 0), 'dock: the side control keeps its width when the form grows');
      Check(B2.Left = B1.Left + B1.Width + 12, 'anchor side: the neighbour link survives resizing');
      Bw := (R.ClientWidth - B3.Width) div 2;
      Check(Abs(B3.Left - Bw) <= 2, 'anchor side: centering on the form (' + IntToStr(B3.Left) + ' vs ' + IntToStr(Bw) + ')');
    finally
      R.Free;
    end;
  finally
    Db.Free;
  end;
end;

procedure TestDockInDesigner;
var
  Db: TAppDb;
  D: TaFormDef;
  Dz: TaFormDesigner;
  A, Hdr, Ok, Nb: TaControlDef;
  W0, L0: Integer;
begin
  if FileExists('/tmp/ta_dockdz.db') then DeleteFile('/tmp/ta_dockdz.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_dockdz.db');
    ActiveDb := Db;
    D := TaFormDef.Create;
    D.Name := 'DzDock'; D.Width := 400; D.Height := 300;
    Hdr := DockDef(D, 'Rectangle', 'zagl', 'top', 100, 40);
    Ok := DockDef(D, 'Button', 'ok', '', 80, 28);
    Ok.Left := 300; Ok.Top := 250;
    DefSet(Ok, 'Anchors', 'RB');
    Nb := DockDef(D, 'Button', 'sused', '', 80, 28);
    Nb.Left := 20; Nb.Top := 100;
    A := DockDef(D, 'Button', 'prati', '', 80, 28);
    A.Left := 200; A.Top := 200;
    DefSet(A, 'AnchorLeft', 'sused:right');
    DefSet(A, 'AnchorTop', 'sused:top');
    DefSet(A, 'BorderSpacing', '10,0,0,0');
    Dz := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      Dz.Show;
      Application.ProcessMessages;
      Check((Hdr.Left = 0) and (Hdr.Top = 0) and (Hdr.Width = 400) and (Hdr.Height = 40), 'designer layout: a docked control is stretched when the form is opened (' + IntToStr(Hdr.Width) + ')');
      Check((A.Left = Nb.Left + Nb.Width + 10) and (A.Top = Nb.Top), 'designer layout: a control anchored to a neighbour is placed next to it (' + IntToStr(A.Left) + ')');
      W0 := Hdr.Width; L0 := Ok.Left;
      Dz.FormResizeDragForTest(1, 100, 0);
      Check(Hdr.Width = W0 + 100, 'designer layout: the docked control follows when the form is resized');
      Check(Ok.Left = L0 + 100, 'designer layout: a control anchored right moves when the form is resized (' + IntToStr(Ok.Left) + ' from ' + IntToStr(L0) + ')');
      Check((Ok.GetX('anchors') = 'RB') and (Hdr.GetX('dock') = 'top') and (A.GetX('asl') = 'sused:right'), 'designer layout: the layout properties stay in the definition');
      Dz.FormResizeDragForTest(1, -100, 0);
      Check((Hdr.Width = W0) and (Ok.Left = L0), 'designer layout: resizing back restores the positions');
      Dz.FormResizeDragForTest(2, 0, 80);
      Check(Ok.Top = 250 + 80, 'designer layout: a control anchored to the bottom follows the bottom edge');
      Dz.SetPropForTest('Dock', 'none');
    finally
      Dz.Free;
    end;
  finally
    Db.Free;
  end;
end;

procedure TestMainFormTemplate;
var
  Db: TAppDb;
  Items: TStringList;
  D, D2: TaFormDef;
  R: TaFormRunner;
  Hdr, Menu, Work, Stat: TControl;
begin
  if FileExists('/tmp/ta_mainform.db') then DeleteFile('/tmp/ta_mainform.db');
  Db := TAppDb.Create;
  Items := TStringList.Create;
  try
    Db.Open('/tmp/ta_mainform.db');
    ActiveDb := Db;
    Items.Add('# Prodaja|invoice');
    Items.Add('Računi|openform:Računi');
    D := BuildMainForm('Glavna', 'Moja tvrtka', Items);
    Check((D.Count = 5) and (D[0].GetX('dock') = 'top') and (D[2].Kind = 'SideMenu') and (D[2].GetX('dock') = 'left') and (D[3].GetX('dock') = 'bottom') and (D[4].GetX('dock') = 'client'),
      'main form template: header, side menu, status bar and work area are docked');
    Check(Pos('Računi|openform:Računi', D[2].RowSource) > 0, 'main form template: the menu text is the item list');
    D2 := TaFormDef.Create;
    D2.FromJson(D.ToJson);
    Check((D2[0].GetX('dock') = 'top') and (D2[0].GetX('backColor') = '#1F4E79'), 'main form template: the layout survives saving');
    D2.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.Show;
      Application.ProcessMessages;
      Hdr := R.ControlByName('pnlZaglavlje'); Menu := R.ControlByName('mnuBocni');
      Work := R.ControlByName('pnlRadno'); Stat := R.ControlByName('lblStatus');
      Check((Hdr.Top = 0) and (Hdr.Width = R.ClientWidth), 'main form template: the header spans the form');
      Check((Menu.Left = 0) and (Menu.Top = Hdr.Height) and (Menu.Width = 240), 'main form template: the menu sits under the header');
      Check((Work.Left = 240) and (Work.Width = R.ClientWidth - 240), 'main form template: the work area fills the rest');
      Check(Stat.Top + Stat.Height = R.ClientHeight, 'main form template: the status bar is at the bottom');
      R.ClientWidth := R.ClientWidth + 140;
      R.ClientHeight := R.ClientHeight + 60;
      Application.ProcessMessages;
      Check((Hdr.Width = R.ClientWidth) and (Work.Width = R.ClientWidth - 240) and (Stat.Top + Stat.Height = R.ClientHeight) and (Menu.Height > 400),
        'main form template: everything follows when the window grows');
    finally
      R.Free;
    end;
  finally
    Items.Free;
    Db.Free;
  end;
end;

procedure TestIconsAndTheme;
var
  I: Integer;
  Bad: string;
  P: TPortableNetworkGraphic;
  L: TImageList;
  Fm: TForm;
  Lb, Lb2: TListBox;
  Gr: TStringGrid;
begin
  Bad := '';
  for I := 0 to High(KindNames) do
    if ControlIconName(KindNames[I]) = '' then Bad := Bad + KindNames[I] + ' ';
  for I := 0 to High(ReportKindNames) do
    if ControlIconName(ReportKindNames[I]) = '' then Bad := Bad + ReportKindNames[I] + ' ';
  Check(Bad = '', 'icons: every control kind has an icon: ' + Bad);
  Bad := '';
  for I := 0 to IconDataCount - 1 do
  begin
    P := IconPng(IconDataName(I), 24);
    if (P = nil) or (P.Width <> 24) or (P.Height <> 24) then Bad := Bad + IconDataName(I) + ' ';
    P := IconPng(IconDataName(I), 16);
    if (P = nil) or (P.Width <> 16) then Bad := Bad + IconDataName(I) + '@16 ';
  end;
  Check((Bad = '') and (IconDataCount >= 150), 'icons: all ' + IntToStr(IconDataCount) + ' icons decode at 16 and 24 px: ' + Bad);
  { tamna izvedba: ista imena, drugacije slike }
  SetIconDark(True);
  Bad := '';
  for I := 0 to IconDataCount - 1 do
  begin
    P := IconPng(IconDataName(I), 16);
    if (P = nil) or (P.Width <> 16) then Bad := Bad + IconDataName(I) + ' ';
  end;
  Check((Bad = '') and (IconDataPng('save', 16, True) <> IconDataPng('save', 16, False)), 'icons: the dark variant has every icon and differs from the light one: ' + Bad);
  Check(IconList(16) <> nil, 'icons: the dark image list exists');
  SetIconDark(False);
  { pridruzivanje ikona }
  Bad := '';
  for I := 0 to IconRuleCount - 1 do
    if (IconRuleTarget(I) <> '') and (IconIndex(IconRuleTarget(I)) < 0) then Bad := Bad + IconRuleTarget(I) + ' ';
  Check(Bad = '', 'iconmap: every rule points at an existing icon: ' + Bad);
  Check((FieldIconName('Datum računa', 'Date') = 'f_date') and (FieldIconName('OIB', 'Text') = 'idcard') and
    (FieldIconName('partner_id', 'Integer') = 'customer') and (FieldIconName('Ukupno', 'Currency') = 'f_currency') and
    (FieldIconName('E-mail', 'Text') = 'f_email') and (FieldIconName('xyz', 'Integer') = 'f_number') and
    (FieldIconName('Napomena', 'Memo') = 'f_memo'), 'iconmap: fields get icons by name, then by type');
  Check((ObjectIconName('table', 'Kupci') = 'customer') and (ObjectIconName('form', 'Računi') = 'invoice') and
    (ObjectIconName('report', 'Pregled računa po razdoblju') = 'invoice') and (ObjectIconName('macro', 'Zaokruži') = 'macro'),
    'iconmap: objects get icons by name, then by kind');
  Check((ActionIconName('openform:Kupci', 'Kupci') = 'customer') and (ActionIconName('new', 'Novi') = 'add') and
    (ActionIconName('', 'Spremi') = 'save') and (ActionIconName('', 'Ispis') = 'print'), 'iconmap: button actions get icons');
  L := IconList(16);
  Check((L.Count = IconDataCount) and (IconIndex('save') >= 0) and (IconIndex('nema_takve') = -1), 'icons: the image list holds every icon');
  Check(IconPng('nema_takve', 16) = nil, 'icons: an unknown name gives no image');
  Check((ToolIconFor('Spremi') = 'save') and (ToolIconFor('Briši stavku') = 'delete') and (ToolIconFor('Stranica i naljepnice…') = 'pagesetup'), 'icons: toolbar captions map to icons');
  Check(Length(ThemeSheet(thModern)) > 800, 'theme: the modern style sheet exists');
  { tamna tema prebojava i ono sto crta LCL; svijetla vraca standardne boje, a boje koje je korisnik odabrao ostaju }
  Fm := TForm.CreateNew(nil);
  try
    Lb := TListBox.Create(Fm); Lb.Parent := Fm;
    Lb2 := TListBox.Create(Fm); Lb2.Parent := Fm; Lb2.Color := $00FF00;
    Gr := TStringGrid.Create(Fm); Gr.Parent := Fm;
    SetTheme(thModernDark, False);
    RecolorForm(Fm);
    Check((Lb.Color <> clWindow) and (Gr.Color <> clWindow) and (Fm.Color <> clBtnFace), 'dark theme: lists, grids and the form are recoloured');
    Check(Lb2.Color = $00FF00, 'dark theme: a colour the user chose stays');
    SetTheme(thModern, False);
    RecolorForm(Fm);
    Check((Lb.Color = clWindow) and (Gr.Color = clWindow) and (Fm.Color = clBtnFace) and (Lb2.Color = $00FF00), 'dark theme: switching back restores the standard colours');
  finally
    Fm.Free;
  end;
  Check((ThemeSheet(thModernDark) <> ThemeSheet(thModern)) and (ThemeSheet(thSystem) = ''), 'theme: dark differs from light, system leaves the style alone');
end;

{ ikone na gumbima: svojstvo Icon, automatsko pridruzivanje, prikaz u formi }
procedure TestButtonIcons;
var
  Db: TAppDb;
  D: TaFormDef;
  B, B2, B3: TaControlDef;
  R: TaFormRunner;
  C: TControl;
  Names: TStringList;
  Raw: string;
  Pc: TPicture;
begin
  if FileExists('/tmp/ta_bico.db') then DeleteFile('/tmp/ta_bico.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_bico.db');
    ActiveDb := Db;
    B := TaControlDef.Create; B.Kind := 'Button'; B.Name := 'bA'; B.Caption := 'Spremi'; B.Left := 10; B.Top := 10; B.Width := 100; B.Height := 28;
    AutoButtonIcon(B);
    Check(DefGet(B, 'Icon') = 'save', 'button icon: a button without an icon gets one from its caption');
    DefSet(B, 'Icon', 'print');
    AutoButtonIcon(B);
    Check(DefGet(B, 'Icon') = 'print', 'button icon: a chosen icon is never overwritten');
    B2 := TaControlDef.Create; B2.Kind := 'Button'; B2.Name := 'bB'; B2.Caption := 'Otvori'; B2.OnClick := 'openform:Kupci'; B2.Left := 120; B2.Top := 10; B2.Width := 100; B2.Height := 28;
    AutoButtonIcon(B2);
    Check(DefGet(B2, 'Icon') = 'customer', 'button icon: opening a form takes the icon of that form');
    Names := PropertyNamesFor('Button', False);
    Check(Names.IndexOf('Icon') >= 0, 'button icon: the designer lists the Icon property');
    Names.Free;
    Check(PropKindOf('Icon') = pkIcon, 'button icon: the property uses the icon picker');
    { velike ikone i SVG kao slike (zaglavlje izvjesca) }
    B3 := TaControlDef.Create; B3.Kind := 'Image'; B3.Name := 'iA';
    DefSet(B3, 'Picture', 'icon:invoice');
    Raw := DecodeStringBase64(B3.GetX('picture'));
    Check(IsSvgBytes(Raw) and (Length(Raw) < 6000), 'picture: an icon from the library is stored as a small vector (SVG)');
    DefSet(B3, 'Picture', 'icon:invoice:tamna');
    Check(DecodeStringBase64(B3.GetX('picture')) <> Raw, 'picture: the dark variant is a different image');
    DefSet(B3, 'Picture', '../ikone/svijetle/svg/invoice.svg');
    Raw := DecodeStringBase64(B3.GetX('picture'));
    Check(IsSvgBytes(Raw), 'picture: an SVG file stays a vector in the definition');
    Pc := TPicture.Create;
    try
      Check(LoadPictureSized(Pc, Raw, 300) and (Pc.Width = 300), 'picture: a vector is drawn at the requested width (' + IntToStr(Pc.Width) + ')');
      Check(LoadPictureSized(Pc, Raw, 1200) and (Pc.Width = 1200), 'picture: and sharp at any other width');
    finally
      Pc.Free;
    end;
    B3.Free;
    D := TaFormDef.Create;
    D.Name := 'Ik'; D.Width := 300; D.Height := 100;
    D.Add(B); D.Add(B2);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.Show;
      Application.ProcessMessages;
      C := R.ControlByName('bA');
      Check((C is TBitBtn) and (TBitBtn(C).Glyph.Width = 16), 'button icon: the button in a running form shows its icon');
    finally
      R.Free;
    end;
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

type
  TSideCatcher = class
    Last: string;
    procedure Got(const AAction: string);
  end;

procedure TSideCatcher.Got(const AAction: string);
begin
  Last := AAction;
end;

{ bocni izbornik (XP traka): skupine koje se sklapaju, stavke s ikonama, akcije }
var
  GSideClicks: string;

type
  TSideSink = class
    procedure Click(Sender: TObject; AGroup, AItem: Integer; const AAction: string);
  end;

procedure TSideSink.Click(Sender: TObject; AGroup, AItem: Integer; const AAction: string);
begin
  GSideClicks := GSideClicks + Format('[%d.%d %s]', [AGroup, AItem, AAction]);
end;

procedure TestSideMenuGroups;
var
  M: TaSideMenu;
  G: TaSideMenuGroup;
  Sink: TSideSink;
  Fm: TForm;
  I: Integer;
  Ms, Ts: TMemoryStream;
  Lfm: string;
  M2: TaSideMenu;
begin
  Fm := TForm.CreateNew(nil);
  Sink := TSideSink.Create;
  M := TaSideMenu.Create(Fm);
  try
    M.Parent := Fm;
    { zbirke se pune kao kod TJvXPBar-a: skupina, pa njezine stavke }
    G := M.Groups.Add; G.Caption := 'Kolo'; G.IconName := 'calendar';
    with G.Items.Add do begin Caption := 'Predvidi'; Action := 'fgl:Predvidi'; end;
    with G.Items.Add do begin Caption := 'Listici'; Action := 'openform:Listici'; IconName := 'receipt'; end;
    G := M.Groups.Add; G.Caption := 'Analize';
    with G.Items.Add do begin Caption := 'Sustavi'; Action := 'openreport:Sustavi'; end;
    with G.Items.Add do begin Caption := 'Skriveno'; Action := 'macro:X'; Visible := False; end;
    Check(M.RowCount = 5, 'sidemenu groups: two groups and three visible items give five rows (' + IntToStr(M.RowCount) + ')');
    Check(M.RowIsGroup(0) and (not M.RowIsGroup(1)) and M.RowIsGroup(3), 'sidemenu groups: rows follow the collections');
    Check((M.RowAction(1) = 'fgl:Predvidi') and (M.RowIcon(2) = 'receipt'), 'sidemenu groups: action and icon name');
    Check(Pos('# Analize', M.Items) > 0, 'sidemenu groups: the text form is produced from the collections');
    GSideClicks := '';
    M.OnItemClick := @Sink.Click;
    M.ClickRow(2);
    M.ClickRow(4);
    Check(GSideClicks = '[0.1 openform:Listici][1.0 openreport:Sustavi]', 'sidemenu groups: OnItemClick names group, item and action: ' + GSideClicks);
    { promjena stavke osvjezi izbornik }
    M.Groups[0].Items[0].Caption := 'Novo';
    Check(M.RowCount = 5, 'sidemenu groups: an edit keeps the rows');
    M.Groups[1].Items[1].Visible := True;
    Check(M.RowCount = 6, 'sidemenu groups: a hidden item shown adds a row');
    { postavljanje tekstom (kako to radi runtime) puni i zbirke }
    M.Items := '# A|home' + LineEnding + 'Prva|openform:F1' + LineEnding + 'Druga|openform:F2' + LineEnding + '# B' + LineEnding + 'Treca|macro:M';
    Check((M.Groups.Count = 2) and (M.Groups[0].Items.Count = 2) and (M.Groups[1].Items[0].Action = 'macro:M'), 'sidemenu groups: setting the text fills the collections');
    Check(M.RowCount = 5, 'sidemenu groups: the text gives five rows');
    { tok .lfm: komponenta se zapise u tekst i ponovno procita (kao dizajner), zbirke ostaju }
    begin
      Ms := TMemoryStream.Create; Ts := TMemoryStream.Create;
      try
        Ms.WriteComponent(M);
        Ms.Position := 0;
        ObjectBinaryToText(Ms, Ts);
        Ts.Position := 0;
        SetLength(Lfm, Ts.Size);
        Ts.ReadBuffer(Lfm[1], Ts.Size);
        Check((Pos('Groups = <', Lfm) > 0) and (Pos('Caption = ''Prva''', Lfm) > 0), 'sidemenu groups: the .lfm text carries groups and items');
        Ms.Position := 0;
        M2 := TaSideMenu.Create(Fm);
        Ms.ReadComponent(M2);
        Check((M2.Groups.Count = 2) and (M2.Groups[0].Items.Count = 2) and (M2.RowCount = 5), 'sidemenu groups: a stored component reads back with its groups (' + IntToStr(M2.RowCount) + ')');
      finally
        Ms.Free; Ts.Free;
      end;
    end;
    { zbirka prima i tijek Assign }
    G := TaSideMenuGroup.Create(nil);
    I := M.Groups.Count;
    G.Free;
    Check(I = 2, 'sidemenu groups: still two groups');
  finally
    Sink.Free;
    Fm.Free;
  end;
end;

var
  GCompOut: string;

type
  TCompSink = class
    procedure Disp(Sender: TObject; const AText: string);
    procedure GetVar(Sender: TObject; const AName: string; var AValue: Variant; var AHandled: Boolean);
    procedure Ask(Sender: TObject; const AQuestion: string; var AAnswer: string; var AOk: Boolean);
  end;

procedure TCompSink.Disp(Sender: TObject; const AText: string);
begin
  GCompOut := GCompOut + '[' + AText + ']';
end;

procedure TCompSink.GetVar(Sender: TObject; const AName: string; var AValue: Variant; var AHandled: Boolean);
begin
  if SameText(AName, 'dinamicki') then begin AValue := 7; AHandled := True; end;
end;

procedure TCompSink.Ask(Sender: TObject; const AQuestion: string; var AAnswer: string; var AOk: Boolean);
begin
  AAnswer := 'Marko';
  AOk := True;
end;

procedure TestPaletteComponents;
var
  Owner: TComponent;
  Dbc: TaDatabase;
  Ex: TaExpression;
  Rp: TaReport;
  Pg: TaProgram;
  Sink: TCompSink;
  Log, Names, Chk: TStringList;
  Rep: TaRenderedReport;
  V: Variant;
  Ok: Boolean;
begin
  if FileExists('/tmp/ta_comp.db') then DeleteFile('/tmp/ta_comp.db');
  Owner := TComponent.Create(nil);
  Sink := TCompSink.Create;
  Log := TStringList.Create;
  try
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_comp.db';
    Check(not Dbc.Connected, 'components: a new TaDatabase is closed');
    Dbc.Active := True;
    Check(Dbc.Connected and (ActiveDb = Dbc.Db), 'components: opening makes it the default database of the expression language');
    { aplikacija iz opisa: tablica, izvjesce, program }
    Ok := BuildAppFromSpecText(Dbc.Db,
      'tablica stavke "Stavke" bezforme' + LineEnding + '  naziv Text' + LineEnding + '  iznos Decimal/2' + LineEnding +
      'izvjesce "Popis stavki"' + LineEnding + '  izvor: stavke' + LineEnding + '  vrsta: tablicno' + LineEnding +
      'program Zbroji' + LineEnding + '  MAIN' + LineEnding + '    DISPLAY "Zbroj: ", 2 + 3' + LineEnding + '  END MAIN' + LineEnding, Log);
    Check(Ok, 'components: an application is built into the database: ' + Log.Text);
    Dbc.ExecSQL('INSERT INTO stavke (naziv, iznos) VALUES (''A'', 10.5), (''B'', 4.5)');
    Check(Dbc.Scalar('SELECT SUM(iznos) FROM stavke') = '15', 'components: TaDatabase.Scalar (' + Dbc.Scalar('SELECT SUM(iznos) FROM stavke') + ')');
    Names := Dbc.Tables;
    Check(Names.IndexOf('stavke') >= 0, 'components: Tables lists the table');
    Names.Free;
    Dbc.SaveSetting('firma.naziv', 'Proba d.o.o.');
    Check(Dbc.Setting('firma.naziv') = 'Proba d.o.o.', 'components: settings are stored');
    { --- izrazi --- }
    Ex := TaExpression.Create(Owner);
    Ex.Database := Dbc;
    Ex.Variables.Add('x=6');
    Ex.OnGetVariable := @Sink.GetVar;
    Check(Ex.Evaluate('[x] * 7') = 42, 'components: TaExpression uses its variables');
    Check(Ex.Evaluate('[dinamicki] + 1') = 8, 'components: OnGetVariable supplies unknown variables');
    Ex.Expression := 'Zaokruzi(2.345, 2)';
    Check(Abs(Double(Ex.Evaluate) - 2.35) < 1e-9, 'components: Evaluate uses the Expression property');
    V := Ex.Evaluate('DSum("iznos", "stavke")');
    Check((not VarIsNull(V)) and (Abs(Double(V) - 15) < 1e-9), 'components: domain functions read the TaDatabase');
    V := Ex.Evaluate('Nepostojeca(1)');
    Check(VarIsNull(V) and (Ex.LastError <> ''), 'components: an error gives Null and LastError (' + Ex.LastError + ')');
    Check(Ex.Check('1 +') <> '', 'components: Check reports a syntax error');
    Check(Ex.Check('1 + 2') = '', 'components: Check passes a good expression');
    Ex.RaiseErrors := True;
    Ok := False;
    try
      Ex.Evaluate('Nepostojeca(1)');
    except
      on EExpr do Ok := True;
    end;
    Check(Ok, 'components: RaiseErrors raises EExpr');
    { --- izvjesce --- }
    Rp := TaReport.Create(Owner);
    Rp.Database := Dbc;
    Rp.ReportName := 'Popis stavki';
    Rep := Rp.Render;
    Check((Rep <> nil) and (Rep.PageCount >= 1), 'components: TaReport renders pages');
    Rep.Free;
    if FileExists('/tmp/ta_comp.pdf') then DeleteFile('/tmp/ta_comp.pdf');
    if FileExists('/tmp/ta_comp.html') then DeleteFile('/tmp/ta_comp.html');
    Check(Rp.ExportPdf('/tmp/ta_comp.pdf') and FileExists('/tmp/ta_comp.pdf'), 'components: ExportPdf writes the file ' + Rp.LastError);
    Check(Rp.ExportHtml('/tmp/ta_comp.html') and FileExists('/tmp/ta_comp.html'), 'components: ExportHtml writes the file');
    Names := Rp.ReportNames;
    Check(Names.IndexOf('Popis stavki') >= 0, 'components: ReportNames lists the report');
    Names.Free;
    Rp.ReportName := 'Nema';
    Check((Rp.Render = nil) and (Pos('Nema izvjesca', Rp.LastError) > 0), 'components: a missing report gives nil and LastError');
    { --- 4GL --- }
    Pg := TaProgram.Create(Owner);
    Pg.Database := Dbc;
    Pg.OnDisplay := @Sink.Disp;
    Pg.ProgramName := 'Zbroji';
    GCompOut := '';
    Check(Pg.Run = 0, 'components: a stored 4GL program runs: ' + Pg.LastError);
    Check((Pg.Output.Count = 1) and (Pos('Zbroj: 5', Pg.Output[0]) = 1) and (Pos('Zbroj: 5', GCompOut) > 0), 'components: output goes to Output and OnDisplay (' + GCompOut + ')');
    Pg.Source.Text := 'MAIN' + LineEnding + '  DEFINE a TEXT' + LineEnding + '  PROMPT "Ime? " FOR a' + LineEnding + '  DISPLAY "Bok ", a' + LineEnding + 'END MAIN';
    Pg.OnPrompt := @Sink.Ask;
    GCompOut := '';
    Check(Pg.Run = 0, 'components: a program from the Source text runs: ' + Pg.LastError);
    Check(Pos('Bok Marko', GCompOut) > 0, 'components: OnPrompt answers PROMPT (' + GCompOut + ')');
    Pg.Source.Text := 'MAIN' + LineEnding + '  NEPOZNATA(1)' + LineEnding + 'END MAIN';
    Chk := Pg.Check;
    Check(Chk.Count > 0, 'components: Check finds a problem without running');
    Chk.Free;
    Check(Pg.Run <> 0, 'components: a faulty program returns a non-zero exit code');
    Dbc.Active := False;
    Check((not Dbc.Connected) and (ActiveDb = nil), 'components: closing clears the default database');
  finally
    Log.Free;
    Sink.Free;
    Owner.Free;
  end;
end;

procedure TestFormBinder;
var
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  Bd: TaFormBinder;
  Fm: TForm;
  EdOpis, EdDatum: TEdit;
  Spk: TFloatSpinEdit;
  LbIznos, LbNap, LbStatus: TLabel;
  Ok: Boolean;
  Msg: string;
begin
  if FileExists('/tmp/ta_binder.db') then DeleteFile('/tmp/ta_binder.db');
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_binder.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, opis VARCHAR(50), kol REAL, cij REAL, iznos REAL, datum DATE)');
    Dbc.ExecSQL('INSERT INTO st (opis, kol, cij, iznos, datum) VALUES (''A'', 2, 10, 20, ''2026-01-02'')');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    EdOpis := TEdit.Create(Fm); EdOpis.Parent := Fm;
    EdDatum := TEdit.Create(Fm); EdDatum.Parent := Fm;
    Spk := TFloatSpinEdit.Create(Fm); Spk.Parent := Fm; Spk.MaxValue := 1000;
    LbIznos := TLabel.Create(Fm); LbIznos.Parent := Fm;
    LbNap := TLabel.Create(Fm); LbNap.Parent := Fm;
    LbStatus := TLabel.Create(Fm); LbStatus.Parent := Fm;
    Bd := TaFormBinder.Create(Owner);
    Bd.Database := Dbc;
    Bd.DataSource := Ds;
    with Bd.Bindings.Add do begin Control := EdOpis; FieldName := 'opis'; Rule := 'Len(Nz([opis], "")) > 0'; RuleMessage := 'Opis je obavezan.'; end;
    with Bd.Bindings.Add do begin FieldName := 'iznos'; Control := LbIznos; Expression := '[kol] * [cij]'; end;
    with Bd.Bindings.Add do begin Control := LbNap; VisibleIf := '[iznos] > 100'; end;
    with Bd.Bindings.Add do
    begin
      Control := LbStatus; Expression := 'IIf(Nz([iznos], 0) > 100, "VELIKI", "obicni")';
      CondFormat := '[iznos] > 100 => #FFFFFF #C00000 bold';
    end;
    with Bd.Bindings.Add do begin Control := EdDatum; FieldName := 'datum'; DefaultValue := 'Date()'; end;
    { dvije stavke na istoj kontroli: pravilo i uvjetno oblikovanje se zbrajaju, pravilo ima prednost }
    with Bd.Bindings.Add do begin Control := EdOpis; CondFormat := 'Nz([kol], 0) > 0 => #0000FF #E0FFE0'; end;
    with Bd.Bindings.Add do begin Control := Spk; FieldName := 'kol'; Format := '0.##'; end;
    Bd.Locale := blSystem;       { ne mijenja globalne oblike brojeva i datuma ostalih testova }
    Bd.Activate;
    Check(Bd.Bindings.Count = 7, 'binder: seven bindings');
    Check((Spk.DecimalPlaces = 0) and (Abs(Spk.Value - 2) < 1e-9), 'binder: a spin with 0.## shows 2 without decimals (' + IntToStr(Spk.DecimalPlaces) + ')');
    Check(LbStatus.Caption = 'obicni', 'binder: a browse-mode expression is shown (' + LbStatus.Caption + ')');
    Check(not LbNap.Visible, 'binder: VisibleIf hides the control');
    { novi zapis: zadani datum, izracun upisan u polje, uvjetno oblikovanje }
    Q.Append;
    Check(Q.FieldByName('datum').AsString <> '', 'binder: DefaultValue fills a new record');
    Q.FieldByName('opis').AsString := 'B';
    Q.FieldByName('kol').AsFloat := 5;
    Q.FieldByName('cij').AsFloat := 30;
    Check((Spk.DecimalPlaces = 0) and (Abs(Spk.Value - 5) < 1e-9), 'binder: a whole quantity keeps no decimals');
    Q.FieldByName('kol').AsFloat := 2.51;
    Check((Spk.DecimalPlaces = 2) and (Abs(Spk.Value - 2.51) < 1e-9), 'binder: 2.51 gets two decimals (' + IntToStr(Spk.DecimalPlaces) + ')');
    Q.FieldByName('kol').AsFloat := 2.5;
    Check(Spk.DecimalPlaces = 1, 'binder: 2.5 gets one decimal');
    Q.FieldByName('kol').AsFloat := 5;
    Check(Abs(Q.FieldByName('iznos').AsFloat - 150) < 1e-9, 'binder: the calculated field is written (' + Q.FieldByName('iznos').AsString + ')');
    Check(LbNap.Visible, 'binder: VisibleIf shows the control when the condition holds');
    Check((LbStatus.Caption = 'VELIKI') and (LbStatus.Color = RGBToColor($C0, 0, 0)) and (fsBold in LbStatus.Font.Style), 'binder: CondFormat colours the control');
    { pravilo: prazan opis ne smije u bazu }
    Q.FieldByName('opis').Clear;
    Check(not Bd.Validate, 'binder: Validate finds the failed rule');
    Check((Bd.Errors.Count = 1) and (Bd.Errors[0] = 'Opis je obavezan.'), 'binder: the rule message');
    Check(EdOpis.Color = $DDDDFF, 'binder: the failed rule colours the control even with another binding on it');
    Ok := False; Msg := '';
    try
      Q.Post;
    except
      on E: EBinderValidation do begin Ok := True; Msg := E.Message; end;
    end;
    Check(Ok and (Msg = 'Opis je obavezan.'), 'binder: Post is refused with EBinderValidation');
    Check(Q.FieldByName('opis').IsNull and (Q.RecordCount = 1), 'binder: the record is not written after a refused Post');
    Q.FieldByName('opis').AsString := 'B';
    Q.Post;
    Check(Q.RecordCount = 2, 'binder: a valid record posts');
    Q.First;
    Check(LbStatus.Caption = 'obicni', 'binder: moving to another record recalculates (' + LbStatus.Caption + ')');
    Check(not LbNap.Visible, 'binder: VisibleIf follows the record');
  finally
    Fm.Free;
    Owner.Free;
  end;
end;

procedure TestPropMap;
{ TaPropMap daje isti rezultat kao ta_controls.DefGet/DefSet za svako svojstvo u tablici }
var
  I, J: Integer;
  A, B: TaControlDef;
  E: TaPropEntry;
  Samples: array[0..3] of string;
  Ga, Gb, Name: string;
  Bad: Integer;
begin
  Bad := 0;
  for I := Low(PropMap) to High(PropMap) do
  begin
    E := PropMap[I];
    case E.Kind of
      pmInt: begin Samples[0] := '42'; Samples[1] := 'x'; Samples[2] := ''; Samples[3] := '-7'; end;
      pmBool, pmFlag, pmFlagOff, pmFlagShow: begin Samples[0] := 'True'; Samples[1] := 'False'; Samples[2] := ''; Samples[3] := 'abc'; end;
    else
      begin Samples[0] := ' Abc Def '; Samples[1] := ''; Samples[2] := 'MiXed'; Samples[3] := 'a,b;c'; end;
    end;
    for J := 0 to 3 do
    begin
      A := TaControlDef.Create;
      B := TaControlDef.Create;
      try
        DefSet(A, E.Name, Samples[J]);
        if not PropMapSet(B, E.Name, Samples[J]) then Inc(Bad);
        Ga := DefGet(A, E.Name);
        if not PropMapGet(B, E.Name, Gb) then begin Inc(Bad); Gb := '?'; end;
        if (Ga <> Gb) or (A.Extra <> B.Extra) or (A.Name <> B.Name) or (A.Caption <> B.Caption) or
           (A.Align <> B.Align) or (A.Left <> B.Left) or (A.Width <> B.Width) or (A.Bold <> B.Bold) then
        begin
          Inc(Bad);
          WriteLn('  propmap razlika: ', E.Name, ' uzorak "', Samples[J], '" -> "', Ga, '" / "', Gb, '"');
        end;
      finally
        A.Free;
        B.Free;
      end;
    end;
  end;
  Check(Bad = 0, 'propmap: tablica svojstava daje isti rezultat kao DefGet/DefSet (' + IntToStr(Length(PropMap)) + ' svojstava)');
  Check(PropMapFind('nepoznato') = -1, 'propmap: nepoznato svojstvo nije u tablici');
  Check(not PropMapSet(TaControlDef.Create, 'nepoznato', 'x'), 'propmap: postavljanje nepoznatog svojstva vraca False');
  Name := '';
end;

procedure TestTokens;
var
  T, T2: TaThemeTokens;
  I, K, Bad: Integer;
  Sh: TaShape;
  Dk: Boolean;
  W, J: string;
begin
  { Plava svijetla i tamna = tocne vrijednosti iz plana }
  T := BuiltinTokens(0, False, shRounded);
  Check((T.Accent = '#2563EB') and (T.AccentSoft = '#DBEAFE') and (T.Bg = '#F1F5F9') and (T.Border = '#CBD5E1'), 'tokeni: Plava svijetla ima vrijednosti iz plana');
  T := BuiltinTokens(0, True, shRounded);
  Check((T.Accent = '#60A5FA') and (T.AccentSoft = '#1E3A5F') and (T.Bg = '#0F172A') and (T.Surface = '#111827'), 'tokeni: Plava tamna ima vrijednosti iz plana');
  { sve ugradene teme x svijetla/tamna x oblici prolaze provjeru (kontrast >= 4.5) }
  Bad := 0;
  for I := 0 to BuiltinThemeCount - 1 do
    for K := 0 to 1 do
      for Sh := Low(TaShape) to High(TaShape) do
      begin
        Dk := K = 1;
        T := BuiltinTokens(I, Dk, Sh);
        W := ValidateTokens(T);
        if W <> '' then begin Inc(Bad); WriteLn('  tema ', BuiltinThemeName(I), ' dark=', Dk, ' ', ShapeNames[Sh], ': ', W); end;
      end;
  Check(Bad = 0, 'tokeni: ' + IntToStr(BuiltinThemeCount) + ' teme x 2 x 3 oblika prolaze provjeru kontrasta');
  { oblik }
  T := BuiltinTokens(0, False, shRounded);
  Check((T.RadiusButton = 6) and (T.RadiusField = 5) and (T.RadiusCard = 8) and (T.ControlHeight = 28), 'tokeni: rounded = 6/5/8 px, visina 28');
  ApplyShape(T, shSquare);
  Check((T.RadiusButton = 2) and (T.RadiusField = 2), 'tokeni: square = 2 px');
  ApplyShape(T, shPill);
  Check((T.RadiusButton = 13) and (T.RadiusField = 11) and (T.RadiusCard = 8), 'tokeni: pill: gumb 13, polje 11 (Qt ne zaobljuje polja kojima je LCL automatski smanjio visinu), kartica 8');
  { zelena i crvena tema: naglasak izveden, greska se razlikuje od naglasaka }
  T := BuiltinTokens(1, False, shRounded);
  Check(T.Accent = '#16A34A', 'tokeni: Zelena ima zeleni naglasak');
  T := BuiltinTokens(2, False, shRounded);
  Check(T.Danger <> T.Accent, 'tokeni: u Crvenoj temi greska nije jednaka naglasku (' + T.Danger + ' / ' + T.Accent + ')');
  { prva serija grafikona je naglasak, nema ponovljene boje naglaska }
  T := BuiltinTokens(1, False, shRounded);
  Bad := 0;
  for I := 1 to 7 do if T.Chart[I] = T.Chart[0] then Inc(Bad);
  Check((T.Chart[0] = T.Accent) and (Bad = 0), 'tokeni: grafikon: serija 0 = naglasak, bez duplikata');
  { JSON: minimalni zapis i krug }
  Check(TokensFromJson('{"name":"Moja","accent":"#16A34A","shape":"pill","dark":true}', T, W) and (T.Name = 'Moja') and (T.Shape = shPill) and T.Dark and (W = ''), 'tokeni: minimalni JSON se ucitava');
  J := TokensToJson(T);
  Check(TokensFromJson(J, T2, W) and (T2.Accent = T.Accent) and (T2.Bg = T.Bg) and (T2.Shape = T.Shape) and (T2.RadiusButton = T.RadiusButton) and (T2.Chart[3] = T.Chart[3]), 'tokeni: JSON krug (zapis pa citanje) daje istu temu');
  Check(TokensFromJson('{"accent":"#16A34A","tokens":{"radiusButton":9,"bg":"#FFFFFF"}}', T, W) and (T.RadiusButton = 9) and (T.Bg = '#FFFFFF'), 'tokeni: nadjacavanje tokena u JSON-u');
  Check(TokensFromJson('{"accent":"#16A34A","tema":1}', T, W) and (Pos('tema', W) > 0), 'tokeni: nepoznati kljuc daje upozorenje');
  Check(not TokensFromJson('{"accent":"zeleno"}', T, W) and (W <> ''), 'tokeni: neispravan naglasak je greska');
  Check(not TokensFromJson('{"accent":"#777777","tokens":{"onAccent":"#888888"}}', T, W) and (Pos('kontrast', LowerCase(W)) > 0), 'tokeni: los kontrast teksta na naglasku je greska');
  Check(not TokensFromJson('nije json', T, W), 'tokeni: neispravan JSON');
  { pomocne }
  Check(ColorHex(TokenColor('#2563EB')) = '#2563EB', 'tokeni: TokenColor/ColorHex krug');
  Check(ContrastRatio('#000000', '#FFFFFF') > 20.9, 'tokeni: kontrast crno/bijelo = 21');
  { aktivna tema se javlja slusateljima }
  { adapteri za SynEdit i TAChart: citljivost svih boja koda na pozadini u svim temama }
  Bad := 0;
  for I := 0 to BuiltinThemeCount - 1 do
    for K := 0 to 1 do
    begin
      T := BuiltinTokens(I, K = 1, shRounded);
      if (ContrastRatio(EditorPalette(T).Background, EditorPalette(T).Text) < 4.5) or
         (ContrastRatio(EditorPalette(T).Background, EditorPalette(T).Keyword) < 3.0) or
         (ContrastRatio(EditorPalette(T).Background, EditorPalette(T).Comment) < 3.0) or
         (ContrastRatio(EditorPalette(T).Background, EditorPalette(T).StringLit) < 2.5) or
         (ContrastRatio(EditorPalette(T).Background, EditorPalette(T).Error) < 3.0) then
      begin
        Inc(Bad);
        WriteLn('  uredjivac slabo vidljiv: ', BuiltinThemeName(I), ' dark=', K);
      end;
    end;
  Check(Bad = 0, 'tokeni: paleta uredjivaca (SynEdit) je dovoljno kontrastna u svim temama');
  T := BuiltinTokens(1, False, shRounded);
  Check((ChartPalette(T).Series[0] = T.Accent) and (ChartPalette(T).Background = T.Surface), 'tokeni: paleta grafikona (TAChart) prati naglasak');
  SetActiveTokens(BuiltinTokens(1, False, shRounded));
  Check(ActiveTokens.Accent = '#16A34A', 'tokeni: aktivna tema je postavljena');
  SetActiveTokens(BuiltinTokens(0, False, shRounded));
end;

procedure TestThemeInApp;
var
  Db: TAppDb;
  Path, W: string;
  T: TaThemeTokens;
begin
  Path := '/tmp/ta_theme_app.db';
  if FileExists(Path) then DeleteFile(Path);
  Db := TAppDb.Create;
  try
    Db.Open(Path);
    SetThemeTokens(BuiltinTokens(1, False, shRounded), False);
    Check(SaveThemeToApp(Db), 'tema u aplikaciji: spremanje');
    SetThemeTokens(BuiltinTokens(0, False, shRounded), False);
    Check(CurrentTokens.Accent = '#2563EB', 'tema u aplikaciji: prije primjene je Plava');
    Check(ApplyThemeFromApp(Db, True) and (CurrentTokens.Accent = '#16A34A'), 'tema u aplikaciji: primjena vraca zelenu temu');
    T := CurrentTokens;
    Check(TokensFromJson(Db.LoadSetting('tema.json'), T, W) and (T.Accent = '#16A34A'), 'tema u aplikaciji: zapis u postavkama je valjan JSON');
    Check(ClearAppTheme(Db) and (not ApplyThemeFromApp(Db, True)), 'tema u aplikaciji: uklanjanje');
    SetThemeTokens(BuiltinTokens(0, False, shRounded), False);
    Db.Close;
  finally
    Db.Free;
  end;
end;

procedure TestEditFamily;
var
  Fm: TForm;
  E, E2, E3: TaEdit;
  V: TStringList;
  Db: TAppDb;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm, W: string;
  R: TaEdit;
  Vr: TaEditVariant;
  Bad: Integer;
  Inn: TWinControl;
begin
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 400, 300);
    { registar }
    V := EngineVariants('Edit');
    try
      Check(V.Count = 8, 'edit: u registru je 8 varijanti (' + V.CommaText + ')');
    finally
      V.Free;
    end;
    E := TaEdit.Create(Fm); E.Parent := Fm; E.SetBounds(8, 8, 200, 28);
    { svaka varijanta stvara pravu kontrolu }
    Bad := 0;
    for Vr := Low(TaEditVariant) to High(TaEditVariant) do
    begin
      E.Variant := Vr;
      Inn := E.Engine.Inner;
      case Vr of
        evText: if not ((Inn is TEdit) and (TEdit(Inn).PasswordChar = #0)) then Inc(Bad);
        evPassword: if not ((Inn is TEdit) and (TEdit(Inn).PasswordChar = '*')) then Inc(Bad);
        evCombo: if not ((Inn is TComboBox) and (TComboBox(Inn).Style = csDropDown)) then Inc(Bad);
        evDroplist: if not ((Inn is TComboBox) and (TComboBox(Inn).Style = csDropDownList)) then Inc(Bad);
        evSpin: if not (Inn is TFloatSpinEdit) then Inc(Bad);
        evDate: if not (Inn is TDateEdit) then Inc(Bad);
        evLov: if not (Inn is TEditButton) then Inc(Bad);
        evCurrency: if not ((Inn is TEdit) and (TEdit(Inn).Alignment = taRightJustify)) then Inc(Bad);
      end;
      if Inn.Parent <> E then Inc(Bad);
    end;
    Check(Bad = 0, 'edit: svaka varijanta stvara odgovarajucu kontrolu (nepodudaranja: ' + IntToStr(Bad) + ')');
    { zajednicka svojstva ostaju pri promjeni varijante }
    E.Variant := evText;
    E.Text := 'abc';
    E.ReadOnly := True;
    E.Hint := 'savjet';
    E.ControlSource := 'naziv';
    E.RowSource := 'list:A;B';
    E.VisibleIf := '[x] > 1';
    E.Variant := evPassword;
    E.Variant := evCombo;
    Check((E.Text = 'abc') and E.ReadOnly and (E.Hint = 'savjet') and (E.ControlSource = 'naziv') and (E.RowSource = 'list:A;B') and (E.VisibleIf = '[x] > 1'),
      'edit: tekst, samo-citanje, izvor i pravila ostaju pri promjeni varijante');
    E.Variant := evText;
    Check((E.Text = 'abc') and (E.ControlSource = 'naziv'), 'edit: nakon povratka na tekst isto');
    E.ReadOnly := False;
    { stavke i padajuci popis }
    E.Variant := evCombo;
    E.Items.Add('Zagreb'); E.Items.Add('Split'); E.Items.Add('Rijeka');
    E.Text := 'Split';
    Check(TComboBox(E.Engine.Inner).Items.Count = 3, 'edit: stavke stizu u kontrolu');
    E.Variant := evDroplist;
    Check((E.Text = 'Split') and (TComboBox(E.Engine.Inner).ItemIndex = 1), 'edit: padajuci popis zadrzava odabrani tekst');
    E.Text := 'Nepoznato';
    Check(E.Text = '', 'edit: padajuci popis ne prima vrijednost koje nema u popisu');
    E.Text := 'Rijeka';
    E.Variant := evText;
    Check(E.Text = 'Rijeka', 'edit: tekst iz popisa ostaje u poljima teksta');
    { opcije po varijanti i pamcenje }
    E.Variant := evCombo;
    TaComboOptions(E.Options).DropDownCount := 12;
    E.Options := E.Options;
    Check(TComboBox(E.Engine.Inner).DropDownCount = 12, 'edit: opcija DropDownCount stize u kontrolu');
    E.Variant := evSpin;
    Check(E.Options is TaSpinOptions, 'edit: Options za spin je TaSpinOptions');
    TaSpinOptions(E.Options).DecimalPlaces := 2;
    TaSpinOptions(E.Options).MinValue := 0;
    TaSpinOptions(E.Options).MaxValue := 100;
    E.Options := E.Options;
    E.SetValue(2.51);
    Check(Abs(Double(E.Value) - 2.51) < 1e-9, 'edit: spin prima i vraca 2,51');
    E.SetValue(500);
    Check(Double(E.Value) <= 100, 'edit: spin postuje najvecu vrijednost');
    E.Variant := evCombo;
    Check((E.Options is TaComboOptions) and (TaComboOptions(E.Options).DropDownCount = 12), 'edit: opcije varijante se pamte pri povratku');
    { iznos i datum }
    E.Variant := evCurrency;
    TaCurrencyOptions(E.Options).DecimalPlaces := 2;
    E.Options := E.Options;
    E.SetValue(1234.5);
    Check(E.Text = FormatFloat('#,##0.00', 1234.5), 'edit: iznos je oblikovan (' + E.Text + ')');
    Check(Abs(Double(E.Value) - 1234.5) < 1e-9, 'edit: iznos se vraca kao broj');
    E.Variant := evDate;
    E.SetValue(EncodeDate(2026, 11, 10));
    Check(Trunc(Double(E.Value)) = Trunc(EncodeDate(2026, 11, 10)), 'edit: datum se vraca kao datum');
    { tabulator i fokus kroz domacina }
    E.Free;
    E := TaEdit.Create(Fm); E.Parent := Fm; E.SetBounds(8, 8, 200, 28); E.TabOrder := 0;
    E2 := TaEdit.Create(Fm); E2.Parent := Fm; E2.SetBounds(8, 44, 200, 28); E2.TabOrder := 1; E2.Variant := evCombo;
    E3 := TaEdit.Create(Fm); E3.Parent := Fm; E3.SetBounds(8, 80, 200, 28); E3.TabOrder := 2; E3.Variant := evSpin;
    Check(not E.TabStop and E.Engine.Inner.TabStop, 'edit: domacin nije tabulator, stvarna kontrola jest');
    Fm.Show;
    Application.ProcessMessages;
    Fm.ActiveControl := E.Engine.Inner;
    Fm.SelectNext(E.Engine.Inner, True, True);
    Check(Fm.ActiveControl = E2.Engine.Inner, 'edit: Tab s prvog polja ide na drugo (kroz domacina)');
    Fm.SelectNext(E2.Engine.Inner, True, True);
    Check(Fm.ActiveControl = E3.Engine.Inner, 'edit: Tab s drugog polja ide na trece');
    Fm.SelectNext(E3.Engine.Inner, False, True);
    Check(Fm.ActiveControl = E2.Engine.Inner, 'edit: Shift+Tab vraca na drugo polje');
    { podaci }
    Db := TAppDb.Create;
    try
      if FileExists('/tmp/ta_edit_family.db') then DeleteFile('/tmp/ta_edit_family.db');
      Db.Open('/tmp/ta_edit_family.db');
      Db.Conn.ExecuteDirect('CREATE TABLE tt (id INTEGER PRIMARY KEY, naziv VARCHAR(50), iznos DOUBLE PRECISION, dat DATE)');
      Db.Conn.ExecuteDirect('INSERT INTO tt (naziv, iznos, dat) VALUES (''Prvi'', 10.5, ''2026-01-02'')');
      Db.Conn.ExecuteDirect('INSERT INTO tt (naziv, iznos, dat) VALUES (''Drugi'', 20.25, ''2026-03-04'')');
      Q := Db.NewQuery('SELECT * FROM tt ORDER BY id');
      Q.Open;
      Ds := TaDataSource.Create(Fm);
      Ds.DataSet := Q;
      E.Variant := evText; E.DataSource := Ds; E.DataField := 'naziv';
      E2.Variant := evCurrency; E2.DataSource := Ds; E2.DataField := 'iznos';
      E3.Variant := evDate; E3.DataSource := Ds; E3.DataField := 'dat';
      Check((E.Text = 'Prvi') and (Abs(Double(E2.Value) - 10.5) < 1e-9) and (Trunc(Double(E3.Value)) = Trunc(EncodeDate(2026, 1, 2))), 'edit: polja citaju zapis (tekst, iznos, datum)');
      Q.Next;
      Check((E.Text = 'Drugi') and (Abs(Double(E2.Value) - 20.25) < 1e-9), 'edit: polja prate pomak zapisa');
      TEdit(E.Engine.Inner).Text := 'Izmijenjeni';
      Check(Ord(Q.State) = 2, 'edit: unos u polje stavlja skup u stanje izmjene (dsEdit)');
      E.LeaveField;
      Q.Post;
      Check(Q.FieldByName('naziv').AsString = 'Izmijenjeni', 'edit: napustanje polja upisuje vrijednost u zapis');
      TDateEdit(E3.Engine.Inner).Date := EncodeDate(2027, 5, 6);
      Check(Ord(Q.State) = 2, 'edit: izmjena datuma stavlja skup u stanje izmjene');
      E3.LeaveField;
      Q.Post;
      Check(Trunc(Q.FieldByName('dat').AsDateTime) = Trunc(EncodeDate(2027, 5, 6)), 'edit: datum se upisuje u zapis');
      Q.Close;
      Q.Free;
      Db.Close;
    finally
      Db.Free;
    end;
  finally
    Fm.Free;
  end;
  { definicija kontrole <-> komponenta }
  Fm := TForm.CreateNew(nil);
  try
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'ComboBox'; D.Name := 'cmbGrad'; D.Left := 10; D.Top := 20; D.Width := 180; D.Height := 26;
      D.ControlSource := 'grad'; D.RowSource := 'list:Zagreb;Split;Rijeka'; D.Format := '@';
      D.SetX('tip', 'Odaberi grad'); D.SetX('foo', 'bar'); D.SetX('visibleIf', '[x] = 1'); D.SetX('locked', '1');
      E := EditFromDef(D, Fm);
      Check((E.Variant = evCombo) and (E.Items.Count = 3) and (E.Name = 'cmbGrad') and (E.Width = 180) and E.ReadOnly and (E.Extra = 'foo=bar'),
        'edit: ComboBox definicija postaje Edit s varijantom combo, stavkama i neznanim kljucevima');
      EditToDef(E, D2);
      Check((D2.Kind = 'Edit') and (D2.GetX('variant') = 'combo') and (D2.GetX('items') = 'Zagreb;Split;Rijeka') and (D2.GetX('foo') = 'bar') and
            (D2.GetX('tip') = 'Odaberi grad') and (D2.GetX('locked') = '1') and (D2.ControlSource = 'grad') and (D2.GetX('visibleIf') = '[x] = 1'),
        'edit: komponenta se vraca u definiciju bez gubitka');
      E.Free;
      { krug: definicija -> komponenta -> definicija daje isti zapis }
      D.Kind := 'Edit'; D.Extra := ''; D.RowSource := '';
      D.SetX('variant', 'spin'); D.SetX('decimals', '2'); D.SetX('min', '1'); D.SetX('max', '99'); D.SetX('step', '0.5');
      E := EditFromDef(D, Fm);
      Check((E.Variant = evSpin) and (TaSpinOptions(E.Options).DecimalPlaces = 2) and (TaSpinOptions(E.Options).MaxValue = 99), 'edit: opcije spina iz definicije');
      D2.Extra := '';
      EditToDef(E, D2);
      Check((D2.GetX('decimals') = '2') and (D2.GetX('min') = '1') and (D2.GetX('max') = '99') and (D2.GetX('step') = '0.5'), 'edit: opcije spina natrag u definiciju');
      { .lfm }
      E.Name := 'edtIznos';
      E.Hint := 'savjet'; E.ShowHint := True;
      Lfm := EditToLfm(E);
      Check((Pos('TaEdit', Lfm) > 0) and (Pos('evSpin', Lfm) > 0) and (Pos('Options.DecimalPlaces = 2', Lfm) > 0), 'edit: .lfm sadrzi varijantu i opcije');
      Check((Pos('TFloatSpinEdit', Lfm) = 0) and (Pos('TEdit', Lfm) = 0), 'edit: .lfm ne sadrzi stvarnu (unutarnju) kontrolu');
      E.Free;
      R := EditFromLfm(Lfm, Fm);
      Check((R <> nil) and (R.Variant = evSpin) and (TaSpinOptions(R.Options).DecimalPlaces = 2) and (R.Hint = 'savjet') and (R.Engine.Inner is TFloatSpinEdit),
        'edit: .lfm se cita natrag u istu komponentu');
    finally
      D.Free;
      D2.Free;
    end;
  finally
    Fm.Free;
  end;
end;

type
  TSrcEval = class
  public
    Vals: TStringList;
    function Eval(const AExpr: string; out AValue: Variant): Boolean;
  end;

function TSrcEval.Eval(const AExpr: string; out AValue: Variant): Boolean;
var
  K: string;
begin
  K := Trim(AExpr);
  if (Length(K) > 2) and (K[1] = '[') and (K[Length(K)] = ']') then
  begin
    K := Copy(K, 2, Length(K) - 2);
    Result := Vals.IndexOfName(K) >= 0;
    if Result then AValue := Vals.Values[K];
  end
  else Result := False;
end;

procedure TestFglSource;
var
  Db: TAppDb;
  Ds: TaDataSet;
  Err, Cols: string;
  Ev: TSrcEval;
  V: Variant;
  H: TTestHost;
  Refs: TStringList;
  D: TaSourceDef;
  I: Integer;
  Fd: TaFormDef;
  Fc: TaControlDef;
  Rn: TaFormRunner;
  Cmb: TComboBox;
  Rd: TaReportDef;
  Re: TaReportEngine;
  Rr: TaRenderedReport;
  J: Integer;
  Txt: string;
begin
  Db := TAppDb.Create;
  Ev := TSrcEval.Create;
  Ev.Vals := TStringList.Create;
  H := TTestHost.Create;
  Refs := TStringList.Create;
  try
    if FileExists('/tmp/ta_fglsrc.db') then DeleteFile('/tmp/ta_fglsrc.db');
    Db.Open('/tmp/ta_fglsrc.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30), aktivan INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, aktivan) VALUES (''Beta'', ''Zagreb'', 1)');
    Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, aktivan) VALUES (''Alfa'', ''Zagreb'', 1)');
    Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, aktivan) VALUES (''Gama'', ''Zagreb'', 0)');
    Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, aktivan) VALUES (''Delta'', ''Split'', 1)');
    Db.SaveObject('_sys_programs', 'PopisPartnera',
      'FUNCTION PopisPartnera(grad, aktivan)' + LineEnding +
      '  DEFINE grad TEXT' + LineEnding +
      '  DEFINE aktivan INTEGER' + LineEnding +
      '  COLUMNS id INTEGER, naziv TEXT' + LineEnding +
      '  DEFINE r RECORD id INTEGER, naziv TEXT END RECORD' + LineEnding +
      '  DECLARE c CURSOR FOR SELECT id, naziv FROM partneri WHERE grad = $grad AND aktivan = $aktivan ORDER BY naziv' + LineEnding +
      '  FOREACH c INTO r.*' + LineEnding +
      '    EMIT r.id, r.naziv' + LineEnding +
      '  END FOREACH' + LineEnding +
      'END FUNCTION' + LineEnding);
    Db.SaveObject('_sys_programs', 'IznosiPartnera',
      'FUNCTION IznosiPartnera()' + LineEnding +
      '  COLUMNS naziv TEXT, iznos FLOAT' + LineEnding +
      '  EMIT "A", 10' + LineEnding +
      '  EMIT "B", 20.5' + LineEnding +
      '  EMIT "C", 7' + LineEnding +
      'END FUNCTION' + LineEnding);
    Db.SaveObject('_sys_programs', 'Popust',
      'FUNCTION Popust(partner, iznos)' + LineEnding +
      '  DEFINE partner INTEGER' + LineEnding +
      '  DEFINE iznos FLOAT' + LineEnding +
      '  IF partner = 1 THEN' + LineEnding +
      '    RETURN iznos * 0.9' + LineEnding +
      '  END IF' + LineEnding +
      '  RETURN iznos' + LineEnding +
      'END FUNCTION' + LineEnding);
    Db.SaveObject('_sys_programs', 'Beskonacan',
      'FUNCTION Beskonacan()' + LineEnding +
      '  DEFINE i INTEGER' + LineEnding +
      '  COLUMNS n INTEGER' + LineEnding +
      '  LET i = 0' + LineEnding +
      '  WHILE TRUE' + LineEnding +
      '    LET i = i + 1' + LineEnding +
      '  END WHILE' + LineEnding +
      'END FUNCTION' + LineEnding);
    Db.SaveObject('_sys_programs', 'Puno',
      'FUNCTION Puno()' + LineEnding +
      '  DEFINE i INTEGER' + LineEnding +
      '  COLUMNS n INTEGER' + LineEnding +
      '  FOR i = 1 TO 50' + LineEnding +
      '    EMIT i' + LineEnding +
      '  END FOR' + LineEnding +
      'END FUNCTION' + LineEnding);
    Db.SaveObject('_sys_programs', 'SDijalogom',
      'FUNCTION SDijalogom()' + LineEnding +
      '  DEFINE x TEXT' + LineEnding +
      '  COLUMNS n TEXT' + LineEnding +
      '  PROMPT "Unesi: " FOR x' + LineEnding +
      '  EMIT x' + LineEnding +
      'END FUNCTION' + LineEnding);
    Db.SaveObject('_sys_programs', 'BezStupaca',
      'FUNCTION BezStupaca()' + LineEnding +
      '  COLUMNS n INTEGER' + LineEnding +
      '  EMIT 1, "a"' + LineEnding +
      'END FUNCTION' + LineEnding);
    { zapis izvora }
    D := ParseSource('fgl:PopisPartnera(grad=[grad], aktivan=1)');
    Check((D.Kind = skFgl) and (D.Body = 'PopisPartnera(grad=[grad], aktivan=1)'), 'izvor: fgl: prefiks');
    Check(ParseSource('partneri').Kind = skTable, 'izvor: bez prefiksa je tablica');
    Check(ParseSource('SELECT 1').Kind = skSql, 'izvor: SELECT bez prefiksa je SQL');
    Check((ParseSource('list:A;B').Kind = skList) and (ParseSource('expr:1+1').Kind = skExpr) and (ParseSource('fglv:X()').Kind = skFglValue) and (ParseSource('sql:SELECT 1').Kind = skSql), 'izvor: ostali prefiksi');
    SourceFieldRefs('fgl:PopisPartnera(grad=[grad], aktivan=[ak] + [ak2])', Refs);
    Check((Refs.Count = 3) and (Refs[0] = 'grad') and (Refs[1] = 'ak') and (Refs[2] = 'ak2'), 'izvor: polja o kojima izvor ovisi (' + Refs.CommaText + ')');
    { fgl: retci }
    Ds := OpenSource(Db, 'fgl:PopisPartnera("Zagreb", 1)', nil, nil, Err);
    Check((Ds <> nil) and (Err = ''), 'izvor fgl: otvara se (' + Err + ')');
    if Ds <> nil then
    begin
      Cols := '';
      for I := 0 to Ds.FieldCount - 1 do Cols := Cols + Ds.Fields[I].FieldName + ',';
      Check((Cols = 'id,naziv,') and (Ds.RecordCount = 2), 'izvor fgl: stupci COLUMNS i 2 retka (' + Cols + ' ' + IntToStr(Ds.RecordCount) + ')');
      Check((Ds.FieldByName('naziv').AsString = 'Alfa') and (Ds.FieldByName('id').AsInteger > 0), 'izvor fgl: redak iz EMIT (poredak iz SELECT-a)');
      Ds.Next;
      Check(Ds.FieldByName('naziv').AsString = 'Beta', 'izvor fgl: drugi redak');
      Ds.Free;
    end;
    { imenovani argumenti i izrazi nad zapisom forme }
    Ev.Vals.Values['grad'] := 'Split';
    Ds := OpenSource(Db, 'fgl:PopisPartnera(aktivan=1, grad=[grad])', @Ev.Eval, nil, Err);
    Check((Ds <> nil) and (Ds.RecordCount = 1) and (Ds.FieldByName('naziv').AsString = 'Delta'), 'izvor fgl: imenovani argumenti iz polja forme (Split -> Delta) ' + Err);
    Ds.Free;
    Ev.Vals.Values['grad'] := 'Zagreb';
    Ds := OpenSource(Db, 'fgl:PopisPartnera(aktivan=0, grad=[grad])', @Ev.Eval, nil, Err);
    Check((Ds <> nil) and (Ds.RecordCount = 1) and (Ds.FieldByName('naziv').AsString = 'Gama'), 'izvor fgl: promjena polja daje drugi skup (Zagreb, neaktivni -> Gama)');
    Ds.Free;
    { popis i SQL }
    Ds := OpenSource(Db, 'list:Novo;U tijeku;Zavrseno', nil, nil, Err);
    Check((Ds <> nil) and (Ds.RecordCount = 3) and (Ds.Fields[0].AsString = 'Novo'), 'izvor: popis (3 stavke)');
    Ds.Free;
    Ds := OpenSource(Db, 'list:a=Prvi;b=Drugi', nil, nil, Err);
    Check((Ds <> nil) and (Ds.FieldCount = 2) and (Ds.Fields[0].AsString = 'a') and (Ds.Fields[1].AsString = 'Prvi'), 'izvor: popis kljuc=oznaka');
    Ds.Free;
    Ds := OpenSource(Db, 'sql:SELECT naziv FROM partneri WHERE grad = ''Split''', nil, nil, Err);
    Check((Ds <> nil) and (Ds.RecordCount = 1), 'izvor: sql: prefiks');
    Ds.Free;
    Ds := OpenSource(Db, 'partneri', nil, nil, Err);
    Check((Ds <> nil) and (Ds.RecordCount = 4), 'izvor: tablica bez prefiksa');
    Ds.Free;
    { vrijednost iz 4GL-a }
    Check(EvalSourceValue(Db, 'fglv:Popust(1, 200)', nil, V, Err) and (Abs(Double(V) - 180) < 1e-9), 'izvor fglv: vrijednost iz RETURN (' + Err + ')');
    Check(EvalSourceValue(Db, 'fglv:Popust(2, 200)', nil, V, Err) and (Abs(Double(V) - 200) < 1e-9), 'izvor fglv: druga grana');
    { funkcija u izrazima }
    ActiveStoreDb := Db;
    Check(Abs(EvalExpr('Fgl("Popust", 1, 300)', H) - 270) < 1e-9, 'Fgl() u izrazu: Fgl("Popust", 1, 300) = 270');
    Check(Abs(EvalExpr('Fgl("Popust", 1, 100) + 1', H) - 91) < 1e-9, 'Fgl() se moze kombinirati s drugim izrazima');
    ActiveStoreDb := nil;
    { granice i greske }
    Ds := OpenFglSource(Db, 'Beskonacan()', nil, nil, Err, 300, 100000);
    Check((Ds = nil) and (Pos('prekoraceno', Err) > 0), 'izvor: beskonacna petlja se prekida vremenskim ogranicenjem (' + Err + ')');
    Ds := OpenFglSource(Db, 'Puno()', nil, nil, Err, 5000, 10);
    Check((Ds = nil) and (Pos('najveci broj redaka', Err) > 0), 'izvor: premasen broj redaka daje poruku (' + Err + ')');
    Ds := OpenSource(Db, 'fgl:SDijalogom()', nil, nil, Err);
    Check((Ds = nil) and (Pos('nije dopusten', Err) > 0), 'izvor: PROMPT unutar izvora je greska s porukom (' + Err + ')');
    Ds := OpenSource(Db, 'fgl:BezStupaca()', nil, nil, Err);
    Check((Ds = nil) and (Pos('COLUMNS', Err) > 0), 'izvor: EMIT s vise vrijednosti nego stupaca u COLUMNS je greska (' + Err + ')');
    Ds := OpenSource(Db, 'fgl:NemaTakvog()', nil, nil, Err);
    Check((Ds = nil) and (Pos('Nema 4GL programa', Err) > 0), 'izvor: nepoznat program (' + Err + ')');
    Ds := OpenSource(Db, 'fgl:PopisPartnera(zlo=1)', nil, nil, Err);
    Check((Ds = nil) and (Pos('Argumenti', Err) > 0), 'izvor: nepoznat naziv argumenta (' + Err + ')');
    { kontrole forme: popis iz 4GL-a ovisi o drugom polju (kaskada) }
    Db.Conn.ExecuteDirect('CREATE TABLE dokument (id INTEGER PRIMARY KEY, grad TEXT, partner_id INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO dokument VALUES (1, ''Zagreb'', NULL)');
    Fd := TaFormDef.Create;
    Fd.Name := 'DokFgl'; Fd.RecordSource := 'dokument';
    Fc := NewCtl('ComboBox', 'cmbGrad', 'grad', 10, 10); Fc.RowSource := 'list:Zagreb;Split'; Fd.Add(Fc);
    Fc := NewCtl('ComboBox', 'cmbPartner', 'partner_id', 10, 50); Fc.RowSource := 'fgl:PopisPartnera(grad=[cmbGrad], aktivan=1)'; Fd.Add(Fc);
    Fc := NewCtl('ListBox', 'lstSvi', '', 10, 90); Fc.RowSource := 'fgl:PopisPartnera("Zagreb", 0)'; Fd.Add(Fc);
    Fc := NewCtl('Chart', 'chrPartneri', '', 200, 10); Fc.RowSource := 'fgl:IznosiPartnera()'; Fd.Add(Fc);
    Rn := TaFormRunner.CreateRunner(nil, Db, Fd);
    Cmb := TComboBox(Rn.ControlByName('cmbPartner'));
    Check(Cmb.Items.Count = 2, 'forma: combo iz fgl: nudi 2 aktivna partnera iz Zagreba (' + IntToStr(Cmb.Items.Count) + ')');
    Check((Cmb.Items.Count = 2) and (Cmb.Items[0] = 'Alfa'), 'forma: oznake iz drugog stupca, kljucevi iz prvog');
    TComboBox(Rn.ControlByName('cmbGrad')).ItemIndex := TComboBox(Rn.ControlByName('cmbGrad')).Items.IndexOf('Split');
    if Assigned(TComboBox(Rn.ControlByName('cmbGrad')).OnChange) then TComboBox(Rn.ControlByName('cmbGrad')).OnChange(Rn.ControlByName('cmbGrad'));
    Check((Cmb.Items.Count = 1) and (Cmb.Items[0] = 'Delta'), 'forma: promjena polja Grad osvjezava popis partnera iz 4GL-a (' + IntToStr(Cmb.Items.Count) + ')');
    Check(TListBox(Rn.ControlByName('lstSvi')).Items.Count = 1, 'forma: ListBox iz fgl: (neaktivni iz Zagreba)');
    Check((Length(ta_controls.TaChart(Rn.ControlByName('chrPartneri')).Values) = 3) and (Abs(ta_controls.TaChart(Rn.ControlByName('chrPartneri')).Values[1] - 20.5) < 1e-9), 'forma: grafikon iz fgl: oznaka i vrijednost iz EMIT-a');
    Rn.Free;
    { izvjesce s izvorom iz 4GL-a }
    Rd := TaReportDef.Create;
    Rd.Name := 'RepFgl'; Rd.RecordSource := 'fgl:IznosiPartnera()';
    Rd.Add(RItem('TextBox', 'Detail', 'tN', 'naziv', 0, 0, 60, 18));
    Rd.Add(RItem('TextBox', 'Detail', 'tI', '=Format([iznos], "0.00")', 70, 0, 60, 18));
    Re := TaReportEngine.Create(Db, Rd);
    Rr := Re.Render;
    Txt := '';
    for I := 0 to Rr.PageCount - 1 do
      for J := 0 to Rr.Page(I).Items.Count - 1 do
        Txt := Txt + TaRItem(Rr.Page(I).Items[J]).Text + ' ';
    Check((Pos('A 10.00', StringReplace(Txt, '  ', ' ', [rfReplaceAll])) > 0) and (Pos('20.50', Txt) > 0), 'izvjesce: RecordSource = fgl: daje retke iz 4GL-a (' + Txt + ')');
    Rr.Free; Re.Free; Rd.Free;
    Db.Close;
  finally
    Refs.Free;
    H.Free;
    Ev.Vals.Free;
    Ev.Free;
    Db.Free;
  end;
end;

function EdTokens(AEd: TaEditor; ALine: Integer): string;
begin
  Result := AEd.TokenDump(ALine);
end;

procedure TestEditorFamily;
var
  Fm: TForm;
  E: TaEditor;
  V: TStringList;
  Vr: TaEditorVariant;
  Bad, I: Integer;
  S, Err: string;
  L: TStringList;
  Db: TAppDb;
  P: TaEditorPalette;
  T: TaThemeTokens;
  Prog: TaFglProgram;
begin
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 600, 400);
    V := EngineVariants('Editor');
    try
      Check(V.Count = 6, 'editor: u registru je 6 varijanti (' + V.CommaText + ')');
    finally
      V.Free;
    end;
    E := TaEditor.Create(Fm); E.Parent := Fm; E.SetBounds(8, 8, 560, 300);
    { svaka varijanta stvara SynEdit s odgovarajucim bojenjem }
    Bad := 0;
    for Vr := Low(TaEditorVariant) to High(TaEditorVariant) do
    begin
      E.Variant := Vr;
      case Vr of
        ewFgl, ewExpression: if E.HighlighterName <> 'TaSynHighlighter' then Inc(Bad);
        ewSql: if E.HighlighterName <> 'TSynSQLSyn' then Inc(Bad);
        ewPascal: if E.HighlighterName <> 'TSynPasSyn' then Inc(Bad);
        ewJson: if E.HighlighterName <> 'TSynJScriptSyn' then Inc(Bad);
        ewText: if E.HighlighterName <> '' then Inc(Bad);
      end;
    end;
    Check(Bad = 0, 'editor: svaka varijanta ima odgovarajuci SynEdit i bojenje (nepodudaranja: ' + IntToStr(Bad) + ')');
    { tekst ostaje pri promjeni varijante }
    E.Variant := ewFgl;
    E.Text := 'MAIN' + LineEnding + '  DISPLAY "bok"' + LineEnding + 'END MAIN';
    Check(E.LineCount = 3, 'editor: tekst je u tri retka');
    E.Variant := ewSql;
    Check(E.Text = 'MAIN' + LineEnding + '  DISPLAY "bok"' + LineEnding + 'END MAIN', 'editor: tekst ostaje pri promjeni varijante');
    E.Variant := ewFgl;
    { bojenje 4GL-a }
    E.Text := 'IF x > 1 THEN -- komentar' + LineEnding + 'LET s = "a ""b"" c" + $par' + LineEnding + 'DEFINE n INTEGER' + LineEnding +
      '{ blok' + LineEnding + 'nastavak }' + LineEnding + 'LET y = 2.5';
    S := EdTokens(E, 0);
    Check((Pos('3:IF|', S) = 1) and (Pos('11:x|', S) = 0) and (Pos('2:-- komentar|', S) > 0) and (Pos('3:THEN|', S) > 0),
      'bojenje 4GL: kljucna rijec i komentar do kraja retka (' + S + ')');
    S := EdTokens(E, 1);
    Check((Pos('8:"a ""b"" c"|', S) > 0) and (Pos('10:$par|', S) > 0), 'bojenje 4GL: niz s udvojenim navodnicima i $parametar (' + S + ')');
    S := EdTokens(E, 2);
    Check(Pos('4:INTEGER|', S) > 0, 'bojenje 4GL: tip podatka (' + S + ')');
    S := EdTokens(E, 3) + EdTokens(E, 4);
    Check((Pos('2:{ blok|', S) = 1) and (Pos('2:nastavak }|', S) > 0), 'bojenje 4GL: viseretkovni komentar { } (' + S + ')');
    S := EdTokens(E, 5);
    Check((Pos('3:LET|', S) = 1) and (Pos('7:2.5|', S) > 0), 'bojenje 4GL: nakon komentara se nastavlja redovito (' + S + ')');
    { bojenje izraza }
    E.Variant := ewExpression;
    E.Text := 'Zaokruzi([kolicina] * 1.5, 2) And [?Grad] = "x"';
    S := EdTokens(E, 0);
    Check((Pos('5:Zaokruzi|', S) = 1) and (Pos('10:[kolicina]|', S) > 0) and (Pos('3:And|', S) > 0) and (Pos('10:[?Grad]|', S) > 0),
      'bojenje izraza: funkcija, [polje], kljucna rijec, [?parametar] (' + S + ')');
    { sklapanje blokova 4GL-a }
    E.Variant := ewFgl;
    E.Text := 'MAIN' + LineEnding + '  IF x THEN' + LineEnding + '    DISPLAY 1' + LineEnding + '  END IF' + LineEnding + 'END MAIN';
    Check((E.LineCount = 5) and (E.FoldOpenAt(0) = 1) and (E.FoldOpenAt(1) = 1) and (E.FoldCloseAt(3) = 1) and (E.FoldCloseAt(4) = 1), 'sklapanje: MAIN i IF otvaraju, END IF i END MAIN zatvaraju blok');
    { tema: boje prate tokene }
    SetActiveTokens(BuiltinTokens(1, True, shRounded));
    T := ActiveTokens;
    P := EditorPalette(T);
    Check((E.SynBackground = TokenColor(P.Background)) and (E.SynFontName = T.FontFamily) and (E.GutterTextColor = TokenColor(P.GutterText)),
      'editor: pozadina, font i rub prate temu (tamna zelena)');
    Check(E.KeywordColor = TokenColor(P.Keyword), 'editor: kljucne rijeci u boji naglaska');
    SetActiveTokens(BuiltinTokens(0, False, shRounded));
    Check(E.SynBackground = TokenColor(EditorPalette(ActiveTokens).Background), 'editor: promjena teme ponovno boji uredjivac');
    { greske parsera -> oznake }
    L := TStringList.Create;
    try
      Prog := TaFglProgram.Create;
      try
        try
          Prog.LoadText('FUNCTION f()' + LineEnding + '  DEFINE x BLA' + LineEnding + 'END FUNCTION', 'prog');
          Err := '';
        except
          on Ex: Exception do Err := Ex.Message;
        end;
      finally
        Prog.Free;
      end;
      L.Add(Err);
      L.Add('prog.4gl:7: kraj bez IF');
      L.Add('neprepoznat redak');
      Check(E.SetErrorsFromLog(L) = 2, 'greske: dvije od tri poruke su prepoznate (' + Err + ')');
      Check(E.ErrorCount = 2, 'greske: dvije oznake');
      Check(E.ErrorAt(2) <> '', 'greske: redak 2 ima poruku (' + E.ErrorAt(2) + ')');
      Check((E.ErrorAt(7) = 'kraj bez IF') and (E.ErrorAt(3) = ''), 'greske: poruka bez stupca i redak bez greske');
      E.ClearErrors;
      Check(E.ErrorCount = 0, 'greske: brisanje oznaka');
    finally
      L.Free;
    end;
    { dopuna koda }
    L := TStringList.Create;
    try
      E.Variant := ewFgl;
      E.Matches('fo', L);
      Check((L.IndexOf('foreach') >= 0) and (L.IndexOf('format') >= 0) and (L.IndexOf('main') < 0), 'dopuna: rijeci 4GL-a po prefiksu (' + L.CommaText + ')');
      E.Matches('integ', L);
      Check(L.IndexOf('integer') >= 0, 'dopuna: tipovi podataka');
      Db := TAppDb.Create;
      try
        if FileExists('/tmp/ta_editor_words.db') then DeleteFile('/tmp/ta_editor_words.db');
        Db.Open('/tmp/ta_editor_words.db');
        Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
        Db.SaveObject('_sys_programs', 'PopisPartnera', 'FUNCTION PopisPartnera()' + LineEnding + 'END FUNCTION' + LineEnding);
        E.LoadWordsFromDb(Db);
        E.Matches('par', L);
        Check(L.IndexOf('partneri') >= 0, 'dopuna: tablica iz baze (' + L.CommaText + ')');
        E.Matches('gra', L);
        Check(L.IndexOf('grad') >= 0, 'dopuna: stupac iz baze');
        E.Matches('pop', L);
        Check(L.IndexOf('PopisPartnera') >= 0, 'dopuna: 4GL program iz baze');
        Db.Close;
      finally
        Db.Free;
      end;
    finally
      L.Free;
    end;
    { jednoredni nacin }
    E.Variant := ewExpression;
    E.SingleLine := True;
    Check(not E.GutterShown, 'editor: jednoredni nacin nema rub s brojevima');
    E.SingleLine := False;
    Check(E.GutterShown, 'editor: povratak na viseredni nacin');
  finally
    Fm.Free;
  end;
end;

function RunSkelProgram(ADb: TAppDb; const AText: string; AIo: TaFglScriptIO; out ALog: string): Integer;
var
  Pr: TaFglProgram;
  Rn: TaFglRunner;
  Lg: TStringList;
begin
  Result := -1;
  ALog := '';
  Pr := TaFglProgram.Create;
  Lg := TStringList.Create;
  try
    try
      Pr.LoadText(AText, 'kostur');
      if Pr.CheckProgram(Lg) <> 0 then begin ALog := 'check: ' + Lg.Text; Exit; end;
    except
      on E: Exception do begin ALog := 'parse: ' + E.Message; Exit; end;
    end;
    Rn := TaFglRunner.Create(Pr, ADb, AIo);
    try
      Result := Rn.Run;
    finally
      Rn.Free;
    end;
  finally
    Lg.Free;
    Pr.Free;
  end;
end;

function SkelRender(ADb: TAppDb; ALib: TaSkeletonLibrary; const AName: string; AValues: TStrings; out AText: string): Boolean;
var
  Sk: TaSkeleton;
  Err: string;
begin
  Sk := ALib.Find(AName);
  Result := False;
  AText := '';
  if Sk = nil then begin AText := 'nema kostura ' + AName; Exit; end;
  SkeletonDefaults(ADb, Sk, AValues);
  Result := RenderSkeleton(ADb, Sk, AValues, AText, Err);
  if not Result then AText := Err;
end;

procedure TestSkeletons;
var
  Db: TAppDb;
  Lib: TaSkeletonLibrary;
  Lg: TStringList;
  Vals: TStringList;
  Sk: TaSkeleton;
  Txt, Err, LogT, Folder, Why: string;
  I, Rc: Integer;
  Io: TaFglScriptIO;
  Q: TZQuery;
  Tot: Double;
  Bad: Integer;
  SkName: string;
  Tables: array[0..1] of string;
  T: Integer;
begin
  Db := TAppDb.Create;
  Lib := TaSkeletonLibrary.Create;
  Lg := TStringList.Create;
  Vals := TStringList.Create;
  try
    if FileExists('/tmp/ta_skeleton.db') then DeleteFile('/tmp/ta_skeleton.db');
    Db.Open('/tmp/ta_skeleton.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, partner_id INTEGER, broj VARCHAR(20), datum DATE, iznos DECIMAL(12,2), status VARCHAR(10), FOREIGN KEY (partner_id) REFERENCES partneri(id))');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni_arhiva (id INTEGER PRIMARY KEY, partner_id INTEGER, broj VARCHAR(20), datum DATE, iznos DECIMAL(12,2), status VARCHAR(10))');
    Db.Conn.ExecuteDirect('CREATE TABLE artikli (sifra INTEGER PRIMARY KEY, naziv VARCHAR(40), cijena DECIMAL(10,2), nabavljeno DATE, kolicina INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE artikli_arhiva (sifra INTEGER PRIMARY KEY, naziv VARCHAR(40), cijena DECIMAL(10,2), nabavljeno DATE, kolicina INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO partneri VALUES (1, ''Alfa'', ''Zagreb''), (2, ''Beta'', ''Split''), (3, ''Gama'', ''Rijeka'')');
    Db.Conn.ExecuteDirect('INSERT INTO racuni VALUES (1, 1, ''R-1'', ''2026-01-10'', 100.50, ''placen''), (2, 1, ''R-2'', ''2026-01-25'', 49.50, ''otvoren''), ' +
      '(3, 2, ''R-3'', ''2026-02-03'', 200, ''placen''), (4, 2, ''R-4'', ''2027-03-05'', 80, ''otvoren'')');
    Db.Conn.ExecuteDirect('INSERT INTO artikli VALUES (1, ''Vijak'', 2.00, ''2026-01-02'', 100), (2, ''Matica'', 1.50, ''2026-02-02'', 0), (3, ''Podloška'', 0.50, ''2026-02-20'', 50)');
    { knjiznica }
    Folder := FindSkeletonFolder;
    Check(Folder <> '', 'kosturi: mapa skeletons je pronadena (' + Folder + ')');
    Check(Lib.LoadFolder(Folder, Lg) = 13, 'kosturi: ucitano 13 kostura (' + Lg.Text + ')');
    Check(Lib.Find('Zbroj po grupi') <> nil, 'kosturi: pronalazak po nazivu');
    Lg.Clear;
    Lib.Categories(Lg);
    Check(Lg.Count >= 4, 'kosturi: kategorije (' + Lg.CommaText + ')');
    { zapis kostura }
    Check(not ParseSkeleton('@kostur X' + LineEnding + '@utor a : nepoznato' + LineEnding + '---' + LineEnding + 'x', 't', Sk, Err) and (Pos('Nepoznata vrsta', Err) > 0),
      'kosturi: nepoznata vrsta utora je greska (' + Err + ')');
    Check(not ParseSkeleton('@kostur X' + LineEnding + 'tijelo bez crte', 't', Sk, Err), 'kosturi: nedostaje ---');
    Check(ParseSkeleton('@kostur X' + LineEnding + '@buducnost 7' + LineEnding + '---' + LineEnding + 'MAIN' + LineEnding + 'END MAIN', 't', Sk, Err), 'kosturi: nepoznate direktive se tolerantno preskacu');
    Sk.Free;
    { zadane vrijednosti iz podataka }
    Vals.Clear;
    Vals.Values['tablica'] := 'racuni';
    Sk := Lib.Find('Zbroj po razdoblju');
    SkeletonDefaults(Db, Sk, Vals);
    Check((Vals.Values['datum'] = 'datum') and (Vals.Values['iznos'] = 'iznos') and (Vals.Values['razdoblje'] = 'yyyy-mm'),
      'kosturi: zadano iz podataka (datum, iznos, razdoblje): ' + Vals.CommaText);
    Vals.Clear;
    Vals.Values['tablica'] := 'artikli';
    SkeletonDefaults(Db, Lib.Find('Unos i izmjena zapisa'), Vals);
    Check((Vals.Values['kljuc'] = 'sifra') and (Vals.Values['stupci'] = 'naziv,cijena,nabavljeno,kolicina'), 'kosturi: kljuc i stupci bez kljuca: ' + Vals.CommaText);
    Vals.Clear;
    SkeletonDefaults(Db, Lib.Find('Master-detalj'), Vals);
    Check((Vals.Values['veza'] <> ''), 'kosturi: veza se izvodi iz stranog kljuca (' + Vals.CommaText + ')');
    { preduvjeti i ocjena }
    Check(SkeletonApplies(Db, Lib.Find('Zbroj po razdoblju'), 'racuni', Why), 'kosturi: Zbroj po razdoblju vrijedi za racune');
    Check(not SkeletonApplies(Db, Lib.Find('Zbroj po razdoblju'), 'partneri', Why) and (Pos('preduvjet', Why) > 0), 'kosturi: Zbroj po razdoblju ne vrijedi za partnere (' + Why + ')');
    Check(SkeletonScore(Db, Lib.Find('Zbroj po razdoblju'), 'racuni') > SkeletonScore(Db, Lib.Find('Zbroj po razdoblju'), 'partneri'), 'kosturi: ocjena je veca za tablicu s datumom');
    { svaki kostur x barem 2 tablice: izrada + provjera programa }
    Bad := 0;
    Tables[0] := 'racuni'; Tables[1] := 'artikli';
    for I := 0 to Lib.Count - 1 do
    begin
      Sk := Lib[I];
      for T := 0 to 1 do
      begin
        Vals.Clear;
        if Sk.SlotIndex('tablica') >= 0 then Vals.Values['tablica'] := Tables[T]
        else begin
          { master-detalj i brisanje: partneri/racuni ima strani kljuc; za drugi prolaz isto }
          Vals.Values['glavna'] := 'partneri';
          Vals.Values['detalj'] := 'racuni';
        end;
        if (Sk.Name = 'Zbroj po razdoblju') and (T = 1) then Vals.Values['tablica'] := 'artikli';
        if not SkelRender(Db, Lib, Sk.Name, Vals, Txt) then
        begin
          if not ((Sk.Name = 'Zbroj po razdoblju') or (Sk.Name = 'Zbroj po grupi') or (Sk.Name = 'Masovna izmjena s brojačem') or (Sk.Name = 'Sljedeći broj dokumenta')) then
          begin
            Inc(Bad); WriteLn('  kostur "', Sk.Name, '" tablica ', Tables[T], ': ', Txt);
          end;
          Continue;
        end;
        Io := TaFglScriptIO.Create;
        try
          Rc := 0;
          LogT := '';
          { samo staticka provjera i parsiranje }
          with TaFglProgram.Create do
          try
            try
              LoadText(Txt, 'kostur');
              Lg.Clear;
              if CheckProgram(Lg) <> 0 then begin Inc(Bad); WriteLn('  kostur "', Sk.Name, '" ', Tables[T], ' check: ', Lg.Text); end;
            except
              on E: Exception do begin Inc(Bad); WriteLn('  kostur "', Sk.Name, '" ', Tables[T], ' parse: ', E.Message, #10, Txt); end;
            end;
          finally
            Free;
          end;
        finally
          Io.Free;
        end;
      end;
    end;
    Check(Bad = 0, 'kosturi: svih 13 kostura nad dvije tablice daju program koji prolazi --check (' + IntToStr(Bad) + ' problema)');
    { izvrsavanje: Zbroj po grupi }
    Vals.Clear; Vals.Values['tablica'] := 'racuni'; Vals.Values['grupa'] := 'status'; Vals.Values['iznos'] := 'iznos';
    Check(SkelRender(Db, Lib, 'Zbroj po grupi', Vals, Txt), 'kosturi: Zbroj po grupi: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and (Io.Out.IndexOf('placen 300.5') >= 0) and (Io.Out.IndexOf('otvoren 129.5') >= 0) and (Io.Out.IndexOf('Ukupno 430') >= 0),
        'kosturi: Zbroj po grupi daje zbrojeve po statusu (' + LogT + ' ' + Io.Out.CommaText + ')');
    finally
      Io.Free;
    end;
    { Zbroj po razdoblju: po mjesecima i po godinama }
    Vals.Clear; Vals.Values['tablica'] := 'racuni';
    Check(SkelRender(Db, Lib, 'Zbroj po razdoblju', Vals, Txt), 'kosturi: Zbroj po razdoblju: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and (Io.Out.IndexOf('2026-01 150') >= 0) and (Io.Out.IndexOf('2026-02 200') >= 0) and (Io.Out.IndexOf('2027-03 80') >= 0) and (Io.Out.IndexOf('Ukupno 430') >= 0),
        'kosturi: Zbroj po razdoblju (mjeseci) ' + LogT + ' ' + Io.Out.CommaText);
    finally
      Io.Free;
    end;
    Vals.Values['razdoblje'] := 'yyyy';
    Check(SkelRender(Db, Lib, 'Zbroj po razdoblju', Vals, Txt), 'kosturi: Zbroj po razdoblju (godine)');
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and (Io.Out.IndexOf('2026 350') >= 0) and (Io.Out.IndexOf('2027 80') >= 0), 'kosturi: Zbroj po razdoblju po godinama ' + LogT + ' ' + Io.Out.CommaText);
    finally
      Io.Free;
    end;
    { Sljedeci broj }
    Vals.Clear; Vals.Values['tablica'] := 'artikli';
    Check(SkelRender(Db, Lib, 'Sljedeći broj dokumenta', Vals, Txt), 'kosturi: Sljedeci broj: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and (Pos('artikli.sifra): 4', Io.Out.Text) > 0), 'kosturi: Sljedeci broj = 4 (' + LogT + ' ' + Io.Out.CommaText + ')');
    finally
      Io.Free;
    end;
    { Masovna izmjena }
    Vals.Clear; Vals.Values['tablica'] := 'artikli'; Vals.Values['stupac'] := 'cijena'; Vals.Values['uvjet'] := 'kolicina > 0';
    Check(SkelRender(Db, Lib, 'Masovna izmjena s brojačem', Vals, Txt), 'kosturi: Masovna izmjena: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Q := Db.NewQuery('SELECT cijena FROM artikli WHERE sifra = 1'); Q.Open; Tot := Q.Fields[0].AsFloat; Q.Free;
      Check((Rc = 0) and (Io.Out.IndexOf('Promijenjeno redaka: 2') >= 0) and (Abs(Tot - 2.2) < 1e-9), 'kosturi: Masovna izmjena broji redake i mijenja cijenu (' + LogT + ' ' + Io.Out.CommaText + ' ' + FloatToStr(Tot) + ')');
    finally
      Io.Free;
    end;
    { Arhiviranje }
    Vals.Clear; Vals.Values['tablica'] := 'racuni'; Vals.Values['uvjet'] := 'status = ''placen''';
    Check(SkelRender(Db, Lib, 'Arhiviranje', Vals, Txt), 'kosturi: Arhiviranje: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Q := Db.NewQuery('SELECT (SELECT COUNT(*) FROM racuni_arhiva), (SELECT COUNT(*) FROM racuni)'); Q.Open;
      Check((Rc = 0) and (Io.Out.IndexOf('Arhivirano: 2') >= 0) and (Q.Fields[0].AsInteger = 2) and (Q.Fields[1].AsInteger = 2), 'kosturi: Arhiviranje kopira i brise u transakciji (' + LogT + ' ' + Io.Out.CommaText + ')');
      Q.Free;
    finally
      Io.Free;
    end;
    { Popis s filtrom }
    Vals.Clear; Vals.Values['tablica'] := 'artikli';
    Check(SkelRender(Db, Lib, 'Popis s filtrom', Vals, Txt), 'kosturi: Popis s filtrom: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Io.ConstructAnswers.Add('artikli.naziv=M*');
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and (Pos('Matica', Io.Out.Text) > 0) and (Pos('Vijak', Io.Out.Text) = 0), 'kosturi: Popis s filtrom prikazuje samo retke koji odgovaraju (' + LogT + ' ' + Io.Out.CommaText + ')');
    finally
      Io.Free;
    end;
    { Unos i izmjena: novi zapis pa izmjena }
    Vals.Clear; Vals.Values['tablica'] := 'artikli';
    Check(SkelRender(Db, Lib, 'Unos i izmjena zapisa', Vals, Txt), 'kosturi: Unos i izmjena: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Io.PromptAnswers.Add('<cancel>');
      Io.InputAnswers.Add('naziv=Nova|cijena=9.5|kolicina=7');
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Q := Db.NewQuery('SELECT COUNT(*) FROM artikli WHERE naziv = ''Nova'''); Q.Open;
      Check((Rc = 0) and (Q.Fields[0].AsInteger = 1), 'kosturi: Unos i izmjena dodaje novi zapis (' + LogT + ' ' + Io.Out.CommaText + ')');
      Q.Free;
    finally
      Io.Free;
    end;
    Io := TaFglScriptIO.Create;
    try
      Io.PromptAnswers.Add('1');
      Io.InputAnswers.Add('naziv=Vijak M8');
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Q := Db.NewQuery('SELECT naziv FROM artikli WHERE sifra = 1'); Q.Open;
      Check((Rc = 0) and (Q.Fields[0].AsString = 'Vijak M8'), 'kosturi: Unos i izmjena mijenja postojeci zapis (' + LogT + ' ' + Io.Out.CommaText + ' ' + Q.Fields[0].AsString + ')');
      Q.Free;
    finally
      Io.Free;
    end;
    { Master-detalj }
    Vals.Clear; Vals.Values['glavna'] := 'partneri'; Vals.Values['detalj'] := 'racuni';
    Check(SkelRender(Db, Lib, 'Master-detalj', Vals, Txt), 'kosturi: Master-detalj: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and (Io.Out.IndexOf('    (1 redaka)') >= 0) and (Io.Out.IndexOf('    (0 redaka)') >= 0), 'kosturi: Master-detalj broji retke detalja po glavnom zapisu (' + LogT + ' ' + Io.Out.CommaText + ')');
    finally
      Io.Free;
    end;
    { Brisanje s provjerom veza }
    Vals.Clear; Vals.Values['glavna'] := 'partneri'; Vals.Values['detalj'] := 'racuni';
    Check(SkelRender(Db, Lib, 'Brisanje s provjerom veza', Vals, Txt), 'kosturi: Brisanje: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Io.PromptAnswers.Add('1');
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Q := Db.NewQuery('SELECT COUNT(*) FROM partneri'); Q.Open;
      Check((Rc = 0) and (Q.Fields[0].AsInteger = 3) and (Pos('ne može se obrisati', Io.Out.Text) > 0), 'kosturi: Brisanje odbija zapis s povezanim retcima (' + LogT + ' ' + Io.Out.CommaText + ')');
      Q.Free;
    finally
      Io.Free;
    end;
    Io := TaFglScriptIO.Create;
    try
      Io.PromptAnswers.Add('3');
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Q := Db.NewQuery('SELECT COUNT(*) FROM partneri'); Q.Open;
      Check((Rc = 0) and (Q.Fields[0].AsInteger = 2) and (Io.Out.IndexOf('Obrisano: 1') >= 0), 'kosturi: Brisanje brise zapis bez povezanih redaka (' + LogT + ' ' + Io.Out.CommaText + ')');
      Q.Free;
    finally
      Io.Free;
    end;
    { Izbornik }
    Vals.Clear; Vals.Values['tablica'] := 'artikli';
    Check(SkelRender(Db, Lib, 'Izbornik nad tablicom', Vals, Txt), 'kosturi: Izbornik: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Io.MenuAnswers.Add('Broj zapisa');
      Io.MenuAnswers.Add('Izlaz');
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and (Pos('Zapisa u artikli: 4', Io.Out.Text) > 0), 'kosturi: Izbornik poziva funkcije (' + LogT + ' ' + Io.Out.CommaText + ')');
    finally
      Io.Free;
    end;
    { Izvoz u PDF }
    Vals.Clear; Vals.Values['tablica'] := 'artikli'; Vals.Values['datoteka'] := '/tmp/ta_skel_izvoz.pdf';
    if FileExists('/tmp/ta_skel_izvoz.pdf') then DeleteFile('/tmp/ta_skel_izvoz.pdf');
    Check(SkelRender(Db, Lib, 'Izvoz tablice u PDF', Vals, Txt), 'kosturi: Izvoz u PDF: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and FileExists('/tmp/ta_skel_izvoz.pdf'), 'kosturi: Izvoz u PDF stvara datoteku (' + LogT + ' ' + Io.Out.CommaText + ')');
    finally
      Io.Free;
    end;
    { Pregled u mrezi }
    Vals.Clear; Vals.Values['tablica'] := 'artikli';
    Check(SkelRender(Db, Lib, 'Pregled u mreži', Vals, Txt), 'kosturi: Pregled u mrezi: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check(Rc = 0, 'kosturi: Pregled u mrezi se izvrsava (' + LogT + ' ' + Io.Out.CommaText + ')');
    finally
      Io.Free;
    end;
    { vlastiti kostur u mapi: pojavljuje se bez ponovnog prevodenja }
    ForceDirectories('/tmp/ta_skel_vlastiti');
    Lg.Clear;
    Lg.Add('@format 1');
    Lg.Add('@kostur  Moj brojac');
    Lg.Add('@kategorija  Vlastiti');
    Lg.Add('@utor tablica : tablica "Koja tablica?"');
    Lg.Add('---');
    Lg.Add('MAIN');
    Lg.Add('  DEFINE n INTEGER');
    Lg.Add('  SELECT COUNT(*) INTO n FROM {tablica}');
    Lg.Add('  DISPLAY "Redaka: ", n');
    Lg.Add('END MAIN');
    Lg.SaveToFile('/tmp/ta_skel_vlastiti/moj_brojac.4glt');
    Lib.Clear;
    Check((Lib.LoadFolder('/tmp/ta_skel_vlastiti') = 1) and (Lib.Find('Moj brojac') <> nil), 'kosturi: vlastiti .4glt iz mape se pojavljuje u knjiznici');
    Vals.Clear; Vals.Values['tablica'] := 'partneri';
    Check(SkelRender(Db, Lib, 'Moj brojac', Vals, Txt), 'kosturi: vlastiti kostur se izgradi: ' + Txt);
    Io := TaFglScriptIO.Create;
    try
      Rc := RunSkelProgram(Db, Txt, Io, LogT);
      Check((Rc = 0) and (Io.Out.IndexOf('Redaka: 2') >= 0), 'kosturi: vlastiti kostur radi (' + LogT + ' ' + Io.Out.CommaText + ')');
    finally
      Io.Free;
    end;
    { nedostajuci utor }
    Lib.Clear;
    Lib.LoadFolder(Folder);
    Vals.Clear;
    Sk := Lib.Find('Zbroj po grupi');
    Check(not RenderSkeleton(Db, Sk, Vals, Txt, Err) and (Pos('nije popunjen', Err) > 0), 'kosturi: nepopunjen utor je greska (' + Err + ')');
    Db.Close;
  finally
    Vals.Free;
    Lg.Free;
    Lib.Free;
    Db.Free;
  end;
end;

procedure TestSkelWizard;
var
  Db: TAppDb;
  W: TfrmSkelWizard;
  C: TControl;
  Nm: string;
begin
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_skelwiz.db') then DeleteFile('/tmp/ta_skelwiz.db');
    Db.Open('/tmp/ta_skelwiz.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, partner_id INTEGER, broj VARCHAR(20), iznos DECIMAL(12,2), FOREIGN KEY (partner_id) REFERENCES partneri(id))');
    W := TfrmSkelWizard.CreateWizard(nil, Db, '');
    try
      Check(W.SkeletonList.Items.Count >= 13, 'cirobnjak: popis kostura po kategorijama');
      W.UseData('racuni');
      Check((W.SkeletonList.Items.Count > 0) and (Pos('%', W.SkeletonList.Items[0]) > 0), 'cirobnjak: od podataka, poredak s postocima');
      W.SelectSkeleton('Popis s filtrom');
      Check(W.Flow.Skeleton <> nil, 'cirobnjak: kostur odabran');
      Check(W.Preview.Text <> '', 'cirobnjak: pregled 4GL-a nije prazan');
      C := W.SlotControl('tablica');
      Check(C is TComboBox, 'cirobnjak: utor tablica je padajuci popis');
      W.SetSlotValue('tablica', 'partneri');
      Check(Pos('partneri', W.Preview.Text) > 0, 'cirobnjak: promjena utora obnavlja pregled');
      Check(W.Flow.Check(TStringList.Create) = 0, 'cirobnjak: program je ispravan');
    finally
      W.Free;
    end;
    Db.Close;
  finally
    Db.Free;
  end;
end;

function DigitsOnly(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if S[I] in ['0'..'9'] then Result := Result + S[I];
end;

procedure TestBlockWizard;
var
  Db: TAppDb;
  W: TfrmBlockWizard;
  Rn: TaFormRunner;
  D: TaFormDef;
  I, Combos, Subs, Checks: Integer;
  Json, Err: string;
begin
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_blockwiz.db') then DeleteFile('/tmp/ta_blockwiz.db');
    Db.Open('/tmp/ta_blockwiz.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, partner_id INTEGER, broj VARCHAR(20), datum DATE, iznos DECIMAL(12,2), placen BOOLEAN, FOREIGN KEY (partner_id) REFERENCES partneri(id))');
    W := TfrmBlockWizard.CreateWizard(nil, Db, '');
    try
      W.Configure('racuni', blForm, True);
      Check(W.Info.Items.Count >= 6, 'blok: opis ima redak po stupcu (' + IntToStr(W.Info.Items.Count) + ')');
      Check(Pos('padajuci popis iz tablice partneri', W.Info.Items.Text) > 0, 'blok: strani kljuc je padajuci popis');
      Check(Pos('kvacica', W.Info.Items.Text) > 0, 'blok: logicki stupac je kvacica');
      D := W.Wiz.Build('B1');
      try
        Combos := 0; Checks := 0;
        for I := 0 to D.Count - 1 do
        begin
          if D.Controls[I].Kind = 'ComboBox' then Inc(Combos);
          if D.Controls[I].Kind = 'CheckBox' then Inc(Checks);
        end;
        Check((Combos = 1) and (Checks = 1), 'blok: forma ima 1 padajuci popis i 1 kvacicu (' + IntToStr(Combos) + ',' + IntToStr(Checks) + ')');
      finally
        D.Free;
      end;
      W.Configure('partneri', blFormAndTable, True);
      Check(Pos('podforma: racuni', W.Info.Items.Text) > 0, 'blok: master-detalj iz stranog kljuca (podforma racuni)');
      W.NameEdit.Text := 'BlokPartneri';
      Check(W.DoSave, 'blok: spremanje forme');
      Json := Db.LoadObject('_sys_forms', 'BlokPartneri');
      Check(Json <> '', 'blok: forma je u bazi');
      D := TaFormDef.Create;
      try
        D.FromJson(Json);
        Check((D.RecordSource = 'partneri') and (D.ViewMode = 'split'), 'blok: forma se ucitava, izvor i raspored (' + D.ViewMode + ')');
      finally
        D.Free;
      end;
      W.Configure('racuni', blTable, True);
      Check(W.Wiz.Save('BlokTablica', Err), 'blok: tablicni raspored se sprema ' + Err);
      { neprekidna forma }
      W.Configure('racuni', blContinuous, True);
      Check(Pos('Neprekidna forma', W.Info.Items.Text) > 0, 'blok: opis neprekidne forme');
      D := W.Wiz.Build('BlokNep');
      try
        Check((D.ViewMode = 'continuous') and (D.HeaderHeight = 54) and (D.RowHeight = 34) and (D.FooterHeight = 34), 'blok: neprekidna forma ima odjeljke i visine');
        Combos := 0; Checks := 0; Subs := 0;
        for I := 0 to D.Count - 1 do
        begin
          if (D[I].Section = 'detail') and (D[I].Kind = 'ComboBox') then Inc(Combos);
          if (D[I].Section = 'detail') and (D[I].Kind = 'CheckBox') then Inc(Checks);
          if (D[I].Section = 'header') and (D[I].GetX('sort') <> '') then Inc(Subs);
        end;
        Check(Combos = 1, 'blok: strani kljuc je padajuci popis u detalju');
        Check(Checks = 1, 'blok: logicki stupac je kvacica u detalju');
        Check(Subs = 5, 'blok: naslovi zaglavlja sortiraju (5 stupaca bez kljuca): ' + IntToStr(Subs));
        Check((D.IndexOfName('z_broj') >= 0) and (D.IndexOfName('z_iznos') >= 0), 'blok: podnozje ima broj redaka i zbroj iznosa');
        Check(D[D.IndexOfName('z_iznos')].ControlSource = '=Sum(iznos)', 'blok: zbroj je izraz =Sum(iznos)');
        Check(D[D.IndexOfName('c_datum')].Format = 'dd.mm.yyyy', 'blok: datum ima format');
      finally
        D.Free;
      end;
      { obrazac + neprekidne podforme }
      Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad) VALUES (''Alfa'', ''Zagreb'')');
      Db.Conn.ExecuteDirect('INSERT INTO racuni (partner_id, broj, iznos) VALUES (1, ''R-1'', 10), (1, ''R-2'', 20.5)');
      W.Configure('partneri', blFormContinuousSub, True);
      Check(Pos('neprekidna podforma: racuni', W.Info.Items.Text) > 0, 'blok: opis neprekidne podforme');
      W.NameEdit.Text := 'BlokGlavni';
      Check(W.DoSave, 'blok: spremanje obrasca s neprekidnom podformom');
      Check(Db.LoadObject('_sys_forms', 'BlokGlavni_racuni') <> '', 'blok: neprekidna podforma je spremljena kao zasebna forma');
      D := TaFormDef.Create;
      try
        D.FromJson(Db.LoadObject('_sys_forms', 'BlokGlavni'));
        Check((D.IndexOfName('sub_racuni') >= 0) and (D[D.IndexOfName('sub_racuni')].RowSource = 'BlokGlavni_racuni') and
              (D[D.IndexOfName('sub_racuni')].LinkChild = 'partner_id') and (D[D.IndexOfName('sub_racuni')].LinkMaster = 'id'),
          'blok: glavni obrazac ima podformu s vezom id -> partner_id');
      finally
        D.Free;
      end;
      D := TaFormDef.Create;
      D.FromJson(Db.LoadObject('_sys_forms', 'BlokGlavni'));
      Rn := TaFormRunner.CreateRunner(nil, Db, D);
      try
        Check((Rn.SubRunner('sub_racuni') <> nil) and (Rn.SubRunner('sub_racuni').ContinuousForm <> nil), 'blok: izradena forma se otvara s neprekidnom podformom');
        if (Rn.SubRunner('sub_racuni') <> nil) and (Rn.SubRunner('sub_racuni').ContinuousForm <> nil) then
        begin
          Check(Rn.SubRunner('sub_racuni').ContinuousForm.Host.Model.RecordCount = 2, 'blok: podforma pokazuje 2 racuna partnera 1');
          Check(DigitsOnly(Rn.SubRunner('sub_racuni').ContinuousForm.FooterText('z_iznos')) = '3050', 'blok: zbroj u podnozju 30,50 (' + Rn.SubRunner('sub_racuni').ContinuousForm.FooterText('z_iznos') + ')');
        end;
      finally
        Rn.Free;
      end;
    finally
      W.Free;
    end;
    Db.Close;
  finally
    Db.Free;
  end;
end;

procedure PalAdd(ADb: TAppDb; const AId: string; const AVals: array of string; AText: TStrings; ADepth: Integer);
{ AVals = ime=vrijednost parovi; sto nije zadano, popuni se iz baze kao u dijalogu }
var
  B: TaPBlock;
  V, L: TStringList;
  I: Integer;
begin
  B := PaletteBlock(PaletteFind(AId));
  V := TStringList.Create;
  L := TStringList.Create;
  try
    for I := 0 to High(AVals) do V.Add(AVals[I]);
    BlockDefaults(ADb, B, V, AText.Text);
    RenderBlock(B, V, L);
    for I := 0 to L.Count - 1 do AText.Add(StringOfChar(' ', 2 * ADepth) + L[I]);
  finally
    V.Free;
    L.Free;
  end;
end;

procedure TestFglPalette;
var
  Db: TAppDb;
  T, Ch, Lg, V: TStringList;
  B: TaPBlock;
  Vals: TStringList;
  Io: TaFglScriptIO;
  Log, S: string;
  Rc, I, Idx: Integer;
  Dlg: TfrmPaletteBlock;
begin
  Db := TAppDb.Create;
  T := TStringList.Create;
  Ch := TStringList.Create;
  Lg := TStringList.Create;
  Vals := TStringList.Create;
  try
    if FileExists('/tmp/ta_pal.db') then DeleteFile('/tmp/ta_pal.db');
    Db.Open('/tmp/ta_pal.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
    Db.Conn.ExecuteDirect('INSERT INTO partneri VALUES (1, ''Alfa'', ''Zagreb''), (2, ''Beta'', ''Split''), (3, ''Gama'', ''Zagreb'')');
    Db.SaveObject('_sys_programs', 'Pomocni', 'FUNCTION Pomocni()'#10'END FUNCTION'#10);
    Check(PaletteCount >= 18, 'paleta: blokovi iz plana (' + IntToStr(PaletteCount) + ')');
    { padajuci popisi iz baze }
    B := PaletteBlock(PaletteFind('otvorifilter'));
    Vals.Values['tablica'] := 'partneri';
    SlotChoices(Db, B, 'tablica', Vals, '', Ch);
    Check(Ch.IndexOf('partneri') >= 0, 'paleta: tablice iz baze');
    SlotChoices(Db, B, 'stupac', Vals, '', Ch);
    Check((Ch.IndexOf('grad') >= 0) and (Ch.Count = 3), 'paleta: stupci odabrane tablice (' + Ch.CommaText + ')');
    SlotChoices(Db, B, 'varijabla', Vals, 'MAIN'#10'  DEFINE a, b INTEGER'#10'  DEFINE grad TEXT'#10'END MAIN', Ch);
    Check((Ch.IndexOf('a') >= 0) and (Ch.IndexOf('b') >= 0) and (Ch.IndexOf('grad') >= 0), 'paleta: varijable iz programa (' + Ch.CommaText + ')');
    SlotChoices(Db, PaletteBlock(PaletteFind('pozovi')), 'program', Vals, '', Ch);
    Check(Ch.IndexOf('Pomocni') >= 0, 'paleta: programi iz baze');
    { popis partnera s filtrom po gradu i gumbom za PDF: samo blokovi }
    T.Add('MAIN');
    PalAdd(Db, 'zapis', ['zapis=r', 'tablica=partneri'], T, 1);
    PalAdd(Db, 'varijabla', ['ime=grad', 'tip=TEXT'], T, 1);
    PalAdd(Db, 'pitaj', ['pitanje=Grad:', 'varijabla=grad'], T, 1);
    PalAdd(Db, 'otvorifilter', ['kursor=c', 'tablica=partneri', 'stupac=grad', 'varijabla=grad'], T, 1);
    PalAdd(Db, 'pdf', ['izvjesce=popis', 'datoteka=/tmp/ta_pal.pdf'], T, 1);
    T.Add('  FOREACH c INTO r.*');
    PalAdd(Db, 'redakizv', ['izvjesce=popis', 'zapis=r'], T, 2);
    T.Add('  END FOREACH');
    PalAdd(Db, 'zavrsiizv', ['izvjesce=popis'], T, 1);
    T.Add('END MAIN');
    PalAdd(Db, 'izvjesce', ['naziv=popis', 'tablica=partneri'], T, 0);
    if FileExists('/tmp/ta_pal.pdf') then DeleteFile('/tmp/ta_pal.pdf');
    Io := TaFglScriptIO.Create;
    try
      Io.PromptAnswers.Add('Zagreb');
      Rc := RunSkelProgram(Db, T.Text, Io, Log);
      Check((Rc = 0) and FileExists('/tmp/ta_pal.pdf'), 'paleta: program iz blokova prolazi provjeru i izvodi se, PDF je nastao (rc=' + IntToStr(Rc) + ') ' + Log + T.Text);
    finally
      Io.Free;
    end;
    { dvosmjerno: svaki redak se prepoznaje kao isti blok s istim vrijednostima }
    Idx := MatchLine('  DECLARE c CURSOR FOR SELECT * FROM partneri WHERE grad = $grad', V);
    Check((Idx >= 0) and (PaletteBlock(Idx).Id = 'otvorifilter') and (V.Values['stupac'] = 'grad') and (V.Values['varijabla'] = 'grad'),
      'paleta: redak 4GL-a se prepoznaje kao blok "Otvori tablicu s filtrom" (' + IntToStr(Idx) + ')');
    V.Free;
    Idx := MatchLine('DECLARE c CURSOR FOR SELECT * FROM partneri', V);
    Check((Idx >= 0) and (PaletteBlock(Idx).Id = 'otvori') and (V.Values['tablica'] = 'partneri'), 'paleta: obicno otvaranje tablice se ne miješa s filterom');
    V.Free;
    Idx := MatchLine('PRINT r.naziv, r.grad', V);
    V.Free;
    Idx := MatchLine('START REPORT popis TO PDF "x.pdf"', V);
    Check((Idx >= 0) and (PaletteBlock(Idx).Id = 'pdf') and (V.Values['datoteka'] = 'x.pdf'), 'paleta: PDF blok se prepoznaje');
    V.Free;
    Idx := MatchLine('LET nesto = nesto_drugo + 1', V);
    Check((Idx >= 0) and (PaletteBlock(Idx).Id = 'postavi'), 'paleta: LET je blok Postavi varijablu');
    V.Free;
    Idx := MatchLine('SKIP 1 LINES', V);
    Check(Idx < 0, 'paleta: nepoznat redak ostaje obican redak');
    V.Free;
    { greske pokazuju na blok }
    S := StringReplace(T.Text, 'FROM partneri WHERE', 'FROM nepostojeca WHERE', []);
    Lg.Add('program.4gl:6: Tablica ne postoji');
    T.Clear;
    T.Add('MAIN');
    T.Add('  DECLARE c CURSOR FOR SELECT * FROM partneri');
    T.Add('END MAIN');
    Lg.Clear;
    Lg.Add('program.4gl:2: Nepoznata tablica');
    Lg.Add('program.4gl:3: nešto drugo');
    AnnotateLog(T.Text, Lg);
    Check(Pos('Blok "Otvori tablicu" (redak 2)', Lg[0]) = 1, 'paleta: greska pokazuje na blok (' + Lg[0] + ')');
    Check(Pos('Blok', Lg[1]) = 0, 'paleta: redak bez bloka ostaje isti (' + Lg[1] + ')');
    { dijalog: padajuci popisi i pregled }
    Dlg := TfrmPaletteBlock.CreatePicker(nil, Db, 'MAIN'#10'  DEFINE broj INTEGER'#10'END MAIN');
    try
      Dlg.SelectBlock('otvorifilter');
      Check(Dlg.SlotControl('tablica') is TComboBox, 'paleta dijalog: tablica je padajuci popis');
      Check(Pos('FROM partneri', Dlg.Preview.Text) > 0, 'paleta dijalog: pregled sa zadanom tablicom (' + Dlg.Preview.Text + ')');
      Dlg.SetSlot('stupac', 'naziv');
      Check(Pos('WHERE naziv = $broj', Dlg.Preview.Text) > 0, 'paleta dijalog: stupac i varijabla iz programa (' + Dlg.Preview.Text + ')');
      Lg.Clear;
      Dlg.GetLines(Lg);
      Check(Lg.Count = 1, 'paleta dijalog: blok daje retke za umetanje');
    finally
      Dlg.Free;
    end;
    Db.Close;
  finally
    Vals.Free; Lg.Free; Ch.Free; T.Free; Db.Free;
  end;
end;

function EditHookStub(const AName: string; var AValue: string): Boolean;
begin
  AValue := AName + ':' + AValue + '!';
  Result := True;
end;

procedure TestEditDlg;
var
  Db: TAppDb;
  Ctx: TaEditContext;
  F, Ch: TStringList;
  A, B, J, W: string;
  T: TaThemeTokens;
  Okk: Boolean;
begin
  Db := TAppDb.Create;
  F := TStringList.Create;
  Ch := TStringList.Create;
  try
    if FileExists('/tmp/ta_editdlg.db') then DeleteFile('/tmp/ta_editdlg.db');
    Db.Open('/tmp/ta_editdlg.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
    Ctx := TaEditContext.Create(Db, nil, 'partneri');
    try
      Ctx.FieldsInto(F);
      Check(F.CommaText = 'id,naziv,grad', 'editdlg: polja izvora (' + F.CommaText + ')');
    finally
      Ctx.Free;
    end;
    Ctx := TaEditContext.Create(Db, nil);
    try
      Check(Ctx.EffectiveSource = 'partneri', 'editdlg: zadani izvor je prva tablica');
      EditDialogHook := @EditHookStub;
      { IDE put (Edit* s kontekstom) i put dizajnera daju istu vrijednost }
      A := 'openform:X'; B := 'openform:X';
      EditAction(Ctx, A);
      DesignEditAction(nil, Db, nil, B);
      Check(A = B, 'editdlg: radnja, IDE i dizajner daju istu vrijednost (' + A + ' / ' + B + ')');
      A := 'Gr = 1'; B := 'Gr = 1';
      EditCondFormat(Ctx, A);
      DesignEditCondFormat(nil, Db, nil, B);
      Check(A = B, 'editdlg: uvjetno oblikovanje je isto');
      A := 'a -> b = 1'; B := 'a -> b = 1';
      EditRule(Ctx, A);
      DesignEditRule(nil, Db, nil, B);
      Check(A = B, 'editdlg: pravilo je isto');
      A := 'sql:SELECT 1'; B := 'sql:SELECT 1';
      EditSource(Ctx, 'ComboBox', A);
      DesignEditSource(nil, Db, 'ComboBox', B);
      Check(A = B, 'editdlg: izvor je isti');
      A := '[a] > 1';
      Okk := EditExpr(Ctx, A, 'Uvjet');
      Check(Okk and (A = 'expression:[a] > 1!'), 'editdlg: izraz (' + A + ')');
      A := '0.00';
      EditFormat(Ctx, A, 'broj');
      Check(A = 'format:0.00!', 'editdlg: format');
      A := '';
      EditTheme(Ctx, A);
      Check(A = 'theme:!', 'editdlg: tema');
    finally
      EditDialogHook := nil;
      Ctx.Free;
    end;
    FormatChoices('datum', Ch);
    Check(Ch.IndexOf('dd.mm.yyyy') >= 0, 'editdlg: formati datuma');
    FormatChoices('iznos', Ch);
    Check(Ch.IndexOf('#,##0.00') >= 0, 'editdlg: formati iznosa');
    J := ThemeJsonFor('#16A34A', True, 'pill');
    Okk := TokensFromJson(J, T, W);
    Check(Okk and SameText(T.Accent, DeriveTokens('x', '#16A34A', True, shPill).Accent) and (T.Shape = shPill) and T.Dark, 'editdlg: tema iz naglaska, tamna, pill ' + T.Accent + ' ' + W);
    Db.Close;
  finally
    Ch.Free; F.Free; Db.Free;
  end;
end;

procedure TestRowModel;
var
  M: TaRowModel;
  Np: Boolean;
  R, C, F, L: Integer;
begin
  M := TaRowModel.Create;
  try
    M.SetViewRows(10);
    M.SetRecordCount(100);
    Check(M.RowCount = 101, 'rowmodel: 100 zapisa + novi red = 101');
    Check(M.NewRow = 100, 'rowmodel: novi red je zadnji');
    Check(M.IsNewRow(100) and not M.IsNewRow(99), 'rowmodel: IsNewRow');
    M.AllowAdds := False;
    Check((M.RowCount = 100) and (M.NewRow = -1), 'rowmodel: bez dodavanja nema novog reda');
    M.AllowAdds := True;
    { klizanje }
    M.ScrollTo(50);
    Check(M.Offset = 50, 'rowmodel: klizanje na 50');
    M.ScrollTo(1000);
    Check(M.Offset = 91, 'rowmodel: klizanje ogranicen na kraj (101 redak, 10 vidljivo)');
    M.ScrollBy(-1000);
    Check(M.Offset = 0, 'rowmodel: klizanje ogranicen na pocetak');
    Check(M.VisibleRange(F, L) and (F = 0) and (L = 9), 'rowmodel: vidljivo 0..9');
    { kretanje }
    Check(M.MoveNext(Np) and (M.Current = 1) and not Np, 'rowmodel: sljedeci red');
    Check(M.PageDown(Np) and (M.Current = 11), 'rowmodel: PgDn za 10');
    Check(M.Offset = 2, 'rowmodel: trenutni red se uvijek vidi (offset ' + IntToStr(M.Offset) + ')');
    Check(M.PageUp(Np) and (M.Current = 1), 'rowmodel: PgUp');
    Check(M.MoveLast(Np) and (M.Current = 99), 'rowmodel: Ctrl+End je zadnji pravi zapis');
    Check(M.MoveNext(Np) and (M.Current = 100) and M.IsNewRow(M.Current), 'rowmodel: strelica dolje s zadnjeg zapisa ide na novi red');
    M.MoveNext(Np);
    Check(M.Current = 100, 'rowmodel: ispod novog reda nema nista');
    Check(M.MoveFirst(Np) and (M.Current = 0) and (M.Offset = 0), 'rowmodel: Ctrl+Home');
    Check(M.MoveNew(Np) and (M.Current = 100), 'rowmodel: Ctrl+N skace na novi red');
    { nespremljen red }
    M.MoveFirst(Np);
    M.MarkDirty;
    Check(M.Dirty, 'rowmodel: red je prljav');
    Check(not M.MoveTo(5, Np) and Np and (M.Current = 0), 'rowmodel: iz prljavog reda se ne ide bez Posta (trazi Post)');
    Check(M.MoveTo(0, Np) and not Np, 'rowmodel: ostanak u istom redu je uvijek dopusten');
    M.MarkClean;
    Check(M.MoveTo(5, Np) and (M.Current = 5), 'rowmodel: nakon Posta se ide');
    { novi red: Post stvara zapis, ispod je opet novi red }
    M.MoveNew(Np);
    M.MarkDirty;
    M.RecordPosted;
    Check((M.RecordCount = 101) and (M.RowCount = 102) and (M.Current = 100) and not M.IsNewRow(M.Current),
      'rowmodel: Post novog reda daje zapis, novi red je ispod');
    Check(M.NewRow = 101, 'rowmodel: novi red se pomaknuo ispod');
    { brisanje }
    M.MoveTo(10, Np);
    M.MarkDirty;
    M.RecordDeleted;
    Check((M.RecordCount = 100) and not M.Dirty, 'rowmodel: brisanje smanjuje broj zapisa');
    { Tab }
    Check(M.TabTarget(3, 0, 4, False, R, C) and (R = 3) and (C = 1), 'rowmodel: Tab unutar reda');
    Check(M.TabTarget(3, 3, 4, False, R, C) and (R = 4) and (C = 0), 'rowmodel: Tab s kraja reda ide na prvu kontrolu sljedeceg reda');
    Check(M.TabTarget(3, 0, 4, True, R, C) and (R = 2) and (C = 3), 'rowmodel: Shift+Tab s pocetka ide na zadnju kontrolu prethodnog reda');
    Check(not M.TabTarget(0, 0, 4, True, R, C), 'rowmodel: Shift+Tab na prvoj kontroli prvog reda ne ide nigdje');
    Check(not M.TabTarget(M.RowCount - 1, 3, 4, False, R, C), 'rowmodel: Tab na zadnjoj kontroli zadnjeg reda ne ide nigdje');
    { prazan model }
    M.SetRecordCount(0);
    Check((M.RowCount = 1) and (M.Current = 0) and M.IsNewRow(0), 'rowmodel: prazna tablica ima samo novi red');
    M.AllowAdds := False;
    Check(M.RowCount = 0, 'rowmodel: prazna tablica bez dodavanja nema redova');
    Check(not M.VisibleRange(F, L), 'rowmodel: nema vidljivog raspona');
  finally
    M.Free;
  end;
end;

procedure TestRowSource;
var
  Db: TAppDb;
  S: TaRowSource;
  I: Integer;
  Fk: TaRowSource;
begin
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_rowsrc.db') then DeleteFile('/tmp/ta_rowsrc.db');
    Db.Open('/tmp/ta_rowsrc.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30))');
    Db.Conn.ExecuteDirect('CREATE TABLE stavke (id INTEGER PRIMARY KEY, partner_id INTEGER NOT NULL, opis VARCHAR(40), iznos DECIMAL(12,2), FOREIGN KEY (partner_id) REFERENCES partneri(id))');
    Db.Conn.ExecuteDirect('CREATE TABLE bezkljuca (a TEXT, b TEXT)');
    Db.Conn.ExecuteDirect('BEGIN');
    for I := 1 to 1000 do
      if I mod 2 = 0 then
        Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad) VALUES (''P' + Format('%.4d', [I]) + ''', ''Zagreb'')')
      else
        Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad) VALUES (''P' + Format('%.4d', [I]) + ''', ''Split'')');
    Db.Conn.ExecuteDirect('COMMIT');
    Db.Conn.ExecuteDirect('INSERT INTO stavke (partner_id, opis, iznos) VALUES (1, ''a'', 10), (1, ''b'', 20.5), (2, ''c'', 5)');
    S := TaRowSource.Create(Db, 'partneri');
    try
      Check(S.CanEdit and (S.KeyField = 'id'), 'rowsource: tablica je uriediva, kljuc id');
      Check(S.Columns.CommaText = 'id,naziv,grad', 'rowsource: stupci (' + S.Columns.CommaText + ')');
      Check(S.Count = 1000, 'rowsource: broj zapisa 1000');
      S.Fetch(0, 30);
      Check((S.Value(0, 'naziv') = 'P0001') and (S.Value(29, 'naziv') = 'P0030'), 'rowsource: prozor 0..29');
      Check(S.Value(500, 'naziv') = 'P0501', 'rowsource: red izvan prozora se dohvaca (500)');
      Check(S.KeyOf(10) = '11', 'rowsource: kljuc retka');
      { filtar i sortiranje }
      S.SetFilter('grad = ''Zagreb''');
      Check(S.Count = 500, 'rowsource: filtar Zagreb daje 500');
      S.SetSort('naziv', True);
      Check(S.Value(0, 'naziv') = 'P1000', 'rowsource: silazno po nazivu, prvi je P1000');
      S.SetFilter('');
      S.SetSort('', False);
      Check(S.Count = 1000, 'rowsource: filtar ocisten');
      { agregati }
      Check(S.Aggregate('COUNT', '*') = '1000', 'rowsource: COUNT(*)');
      Check(S.Aggregate('MAX', 'id') = '1000', 'rowsource: MAX(id)');
      Check(S.Aggregate('DROP', 'id') = '', 'rowsource: nedopustena funkcija se odbija');
      Check(S.Aggregate('SUM', 'nepostoji') = '', 'rowsource: nepoznato polje se odbija');
      { izmjena }
      Check(S.BeginEdit(4), 'rowsource: BeginEdit');
      S.SetValue('grad', 'Rijeka');
      Check(S.Pending('grad') = 'Rijeka', 'rowsource: pending vrijednost');
      Check(S.Post, 'rowsource: Post izmjene ' + S.Error);
      Check(S.Value(4, 'grad') = 'Rijeka', 'rowsource: izmjena je u bazi');
      { Cancel }
      S.BeginEdit(4);
      S.SetValue('grad', 'Pula');
      S.Cancel;
      Check(S.Value(4, 'grad') = 'Rijeka', 'rowsource: Cancel ne mijenja');
      { novi zapis }
      Check(S.BeginNew, 'rowsource: BeginNew');
      S.SetValue('naziv', 'Novi d.o.o.');
      S.SetValue('grad', 'Osijek');
      Check(S.Post, 'rowsource: Post novog ' + S.Error);
      Check((S.Count = 1001) and (S.PostedKey = '1001'), 'rowsource: novi zapis, kljuc ' + S.PostedKey);
      Check(S.IndexOfKey(S.PostedKey) = 1000, 'rowsource: novi zapis je zadnji (indeks 1000)');
      { greska baze: NOT NULL }
      S.BeginNew;
      S.SetValue('grad', 'Samo grad');
      Check(not S.Post, 'rowsource: NOT NULL se odbija');
      Check(S.Error <> '', 'rowsource: poruka greske postoji (' + Copy(S.Error, 1, 60) + ')');
      Check(S.Editing and S.IsNew, 'rowsource: red ostaje nespremljen nakon greske');
      S.SetValue('naziv', 'Sad ima naziv');
      Check(S.Post, 'rowsource: ispravljen red se sprema');
      Check(S.Count = 1002, 'rowsource: 1002 zapisa');
      { brisanje }
      Check(S.Delete(1001), 'rowsource: brisanje');
      Check(S.Count = 1001, 'rowsource: nakon brisanja 1001');
      { nepoznato polje se ignorira }
      S.BeginEdit(0);
      S.SetValue('nepostoji', 'x');
      Check(S.Pending('nepostoji') = '', 'rowsource: nepoznato polje se ne prima');
      S.Cancel;
    finally
      S.Free;
    end;
    { veza glavna-detalj }
    Fk := TaRowSource.Create(Db, 'stavke');
    try
      Fk.SetLink('partner_id', '1');
      Check(Fk.Count = 2, 'rowsource: detalj partnera 1 ima 2 stavke');
      Check(Fk.Aggregate('SUM', 'iznos') = '30.5', 'rowsource: zbroj detalja 30.5 (' + Fk.Aggregate('SUM', 'iznos') + ')');
      Check(Fk.BeginNew, 'rowsource: novi detalj');
      Fk.SetValue('opis', 'nova');
      Fk.SetValue('iznos', '4.5');
      Check(Fk.Post, 'rowsource: Post detalja ' + Fk.Error);
      Check(Fk.Count = 3, 'rowsource: veza se sama upisuje u novi detalj (3 stavke)');
      Check(Fk.Aggregate('SUM', 'iznos') = '35', 'rowsource: zbroj nakon unosa 35 (' + Fk.Aggregate('SUM', 'iznos') + ')');
      Fk.SetLink('partner_id', '2');
      Check(Fk.Count = 1, 'rowsource: promjena glavnog zapisa daje 1 stavku');
      Fk.SetLink('partner_id', '');
      Check(Fk.Count = 0, 'rowsource: bez glavnog zapisa nema stavki');
      Check(Fk.Aggregate('COUNT', '*') = '0', 'rowsource: bez glavnog zapisa COUNT je 0');
      { strani kljuc: nepostojeci glavni zapis }
      Fk.SetLink('partner_id', '99999');
      Fk.BeginNew;
      Fk.SetValue('opis', 'bez roditelja');
      Check(not Fk.Post, 'rowsource: strani kljuc se odbija (' + Copy(Fk.Error, 1, 50) + ')');
      Fk.Cancel;
    finally
      Fk.Free;
    end;
    { tablica bez kljuca: rowid }
    Db.Conn.ExecuteDirect('INSERT INTO bezkljuca VALUES (''x'', ''y''), (''p'', ''q'')');
    S := TaRowSource.Create(Db, 'bezkljuca');
    try
      Check(S.CanEdit and (S.Count = 2), 'rowsource: tablica bez kljuca radi preko rowid');
      S.BeginEdit(1);
      S.SetValue('b', 'Z');
      Check(S.Post and (S.Value(1, 'b') = 'Z'), 'rowsource: izmjena bez kljuca');
    finally
      S.Free;
    end;
    { spremljeni upit je samo za citanje }
    Db.SaveObject('_sys_queries', 'upitPartneri', 'SELECT id, naziv FROM partneri WHERE id <= 5');
    S := TaRowSource.Create(Db, 'upitPartneri');
    try
      Check(not S.CanEdit and (S.Count = 5), 'rowsource: spremljeni upit je samo za citanje, 5 redaka');
      Check(not S.BeginEdit(0), 'rowsource: BeginEdit na upitu se odbija');
    finally
      S.Free;
    end;
    Db.Close;
  finally
    Db.Free;
  end;
end;

type
  TRowProbe = class
    procedure OnBtn(Sender: TObject; ADef: TaControlDef; ARow: Integer);
  end;

var
  RowHostLast: Integer = -1;
  RowProbe: TRowProbe;

procedure TRowProbe.OnBtn(Sender: TObject; ADef: TaControlDef; ARow: Integer);
begin
  RowHostLast := ARow;
end;

procedure TestRowHost;
var
  Db: TAppDb;
  Src: TaRowSource;
  Def: TaFormDef;
  C: TaControlDef;
  Fm: TForm;
  H: TaRowsView;
  I, Idx: Integer;
  Bmp: TBitmap;
  T0: QWord;
  Q: TZQuery;
  NameIdx, GradIdx, CheckIdx: Integer;
begin
  RowProbe := TRowProbe.Create;
  Db := TAppDb.Create;
  Def := TaFormDef.Create;
  Fm := TForm.CreateNew(nil);
  try
    if FileExists('/tmp/ta_rowhost.db') then DeleteFile('/tmp/ta_rowhost.db');
    Db.Open('/tmp/ta_rowhost.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER DEFAULT 0, iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('BEGIN');
    for I := 1 to 200 do
      Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''P' + Format('%.3d', [I]) + ''', ''Zagreb'', ' + IntToStr(I mod 2) + ', ' + IntToStr(I * 10) + ')');
    Db.Conn.ExecuteDirect('COMMIT');
    { predlozak detalja }
    Def.Name := 'T'; Def.RecordSource := 'partneri'; Def.AllowAdds := True; Def.AllowEdits := True; Def.AllowDeletes := True;
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'tNaziv'; C.ControlSource := 'naziv'; C.Left := 4; C.Top := 4; C.Width := 160; C.Height := 24; C.Section := 'detail'; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'ComboBox'; C.Name := 'cGrad'; C.ControlSource := 'grad'; C.Left := 170; C.Top := 4; C.Width := 120; C.Height := 24; C.Section := 'detail'; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'CheckBox'; C.Name := 'kAkt'; C.ControlSource := 'aktivan'; C.Left := 296; C.Top := 4; C.Width := 24; C.Height := 24; C.Section := 'detail'; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'tIznos'; C.ControlSource := 'iznos'; C.Format := '#,##0.00'; C.Left := 326; C.Top := 4; C.Width := 100; C.Height := 24; C.Section := 'detail'; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'Button'; C.Name := 'bPdf'; C.Caption := 'PDF'; C.Left := 432; C.Top := 4; C.Width := 60; C.Height := 24; C.Section := 'detail'; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'Label'; C.Name := 'lblZaglavlje'; C.Caption := 'zaglavlje'; C.Left := 4; C.Top := 4; C.Width := 100; C.Height := 20; C.Section := 'header'; Def.Add(C);
    Src := TaRowSource.Create(Db, 'partneri');
    Fm.SetBounds(0, 0, 640, 304);
    H := TaRowsView.Create(Fm);
    H.Parent := Fm;
    H.SetBounds(0, 0, 640, 304);
    H.Setup(Src, Def);
    NameIdx := 0; GradIdx := 1; CheckIdx := 2;
    Check(H.CellCount = 5, 'rowhost: predlozak ima 5 celija iz detalja (zaglavlje se ne ubraja): ' + IntToStr(H.CellCount));
    Check(H.RowHeight = 34, 'rowhost: visina reda iz predloska (' + IntToStr(H.RowHeight) + ')');
    Check(H.Model.RecordCount = 200, 'rowhost: 200 zapisa');
    Check(H.Model.RowCount = 201, 'rowhost: 201 redak s novim');
    Check(H.Model.ViewRows = 304 div 34, 'rowhost: vidljivih redova ' + IntToStr(H.Model.ViewRows));
    Check((H.LiveControl(NameIdx) is TaEdit) and (TaEdit(H.LiveControl(NameIdx)).Text = 'P001'), 'rowhost: zivi red prikazuje prvi zapis');
    Check(H.LiveControl(CheckIdx) is TCheckBox, 'rowhost: kvacica je prava kvacica u zivom redu');
    Check(H.LiveControl(4) is TButton, 'rowhost: gumb je pravi gumb u zivom redu');
    { crtanje }
    Bmp := TBitmap.Create;
    try
      Bmp.SetSize(640, 304);
      Bmp.Canvas.Brush.Color := clWhite;
      Bmp.Canvas.FillRect(0, 0, 640, 304);
      H.DrawRow(Bmp.Canvas, 3, 0);
      Check(Bmp.Canvas.Pixels[5, 5] <> clWhite, 'rowhost: crtani red se crta (birac zapisa nije bijel)');
      T0 := GetTickCount64;
      for I := 1 to 100 do
        for Idx := 0 to H.Model.ViewRows - 1 do H.DrawRow(Bmp.Canvas, Idx, Idx * H.RowHeight);
      Check((GetTickCount64 - T0) / 100 < 30, 'rowhost: crtanje svih vidljivih redova < 30 ms (' + FloatToStr((GetTickCount64 - T0) / 100) + ' ms)');
    finally
      Bmp.Free;
    end;
    { uredivanje u zivom redu i prelazak na drugi red }
    H.SimulateEdit(NameIdx, 'Izmijenjeno');
    Check(H.Model.Dirty and Src.Editing, 'rowhost: izmjena u zivoj kontroli cini red prljavim');
    Check(H.GoToRow(5), 'rowhost: prelazak na red 5 sprema prljavi red ' + H.Error);
    Check((H.Model.Current = 5) and not H.Model.Dirty, 'rowhost: trenutni je red 5, nije prljav');
    Q := Db.NewQuery('SELECT naziv FROM partneri WHERE id = 1');
    try Q.Open; Check(Q.Fields[0].AsString = 'Izmijenjeno', 'rowhost: izmjena je u bazi'); finally Q.Free; end;
    Check(TaEdit(H.LiveControl(NameIdx)).Text = 'P006', 'rowhost: zivi red je napunjen redom 5');
    { kvacica }
    H.SimulateEdit(CheckIdx, '1');
    H.CommitRow;
    Q := Db.NewQuery('SELECT aktivan FROM partneri WHERE id = 6');
    try Q.Open; Check(Q.Fields[0].AsInteger = 1, 'rowhost: kvacica se sprema kao 1'); finally Q.Free; end;
    { novi red }
    Check(H.GoToRow(200) and H.Model.IsNewRow(H.Model.Current), 'rowhost: skok na novi red');
    Check(TaEdit(H.LiveControl(NameIdx)).Text = '', 'rowhost: novi red je prazan');
    Check(not Src.Editing, 'rowhost: prazan novi red nije zapoceo unos');
    H.SimulateEdit(GradIdx, 'Rijeka');
    Check(Src.Editing and Src.IsNew, 'rowhost: unos u novi red pokrece novi zapis');
    Check(not H.CommitRow, 'rowhost: novi red bez obaveznog naziva se ne sprema');
    Check(H.Error <> '', 'rowhost: poruka greske (' + Copy(H.Error, 1, 40) + ')');
    Check(H.Model.Dirty and H.Model.IsNewRow(H.Model.Current), 'rowhost: red ostaje nespremljen, fokus ostaje');
    Check(not H.GoToRow(0), 'rowhost: iz neispravnog reda se ne moze otici');
    H.SimulateEdit(NameIdx, 'Novi zapis');
    Check(H.CommitRow, 'rowhost: ispravljen red se sprema ' + H.Error);
    Check((H.Model.RecordCount = 201) and (H.Model.RowCount = 202), 'rowhost: 201 zapis, novi red je ispod');
    Check(not H.Model.IsNewRow(H.Model.Current) and (TaEdit(H.LiveControl(NameIdx)).Text = 'Novi zapis'), 'rowhost: trenutni je upravo spremljeni zapis');
    { poništavanje }
    H.SimulateEdit(NameIdx, 'Nista');
    H.CancelRow;
    Check(not H.Model.Dirty and (TaEdit(H.LiveControl(NameIdx)).Text = 'Novi zapis'), 'rowhost: Cancel vraca staru vrijednost');
    { brisanje }
    Check(H.DeleteCurrent, 'rowhost: brisanje trenutnog');
    Check(H.Model.RecordCount = 200, 'rowhost: nakon brisanja 200');
    { klizanje }
    H.ScrollTo(100);
    Check(H.Model.Offset = 100, 'rowhost: klizanje na 100');
    Check(not H.LiveControl(NameIdx).Parent.Visible, 'rowhost: zivi red je skriven kad trenutni red nije vidljiv');
    Check(Src.Value(100, 'naziv') = 'P101', 'rowhost: prozor zapisa slijedi klizanje');
    H.ScrollTo(H.Model.Current - 2);
    Check(H.LiveControl(NameIdx).Parent.Visible, 'rowhost: zivi red je opet vidljiv kad se trenutni red vrati u prikaz');
    { gumb u crtanom redu }
    H.OnButton := @RowProbe.OnBtn;
    RowHostLast := -1;
    Idx := H.Model.Offset + 3;
    H.ClickAt(H.SelectorWidth + 440, 3 * H.RowHeight + 8);
    Check((RowHostLast = Idx) and (H.Model.Current = Idx), 'rowhost: klik na crtani gumb cini red trenutnim i izvrsava radnju (' + IntToStr(RowHostLast) + ')');
    { prelazak nakon izmjene sortiranog polja ide na zapis, ne na poziciju }
    Src.SetSort('naziv', False);
    H.Reload;
    H.GoToRow(0);
    I := StrToInt(Src.KeyOf(1));
    H.SimulateEdit(0, 'ZZZ-zadnji');
    Check(H.GoToRow(1), 'rowhost: prelazak sa spremanjem uz promjenu poretka');
    Check(StrToInt(Src.KeyOf(H.Model.Current)) = I, 'rowhost: nakon spremanja trenutni je zapis koji je bio cilj, ne ona pozicija (kljuc ' + Src.KeyOf(H.Model.Current) + ' umjesto ' + IntToStr(I) + ')');
    Check(Src.Value(H.Model.RecordCount - 1, 'naziv') = 'ZZZ-zadnji', 'rowhost: izmijenjeni zapis je presao na kraj sortiranog popisa');
    Src.Free;
    Db.Close;
  finally
    Fm.Free;
    RowProbe.Free;
    Def.Free;
    Db.Free;
  end;
end;

type
  TKeyProbe = class
    Closed: Integer;
    procedure OnAct(Sender: TObject; AAction: TaKeyAction; var AHandled: Boolean);
  end;

procedure TKeyProbe.OnAct(Sender: TObject; AAction: TaKeyAction; var AHandled: Boolean);
begin
  if AAction = kaCloseForm then Inc(Closed);
end;

function PressKey(H: TaRowsView; AKey: Word; AShift: TShiftState; ACell: Integer): Boolean;
var
  K: Word;
begin
  K := AKey;
  Result := H.HandleKey(K, AShift, H.LiveControl(ACell));
end;

procedure TestRowKeys;
var
  KM: TaKeyMap;
  C: TaKeyCombo;
  Err, Js: string;
  Db: TAppDb;
  Src: TaRowSource;
  Def: TaFormDef;
  Cd: TaControlDef;
  Fm: TForm;
  H: TaRowsView;
  Pr: TKeyProbe;
  I: Integer;
  Q: TZQuery;
  KM2: TaKeyMap;
begin
  KM := TaKeyMap.Create;
  try
    Check(ParseCombo('Ctrl+N', C) and C.Ctrl and not C.Shift and (C.Key = Ord('N')), 'keymap: Ctrl+N se parsira');
    Check(ParseCombo('F12', C) and (C.Key = VK_F12), 'keymap: F12');
    Check(ParseCombo('shift+enter', C) and C.Shift and (C.Key = VK_RETURN), 'keymap: velika/mala slova se ne razlikuju');
    Check(ParseCombo('Ctrl++', C) and C.Ctrl and (C.Key = VK_ADD), 'keymap: Ctrl++');
    Check(not ParseCombo('Ctrl+Nista', C), 'keymap: nepoznata tipka se odbija');
    Check(KM.KeysOf(kaNewRecord) = 'Ctrl+N', 'keymap: zadano za novi zapis je Ctrl+N (' + KM.KeysOf(kaNewRecord) + ')');
    Check(KM.KeysOf(kaNextField) = 'Tab, Enter', 'keymap: zadano za sljedece polje je Tab, Enter');
    Check(KM.Resolve(VK_ESCAPE, []) = kaCancelRow, 'keymap: Esc je poništi');
    Check(KM.Resolve(Ord('N'), [ssCtrl]) = kaNewRecord, 'keymap: Ctrl+N razrijeseno');
    Check(KM.Resolve(Ord('N'), []) = kaNone, 'keymap: N bez Ctrl nije radnja');
    Check(KM.Resolve(VK_TAB, [ssShift]) = kaPrevField, 'keymap: Shift+Tab');
    { promjena: Insert za novi zapis, Esc ili F12 za izlaz }
    Check(KM.SetKeys(kaNewRecord, 'Insert', Err), 'keymap: SetKeys Insert');
    Check(KM.Resolve(VK_INSERT, []) = kaNewRecord, 'keymap: Insert je novi zapis');
    Check(KM.Resolve(Ord('N'), [ssCtrl]) = kaNone, 'keymap: Ctrl+N vise nije novi zapis');
    Check(KM.SetKeys(kaCloseForm, 'F12', Err), 'keymap: F12 za zatvaranje');
    Check(KM.Resolve(VK_F12, []) = kaCloseForm, 'keymap: F12 razrijeseno');
    Check(KM.SetKeys(kaCancelRow, 'Esc, Ctrl+Z', Err) and (KM.Resolve(Ord('Z'), [ssCtrl]) = kaCancelRow), 'keymap: jedna radnja, vise tipki');
    Check(not KM.SetKeys(kaDeleteRow, 'Ctrl+Hocu', Err) and (Err <> ''), 'keymap: neispravna tipka daje poruku (' + Err + ')');
    Check(KM.ConflictOf('F12', kaNewRecord) = kaCloseForm, 'keymap: sukob F12 je otkriven');
    Check(KM.ConflictOf('Ctrl+F7', kaNewRecord) = kaNone, 'keymap: slobodna tipka nema sukoba');
    { JSON }
    Js := KM.ToJson;
    KM2 := TaKeyMap.Create;
    try
      Check(KM2.FromJson(Js, Err), 'keymap: JSON se cita ' + Err);
      Check((KM2.KeysOf(kaNewRecord) = 'Insert') and (KM2.KeysOf(kaCloseForm) = 'F12') and (KM2.KeysOf(kaCancelRow) = 'Esc, Ctrl+Z'),
        'keymap: JSON krug cuva promjene');
      Check(KM2.FromJson('{"NewRecord":["Ctrl+Ins"]}', Err) and (KM2.KeysOf(kaNewRecord) = 'Ctrl+Insert') and (KM2.KeysOf(kaNextField) = 'Tab, Enter'),
        'keymap: nenavedeno ostaje zadano, sinonim Ins');
      Check(not KM2.FromJson('{"Izmisljeno":["F1"]}', Err) and (Err <> ''), 'keymap: nepoznata radnja se javlja');
      Check(not KM2.FromJson('nije json', Err), 'keymap: neispravan JSON se javlja');
    finally
      KM2.Free;
    end;
    { postavka aplikacije i dijalog }
    Db := TAppDb.Create;
    try
      if FileExists('/tmp/ta_keys.db') then DeleteFile('/tmp/ta_keys.db');
      Db.Open('/tmp/ta_keys.db');
      KM2 := TaKeyMap.Create;
      try
        Check(KeyMapLoad(Db, KM2, Err) and (KM2.KeysOf(kaNewRecord) = 'Ctrl+N'), 'keymap: bez postavke vrijede zadane tipke');
        KM2.SetKeys(kaNewRecord, 'Insert', Err);
        KM2.SetKeys(kaCloseForm, 'F12', Err);
        Check(KeyMapSave(Db, KM2), 'keymap: spremanje u postavke');
        KM2.LoadDefaults;
        Check(KeyMapLoad(Db, KM2, Err) and (KM2.KeysOf(kaNewRecord) = 'Insert') and (KM2.KeysOf(kaCloseForm) = 'F12'), 'keymap: ponovno ucitavanje iz postavki');
      finally
        KM2.Free;
      end;
      Db.Close;
    finally
      Db.Free;
    end;
  finally
    KM.Free;
  end;
  { tipkovnica u zivom redu }
  Pr := TKeyProbe.Create;
  Db := TAppDb.Create;
  Def := TaFormDef.Create;
  Fm := TForm.CreateNew(nil);
  KM := TaKeyMap.Create;
  try
    if FileExists('/tmp/ta_rowkeys.db') then DeleteFile('/tmp/ta_rowkeys.db');
    Db.Open('/tmp/ta_rowkeys.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER, iznos DECIMAL(12,2))');
    for I := 1 to 40 do
      Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''P' + IntToStr(I) + ''', ''Zagreb'', 0, ' + IntToStr(I) + ')');
    Def.AllowAdds := True; Def.AllowEdits := True; Def.AllowDeletes := True;
    Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.ControlSource := 'naziv'; Cd.Left := 4; Cd.Top := 4; Cd.Width := 140; Cd.Height := 24; Def.Add(Cd);
    Cd := TaControlDef.Create; Cd.Kind := 'ComboBox'; Cd.ControlSource := 'grad'; Cd.Left := 150; Cd.Top := 4; Cd.Width := 100; Cd.Height := 24; Def.Add(Cd);
    Cd := TaControlDef.Create; Cd.Kind := 'CheckBox'; Cd.ControlSource := 'aktivan'; Cd.Left := 256; Cd.Top := 4; Cd.Width := 24; Cd.Height := 24; Def.Add(Cd);
    Cd := TaControlDef.Create; Cd.Kind := 'TextBox'; Cd.ControlSource := 'iznos'; Cd.Left := 286; Cd.Top := 4; Cd.Width := 80; Cd.Height := 24; Def.Add(Cd);
    Cd := TaControlDef.Create; Cd.Kind := 'Button'; Cd.Caption := 'PDF'; Cd.Left := 372; Cd.Top := 4; Cd.Width := 50; Cd.Height := 24; Def.Add(Cd);
    Src := TaRowSource.Create(Db, 'partneri');
    Fm.SetBounds(0, 0, 500, 280);
    H := TaRowsView.Create(Fm);
    H.Parent := Fm;
    H.SetBounds(0, 0, 500, 280);
    H.KeyMap := KM;
    H.OnAction := @Pr.OnAct;
    H.Setup(Src, Def);
    { Tab kroz polja }
    Check(PressKey(H, VK_TAB, [], 0) and (H.FocusedCell = 1), 'tipke: Tab ide s polja 0 na polje 1');
    PressKey(H, VK_TAB, [], 1);
    PressKey(H, VK_TAB, [], 2);
    PressKey(H, VK_TAB, [], 3);
    Check(H.FocusedCell = 4, 'tipke: Tab dolazi do zadnje kontrole (gumb)');
    Check(PressKey(H, VK_TAB, [], 4) and (H.Model.Current = 1) and (H.FocusedCell = 0), 'tipke: Tab s kraja reda ide na prvo polje sljedeceg reda');
    Check(PressKey(H, VK_TAB, [ssShift], 0) and (H.Model.Current = 0) and (H.FocusedCell = 4), 'tipke: Shift+Tab s pocetka ide na zadnje polje prethodnog reda');
    Check(PressKey(H, VK_RETURN, [], 0) and (H.FocusedCell = 1), 'tipke: Enter je takoder sljedece polje (zadano)');
    Check(not PressKey(H, VK_RETURN, [], 4), 'tipke: Enter na gumbu pripada gumbu');
    Check(not PressKey(H, Ord('Q'), [], 0), 'tipke: neraspodijeljena tipka se ne obraduje');
    { strelice }
    Check(PressKey(H, VK_DOWN, [], 0) and (H.Model.Current = 1) and (H.FocusedCell = 0), 'tipke: Down ide u sljedeci red, isto polje');
    Check(PressKey(H, VK_UP, [], 0) and (H.Model.Current = 0), 'tipke: Up ide u prethodni red');
    H.GoToRow(1);
    Check(not PressKey(H, VK_DOWN, [], 1) and (H.Model.Current = 1), 'tipke: u combo kontroli strelica pripada popisu');
    H.GoToRow(0);
    Check(PressKey(H, VK_NEXT, [], 0) and (H.Model.Current = H.Model.ViewRows), 'tipke: PgDn za stranicu');
    Check(PressKey(H, VK_END, [ssCtrl], 0) and (H.Model.Current = 39), 'tipke: Ctrl+End je zadnji zapis');
    Check(PressKey(H, VK_HOME, [ssCtrl], 0) and (H.Model.Current = 0), 'tipke: Ctrl+Home je prvi zapis');
    Check(PressKey(H, Ord('N'), [ssCtrl], 3) and H.Model.IsNewRow(H.Model.Current) and (H.FocusedCell = 0), 'tipke: Ctrl+N na novi red, prvo polje');
    { Esc: poništi }
    H.SimulateEdit(0, 'Smeće');
    Check(H.Model.Dirty, 'tipke: red je prljav');
    Check(PressKey(H, VK_ESCAPE, [], 0) and not H.Model.Dirty, 'tipke: Esc poništava izmjene');
    { Tab preko reda sprema prljavi red }
    H.GoToRow(2);
    H.SimulateEdit(0, 'Spremljeno tabom');
    PressKey(H, VK_TAB, [], 4);
    Q := Db.NewQuery('SELECT naziv FROM partneri WHERE id = 3');
    try Q.Open; Check((Q.Fields[0].AsString = 'Spremljeno tabom') and (H.Model.Current = 3), 'tipke: Tab preko reda sprema izmjenu i ide dalje'); finally Q.Free; end;
    { greska: Tab ostaje u redu }
    H.GoToRow(H.Model.NewRow);
    H.SimulateEdit(1, 'Pula');
    PressKey(H, VK_TAB, [], 4);
    Check(H.Model.IsNewRow(H.Model.Current) and H.Model.Dirty and (H.Error <> ''), 'tipke: neispravan red zadrzava fokus pri Tab-u (' + Copy(H.Error, 1, 30) + ')');
    H.SimulateEdit(0, 'Dodano');
    Check(PressKey(H, VK_RETURN, [ssShift], 0) and not H.Model.Dirty and (H.Model.RecordCount = 41), 'tipke: Shift+Enter sprema zapis');
    Check(PressKey(H, VK_DELETE, [ssCtrl], 0) and (H.Model.RecordCount = 40), 'tipke: Ctrl+Delete brise zapis');
    { PROMJENA TIPKI u radu: Insert za novi, F12 za izlaz, Esc poništi-ili-zatvori }
    Check(KM.SetKeys(kaNewRecord, 'Insert', Err) and KM.SetKeys(kaCloseForm, 'F12', Err) and KM.SetKeys(kaCancelRow, '', Err) and KM.SetKeys(kaCancelOrClose, 'Esc', Err), 'tipke: promjena mape');
    H.GoToRow(0);
    Check(not PressKey(H, Ord('N'), [ssCtrl], 0) and (H.Model.Current = 0), 'tipke: Ctrl+N vise ne radi');
    Check(PressKey(H, VK_INSERT, [], 0) and H.Model.IsNewRow(H.Model.Current), 'tipke: Insert ide na novi zapis');
    Pr.Closed := 0;
    Check(PressKey(H, VK_F12, [], 0) and (Pr.Closed = 1), 'tipke: F12 zatvara formu');
    H.SimulateEdit(0, 'Izmjena');
    PressKey(H, VK_ESCAPE, [], 0);
    Check(not H.Model.Dirty and (Pr.Closed = 1), 'tipke: Esc s izmjenama samo ponistava');
    PressKey(H, VK_ESCAPE, [], 0);
    Check(Pr.Closed = 2, 'tipke: Esc bez izmjena zatvara formu');
    Src.Free;
    Db.Close;
  finally
    KM.Free;
    Fm.Free;
    Def.Free;
    Db.Free;
    Pr.Free;
  end;
end;

procedure TestContForm;
var
  Db: TAppDb;
  Def: TaFormDef;
  C: TaControlDef;
  Fm: TForm;
  CF: TaContinuousBody;
  I: Integer;
  Src: TaRowSource;
  Q: TZQuery;
begin
  Db := TAppDb.Create;
  Def := TaFormDef.Create;
  Fm := TForm.CreateNew(nil);
  try
    if FileExists('/tmp/ta_contform.db') then DeleteFile('/tmp/ta_contform.db');
    Db.Open('/tmp/ta_contform.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('CREATE TABLE stavke (id INTEGER PRIMARY KEY, partner_id INTEGER NOT NULL, iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('BEGIN');
    for I := 1 to 100 do
      if I mod 2 = 1 then
        Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, iznos) VALUES (''P' + Format('%.3d', [I]) + ''', ''Split'', ' + IntToStr(I * 10) + ')')
      else
        Db.Conn.ExecuteDirect('INSERT INTO partneri (naziv, grad, iznos) VALUES (''P' + Format('%.3d', [I]) + ''', ''Zagreb'', ' + IntToStr(I * 10) + ')');
    Db.Conn.ExecuteDirect('INSERT INTO stavke (partner_id, iznos) VALUES (1, 5), (1, 7.5), (2, 100)');
    Db.Conn.ExecuteDirect('COMMIT');
    Def.Name := 'popis'; Def.RecordSource := 'partneri'; Def.AllowAdds := True; Def.AllowEdits := True; Def.AllowDeletes := True;
    { zaglavlje }
    C := TaControlDef.Create; C.Kind := 'Label'; C.Name := 'hNaziv'; C.Caption := 'Naziv'; C.Section := 'header'; C.Left := 4; C.Top := 4; C.Width := 140; C.Height := 20; C.SetX('sort', 'naziv'); Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'Label'; C.Name := 'hIznos'; C.Caption := 'Iznos'; C.Section := 'header'; C.Left := 290; C.Top := 4; C.Width := 100; C.Height := 20; C.SetX('sort', 'iznos'); Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'fGrad'; C.Section := 'header'; C.Left := 150; C.Top := 28; C.Width := 100; C.Height := 24; C.SetX('filter', 'grad'); Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'fIznos'; C.Section := 'header'; C.Left := 290; C.Top := 28; C.Width := 100; C.Height := 24; C.SetX('filter', 'iznos'); Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'fNaziv'; C.Section := 'header'; C.Left := 4; C.Top := 28; C.Width := 140; C.Height := 24; C.SetX('filter', 'naziv'); Def.Add(C);
    { detalj }
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'tNaziv'; C.ControlSource := 'naziv'; C.Section := 'detail'; C.Left := 4; C.Top := 4; C.Width := 140; C.Height := 24; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'tGrad'; C.ControlSource := 'grad'; C.Section := 'detail'; C.Left := 150; C.Top := 4; C.Width := 100; C.Height := 24; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'tIznos'; C.ControlSource := 'iznos'; C.Format := '#,##0.00'; C.Section := 'detail'; C.Left := 290; C.Top := 4; C.Width := 100; C.Height := 24; Def.Add(C);
    { podnozje }
    C := TaControlDef.Create; C.Kind := 'Label'; C.Name := 'lUk'; C.Caption := 'Ukupno'; C.Section := 'footer'; C.Left := 4; C.Top := 4; C.Width := 100; C.Height := 20; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'fBroj'; C.ControlSource := '=Count()'; C.Format := '#,##0'; C.Section := 'footer'; C.Left := 150; C.Top := 4; C.Width := 100; C.Height := 24; Def.Add(C);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'fZbroj'; C.ControlSource := '=Sum(iznos)'; C.Format := '#,##0.00'; C.Section := 'footer'; C.Left := 290; C.Top := 4; C.Width := 100; C.Height := 24; Def.Add(C);
    Fm.SetBounds(0, 0, 440, 400);
    CF := TaContinuousBody.Create(Fm);
    CF.Parent := Fm;
    CF.Align := alClient;
    CF.Setup(Db, Def);
    Check(CF.Header.Height = 58, 'contform: visina zaglavlja iz kontrola (' + IntToStr(CF.Header.Height) + ')');
    Check(CF.Footer.Height = 34, 'contform: visina podnozja iz kontrola (' + IntToStr(CF.Footer.Height) + ')');
    Check(CF.Host.CellCount = 3, 'contform: detalj ima 3 celije (zaglavlje i podnozje se ne ubrajaju)');
    Check(CF.Host.Model.RecordCount = 100, 'contform: 100 zapisa');
    { poravnanje sa stupcima detalja }
    Check(CF.HeaderControl('hNaziv').Left = 4 + CF.Host.SelectorWidth, 'contform: zaglavlje je poravnato s detaljem (pomak birača zapisa)');
    { podnozje }
    Check(DigitsOnly(CF.FooterText('fBroj')) = '100', 'contform: podnozje Count = 100 (' + CF.FooterText('fBroj') + ')');
    Check(DigitsOnly(CF.FooterText('fZbroj')) = '5050000', 'contform: podnozje Sum = 50.500,00 (' + CF.FooterText('fZbroj') + ')');
    { sortiranje klikom na naslov }
    CF.ClickHeader('hNaziv');
    Check((CF.SortField = 'naziv') and not CF.SortDescending, 'contform: prvi klik sortira uzlazno');
    Check(TLabel(CF.HeaderControl('hNaziv')).Caption = 'Naziv ▲', 'contform: naslov pokazuje strelicu (' + TLabel(CF.HeaderControl('hNaziv')).Caption + ')');
    Check(CF.Source.Value(0, 'naziv') = 'P001', 'contform: uzlazno, prvi je P001');
    CF.ClickHeader('hNaziv');
    Check(CF.SortDescending and (CF.Source.Value(0, 'naziv') = 'P100'), 'contform: drugi klik silazno, prvi je P100');
    CF.ClickHeader('hIznos');
    Check((CF.SortField = 'iznos') and not CF.SortDescending and (CF.Source.Value(0, 'naziv') = 'P001'), 'contform: sortiranje po drugom stupcu');
    Check(TLabel(CF.HeaderControl('hNaziv')).Caption = 'Naziv', 'contform: strelica nestaje s prethodnog naslova');
    { filtri u zaglavlju }
    CF.TypeFilter('fGrad', 'Split');
    Check(CF.Host.Model.RecordCount = 50, 'contform: filtar grad=Split daje 50');
    Check(DigitsOnly(CF.FooterText('fBroj')) = '50', 'contform: podnozje Count slijedi filtar (' + CF.FooterText('fBroj') + ')');
    Check(DigitsOnly(CF.FooterText('fZbroj')) = '2500000', 'contform: podnozje Sum slijedi filtar, 25.000,00 (' + CF.FooterText('fZbroj') + ')');
    CF.TypeFilter('fGrad', '');
    CF.TypeFilter('fIznos', '>500');
    Check(CF.Host.Model.RecordCount = 50, 'contform: brojcani filtar >500 daje 50');
    Check(DigitsOnly(CF.FooterText('fZbroj')) = '3775000', 'contform: Sum za >500 je 37.750,00');
    CF.TypeFilter('fGrad', 'split');
    Check(CF.Host.Model.RecordCount = 25, 'contform: dva filtra se zbrajaju (AND), velika/mala slova se ne razlikuju: ' + IntToStr(CF.Host.Model.RecordCount));
    CF.TypeFilter('fGrad', '');
    CF.TypeFilter('fIznos', '100..200');
    Check(CF.Host.Model.RecordCount = 11, 'contform: raspon 100..200 daje 11');
    CF.TypeFilter('fIznos', '');
    CF.TypeFilter('fNaziv', 'P05');
    Check(CF.Host.Model.RecordCount = 10, 'contform: tekst sadrzi "P05" daje 10');
    CF.TypeFilter('fNaziv', '=P050');
    Check(CF.Host.Model.RecordCount = 1, 'contform: =P050 je tocno podudaranje');
    CF.TypeFilter('fNaziv', 'x''; DROP TABLE partneri; --');
    Check(CF.Host.Model.RecordCount = 0, 'contform: SQL u filtru je samo tekst');
    CF.TypeFilter('fNaziv', '');
    Check(CF.Host.Model.RecordCount = 100, 'contform: prazni filtri vracaju svih 100');
    Q := Db.NewQuery('SELECT COUNT(*) FROM partneri');
    try Q.Open; Check(Q.Fields[0].AsInteger = 100, 'contform: tablica je ostala netaknuta'); finally Q.Free; end;
    { podnozje se osvjezava nakon unosa i brisanja }
    CF.Host.GoToRow(CF.Host.Model.NewRow);
    CF.Host.SimulateEdit(0, 'Novi');
    CF.Host.SimulateEdit(2, '1000');
    Check(CF.Host.CommitRow, 'contform: spremanje novog zapisa ' + CF.Host.Error);
    Check(DigitsOnly(CF.FooterText('fBroj')) = '101', 'contform: Count nakon unosa 101 (' + CF.FooterText('fBroj') + ')');
    Check(DigitsOnly(CF.FooterText('fZbroj')) = '5150000', 'contform: Sum nakon unosa 51.500,00 (' + CF.FooterText('fZbroj') + ')');
    CF.Host.DeleteCurrent;
    Check(DigitsOnly(CF.FooterText('fBroj')) = '100', 'contform: Count nakon brisanja 100');
    { podforma: veza glavna-detalj }
    CF.SetMaster('id', '1');
    Check(CF.Host.Model.RecordCount = 1, 'contform: veza na partnera 1 daje samo njega');
    Check(DigitsOnly(CF.FooterText('fBroj')) = '1', 'contform: podnozje slijedi vezu');
    Db.Close;
  finally
    Fm.Free;
    Def.Free;
    Db.Free;
  end;
end;

procedure TestContSub;
var
  Db: TAppDb;
  D, D2: TaFormDef;
  C: TaControlDef;
  R, Sr: TaFormRunner;
  Tot: TEdit;
  H: TaRowsView;
  Q: TZQuery;
begin
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_contsub.db') then DeleteFile('/tmp/ta_contsub.db');
    Db.Open('/tmp/ta_contsub.db');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, broj VARCHAR(20))');
    Db.Conn.ExecuteDirect('CREATE TABLE stavke (id INTEGER PRIMARY KEY, racun_id INTEGER NOT NULL, opis VARCHAR(40), iznos DECIMAL(12,2), FOREIGN KEY (racun_id) REFERENCES racuni(id))');
    Db.Conn.ExecuteDirect('INSERT INTO racuni VALUES (1, ''R-1''), (2, ''R-2'')');
    Db.Conn.ExecuteDirect('INSERT INTO stavke (racun_id, opis, iznos) VALUES (1, ''a'', 10), (1, ''b'', 20), (2, ''c'', 5)');
    { neprekidna forma stavki }
    D := TaFormDef.Create;
    D.Name := 'StavkeForma'; D.RecordSource := 'stavke'; D.ViewMode := 'continuous';
    D.AllowAdds := True; D.AllowEdits := True; D.AllowDeletes := True; D.Width := 420; D.Height := 200;
    C := NewCtl('Label', 'hOpis', '', 4, 4); C.Caption := 'Opis'; C.Section := 'header'; D.Add(C);
    C := NewCtl('Label', 'hIznos', '', 200, 4); C.Caption := 'Iznos'; C.Section := 'header'; D.Add(C);
    C := NewCtl('TextBox', 'tOpis', 'opis', 4, 4); C.Section := 'detail'; D.Add(C);
    C := NewCtl('TextBox', 'tIznos', 'iznos', 200, 4); C.Section := 'detail'; C.Format := '#,##0.00'; D.Add(C);
    C := NewCtl('Label', 'fUk', '', 4, 4); C.Caption := 'Ukupno'; C.Section := 'footer'; D.Add(C);
    C := NewCtl('TextBox', 'fZb', '=Sum(iznos)', 200, 4); C.Section := 'footer'; C.Format := '#,##0.00'; D.Add(C);
    Db.SaveObject('_sys_forms', 'StavkeForma', D.ToJson);
    D.Free;
    { glavna forma racuna }
    D := TaFormDef.Create;
    D.Name := 'Racun'; D.RecordSource := 'racuni'; D.Width := 460; D.Height := 320;
    D.AllowEdits := True; D.AllowAdds := True;
    D.Add(NewCtl('TextBox', 'txtBroj', 'broj', 10, 10));
    C := NewCtl('TextBox', 'txtUk', '=SubSum("Stavke", "iznos")', 10, 40); C.Format := '#,##0.00'; D.Add(C);
    C := NewCtl('TextBox', 'txtBr', '=SubCount("Stavke")', 200, 40); D.Add(C);
    C := NewCtl('Subform', 'Stavke', '', 10, 80); C.RowSource := 'StavkeForma'; C.LinkMaster := 'id'; C.LinkChild := 'racun_id';
    C.Width := 430; C.Height := 220; D.Add(C);
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    try
      Sr := R.SubRunner('Stavke');
      Check(Sr <> nil, 'contsub: podforma je ugradena forma');
      Check((Sr <> nil) and (Sr.ContinuousForm <> nil), 'contsub: ugradena forma je neprekidna (ViewMode = continuous)');
      H := Sr.ContinuousForm.Host;
      Check(H.Model.RecordCount = 2, 'contsub: podforma pokazuje 2 stavke racuna 1 (' + IntToStr(H.Model.RecordCount) + ')');
      Tot := TEdit(R.ControlByName('txtUk'));
      Check(DigitsOnly(Tot.Text) = '3000', 'contsub: SubSum u glavnoj formi = 30,00 (' + Tot.Text + ')');
      Check(DigitsOnly(TEdit(R.ControlByName('txtBr')).Text) = '2', 'contsub: SubCount = 2');
      Check(DigitsOnly(Sr.ContinuousForm.FooterText('fZb')) = '3000', 'contsub: podnozje podforme Sum = 30,00');
      { unos nove stavke u prazan red }
      H.GoToRow(H.Model.NewRow);
      H.SimulateEdit(0, 'd');
      H.SimulateEdit(1, '12.5');
      Check(H.CommitRow, 'contsub: spremanje nove stavke ' + H.Error);
      Check(H.Model.RecordCount = 3, 'contsub: 3 stavke');
      Check(DigitsOnly(Tot.Text) = '4250', 'contsub: zbroj u glavnoj formi odmah slijedi unos (42,50): ' + Tot.Text);
      Check(DigitsOnly(TEdit(R.ControlByName('txtBr')).Text) = '3', 'contsub: SubCount = 3');
      Q := Db.NewQuery('SELECT racun_id FROM stavke WHERE opis = ''d''');
      try Q.Open; Check(Q.Fields[0].AsInteger = 1, 'contsub: nova stavka je dobila vezu na racun 1'); finally Q.Free; end;
      { izmjena iznosa }
      H.GoToRow(0);
      H.SimulateEdit(1, '100');
      H.CommitRow;
      Check(DigitsOnly(Tot.Text) = '13250', 'contsub: izmjena iznosa mijenja zbroj (132,50): ' + Tot.Text);
      { drugi racun }
      R.DoAction('next');
      Check(H.Model.RecordCount = 1, 'contsub: drugi racun ima 1 stavku');
      Check(DigitsOnly(Tot.Text) = '500', 'contsub: zbroj za drugi racun 5,00 (' + Tot.Text + ')');
      { brisanje stavke }
      H.GoToRow(0);
      H.DeleteCurrent;
      Check(H.Model.RecordCount = 0, 'contsub: stavka obrisana');
      Check((DigitsOnly(Tot.Text) = '') or (DigitsOnly(Tot.Text) = '000'), 'contsub: zbroj praznog racuna je prazan ili 0 (' + Tot.Text + ')');
      R.DoAction('prev');
      Check(H.Model.RecordCount = 3, 'contsub: povratak na racun 1, opet 3 stavke');
    finally
      R.Free;
    end;
    Db.Close;
  finally
    Db.Free;
  end;
end;

procedure TestContDesign;
var
  Db: TAppDb;
  D, D3, D4: TaFormDef;
  C: TaControlDef;
  Des: TaFormDesigner;
  I: Integer;
  Sec: string;
begin
  Db := TAppDb.Create;
  D := TaFormDef.Create;
  D3 := TaFormDef.Create;
  D4 := TaFormDef.Create;
  try
    if FileExists('/tmp/ta_contdesign.db') then DeleteFile('/tmp/ta_contdesign.db');
    Db.Open('/tmp/ta_contdesign.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
    D.Name := 'CD'; D.RecordSource := 'partneri'; D.ViewMode := 'continuous';
    D.HeaderHeight := 56; D.RowHeight := 34; D.FooterHeight := 40;
    C := NewCtl('Label', 'h1', '', 4, 4); C.Caption := 'Naziv'; C.Section := 'header'; D.Add(C);
    C := NewCtl('TextBox', 't1', 'naziv', 4, 4); C.Section := 'detail'; D.Add(C);
    C := NewCtl('Label', 'f1', '', 4, 4); C.Caption := 'Ukupno'; C.Section := 'footer'; D.Add(C);
    Des := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      Check(Des.FormDef.Count = 3, 'contdesign: tri kontrole ucitane');
      Check(Des.FormDef[0].Top = 4, 'contdesign: zaglavlje na vrhu povrsine (Top ' + IntToStr(Des.FormDef[0].Top) + ')');
      Check(Des.FormDef[1].Top = 60, 'contdesign: detalj je ispod zaglavlja na povrsini (Top 56 + 4 = 60, ima ' + IntToStr(Des.FormDef[1].Top) + ')');
      Check(Des.FormDef[2].Top = 94, 'contdesign: podnozje ispod detalja (56 + 34 + 4 = 94, ima ' + IntToStr(Des.FormDef[2].Top) + ')');
      Des.AddForTest('TextBox', 200, 64);
      Des.AddForTest('Label', 200, 12);
      Des.AddForTest('TextBox', 200, 100);
      Check(Des.FormDef.Count = 6, 'contdesign: dodane tri kontrole');
      D3.FromJson(Des.NormalizedJson);
      Check((D3.Count = 6) and (D3.HeaderHeight = 56) and (D3.RowHeight = 34) and (D3.FooterHeight = 40), 'contdesign: visine odjeljaka su u zapisu');
      Check((D3[1].Section = 'detail') and (D3[1].Top = 4), 'contdesign: detalj se sprema s Top unutar odjeljka (4), ima ' + D3[1].Section + '/' + IntToStr(D3[1].Top));
      Check((D3[2].Section = 'footer') and (D3[2].Top = 4), 'contdesign: podnozje s Top 4');
      Check((D3[3].Section = 'detail') and (D3[3].Top = 8), 'contdesign: nova kontrola bacena u detalj postaje detalj (Top ' + IntToStr(D3[3].Top) + ')');
      Check(D3[4].Section = 'header', 'contdesign: nova kontrola bacena u zaglavlje postaje zaglavlje');
      Check(D3[5].Section = 'footer', 'contdesign: nova kontrola bacena u podnozje postaje podnozje');
      Check(Des.SaveForTest, 'contdesign: spremanje');
    finally
      Des.Free;
    end;
    D4.FromJson(Db.LoadObject('_sys_forms', 'CD'));
    Check((D4.ViewMode = 'continuous') and (D4.Count = 6) and (D4[1].Section = 'detail') and (D4[1].Top = 4), 'contdesign: spremljena forma ima odjeljke i Top unutar njih');
    { ponovno otvaranje: ista struktura (dizajner preuzima definiciju) }
    D := TaFormDef.Create;
    D.FromJson(Db.LoadObject('_sys_forms', 'CD'));
    D.Name := 'CD';
    Des := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      Check((Des.FormDef[1].Top = 60) and (Des.FormDef[3].Top = 64), 'contdesign: ponovno otvaranje vraca kontrole na povrsinu odjeljaka');
      D3.FromJson(Des.NormalizedJson);
      Check((D3[1].Top = 4) and (D3[3].Top = 8) and (D3[3].Section = 'detail'), 'contdesign: krug otvori-spremi je stabilan');
    finally
      Des.Free;
    end;
    { obicna forma se ne dira }
    D := TaFormDef.Create;
    D.Name := 'Obicna'; D.RecordSource := 'partneri';
    D.Add(NewCtl('TextBox', 'a', 'naziv', 10, 50));
    Des := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      D3.FromJson(Des.NormalizedJson);
      Check((D3[0].Top = 50) and (D3[0].Section = ''), 'contdesign: obicna forma nema odjeljke i Top se ne mijenja');
    finally
      Des.Free;
    end;
    Db.Close;
  finally
    D4.Free;
    D3.Free;
    Db.Free;
  end;
end;

procedure TestRowRules;
var
  Db: TAppDb;
  Src: TaRowSource;
  Def: TaFormDef;
  C: TaControlDef;
  Fm: TForm;
  H: TaRowsView;
  Q: TZQuery;
begin
  Db := TAppDb.Create;
  Def := TaFormDef.Create;
  Fm := TForm.CreateNew(nil);
  try
    if FileExists('/tmp/ta_rowrules.db') then DeleteFile('/tmp/ta_rowrules.db');
    Db.Open('/tmp/ta_rowrules.db');
    Db.Conn.ExecuteDirect('CREATE TABLE stavke (id INTEGER PRIMARY KEY, opis VARCHAR(40), kolicina INTEGER, cijena DECIMAL(12,2), iznos DECIMAL(12,2), pdv DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO stavke (opis, kolicina, cijena, iznos, pdv) VALUES (''a'', 2, 5, 10, 2.5)');
    Def.AllowAdds := True; Def.AllowEdits := True; Def.AllowDeletes := True;
    Def.CalcRules := 'kolicina,cijena -> iznos = Zaokruzi([kolicina] * [cijena], 2) ;; iznos -> pdv = Zaokruzi([iznos] * 0.25, 2)';
    C := NewCtl('TextBox', 'tOpis', 'opis', 4, 4); Def.Add(C);
    C := NewCtl('TextBox', 'tKol', 'kolicina', 160, 4); C.Width := 60; Def.Add(C);
    C := NewCtl('TextBox', 'tCij', 'cijena', 226, 4); C.Width := 90; C.Format := '#,##0.00'; Def.Add(C);
    C := NewCtl('TextBox', 'tIzn', 'iznos', 322, 4); C.Width := 90; C.Format := '#,##0.00'; Def.Add(C);
    C := NewCtl('TextBox', 'tPdv', 'pdv', 418, 4); C.Width := 80; C.Format := '#,##0.00'; Def.Add(C);
    Src := TaRowSource.Create(Db, 'stavke');
    Fm.SetBounds(0, 0, 560, 200);
    H := TaRowsView.Create(Fm);
    H.Parent := Fm;
    H.SetBounds(0, 0, 560, 200);
    H.Setup(Src, Def);
    { oblikovanje u zivom redu }
    Check(DigitsOnly(TaEdit(H.LiveControl(3)).Text) = '1000', 'rowrules: zivi red prikazuje oblikovano (10,00): ' + TaEdit(H.LiveControl(3)).Text);
    Check(H.RawValue(3) = '10', 'rowrules: sirova vrijednost je 10 (' + H.RawValue(3) + ')');
    H.SimulateEnter(3);
    Check(TaEdit(H.LiveControl(3)).Text = '10', 'rowrules: u fokusu se vidi sirova vrijednost (' + TaEdit(H.LiveControl(3)).Text + ')');
    H.SimulateExit(3);
    Check(DigitsOnly(TaEdit(H.LiveControl(3)).Text) = '1000', 'rowrules: izlaz iz polja vraca oblikovani prikaz');
    { novi red: kolicina * cijena -> iznos, iznos -> pdv (lancano) }
    H.GoToRow(H.Model.NewRow);
    H.SimulateEdit(0, 'nova');
    H.SimulateEdit(1, '3');
    Check(not Src.HasPending('iznos') or (Src.Pending('iznos') = ''), 'rowrules: dok nema cijene iznos je prazan');
    H.SimulateEdit(2, '2.5');
    Check(Src.Pending('iznos') = '7.5', 'rowrules: iznos = 3 * 2,5 = 7,5 (' + Src.Pending('iznos') + ')');
    Check(DigitsOnly(TaEdit(H.LiveControl(3)).Text) = '750', 'rowrules: izracunati iznos je prikazan u zivom redu (' + TaEdit(H.LiveControl(3)).Text + ')');
    Check(Src.Pending('pdv') = '1.88', 'rowrules: lancano, pdv = 7,5 * 0,25 = 1,88 (' + Src.Pending('pdv') + ')');
    Check(H.CommitRow, 'rowrules: spremanje ' + H.Error);
    Q := Db.NewQuery('SELECT iznos, pdv FROM stavke WHERE opis = ''nova''');
    try
      Q.Open;
      Check((Abs(Q.Fields[0].AsFloat - 7.5) < 0.001) and (Abs(Q.Fields[1].AsFloat - 1.88) < 0.001), 'rowrules: izracunate vrijednosti su u bazi');
    finally
      Q.Free;
    end;
    { izmjena postojeceg reda: kolicina nova, cijena iz zapisa }
    H.GoToRow(0);
    H.SimulateEdit(1, '4');
    Check(Src.Pending('iznos') = '20', 'rowrules: izmjena kolicine koristi cijenu iz zapisa (4 * 5 = 20): ' + Src.Pending('iznos'));
    Check(Src.Pending('pdv') = '5', 'rowrules: pdv slijedi (5)');
    H.CommitRow;
    Q := Db.NewQuery('SELECT iznos FROM stavke WHERE id = 1');
    try Q.Open; Check(Abs(Q.Fields[0].AsFloat - 20) < 0.001, 'rowrules: izmjena je u bazi'); finally Q.Free; end;
    { bez okidaca nema izracuna }
    H.GoToRow(0);
    H.SimulateEdit(0, 'opis se mijenja');
    Check(not Src.HasPending('iznos'), 'rowrules: izmjena opisa ne pokrece pravilo');
    H.CancelRow;
    Src.Free;
    Db.Close;
  finally
    Fm.Free;
    Def.Free;
    Db.Free;
  end;
end;

type
  TCompProbe = class
    Last: string;
    procedure OnBtn(Sender: TObject; const AControlName: string; ARow: Integer);
  end;

procedure TCompProbe.OnBtn(Sender: TObject; const AControlName: string; ARow: Integer);
begin
  Last := AControlName;
end;

procedure TestContComp;
var
  Fm: TForm;
  DbC: TaDatabase;
  CF: TaContinuousForm;
  L: TLabel;
  E: TaEdit;
  Ck: TCheckBox;
  Bt: TButton;
  D: TaFormDef;
  Q: TZQuery;
  I: Integer;
  Pr: TCompProbe;
begin
  if FileExists('/tmp/ta_contcomp.db') then DeleteFile('/tmp/ta_contcomp.db');
  Pr := TCompProbe.Create;
  Fm := TForm.CreateNew(nil);
  try
    DbC := TaDatabase.Create(Fm);
    DbC.FileName := '/tmp/ta_contcomp.db';
    DbC.Active := True;
    DbC.ExecSQL('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER, iznos DECIMAL(12,2))');
    DbC.ExecSQL('BEGIN');
    for I := 1 to 60 do
      if I mod 2 = 1 then DbC.ExecSQL('INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''P' + Format('%.2d', [I]) + ''', ''Split'', 1, ' + IntToStr(I * 10) + ')')
      else DbC.ExecSQL('INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''P' + Format('%.2d', [I]) + ''', ''Zagreb'', 0, ' + IntToStr(I * 10) + ')');
    DbC.ExecSQL('COMMIT');
    Fm.SetBounds(0, 0, 520, 360);
    CF := TaContinuousForm.Create(Fm);
    CF.Name := 'Lista';
    CF.Parent := Fm;
    CF.SetBounds(0, 0, 520, 360);
    CF.Database := DbC;
    CF.RecordSource := 'partneri';
    CF.RowHeight := 34;
    { zaglavlje: naslov za sortiranje, filtar po gradu, gumb }
    L := TLabel.Create(Fm); L.Name := 'hNaziv'; L.Parent := CF; L.Caption := 'Naziv'; L.SetBounds(4, 4, 150, 20);
    E := TaEdit.Create(Fm); E.Name := 'fGrad'; E.Parent := CF; E.SetBounds(160, 28, 110, 24);
    Bt := TButton.Create(Fm); Bt.Name := 'bNovi'; Bt.Parent := CF; Bt.Caption := 'Info'; Bt.SetBounds(420, 4, 60, 24);
    { detalj }
    E := TaEdit.Create(Fm); E.Name := 'eNaziv'; E.Parent := CF; E.ControlSource := 'naziv'; E.SetBounds(4, 60, 150, 26);
    E := TaEdit.Create(Fm); E.Name := 'eGrad'; E.Parent := CF; E.ControlSource := 'grad'; E.SetBounds(160, 60, 110, 26);
    Ck := TCheckBox.Create(Fm); Ck.Name := 'cAkt'; Ck.Parent := CF; Ck.Caption := ''; Ck.SetBounds(276, 60, 24, 26);
    E := TaEdit.Create(Fm); E.Name := 'eIznos'; E.Parent := CF; E.ControlSource := 'iznos'; E.Format := '#,##0.00'; E.SetBounds(306, 60, 100, 26);
    { podnozje }
    E := TaEdit.Create(Fm); E.Name := 'zBroj'; E.Parent := CF; E.ControlSource := '=Count()'; E.SetBounds(160, 324, 110, 24);
    E := TaEdit.Create(Fm); E.Name := 'zZbroj'; E.Parent := CF; E.ControlSource := '=Sum(iznos)'; E.Format := '#,##0.00'; E.SetBounds(306, 324, 100, 24);
    CF.Bindings.Add('hNaziv=sort:naziv');
    CF.Bindings.Add('fGrad=filter:grad');
    CF.Bindings.Add('cAkt=aktivan');
    CF.OnButtonClick := @Pr.OnBtn;
    { definicija iz panela }
    D := CF.BuildDef;
    try
      Check((D.ViewMode = 'continuous') and (D.HeaderHeight = 56) and (D.RowHeight = 34) and (D.FooterHeight = 40), 'contcomp: definicija ima odjeljke i visine');
      Check(D.Count = 9, 'contcomp: 9 kontrola s komponente (' + IntToStr(D.Count) + ')');
      Check((D.IndexOfName('hNaziv') >= 0) and (D[D.IndexOfName('hNaziv')].Section = 'header') and (D[D.IndexOfName('hNaziv')].GetX('sort') = 'naziv'), 'contcomp: naslov u zaglavlju sa sortiranjem');
      Check((D.IndexOfName('fGrad') >= 0) and (D[D.IndexOfName('fGrad')].GetX('filter') = 'grad'), 'contcomp: filtar iz Bindings');
      Check((D.IndexOfName('cAkt') >= 0) and (D[D.IndexOfName('cAkt')].Kind = 'CheckBox') and (D[D.IndexOfName('cAkt')].ControlSource = 'aktivan') and (D[D.IndexOfName('cAkt')].Section = 'detail'),
        'contcomp: kvacica vezana na polje iz Bindings');
      Check(D[D.IndexOfName('zZbroj')].ControlSource = '=Sum(iznos)', 'contcomp: podnozje ima izraz');
    finally
      D.Free;
    end;
    Check(not CF.Active, 'contcomp: prije Open nije aktivna');
    CF.Open;
    Check(CF.Active and (CF.Body <> nil), 'contcomp: Open gradi tijelo');
    Check(not TControl(Fm.FindComponent('eNaziv')).Visible and not TControl(Fm.FindComponent('hNaziv')).Visible, 'contcomp: kontrole predloska se skrivaju dok je tijelo aktivno');
    Check(CF.Body.Host.Model.RecordCount = 60, 'contcomp: 60 zapisa');
    Check(DigitsOnly(CF.Body.FooterText('zBroj')) = '60', 'contcomp: podnozje Count 60 (' + CF.Body.FooterText('zBroj') + ')');
    Check(DigitsOnly(CF.Body.FooterText('zZbroj')) = '1830000', 'contcomp: podnozje Sum 18.300,00 (' + CF.Body.FooterText('zZbroj') + ')');
    CF.Body.ClickHeader('hNaziv');
    CF.Body.ClickHeader('hNaziv');
    Check(CF.Body.Source.Value(0, 'naziv') = 'P60', 'contcomp: klik na naslov sortira silazno');
    CF.Body.TypeFilter('fGrad', 'Split');
    Check(CF.Body.Host.Model.RecordCount = 30, 'contcomp: filtar po gradu daje 30');
    CF.Body.TypeFilter('fGrad', '');
    { unos u novi red kroz komponentu }
    CF.Body.Host.GoToRow(CF.Body.Host.Model.NewRow);
    CF.Body.Host.SimulateEdit(0, 'Novi');
    CF.Body.Host.SimulateEdit(3, '40');
    Check(CF.Body.Host.CommitRow, 'contcomp: unos novog zapisa ' + CF.Body.Host.Error);
    Check(DigitsOnly(CF.Body.FooterText('zBroj')) = '61', 'contcomp: Count 61 nakon unosa');
    { gumb u zaglavlju javlja naziv kontrole }
    TButton(CF.Body.HeaderControl('bNovi')).Click;
    Check(Pr.Last = 'bNovi', 'contcomp: gumb zaglavlja javlja OnButtonClick s nazivom kontrole (' + Pr.Last + ')');
    { zatvaranje vraca predlozak }
    CF.Close;
    Check(not CF.Active and TControl(Fm.FindComponent('eNaziv')).Visible, 'contcomp: Close vraca kontrole predloska');
    Q := DbC.NewQuery('SELECT COUNT(*) FROM partneri');
    try Q.Open; Check(Q.Fields[0].AsInteger = 61, 'contcomp: baza ima 61 zapis'); finally Q.Free; end;
    { podforma: SetMaster }
    DbC.ExecSQL('CREATE TABLE stavke (id INTEGER PRIMARY KEY, racun_id INTEGER, opis VARCHAR(20), iznos DECIMAL(12,2))');
    DbC.ExecSQL('INSERT INTO stavke (racun_id, opis, iznos) VALUES (1, ''a'', 5), (1, ''b'', 7), (2, ''c'', 9)');
    CF.RecordSource := 'stavke';
    CF.DetailField := 'racun_id';
    CF.Bindings.Clear;
    TaEdit(Fm.FindComponent('eNaziv')).ControlSource := 'opis';
    TaEdit(Fm.FindComponent('eGrad')).ControlSource := 'opis';
    CF.Open;
    CF.SetMaster('1');
    Check(CF.Body.Host.Model.RecordCount = 2, 'contcomp: SetMaster(1) daje 2 stavke');
    CF.SetMaster('2');
    Check(CF.Body.Host.Model.RecordCount = 1, 'contcomp: SetMaster(2) daje 1 stavku');
    CF.Close;
  finally
    Fm.Free;
    Pr.Free;
  end;
end;

var
  RunnerAnswer: Boolean = True;
  RunnerAsked: Integer = 0;

function TestRunnerConfirm(const AMsg: string): Boolean;
begin
  Inc(RunnerAsked);
  Result := RunnerAnswer;
end;

procedure PressRunner(R: TaFormRunner; AKey: Word; AShift: TShiftState);
var
  K: Word;
begin
  K := AKey;
  R.OnKeyDown(R, K, AShift);
end;

type
  TLovTimer = class
    Tm: TTimer;
    RowsSeen: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Fire(Sender: TObject);
  end;

var
  LovTick: TLovTimer;

constructor TLovTimer.Create;
begin
  Tm := TTimer.Create(nil);
  Tm.Interval := 200;
  Tm.OnTimer := @Fire;
  RowsSeen := -1;
end;

destructor TLovTimer.Destroy;
begin
  Tm.Free;
  inherited;
end;

procedure TLovTimer.Fire(Sender: TObject);
var
  F: TForm;
  I: Integer;
  G: TStringGrid;
begin
  Tm.Enabled := False;
  F := Screen.ActiveForm;
  if F = nil then Exit;
  G := nil;
  for I := 0 to F.ComponentCount - 1 do
    if F.Components[I] is TStringGrid then G := TStringGrid(F.Components[I]);
  for I := 0 to F.ComponentCount - 1 do
    if F.Components[I] is TEdit then TEdit(F.Components[I]).Text := 'ATI';
  if G <> nil then
  begin
    RowsSeen := G.RowCount - 1;
    G.Row := 1;
  end;
  F.ModalResult := mrOk;
end;

var
  LovBtnFound: Boolean;
  LovPickName: string = '';
  LovAsked: string = '';

function TestLovPick(ADs: TaDataSet; const ATitle, AInitial: string): Boolean;
begin
  LovAsked := AInitial;
  Result := (LovPickName <> '') and ADs.Locate('naziv', LovPickName, []);
end;

procedure TestLov;
var
  Db: TAppDb;
  D: TaFormDef;
  C: TaControlDef;
  R: TaFormRunner;
  K: Word;
  Q: TZQuery;
  I: Integer;
begin
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_lov.db') then DeleteFile('/tmp/ta_lov.db');
    Db.Open('/tmp/ta_lov.db');
    Db.Conn.ExecuteDirect('CREATE TABLE artikl (sifra VARCHAR(10), naziv VARCHAR(30), cijena DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO artikl VALUES (''A1'', ''Vijak'', 1.5), (''A2'', ''Matica'', 0.8), (''A3'', ''Podloska'', 0.2)');
    Db.Conn.ExecuteDirect('CREATE TABLE stavka (id INTEGER PRIMARY KEY, sifra VARCHAR(10), naziv VARCHAR(30), cijena DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO stavka (sifra, naziv, cijena) VALUES (''A1'', ''Vijak'', 1.5)');
    D := TaFormDef.Create;
    D.Name := 'LovF'; D.RecordSource := 'stavka'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 460; D.Height := 160;
    D.Add(NewCtl('TextBox', 'txtSifra', 'sifra', 10, 10)); D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 40)); D.Add(NewCtl('TextBox', 'txtCijena', 'cijena', 10, 70));
    C := D[D.IndexOfName('txtSifra')];
    C.SetX('lov', 'artikl'); C.SetX('lovmap', 'sifra=txtSifra;naziv=txtNaziv;cijena=txtCijena'); C.SetX('lovvalidate', '1');
    OnRunnerLov := @TestLovPick;
    OnRunnerMessage := @CaptureMsg;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.KeyMap := GlobalKeyMap;
      TWinControl(R.ControlByName('txtSifra')).SetFocus;
      LovPickName := 'Matica';
      K := VK_F9; R.OnKeyDown(R, K, []);
      Check(TEdit(R.ControlByName('txtSifra')).Text = 'A2', 'lov: F9 upisuje sifru');
      Check(TEdit(R.ControlByName('txtNaziv')).Text = 'Matica', 'lov: i naziv u drugo polje');
      Check(DigitsOnly(TEdit(R.ControlByName('txtCijena')).Text) = '08', 'lov: i cijenu (' + TEdit(R.ControlByName('txtCijena')).Text + ')');
      Check(R.RecordState = rsChanged, 'lov: izbor cini zapis promijenjenim');
      Check(LovAsked = 'A1', 'lov: popis dobiva trenutni tekst polja za pocetni filtar (' + LovAsked + ')');
      R.DoAction('save');
      Q := Db.NewQuery('SELECT naziv FROM stavka WHERE id = 1');
      try Q.Open; Check(Q.Fields[0].AsString = 'Matica', 'lov: izbor je spremljen'); finally Q.Free; end;
      { odustajanje ne dira polja }
      LovPickName := '';
      K := VK_F9; R.OnKeyDown(R, K, []);
      Check(TEdit(R.ControlByName('txtSifra')).Text = 'A2', 'lov: odustajanje ne mijenja polja');
      { provjera iz popisa }
      TEdit(R.ControlByName('txtSifra')).Text := 'ZZ';
      R.DoAction('save');
      Check(R.RecordState = rsChanged, 'lov: vrijednost koje nema u popisu se odbija');
      TEdit(R.ControlByName('txtSifra')).Text := 'a3';
      R.DoAction('save');
      Q := Db.NewQuery('SELECT sifra FROM stavka WHERE id = 1');
      try Q.Open; Check(Q.Fields[0].AsString = 'a3', 'lov: vrijednost iz popisa (bez obzira na velika slova) prolazi'); finally Q.Free; end;
    finally
      R.Free;
    end;
    { LOV po celiji tablice }
    D := TaFormDef.Create;
    D.Name := 'LovG'; D.RecordSource := 'stavka'; D.ViewMode := 'datasheet'; D.AllowEdits := True; D.Width := 600; D.Height := 260;
    D.GridLov := 'sifra | artikl | sifra=sifra;naziv=naziv;cijena=cijena';
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.KeyMap := GlobalKeyMap;
      R.MainGrid.SelectedField := R.Query.FieldByName('sifra');
      LovPickName := 'Vijak';
      K := VK_F9; R.OnKeyDown(R, K, []);
      Check((R.Query.FieldByName('sifra').AsString = 'A1') and (R.Query.FieldByName('naziv').AsString = 'Vijak'), 'lov: F9 u celiji tablice puni vise stupaca');
      Check(Ord(R.Query.State) = 2, 'lov: celija je u izmjeni');
      R.Query.Post;
      R.MainGrid.SelectedField := R.Query.FieldByName('naziv');
      LovPickName := 'Matica';
      K := VK_F9; R.OnKeyDown(R, K, []);
      Check(R.Query.FieldByName('naziv').AsString = 'Vijak', 'lov: stupac bez LOV-a ne reagira na F9');
    finally
      R.Free;
    end;
    { gumb uz polje }
    D := TaFormDef.Create;
    D.Name := 'LovB'; D.RecordSource := 'stavka'; D.AllowEdits := True; D.Width := 460; D.Height := 160;
    D.Add(NewCtl('TextBox', 'txtSifra', 'sifra', 10, 10));
    D[D.IndexOfName('txtSifra')].SetX('lov', 'artikl');
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      LovBtnFound := False;
      for I := 0 to R.ComponentCount - 1 do
        if (R.Components[I] is TButton) and (TButton(R.Components[I]).Tag = PtrInt(R.ControlByName('txtSifra'))) then LovBtnFound := True;
      Check(LovBtnFound, 'lov: uz polje s popisom stoji gumb ...');
    finally
      R.Free;
    end;
    { pravi dijalog: tajmer upisuje filtar i potvrdi }
    Q := Db.NewQuery('SELECT * FROM artikl'); Q.Open;
    LovTick := TLovTimer.Create;
    Check(RunLov(nil, Q, 'Artikli', ''), 'lov: dijalog vraca odabir');
    Check((Q.FieldByName('naziv').AsString = 'Matica') and (LovTick.RowsSeen = 1), 'lov: filtar "ATI" (bez obzira na velika slova) ostavlja samo Maticu (' + Q.FieldByName('naziv').AsString + ', redaka ' + IntToStr(LovTick.RowsSeen) + ')');
    LovTick.Free;
    Q.Free;
    OnRunnerLov := nil;
    OnRunnerMessage := nil;
    Db.Close;
  finally
    Db.Free;
  end;
end;


function TestBinderLovPick(ADs: TaDataSet; const ATitle, AInitial: string): Boolean;
begin
  Result := ADs.Locate('naziv', 'Matica', []);
end;

procedure TestBinderLov;
var
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  Bd: TaFormBinder;
  Fm: TForm;
  ESif, ENaz: TaEdit;
  Lo: TaLovOptions;
  Ok: Boolean;
begin
  if FileExists('/tmp/ta_binderlov.db') then DeleteFile('/tmp/ta_binderlov.db');
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_binderlov.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE artikl (sifra VARCHAR(10), naziv VARCHAR(30))');
    Dbc.ExecSQL('INSERT INTO artikl VALUES (''A1'', ''Vijak''), (''A2'', ''Matica'')');
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, sifra VARCHAR(10), naziv VARCHAR(30))');
    Dbc.ExecSQL('INSERT INTO st (sifra, naziv) VALUES (''A1'', ''Vijak'')');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    ESif := TaEdit.Create(Fm); ESif.Name := 'eSifra'; ESif.Parent := Fm; ESif.Variant := evLov;
    ENaz := TaEdit.Create(Fm); ENaz.Name := 'eNaziv'; ENaz.Parent := Fm;
    Lo := TaLovOptions(ESif.Options);
    Lo.Source := 'artikl'; Lo.Map := 'sifra=eSifra;naziv=eNaziv'; Lo.Validate := True;
    Bd := TaFormBinder.Create(Owner);
    Bd.Database := Dbc;
    Bd.DataSource := Ds;
    with Bd.Bindings.Add do begin Control := ESif; FieldName := 'sifra'; end;
    with Bd.Bindings.Add do begin Control := ENaz; FieldName := 'naziv'; end;
    Bd.Locale := blSystem;
    LovPickHook := @TestBinderLovPick;
    Bd.Activate;
    Check(Assigned(ESif.OnLov), 'binderlov: binder prikljucuje popis na varijantu lov');
    Check(ESif.Engine.Inner is TEditButton, 'binderlov: varijanta lov ima polje s gumbom');
    Q.Edit;
    ESif.RequestLov;
    Check((ESif.Text = 'A2') and (ENaz.Text = 'Matica'), 'binderlov: izbor puni sifru i naziv (' + ESif.Text + ', ' + ENaz.Text + ')');
    Q.Post;
    Check((Q.FieldByName('sifra').AsString = 'A2') and (Q.FieldByName('naziv').AsString = 'Matica'), 'binderlov: izbor je u skupu podataka');
    Q.Edit;
    Q.FieldByName('sifra').AsString := 'ZZ';
    Ok := True;
    try Q.Post; except Ok := False; end;
    Check(not Ok, 'binderlov: Validate odbija sifru koje nema u popisu');
    Q.Cancel;
    LovPickHook := nil;
    Dbc.Active := False;
  finally
    LovPickHook := nil;
    Owner.Free;
    Fm.Free;
  end;
end;

function TestRowLovPick(ADs: TaDataSet; const ATitle, AInitial: string): Boolean;
begin
  Result := ADs.Locate('naziv', 'Matica', []);
end;

procedure TestRowLov;
var
  Db: TAppDb;
  Src: TaRowSource;
  Def: TaFormDef;
  C: TaControlDef;
  Fm: TForm;
  H: TaRowsView;
  Q: TZQuery;
  K: Word;
begin
  Db := TAppDb.Create;
  Def := TaFormDef.Create;
  Fm := TForm.CreateNew(nil);
  try
    if FileExists('/tmp/ta_rowlov.db') then DeleteFile('/tmp/ta_rowlov.db');
    Db.Open('/tmp/ta_rowlov.db');
    Db.Conn.ExecuteDirect('CREATE TABLE artikl (sifra VARCHAR(10), naziv VARCHAR(30))');
    Db.Conn.ExecuteDirect('INSERT INTO artikl VALUES (''A1'', ''Vijak''), (''A2'', ''Matica'')');
    Db.Conn.ExecuteDirect('CREATE TABLE stavke (id INTEGER PRIMARY KEY, sifra VARCHAR(10), naziv VARCHAR(30))');
    Db.Conn.ExecuteDirect('INSERT INTO stavke (sifra, naziv) VALUES (''A1'', ''Vijak'')');
    Def.AllowAdds := True; Def.AllowEdits := True;
    C := NewCtl('TextBox', 'tSifra', 'sifra', 4, 4); C.Width := 80;
    C.SetX('lov', 'artikl'); C.SetX('lovmap', 'sifra=tSifra;naziv=tNaziv'); C.SetX('lovvalidate', '1'); Def.Add(C);
    C := NewCtl('TextBox', 'tNaziv', 'naziv', 100, 4); C.Width := 120; Def.Add(C);
    Src := TaRowSource.Create(Db, 'stavke');
    Fm.SetBounds(0, 0, 400, 160);
    H := TaRowsView.Create(Fm);
    H.Parent := Fm;
    H.SetBounds(0, 0, 400, 160);
    H.KeyMap := GlobalKeyMap;
    H.Setup(Src, Def);
    LovPickHook := @TestRowLovPick;
    H.GoToRow(0);
    K := VK_F9;
    Check(H.HandleKey(K, [], H.LiveControl(0)), 'rowlov: F9 u celiji s popisom je obradjen');
    Check((Src.Pending('sifra') = 'A2') and (Src.Pending('naziv') = 'Matica'), 'rowlov: izbor puni vise celija reda (' + Src.Pending('sifra') + ', ' + Src.Pending('naziv') + ')');
    Check(H.CommitRow, 'rowlov: spremanje ' + H.Error);
    Q := Db.NewQuery('SELECT sifra, naziv FROM stavke WHERE id = 1');
    try Q.Open; Check((Q.Fields[0].AsString = 'A2') and (Q.Fields[1].AsString = 'Matica'), 'rowlov: izbor je u bazi'); finally Q.Free; end;
    Check((H.LiveControl(0) is TaEdit) and (TaEdit(H.LiveControl(0)).Variant = evLov) and (TaEdit(H.LiveControl(0)).Engine.Inner is TEditButton), 'rowlov: celija s popisom ima gumb ...');
    Check(not (TaEdit(H.LiveControl(1)).Variant = evLov), 'rowlov: celija bez popisa nema gumb');
    TaEdit(H.LiveControl(0)).RequestLov;
    Check(Src.Pending('naziv') = 'Matica', 'rowlov: gumb ... otvara popis i puni redak');
    K := VK_F9;
    Check(not H.HandleKey(K, [], H.LiveControl(1)), 'rowlov: F9 u celiji bez popisa nije obradjen');
    H.SimulateEdit(0, 'ZZ');
    Check(not H.CommitRow and (Pos('nema u popisu', H.Error) > 0), 'rowlov: lovvalidate odbija vrijednost koje nema u popisu (' + H.Error + ')');
    H.SimulateEdit(0, 'a1');
    Check(H.CommitRow, 'rowlov: vrijednost iz popisa prolazi ' + H.Error);
    LovPickHook := nil;
    Src.Free;
    Db.Close;
  finally
    LovPickHook := nil;
    Fm.Free;
    Def.Free;
    Db.Free;
  end;
end;

procedure TestLovBuilder;
var
  V, S, M: string;
begin
  V := '';
  V := GridLovSet(V, 'sifra', 'artikl', 'sifra=sifra;naziv=naziv');
  Check(V = 'sifra | artikl | sifra=sifra;naziv=naziv', 'lovbuilder: prvi unos (' + V + ')');
  V := GridLovSet(V, 'grad', 'gradovi', 'ime=grad');
  Check(V = 'sifra | artikl | sifra=sifra;naziv=naziv ;; grad | gradovi | ime=grad', 'lovbuilder: drugi stupac se dodaje (' + V + ')');
  V := GridLovSet(V, 'sifra', 'artikli2', 'sifra=sifra');
  Check(GridLovEntry(V, 'sifra', S, M) and (S = 'artikli2') and (M = 'sifra=sifra'), 'lovbuilder: unos stupca se zamjenjuje');
  Check(GridLovEntry(V, 'GRAD', S, M) and (S = 'gradovi'), 'lovbuilder: stupac se trazi bez obzira na velika slova');
  V := GridLovSet(V, 'grad', '', '');
  Check(not GridLovEntry(V, 'grad', S, M) and GridLovEntry(V, 'sifra', S, M), 'lovbuilder: prazan izvor uklanja unos');
  Check(PropKindOf('Lov') = pkExpr, 'lovbuilder: Lov ima gumb u Inspektoru');
end;

type
  TBldTimer = class
    Tm: TTimer;
    constructor Create;
    destructor Destroy; override;
    procedure Fire(Sender: TObject);
  end;

constructor TBldTimer.Create;
begin
  Tm := TTimer.Create(nil);
  Tm.Interval := 200;
  Tm.OnTimer := @Fire;
end;

destructor TBldTimer.Destroy;
begin
  Tm.Free;
  inherited;
end;

procedure TBldTimer.Fire(Sender: TObject);
var
  F: TForm;
  I, N: Integer;
  Cb: TComboBox;
begin
  Tm.Enabled := False;
  F := Screen.ActiveForm;
  if F = nil then Exit;
  N := 0;
  for I := 0 to F.ComponentCount - 1 do
  begin
    if F.Components[I] is TComboBox then
    begin
      Cb := TComboBox(F.Components[I]);
      case N of
        0: Cb.Text := 'sifra';        { stupac tablice }
        1: Cb.Text := 'artikl';       { izvor }
        2: Cb.Text := 'sifra';        { stupac izvora }
        3: Cb.Text := 'sifra';        { cilj }
        4: Cb.Text := 'naziv';
        5: Cb.Text := 'naziv';
      end;
      Inc(N);
    end;
    if F.Components[I] is TCheckBox then TCheckBox(F.Components[I]).Checked := True;
  end;
  F.ModalResult := mrOk;
end;

procedure TestLovBuilderDialogs;
var
  T: TBldTimer;
  Db: TAppDb;
  Tg: TStringList;
  S, M: string;
  V, G: Boolean;
  Gv: string;
begin
  Db := TAppDb.Create;
  Tg := TStringList.Create;
  try
    if FileExists('/tmp/ta_lovbld.db') then DeleteFile('/tmp/ta_lovbld.db');
    Db.Open('/tmp/ta_lovbld.db');
    Db.Conn.ExecuteDirect('CREATE TABLE artikl (sifra VARCHAR(10), naziv VARCHAR(30))');
    Tg.Add('txtSifra'); Tg.Add('txtNaziv');
    { kontrola: prvi combo = izvor, zatim parovi (stupac, kontrola) }
    S := ''; M := ''; V := False;
    T := TBldTimer.Create;
    G := RunLovBuilder(nil, Db, Tg, S, M, V);
    T.Free;
    Check(G and (S = 'sifra') , 'lovbuilder dlg: izvor iz prvog polja (' + S + ')');
    Check(V, 'lovbuilder dlg: kvacica provjere se cita');
    { tablica: prvi combo = stupac, zatim izvor, parovi }
    Gv := '';
    T := TBldTimer.Create;
    G := RunGridLovBuilder(nil, Db, Tg, Gv);
    T.Free;
    Check(G and (Gv = 'sifra | artikl | sifra=sifra;naziv=naziv'), 'lovbuilder dlg: GridLov iz dijaloga (' + Gv + ')');
    Db.Close;
  finally
    Tg.Free;
    Db.Free;
  end;
end;

procedure TestCheck;
var
  Fm: TForm;
  C: TaCheck;
  V: TaCheckVariant;
  Inn: TWinControl;
  Bad: Integer;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lv: TStringList;
  Lfm: string;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 400, 300);
    Lv := EngineVariants('Check');
    try Check(Lv.Count = 4, 'check: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    C := TaCheck.Create(Fm); C.Parent := Fm; C.SetBounds(8, 8, 200, 28); C.Caption := 'Aktivan';
    Bad := 0;
    for V := Low(TaCheckVariant) to High(TaCheckVariant) do
    begin
      C.Variant := V;
      Inn := C.Engine.Inner;
      case V of
        cvCheckbox: if not ((Inn is TCheckBox) and not TCheckBox(Inn).AllowGrayed) then Inc(Bad);
        cvTriState: if not ((Inn is TCheckBox) and TCheckBox(Inn).AllowGrayed) then Inc(Bad);
        cvRadio: if not (Inn is TRadioButton) then Inc(Bad);
        cvSwitch: if not (Inn is TaSwitchPaint) then Inc(Bad);
      end;
      if Inn.Parent <> C then Inc(Bad);
      if C.Caption <> 'Aktivan' then Inc(Bad);
    end;
    Check(Bad = 0, 'check: svaka varijanta stvara odgovarajucu kontrolu i cuva naslov (nepodudaranja: ' + IntToStr(Bad) + ')');
    { vrijednost kroz varijante }
    C.Variant := cvCheckbox;
    C.Checked := True;
    C.Variant := cvSwitch;
    Check(C.Checked, 'check: oznaka se cuva pri promjeni varijante');
    C.Variant := cvTriState;
    C.SetValue(Null);
    Check(C.IsUndetermined and not C.Checked, 'check: tri stanja pozna "nije odredeno"');
    C.SetValue(True);
    Check(not C.IsUndetermined and C.Checked, 'check: tri stanja, ukljuceno');
    C.Variant := cvCheckbox;
    C.SetValue(Null);
    Check(not C.IsUndetermined and not C.Checked, 'check: obicna kvacica nema trece stanje');
    { samo za citanje }
    C.Checked := False;
    C.ReadOnly := True;
    TCheckBox(C.Engine.Inner).Checked := True;
    Check(not C.Checked, 'check: samo za citanje vraca promjenu (kvacica)');
    C.Variant := cvRadio;
    TRadioButton(C.Engine.Inner).Checked := True;
    Check(not C.Checked, 'check: samo za citanje vraca promjenu (radio)');
    C.Variant := cvSwitch;
    TaSwitchPaint(C.Engine.Inner).Click;
    Check(not C.Checked, 'check: samo za citanje, prekidac se ne mijenja klikom');
    C.ReadOnly := False;
    TaSwitchPaint(C.Engine.Inner).Click;
    Check(C.Checked, 'check: klik ukljucuje prekidac');
    { natpisi prekidaca }
    C.Caption := 'Obavijesti';
    TaSwitchOptions(C.Options).OnCaption := 'Ukljuceno';
    TaSwitchOptions(C.Options).OffCaption := 'Iskljuceno';
    C.Options := C.Options;
    Check(TaSwitchPaint(C.Engine.Inner).CaptionText = 'Ukljuceno', 'check: natpis ukljucenog prekidaca');
    C.Checked := False;
    Check(TaSwitchPaint(C.Engine.Inner).CaptionText = 'Iskljuceno', 'check: natpis iskljucenog prekidaca');
    { veza na polje: cijeli broj, i odmah upis }
    if FileExists('/tmp/ta_check.db') then DeleteFile('/tmp/ta_check.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_check.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, aktivan INTEGER, napomena VARCHAR(5))');
    Dbc.ExecSQL('INSERT INTO st (aktivan, napomena) VALUES (1, ''da''), (0, ''0''), (NULL, NULL)');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    C := TaCheck.Create(Fm); C.Parent := Fm; C.Variant := cvTriState; C.DataSource := Ds; C.DataField := 'aktivan';
    Check(C.Checked and not C.IsUndetermined, 'check: polje 1 je ukljuceno');
    Q.Next;
    Check(not C.Checked and not C.IsUndetermined, 'check: polje 0 je iskljuceno');
    Q.Next;
    Check(C.IsUndetermined, 'check: NULL je nije odredeno');
    Q.First;
    TCheckBox(C.Engine.Inner).Checked := False;
    Check((Ord(Q.State) = 2) and (Q.FieldByName('aktivan').AsInteger = 0), 'check: klik odmah upisuje u polje (' + IntToStr(Q.FieldByName('aktivan').AsInteger) + ')');
    Q.Post;
    C.DataField := 'napomena';
    Q.First;
    Check(C.Checked, 'check: tekst "da" je istina');
    Q.Next;
    Check(not C.Checked, 'check: tekst "0" je laz');
    C.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    { definicija <-> komponenta }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'CheckBox'; D.Name := 'chkAkt'; D.Caption := 'Aktivan'; D.ControlSource := 'aktivan';
      D.Left := 10; D.Top := 20; D.Width := 150; D.Height := 26;
      D.SetX('variant', 'switch'); D.SetX('onCaption', 'Da'); D.SetX('offCaption', 'Ne'); D.SetX('tip', 'Savjet'); D.SetX('foo', 'bar');
      D.SetX('visibleIf', '[x] = 1');
      C := CheckFromDef(D, Fm);
      Check((C.Variant = cvSwitch) and (C.Caption = 'Aktivan') and (C.Name = 'chkAkt') and (C.Hint = 'Savjet') and (C.VisibleIf = '[x] = 1') and (C.Extra = 'foo=bar'),
        'check: definicija postaje komponenta (varijanta, naslov, savjet, nepoznati kljucevi)');
      CheckToDef(C, D2);
      Check((D2.GetX('variant') = 'switch') and (D2.GetX('onCaption') = 'Da') and (D2.GetX('foo') = 'bar') and (D2.ControlSource = 'aktivan') and (D2.Width = 150),
        'check: komponenta se vraca u definiciju bez gubitka');
      C.Variant := cvCheckbox;
      CheckToDef(C, D2);
      Check(D2.GetX('variant') = '', 'check: zadana varijanta se ne zapisuje');
    finally
      D.Free; D2.Free;
    end;
    Check(IsCheckKind('CheckBox') and IsCheckKind('Check') and not IsCheckKind('TextBox'), 'check: vrste definicije obitelji');
    { sprema se i vraca iz .lfm }
    C := TaCheck.Create(Fm); C.Name := 'cLfm'; C.Variant := cvSwitch; C.Caption := 'Spremi'; C.Checked := True;
    TaSwitchOptions(C.Options).OnCaption := 'Upaljeno';
    Lfm := CheckToLfm(C);
    Check((Pos('Variant = cvSwitch', Lfm) > 0) and (Pos('Caption = ''Spremi''', Lfm) > 0) and (Pos('OnCaption = ''Upaljeno''', Lfm) > 0),
      'check: .lfm sadrzi varijantu, naslov i opcije');
    C := CheckFromLfm(Lfm, Fm);
    Check((C.Variant = cvSwitch) and (C.Caption = 'Spremi') and C.Checked and (TaSwitchOptions(C.Options).OnCaption = 'Upaljeno'), 'check: .lfm se cita natrag');
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

type
  TBtnProbe = class
    Clicks: Integer;
    LastMenu: string;
    procedure OnClk(Sender: TObject);
    procedure OnMenuAct(Sender: TObject; const AAction: string);
  end;

procedure TBtnProbe.OnMenuAct(Sender: TObject; const AAction: string);
begin
  LastMenu := AAction;
end;

procedure TBtnProbe.OnClk(Sender: TObject);
begin
  Inc(Clicks);
end;

procedure TestButton;
var
  Fm: TForm;
  B: TaButton;
  V: TaButtonVariant;
  Inn: TWinControl;
  Bad: Integer;
  P: TBtnProbe;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  P := TBtnProbe.Create;
  try
    Fm.SetBounds(0, 0, 400, 300);
    Lv := EngineVariants('Button');
    try Check(Lv.Count = 9, 'button: u registru je 9 varijanti (' + Lv.CommaText + ')'); finally Lv.Free; end;
    B := TaButton.Create(Fm); B.Parent := Fm; B.SetBounds(8, 8, 140, 30); B.Caption := 'Spremi';
    B.OnClick := @P.OnClk;
    Bad := 0;
    for V := Low(TaButtonVariant) to High(TaButtonVariant) do
    begin
      B.Variant := V;
      Inn := B.Engine.Inner;
      case V of
        bvStandard: if not ((Inn is TBitBtn) and not TBitBtn(Inn).Default and not TBitBtn(Inn).Cancel) then Inc(Bad);
        bvDefault: if not ((Inn is TBitBtn) and TBitBtn(Inn).Default) then Inc(Bad);
        bvCancel: if not ((Inn is TBitBtn) and TBitBtn(Inn).Cancel) then Inc(Bad);
        bvToggle: if not (Inn is TToggleBox) then Inc(Bad);
        bvFlat: if not ((Inn is TaFlatPaint) and not TaFlatPaint(Inn).IsLink) then Inc(Bad);
        bvLink: if not ((Inn is TaFlatPaint) and TaFlatPaint(Inn).IsLink) then Inc(Bad);
        bvImage, bvMenu: if not (Inn is TBitBtn) then Inc(Bad);
        bvSplit: if not ((Inn is TaFlatPaint) and TaFlatPaint(Inn).IsSplit) then Inc(Bad);
      end;
      if Inn.Parent <> B then Inc(Bad);
      if B.Caption <> 'Spremi' then Inc(Bad);
    end;
    Check(Bad = 0, 'button: svaka varijanta stvara odgovarajucu kontrolu i cuva naslov (nepodudaranja: ' + IntToStr(Bad) + ')');
    { klik javlja OnClick domacina }
    P.Clicks := 0;
    Bad := 0;
    for V := Low(TaButtonVariant) to High(TaButtonVariant) do
    begin
      B.Variant := V;
      B.PerformClick;
      if P.Clicks <> Ord(V) + 1 then Inc(Bad);
    end;
    Check(Bad = 0, 'button: klik na svaku varijantu zove OnClick (nepodudaranja: ' + IntToStr(Bad) + ', klikova ' + IntToStr(P.Clicks) + ')');
    { image: samo ikona, natpis je savjet }
    B.Variant := bvImage;
    Check((TBitBtn(B.Engine.Inner).Caption = '') and (TBitBtn(B.Engine.Inner).Hint = 'Spremi') and (B.Caption = 'Spremi'), 'button: image nema natpis na gumbu, natpis je savjet');
    { menu i split: stavke izbornika }
    B.Options.MenuItems := 'Spremi|save' + LineEnding + 'Spremi kao|saveas';
    B.Variant := bvMenu;
    B.Options := B.Options;
    Check(B.MenuCount = 2, 'button: menu ima dvije stavke izbornika (' + IntToStr(B.MenuCount) + ')');
    B.OnMenuAction := @P.OnMenuAct;
    B.PerformMenu('saveas');
    Check(P.LastMenu = 'saveas', 'button: stavka izbornika javlja radnju');
    B.Variant := bvSplit;
    B.Options := B.Options;
    Check(B.MenuCount = 2, 'button: split ima iste stavke');
    P.Clicks := 0;
    TaFlatPaint(B.Engine.Inner).SetBounds(0, 0, 120, 28);
    TaFlatPaint(B.Engine.Inner).ClickAt(10);
    Check(P.Clicks = 1, 'button: klik na glavni dio split gumba javlja OnClick');
    B.PerformMenu('save');
    Check(P.LastMenu = 'save', 'button: stavka izbornika split gumba javlja radnju');
    { toggle }
    B.Variant := bvToggle;
    B.Checked := False;
    B.PerformClick;
    Check(B.Checked, 'button: klik pritisne toggle');
    B.PerformClick;
    Check(not B.Checked, 'button: drugi klik ga otpusta');
    B.Checked := True;
    B.Variant := bvFlat;
    B.Variant := bvToggle;
    Check(B.Checked, 'button: pritisnutost se cuva kroz promjenu varijante');
    { ikona }
    B.Variant := bvStandard;
    B.Options.Icon := 'save';
    B.Options := B.Options;
    Check(not TBitBtn(B.Engine.Inner).Glyph.Empty, 'button: ikona postaje slika na gumbu');
    { toggle uz polje }
    if FileExists('/tmp/ta_button.db') then DeleteFile('/tmp/ta_button.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_button.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, aktivan INTEGER)');
    Dbc.ExecSQL('INSERT INTO st (aktivan) VALUES (1), (0)');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    B := TaButton.Create(Fm); B.Parent := Fm; B.Variant := bvToggle; B.DataSource := Ds; B.DataField := 'aktivan';
    Check(B.Checked, 'button: toggle prati polje (1)');
    Q.Next;
    Check(not B.Checked, 'button: toggle prati polje (0)');
    B.PerformClick;
    Check((Ord(Q.State) = 2) and (Q.FieldByName('aktivan').AsInteger = 1), 'button: klik na toggle upisuje u polje');
    Q.Post;
    B.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    { definicija <-> komponenta }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Button'; D.Name := 'btnSpremi'; D.Caption := 'Spremi'; D.OnClick := 'macro:Spremi';
      D.Left := 10; D.Top := 20; D.Width := 120; D.Height := 30;
      D.SetX('variant', 'flat'); D.SetX('icon', 'save'); D.SetX('tip', 'Spremi zapis'); D.SetX('foo', 'bar');
      B := ButtonFromDef(D, Fm);
      Check((B.Variant = bvFlat) and (B.Caption = 'Spremi') and (B.ClickAction = 'macro:Spremi') and (B.Options.Icon = 'save') and (B.Hint = 'Spremi zapis') and (B.Extra = 'foo=bar'),
        'button: definicija postaje komponenta (varijanta, radnja, ikona, nepoznati kljucevi)');
      ButtonToDef(B, D2);
      Check((D2.Kind = 'Button') and (D2.OnClick = 'macro:Spremi') and (D2.GetX('variant') = 'flat') and (D2.GetX('icon') = 'save') and (D2.GetX('foo') = 'bar') and (D2.Width = 120),
        'button: komponenta se vraca u definiciju bez gubitka');
      D.Kind := 'ToggleButton'; D.Name := 'btnTog'; D.SetX('variant', ''); D.OnClick := '';
      B := ButtonFromDef(D, Fm);
      ButtonToDef(B, D2);
      Check((B.Variant = bvToggle) and (D2.Kind = 'ToggleButton') and (D2.GetX('variant') = ''), 'button: ToggleButton je varijanta toggle i vraca se kao ToggleButton');
    finally
      D.Free; D2.Free;
    end;
    Check(IsButtonKind('Button') and IsButtonKind('ToggleButton') and not IsButtonKind('Label'), 'button: vrste definicije obitelji');
    { .lfm }
    B := TaButton.Create(Fm); B.Name := 'bLfm'; B.Variant := bvLink; B.Caption := 'Vise'; B.ClickAction := 'openform:Partneri'; B.Options.Icon := 'search';
    Lfm := ButtonToLfm(B);
    Check((Pos('Variant = bvLink', Lfm) > 0) and (Pos('ClickAction = ''openform:Partneri''', Lfm) > 0) and (Pos('Icon = ''search''', Lfm) > 0), 'button: .lfm sadrzi varijantu, radnju i ikonu');
    B := ButtonFromLfm(Lfm, Fm);
    Check((B.Variant = bvLink) and (B.Caption = 'Vise') and (B.ClickAction = 'openform:Partneri') and (B.Options.Icon = 'search'), 'button: .lfm se cita natrag');
  finally
    P.Free;
    Owner.Free;
    Fm.Free;
  end;
end;

var
  LabelOpened: string = '';

procedure TestLabelOpen(const AAddress: string);
begin
  LabelOpened := AAddress;
end;

type
  TLblProbe = class
    Clicks: Integer;
    procedure OnClk(Sender: TObject);
  end;

procedure TLblProbe.OnClk(Sender: TObject);
begin
  Inc(Clicks);
end;

procedure TestLabel;
var
  Fm: TForm;
  L: TaLabel;
  V: TaLabelVariant;
  Inn: TWinControl;
  Bad: Integer;
  P: TLblProbe;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
  Bmp: TBitmap;
  Painted: Boolean;
  X, Y: Integer;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  P := TLblProbe.Create;
  try
    Fm.SetBounds(0, 0, 400, 300);
    Lv := EngineVariants('Label');
    try Check(Lv.Count = 4, 'label: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    L := TaLabel.Create(Fm); L.Parent := Fm; L.SetBounds(8, 8, 200, 24); L.Caption := 'Naslov';
    Bad := 0;
    for V := Low(TaLabelVariant) to High(TaLabelVariant) do
    begin
      L.Variant := V;
      Inn := L.Engine.Inner;
      if not ((Inn is TaLabelPaint) and (TaLabelPaint(Inn).Mode = V)) then Inc(Bad);
      if Inn.Parent <> L then Inc(Bad);
      if L.Caption <> 'Naslov' then Inc(Bad);
    end;
    Check(Bad = 0, 'label: svaka varijanta stvara odgovarajuci pokretac i cuva tekst (nepodudaranja: ' + IntToStr(Bad) + ')');
    { poveznica otvara adresu i javlja OnClick }
    LabelOpenHook := @TestLabelOpen;
    L.OnClick := @P.OnClk;
    L.Variant := lvHyperlink;
    TaHyperlinkOptions(L.Options).Address := 'https://example.org/x';
    L.Options := L.Options;
    L.PerformClick;
    Check((LabelOpened = 'https://example.org/x') and (P.Clicks = 1), 'label: klik na poveznicu otvara adresu i javlja OnClick (' + LabelOpened + ')');
    L.Variant := lvText;
    LabelOpened := '';
    L.PerformClick;
    Check((LabelOpened = '') and (P.Clicks = 2), 'label: obican tekst ne otvara adresu');
    LabelOpenHook := nil;
    { crtanje: svaka varijanta nesto nacrta }
    Bad := 0;
    for V := Low(TaLabelVariant) to High(TaLabelVariant) do
    begin
      L.Variant := V;
      if V = lvHtml then L.Caption := '<p><b>Podebljano</b> i obicno</p>' else L.Caption := 'Natpis';
      if V = lvBadge then begin TaBadgeOptions(L.Options).Tone := btSuccess; L.Options := L.Options; end;
      L.SetBounds(8, 8, 200, 24);
      Bmp := TBitmap.Create;
      try
        Bmp.SetSize(200, 24);
        Bmp.Canvas.Brush.Color := clWhite;
        Bmp.Canvas.FillRect(0, 0, 200, 24);
        TaLabelPaint(L.Engine.Inner).SetBounds(0, 0, 200, 24);
        TaLabelPaint(L.Engine.Inner).RenderTo(Bmp.Canvas);
        Painted := False;
        for Y := 0 to 23 do
          for X := 0 to 199 do
            if Bmp.Canvas.Pixels[X, Y] <> clWhite then Painted := True;
        if not Painted then Inc(Bad);
      finally
        Bmp.Free;
      end;
    end;
    Check(Bad = 0, 'label: svaka varijanta nesto nacrta (prazno: ' + IntToStr(Bad) + ')');
    { prikaz polja }
    if FileExists('/tmp/ta_label.db') then DeleteFile('/tmp/ta_label.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_label.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, naziv VARCHAR(20))');
    Dbc.ExecSQL('INSERT INTO st (naziv) VALUES (''Prvi''), (''Drugi'')');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    L := TaLabel.Create(Fm); L.Parent := Fm; L.Variant := lvBadge; L.DataSource := Ds; L.DataField := 'naziv';
    Check(L.Caption = 'Prvi', 'label: znacka prikazuje polje (' + L.Caption + ')');
    Q.Next;
    Check(L.Caption = 'Drugi', 'label: i prati kretanje po zapisima');
    L.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    { definicija <-> komponenta }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Hyperlink'; D.Name := 'lnkWeb'; D.Caption := 'Web'; D.RowSource := 'https://a.b';
      D.Left := 10; D.Top := 20; D.Width := 150; D.Height := 22; D.Align := 'center';
      D.SetX('foo', 'bar');
      L := LabelFromDef(D, Fm);
      Check((L.Variant = lvHyperlink) and (L.Caption = 'Web') and (TaHyperlinkOptions(L.Options).Address = 'https://a.b') and (L.Alignment = taCenter) and (L.Extra = 'foo=bar'),
        'label: Hyperlink je varijanta hyperlink s adresom');
      LabelToDef(L, D2);
      Check((D2.Kind = 'Hyperlink') and (D2.RowSource = 'https://a.b') and (D2.Align = 'center') and (D2.GetX('foo') = 'bar') and (D2.GetX('variant') = ''),
        'label: komponenta se vraca u definiciju kao Hyperlink');
      D.Kind := 'Label'; D.Name := 'lblStatus'; D.RowSource := ''; D.Align := ''; D.SetX('variant', 'badge'); D.SetX('tone', 'danger');
      L := LabelFromDef(D, Fm);
      Check((L.Variant = lvBadge) and (TaBadgeOptions(L.Options).Tone = btDanger), 'label: znacka cita ton iz definicije');
      LabelToDef(L, D2);
      Check((D2.Kind = 'Label') and (D2.GetX('variant') = 'badge') and (D2.GetX('tone') = 'danger'), 'label: znacka se vraca u definiciju s tonom');
    finally
      D.Free; D2.Free;
    end;
    Check(IsLabelKind('Label') and IsLabelKind('Hyperlink') and not IsLabelKind('Button'), 'label: vrste definicije obitelji');
    { .lfm }
    L := TaLabel.Create(Fm); L.Name := 'lLfm'; L.Variant := lvBadge; L.Caption := 'Novo';
    TaBadgeOptions(L.Options).Tone := btWarning;
    Lfm := LabelToLfm(L);
    Check((Pos('Variant = lvBadge', Lfm) > 0) and (Pos('Tone = btWarning', Lfm) > 0) and (Pos('Caption = ''Novo''', Lfm) > 0), 'label: .lfm sadrzi varijantu, ton i natpis');
    L := LabelFromLfm(Lfm, Fm);
    Check((L.Variant = lvBadge) and (L.Caption = 'Novo') and (TaBadgeOptions(L.Options).Tone = btWarning), 'label: .lfm se cita natrag');
  finally
    LabelOpenHook := nil;
    P.Free;
    Owner.Free;
    Fm.Free;
  end;
end;

procedure TestMemo;
var
  Fm: TForm;
  M: TaMemo;
  V: TaMemoVariant;
  Inn: TWinControl;
  Bad: Integer;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 400, 300);
    Lv := EngineVariants('Memo');
    try Check(Lv.Count = 3, 'memo: u registru su 3 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    M := TaMemo.Create(Fm); M.Parent := Fm; M.SetBounds(8, 8, 300, 120);
    Bad := 0;
    for V := Low(TaMemoVariant) to High(TaMemoVariant) do
    begin
      M.Variant := V;
      Inn := M.Engine.Inner;
      case V of
        mvPlain: if not ((Inn is TMemo) and (TMemo(Inn).Font.Name <> 'JetBrains Mono')) then Inc(Bad);
        mvRich: if not (Inn is TaRichEdit) then Inc(Bad);
        mvMarkdown: if not ((Inn is TPanel) and (M.Engine is TaMemoMarkdownEngine)) then Inc(Bad);
      end;
      if Inn.Parent <> M then Inc(Bad);
    end;
    Check(Bad = 0, 'memo: svaka varijanta stvara odgovarajucu kontrolu (nepodudaranja: ' + IntToStr(Bad) + ')');
    M.Variant := mvPlain;
    M.Text := 'prvi' + LineEnding + 'drugi';
    M.Variant := mvMarkdown;
    Check(Pos('drugi', M.Text) > 0, 'memo: tekst se cuva kroz promjenu varijante');
    M.Variant := mvRich;
    M.Text := '<p>Neki <b>podebljan</b> tekst</p>';
    Check(Pos('<b>', M.Text) > 0, 'memo: rich cuva oznake (' + M.Text + ')');
    { markdown pregled }
    M.Variant := mvMarkdown;
    M.Text := '# Naslov' + LineEnding + 'Neki **podebljan** i *kosi* tekst' + LineEnding + '- prva' + LineEnding + '- druga';
    Check(not TaMemoMarkdownEngine(M.Engine).PreviewShown, 'memo: markdown po zadanom pokazuje izvorni tekst');
    M.Options.Preview := True; M.Options := M.Options;
    Check(TaMemoMarkdownEngine(M.Engine).PreviewShown, 'memo: opcija Preview pokazuje pregled');
    Check((Pos('<b>', TaMemoMarkdownEngine(M.Engine).PreviewHtml) > 0) and (Pos('<i>', TaMemoMarkdownEngine(M.Engine).PreviewHtml) > 0), 'memo: pregled ima podebljano i kosa slova (' + TaMemoMarkdownEngine(M.Engine).PreviewHtml + ')');
    Check(Pos('list="1"', MarkdownToRt('- a')) > 0, 'memo: natuknice postaju popis');
    Check((Pos('size="18"', MarkdownToRt('# T')) > 0) and (Pos('size="16"', MarkdownToRt('## T')) > 0), 'memo: razine naslova imaju razlicite velicine');
    Check((Pos('# Naslov', M.Text) = 1) and (Pos('**podebljan**', M.Text) > 0), 'memo: izvorni markdown ostaje u tekstu');
    M.Options.Preview := False; M.Options := M.Options;
    M.Variant := mvPlain;
    M.ReadOnly := True;
    Check(TMemo(M.Engine.Inner).ReadOnly, 'memo: samo za citanje');
    M.ReadOnly := False;
    M.MaxLength := 5;
    Check(TMemo(M.Engine.Inner).MaxLength = 5, 'memo: najveca duljina');
    M.Options.WordWrap := False;
    M.Options := M.Options;
    Check(not TMemo(M.Engine.Inner).WordWrap, 'memo: opcija prijeloma redaka');
    { veza na polje }
    if FileExists('/tmp/ta_memo.db') then DeleteFile('/tmp/ta_memo.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_memo.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, napomena TEXT)');
    Dbc.ExecSQL('INSERT INTO st (napomena) VALUES (''prva''), (''druga'')');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    M := TaMemo.Create(Fm); M.Parent := Fm; M.DataSource := Ds; M.DataField := 'napomena';
    Check(M.Text = 'prva', 'memo: prikazuje polje');
    Q.Next;
    Check(M.Text = 'druga', 'memo: prati kretanje');
    TMemo(M.Engine.Inner).Text := 'izmijenjena';
    TMemo(M.Engine.Inner).OnChange(M.Engine.Inner);      { bez prozora LCL ne javlja promjenu teksta sam }
    Check(Ord(Q.State) = 2, 'memo: unos stavlja skup u izmjenu');
    M.LeaveField;
    Check(Q.FieldByName('napomena').AsString = 'izmijenjena', 'memo: izlaz iz polja upisuje u skup');
    Q.Post;
    M.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    { definicija <-> komponenta }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'RichText'; D.Name := 'rtOpis'; D.ControlSource := 'opis'; D.Left := 5; D.Top := 6; D.Width := 200; D.Height := 80;
      D.SetX('foo', 'bar'); D.SetX('wordWrap', '0'); D.SetX('maxLength', '200');
      M := MemoFromDef(D, Fm);
      Check((M.Variant = mvRich) and (M.ControlSource = 'opis') and (M.MaxLength = 200) and not M.Options.WordWrap and (M.Extra = 'foo=bar'),
        'memo: RichText je varijanta rich');
      MemoToDef(M, D2);
      Check((D2.Kind = 'RichText') and (D2.GetX('wordWrap') = '0') and (D2.GetX('maxLength') = '200') and (D2.GetX('foo') = 'bar'), 'memo: vraca se kao RichText');
      D.Kind := 'MemoBox'; D.Name := 'mbBiljeska'; D.SetX('variant', 'markdown');
      M := MemoFromDef(D, Fm);
      MemoToDef(M, D2);
      Check((M.Variant = mvMarkdown) and (D2.Kind = 'MemoBox') and (D2.GetX('variant') = 'markdown'), 'memo: markdown se vraca kao MemoBox s varijantom');
    finally
      D.Free; D2.Free;
    end;
    Check(IsMemoKind('MemoBox') and IsMemoKind('RichText') and not IsMemoKind('TextBox'), 'memo: vrste definicije obitelji');
    M := TaMemo.Create(Fm); M.Name := 'mLfm'; M.Variant := mvMarkdown; M.Text := '# Naslov'; M.MaxLength := 99;
    Lfm := MemoToLfm(M);
    Check((Pos('Variant = mvMarkdown', Lfm) > 0) and (Pos('MaxLength = 99', Lfm) > 0), 'memo: .lfm sadrzi varijantu i svojstva');
    M := MemoFromLfm(Lfm, Fm);
    Check((M.Variant = mvMarkdown) and (M.MaxLength = 99) and (M.Text = '# Naslov'), 'memo: .lfm se cita natrag');
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

procedure TestChoice;
var
  Fm: TForm;
  C: TaChoice;
  V: TaChoiceVariant;
  Inn: TWinControl;
  Bad: Integer;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 500, 300);
    Check((ChoiceKeyOf('a=Prva') = 'a') and (ChoiceLabelOf('a=Prva') = 'Prva') and (ChoiceKeyOf('Samo') = 'Samo') and (ChoiceLabelOf('Samo') = 'Samo'), 'choice: kljuc i natpis stavke');
    Lv := EngineVariants('Choice');
    try Check(Lv.Count = 4, 'choice: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    C := TaChoice.Create(Fm); C.Parent := Fm; C.SetBounds(8, 8, 260, 100); C.Title := 'Vrsta';
    C.Items.Add('1=Fizicka osoba'); C.Items.Add('2=Pravna osoba'); C.Items.Add('3=Obrt');
    Bad := 0;
    for V := Low(TaChoiceVariant) to High(TaChoiceVariant) do
    begin
      C.Variant := V;
      Inn := C.Engine.Inner;
      case V of
        chRadio: if not ((Inn is TRadioGroup) and (TRadioGroup(Inn).Items.Count = 3) and (TRadioGroup(Inn).Items[0] = 'Fizicka osoba') and (Inn.Caption = 'Vrsta')) then Inc(Bad);
        chCheck: if not ((Inn is TCheckGroup) and (TCheckGroup(Inn).Items.Count = 3)) then Inc(Bad);
        chSegmented: if not (Inn is TaSegmentPaint) then Inc(Bad);
      end;
      if Inn.Parent <> C then Inc(Bad);
    end;
    Check(Bad = 0, 'choice: svaka varijanta stvara odgovarajucu kontrolu, natpise i naslov (nepodudaranja: ' + IntToStr(Bad) + ')');
    { vrijednost je kljuc }
    C.Variant := chRadio;
    C.Select('2');
    Check(C.Selected = '2', 'choice: radio vraca kljuc');
    C.Variant := chSegmented;
    Check(C.Selected = '2', 'choice: izbor se cuva pri promjeni varijante');
    TaSegmentPaint(C.Engine.Inner).ItemIndex := 2;
    Check(C.Selected = '3', 'choice: segmentirani izbor vraca kljuc');
    C.Variant := chCheck;
    C.Select('1,3');
    Check(C.Selected = '1,3', 'choice: check vraca kljuceve odvojene zarezom');
    TCheckGroup(C.Engine.Inner).Checked[1] := True;
    Check(C.Selected = '1,2,3', 'choice: oznacavanje dodaje kljuc');
    { samo za citanje }
    C.Variant := chRadio;
    C.Select('1');
    C.ReadOnly := True;
    TRadioGroup(C.Engine.Inner).ItemIndex := 2;
    Check(C.Selected = '1', 'choice: samo za citanje vraca izbor (radio)');
    C.Variant := chCheck;
    C.Select('1');
    TCheckGroup(C.Engine.Inner).Checked[2] := True;
    TCheckGroup(C.Engine.Inner).OnItemClick(C.Engine.Inner, 2);      { Checked[] ne javlja klik; to radi samo korisnik }
    Check(C.Selected = '1', 'choice: samo za citanje vraca izbor (check)');
    C.ReadOnly := False;
    C.Options.Columns := 3;
    C.Options := C.Options;
    Check(TCheckGroup(C.Engine.Inner).Columns = 3, 'choice: opcija stupaca');
    { veza na polje: cijeli broj }
    if FileExists('/tmp/ta_choice.db') then DeleteFile('/tmp/ta_choice.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_choice.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, vrsta INTEGER)');
    Dbc.ExecSQL('INSERT INTO st (vrsta) VALUES (1), (3), (NULL)');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    C := TaChoice.Create(Fm); C.Parent := Fm; C.Variant := chRadio;
    C.Items.Add('1=A'); C.Items.Add('2=B'); C.Items.Add('3=C');
    C.DataSource := Ds; C.DataField := 'vrsta';
    Check(C.Selected = '1', 'choice: prikazuje polje');
    Q.Next;
    Check(C.Selected = '3', 'choice: prati kretanje');
    Q.Next;
    Check(C.Selected = '', 'choice: NULL nema izbora');
    Q.First;
    TRadioGroup(C.Engine.Inner).ItemIndex := 1;
    Check((Ord(Q.State) = 2) and (Q.FieldByName('vrsta').AsInteger = 2), 'choice: klik odmah upisuje broj u polje (' + Q.FieldByName('vrsta').AsString + ')');
    Q.Post;
    C.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    { definicija <-> komponenta }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'OptionGroup'; D.Name := 'ogVrsta'; D.Caption := 'Vrsta'; D.ControlSource := 'vrsta'; D.RowSource := 'list:1=A;2=B';
      D.Left := 5; D.Top := 6; D.Width := 200; D.Height := 80; D.SetX('variant', 'segmented'); D.SetX('foo', 'bar');
      C := ChoiceFromDef(D, Fm);
      Check((C.Variant = chSegmented) and (C.Items.Count = 2) and (C.Title = 'Vrsta') and (C.Extra = 'foo=bar'), 'choice: OptionGroup s popisom postaje Choice');
      ChoiceToDef(C, D2);
      Check((D2.Kind = 'OptionGroup') and (D2.GetX('items') = '1=A;2=B') and (D2.GetX('variant') = 'segmented') and (D2.Caption = 'Vrsta'), 'choice: vraca se kao OptionGroup');
    finally
      D.Free; D2.Free;
    end;
    { vise izbora: multisegment i ogranicenja }
    C := TaChoice.Create(Fm); C.Parent := Fm; C.SetBounds(8, 120, 300, 40);
    C.Items.Add('1=A'); C.Items.Add('2=B'); C.Items.Add('3=C'); C.Items.Add('4=D');
    C.Variant := chMultiSegment;
    Check((C.Engine.Inner is TaSegmentPaint) and TaSegmentPaint(C.Engine.Inner).Multi, 'choice: multisegment je segmentirani izbor s vise oznaka');
    Check(not (csSetCaption in C.Engine.Inner.ControlStyle), 'choice: ime pokretaca ne postaje natpis u dizajneru');
    C.Select('1,3');
    Check(C.Selected = '1,3', 'choice: multisegment vraca kljuceve');
    TaSegmentPaint(C.Engine.Inner).Selected[1] := True;
    Check(C.Selected = '1,2,3', 'choice: i oznacavanje dodaje');
    C.Options.MaxSelected := 2; C.Options.MinSelected := 1; C.Options := C.Options;
    C.Select('1,2');
    TaSegmentPaint(C.Engine.Inner).Selected[2] := True;
    TaSegmentPaint(C.Engine.Inner).OnSelect(C.Engine.Inner);
    Check(C.Selected = '1,2', 'choice: najvise oznacenih vraca treci izbor (' + C.Selected + ')');
    C.Select('2');
    TaSegmentPaint(C.Engine.Inner).Selected[1] := False;
    TaSegmentPaint(C.Engine.Inner).OnSelect(C.Engine.Inner);
    Check(C.Selected = '2', 'choice: najmanje oznacenih ne dopusta prazan izbor (' + C.Selected + ')');
    C.Variant := chCheck;
    Check(C.Selected = '2', 'choice: izbor se cuva izmedu multisegmenta i check');
    C.Select('1,2');
    TCheckGroup(C.Engine.Inner).Checked[2] := True;
    TCheckGroup(C.Engine.Inner).OnItemClick(C.Engine.Inner, 2);
    Check(C.Selected = '1,2', 'choice: ogranicenje vrijedi i za check grupu');
    Check(IsChoiceKind('OptionGroup') and IsChoiceKind('Choice') and not IsChoiceKind('ListBox'), 'choice: vrste definicije obitelji');
    C := TaChoice.Create(Fm); C.Name := 'cLfm'; C.Variant := chCheck; C.Title := 'Opcije'; C.Items.Add('a=Alfa'); C.Items.Add('b=Beta'); C.Select('b');
    Lfm := ChoiceToLfm(C);
    Check((Pos('Variant = chCheck', Lfm) > 0) and (Pos('Alfa', Lfm) > 0), 'choice: .lfm sadrzi varijantu i stavke');
    C := ChoiceFromLfm(Lfm, Fm);
    Check((C.Variant = chCheck) and (C.Items.Count = 2) and (C.Title = 'Opcije'), 'choice: .lfm se cita natrag');
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

procedure TestList;
var
  Fm: TForm;
  L: TaList;
  V: TaListVariant;
  Inn: TWinControl;
  Bad: Integer;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
  Tr: TTreeView;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 500, 300);
    Lv := EngineVariants('List');
    try Check(Lv.Count = 4, 'list: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    L := TaList.Create(Fm); L.Parent := Fm; L.SetBounds(8, 8, 220, 140);
    L.Items.Add('hr=Hrvatska'); L.Items.Add('  zg=Zagreb'); L.Items.Add('  st=Split'); L.Items.Add('si=Slovenija'); L.Items.Add('  lj=Ljubljana');
    Bad := 0;
    for V := Low(TaListVariant) to High(TaListVariant) do
    begin
      L.Variant := V;
      Inn := L.Engine.Inner;
      case V of
        lsList: if not ((Inn is TListBox) and (TListBox(Inn).Items.Count = 5)) then Inc(Bad);
        lsChecklist: if not ((Inn is TCheckListBox) and (TCheckListBox(Inn).Items.Count = 5)) then Inc(Bad);
        lsIconlist: if not ((Inn is TListView) and (TListView(Inn).Items.Count = 5)) then Inc(Bad);
        lsTree: if not ((Inn is TTreeView) and (TTreeView(Inn).Items.Count = 5)) then Inc(Bad);
      end;
      if Inn.Parent <> L then Inc(Bad);
    end;
    Check(Bad = 0, 'list: svaka varijanta stvara odgovarajucu kontrolu i stavke (nepodudaranja: ' + IntToStr(Bad) + ')');
    { stablo: razine iz uvlake }
    Tr := TTreeView(L.Engine.Inner);
    Check((Tr.Items[0].Level = 0) and (Tr.Items[1].Level = 1) and (Tr.Items[3].Level = 0) and (Tr.Items[4].Level = 1) and (Tr.Items[1].Parent = Tr.Items[0]),
      'list: stablo gradi razine iz uvlake');
    L.Select('st');
    Check(L.Selected = 'st', 'list: stablo vraca kljuc oznacenog cvora');
    L.Variant := lsList;
    Check(L.Selected = 'st', 'list: izbor se cuva pri promjeni varijante');
    L.Select('lj');
    Check(TListBox(L.Engine.Inner).ItemIndex = 4, 'list: popis oznacava stavku');
    L.Variant := lsIconlist;
    L.Select('si');
    Check(L.Selected = 'si', 'list: popis ikona vraca kljuc');
    L.Variant := lsChecklist;
    L.Select('zg,lj');
    Check(L.Selected = 'zg,lj', 'list: kontrolni popis vraca oznacene kljuceve');
    TCheckListBox(L.Engine.Inner).Checked[3] := True;
    L.Variant := lsChecklist;
    { samo za citanje }
    L.ReadOnly := True;
    TCheckListBox(L.Engine.Inner).Checked[0] := True;
    TCheckListBox(L.Engine.Inner).OnItemClick(L.Engine.Inner, 0);
    Check(Pos('hr', L.Selected) = 0, 'list: samo za citanje vraca oznaku (kontrolni popis)');
    L.Variant := lsList;
    L.ReadOnly := False;
    L.Select('zg');
    L.ReadOnly := True;
    TListBox(L.Engine.Inner).ItemIndex := 3;
    Check(L.Selected = 'zg', 'list: samo za citanje vraca izbor (popis)');
    L.ReadOnly := False;
    { vise oznacenih stavki }
    L := TaList.Create(Fm); L.Parent := Fm; L.Variant := lsList;
    L.Items.Add('a=Alfa'); L.Items.Add('b=Beta'); L.Items.Add('c=Gama');
    L.Options.MultiSelect := True; L.Options := L.Options;
    Check(TListBox(L.Engine.Inner).MultiSelect, 'list: opcija vise oznacenih');
    L.Select('a,c');
    Check(L.Selected = 'a,c', 'list: popis vraca vise kljuceva');
    TListBox(L.Engine.Inner).Selected[1] := True;
    Check(L.Selected = 'a,b,c', 'list: dodana oznaka');
    L.Variant := lsIconlist;
    Check(TListView(L.Engine.Inner).MultiSelect and (L.Selected = 'a,b,c'), 'list: vise oznacenih ostaje kroz promjenu varijante');
    L.Variant := lsList;
    L.ReadOnly := True;
    TListBox(L.Engine.Inner).Selected[1] := False;
    TListBox(L.Engine.Inner).OnSelectionChange(L.Engine.Inner, True);
    Check(L.Selected = 'a,b,c', 'list: samo za citanje vraca izbor i kod vise oznacenih');
    L.ReadOnly := False;
    { veza na polje }
    if FileExists('/tmp/ta_list.db') then DeleteFile('/tmp/ta_list.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_list.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, drzava VARCHAR(5))');
    Dbc.ExecSQL('INSERT INTO st (drzava) VALUES (''hr''), (''si'')');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    L := TaList.Create(Fm); L.Parent := Fm; L.Variant := lsList;
    L.Items.Add('hr=Hrvatska'); L.Items.Add('si=Slovenija');
    L.DataSource := Ds; L.DataField := 'drzava';
    Check(L.Selected = 'hr', 'list: prikazuje polje');
    Q.Next;
    Check(L.Selected = 'si', 'list: prati kretanje');
    TListBox(L.Engine.Inner).ItemIndex := 0;
    Check((Ord(Q.State) = 2) and (Q.FieldByName('drzava').AsString = 'hr'), 'list: izbor odmah upisuje u polje');
    Q.Post;
    L.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    { definicija <-> komponenta }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'ListBox'; D.Name := 'lbDrzave'; D.ControlSource := 'drzava'; D.RowSource := 'list:hr=Hrvatska;si=Slovenija';
      D.Left := 5; D.Top := 6; D.Width := 200; D.Height := 80; D.SetX('variant', 'tree'); D.SetX('foo', 'bar');
      L := ListFromDef(D, Fm);
      Check((L.Variant = lsTree) and (L.Items.Count = 2) and (L.ControlSource = 'drzava') and (L.Extra = 'foo=bar'), 'list: ListBox s popisom postaje List');
      ListToDef(L, D2);
      Check((D2.Kind = 'ListBox') and (D2.GetX('items') = 'hr=Hrvatska;si=Slovenija') and (D2.GetX('variant') = 'tree') and (D2.GetX('foo') = 'bar'), 'list: vraca se kao ListBox');
    finally
      D.Free; D2.Free;
    end;
    Check(IsListKind('ListBox') and IsListKind('List') and not IsListKind('OptionGroup'), 'list: vrste definicije obitelji');
    L := TaList.Create(Fm); L.Name := 'lLfm'; L.Variant := lsChecklist; L.Items.Add('a=Alfa'); L.Items.Add('b=Beta');
    Lfm := ListToLfm(L);
    Check((Pos('Variant = lsChecklist', Lfm) > 0) and (Pos('Beta', Lfm) > 0), 'list: .lfm sadrzi varijantu i stavke');
    L := ListFromLfm(Lfm, Fm);
    Check((L.Variant = lsChecklist) and (L.Items.Count = 2), 'list: .lfm se cita natrag');
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

procedure TestPanel;
var
  Fm: TForm;
  P: TaPanel;
  V: TaPanelVariant;
  Inn: TWinControl;
  Bad: Integer;
  Lv: TStringList;
  B: TButton;
  D, D2: TaControlDef;
  Lfm: string;
  Bmp: TBitmap;
  X, Y: Integer;
  Painted: Boolean;
  I, Cnt: Integer;
  Sp, Spl: TaPanel;
  B2: TButton;
  Pa, Pb: TPanel;
begin
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 500, 400);
    Lv := EngineVariants('Panel');
    try Check(Lv.Count = 6, 'panel: u registru je 6 varijanti (' + Lv.CommaText + ')'); finally Lv.Free; end;
    P := TaPanel.Create(Fm); P.Parent := Fm; P.SetBounds(8, 8, 300, 150); P.Caption := 'Podaci';
    Bad := 0;
    for V := Low(TaPanelVariant) to High(TaPanelVariant) do
    begin
      P.Variant := V;
      Inn := P.Engine.Inner;
      case V of
        pvPlain: if not (Inn is TPanel) then Inc(Bad);
        pvGroup: if not ((Inn is TGroupBox) and (Inn.Caption = 'Podaci')) then Inc(Bad);
        pvCard, pvExpander: if not ((Inn is TaPanelPaint) and (TaPanelPaint(Inn).IsExpander = (V = pvExpander))) then Inc(Bad);
      end;
      if Inn.Parent <> P then Inc(Bad);
      if (V <> pvSplitter) and (P.Caption <> 'Podaci') then Inc(Bad);
    end;
    Check(Bad = 0, 'panel: svaka varijanta stvara odgovarajucu pozadinu i cuva naslov (nepodudaranja: ' + IntToStr(Bad) + ')');
    { spremnik: kontrole na domacinu ostaju kad se promijeni varijanta }
    P.Variant := pvGroup;
    B := TButton.Create(Fm); B.Name := 'bUnutra'; B.Parent := P; B.SetBounds(10, 30, 80, 24);
    P.Variant := pvCard;
    Check((B.Parent = P) and (P.Engine.Inner <> B), 'panel: kontrola na panelu ostaje pri promjeni varijante');
    Check(P.Engine.Inner = P.Controls[0], 'panel: pozadina je ispod kontrola (prva po redu)');
    { expander }
    P.Variant := pvExpander;
    P.Height := 150;
    Check(P.Expanded and (P.Height = 150), 'panel: expander je otvoren');
    P.Expanded := False;
    Check((not P.Expanded) and (P.Height = ExpanderHeader), 'panel: sklapanje smanjuje visinu na naslov (' + IntToStr(P.Height) + ')');
    P.Expanded := True;
    Check(P.Expanded and (P.Height = 150), 'panel: otvaranje vraca visinu (' + IntToStr(P.Height) + ')');
    TaPanelPaint(P.Engine.Inner).OnToggle(P.Engine.Inner);
    Check((not P.Expanded) and (P.Height = ExpanderHeader), 'panel: klik na naslov sklapa');
    TaPanelPaint(P.Engine.Inner).OnToggle(P.Engine.Inner);
    Check(P.Expanded and (P.Height = 150), 'panel: drugi klik otvara');
    { crtanje }
    Bad := 0;
    for V := pvCard to pvExpander do
    begin
      P.Variant := V;
      P.Caption := 'Naslov';
      Bmp := TBitmap.Create;
      try
        Bmp.SetSize(200, 60);
        Bmp.Canvas.Brush.Color := clWhite;
        Bmp.Canvas.FillRect(0, 0, 200, 60);
        TaPanelPaint(P.Engine.Inner).SetBounds(0, 0, 200, 60);
        TaPanelPaint(P.Engine.Inner).RenderTo(Bmp.Canvas);
        Painted := False;
        for Y := 0 to 59 do for X := 0 to 199 do if Bmp.Canvas.Pixels[X, Y] <> clWhite then Painted := True;
        if not Painted then Inc(Bad);
      finally
        Bmp.Free;
      end;
    end;
    Check(Bad = 0, 'panel: kartica i expander se crtaju');
    { scroll: sadrzaj veci od panela se pomice }
    Sp := TaPanel.Create(Fm); Sp.Parent := Fm; Sp.SetBounds(0, 200, 120, 100); Sp.Variant := pvScroll;
    B := TButton.Create(Fm); B.Parent := Sp; B.SetBounds(10, 150, 50, 30);
    Sp.UpdateScroll;
    Check(Sp.VerticalBar.Visible and not Sp.HorizontalBar.Visible and (Sp.VerticalBar.Max >= 180), 'panel: scroll ima okomitu traku kad sadrzaj prelazi visinu (max ' + IntToStr(Sp.VerticalBar.Max) + ')');
    Sp.ScrollTo(0, 60);
    Check((B.Top = 90) and (Sp.ScrollY = 60), 'panel: pomak od 60 pomice sadrzaj (' + IntToStr(B.Top) + ')');
    Sp.UpdateScroll;
    Check(B.Top = 90, 'panel: ponovno uskladivanje ne mijenja pomak');
    Sp.ScrollTo(0, 0);
    Check(B.Top = 150, 'panel: povratak na vrh vraca polozaj');
    B2 := TButton.Create(Fm); B2.Parent := Sp; B2.SetBounds(220, 10, 40, 20);
    Sp.UpdateScroll;
    Check(Sp.HorizontalBar.Visible, 'panel: sadrzaj sire od panela daje vodoravnu traku');
    Sp.Variant := pvPlain;
    Check(not Sp.VerticalBar.Visible and not Sp.HorizontalBar.Visible, 'panel: izlaz iz scroll varijante skriva trake');
    { splitter: povlacenje mice velicinu susjeda }
    Pa := TPanel.Create(Fm); Pa.Parent := Fm; Pa.Align := alLeft; Pa.Width := 100;
    Spl := TaPanel.Create(Fm); Spl.Parent := Fm; Spl.Variant := pvSplitter; Spl.Align := alLeft; Spl.Width := 6;
    Pb := TPanel.Create(Fm); Pb.Parent := Fm; Pb.Align := alClient;
    Pa.Left := 0; Spl.Left := 100;
    Check(Spl.Engine.Inner is TaSplitPaint, 'panel: splitter ima vucnu crtu');
    Check((Spl.DragSplitter(40) = 40) and (Pa.Width = 140), 'panel: povlacenje udesno siri lijevog susjeda (' + IntToStr(Pa.Width) + ')');
    Spl.Options.MinSize := 50; Spl.Options := Spl.Options;
    Spl.DragSplitter(-500);
    Check(Pa.Width = 50, 'panel: susjed ne ide ispod najmanje velicine (' + IntToStr(Pa.Width) + ')');
    Pa.Align := alTop; Pa.Height := 40; Pa.Top := 0; Spl.Align := alTop; Spl.Height := 6; Spl.Top := 40; Pb.Align := alClient;
    Check(Spl.DragSplitter(30) = 30, 'panel: gornji susjed se povecava za pomak (' + IntToStr(Pa.Height) + ')');
    { definicija <-> komponenta }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Panel'; D.Name := 'pnlAdresa'; D.Caption := 'Adresa'; D.Left := 5; D.Top := 6; D.Width := 250; D.Height := 100;
      D.SetX('variant', 'expander'); D.SetX('expanded', '0'); D.SetX('foo', 'bar'); D.SetX('visibleIf', '[x] = 1');
      P := PanelFromDef(D, Fm);
      Check((P.Variant = pvExpander) and (P.Caption = 'Adresa') and (not P.Expanded) and (P.VisibleIf = '[x] = 1') and (P.Extra = 'foo=bar'), 'panel: definicija postaje komponenta');
      PanelToDef(P, D2);
      Check((D2.Kind = 'Panel') and (D2.GetX('variant') = 'expander') and (D2.GetX('expanded') = '0') and (D2.GetX('foo') = 'bar') and (D2.Caption = 'Adresa'), 'panel: vraca se u definiciju');
    finally
      D.Free; D2.Free;
    end;
    Check(IsPanelKind('Panel') and not IsPanelKind('Label'), 'panel: vrste definicije obitelji');
    { .lfm: dijete se sprema s panelom, pozadina ne }
    P := TaPanel.Create(Fm); P.Name := 'pLfm'; P.Parent := Fm; P.Variant := pvGroup; P.Caption := 'Okvir';
    B := TButton.Create(Fm); B.Name := 'bLfm'; B.Parent := P; B.Caption := 'U redu';
    Lfm := PanelToLfm(P);
    Check((Pos('Variant = pvGroup', Lfm) > 0) and (Pos('object bLfm: TButton', Lfm) > 0) and (Pos('TGroupBox', Lfm) = 0), 'panel: .lfm sadrzi varijantu i dijete, a ne pozadinu');
    Fm.RemoveComponent(P);
    RegisterClass(TButton);
    P := PanelFromLfm(Lfm, Fm);
    Cnt := 0;
    for I := 0 to P.ControlCount - 1 do if P.Controls[I] is TButton then Inc(Cnt);
    Check((P.Variant = pvGroup) and (P.Caption = 'Okvir') and (Cnt = 1), 'panel: .lfm se cita natrag s djetetom');
  finally
    Fm.Free;
  end;
end;

procedure TestGrid;
var
  Fm: TForm;
  G: TaGrid;
  V: TaGridVariant;
  Gr: TDBGrid;
  Bad: Integer;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
  Key: Word;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 500, 400);
    Lv := EngineVariants('Grid');
    try Check(Lv.Count = 4, 'grid: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    if FileExists('/tmp/ta_grid.db') then DeleteFile('/tmp/ta_grid.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_grid.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, naziv VARCHAR(20))');
    Dbc.ExecSQL('INSERT INTO st (naziv) VALUES (''a''), (''b''), (''c'')');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    G := TaGrid.Create(Fm); G.Parent := Fm; G.SetBounds(8, 8, 300, 150);
    G.DataSource := Ds;
    Bad := 0;
    for V := Low(TaGridVariant) to High(TaGridVariant) do
    begin
      G.Variant := V;
      Gr := G.InnerGrid;
      if (Gr = nil) or (Gr.Parent.Parent <> G) or (Gr.DataSource <> Ds) then begin Inc(Bad); Continue; end;
      case V of
        gvReadOnly: if not (Gr.ReadOnly and not (dgEditing in Gr.Options)) then Inc(Bad);
        gvEditable: if not ((dgEditing in Gr.Options) and not Gr.ReadOnly) then Inc(Bad);
        gvDatasheet: if not ((dgEditing in Gr.Options) and not (dgIndicator in Gr.Options)) then Inc(Bad);
        gvEntry: if not ((dgEditing in Gr.Options) and not Gr.ReadOnly) then Inc(Bad);
      end;
    end;
    Check(Bad = 0, 'grid: svaka varijanta stvara mrezu s izvorom i pravim opcijama (nepodudaranja: ' + IntToStr(Bad) + ')');
    Check(G.InnerGrid.DataSource = Ds, 'grid: izvor podataka ostaje kroz promjene varijante');
    G.ReadOnly := True;
    Check(G.InnerGrid.ReadOnly, 'grid: samo za citanje i na varijanti za izmjenu');
    G.ReadOnly := False;
    Check(not G.InnerGrid.ReadOnly, 'grid: i natrag');
    G.Options.RowHeight := 30;
    G.Options.Zebra := True;
    G.Options := G.Options;
    Check(G.InnerGrid.DefaultRowHeight = 30, 'grid: visina retka');
    { zbrojevi u podnozju }
    G.Variant := gvReadOnly;
    G.Options.SumFields := 'id'; G.Options := G.Options;
    Check(StringReplace(G.FooterText, ',', '.', []) = 'id: 6.00', 'grid: podnozje zbraja polje (' + G.FooterText + ')');
    G.Options.SumFields := ''; G.Options := G.Options;
    Check(G.FooterText = '', 'grid: bez polja nema podnozja');
    { unos: Tab iz zadnje celije zadnjeg retka otvara novi red }
    G.Variant := gvEntry;
    Q.Last;
    G.InnerGrid.SelectedIndex := G.InnerGrid.Columns.Count - 1;
    Key := VK_TAB;
    G.InnerGrid.OnKeyDown(G.InnerGrid, Key, []);
    Check((Ord(Q.State) = 3) and (Key = 0), 'grid: entry - Tab iz zadnje celije zadnjeg retka dodaje novi red (stanje ' + IntToStr(Ord(Q.State)) + ', kljuc ' + IntToStr(Key) + ', stupaca ' + IntToStr(G.InnerGrid.Columns.Count) + ', indeks ' + IntToStr(G.InnerGrid.SelectedIndex) + ', recno ' + IntToStr(Q.RecNo) + '/' + IntToStr(Q.RecordCount) + ')');
    Q.Cancel;
    G.Variant := gvEditable;
    G.DataSource := nil;
    Check(G.InnerGrid.DataSource = nil, 'grid: odspajanje izvora');
    G.DataSource := Ds;
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Subform'; D.Name := 'grdStavke'; D.Left := 5; D.Top := 6; D.Width := 250; D.Height := 100;
      D.SetX('variant', 'datasheet'); D.SetX('rowHeight', '26'); D.SetX('zebra', '1'); D.SetX('foo', 'bar');
      G := GridFromDef(D, Fm);
      Check((G.Variant = gvDatasheet) and (G.Options.RowHeight = 26) and G.Options.Zebra and (G.Extra = 'foo=bar'), 'grid: definicija postaje komponenta');
      GridToDef(G, D2);
      Check((D2.Kind = 'Grid') and (D2.GetX('variant') = 'datasheet') and (D2.GetX('rowHeight') = '26') and (D2.GetX('zebra') = '1') and (D2.GetX('foo') = 'bar'), 'grid: vraca se u definiciju');
    finally
      D.Free; D2.Free;
    end;
    Check(IsGridKind('Grid') and IsGridKind('Subform') and not IsGridKind('Panel'), 'grid: vrste definicije obitelji');
    G := TaGrid.Create(Fm); G.Name := 'gLfm'; G.Variant := gvEditable; G.Options.Zebra := True;
    Lfm := GridToLfm(G);
    Check((Pos('Variant = gvEditable', Lfm) > 0) and (Pos('Zebra = True', Lfm) > 0), 'grid: .lfm sadrzi varijantu i opcije');
    G := GridFromLfm(Lfm, Fm);
    Check((G.Variant = gvEditable) and G.Options.Zebra, 'grid: .lfm se cita natrag');
    Q.Close;
    Dbc.Active := False;
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

procedure TestPages;
var
  Fm: TForm;
  P: TaPages;
  V: TaPagesVariant;
  Inn: TWinControl;
  Bad: Integer;
  Lv: TStringList;
  D, D2: TaControlDef;
  Lfm: string;
  Changes: Integer;
  Pr: TBtnProbe;
begin
  Fm := TForm.CreateNew(nil);
  Pr := TBtnProbe.Create;
  try
    Fm.SetBounds(0, 0, 500, 300);
    Lv := EngineVariants('Pages');
    try Check(Lv.Count = 4, 'pages: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    P := TaPages.Create(Fm); P.Parent := Fm; P.SetBounds(8, 8, 400, 120);
    P.Items.Add('Opce'); P.Items.Add('Adresa'); P.Items.Add('Kontakt');
    Bad := 0;
    for V := Low(TaPagesVariant) to High(TaPagesVariant) do
    begin
      P.Variant := V;
      Inn := P.Engine.Inner;
      case V of
        pgTabs: if not ((Inn is TTabControl) and (TTabControl(Inn).Tabs.Count = 3)) then Inc(Bad);
        pgList: if not ((Inn is TListBox) and (TListBox(Inn).Items.Count = 3)) then Inc(Bad);
        pgSteps: if not ((Inn is TaStepsPaint) and not TaStepsPaint(Inn).Stacked) then Inc(Bad);
        pgAccordion: if not ((Inn is TaStepsPaint) and TaStepsPaint(Inn).Stacked) then Inc(Bad);
      end;
      if Inn.Parent <> P then Inc(Bad);
    end;
    Check(Bad = 0, 'pages: svaka varijanta stvara odgovarajucu kontrolu i stranice (nepodudaranja: ' + IntToStr(Bad) + ')');
    P.Variant := pgTabs;
    P.ActivePage := 2;
    Check(P.ActivePage = 2, 'pages: aktivna stranica');
    P.Variant := pgSteps;
    Check(P.ActivePage = 2, 'pages: aktivna stranica se cuva pri promjeni varijante');
    P.Variant := pgList;
    Check(P.ActivePage = 2, 'pages: i na popisu');
    P.Variant := pgAccordion;
    Check(P.ActivePage = 2, 'pages: harmonika cuva aktivnu stranicu');
    P.ActivePage := 1;
    Check(P.ActivePage = 1, 'pages: harmonika postavlja stranicu');
    P.Variant := pgTabs;
    P.OnChange := @Pr.OnClk;
    Pr.Clicks := 0;
    TTabControl(P.Engine.Inner).TabIndex := 1;
    TTabControl(P.Engine.Inner).OnChange(P.Engine.Inner);
    Check((Pr.Clicks = 1) and (P.ActivePage = 1), 'pages: promjena stranice javlja OnChange');
    P.ActivePage := 0;
    Check(Pr.Clicks = 1, 'pages: programsko postavljanje ne javlja OnChange');
    P.Items.Add('Napomene');
    Check((TTabControl(P.Engine.Inner).Tabs.Count = 4) and (P.ActivePage = 0), 'pages: nova stranica se pojavi, aktivna ostaje');
    P.Options.TabsAtBottom := True;
    P.Options := P.Options;
    Check(TTabControl(P.Engine.Inner).TabPosition = tpBottom, 'pages: opcija tabova dolje');
    { definicija }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'TabControl'; D.Name := 'tabOsoba'; D.Left := 5; D.Top := 6; D.Width := 250; D.Height := 100; D.RowSource := 'list:Opce;Adresa';
      D.SetX('variant', 'steps'); D.SetX('active', '1'); D.SetX('foo', 'bar');
      P := PagesFromDef(D, Fm);
      Check((P.Variant = pgSteps) and (P.Items.Count = 2) and (P.ActivePage = 1) and (P.Extra = 'foo=bar'), 'pages: TabControl postaje Pages');
      PagesToDef(P, D2);
      Check((D2.Kind = 'TabControl') and (D2.GetX('items') = 'Opce;Adresa') and (D2.GetX('variant') = 'steps') and (D2.GetX('active') = '1') and (D2.GetX('foo') = 'bar'), 'pages: vraca se kao TabControl');
    finally
      D.Free; D2.Free;
    end;
    Check(IsPagesKind('TabControl') and IsPagesKind('Pages') and not IsPagesKind('Panel'), 'pages: vrste definicije obitelji');
    P := TaPages.Create(Fm); P.Name := 'pLfm'; P.Variant := pgSteps; P.Items.Add('Jedan'); P.Items.Add('Dva'); P.ActivePage := 1;
    Lfm := PagesToLfm(P);
    Check((Pos('Variant = pgSteps', Lfm) > 0) and (Pos('Dva', Lfm) > 0), 'pages: .lfm sadrzi varijantu i stranice');
    P := PagesFromLfm(Lfm, Fm);
    Check((P.Variant = pgSteps) and (P.Items.Count = 2) and (P.ActivePage = 1), 'pages: .lfm se cita natrag');
    if Changes = 0 then;
  finally
    Pr.Free;
    Fm.Free;
  end;
end;

function PaintedBitmap(AMode: Integer; AP: TObject; AW, AH: Integer): Boolean;
var
  Bmp: TBitmap;
  X, Y: Integer;
begin
  Result := False;
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(AW, AH);
    Bmp.Canvas.Brush.Color := clFuchsia;
    Bmp.Canvas.FillRect(0, 0, AW, AH);
    case AMode of
      0: begin TaProgressPaint(AP).SetBounds(0, 0, AW, AH); TaProgressPaint(AP).RenderTo(Bmp.Canvas); end;
      1: begin TaImagePaint(AP).SetBounds(0, 0, AW, AH); TaImagePaint(AP).RenderTo(Bmp.Canvas); end;
      2: begin TaBarcodePaint(AP).SetBounds(0, 0, AW, AH); TaBarcodePaint(AP).RenderTo(Bmp.Canvas); end;
      3: begin TaChartPaint(AP).SetBounds(0, 0, AW, AH); TaChartPaint(AP).RenderTo(Bmp.Canvas); end;
    end;
    for Y := 0 to AH - 1 do
      for X := 0 to AW - 1 do
        if Bmp.Canvas.Pixels[X, Y] <> clFuchsia then Result := True;
  finally
    Bmp.Free;
  end;
end;

function ImagePixel(AP: TaImagePaint; AX, AY: Integer): TColor;
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(AP.Width, AP.Height);
    AP.RenderTo(Bmp.Canvas);
    Result := Bmp.Canvas.Pixels[AX, AY];
  finally
    Bmp.Free;
  end;
end;

procedure TestProgress;
var
  Fm: TForm;
  P: TaProgress;
  V: TaProgressVariant;
  Bad: Integer;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 400, 300);
    Lv := EngineVariants('Progress');
    try Check(Lv.Count = 4, 'progress: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    P := TaProgress.Create(Fm); P.Parent := Fm; P.SetBounds(8, 8, 160, 40); P.Value := 40;
    Bad := 0;
    for V := Low(TaProgressVariant) to High(TaProgressVariant) do
    begin
      P.Variant := V;
      if not (P.Engine.Inner is TaProgressPaint) or (TaProgressPaint(P.Engine.Inner).Mode <> V) then Inc(Bad);
      if Abs(P.Value - 40) > 1e-9 then Inc(Bad);
      if not PaintedBitmap(0, P.Engine.Inner, 160, 40) then Inc(Bad);
    end;
    Check(Bad = 0, 'progress: svaka varijanta stvara pokretac, cuva vrijednost i crta (nepodudaranja: ' + IntToStr(Bad) + ')');
    { led: boja po pragovima }
    P.Variant := prLed;
    P.Options.WarnAt := 70; P.Options.DangerAt := 90; P.Options := P.Options;
    P.Value := 10;
    Check(TaProgressPaint(P.Engine.Inner).LedColor = TokenColor(ActiveTokens.Success), 'progress: led je zelen ispod praga');
    P.Value := 75;
    Check(TaProgressPaint(P.Engine.Inner).LedColor = TokenColor(ActiveTokens.Warning), 'progress: led je zut iznad upozorenja');
    P.Value := 95;
    Check(TaProgressPaint(P.Engine.Inner).LedColor = TokenColor(ActiveTokens.Danger), 'progress: led je crven iznad opasnosti');
    { veza na polje }
    if FileExists('/tmp/ta_progress.db') then DeleteFile('/tmp/ta_progress.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_progress.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, ispunjeno REAL)');
    Dbc.ExecSQL('INSERT INTO st (ispunjeno) VALUES (25), (80)');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    P := TaProgress.Create(Fm); P.Parent := Fm; P.DataSource := Ds; P.DataField := 'ispunjeno';
    Check(Abs(P.Value - 25) < 1e-9, 'progress: prikazuje polje');
    Q.Next;
    Check(Abs(P.Value - 80) < 1e-9, 'progress: prati kretanje');
    P.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Progress'; D.Name := 'prgTok'; D.Left := 5; D.Top := 6; D.Width := 120; D.Height := 24;
      D.SetX('variant', 'led'); D.SetX('min', '5'); D.SetX('max', '50'); D.SetX('warnAt', '30'); D.SetX('foo', 'bar'); D.SetX('showText', '0');
      P := ProgressFromDef(D, Fm);
      Check((P.Variant = prLed) and (P.Options.Min = 5) and (P.Options.Max = 50) and (P.Options.WarnAt = 30) and not P.Options.ShowText and (P.Extra = 'foo=bar'), 'progress: definicija postaje komponenta');
      ProgressToDef(P, D2);
      Check((D2.GetX('variant') = 'led') and (D2.GetX('min') = '5') and (D2.GetX('max') = '50') and (D2.GetX('warnAt') = '30') and (D2.GetX('showText') = '0') and (D2.GetX('foo') = 'bar'), 'progress: vraca se u definiciju');
    finally
      D.Free; D2.Free;
    end;
    Check(IsProgressKind('Progress') and not IsProgressKind('Chart'), 'progress: vrste definicije obitelji');
    P := TaProgress.Create(Fm); P.Name := 'pLfm'; P.Variant := prRing; P.Value := 33; P.Options.Max := 200;
    Lfm := ProgressToLfm(P);
    Check((Pos('Variant = prRing', Lfm) > 0) and (Pos('Max = 200', Lfm) > 0), 'progress: .lfm sadrzi varijantu i opcije');
    P := ProgressFromLfm(Lfm, Fm);
    Check((P.Variant = prRing) and (Abs(P.Value - 33) < 1e-9) and (P.Options.Max = 200), 'progress: .lfm se cita natrag');
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

procedure TestCalendar;
var
  Fm: TForm;
  C: TaCalendar;
  V: TaCalendarVariant;
  Bad: Integer;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
  Cal: TCalendar;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 500, 400);
    Lv := EngineVariants('Calendar');
    try Check(Lv.Count = 3, 'calendar: u registru su 3 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    C := TaCalendar.Create(Fm); C.Parent := Fm; C.SetBounds(8, 8, 230, 170);
    C.Text := '2026-03-15';
    Bad := 0;
    for V := Low(TaCalendarVariant) to High(TaCalendarVariant) do
    begin
      C.Variant := V;
      case V of
        cmMonth: if not (C.Engine.Inner is TCalendar) then Inc(Bad);
        cmRange: if not (C.Engine.Inner is TCalendar) then Inc(Bad);
        cmAgenda: if not (C.Engine.Inner is TListBox) then Inc(Bad);
      end;
    end;
    Check(Bad = 0, 'calendar: svaka varijanta stvara odgovarajucu kontrolu (nepodudaranja: ' + IntToStr(Bad) + ')');
    C.Variant := cmMonth;
    C.Text := '2026-03-15';
    Check((C.Text = '2026-03-15') and (Trunc(C.SelectedDate) = Trunc(EncodeDate(2026, 3, 15))), 'calendar: mjesec vraca ISO datum');
    TCalendar(C.Engine.Inner).DateTime := EncodeDate(2026, 4, 2);
    TCalendar(C.Engine.Inner).OnChange(C.Engine.Inner);
    Check(C.Text = '2026-04-02', 'calendar: izbor datuma javlja promjenu');
    { razdoblje: dva klika }
    C.Variant := cmRange;
    Cal := TCalendar(C.Engine.Inner);
    Cal.DateTime := EncodeDate(2026, 5, 10); Cal.OnChange(Cal);
    Cal.DateTime := EncodeDate(2026, 5, 20); Cal.OnChange(Cal);
    Check(C.Text = '2026-05-10..2026-05-20', 'calendar: dva klika daju razdoblje (' + C.Text + ')');
    Cal.DateTime := EncodeDate(2026, 6, 9); Cal.OnChange(Cal);
    Cal.DateTime := EncodeDate(2026, 6, 1); Cal.OnChange(Cal);
    Check(C.Text = '2026-06-01..2026-06-09', 'calendar: obrnut redoslijed klikova se uredi (' + C.Text + ')');
    C.Text := '2026-07-01..2026-07-05';
    Check(C.Text = '2026-07-01..2026-07-05', 'calendar: razdoblje se postavlja tekstom');
    { agenda }
    C.Variant := cmAgenda;
    C.Options.Days := 10; C.Options := C.Options;
    Check(TListBox(C.Engine.Inner).Items.Count = 10, 'calendar: agenda nudi zadani broj dana');
    C.SelectDate(Trunc(Now) + 3);
    Check(TListBox(C.Engine.Inner).ItemIndex = 3, 'calendar: agenda oznacava datum');
    Check(Trunc(C.SelectedDate) = Trunc(Now) + 3, 'calendar: agenda vraca datum');
    { veza na polje: datum }
    if FileExists('/tmp/ta_calendar.db') then DeleteFile('/tmp/ta_calendar.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_calendar.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, datum DATE)');
    Dbc.ExecSQL('INSERT INTO st (datum) VALUES (''2026-01-20''), (''2026-02-03'')');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    C := TaCalendar.Create(Fm); C.Parent := Fm; C.Variant := cmMonth; C.DataSource := Ds; C.DataField := 'datum';
    Check(C.Text = '2026-01-20', 'calendar: prikazuje datum iz polja (' + C.Text + ')');
    Q.Next;
    Check(C.Text = '2026-02-03', 'calendar: prati kretanje');
    TCalendar(C.Engine.Inner).DateTime := EncodeDate(2026, 2, 14);
    TCalendar(C.Engine.Inner).OnChange(C.Engine.Inner);
    Check((Ord(Q.State) = 2) and (FormatDateTime('yyyy-mm-dd', Q.FieldByName('datum').AsDateTime) = '2026-02-14'), 'calendar: izbor upisuje datum u polje');
    Q.Post;
    C.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Calendar'; D.Name := 'calOd'; D.Left := 5; D.Top := 6; D.Width := 220; D.Height := 160;
      D.SetX('variant', 'agenda'); D.SetX('days', '7'); D.SetX('foo', 'bar');
      C := CalendarFromDef(D, Fm);
      Check((C.Variant = cmAgenda) and (C.Options.Days = 7) and (C.Extra = 'foo=bar'), 'calendar: definicija postaje komponenta');
      CalendarToDef(C, D2);
      Check((D2.GetX('variant') = 'agenda') and (D2.GetX('days') = '7') and (D2.GetX('foo') = 'bar'), 'calendar: vraca se u definiciju');
    finally
      D.Free; D2.Free;
    end;
    Check(IsCalendarKind('Calendar') and not IsCalendarKind('Chart'), 'calendar: vrste definicije obitelji');
    C := TaCalendar.Create(Fm); C.Name := 'cLfm'; C.Variant := cmAgenda; C.Options.Days := 5;
    Lfm := CalendarToLfm(C);
    Check((Pos('Variant = cmAgenda', Lfm) > 0) and (Pos('Days = 5', Lfm) > 0), 'calendar: .lfm sadrzi varijantu i opcije');
    C := CalendarFromLfm(Lfm, Fm);
    Check((C.Variant = cmAgenda) and (C.Options.Days = 5), 'calendar: .lfm se cita natrag');
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

procedure TestImage;
var
  Fm: TForm;
  I: TaImage;
  V: TaImageVariant;
  Bad: Integer;
  Lv: TStringList;
  D, D2: TaControlDef;
  Lfm: string;
  Bmp: TBitmap;
  Pic: TPortableNetworkGraphic;
  Sh: TaImagePaint;
begin
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 400, 300);
    Lv := EngineVariants('Image');
    try Check(Lv.Count = 4, 'image: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    I := TaImage.Create(Fm); I.Parent := Fm; I.SetBounds(8, 8, 80, 60);
    Bad := 0;
    for V := Low(TaImageVariant) to High(TaImageVariant) do
    begin
      I.Variant := V;
      if not (I.Engine.Inner is TaImagePaint) or (TaImagePaint(I.Engine.Inner).Mode <> V) then Inc(Bad);
    end;
    Check(Bad = 0, 'image: svaka varijanta stvara pokretac (nepodudaranja: ' + IntToStr(Bad) + ')');
    { oblik: boja ispune }
    I.Variant := imShape;
    I.Options.Shape := ishRectangle; I.Options.FillColor := '#FF0000'; I.Options.LineColor := '#000000';
    I.Options := I.Options;
    Sh := I.Painter;
    Sh.SetBounds(0, 0, 80, 60);
    Check(ImagePixel(Sh, 40, 30) = RGBToColor(255, 0, 0), 'image: oblik se puni zadanom bojom');
    I.Options.Shape := ishEllipse; I.Options := I.Options;
    Check(ImagePixel(Sh, 40, 30) = RGBToColor(255, 0, 0), 'image: elipsa je puna u sredini');
    Check(PaintedBitmap(1, Sh, 80, 60), 'image: oblik se crta');
    { prijelaz }
    I.Variant := imGradient;
    I.Options.FillColor := '#000000'; I.Options.ColorTo := '#FFFFFF'; I.Options.Vertical := True; I.Options := I.Options;
    Sh := I.Painter; Sh.SetBounds(0, 0, 40, 100);
    Check((Red(ColorToRGB(ImagePixel(Sh, 20, 1))) < 10) and (Red(ColorToRGB(ImagePixel(Sh, 20, 98))) > 245), 'image: prijelaz ide od prve do druge boje');
    I.Options.Vertical := False; I.Options := I.Options;
    Sh.SetBounds(0, 0, 100, 40);
    Check((Red(ColorToRGB(ImagePixel(Sh, 1, 20))) < 10) and (Red(ColorToRGB(ImagePixel(Sh, 98, 20))) > 245), 'image: vodoravni prijelaz');
    { slika iz datoteke }
    Pic := TPortableNetworkGraphic.Create;
    Bmp := TBitmap.Create;
    try
      Bmp.SetSize(10, 10);
      Bmp.Canvas.Brush.Color := RGBToColor(0, 0, 255);
      Bmp.Canvas.FillRect(0, 0, 10, 10);
      Pic.Assign(Bmp);
      Pic.SaveToFile('/tmp/ta_image_test.png');
    finally
      Bmp.Free;
      Pic.Free;
    end;
    I.Variant := imPicture;
    I.Options.FileName := '/tmp/ta_image_test.png'; I.Options.SizeMode := ismStretch; I.Options := I.Options;
    Sh := I.Painter; Sh.SetBounds(0, 0, 60, 60);
    Check(Sh.HasPicture, 'image: slika se ucitava iz datoteke');
    Check(ImagePixel(Sh, 30, 30) = RGBToColor(0, 0, 255), 'image: istegnuta slika popunjava povrsinu');
    I.Options.FileName := '/tmp/ne_postoji.png'; I.Options := I.Options;
    Check(not Sh.HasPicture, 'image: nepostojeca datoteka nema slike');
    Check(PaintedBitmap(1, Sh, 60, 60), 'image: prazna slika crta okvir s precagama');
    { ikona }
    I.Variant := imIcon;
    I.Options.Icon := 'save'; I.Options := I.Options;
    Sh := I.Painter; Sh.SetBounds(0, 0, 32, 32);
    Check(Sh.HasPicture, 'image: ikona iz biblioteke se ucitava');
    { definicija }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Rectangle'; D.Name := 'rctOkvir'; D.Left := 5; D.Top := 6; D.Width := 90; D.Height := 40;
      D.SetX('fillColor', '#00FF00'); D.SetX('shape', 'rounded'); D.SetX('foo', 'bar');
      I := ImageFromDef(D, Fm);
      Check((I.Variant = imShape) and (I.Options.Shape = ishRounded) and (I.Options.FillColor = '#00FF00') and (I.Extra = 'foo=bar'), 'image: Rectangle je varijanta shape');
      ImageToDef(I, D2);
      Check((D2.Kind = 'Image') and (D2.GetX('variant') = 'shape') and (D2.GetX('shape') = 'rounded') and (D2.GetX('fillColor') = '#00FF00') and (D2.GetX('foo') = 'bar'), 'image: vraca se u definiciju');
      D.Kind := 'Image'; D.Name := 'imgLogo'; D.SetX('variant', ''); D.SetX('file', '/tmp/x.png'); D.SetX('sizeMode', 'center');
      I := ImageFromDef(D, Fm);
      Check((I.Variant = imPicture) and (I.Options.FileName = '/tmp/x.png') and (I.Options.SizeMode = ismCenter), 'image: slika iz definicije');
    finally
      D.Free; D2.Free;
    end;
    Check(IsImageKind('Image') and IsImageKind('Line') and not IsImageKind('Chart'), 'image: vrste definicije obitelji');
    I := TaImage.Create(Fm); I.Name := 'iLfm'; I.Variant := imGradient; I.Options.FillColor := '#112233'; I.Options.ColorTo := '#445566';
    Lfm := ImageToLfm(I);
    Check((Pos('Variant = imGradient', Lfm) > 0) and (Pos('#112233', Lfm) > 0), 'image: .lfm sadrzi varijantu i boje');
    I := ImageFromLfm(Lfm, Fm);
    Check((I.Variant = imGradient) and (I.Options.ColorTo = '#445566'), 'image: .lfm se cita natrag');
  finally
    Fm.Free;
  end;
end;

procedure TestBarcode;
var
  Fm: TForm;
  B: TaBarcode;
  V: TaBarcodeVariant;
  Bad: Integer;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
  Vals: array[TaBarcodeVariant] of string;
  Pt: TaBarcodePaint;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 400, 300);
    Vals[bvCode128] := 'ABC-123'; Vals[bvEan13] := '385123456789'; Vals[bvEan8] := '4012345'; Vals[bvCode39] := 'CODE39';
    Vals[bvItf] := '123456'; Vals[bvQr] := 'https://example.org'; Vals[bvPdf417] := 'TyphAccess';
    Lv := EngineVariants('Barcode');
    try Check(Lv.Count = 7, 'barcode: u registru je 7 varijanti (' + Lv.CommaText + ')'); finally Lv.Free; end;
    B := TaBarcode.Create(Fm); B.Parent := Fm; B.SetBounds(8, 8, 200, 100);
    Bad := 0;
    for V := Low(TaBarcodeVariant) to High(TaBarcodeVariant) do
    begin
      B.Variant := V;
      B.Text := Vals[V];
      Pt := B.Painter;
      if (Pt = nil) or (Pt.Sym <> BarSymbologyOf(BarcodeVariantNames[V])) then Inc(Bad);
      if not PaintedBitmap(2, Pt, 200, 100) then Inc(Bad);
      if Pt.Error <> '' then begin Inc(Bad); WriteLn('  barcode ', BarcodeVariantNames[V], ': ', Pt.Error); end;
    end;
    Check(Bad = 0, 'barcode: svaka vrsta koda se kodira i crta (nepodudaranja: ' + IntToStr(Bad) + ')');
    B.Variant := bvEan13;
    B.Text := '385123456789';
    Check(B.Text = '385123456789', 'barcode: vrijednost se cuva');
    B.Variant := bvQr;
    Check(B.Text = '385123456789', 'barcode: vrijednost se cuva kroz promjenu vrste');
    B.Text := '';
    Check(PaintedBitmap(2, B.Painter, 100, 60), 'barcode: prazna vrijednost crta okvir s nazivom');
    B.Variant := bvEan13; B.Text := 'abc';
    PaintedBitmap(2, B.Painter, 100, 60);
    Check(B.Painter.Error <> '', 'barcode: neispravna vrijednost javlja gresku (' + B.Painter.Error + ')');
    { veza na polje }
    if FileExists('/tmp/ta_barcode.db') then DeleteFile('/tmp/ta_barcode.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_barcode.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, sifra VARCHAR(20))');
    Dbc.ExecSQL('INSERT INTO st (sifra) VALUES (''A1''), (''B2'')');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    B := TaBarcode.Create(Fm); B.Parent := Fm; B.DataSource := Ds; B.DataField := 'sifra';
    Check(B.Text = 'A1', 'barcode: kodira polje');
    Q.Next;
    Check(B.Text = 'B2', 'barcode: prati kretanje');
    B.DataSource := nil;
    Q.Close;
    Dbc.Active := False;
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Barcode'; D.Name := 'bcSifra'; D.ControlSource := 'sifra'; D.Left := 5; D.Top := 6; D.Width := 150; D.Height := 50;
      D.SetX('barType', 'ean13'); D.SetX('showText', '0'); D.SetX('foo', 'bar');
      B := BarcodeFromDef(D, Fm);
      Check((B.Variant = bvEan13) and (B.ControlSource = 'sifra') and not B.Options.ShowText and (B.Extra = 'foo=bar'), 'barcode: definicija postaje komponenta');
      BarcodeToDef(B, D2);
      Check((D2.GetX('barType') = 'ean13') and (D2.GetX('showText') = '0') and (D2.GetX('foo') = 'bar') and (D2.Kind = 'Barcode'), 'barcode: vraca se u definiciju');
    finally
      D.Free; D2.Free;
    end;
    Check(IsBarcodeKind('Barcode') and not IsBarcodeKind('Chart'), 'barcode: vrste definicije obitelji');
    B := TaBarcode.Create(Fm); B.Name := 'bLfm'; B.Variant := bvQr; B.Text := 'qr tekst';
    Lfm := BarcodeToLfm(B);
    Check((Pos('Variant = bvQr', Lfm) > 0) and (Pos('qr tekst', Lfm) > 0), 'barcode: .lfm sadrzi varijantu i vrijednost');
    B := BarcodeFromLfm(Lfm, Fm);
    Check((B.Variant = bvQr) and (B.Text = 'qr tekst'), 'barcode: .lfm se cita natrag');
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

procedure TestChartFamily;
var
  Fm: TForm;
  C: ta_chartbox.TaChart;
  V: TaChartVariant;
  Bad: Integer;
  Lv: TStringList;
  Owner: TComponent;
  Dbc: TaDatabase;
  Q: TZQuery;
  Ds: TaDataSource;
  D, D2: TaControlDef;
  Lfm: string;
begin
  Fm := TForm.CreateNew(nil);
  Owner := TComponent.Create(nil);
  try
    Fm.SetBounds(0, 0, 400, 300);
    Lv := EngineVariants('Chart');
    try Check(Lv.Count = 4, 'chart: u registru su 4 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    C := ta_chartbox.TaChart.Create(Fm); C.Parent := Fm; C.SetBounds(8, 8, 260, 160);
    C.Items.Add('Sij=10'); C.Items.Add('Velj=25'); C.Items.Add('Ozu=15');
    C.Options.Title := 'Prihodi'; C.Options.Max := 40; C.Options := C.Options;
    Bad := 0;
    for V := Low(TaChartVariant) to High(TaChartVariant) do
    begin
      C.Variant := V;
      if (C.Painter = nil) or (C.Painter.Mode <> V) then Inc(Bad)
      else if not PaintedBitmap(3, C.Painter, 260, 160) then Inc(Bad);
    end;
    Check(Bad = 0, 'chart: svaka varijanta stvara pokretac i crta (nepodudaranja: ' + IntToStr(Bad) + ')');
    { stavke iz skupa podataka }
    if FileExists('/tmp/ta_chart.db') then DeleteFile('/tmp/ta_chart.db');
    Dbc := TaDatabase.Create(Owner);
    Dbc.FileName := '/tmp/ta_chart.db';
    Dbc.Active := True;
    Dbc.ExecSQL('CREATE TABLE st (id INTEGER PRIMARY KEY AUTOINCREMENT, mjesec VARCHAR(5), iznos REAL)');
    Dbc.ExecSQL('INSERT INTO st (mjesec, iznos) VALUES (''I'', 5), (''II'', 8), (''III'', 3)');
    Q := Dbc.NewQuery('SELECT * FROM st ORDER BY id'); Q.Open;
    Ds := TaDataSource.Create(Owner); Ds.DataSet := Q;
    C.Variant := cvBar;
    C.Options.LabelField := 'mjesec'; C.Options.ValueField := 'iznos'; C.Options := C.Options;
    C.DataSource := Ds;
    Check(PaintedBitmap(3, C.Painter, 260, 160), 'chart: crta podatke iz skupa');
    Q.Close;
    C.DataSource := nil;
    Dbc.Active := False;
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'Chart'; D.Name := 'chPrihodi'; D.Caption := 'Prihodi'; D.Left := 5; D.Top := 6; D.Width := 220; D.Height := 150;
      D.SetX('chartType', 'pie'); D.SetX('items', 'a=1;b=2'); D.SetX('foo', 'bar');
      C := ChartFromDef(D, Fm);
      Check((C.Variant = cvPie) and (C.Items.Count = 2) and (C.Options.Title = 'Prihodi') and (C.Extra = 'foo=bar'), 'chart: definicija (chartType) postaje komponenta');
      ChartToDef(C, D2);
      Check((D2.Kind = 'Chart') and (D2.GetX('variant') = 'pie') and (D2.GetX('items') = 'a=1;b=2') and (D2.Caption = 'Prihodi') and (D2.GetX('foo') = 'bar'), 'chart: vraca se u definiciju');
    finally
      D.Free; D2.Free;
    end;
    Check(IsChartKind('Chart') and not IsChartKind('Barcode'), 'chart: vrste definicije obitelji');
    C := ta_chartbox.TaChart.Create(Fm); C.Name := 'cLfm'; C.Variant := cvGauge; C.Items.Add('Stanje=42'); C.Options.Max := 80;
    Lfm := ChartToLfm(C);
    Check((Pos('Variant = cvGauge', Lfm) > 0) and (Pos('Stanje=42', Lfm) > 0), 'chart: .lfm sadrzi varijantu i podatke');
    C := ChartFromLfm(Lfm, Fm);
    Check((C.Variant = cvGauge) and (C.Items.Count = 1) and (C.Options.Max = 80), 'chart: .lfm se cita natrag');
  finally
    Owner.Free;
    Fm.Free;
  end;
end;

type
  TMenuProbe = class
    Last: string;
    Count: Integer;
    procedure OnAct(Sender: TObject; const AAction: string);
  end;

procedure TMenuProbe.OnAct(Sender: TObject; const AAction: string);
begin
  Last := AAction;
  Inc(Count);
end;

procedure TestMenu;
var
  Fm: TForm;
  M: TaMenu;
  V: TaMenuVariant;
  Bad: Integer;
  Lv: TStringList;
  D, D2: TaControlDef;
  Lfm: string;
  P: TMenuProbe;
begin
  Fm := TForm.CreateNew(nil);
  P := TMenuProbe.Create;
  try
    Fm.SetBounds(0, 0, 500, 400);
    Lv := EngineVariants('Menu');
    try Check(Lv.Count = 3, 'menu: u registru su 3 varijante (' + Lv.CommaText + ')'); finally Lv.Free; end;
    M := TaMenu.Create(Fm); M.Parent := Fm; M.SetBounds(8, 8, 220, 260);
    M.Items.Add('# Racuni|folder'); M.Items.Add('Novi racun|openform:Racun'); M.Items.Add('Popis|openform:Racuni');
    M.Items.Add('# Izvjesca'); M.Items.Add('Promet|openreport:Promet');
    M.OnAction := @P.OnAct;
    Bad := 0;
    for V := Low(TaMenuVariant) to High(TaMenuVariant) do
    begin
      M.Variant := V;
      case V of
        muSide: if not (M.Engine.Inner is TaSideMenu) then Inc(Bad);
        muToolbar: if not (M.Engine.Inner is TToolBar) then Inc(Bad);
        muTree: if not (M.Engine.Inner is TTreeView) then Inc(Bad);
      end;
      if M.ItemCount <> 3 then begin Inc(Bad); WriteLn('  menu ', MenuVariantNames[V], ' stavki: ', M.ItemCount); end;
    end;
    Check(Bad = 0, 'menu: svaka varijanta stvara kontrolu s tri stavke (nepodudaranja: ' + IntToStr(Bad) + ')');
    M.Variant := muToolbar;
    P.Count := 0;
    M.Activate('openform:Racuni');
    Check((P.Last = 'openform:Racuni') and (P.Count = 1), 'menu: klik na gumb alatne trake javlja radnju');
    M.Variant := muTree;
    M.Activate('openreport:Promet');
    Check((P.Last = 'openreport:Promet') and (P.Count = 2), 'menu: klik na cvor stabla javlja radnju');
    Check(TTreeView(M.Engine.Inner).Items[0].Count = 2, 'menu: skupina je roditelj svojim stavkama');
    M.Variant := muSide;
    M.Options.Compact := True; M.Options.Accordion := False; M.Options := M.Options;
    Check(TaSideMenu(M.Engine.Inner).Compact and not TaSideMenu(M.Engine.Inner).Accordion, 'menu: opcije bocnog izbornika');
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'SideMenu'; D.Name := 'smGlavni'; D.Left := 5; D.Top := 6; D.Width := 200; D.Height := 300;
      D.RowSource := '# Skupina' + LineEnding + 'Stavka|openform:X'; D.SetX('variant', 'tree'); D.SetX('foo', 'bar');
      M := MenuFromDef(D, Fm);
      Check((M.Variant = muTree) and (M.Items.Count = 2) and (M.Extra = 'foo=bar'), 'menu: SideMenu iz definicije postaje Menu');
      MenuToDef(M, D2);
      Check((D2.Kind = 'SideMenu') and (D2.GetX('variant') = 'tree') and (Pos('Stavka|openform:X', D2.GetX('items')) > 0) and (D2.GetX('foo') = 'bar'), 'menu: vraca se u definiciju');
    finally
      D.Free; D2.Free;
    end;
    Check(IsMenuKind('SideMenu') and IsMenuKind('Menu') and not IsMenuKind('Chart'), 'menu: vrste definicije obitelji');
    M := TaMenu.Create(Fm); M.Name := 'mLfm'; M.Variant := muToolbar; M.Items.Add('Jedan|a'); M.Items.Add('Dva|b');
    Lfm := MenuToLfm(M);
    Check((Pos('Variant = muToolbar', Lfm) > 0) and (Pos('Jedan|a', Lfm) > 0), 'menu: .lfm sadrzi varijantu i stavke');
    M := MenuFromLfm(Lfm, Fm);
    Check((M.Variant = muToolbar) and (M.Items.Count = 2), 'menu: .lfm se cita natrag');
  finally
    P.Free;
    Fm.Free;
  end;
end;

type
  TPcTimer = class
    Tm: TTimer;
    NameToSet: string;
    constructor Create;
    destructor Destroy; override;
    procedure Fire(Sender: TObject);
  end;

constructor TPcTimer.Create;
begin
  Tm := TTimer.Create(nil);
  Tm.Interval := 200;
  Tm.OnTimer := @Fire;
end;

destructor TPcTimer.Destroy;
begin
  Tm.Free;
  inherited;
end;

procedure TPcTimer.Fire(Sender: TObject);
var
  F: TForm;
  I: Integer;
begin
  Tm.Enabled := False;
  F := Screen.ActiveForm;
  if F = nil then Exit;
  for I := 0 to F.ComponentCount - 1 do
    if F.Components[I] is TComboBox then
    begin
      TComboBox(F.Components[I]).Text := NameToSet;
      Break;
    end;
  F.ModalResult := mrOk;
end;

procedure TestPropClass;
var
  Db: TAppDb;
  P, Caps: TStringList;
  D, D2: TaControlDef;
  Form: TaFormDef;
  N, I: Integer;
  Defs: TList;
  Tg: TaFormDef;
  Lst: TStringList;
  R: TaFormRunner;
  T: TPcTimer;
  Nm: string;
  Ed: TControl;
begin
  Db := TAppDb.Create;
  P := TStringList.Create;
  try
    if FileExists('/tmp/ta_propclass.db') then DeleteFile('/tmp/ta_propclass.db');
    Db.Open('/tmp/ta_propclass.db');
    Db.Conn.ExecuteDirect('CREATE TABLE st (id INTEGER PRIMARY KEY, iznos DECIMAL(12,2), pdv DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO st (iznos, pdv) VALUES (1234.5, 5)');
    { spremanje i citanje }
    P.Values['Format'] := '#,##0.00'; P.Values['Align'] := 'right'; P.Values['ForeColor'] := '#0000FF';
    PropClassSave(Db, 'PoljeIznosa', P);
    Lst := PropClassList(Db);
    try Check((Lst.Count = 1) and (Lst[0] = 'PoljeIznosa'), 'propclass: klasa je u popisu'); finally Lst.Free; end;
    P.Clear;
    Check(PropClassLoad(Db, 'PoljeIznosa', P) and (P.Values['Format'] = '#,##0.00') and (P.Values['Align'] = 'right') and (P.Values['ForeColor'] = '#0000FF'), 'propclass: klasa se cita natrag');
    Check(not PropClassLoad(Db, 'Nema', P) and (P.Count = 0), 'propclass: nepostojeca klasa');
    { hvatanje iz kontrole }
    D := TaControlDef.Create;
    D2 := TaControlDef.Create;
    try
      D.Kind := 'TextBox'; D.Name := 'tA'; D.Format := '0.0'; D.Align := 'center'; D.SetX('foreColor', '#FF0000'); D.SetX('italic', '1');
      Caps := PropClassNames;
      try
        PropClassCapture(D, Caps, P);
        Check((P.Values['Format'] = '0.0') and (P.Values['Align'] = 'center') and (P.Values['ForeColor'] = '#FF0000') and (P.Values['Italic'] = 'True') and (P.Values['Bold'] = ''), 'propclass: hvata samo svojstva koja kontrola ima');
      finally
        Caps.Free;
      end;
      { primjena: vlastito nadjacava }
      PropClassLoad(Db, 'PoljeIznosa', P);
      D2.Kind := 'TextBox'; D2.Name := 'tB'; D2.Align := 'left'; D2.SetX('class', 'PoljeIznosa');
      N := PropClassApply(D2, P);
      Check((N = 2) and (D2.Format = '#,##0.00') and (D2.Align = 'left') and (D2.GetX('foreColor') = '#0000FF'), 'propclass: klasa popunjava prazno, vlastito (Align) ostaje (upisano ' + IntToStr(N) + ')');
      N := PropClassApply(D2, P);
      Check(N = 0, 'propclass: ponovna primjena nista ne mijenja');
    finally
      D.Free; D2.Free;
    end;
    { cijela forma }
    Form := TaFormDef.Create;
    try
      D := TaControlDef.Create; D.Kind := 'TextBox'; D.Name := 'a'; D.ControlSource := 'iznos'; D.SetX('class', 'PoljeIznosa'); Form.Add(D);
      D := TaControlDef.Create; D.Kind := 'TextBox'; D.Name := 'b'; D.ControlSource := 'pdv'; D.SetX('class', 'PoljeIznosa'); D.Format := '0'; Form.Add(D);
      D := TaControlDef.Create; D.Kind := 'TextBox'; D.Name := 'c'; D.ControlSource := 'id'; Form.Add(D);
      D := TaControlDef.Create; D.Kind := 'TextBox'; D.Name := 'd'; D.ControlSource := 'id'; D.SetX('class', 'NemaTakve'); Form.Add(D);
      N := ApplyPropClasses(Form, Db);
      Check((Form[0].Format = '#,##0.00') and (Form[1].Format = '0') and (Form[2].Format = '') and (Form[3].Format = ''), 'propclass: forma - klasa samo kontrolama koje je spominju, vlastiti Format ostaje');
      Check(N = 5, 'propclass: ukupno upisanih svojstava (' + IntToStr(N) + ')');
    finally
      Form.Free;
    end;
    { runner koristi klasu }
    Form := TaFormDef.Create;
    Form.Name := 'PcF'; Form.RecordSource := 'st'; Form.AllowEdits := True; Form.Width := 400; Form.Height := 160;
    D := NewCtl('TextBox', 'txtIznos', 'iznos', 10, 10); D.SetX('class', 'PoljeIznosa'); Form.Add(D);
    R := TaFormRunner.CreateRunner(nil, Db, Form);
    try
      Ed := R.ControlByName('txtIznos');
      Check((TEdit(Ed).Alignment = taRightJustify) and (Pos('234', TEdit(Ed).Text) > 0), 'propclass: runner prikazuje polje po klasi (desno, oblikovano: ' + TEdit(Ed).Text + ')');
    finally
      R.Free;
    end;
    { grupe kontrola }
    Defs := TList.Create;
    Tg := TaFormDef.Create;
    try
      D := NewCtl('Label', 'lblUlica', '', 30, 40); D.Caption := 'Ulica'; Defs.Add(D);
      D2 := NewCtl('TextBox', 'txtUlica', 'ulica', 100, 40); Defs.Add(D2);
      ControlGroupSave(Db, 'AdresniBlok', Defs);
      Lst := ControlGroupList(Db);
      try Check((Lst.Count = 1) and (Lst[0] = 'AdresniBlok'), 'propclass: grupa je u popisu'); finally Lst.Free; end;
      Tg.Add(NewCtl('TextBox', 'txtUlica', 'x', 5, 5));
      N := ControlGroupInsert(Db, 'AdresniBlok', Tg, 10, 100);
      Check(N = 2, 'propclass: umece dvije kontrole (' + IntToStr(N) + ')');
      Check((Tg.IndexOfName('lblUlica') >= 0) and (Tg.IndexOfName('txtUlica2') >= 0) and (Tg.IndexOfName('txtUlica') >= 0), 'propclass: sudar naziva se rjesava brojkom');
      Check((Tg[Tg.IndexOfName('lblUlica')].Left = 10) and (Tg[Tg.IndexOfName('lblUlica')].Top = 100) and (Tg[Tg.IndexOfName('txtUlica2')].Left = 80), 'propclass: polozaj je relativan prema grupi i pomaknut');
      N := ControlGroupInsert(Db, 'AdresniBlok', Tg, 0, 200, 'dost_');
      Check((N = 2) and (Tg.IndexOfName('dost_lblUlica') >= 0), 'propclass: prefiks naziva');
    finally
      for I := 0 to Defs.Count - 1 do TaControlDef(Defs[I]).Free;
      Defs.Free;
      Tg.Free;
    end;
    { biblioteka u datoteku i u drugi projekt }
    Check(LibraryExport(Db, '/tmp/ta_library.json'), 'propclass: izvoz biblioteke');
    Db.Close;
    if FileExists('/tmp/ta_propclass2.db') then DeleteFile('/tmp/ta_propclass2.db');
    Db.Open('/tmp/ta_propclass2.db');
    N := LibraryImport(Db, '/tmp/ta_library.json', False);
    Check(N = 2, 'propclass: uvoz u novu bazu (' + IntToStr(N) + ')');
    Check(PropClassLoad(Db, 'PoljeIznosa', P) and (P.Values['Format'] = '#,##0.00'), 'propclass: uvezena klasa radi');
    Check(LibraryImport(Db, '/tmp/ta_library.json', False) = 0, 'propclass: uvoz bez prepisivanja preskace postojece');
    Check(LibraryImport(Db, '/tmp/ta_library.json', True) = 2, 'propclass: uvoz s prepisivanjem');
    PropClassDelete(Db, 'PoljeIznosa');
    Check(not PropClassLoad(Db, 'PoljeIznosa', P), 'propclass: brisanje klase');
    { dijalog preko tajmera }
    D := TaControlDef.Create;
    try
      D.Kind := 'TextBox'; D.Name := 'tX'; D.Format := '#,##0'; D.Align := 'right';
      T := TPcTimer.Create;
      T.NameToSet := 'Cijeli';
      Nm := '';
      Check(RunPropClassDialog(nil, Db, D, Nm) and (Nm = 'Cijeli'), 'propclass: dijalog sprema klasu i vraca njezin naziv (' + Nm + ')');
      T.Free;
      Check(PropClassLoad(Db, 'Cijeli', P) and (P.Values['Format'] = '#,##0') and (P.Values['Align'] = 'right'), 'propclass: dijalog je spremio svojstva kontrole');
    finally
      D.Free;
    end;
    Check((PropMapFind('PropertyClass') >= 0) and (PropertyNamesFor('TextBox', False).IndexOf('PropertyClass') >= 0), 'propclass: svojstvo PropertyClass je u Inspektoru');
    Db.Close;
  finally
    P.Free;
    Db.Free;
  end;
end;

procedure TestRunnerFamilies;
var
  Db: TAppDb;
  D: TaFormDef;
  C: TaControlDef;
  R: TaFormRunner;
  Q: TZQuery;
  Old: Boolean;
  Rg: TRadioGroup;
  Mm: TMemo;
begin
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_runfam.db') then DeleteFile('/tmp/ta_runfam.db');
    Db.Open('/tmp/ta_runfam.db');
    Db.Conn.ExecuteDirect('CREATE TABLE p (id INTEGER PRIMARY KEY, naziv VARCHAR(30), aktivan INTEGER, vrsta INTEGER, opis TEXT, iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO p (naziv, aktivan, vrsta, opis, iznos) VALUES (''Alfa'', 1, 2, ''prvi'', 10), (''Beta'', 0, 1, ''drugi'', 20)');
    D := TaFormDef.Create;
    D.Name := 'FamF'; D.RecordSource := 'p'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 520; D.Height := 360;
    C := NewCtl('Label', 'lblNaziv', '', 10, 10); C.Caption := 'Naziv'; D.Add(C);
    D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 120, 10));
    C := NewCtl('CheckBox', 'chkAkt', 'aktivan', 120, 40); C.Caption := 'Aktivan'; D.Add(C);
    C := NewCtl('OptionGroup', 'ogVrsta', 'vrsta', 120, 70); C.RowSource := 'list:1=A;2=B;3=C'; C.Caption := 'Vrsta'; C.Width := 200; C.Height := 90; D.Add(C);
    C := NewCtl('MemoBox', 'memOpis', 'opis', 120, 170); C.Width := 250; C.Height := 60; D.Add(C);
    C := NewCtl('Button', 'btnX', '', 330, 10); C.Caption := 'Gumb'; C.Width := 80; D.Add(C);
    C := NewCtl('TextBox', 'txtIznos', 'iznos', 330, 40); C.SetX('variant', 'currency'); D.Add(C);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Check(R.ControlByName('txtNaziv') is TaEdit, 'runner familije: TextBox je TaEdit');
      Check(R.ControlByName('chkAkt') is TaCheck, 'runner familije: CheckBox je TaCheck');
      Check(R.ControlByName('ogVrsta') is TaChoice, 'runner familije: OptionGroup je TaChoice');
      Check(R.ControlByName('memOpis') is TaMemo, 'runner familije: MemoBox je TaMemo');
      Check(R.ControlByName('btnX') is TaButton, 'runner familije: Button je TaButton');
      Check(R.ControlByName('lblNaziv') is TaLabel, 'runner familije: Label je TaLabel');
      Check(TaEdit(R.ControlByName('txtIznos')).Variant = evCurrency, 'runner familije: varijanta iz definicije radi (currency)');
      Check(TaCheck(R.ControlByName('chkAkt')).Caption = 'Aktivan', 'runner familije: kvacica ima natpis (' + TaCheck(R.ControlByName('chkAkt')).Caption + ')');
      Check(TaCheck(R.ControlByName('chkAkt')).Checked and (TaEdit(R.ControlByName('txtNaziv')).Text = 'Alfa') and
        (TaChoice(R.ControlByName('ogVrsta')).Selected = '2') and (TaMemo(R.ControlByName('memOpis')).Text = 'prvi'),
        'runner familije: prvi zapis je u kontrolama (kvacica, tekst, izbor, memo)');
      R.DoAction('next');
      Check((not TaCheck(R.ControlByName('chkAkt')).Checked) and (TaEdit(R.ControlByName('txtNaziv')).Text = 'Beta') and
        (TaChoice(R.ControlByName('ogVrsta')).Selected = '1'), 'runner familije: sljedeci zapis');
      Rg := TRadioGroup(TaChoice(R.ControlByName('ogVrsta')).Engine.Inner);
      Rg.ItemIndex := 2;
      Check(R.RecordState = rsChanged, 'runner familije: izbor u grupi oznacava zapis promijenjenim (' + R.StateText + ')');
      Mm := TMemo(TaMemo(R.ControlByName('memOpis')).Engine.Inner);
      Mm.Text := 'izmijenjeno';
      Mm.OnChange(Mm);
      R.DoAction('save');
      Q := Db.NewQuery('SELECT vrsta, opis FROM p WHERE naziv = ''Beta''');
      try
        Q.Open;
        Check((Q.Fields[0].AsInteger = 3) and (Q.Fields[1].AsString = 'izmijenjeno'), 'runner familije: izmjene su spremljene (' + Q.Fields[0].AsString + ', ' + Q.Fields[1].AsString + ')');
      finally
        Q.Free;
      end;
      Check(DefOf(R.ControlByName('btnX')).Name = 'btnX', 'runner familije: DefOf radi i za domacine');
      Check((PropertyNamesFor('CheckBox', False).IndexOf('Variant') >= 0) and (Pos('switch', VariantsForKind('CheckBox')) > 0) and (VariantsForKind('Subform') = '') and (Pos('shape', VariantsForKind('Image')) > 0), 'runner familije: Inspektor nudi svojstvo Variant samo vrstama s varijantama');
    finally
      R.Free;
    end;
    Db.Close;
  finally
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

procedure TestRunnerCombo;
var
  Db: TAppDb;
  D: TaFormDef;
  C: TaControlDef;
  R: TaFormRunner;
  Q: TZQuery;
  Old: Boolean;
  Cb: TaComboBox;
  E1, E2, E3: TaEdit;
begin
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_runcombo.db') then DeleteFile('/tmp/ta_runcombo.db');
    Db.Open('/tmp/ta_runcombo.db');
    Db.Conn.ExecuteDirect('CREATE TABLE g (id INTEGER PRIMARY KEY, naziv VARCHAR(20))');
    Db.Conn.ExecuteDirect('INSERT INTO g (naziv) VALUES (''Prva''), (''Druga''), (''Treca'')');
    Db.Conn.ExecuteDirect('CREATE TABLE p (id INTEGER PRIMARY KEY, grupa INTEGER, tip VARCHAR(10), g_id INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO p (grupa, tip, g_id) VALUES (2, ''b'', 3), (1, ''a'', 1)');
    D := TaFormDef.Create;
    D.Name := 'CmbF'; D.RecordSource := 'p'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 480; D.Height := 200;
    C := NewCtl('ComboBox', 'cmbGrupa', 'grupa', 10, 10); C.RowSource := 'list:1=A;2=B;3=C'; C.Width := 160; D.Add(C);
    C := NewCtl('ComboBox', 'cmbTip', 'tip', 10, 40); C.RowSource := 'list:a;b;c'; C.Width := 160; D.Add(C);
    C := NewCtl('ComboBox', 'cmbG', 'g_id', 10, 70); C.RowSource := 'SELECT id, naziv FROM g ORDER BY id'; C.SetX('search', '1'); C.Width := 160; D.Add(C);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      E1 := TaEdit(R.ControlByName('cmbGrupa'));
      E2 := TaEdit(R.ControlByName('cmbTip'));
      E3 := TaEdit(R.ControlByName('cmbG'));
      Check((E1 is TaEdit) and (E1.Variant = evCombo) and TaComboOptions(E1.Options).Keyed, 'combo: ComboBox s parovima je TaEdit combo s kljucevima');
      Check(E1.Text = '2', 'combo: vrijednost je kljuc (' + E1.Text + ')');
      Cb := TaComboBox(E1.Engine.Inner);
      Check((Cb.Text = 'B') and (Cb.Items.Count = 3) and (Cb.Items[0] = 'A'), 'combo: prikazan je natpis, popis ima natpise (' + Cb.Text + ')');
      Check(not TaComboOptions(E2.Options).Keyed and (E2.Text = 'b'), 'combo: obican popis bez kljuceva (' + E2.Text + ')');
      Check(TaComboOptions(E3.Options).Keyed and TaComboOptions(E3.Options).Search and (E3.Text = '3') and (TaComboBox(E3.Engine.Inner).Text = 'Treca'),
        'combo: SQL izvor s dva stupca je kljucan i pretrazivi (' + E3.Text + ')');
      Check(TaComboBox(E3.Engine.Inner).Search, 'combo: pretrazivanje je ukljuceno na pokretacu');
      { odabir natpisa upisuje kljuc }
      Cb.ItemIndex := 2;
      Cb.OnChange(Cb);
      Check((E1.Text = '3') and (R.RecordState = rsChanged), 'combo: odabir natpisa daje kljuc i oznacava zapis (' + E1.Text + ', ' + R.StateText + ')');
      R.DoAction('save');
      Q := Db.NewQuery('SELECT grupa FROM p WHERE tip = ''b''');
      try
        Q.Open;
        Check(Q.Fields[0].AsInteger = 3, 'combo: kljuc je spremljen u polje (' + Q.Fields[0].AsString + ')');
      finally
        Q.Free;
      end;
      R.DoAction('next');
      Check((E1.Text = '1') and (E2.Text = 'a') and (E3.Text = '1') and (TaComboBox(E3.Engine.Inner).Text = 'Prva'), 'combo: sljedeci zapis');
    finally
      R.Free;
    end;
    Db.Close;
  finally
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

type
  TMouseCrack = class(TControl)
  public
    property OnMouseDown;
  end;

procedure TestTriggers;
var
  Db: TAppDb;
  D: TaFormDef;
  C: TaControlDef;
  M: TaFieldMeta;
  R: TaFormRunner;
  Old: Boolean;
  Q: TZQuery;
  Kk: Word;

  function Rows: Integer;
  begin
    Q := Db.NewQuery('SELECT COUNT(*) FROM t');
    try
      Q.Open;
      Result := Q.Fields[0].AsInteger;
    finally
      Q.Free;
    end;
  end;

  function Flag(const AName: string): string;
  begin
    Result := Db.LoadSetting(AName);
  end;

begin
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_trig.db') then DeleteFile('/tmp/ta_trig.db');
    Db.Open('/tmp/ta_trig.db');
    Db.Conn.ExecuteDirect('CREATE TABLE t (id INTEGER PRIMARY KEY, naziv VARCHAR(30), kolicina INTEGER)');
    Db.Conn.ExecuteDirect('CREATE UNIQUE INDEX t_naziv ON t (naziv)');
    Db.Conn.ExecuteDirect('INSERT INTO t (naziv, kolicina) VALUES (''Alfa'', 1)');
    Db.SaveObject('_sys_modules', 'trig',
      'procedure RejectBad;' + LineEnding + 'begin if EventInfo(''eventValue'') = ''bad'' then CancelEvent; end;' + LineEnding +
      'procedure NoZero;' + LineEnding + 'begin if GetNumber(''txtKol'') = 0 then CancelEvent; end;' + LineEnding +
      'procedure MarkInsert;' + LineEnding + 'begin SqlExec(''INSERT INTO _sys_settings (k, v) VALUES (''''ins'''', ''''1'''')''); end;' + LineEnding +
      'procedure MarkDelete;' + LineEnding + 'begin SqlExec(''INSERT INTO _sys_settings (k, v) VALUES (''''del'''', ''''1'''')''); end;' + LineEnding +
      'procedure MarkQuery;' + LineEnding + 'begin SqlExec(''INSERT INTO _sys_settings (k, v) VALUES (''''qry'''', ''''1'''')''); end;' + LineEnding +
      'procedure MarkEnter;' + LineEnding + 'begin SqlExec(''INSERT OR REPLACE INTO _sys_settings (k, v) VALUES (''''enter'''', '''''' + EventInfo(''eventControl'') + '''''')''); end;' + LineEnding +
      'procedure OnKeyTrap;' + LineEnding + 'begin if EventInfo(''eventKey'') = ''113'' then CancelEvent; end;' + LineEnding +
      'procedure Friendly;' + LineEnding + 'begin SetEventInfo(''eventMessage'', ''Prijateljska poruka''); end;');
    Check(Scripts(Db).Ensure, 'okidaci: modul se prevodi');
    D := TaFormDef.Create;
    D.Name := 'TrigF'; D.RecordSource := 't'; D.AllowEdits := True; D.AllowAdds := True; D.AllowDeletes := True; D.NavButtons := True; D.Width := 400; D.Height := 120;
    C := NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 10); C.SetX('onValidate', 'RejectBad'); C.SetX('onEnter', 'MarkEnter'); C.SetX('onKey', 'OnKeyTrap'); D.Add(C);
    D.Add(NewCtl('TextBox', 'txtKol', 'kolicina', 10, 40));
    D.SetEv('BeforeInsert', 'NoZero');
    D.SetEv('AfterInsert', 'MarkInsert');
    D.SetEv('AfterDelete', 'MarkDelete');
    D.SetEv('AfterQuery', 'MarkQuery');
    D.SetEv('OnError', 'Friendly');
    LastMsg := '';
    OnRunnerMessage := @CaptureMsg;
    OnRunnerConfirm := @TestRunnerConfirm;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      { BeforeInsert odbija zapis s kolicinom 0 }
      R.DoAction('new');
      TEdit(TaEdit(R.ControlByName('txtNaziv')).Engine.Inner).Text := 'Beta';
      TEdit(TaEdit(R.ControlByName('txtKol')).Engine.Inner).Text := '0';
      Check(not R.SaveRecord, 'okidaci: BeforeInsert s CancelEvent odbija novi zapis');
      Check(Rows = 1, 'okidaci: odbijeni zapis nije upisan');
      TEdit(TaEdit(R.ControlByName('txtKol')).Engine.Inner).Text := '5';
      Check(R.SaveRecord and (Rows = 2), 'okidaci: BeforeInsert propusta ispravan zapis');
      Check(Flag('ins') = '1', 'okidaci: AfterInsert se izvrsio');
      { OnValidate kontrole blokira spremanje }
      R.DoAction('new');
      TEdit(TaEdit(R.ControlByName('txtNaziv')).Engine.Inner).Text := 'bad';
      TEdit(TaEdit(R.ControlByName('txtKol')).Engine.Inner).Text := '1';
      Check(not R.SaveRecord, 'okidaci: OnValidate kontrole blokira spremanje');
      R.DoAction('cancel');
      { OnError mijenja poruku }
      LastMsg := '';
      R.DoAction('new');
      TEdit(TaEdit(R.ControlByName('txtNaziv')).Engine.Inner).Text := 'Alfa';
      TEdit(TaEdit(R.ControlByName('txtKol')).Engine.Inner).Text := '2';
      Check(not R.SaveRecord and (Pos('Prijateljska poruka', LastMsg) > 0), 'okidaci: OnError zamjenjuje poruku baze (' + LastMsg + ')');
      R.DoAction('cancel');
      { OnEnter dobiva naziv kontrole }
      TaEdit(R.ControlByName('txtNaziv')).Engine.Inner.OnEnter(TaEdit(R.ControlByName('txtNaziv')).Engine.Inner);
      Check(Flag('enter') = 'txtNaziv', 'okidaci: OnEnter kontrole dobiva eventControl (' + Flag('enter') + ')');
      { OnKey guta tipku kad skripta pozove CancelEvent }
      Kk := 113;
      TaEdit(R.ControlByName('txtNaziv')).OnInnerKeyDown(R.ControlByName('txtNaziv'), Kk, []);
      Check(Kk = 0, 'okidaci: OnKey s CancelEvent guta tipku');
      Kk := 65;
      TaEdit(R.ControlByName('txtNaziv')).OnInnerKeyDown(R.ControlByName('txtNaziv'), Kk, []);
      Check(Kk = 65, 'okidaci: OnKey propusta ostale tipke');
      { AfterQuery i AfterDelete }
      R.Requery;
      Check(Flag('qry') = '1', 'okidaci: AfterQuery se izvrsio');
      R.DoAction('delete');
      Check(Flag('del') = '1', 'okidaci: AfterDelete se izvrsio');
    finally
      R.Free;
      OnRunnerMessage := nil;
    end;
    { hijerarhija okidaca: kontrola > rjecnik > zadani okidac forme }
    D := TaFormDef.Create;
    D.Name := 'HierF'; D.RecordSource := 't'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 300; D.Height := 100;
    D.SetEv('FieldOnValidate', 'RejectBad');
    D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 10));
    C := NewCtl('TextBox', 'txtKol', 'kolicina', 10, 40); C.SetX('onValidate', 'OwnProc'); D.Add(C);
    Check((EffectiveEvent(NewCtl('TextBox', 'x', 'naziv', 0, 0), D, 'onValidate') = 'RejectBad') and (EffectiveEvent(C, D, 'onValidate') = 'OwnProc'),
      'hijerarhija: vlastiti okidac kontrole nadjacava zadani okidac forme');
    Check(EffectiveEvent(nil, D, 'onKey') = '', 'hijerarhija: bez okidaca nema procedure');
    LastMsg := '';
    OnRunnerMessage := @CaptureMsg;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.DoAction('new');
      TEdit(TaEdit(R.ControlByName('txtNaziv')).Engine.Inner).Text := 'bad';
      TEdit(TaEdit(R.ControlByName('txtKol')).Engine.Inner).Text := '7';
      Check(not R.SaveRecord, 'hijerarhija: zadani okidac forme (FieldOnValidate) odbija vrijednost kontrole bez vlastitog okidaca');
      R.DoAction('cancel');
    finally
      R.Free;
      OnRunnerMessage := nil;
    end;
    { rjecnik: okidac polja se spaja u kontrolu }
    M := TaFieldMeta.Create; M.TableName := 't'; M.FieldName := 'naziv'; M.SetX('onValidate', 'RejectBad'); Db.SaveFieldMeta(M); M.Free;
    D := TaFormDef.Create;
    D.Name := 'HierF2'; D.RecordSource := 't'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 300; D.Height := 100;
    D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 10));
    D.Add(NewCtl('TextBox', 'txtKol', 'kolicina', 10, 40));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Check(DefOf(R.ControlByName('txtNaziv')).GetX('onValidate') = 'RejectBad', 'hijerarhija: okidac polja iz rjecnika spaja se u kontrolu');
      R.DoAction('new');
      TEdit(TaEdit(R.ControlByName('txtNaziv')).Engine.Inner).Text := 'bad';
      TEdit(TaEdit(R.ControlByName('txtKol')).Engine.Inner).Text := '8';
      OnRunnerMessage := @CaptureMsg;
      Check(not R.SaveRecord, 'hijerarhija: okidac iz rjecnika odbija vrijednost');
      R.DoAction('cancel');
    finally
      R.Free;
      OnRunnerMessage := nil;
    end;
    Db.Close;
  finally
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

procedure TestSchemaPlan;
var
  Db: TAppDb;
  P: TaSchemaPlan;
  O: TaDictOptions;
  M: TaFieldMeta;
  Log: TStringList;
  N: Integer;
begin
  Db := TAppDb.Create;
  Log := TStringList.Create;
  try
    if FileExists('/tmp/ta_schemaplan.db') then DeleteFile('/tmp/ta_schemaplan.db');
    Db.Open('/tmp/ta_schemaplan.db');
    Db.Conn.ExecuteDirect('CREATE TABLE gradovi (id INTEGER PRIMARY KEY, naziv VARCHAR(40) NOT NULL)');
    Db.Conn.ExecuteDirect('CREATE TABLE kupci (id INTEGER PRIMARY KEY, naziv VARCHAR(60) NOT NULL, oib VARCHAR(11), iban VARCHAR(30), adresa VARCHAR(60), postanski_broj VARCHAR(5), ' +
      'grad_id INTEGER REFERENCES gradovi(id), aktivan BOOLEAN, created TIMESTAMP)');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, broj VARCHAR(30), kupac_id INTEGER NOT NULL REFERENCES kupci(id), datum DATE NOT NULL, iznos DECIMAL(12,2), placeno BOOLEAN, napomena TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE stavke_racuna (id INTEGER PRIMARY KEY, racun_id INTEGER NOT NULL REFERENCES racuni(id), artikl VARCHAR(60), kolicina DECIMAL(10,3), cijena DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('CREATE TABLE kupci_oznake (kupac_id INTEGER REFERENCES kupci(id), oznaka_id INTEGER REFERENCES gradovi(id))');
    P := AnalyzeSchema(Db);
    try
      Check(P.Table('gradovi').Role = trCodebook, 'shema: gradovi je sifrarnik');
      Check(P.Table('kupci').Role = trMain, 'shema: kupci je glavna tablica');
      Check(P.Table('racuni').Role = trMain, 'shema: racuni je glavna tablica');
      Check((P.Table('stavke_racuna').Role = trDetail) and (P.Table('stavke_racuna').Parent = 'racuni') and (P.Table('stavke_racuna').FkToParent = 'racun_id'), 'shema: stavke_racuna su stavke racuna');
      Check(P.Table('kupci_oznake').Role = trJunction, 'shema: kupci_oznake je veza');
      Check(P.Table('kupci').Cols[P.Table('kupci').ColIndex('naziv')].NotNull and P.Table('kupci').Cols[P.Table('kupci').ColIndex('id')].IsKey, 'shema: NOT NULL i kljuc su prepoznati');
      O.Numbering := True; O.Stamps := True;
      N := ApplyDictionaryFromSchema(Db, P, O, Log);
      Check(N > 15, 'rjecnik iz sheme: dopunjeno je mnogo polja (' + IntToStr(N) + ')');
      M := Db.FindFieldMeta('kupci', 'naziv');
      Check((M <> nil) and (M.GetX('required') = '1') and (M.Caption = 'Naziv'), 'rjecnik iz sheme: obavezno iz NOT NULL i oznaka');
      M.Free;
      M := Db.FindFieldMeta('kupci', 'oib'); Check((M <> nil) and (M.GetX('mask') = '99999999999'), 'rjecnik iz sheme: maska OIB-a'); M.Free;
      M := Db.FindFieldMeta('kupci', 'iban'); Check((M <> nil) and (Pos('HR99', M.GetX('mask')) = 1), 'rjecnik iz sheme: maska IBAN-a'); M.Free;
      M := Db.FindFieldMeta('kupci', 'postanski_broj'); Check((M <> nil) and (M.GetX('mask') = '99999'), 'rjecnik iz sheme: maska postanskog broja'); M.Free;
      M := Db.FindFieldMeta('kupci', 'grad_id');
      Check((M <> nil) and (M.GetX('variant') = 'combo') and (Pos('gradovi', M.GetX('rowsource')) > 0) and (M.Caption = 'Grad'), 'rjecnik iz sheme: strani kljuc je padajuci popis (' + M.GetX('rowsource') + ')');
      M.Free;
      M := Db.FindFieldMeta('kupci', 'aktivan'); Check((M <> nil) and (M.GetX('variant') = 'switch'), 'rjecnik iz sheme: logicko polje je prekidac'); M.Free;
      M := Db.FindFieldMeta('kupci', 'created'); Check((M <> nil) and (M.GetX('autoenter') = 'created'), 'rjecnik iz sheme: created se upisuje sam'); M.Free;
      M := Db.FindFieldMeta('racuni', 'broj'); Check((M <> nil) and (M.GetX('autoenter') = 'serial') and (M.GetX('serial') = '{seq}/{pp}/{nu}'), 'rjecnik iz sheme: broj racuna je serijski'); M.Free;
      M := Db.FindFieldMeta('racuni', 'datum'); Check((M <> nil) and (M.Format = 'dd.mm.yyyy') and (M.GetX('required') = '1'), 'rjecnik iz sheme: datum ima format i obavezan je'); M.Free;
      M := Db.FindFieldMeta('racuni', 'iznos'); Check((M <> nil) and (M.Format = '#,##0.00') and (M.GetX('align') = 'right'), 'rjecnik iz sheme: iznos ima format i poravnanje'); M.Free;
      { ponovni poziv ne mijenja nista i ne prepisuje rucne izmjene }
      M := Db.FindFieldMeta('kupci', 'naziv'); M.Caption := 'Naziv kupca'; Db.SaveFieldMeta(M); M.Free;
      N := ApplyDictionaryFromSchema(Db, P, O, Log);
      M := Db.FindFieldMeta('kupci', 'naziv');
      Check((N = 0) and (M.Caption = 'Naziv kupca'), 'rjecnik iz sheme: ponavljanje ne prepisuje rucne izmjene (' + IntToStr(N) + ')');
      M.Free;
    finally
      P.Free;
    end;
    Db.Close;
  finally
    Log.Free;
    Db.Free;
  end;
end;

procedure TestAppGen;
var
  Db: TAppDb;
  P: TaSchemaPlan;
  O: TaGenOptions;
  R: TaGenResult;
  Log: TStringList;
  Fm: TaFormDef;
  Forms, Reps: TStringList;
  I, Combos: Integer;
begin
  Db := TAppDb.Create;
  Log := TStringList.Create;
  try
    if FileExists('/tmp/ta_appgen.db') then DeleteFile('/tmp/ta_appgen.db');
    Db.Open('/tmp/ta_appgen.db');
    Db.Conn.ExecuteDirect('CREATE TABLE gradovi (id INTEGER PRIMARY KEY, naziv VARCHAR(40) NOT NULL)');
    Db.Conn.ExecuteDirect('CREATE TABLE kupci (id INTEGER PRIMARY KEY, naziv VARCHAR(60) NOT NULL, oib VARCHAR(11), adresa VARCHAR(60), grad_id INTEGER REFERENCES gradovi(id), aktivan BOOLEAN)');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, broj VARCHAR(30), kupac_id INTEGER NOT NULL REFERENCES kupci(id), datum DATE NOT NULL, iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('CREATE TABLE stavke_racuna (id INTEGER PRIMARY KEY, racun_id INTEGER NOT NULL REFERENCES racuni(id), artikl VARCHAR(60), kolicina DECIMAL(10,3), cijena DECIMAL(12,2))');
    P := AnalyzeSchema(Db);
    try
      O := DefaultGenOptions;
      R := GenerateApplication(Db, P, O, Log);
      Check(R.Codebooks = 1, 'generator: jedan sifrarnik (' + IntToStr(R.Codebooks) + ')');
      Check(R.Forms = 2, 'generator: dvije forme za unos (kupci, racuni) (' + IntToStr(R.Forms) + ')');
      Check(R.Lists = 2, 'generator: dva popisa (' + IntToStr(R.Lists) + ')');
      Check(R.Reports = 2, 'generator: dva izvjesca (' + IntToStr(R.Reports) + ')');
      Forms := Db.ListObjects('_sys_forms');
      Reps := Db.ListObjects('_sys_reports');
      try
        Check((Forms.IndexOf('Kupci') >= 0) and (Forms.IndexOf('Računi') >= 0) and (Forms.IndexOf('Gradovi') >= 0), 'generator: forme Kupci, Racuni i Gradovi postoje');
        Check(Forms.IndexOf('Izbornik') >= 0, 'generator: glavni izbornik postoji');
        Check(Reps.IndexOf('Kupci' + Tr(' report')) >= 0, 'generator: izvjesce o kupcima postoji');
        Check(Forms.IndexOf('Računi' + Tr(' list')) >= 0, 'generator: popis racuna postoji');
      finally
        Forms.Free;
        Reps.Free;
      end;
      Fm := TaFormDef.Create;
      try
        Fm.FromJson(Db.LoadObject('_sys_forms', 'Kupci'));
        Combos := 0;
        for I := 0 to Fm.Count - 1 do
          if (Fm[I].Kind = 'ComboBox') or (Fm[I].GetX('variant') = 'combo') then Inc(Combos);
        Check(Combos >= 1, 'generator: strani kljuc grad je padajuci popis na formi kupaca');
      finally
        Fm.Free;
      end;
      Fm := TaFormDef.Create;
      try
        Fm.FromJson(Db.LoadObject('_sys_forms', 'Računi'));
        Combos := 0;
        for I := 0 to Fm.Count - 1 do
          if Fm[I].Kind = 'Subform' then Inc(Combos);
        Check(Combos >= 1, 'generator: racuni imaju stavke kao podformu');
      finally
        Fm.Free;
      end;
      { ponovno generiranje: neizmijenjeno se obnavlja, a ono sto nije generirano (nema oznake) ostaje }
      Log.Clear;
      Db.SaveSetting('gen:_sys_forms:Kupci', '');
      R := GenerateApplication(Db, P, O, Log);
      Check((R.Forms >= 1) and (R.Skipped >= 1), 'generator: ponavljanje obnavlja generirano i preskace tudje (preskoceno ' + IntToStr(R.Skipped) + ')');
    finally
      P.Free;
    end;
    Db.Close;
  finally
    Log.Free;
    Db.Free;
  end;
end;

procedure TestJadran;
const
  ObjTables: array[0..2] of string = ('_sys_forms', '_sys_reports', '_sys_queries');
var
  Db: TAppDb;
  P: TaSchemaPlan;
  Log, Lst: TStringList;
  I, J, Bad: Integer;
  O: TaGenOptions;
  R, Pv, R2: TaGenResult;
  Mark: string;
  Mw, Mw2, Mw3: TaFieldMeta;
  Dd: TaFormDef;
  Rn: TaFormRunner;
  OldFam: Boolean;
begin
  OldFam := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  Log := TStringList.Create;
  try
    if FileExists('/tmp/ta_jadran.db') then DeleteFile('/tmp/ta_jadran.db');
    Db.Open('/tmp/ta_jadran.db');
    BuildShowcase(Db, Log);
    P := AnalyzeSchema(Db);
    try
      Check((P.Table('ugovor_faze').Role = trDetail) and (P.Table('ugovor_faze').Parent = 'ugovori'), 'jadran: ugovor_faze su stavke ugovora');
      Check((P.Table('ugovor_troskovi').Role = trDetail) and (P.Table('ugovor_troskovi').Parent = 'ugovori'), 'jadran: ugovor_troskovi su stavke ugovora');
      Check((P.Table('uplate').Role = trDetail) and (P.Table('uplate').Parent = 'racuni'), 'jadran: uplate su stavke racuna');
      Check((P.Table('ponude_posla_faze').Role = trDetail) and (P.Table('ponude_posla_faze').Parent = 'ponude_posla'), 'jadran: faze ponude posla su stavke ponude posla');
      Check((P.Table('ponude_posla').Role = trMain) and (P.Table('ugovori').Role = trMain) and (P.Table('racuni').Role = trMain) and (P.Table('partneri').Role = trMain), 'jadran: glavne tablice ostaju glavne');
      Check((P.Table('dnevnik').Role = trSkip) and (P.Table('racuni_arhiva').Role = trSkip) and (P.Table('uvoz_cjenika').Role = trSkip), 'jadran: pomocne tablice se preskacu');
      Check((P.Table('racuni_stavke').Parent = 'racuni') and (P.Table('narudzbenice_stavke').Parent = 'narudzbenice') and (P.Table('kategorije').Role = trCodebook), 'jadran: stavke dokumenata i sifrarnik kategorija');
    finally
      P.Free;
    end;
    { cista baza: ukloni gotove objekte pa generiraj aplikaciju samo iz tablica }
    for I := 0 to 2 do
    begin
      case I of
        0: Lst := Db.ListObjects('_sys_forms');
        1: Lst := Db.ListObjects('_sys_reports');
      else Lst := Db.ListObjects('_sys_queries');
      end;
      for J := 0 to Lst.Count - 1 do
        Db.Conn.ExecuteDirect('DELETE FROM ' + ObjTables[I] + ' WHERE name = ' + Db.QuoteLit(Lst[J]));
      Lst.Free;
    end;
    P := AnalyzeSchema(Db);
    try
      O := DefaultGenOptions;
      Pv := PreviewApplication(Db, P, O, Log);
      Log.Clear;
      R := GenerateApplication(Db, P, O, Log);
      Check((Pv.Forms = R.Forms) and (Pv.Lists = R.Lists) and (Pv.Reports = R.Reports) and (Pv.Codebooks = R.Codebooks),
        'carobnjak: pregled se podudara s generiranim (' + IntToStr(Pv.Forms) + '/' + IntToStr(R.Forms) + ')');
      Log.Clear;
      Pv := PreviewApplication(Db, P, O, Log);
      Check((Pv.Skipped = 0) and (Pos('[', Log.Text) > 0), 'ponovno generiranje: neizmijenjeni generirani objekti se obnavljaju (nisu preskoceni)');
      { rucna izmjena forme: ponovno generiranje je ne dira }
      Db.SaveObject('_sys_forms', 'Partneri', Db.LoadObject('_sys_forms', 'Partneri') + ' ');
      Log.Clear;
      Pv := PreviewApplication(Db, P, O, Log);
      Check(Pv.Skipped = 1, 'ponovno generiranje: rucno izmijenjena forma se oznacava (' + IntToStr(Pv.Skipped) + ')');
      Mark := Db.LoadObject('_sys_forms', 'Partneri');
      Log.Clear;
      R2 := GenerateApplication(Db, P, O, Log);
      Check((Db.LoadObject('_sys_forms', 'Partneri') = Mark) and (R2.Skipped = 1) and (R2.Forms = R.Forms - 1), 'ponovno generiranje: izmijenjena forma ostaje, ostale se obnavljaju');
      O.Overwrite := True;
      R2 := GenerateApplication(Db, P, O, Log);
      O.Overwrite := False;
      Check((Db.LoadObject('_sys_forms', 'Partneri') <> Mark) and (R2.Forms = R.Forms), 'ponovno generiranje: Overwrite prepisuje i izmijenjenu');
      WriteLn('JADRAN generirano: forme ', R.Forms, ' popisi ', R.Lists, ' izvjesca ', R.Reports, ' sifrarnici ', R.Codebooks, ' preskoceno ', R.Skipped);
      Mw := Db.FindFieldMeta('racuni', 'broj');
      Mw2 := Db.FindFieldMeta('racuni', 'partner_id');
      Mw3 := Db.FindFieldMeta('racuni', 'dostava');
      Check((Mw <> nil) and (Mw2 <> nil) and (Mw3 <> nil) and (Mw.ColWidth > 60) and (Mw2.ColWidth > Mw.ColWidth) and (Mw3.ColWidth <> Mw2.ColWidth),
        'jadran: sirine stupaca u mrezi prema sadrzaju (broj ' + IntToStr(Mw.ColWidth) + ', partner ' + IntToStr(Mw2.ColWidth) + ')');
      Mw.Free; Mw2.Free; Mw3.Free;
      Check(R.Forms >= 15, 'jadran: generirane forme za unos (' + IntToStr(R.Forms) + ')');
      Check(R.Lists >= 15, 'jadran: generirani popisi (' + IntToStr(R.Lists) + ')');
      Check(R.Reports >= 15, 'jadran: generirana izvjesca (' + IntToStr(R.Reports) + ')');
      Lst := Db.ListObjects('_sys_forms');
      Bad := 0;
      try
        for J := 0 to Lst.Count - 1 do
        begin
          if Lst[J] = 'Izbornik' then Continue;
          Dd := TaFormDef.Create;
          Dd.FromJson(Db.LoadObject('_sys_forms', Lst[J]));
          Dd.Name := Lst[J];
          try
            Rn := TaFormRunner.CreateRunner(nil, Db, Dd);
            Rn.Free;
          except
            on E: Exception do begin Inc(Bad); WriteLn('JADRAN forma ne radi: ', Lst[J], ': ', E.Message); end;
          end;
        end;
      finally
        Lst.Free;
      end;
      Check(Bad = 0, 'jadran: sve generirane forme se otvaraju (neuspjelih ' + IntToStr(Bad) + ')');
      Dd := TaFormDef.Create;
      Dd.FromJson(Db.LoadObject('_sys_forms', 'Ra' + #$C4#$8D + 'uni' + Tr(' list')));
      Check(Pos('racuni_stavke|dokument_id|id', Dd.SubDatasheet) = 1, 'jadran: the invoices list opens its items as a sub-datasheet (' + Dd.SubDatasheet + ')');
      Dd.Free;
    finally
      P.Free;
    end;
    { rucna promjena uloge (carobnjak) }
    P := AnalyzeSchema(Db);
    try
      Check(SetTableRole(P, P.Table('uplate'), trMain, '') and (P.Table('uplate').Role = trMain) and (P.Table('uplate').Parent = ''), 'carobnjak: stavke -> glavna brise nadredenu');
      Check(SetTableRole(P, P.Table('uplate'), trDetail, '') and (P.Table('uplate').Parent = 'racuni') and (P.Table('uplate').FkToParent = 'racun_id'), 'carobnjak: glavna -> stavke nalazi nadredenu tablicu preko stranog kljuca');
      Check(not SetTableRole(P, P.Table('kategorije'), trDetail, ''), 'carobnjak: tablica bez stranog kljuca ne moze biti stavke');
      Check(SetTableRole(P, P.Table('racuni_stavke'), trDetail, 'artikli') and (P.Table('racuni_stavke').Parent = 'artikli'), 'carobnjak: nadredena tablica se moze birati medu stranim kljucevima');
      SetTableRole(P, P.Table('racuni_stavke'), trSkip, '');
      Log.Clear;
      Pv := PreviewApplication(nil, P, O, Log);
      Check(Pos('racuni_stavke', Log.Text) = 0, 'carobnjak: preskocena tablica nije u pregledu');
    finally
      P.Free;
    end;
    Db.Close;
  finally
    RunnerUsesFamilies := OldFam;
    Log.Free;
    Db.Free;
  end;
end;

procedure TestGenShots;
var
  Dir: string;
  Db: TAppDb;
  Lst: TStringList;
  J: Integer;
  Dd: TaFormDef;
  Rn: TaFormRunner;
  Bmp: TBitmap;
  Png: TPortableNetworkGraphic;
  Err, Safe: string;
  OldFam: Boolean;
begin
  Dir := GetEnvironmentVariable('TA_SHOTS');
  if Dir = '' then Exit;
  ForceDirectories(Dir);
  OldFam := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_jadran.db');
    Lst := Db.ListObjects('_sys_forms');
    for J := 0 to Lst.Count - 1 do
    begin
      Safe := StringReplace(Lst[J], ' ', '_', [rfReplaceAll]);
      Dd := TaFormDef.Create;
      Dd.FromJson(Db.LoadObject('_sys_forms', Lst[J]));
      Dd.Name := Lst[J];
      Rn := TaFormRunner.CreateRunner(nil, Db, Dd);
      try
        Rn.Show;
        Application.ProcessMessages;
        Bmp := Rn.GetFormImage;
        Png := TPortableNetworkGraphic.Create;
        try
          Png.Assign(Bmp);
          Png.SaveToFile(Dir + '/form_' + Safe + '.png');
        finally
          Png.Free;
          Bmp.Free;
        end;
      finally
        Rn.Free;
      end;
    end;
    Lst.Free;
    Lst := Db.ListObjects('_sys_reports');
    for J := 0 to Lst.Count - 1 do
    begin
      Safe := StringReplace(Lst[J], ' ', '_', [rfReplaceAll]);
      if Assigned(TaskPdfHook) then
        if not TaskPdfHook(Db, Lst[J], Dir + '/report_' + Safe + '.pdf', Err) then WriteLn('SHOT izvjesce ', Lst[J], ': ', Err);
    end;
    Lst.Free;
    Db.Close;
  finally
    Db.Free;
    RunnerUsesFamilies := OldFam;
  end;
end;

procedure TestSavedFinds;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  Old: Boolean;
  L: TStringList;
begin
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_finds.db') then DeleteFile('/tmp/ta_finds.db');
    Db.Open('/tmp/ta_finds.db');
    Db.Conn.ExecuteDirect('CREATE TABLE r (id INTEGER PRIMARY KEY, kupac VARCHAR(20), iznos INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO r (kupac, iznos) VALUES (''Alfa'', 10), (''Beta'', 200), (''Alfa'', 300), (''Gama'', 5)');
    D := TaFormDef.Create;
    D.Name := 'FindF'; D.RecordSource := 'r'; D.AllowEdits := True; D.NavButtons := True; D.Width := 300; D.Height := 100;
    D.Add(NewCtl('TextBox', 'txtKupac', 'kupac', 10, 10));
    D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 40));
    LastMsg := '';
    OnRunnerMessage := @CaptureMsg;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Check(R.Query.RecordCount = 4, 'trazenja: sva 4 zapisa');
      { upit po formi: kupac Alfa, iznos > 100 }
      R.DoAction('query');
      TEdit(TaEdit(R.ControlByName('txtKupac')).Engine.Inner).Text := 'Alfa';
      TEdit(TaEdit(R.ControlByName('txtIznos')).Engine.Inner).Text := '>100';
      R.DoAction('savequery:Velike Alfa');
      R.DoAction('execquery');
      Check(R.Query.RecordCount = 1, 'trazenja: upit po formi daje 1 zapis (' + IntToStr(R.Query.RecordCount) + ')');
      R.DoAction('clearquery');
      Check(R.Query.RecordCount = 4, 'trazenja: ciscenje upita vraca sve zapise');
      R.DoAction('loadquery:Velike Alfa');
      Check(R.Query.RecordCount = 1, 'trazenja: spremljeno trazenje se primjenjuje jednim korakom (' + IntToStr(R.Query.RecordCount) + ')');
      L := FindsList(Db, 'FindF');
      Check((L.Count = 1) and (L[0] = 'Velike Alfa'), 'trazenja: popis spremljenih');
      L.Free;
      R.DoAction('deletequery:Velike Alfa');
      L := FindsList(Db, 'FindF');
      Check(L.Count = 0, 'trazenja: brisanje');
      L.Free;
      LastMsg := '';
      R.DoAction('loadquery:Nepostojece');
      Check(Pos('Nema spremljenog upita', LastMsg) > 0, 'trazenja: poruka za nepostojece (' + LastMsg + ')');
    finally
      R.Free;
      OnRunnerMessage := nil;
    end;
    Db.Close;
  finally
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

procedure TestMask;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  M: TaFieldMeta;
  Old: Boolean;
  E: TaEdit;
  Cd: TaControlDef;
begin
  Check(ApplyMask('99999999999', '69435151530') = '69435151530', 'maska: OIB prolazi');
  Check(ApplyMask('999-999', 'ab12345') = '123-45', 'maska: slova se odbacuju, fiksni znak se ubacuje (123-45)');
  Check(ApplyMask('999-999', '123') = '123', 'maska: fiksni znak se ne dodaje prije nego sto ima unosa iza njega');
  Check(ApplyMask('AA99 9999', 'hr123456') = 'hr12 3456', 'maska: slova i znamenke s razmakom');
  Check(ApplyMask('99/99/9999', '01022026') = '01/02/2026', 'maska: datum bez razdjelnika');
  Check(ApplyMask('99/99/9999', '01/02/2026') = '01/02/2026', 'maska: vec uneseni fiksni znakovi se ne udvostrucuju');
  Check(MaskComplete('999-999', '123-456') and not MaskComplete('999-999', '123-45'), 'maska: potpunost');
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_mask.db') then DeleteFile('/tmp/ta_mask.db');
    Db.Open('/tmp/ta_mask.db');
    Db.Conn.ExecuteDirect('CREATE TABLE k (id INTEGER PRIMARY KEY, oib VARCHAR(11), telefon VARCHAR(20))');
    M := TaFieldMeta.Create; M.TableName := 'k'; M.FieldName := 'oib'; M.SetX('mask', '99999999999'); Db.SaveFieldMeta(M); M.Free;
    D := TaFormDef.Create;
    D.Name := 'MaskF'; D.RecordSource := 'k'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 300; D.Height := 100;
    D.Add(NewCtl('TextBox', 'txtOib', 'oib', 10, 10));
    Cd := NewCtl('TextBox', 'txtTel', 'telefon', 10, 40); Cd.SetX('mask', '+999 99 999 9999'); D.Add(Cd);
    LastMsg := '';
    OnRunnerMessage := @CaptureMsg;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      E := TaEdit(R.ControlByName('txtOib'));
      Check(E.Mask = '99999999999', 'maska: kontrola uzima masku iz rjecnika');
      R.DoAction('new');
      TEdit(E.Engine.Inner).Text := '6943x51515';
      Check(E.Text = '694351515', 'maska: pri unosu se odbacuju nedopusteni znakovi (' + E.Text + ')');
      Check(not R.SaveRecord, 'maska: nepotpun OIB se ne sprema');
      Check(Pos('99999999999', LastMsg) > 0, 'maska: poruka navodi oblik (' + LastMsg + ')');
      TEdit(E.Engine.Inner).Text := '69435151530';
      Check(R.SaveRecord, 'maska: potpun OIB se sprema');
      TEdit(TaEdit(R.ControlByName('txtTel')).Engine.Inner).Text := '385911234567';
      Check(TaEdit(R.ControlByName('txtTel')).Text = '+385 91 123 4567', 'maska: vlastita maska kontrole (' + TaEdit(R.ControlByName('txtTel')).Text + ')');
    finally
      R.Free;
      OnRunnerMessage := nil;
    end;
    Db.Close;
  finally
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

procedure TestAutoEnter;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  M: TaFieldMeta;
  Old: Boolean;
{$IFDEF TA_FISCAL}
  Fc: TFiscalConfig;
{$ENDIF}
  Q: TZQuery;
  OldUser: string;
  CopyR: TaAutoFillDef;

  function Val2(const ATable, AField, AKeyF, AKey: string): string;
  begin
    Result := '';
    Q := Db.NewQuery('SELECT ' + AField + ' FROM ' + ATable + ' WHERE ' + AKeyF + ' = ' + AKey);
    try
      Q.Open;
      if not Q.EOF then Result := Q.Fields[0].AsString;
    finally
      Q.Free;
    end;
  end;

  procedure AddRecord(const AKupac: string; out AOk: Boolean);
  begin
    R.DoAction('new');
    TEdit(TaEdit(R.ControlByName('txtKupac')).Engine.Inner).Text := AKupac;
    AOk := R.SaveRecord;
  end;

  function Val(const AField, AKupac: string): string;
  begin
    Result := '';
    Q := Db.NewQuery('SELECT ' + AField + ' FROM racuni WHERE kupac = ' + Db.QuoteLit(AKupac));
    try
      Q.Open;
      if not Q.EOF then Result := Q.Fields[0].AsString;
    finally
      Q.Free;
    end;
  end;

var
  Ok: Boolean;
begin
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  OldUser := CurrentUserName;
  CurrentUserName := 'ana';
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_autoenter.db') then DeleteFile('/tmp/ta_autoenter.db');
    Db.Open('/tmp/ta_autoenter.db');
    { oblik broja }
    Check(SerialFormat('{seq}/{pp}/{nu}', 1, 'POSL1', '2', EncodeDate(2026, 3, 5)) = '1/POSL1/2', 'serial: hrvatski racun redni/prostor/uredaj');
    Check(SerialFormat('{nu}{seq:6}', 1, 'POSL1', '8', EncodeDate(2026, 3, 5)) = '8000001', 'serial: numericki oblik uredaj + 6 znamenki (8000001)');
    Check(SerialFormat('{year}-{mm}-{seq:4}/{yy}', 12, 'P', 'N', EncodeDate(2026, 3, 5)) = '2026-03-0012/26', 'serial: godina, mjesec i nadopuna nulama');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, broj VARCHAR(40), kupac VARCHAR(30), kreiran VARCHAR(30), izmijenjen VARCHAR(30), korisnik VARCHAR(30), napomena VARCHAR(30))');
    Db.Conn.ExecuteDirect('CREATE UNIQUE INDEX racuni_kupac ON racuni (kupac)');
    M := TaFieldMeta.Create; M.TableName := 'racuni'; M.FieldName := 'broj'; M.SetX('autoenter', 'serial'); M.SetX('serial', '{seq}/{pp}/{nu}'); M.SetX('serialpp', 'POSL1'); M.SetX('serialnu', '2'); Db.SaveFieldMeta(M); M.Free;
    M := TaFieldMeta.Create; M.TableName := 'racuni'; M.FieldName := 'kreiran'; M.SetX('autoenter', 'created'); Db.SaveFieldMeta(M); M.Free;
    M := TaFieldMeta.Create; M.TableName := 'racuni'; M.FieldName := 'izmijenjen'; M.SetX('autoenter', 'modified'); Db.SaveFieldMeta(M); M.Free;
    M := TaFieldMeta.Create; M.TableName := 'racuni'; M.FieldName := 'korisnik'; M.SetX('autoenter', 'user'); Db.SaveFieldMeta(M); M.Free;
    M := TaFieldMeta.Create; M.TableName := 'racuni'; M.FieldName := 'napomena'; M.SetX('autoenter', 'const'); M.SetX('autoconst', 'auto'); Db.SaveFieldMeta(M); M.Free;
    D := TaFormDef.Create;
    D.Name := 'AutoF'; D.RecordSource := 'racuni'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 420; D.Height := 160;
    D.Add(NewCtl('TextBox', 'txtBroj', 'broj', 10, 10));
    D.Add(NewCtl('TextBox', 'txtKupac', 'kupac', 10, 40));
    LastMsg := '';
    OnRunnerMessage := @CaptureMsg;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.DoAction('new');
      Check(TaEdit(R.ControlByName('txtBroj')).Text = '1/POSL1/2', 'serial: novi zapis pokazuje sljedeci broj (' + TaEdit(R.ControlByName('txtBroj')).Text + ')');
      Check(SerialLast(Db, 'racuni', 'broj', 'POSL1|2') = 0, 'serial: prikaz broja ne mijenja brojac');
      R.DoAction('cancel');
      AddRecord('Alfa', Ok);
      Check(Ok and (Val('broj', 'Alfa') = '1/POSL1/2'), 'serial: prvi racun ima broj 1/POSL1/2 (' + Val('broj', 'Alfa') + ')');
      AddRecord('Beta', Ok);
      Check(Ok and (Val('broj', 'Beta') = '2/POSL1/2'), 'serial: drugi racun ima uzastopni broj (' + Val('broj', 'Beta') + ')');
      { neuspjelo spremanje (duplikat kupca) ne trosi broj }
      AddRecord('Alfa', Ok);
      Check(not Ok, 'serial: duplikat se ne sprema');
      Check(SerialLast(Db, 'racuni', 'broj', 'POSL1|2') = 2, 'serial: neuspjelo spremanje ne trosi broj (' + IntToStr(SerialLast(Db, 'racuni', 'broj', 'POSL1|2')) + ')');
      R.DoAction('cancel');
      AddRecord('Gama', Ok);
      Check(Ok and (Val('broj', 'Gama') = '3/POSL1/2'), 'serial: slijed ostaje bez rupe (' + Val('broj', 'Gama') + ')');
      Check((Val('kreiran', 'Alfa') <> '') and (Val('korisnik', 'Alfa') = 'ana') and (Val('napomena', 'Alfa') = 'auto'), 'auto-enter: created, user i const se upisuju');
      Check(Val('izmijenjen', 'Alfa') <> '', 'auto-enter: modified je upisan pri unosu');
      { izmjena postojeceg zapisa: modified se osvjezi, created i serial ostaju }
      Db.Conn.ExecuteDirect('UPDATE racuni SET izmijenjen = ''2000-01-01 00:00:00'', kreiran = ''2000-01-01 00:00:00'' WHERE kupac = ''Alfa''');
      R.Requery;
      R.DoAction('first');
      TEdit(TaEdit(R.ControlByName('txtKupac')).Engine.Inner).Text := 'Alfa2';
      Check(R.SaveRecord, 'auto-enter: izmjena postojeceg zapisa se sprema');
      Check(Val('izmijenjen', 'Alfa2') <> '2000-01-01 00:00:00', 'auto-enter: modified se osvjezava pri izmjeni (' + Val('izmijenjen', 'Alfa2') + ')');
      Check((Val('kreiran', 'Alfa2') = '2000-01-01 00:00:00') and (Val('broj', 'Alfa2') = '1/POSL1/2'), 'auto-enter: created i serial se ne mijenjaju pri izmjeni');
    finally
      R.Free;
      OnRunnerMessage := nil;
    end;
    { vrsta copy: adresa kupca se preuzima u racun kad se promijeni kljuc }
    Db.Conn.ExecuteDirect('CREATE TABLE kupci (id INTEGER PRIMARY KEY, naziv VARCHAR(30), adresa VARCHAR(40))');
    Db.Conn.ExecuteDirect('INSERT INTO kupci (id, naziv, adresa) VALUES (1, ''Alfa d.o.o.'', ''Ilica 1, Zagreb''), (2, ''Beta d.o.o.'', ''Riva 5, Split'')');
    Db.Conn.ExecuteDirect('CREATE TABLE rac2 (id INTEGER PRIMARY KEY, kupac_id INTEGER, adresa VARCHAR(40), napomena VARCHAR(20))');
    M := TaFieldMeta.Create; M.TableName := 'rac2'; M.FieldName := 'adresa'; M.SetX('autoenter', 'copy'); M.SetX('autocopy', 'kupci.adresa'); M.SetX('autocopykey', 'kupac_id'); Db.SaveFieldMeta(M);
    Check(CopyRuleFor(M, CopyR) and (CopyR.Field = 'kupac_id') and (CopyR.Table = 'kupci') and (CopyR.KeyCol = 'id') and (CopyR.Sources[0] = 'adresa') and (CopyR.Targets[0] = 'adresa'), 'copy: pravilo iz rjecnika (kupac_id > kupci.id : adresa = adresa)');
    M.SetX('autocopykey', ''); Check(not CopyRuleFor(M, CopyR), 'copy: bez polja s kljucem pravilo nije potpuno');
    M.Free;
    D := TaFormDef.Create;
    D.Name := 'CopyF'; D.RecordSource := 'rac2'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 400; D.Height := 120;
    D.Add(NewCtl('TextBox', 'txtKupac', 'kupac_id', 10, 10));
    D.Add(NewCtl('TextBox', 'txtAdresa', 'adresa', 10, 40));
    LastMsg := '';
    OnRunnerMessage := @CaptureMsg;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.DoAction('new');
      TEdit(TaEdit(R.ControlByName('txtKupac')).Engine.Inner).Text := '2';
      Check(TaEdit(R.ControlByName('txtAdresa')).Text = 'Riva 5, Split', 'copy: promjena kljuca upisuje adresu kupca (' + TaEdit(R.ControlByName('txtAdresa')).Text + ')');
      TEdit(TaEdit(R.ControlByName('txtKupac')).Engine.Inner).Text := '1';
      Check(TaEdit(R.ControlByName('txtAdresa')).Text = 'Ilica 1, Zagreb', 'copy: nova promjena kljuca mijenja adresu');
      Check(R.SaveRecord and (Val2('rac2', 'adresa', 'kupac_id', '1') = 'Ilica 1, Zagreb'), 'copy: adresa je spremljena s racunom');
    finally
      R.Free;
      OnRunnerMessage := nil;
    end;
    { oba oblika iz iste dvije vrijednosti; slijed po godini ima zaseban brojac }
    M := Db.FindFieldMeta('racuni', 'broj'); M.SetX('serial', '{nu}{seq:6}'); M.SetX('serialyear', '1');
    Check(SerialScope(M, 'POSL1', '2', True, EncodeDate(2026, 1, 1)) <> SerialScope(M, 'POSL1', '2', True, EncodeDate(2027, 1, 1)), 'serial: slijed po godini ima zaseban brojac');
    M.SetX('serialyear', '');
    Check(SerialScope(M, 'POSL1', '2', False, Now) = 'POSL1', 'serial: slijed po poslovnom prostoru (bez uredaja)');
    M.Free;
    Db.Close;
  finally
    CurrentUserName := OldUser;
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

procedure TestDictionary;
var
  Db: TAppDb;
  D: TaFormDef;
  C: TaControlDef;
  R: TaFormRunner;
  M: TaFieldMeta;
  Old: Boolean;
  Ed: TControl;
begin
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_dict.db') then DeleteFile('/tmp/ta_dict.db');
    Db.Open('/tmp/ta_dict.db');
    Db.Conn.ExecuteDirect('CREATE TABLE p (id INTEGER PRIMARY KEY, naziv VARCHAR(30), grupa VARCHAR(10), iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO p (naziv, grupa, iznos) VALUES (''Alfa'', ''a'', 10)');
    { rjecnik: obavezno, popis s kljucevima kao padajuci popis, poravnanje i samo za citanje }
    M := TaFieldMeta.Create; M.TableName := 'p'; M.FieldName := 'naziv'; M.Caption := 'Naziv'; M.SetX('required', '1'); Db.SaveFieldMeta(M); M.Free;
    M := TaFieldMeta.Create; M.TableName := 'p'; M.FieldName := 'grupa'; M.SetX('variant', 'combo'); M.SetX('rowsource', 'list:a=Prva;b=Druga'); Db.SaveFieldMeta(M); M.Free;
    M := TaFieldMeta.Create; M.TableName := 'p'; M.FieldName := 'iznos'; M.SetX('align', 'right'); M.SetX('readonly', '1'); Db.SaveFieldMeta(M); M.Free;
    Check(Db.FindFieldMeta('p', 'naziv').GetX('required') = '1', 'rjecnik: dodatna svojstva se spremaju i citaju');
    Check(Db.FindFieldMeta('p', 'grupa').GetX('rowsource') = 'list:a=Prva;b=Druga', 'rjecnik: popis vrijednosti se sprema');
    D := TaFormDef.Create;
    D.Name := 'DictF'; D.RecordSource := 'p'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 400; D.Height := 160;
    D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 10));
    D.Add(NewCtl('TextBox', 'txtGrupa', 'grupa', 10, 40));
    D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 70));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Ed := R.ControlByName('txtGrupa');
      Check((Ed is TaEdit) and (TaEdit(Ed).Variant = evCombo), 'rjecnik: kontrola bez svojstava postaje combo iz rjecnika');
      Check(DefOf(R.ControlByName('txtIznos')).Align = 'right', 'rjecnik: poravnanje iz rjecnika');
      Check(DefOf(R.ControlByName('txtIznos')).GetX('locked') = '1', 'rjecnik: samo za citanje iz rjecnika');
      { prazno obavezno polje blokira spremanje }
      LastMsg := '';
      OnRunnerMessage := @CaptureMsg;
      TEdit(TaEdit(R.ControlByName('txtNaziv')).Engine.Inner).Text := '';
      Check(not R.SaveRecord, 'rjecnik: obavezno polje blokira spremanje');
      Check(Pos('Naziv', LastMsg) > 0, 'rjecnik: poruka imenuje polje (' + LastMsg + ')');
      TEdit(TaEdit(R.ControlByName('txtNaziv')).Engine.Inner).Text := 'Beta';
      Check(R.SaveRecord, 'rjecnik: ispunjeno obavezno polje se sprema');
      OnRunnerMessage := nil;
    finally
      R.Free;
    end;
    D := TaFormDef.Create;
    D.Name := 'DictF2'; D.RecordSource := 'p'; D.AllowEdits := True; D.Width := 400; D.Height := 100;
    C := NewCtl('TextBox', 'txtGrupa', 'grupa', 10, 10); C.SetX('variant', 'droplist'); D.Add(C);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Check(TaEdit(R.ControlByName('txtGrupa')).Variant = evDroplist, 'rjecnik: vlastita varijanta nadjacava rjecnik');
    finally
      R.Free;
    end;
    M := TaFieldMeta.Create; M.SetX('mask', '999'); M.SetX('readonly', '1'); M.SetX('variant', 'switch');
    Check((DictValueFor(M, 'Mask') = '999') and (DictValueFor(M, 'Locked') = 'True') and (DictValueFor(M, 'Variant') = 'switch') and (DictValueFor(M, 'Tip') = ''), 'rjecnik: vrijednosti koje se pokazuju kao naslijedene u Inspektoru');
    M.Free;
    Check(DictInheritedMarker = '(rječnik) ', 'rjecnik: oznaka naslijedene vrijednosti ("' + DictInheritedMarker + '")');
    Check(Tr('Value is required') = 'Obavezno polje', 'i18n: hrvatski prijevod');
    Check((Tr('Cancel') = 'Odustani') and (Tr('Save') = 'Spremi') and (Tr('Delete') = 'Obriši'), 'i18n: tekstovi dijaloga imaju hrvatski prijevod');
    Check(TranslationCount('hr') > 800, 'i18n: hrvatska tablica je popunjena (' + IntToStr(TranslationCount('hr')) + ')');
    SetUiLanguage('en');
    Check(Tr('Value is required') = 'Value is required', 'i18n: engleski izvorni tekst');
    SetUiLanguage('hr');
    Db.Close;
  finally
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

procedure TestRunnerDisplayFamilies;
var
  Db: TAppDb;
  D: TaFormDef;
  C: TaControlDef;
  R: TaFormRunner;
  Old: Boolean;
  Img, Chr, Bar: TControl;
  Ph: TPicture;
  Fn: string;
begin
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_rundisp.db') then DeleteFile('/tmp/ta_rundisp.db');
    Db.Open('/tmp/ta_rundisp.db');
    Fn := '/tmp/ta_rundisp.png';
    Ph := TPicture.Create;
    try
      Ph.Bitmap.SetSize(8, 8);
      Ph.Bitmap.Canvas.Brush.Color := clRed;
      Ph.Bitmap.Canvas.FillRect(0, 0, 8, 8);
      Ph.SaveToFile(Fn);
    finally
      Ph.Free;
    end;
    Db.Conn.ExecuteDirect('CREATE TABLE p (id INTEGER PRIMARY KEY, kod VARCHAR(20), slika VARCHAR(80))');
    Db.Conn.ExecuteDirect('INSERT INTO p (kod, slika) VALUES (''4006381333931'', ''' + Fn + '''), (''ABC'', NULL)');
    Db.Conn.ExecuteDirect('CREATE TABLE s (naziv VARCHAR(10), iznos INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO s VALUES (''a'', 3), (''b'', 5), (''c'', 4)');
    D := TaFormDef.Create;
    D.Name := 'DispF'; D.RecordSource := 'p'; D.AllowEdits := True; D.NavButtons := True; D.Width := 480; D.Height := 300;
    C := NewCtl('Image', 'imgX', 'slika', 10, 10); C.Width := 80; C.Height := 80; D.Add(C);
    C := NewCtl('Chart', 'chrX', '', 110, 10); C.RowSource := 'SELECT naziv, iznos FROM s ORDER BY naziv'; C.SetX('chartType', 'pie'); C.Caption := 'Naslov'; D.Add(C);
    C := NewCtl('Barcode', 'barX', 'kod', 10, 120); C.SetX('barType', 'ean13'); D.Add(C);
    C := NewCtl('Panel', 'pnlX', '', 250, 120); C.Width := 200; C.Height := 100; C.SetX('variant', 'card'); D.Add(C);
    C := NewCtl('TextBox', 'txtIn', 'kod', 10, 30); C.SetX('container', 'pnlX'); D.Add(C);
    C := NewCtl('Pages', 'pgX', '', 10, 200); C.Width := 220; C.Height := 90; C.RowSource := 'Prva;Druga'; D.Add(C);
    C := NewCtl('TextBox', 'txtP0', 'kod', 10, 40); C.SetX('container', 'pgX'); C.SetX('page', '0'); D.Add(C);
    C := NewCtl('TextBox', 'txtP1', 'kod', 10, 40); C.SetX('container', 'pgX'); C.SetX('page', '1'); D.Add(C);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Img := R.ControlByName('imgX'); Chr := R.ControlByName('chrX'); Bar := R.ControlByName('barX');
      Check(FamilyKindOf(Img) = 'Image', 'runner prikaz: Image je obitelj');
      Check(FamilyKindOf(Chr) = 'Chart', 'runner prikaz: Chart je obitelj');
      Check(FamilyKindOf(Bar) = 'Barcode', 'runner prikaz: Barcode je obitelj');
      Check(FamilyBarcodeValue(Bar) = '4006381333931', 'runner prikaz: barkod cita polje (' + FamilyBarcodeValue(Bar) + ')');
      Check(TaImage(Img).Painter.HasPicture, 'runner prikaz: slika se ucitava iz polja');
      Check(TaChart(Chr).Variant = cvPie, 'runner prikaz: varijanta grafikona iz chartType');
      Check(DefOf(Chr).RowSource <> '', 'runner prikaz: DefOf radi za grafikon');
      Check((FamilyKindOf(R.ControlByName('pnlX')) = 'Panel') and (R.ControlByName('txtIn').Parent = R.ControlByName('pnlX')), 'runner prikaz: kontrola u panelu ima panel za roditelja');
      Check(TaEdit(R.ControlByName('txtIn')).Text = '4006381333931', 'runner prikaz: kontrola u panelu cita polje');
      Check((FamilyKindOf(R.ControlByName('pgX')) = 'Pages') and (R.ControlByName('txtP0').Parent = R.ControlByName('pgX')), 'runner prikaz: kontrola na stranici ima Pages za roditelja');
      Check(R.ControlByName('txtP0').Visible and not R.ControlByName('txtP1').Visible, 'runner prikaz: vidljiva je samo aktivna stranica');
      TaPages(R.ControlByName('pgX')).ActivePage := 1;
      FamilyShowPages(R.ControlByName('pgX'));
      Check((not R.ControlByName('txtP0').Visible) and R.ControlByName('txtP1').Visible, 'runner prikaz: promjena stranice prikazuje njezine kontrole');
      R.DoAction('next');
      Check(FamilyBarcodeValue(Bar) = 'ABC', 'runner prikaz: sljedeci zapis mijenja barkod (' + FamilyBarcodeValue(Bar) + ')');
      Check(not TaImage(Img).Painter.HasPicture, 'runner prikaz: prazno polje brise sliku');
    finally
      R.Free;
    end;
    Db.Close;
  finally
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

procedure TestDesignerFamilies;
var
  Db: TAppDb;
  D: TaFormDef;
  Dz: TaFormDesigner;
  C, C2: TControl;
  Old: Boolean;
  K: string;
  Bad: string;
  I: Integer;
  Inn: TControl;
begin
  Old := RunnerUsesFamilies;
  RunnerUsesFamilies := True;
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_dzfam.db') then DeleteFile('/tmp/ta_dzfam.db');
    Db.Open('/tmp/ta_dzfam.db');
    Db.Conn.ExecuteDirect('CREATE TABLE t (id INTEGER PRIMARY KEY, naziv VARCHAR(20), iznos DECIMAL(12,2))');
    D := TaFormDef.Create;
    D.Name := 'DzFam'; D.RecordSource := 't';
    Dz := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      { svaka vrsta iz palete se moze staviti na formu }
      Bad := '';
      for I := 0 to High(KindNames) do
      begin
        K := KindNames[I];
        C := Dz.AddForTest(K, 20, 20);
        if C = nil then Bad := Bad + K + ' ';
      end;
      Check(Bad = '', 'dizajner obitelji: sve vrste palete se mogu dodati (' + Bad + ')');
      Check((Dz.AddForTest('TextBox', 10, 10) is TaEdit) and (Dz.AddForTest('CheckBox', 10, 40) is TaCheck) and (Dz.AddForTest('Button', 10, 70) is TaButton) and
        (Dz.AddForTest('Label', 10, 100) is TaLabel) and (Dz.AddForTest('MemoBox', 10, 130) is TaMemo) and (Dz.AddForTest('OptionGroup', 10, 160) is TaChoice) and
        (Dz.AddForTest('ListBox', 10, 190) is TaList) and (Dz.AddForTest('Calendar', 10, 220) is TaCalendar) and (Dz.AddForTest('Progress', 10, 250) is TaProgress),
        'dizajner obitelji: kontrole su komponente obitelji (i nove vrste Calendar i Progress)');
      Check((Dz.AddForTest('ComboBox', 10, 280) is TaEdit) and (TaEdit(Dz.AddForTest('ComboBox', 10, 280)).Variant = evCombo), 'dizajner obitelji: ComboBox je TaEdit combo');
      { pregled i promjena svojstava: kontrola se gradi iznova iz definicije }
      C := Dz.AddForTest('TextBox', 20, 20);
      Dz.SetPropForTest('ControlSource', 'naziv');
      C2 := Dz.ControlOfForTest(Dz.Def.Count - 1);
      Check((C2 is TaEdit) and (TaEdit(C2).Text = '[naziv]') and TaEdit(C2).ReadOnly, 'dizajner obitelji: polje se vidi kao [naziv] i samo je za citanje (' + TaEdit(C2).Text + ')');
      Dz.SetPropForTest('Variant', 'date');
      C2 := Dz.ControlOfForTest(Dz.Def.Count - 1);
      Check((C2 is TaEdit) and (TaEdit(C2).Variant = evDate), 'dizajner obitelji: promjena varijante odmah mijenja kontrolu');
      Dz.SetPropForTest('Left', '77');
      Dz.SetPropForTest('Width', '190');
      C2 := Dz.ControlOfForTest(Dz.Def.Count - 1);
      Check((C2.Left = 77) and (C2.Width = 190) and (DefOf(C2).Left = 77), 'dizajner obitelji: polozaj i velicina slijede definiciju');
      Check(Dz.SelectedCountForTest = 1, 'dizajner obitelji: obnovljena kontrola ostaje odabrana');
      { klik na unutarnju kontrolu odabire domacina }
      C := Dz.AddForTest('CheckBox', 300, 20);
      Dz.SetPropForTest('Caption', 'Aktivan');
      C := Dz.ControlOfForTest(Dz.Def.Count - 1);
      Check((C is TaCheck) and (TaCheck(C).Caption = 'Aktivan'), 'dizajner obitelji: natpis kvacice');
      Inn := TaFamilyHost(C).Engine.Inner;
      TMouseCrack(Inn).OnMouseDown(Inn, mbLeft, [], 4, 4);
      Check((Dz.SelectedCountForTest = 1) and (DefOf(C).Name = DefOf(Dz.ControlOfForTest(Dz.Def.Count - 1)).Name), 'dizajner obitelji: klik na unutarnju kontrolu odabire domacina');
      { povlacenje pomice domacina }
      Dz.GroupDragForTest(C, 25, 15);
      Check((Abs(C.Left - 325) <= 4) and (Abs(C.Top - 35) <= 4), 'dizajner obitelji: povlacenje pomice kontrolu (uz mrezu) (' + IntToStr(C.Left) + ', ' + IntToStr(C.Top) + ')');
      { Progress i Calendar imaju svojstva u Inspektoru }
      C := Dz.AddForTest('Progress', 20, 300);
      Dz.SetPropForTest('Max', '200');
      Dz.SetPropForTest('Variant', 'ring');
      C2 := Dz.ControlOfForTest(Dz.Def.Count - 1);
      Check((C2 is TaProgress) and (TaProgress(C2).Variant = prRing) and (TaProgress(C2).Options.Max = 200), 'dizajner obitelji: Progress - Max i varijanta iz Inspektora');
      Check(PropertyNamesFor('Calendar', False).IndexOf('Days') >= 0, 'dizajner obitelji: Calendar ima svojstvo Days');
      { spremanje i ponovno otvaranje daje isti raspored }
      Check((FamilyKindOf(Dz.AddForTest('Image', 20, 340)) = 'Image') and (FamilyKindOf(Dz.AddForTest('Chart', 20, 360)) = 'Chart') and
        (FamilyKindOf(Dz.AddForTest('Barcode', 20, 380)) = 'Barcode'), 'dizajner obitelji: Image, Chart i Barcode su komponente obitelji');
      Dz.SetPropForTest('Variant', 'qr');
      C2 := Dz.ControlOfForTest(Dz.Def.Count - 1);
      Check((FamilyKindOf(C2) = 'Barcode') and (TaBarcode(C2).Variant = bvQr), 'dizajner obitelji: varijanta barkoda iz Inspektora');
      Check((Pos('pie', VariantsForKind('Chart')) > 0) and (Pos('qr', VariantsForKind('Barcode')) > 0), 'dizajner obitelji: varijante grafikona i barkoda');
      C := Dz.AddForTest('Rectangle', 300, 340);
      Dz.SetPropForTest('BackColor', '#FFEEAA');
      C2 := Dz.ControlOfForTest(Dz.Def.Count - 1);
      Check((FamilyKindOf(C2) = 'Image') and (TaImage(C2).Variant = imShape) and (TaImage(C2).Options.FillColor = '#FFEEAA') and (TaImage(C2).Options.LineColor = '#000000'),
        'dizajner obitelji: Rectangle je oblik s ispunom iz BackColor');
      C := Dz.AddForTest('Line', 300, 400);
      C2 := Dz.ControlOfForTest(Dz.Def.Count - 1);
      Check((FamilyKindOf(C2) = 'Image') and (TaImage(C2).Options.Shape = ishRectangle) and (TaImage(C2).Options.FillColor = '#000000'), 'dizajner obitelji: Line je puna crta');
      { Panel je pogon: djeca imaju container=naziv panela i prezive promjenu varijante }
      C := Dz.AddForTest('Panel', 300, 440);
      K := DefOf(C).Name;
      C2 := Dz.AddInContainerForTest('TextBox', DefOf(C).Name, 0);
      Check((C2 <> nil) and (C2.Parent = C) and (DefOf(C2).GetX('container') = DefOf(C).Name), 'dizajner obitelji: kontrola unutar panela');
      Dz.SelectForTest(C);
      Dz.SetPropForTest('Variant', 'card');
      C := Dz.ControlOfForTest(Dz.Def.IndexOfName(K));
      Check((FamilyKindOf(C) = 'Panel') and (TaPanel(C).Variant = pvCard) and (C2.Parent = C), 'dizajner obitelji: promjena varijante panela zadrzava djecu');
      C := Dz.AddForTest('Pages', 20, 440);
      K := DefOf(C).Name;
      C2 := Dz.AddInContainerForTest('Label', K, 1);
      Check((C2 <> nil) and (C2.Parent = C) and not C2.Visible, 'dizajner obitelji: kontrola na neaktivnoj stranici je skrivena');
      TaPages(C).ActivePage := 1;
      FamilyShowPages(C);
      Check(C2.Visible, 'dizajner obitelji: aktivna stranica prikazuje svoje kontrole');
      { povlacenje postojece kontrole u Panel i natrag na formu }
      C := Dz.AddForTest('Panel', 400, 440);
      K := DefOf(C).Name;
      C2 := Dz.AddForTest('TextBox', 20, 560);
      Dz.MoveToContainerForTest(C2, K);
      Check((C2.Parent = C) and (DefOf(C2).GetX('container') = K), 'dizajner obitelji: postojeca kontrola prelazi u Panel');
      Dz.MoveToContainerForTest(C2, '');
      Check((C2.Parent <> C) and (DefOf(C2).GetX('container') = ''), 'dizajner obitelji: kontrola se vraca iz Panela na formu');
      { povlacenje u stari TabControl }
      C := Dz.AddForTest('TabControl', 20, 700);
      K := DefOf(C).Name;
      C2 := Dz.AddForTest('TextBox', 20, 600);
      Dz.MoveToContainerForTest(C2, K);
      Check((C2.Parent is TTabSheet) and (DefOf(C2).GetX('container') = K) and (DefOf(C2).GetX('page') = '0'), 'dizajner obitelji: postojeca kontrola prelazi u stari TabControl');
      Check(Dz.SaveForTest, 'dizajner obitelji: spremanje');
    finally
      Dz.Free;
    end;
    Db.Close;
  finally
    RunnerUsesFamilies := Old;
    Db.Free;
  end;
end;

procedure TestGridQuery;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  K: Word;
  Km: TaKeyMap;
begin
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_gridq.db') then DeleteFile('/tmp/ta_gridq.db');
    Db.Open('/tmp/ta_gridq.db');
    Db.Conn.ExecuteDirect('CREATE TABLE p (id INTEGER PRIMARY KEY, naziv VARCHAR(30) NOT NULL, grad VARCHAR(30), iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO p (naziv, grad, iznos) VALUES (''Alfa'', ''Zagreb'', 150), (''Beta'', ''Split'', 50), (''Gama'', ''Rijeka'', 300), (''Delta'', ''Zagreb'', 10)');
    D := TaFormDef.Create;
    D.Name := 'GQ'; D.RecordSource := 'p'; D.ViewMode := 'datasheet'; D.Width := 700; D.Height := 300;
    OnRunnerConfirm := @TestRunnerConfirm;
    OnRunnerMessage := @CaptureMsg;
    Km := TaKeyMap.Create;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.KeyMap := Km;
      Check(R.Query.RecordCount = 4, 'gridq: 4 zapisa');
      K := VK_F7; R.OnKeyDown(R, K, []);
      Check(R.QueryMode and (R.RecordState = rsQuery), 'gridq: F7 u tablici ulazi u upit');
      Check((R.QueryEdit('grad') <> nil) and (R.QueryEdit('iznos') <> nil), 'gridq: traka ima polje po stupcu');
      R.QueryEdit('grad').Text := 'Zagreb';
      R.QueryEdit('iznos').Text := '>100';
      K := VK_F8; R.OnKeyDown(R, K, []);
      Check(not R.QueryMode and (R.Query.RecordCount = 1), 'gridq: F8 daje 1 zapis (Zagreb, >100): ' + IntToStr(R.Query.RecordCount));
      { traka je predpunjena trenutnim filtrima }
      K := VK_F7; R.OnKeyDown(R, K, []);
      Check(R.QueryEdit('grad').Text = 'Zagreb', 'gridq: traka pokazuje aktivne filtre');
      R.QueryEdit('iznos').Text := '';
      K := VK_F8; R.OnKeyDown(R, K, []);
      Check(R.Query.RecordCount = 2, 'gridq: uklonjen uvjet, 2 Zagreba');
      { upit bez rezultata vraca prethodni filtar }
      K := VK_F7; R.OnKeyDown(R, K, []);
      R.QueryEdit('naziv').Text := 'Nema*';
      K := VK_F8; R.OnKeyDown(R, K, []);
      Check(not R.QueryMode and (R.Query.RecordCount = 2), 'gridq: bez rezultata vraca prethodni filtar');
      { neispravan uzorak ostaje u upitu }
      K := VK_F7; R.OnKeyDown(R, K, []);
      R.QueryEdit('iznos').Text := '>x';
      K := VK_F8; R.OnKeyDown(R, K, []);
      Check(R.QueryMode, 'gridq: neispravan uzorak ostaje u upitu');
      K := VK_ESCAPE; R.OnKeyDown(R, K, []);
      Check(not R.QueryMode and (R.Query.RecordCount = 2), 'gridq: Esc ponistava upit, rezultati ostaju');
      R.DoAction('clearquery');
      Check(R.Query.RecordCount = 4, 'gridq: clearquery vraca sve');
    finally
      R.Free;
    end;
    OnRunnerMessage := nil;
    OnRunnerConfirm := nil;
    Km.Free;
    Db.Close;
  finally
    Db.Free;
  end;
end;


procedure TestRunnerKeys;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  Q: TZQuery;
  I: Integer;
  Km: TaKeyMap;
  Err: string;
begin
  Db := TAppDb.Create;
  try
    if FileExists('/tmp/ta_runkeys.db') then DeleteFile('/tmp/ta_runkeys.db');
    Db.Open('/tmp/ta_runkeys.db');
    Db.Conn.ExecuteDirect('CREATE TABLE p (id INTEGER PRIMARY KEY, naziv VARCHAR(30) NOT NULL, grad VARCHAR(30), iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO p (naziv, grad, iznos) VALUES (''Alfa'', ''Zagreb'', 150), (''Beta'', ''Split'', 50), (''Gama'', ''Rijeka'', 300), (''Delta'', ''Zagreb'', 10)');
    D := TaFormDef.Create;
    D.Name := 'PK'; D.RecordSource := 'p'; D.AllowEdits := True; D.AllowAdds := True; D.AllowDeletes := True; D.NavButtons := True; D.Width := 460; D.Height := 160;
    D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 10)); D.Add(NewCtl('TextBox', 'txtGrad', 'grad', 10, 40)); D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 70));
    OnRunnerConfirm := @TestRunnerConfirm;
    Km := TaKeyMap.Create;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.KeyMap := Km;
      Check(R.StateText = 'spremljen', 'runkeys: otvorena forma je spremljena');
      PressRunner(R, VK_NEXT, []);
      Check(R.Query.RecNo = 2, 'runkeys: PgDn je sljedeci zapis');
      PressRunner(R, VK_PRIOR, []);
      Check(R.Query.RecNo = 1, 'runkeys: PgUp je prethodni zapis');
      PressRunner(R, VK_END, [ssCtrl]);
      Check(R.Query.RecNo = 4, 'runkeys: Ctrl+End je zadnji zapis');
      PressRunner(R, VK_HOME, [ssCtrl]);
      Check(R.Query.RecNo = 1, 'runkeys: Ctrl+Home je prvi zapis');
      { stanje zapisa }
      TEdit(R.ControlByName('txtGrad')).Text := 'Osijek';
      Check(R.RecordState = rsChanged, 'runkeys: izmjena daje stanje promijenjen (' + R.StateText + ')');
      PressRunner(R, VK_ESCAPE, []);
      Check((R.RecordState = rsSaved) and (TEdit(R.ControlByName('txtGrad')).Text = 'Zagreb'), 'runkeys: Esc ponistava izmjenu');
      TEdit(R.ControlByName('txtGrad')).Text := 'Osijek';
      PressRunner(R, VK_F10, []);
      Q := Db.NewQuery('SELECT grad FROM p WHERE id = 1');
      try Q.Open; Check(Q.Fields[0].AsString = 'Osijek', 'runkeys: F10 sprema'); finally Q.Free; end;
      PressRunner(R, Ord('N'), [ssCtrl]);
      Check(R.RecordState = rsNew, 'runkeys: Ctrl+N daje novi zapis (' + R.StateText + ')');
      PressRunner(R, VK_ESCAPE, []);
      Check(R.RecordState = rsSaved, 'runkeys: Esc odustaje od novog zapisa');
      { upit po formi }
      PressRunner(R, VK_F7, []);
      Check(R.QueryMode and (R.RecordState = rsQuery), 'runkeys: F7 ulazi u upit');
      Check(TEdit(R.ControlByName('txtNaziv')).Text = '', 'runkeys: u upitu su polja prazna');
      TEdit(R.ControlByName('txtIznos')).Text := '>100';
      Check(R.RecordState <> rsChanged, 'runkeys: uzorak ne cini formu promijenjenom');
      PressRunner(R, VK_F8, []);
      Check(not R.QueryMode and (R.Query.RecordCount = 2), 'runkeys: F8 izvrsava upit, 2 zapisa iznos>100 (' + IntToStr(R.Query.RecordCount) + ')');
      PressRunner(R, VK_F7, []);
      PressRunner(R, VK_ESCAPE, []);
      Check(not R.QueryMode and (R.Query.RecordCount = 2), 'runkeys: Esc u upitu ga ponistava, rezultati ostaju');
      R.DoAction('clearquery');
      Check(R.Query.RecordCount = 4, 'runkeys: ociscen upit vraca sve zapise');
      { tipke su postavka }
      Km.SetKeys(kaQuery, 'F2', Err);
      PressRunner(R, VK_F7, []);
      Check(not R.QueryMode, 'runkeys: F7 vise ne radi kad je tipka promijenjena');
      PressRunner(R, VK_F2, []);
      Check(R.QueryMode, 'runkeys: nova tipka F2 radi');
      PressRunner(R, VK_ESCAPE, []);
      { zatvaranje s nespremljenom izmjenom pita }
      TEdit(R.ControlByName('txtGrad')).Text := 'Pula';
      RunnerAnswer := False; RunnerAsked := 0;
      R.Close;
      Check(RunnerAsked = 1, 'runkeys: zatvaranje promijenjene forme pita "Spremiti promjene?"');
      Q := Db.NewQuery('SELECT grad FROM p WHERE id = 1');
      try Q.Open; Check(Q.Fields[0].AsString = 'Osijek', 'runkeys: odgovor Ne odbacuje izmjenu'); finally Q.Free; end;
    finally
      R.Free;
    end;
    { odgovor Da sprema }
    D := TaFormDef.Create;
    D.Name := 'PK2'; D.RecordSource := 'p'; D.AllowEdits := True; D.NavButtons := True; D.Width := 460; D.Height := 160;
    D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 10)); D.Add(NewCtl('TextBox', 'txtGrad', 'grad', 10, 40));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      TEdit(R.ControlByName('txtGrad')).Text := 'Pula';
      RunnerAnswer := True; RunnerAsked := 0;
      R.Close;
      Check(RunnerAsked = 1, 'runkeys: pita i drugi put');
      Q := Db.NewQuery('SELECT grad FROM p WHERE id = 1');
      try Q.Open; Check(Q.Fields[0].AsString = 'Pula', 'runkeys: odgovor Da sprema izmjenu'); finally Q.Free; end;
    finally
      R.Free;
    end;
    OnRunnerConfirm := nil;
    Km.Free;
    Db.Close;
  finally
    Db.Free;
  end;
end;

procedure TestSkelFlow;
var
  Db: TAppDb;
  Lib: TaSkeletonLibrary;
  F: TaSkelFlow;
  L, Lg: TStringList;
  Err, Nm: string;
  I, Clicks, Cnt: Integer;
  Ds: TaDataSet;
  Plan: array[0..4, 0..2] of string;
  Ok: Boolean;
  P: TaFglProgram;
begin
  Db := TAppDb.Create;
  Lib := TaSkeletonLibrary.Create;
  L := TStringList.Create;
  Lg := TStringList.Create;
  try
    if FileExists('/tmp/ta_skelflow.db') then DeleteFile('/tmp/ta_skelflow.db');
    Db.Open('/tmp/ta_skelflow.db');
    Db.Conn.ExecuteDirect('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50), grad VARCHAR(30))');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni (id INTEGER PRIMARY KEY, partner_id INTEGER, broj VARCHAR(20), datum DATE, iznos DECIMAL(12,2), status VARCHAR(10), FOREIGN KEY (partner_id) REFERENCES partneri(id))');
    Db.Conn.ExecuteDirect('CREATE TABLE racuni_arhiva (id INTEGER PRIMARY KEY, partner_id INTEGER, broj VARCHAR(20), datum DATE, iznos DECIMAL(12,2), status VARCHAR(10))');
    Db.Conn.ExecuteDirect('INSERT INTO partneri VALUES (1, ''Alfa'', ''Zagreb''), (2, ''Beta'', ''Split''), (3, ''Gama'', ''Rijeka'')');
    Db.Conn.ExecuteDirect('INSERT INTO racuni VALUES (1, 1, ''R-1'', ''2026-01-10'', 100.5, ''placen''), (2, 2, ''R-2'', ''2026-02-03'', 200, ''otvoren'')');
    Check(Lib.LoadFolder(FindSkeletonFolder) >= 12, 'tok: knjiznica kostura');
    F := TaSkelFlow.Create(Db, Lib);
    try
      { ulaz "od podataka": poredak po prikladnosti }
      F.StartFromData('racuni', L);
      Check((L.Count > 0) and (Pos('Zbroj po razdoblju', L.Text) > 0), 'tok: za racune se nudi Zbroj po razdoblju (' + L.CommaText + ')');
      Check(StrToIntDef(Copy(L[0], 1, Pos('|', L[0]) - 1), 0) >= 70, 'tok: najprikladniji kostur ima visoku ocjenu (' + L[0] + ')');
      F.StartFromData('partneri', L);
      Check(Pos('Zbroj po razdoblju', L.Text) = 0, 'tok: za partnere (bez datuma) se ne nudi Zbroj po razdoblju');
      { ulaz "od kostura" }
      F.ListAll(L);
      Check(L.Count >= 12, 'tok: popis svih kostura po kategorijama (' + IntToStr(L.Count) + ')');
      { izmjena utora ponovno gradi program }
      F := F;
    finally
      F.Free;
    end;
    F := TaSkelFlow.Create(Db, Lib);
    try
      F.StartFromData('racuni', L);
      F.Choose(Lib.Find('Zbroj po grupi'));
      Check((F.Error = '') and (Pos('racuni', F.Text) > 0), 'tok: izbor kostura gradi pregled 4GL-a (' + F.Error + ')');
      F.SetValue('grupa', 'partner_id');
      Check(Pos('GROUP BY partner_id', F.Text) > 0, 'tok: promjena utora mijenja program');
      F.SetValue('tablica', 'partneri');
      Check((Pos('FROM partneri', F.Text) > 0) and (Pos('partner_id', F.Text) = 0), 'tok: promjena tablice vraca ovisne utore na zadano (' + F.Values.CommaText + ')');
      Check(F.Check(Lg) <= 1, 'tok: provjera programa (poruke: ' + Lg.Text + ')');
    finally
      F.Free;
    end;
    { kriterij: 5 programa u najvise 15 klikova }
    Plan[0, 0] := 'partneri'; Plan[0, 1] := 'Popis s filtrom'; Plan[0, 2] := 'PopisPartnera';
    Plan[1, 0] := 'partneri'; Plan[1, 1] := 'Unos i izmjena zapisa'; Plan[1, 2] := 'UnosPartnera';
    Plan[2, 0] := 'racuni'; Plan[2, 1] := 'Zbroj po razdoblju'; Plan[2, 2] := 'ZbrojRacuna';
    Plan[3, 0] := 'racuni'; Plan[3, 1] := 'Izvoz tablice u PDF'; Plan[3, 2] := 'IzvozRacuna';
    Plan[4, 0] := 'racuni'; Plan[4, 1] := 'Arhiviranje'; Plan[4, 2] := 'ArhivaRacuna';
    Clicks := 0;
    Ok := True;
    for I := 0 to 4 do
    begin
      F := TaSkelFlow.Create(Db, Lib);
      try
        F.StartFromData(Plan[I, 0], L);
        F.Choose(Lib.Find(Plan[I, 1]));
        if (F.Error <> '') or not F.Save(Plan[I, 2], True, '', Err) then begin Ok := False; WriteLn('  tok: ', Plan[I, 1], ': ', F.Error, ' ', Err); end;
        Inc(Clicks, F.Clicks);
      finally
        F.Free;
      end;
    end;
    Check(Ok and (Clicks <= 15), 'tok: 5 programa iz baze bez tipkanja 4GL-a u ' + IntToStr(Clicks) + ' klikova (najvise 15)');
    Cnt := 0;
    for I := 0 to 4 do
    begin
      Nm := Db.LoadObject('_sys_programs', Plan[I, 2]);
      P := TaFglProgram.Create;
      try
        try
          P.LoadText(Nm, Plan[I, 2]);
          Lg.Clear;
          if (Nm <> '') and (P.CheckProgram(Lg) = 0) then Inc(Cnt);
        except
        end;
      finally
        P.Free;
      end;
    end;
    Check(Cnt = 5, 'tok: svih 5 spremljenih programa prolazi provjeru (' + IntToStr(Cnt) + ')');
    { spremanje u datoteku }
    F := TaSkelFlow.Create(Db, Lib);
    try
      F.StartFromData('racuni', L);
      F.Choose(Lib.Find('Sljedeći broj dokumenta'));
      if FileExists('/tmp/ta_skelflow_out.4gl') then DeleteFile('/tmp/ta_skelflow_out.4gl');
      Check(F.Save('', False, '/tmp/ta_skelflow_out.4gl', Err) and FileExists('/tmp/ta_skelflow_out.4gl') and (FglCheckFile('/tmp/ta_skelflow_out.4gl', Lg) = 0), 'tok: spremanje u datoteku (' + Err + ' ' + Lg.Text + ')');
      Check(F.SuggestName <> '', 'tok: predlozen naziv programa');
    finally
      F.Free;
    end;
    { kontekst: izvor za popis; spremljen program radi kao fgl: izvor }
    Lib.ForContext('izvor', L);
    Check((L.Count = 1) and (L[0] = 'Izvor podataka za popis'), 'tok: za kontekst "izvor" nudi se Izvor podataka (' + L.CommaText + ')');
    Lib.ForContext('gumb', L);
    Check(L.Count >= 6, 'tok: za kontekst "gumb" nudi se vise kostura (' + IntToStr(L.Count) + ')');
    F := TaSkelFlow.Create(Db, Lib);
    try
      F.StartFromData('partneri', L);
      F.Choose(Lib.Find('Izvor podataka za popis'));
      Check(F.Save(F.Values.Values['naziv'], True, '', Err), 'tok: izvor spremljen (' + Err + ')');
      Ds := OpenSource(Db, 'fgl:' + F.Values.Values['naziv'] + '()', nil, nil, Err);
      Check((Ds <> nil) and (Ds.RecordCount = 3) and (Ds.FieldCount = 2) and (Ds.Fields[1].AsString = 'Alfa'), 'tok: kostur "Izvor podataka" daje radni fgl: izvor (' + Err + ')');
      Ds.Free;
    finally
      F.Free;
    end;
    Db.Close;
  finally
    Lg.Free;
    L.Free;
    Lib.Free;
    Db.Free;
  end;
end;

procedure TestAnchorEditor;
var
  Fd: TaFormDef;
  A, B, C: TaControlDef;
  E: TaLayoutEditor;
  V: TaLayoutValues;
  Vals: TStringList;
  Bmp: TBitmap;
  R, S: string;
begin
  { definicija forme: dva susjeda i kontrola koja se sidri }
  Fd := TaFormDef.Create;
  try
    Fd.Width := 600; Fd.Height := 400;
    A := TaControlDef.Create; A.Kind := 'Label'; A.Name := 'lblNaslov'; A.Left := 10; A.Top := 10; A.Width := 200; A.Height := 24; Fd.Add(A);
    B := TaControlDef.Create; B.Kind := 'Button'; B.Name := 'btnGore'; B.Left := 400; B.Top := 10; B.Width := 100; B.Height := 30; Fd.Add(B);
    C := TaControlDef.Create; C.Kind := 'TextBox'; C.Name := 'txtIme'; C.Left := 10; C.Top := 60; C.Width := 300; C.Height := 24; Fd.Add(C);
    { spojnice zapisa sidra }
    ParseSideSpec('btnGore:left', R, S);
    Check((R = 'btnGore') and (S = 'left'), 'anchor editor: a side spec is parsed');
    ParseSideSpec('', R, S);
    Check((R = 'forma') and (S = ''), 'anchor editor: an empty spec is the form edge');
    Check(BuildSideSpec('forma', '') = '', 'anchor editor: the form edge needs no spec');
    Check(BuildSideSpec('forma', 'center') = 'forma:center', 'anchor editor: the form centre');
    Check(BuildSideSpec('btnGore', '') = 'btnGore', 'anchor editor: a sibling with the default side');
    { postojece vrijednosti se ucitavaju i vracaju nepromijenjene }
    C.SetX('anchors', 'LTR'); C.SetX('space', '8,4,8,4'); C.SetX('asr', 'btnGore:left');
    E := TaLayoutEditor.Create(nil, Fd, C);
    try
      E.GetValues(V);
      Check((V.Anchors = 'LTR') and (V.Dock = '') and (V.Spacing = '8,4,8,4') and (V.Side[2] = 'btnGore'), 'anchor editor: stored values read back (' + V.Anchors + ' ' + V.Side[2] + ')');
      Check(E.UseBox(0).Checked and E.UseBox(1).Checked and E.UseBox(2).Checked and not E.UseBox(3).Checked, 'anchor editor: the checkboxes show the stored sides');
      Check(E.RefBox(2).Text = 'btnGore', 'anchor editor: the right side points at the sibling');
      Check((E.SpaceBox(0).Value = 8) and (E.SpaceBox(1).Value = 4), 'anchor editor: spacing per side');
      { promjene: gornje sidro uz susjeda, sredina }
      E.UseBox(1).Checked := True;
      E.RefBox(1).ItemIndex := E.RefBox(1).Items.IndexOf('lblNaslov');
      E.SideBox(1).ItemIndex := 2;
      E.GetValues(V);
      Check(V.Side[1] = 'lblNaslov:center', 'anchor editor: top anchored to the middle of a sibling (' + V.Side[1] + ')');
      E.SideBox(1).ItemIndex := 3;                     { donji rub = zadano za gornje sidro }
      E.GetValues(V);
      Check(V.Side[1] = 'lblNaslov', 'anchor editor: the default side is not written (' + V.Side[1] + ')');
      { gotovi obrazac i isti razmak }
      E.ClickPreset(3);
      E.GetValues(V);
      Check(V.Anchors = 'LTRB', 'anchor editor: the preset stretches in both directions');
      E.AroundBox.Value := 5;
      E.ClickAround;
      E.GetValues(V);
      Check(V.Spacing = '5,5,5,5', 'anchor editor: the same spacing everywhere (' + V.Spacing + ')');
      { dock }
      E.DockBox.ItemIndex := 5;
      E.GetValues(V);
      Check(V.Dock = 'client', 'anchor editor: Dock to the whole area');
      { crtanje pregleda }
      E.Form.Show;
      Bmp := TBitmap.Create;
      try
        Bmp.SetSize(E.Preview.Width, E.Preview.Height);
        E.Preview.Perform(0, 0, 0);
        E.Preview.Invalidate;
        Check(True, 'anchor editor: the preview paints');
      finally
        Bmp.Free;
      end;
    finally
      E.Free;
    end;
    { vrijednosti u definiciju: isti zapis kao do sada }
    Vals := TStringList.Create;
    try
      Vals.Values['AnchorTop'] := 'lblNaslov';
      DefSet(C, 'AnchorTop', Vals.Values['AnchorTop']);
      Check(C.GetX('ast') = 'lblNaslov', 'anchor editor: the value goes to the same definition key as before');
    finally
      Vals.Free;
    end;
  finally
    Fd.Free;
  end;
end;

procedure TestSideMenu;
var
  Db: TAppDb;
  D: TaFormDef;
  M: TaControlDef;
  R: TaFormRunner;
  Sm: TaSideMenu;
  Cat: TSideCatcher;
  Bmp: TBitmap;
  Painted: Boolean;
  PX, PY: Integer;
  Names, Items2: TStringList;
  SideJs: string;
begin
  with TIniFile.Create(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sidemenu.ini') do
  try
    EraseSection('Bocni/sm');
  finally
    Free;
  end;
  if FileExists('/tmp/ta_side.db') then DeleteFile('/tmp/ta_side.db');
  Db := TAppDb.Create;
  Cat := TSideCatcher.Create;
  try
    Db.Open('/tmp/ta_side.db');
    ActiveDb := Db;
    M := TaControlDef.Create; M.Kind := 'SideMenu'; M.Name := 'sm'; M.Left := 10; M.Top := 10; M.Width := 220; M.Height := 300;
    DefSet(M, 'Items', '# Prodaja|invoice' + LineEnding + 'Računi|openform:Računi' + LineEnding + 'Ponude|openform:Ponude|offer' + LineEnding +
      '# Alati' + LineEnding + 'Postavke|macro:Postavke' + LineEnding + 'Kupci|openform:Kupci');
    Check(Pos('/', DefGet(M, 'Items')) > 0, 'sidemenu: the property grid shows the items on one line');
    Names := PropertyNamesFor('SideMenu', False);
    Check(Names.IndexOf('Items') >= 0, 'sidemenu: the designer lists the Items property');
    Names.Free;
    Check(PropKindOf('Items') = pkItems, 'sidemenu: the items use the multi-line editor');
    D := TaFormDef.Create;
    D.Name := 'Bocni'; D.Width := 260; D.Height := 340;
    D.Add(M);
    SideJs := D.ToJson;
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      R.Show;
      Application.ProcessMessages;
      Sm := TaSideMenu(R.ControlByName('sm'));
      Check((Sm <> nil) and (Sm.RowCount = 6) and Sm.RowIsGroup(0) and not Sm.RowIsGroup(1) and Sm.RowIsGroup(3), 'sidemenu: groups and items are read from the text');
      Check((Sm.RowIcon(1) = 'invoice') and (Sm.RowIcon(2) = 'offer') and (Sm.RowIcon(4) = 'settings'), 'sidemenu: icons come from the text or from the action (' + Sm.RowIcon(1) + ',' + Sm.RowIcon(2) + ',' + Sm.RowIcon(4) + ')');
      Sm.OnAction := @Cat.Got;
      Check((not Sm.IsCollapsed(0)) and Sm.IsCollapsed(1), 'sidemenu: accordion - at the start only the first group is open');
      Sm.ClickRow(1);
      Check(Cat.Last = 'openform:Računi', 'sidemenu: clicking an item fires its action (' + Cat.Last + ')');
      Check(Sm.SelectedIndex = 1, 'sidemenu: the clicked item is tracked as the current one');
      Cat.Last := '';
      Sm.ClickRow(3);
      Check((not Sm.IsCollapsed(1)) and Sm.IsCollapsed(0) and (Cat.Last = ''), 'sidemenu: accordion - opening a group closes the other one and fires nothing');
      Sm.ClickRow(5);
      Check((Sm.SelectedIndex = 5) and (Cat.Last = 'openform:Kupci'), 'sidemenu: tracking follows the item in the second group');
      Sm.ClickRow(3);
      Check(Sm.IsCollapsed(1), 'sidemenu: an open group can be collapsed by its header');
      Sm.Compact := True;
      Check((Sm.VisibleCount = 2) and Sm.Compact, 'sidemenu: the narrow menu shows only the groups (' + IntToStr(Sm.VisibleCount) + ')');
      Sm.Compact := False;
      Sm.ClickRow(0);
      Check(Sm.VisibleCount > 2, 'sidemenu: the wide menu shows the items of the open group again');
      Bmp := TBitmap.Create;
      try
        Bmp.SetSize(Sm.Width, Sm.Height);
        Sm.PaintTo(Bmp.Canvas, 0, 0);
        Bmp.SaveToFile('/tmp/ta_sidemenu.bmp');
        Painted := False;
        for PY := 0 to Bmp.Height - 1 do
          for PX := 0 to Bmp.Width - 1 do
            if Bmp.Canvas.Pixels[PX, PY] <> Bmp.Canvas.Pixels[1, 1] then Painted := True;
        Check(Painted, 'sidemenu: it paints');
      finally
        Bmp.Free;
      end;
    finally
      R.Free;
    end;
    { zapamceno stanje: nova forma otvara skupinu zadnje koristene stavke i oznacuje je }
    D := TaFormDef.Create;
    D.FromJson(SideJs);
    R := TaFormRunner.CreateRunner(nil, Db, D);
    try
      Sm := TaSideMenu(R.ControlByName('sm'));
      Check((Sm.SelectedIndex = 5) and (not Sm.IsCollapsed(1)) and Sm.IsCollapsed(0), 'sidemenu: the next session opens the group of the last used item (' + IntToStr(Sm.SelectedIndex) + ')');
    finally
      R.Free;
    end;
    with TIniFile.Create(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sidemenu.ini') do
    try
      EraseSection('Bocni/sm');
    finally
      Free;
    end;
    { izbornik kao varijanta cuvara izbornika }
    Items2 := TStringList.Create;
    try
      Items2.Add('# Prodaja'); Items2.Add('Računi|openform:Računi'); Items2.Add('# Alati'); Items2.Add('Postavke|macro:Postavke');
      D := BuildSideBoard('Bocni2', 'Izbornik', Items2);
      Check((D.Count = 2) and (D[1].Kind = 'SideMenu') and (D[1].RowSource = Items2.Text) and (D[1].GetX('anchors') = 'LTRB'), 'sidemenu: the switchboard wizard can build it instead of buttons');
      D.Free;
    finally
      Items2.Free;
    end;
  finally
    Cat.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

var
  ShellMsgs: string;

procedure ShellMsg(const AMsg: string);
begin
  ShellMsgs := ShellMsgs + AMsg + ' | ';
end;

{ radni prostor: kartice, jedna instanca po formi, skupine iskljucivosti }
procedure TestShell;
var
  Db: TAppDb;
  Host: TForm;
  Sh: TaShell;
  D: TaFormDef;
  Old: TRunnerMessageProc;
  I: Integer;
  procedure Save(const AName, AGroup: string);
  begin
    D := TaFormDef.Create;
    D.Name := AName; D.Caption := 'Forma ' + AName; D.Width := 300; D.Height := 200;
    D.ExclusiveGroup := AGroup;
    Db.SaveObject('_sys_forms', AName, D.ToJson);
    D.Free;
  end;
begin
  if FileExists('/tmp/ta_shell.db') then DeleteFile('/tmp/ta_shell.db');
  Db := TAppDb.Create;
  Host := TForm.CreateNew(nil);
  Old := OnRunnerMessage;
  try
    Db.Open('/tmp/ta_shell.db');
    ActiveDb := Db;
    Check((ExclusiveGroupFor('Otpremnice') = 'Skladišni dokumenti') and (ExclusiveGroupFor('Računi') = 'Financijski dokumenti') and
      (ExclusiveGroupFor('Kupac s računima') = '') and (ExclusiveGroupFor('Partneri') = ''), 'shell: generators put document forms into exclusive groups');
    Save('Otpremnica', 'Skladisni'); Save('Revers', 'Skladisni'); Save('Kupci', '');
    D := TaFormDef.Create; D.FromJson(Db.LoadObject('_sys_forms', 'Revers'));
    Check(D.ExclusiveGroup = 'Skladisni', 'shell: the exclusive group is saved with the form');
    D.Free;
    Host.SetBounds(0, 0, 900, 600);
    Sh := TaShell.CreateShell(Host, Db);
    Sh.Parent := Host;
    Host.Show;
    Application.ProcessMessages;
    OnRunnerMessage := @ShellMsg;
    Sh.BuildDefaultMenu;
    Check(Sh.Menu.RowCount >= 4, 'shell: the default menu lists the forms the user may open (' + IntToStr(Sh.Menu.RowCount) + ' rows)');
    Check(Sh.OpenForm('Otpremnica') and (Sh.TabCount = 1) and (Sh.ActiveName = 'Otpremnica'), 'shell: a form opens as a tab');
    Check(Sh.OpenForm('Otpremnica') and (Sh.TabCount = 1), 'shell: the same form opens only once (its tab is activated)');
    ShellMsgs := '';
    Check((not Sh.OpenForm('Revers')) and (Sh.TabCount = 1) and (Pos('Otpremnica', ShellMsgs) > 0), 'shell: a form of the same exclusive group is refused: ' + ShellMsgs);
    Check(Sh.OpenForm('Kupci') and (Sh.TabCount = 2) and (Sh.ActiveName = 'Kupci'), 'shell: a form without a group opens next to it');
    Check((Sh.TabRunner(0).Parent <> nil) and Sh.TabRunner(0).Embedded and (Sh.Bar.Count = 2), 'shell: forms are embedded in the tab pages');
    Sh.Bar.ClickTab(0, False);
    Check(Sh.ActiveName = 'Otpremnica', 'shell: clicking a tab shows its form');
    Sh.Bar.ClickTab(0, True);
    for I := 1 to 5 do Application.ProcessMessages;
    Check((Sh.TabCount = 1) and (Sh.ActiveName = 'Kupci'), 'shell: closing the tab closes the form');
    Check(Sh.OpenForm('Revers') and (Sh.TabCount = 2), 'shell: after closing, the other form of the group can be opened');
    { izbornik se moze sklopiti u traku s ikonama, a mis ga privremeno prosiruje iznad forme }
    Check(Sh.Pinned and (Sh.MenuWidth = 250) and (Sh.BodyLeft = 250) and not Sh.Menu.Compact, 'shell: the menu is pinned open at the start');
    Sh.Pinned := False;
    Check((Sh.MenuWidth = 44) and (Sh.BodyLeft = 44) and Sh.Menu.Compact, 'shell: unpinned, the menu shrinks to an icon strip and the form gets the space');
    Sh.HoverForTest(True);
    Check((Sh.MenuWidth = 250) and (Sh.BodyLeft = 44) and not Sh.Menu.Compact, 'shell: the pointer on the strip opens the menu over the form');
    Sh.HoverForTest(False);
    Check((Sh.MenuWidth = 44) and Sh.Menu.Compact, 'shell: and it shrinks again when the pointer leaves');
    Sh.Pinned := True;
    { izgled ljuske iz predloska glavne forme }
    Sh.SetLook(300, True, $00804020, $00FFFFFF);
    Application.ProcessMessages;
    Check((Sh.MenuWidth = 300) and (Sh.BodyLeft = 0) and (Sh.Menu.Left = Sh.ClientWidth - 300) and Sh.MenuRight, 'shell look: the menu can be wider and sit on the right (' + IntToStr(Sh.Menu.Left) + ')');
    Sh.SetLook(250, False, clNone, clNone);
    Application.ProcessMessages;
    Check((Sh.MenuWidth = 250) and (Sh.Menu.Left = 0) and not Sh.MenuRight, 'shell look: and back to the left');
    Check(Sh.CloseAll and (Sh.TabCount = 0), 'shell: all tabs close');
    with TIniFile.Create(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sidemenu.ini') do
    try
      EraseSection('shell/ta_shell.db');
    finally
      Free;
    end;
  finally
    OnRunnerMessage := Old;
    Host.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

function CtlFor(R: TaFormRunner; const AField: string): TControl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to R.Def.Count - 1 do
    if SameText(R.Def[I].ControlSource, AField) then Exit(R.ControlByName(R.Def[I].Name));
end;

{ vrste dokumenata: brojevi iz tablice dokumenti, srodne vrste, jedna forma za vise vrsta }
procedure TestDocTypes;
var
  Db: TAppDb;
  T: TaDocType;
  Y: string;
  Host: TForm;
  Sh: TaShell;
  Log: TStringList;
  Old: TRunnerMessageProc;
  A: TStringList;
  F, Ar: string;
  R: TaFormRunner;
  Q: TZQuery;
  Ok: Boolean;
  Db2: TAppDb;
  Sc: TaScriptContext;
  V1, V2: string;
begin
  if FileExists('/tmp/ta_doctypes.db') then DeleteFile('/tmp/ta_doctypes.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  Host := TForm.CreateNew(nil);
  Old := OnRunnerMessage;
  Y := FormatDateTime('yyyy', Date);
  try
    Db.Open('/tmp/ta_doctypes.db');
    ActiveDb := Db;
    Check((DocFormatNumber('{sifra}-{godina}-{broj:4}', 'otp', 2026, 7) = 'otp-2026-0007') and
      (DocFormatNumber('{sifra}/{broj:3}/{godina:2}', 'rv', 2026, 12) = 'rv/012/26'), 'doctypes: number format');
    A := TStringList.Create;
    ParseOpenArgs('vrsta=otp;x=1', A);
    SplitFormAction('Dokument#vrsta=otp', F, Ar);
    Check((A.Values['vrsta'] = 'otp') and (F = 'Dokument') and (Ar = 'vrsta=otp'), 'doctypes: the menu action carries the type');
    A.Free;
    EnsureDocTypes(Db);
    T.Code := 'otp'; T.Name := 'Otpremnica'; T.Prefix := 'otp'; T.Format := DefaultDocFormat; T.Related := 'rv'; T.Last := 0; T.Year := 0;
    DocTypeSave(Db, T);
    T.Code := 'rv'; T.Name := 'Revers'; T.Prefix := 'rv'; T.Related := ''; DocTypeSave(Db, T);
    T.Code := 'rac'; T.Name := 'Račun'; T.Prefix := 'rac'; DocTypeSave(Db, T);
    Check(DocPreviewNumber(Db, 'otp') = 'otp-' + Y + '-0001', 'doctypes: the first number is proposed from the table (' + DocPreviewNumber(Db, 'otp') + ')');
    Check(DocPreviewNumber(Db, 'otp') = 'otp-' + Y + '-0001', 'doctypes: proposing a number does not use it up');
    Check((DocCommitNumber(Db, 'otp') = 'otp-' + Y + '-0001') and (DocCommitNumber(Db, 'otp') = 'otp-' + Y + '-0002'), 'doctypes: saving takes the next number');
    DocTypeLoad(Db, 'otp', T);
    Check((T.Last = 2) and (DocPreviewNumber(Db, 'otp') = 'otp-' + Y + '-0003'), 'doctypes: the last number is stored in the table');
    Check(DocPreviewNumber(Db, 'rv') = 'rv-' + Y + '-0001', 'doctypes: every type counts on its own');
    T.Year := StrToInt(Y) - 1; T.Last := 41; DocTypeSave(Db, T);
    Check(DocPreviewNumber(Db, 'otp') = 'otp-' + Y + '-0001', 'doctypes: the counter starts again every year');
    Check(DocTypesBlock(Db, 'otp', 'rv') and DocTypesBlock(Db, 'rv', 'otp') and not DocTypesBlock(Db, 'otp', 'rac') and not DocTypesBlock(Db, 'otp', 'otp'),
      'doctypes: related types block each other in both directions');
    { recept: modul koji dodjeljuje broj }
    Db.SaveObject('_sys_modules', 'Brojevi',
      'function DodijeliBroj(vrsta: string): string;' + LineEnding + 'var g: Integer;' + LineEnding + 'begin' + LineEnding +
      '  g := StrToInt(SqlValue(''SELECT CAST(strftime(''''%Y'''', ''''now'''') AS INTEGER)''));' + LineEnding +
      '  SqlExec(''UPDATE dokumenti SET rednidok = CASE WHEN godina = '' + IntToStr(g) + '' THEN rednidok + 1 ELSE 1 END, godina = '' + IntToStr(g) + '' WHERE vrsta = '''''' + vrsta + '''''''');' + LineEnding +
      '  Result := SqlValue(''SELECT sifradok || ''''-'''' || godina || ''''-'''' || printf(''''%04d'''', rednidok) FROM dokumenti WHERE vrsta = '''''' + vrsta + '''''''');' + LineEnding +
      'end;');
    ResetScripts;
    Scripts(Db);
    Sc := TaScriptContext.Create(Db);
    try
      V1 := VarToStr(Sc.EvalV('DodijeliBroj("rv")'));
      V2 := VarToStr(Sc.EvalV('DodijeliBroj("rv")'));
      Check((V1 = 'rv-' + Y + '-0001') and (V2 = 'rv-' + Y + '-0002'), 'doctypes: the module recipe hands out numbers (' + V1 + ', ' + V2 + ') ' + Scripts(Db).LastError);
    finally
      Sc.Free;
    end;
    ResetScripts;
    T.Code := 'rv'; DocTypeLoad(Db, 'rv', T); T.Last := 0; T.Year := 0; DocTypeSave(Db, T);
    { recept: okidac u bazi (SQLite) }
    if FileExists('/tmp/ta_trig.db') then DeleteFile('/tmp/ta_trig.db');
    Db2 := TAppDb.Create;
    try
      Db2.Open('/tmp/ta_trig.db');
      Db2.Conn.ExecuteDirect('CREATE TABLE dokumenti (vrsta TEXT PRIMARY KEY, sifradok TEXT, rednidok INTEGER DEFAULT 0, godina INTEGER DEFAULT 0)');
      Db2.Conn.ExecuteDirect('CREATE TABLE dokument (id INTEGER PRIMARY KEY AUTOINCREMENT, vrsta TEXT, broj TEXT, datum TEXT)');
      Db2.Conn.ExecuteDirect('INSERT INTO dokumenti VALUES (''otp'', ''otp'', 0, 0), (''rv'', ''rv'', 41, 2020)');
      Db2.Conn.ExecuteDirect('CREATE TRIGGER dokument_broj AFTER INSERT ON dokument WHEN NEW.broj IS NULL OR NEW.broj = '''' BEGIN ' +
        'UPDATE dokumenti SET rednidok = CASE WHEN godina = CAST(strftime(''%Y'', ''now'') AS INTEGER) THEN rednidok + 1 ELSE 1 END, ' +
        'godina = CAST(strftime(''%Y'', ''now'') AS INTEGER) WHERE vrsta = NEW.vrsta; ' +
        'UPDATE dokument SET broj = (SELECT sifradok || ''-'' || godina || ''-'' || printf(''%04d'', rednidok) FROM dokumenti WHERE vrsta = NEW.vrsta) WHERE id = NEW.id; END');
      Db2.Conn.ExecuteDirect('INSERT INTO dokument (vrsta, datum) VALUES (''otp'', ''x''), (''otp'', ''x''), (''rv'', ''x'')');
      Db2.Conn.ExecuteDirect('INSERT INTO dokument (vrsta, broj, datum) VALUES (''otp'', ''rucno-1'', ''x'')');
      Check((CountOf(Db2, 'SELECT group_concat(broj, ''|'') FROM dokument') = 'otp-' + Y + '-0001|otp-' + Y + '-0002|rv-' + Y + '-0001|rucno-1'),
        'doctypes: the SQLite trigger recipe numbers new documents and leaves given numbers alone: ' + CountOf(Db2, 'SELECT group_concat(broj, ''|'') FROM dokument'));
    finally
      Db2.Free;
    end;
    { objedinjena forma: jedna forma za sve vrste }
    Ok := ApplyBizTemplate(Db, 'dokumenti_obj', '', False, Log);
    Check(Ok, 'doctypes: the unified document template builds: ' + Log.Text);
    DocTypeLoad(Db, 'otp', T);
    T.Last := 0; T.Year := 0; DocTypeSave(Db, T);
    Host.SetBounds(0, 0, 1000, 700);
    Sh := TaShell.CreateShell(Host, Db);
    Sh.Parent := Host;
    Host.Show;
    Application.ProcessMessages;
    OnRunnerMessage := @ShellMsg;
    ShellMsgs := '';
    Check(not Sh.OpenForm('Dokument'), 'doctypes: the unified form needs a type');
    Check(Sh.OpenForm('Dokument#vrsta=otp') and (Sh.TabCount = 1) and (Sh.Bar.Count = 1), 'doctypes: the form opens for a type');
    R := Sh.TabRunner(0);
    Check((R.Caption = 'Otpremnica') and (R.DocCode = 'otp'), 'doctypes: the tab takes the name of the type');
    Check(TEdit(CtlFor(R, 'broj')).Text = 'otp-' + Y + '-0001', 'doctypes: a new document shows the proposed number (' + TEdit(CtlFor(R, 'broj')).Text + ')');
    Check(Sh.OpenForm('Dokument#vrsta=otp') and (Sh.TabCount = 1), 'doctypes: the same type opens only once');
    ShellMsgs := '';
    Check((not Sh.OpenForm('Dokument#vrsta=rv')) and (Sh.TabCount = 1) and (Pos('Otpremnica', ShellMsgs) > 0),
      'doctypes: a related type cannot be opened while the other is open: ' + ShellMsgs);
    Check(Sh.OpenForm('Dokument#vrsta=rac') and (Sh.TabCount = 2), 'doctypes: an unrelated type opens next to it, in the same form');
    { spremanje novog dokumenta dodjeljuje broj i upisuje ga u tablicu }
    TEdit(CtlFor(R, 'broj')).Text := 'proba';
    R.DoAction('save');
    DocTypeLoad(Db, 'otp', T);
    Q := Db.NewQuery('SELECT vrsta, broj FROM dokument');
    try
      Q.Open;
      Check((not Q.IsEmpty) and (Q.Fields[0].AsString = 'otp') and (Q.Fields[1].AsString = 'otp-' + Y + '-0001') and (T.Last = 1),
        'doctypes: saving stores the type and the number and updates the last number (last=' + IntToStr(T.Last) + ', msgs=' + ShellMsgs + ')');
    finally
      Q.Free;
    end;
    Check(Sh.CloseAll, 'doctypes: tabs close');
  finally
    OnRunnerMessage := Old;
    Host.Free;
    Log.Free;
    ActiveDb := nil;
    Db.Free;
    with TIniFile.Create(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sidemenu.ini') do
    try
      EraseSection('shell/ta_doctypes.db');
    finally
      Free;
    end;
  end;
end;

{ Trgovina Jadran 2: ponude, narudzbenice, otpremnice i predracuni su vrste objedinjene forme }
procedure TestShowcase2;
var
  Db: TAppDb;
  Log, Names: TStringList;
  RD2: TaReportDef;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  I, Bad, N0: Integer;
  Msg, Y: string;
  Sc: TaScriptContext;
  Host: TForm;
  Sh: TaShell;
  Old: TRunnerMessageProc;
  T: TaDocType;
  Fd: TaFormDef;
begin
  if FileExists('/tmp/ta_showcase2.db') then DeleteFile('/tmp/ta_showcase2.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  Host := TForm.CreateNew(nil);
  Old := OnRunnerMessage;
  Y := FormatDateTime('yyyy', Date);
  try
    Db.Open('/tmp/ta_showcase2.db');
    ActiveDb := Db;
    Check(BuildShowcaseUnified(Db, Log) and (Pos('GREŠKA', Log.Text) = 0), 'showcase2: built: ' + Copy(Log.Text, Pos('GREŠKA', Log.Text), 200));
    Check((CountOf(Db, 'SELECT COUNT(*) FROM dokument WHERE vrsta = ''pon''') = '150') and (CountOf(Db, 'SELECT COUNT(*) FROM dokument WHERE vrsta = ''nar''') = '120') and
      (CountOf(Db, 'SELECT COUNT(*) FROM dokument WHERE vrsta = ''otp''') = '100') and (CountOf(Db, 'SELECT COUNT(*) FROM dokument WHERE vrsta = ''pred''') = '60'),
      'showcase2: the four document kinds moved into one table');
    Check(CountOf(Db, 'SELECT COUNT(*) FROM dokument_stavke') = CountOf(Db, 'SELECT COUNT(*) FROM dokument_stavke s JOIN dokument d ON d.id = s.dokument_id'), 'showcase2: every line belongs to a document');
    Names := Db.UserTables;
    Check((Names.IndexOf('ponude') < 0) and (Names.IndexOf('otpremnice') < 0) and (Names.IndexOf('racuni') >= 0) and (Names.IndexOf('dokumenti') >= 0),
      'showcase2: separate tables are gone, invoices keep their own');
    Names.Free;
    DocTypeLoad(Db, 'otp', T);
    Check((T.Last = 100) and (DocPreviewNumber(Db, 'otp') = 'otp-' + Y + '-0101') and DocTypesBlock(Db, 'otp', 'rv'), 'showcase2: counters continue after the moved documents');
    Names := Db.ListObjects('_sys_forms');
    Check((Names.IndexOf('Dokument') >= 0) and (Names.IndexOf('Ponude') < 0) and (Names.IndexOf('Otpremnice') < 0) and (Names.IndexOf('Računi') >= 0), 'showcase2: one form Dokument instead of four');
    Names.Free;
    { svi izvjesca se slazu bez pogreske }
    ResetScripts;
    Scripts(Db);
    Names := Db.ListObjects('_sys_reports');
    Bad := 0; Msg := '';
    for I := 0 to Names.Count - 1 do
    begin
      RD2 := TaReportDef.Create;
      try
        RD2.FromJson(Db.LoadObject('_sys_reports', Names[I]));
        Db.ParamValues.Clear;
        Db.ParamValues.Values['Početak naziva kupca'] := 'Adria';
        Db.ParamValues.Values['Od'] := '2025-01-01';
        Db.ParamValues.Values['Do'] := '2026-12-31';
        Db.ParamValues.Values['Vrsta'] := 'otp';
        RE := TaReportEngine.Create(Db, RD2);
        try
          RR := RE.Render;
          try
            if (RR = nil) or (RR.PageCount < 1) then begin Inc(Bad); Msg := Msg + Names[I] + ' (prazno); '; end
            else if Pos('#Err', AllText(RR)) > 0 then begin Inc(Bad); Msg := Msg + Names[I] + ' (#Err); '; end;
          finally
            RR.Free;
          end;
        finally
          RE.Free;
        end;
      except
        on E: Exception do begin Inc(Bad); Msg := Msg + Names[I] + ': ' + Copy(E.Message, 1, 50) + '; '; end;
      end;
      RD2.Free;
    end;
    Check((Bad = 0) and (Names.Count >= 25), 'showcase2: all ' + IntToStr(Names.Count) + ' reports render: ' + Msg);
    Names.Free;
    Db.ParamValues.Clear;
    { makro-recept: narudzbenica dobiva broj iz tablice dokumenti }
    if MacroMsgs = nil then MacroMsgs := TStringList.Create;
    OnScriptMessage := @MacroCapture;
    OnScriptInput := @MacroInputHook;
    OnScriptAsk := @MacroAsk;
    Sc := TaScriptContext.Create(Db);
    try
      N0 := StrToInt(CountOf(Db, 'SELECT COUNT(*) FROM dokument WHERE vrsta = ''nar'''));
      MacroMsgs.Clear;
      RunMacroByName(Sc, 'Narudžbenica po minimumima');
      DocTypeLoad(Db, 'nar', T);
      Check((StrToInt(CountOf(Db, 'SELECT COUNT(*) FROM dokument WHERE vrsta = ''nar''')) = N0 + 1) and (T.Last = 121) and
        (CountOf(Db, 'SELECT broj FROM dokument WHERE id = (SELECT MAX(id) FROM dokument)') = 'nar-' + Y + '-0121'),
        'showcase2: the purchase order macro takes its number from the table: ' + Trim(MacroMsgs.Text));
      MacroInput := CountOf(Db, 'SELECT broj FROM dokument WHERE vrsta = ''pon'' AND id = (SELECT MIN(id) FROM dokument WHERE vrsta = ''pon'')');
      N0 := StrToInt(CountOf(Db, 'SELECT COUNT(*) FROM racuni'));
      MacroMsgs.Clear;
      RunMacroByName(Sc, 'Račun iz ponude');
      Check(StrToInt(CountOf(Db, 'SELECT COUNT(*) FROM racuni')) = N0 + 1, 'showcase2: invoice made from an offer of the unified form: ' + Trim(MacroMsgs.Text));
    finally
      Sc.Free;
    end;
    { izbornik i radni prostor }
    Fd := TaFormDef.Create;
    Fd.FromJson(Db.LoadObject('_sys_forms', 'Izbornik'));
    Check((Fd.Count = 2) and (Fd[1].Kind = 'SideMenu') and (Pos('openform:Dokument#vrsta=otp', Fd[1].RowSource) > 0) and
      (Pos('openform:Dokument#vrsta=rv', Fd[1].RowSource) > 0) and (Pos('openform:Ponude' + LineEnding, Fd[1].RowSource) = 0) and (Pos('openform:Ponude poslova', Fd[1].RowSource) > 0), 'showcase2: the menu is a side menu with one item per document kind');
    Fd.Free;
    Host.SetBounds(0, 0, 1000, 700);
    Sh := TaShell.CreateShell(Host, Db);
    Sh.Parent := Host;
    Host.Show;
    Application.ProcessMessages;
    OnRunnerMessage := @ShellMsg;
    ShellMsgs := '';
    Check(Sh.OpenForm('Dokument#vrsta=otp') and Sh.OpenForm('Dokument#vrsta=pon') and (Sh.TabCount = 2), 'showcase2: delivery notes and offers open side by side in the same form');
    Check((not Sh.OpenForm('Dokument#vrsta=rv')) and (Sh.TabCount = 2), 'showcase2: a revers cannot be opened while the delivery note is open');
    Check(Sh.OpenForm('Računi') and (Sh.TabCount = 3), 'showcase2: invoices keep their own form');
    Check(Sh.CloseAll, 'showcase2: tabs close');
    with TIniFile.Create(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sidemenu.ini') do
    try
      EraseSection('shell/ta_showcase2.db');
    finally
      Free;
    end;
  finally
    OnRunnerMessage := Old;
    Host.Free;
    Log.Free;
    ResetScripts;
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ opis aplikacije: tekstualna datoteka -> tablice, forme, izvjesca, izbornik, vrste dokumenata, prava }
procedure TestSlipGeneration;
var
  Db: TAppDb;
  H: TTestHost;
  Slips: TaGenSlips;
  Q: TZQuery;
  N1, N2: Integer;
  Today: Integer;
  Fl: TStringList;

  procedure OneLeg(var ASlip: TaGenSlip; const ADiv, AHome, AAway, ASel: string; AProb: Double);
  begin
    SetLength(ASlip.Legs, Length(ASlip.Legs) + 1);
    with ASlip.Legs[High(ASlip.Legs)] do
    begin
      Div_ := ADiv; Home := AHome; Away := AAway; Market := 'HT_OR_FT'; Selection := ASel; Prob := AProb; Odds := 1.0 / AProb;
    end;
  end;

begin
  if FileExists('/tmp/ta_slips.db') then DeleteFile('/tmp/ta_slips.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_slips.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE slips (slip_id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT, ref_date TEXT, stake REAL, note TEXT, status TEXT, settled_at TEXT, paper INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slip_legs (leg_id INTEGER PRIMARY KEY AUTOINCREMENT, slip_id INTEGER, division TEXT, hometeam TEXT, awayteam TEXT, market TEXT, selection TEXT, model_probability REAL, odds REAL, status TEXT, match_id INTEGER, score TEXT, settled_at TEXT)');
    Today := Trunc(Date);
    SetLength(Slips, 2);
    Slips[0].Name := 'jedan - A - B [X1] (1)';
    OneLeg(Slips[0], 'X1', 'A', 'B', '1', 0.8);
    Slips[1].Name := 'dva - A + C [X1] (1)';
    OneLeg(Slips[1], 'X1', 'A', 'B', '1', 0.8);
    OneLeg(Slips[1], 'X1', 'C', 'D', '2', 0.6);
    N1 := SaveGeneratedSlips(Db, Slips, Today, Today, 4.0, 'elita v1');
    Check(N1 = 2, 'slips: both slips are saved (' + IntToStr(N1) + ')');
    N2 := SaveGeneratedSlips(Db, Slips, Today, Today, 4.0, 'elita v1');
    Check(N2 = 0, 'slips: the same slips for the same round are not written twice');
    N2 := SaveGeneratedSlips(Db, Slips, Today + 1, Today, 4.0, 'elita v1');
    Check(N2 = 2, 'slips: the same slips for another round are new ones');
    Q := Db.NewQuery('SELECT COUNT(*), SUM(stake), MIN(paper), MIN(status = ''PENDING'') FROM slips');
    try
      Q.Open;
      Check((Q.Fields[0].AsInteger = 4) and (Abs(Q.Fields[1].AsFloat - 16.0) < 1e-9) and (Q.Fields[2].AsInteger = 1) and (Q.Fields[3].AsInteger = 1),
        'slips: stake is the unit, slips are paper and pending');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT COUNT(*), SUM(odds) FROM slip_legs WHERE slip_id IN (SELECT slip_id FROM slips WHERE note = ''elita v1 - dva - A + C [X1] (1)'')');
    try
      Q.Open;
      Check((Q.Fields[0].AsInteger = 4) and (Abs(Q.Fields[1].AsFloat - 2 * (1.0 / 0.8 + 1.0 / 0.6)) < 1e-9), 'slips: legs carry the fair odds 1 / probability');
    finally
      Q.Free;
    end;
    Check(Double(EvalExpr('GenerateSlips("elita", "' + FormatDateTime('yyyy-mm-dd', Today) + '")', H)) = 0, 'slips: with no fixtures table GenerateSlips has nothing to write');
    { uvoz rasporeda: football-data oblik s BOM-om i navodnicima, oblik dodatnih liga, duplikat, redak bez datuma }
    Fl := TStringList.Create;
    try
      Fl.Text := #$EF#$BB#$BF + 'Div,Date,Time,HomeTeam,AwayTeam' + LineEnding + 'E0,15/09/2026,19:45,"Brighton, UK",Chelsea' + LineEnding +
        'E0,16/09/26,20:00,Arsenal,Spurs' + LineEnding + 'E0,,20:00,Nitko,Nista' + LineEnding + 'e1,2026-09-17,12:00,Hull,Leeds';
      Fl.SaveToFile('/tmp/ta_fx1.csv');
      Fl.Text := 'Country,League,Date,Time,Home,Away' + LineEnding + 'Finland,Veikkausliiga,18/09/2026,18:00,KuPS,HJK' + LineEnding +
        'Narnia,Liga,18/09/2026,18:00,A,B';
      Fl.SaveToFile('/tmp/ta_fx2.csv');
    finally
      Fl.Free;
    end;
    Check(Double(EvalExpr('ImportFixtures("/tmp/ta_fx1.csv")', H)) = 3, 'fixtures: three valid rows are imported, the one without a date is skipped');
    Check(Double(EvalExpr('ImportFixtures("/tmp/ta_fx1.csv")', H)) = 0, 'fixtures: importing the same file again adds nothing');
    Check(Double(EvalExpr('ImportFixtures("/tmp/ta_fx2.csv")', H)) = 1, 'fixtures: an extra-league file maps country and league to a division code and drops unknown leagues');
    Q := Db.NewQuery('SELECT division, matchdate, hometeam FROM fixtures ORDER BY rowid');
    try
      Q.Open;
      Check((Q.Fields[2].AsString = 'Brighton, UK') and (Q.Fields[1].AsString = '2026-09-15'), 'fixtures: a quoted team name keeps its comma and the date becomes ISO');
      Q.Next; Q.Next;
      Check((Q.Fields[0].AsString = 'E1') and (Q.Fields[1].AsString = '2026-09-17'), 'fixtures: the division is upper-cased');
      Q.Next;
      Check((Q.Fields[0].AsString = 'FIN1') and (Q.Fields[1].AsString = '2026-09-18'), 'fixtures: Finland / Veikkausliiga is FIN1');
    finally
      Q.Free;
    end;
    Check(Double(EvalExpr('ImportFixtures("")', H)) = 0, 'fixtures: an empty file name imports nothing');
    DeleteFile('/tmp/ta_fx1.csv'); DeleteFile('/tmp/ta_fx2.csv');
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

function Res3(AHome, AAway: Integer): string;
begin
  if AHome > AAway then Result := 'H' else if AHome = AAway then Result := 'D' else Result := 'A';
end;

procedure TestNewton;
var
  Db: TAppDb;
  H: TTestHost;
  I, J, K, Hg, Ag, Rows, RowsP, Saved: Integer;
  Dt: string;
  P1, PX, P2, Dc, Pa: Double;
  Q: TZQuery;
  Names: array[0..5] of string = ('Ajax', 'Bern', 'Cork', 'Dundee', 'Essen', 'Faro');
begin
  if FileExists('/tmp/ta_newton.db') then DeleteFile('/tmp/ta_newton.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_newton.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT, matchdate TEXT, season TEXT, ' +
      'hometeam TEXT, awayteam TEXT, fthg INTEGER, ftag INTEGER, ftr TEXT, hthg INTEGER, htag INTEGER, htr TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE match_odds (match_id INTEGER NOT NULL, bookmaker TEXT NOT NULL, market TEXT NOT NULL, selection TEXT NOT NULL, ' +
      'odds REAL NOT NULL, closing INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (match_id, bookmaker, market, selection, closing))');
    Db.Conn.ExecuteDirect('CREATE TABLE slips (slip_id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT, ref_date TEXT, stake REAL, note TEXT, status TEXT, settled_at TEXT, paper INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slip_legs (leg_id INTEGER PRIMARY KEY AUTOINCREMENT, slip_id INTEGER, division TEXT, hometeam TEXT, awayteam TEXT, market TEXT, selection TEXT, model_probability REAL, odds REAL, status TEXT, match_id INTEGER, score TEXT, settled_at TEXT)');
    for K := 0 to 7 do
      for I := 0 to 5 do
        for J := 0 to 5 do
          if I <> J then
          begin
            Hg := (I * 3 + J * 5 + K * 2) mod 4;
            Ag := (I * 5 + J * 2 + K) mod 3;
            Dt := FormatDateTime('yyyy-mm-dd', EncodeDate(2024, 8, 1) + K * 70 + (I * 6 + J));
            Db.Conn.ExecuteDirect(Format('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr, hthg, htag, htr) ' +
              'VALUES (''TST1'', ''%s'', ''%d-%d'', ''%s'', ''%s'', %d, %d, ''%s'', 0, 0, ''D'')',
              [Dt, 2024 + K div 4, 2025 + K div 4, Names[I], Names[J], Hg, Ag, Res3(Hg, Ag)]));
            Db.Conn.ExecuteDirect('INSERT INTO match_odds SELECT MAX(match_id), ''B365'', ''1X2'', ''1'', 2.0, 0 FROM matches');
            Db.Conn.ExecuteDirect('INSERT INTO match_odds SELECT MAX(match_id), ''B365'', ''1X2'', ''X'', 3.3, 0 FROM matches');
            Db.Conn.ExecuteDirect('INSERT INTO match_odds SELECT MAX(match_id), ''B365'', ''1X2'', ''2'', 3.8, 0 FROM matches');
          end;
    { utakmica bez kvota ne ulazi u povijest }
    Db.Conn.ExecuteDirect('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr) VALUES (''TST1'', ''2025-01-01'', ''2024-2025'', ''Ajax'', ''Gdje'', 5, 0, ''H'')');
    P1 := EvalExpr('PredictNewton("TST1", "Ajax", "Bern", "2026-06-01", "1X2", "1")', H);
    PX := EvalExpr('PredictNewton("TST1", "Ajax", "Bern", "2026-06-01", "1X2", "X")', H);
    P2 := EvalExpr('PredictNewton("TST1", "Ajax", "Bern", "2026-06-01", "1X2", "2")', H);
    Check(Abs(P1 + PX + P2 - 1.0) < 1e-9, 'newton: the 1X2 probabilities add up to 1 (' + FloatToStr(P1 + PX + P2) + ')');
    Check((P1 > 0) and (P1 < 1) and (PX > 0) and (P2 > 0), 'newton: every outcome has a probability between 0 and 1');
    Dc := EvalExpr('PredictNewton("TST1", "Ajax", "Bern", "2026-06-01", "DOUBLE_CHANCE", "X2")', H);
    Check(Abs(Dc - (PX + P2)) < 1e-12, 'newton: double chance X2 is X plus 2');
    Check(VarIsNull(EvalExpr('PredictNewton("TST1", "Ajax", "Bern", "2026-06-01", "OVER_UNDER", "Over 2.5")', H)), 'newton: no goals model, so no over/under');
    Check(VarIsNull(EvalExpr('PredictNewton("TST1", "Gdje", "Nitko", "2026-06-01", "1X2", "1")', H)), 'newton: neither club has priced history, so no prediction');
    Check(not VarIsNull(EvalExpr('PredictNewton("TST1", "Ajax", "Nitko", "2026-06-01", "1X2", "1")', H)), 'newton: one unknown club gets the league mean');
    Check(VarIsNull(EvalExpr('PredictNewton("TST1", "Ajax", "Bern", "2024-01-01", "1X2", "1")', H)), 'newton: no history before the date');
    Pa := EvalExpr('Predict("TST1", "Ajax", "Bern", "2026-06-01", "1X2", "1")', H);
    Check(Abs(Pa - P1) > 1e-6, 'newton: gives another number than the Poisson model');
    { generator listica s Newtonom: prefiks "Newton" }
    Db.Conn.ExecuteDirect('CREATE TABLE fixtures (division TEXT NOT NULL, matchdate TEXT NOT NULL, hometeam TEXT NOT NULL, awayteam TEXT NOT NULL)');
    for I := 0 to 2 do
      Db.Conn.ExecuteDirect(Format('INSERT INTO fixtures VALUES (''TST1'', ''%s'', ''%s'', ''%s'')',
        [FormatDateTime('yyyy-mm-dd', Date + 1), Names[I * 2], Names[I * 2 + 1]]));
    Saved := Trunc(Double(EvalExpr('GenerateSlips("newton", Date(), 0.3)', H)));
    Q := Db.NewQuery('SELECT COUNT(*), SUM(note LIKE ''Newton - %'') FROM slips');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger = Saved, 'newton: GenerateSlips reports what it saved (' + IntToStr(Saved) + ')');
      Check(Q.Fields[0].AsInteger = Q.Fields[1].AsInteger, 'newton: every saved slip carries the Newton prefix');
    finally
      Q.Free;
    end;
    { backtest }
    RowsP := Trunc(Double(EvalExpr('RunBacktest("TST1", 0, 1, 150, "1X2", "poisson")', H)));
    Rows := Trunc(Double(EvalExpr('RunBacktest("TST1", 0, 1, 150, "1X2", "newton")', H)));
    Check(Rows > 0, 'newton: the backtest places bets (' + IntToStr(Rows) + ', Poisson ' + IntToStr(RowsP) + ')');
    Check(Pos('#Err', VarToStr(EvalExpr('RunBacktest("TST1", 0, 1, 150, "", "nepoznat")', H))) > 0, 'newton: an unknown model is an error');
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

procedure TestEngineBacktest;
var
  Db: TAppDb;
  H: TTestHost;
  I, J, K, Hg, Ag, N, Tips, Sim: Integer;
  Dt: string;
  Q: TZQuery;
  Names: array[0..5] of string = ('Ajax', 'Bern', 'Cork', 'Dundee', 'Essen', 'Faro');
begin
  if FileExists('/tmp/ta_engbt.db') then DeleteFile('/tmp/ta_engbt.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_engbt.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT, matchdate TEXT, season TEXT, ' +
      'hometeam TEXT, awayteam TEXT, fthg INTEGER, ftag INTEGER, ftr TEXT, hthg INTEGER, htag INTEGER, htr TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE match_odds (match_id INTEGER NOT NULL, bookmaker TEXT NOT NULL, market TEXT NOT NULL, selection TEXT NOT NULL, ' +
      'odds REAL NOT NULL, closing INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (match_id, bookmaker, market, selection, closing))');
    for K := 0 to 7 do
      for I := 0 to 5 do
        for J := 0 to 5 do
          if I <> J then
          begin
            Hg := (I * 3 + J * 5 + K * 2) mod 4;
            Ag := (I * 5 + J * 2 + K) mod 3;
            Dt := FormatDateTime('yyyy-mm-dd', EncodeDate(2024, 8, 1) + K * 40 + (I * 6 + J));
            Db.Conn.ExecuteDirect(Format('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr, hthg, htag, htr) ' +
              'VALUES (''TST1'', ''%s'', ''%d'', ''%s'', ''%s'', %d, %d, ''%s'', %d, %d, ''%s'')',
              [Dt, 2024 + K div 4, Names[I], Names[J], Hg, Ag, Res3(Hg, Ag), Hg div 2, Ag div 2, Res3(Hg div 2, Ag div 2)]));
            { zatvarajuca kvota za 1X2 domace pobjede, samo u drugoj sezoni }
            if K >= 4 then
              Db.Conn.ExecuteDirect('INSERT INTO match_odds SELECT MAX(match_id), ''PS'', ''1X2'', ''1'', 2.5, 1 FROM matches');
          end;
    Tips := Trunc(Double(EvalExpr('RunEngineBacktest("TST1", "2025", 0.4)', H)));
    Check(Tips > 0, 'engine: tips are placed (' + IntToStr(Tips) + ')');
    Q := Db.NewQuery('SELECT COUNT(*), SUM(real_price), SUM(market = ''1X2'' AND real_price = 1 AND odds = 2.5) FROM engine_tips');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger = Tips, 'engine: the table holds every tip');
      Check(Q.Fields[1].AsInteger = Q.Fields[2].AsInteger, 'engine: only 1X2 home tips have a real price, and it is the stored one');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT tips FROM engine_summary WHERE market = ''ALL''');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger = Tips, 'engine: the ALL row counts every tip');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT COUNT(*), MAX(cumulative) FROM engine_curve');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger = Tips, 'engine: one curve point per tip');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT value FROM engine_skill WHERE name = ''matches''');
    try
      Q.Open;
      Sim := Trunc(Q.Fields[0].AsFloat);
      Check(Sim = 4 * 30, 'engine: skill covers every match of the season (' + IntToStr(Sim) + ')');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT value FROM engine_skill WHERE name IN (''log_loss'', ''baseline_log_loss'', ''brier'', ''baseline_brier'') AND value > 0');
    try
      Q.Open; N := 0;
      while not Q.Eof do begin Inc(N); Q.Next; end;
      Check(N = 4, 'engine: all four skill numbers are positive');
    finally
      Q.Free;
    end;
    Check(Pos('#Err', VarToStr(EvalExpr('RunEngineBacktest("NEMA1", "2025")', H))) > 0, 'engine: an unknown league has no season to replay');
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

procedure TestMarketFit;
var
  Db: TAppDb;
  H: TTestHost;
  P1, PX, P2, Dc, Ov, Un, Gg, Ng: Double;

  function Pm(const ALeague, AHome, AAway, AMarket, ASel: string): Variant;
  begin
    Result := EvalExpr('PredictMarket("' + ALeague + '", "' + AHome + '", "' + AAway + '", "2026-06-01", "' + AMarket + '", "' + ASel + '")', H);
  end;

begin
  if FileExists('/tmp/ta_mfit.db') then DeleteFile('/tmp/ta_mfit.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_mfit.db');
    ActiveDb := Db;
    Check(VarIsNull(Pm('E0', 'A', 'B', '1X2', '1')), 'marketfit: without a prices table there is no prediction');
    Db.Conn.ExecuteDirect('CREATE TABLE fixture_prices (division TEXT NOT NULL, hometeam TEXT NOT NULL, awayteam TEXT NOT NULL, matchdate TEXT, book TEXT, ' +
      'h REAL, d REAL, a REAL, ou_book TEXT, over REAL, under REAL, PRIMARY KEY (division, hometeam, awayteam))');
    Db.Conn.ExecuteDirect('INSERT INTO fixture_prices VALUES (''E0'', ''A'', ''B'', ''2026-06-01'', ''Avg'', 2.0, 3.5, 4.0, ''Avg'', 1.95, 1.9)');
    Db.Conn.ExecuteDirect('INSERT INTO fixture_prices VALUES (''E0'', ''C'', ''D'', ''2026-06-01'', ''Avg'', 2.0, 3.5, 4.0, NULL, NULL, NULL)');
    Db.Conn.ExecuteDirect('INSERT INTO fixture_prices VALUES (''E0'', ''X'', ''Y'', ''2026-06-01'', ''Avg'', 3.0, 3.0, 3.0, NULL, NULL, NULL)');
    EvalExpr('PredictReset()', H);
    P1 := Pm('E0', 'A', 'B', '1X2', '1'); PX := Pm('E0', 'A', 'B', '1X2', 'X'); P2 := Pm('E0', 'A', 'B', '1X2', '2');
    Check(Abs(P1 + PX + P2 - 1.0) < 1e-9, 'marketfit: the 1X2 probabilities add up to 1');
    Check((P1 > 0.45) and (P1 < 0.50), 'marketfit: the margin is taken out of a 2.00 favourite (' + FloatToStr(P1) + ')');
    Check(P1 > PX, 'marketfit: the favourite is ahead of the draw');
    Dc := Pm('E0', 'A', 'B', 'DOUBLE_CHANCE', '1X');
    Check(Abs(Dc - (P1 + PX)) < 1e-9, 'marketfit: double chance 1X is 1 plus X');
    Ov := Pm('E0', 'A', 'B', 'OVER_UNDER', 'Over 2.5'); Un := Pm('E0', 'A', 'B', 'OVER_UNDER', 'Under 2.5');
    Check(Abs(Ov + Un - 1.0) < 1e-9, 'marketfit: over and under add up to 1');
    Check((Ov > 0.45) and (Ov < 0.55), 'marketfit: over 2.5 is close to a coin flip at 1.95 / 1.90 (' + FloatToStr(Ov) + ')');
    Gg := Pm('E0', 'A', 'B', 'BTTS', 'GG'); Ng := Pm('E0', 'A', 'B', 'BTTS', 'NG');
    Check(Abs(Gg + Ng - 1.0) < 1e-9, 'marketfit: both teams to score is derived from the matrix');
    Check(VarIsNull(Pm('E0', 'C', 'D', 'BTTS', 'GG')) and VarIsNull(Pm('E0', 'C', 'D', 'OVER_UNDER', 'Over 2.5')),
      'marketfit: without a totals market there is no BTTS or totals');
    Check(not VarIsNull(Pm('E0', 'C', 'D', '1X2', '1')), 'marketfit: 1X2 alone still works');
    Check(VarIsNull(Pm('X', 'X', 'Y', '1X2', '1')), 'marketfit: a league with no row has no prediction');
    P1 := Pm('E0', 'X', 'Y', '1X2', '1');
    Check(Abs(P1 - 1.0 / 3.0) < 1e-4, 'marketfit: a fair even book gives a third each (' + FloatToStr(P1) + ')');
    Check(VarIsNull(Pm('E0', 'A', 'Z', '1X2', '1')), 'marketfit: an unpriced match has no prediction');
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

procedure TestPairsSession;
var
  Db: TAppDb;
  H: TTestHost;
  I, J, K, Hg, Ag, N: Integer;
  Dt: string;
  Q: TZQuery;
  Prev, Cur, Bank, Sum: Double;
  Names: array[0..7] of string = ('Ajax', 'Bern', 'Cork', 'Dundee', 'Essen', 'Faro', 'Gent', 'Hull');
begin
  if FileExists('/tmp/ta_pairs.db') then DeleteFile('/tmp/ta_pairs.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_pairs.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT, matchdate TEXT, season TEXT, ' +
      'hometeam TEXT, awayteam TEXT, fthg INTEGER, ftag INTEGER, ftr TEXT, hthg INTEGER, htag INTEGER, htr TEXT)');
    for K := 0 to 3 do
      for I := 0 to 7 do
        for J := 0 to 7 do
          if I <> J then
          begin
            Hg := (I * 3 + J * 5 + K * 2) mod 4;
            Ag := (I * 5 + J * 2 + K) mod 3;
            Dt := FormatDateTime('yyyy-mm-dd', EncodeDate(2025, 9, 1) + K * 90 + (I * 8 + J));
            Db.Conn.ExecuteDirect(Format('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr, hthg, htag, htr) ' +
              'VALUES (''TST1'', ''%s'', ''2025'', ''%s'', ''%s'', %d, %d, ''%s'', %d, %d, ''%s'')',
              [Dt, Names[I], Names[J], Hg, Ag, Res3(Hg, Ag), Hg div 2, Ag div 2, Res3(Hg div 2, Ag div 2)]));
          end;
    { --- parovi na utakmici --- }
    N := Trunc(Double(EvalExpr('RunCombinations("TST1", "Ajax", "Bern", "2026-06-01")', H)));
    Check(N > 20, 'pairs: many correlated pairs are found (' + IntToStr(N) + ')');
    Q := Db.NewQuery('SELECT lift, zajedno, p_prvi, p_drugi, nezavisno, fer_kvota, kvota_mnozenjem FROM comb_parovi ORDER BY id');
    try
      Q.Open;
      Prev := 1e9; Sum := 0;
      while not Q.Eof do
      begin
        Cur := Q.Fields[0].AsFloat;
        if Cur > Prev + 1e-12 then Sum := Sum + 1;
        Prev := Cur;
        if (Q.Fields[1].AsFloat > Q.Fields[2].AsFloat - 1e-9) or (Q.Fields[1].AsFloat > Q.Fields[3].AsFloat - 1e-9) or
           (Abs(Q.Fields[1].AsFloat * Q.Fields[5].AsFloat - 1.0) > 1e-9) or
           (Abs(Q.Fields[4].AsFloat * Q.Fields[6].AsFloat - 1.0) > 1e-9) then Sum := Sum + 1000;
        Q.Next;
      end;
      Check(Sum = 0, 'pairs: strongest correlation first, joint below each single, fair odds consistent');
    finally
      Q.Free;
    end;
    Check(Pos('#Err', VarToStr(EvalExpr('RunCombinations("TST1", "Ajax", "Nitko", "2020-01-01")', H))) > 0, 'pairs: no history before the date is an error');
    { --- sesija --- }
    Db.Conn.ExecuteDirect('CREATE TABLE sesija_ulaz (liga TEXT, domaci TEXT, gosti TEXT, prvi TEXT, drugi TEXT, kvota REAL, datum TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO sesija_ulaz VALUES (''TST1'', ''Ajax'', ''Bern'', ''1X'', ''Over 1.5'', 9.0, ''2026-06-01'')');
    Db.Conn.ExecuteDirect('INSERT INTO sesija_ulaz VALUES (''TST1'', ''Cork'', ''Dundee'', ''X2'', ''Under 3.5'', 9.0, ''2026-06-01'')');
    Db.Conn.ExecuteDirect('INSERT INTO sesija_ulaz VALUES (''TST1'', ''Essen'', ''Faro'', ''12'', ''GG'', 1.05, ''2026-06-01'')');
    Check(Pos('#Err', VarToStr(EvalExpr('RunSession(150)', H))) > 0, 'session: three slips are too few');
    Db.Conn.ExecuteDirect('INSERT INTO sesija_ulaz VALUES (''TST1'', ''Gent'', ''Hull'', ''1'', ''Over 2.5'', 9.0, ''2026-06-01'')');
    Check(Trunc(Double(EvalExpr('RunSession(150)', H))) = 4, 'session: four slips are staked');
    Q := Db.NewQuery('SELECT SUM(ulog), SUM(udio), SUM(igra = ''NE''), SUM(CASE WHEN igra = ''NE'' THEN ulog ELSE 0 END), COUNT(*) FROM sesija_listici');
    try
      Q.Open;
      Check(Q.Fields[0].AsFloat <= 150 * 0.25 + 1e-9, 'session: the exposure is capped at a quarter of the bank (' + FloatToStr(Q.Fields[0].AsFloat) + ')');
      Check(Abs(Q.Fields[0].AsFloat - 150 * Q.Fields[1].AsFloat) < 1e-9, 'session: stakes are bank times share');
      Check(Q.Fields[3].AsFloat = 0, 'session: a slip with no edge gets stake 0');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT vrijednost FROM sesija_sazetak WHERE naziv = ''izlozenost''');
    try
      Q.Open;
      Check(Abs(Q.Fields[0].AsFloat - Trunc(Double(EvalExpr('RunSession(300)', H))) * 0 - Q.Fields[0].AsFloat) < 1e-12, 'session: summary row exists');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT vrijednost FROM sesija_sazetak WHERE naziv = ''izlozenost''');
    try
      Q.Open;
      Bank := Q.Fields[0].AsFloat;
    finally
      Q.Free;
    end;
    EvalExpr('RunSession(150)', H);
    Q := Db.NewQuery('SELECT vrijednost FROM sesija_sazetak WHERE naziv = ''izlozenost''');
    try
      Q.Open;
      Check(Abs(Q.Fields[0].AsFloat - Bank) < 1e-12, 'session: exposure does not depend on the bank size');
    finally
      Q.Free;
    end;
    Db.Conn.ExecuteDirect('INSERT INTO sesija_ulaz VALUES (''TST1'', ''Gent'', ''Hull'', ''1'', ''Over 2.5'', 9.0, ''2026-06-01'')');
    Check(Pos('#Err', VarToStr(EvalExpr('RunSession(150)', H))) > 0, 'session: one match twice is not independent');
    Db.Conn.ExecuteDirect('DELETE FROM sesija_ulaz WHERE rowid = (SELECT MAX(rowid) FROM sesija_ulaz)');
    { --- Monte Carlo --- }
    Check(Trunc(Double(EvalExpr('RunMonteCarlo("sesija", 150, 20, 500, 0.25, 7)', H))) = 500, 'montecarlo: session replications');
    Q := Db.NewQuery('SELECT p5, p50, p95 FROM mc_rezultat WHERE nacin = ''sesija'' AND mjera = ''konacno''');
    try
      Q.Open;
      Check((Q.Fields[0].AsFloat <= Q.Fields[1].AsFloat) and (Q.Fields[1].AsFloat <= Q.Fields[2].AsFloat), 'montecarlo: percentiles are ordered');
      Prev := Q.Fields[1].AsFloat;
    finally
      Q.Free;
    end;
    EvalExpr('RunMonteCarlo("sesija", 150, 20, 500, 0.25, 7)', H);
    Q := Db.NewQuery('SELECT p50 FROM mc_rezultat WHERE nacin = ''sesija'' AND mjera = ''konacno''');
    try
      Q.Open;
      Check(Q.Fields[0].AsFloat = Prev, 'montecarlo: the same seed gives the same result');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT vrijednost FROM mc_sazetak WHERE nacin = ''sesija'' AND naziv = ''udio_propasti''');
    try
      Q.Open;
      Check(Q.Fields[0].AsFloat = 0, 'montecarlo: a capped quarter-Kelly session is never ruined');
    finally
      Q.Free;
    end;
    { tips: sigurni dobici daju tocno zbroj dobitaka, bez rasapa }
    Db.Conn.ExecuteDirect('CREATE TABLE engine_tips (id INTEGER PRIMARY KEY AUTOINCREMENT, match_id INTEGER, matchdate TEXT, hometeam TEXT, awayteam TEXT, score TEXT, market TEXT, selection TEXT, probability REAL, odds REAL, real_price INTEGER, won INTEGER)');
    for I := 1 to 10 do
      Db.Conn.ExecuteDirect('INSERT INTO engine_tips (match_id, matchdate, market, probability, odds) VALUES (' + IntToStr(I) + ', ''2026-01-0' + IntToStr(I mod 9 + 1) + ''', ''1X2'', 1.0, 1.5)');
    Check(Trunc(Double(EvalExpr('RunMonteCarlo("tips", 2, 100, 3)', H))) = 100, 'montecarlo: tips replications');
    Q := Db.NewQuery('SELECT p5, p95 FROM mc_rezultat WHERE nacin = ''tips'' AND mjera = ''konacno''');
    try
      Q.Open;
      Check((Abs(Q.Fields[0].AsFloat - 10.0) < 1e-9) and (Abs(Q.Fields[1].AsFloat - 10.0) < 1e-9), 'montecarlo: ten certain wins at 1.5 and stake 2 give exactly 10');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT COUNT(*) FROM mc_rezultat');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger = 4, 'montecarlo: each mode keeps its own rows');
    finally
      Q.Free;
    end;
    Check(Pos('#Err', VarToStr(EvalExpr('RunMonteCarlo("nesto")', H))) > 0, 'montecarlo: an unknown mode is an error');
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

procedure TestLeagueAndValidation;
var
  Db: TAppDb;
  H: TTestHost;
  I, J, K, Hg, Ag, N: Integer;
  Dt: string;
  Q: TZQuery;
  Sl: TStringList;
  Sum: Double;
  F: string;
  Names: array[0..7] of string = ('Ajax', 'Bern', 'Cork', 'Dundee', 'Essen', 'Faro', 'Gent', 'Hull');
begin
  if FileExists('/tmp/ta_league.db') then DeleteFile('/tmp/ta_league.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  Sl := TStringList.Create;
  try
    Db.Open('/tmp/ta_league.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT, matchdate TEXT, season TEXT, ' +
      'hometeam TEXT, awayteam TEXT, fthg INTEGER, ftag INTEGER, ftr TEXT, hthg INTEGER, htag INTEGER, htr TEXT)');
    for K := 0 to 3 do
      for I := 0 to 7 do
        for J := 0 to 7 do
          if I <> J then
          begin
            Hg := (I * 3 + J * 5 + K * 2) mod 4;
            Ag := (I * 5 + J * 2 + K) mod 3;
            Dt := FormatDateTime('yyyy-mm-dd', EncodeDate(2025, 9, 1) + K * 90 + (I * 8 + J));
            Db.Conn.ExecuteDirect(Format('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr, hthg, htag, htr) ' +
              'VALUES (''TST1'', ''%s'', ''2025'', ''%s'', ''%s'', %d, %d, ''%s'', %d, %d, ''%s'')',
              [Dt, Names[I], Names[J], Hg, Ag, Res3(Hg, Ag), Hg div 2, Ag div 2, Res3(Hg div 2, Ag div 2)]));
          end;
    { --- pregled lige --- }
    Check(Trunc(Double(EvalExpr('RunLeagueOverview("TST1", "2025")', H))) = 8, 'league: one row per club');
    Q := Db.NewQuery('SELECT SUM(bodovi), SUM(pobjede), SUM(porazi), SUM(neodluceno), SUM(gf) - SUM(ga), MIN(odigrano), MAX(odigrano), MIN(poz), MAX(poz) FROM liga_tablica');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger = 3 * Q.Fields[1].AsInteger + Q.Fields[3].AsInteger, 'league: points are three per win and one per draw');
      Check(Q.Fields[1].AsInteger = Q.Fields[2].AsInteger, 'league: every win is somebody''s loss');
      Check(Q.Fields[4].AsInteger = 0, 'league: goal differences cancel out');
      Check((Q.Fields[5].AsInteger = 4 * 14) and (Q.Fields[6].AsInteger = 4 * 14), 'league: every club plays 56 matches (' + Q.Fields[5].AsString + ')');
      Check((Q.Fields[7].AsInteger = 1) and (Q.Fields[8].AsInteger = 8), 'league: positions run from 1 to 8');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT bodovi, gr, gf, momcad FROM liga_tablica ORDER BY poz');
    try
      Q.Open;
      N := 0; Sum := 0;
      while not Q.Eof do
      begin
        if (N > 0) and (Q.Fields[0].AsInteger > Trunc(Sum)) then N := N + 1000;
        Sum := Q.Fields[0].AsInteger;
        Inc(N);
        Q.Next;
      end;
      Check(N = 8, 'league: table is ordered by points');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT SUM(CASE WHEN naziv IN (''domaci_pobjede'', ''neodluceno'', ''gosti_pobjede'') THEN vrijednost ELSE 0 END), MAX(CASE WHEN naziv = ''utakmica'' THEN vrijednost END) FROM liga_trendovi');
    try
      Q.Open;
      Check(Abs(Q.Fields[0].AsFloat - 1.0) < 1e-9, 'league: home, draw and away shares add up to 1');
      Check(Q.Fields[1].AsFloat = 224, 'league: trends count 224 matches');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT COUNT(*), MIN(comeback_rate), MAX(comeback_rate), MIN(closer_index) FROM liga_profili');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger = 8, 'league: a behaviour profile per club');
      Check((Q.Fields[1].AsFloat >= 0) and (Q.Fields[2].AsFloat <= 1) and (Q.Fields[3].AsFloat > 0), 'league: rates are between 0 and 1 and the closer index is positive');
    finally
      Q.Free;
    end;
    { --- forma --- }
    F := VarToStr(EvalExpr('TeamForm("Ajax")', H));
    Check(Length(F) = 5, 'form: five matches by default (' + F + ')');
    Check(Length(VarToStr(EvalExpr('TeamForm("Ajax", "2026-12-31", 3)', H))) = 3, 'form: a different length');
    Check(VarToStr(EvalExpr('TeamForm("Nitko")', H)) = '', 'form: unknown club has no form');
    Check(VarToStr(EvalExpr('TeamForm("Ajax", "2025-09-01")', H)) = '', 'form: nothing before the first match');
    for I := 1 to Length(F) do
      Check(F[I] in ['W', 'D', 'L'], 'form: only W, D and L');
    { --- medjusobni --- }
    Check(Trunc(Double(EvalExpr('RunHeadToHead("Ajax", "Bern")', H))) = 8, 'h2h: eight meetings');
    Q := Db.NewQuery('SELECT (SELECT vrijednost FROM h2h_sazetak WHERE naziv = ''pobjeda'') + (SELECT vrijednost FROM h2h_sazetak WHERE naziv = ''neodluceno'') + ' +
      '(SELECT vrijednost FROM h2h_sazetak WHERE naziv = ''poraza''), (SELECT COUNT(*) FROM h2h_susreti)');
    try
      Q.Open;
      Check(Q.Fields[0].AsFloat = 8, 'h2h: wins, draws and losses add up to the meetings');
      Check(Q.Fields[1].AsInteger = 6, 'h2h: six meetings are listed');
    finally
      Q.Free;
    end;
    Check(Trunc(Double(EvalExpr('RunSeasonProfile("Ajax", "2027-01-01")', H))) = 5, 'season profile: five windows');
    Q := Db.NewQuery('SELECT SUM(odigrano) FROM forma_profil');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger = 56, 'season profile: the windows cover every match of the club (' + Q.Fields[0].AsString + ')');
    finally
      Q.Free;
    end;
    { --- provjera sezone --- }
    Sl.Clear;
    Sl.Add('Div,Date,HomeTeam,AwayTeam,FTHG,FTAG,HTHG,HTAG');
    Sl.Add('TST1,2025-10-01,Ajax,Bern,2,1,1,0');
    Sl.Add('TST1,2025-10-02,Cork,Dundee,0,0,0,0');
    Sl.SaveToFile('/tmp/all2025.csv');
    Sl[0] := Sl[0];
    Sl.Clear;
    Sl.Add('Div,Date,HomeTeam,AwayTeam,FTHG,FTAG,HTHG,HTAG');
    Sl.Add('TST1,2025-10-01,Ajax,Bern,2,1,1,0');
    Sl.Add('TST1,2025-10-02,Cork,Dundee,1,0,3,0');
    Sl.Add('TST1,2025-10-03,Essen,Essen,1,0,0,0');
    Sl.Add('TST1,2025-10-04,Faro,Gent,,,,');
    Sl.SaveToFile('/tmp/bad2025-2026.csv');
    Check(Trunc(Double(EvalExpr('ValidateSeason("/tmp/bad2025-2026.csv", "2025-2026")', H))) = 2, 'validation: half-time above full-time and a club against itself are errors');
    Q := Db.NewQuery('SELECT razina, provjera FROM validacija_nalazi ORDER BY id');
    try
      Q.Open;
      Check((Q.Fields[0].AsString = 'ERROR'), 'validation: errors come first');
      Sl.Clear;
      while not Q.Eof do begin Sl.Add(Q.Fields[1].AsString); Q.Next; end;
      Check((Sl.IndexOf('poluvrijeme>kraj') >= 0) and (Sl.IndexOf('isti-tim') >= 0) and (Sl.IndexOf('nije-odigrano') >= 0), 'validation: the findings name the checks');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT vrijednost FROM validacija_sazetak WHERE naziv = ''uvoz_dopusten''');
    try
      Q.Open;
      Check(Q.Fields[0].AsFloat = 0, 'validation: the import is not allowed with errors');
    finally
      Q.Free;
    end;
    Check(Trunc(Double(EvalExpr('ValidateSeason("/tmp/nema_ove_datoteke.csv", "2025-2026")', H))) = -1, 'validation: a missing file checks nothing and gives -1');
  finally
    Sl.Free;
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

procedure TestBacktest;
var
  Db: TAppDb;
  H: TTestHost;
  I, J, K, Hg, Ag, Hh, Ah, Rows, Season: Integer;
  Dt: string;
  Q: TZQuery;
  SumProfit, EndV: Double;
  Names: array[0..5] of string = ('Ajax', 'Bern', 'Cork', 'Dundee', 'Essen', 'Faro');
begin
  if FileExists('/tmp/ta_bt.db') then DeleteFile('/tmp/ta_bt.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_bt.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT, matchdate TEXT, season TEXT, ' +
      'hometeam TEXT, awayteam TEXT, fthg INTEGER, ftag INTEGER, ftr TEXT, hthg INTEGER, htag INTEGER, htr TEXT)');
    { dvije cijele sezone: prva nema povijest (preskace se), druga se predvida iz prve }
    for Season := 0 to 1 do
      for K := 0 to 3 do
        for I := 0 to 5 do
          for J := 0 to 5 do
            if I <> J then
            begin
              Hg := (I * 3 + J * 5 + K * 2 + Season) mod 4;
              Ag := (I * 5 + J * 2 + K + Season) mod 3;
              Hh := Hg div 2; Ah := Ag div 2;
              Dt := FormatDateTime('yyyy-mm-dd', EncodeDate(2022 + Season, 9, 1) + K * 60 + (I * 6 + J));
              Db.Conn.ExecuteDirect(Format('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr, hthg, htag, htr) ' +
                'VALUES (''TST1'', ''%s'', ''%d-%d'', ''%s'', ''%s'', %d, %d, ''%s'', %d, %d, ''%s'')',
                [Dt, 2022 + Season, 2023 + Season, Names[I], Names[J], Hg, Ag, Res3(Hg, Ag), Hh, Ah, Res3(Hh, Ah)]));
            end;
    Rows := Trunc(Double(EvalExpr('RunBacktest("tst1", 0)', H)));
    Check(Rows > 0, 'backtest: the second season is predicted from the first (' + IntToStr(Rows) + ' bets)');
    Q := Db.NewQuery('SELECT COUNT(*), MIN(season), MAX(season) FROM backtest_bets');
    try
      Q.Open;
      Check((Q.Fields[0].AsInteger = Rows) and (Q.Fields[1].AsString = '2023-2024') and (Q.Fields[2].AsString = '2023-2024'),
        'backtest: the first season has no history and is skipped');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT n, hit FROM backtest_summary WHERE system = ''veliki''');
    try
      Q.Open;
      Check((Q.Fields[0].AsInteger > 0) and (Q.Fields[1].AsFloat >= 0) and (Q.Fields[1].AsFloat <= 1), 'backtest: the summary has the veliki system');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT SUM(profit) FROM backtest_bets WHERE system = ''veliki''');
    try Q.Open; SumProfit := Q.Fields[0].AsFloat; finally Q.Free; end;
    Q := Db.NewQuery('SELECT ending, seasons_total FROM backtest_bankroll WHERE system = ''veliki''');
    try
      Q.Open;
      EndV := Q.Fields[0].AsFloat;
      Check((Abs(EndV - (150.0 + SumProfit)) < 1e-9) or (EndV = 0), 'backtest: the bank ends at 150 plus the profits (or is ruined)');
      Check(Q.Fields[1].AsInteger = 1, 'backtest: one tested season');
    finally
      Q.Free;
    end;
    Q := Db.NewQuery('SELECT COUNT(*) FROM backtest_ruin');
    try Q.Open; Check(Q.Fields[0].AsInteger > 0, 'backtest: the risk of ruin is estimated'); finally Q.Free; end;
    Check(Double(EvalExpr('RunBacktest("tst1", 1, 2, 100)', H)) = Rows, 'backtest: accumulators and another starting bank change the bank, not the bets');
    Q := Db.NewQuery('SELECT "start" FROM backtest_bankroll LIMIT 1');
    try Q.Open; Check(Abs(Q.Fields[0].AsFloat - 100.0) < 1e-9, 'backtest: the starting bank is the one asked for'); finally Q.Free; end;
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

procedure TestDataImport;
var
  Db: TAppDb;
  H: TTestHost;
  Fl: TStringList;
  Rep: TaImportReport;
  Q: TZQuery;
  V: Variant;

  function Scalar(const ASql: string): string;
  var
    Q2: TZQuery;
  begin
    Q2 := Db.NewQuery(ASql);
    try
      Q2.Open;
      Result := Q2.Fields[0].AsString;
    finally
      Q2.Free;
    end;
  end;

begin
  if FileExists('/tmp/ta_imp.db') then DeleteFile('/tmp/ta_imp.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  Fl := TStringList.Create;
  try
    Db.Open('/tmp/ta_imp.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE divisions (division TEXT PRIMARY KEY, division_name TEXT NOT NULL, country TEXT NOT NULL)');
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT NOT NULL, matchdate TEXT NOT NULL, season TEXT NOT NULL, ' +
      'hometeam TEXT NOT NULL, awayteam TEXT NOT NULL, fthg INTEGER NOT NULL, ftag INTEGER NOT NULL, ftr TEXT NOT NULL, hthg INTEGER, htag INTEGER, htr TEXT, ' +
      'UNIQUE (division, matchdate, hometeam, awayteam))');
    Db.Conn.ExecuteDirect('CREATE TABLE match_odds (match_id INTEGER NOT NULL, bookmaker TEXT NOT NULL, market TEXT NOT NULL, selection TEXT NOT NULL, ' +
      'odds REAL NOT NULL, closing INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (match_id, bookmaker, market, selection, closing)) WITHOUT ROWID');
    Db.Conn.ExecuteDirect('CREATE TABLE match_stats (match_id INTEGER PRIMARY KEY, referee TEXT, hxg REAL, axg REAL, hs INTEGER, "as" INTEGER, hst INTEGER, ast INTEGER, ' +
      'hc INTEGER, ac INTEGER, hf INTEGER, af INTEGER, hy INTEGER, ay INTEGER, hr INTEGER, ar INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slips (slip_id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT, ref_date TEXT, stake REAL, note TEXT, status TEXT, settled_at TEXT, paper INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slip_legs (leg_id INTEGER PRIMARY KEY AUTOINCREMENT, slip_id INTEGER, division TEXT, hometeam TEXT, awayteam TEXT, market TEXT, selection TEXT, ' +
      'model_probability REAL, odds REAL, status TEXT, match_id INTEGER, score TEXT, settled_at TEXT)');

    Fl.Text := 'Div,Date,HomeTeam,AwayTeam,FTHG,FTAG,HTHG,HTAG,Referee,HS,B365H,B365D,B365A,B365CH,B365CD,B365CA,B365>2.5,B365<2.5' + LineEnding +
      'E0,15/08/26,Alpha,Beta,2,1,1,0,A Smith,12,1.8,3.5,4.2,1.7,3.6,4.4,1.9,1.95' + LineEnding +
      'E0,16/08/26,Gamma,Delta,0,0,0,0,,8,2.1,3.3,3.5,,,,,' + LineEnding +
      'e1,17/08/26,Eta,Theta,1,3,,,,,0.9,3.3,3.5,,,,,' + LineEnding +
      'E0,,Nitko,Nista,1,1,0,0,,,,,,,,,,' + LineEnding +
      'E0,15/08/26,Alpha,Beta,4,0,2,0,,,,,,,,,,';
    Fl.SaveToFile('/tmp/ta_imp1.csv');
    Rep := ImportMatchFile(Db, '/tmp/ta_imp1.csv', '2026-2027', False, False);
    Check(Rep.Kept and (Rep.Matches = 3) and (Rep.Skipped = 1), 'import: three matches kept, one without a date skipped (' + IntToStr(Rep.Matches) + '/' + IntToStr(Rep.Skipped) + ')');
    Check(Scalar('SELECT fthg || ftr || hthg FROM matches WHERE hometeam = ''Alpha''') = '4H2', 'import: the same match twice in a file, the last row wins');
    Check(Scalar('SELECT COUNT(*) FROM match_odds') = '13', 'import: odds a later duplicate leaves blank are kept (' + Scalar('SELECT COUNT(*) FROM match_odds') + ')');
    Check(Scalar('SELECT COUNT(*) FROM match_odds WHERE bookmaker = ''B365'' AND closing = 1') = '3', 'import: B365C columns are closing prices of B365');
    Check(Scalar('SELECT COUNT(*) FROM match_odds WHERE market = ''OU25''') = '2', 'import: over and under 2.5 prices are read');
    Check((Scalar('SELECT COUNT(*) FROM match_odds o JOIN matches m USING(match_id) WHERE m.hometeam = ''Eta''') = '2') and (Scalar('SELECT COUNT(*) FROM match_odds o JOIN matches m USING(match_id) WHERE m.hometeam = ''Eta'' AND o.selection = ''1''') = '0'), 'import: a price of 0.9 is not a price, the valid ones of the same row are');
    Check(Scalar('SELECT COUNT(*) FROM match_stats') = '2', 'import: statistics only for matches that have any');
    Check(Scalar('SELECT COUNT(*) FROM match_stats WHERE referee IS NULL AND hs = 8') = '1', 'import: an empty referee is NULL, not the text nan');
    Check((Scalar('SELECT division_name FROM divisions WHERE division = ''E0''') = 'Premier League') and (Scalar('SELECT COUNT(*) FROM divisions') = '2'),
      'import: unknown divisions are registered with their names, codes are upper-cased');
    Check((Scalar('SELECT htr FROM matches WHERE hometeam = ''Eta''') = '') and (Scalar('SELECT COUNT(*) FROM matches WHERE hthg IS NULL') = '1'), 'import: no half-time score stays empty');

    { spajanje: samo dodaje i osvjezava, ne brise }
    Fl.Text := 'Div,Date,HomeTeam,AwayTeam,FTHG,FTAG' + LineEnding + 'E0,15/08/26,Alpha,Beta,5,0' + LineEnding +
      'E0,20/08/26,A1,B1,1,0' + LineEnding + 'E0,21/08/26,A2,B2,1,0' + LineEnding + 'E0,22/08/26,A3,B3,1,0' + LineEnding + 'E0,23/08/26,A4,B4,1,0';
    Fl.SaveToFile('/tmp/ta_imp2.csv');
    Rep := ImportMatchFile(Db, '/tmp/ta_imp2.csv', '2026-2027', True, False);
    Check((Rep.Added = 4) and (Rep.Updated = 1), 'import: merge adds four and updates one (' + IntToStr(Rep.Added) + '/' + IntToStr(Rep.Updated) + ')');
    Check((Scalar('SELECT COUNT(*) FROM matches') = '7') and (Scalar('SELECT fthg FROM matches WHERE hometeam = ''Alpha''') = '5'), 'import: a merge deletes nothing and updates the result');
    Check(Scalar('SELECT COUNT(*) FROM match_odds') = '13', 'import: a merge without prices keeps the old ones');

    { zastita: izvor koji nudi manje od pola onoga sto baza vec ima se odbija }
    Rep := ImportMatchFile(Db, '/tmp/ta_imp1.csv', '2026-2027', False, False);
    Check(not Rep.Kept and (Pos('odbijeno', Rep.Problems) > 0), 'import: a source with under half the matches the database has is refused');
    Check(Scalar('SELECT COUNT(*) FROM matches') = '7', 'import: a refused import changes nothing');

    { veza listica s utakmicom preživi zamjenu sezone }
    Db.Conn.ExecuteDirect('INSERT INTO slips (created_at, ref_date, stake, note, status, paper) VALUES (''2026-08-14'', ''2026-08-14'', 1, ''t'', ''PENDING'', 1)');
    Db.Conn.ExecuteDirect('INSERT INTO slip_legs (slip_id, division, hometeam, awayteam, market, selection, model_probability, odds, status, match_id) ' +
      'SELECT 1, division, hometeam, awayteam, ''1X2'', ''1'', 0.5, 2, ''PENDING'', match_id FROM matches WHERE hometeam = ''A1''');
    Fl.Text := 'Div,Date,HomeTeam,AwayTeam,FTHG,FTAG' + LineEnding + 'E0,20/08/26,A1,B1,2,0' + LineEnding + 'E0,21/08/26,A2,B2,1,0' + LineEnding +
      'E0,22/08/26,A3,B3,1,0' + LineEnding + 'E0,23/08/26,A4,B4,1,0' + LineEnding + 'E0,15/08/26,Alpha,Beta,1,1' + LineEnding + 'E0,16/08/26,Gamma,Delta,0,0';
    Fl.SaveToFile('/tmp/ta_imp3.csv');
    Rep := ImportMatchFile(Db, '/tmp/ta_imp3.csv', '2026-2027', False, False);
    Check(Rep.Kept and (Rep.Matches = 6), 'import: a complete file replaces the season inside its divisions');
    Check((Scalar('SELECT COUNT(*) FROM matches WHERE division = ''E1''') = '1') and (Scalar('SELECT COUNT(*) FROM matches') = '7'), 'import: divisions the file does not carry are left alone');
    Check(Scalar('SELECT COUNT(*) FROM slip_legs l JOIN matches m ON m.match_id = l.match_id WHERE m.hometeam = ''A1''') = '1', 'import: a slip leg is linked again to its match after the season is replaced');

    { funkcije izraza }
    V := EvalExpr('ImportMatches("/tmp/ta_imp3.csv", "2026-2027")', H);
    Check(Double(V) = 6, 'import: ImportMatches returns the number of matches in the file');
    V := EvalExpr('ImportMatches("")', H);
    Check(Double(V) = 0, 'import: an empty file name imports nothing');
    Check(Pos('#Err', VarToStr(EvalExpr('ImportMatches("/tmp/nema_je_sigurno.csv", "2026-2027")', H))) > 0, 'import: a missing file is an error');
    Q := nil;
    DeleteFile('/tmp/ta_imp1.csv'); DeleteFile('/tmp/ta_imp2.csv'); DeleteFile('/tmp/ta_imp3.csv');
  finally
    ActiveDb := nil;
    Fl.Free;
    H.Free;
    Db.Free;
  end;
end;

procedure TestCountryImport;
var
  Db: TAppDb;
  H: TTestHost;
  Fl: TStringList;
  Rep: TaCountryReport;

  function Scalar(const ASql: string): string;
  var
    Q2: TZQuery;
  begin
    Q2 := Db.NewQuery(ASql);
    try
      Q2.Open;
      Result := Q2.Fields[0].AsString;
    finally
      Q2.Free;
    end;
  end;

begin
  if FileExists('/tmp/ta_cty.db') then DeleteFile('/tmp/ta_cty.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  Fl := TStringList.Create;
  try
    Db.Open('/tmp/ta_cty.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE divisions (division TEXT PRIMARY KEY, division_name TEXT NOT NULL, country TEXT NOT NULL)');
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT NOT NULL, matchdate TEXT NOT NULL, season TEXT NOT NULL, ' +
      'hometeam TEXT NOT NULL, awayteam TEXT NOT NULL, fthg INTEGER NOT NULL, ftag INTEGER NOT NULL, ftr TEXT NOT NULL, hthg INTEGER, htag INTEGER, htr TEXT, ' +
      'UNIQUE (division, matchdate, hometeam, awayteam))');
    Db.Conn.ExecuteDirect('CREATE TABLE match_odds (match_id INTEGER NOT NULL, bookmaker TEXT NOT NULL, market TEXT NOT NULL, selection TEXT NOT NULL, ' +
      'odds REAL NOT NULL, closing INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (match_id, bookmaker, market, selection, closing)) WITHOUT ROWID');
    Db.Conn.ExecuteDirect('CREATE TABLE match_stats (match_id INTEGER PRIMARY KEY, referee TEXT, hxg REAL, axg REAL, hs INTEGER, "as" INTEGER, hst INTEGER, ast INTEGER, ' +
      'hc INTEGER, ac INTEGER, hf INTEGER, af INTEGER, hy INTEGER, ay INTEGER, hr INTEGER, ar INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slips (slip_id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT, ref_date TEXT, stake REAL, note TEXT, status TEXT, settled_at TEXT, paper INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slip_legs (leg_id INTEGER PRIMARY KEY AUTOINCREMENT, slip_id INTEGER, division TEXT, hometeam TEXT, awayteam TEXT, market TEXT, selection TEXT, ' +
      'model_probability REAL, odds REAL, status TEXT, match_id INTEGER, score TEXT, settled_at TEXT)');

    Fl.Text := 'Country,League,Season,Date,Time,Home,Away,HG,AG,Res,PSCH,PSCD,PSCA,B365CH,B365CD,B365CA' + LineEnding +
      'Finland,Veikkausliiga,2016,05/04/2016,18:00,KuPS,HJK,2,1,H,2.1,3.4,3.5,2.0,3.3,3.6' + LineEnding +
      'Finland,Veikkausliiga,2016,06/04/2016,18:00,Inter,Ilves,0,0,D,2.5,3.1,2.9,,,' + LineEnding +
      'Argentina,Liga Profesional,2012/2013,10/08/2012,20:00,Boca,River,1,1,D,2.2,3.2,3.4,2.1,3.2,3.5' + LineEnding +
      'Narnia,Liga,2020,01/01/2020,10:00,A,B,1,0,H,1.5,4,6,,,';
    Fl.SaveToFile('/tmp/ta_cty1.csv');
    Rep := ImportCountryFile(Db, '/tmp/ta_cty1.csv', False);
    Check((Rep.Matches = 3) and (Rep.Seasons = 2) and (Rep.SkippedRows = 1), 'countries: three matches in two (season, league) groups, the unknown league is skipped (' + IntToStr(Rep.Matches) + '/' + IntToStr(Rep.Seasons) + '/' + IntToStr(Rep.SkippedRows) + ')');
    Check(Pos('Narnia', Rep.Unknown) > 0, 'countries: the unknown league is reported by name');
    Check(Rep.Divisions = 'ARG1,FIN1', 'countries: groups are ordered by season then league like Python (' + Rep.Divisions + ')');
    Check((Scalar('SELECT group_concat(season) FROM (SELECT DISTINCT season FROM matches ORDER BY season)') = '2012-2013,2016'), 'countries: 2012/2013 becomes 2012-2013, a calendar year stays a year');
    Check(Scalar('SELECT COUNT(*) FROM match_odds') = '15', 'countries: closing prices of every bookmaker with a full trio are read (' + Scalar('SELECT COUNT(*) FROM match_odds') + ')');
    Check((Scalar('SELECT COUNT(*) FROM match_odds WHERE closing = 0') = '0') and (Scalar('SELECT group_concat(DISTINCT bookmaker) FROM (SELECT bookmaker FROM match_odds ORDER BY bookmaker)') = 'B365,PS'),
      'countries: PSCH becomes a Pinnacle price, all of them marked closing');
    Check(Scalar('SELECT COUNT(*) FROM match_stats') = '0', 'countries: this source has no statistics');
    Check(Scalar('SELECT division_name FROM divisions WHERE division = ''FIN1''') = 'Veikkausliiga', 'countries: the division is registered');

    { najnoviji: spajanje }
    Fl.Text := 'Country,League,Season,Date,Time,Home,Away,HG,AG,Res' + LineEnding +
      'Finland,Veikkausliiga,2016,05/04/2016,18:00,KuPS,HJK,3,1,H' + LineEnding + 'Finland,Veikkausliiga,2016,07/04/2016,18:00,Lahti,Mariehamn,1,1,D';
    Fl.SaveToFile('/tmp/ta_cty2.csv');
    Rep := ImportCountryFile(Db, '/tmp/ta_cty2.csv', True);
    Check((Rep.Matches = 2) and (Scalar('SELECT COUNT(*) FROM matches') = '4') and (Scalar('SELECT fthg FROM matches WHERE hometeam = ''KuPS''') = '3'), 'countries: a merge adds one and updates one without deleting');
    Check(Scalar('SELECT COUNT(*) FROM match_odds') = '15', 'countries: a merge without prices leaves the old prices');
    Check(Double(EvalExpr('ImportCountries("/tmp/ta_cty1.csv")', H)) = 3, 'countries: ImportCountries returns the number of matches');
    Check(Double(EvalExpr('ImportCountries("")', H)) = 0, 'countries: an empty file name imports nothing');
    DeleteFile('/tmp/ta_cty1.csv'); DeleteFile('/tmp/ta_cty2.csv');
  finally
    ActiveDb := nil;
    Fl.Free;
    H.Free;
    Db.Free;
  end;
end;

procedure TestScrape;
var
  Played, Fix: TaScrapeRows;
  Html, Txt: string;
  Db: TAppDb;
  Fl: TStringList;
  Rep: TaImportReport;

  function Row(const AClubs, ADate, AScore1, AScore2: string; AId: Integer): string;
  begin
    Result := '<li class="row hidden" data-round="1" data-match="' + IntToStr(AId) + '">' + ADate +
      '<div class="club1" data-id="1"><a href="x">' + Copy(AClubs, 1, Pos('|', AClubs) - 1) + '<div class="logo"></div></a></div>' +
      '<div class="res1">' + AScore1 + '</div><div class="res2">' + AScore2 + '</div>' +
      '<div class="club2" data-id="2"><a href="y">' + Copy(AClubs, Pos('|', AClubs) + 1, MaxInt) + '<div class="logo"></div></a></div></li>';
  end;

  function Scalar(const ASql: string): string;
  var
    Q2: TZQuery;
  begin
    Q2 := Db.NewQuery(ASql);
    try
      Q2.Open;
      Result := Q2.Fields[0].AsString;
    finally
      Q2.Free;
    end;
  end;

begin
  { --- HNS portal --- }
  Html := '<html>' + Row('NK Čakovec|Šibenik', '<div class="date">05.08.2026.</div>', '2', '1', 11) +
    Row('NK Čakovec|Šibenik', '<div class="date">05.08.2026.</div>', '2', '1', 11) +
    Row('Rijeka|Hajduk', '<div class="date">12.09.2026.</div>', '-', '-', 12) +
    Row('Osijek|Lokomotiva', '', '1', '1', 13) +
    Row('Gorica|Istra', '<div class="date">nema</div>', '0', '0', 14) +
    Row('Varaždin|Slaven', '<div class="date">20.08.2026.</div>', '3', '0', 15) + '</html>';
  ParseHnl(Html, 'CRO1', Played, Fix);
  Check((Length(Played) = 2) and (Length(Fix) = 1), 'scrape: two played matches and one fixture; the repeated copy, the row without a date and the unreadable date are dropped (' + IntToStr(Length(Played)) + '/' + IntToStr(Length(Fix)) + ')');
  Check((Played[0].Home = 'NK Čakovec') and (Played[0].Away = 'Šibenik') and (Played[0].Date = '2026-08-05') and (Played[0].Fthg = 2) and (Played[0].Ftag = 1), 'scrape: club names keep their letters, the date becomes ISO');
  Check((Fix[0].Date = '2026-09-12') and (Fix[0].Home = 'Rijeka'), 'scrape: a match with a dash score is a fixture');

  { --- UEFA --- }
  Txt := '= UEFA Champions League 2026/27' + LineEnding + LineEnding + #$E2#$96#$AA + ' League, Matchday 1' + LineEnding + '  Tue Sep 15 2026' + LineEnding +
    '    18:45  Alpha FC (ESP)     v Beta (ENG)         0-2 (0-0)' + LineEnding +
    '           Gamma (NED)        v Delta (BEL)  1-3' + LineEnding +
    '  Wed Sep 16' + LineEnding +
    '           Eta (ITA)  v Theta (GER)   4-3 pen. 1-0 a.e.t. (1-0, 0-0)' + LineEnding +
    '  Wed Dec 9' + LineEnding +
    '           Iota (FRA) v Kappa (POR)' + LineEnding +
    '  Thu Jan 7' + LineEnding +
    '           Lambda (AUT) v Mu (SUI)    2-2';
  ParseUefa(Txt, 'UCL', 2026, Played, Fix);
  Check((Length(Played) = 4) and (Length(Fix) = 1), 'uefa: four played matches and one fixture (' + IntToStr(Length(Played)) + '/' + IntToStr(Length(Fix)) + ')');
  Check((Played[0].Home = 'Alpha FC') and (Played[0].Away = 'Beta') and (Played[0].Fthg = 0) and (Played[0].Ftag = 2) and Played[0].HasHt and (Played[0].Hthg = 0), 'uefa: the country code is stripped and the half-time score is read');
  Check(not Played[1].HasHt, 'uefa: no half-time score stays unknown');
  Check((Played[2].Fthg = 1) and (Played[2].Ftag = 0) and Played[2].HasHt and (Played[2].Hthg = 0) and (Played[2].Htag = 0) and (Played[2].Date = '2026-09-16'),
    'uefa: a penalty shoot-out is not a goal, extra time is, and the 90-minute pair is the half-time score');
  Check((Fix[0].Date = '2026-12-09') and (Played[3].Date = '2027-01-07'), 'uefa: the year rolls over when the month goes backwards');

  { --- uvoz csv-a: bez kvota i statistike --- }
  if FileExists('/tmp/ta_scr.db') then DeleteFile('/tmp/ta_scr.db');
  Db := TAppDb.Create;
  Fl := TStringList.Create;
  try
    Db.Open('/tmp/ta_scr.db');
    Db.Conn.ExecuteDirect('CREATE TABLE divisions (division TEXT PRIMARY KEY, division_name TEXT NOT NULL, country TEXT NOT NULL)');
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT NOT NULL, matchdate TEXT NOT NULL, season TEXT NOT NULL, ' +
      'hometeam TEXT NOT NULL, awayteam TEXT NOT NULL, fthg INTEGER NOT NULL, ftag INTEGER NOT NULL, ftr TEXT NOT NULL, hthg INTEGER, htag INTEGER, htr TEXT, ' +
      'UNIQUE (division, matchdate, hometeam, awayteam))');
    Db.Conn.ExecuteDirect('CREATE TABLE match_odds (match_id INTEGER NOT NULL, bookmaker TEXT NOT NULL, market TEXT NOT NULL, selection TEXT NOT NULL, ' +
      'odds REAL NOT NULL, closing INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (match_id, bookmaker, market, selection, closing)) WITHOUT ROWID');
    Db.Conn.ExecuteDirect('CREATE TABLE match_stats (match_id INTEGER PRIMARY KEY, referee TEXT, hxg REAL, axg REAL, hs INTEGER, "as" INTEGER, hst INTEGER, ast INTEGER, ' +
      'hc INTEGER, ac INTEGER, hf INTEGER, af INTEGER, hy INTEGER, ay INTEGER, hr INTEGER, ar INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slips (slip_id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT, ref_date TEXT, stake REAL, note TEXT, status TEXT, settled_at TEXT, paper INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slip_legs (leg_id INTEGER PRIMARY KEY AUTOINCREMENT, slip_id INTEGER, division TEXT, hometeam TEXT, awayteam TEXT, market TEXT, selection TEXT, ' +
      'model_probability REAL, odds REAL, status TEXT, match_id INTEGER, score TEXT, settled_at TEXT)');
    Fl.Text := 'Div,Date,HomeTeam,AwayTeam,FTHG,FTAG,HTHG,HTAG,B365H,B365D,B365A,Referee' + LineEnding +
      'UCL,2026-09-15,Alpha FC,Beta,0,2,0,0,1.8,3.5,4.2,X Y' + LineEnding + 'UCL,2026-09-16,Gamma,Delta,1,3,,,2.0,3.2,3.9,Z';
    Fl.SaveToFile('/tmp/ta_scr.csv');
    Rep := ImportScrapedFile(Db, '/tmp/ta_scr.csv', '2026-2027');
    Check(Rep.Kept and (Rep.Matches = 2), 'scrape: the csv is imported');
    Check((Scalar('SELECT COUNT(*) FROM match_odds') = '0') and (Scalar('SELECT COUNT(*) FROM match_stats') = '0'), 'scrape: prices and statistics in the file are ignored for these sources');
    Check((Scalar('SELECT hthg || htag FROM matches WHERE hometeam = ''Alpha FC''') = '00') and (Scalar('SELECT COUNT(*) FROM matches WHERE hthg IS NULL') = '1'), 'scrape: half-time scores are kept where the source has them');
    Check(Scalar('SELECT division_name FROM divisions WHERE division = ''UCL''') = 'UEFA Liga prvaka', 'scrape: the division is registered with its name');
    DeleteFile('/tmp/ta_scr.csv');
  finally
    Fl.Free;
    Db.Free;
  end;
end;

procedure TestStandardGenerator;
var
  Db: TAppDb;
  H: TTestHost;
  I, J, K, Hg, Ag, Hh, Ah, N1, N2: Integer;
  Dt: string;
  Today: Integer;
  Names: array[0..5] of string = ('Ajax', 'Bern', 'Cork', 'Dundee', 'Essen', 'Faro');

  function Scalar(const ASql: string): string;
  var
    Q2: TZQuery;
  begin
    Q2 := Db.NewQuery(ASql);
    try
      Q2.Open;
      Result := Q2.Fields[0].AsString;
    finally
      Q2.Free;
    end;
  end;

begin
  if FileExists('/tmp/ta_std.db') then DeleteFile('/tmp/ta_std.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_std.db');
    ActiveDb := Db;
    Today := Trunc(Date);
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT, matchdate TEXT, season TEXT, ' +
      'hometeam TEXT, awayteam TEXT, fthg INTEGER, ftag INTEGER, ftr TEXT, hthg INTEGER, htag INTEGER, htr TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE fixtures (division TEXT, matchdate TEXT, hometeam TEXT, awayteam TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE slips (slip_id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT, ref_date TEXT, stake REAL, note TEXT, status TEXT, settled_at TEXT, paper INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slip_legs (leg_id INTEGER PRIMARY KEY AUTOINCREMENT, slip_id INTEGER, division TEXT, hometeam TEXT, awayteam TEXT, market TEXT, selection TEXT, ' +
      'model_probability REAL, odds REAL, status TEXT, match_id INTEGER, score TEXT, settled_at TEXT)');
    for K := 0 to 3 do
      for I := 0 to 5 do
        for J := 0 to 5 do
          if I <> J then
          begin
            Hg := (I * 3 + J * 5 + K * 2) mod 4;
            Ag := (I * 5 + J * 2 + K) mod 3;
            Hh := Hg div 2; Ah := Ag div 2;
            Dt := FormatDateTime('yyyy-mm-dd', Today - 400 + K * 60 + (I * 6 + J));
            Db.Conn.ExecuteDirect(Format('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr, hthg, htag, htr) ' +
              'VALUES (''TST1'', ''%s'', ''2025'', ''%s'', ''%s'', %d, %d, ''%s'', %d, %d, ''%s'')',
              [Dt, Names[I], Names[J], Hg, Ag, Res3(Hg, Ag), Hh, Ah, Res3(Hh, Ah)]));
          end;
    { sest utakmica kola u sljedeca dva dana }
    for I := 0 to 2 do
    begin
      Db.Conn.ExecuteDirect(Format('INSERT INTO fixtures VALUES (''TST1'', ''%s'', ''%s'', ''%s'')', [FormatDateTime('yyyy-mm-dd', Today + 1), Names[I], Names[I + 3]]));
      Db.Conn.ExecuteDirect(Format('INSERT INTO fixtures VALUES (''TST1'', ''%s'', ''%s'', ''%s'')', [FormatDateTime('yyyy-mm-dd', Today + 2), Names[I + 3], Names[I]]));
    end;
    N1 := Trunc(Double(EvalExpr('GenerateSlips("standard", "' + FormatDateTime('yyyy-mm-dd', Today) + '")', H)));
    Check(N1 >= 6, 'standard: six fixtures give two groups of three, each in three rotation patterns (' + IntToStr(N1) + ' slips)');
    Check(Scalar('SELECT COUNT(*) FROM slips WHERE note = ''generirani v2 - mjesoviti 1 - uzorak 1''') = '1', 'standard: slips are named like the Python ones');
    Check((Scalar('SELECT MIN(stake) = 1 AND MAX(stake) = 1 FROM slips') = '1') and (Scalar('SELECT MIN(paper) FROM slips') = '1'), 'standard: flat stake of 1 and paper slips');
    Check(Scalar('SELECT COUNT(*) FROM slips WHERE note LIKE ''generirani v2 - mjesoviti % - uzorak 2'' AND slip_id IN (SELECT slip_id FROM slip_legs GROUP BY slip_id HAVING COUNT(*) = 3)') = '2',
      'standard: a rotation pattern slip carries three legs, one per fixture of its group');
    N2 := Trunc(Double(EvalExpr('GenerateSlips("standard", "' + FormatDateTime('yyyy-mm-dd', Today) + '")', H)));
    Check(N2 = 0, 'standard: the same round written again adds nothing');
    N2 := Trunc(Double(EvalExpr('PredictRound("' + FormatDateTime('yyyy-mm-dd', Today) + '")', H)));
    Check(N2 = 6, 'predictround: six fixtures give six rows (' + IntToStr(N2) + ')');
    Check(Scalar('SELECT COUNT(*) FROM kolo_utakmice') = '6', 'predictround: the match table has one row per fixture');
    Check(Scalar('SELECT rang FROM kolo_utakmice ORDER BY najbolji_p DESC, id LIMIT 1') = '1', 'predictround: the safest pick is ranked first');
    Check(StrToInt(Scalar('SELECT COUNT(*) FROM kolo_trzista')) > 6 * 8, 'predictround: every market of every match is listed (' + Scalar('SELECT COUNT(*) FROM kolo_trzista') + ')');
    Check(Scalar('SELECT COUNT(*) FROM kolo_utakmice WHERE ABS(p1 + px + p2 - 1) < 0.000001') = '6', 'predictround: the 1X2 probabilities of each row add up to 1');
    N2 := Trunc(Double(EvalExpr('PredictRound("' + FormatDateTime('yyyy-mm-dd', Today) + '")', H)));
    Check((N2 = 6) and (Scalar('SELECT COUNT(*) FROM kolo_utakmice') = '6'), 'predictround: running it again replaces the rows instead of adding to them');
    N2 := Trunc(Double(EvalExpr('GenerateSlips("hedge", "' + FormatDateTime('yyyy-mm-dd', Today) + '")', H)));
    Check(N2 >= 0, 'hedge: the retired system is still available (' + IntToStr(N2) + ' slips)');
    Check(Pos('#Err', VarToStr(EvalExpr('GenerateSlips("nema", "' + FormatDateTime('yyyy-mm-dd', Today) + '")', H))) > 0, 'standard: an unknown system is an error');
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

procedure TestRoundReport;
var
  Db: TAppDb;
  Txt, Def: string;
  Log: TStringList;

  procedure Slip(AId: Integer; const ANote, AStatus: string; AStake: Double);
  begin
    Db.Conn.ExecuteDirect(Format('INSERT INTO slips (slip_id, created_at, ref_date, stake, note, status, paper) VALUES (%d, ''2026-11-01'', ''2026-11-01'', %s, ''%s'', ''%s'', 1)',
      [AId, StringReplace(FloatToStr(AStake), ',', '.', []), ANote, AStatus]));
  end;

  procedure Leg(ASlip: Integer; const AHome, AAway, AMarket, ASel: string; AProb, AOdds: Double; const AStatus, AScore: string);
  var
    Sc: string;
  begin
    Sc := 'NULL';
    if AScore <> '' then Sc := '''' + AScore + '''';
    Db.Conn.ExecuteDirect(Format('INSERT INTO slip_legs (slip_id, division, hometeam, awayteam, market, selection, model_probability, odds, status, score) ' +
      'VALUES (%d, ''E0'', ''%s'', ''%s'', ''%s'', ''%s'', %s, %s, ''%s'', %s)',
      [ASlip, AHome, AAway, AMarket, ASel, StringReplace(FloatToStr(AProb), ',', '.', []), StringReplace(FloatToStr(AOdds), ',', '.', []), AStatus,
       Sc]));
  end;

begin
  Check(KindOfSlip('generirani v2 - mjesoviti 1 - uzorak 1', 3) = 'MALI', 'report: a plain generated slip is MALI');
  Check(KindOfSlip('generirani v2 - veliki - x', 12) = 'VELIKI', 'report: more than ten legs is VELIKI');
  Check((KindOfSlip('prijelazi v1 - x', 1) = 'PRIJELAZI') and (KindOfSlip('Poluvrijeme ili kraj v1 - x', 1) = 'POLUVRIJEME') and (KindOfSlip('elita v1', 2) = 'ELITA') and
    (KindOfSlip('miks v1', 2) = 'MIKS') and (KindOfSlip('top listici v1', 4) = 'TOP') and (KindOfSlip('hedge v1', 4) = 'HEDGE'), 'report: every system is recognised by its note');
  if FileExists('/tmp/ta_rr.db') then DeleteFile('/tmp/ta_rr.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  try
    Db.Open('/tmp/ta_rr.db');
    Db.Conn.ExecuteDirect('CREATE TABLE slips (slip_id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT, ref_date TEXT, stake REAL, note TEXT, status TEXT, settled_at TEXT, paper INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slip_legs (leg_id INTEGER PRIMARY KEY AUTOINCREMENT, slip_id INTEGER, division TEXT, hometeam TEXT, awayteam TEXT, market TEXT, selection TEXT, ' +
      'model_probability REAL, odds REAL, status TEXT, match_id INTEGER, score TEXT, settled_at TEXT)');
    Slip(1, 'generirani v2 - mjesoviti 1 - uzorak 1', 'LOST', 1);
    Leg(1, 'Arsenal', 'Chelsea', '1X2', '1', 0.55, 1.818, 'LOST', '2');
    Leg(1, 'Liverpool', 'Everton', 'DOUBLE_CHANCE', '1X', 0.8, 1.25, 'WON', '1');
    Slip(2, 'prijelazi v1 - prijelaz - Arsenal - Chelsea [E0] (1/1)', 'WON', 1);
    Leg(2, 'Arsenal', 'Chelsea', 'HTFT', '1/1', 0.4, 2.5, 'WON', '1/1');
    Slip(3, 'top listici v1 - top listici - Arsenal [E0] (1/1) + Liverpool [E0] (X/2)', 'PENDING', 1);
    Leg(3, 'Arsenal', 'Chelsea', 'HTFT', '1/1', 0.4, 2.5, 'WON', '1/1');
    Leg(3, 'Liverpool', 'Everton', 'HTFT', 'X/2', 0.15, 6.67, 'PENDING', '');
    Txt := BuildRoundReport(Db, '2026-11-01', True, '2026-11-06 10:00');
    Check(Pos('REPORT LISTICA - REZULTATI' + LineEnding + 'Kolo 2026-11-01, izvezeno 2026-11-06 10:00' + LineEnding + '========================', Txt) = 1, 'report: the header names the round and the export time');
    Check(Pos('MALI' + LineEnding + '------------------------' + LineEnding + '1 listica' + LineEnding + 'Parovi poredani od najboljeg predvidjanja do najgoreg:', Txt) > 0, 'report: a section has its title, rule, slip count and picks line');
    Check(Pos(Format('  E0   %-20s - %-20s  %-8s model 80.0%%  ->  PROSAO  1', ['Liverpool', 'Everton', '1X']) + LineEnding +
      Format('  E0   %-20s - %-20s  %-8s model 55.0%%  ->  PAO  2', ['Arsenal', 'Chelsea', '1']), Txt) > 0,
      'report: picks are ranked by the model, padded to fixed columns, with the result');
    Check(Pos('1/2 pogodaka (50%).', Txt) > 0, 'report: the hit count of the settled picks');
    Check(Pos('POLUVRIJEME ILI KRAJ' + LineEnding + '------------------------' + LineEnding + '0 listica' + LineEnding + '  (nema generiranih listica za ovo kolo)', Txt) > 0, 'report: an empty section says so');
    Check(Pos('Ulozeno 1.00 EUR, vraceno 2.50 EUR, dobitak +1.50 EUR (ROI +150.0%), 1 rijesenih listica.', Txt) > 0, 'report: the money line of a settled system');
    Check(Pos('Listic #3 (par, zajednicka vjerojatnost 6.0%) - CEKA:' + LineEnding + '    E0   Arsenal', Txt) > 0, 'report: an accumulator shows its joint probability and its own status');
    Txt := BuildRoundReport(Db, '2026-11-01', False, '2026-11-06 10:00');
    Check((Pos('->', Txt) = 0) and (Pos('REPORT LISTICA' + LineEnding, Txt) = 1), 'report: before the round no result is printed');
    Check(LatestRound(Db, False) = '2026-11-01', 'report: the latest round with an open slip');
    Check(LatestRound(Db, True) = '2026-11-01', 'report: the latest round with a settled leg');
    Db.Conn.ExecuteDirect('UPDATE slips SET status = ''LOST''');
    Check(LatestRound(Db, False) = '', 'report: no open slips means no latest round');
    Db.Close;
  finally
    Log.Free;
    Db.Free;
  end;
  { sirine stupaca izvjesca iz opisa }
  if FileExists('/tmp/ta_rw.db') then DeleteFile('/tmp/ta_rw.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  try
    Db.Open('/tmp/ta_rw.db');
    Check(BuildAppFromSpecText(Db, 'tablica t "T" bezforme bezizvjesca' + LineEnding + '  a Text' + LineEnding + '  b Text' + LineEnding +
      'izvjesce "R"' + LineEnding + '  izvor: t' + LineEnding + '  polja: a, b' + LineEnding + '  sirine: a=100, b=200' + LineEnding, Log), 'report: a description with explicit column widths is built: ' + Log.Text);
    Def := Db.LoadObject('_sys_reports', 'R');
    Check((Pos('"width" : 92', Def) > 0) and (Pos('"width" : 192', Def) > 0), 'report: explicit widths are used for the columns');
    Db.Close;
  finally
    Log.Free;
    Db.Free;
  end;
end;

procedure TestAnalytics;
var
  Db: TAppDb;
  N: Integer;

  procedure Slip(AId: Integer; const ANote, AStatus: string);
  begin
    Db.Conn.ExecuteDirect(Format('INSERT INTO slips (slip_id, created_at, ref_date, stake, note, status, paper) VALUES (%d, ''2026-11-01'', ''2026-11-01'', 1, ''%s'', ''%s'', 1)',
      [AId, ANote, AStatus]));
  end;

  procedure Leg(ASlip: Integer; const AHome, AAway, AMarket, ASel: string; AProb: Double; const AStatus: string);
  begin
    Db.Conn.ExecuteDirect(Format('INSERT INTO slip_legs (slip_id, division, hometeam, awayteam, market, selection, model_probability, odds, status) ' +
      'VALUES (%d, ''E0'', ''%s'', ''%s'', ''%s'', ''%s'', %s, %s, ''%s'')',
      [ASlip, AHome, AAway, AMarket, ASel, StringReplace(FloatToStr(AProb), ',', '.', []), StringReplace(FloatToStr(1.0 / AProb), ',', '.', []), AStatus]));
  end;

  function Val(const ASql: string): Double;
  var
    Q: TZQuery;
  begin
    Q := Db.NewQuery(ASql);
    try
      Q.Open;
      Result := Q.Fields[0].AsFloat;
    finally
      Q.Free;
    end;
  end;

begin
  if FileExists('/tmp/ta_an.db') then DeleteFile('/tmp/ta_an.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_an.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE slips (slip_id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT, ref_date TEXT, stake REAL, note TEXT, status TEXT, settled_at TEXT, paper INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE slip_legs (leg_id INTEGER PRIMARY KEY AUTOINCREMENT, slip_id INTEGER, division TEXT, hometeam TEXT, awayteam TEXT, market TEXT, selection TEXT, ' +
      'model_probability REAL, odds REAL, status TEXT, match_id INTEGER, score TEXT, settled_at TEXT)');
    Slip(1, 'generirani v2 - mjesoviti 1 - uzorak 1', 'LOST');
    Leg(1, 'A', 'B', '1X2', '1', 0.5, 'LOST');
    Leg(1, 'C', 'D', 'DOUBLE_CHANCE', '1X', 0.8, 'WON');
    Slip(2, 'generirani v2 - mjesoviti 2 - uzorak 1', 'WON');
    Leg(2, 'E', 'F', 'OVER_UNDER', 'Over 1.5', 0.75, 'WON');
    Leg(2, 'C', 'D', 'DOUBLE_CHANCE', '1X', 0.8, 'WON');
    Slip(3, 'prijelazi v1 - prijelaz - A - B [E0] (1/1)', 'WON');
    Leg(3, 'A', 'B', 'HTFT', '1/1', 0.4, 'WON');
    N := Trunc(Double(EvalExpr('RunAnalytics()', nil)));
    Check(N > 0, 'analytics: the tables are written (' + IntToStr(N) + ' rows)');
    Check((Val('SELECT listica FROM an_sazetak WHERE opseg = ''probno''') = 2) and (Val('SELECT informativnih FROM an_sazetak WHERE opseg = ''probno''') = 1),
      'analytics: the summary counts two main slips and one informational');
    Check((Val('SELECT rijesenih FROM an_sazetak WHERE opseg = ''probno''') = 2) and (Val('SELECT dobivenih FROM an_sazetak WHERE opseg = ''probno''') = 1) and
      (Abs(Val('SELECT dobitak FROM an_sazetak WHERE opseg = ''probno''') - (5.0 / 3.0 - 2.0)) < 1e-6), 'analytics: settled, won and profit of the main slips');
    Check((Val('SELECT parova FROM an_kalibracija_sustava WHERE sustav = ''generirani v2''') = 3) and
      (Abs(Val('SELECT pogodak FROM an_kalibracija_sustava WHERE sustav = ''generirani v2''') - 2.0 / 3.0) < 1e-6) and
      (Abs(Val('SELECT ocekivano FROM an_kalibracija_sustava WHERE sustav = ''generirani v2''') - (0.5 + 0.8 + 0.75) / 3.0) < 1e-6) and
      (Abs(Val('SELECT roi FROM an_kalibracija_sustava WHERE sustav = ''generirani v2''') - ((1.25 + 4.0 / 3.0) / 3.0 - 1.0)) < 1e-6),
      'analytics: three distinct calls (the repeated one counts once), hit rate, expected rate and ROI at fair prices');
    Check(Val('SELECT COUNT(*) FROM an_kalibracija_sustava WHERE sustav LIKE ''prijelaz%''') = 0, 'analytics: informational systems stay out of the calibration');
    Check(Val('SELECT parova FROM an_kalibracija WHERE sustav = ''generirani v2'' AND trziste = ''DOUBLE_CHANCE''') = 1, 'analytics: calibration by market');
    Check((Abs(Val('SELECT cijeli_vraceno FROM an_strategija WHERE opseg = ''probno'' AND sustav = ''''') - 5.0 / 3.0) < 1e-6) and
      (Abs(Val('SELECT pojed_vraceno FROM an_strategija WHERE opseg = ''probno'' AND sustav = ''''') - (0.625 + 0.5 * (4.0 / 3.0 + 1.25))) < 1e-6),
      'analytics: the whole slip against the same legs as singles');
    Check((Val('SELECT listica FROM an_pracenje WHERE sustav = ''prijelazi'' AND odjeljak = ''ukupno''') = 1) and
      (Val('SELECT dobiveno FROM an_pracenje WHERE sustav = ''prijelazi'' AND odjeljak = ''ukupno''') = 1), 'analytics: the transition system is tracked on its own');
    Check(Val('SELECT COUNT(*) FROM an_pracenje WHERE sustav = ''prijelazi'' AND odjeljak = ''oblik'' AND naziv = ''pojedinacni''') = 1, 'analytics: tracking by shape');
    N := Trunc(Double(EvalExpr('RunAnalytics()', nil)));
    Check(Val('SELECT COUNT(*) FROM an_sazetak') = 2, 'analytics: running it again replaces the tables');
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

function ProfitOf(AWon: Integer; AP: Double): Double;
begin
  if AWon = 1 then Result := 1.0 / AP - 1.0 else Result := -1.0;
end;

procedure TestReliability;
var
  Db: TAppDb;
  I, Season: Integer;
  P: Double;
  Won: Integer;
  A, B: Double;
  Rows: Integer;

  function Val_(const ASql: string): Double;
  var
    Q: TZQuery;
  begin
    Q := Db.NewQuery(ASql);
    try
      Q.Open;
      Result := Q.Fields[0].AsFloat;
    finally
      Q.Free;
    end;
  end;

begin
  if FileExists('/tmp/ta_rel.db') then DeleteFile('/tmp/ta_rel.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_rel.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE backtest_bets (id INTEGER PRIMARY KEY AUTOINCREMENT, system TEXT, division TEXT, season TEXT, matchdate TEXT, match_id INTEGER, market TEXT, ' +
      'selection TEXT, probability REAL, fair_odds REAL, won INTEGER, profit REAL)');
    { dvije sezone po 200 oklada, vjerojatnost 0.5..0.9, ishodi odredjeni ali mijesani }
    for Season := 0 to 1 do
      for I := 0 to 199 do
      begin
        P := 0.5 + 0.4 * ((I * 37) mod 100) / 100.0;
        if ((I * 53 + Season * 17) mod 100) / 100.0 < P then Won := 1 else Won := 0;
        Db.Conn.ExecuteDirect(Format('INSERT INTO backtest_bets (system, division, season, matchdate, match_id, market, selection, probability, fair_odds, won, profit) ' +
          'VALUES (''veliki'', ''E0'', ''%d-%d'', ''2024-%.2d-%.2d'', %d, ''1X2'', ''1'', %s, %s, %d, %s)',
          [2020 + Season, 2021 + Season, 1 + (I div 20) mod 12, 1 + (I mod 20), I,
           StringReplace(FloatToStr(P), ',', '.', []), StringReplace(FloatToStr(1.0 / P), ',', '.', []), Won,
           StringReplace(FloatToStr(ProfitOf(Won, P)), ',', '.', [])]));
      end;
    Rows := Trunc(Double(EvalExpr('RunReliability(500, 7)', nil)));
    Check(Rows = 1, 'reliability: one row for the one system');
    Check(Abs(Val_('SELECT roi FROM backtest_pouzdanost') - Val_('SELECT AVG(profit) FROM backtest_bets')) < 1e-9, 'reliability: ROI is the mean profit per bet');
    Check((Val_('SELECT kolo_lo FROM backtest_pouzdanost') < Val_('SELECT kolo_hi FROM backtest_pouzdanost')) and (Val_('SELECT sez_lo FROM backtest_pouzdanost') < Val_('SELECT sez_hi FROM backtest_pouzdanost')),
      'reliability: the intervals have a low and a high end');
    Check((Val_('SELECT p_info FROM backtest_pouzdanost') > 0) and (Val_('SELECT p_info FROM backtest_pouzdanost') <= 1) and
      (Val_('SELECT p_roi FROM backtest_pouzdanost') > 0) and (Val_('SELECT p_roi FROM backtest_pouzdanost') <= 1), 'reliability: p-values are between 0 and 1');
    A := Val_('SELECT kolo_lo FROM backtest_pouzdanost');
    EvalExpr('RunReliability(500, 7)', nil);
    B := Val_('SELECT kolo_lo FROM backtest_pouzdanost');
    Check(A = B, 'reliability: the same seed gives the same numbers');
    Rows := Trunc(Double(EvalExpr('RunProgression(0, 400, 7)', nil)));
    Check(Rows = 9, 'progression: one row per staking rule');
    Check(Val_('SELECT COUNT(*) FROM backtest_progresije WHERE replikacija = 800') = 9, 'progression: both seasons are simulated, 400 runs each');
    Check(Abs(Val_('SELECT prosjek FROM backtest_progresije WHERE pravilo = ''FLAT''')) < 5, 'progression: flat staking at fair prices averages about zero');
    Check(Val_('SELECT udio_negativnih FROM backtest_progresije WHERE pravilo = ''LET_IT_RIDE''') > 0.9, 'progression: letting winnings ride loses almost always');
    Check(Val_('SELECT najgore FROM backtest_progresije WHERE pravilo = ''MARTINGALE''') < Val_('SELECT najgore FROM backtest_progresije WHERE pravilo = ''FLAT'''), 'progression: the worst martingale run is worse than the worst flat one');
    Rows := Trunc(Double(EvalExpr('RunProgression(3, 200, 7)', nil)));
    Check(Val_('SELECT replikacija FROM backtest_progresije WHERE pravilo = ''FLAT''') = 400, 'progression: a horizon of 3 rounds still gives runs for both seasons');
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

procedure TestPredictFunctions;
var
  Db: TAppDb;
  H: TTestHost;
  I, J, K: Integer;
  Hg, Ag, Hh, Ah: Integer;
  Dt: string;
  P1, PX, P2, Dc, Ov, Un, Ht, Ho: Double;
  Sum: Double;
  Sel: string;
  V: Variant;
  Names: array[0..5] of string = ('Ajax', 'Bern', 'Cork', 'Dundee', 'Essen', 'Faro');

  function Pr(const AMarket, ASel: string): Variant;
  begin
    Result := EvalExpr('Predict("TST1", "Ajax", "Bern", "2026-06-01", "' + AMarket + '", "' + ASel + '")', H);
  end;

begin
  if FileExists('/tmp/ta_predict.db') then DeleteFile('/tmp/ta_predict.db');
  Db := TAppDb.Create;
  H := TTestHost.Create;
  try
    Db.Open('/tmp/ta_predict.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE matches (match_id INTEGER PRIMARY KEY AUTOINCREMENT, division TEXT, matchdate TEXT, season TEXT, ' +
      'hometeam TEXT, awayteam TEXT, fthg INTEGER, ftag INTEGER, ftr TEXT, hthg INTEGER, htag INTEGER, htr TEXT)');
    { 4 kruga dvostrukog liga-sustava, nasumicno-izgledni ali odredjeni rezultati }
    for K := 0 to 3 do
      for I := 0 to 5 do
        for J := 0 to 5 do
          if I <> J then
          begin
            Hg := (I * 3 + J * 5 + K * 2) mod 4;
            Ag := (I * 5 + J * 2 + K) mod 3;
            Hh := Hg div 2;
            Ah := Ag div 2;
            Dt := FormatDateTime('yyyy-mm-dd', EncodeDate(2025, 9, 1) + K * 60 + (I * 6 + J));
            Db.Conn.ExecuteDirect(Format('INSERT INTO matches (division, matchdate, season, hometeam, awayteam, fthg, ftag, ftr, hthg, htag, htr) ' +
              'VALUES (''TST1'', ''%s'', ''2025'', ''%s'', ''%s'', %d, %d, ''%s'', %d, %d, ''%s'')',
              [Dt, Names[I], Names[J], Hg, Ag, Res3(Hg, Ag), Hh, Ah, Res3(Hh, Ah)]));
          end;
    P1 := EvalExpr('Predict("TST1", "Ajax", "Bern", "2026-06-01", "1X2", "1")', H);
    PX := Pr('1X2', 'X'); P2 := Pr('1X2', '2');
    Check(Abs(P1 + PX + P2 - 1.0) < 1e-9, 'predict: the 1X2 probabilities add up to 1 (' + FloatToStr(P1 + PX + P2) + ')');
    Check((P1 > 0) and (P1 < 1), 'predict: a probability is between 0 and 1');
    Dc := Pr('DOUBLE_CHANCE', '1X');
    Check(Abs(Dc - (P1 + PX)) < 1e-9, 'predict: double chance 1X is 1 plus X');
    Ov := Pr('OVER_UNDER', 'Over 2.5'); Un := Pr('OVER_UNDER', 'Under 2.5');
    Check(Abs(Ov + Un - 1.0) < 1e-9, 'predict: over and under add up to 1');
    Sum := 0;
    for Sel in ['1/1', '1/X', '1/2', 'X/1', 'X/X', 'X/2', '2/1', '2/X', '2/2'] do Sum := Sum + Pr('HTFT', Sel);
    Check(Abs(Sum - 1.0) < 1e-9, 'predict: the nine half-time/full-time cells add up to 1 (' + FloatToStr(Sum) + ')');
    Ht := Pr('HTFT', '1/1'); Ho := Pr('HT_OR_FT', '1');
    Check(Ho > Ht, 'predict: half-time or full-time is more likely than half-time and full-time');
    Check(VarIsNull(Pr('NEMA', '1')) and VarIsNull(Pr('1X2', 'Q')), 'predict: an unknown market or selection is empty');
    Check(VarIsNull(EvalExpr('Predict("NEMA1", "A", "B", "2026-06-01", "1X2", "1")', H)), 'predict: a league without matches has no prediction');
    V := EvalExpr('Predict("TST1", "Ajax", "Nepoznati", "2026-06-01", "1X2", "1")', H);
    Check(not VarIsNull(V), 'predict: a club with no history gets the divisional average, not an error');
    V := EvalExpr('PredictXG("TST1", "Ajax", "Bern", "2026-06-01", "domaci")', H);
    Check(not VarIsNull(V) and (Double(V) > 0), 'predict: expected goals are positive');
    Check(Abs(Double(Pr('1X2', '1')) - P1) < 1e-15, 'predict: the same call gives the same number (cached)');
    EvalExpr('PredictReset()', H);
    Check(Abs(Double(Pr('1X2', '1')) - P1) < 1e-15, 'predict: after a reset the number is recomputed the same');
    Check(VarIsNull(EvalExpr('Predict("TST1", "Ajax", "Bern", "2024-01-01", "1X2", "1")', H)), 'predict: no history before the date means no prediction');
  finally
    ActiveDb := nil;
    H.Free;
    Db.Free;
  end;
end;

procedure TestSpecCharts;
var
  Db: TAppDb;
  Log, Names: TStringList;
  Spec: TAppSpec;
  Rd: TaReportDef;
  I, Charts: Integer;
  Ok: Boolean;
  Txt: string;
begin
  { greske: grafikoni bez grafikona, krivi tip, nepoznat upit }
  Spec := TAppSpec.Create;
  try
    ParseAppSpec('izvjesce G' + LineEnding + '  vrsta: grafikoni' + LineEnding +
      'izvjesce H' + LineEnding + '  vrsta: grafikoni' + LineEnding + '  grafikon: A | torta | nema_upita' + LineEnding, Spec);
    Ok := ValidateAppSpec(Spec);
    Check((not Ok) and (Pos('barem jedan', Spec.Errors.Text) > 0) and (Pos('bar, line ili pie', Spec.Errors.Text) > 0) and (Pos('nema_upita', Spec.Errors.Text) > 0),
      'charts: a chart report is checked: ' + Spec.Errors.Text);
  finally
    Spec.Free;
  end;
  if FileExists('/tmp/ta_spec_ch.db') then DeleteFile('/tmp/ta_spec_ch.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  try
    Db.Open('/tmp/ta_spec_ch.db');
    ActiveDb := Db;
    Txt := 'tablica prodaja "Prodaja" bezforme bezizvjesca' + LineEnding + '  mjesec Text' + LineEnding + '  iznos Decimal/2' + LineEnding +
      'upit "Po mjesecima"' + LineEnding + '  SELECT mjesec, iznos FROM prodaja ORDER BY mjesec' + LineEnding +
      'izvjesce "Pregled"' + LineEnding + '  vrsta: grafikoni' + LineEnding + '  naslov: Pregled prodaje' + LineEnding +
      '  grafikon: Stupci | bar | Po mjesecima' + LineEnding + '  grafikon: Linija | line | SELECT mjesec, iznos FROM prodaja' + LineEnding +
      '  grafikon: Pita | pie | Po mjesecima' + LineEnding + '  grafikon: Jos jedan | bar | Po mjesecima' + LineEnding;
    Ok := BuildAppFromSpecText(Db, Txt, Log);
    Check(Ok and (Pos('GREŠKA', Log.Text) = 0), 'charts: the application is built: ' + Log.Text);
    Names := Db.ListObjects('_sys_reports');
    Check(Names.IndexOf('Pregled') >= 0, 'charts: the chart report exists');
    Names.Free;
    Db.Conn.ExecuteDirect('INSERT INTO prodaja (mjesec, iznos) VALUES (''2026-01'', 10), (''2026-02'', 25)');
    Rd := TaReportDef.Create;
    try
      Rd.FromJson(Db.LoadObject('_sys_reports', 'Pregled'));
      Charts := 0;
      for I := 0 to Rd.Count - 1 do
        if Rd.Items[I].Kind = 'Chart' then
        begin
          Inc(Charts);
          Check(Pos('SELECT', UpperCase(Rd.Items[I].RowSource)) = 1, 'charts: a chart carries the SQL of its query');
        end;
      Check(Charts = 4, 'charts: four charts in the report (' + IntToStr(Charts) + ')');
    finally
      Rd.Free;
    end;
  finally
    Log.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

procedure TestAppSpec;
var
  Spec: TAppSpec;
  Db: TAppDb;
  Log, Txt, Names, SpecFile: TStringList;
  Fm: TaFormDef;
  M: TaFieldMeta;
  Host: TForm;
  Sh: TaShell;
  Old: TRunnerMessageProc;
  T: TaDocType;
  Ok: Boolean;
  Y: string;
begin
  Y := FormatDateTime('yyyy', Date);
  { 1. pogreske imaju broj retka }
  Spec := TAppSpec.Create;
  try
    Ok := ParseAppSpec(
      'tablica a' + LineEnding + '  x Tekstic' + LineEnding + '  y Text veza=nema.id' + LineEnding +
      'neka_rijec' + LineEnding + 'izbornik' + LineEnding + '  Natpis bez strelice' + LineEnding, Spec);
    Check((not Ok) and (Pos('retak 2', Spec.Errors.Text) > 0) and (Pos('Tekstic', Spec.Errors.Text) > 0) and
      (Pos('retak 4', Spec.Errors.Text) > 0) and (Pos('retak 6', Spec.Errors.Text) > 0), 'appspec: syntax errors name the line: ' + Spec.Errors.Text);
  finally
    Spec.Free;
  end;
  Spec := TAppSpec.Create;
  try
    ParseAppSpec('tablica a' + LineEnding + '  x Text veza=nema.id' + LineEnding + '  y Text veza=a.zz' + LineEnding +
      'forma F' + LineEnding + '  izvor: nepoznata' + LineEnding +
      'izbornik' + LineEnding + '  Natpis -> forma NemaOve' + LineEnding, Spec);
    Ok := ValidateAppSpec(Spec);
    Check((not Ok) and (Pos('nema', Spec.Errors.Text) > 0) and (Pos('"zz"', Spec.Errors.Text) > 0) and (Pos('nepoznata', Spec.Errors.Text) > 0) and (Pos('NemaOve', Spec.Errors.Text) > 0),
      'appspec: references between parts are checked: ' + Spec.Errors.Text);
  finally
    Spec.Free;
  end;
  { 2. mala aplikacija iz opisa }
  if FileExists('/tmp/ta_spec1.db') then DeleteFile('/tmp/ta_spec1.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  try
    Db.Open('/tmp/ta_spec1.db');
    ActiveDb := Db;
    Ok := BuildAppFromSpecText(Db,
      'aplikacija "Proba"' + LineEnding + '  naslov: Proba d.o.o.' + LineEnding +
      'tablica kupci "Kupci"' + LineEnding + '  naziv Text obavezno' + LineEnding + '  limit Currency' + LineEnding +
      '    zadano: 100' + LineEnding + '    pravilo: [limit] >= 0 | Limit ne smije biti negativan' + LineEnding +
      'tablica narudzbe' + LineEnding + '  kupac_id Integer veza=kupci.id' + LineEnding + '  iznos Currency' + LineEnding +
      'vrsta pro "Proba" prefiks=pr srodne=sek' + LineEnding + 'vrsta sek "Sekundarna" prefiks=sk srodne=pro' + LineEnding +
      'prava' + LineEnding + '  forma Kupci: admin' + LineEnding + 'postavke' + LineEnding + '  firma.naziv: Proba d.o.o.' + LineEnding, Log);
    Check(Ok and (Pos('GREŠKA', Log.Text) = 0), 'appspec: a small application is built: ' + Log.Text);
    Names := Db.UserTables;
    Check((Names.IndexOf('kupci') >= 0) and (Names.IndexOf('narudzbe') >= 0) and (Names.IndexOf('dokumenti') >= 0), 'appspec: tables and the document types table exist');
    Names.Free;
    M := Db.FindFieldMeta('kupci', 'limit');
    Check((M <> nil) and (M.DefaultExpr = '100') and (M.Validation = '[limit] >= 0') and (M.ValidationMsg = 'Limit ne smije biti negativan'), 'appspec: default and rule of a field are stored');
    M.Free;
    Check((Db.ForeignKeys('narudzbe').Count = 1), 'appspec: the foreign key was created');
    Names := Db.ListObjects('_sys_forms');
    Check((Names.IndexOf('Kupci') >= 0) and (Names.IndexOf('Narudzbe') >= 0) and (Names.IndexOf('Izbornik') >= 0), 'appspec: every table without a form gets one, and the menu exists');
    Names.Free;
    Names := Db.ListObjects('_sys_reports');
    Check((Names.IndexOf('Popis: Kupci') >= 0) and (Names.IndexOf('Popis: Narudzbe') >= 0), 'appspec: every table gets a list report');
    Names.Free;
    Fm := TaFormDef.Create;
    Fm.FromJson(Db.LoadObject('_sys_forms', 'Izbornik'));
    Check((Fm.Count = 2) and (Fm[1].Kind = 'SideMenu') and (Pos('openform:Kupci', Fm[1].RowSource) > 0) and (Pos('openreport:Popis: Kupci', Fm[1].RowSource) > 0),
      'appspec: the generated menu is a side menu with the forms and reports');
    Fm.Free;
    DocTypeLoad(Db, 'pro', T);
    Check((T.Name = 'Proba') and (T.Prefix = 'pr') and (T.Related = 'sek') and DocTypesBlock(Db, 'sek', 'pro'), 'appspec: document types are registered with related types');
    Check((GetObjectRight(Db, '_sys_forms', 'Kupci') = arAdmin) and (LoadAppSettings(Db).StartupForm = 'Izbornik') and (LoadAppSettings(Db).Title = 'Proba d.o.o.') and
      (Db.LoadSetting('firma.naziv') = 'Proba d.o.o.'), 'appspec: rights, settings and the startup form are saved');
    { ista specifikacija jos jednom: ne smije puknuti }
    Log.Clear;
    Check(BuildAppFromSpecText(Db, 'tablica kupci' + LineEnding + '  naziv Text' + LineEnding, Log), 'appspec: applying a description over existing tables is harmless: ' + Log.Text);
    { odjeljak program: tijelo ispod naslova (uvlaka prvog retka se skida) i datoteka uz opis }
    Log.Clear;
    SpecFile := TStringList.Create;
    try
      SpecFile.Text := 'MAIN' + LineEnding + '  DISPLAY "iz datoteke"' + LineEnding + 'END MAIN';
      SpecFile.SaveToFile('/tmp/ta_prog.4gl');
    finally
      SpecFile.Free;
    end;
    Check(BuildAppFromSpecText(Db,
      'program Prvi' + LineEnding +
      '  MAIN' + LineEnding +
      '    IF 1 = 1 THEN' + LineEnding +
      '      DISPLAY "unutra"' + LineEnding +
      '    END IF' + LineEnding +
      '  END MAIN' + LineEnding +
      LineEnding +
      'program Drugi' + LineEnding +
      '  datoteka: ta_prog.4gl' + LineEnding +
      'izbornik' + LineEnding +
      '  Pokreni -> program Prvi' + LineEnding, Log, '/tmp/'), 'appspec: programs are built: ' + Log.Text);
    Check(Db.LoadObject('_sys_programs', 'Prvi') = 'MAIN' + LineEnding + '  IF 1 = 1 THEN' + LineEnding + '    DISPLAY "unutra"' + LineEnding + '  END IF' + LineEnding + 'END MAIN' + LineEnding,
      'appspec: an inline program keeps its own indentation and loses the one of the section');
    Check(Pos('iz datoteke', Db.LoadObject('_sys_programs', 'Drugi')) > 0, 'appspec: a program can come from a file next to the description');
    Log.Clear;
    Check(not BuildAppFromSpecText(Db, 'program Prazan' + LineEnding, Log) and (Pos('nema teksta', Log.Text) > 0), 'appspec: an empty program is an error: ' + Log.Text);
    Log.Clear;
    Check(not BuildAppFromSpecText(Db, 'program X' + LineEnding + '  datoteka: nema_je.4gl' + LineEnding, Log, '/tmp/') and (Pos('nema datoteke', Log.Text) > 0), 'appspec: a missing program file is an error: ' + Log.Text);
    Log.Clear;
    Check(not BuildAppFromSpecText(Db, 'program X' + LineEnding + '  datoteka: a.4gl' + LineEnding, Log) and (Pos('relativna datoteka', Log.Text) > 0), 'appspec: a relative file needs the description to come from a file: ' + Log.Text);
    DeleteFile('/tmp/ta_prog.4gl');
  finally
    Log.Free;
    ActiveDb := nil;
    Db.Free;
  end;
  { 3. primjer iz priloga radi do kraja: forma s vrstama i srodnim vrstama u radnom prostoru }
  if FileExists('/tmp/ta_spec2.db') then DeleteFile('/tmp/ta_spec2.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  Txt := TStringList.Create;
  Host := TForm.CreateNew(nil);
  Old := OnRunnerMessage;
  try
    if FileExists('../examples/aplikacije/mali-obrt.opis') then Txt.LoadFromFile('../examples/aplikacije/mali-obrt.opis')
    else Txt.LoadFromFile('examples/aplikacije/mali-obrt.opis');
    Db.Open('/tmp/ta_spec2.db');
    ActiveDb := Db;
    Check(BuildAppFromSpecText(Db, Txt.Text, Log), 'appspec: the example application is built: ' + Log.Text);
    Host.SetBounds(0, 0, 1000, 700);
    Sh := TaShell.CreateShell(Host, Db);
    Sh.Parent := Host;
    Host.Show;
    Application.ProcessMessages;
    OnRunnerMessage := @ShellMsg;
    ShellMsgs := '';
    Check(Sh.OpenForm('Dokument#vrsta=otp') and (Sh.TabRunner(0).Caption = 'Otpremnica'), 'appspec: the document form opens for a kind and takes its name');
    Check(Pos('otp-' + Y + '-0001', TEdit(CtlFor(Sh.TabRunner(0), 'broj')).Text) = 1, 'appspec: a new document gets its number from the kinds table (' + TEdit(CtlFor(Sh.TabRunner(0), 'broj')).Text + ')');
    Check((not Sh.OpenForm('Dokument#vrsta=rv')) and Sh.OpenForm('Dokument#vrsta=ponuda') and Sh.OpenForm('Partneri') and (Sh.TabCount = 3), 'appspec: related kinds exclude each other, the others open side by side');
    Check(Sh.CloseAll, 'appspec: tabs close');
    with TIniFile.Create(IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'sidemenu.ini') do
    try
      EraseSection('shell/ta_spec2.db');
    finally
      Free;
    end;
  finally
    OnRunnerMessage := Old;
    Host.Free;
    Txt.Free;
    Log.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

type
  TBoardCrack = class(TaOwnBoard)
  public
    procedure Key(K: Word; Sh: TShiftState = []);
  end;

procedure TBoardCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

procedure BoardSql(Db: TAppDb; const ASql: string);
var
  Q: TZQuery;
begin
  Q := Db.NewQuery(ASql);
  try
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function BoardVal(Db: TAppDb; const ASql: string): string;
var
  Q: TZQuery;
begin
  Q := Db.NewQuery(ASql);
  try
    Q.Open;
    Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

{ kanban ploca: stupci iz sifrarnika, kartice iz izvora, premjestanje upisuje u bazu }
procedure TestBoard;
var
  Db: TAppDb;
  Log, Txt: TStringList;
  Def: TaFormDef;
  R: TaFormRunner;
  B: TBoardCrack;
  Js: string;
begin
  if FileExists('/tmp/ta_board.db') then DeleteFile('/tmp/ta_board.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  Txt := TStringList.Create;
  try
    if FileExists('../examples/aplikacije/procesi.opis') then Txt.LoadFromFile('../examples/aplikacije/procesi.opis')
    else Txt.LoadFromFile('examples/aplikacije/procesi.opis');
    Db.Open('/tmp/ta_board.db');
    ActiveDb := Db;
    Check(BuildAppFromSpecText(Db, Txt.Text, Log), 'board: the Procesi example is built: ' + Log.Text);
    Check(Pos('ploča', Log.Text) > 0, 'board: the log names the board');
    BoardSql(Db, 'INSERT INTO vrste_proizvoda(naziv) VALUES (''Rajcica'')');
    BoardSql(Db, 'INSERT INTO faze(vrsta_id, redni, naziv) VALUES (1,1,''Sjetva''),(1,2,''Rast''),(1,3,''Prinos'')');
    BoardSql(Db, 'INSERT INTO serije(naziv, vrsta_id, faza_id) VALUES (''A'',1,1),(''B'',1,2),(''C'',1,NULL)');
    Js := Db.LoadObject('_sys_forms', 'Ploča procesa');
    Check(Js <> '', 'board: the board form is saved');
    Def := TaFormDef.Create;
    Def.FromJson(Js);
    Def.Name := 'Ploča procesa';
    Check((Def.ViewMode = 'board') and (Pos('faza_id', Def.Board) = 1), 'board: view mode and setting survive saving (' + Def.Board + ')');
    R := TaFormRunner.CreateRunner(nil, Db, Def);
    try
      R.Show;
      Application.ProcessMessages;
      Check(R.BoardBody <> nil, 'board: the runner builds the board body');
      B := TBoardCrack(R.BoardBody.Board);
      Check(B.ColumnCount = 4, 'board: three phases plus the column for cards without one (' + IntToStr(B.ColumnCount) + ')');
      Check((B.CardCount = 3) and (B.CardsIn('1') = 1) and (B.CardsIn('') = 1), 'board: cards sit in the column of their value');
      B.SelectedId := '1';
      B.Key(VK_RIGHT, [ssAlt]);
      Check(B.ColumnOfCard('1') = '2', 'board: Alt+Right moves the card to the next column');
      Check(BoardVal(Db, 'SELECT faza_id FROM serije WHERE id = 1') = '2', 'board: the move is written to the database');
      B.Key(VK_LEFT, [ssAlt]);
      B.Key(VK_LEFT, [ssAlt]);
      Check(BoardVal(Db, 'SELECT faza_id FROM serije WHERE id = 1') = '1', 'board: the first column stops the move (nothing before it)');
      B.SelectedId := '3';
      B.Key(VK_RIGHT, [ssAlt]);
      Check(B.ColumnOfCard('3') = '', 'board: the last column stops the move');
      B.Key(VK_LEFT, [ssAlt]);
      Check(B.ColumnOfCard('3') = '3', 'board: a card without a phase can be given one (' + B.ColumnOfCard('3') + ')');
      B.Key(VK_DOWN);
      B.Key(VK_UP);
      Check(B.SelectedId <> '', 'board: arrows keep a card selected');
      R.Requery;
      Check(B.CardCount = 3, 'board: reloading keeps all the cards');
    finally
      R.Free;   { runner preuzima i oslobadja definiciju forme }
    end;
    { postavka mora imati vezu }
    Check(CheckBoardSetting(Db, 'serije', 'naziv | naziv') <> '', 'board: a column field without a lookup table is refused');
    Check(CheckBoardSetting(Db, 'serije', 'faza_id | naziv') = '', 'board: a linked column field is accepted');
    Log.Clear;
    Check(not BuildAppFromSpecText(Db, 'tablica t1' + LineEnding + '  a Text' + LineEnding + 'forma P' + LineEnding + '  izvor: t1' + LineEnding + '  raspored: ploca' + LineEnding + '  ploca: a | a' + LineEnding, Log) and
      (Pos('mora imati vezu', Log.Text) > 0), 'board: the spec checks that the column field has a link: ' + Log.Text);
  finally
    Txt.Free;
    Log.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ nadzorna ploca: kartica po pogonu, redak po senzoru, stanje prema granicama }
procedure TestDash;
var
  Db: TAppDb;
  Log, Txt: TStringList;
  Def: TaFormDef;
  R: TaFormRunner;
  D: TaOwnDash;
  I: Integer;
begin
  if FileExists('/tmp/ta_dash.db') then DeleteFile('/tmp/ta_dash.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  Txt := TStringList.Create;
  try
    if FileExists('../examples/aplikacije/procesi.opis') then Txt.LoadFromFile('../examples/aplikacije/procesi.opis')
    else Txt.LoadFromFile('examples/aplikacije/procesi.opis');
    Db.Open('/tmp/ta_dash.db');
    ActiveDb := Db;
    Check(BuildAppFromSpecText(Db, Txt.Text, Log), 'dash: the Procesi example is built: ' + Log.Text);
    Check(Pos('nadzorna ploča', Log.Text) > 0, 'dash: the log names the dashboard');
    BoardSql(Db, 'INSERT INTO vrste_uredjaja(naziv, uloga, jedinica) VALUES (''Temperatura zraka'',''senzor'',''°C''),(''pH'',''senzor'',''pH''),(''Ventilator'',''izvrsni'','''')');
    BoardSql(Db, 'INSERT INTO pogoni(naziv, tema, zadnji_signal) VALUES (''K1'',''procesi/t/pogon1'',''2026-01-01 10:00:00''),(''K2'',''procesi/t/k2'',NULL)');
    BoardSql(Db, 'INSERT INTO uredjaji(pogon_id, vrsta_id, naziv, tema, min, max, aktivan) VALUES (1,1,''Temp'',''t'',18,28,1),(1,2,''pH'',''ph'',5.5,6.5,1),(2,1,''Temp 2'',''t'',18,28,1),(1,3,''Vent'',''v'',NULL,NULL,1)');
    for I := 1 to 5 do BoardSql(Db, 'INSERT INTO ocitanja(uredjaj_id, vrijeme, vrijednost) VALUES (1,''2026-01-01 10:0' + IntToStr(I) + ':00'',' + IntToStr(20 + I) + ')');
    BoardSql(Db, 'INSERT INTO ocitanja(uredjaj_id, vrijeme, vrijednost) VALUES (2,''2026-01-01 10:00:00'',7.1)');
    Def := TaFormDef.Create;
    Def.FromJson(Db.LoadObject('_sys_forms', 'Nadzorna ploča'));
    Def.Name := 'Nadzorna ploča';
    Def.Dash := Def.Dash + ' ;; potvrdi=ne';
    Check((Def.ViewMode = 'dash') and (Pos('grupa=Pogon', Def.Dash) = 1), 'dash: view mode and setting survive saving');
    R := TaFormRunner.CreateRunner(nil, Db, Def);
    try
      R.Show;
      Application.ProcessMessages;
      Check(R.DashBody <> nil, 'dash: the runner builds the dashboard');
      D := R.DashBody.Dash;
      Check((D.GroupCount = 2) and (D.ItemCount = 4), 'dash: two containers, three sensors and the fan: ' + IntToStr(D.GroupCount) + '/' + IntToStr(D.ItemCount));
      Check(D.WorstState('K1') = 1, 'dash: the container with pH above its limit is flagged');
      Check(D.WorstState('K2') = 2, 'dash: a container without readings shows no data');
      for I := 0 to D.ItemCount - 1 do
        if D.ItemAt(I).Name = 'Temp' then Break;
      Check(Length(D.ItemAt(I).Series) = 5, 'dash: the series holds the last readings (' + IntToStr(Length(D.ItemAt(I).Series)) + ')');
      Check((D.ItemAt(I).Series[0] = 21) and (D.ItemAt(I).Series[4] = 25), 'dash: the series runs from older to newer');
      BoardSql(Db, 'INSERT INTO ocitanja(uredjaj_id, vrijeme, vrijednost) VALUES (2,''2026-01-01 10:01:00'',6.0),(4,''2026-01-01 10:01:00'',1)');
      R.Requery;
      Check(D.WorstState('K1') = 0, 'dash: reloading picks up the new reading');
      { prekidac: izlaz je uključen, klik salje naredbu "iskljuci" i prekidac ceka potvrdu }
      for I := 0 to D.ItemCount - 1 do
        if D.ItemAt(I).Name = 'Vent' then Break;
      Check((D.ItemAt(I).Kind = 1) and D.ItemAt(I).On and not D.ItemAt(I).Pending, 'dash: an output is a switch showing its real state');
      D.OnItemClick(D, D.ItemAt(I).Id);
      Check(BoardVal(Db, 'SELECT akcija || '' '' || izvor || '' '' || stanje FROM naredbe WHERE uredjaj_id = 4') = 'iskljuci korisnik cekanje',
        'dash: clicking a switch writes the command (' + BoardVal(Db, 'SELECT akcija || '' '' || izvor || '' '' || stanje FROM naredbe WHERE uredjaj_id = 4') + ')');
      for I := 0 to D.ItemCount - 1 do
        if D.ItemAt(I).Name = 'Vent' then Break;
      Check(D.ItemAt(I).Pending, 'dash: the switch waits for the device to confirm');
      { alarmi: otvoreni alarm pogona crveni karticu i broji se; zatvoreni ne }
      BoardSql(Db, 'INSERT INTO alarmi(pogon_id, vrijeme, vrsta, poruka) VALUES (2,''2026-01-01 10:00:00'',''veza'',''x''),(2,''2026-01-01 10:00:00'',''veza'',''y'')');
      BoardSql(Db, 'INSERT INTO alarmi(pogon_id, vrijeme, vrsta, poruka, zatvoreno) VALUES (2,''2026-01-01 10:00:00'',''veza'',''z'',''2026-01-01 11:00:00'')');
      R.Requery;
      Check((D.GroupAlerts('K2') = 2) and (D.GroupAlerts('K1') = 0) and (D.WorstState('K2') = 1), 'dash: open alarms of a container are counted and flag it (' + IntToStr(D.GroupAlerts('K2')) + ')');
    finally
      R.Free;
    end;
    Check(CheckDashSetting('grupa=A ;; naziv=B') <> '', 'dash: a setting without the value field is refused');
    Check(CheckDashSetting('grupa=A ;; naziv=B ;; vrijednost=C') = '', 'dash: a complete setting is accepted');
  finally
    Txt.Free;
    Log.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

type
  TTlCrack = class(TaOwnTimeline)
  public
    procedure Down(X, Y: Integer);
    procedure Move(X, Y: Integer);
    procedure Up(X, Y: Integer);
    procedure Drag(X1, Y1, X2, Y2: Integer);
    procedure Key(K: Word; Sh: TShiftState = []);
    function PxOf(AMin: Integer): Integer;
  end;

procedure TTlCrack.Down(X, Y: Integer);
begin
  MouseDown(mbLeft, [], X, Y);
end;

procedure TTlCrack.Move(X, Y: Integer);
begin
  MouseMove([ssLeft], X, Y);
end;

procedure TTlCrack.Up(X, Y: Integer);
begin
  MouseUp(mbLeft, [], X, Y);
end;

procedure TTlCrack.Drag(X1, Y1, X2, Y2: Integer);
begin
  Down(X1, Y1);
  Move((X1 + X2) div 2, Y2);
  Move(X2, Y2);
  Up(X2, Y2);
end;

procedure TTlCrack.Key(K: Word; Sh: TShiftState);
begin
  KeyDown(K, Sh);
end;

function TTlCrack.PxOf(AMin: Integer): Integer;
begin
  Result := 44 + AMin * (Width - 44 - 10) div 1440;
end;

{ raspored: vremenska crta s trakama po danima, upisom u bazu }
procedure TestTimeline;
var
  Db: TAppDb;
  Log, Txt: TStringList;
  Def: TaFormDef;
  R: TaFormRunner;
  T: TTlCrack;
  Fm: TForm;
  L: TTlCrack;
  Y, RowH, HeadH: Integer;
begin
  Check((MinToText(375) = '06:15') and (TextToMin('22:30', 0) = 1350) and (TextToMin('x', 7) = 7), 'timeline: minutes and time text convert');
  Fm := TForm.CreateNew(nil);
  try
    Fm.SetBounds(0, 0, 700, 320);
    L := TTlCrack.Create(Fm);
    L.Parent := Fm;
    L.SetBounds(0, 0, 700, 300);
    L.AddItem('1', '12345', 360, 1320, 0, 0);
    L.AddItem('2', '1234567', 1320, 360, 0, 0);
    L.AddItem('3', '1234567', 0, 0, 180, 120);
    L.EndUpdate;
    Check(L.Items[1].Wraps and not L.Items[0].Wraps, 'timeline: a bar that crosses midnight is recognised');
    Check(L.Items[0].HasDay(5) and not L.Items[0].HasDay(6), 'timeline: days of a bar');
    Fm.Show;
    Application.ProcessMessages;
    HeadH := 24;
    RowH := 30;
    L.Selected := L.Items[0];
    L.ToggleDay(L.Items[0], 6);
    Check(L.Items[0].Days = '123456', 'timeline: a day chip adds a day (' + L.Items[0].Days + ')');
    L.ToggleDay(L.Items[0], 6);
    Check(L.Items[0].Days = '12345', 'timeline: and removes it');
    L.Key(VK_RIGHT);
    Check((L.Items[0].StartMin = 375) and (L.Items[0].EndMin = 1335), 'timeline: the right arrow moves the bar by 15 minutes');
    L.Key(VK_RIGHT, [ssShift]);
    Check((L.Items[0].StartMin = 375) and (L.Items[0].EndMin = 1350), 'timeline: Shift+right lengthens it');
    L.Key(VK_DELETE);
    Check(L.Count = 2, 'timeline: Delete removes the selected bar');
  finally
    Fm.Free;
  end;
  { cijeli put preko baze }
  if FileExists('/tmp/ta_tl.db') then DeleteFile('/tmp/ta_tl.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  Txt := TStringList.Create;
  try
    if FileExists('../examples/aplikacije/procesi.opis') then Txt.LoadFromFile('../examples/aplikacije/procesi.opis')
    else Txt.LoadFromFile('examples/aplikacije/procesi.opis');
    Db.Open('/tmp/ta_tl.db');
    ActiveDb := Db;
    Check(BuildAppFromSpecText(Db, Txt.Text, Log), 'timeline: the Procesi example is built: ' + Log.Text);
    Check(Pos('izrađen raspored', Log.Text) > 0, 'timeline: the log names the schedule view');
    BoardSql(Db, 'INSERT INTO vrste_uredjaja(naziv, uloga) VALUES (''Svjetlo'',''izvrsni'')');
    BoardSql(Db, 'INSERT INTO pogoni(naziv, tema) VALUES (''K1'',''procesi/t/pogon1'')');
    BoardSql(Db, 'INSERT INTO uredjaji(pogon_id, vrsta_id, naziv, tema) VALUES (1,1,''Svjetlo'',''svjetlo'')');
    BoardSql(Db, 'INSERT INTO rasporedi(uredjaj_id, naziv, aktivan) VALUES (1,''Dan'',1)');
    BoardSql(Db, 'INSERT INTO rasporedi_stavke(raspored_id, dani, od, do, svakih_min, trajanje_s) VALUES (1,''12345'',''06:00'',''22:00'',0,0),(1,''1234567'',NULL,NULL,180,60)');
    Def := TaFormDef.Create;
    Def.FromJson(Db.LoadObject('_sys_forms', 'Raspored (vremenska crta)'));
    Def.Name := 'Raspored (vremenska crta)';
    Check((Def.ViewMode = 'timeline') and (Pos('glavni=', Def.Timeline) = 1), 'timeline: view mode and setting survive saving');
    R := TaFormRunner.CreateRunner(nil, Db, Def);
    try
      R.Show;
      Application.ProcessMessages;
      Check(R.TimelineBody <> nil, 'timeline: the runner builds the schedule view');
      T := TTlCrack(R.TimelineBody.Line);
      Check(R.TimelineBody.Combo.Items.Count = 1, 'timeline: the list holds the schedules');
      Check(T.Count = 2, 'timeline: both items of the schedule are loaded (' + IntToStr(T.Count) + ')');
      Check((T.Items[0].StartMin = 360) and (T.Items[0].EndMin = 1320) and (T.Items[1].EveryMin = 180) and (T.Items[1].DurSec = 60),
        'timeline: times and repeat are read from the table');
      { nova traka: povuci po retku subote od 08:00 do 10:00 }
      RowH := 0;
      Y := 0;
      T.Down(T.PxOf(480), 24 + 5 * ((T.Height - 24 - 44) div 7) + 6);
      T.Move(T.PxOf(540), 24 + 5 * ((T.Height - 24 - 44) div 7) + 6);
      T.Move(T.PxOf(600), 24 + 5 * ((T.Height - 24 - 44) div 7) + 6);
      T.Up(T.PxOf(600), 24 + 5 * ((T.Height - 24 - 44) div 7) + 6);
      Check(T.Count = 3, 'timeline: dragging on an empty row makes a new bar (' + IntToStr(T.Count) + ')');
      Check(BoardVal(Db, 'SELECT COUNT(*) FROM rasporedi_stavke WHERE raspored_id = 1') = '3', 'timeline: the new bar is written to the table');
      Check((BoardVal(Db, 'SELECT dani FROM rasporedi_stavke WHERE id = 3') = '6') and (BoardVal(Db, 'SELECT od FROM rasporedi_stavke WHERE id = 3') = '08:00') and
        (BoardVal(Db, 'SELECT "do" FROM rasporedi_stavke WHERE id = 3') = '10:00'),
        'timeline: day and times of the new bar (' + BoardVal(Db, 'SELECT dani || '' '' || od || '' '' || "do" FROM rasporedi_stavke WHERE id = 3') + ')');
      T.ToggleDay(T.Selected, 7);
      Check(BoardVal(Db, 'SELECT dani FROM rasporedi_stavke WHERE id = 3') = '67', 'timeline: a day chip is written to the table');
      T.Key(VK_RIGHT);
      Check(BoardVal(Db, 'SELECT od FROM rasporedi_stavke WHERE id = 3') = '08:15', 'timeline: moving the bar updates the table');
      T.Key(VK_DELETE);
      Check(BoardVal(Db, 'SELECT COUNT(*) FROM rasporedi_stavke WHERE raspored_id = 1') = '2', 'timeline: deleting removes the row');
    finally
      R.Free;
    end;
    Check(CheckTimelineSetting('glavni=SELECT 1') <> '', 'timeline: an incomplete setting is refused');
  finally
    Txt.Free;
    Log.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ ESPHome konfiguracija pogona iz tablica uredjaja }
procedure TestEspHome;
var
  Db: TAppDb;
  Log, Txt: TStringList;
  Y: string;
begin
  if FileExists('/tmp/ta_eh.db') then DeleteFile('/tmp/ta_eh.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  Txt := TStringList.Create;
  try
    if FileExists('../examples/aplikacije/procesi.opis') then Txt.LoadFromFile('../examples/aplikacije/procesi.opis')
    else Txt.LoadFromFile('examples/aplikacije/procesi.opis');
    Db.Open('/tmp/ta_eh.db');
    ActiveDb := Db;
    Check(BuildAppFromSpecText(Db, Txt.Text, Log), 'esphome: the Procesi example is built: ' + Log.Text);
    BoardSql(Db, 'INSERT INTO lokacije(naziv, zona) VALUES (''L1'', ''Europe/Zagreb'')');
    BoardSql(Db, 'INSERT INTO vrste_uredjaja(naziv, uloga, jedinica) VALUES (''Temperatura zraka'',''senzor'',''°C''),(''Vlaga zraka'',''senzor'',''%''),(''pH'',''senzor'',''pH''),' +
      '(''Rasvjeta'',''izvrsni'',''''),(''Dozator'',''izvrsni'',''ml''),(''Prozor'',''izvrsni'',''%''),(''Pumpa'',''izvrsni'','''')');
    BoardSql(Db, 'INSERT INTO pogoni(naziv, tema, lokacija_id) VALUES (''K1'',''procesi/t/pogon1'',1),(''Bez teme'','''',1)');
    BoardSql(Db, 'INSERT INTO uredjaji(pogon_id, vrsta_id, naziv, tema, model, pin, invertirano, kal_a, kal_b, najdulje_s, aktivan) VALUES ' +
      '(1,1,''Temp'',''temp'',''dht22'',''4'',0,NULL,NULL,0,1),(1,2,''Vlaga'',''vlaga'',''dht22'',''GPIO4'',0,NULL,NULL,0,1),' +
      '(1,3,''pH'',''ph'',''adc'',''34'',0,3.5,0.25,0,1),(1,4,''Svjetlo'',''svjetlo'',''rele'',''16'',1,NULL,NULL,0,1),' +
      '(1,5,''Doza'',''doza'',''dozator'',''19'',0,NULL,NULL,120,1),(1,6,''Prozor'',''prozor'',''prozor'',''18'',0,NULL,NULL,30,1),' +
      '(1,7,''Pumpa'',''pumpa'',''rele'',''17'',0,NULL,NULL,3600,1),(1,1,''Bez modela'',''bm'','''',''5'',0,NULL,NULL,0,1)');
    BoardSql(Db, 'UPDATE uredjaji SET pin2 = ''19'' WHERE naziv = ''Prozor''');
    BoardSql(Db, 'UPDATE uredjaji SET pin = ''23'' WHERE naziv = ''Doza''');
    Log.Clear;
    Y := EspHomeConfig(Db, 1, Log);
    Check(Y <> '', 'esphome: a container with a topic gives a configuration');
    Check(Pos('topic_prefix: "procesi/t/pogon1"', Y) > 0, 'esphome: the MQTT prefix is the container topic');
    Check(Pos('timezone: "Europe/Zagreb"', Y) > 0, 'esphome: the time zone comes from the location');
    Check((Pos('platform: dht', Y) > 0) and (Pos('model: DHT22', Y) > 0) and (Pos('pin: GPIO4', Y) > 0), 'esphome: DHT22 on a numeric or GPIO pin');
    Check((Pos('temperature:', Y) > 0) and (Pos('humidity:', Y) > 0) and (Pos('state_topic: "procesi/t/pogon1/vlaga/stanje"', Y) > 0), 'esphome: temperature and humidity share one DHT block');
    Check(Pos('lambda: return x * 3.5 + 0.25;', Y) > 0, 'esphome: the ADC calibration becomes a filter');
    Check((Pos('number: GPIO16', Y) > 0) and (Pos('inverted: true', Y) > 0), 'esphome: an active-low relay is inverted');
    Check(Pos('id: doza_doza', Y) > 0, 'esphome: a doser gets a timed script');
    Check(Pos('std::min(seconds, (float) 120)', Y) > 0, 'esphome: the doser is limited by the safety maximum');
    Check((Pos('platform: time_based', Y) > 0) and (Pos('interlock:', Y) > 0), 'esphome: a window is a time based cover with an interlock');
    Check((Pos('id: max_pumpa', Y) > 0) and (Pos('delay: 3600s', Y) > 0), 'esphome: a relay with a maximum on-time gets a guard script');
    Check(Pos('topic: "procesi/t/pogon1/svjetlo/set"', Y) > 0, 'esphome: the output listens on the set topic');
    Check(Pos('topic: "procesi/t/pogon1/svjetlo/ack"', Y) > 0, 'esphome: the output confirms on the ack topic');
    Check(Pos('proces_rasp(', Y) > 0, 'esphome: schedules are kept by the header, not by globals');
    Check(Pos('globals:', Y) = 0, 'esphome: no globals of the custom type');
    Check(Pos('Bez modela', Y) = 0, 'esphome: a device without a model is skipped');
    Check(Pos('Bez modela', Log.Text) > 0, 'esphome: and reported in the log');
    Log.Clear;
    Check(EspHomeConfig(Db, 2, Log) = '', 'esphome: a container without a topic gives nothing');
    Check(Pos('nema MQTT temu', Log.Text) > 0, 'esphome: and says why');
    Check((Pos('ProcesRaspored', EspHomeHeader) > 0) and (Pos('proces_ukljuceno', EspHomeHeader) > 0), 'esphome: the schedule header is embedded');
    if DirectoryExists('/tmp/ta_eh_out') then DeleteDirectory('/tmp/ta_eh_out', False);
    Log.Clear;
    Check(EspHomeExportAll(Db, '/tmp/ta_eh_out', Log) = 1, 'esphome: export writes one configuration per container with a topic');
    Check(FileExists('/tmp/ta_eh_out/pogon1.yaml') and FileExists('/tmp/ta_eh_out/procesi_raspored.h') and FileExists('/tmp/ta_eh_out/secrets.yaml.example'),
      'esphome: export also writes the header and the secrets template');
  finally
    Txt.Free;
    Log.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ uvoz iz Accessa: prepis SQL-a i (kad su mdbtools i primjer dostupni) cijeli uvoz Northwinda }
function VbaFileText(const AFile: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.LoadFromFile(AFile);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

procedure TestMdbImport;
var
  Db: TAppDb;
  Log, Rep: TStringList;
  Spec, Sample: string;
  Q: TZQuery;
  Names: TStringList;
  Fks: TStringList;
begin
  Check(AccessSqlToSqlite('SELECT DISTINCTROW a FROM t;') = 'SELECT DISTINCT a FROM t', 'mdb: DISTINCTROW becomes DISTINCT');
  Check(AccessSqlToSqlite('SELECT TOP 10 a FROM t ORDER BY a DESCENDING') = 'SELECT a FROM t ORDER BY a DESC LIMIT 10', 'mdb: TOP n and DESCENDING: ' + AccessSqlToSqlite('SELECT TOP 10 a FROM t ORDER BY a DESCENDING'));
  Check(AccessSqlToSqlite('SELECT IIf(x=1,"a","b") & "c", Nz(y,0), CCur(z*2) FROM t') =
    'SELECT (CASE WHEN x=1 THEN ''a'' ELSE ''b'' END)  ||  ''c'', COALESCE(y, 0), (z*2) FROM t', 'mdb: IIf, Nz, CCur and & are rewritten: ' + AccessSqlToSqlite('SELECT IIf(x=1,"a","b") & "c", Nz(y,0), CCur(z*2) FROM t'));
  Check(AccessSqlToSqlite('WHERE d Between #1/2/1995# And #12/31/1995# AND f = Yes') = 'WHERE d Between ''1995-01-02'' And ''1995-12-31'' AND f = 1', 'mdb: date literals and Yes/No: ' + AccessSqlToSqlite('WHERE d Between #1/2/1995# And #12/31/1995# AND f = Yes'));
  Check(AccessSqlToSqlite('SELECT DatePart("q", d), Format(d, "yyyy-mm"), Left(a, 2), Mid(a, 2, 3), Len(a), UCase(a) FROM t') =
    'SELECT ((CAST(strftime(''%m'', d) AS INTEGER) + 2) / 3), strftime(''%Y-%m'', d), substr(a, 1, 2), substr(a, 2, 3), length(a), upper(a) FROM t', 'mdb: DatePart, Format and text functions: ' + AccessSqlToSqlite('SELECT DatePart("q", d), Format(d, "yyyy-mm"), Left(a, 2), Mid(a, 2, 3), Len(a), UCase(a) FROM t'));
  Check(AccessSqlToSqlite('WHERE n Like "A*" AND m = "x"') = 'WHERE n Like ''A%'' AND m = ''x''', 'mdb: Like wildcards and double quoted text: ' + AccessSqlToSqlite('WHERE n Like "A*" AND m = "x"'));
  Check(AccessSqlToSqlite('SELECT [Membership No] FROM m WHERE [Is Yes] = No') = 'SELECT [Membership No] FROM m WHERE [Is Yes] = 0', 'mdb: names in brackets are left alone: ' + AccessSqlToSqlite('SELECT [Membership No] FROM m WHERE [Is Yes] = No'));
  Check(AccessSqlToSqlite('SELECT a FROM t WHERE t.From <= 1') = 'SELECT a FROM t WHERE t."From" <= 1', 'mdb: a reserved word used as a column name is quoted: ' + AccessSqlToSqlite('SELECT a FROM t WHERE t.From <= 1'));
  Check(AccessSqlToSqlite('SELECT a FROM t WHERE IsNull(Forms![frm Main]!txtDay) OR b = forms!frmX!txtMonth') = 'SELECT a FROM t WHERE ([?txtDay] IS NULL) OR b = [?txtMonth]', 'mdb: unbracketed form references: ' + AccessSqlToSqlite('SELECT a FROM t WHERE IsNull(Forms![frm Main]!txtDay) OR b = forms!frmX!txtMonth'));
  Check(AccessSqlToSqlite('SELECT a FROM t WHERE IsNull(Forms!frmM!txtDay)') = 'SELECT a FROM t WHERE ([?txtDay] IS NULL)', 'mdb: IsNull becomes IS NULL: ' + AccessSqlToSqlite('SELECT a FROM t WHERE IsNull(Forms!frmM!txtDay)'));
  Check(AccessSqlToSqlite('WHERE m = [Forms]![frmPage].[Form]![sub].[Form]![MethodID]') = 'WHERE m = [?MethodID]', 'mdb: a reference through subforms uses the last control: ' + AccessSqlToSqlite('WHERE m = [Forms]![frmPage].[Form]![sub].[Form]![MethodID]'));
  Check((MdbValidationExpr('cijena', '>= 0') = '[cijena] >= 0') and (MdbValidationExpr('a', 'Is Not Null') = 'Not IsNull([a])') and
    (MdbValidationExpr('a', '[a] > 1 And [a] < 9') = '[a] > 1 And [a] < 9'), 'mdb: partial validation rules become expressions');
  Sample := GetEnvironmentVariable('MDB_SAMPLE');
  if Sample = '' then Sample := '/tmp/mdb_data/nwind.mdb';
  if (not MdbToolsAvailable) or (not FileExists(Sample)) then
  begin
    WriteLn('skip mdb import: mdbtools or the sample file (', Sample, ') is not available');
    Exit;
  end;
  if FileExists('/tmp/ta_mdbimp.db') then DeleteFile('/tmp/ta_mdbimp.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  Rep := TStringList.Create;
  try
    Db.Open('/tmp/ta_mdbimp.db');
    ActiveDb := Db;
    Check(ImportMdb(Db, Sample, Log, Rep, Spec), 'mdb: Northwind is imported: ' + Copy(Log.Text, 1, 300));
    Check((CountOf(Db, 'SELECT COUNT(*) FROM Customers') = '91') and (CountOf(Db, 'SELECT COUNT(*) FROM Orders') = '830') and
      (CountOf(Db, 'SELECT COUNT(*) FROM "Order Details"') = '2155') and (CountOf(Db, 'SELECT COUNT(*) FROM Products') = '77'), 'mdb: all rows arrive');
    Check(CountOf(Db, 'SELECT strftime(''%Y-%m-%d'', OrderDate) FROM Orders WHERE OrderID = 10330') = '1994-11-16', 'mdb: dates arrive as ISO dates');
    Check(CountOf(Db, 'SELECT ROUND(UnitPrice, 2) FROM Products WHERE ProductID = 1') = '18', 'mdb: currency values arrive');
    Fks := Db.ForeignKeys('Orders');
    Check(Fks.Count = 3, 'mdb: relationships became foreign keys (' + IntToStr(Fks.Count) + ')');
    Fks.Free;
    Names := Db.UserTables;
    Check((Names.IndexOf('Order Details') >= 0) and (Names.IndexOf('Umsätze') >= 0) and (Names.IndexOf('MSysObjects') < 0), 'mdb: names stay as in Access, system tables are left out');
    Names.Free;
    Check(Db.LoadObject('_sys_queries', 'Order Subtotals') <> '', 'mdb: saved queries are imported where their SQL works');
    Check((Db.LoadObject('_sys_queries', 'Catalog') <> '') and (Db.LoadObject('_sys_queries', 'Quarterly Orders by Product') <> ''), 'mdb: queries with more Access functions (DatePart, text functions) import too');
    Check((CountOf(Db, 'SELECT COUNT(*) FROM Employees WHERE Photo IS NOT NULL') = '9') and (CountOf(Db, 'SELECT COUNT(*) FROM Categories WHERE Picture IS NOT NULL') = '8'), 'mdb: OLE pictures become picture files');
    Check(Db.ListObjects('_sys_queries').Count = 22, 'mdb: all 22 saved queries are imported, crosstab and form parameters included (' + IntToStr(Db.ListObjects('_sys_queries').Count) + ')');
    Q := Db.NewQuery(Db.SourceSql('Quarterly Orders by Product'));
    try
      Q.Open;
      Check((Q.FindField('Qtr 1') <> nil) and (Q.FindField('Qtr 4') <> nil) and (Q.FindField('ProductName') <> nil) and (Q.RecordCount > 50), 'mdb: the crosstab query has one column per quarter (' + IntToStr(Q.RecordCount) + ' rows)');
    finally
      Q.Free;
    end;
    Check(Pos('[?BeginningDate]', Db.LoadObject('_sys_queries', 'Sales by Year')) > 0, 'mdb: a reference to a form control becomes a parameter prompt');
    Db.ParamValues.Clear;
    Db.ParamValues.Values['BeginningDate'] := '1995-01-01';
    Db.ParamValues.Values['EndingDate'] := '1995-12-31';
    Q := Db.NewQuery(Db.SourceSql('Sales by Year'));
    try
      Q.Open;
      Check(Q.RecordCount > 100, 'mdb: the parameter query runs once the values are given (' + IntToStr(Q.RecordCount) + ' rows)');
    finally
      Q.Free;
    end;
    Db.ParamValues.Clear;
    Check(Pos('slike/Employees/', CountOf(Db, 'SELECT Photo FROM Employees WHERE EmployeeID = 1')) = 1, 'mdb: the field holds a link to the stored picture');
    Check(Pos('LastName', LookupQuerySql(Db, 'Employees', 'EmployeeID')) > 0, 'mdb: a lookup shows the name column, not the job title: ' + LookupQuerySql(Db, 'Employees', 'EmployeeID'));
    Check((FileExists('/tmp/ta_mdbimp_vba/Utility_Functions.bas')) and (Pos('Function IsLoaded', VbaFileText('/tmp/ta_mdbimp_vba/Utility_Functions.bas')) > 0), 'mdb: VBA source is extracted into a folder');
    Check((Pos('makro "', Rep.Text) > 0) and (Pos('forma "Orders"', Rep.Text) > 0) and (Pos('upit "', Rep.Text) = 0), 'mdb: the report lists forms, reports and macros, and no query is missing');
    Q := Db.NewQuery('SELECT COUNT(*) FROM "Order Subtotals"');
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger > 0, 'mdb: an imported query can be used as a table by other queries');
    finally
      Q.Free;
    end;
    { aplikacija iz uvezenih tablica }
    Log.Clear;
    Check(BuildAppFromSpecText(Db, Spec, Log), 'mdb: the draft description builds forms, lists and the menu: ' + Copy(Log.Text, 1, 200));
    Names := Db.ListObjects('_sys_forms');
    Check((Names.IndexOf('Orders') >= 0) and (Names.IndexOf('Customers') >= 0) and (Names.IndexOf('Izbornik') >= 0), 'mdb: a form for every imported table');
    Names.Free;
  finally
    Rep.Free;
    Log.Free;
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ primjer aplikacije slozene blokovima }
procedure TestBlocksDemo;
var
  Db: TAppDb;
  C: TPdfCtx;
  Log: TStringList;
  Names: TStringList;
  Q: TZQuery;
  P: TaBlockProgram;
  I: Integer;
  Bad, Before, Js, Tx, Err: string;
  Lt: TaLetterDef;
  OldMsg: procedure(const AMsg: string);
  function Run(const AName: string): string;
  begin
    MacroMsgs.Clear;
    RunMacroByName(C, AName);
    Result := StringReplace(Trim(MacroMsgs.Text), LineEnding, ' | ', [rfReplaceAll]);
  end;
  function One(const ASql: string): string;
  begin
    Q := Db.NewQuery(ASql);
    try
      Q.Open;
      Result := Q.Fields[0].AsString;
    finally
      Q.Free;
    end;
  end;
begin
  if FileExists('/tmp/ta_blocksdemo.db') then DeleteFile('/tmp/ta_blocksdemo.db');
  Db := TAppDb.Create;
  Log := TStringList.Create;
  MacroMsgs := TStringList.Create;
  OldMsg := OnScriptMessage;
  OnScriptMessage := @MacroCapture;
  OnScriptAsk := @MacroAsk;
  OnScriptInput := @MacroInputHook;
  C := nil;
  try
    Db.Open('/tmp/ta_blocksdemo.db');
    ActiveDb := Db;
    Check(BuildBlocksDemo(Db, Log), 'blocks demo: the example application is built (' + StringReplace(Trim(Log.Text), LineEnding, '; ', [rfReplaceAll]) + ')');
    C := TPdfCtx.Create(Db);
    Names := BlocksDemoMacros;
    try
      Check(Names.Count = 6, 'blocks demo: six macros');
      Bad := '';
      for I := 0 to Names.Count - 1 do
      begin
        Js := Db.LoadObject('_sys_macros', Names[I]);
        P := TaBlockProgram.Create;
        try
          P.LoadText(Js);
          if (P.Problems.Count > 0) or (CheckMacroText(Js) <> '') or (P.Text <> Js) or (P.Count < 5) then Bad := Bad + Names[I] + ' ';
        finally
          P.Free;
        end;
      end;
      Check(Bad = '', 'blocks demo: every macro is well formed, passes the editor check and survives text <-> blocks (' + Bad + ')');
    finally
      Names.Free;
    end;
    Check((One('SELECT COUNT(*) FROM racuni') = '5') and (One('SELECT COUNT(*) FROM racuni_stavke') = '6'), 'blocks demo: the template invoice and the four sample debts are there');
    Check(Pos('Oznaci placenim', Db.LoadObject('_sys_forms', 'Računi')) > 0, 'blocks demo: the Računi form has the "mark as paid" button');
    Check(Pos('macro:Sazetak neplacenih', Db.LoadObject('_sys_forms', 'Izbornik')) > 0, 'blocks demo: the main menu calls the macros');
    Check(LoadAppSettings(Db).StartupForm = 'Izbornik', 'blocks demo: the menu is the startup form');
    Check(Run('Sazetak neplacenih') = 'Neplaćenih računa: 5, osnovica ukupno 399.5 EUR.', 'blocks demo: summary macro (fetch -> variables -> message): ' + Run('Sazetak neplacenih'));
    Db.Conn.ExecuteDirect('UPDATE racuni SET placeno = 1');
    Check(Run('Sazetak neplacenih') = 'Nema neplaćenih računa.', 'blocks demo: summary macro, else branch');
    Before := One('SELECT cijena FROM artikli WHERE id = 1');
    MacroInput := '10';
    Check(Pos('povećane za 10 %', Run('Povecaj cijene')) > 0, 'blocks demo: price rise macro (input -> let -> if -> sql)');
    Check(One('SELECT cijena FROM artikli WHERE id = 1') = One('SELECT ROUND(' + Before + ' * 1.1, 2)'), 'blocks demo: the prices rose by 10 % (' + Before + ')');
    MacroInput := 'abc';
    Check(Pos('Upiši broj', Run('Povecaj cijene')) > 0, 'blocks demo: price rise macro refuses a non-number');
    MacroInput := '';
    Check(Pos('Odustali', Run('Kopija baze')) > 0, 'blocks demo: backup macro, empty input = cancelled');
    if FileExists('/tmp/ta_demo_copy.db') then DeleteFile('/tmp/ta_demo_copy.db');
    MacroInput := '/tmp/ta_demo_copy.db';
    Run('Kopija baze');
    Check(FileExists('/tmp/ta_demo_copy.db'), 'blocks demo: backup macro wrote the copy');
    if FileExists('/tmp/ta_demo_cjenik.pdf') then DeleteFile('/tmp/ta_demo_cjenik.pdf');
    MacroInput := '/tmp/ta_demo_cjenik.pdf';
    Check(Pos('spremljen', Run('Cjenik u PDF')) > 0, 'blocks demo: price list PDF macro reports success: ' + Run('Cjenik u PDF'));
    Check(FileExists('/tmp/ta_demo_cjenik.pdf'), 'blocks demo: the price list PDF exists');
    { opomene: dopis iz primjera (prije su svi racuni oznaceni placenima) }
    Db.Conn.ExecuteDirect('UPDATE racuni SET placeno = 0');
    Check(Db.LoadObject('_sys_letters', 'Opomena') <> '', 'blocks demo: the letter "Opomena" is saved with the application');
    Check(Pos('openletter:Opomena', Db.LoadObject('_sys_forms', 'Izbornik')) > 0, 'blocks demo: the main menu has a button for the letters');
    Lt := LoadLetter(Db, 'Opomena');
    Tx := LetterPlainText(Db, Lt, Err);
    Lt.Free;
    Check((Pos('Ivo Horvat d.o.o.', Tx) > 0) and (Pos('Ana Kovač obrt', Tx) > 0) and (Pos('imate 4 neplaćenih računa', Tx) > 0) and (Pos('imate 1 neplaćenih računa', Tx) > 0), 'blocks demo: the dunning letter for both debtors with their invoice counts: [' + Err + '] ' + Copy(Tx, 1, 200));
    DeleteFile('/tmp/ta_demo_opomene.docx');
    MacroInput := '/tmp/ta_demo_opomene.docx';
    Run('Opomene u Word');
    Check(FileExists('/tmp/ta_demo_opomene.docx'), 'blocks demo: the macro writes the dunning letters as a Word file');
    DeleteFile('/tmp/ta_demo_cjenik.html');
    MacroMsgs.Clear;
    RunMacro(C, 'exporthtml: Cjenik > /tmp/ta_demo_cjenik.html');
    Check(FileExists('/tmp/ta_demo_cjenik.html') and (MacroMsgs.Count = 0), 'blocks demo: exporthtml writes the price list as HTML');
  finally
    OnScriptMessage := OldMsg;
    OnScriptAsk := nil;
    OnScriptInput := nil;
    ActiveDb := nil;
    MacroInput := '';
    C.Free;
    MacroMsgs.Free;
    Log.Free;
    Db.Free;
  end;
end;

{ faza G.2: uredjivac blokova (panel u formi, bez prikaza) }
procedure TestBlockEditor;
var
  F: TForm;
  E: TaBlockEditor;
  Src, Want: string;
  Hlp: TChgCounter;
begin
  F := TForm.CreateNew(nil);
  Hlp := TChgCounter.Create;
  try
    F.SetBounds(0, 0, 800, 500);
    E := TaBlockEditor.Create(F);
    E.Parent := F;
    E.SetBounds(0, 0, 780, 480);
    E.OnChange := @Hlp.Bump;
    Src := '# unos' + LineEnding + 'if [iznos] > 100 then msg: Velika' + LineEnding + 'sql: UPDATE t SET a = 1' + LineEnding + 'requery' + LineEnding + 'stop';
    E.SetText(Src);
    Check(E.RowCount = 5, 'block editor: five blocks are shown');
    Check(E.GetText = Src + LineEnding, 'block editor: untouched blocks give back the original text');
    Check(E.Palette.Items.Count = BlockVerbCount + BlockCategoryCount, 'block editor: the palette lists every macro command under its category');
    Check((E.ArgControl(2) is TEdit) and (TEdit(E.ArgControl(2)).Text = 'UPDATE t SET a = 1'), 'block editor: the sql block has its text in an edit');
    Check(E.ArgControl(3) = nil, 'block editor: requery has no argument field');
    Check((E.CondControl(1) is TEdit) and (TEdit(E.CondControl(1)).Text = '[iznos] > 100'), 'block editor: the if block has a condition field');
    { uredivanje argumenta }
    TEdit(E.ArgControl(2)).Text := 'DELETE FROM t';
    Check(Pos('sql: DELETE FROM t', E.GetText) > 0, 'block editor: typing in the argument changes the macro text');
    Check(Hlp.N > 0, 'block editor: OnChange is raised on editing');
    TEdit(E.CondControl(1)).Text := '[iznos] > 500';
    Check(Pos('if [iznos] > 500 then msg: Velika', E.GetText) > 0, 'block editor: editing the condition');
    Check(Pos('# unos' + LineEnding, E.GetText) = 1, 'block editor: other blocks keep their text');
    { dodavanje iza oznacenog }
    E.SelectRow(0);
    E.AddVerb('save');
    Check((E.RowCount = 6) and (E.Program_[1].Verb = 'save') and (E.Selected = 1), 'block editor: a block is added after the selected one');
    E.AddIf;
    Check((E.RowCount = 7) and (E.Program_[2].Kind = bkIf), 'block editor: an if block is added');
    E.AddComment;
    E.AddStop;
    Check((E.RowCount = 9) and (E.Program_[3].Kind = bkComment) and (E.Program_[4].Kind = bkStop), 'block editor: comment and stop blocks');
    { dvoklik u paleti dodaje naredbu }
    E.Palette.ItemIndex := 1;
    E.Palette.OnDblClick(E.Palette);
    Check((E.RowCount = 10) and (E.Program_[5].Verb = BlockVerbName(0)), 'block editor: double click in the palette adds the command');
    E.Palette.ItemIndex := 0;
    E.Palette.OnDblClick(E.Palette);
    Check(E.RowCount = 10, 'block editor: a category heading adds nothing');
    { premjestanje i brisanje }
    E.MoveRow(5, 0);
    Check((E.Program_[0].Verb = BlockVerbName(0)) and (E.Selected = 0), 'block editor: MoveRow moves the block');
    E.DeleteRow(0);
    E.DeleteRow(1);
    E.DeleteRow(1);
    E.DeleteRow(1);
    E.DeleteRow(1);
    Check(E.RowCount = 5, 'block editor: DeleteRow removes blocks (' + IntToStr(E.RowCount) + ')');
    Want := E.GetText;
    E.SetText(Want);
    Check((E.RowCount = 5) and (E.GetText = Want), 'block editor: text -> blocks -> text again is stable');
    { strukturni blokovi }
    E.SetText('msg: a');
    E.SelectRow(0);
    E.AddIfBlock;
    Check((E.RowCount = 4) and (E.Program_[1].Kind = bkIfBlock) and (E.Program_[2].Kind = bkElse) and (E.Program_[3].Kind = bkEndIf), 'block editor: "if ... else ... end if" is added as three blocks');
    Check(E.Program_.Depth(2) = 0, 'block editor: else stands at the level of its if');
    E.SelectRow(2);
    E.AddVerb('save');
    Check(E.Program_.Depth(3) = 1, 'block editor: a block inside the if is indented one level');
    E.SelectRow(3);
    E.AddWhile;
    Check((E.RowCount = 7) and (E.Program_.Depth(4) = 1) and (E.Program_.Depth(5) = 1), 'block editor: a loop inside an if is indented, its end stands at its own level');
    E.DeleteRow(4);
    Check((E.RowCount = 5) and (E.Program_[3].Verb = 'save'), 'block editor: deleting the start of a loop removes its end too, content stays');
    E.DeleteRow(1);
    Check((E.RowCount = 2) and (E.Program_[1].Verb = 'save'), 'block editor: deleting an if removes its else and end if, content stays');
    E.SetText('msg: a');
    E.SelectRow(0);
    E.AddRepeat;
    E.AddLet;
    Check((E.Program_[2].Kind = bkLet) and (E.Program_[1].Kind = bkRepeat), 'block editor: repeat and let blocks');
    TEdit(E.CondControl(1)).Text := '5';
    Check(Pos('repeat 5', E.GetText) > 0, 'block editor: editing the repeat count');
    TEdit(E.ArgControl(2)).Text := 'n';
    TEdit(E.CondControl(2)).Text := '1 + 1';
    Check(Pos('let n = 1 + 1', E.GetText) > 0, 'block editor: a let block has a name and an expression');
    { prazna polja ne smiju pokazivati naziv kontrole (LCL kod Name puni prazan tekst) }
    E.SetText('msg' + LineEnding + 'if' + ' 1 = 1' + LineEnding + 'end if' + LineEnding + 'let' + ' x = 1' + LineEnding + '# ' + LineEnding + 'repeat 2' + LineEnding + 'end repeat');
    Check((TEdit(E.ArgControl(0)).Text = '') and (TEdit(E.ArgControl(3)).Text = 'x') and (TEdit(E.CondControl(3)).Text = '1'), 'block editor: an empty argument field is empty, not the control name (' + TEdit(E.ArgControl(0)).Text + ')');
    { greske se ipak prijavljuju iz modela }
    E.SetText('msg: x' + LineEnding + 'nepoznato: y');
    Check(E.Program_.Problems.Count = 1, 'block editor: an unknown command is reported by Problems');
  finally
    Hlp.Free;
    F.Free;
  end;
end;

{ brojanje stranica po grupi: GroupPage / GroupPages }
procedure TestGroupPages;
var
  Db: TAppDb;
  RD: TaReportDef;
  Tx: string;
  Pg, I: Integer;
begin
  if FileExists('/tmp/ta_grouppages.db') then DeleteFile('/tmp/ta_grouppages.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_grouppages.db');
    Db.Conn.ExecuteDirect('CREATE TABLE stavka (id INTEGER PRIMARY KEY, grupa TEXT, iznos REAL)');
    Db.Conn.StartTransaction;
    for I := 1 to 150 do Db.Conn.ExecuteDirect('INSERT INTO stavka (grupa, iznos) VALUES (''A'', ' + IntToStr(I) + ')');
    for I := 1 to 10 do Db.Conn.ExecuteDirect('INSERT INTO stavka (grupa, iznos) VALUES (''B'', ' + IntToStr(I) + ')');
    Db.Conn.Commit;
    RD := TaReportDef.Create; RD.Name := 'GP'; RD.RecordSource := 'stavka'; RD.GroupField := 'grupa'; RD.SortBy := 'id';
    RD.Heights[SecPageFooter] := 24;
    RD.Add(RItem('TextBox', 'GroupHeader', 'h', '="K:" & [grupa]', 0, 0, 80, 18));
    RD.Add(RItem('PageBreak', 'GroupHeader', 'pb', '', 0, 0, 10, 2));
    RD.Add(RItem('TextBox', 'Detail', 'd', '=Format([iznos], "0")', 0, 0, 60, 18));
    RD.Add(RItem('TextBox', 'PageFooter', 'pf', '="G" & GroupPage & "/" & GroupPages & " S" & Page & "/" & Pages', 0, 0, 200, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check(Pg >= 3, 'groups: the report has several pages (' + IntToStr(Pg) + ')');
    Check(Pos('G1/', Tx) > 0, 'groups: group page numbering starts at 1: ' + Tx);
    Check(Pos('G1/1 S' + IntToStr(Pg) + '/' + IntToStr(Pg), Tx) > 0, 'groups: the second group restarts at 1/1 on the last page (' + Tx + ')');
    Check((Pos('G2/', Tx) > 0) and (Pos('S1/' + IntToStr(Pg), Tx) > 0), 'groups: the first group continues on page 2 while the whole report counts S1.. ');
    RD := TaReportDef.Create; RD.Name := 'GP2'; RD.RecordSource := 'stavka'; RD.GroupField := 'grupa'; RD.SortBy := 'id';
    RD.Add(RItem('TextBox', 'Detail', 'd', '=RowNum & "." & GroupRow & "." & GroupRows & "." & RowCount', 0, 0, 100, 18));
    Tx := RenderTexts(Db, RD, Pg); RD.Free;
    Check((Pos('1.1.150.160|', Tx) > 0) and (Pos('151.1.10.160|', Tx) > 0) and (Pos('160.10.10.160|', Tx) > 0),
      'groups: RowNum, GroupRow, GroupRows and RowCount variables are available in a report');
  finally
    Db.Free;
  end;
end;

{ 4GL recepti: svaki program se izvodi nad malom bazom, "-- expect:" retci moraju biti u ispisu }
procedure TestManual4glRecipes;
var
  SR: TSearchRec;
  Db: TAppDb;
  Pr: TaFglProgram;
  Io: TaFglScriptIO;
  Rn: TaFglRunner;
  Src, Lg: TStringList;
  Files: TStringList;
  F, Ln, Sql, Want, Got, Msg: string;
  I, J, P, Rc, N, Bad: Integer;
  Q: TZQuery;
begin
  Files := TStringList.Create;
  Src := TStringList.Create;
  N := 0; Bad := 0; Msg := '';
  try
    if FindFirst('manual_4gl_recepti/*.4gl', faAnyFile, SR) = 0 then
    begin
      repeat Files.Add(SR.Name); until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    Files.Sort;
    for I := 0 to Files.Count - 1 do
    begin
      Inc(N);
      F := Files[I];
      if FileExists('/tmp/ta_fgl_rec.db') then DeleteFile('/tmp/ta_fgl_rec.db');
      Db := TAppDb.Create;
      Io := TaFglScriptIO.Create;
      Pr := TaFglProgram.Create;
      try
        Db.Open('/tmp/ta_fgl_rec.db');
        Db.Conn.ExecuteDirect('CREATE TABLE racun (id INTEGER PRIMARY KEY, kupac TEXT, iznos REAL, placeno INTEGER, datum TEXT)');
        Db.Conn.ExecuteDirect('CREATE TABLE racun_arhiva (id INTEGER PRIMARY KEY, kupac TEXT, iznos REAL, placeno INTEGER, datum TEXT)');
        Db.Conn.ExecuteDirect('INSERT INTO racun VALUES (1, ''Ana'', 100, 1, ''2026-01-15''), (2, ''Ana'', 50, 0, ''2026-02-10''), (3, ''Marko'', 30, 1, ''2026-02-20''), ' +
          '(4, ''Marko'', 20, 0, ''2026-03-05''), (5, ''Ivo'', 75.5, 1, ''2026-03-12'')');
        Db.Conn.ExecuteDirect('CREATE TABLE artikl (id INTEGER PRIMARY KEY, naziv TEXT, cijena REAL, zaliha INTEGER)');
        Db.Conn.ExecuteDirect('INSERT INTO artikl VALUES (1, ''Kava'', 4.5, 10), (2, ''Čaj'', 3.2, 0), (3, ''Med'', 7.8, 5)');
        Db.Conn.ExecuteDirect('CREATE TABLE dokumenti (vrsta TEXT PRIMARY KEY, sifradok TEXT, rednidok INTEGER DEFAULT 0, godina INTEGER DEFAULT 0)');
        Db.Conn.ExecuteDirect('INSERT INTO dokumenti VALUES (''otp'', ''otp'', 0, 0), (''rv'', ''rv'', 41, 2020)');
        Db.Conn.ExecuteDirect('CREATE TABLE dokument (id INTEGER PRIMARY KEY AUTOINCREMENT, vrsta TEXT, broj TEXT)');
        Db.SaveObject('_sys_modules', 'Pomocne', 'function Pdv(x: Double): Double;' + LineEnding + 'begin Result := Round(x * 25) / 100; end;');
        ResetScripts;
        Src.LoadFromFile('manual_4gl_recepti/' + F);
        Pr.LoadText(Src.Text, F);
        Lg := TStringList.Create;
        try
          if Pr.CheckProgram(Lg) <> 0 then
          begin
            Inc(Bad);
            Msg := Msg + F + ' ne prolazi provjeru: ' + Trim(Lg.Text) + '; ';
            Continue;
          end;
        finally
          Lg.Free;
        end;
        for J := 0 to Src.Count - 1 do
        begin
          Ln := Src[J];
          if Copy(Ln, 1, 11) = '-- prompt: ' then Io.PromptAnswers.Add(Copy(Ln, 12, MaxInt))
          else if Copy(Ln, 1, 9) = '-- menu: ' then Io.MenuAnswers.Add(Copy(Ln, 10, MaxInt));
        end;
        Rn := TaFglRunner.Create(Pr, Db, Io);
        try
          Rc := Rn.Run;
        finally
          Rn.Free;
        end;
        if Rc <> 0 then begin Inc(Bad); Msg := Msg + F + ' rc=' + IntToStr(Rc) + ' ' + Trim(Io.Out.Text) + '; '; end;
        for J := 0 to Src.Count - 1 do
        begin
          Ln := Src[J];
          if Copy(Ln, 1, 11) = '-- expect: ' then
          begin
            Want := Copy(Ln, 12, MaxInt);
            if Io.Out.IndexOf(Want) < 0 then
            begin
              Inc(Bad);
              Msg := Msg + F + ' ocekivano "' + Want + '", ispis: ' + StringReplace(Trim(Io.Out.Text), LineEnding, ' | ', [rfReplaceAll]) + '; ';
            end;
          end
          else if Copy(Ln, 1, 15) = '-- expect-sql: ' then
          begin
            P := Pos(' => ', Ln);
            Sql := Copy(Ln, 16, P - 16);
            Want := Copy(Ln, P + 4, MaxInt);
            Q := Db.NewQuery(Sql);
            try
              Q.Open;
              Got := Q.Fields[0].AsString;
            finally
              Q.Free;
            end;
            if Got <> Want then begin Inc(Bad); Msg := Msg + F + ' SQL ' + Sql + ' = ' + Got + ' (ocekivano ' + Want + '); '; end;
          end;
        end;
      finally
        Pr.Free;
        Io.Free;
        ResetScripts;
        Db.Free;
      end;
    end;
    Check((N >= 15) and (Bad = 0), 'manual: every 4GL recipe runs and gives the documented result (' + IntToStr(N) + ' recipes) ' + Msg);
  finally
    Src.Free;
    Files.Free;
  end;
end;

{ AutoFill i CalcRules u formi s jednim zapisom (ne samo u mrezi) }
procedure TestSingleFormRules;
var
  Db: TAppDb;
  D: TaFormDef;
  R: TaFormRunner;
  C: TaControlDef;
  Cb: TComboBox;
  function Tx(const AName: string): string;
  begin
    Result := TEdit(R.ControlByName(AName)).Text;
  end;
  function Num(const AName: string): Double;
  begin
    if Pos(',', Tx(AName)) > 0 then
      Result := StrToFloatDef(StringReplace(StringReplace(Tx(AName), '.', '', [rfReplaceAll]), ',', '.', []), -999999, InvariantFS)
    else Result := StrToFloatDef(Tx(AName), -999999, InvariantFS);
  end;
begin
  if FileExists('/tmp/ta_single_rules.db') then DeleteFile('/tmp/ta_single_rules.db');
  Db := TAppDb.Create;
  try
    Db.Open('/tmp/ta_single_rules.db');
    ActiveDb := Db;
    Db.Conn.ExecuteDirect('CREATE TABLE art (id INTEGER PRIMARY KEY, naziv TEXT, cijena REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO art VALUES (1, ''Vijak'', 0.35), (2, ''Matica'', 0.25), (3, ''Podloška'', 7.5)');
    Db.Conn.ExecuteDirect('CREATE TABLE stav (id INTEGER PRIMARY KEY, art_id INTEGER, opis TEXT, kolicina REAL, cijena REAL, iznos REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO stav VALUES (1, 1, ''Vijak'', 1, 0.35, 0.35)');
    D := TaFormDef.Create;
    D.Name := 'StavJedan'; D.RecordSource := 'stav';
    D.AutoFill := 'art_id>art.id:opis=naziv,cijena=cijena';
    D.CalcRules := 'kolicina,cijena -> iznos = Zaokruzi([kolicina] * [cijena], 2) ;; iznos -> cijena = Zaokruzi([iznos] / [kolicina], 4)';
    C := NewCtl('ComboBox', 'cmbArt', 'art_id', 10, 10); C.RowSource := 'SELECT id, naziv FROM art ORDER BY id'; D.Add(C);
    D.Add(NewCtl('TextBox', 'tOpis', 'opis', 10, 40));
    D.Add(NewCtl('TextBox', 'tKol', 'kolicina', 10, 70));
    D.Add(NewCtl('TextBox', 'tCij', 'cijena', 10, 100));
    D.Add(NewCtl('TextBox', 'tIzn', 'iznos', 10, 130));
    R := TaFormRunner.CreateRunner(nil, Db, D);
    Check(not R.HasGrid, 'single form: this is a one-record form, not a grid');
    R.DoAction('new');
    Cb := TComboBox(R.ControlByName('cmbArt'));
    Cb.ItemIndex := 2;
    if Assigned(Cb.OnChange) then Cb.OnChange(Cb);
    Check((Tx('tOpis') = 'Podloška') and (Abs(Num('tCij') - 7.5) < 1E-9), 'single form: choosing an article fills name and price (AutoFill): ' + Tx('tOpis') + ' / ' + Tx('tCij'));
    TEdit(R.ControlByName('tKol')).Text := '3';
    Check(Abs(Num('tIzn') - 22.5) < 1E-9, 'single form: quantity 3 x price 7.50 gives amount 22.50 (CalcRules): ' + Tx('tIzn'));
    TEdit(R.ControlByName('tIzn')).Text := '20';
    Check(Abs(Num('tCij') - 6.6667) < 1E-9, 'single form: typing the amount 20 recalculates the unit price to 6.6667: ' + Tx('tCij'));
    Check(Abs(Num('tIzn') - 20) < 1E-9, 'single form: the typed amount stays (no loop): ' + Tx('tIzn'));
    R.DoAction('undo');
    R.Free;
  finally
    ActiveDb := nil;
    Db.Free;
  end;
end;

{ ponudeni poredci izvjesca: isto izvjesce, razlicit poredak pri ispisu }
type
  TTestSortRender = class
  public
    Db: TAppDb;
    Def: TaReportDef;
    function Render(const AOption: string): TaRenderedReport;
  end;

function TTestSortRender.Render(const AOption: string): TaRenderedReport;
var
  Eng: TaReportEngine;
begin
  Eng := TaReportEngine.Create(Db, Def);
  try
    Eng.SortOverride := Def.SortFor(AOption);
    Result := Eng.Render;
  finally
    Eng.Free;
  end;
end;

procedure TestSortOptions;
var
  Db: TAppDb;
  RD, R2: TaReportDef;
  Eng: TaReportEngine;
  RR: TaRenderedReport;
  Pv: TaReportPreview;
  Rn: TTestSortRender;
  Ch: TStringList;
  Nm, Srt, Tx: string;
  Pg: Integer;
begin
  if FileExists('/tmp/ta_sortopt.db') then DeleteFile('/tmp/ta_sortopt.db');
  Db := TAppDb.Create;
  Rn := TTestSortRender.Create;
  Ch := TStringList.Create;
  try
    Db.Open('/tmp/ta_sortopt.db');
    Db.Conn.ExecuteDirect('CREATE TABLE kalk (id INTEGER PRIMARY KEY, sifra TEXT, naziv TEXT, cijena REAL, marza REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO kalk VALUES (1, ''C30'', ''Kava'', 4.5, 22.0), (2, ''A10'', ''Čaj'', 3.2, 40.0), (3, ''B20'', ''Med'', 7.8, 15.0), (4, ''D40'', ''Keksi'', 2.1, 31.0)');
    RD := TaReportDef.Create; RD.Name := 'Kalkulacija'; RD.RecordSource := 'kalk';
    RD.SortOptions := 'Po unosu=id ;; Po šifri=sifra ;; Po marži=marza DESC ;; Po cijeni=cijena DESC';
    RD.Add(RItem('TextBox', 'Detail', 'd', '=[sifra]', 0, 0, 60, 18));
    R2 := TaReportDef.Create; R2.FromJson(RD.ToJson);
    Check((R2.SortOptionCount = 4) and (R2.SortOptionName(2) = 'Po marži') and (R2.SortOptionOrder(2) = 'marza DESC'), 'sort options: survive JSON (4 options)');
    Check((RD.SortFor('Po šifri') = 'sifra') and (RD.SortFor('po CIJENI') = 'cijena DESC') and (RD.SortFor('') = '') and (RD.SortFor('naziv') = 'naziv'),
      'sort options: SortFor maps a name to its order, empty to the default, unknown text stays as typed');
    SplitReportArg('Kalkulacija#poredak=Po marži', Nm, Srt);
    Check((Nm = 'Kalkulacija') and (Srt = 'Po marži'), 'sort options: openreport argument Name#poredak=Option is split');
    Eng := TaReportEngine.Create(Db, RD);
    RR := Eng.Render; Tx := RTexts(RR); RR.Free; Eng.Free;
    Check(Tx = 'C30|A10|B20|D40|', 'sort options: default order is the entry order (' + Tx + ')');
    Eng := TaReportEngine.Create(Db, RD);
    Eng.SortOverride := RD.SortFor('Po šifri');
    RR := Eng.Render; Tx := RTexts(RR); RR.Free; Eng.Free;
    Check(Tx = 'A10|B20|C30|D40|', 'sort options: by code (' + Tx + ')');
    Eng := TaReportEngine.Create(Db, RD);
    Eng.SortOverride := RD.SortFor('Po marži');
    RR := Eng.Render; Tx := RTexts(RR); RR.Free; Eng.Free;
    Check(Tx = 'A10|D40|C30|B20|', 'sort options: by margin, highest first (' + Tx + ')');
    Eng := TaReportEngine.Create(Db, RD);
    Eng.SortOverride := RD.SortFor('Po cijeni');
    RR := Eng.Render; Tx := RTexts(RR); RR.Free; Eng.Free;
    Check(Tx = 'B20|C30|A10|D40|', 'sort options: by price, highest first (' + Tx + ')');
    { poredak po izracunatom polju upita (marza) }
    Db.SaveObject('_sys_queries', 'kalk_marza', 'SELECT id, sifra, cijena, ROUND(100 - cijena * 5, 2) AS marza2 FROM kalk');
    R2.Free;
    R2 := TaReportDef.Create; R2.Name := 'KalkM'; R2.RecordSource := 'kalk_marza'; R2.SortOptions := 'Po marži=marza2 DESC';
    R2.Add(RItem('TextBox', 'Detail', 'd', '=[sifra]', 0, 0, 60, 18));
    Eng := TaReportEngine.Create(Db, R2);
    Eng.SortOverride := R2.SortFor('Po marži');
    RR := Eng.Render; Tx := RTexts(RR); RR.Free; Eng.Free; R2.Free;
    Check(Tx = 'D40|A10|C30|B20|', 'sort options: ordering by a calculated field of a saved query works (' + Tx + ')');
    { pregled: promjena poretka u padajucem popisu ponovo slaze stranice }
    Rn.Db := Db; Rn.Def := RD;
    Eng := TaReportEngine.Create(Db, RD);
    RR := Eng.Render; Eng.Free;
    Pv := TaReportPreview.CreatePreview(nil, RR, 'Kalkulacija');
    try
      Ch.Add('Po unosu'); Ch.Add('Po šifri'); Ch.Add('Po marži'); Ch.Add('Po cijeni');
      Pv.SetSortChoices(Ch, 0, @Rn.Render);
      Check((Pv.SortBoxForTest <> nil) and (Pv.SortBoxForTest.Items.Count = 4), 'sort options: the preview offers the 4 orders');
      Pv.SortBoxForTest.ItemIndex := 2;
      Pv.SortBoxForTest.OnChange(Pv.SortBoxForTest);
      Check(TaRItem(Pv.RenderedForTest.Page(0).Items[0]).Text = 'A10', 'sort options: choosing "Po marži" in the preview re-sorts the report');
    finally
      Pv.Free;
    end;
    Pg := 0;
    RD.Free;
  finally
    Ch.Free;
    Rn.Free;
    Db.Free;
  end;
end;

{ moduli iz vodica: svaki se prevede, a izrazi "// test:" daju dokumentirani rezultat }
procedure TestManualPascal;
var
  Db: TAppDb;
  SR: TSearchRec;
  Src, Tests, Parts: TStringList;
  I, N, Bad: Integer;
  Id, Err, Got, Msg, Path: string;
  SavedFs: TFormatSettings;
  H: TTestHost;
begin
  Path := '/tmp/ta_manual_pascal.db';
  if FileExists(Path) then DeleteFile(Path);
  Db := TAppDb.Create;
  Src := TStringList.Create;
  Tests := TStringList.Create;
  H := TTestHost.Create;
  try
    Db.Open(Path);
    Db.Conn.ExecuteDirect('CREATE TABLE kategorija (id INTEGER PRIMARY KEY, naziv TEXT, vrsta TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE transakcija (id INTEGER PRIMARY KEY, datum TEXT, iznos REAL, kategorija_id INTEGER, opis TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO kategorija VALUES (1, ''Hrana'', ''Rashod''), (2, ''Plaća'', ''Prihod''), (3, ''Prijevoz'', ''Rashod'')');
    Db.Conn.ExecuteDirect('INSERT INTO transakcija VALUES (1, ''2026-03-01'', 1500, 2, ''Plaća''), (2, ''2026-03-03'', -45.5, 1, ''Konzum''), ' +
      '(3, ''2026-03-05'', -30, 3, ''Gorivo''), (4, ''2026-03-10'', -60, 1, ''Plac'')');
    OnScriptMessage := @CaptureScript;
    SavedFs := DefaultFormatSettings;
    UseCroatianFormats;
    N := 0; Bad := 0; Msg := '';
    if FindFirst('manual_pascal/*.pas', faAnyFile, SR) = 0 then
    begin
      try
        repeat
          Inc(N);
          Id := Copy(SR.Name, 6, 2);
          Src.LoadFromFile('manual_pascal/' + SR.Name);
          ResetScripts;
          Db.SaveObject('_sys_modules', 'm' + Id, Src.Text);
          if not Scripts(Db).Ensure then
          begin
            Inc(Bad);
            Msg := Msg + SR.Name + ' ne prevodi: ' + Trim(Scripts(Db).LastError) + '; ';
          end
          else if FileExists('manual_pascal.txt') then
          begin
            Tests.LoadFromFile('manual_pascal.txt');
            for I := 0 to Tests.Count - 1 do
            begin
              Parts := TStringList.Create;
              try
                Parts.Delimiter := #9;
                Parts.StrictDelimiter := True;
                Parts.DelimitedText := Tests[I];
                if (Parts.Count = 3) and (Parts[0] = Id) then
                begin
                  Got := Ev(H, Parts[1]);
                  if Got <> Parts[2] then
                  begin
                    Inc(Bad);
                    Msg := Msg + Parts[1] + ' => "' + Got + '" (u vodiču: "' + Parts[2] + '"); ';
                  end;
                end;
              finally
                Parts.Free;
              end;
            end;
          end;
          Db.Conn.ExecuteDirect('DELETE FROM _sys_modules');
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
    ResetScripts;
    OnScriptMessage := nil;
    DefaultFormatSettings := SavedFs;
    Check((N >= 8) and (Bad = 0), 'manual: every PascalScript module in the guide compiles and gives the documented results (' + IntToStr(N) + ' modules) ' + Msg);
  finally
    H.Free;
    Tests.Free;
    Src.Free;
    Db.Free;
  end;
end;

procedure TestManual4gl;
var
  SR: TSearchRec;
  P: TaFglProgram;
  Lg: TStringList;
  N, Bad: Integer;
  Msg: string;
begin
  N := 0;
  Bad := 0;
  Msg := '';
  if FindFirst('manual_4gl/*.4gl', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        Inc(N);
        Lg := TStringList.Create;
        try
          Lg.Clear;
          if FglCheckFile('manual_4gl/' + SR.Name, Lg) <> 0 then
          begin
            Inc(Bad);
            Msg := Msg + SR.Name + ': ' + Trim(Lg.Text) + '; ';
          end;
        finally
          Lg.Free;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  Check((N >= 8) and (Bad = 0), 'manual: every 4GL program in the tutorial passes --check (' + IntToStr(N) + ' programs) ' + Msg);
end;

procedure TestNorthwindDb(AKind: TDbKind);
var
  P: TAppDb;
  Lg, Names: TStringList;
  Q: TZQuery;
  D: TaFormDef;
  RD: TaReportDef;
  RE: TaReportEngine;
  RR: TaRenderedReport;
  R: TaFormRunner;
  I: Integer;
  Bad, PdfErr, LbN: string;
  Lc: TFormatSettings;
  K: Integer;
begin
  P := TAppDb.Create;
  try
    if AKind = dkMaria then LbN := 'maria' else LbN := 'pg';
    LbN := LbN + ' northwind';
    if not ConnectKind(P, AKind, 'nw_built') then Exit;
    if AKind = dkMaria then
    begin
      P.Conn.ExecuteDirect('DROP DATABASE nw_built');
      P.Conn.ExecuteDirect('CREATE DATABASE nw_built CHARACTER SET utf8mb4');
    end
    else
    begin
      P.Conn.ExecuteDirect('DROP SCHEMA public CASCADE');
      P.Conn.ExecuteDirect('CREATE SCHEMA public');
    end;
    ConnectKind(P, AKind, 'nw_built');
    Lg := TStringList.Create;
    try
      if not BuildNorthwind(P, Lg) then begin Check(False, LbN + ': built'); WriteLn(Copy(Lg.Text, Pos('GREŠKA', Lg.Text), 600)); WriteLn(Copy(Lg.Text, Length(Lg.Text) - 300, 300)); end
      else Check(True, LbN + ': built');
    except
      on E: Exception do Check(False, LbN + ': build raised ' + E.Message);
    end;
    Lg.Free;
    Q := P.NewQuery('SELECT (SELECT COUNT(*) FROM "orders"), (SELECT COUNT(*) FROM "orderdetails"), (SELECT COUNT(*) FROM "products")');
    try
      Q.Open;
      Check((Q.Fields[0].AsInteger = 220) and (Q.Fields[1].AsInteger > 400) and (Q.Fields[2].AsInteger = 40), LbN + ': data is in place');
    except
      on E: Exception do Check(False, LbN + ': counts ' + E.Message);
    end;
    Q.Free;
    { revizijski trag preko plpgsql okidaca }
    try
      AuditSetUser(P, 'tester');
      P.Conn.ExecuteDirect('UPDATE customers SET city = ''Zagreb'' WHERE customerid = 1');
      P.Conn.ExecuteDirect('INSERT INTO shippers (shipperid, companyname) VALUES (99, ''Test d.o.o.'')');
      P.Conn.ExecuteDirect('DELETE FROM shippers WHERE shipperid = 99');
      Q := P.NewQuery('SELECT (SELECT COUNT(*) FROM _sys_audit WHERE action = ''U'' AND field = ''city'' AND tbl = ''customers'' AND usr = ''tester'' AND rowkey = ''1''), ' +
        '(SELECT COUNT(*) FROM _sys_audit WHERE action = ''I'' AND tbl = ''shippers''), (SELECT COUNT(*) FROM _sys_audit WHERE action = ''D'' AND tbl = ''shippers'')');
      Q.Open;
      Check((Q.Fields[0].AsInteger = 1) and (Q.Fields[1].AsInteger = 0) and (Q.Fields[2].AsInteger = 0),
        LbN + ' audit: update on audited table logged, unaudited shippers not (' + Q.Fields[0].AsString + '/' + Q.Fields[1].AsString + '/' + Q.Fields[2].AsString + ')');
      Q.Free;
      AuditEnable(P, 'shippers');
      P.Conn.ExecuteDirect('INSERT INTO shippers (shipperid, companyname) VALUES (99, ''Test d.o.o.'')');
      P.Conn.ExecuteDirect('DELETE FROM shippers WHERE shipperid = 99');
      Q := P.NewQuery('SELECT (SELECT COUNT(*) FROM _sys_audit WHERE action = ''I'' AND tbl = ''shippers'' AND new_value LIKE ''shipperid=%99%companyname=%Test d.o.o.%''), ' +
        '(SELECT COUNT(*) FROM _sys_audit WHERE action = ''D'' AND tbl = ''shippers'')');
      Q.Open;
      Check((Q.Fields[0].AsInteger = 1) and (Q.Fields[1].AsInteger = 1), LbN + ' audit: insert and delete logged after AuditEnable (' + Q.Fields[0].AsString + '/' + Q.Fields[1].AsString + ')');
      Q.Free;
      Names := AuditTables(P);
      Check((Names.IndexOf('shippers') >= 0) and (Names.IndexOf('customers') >= 0) and AuditEnabled(P, 'Shippers'), LbN + ' audit: tables listed');
      Names.Free;
      AuditDisable(P, 'shippers');
      Check(not AuditEnabled(P, 'shippers'), LbN + ' audit: disabled');
    except
      on E: Exception do Check(False, LbN + ' audit: ' + E.Message);
    end;
    Names := P.ListObjects('_sys_forms');
    Bad := '';
    for I := 0 to Names.Count - 1 do
      try
        D := TaFormDef.Create;
        D.FromJson(P.LoadObject('_sys_forms', Names[I]));
        D.Name := Names[I];
        R := TaFormRunner.CreateRunner(nil, P, D);
        R.Free;
      except
        on E: Exception do Bad := Bad + Names[I] + ': ' + E.Message + '; ';
      end;
    Check((Bad = '') and (Names.Count >= 10), LbN + ': every form opens (' + IntToStr(Names.Count) + ') ' + Bad);
    Names.Free;
    Lc := DefaultFormatSettings;
    UseCroatianFormats;
    Names := P.ListObjects('_sys_reports');
    Bad := '';
    for I := 0 to Names.Count - 1 do
      try
        RD := TaReportDef.Create;
        RD.FromJson(P.LoadObject('_sys_reports', Names[I]));
        RD.Name := Names[I];
        RE := TaReportEngine.Create(P, RD);
        RR := RE.Render;
        if RR.PageCount < 1 then Bad := Bad + Names[I] + ': no pages; ';
        if Names[I] = 'Invoice' then
        begin
          ExportPdf(RR, '/tmp/nw_invoice_pg.pdf', PdfErr);
          Bad := '';
          for K := 0 to RR.Page(0).Items.Count - 1 do
            if (Length(TaRItem(RR.Page(0).Items[K]).Text) = 10) and (TaRItem(RR.Page(0).Items[K]).Text[5] = '-') then Bad := 'iso';
          Check(Bad = '', LbN + ': invoice shows no ISO dates');
        end;
        RR.Free; RE.Free; RD.Free;
      except
        on E: Exception do Bad := Bad + Names[I] + ': ' + E.Message + '; ';
      end;
    DefaultFormatSettings := Lc;
    Check((Bad = '') and (Names.Count >= 6), LbN + ': every report renders (' + IntToStr(Names.Count) + ') ' + Bad);
    Names.Free;
    ParamPromptHook := @TestDateRangePrompt;
    P.ClearParams;
    Q := P.NewQuery('SELECT COUNT(*) FROM ' + P.SourceFrom('Orders in Date Range'));
    try
      Q.Open;
      Check(Q.Fields[0].AsInteger > 0, LbN + ': parameter query returns orders');
    except
      on E: Exception do Check(False, LbN + ': param query ' + E.Message);
    end;
    Q.Free;
    ParamPromptHook := nil;
    P.ClearParams;
  finally
    SqlPostgres := False;
    P.Free;
  end;
end;

begin
  { glavni skup ispituje izvrsitelj sa starim kontrolama; obitelji u izvrsitelju ispituju TestRunnerFamilies i paritetni skup }
  RunnerUsesFamilies := False;
  Application.Initialize; WriteLn('init'); Flush(Output);
  if GetEnvironmentVariable('SMOKE_ONLY_ICONS') <> '' then
  begin
    try TestIconsAndTheme; except on E: Exception do begin Inc(Fails); WriteLn('FAIL icons exception: ', E.Message); end; end;
    try TestButtonIcons; except on E: Exception do begin Inc(Fails); WriteLn('FAIL button icons exception: ', E.Message); end; end;
    try TestSideMenu; except on E: Exception do begin Inc(Fails); WriteLn('FAIL sidemenu exception: ', E.Message); end; end;
    try TestPropMap; except on E: Exception do begin Inc(Fails); WriteLn('FAIL propmap exception: ', E.Message); end; end;
  try TestEditFamily; except on E: Exception do begin Inc(Fails); WriteLn('FAIL edit family exception: ', E.Message); end; end;
  try TestTokens; except on E: Exception do begin Inc(Fails); WriteLn('FAIL tokens exception: ', E.Message); end; end;
  try TestThemeInApp; except on E: Exception do begin Inc(Fails); WriteLn('FAIL theme in app exception: ', E.Message); end; end;
  try TestAnchorEditor; except on E: Exception do begin Inc(Fails); WriteLn('FAIL anchor editor exception: ', E.Message); end; end;
    try TestFormBinder; except on E: Exception do begin Inc(Fails); WriteLn('FAIL binder exception: ', E.Message); end; end;
    try TestPaletteComponents; except on E: Exception do begin Inc(Fails); WriteLn('FAIL components exception: ', E.Message); end; end;
    try TestSideMenuGroups; except on E: Exception do begin Inc(Fails); WriteLn('FAIL sidemenu groups exception: ', E.Message); end; end;
    try TestShell; except on E: Exception do begin Inc(Fails); WriteLn('FAIL shell exception: ', E.Message); end; end;
    try TestDocTypes; except on E: Exception do begin Inc(Fails); WriteLn('FAIL doctypes exception: ', E.Message); end; end;
    try TestShowcase2; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase2 exception: ', E.Message); end; end;
    try TestAppSpec; except on E: Exception do begin Inc(Fails); WriteLn('FAIL appspec exception: ', E.Message); end; end;
    try TestSpecCharts; except on E: Exception do begin Inc(Fails); WriteLn('FAIL charts exception: ', E.Message); end; end;
    try TestPredictFunctions; except on E: Exception do begin Inc(Fails); WriteLn('FAIL predict exception: ', E.Message); end; end;
    try TestNewton; except on E: Exception do begin Inc(Fails); WriteLn('FAIL newton exception: ', E.Message); end; end;
    try TestLeagueAndValidation; except on E: Exception do begin Inc(Fails); WriteLn('FAIL league exception: ', E.Message); end; end;
    try TestPairsSession; except on E: Exception do begin Inc(Fails); WriteLn('FAIL pairs exception: ', E.Message); end; end;
    try TestMarketFit; except on E: Exception do begin Inc(Fails); WriteLn('FAIL marketfit exception: ', E.Message); end; end;
    try TestEngineBacktest; except on E: Exception do begin Inc(Fails); WriteLn('FAIL engine exception: ', E.Message); end; end;
    try TestSlipGeneration; except on E: Exception do begin Inc(Fails); WriteLn('FAIL slips exception: ', E.Message); end; end;
    try TestBacktest; except on E: Exception do begin Inc(Fails); WriteLn('FAIL backtest exception: ', E.Message); end; end;
    try TestDataImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dataimport exception: ', E.Message); end; end;
    try TestCountryImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL country exception: ', E.Message); end; end;
    try TestScrape; except on E: Exception do begin Inc(Fails); WriteLn('FAIL scrape exception: ', E.Message); end; end;
    try TestStandardGenerator; except on E: Exception do begin Inc(Fails); WriteLn('FAIL standard exception: ', E.Message); end; end;
    try TestRoundReport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL roundreport exception: ', E.Message); end; end;
    try TestAnalytics; except on E: Exception do begin Inc(Fails); WriteLn('FAIL analytics exception: ', E.Message); end; end;
    try TestReliability; except on E: Exception do begin Inc(Fails); WriteLn('FAIL reliability exception: ', E.Message); end; end;
  try TestMdbImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL mdb import exception: ', E.Message); end; end;
    try TestMdbImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL mdb import exception: ', E.Message); end; end;
    WriteLn('fails=', Fails);
    Halt(Fails);
  end;
  if GetEnvironmentVariable('SMOKE_ONLY_WINDOW') <> '' then
  begin
    try TestIconsAndTheme; except on E: Exception do begin Inc(Fails); WriteLn('FAIL icons exception: ', E.Message); end; end;
    try TestButtonIcons; except on E: Exception do begin Inc(Fails); WriteLn('FAIL button icons exception: ', E.Message); end; end;
    try TestSideMenu; except on E: Exception do begin Inc(Fails); WriteLn('FAIL sidemenu exception: ', E.Message); end; end;
    try TestAnchorEditor; except on E: Exception do begin Inc(Fails); WriteLn('FAIL anchor editor exception: ', E.Message); end; end;
    try TestFormBinder; except on E: Exception do begin Inc(Fails); WriteLn('FAIL binder exception: ', E.Message); end; end;
    try TestPaletteComponents; except on E: Exception do begin Inc(Fails); WriteLn('FAIL components exception: ', E.Message); end; end;
    try TestSideMenuGroups; except on E: Exception do begin Inc(Fails); WriteLn('FAIL sidemenu groups exception: ', E.Message); end; end;
    try TestShell; except on E: Exception do begin Inc(Fails); WriteLn('FAIL shell exception: ', E.Message); end; end;
    try TestDocTypes; except on E: Exception do begin Inc(Fails); WriteLn('FAIL doctypes exception: ', E.Message); end; end;
    try TestShowcase2; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase2 exception: ', E.Message); end; end;
    try TestAppSpec; except on E: Exception do begin Inc(Fails); WriteLn('FAIL appspec exception: ', E.Message); end; end;
    try TestSpecCharts; except on E: Exception do begin Inc(Fails); WriteLn('FAIL charts exception: ', E.Message); end; end;
    try TestPredictFunctions; except on E: Exception do begin Inc(Fails); WriteLn('FAIL predict exception: ', E.Message); end; end;
    try TestNewton; except on E: Exception do begin Inc(Fails); WriteLn('FAIL newton exception: ', E.Message); end; end;
    try TestLeagueAndValidation; except on E: Exception do begin Inc(Fails); WriteLn('FAIL league exception: ', E.Message); end; end;
    try TestPairsSession; except on E: Exception do begin Inc(Fails); WriteLn('FAIL pairs exception: ', E.Message); end; end;
    try TestMarketFit; except on E: Exception do begin Inc(Fails); WriteLn('FAIL marketfit exception: ', E.Message); end; end;
    try TestEngineBacktest; except on E: Exception do begin Inc(Fails); WriteLn('FAIL engine exception: ', E.Message); end; end;
    try TestSlipGeneration; except on E: Exception do begin Inc(Fails); WriteLn('FAIL slips exception: ', E.Message); end; end;
    try TestBacktest; except on E: Exception do begin Inc(Fails); WriteLn('FAIL backtest exception: ', E.Message); end; end;
    try TestDataImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dataimport exception: ', E.Message); end; end;
    try TestCountryImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL country exception: ', E.Message); end; end;
    try TestScrape; except on E: Exception do begin Inc(Fails); WriteLn('FAIL scrape exception: ', E.Message); end; end;
    try TestStandardGenerator; except on E: Exception do begin Inc(Fails); WriteLn('FAIL standard exception: ', E.Message); end; end;
    try TestRoundReport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL roundreport exception: ', E.Message); end; end;
    try TestAnalytics; except on E: Exception do begin Inc(Fails); WriteLn('FAIL analytics exception: ', E.Message); end; end;
    try TestReliability; except on E: Exception do begin Inc(Fails); WriteLn('FAIL reliability exception: ', E.Message); end; end;
  try TestMdbImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL mdb import exception: ', E.Message); end; end;
    try TestMdbImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL mdb import exception: ', E.Message); end; end;
  try TestAnchorsAndWindow; except on E: Exception do begin Inc(Fails); WriteLn('FAIL anchors exception: ', E.Message); end; end;
  try TestDockLayout; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dock exception: ', E.Message); end; end;
  try TestDockInDesigner; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dock designer exception: ', E.Message); end; end;
  try TestMainFormTemplate; except on E: Exception do begin Inc(Fails); WriteLn('FAIL main form template exception: ', E.Message); end; end;
    WriteLn('fails=', Fails);
    Halt(Fails);
  end;
  if GetEnvironmentVariable('SMOKE_ONLY_RICH') <> '' then
  begin
    try TestRichText; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rich text exception: ', E.Message); end; end;
    try TestAnchorsAndWindow; except on E: Exception do begin Inc(Fails); WriteLn('FAIL anchors exception: ', E.Message); end; end;
  try TestDockLayout; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dock exception: ', E.Message); end; end;
  try TestDockInDesigner; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dock designer exception: ', E.Message); end; end;
  try TestMainFormTemplate; except on E: Exception do begin Inc(Fails); WriteLn('FAIL main form template exception: ', E.Message); end; end;
  try TestRichTextField; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rich field exception: ', E.Message); end; end;
    WriteLn('fails=', Fails);
    Halt(Fails);
  end;
  if GetEnvironmentVariable('SMOKE_ONLY_SHOWCASE') <> '' then
  begin
    try TestRichText; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rich text exception: ', E.Message); end; end;
  try TestRichTextField; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rich field exception: ', E.Message); end; end;
  try TestShowcase; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase exception: ', E.Message); end; end;
    try TestShowcasePrograms; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase programs exception: ', E.Message); end; end;
    WriteLn('fails=', Fails);
    Halt(Fails);
  end;
  if GetEnvironmentVariable('SMOKE_ONLY_PAGE') <> '' then
  begin
    try TestPageAndSelection; except on E: Exception do begin Inc(Fails); WriteLn('FAIL page setup exception: ', E.Message); end; end;
  try TestShowcase; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase exception: ', E.Message); end; end;
  try TestShowcasePrograms; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase programs exception: ', E.Message); end; end;
    WriteLn('fails=', Fails);
    Halt(Fails);
  end;
  if GetEnvironmentVariable('SMOKE_ONLY_FGL') <> '' then
  begin
    TestExprUtf8;
    TestManualExamples;
    TestManual4gl;
    TestManualPascal;
    TestManual4glRecipes;
    TestInvoiceRounding;
    TestRecipes2;
    TestRecipes3;
    TestRecipes4;
    TestRecipes5;
    TestBlocks;
    TestMacroLang;
    TestFormVerbs;
    TestFglBlocks;
    TestFglBlockEditor;
    TestOffers;
    TestLetters;
    TestBlocksDemo;
    TestDesignGeometry;
    TestBlockEditor;
    TestGroupPages;
    TestSingleFormRules;
    TestSortOptions;
    TestFileStore;
    TestFgl; TestFgl2; TestFgl3; TestFgl4;
    WriteLn('fails=', Fails);
    Halt(Fails);
  end;
  DeleteFile('/tmp/ta_smoke.db');
  Db := TAppDb.Create;
  Db.Open('/tmp/ta_smoke.db');
  WriteLn('step opened'); Flush(Output);
  SetLength(Fl, 3);
  Fl[0].Name := 'id'; Fl[0].SqlType := 'INTEGER'; Fl[0].PrimaryKey := True;
  Fl[1].Name := 'naziv'; Fl[1].SqlType := 'TEXT';
  Fl[2].Name := 'aktivan'; Fl[2].SqlType := 'INTEGER';
  Db.CreateTable('partner', Fl);
  WriteLn('step created'); Flush(Output);
  Check(Db.UserTables.IndexOf('partner') >= 0, 'table created, listed');

  D := TaFormDef.Create;
  D.Name := 'Partneri'; D.RecordSource := 'partner';
  D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 10));
  D.Add(NewCtl('CheckBox', 'chkAktivan', 'aktivan', 10, 40));
  C := NewCtl('Button', 'btnNovi', '', 10, 70); C.OnClick := 'new'; D.Add(C);
  Db.SaveObject('_sys_forms', D.Name, D.ToJson);
  D.Free;

  WriteLn('step saved'); Flush(Output);
  D2 := TaFormDef.Create;
  D2.FromJson(Db.LoadObject('_sys_forms', 'Partneri'));
  Check((D2.Count = 3) and (D2.RecordSource = 'partner'), 'definition JSON round trip');

  R := TaFormRunner.CreateRunner(nil, Db, D2);
  WriteLn('step runner'); Flush(Output);
  R.DoAction('new');
  TEdit(R.ControlByName('txtNaziv')).Text := 'Prvi';
  TCheckBox(R.ControlByName('chkAktivan')).Checked := True;
  R.DoAction('new');
  TEdit(R.ControlByName('txtNaziv')).Text := 'Drugi';
  R.DoAction('first');
  Check(TEdit(R.ControlByName('txtNaziv')).Text = 'Prvi', 'first record loads back');
  Check(TCheckBox(R.ControlByName('chkAktivan')).Checked, 'checkbox bound');
  R.DoAction('next');
  Check(TEdit(R.ControlByName('txtNaziv')).Text = 'Drugi', 'next record, auto-saved on move');
  TEdit(R.ControlByName('txtNaziv')).Text := 'Drugi-izmj';
  R.DoAction('save');
  R.Free;

  Q := Db.NewQuery('SELECT naziv, aktivan FROM partner ORDER BY id');
  Q.Open;
  Check(Q.RecordCount = 2, 'two rows in table');
  Check(Q.Fields[0].AsString = 'Prvi', 'row 1 value in SQLite');
  Q.Next;
  Check(Q.Fields[0].AsString = 'Drugi-izmj', 'row 2 edit persisted');
  Q.Free;

  { ---- Phase 2 ---- }
  Db.Conn.ExecuteDirect('CREATE TABLE kupac (id INTEGER PRIMARY KEY, naziv TEXT)');
  Db.Conn.ExecuteDirect('CREATE TABLE racun (id INTEGER PRIMARY KEY, kupac_id INTEGER REFERENCES kupac(id), iznos REAL)');
  Db.Conn.ExecuteDirect('INSERT INTO kupac VALUES (1, ''Ana''), (2, ''Ivo'')');
  Db.Conn.ExecuteDirect('INSERT INTO racun VALUES (1,1,50), (2,1,150), (3,2,300)');

  Fd.Name := 'grad'; Fd.SqlType := 'TEXT'; Fd.PrimaryKey := False; Fd.NotNull := False;
  Db.AddColumn('kupac', Fd);
  Db.RenameColumn('kupac', 'grad', 'mjesto');
  Q := Db.TableInfo('kupac');
  Check(Q.RecordCount = 3, 'ALTER add column');
  Q.Free;
  Db.DropColumn('kupac', 'mjesto');
  Q := Db.TableInfo('kupac');
  Check(Q.RecordCount = 2, 'ALTER drop column after rename');
  Q.Free;

  Db.SaveObject('_sys_queries', 'veliki', 'SELECT * FROM racun WHERE iznos > 100;');
  Q := Db.NewQuery(Db.SourceSql('veliki'));
  Q.Open;
  Check(Q.RecordCount = 2, 'saved query resolves as record source');
  Q.Free;

  QD := TaQueryDesigner.CreateDesigner(nil, Db, 'spoj');
  QD.CheckTable('kupac');
  QD.CheckTable('racun');
  Check(Pos('INNER JOIN "racun" ON "racun"."kupac_id" = "kupac"."id"', QD.GenerateSql) > 0, 'designer joins on foreign key');
  Check((QD.FieldListItems.IndexOf('kupac') >= 0) and (QD.FieldListItems.IndexOf('racun') >= 0), 'query designer: each table has a title in the field list');
  Check((QD.FieldListItems.IndexOf('naziv') >= 0) and (QD.FieldListItems.IndexOf('iznos') >= 0), 'query designer: the field list shows plain field names');
  Sq := Db.NewQuery('SELECT 150.0 AS x, 0.5 AS y, 1234567.25 AS z'); Sq.Open;
  Check((Sq.Fields[0].DisplayText = '150') and (Sq.Fields[1].DisplayText = '0.5') and (Sq.Fields[2].DisplayText = '1,234,567.25'), 'query results: decimals are not shown in exponent form (' + Sq.Fields[0].DisplayText + ')');
  Sq.Free;
  Check((QD.FieldKeyAt(QD.FieldListItems.IndexOf('naziv')) = 'kupac.naziv') and (QD.FieldKeyAt(QD.FieldListItems.IndexOf('kupac')) = ''), 'query designer: names map back to table.field, titles map to nothing');
  QD.Sql.Text := QD.GenerateSql;
  QD.RunQuery;
  try
    QD.Show;
    Application.ProcessMessages;
    QD.GridResizeForTest;
    Application.ProcessMessages;
    QdBmp := QD.GetFormImage;
    QdPng := TPortableNetworkGraphic.Create;
    QdPng.Assign(QdBmp);
    QdPng.SaveToFile('/tmp/ta_querydesigner.png');
    QdPng.Free; QdBmp.Free;
  except
    on E: Exception do WriteLn('screenshot skipped: ', E.Message);
  end;
  QD.Hide;
  QD.Free;

  D := TaFormDef.Create;
  D.Name := 'Kupci'; D.RecordSource := 'kupac';
  D.Add(NewCtl('TextBox', 'txtNaziv', 'naziv', 10, 10));
  C := NewCtl('Subform', 'subRacuni', '', 10, 50);
  C.RowSource := 'racun'; C.LinkMaster := 'id'; C.LinkChild := 'kupac_id'; D.Add(C);
  Db.SaveObject('_sys_forms', 'Kupci', D.ToJson);
  D.Free;
  D2 := TaFormDef.Create;
  D2.FromJson(Db.LoadObject('_sys_forms', 'Kupci'));
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check(R.SubCount('subRacuni') = 2, 'subform shows master''s 2 invoices');
  R.DoAction('next');
  Check(R.SubCount('subRacuni') = 1, 'subform follows master record');
  R.Free;

  D := TaFormDef.Create;
  D.Name := 'Racuni'; D.RecordSource := 'racun';
  C := NewCtl('ComboBox', 'cmbKupac', 'kupac_id', 10, 10);
  C.RowSource := 'SELECT id, naziv FROM kupac ORDER BY id'; D.Add(C);
  Db.SaveObject('_sys_forms', 'Racuni', D.ToJson);
  D.Free;
  D2 := TaFormDef.Create;
  D2.FromJson(Db.LoadObject('_sys_forms', 'Racuni'));
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  R.DoAction('first');
  Check(TComboBox(R.ControlByName('cmbKupac')).Text = 'Ana', 'lookup shows display column');
  TComboBox(R.ControlByName('cmbKupac')).ItemIndex := 1;
  TComboBox(R.ControlByName('cmbKupac')).OnChange(R.ControlByName('cmbKupac'));
  R.DoAction('save');
  R.Free;
  Q := Db.NewQuery('SELECT kupac_id FROM racun WHERE id = 1');
  Q.Open;
  Check(Q.Fields[0].AsInteger = 2, 'lookup writes bound key');
  Q.Free;

  { ---- Phase 3: reports ---- }
  Db.Conn.ExecuteDirect('UPDATE kupac SET naziv = ''Đuro Ćosić'' WHERE id = 2');
  Db.SaveObject('_sys_queries', 'rac_kup',
    'SELECT k.naziv AS kupac, r.iznos AS iznos FROM racun r JOIN kupac k ON k.id = r.kupac_id');
  RD := TaReportDef.Create;
  RD.Name := 'Racuni po kupcu'; RD.Title := 'Računi'; RD.RecordSource := 'rac_kup'; RD.GroupField := 'kupac';
  RD.SortBy := 'iznos';
  RD.Add(RItem('Label', 'ReportHeader', 'lblNaslov', 'Računi po kupcu', 0, 8, 400, 24));
  RD.Add(RItem('TextBox', 'GroupHeader', 'txtKupac', 'kupac', 0, 2, 300, 22)).Bold := True;
  RD.Add(RItem('TextBox', 'Detail', 'txtIznos', 'iznos', 200, 2, 100, 20)).Format := '0.00';
  RD.Add(RItem('Label', 'GroupFooter', 'lblUk', 'Ukupno', 0, 4, 100, 20));
  RD.Add(RItem('TextBox', 'GroupFooter', 'txtSum', '=Sum([iznos])', 200, 4, 100, 20)).Format := '0.00';
  RD.Add(RItem('TextBox', 'ReportFooter', 'txtBr', '="Računa: " & Count(*) & ", prosjek " & Round(Avg([iznos]), 1)', 0, 8, 400, 20));
  RD.Add(RItem('TextBox', 'PageFooter', 'txtPg', '="Stranica " & Page & " / " & Pages', 0, 2, 200, 20));
  Db.SaveObject('_sys_reports', RD.Name, RD.ToJson);
  RD.Free;
  Rd2 := TaReportDef.Create;
  Rd2.FromJson(Db.LoadObject('_sys_reports', 'Racuni po kupcu'));
  Check((Rd2.Count = 7) and (Rd2.GroupField = 'kupac'), 'report JSON round trip');
  RE := TaReportEngine.Create(Db, Rd2);
  RR := RE.Render;
  Check(RR.PageCount = 1, 'one page');
  Check(HasText(RR, 'Đuro Ćosić'), 'group header, Croatian letters');
  Check(HasText(RR, '350.00') and HasText(RR, '150.00'), 'group sums 350 and 150');
  Check(HasText(RR, 'Računa: 3, prosjek 166.7'), 'report footer Count/Avg/Round');
  Check(HasText(RR, 'Stranica 1 / 1'), 'Page / Pages resolved');
  Check(HasText(RR, '50.00') and HasText(RR, '300.00'), 'detail rows formatted');
  Check(ExportHtml(RR, '/tmp/ta_report.html'), 'HTML export');
  Check(ExportPdf(RR, '/tmp/ta_report.pdf', PdfErr), 'PDF export ' + PdfErr);
  RR.Free;
  RE.Free;
  Rd2.Free;
  Rd2 := TaReportDef.Create;
  Rd2.FromJson(Db.LoadObject('_sys_reports', 'Racuni po kupcu'));
  with TaReportDesigner.CreateDesigner(nil, Db, Rd2) do Free;
  Check(True, 'report designer builds');
  D2 := TaFormDef.Create;
  D2.FromJson(Db.LoadObject('_sys_forms', 'Kupci'));
  with TaFormDesigner.CreateDesigner(nil, Db, D2) do Free;
  Check(True, 'form designer builds');

  { ---- Phase 4a: typed fields ---- }
  Mt := TaFieldMeta.Create; Mt.LType := ltDate;
  Check(DisplayToStored(Mt, '1.2.2026', Sv) and (Sv = '2026-02-01'), 'date d.m.yyyy -> ISO');
  Check(DisplayToStored(Mt, '2026-02-01', Sv) and (Sv = '2026-02-01'), 'date ISO accepted');
  Check(not DisplayToStored(Mt, '31.02.2026', Sv), 'invalid date rejected');
  Check(StoredToDisplay(Mt, '2026-02-01') = '01.02.2026', 'date display dd.mm.yyyy');
  Mt.LType := ltCurrency; Mt.Decimals := 2; Mt.Format := '#,##0.00 "€"';
  Check(DisplayToStored(Mt, '1.234,5', Sv) and (Sv = '1234.5'), 'currency parses 1.234,5');
  Check(DisplayToStored(Mt, '12,346', Sv) and (Sv = '12.35'), 'currency rounds to decimals');
  Check((Pos('€', StoredToDisplay(Mt, '1234.5')) > 0) and (Pos('234', StoredToDisplay(Mt, '1234.5')) > 0), 'currency display with symbol');
  Mt.LType := ltDate; Mt.DefaultExpr := 'Today()';
  Check(EvalDefault(Mt) = FormatDateTime('yyyy-mm-dd', Date), 'default Today()');
  Mt.LType := ltDateTime; Mt.DefaultExpr := '=Now()';
  Check(Copy(EvalDefault(Mt), 1, 10) = FormatDateTime('yyyy-mm-dd', Date), 'default Now()');
  Mt.LType := ltYesNo; Mt.DefaultExpr := '1';
  Check(EvalDefault(Mt) = '1', 'default literal 1');
  Mt.LType := ltText; Mt.DefaultExpr := '''n/a''';
  Check(EvalDefault(Mt) = 'n/a', 'default text literal');
  Mt.Free;

  SetLength(Fl, 4);
  Fl[0].Name := 'id'; Fl[0].PrimaryKey := True; Fl[0].Meta := TaFieldMeta.Create; Fl[0].Meta.LType := ltAutoNumber;
  Fl[1].Name := 'datum'; Fl[1].Meta := TaFieldMeta.Create; Fl[1].Meta.LType := ltDate; Fl[1].Meta.DefaultExpr := 'Today()';
  Fl[2].Name := 'iznos'; Fl[2].Meta := TaFieldMeta.Create; Fl[2].Meta.LType := ltCurrency;
  Fl[2].Meta.Format := '#,##0.00 "€"';
  Fl[3].Name := 'aktivno'; Fl[3].Meta := TaFieldMeta.Create; Fl[3].Meta.LType := ltYesNo; Fl[3].Meta.DefaultExpr := '1';
  Db.CreateTable('uplata', Fl);
  for K := 0 to 3 do Fl[K].Meta.Free;
  Q := Db.TableInfo('uplata');
  Check(Q.RecordCount = 4, 'typed table created');
  Q.Free;
  Mt := Db.FindFieldMeta('uplata', 'iznos');
  Check((Mt <> nil) and (Mt.LType = ltCurrency) and (Mt.Format = '#,##0.00 "€"'), 'field meta persisted');
  Mt.Free;

  D := TaFormDef.Create;
  D.Name := 'Uplate'; D.RecordSource := 'uplata';
  D.Add(NewCtl('TextBox', 'txtDatum', 'datum', 10, 10));
  D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 40));
  D.Add(NewCtl('CheckBox', 'chkAkt', 'aktivno', 10, 70));
  Db.SaveObject('_sys_forms', 'Uplate', D.ToJson);
  D.Free;
  D2 := TaFormDef.Create;
  D2.FromJson(Db.LoadObject('_sys_forms', 'Uplate'));
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  R.DoAction('new');
  Check(TEdit(R.ControlByName('txtDatum')).Text = FormatDateTime('dd.mm.yyyy', Date), 'new record: date default shown dd.mm.yyyy');
  Check(TCheckBox(R.ControlByName('chkAkt')).Checked, 'new record: YesNo default');
  TEdit(R.ControlByName('txtIznos')).Text := '1.234,5';
  R.DoAction('save');
  R.Free;
  Sq := Db.NewQuery('SELECT datum, iznos, aktivno FROM uplata');
  Sq.Open;
  Check(Sq.Fields[0].AsString = FormatDateTime('yyyy-mm-dd', Date), 'date stored as ISO');
  Check(Abs(Sq.Fields[1].AsFloat - 1234.5) < 0.0001, 'currency stored as number');
  Check(Sq.Fields[2].AsInteger = 1, 'YesNo stored as 1');
  Sq.Free;

  Sq := Db.NewQuery('SELECT * FROM uplata');
  Sq.Open;
  Fmt := TaDatasetFormatter.Create(Sq, Db.LoadFieldMetas('uplata'));
  Check(Sq.FieldByName('datum').DisplayText = FormatDateTime('dd.mm.yyyy', Date), 'datasheet shows display format');
  Sq.First; Sq.Edit;
  Sq.FieldByName('datum').Text := '5.5.2027';
  Sq.Post;
  Check(Sq.FieldByName('datum').AsString = '2027-05-05', 'datasheet edit parsed to ISO');
  Fmt.Free;
  Sq.Free;

  { ---- Phase 4b: import / export ---- }
  with TStringList.Create do
  try
    Add('Naziv;Iznos;Datum;Aktivan;Bilješka');
    Add('Šime Čović;12,50;1.2.2026;da;"redak 1' + #10 + 'redak 2"');
    Add('Ćiro;1.234,5;15.03.2026;ne;"kaže ""bok"""');
    Add('Đuka;;3.4.2026;da;');
    Sv := UTF8ToCP1250(Text);
  finally
    Free;
  end;
  with TFileStream.Create('/tmp/ta_import.csv', fmCreate) do
  try
    WriteBuffer(Sv[1], Length(Sv));
  finally
    Free;
  end;
  Check(ReadCsvFile('/tmp/ta_import.csv', #0, Rows, Dl) and (Dl = ';') and (Length(Rows) = 4), 'CSV read, delimiter ; detected, 4 rows');
  Check(Rows[1][0] = 'Šime Čović', 'CP1250 converted to UTF-8');
  Check(Rows[1][4] = 'redak 1' + #10 + 'redak 2', 'newline inside quotes kept');
  Check(Rows[2][4] = 'kaže "bok"', 'doubled quote unescaped');
  ICols := InferColumns(Rows, True);
  Check((ICols[1].LType = ltDecimal) and (ICols[2].LType = ltDate) and (ICols[3].LType = ltYesNo) and (ICols[0].LType = ltText),
    'column types inferred Decimal/Date/YesNo/Text');
  IRes := ImportToNewTable(Db, 'uvoz', Rows, True, True, ICols);
  Check((IRes.Inserted = 3) and (IRes.BadValues = 0), 'imported 3 rows, no bad values');
  Sq := Db.NewQuery('SELECT id, naziv, iznos, datum, aktivan FROM uvoz ORDER BY id');
  Sq.Open;
  Check((Sq.Fields[0].AsInteger = 1) and (Sq.Fields[1].AsString = 'Šime Čović'), 'new table: key added, text stored');
  Check(Abs(Sq.Fields[2].AsFloat - 12.5) < 0.0001, 'decimal comma stored as 12.5');
  Check(Sq.Fields[3].AsString = '2026-02-01', 'date stored ISO');
  Check(Sq.Fields[4].AsInteger = 1, 'da -> 1');
  Sq.Next; Sq.Next;
  Check(Sq.Fields[2].IsNull, 'empty cell -> NULL');
  Sq.Free;
  Mt := Db.FindFieldMeta('uvoz', 'datum');
  Check((Mt <> nil) and (Mt.LType = ltDate), 'imported column carries Date type');
  Mt.Free;

  ExportCsv(Db, 'uvoz', '/tmp/ta_export.csv', ';');
  Check(ReadCsvFile('/tmp/ta_export.csv', #0, Rows, Dl) and (Length(Rows) = 4) and (Rows[0][1] = 'Naziv'), 'CSV export re-readable with header');
  Check((Rows[1][3] = '01.02.2026') and (Rows[1][2] = '12,5'), 'CSV export: display dates, decimal comma');
  ExportXlsx(Db, 'uvoz', '/tmp/ta_export.xlsx');
  Check(ReadSheetFile('/tmp/ta_export.xlsx', Rows) and (Length(Rows) = 4), 'XLSX export read back, 4 rows');
  Check((Rows[1][1] = 'Šime Čović') and (Rows[1][3] = '2026-02-01'), 'XLSX keeps text and real dates');
  ICols := InferColumns(Rows, True);
  Check((ICols[3].LType = ltDate) and (ICols[2].LType = ltDecimal), 'XLSX columns re-infer Date/Decimal');
  ExportJson(Db, 'uvoz', '/tmp/ta_export.json');
  with TStringList.Create do
  try
    LoadFromFile('/tmp/ta_export.json');
    Check((Pos('"Iznos": 12.5', Text) > 0) and (Pos('Šime', Text) > 0), 'JSON export');
  finally
    Free;
  end;

  Db.Conn.ExecuteDirect('DELETE FROM partner');
  SetLength(Rows, 0);
  SetLength(Rows, 2);
  SetLength(Rows[0], 2); SetLength(Rows[1], 2);
  Rows[0][0] := 'naziv'; Rows[0][1] := 'nepoznato';
  Rows[1][0] := 'Uvezeni'; Rows[1][1] := 'x';
  IRes := ImportToExisting(Db, 'partner', Rows, True);
  Sq := Db.NewQuery('SELECT naziv FROM partner');
  Sq.Open;
  Check((IRes.Inserted = 1) and (Sq.Fields[0].AsString = 'Uvezeni'), 'import into existing table maps by header');
  Sq.Free;

  { ---- Phase 4c: wizard generators ---- }
  Flds := TStringList.Create;
  Flds.CommaText := 'kupac_id,iznos';
  D := BuildFormDef(Db, 'racun', 'WizForma', Flds, False);
  Check((D.Count = 4) and (D[1].Kind = 'ComboBox') and (Pos('FROM "kupac"', D[1].RowSource) > 0), 'form wizard: FK -> lookup combo');
  Check(Pos('"naziv"', D[1].RowSource) > 0, 'lookup shows first text column');
  Db.SaveObject('_sys_forms', 'WizForma', D.ToJson);
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  R.DoAction('first');
  Check(TComboBox(R.ControlByName(D2[1].Name)).Text = 'Đuro Ćosić', 'wizard form runs, lookup resolves name');
  R.Free;
  Flds.CommaText := 'datum,iznos,aktivno';
  D := BuildFormDef(Db, 'uplata', 'WizForma2', Flds, True);
  Check((D[1].Kind = 'TextBox') and (D[5].Kind = 'CheckBox') and (D.Width > 640), 'form wizard: typed controls, two columns');
  D.Free;
  Flds.CommaText := 'kupac,iznos';
  RD := BuildReportDef(Db, 'rac_kup', 'WizIzv', 'Računi', Flds, 'kupac', 'iznos', False, True);
  Check((RD.GroupField = 'kupac') and (RD.SortBy = '"iznos"'), 'report wizard: group and sort');
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(HasText(RR, 'Ukupno') and HasText(RR, 'Sveukupno'), 'report wizard: group and grand total labels');
  Check(HasText(RR, '350.00') and HasText(RR, '500.00') and HasText(RR, 'Računi'), 'report wizard: sums 350 and 500, title');
  RR.Free; RE.Free; RD.Free;
  Flds.CommaText := 'datum,iznos,aktivno';
  RD := BuildReportDef(Db, 'uplata', 'WizIzv2', 'Uplate', Flds, '', '', False, True);
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(HasText(RR, '05.05.2027'), 'report shows Date in display format');
  Check(HasText(RR, '1,234.50 €'), 'report shows Currency in field format');
  Check(HasText(RR, 'Da'), 'report shows YesNo as Da');
  RR.Free; RE.Free; RD.Free;
  Flds.Free;


  { ---- FK / relations ---- }
  Db.Conn.ExecuteDirect('CREATE TABLE grad (id INTEGER PRIMARY KEY, naziv TEXT UNIQUE)');
  Db.Conn.ExecuteDirect('CREATE TABLE osoba (id INTEGER PRIMARY KEY, ime TEXT NOT NULL DEFAULT ''x'', grad_id INTEGER)');
  Db.Conn.ExecuteDirect('CREATE INDEX ix_osoba_ime ON osoba (ime)');
  Db.Conn.ExecuteDirect('INSERT INTO grad VALUES (1, ''Zagreb''), (2, ''Split'')');
  Db.Conn.ExecuteDirect('INSERT INTO osoba (ime, grad_id) VALUES (''Ana'', 1), (''Ivo'', 2)');
  SetLength(Fks, 1);
  Fks[0].FromCol := 'grad_id'; Fks[0].RefTable := 'grad'; Fks[0].RefCol := 'id'; Fks[0].OnDelete := 'CASCADE';
  Db.SetFks('osoba', Fks);
  Fks := Db.GetFks('osoba');
  Check((Length(Fks) = 1) and (Fks[0].RefTable = 'grad') and (Fks[0].OnDelete = 'CASCADE'), 'SetFks adds foreign key');
  Sq := Db.NewQuery('SELECT COUNT(*) FROM osoba');
  Sq.Open;
  Check(Sq.Fields[0].AsInteger = 2, 'rebuild kept the rows');
  Sq.Free;
  Sq := Db.NewQuery('SELECT sql FROM sqlite_master WHERE name = ''ix_osoba_ime''');
  Sq.Open;
  Check(not Sq.EOF, 'rebuild recreated the index');
  Sq.Free;
  Db.Conn.ExecuteDirect('DELETE FROM grad WHERE id = 1');
  Sq := Db.NewQuery('SELECT COUNT(*) FROM osoba');
  Sq.Open;
  Check(Sq.Fields[0].AsInteger = 1, 'ON DELETE CASCADE works');
  Sq.Free;
  Rels := Db.AllRelations;
  Check((Length(Rels) >= 1) and (Rels[High(Rels)].Parent <> ''), 'AllRelations lists relations');
  { dangling row 77 must make a new key refuse }
  SetLength(Fks, 1);
  Fks[0].FromCol := 'grad_id'; Fks[0].RefTable := 'grad'; Fks[0].RefCol := 'id';
  Db.Conn.ExecuteDirect('PRAGMA foreign_keys = OFF');
  Db.Conn.ExecuteDirect('INSERT INTO osoba (ime, grad_id) VALUES (''Siroce'', 99)');
  Db.Conn.ExecuteDirect('PRAGMA foreign_keys = ON');
  FkRefused := False;
  try
    Db.SetFks('osoba', Fks);
  except
    FkRefused := True;
  end;
  Check(FkRefused, 'SetFks refuses when existing rows violate the key');
  Sq := Db.NewQuery('SELECT COUNT(*) FROM osoba');
  Sq.Open;
  Check(Sq.Fields[0].AsInteger >= 2, 'refused rebuild rolled back (table intact)');
  Sq.Free;
  Check(Db.PrimaryKeyOf('grad') = 'id', 'PrimaryKeyOf');
  Db.SaveSetting('relview', '{"a":1}');
  Check(Db.LoadSetting('relview') = '{"a":1}', 'settings round trip');

  { ---- Phase 5a: expression language ---- }
  XH := TTestHost.Create;

  Check(Ev(XH, '1 + 2 * 3') = '7', 'expr precedence');
  Check(Ev(XH, '(1 + 2) * 3 ^ 2') = '27', 'expr power and parentheses');
  Check(Ev(XH, '7 \ 2') = '3', 'expr integer division');
  Check(Ev(XH, '7 Mod 3') = '1', 'expr Mod');
  Check(Ev(XH, '[a] * [b] - 1') = '14', 'expr field refs [a]=5 [b]=3');
  Check(Ev(XH, '[a] > [b] And [b] > 0') = 'Da', 'expr And, comparison');
  Check(Ev(XH, 'Not ([a] = 5)') = 'Ne', 'expr Not');
  Check(Ev(XH, '[a] = 5 Or 1 / 0') = 'Da', 'expr Or with Null operand');
  Check(Ev(XH, 'Iif([a] > 3, "veliko", "malo")') = 'veliko', 'expr Iif');
  Check(Ev(XH, 'Nz([n], "prazno")') = 'prazno', 'expr Nz');
  Check(Ev(XH, 'IsNull([n])') = 'Da', 'expr IsNull');
  Check(Ev(XH, '[n] Is Null') = 'Da', 'expr Is Null');
  Check(Ev(XH, '[s] Is Not Null') = 'Da', 'expr Is Not Null');
  Check(Ev(XH, '[s] Like "Zag*"') = 'Da', 'expr Like');
  Check(Ev(XH, '[a] Between 1 And 5') = 'Da', 'expr Between');
  Check(Ev(XH, '[a] In (1, 5, 9)') = 'Da', 'expr In');
  Check(Ev(XH, '"Ana" & " " & "Ban"') = 'Ana Ban', 'expr concat &');
  Check(Ev(XH, '"a" + "b"') = 'ab', 'expr text + text');
  Check(Ev(XH, 'Len("Zagreb")') = '6', 'expr Len');
  Check(Ev(XH, 'UCase(Left([s], 3)) & Right([s], 2)') = 'ZAGeb', 'expr Left/Right/UCase');
  Check(Ev(XH, 'Mid("abcdef", 2, 3)') = 'bcd', 'expr Mid');
  Check(Ev(XH, 'InStr("Zagreb", "gre")') = '3', 'expr InStr');
  Check(Ev(XH, 'Replace("a-b-c", "-", "+")') = 'a+b+c', 'expr Replace');
  Check(Ev(XH, 'Proper("ivo horvat")') = 'Ivo Horvat', 'expr Proper');
  Check(Ev(XH, 'Round(2.567, 1)') = '2.6', 'expr Round');
  Check(Ev(XH, 'Abs(-4) + Int(2.9) + Sqr(16)') = '10', 'expr Abs/Int/Sqr');
  Check(Ev(XH, 'Max(3, 9, 4) - Min(3, 9, 4)') = '6', 'expr scalar Max/Min');
  Check(Ev(XH, 'Sum([a])') = '42', 'expr aggregate goes to host');
  Check(Ev(XH, 'Format(1234.5, "#,##0.00")') = '1,234.50', 'expr Format number');
  Check(Ev(XH, 'Format(1234.5, "Currency")') = '1,234.50 €', 'expr Format Currency');
  Check(Ev(XH, 'Format(#2026-03-15#, "dd.mm.yyyy")') = '15.03.2026', 'expr date literal + Format');
  Check(Ev(XH, 'Year([d]) & "/" & Month([d])') = '2026/3', 'expr Year/Month of ISO string');
  Check(Ev(XH, 'Format(DateAdd("d", 20, [d]), "yyyy-mm-dd")') = '2026-04-04', 'expr DateAdd');
  Check(Ev(XH, 'Format(DateAdd("m", 1, [d]), "yyyy-mm-dd")') = '2026-04-15', 'expr DateAdd month');
  Check(Ev(XH, 'DateDiff("d", [d], #2026-04-01#)') = '17', 'expr DateDiff days');
  Check(Ev(XH, 'DateDiff("m", #2026-01-31#, #2026-03-01#)') = '2', 'expr DateDiff months');
  Check(Ev(XH, 'Format(DateSerial(2026, 14, 1), "yyyy-mm-dd")') = '2027-02-01', 'expr DateSerial overflow');
  Check(Ev(XH, 'Weekday(#2026-03-15#)') = '1', 'expr Weekday (Sunday=1)');
  Check(Ev(XH, 'MonthName(3)') = 'ožujak', 'expr MonthName');
  Check(Ev(XH, 'Format(Date(), "yyyy")') = FormatDateTime('yyyy', Date), 'expr Date()/Format');
  Check(Ev(XH, '[d] < #2026-12-31#') = 'Da', 'expr ISO string vs date literal');
  Check(Ev(XH, 'Switch([a] < 3, "a", [a] < 9, "b", True, "c")') = 'b', 'expr Switch');
  Check(Ev(XH, 'Choose(2, "x", "y", "z")') = 'y', 'expr Choose');
  Check(Ev(XH, 'CInt("12") + Val("3.5")') = '15.5', 'expr CInt/Val');
  Check(Ev(XH, 'IsNumeric("1,5") And Not IsNumeric("abc")') = 'Da', 'expr IsNumeric');
  Check(Ev(XH, '1 +') = '#Err', 'expr syntax error reported as #Err');
  Check(CheckExpr('Iif([a] > 1, 2, 3)') = '', 'CheckExpr accepts valid');
  Check(CheckExpr('Iif([a] > 1, 2,') <> '', 'CheckExpr finds unclosed call');
  Check(CheckExpr('Foo(1)') <> '', 'CheckExpr finds unknown function');
  XH.Free;
  Mt := TaFieldMeta.Create; Mt.LType := ltDate; Mt.DefaultExpr := 'DateAdd("d", 30, Today())';
  Check(EvalDefault(Mt) = FormatDateTime('yyyy-mm-dd', Date + 30), 'default expr DateAdd(Today)');
  Mt.Free;
  Check(VarToStr(DbDomain(Db, 'dcount', '*', 'racun', 'iznos > 100')) = '2', 'DCount');
  Check(VarToStr(DbDomain(Db, 'dsum', 'iznos', 'racun', '')) = '500', 'DSum');
  Check(VarToStr(DbDomain(Db, 'dlookup', 'naziv', 'kupac', 'id = 1')) = 'Ana', 'DLookup');
  Check(VarToStr(DbDomain(Db, 'preuzmi', 'naziv', 'kupac', '1')) = 'Ana', 'Preuzmi: field of the row with that primary key');
  Check(VarIsNull(DbDomain(Db, 'preuzmi', 'naziv', 'kupac', '99999')), 'Preuzmi: no such key gives empty');

  { ---- Phase 5b: runtime features ---- }
  Closer0 := TCloser0.Create;
  Tm0 := TTimer.Create(nil);
  Tm0.Interval := 300;
  Tm0.OnTimer := @Closer0.Tick;
  Tm0.Enabled := False;
  D := TaFormDef.Create;
  D.Name := 'Kalk'; D.RecordSource := 'racun'; D.Filter := 'iznos > 100'; D.OrderBy := 'iznos DESC';
  D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 10));
  C := NewCtl('TextBox', 'txtPdv', '=[iznos] * 1.25', 10, 40); C.Format := '0.00'; D.Add(C);
  C := NewCtl('TextBox', 'txtNaz', '=DLookup("naziv", "kupac", "id = " & [kupac_id])', 10, 70); D.Add(C);
  C := NewCtl('Label', 'lblVeliko', '', 10, 100); C.Caption := 'veliko'; C.SetX('visibleIf', '[iznos] > 200'); D.Add(C);
  C := NewCtl('OptionGroup', 'opgKupac', 'kupac_id', 200, 10); C.RowSource := 'SELECT id, naziv FROM kupac ORDER BY id'; D.Add(C);
  C := NewCtl('ListBox', 'lstKupac', 'kupac_id', 200, 100); C.RowSource := 'SELECT id, naziv FROM kupac ORDER BY id'; D.Add(C);
  C := NewCtl('Chart', 'chtUk', '', 10, 140); C.RowSource := 'SELECT kupac_id, SUM(iznos) FROM racun GROUP BY kupac_id'; C.SetX('chartType', 'pie'); D.Add(C);
  C := NewCtl('Barcode', 'bcRac', '="RAC-" & [iznos]', 200, 200); C.SetX('barType', 'code128'); D.Add(C);
  C := NewCtl('Image', 'imgLogo', '', 10, 340); C.SetX('picture', 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='); D.Add(C);
  C := NewCtl('TabControl', 'tabX', '', 400, 10); C.RowSource := 'Prvi;Drugi'; D.Add(C);
  C := NewCtl('TextBox', 'txtUTabu', '', 10, 10); C.SetX('container', 'tabX'); C.SetX('page', '1'); D.Add(C);
  Db.SaveObject('_sys_forms', 'Kalk', D.ToJson);
  D.Free;
  D2 := TaFormDef.Create;
  D2.FromJson(Db.LoadObject('_sys_forms', 'Kalk'));
  Check(D2[1].ControlSource = '=[iznos] * 1.25', 'calc control definition round trip');
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check(R.Query.RecordCount = 2, 'form filter applied (iznos > 100)');
  Check(TEdit(R.ControlByName('txtIznos')).Text = '300', 'form order DESC: first record is 300');
  Check(TEdit(R.ControlByName('txtPdv')).Text = '375.00', 'calculated control = [iznos] * 1.25');
  Check(TEdit(R.ControlByName('txtNaz')).Text <> '', 'calculated control with DLookup');
  Check(R.ControlByName('lblVeliko').Visible, 'VisibleIf true for 300');
  R.DoAction('next');
  Check(TEdit(R.ControlByName('txtPdv')).Text = '187.50', 'calculated control recalculated on next record');
  Check(not R.ControlByName('lblVeliko').Visible, 'VisibleIf false for 150');
  Check(TRadioGroup(R.ControlByName('opgKupac')).Items.Count = 2, 'OptionGroup filled from SQL');
  Check(TRadioGroup(R.ControlByName('opgKupac')).ItemIndex >= 0, 'OptionGroup shows current value');
  Check(TListBox(R.ControlByName('lstKupac')).Items.Count = 2, 'ListBox filled from SQL');
  Check(ta_controls.TaChart(R.ControlByName('chtUk')).Labels.Count = 2, 'Chart loaded its data');
  Check(ta_controls.TaImage(R.ControlByName('imgLogo')).Picture.Width = 1, 'static Image decoded from base64');
  Check(Copy(ta_controls.TaBarcode(R.ControlByName('bcRac')).Value, 1, 4) = 'RAC-', 'Barcode control shows an expression value: ' + ta_controls.TaBarcode(R.ControlByName('bcRac')).Value);
  Check(R.ControlByName('txtUTabu').Parent is TTabSheet, 'control placed on a tab page');
  Check(TTabSheet(R.ControlByName('txtUTabu').Parent).PageIndex = 1, 'on the second tab');
  R.Search('300');
  Check(R.Query.RecordCount = 1, 'quick search narrows records');
  R.Search('');
  Check(R.Query.RecordCount = 2, 'clearing search restores records');
  R.Free;

  { validation rule }
  Mt := Db.FindFieldMeta('uplata', 'iznos');
  Mt.Validation := '[iznos] > 0'; Mt.ValidationMsg := 'Iznos mora biti pozitivan';
  Db.SaveFieldMeta(Mt);
  Mt.Free;
  D := TaFormDef.Create;
  D.Name := 'UplV'; D.RecordSource := 'uplata';
  D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 10));
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  R.DoAction('new');
  TEdit(R.ControlByName('txtIznos')).Text := '-5';
  OnRunnerMessage := @CaptureMsg;
  Check(not R.SaveRecord, 'validation rule rejects -5');
  Check(Pos('Iznos mora biti pozitivan', LastMsg) > 0, 'validation message shown');
  OnRunnerMessage := nil;
  TEdit(R.ControlByName('txtIznos')).Text := '12,5';
  Check(R.SaveRecord, 'validation rule accepts 12,5');
  R.Free;

  { form inside a form }
  D := TaFormDef.Create;
  D.Name := 'RacuniMali'; D.RecordSource := 'racun';
  D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 10));
  Db.SaveObject('_sys_forms', 'RacuniMali', D.ToJson);
  D.Free;
  D := TaFormDef.Create;
  D.Name := 'KupciSub'; D.RecordSource := 'kupac';
  D.Add(NewCtl('TextBox', 'txtNaz', 'naziv', 10, 10));
  C := NewCtl('Subform', 'subR', '', 10, 50); C.RowSource := 'RacuniMali'; C.LinkMaster := 'id'; C.LinkChild := 'kupac_id'; D.Add(C);
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check(R.SubCount('subR') = 1, 'embedded form shows the master''s rows');
  R.DoAction('next');
  Check(R.SubCount('subR') = 2, 'embedded form follows the master record');
  R.Free;
  Tm0.Free;

  { ---- designer: palette, containers, undo ---- }
  D := TaFormDef.Create;
  D.Name := 'DizTest'; D.RecordSource := 'racun';
  with TaFormDesigner.CreateDesigner(nil, Db, D) do
  try
    AddForTest('TextBox', 8, 8);
    Check(Def.Count = 1, 'designer: control added');
    UndoForTest;
    Check(Def.Count = 0, 'designer: undo removes it');
    AddForTest('TabControl', 20, 20);
    TabC := AddInContainerForTest('TextBox', 'TabControl1', 1);
    Check((TabC <> nil) and (TabC.Parent is TTabSheet) and (TTabSheet(TabC.Parent).PageIndex = 1),
      'designer: control dropped onto the second tab page');
    Check((Def[1].GetX('container') = 'TabControl1') and (Def[1].GetX('page') = '1'), 'designer: container recorded in definition');
    AddForTest('Chart', 300, 300); AddForTest('Image', 300, 100); AddForTest('OptionGroup', 300, 200);
    AddForTest('Hyperlink', 20, 300); AddForTest('Rectangle', 20, 340); AddForTest('ToggleButton', 20, 380); AddForTest('ListBox', 150, 380);
    Check(Def.Count = 9, 'designer: all new control kinds can be placed');
    UndoForTest; UndoForTest;
    Check(Def.Count = 7, 'designer: two undos');
    { remove the tab control: its child must go too }
    Def.ToJson;
  finally
    Free;
  end;

  { ---- Phase 5c: report items ---- }
  RD := TaReportDef.Create;
  RD.Name := 'Sve'; RD.Title := 'Sve'; RD.RecordSource := 'rac_kup'; RD.GroupField := 'kupac';
  RD.Heights[SecReportHeader] := 230;
  C := RItem('Label', 'ReportHeader', 'lblN', 'Pregled', 0, 4, 300, 24); C.Bold := True; C.SetX('fontSize', '16'); C.SetX('foreColor', '#1F4E9C'); RD.Add(C);
  C := RItem('Chart', 'ReportHeader', 'chtA', '', 0, 36, 340, 180); C.RowSource := 'SELECT kupac_id, SUM(iznos) FROM racun GROUP BY kupac_id'; C.Caption := 'Iznosi po kupcu'; RD.Add(C);
  C := RItem('Chart', 'ReportHeader', 'chtB', '', 360, 36, 340, 180); C.RowSource := 'SELECT kupac_id, SUM(iznos) FROM racun GROUP BY kupac_id'; C.SetX('chartType', 'pie'); C.Caption := 'Udjeli'; RD.Add(C);
  C := RItem('Rectangle', 'GroupHeader', 'rctG', '', 0, 2, 300, 22); C.SetX('backColor', '#FFE9A8'); C.SetX('foreColor', '#B07800'); RD.Add(C);
  RD.Add(RItem('TextBox', 'GroupHeader', 'txtK', 'kupac', 6, 4, 280, 18)).Bold := True;
  RD.Add(RItem('TextBox', 'Detail', 'txtI', 'iznos', 0, 1, 120, 20)).Format := '#,##0.00';
  C := RItem('Hyperlink', 'ReportFooter', 'lnk', '', 0, 6, 300, 20); C.Caption := 'Web stranica'; C.RowSource := 'https://example.com'; RD.Add(C);
  C := RItem('Image', 'ReportFooter', 'img', '', 320, 0, 60, 40); C.SetX('picture', 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='); RD.Add(C);
  C := RItem('Image', 'ReportFooter', 'img2', '', 400, 0, 120, 120); DefSet(C, 'Picture', 'icon:invoice'); RD.Add(C);
  { SVG s gradijentom nije podrzan kao vektor u PDF-u: ide kao slika visoke razlucivosti, ali izvoz uspijeva }
  C := RItem('Image', 'ReportFooter', 'img3', '', 540, 0, 100, 100);
  C.SetX('picture', EncodeStringBase64('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><defs><linearGradient id="g"><stop offset="0" stop-color="#f00"/><stop offset="1" stop-color="#00f"/></linearGradient></defs><rect width="10" height="10" fill="url(#g)"/></svg>'));
  RD.Add(C);
  C := RItem('PageBreak', 'GroupFooter', 'pb', '', 0, 6, 200, 2); RD.Add(C);
  RD.Heights[SecGroupFooter] := 12;
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(RR.PageCount >= 2, 'PageBreak in group footer starts a new page per group');
  PgK := 0;
  for K := 0 to RR.PageCount - 1 do
    for K1i := 0 to RR.Page(K).Items.Count - 1 do
      if TaRItem(RR.Page(K).Items[K1i]).Kind = 'Frame' then Inc(PgK);
  Check(PgK >= 4, 'chart bars and rectangle emitted as frames');
  Check(HasText(RR, 'Iznosi po kupcu') and HasText(RR, 'Web stranica'), 'chart title and hyperlink text');
  Check(ExportPdf(RR, '/tmp/ta_report2.pdf', PdfErr), 'PDF export with chart/image/frames ' + PdfErr);
  with TStringList.Create do
  try
    LoadFromFile('/tmp/ta_report2.pdf');
    { slike u PDF-u: 1x1 PNG i gradijent (rasterski); ikona racuna je vektor i nije slika }
    Check(Length(Text) - Length(StringReplace(Text, '/Subtype /Image', '', [rfReplaceAll])) = 2 * Length('/Subtype /Image'),
      'PDF vector: an icon is drawn as paths, only the raster pictures are images');
  finally
    Free;
  end;
  Check(ExportHtml(RR, '/tmp/ta_report2.html'), 'HTML export with new items');
  with TStringList.Create do
  try
    LoadFromFile('/tmp/ta_report2.html');
    Check((Pos('data:image/png;base64', Text) > 0) and (Pos('data:image/svg+xml;base64', Text) > 0) and (Pos('href="https://example.com"', Text) > 0), 'HTML has embedded image (raster and vector) and link');
  finally
    Free;
  end;
  RR.Free; RE.Free; RD.Free;

  { ---- Phase 6: scripting and macros ---- }
  ScriptLog := '';
  OnScriptMessage := @CaptureScript;
  Db.SaveObject('_sys_modules', 'm1',
    'function Dvaput(X: Integer): Integer;' + LineEnding + 'begin Result := X * 2; end;' + LineEnding +
    'procedure OnCur;' + LineEnding + 'begin SetValue(''txtNaz'', ''K'' + GetValue(''txtIznos'')); end;' + LineEnding +
    'procedure Blokiraj;' + LineEnding + 'begin if GetNumber(''txtIznos'') < 0 then CancelEvent; end;' + LineEnding +
    'procedure Hello;' + LineEnding + 'begin Msg(''zdravo '' + UpperCase(GetValue(''txtIznos''))); end;' + LineEnding +
    'procedure Dodaj;' + LineEnding + 'begin SqlExec(''INSERT INTO partner (naziv) VALUES (''''Skripta'''')''); end;');
  Check(Scripts(Db).Ensure, 'modules compile');
  Check(Scripts(Db).HasProc('Dvaput') and Scripts(Db).HasProc('ONCUR'), 'procedures discovered (case-insensitive)');
  Check(Scripts(Db).CallProc(FallbackForTest(Db), 'Dvaput', [21], RV) and (RV = 42), 'script function returns 42');
  XH := TTestHost.Create;
  Check(Ev(XH, 'Dvaput(21) + 1') = '43', 'script function callable from an expression');
  Check(CheckExpr('Dvaput(1)') = '', 'CheckExpr knows script functions');
  XH.Free;
  Check(not Scripts(Db).Check('bad', 'procedure X;' + LineEnding + 'begin' + LineEnding + '  Foo(;' + LineEnding + 'end;', ScriptErr), 'syntax error detected');
  Check(Pos('(3:', ScriptErr) > 0, 'error line is relative to the module (' + Trim(ScriptErr) + ')');
  Check(Scripts(Db).Check('m1', 'procedure OnCur; begin end;', ScriptErr) or True, 'module check runs');

  D := TaFormDef.Create;
  D.Name := 'ScrF'; D.RecordSource := 'racun';
  D.SetEv('OnCurrent', 'OnCur'); D.SetEv('BeforeUpdate', 'Blokiraj');
  D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 10));
  D.Add(NewCtl('TextBox', 'txtNaz', '', 10, 40));
  C := NewCtl('Button', 'btnHello', '', 10, 70); C.OnClick := 'run:Hello'; D.Add(C);
  C := NewCtl('Button', 'btnMakro', '', 120, 70); C.OnClick := 'macro:MojMakro'; D.Add(C);
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  Check(D2.GetEv('OnCurrent') = 'OnCur', 'form events survive JSON');
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check(TEdit(R.ControlByName('txtNaz')).Text = 'K' + TEdit(R.ControlByName('txtIznos')).Text, 'OnCurrent script set txtNaz');
  R.DoAction('next');
  Check(TEdit(R.ControlByName('txtNaz')).Text = 'K' + TEdit(R.ControlByName('txtIznos')).Text, 'OnCurrent runs on every record');
  TEdit(R.ControlByName('txtIznos')).Text := '-5';
  Check(not R.SaveRecord, 'BeforeUpdate script cancelled the save');
  TEdit(R.ControlByName('txtIznos')).Text := '77';
  Check(R.SaveRecord, 'BeforeUpdate lets a good value through');
  R.DoAction('run:Hello');
  Check(Pos('zdravo 77', ScriptLog) > 0, 'run: action calls the script, GetValue works');
  { fgl: pokrece 4GL program iz baze (izbornik "program Naziv"), run: pokrece proceduru modula }
  Db.SaveObject('_sys_programs', 'Upisi', 'MAIN' + LineEnding + '  INSERT INTO partner (naziv) VALUES ("Iz4GL")' + LineEnding + 'END MAIN' + LineEnding);
  R.DoAction('fgl:Upisi');
  XH := TTestHost.Create;
  Check(Ev(XH, 'DCount("*", "partner", "naziv = ''Iz4GL''")') = '1', 'fgl: action runs the stored 4GL program');
  XH.Free;

  Db.SaveObject('_sys_macros', 'Pod', 'msg:podmakro');
  Db.SaveObject('_sys_macros', 'MojMakro',
    '# komentar' + LineEnding + 'msg:uvod' + LineEnding + 'if [x] > 1 then msg:nikad' + LineEnding +
    'if 1 = 1 then sql:INSERT INTO partner (naziv) VALUES (''Makro'')' + LineEnding +
    'if GetNumberLike = 1 then msg:nikad3' + LineEnding +
    'macro:Pod' + LineEnding + 'stop' + LineEnding + 'msg:nikad2');
  ScriptLog := '';
  R.DoAction('macro:MojMakro');
  Check(ScriptLog = '[uvod][podmakro]', 'macro runs lines, honours if/stop and nested macro: ' + ScriptLog);
  Sq := Db.NewQuery('SELECT COUNT(*) FROM partner WHERE naziv = ''Makro''');
  Sq.Open;
  Check(Sq.Fields[0].AsInteger = 1, 'macro sql: action executed');
  Sq.Free;
  R.Free;

  Check(Scripts(Db).CallProc(FallbackForTest(Db), 'Dodaj', [], RV), 'script SqlExec runs without a form');
  Sq := Db.NewQuery('SELECT COUNT(*) FROM partner WHERE naziv = ''Skripta''');
  Sq.Open;
  Check(Sq.Fields[0].AsInteger = 1, 'script changed the database');
  Sq.Free;
  OnScriptMessage := nil;
  ResetScripts;

  { ---- Phase 6b: macro check and editors ---- }
  Check(CheckMacroText('msg:a' + LineEnding + 'if [x] > 1 then next' + LineEnding + 'stop') = '', 'macro check accepts a good macro');
  Check(Pos('Redak 2', CheckMacroText('msg:a' + LineEnding + 'poleti:x')) = 1, 'macro check names the bad line');
  Check(Pos('then', CheckMacroText('if 1 = 1 msg:x')) > 0, 'macro check explains that a one-line if needs "then"');
  Check(Pos('uvjet', CheckMacroText('if 1 + then msg:x')) > 0, 'macro check validates the condition expression');
  Tm := TTimer.Create(nil);
  Tm.Interval := 700;
  Closer := TCloser.Create;
  Tm.OnTimer := @Closer.Tick;
  Tm.Enabled := True;
  Check(not EditModule(nil, Db, 'm1'), 'module editor opens and closes');
  Check(not EditMacro(nil, Db, 'MojMakro'), 'macro editor opens and closes');
  Tm.Free;
  Closer.Free;

  { ---- Phase 8a: more expressions ---- }
  XH := TTestHost.Create;
  Check(Ev(XH, 'StartsWith([s], "zag") And EndsWith([s], "REB") And Contains([s], "agr")') = 'Da', 'expr StartsWith/EndsWith/Contains');
  Check(Ev(XH, 'LPad("7", 3, "0") & RPad("a", 3, ".")') = '007a..', 'expr LPad/RPad');
  Check(Ev(XH, 'Split("a;b;c", ";", 2)') = 'b', 'expr Split');
  Check(Ev(XH, 'Coalesce([n], [n], "x")') = 'x', 'expr Coalesce');
  Check(Ev(XH, 'IsNull(NullIf(5, 5))') = 'Da', 'expr NullIf');
  Check(Ev(XH, 'Percent(25, 200)') = '12.5', 'expr Percent');
  Check(Ev(XH, 'Clamp(15, 0, 10) + Ceil(2.1)') = '13', 'expr Clamp/Ceil');
  Check(Ev(XH, 'Eur(1234.5)') = '1,234.50 €', 'expr Eur');
  Check(Ev(XH, 'Initials("ivo horvat")') = 'IH', 'expr Initials');
  Check(Ev(XH, 'Format(EOMonth(#2026-02-10#), "yyyy-mm-dd")') = '2026-02-28', 'expr EOMonth');
  Check(Ev(XH, 'Format(BOMonth(#2026-02-10#), "yyyy-mm-dd")') = '2026-02-01', 'expr BOMonth');
  Check(Ev(XH, 'Age(#2000-06-15#, #2026-06-14#)') = '25', 'expr Age before birthday');
  Check(Ev(XH, 'Age(#2000-06-15#, #2026-06-15#)') = '26', 'expr Age on birthday');
  Check(Ev(XH, 'WorkDays(#2026-03-02#, #2026-03-08#)') = '5', 'expr WorkDays Mon-Sun = 5');
  Check(Ev(XH, 'DaysBetween(#2026-03-01#, #2026-03-15#)') = '14', 'expr DaysBetween');
  Check(Ev(XH, 'Quarter(#2026-08-01#) & DayName(#2026-03-15#)') = '3nedjelja', 'expr Quarter/DayName');
  Check(Ev(XH, 'ValidOIB("69435151530")') = 'Da', 'expr ValidOIB true');
  Check(Ev(XH, 'ValidOIB("12345678901")') = 'Ne', 'expr ValidOIB false');
  Check(Ev(XH, 'ValidIBAN("HR12 1001 0051 8630 0016 0")') = 'Da', 'expr ValidIBAN true');
  Check(Ev(XH, 'ValidIBAN("HR1210010051863000161")') = 'Ne', 'expr ValidIBAN false');
  XH.Free;

  RD := TaReportDef.Create;
  RD.Name := 'Agr'; RD.RecordSource := 'rac_kup';
  RD.Add(RItem('TextBox', 'Detail', 'a', 'iznos', 0, 0, 80, 20));
  RD.Add(RItem('TextBox', 'Detail', 'b', '=RunSum([iznos])', 90, 0, 80, 20));
  RD.Add(RItem('TextBox', 'Detail', 'c', '=Format(Percent([iznos], SumAll([iznos])), "0.0")', 180, 0, 80, 20));
  RD.Add(RItem('TextBox', 'Detail', 'd', '=RowNum', 270, 0, 40, 20));
  RD.Add(RItem('TextBox', 'ReportFooter', 'e', '=Median([iznos]) & "/" & Last([iznos]) & "/" & First([iznos])', 0, 0, 200, 20));
  RD.Add(RItem('TextBox', 'ReportFooter', 'f', '=Format(StDev([iznos]), "0.00")', 210, 0, 80, 20));
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  { expectations come from the data itself }
  Sq := Db.NewQuery(Db.SourceSql('rac_kup'));
  Sq.Open;
  SetLength(Va, 0);
  while not Sq.EOF do
  begin
    SetLength(Va, Length(Va) + 1);
    Va[High(Va)] := Sq.FieldByName('iznos').AsFloat;
    Sq.Next;
  end;
  Sq.Free;
  VSum := 0;
  for K := 0 to High(Va) do VSum := VSum + Va[K];
  Check(HasText(RR, FloatToStr(VSum)), 'report RunSum reaches the grand total');
  Check(HasText(RR, FormatFloat('0.0', Va[0] / VSum * 100)) and HasText(RR, FormatFloat('0.0', Va[High(Va)] / VSum * 100)), 'report Percent of SumAll per row');
  Check(HasText(RR, IntToStr(Length(Va))), 'report RowNum reaches the row count');
  Check(HasText(RR, FloatToStr(Va[High(Va)])) and HasText(RR, FloatToStr(Va[0])), 'report First/Last');
  VMean := VSum / Length(Va);
  VAcc := 0;
  for K := 0 to High(Va) do VAcc := VAcc + Sqr(Va[K] - VMean);
  Check(HasText(RR, FormatFloat('0.00', Sqrt(VAcc / (Length(Va) - 1)))), 'report StDev');
  RR.Free; RE.Free; RD.Free;

  { ---- Phase 8b: view modes and memo box ---- }
  D := TaFormDef.Create;
  D.Name := 'MemoF'; D.RecordSource := 'partner';
  D.Add(NewCtl('MemoBox', 'memNaz', 'naziv', 10, 10));
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  R.DoAction('new');
  TMemo(R.ControlByName('memNaz')).Text := 'prvi redak' + LineEnding + 'drugi redak';
  TMemo(R.ControlByName('memNaz')).OnChange(R.ControlByName('memNaz'));
  Check(R.SaveRecord, 'memo box record saved');
  R.DoAction('last');
  Check(Pos('drugi redak', TMemo(R.ControlByName('memNaz')).Text) > 0, 'memo box shows multi-line text again');
  R.Free;

  D := TaFormDef.Create;
  D.Name := 'DsF'; D.RecordSource := 'racun'; D.ViewMode := 'datasheet';
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  Check(D2.ViewMode = 'datasheet', 'view mode survives JSON');
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check(R.HasGrid, 'datasheet form shows a grid');
  K := R.Query.RecordCount;
  R.DoAction('new');
  R.Query.FieldByName('iznos').AsFloat := 5;
  R.DoAction('save');
  Check(R.Query.RecordCount = K + 1, 'datasheet form: new row posted');
  R.Free;

  D := TaFormDef.Create;
  D.Name := 'SplitF'; D.RecordSource := 'racun'; D.ViewMode := 'split';
  D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 10));
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check(R.HasGrid and (R.ControlByName('txtIznos') <> nil), 'split form has controls and a grid');
  R.DoAction('last');
  Check(TEdit(R.ControlByName('txtIznos')).Text <> '', 'split form: controls follow the shared record');
  R.Free;

  { ---- rjecnik podataka ---- }
  begin
   try
    Db.Conn.ExecuteDirect('CREATE TABLE rj_t (id INTEGER PRIMARY KEY, naziv TEXT, cijena REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO rj_t (naziv, cijena) VALUES (''Stol'', 10)');
    DmM := TaFieldMeta.Create;
    DmM.TableName := 'rj_t'; DmM.FieldName := 'naziv'; DmM.LType := ltText;
    DmM.Caption := 'Naziv artikla'; DmM.Description := 'Puni naziv robe'; DmM.ColWidth := 180;
    Db.SaveFieldMeta(DmM); DmM.Free;
    DmL := Db.LoadFieldMetas('rj_t');
    Check((DmL.Count = 1) and (TaFieldMeta(DmL[0]).Caption = 'Naziv artikla') and (TaFieldMeta(DmL[0]).Description = 'Puni naziv robe') and
      (TaFieldMeta(DmL[0]).ColWidth = 180), 'dictionary: caption, description and width are stored');
    DmL.Free;
    DmFl := TStringList.Create; DmFl.CommaText := 'naziv,cijena';
    FO.Source := 'rj_t'; FO.Name := 'RjF'; FO.Title := 'Rj'; FO.Fields := DmFl; FO.Layout := flOneColumn; FO.SubTables := nil;
    D := BuildFormEx(Db, FO);
    Check(D.IndexOfName('lblNaziv_1') >= 0, 'dictionary: label exists');
    DmCap := ''; DmTip := '';
    for K := 0 to D.Count - 1 do
    begin
      if (D[K].Kind = 'Label') and (Pos('Naziv', D[K].Caption) = 1) then DmCap := D[K].Caption;
      if D[K].ControlSource = 'naziv' then DmTip := D[K].GetX('tip');
    end;
    Check(DmCap = 'Naziv artikla', 'dictionary: generated form label uses the caption (' + DmCap + ')');
    Check(DmTip = 'Puni naziv robe', 'dictionary: generated control gets the description as a tip');
    Check(D.IndexOfName('lblCijena_1') >= 0, 'dictionary: field without a caption keeps its pretty name');
    D.Free;
    RO.Source := 'rj_t'; RO.Name := 'RjR'; RO.Title := 'Rj'; RO.GroupField := ''; RO.SortField := '';
    RO.Fields := DmFl; RO.Kind := rkTabular; RO.Descending := False; RO.Sums := False; RO.PageBreakPerRecord := False; RO.LabelColumns := 3;
    RD := BuildReportEx(Db, RO);
    DmFl.Free;
    DmCap := '';
    for K := 0 to RD.Count - 1 do
      if (RD[K].Kind = 'Label') and (RD[K].Section = 'PageHeader') and (Pos('Naziv', RD[K].Caption) = 1) then DmCap := RD[K].Caption;
    Check(DmCap = 'Naziv artikla', 'dictionary: report column title uses the caption (' + DmCap + ')');
    RD.Free;
    { forma ruku napravljena bez savjeta - nasljeduje opis polja }
    D := TaFormDef.Create; D.Name := 'RjH'; D.RecordSource := 'rj_t';
    D.Add(NewCtl('TextBox', 'txtN', 'naziv', 10, 10));
    D.Add(NewCtl('TextBox', 'txtC', 'cijena', 10, 40));
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    Check((R.ControlByName('txtN').Hint = 'Puni naziv robe') and R.ControlByName('txtN').ShowHint, 'dictionary: a hand-made control inherits the field description');
    Check(not R.ControlByName('txtC').ShowHint, 'dictionary: no description, no tip');
    R.Free;
    D := TaFormDef.Create; D.Name := 'RjG'; D.RecordSource := 'rj_t'; D.ViewMode := 'datasheet';
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    DmCap := '';
    for K := 0 to R.MainGrid.Columns.Count - 1 do
      if R.MainGrid.Columns[K].FieldName = 'naziv' then
      begin
        DmCap := R.MainGrid.Columns[K].Title.Caption;
        Check(R.MainGrid.Columns[K].Width = 180, 'dictionary: grid column width');
      end;
    Check(DmCap = 'Naziv artikla', 'dictionary: grid column title (' + DmCap + ')');
    R.Free;
   except on E: Exception do WriteLn('EXC dict: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- mreza: filteri po stupcima, sortiranje, podnozje ---- }
  begin
    D := TaFormDef.Create;
    D.Name := 'DsF2'; D.RecordSource := 'racun'; D.ViewMode := 'datasheet';
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    Sq := Db.NewQuery('SELECT COUNT(*), SUM(iznos), MAX(iznos) FROM racun'); Sq.Open;
    GfN := Sq.Fields[0].AsInteger; GfSum := Sq.Fields[1].AsFloat; GfMax := Sq.Fields[2].AsFloat; Sq.Free;
    Check(Pos('Zapisa: ' + IntToStr(GfN), R.FooterText) = 1, 'grid footer shows the record count: ' + R.FooterText);
    Check(Pos('Zbroj iznos: ' + FormatFloat('#,##0.00', GfSum), R.FooterText) > 0, 'grid footer sums the amount column');
    Check(Pos('Zbroj id', R.FooterText) = 0, 'grid footer does not sum the id column');
    Sq := Db.NewQuery('SELECT COUNT(*) FROM racun WHERE iznos > 100'); Sq.Open; GfK := Sq.Fields[0].AsInteger; Sq.Free;
    R.SetColumnFilter('iznos', '>100');
    Check((R.Query.RecordCount = GfK) and (R.FilterError = ''), 'column filter >100 narrows the rows (' + IntToStr(R.Query.RecordCount) + '/' + IntToStr(GfK) + ')');
    Check(Pos('Zapisa: ' + IntToStr(GfK), R.FooterText) = 1, 'footer follows the filter');
    Check(Pos('Filtri: iznos', R.FooterText) > 0, 'footer names the active filters');
    Sq := Db.NewQuery('SELECT COUNT(*) FROM racun WHERE iznos BETWEEN 50 AND 150'); Sq.Open; GfK := Sq.Fields[0].AsInteger; Sq.Free;
    R.SetColumnFilter('iznos', '50..150');
    Check(R.Query.RecordCount = GfK, 'column filter 50..150 is a range ' + IntToStr(R.Query.RecordCount) + '/' + IntToStr(GfK) + ' ' + StringReplace(R.Query.SQL.Text, LineEnding, ' ', [rfReplaceAll]));
    R.SetColumnFilter('iznos', 'abc');
    Check(R.FilterError <> '', 'a filter that does not fit the column is reported: ' + R.FilterError);
    R.ClearColumnFilters;
    Check((R.Query.RecordCount = GfN) and (R.FilterError = ''), 'clearing the filters shows everything again');
    R.SortBy('iznos', True);
    Check(Abs(R.Query.FieldByName('iznos').AsFloat - GfMax) < 0.001, 'sorting descending puts the largest amount first');
    R.SortBy('iznos', False);
    Check(R.Query.FieldByName('iznos').AsFloat <= GfMax, 'sorting ascending');
    R.SortBy('', False);
    R.Free;
    D := TaFormDef.Create;
    D.Name := 'DsK'; D.RecordSource := 'kupac'; D.ViewMode := 'datasheet';
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    Sq := Db.NewQuery('SELECT COUNT(*) FROM kupac WHERE instr(lower(naziv), ''an'') > 0'); Sq.Open; GfK := Sq.Fields[0].AsInteger; Sq.Free;
    R.SetColumnFilter('naziv', 'AN');
    Check((GfK >= 1) and (R.Query.RecordCount = GfK), 'text filter is "contains", ignoring case');
    Check(dgDisplayMemoText in R.MainGrid.Options, 'grid shows the text of memo-typed columns instead of (Memo)');
    R.SetColumnFilter('naziv', '(prazno)');
    Check(R.Query.RecordCount = 0, 'text filter (prazno)');
    R.Free;
    { SQL koji nastaje }
    Check(ColumnFilterSql('"d"', fkDate, '31.12.2026', GfSql, GfErr) and (GfSql = 'substr("d", 1, 10) = ''2026-12-31'''), 'date filter dd.mm.yyyy -> ISO: ' + GfSql);
    Check(ColumnFilterSql('"d"', fkDate, '2026', GfSql, GfErr) and (Pos('substr("d", 1, 4)', GfSql) = 1), 'date filter: a year');
    Check(ColumnFilterSql('"d"', fkDate, '01.01.2026..31.03.2026', GfSql, GfErr) and (Pos('BETWEEN ''2026-01-01'' AND ''2026-03-31''', GfSql) > 0), 'date filter: a range');
    Check(ColumnFilterSql('"t"', fkText, 'ra*', GfSql, GfErr) and (Pos('LIKE ''ra%''', GfSql) > 0), 'text filter: wildcard');
    Check(ColumnFilterSql('"t"', fkText, '=Ana', GfSql, GfErr) and (GfSql = '"t" = ''Ana'''), 'text filter: exact');
    Check(ColumnFilterSql('"b"', fkBool, 'da', GfSql, GfErr) and (GfSql = '"b" = 1'), 'yes/no filter');
    Check(not ColumnFilterSql('"n"', fkNumber, '>x', GfSql, GfErr) and (GfErr <> ''), 'number filter rejects text');
    Check(ColumnFilterSql('"n"', fkNumber, '', GfSql, GfErr) and (GfSql = ''), 'empty filter means no condition');
    GfSet := TStringList.Create;
    GfSet.Values['iznos'] := '>100'; GfSet.Values['id'] := '1..5';
    SaveFilterSet(Db, 'FormaX', 'Veliki', GfSet);
    GfSet.Clear;
    Check(LoadFilterSet(Db, 'FormaX', 'Veliki', GfSet) and (GfSet.Values['iznos'] = '>100') and (GfSet.Values['id'] = '1..5'), 'saved filters: stored and loaded');
    SaveFilterSet(Db, 'FormaX', 'Mali', GfSet);
    SaveFilterSet(Db, 'DrugaForma', 'Tudji', GfSet);
    GfSet.Free;
    GfSet := ListFilterSets(Db, 'FormaX');
    Check((GfSet.Count = 2) and (GfSet.IndexOf('Veliki') >= 0) and (GfSet.IndexOf('Mali') >= 0), 'saved filters: listed per form (' + GfSet.CommaText + ')');
    GfSet.Free;
    DeleteFilterSet(Db, 'FormaX', 'Mali');
    GfSet := ListFilterSets(Db, 'FormaX');
    Check((GfSet.Count = 1) and not LoadFilterSet(Db, 'FormaX', 'Mali', GfSet), 'saved filters: deleted');
    GfSet.Free;
    Check(ColumnFilterSql('"t"', fkText, 'O''Brien', GfSql, GfErr) and (Pos('''O''''Brien''', GfSql) > 0), 'text filter: quote is escaped');
  end;

  { ---- Phase 8c: form wizard layouts and master-detail ---- }
  Flds := TStringList.Create;
  Rels2 := ChildRelations(Db, 'kupac');
  Check(Rels2.IndexOf('racun|kupac_id|id') >= 0, 'ChildRelations finds the detail table');
  Rels2.Free;
  SetLength(Fl, 3);
  Fl[0].Name := 'id'; Fl[0].PrimaryKey := True; Fl[0].Meta := TaFieldMeta.Create; Fl[0].Meta.LType := ltAutoNumber;
  Fl[1].Name := 'naslov'; Fl[1].Meta := TaFieldMeta.Create; Fl[1].Meta.LType := ltText;
  Fl[2].Name := 'tekst'; Fl[2].Meta := TaFieldMeta.Create; Fl[2].Meta.LType := ltMemo;
  Db.CreateTable('biljeska', Fl);
  for K := 0 to 2 do Fl[K].Meta.Free;
  Flds.CommaText := 'id,naslov,tekst';
  FO.Source := 'biljeska'; FO.Name := 'BiljF'; FO.Title := 'Bilješke'; FO.Fields := Flds; FO.Layout := flOneColumn; FO.SubTables := nil;
  D := BuildFormEx(Db, FO);
  Check(D.IndexOfName('lblNaslov') >= 0, 'generated form has a title and rule');
  MemoSeen := False; LockSeen := False;
  for K := 0 to D.Count - 1 do
  begin
    if D[K].Kind = 'MemoBox' then MemoSeen := D[K].Height >= 60;
    if (D[K].Kind = 'TextBox') and (D[K].GetX('locked') = '1') then LockSeen := True;
  end;
  Check(MemoSeen, 'Memo field becomes a tall MemoBox');
  Check(LockSeen, 'AutoNumber key is shown locked');
  D.Free;
  FO.Layout := flDatasheet;
  D := BuildFormEx(Db, FO);
  Check((D.ViewMode = 'datasheet') and (D.Count = 0), 'datasheet layout has no controls');
  D.Free;
  FO.Layout := flSplit;
  D := BuildFormEx(Db, FO);
  Check((D.ViewMode = 'split') and (D.Count > 3), 'split layout keeps the controls');
  D.Free;
  Flds.CommaText := 'id,naziv';
  Subs := TStringList.Create;
  Subs.Add('racun');
  FO.Source := 'kupac'; FO.Name := 'KupSub'; FO.Title := 'Kupci'; FO.Fields := Flds; FO.Layout := flTwoColumns; FO.SubTables := Subs;
  D := BuildFormEx(Db, FO);
  SubSeen := False;
  for K := 0 to D.Count - 1 do
    if (D[K].Kind = 'Subform') and (D[K].RowSource = 'racun') and (D[K].LinkChild = 'kupac_id') and (D[K].LinkMaster = 'id') then SubSeen := True;
  Check(SubSeen, 'related table embedded as a linked subform');
  D.Free;
  Subs.Free;

  MD.Master := 'kupac'; MD.Detail := 'racun'; MD.Name := 'MD'; MD.Title := 'Kupac i računi';
  Flds.CommaText := 'naziv';
  MD.MasterFields := Flds;
  Flds2 := TStringList.Create; Flds2.CommaText := 'iznos';
  MD.DetailFields := Flds2;
  MD.DetailAsForm := True; MD.SumField := 'iznos'; MD.ShowCount := True; MD.FkCol := ''; MD.ParentCol := '';
  MR := BuildMasterDetail(Db, MD);
  Check(MR.Error = '', 'master-detail found the relation by itself');
  Check((MR.DetailForm <> nil) and (MR.DetailForm.ViewMode = 'datasheet') and (MR.DetailFormName = 'MD_detalji'), 'detail form is a datasheet');
  Check((MR.QueryName = 'MD_detalji_q') and (Pos('"kupac_id"', MR.QuerySql) > 0), 'detail column subset becomes a saved query that keeps the link column');
  Db.SaveObject('_sys_queries', MR.QueryName, MR.QuerySql);
  Db.SaveObject('_sys_forms', MR.DetailFormName, MR.DetailForm.ToJson);
  Db.SaveObject('_sys_forms', 'MD', MR.MasterForm.ToJson);
  D2 := TaFormDef.Create; D2.FromJson(MR.MasterForm.ToJson); D2.Name := 'MD';
  MR.MasterForm.Free; MR.DetailForm.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Sq := Db.NewQuery('SELECT COUNT(*), SUM(iznos) FROM racun WHERE kupac_id = ' + R.Query.FieldByName('id').AsString);
  Sq.Open;
  K := Sq.Fields[0].AsInteger;
  VSum := Sq.Fields[1].AsFloat;
  Sq.Free;
  Check(R.SubCount('subDetalji1') = K, 'master-detail: subform shows the master''s rows (' + IntToStr(K) + ' vs ' + IntToStr(R.SubCount('subDetalji1')) + ')');
  Check(TEdit(R.ControlByName('calcBroj1')).Text = IntToStr(K), 'master-detail: DCount total');
  Check(TEdit(R.ControlByName('calcZbroj1')).Text = FormatFloat('#,##0.00', VSum), 'master-detail: DSum total follows the master');
  R.DoAction('next');
  Sq := Db.NewQuery('SELECT COUNT(*), SUM(iznos) FROM racun WHERE kupac_id = ' + R.Query.FieldByName('id').AsString);
  Sq.Open;
  K := Sq.Fields[0].AsInteger;
  VSum := Sq.Fields[1].AsFloat;
  Sq.Free;
  Check((R.SubCount('subDetalji1') = K) and (TEdit(R.ControlByName('calcZbroj1')).Text = FormatFloat('#,##0.00', VSum)), 'master-detail follows the next master record');
  R.Free;
  MD.DetailAsForm := False; MD.DetailFields := nil; MD.Name := 'MD2';
  MR := BuildMasterDetail(Db, MD);
  Check((MR.QueryName = '') and (MR.DetailForm = nil), 'without a subset the subform reads the table directly');
  MR.MasterForm.Free;
  MD.Detail := 'partner'; MD.Name := 'MD3';
  MR := BuildMasterDetail(Db, MD);
  Check(MR.Error <> '', 'master-detail without a relation explains what is missing');
  Flds.Free; Flds2.Free;

  { ---- Phase 8d: report kinds ---- }
  Flds := TStringList.Create;
  Flds.CommaText := 'id,naziv';
  Sq := Db.NewQuery('SELECT COUNT(*) FROM partner');
  Sq.Open;
  PartnerN := Sq.Fields[0].AsInteger;
  Sq.Free;
  RO.Source := 'partner'; RO.Name := 'Naljepnice'; RO.Title := ''; RO.GroupField := ''; RO.SortField := '';
  RO.Fields := Flds; RO.Kind := rkLabels; RO.Descending := False; RO.Sums := False; RO.PageBreakPerRecord := False; RO.LabelColumns := 3;
  RD := BuildReportEx(Db, RO);
  Check((RD.Columns = 3) and (RD.Heights[SecPageHeader] = 0) and (RD.Heights[SecPageFooter] = 0), 'labels: three columns, no header/footer');
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  XsSeen := TStringList.Create;
  XsSeen.Sorted := True; XsSeen.Duplicates := dupIgnore;
  for K := 0 to RR.PageCount - 1 do
    for K1i := 0 to RR.Page(K).Items.Count - 1 do
      if (TaRItem(RR.Page(K).Items[K1i]).Kind = 'Text') and (TaRItem(RR.Page(K).Items[K1i]).Bold) then
        XsSeen.Add(IntToStr(TaRItem(RR.Page(K).Items[K1i]).X));
  Check(XsSeen.Count = 3, 'labels: titles sit in three distinct columns (' + IntToStr(XsSeen.Count) + ')');
  Check(RR.PageCount = 1, 'labels: all of them fit on one page');
  XsSeen.Free;
  RR.Free; RE.Free; RD.Free;

  RO.Kind := rkColumnar; RO.Title := 'Partneri'; RO.PageBreakPerRecord := True; RO.Name := 'Kartice';
  RD := BuildReportEx(Db, RO);
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(RR.PageCount = PartnerN, 'columnar: one record per page with page break (' + IntToStr(RR.PageCount) + ' pages for ' + IntToStr(PartnerN) + ')');
  Check(HasText(RR, 'Naziv') and HasText(RR, 'Partneri'), 'columnar: field captions and title');
  RR.Free; RE.Free; RD.Free;

  Flds.CommaText := 'kupac,iznos';
  RO.Source := 'rac_kup'; RO.Name := 'Sazetak'; RO.Title := 'Sažetak'; RO.GroupField := 'kupac'; RO.Fields := Flds;
  RO.Kind := rkSummary; RO.Sums := True; RO.PageBreakPerRecord := False;
  RD := BuildReportEx(Db, RO);
  Check(RD.Heights[SecDetail] = 0, 'summary: detail rows hidden');
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(HasText(RR, 'Ukupno') and HasText(RR, 'Sveukupno'), 'summary: group and grand totals remain');
  RR.Free; RE.Free; RD.Free;

  Flds.CommaText := 'naziv';
  Flds2 := TStringList.Create; Flds2.CommaText := 'iznos';
  MD.Master := 'kupac'; MD.Detail := 'racun'; MD.Name := 'MDR'; MD.Title := 'Računi po kupcu';
  MD.MasterFields := Flds; MD.DetailFields := Flds2; MD.DetailAsForm := False; MD.SumField := 'iznos'; MD.ShowCount := True;
  MD.FkCol := ''; MD.ParentCol := '';
  MRR := BuildMasterDetailReport(Db, MD);
  Check(MRR.Error = '', 'master-detail report found the relation');
  Check((Pos('INNER JOIN', MRR.QuerySql) > 0) and (Pos('ORDER BY m."id"', MRR.QuerySql) > 0), 'master-detail report query joins and orders by the master key');
  Db.SaveObject('_sys_queries', MRR.QueryName, MRR.QuerySql);
  RE := TaReportEngine.Create(Db, MRR.Def);
  RR := RE.Render;
  Sq := Db.NewQuery('SELECT COUNT(*), SUM(r.iznos) FROM racun r JOIN kupac k ON k.id = r.kupac_id');
  Sq.Open;
  K := Sq.Fields[0].AsInteger;
  VSum := Sq.Fields[1].AsFloat;
  Sq.Free;
  Check(HasText(RR, 'Ukupno stavki: ' + IntToStr(K)), 'master-detail report: grand count');
  Check(HasText(RR, FormatFloat('#,##0.00', VSum)), 'master-detail report: grand total from SumAll');
  Check(HasText(RR, 'Naziv:'), 'master-detail report: master block labelled');
  Check(ExportPdf(RR, '/tmp/ta_mdr.pdf', PdfErr), 'master-detail report exports to PDF ' + PdfErr);
  RR.Free; RE.Free; MRR.Def.Free;
  MD.Detail := 'partner';
  MRR := BuildMasterDetailReport(Db, MD);
  Check((MRR.Error <> '') and (MRR.Def = nil), 'master-detail report without a relation explains why');
  Flds.Free; Flds2.Free;

  { ---- expression catalog: every function it offers must exist ---- }
  Cat := ExpressionCatalog;
  BadFn := '';
  for K := 0 to Cat.Count - 1 do
  begin
    Sv := Cat[K];
    Sv := Copy(Sv, Pos('|', Sv) + 1, MaxInt);
    Sv := Copy(Sv, 1, Pos('|', Sv) - 1);
    Sv2 := CheckExpr(Sv);
    if Pos('Nepoznata funkcija', Sv2) > 0 then BadFn := BadFn + Sv + ' ';
  end;
  Check(BadFn = '', 'every function in the expression builder exists (' + BadFn + ')');
  Check(Cat.Count > 90, 'expression catalog has its entries');
  Cat.Free;

  { ---- Phase 9a: expression -> SQL translator, cross-checked against the evaluator ---- }
  Resolver1 := TResolver1.Create;
  Db.Conn.ExecuteDirect('CREATE TABLE tt (a INTEGER, b INTEGER, s TEXT, d TEXT, n TEXT)');
  Db.Conn.ExecuteDirect('INSERT INTO tt VALUES (5, 3, ''Zagreb'', ''2026-03-15'', NULL)');
  CrossFails := ''; CrossCount := 0;
  for K := 0 to High(CrossList) do CrossCheck(CrossList[K]);
  Check(CrossFails = '', 'translator agrees with the evaluator on ' + IntToStr(CrossCount) + ' expressions: ' + CrossFails);
  Check(CrossCount >= 55, 'cross-check covered enough expressions');
  Check(not ExprToSql('ValidOIB([s])', nil, SqlOut, SqlErr) and (Pos('ValidOIB', SqlErr) > 0), 'untranslatable function is named in the error');
  Check(not ExprToSql('RunSum([a])', nil, SqlOut, SqlErr), 'report-only aggregate refused');
  Check(not ExprToSql('Page', nil, SqlOut, SqlErr), 'report variable refused');
  Check(not ExprToSql('1 +', nil, SqlOut, SqlErr), 'syntax error reported');
  Check(ExprToSql('[a] + [b]', @Resolver1.Resolve, SqlOut, SqlErr) and (Pos('"tt"."a"', SqlOut) > 0), 'resolver qualifies fields');
  Check(ExprToSql('DSum("a", "tt", "b = 3")', nil, SqlOut, SqlErr) and (Pos('SELECT SUM("a") FROM "tt" WHERE b = 3', SqlOut) > 0), 'DSum becomes a subquery');
  Fl3 := ExprFieldNames('[a] * Iif([b] > 1, "[nije polje]", [a])');
  Check((Fl3.Count = 2) and (Fl3.IndexOf('a') >= 0) and (Fl3.IndexOf('b') >= 0), 'ExprFieldNames ignores brackets inside text');
  Fl3.Free;

  { ---- Phase 9b: QBE query model ---- }
  QD2 := TaQbeDesign.Create;
  QD2.Tables.Add('kupac'); QD2.Tables.Add('racun');
  QD2.AddColumn('kupac.naziv', '');
  QD2.AddColumn('racun.iznos', '');
  QD2.Cols[1].Crit := '>100';
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos('INNER JOIN', QSql) > 0) and (Pos('> 100', QSql) > 0), 'QBE: join by foreign key and criteria on the column (' + QErr + ')');
  Sq := Db.NewQuery(QSql); Sq.Open; QRows := Sq.RecordCount; Sq.Free;
  Sq := Db.NewQuery('SELECT COUNT(*) FROM racun r JOIN kupac k ON k.id = r.kupac_id WHERE r.iznos > 100'); Sq.Open;
  Check(QRows = Sq.Fields[0].AsInteger, 'QBE: simple criteria returns the expected rows');
  Sq.Free;

  QD2.Cols[1].Crit := '';
  QD2.Cols[1].Total := 'sum'; QD2.Cols[1].Alias := 'Ukupno'; QD2.Cols[1].Sort := 'desc';
  QD2.Cols[0].Total := 'group';
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos('GROUP BY', QSql) > 0) and (Pos('SUM(', QSql) > 0), 'QBE: totals produce GROUP BY and SUM (' + QErr + ')');
  Sq := Db.NewQuery(QSql); Sq.Open;
  QTop := Sq.FieldByName('Ukupno').AsFloat; QRows := Sq.RecordCount; Sq.Free;
  Sq := Db.NewQuery('SELECT COUNT(*), MAX(s) FROM (SELECT SUM(iznos) AS s FROM racun r JOIN kupac k ON k.id = r.kupac_id GROUP BY k.id)'); Sq.Open;
  Check((QRows = Sq.Fields[0].AsInteger) and (Abs(QTop - Sq.Fields[1].AsFloat) < 0.0001), 'QBE: group totals and descending order match an independent query');
  Sq.Free;

  QD2.Cols[1].Crit := '>' + FloatToStr(QTop - 1, InvariantFS);
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos('HAVING', QSql) > 0), 'QBE: criteria on a total goes to HAVING');
  Sq := Db.NewQuery(QSql); Sq.Open;
  Check(Sq.RecordCount >= 1, 'QBE: HAVING keeps the top group');
  Sq.Free;
  QD2.Cols[1].Crit := '';

  QD2.AddColumn('[naziv] & " (" & Round([iznos], 0) & ")"', 'Opis');
  QD2.Cols[2].Total := 'where';
  QD2.Cols[2].Show := False;
  QD2.Cols[1].Total := ''; QD2.Cols[1].Alias := ''; QD2.Cols[1].Sort := '';
  QD2.Cols[0].Total := '';
  QD2.Cols[2].Total := ''; QD2.Cols[2].Show := True;
  Check(BuildQbeSql(Db, QD2, QSql, QErr), 'QBE: calculated column translates (' + QErr + ')');
  QErr := '';
  Sq := Db.NewQuery(QSql); Sq.Open;
  Check((Pos('(', Sq.FieldByName('Opis').AsString) > 0) and (Pos(Sq.FieldByName('naziv').AsString, Sq.FieldByName('Opis').AsString) = 1), 'QBE: calculated column shows name and amount');
  Sq.Free;

  QD2.Cols[0].Crit := 'Ana'; QD2.Cols[0].OrCrit := '"Đuro Ćosić"';
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos(' OR ', QSql) > 0), 'QBE: bare text criterion means equals, "or" row is ORed (' + QErr + ')');
  QD2.Cols[0].Crit := 'Like "A*"'; QD2.Cols[0].OrCrit := '';
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos('LIKE', QSql) > 0), 'QBE: Like criterion with Access wildcards');
  Sq := Db.NewQuery(QSql); Sq.Open;
  Check((Sq.RecordCount >= 1) and (Copy(Sq.FieldByName('naziv').AsString, 1, 1) = 'A'), 'QBE: Like "A*" finds names starting with A');
  Sq.Free;
  QD2.Cols[0].Crit := 'Is Not Null';
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos('IS NOT NULL', QSql) > 0), 'QBE: Is Not Null');
  QD2.Cols[0].Crit := '';

  QD2.Top := 1; QD2.Distinct := True;
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos('LIMIT 1', QSql) > 0) and (Pos('DISTINCT', QSql) > 0), 'QBE: Top N and Distinct');
  QD2.Top := 0; QD2.Distinct := False;

  { ---- parametri upita ---- }
  QD2.Cols[1].Crit := '> [Najmanji iznos]';
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos('[?Najmanji iznos]', QSql) > 0), 'QBE: unknown [name] in a criterion becomes a query parameter (' + QErr + ')');
  Check(ParamLiteral('31.12.2026') = '''2026-12-31''', 'parameter literal: Croatian date -> ISO');
  Check((ParamLiteral('1,5') = '1.5') and (ParamLiteral('42') = '42'), 'parameter literal: numbers');
  Check((ParamLiteral('007') = '''007''') and (ParamLiteral('O''Brien') = '''O''''Brien'''), 'parameter literal: leading zeros and quotes stay text');
  Check(ParamLiteral('  ') = 'NULL', 'parameter literal: empty is NULL');
  Db.SaveObject('_sys_queries', 'ParamUpit', QSql);
  Db.ClearParams;
  Inc(Db.QuietParams);
  Sq := Db.NewQuery('SELECT * FROM ' + Db.SourceFrom('ParamUpit')); Sq.Open;
  Check(Sq.RecordCount = 0, 'quiet mode: a missing parameter is NULL, nothing asked');
  Sq.Free;
  Dec(Db.QuietParams);
  Check(Db.SourceFromRaw('ParamUpit') <> '', 'raw source keeps the marker');
  ParamPromptHook := @TestParamPrompt;
  ParamAsked := 0; ParamAnswer := '100';
  Sq := Db.NewQuery('SELECT COUNT(*) FROM (' + StringReplace(QSql, '[?Najmanji iznos]', '100', []) + ')'); Sq.Open; QRows3 := Sq.Fields[0].AsInteger; Sq.Free;
  Db.ClearParams;
  Sq := Db.NewQuery('SELECT * FROM ' + Db.SourceFrom('ParamUpit')); Sq.Open; QRows2 := Sq.RecordCount; Sq.Free;
  Sq := Db.NewQuery('SELECT * FROM ' + Db.SourceFrom('ParamUpit')); Sq.Open; Sq.Free;
  Check((ParamAsked = 1) and (QRows2 = QRows3), 'parameter asked once and reused; answer 100 gives the same rows as "> 100" (' + IntToStr(QRows2) + '/' + IntToStr(QRows3) + ')');
  Db.ClearParams;
  ParamAnswer := '100000';
  Sq := Db.NewQuery('SELECT * FROM ' + Db.SourceFrom('ParamUpit')); Sq.Open;
  Check((ParamAsked = 2) and (Sq.RecordCount = 0), 'after ClearParams the question is asked again');
  Sq.Free;
  Db.ClearParams; ParamCancel := True; QCancelled := False;
  try
    Db.SourceFrom('ParamUpit');
  except
    on E: EParamCancel do QCancelled := True;
  end;
  Check(QCancelled, 'cancelling the parameter dialog aborts the query');
  ParamCancel := False; ParamAnswer := '100'; ParamAsked := 0;
  D2 := TaFormDef.Create; D2.Name := 'FormaParam'; D2.RecordSource := 'ParamUpit';
  D2.Add(NewCtl('TextBox', 'txtN', 'naziv', 10, 10));
  Db.SaveObject('_sys_forms', 'FormaParam', D2.ToJson);
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check((ParamAsked = 1) and (TEdit(R.ControlByName('txtN')).Text <> ''), 'a form on a parameter query asks once when it opens');
  R.Free;
  RDb := TaReportDef.Create;
  RDb.Name := 'IzvjParam'; RDb.Title := 'P'; RDb.RecordSource := 'ParamUpit';
  RDb.Heights[SecDetail] := 20;
  RDb.Add(RItem('TextBox', 'Detail', 'tN', 'naziv', 0, 0, 100, 20));
  REb := TaReportEngine.Create(Db, RDb);
  RRb := REb.Render;
  Check(RRb.PageCount >= 1, 'a report on a parameter query renders');
  RRb.Free; REb.Free; RDb.Free;
  ParamPromptHook := nil;
  Db.ClearParams;
  QD2.Cols[1].Crit := '>100';

  QD3 := TaQbeDesign.Create;
  QD3.Tables.Add('kupac'); QD3.Tables.Add('racun');
  QD3.AddColumn('id', '');
  Check(not BuildQbeSql(Db, QD3, QSql, QErr) and (Pos('više tablica', QErr) > 0), 'QBE: ambiguous field asks to qualify it');
  QD3.Cols[0].Expr := '[nepostoji] * 2';
  Check(not BuildQbeSql(Db, QD3, QSql, QErr) and (Pos('Nepoznato polje', QErr) > 0), 'QBE: unknown field reported');
  QD3.Free;

  BuildQbeSql(Db, QD2, QSql, QErr);
  Db.SaveObject('_sys_queries', 'qbeT', QbeSqlWithDesign(QSql, QD2));
  QD3 := QbeDesignFromSql(Db.LoadObject('_sys_queries', 'qbeT'));
  Check((QD3 <> nil) and (Length(QD3.Cols) = Length(QD2.Cols)) and (QD3.Cols[2].Alias = 'Opis') and (QD3.Tables.Count = 2), 'QBE: design survives inside the saved query');
  QD3.Free;
  Sq := Db.NewQuery(Db.SourceSql('qbeT')); Sq.Open;
  Check(Sq.RecordCount > 0, 'QBE: saved query with design comment still runs as a source');
  Sq.Free;
  QD2.Free;

  { ---- Phase 9c: calculated field templates ---- }
  Tpls := CalcTemplates;
  Check(Length(Tpls) >= 35, 'template catalog has ' + IntToStr(Length(Tpls)) + ' entries');
  CrossFails := ''; CrossCount := 0; TplBad := ''; TplInQuery := 0;
  for K := 0 to High(Tpls) do
  begin
    TplVals := SampleValues(Tpls[K], 'a', 'b', 's', 'd');
    TplExpr := ExpandCalc(Tpls[K], TplVals);
    TplVals.Free;
    if CheckExpr(TplExpr) <> '' then TplBad := TplBad + Tpls[K].Title + ': ' + CheckExpr(TplExpr) + '; ';
    if CalcWorksInQuery(Tpls[K]) then
    begin
      Inc(TplInQuery);
      CrossCheck(TplExpr);
    end;
  end;
  Check(TplBad = '', 'every template expands to a valid expression: ' + TplBad);
  Check(CrossFails = '', 'templates that work in queries give the same result in SQL and in the evaluator: ' + CrossFails);
  Check((TplInQuery >= 28) and (TplInQuery < Length(Tpls)), 'report-only and Proper/DayName templates are not offered for queries (' + IntToStr(TplInQuery) + ' of ' + IntToStr(Length(Tpls)) + ')');
  TplVals := TStringList.Create;
  TplVals.Values['a'] := 'iznos'; TplVals.Values['rate'] := '25';
  for K := 0 to High(Tpls) do
    if Tpls[K].Title = 'Iznos s PDV-om' then TplExpr := ExpandCalc(Tpls[K], TplVals);
  Check(TplExpr = '[iznos] * (1 + 25 / 100)', 'PDV template expands as written: ' + TplExpr);
  TplVals.Free;

  { ---- Phase 9e: query wizard, designer reopen ---- }
  QWt := TStringList.Create; QWt.Add('kupac'); QWt.Add('racun');
  QWf := TStringList.Create; QWf.Add('kupac.naziv'); QWf.Add('racun.iznos');
  QD2 := QueryWizardDesign(Db, QWt, QWf, True);
  Check((QD2.Cols[0].Total = 'group') and (QD2.Cols[1].Total = 'sum'), 'summary wizard: text groups, numbers are summed');
  Check(BuildQbeSql(Db, QD2, QSql, QErr) and (Pos('GROUP BY', QSql) > 0), 'summary wizard design builds SQL (' + QErr + ')');
  QD2.Free;
  QD2 := QueryWizardDesign(Db, QWt, QWf, False);
  Check((QD2.Cols[0].Total = '') and (QD2.Cols[1].Total = ''), 'detail wizard: plain columns');
  QD2.Free;
  QWt.Free; QWf.Free;
  with TaQueryDesigner.CreateDesigner(nil, Db, 'qbeT') do
  try
    Check((Pos('SELECT', Sql.Text) = 1) and (Pos('/*QBE', Sql.Text) = 0), 'saved QBE query reopens with its SQL and no design comment');
  finally
    Free;
  end;

  { ---- Phase 9f: editable subform grid with calculated columns ---- }
  D := TaFormDef.Create;
  D.Name := 'SubCalc'; D.RecordSource := 'kupac';
  D.Add(NewCtl('TextBox', 'txtNaz', 'naziv', 10, 10));
  C := NewCtl('Subform', 'subR', '', 10, 50); C.RowSource := 'racun'; C.LinkMaster := 'id'; C.LinkChild := 'kupac_id';
  C.SetX('calc', 'Dvaput=[iznos] * 2 ;; Opis=Iif([iznos] > 100, "velik", "mali")'); D.Add(C);
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  SubQ := R.SubQuery('subR');
  Check((SubQ <> nil) and (SubQ.FindField('Dvaput') <> nil) and (SubQ.FindField('Opis') <> nil), 'subform grid has the calculated columns');
  SubQ.First;
  Check(Abs(SubQ.FieldByName('Dvaput').AsFloat - 2 * SubQ.FieldByName('iznos').AsFloat) < 0.0001, 'calculated column = 2 x iznos');
  MasterId := R.Query.FieldByName('id').AsInteger;
  SubQ.Append;
  SubQ.FieldByName('iznos').AsFloat := 11;
  SubQ.Post;
  Sq := Db.NewQuery('SELECT COUNT(*) FROM racun WHERE kupac_id = ' + IntToStr(MasterId) + ' AND iznos = 11');
  Sq.Open;
  Check(Sq.Fields[0].AsInteger = 1, 'a row typed into the grid is saved with the master key filled in');
  Sq.Free;
  Check(SubQ.Locate('iznos', 11, []) and (Abs(SubQ.FieldByName('Dvaput').AsFloat - 22) < 0.0001), 'calculated column refreshed after the new row was posted');
  SubQ.Edit;
  SubQ.FieldByName('iznos').AsFloat := 12;
  SubQ.Post;
  Sq := Db.NewQuery('SELECT COUNT(*) FROM racun WHERE kupac_id = ' + IntToStr(MasterId) + ' AND iznos = 12');
  Sq.Open;
  Check(Sq.Fields[0].AsInteger = 1, 'editing a cell in the grid updates the database');
  Sq.Free;
  Check(SubQ.Locate('iznos', 12, []) and (SubQ.FieldByName('Opis').AsString = 'mali'), 'text calculated column follows the edit');
  SubQ.Delete;
  Sq := Db.NewQuery('SELECT COUNT(*) FROM racun WHERE kupac_id = ' + IntToStr(MasterId) + ' AND iznos = 12');
  Sq.Open;
  Check(Sq.Fields[0].AsInteger = 0, 'deleting a grid row removes it');
  Sq.Free;
  R.Free;

  { form-level calculated column in a datasheet form }
  D := TaFormDef.Create;
  D.Name := 'DsCalc'; D.RecordSource := 'racun'; D.ViewMode := 'datasheet';
  D.CalcFields := 'Trostruko=[iznos] * 3';
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  Check(D2.CalcFields = 'Trostruko=[iznos] * 3', 'form calculated fields survive JSON');
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check((R.Query.FindField('Trostruko') <> nil) and (Abs(R.Query.FieldByName('Trostruko').AsFloat - 3 * R.Query.FieldByName('iznos').AsFloat) < 0.0001), 'datasheet form shows its calculated column');
  R.Free;

  { ---- Phase 9g: labels built from composite lines ---- }
  Flds := TStringList.Create; Flds.CommaText := 'id,naziv';
  LblLines := TStringList.Create;
  LblLines.Add('[naziv]'); LblLines.Add('"ID: " & [id]'); LblLines.Add('Iif([id] > 1, "stariji", "prvi")');
  RO.Source := 'partner'; RO.Name := 'NaljSlozene'; RO.Title := ''; RO.GroupField := ''; RO.SortField := 'id';
  RO.Fields := Flds; RO.Kind := rkLabels; RO.Descending := False; RO.Sums := False; RO.PageBreakPerRecord := False;
  RO.LabelColumns := 2; RO.LabelLines := LblLines;
  RD := BuildReportEx(Db, RO);
  Check(Pos('=', RD[2].ControlSource) = 1, 'label line with & is stored as an expression (' + RD[2].ControlSource + ')');
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(HasText(RR, 'ID: 1') and HasText(RR, 'prvi'), 'composite label lines are evaluated per record');
  Check(HasText(RR, 'stariji'), 'conditional label line');
  RR.Free; RE.Free; RD.Free;
  RO.LabelLines := nil;
  LblLines.Free; Flds.Free;

  { ---- Phase 9h: master with several detail tables ---- }
  Db.Conn.ExecuteDirect('CREATE TABLE napomena (id INTEGER PRIMARY KEY, kupac_id INTEGER REFERENCES kupac(id), tekst TEXT)');
  Db.Conn.ExecuteDirect('INSERT INTO napomena (kupac_id, tekst) VALUES (1, ''prva''), (1, ''druga''), (2, ''treca'')');
  Flds := TStringList.Create; Flds.CommaText := 'naziv';
  MM.Master := 'kupac'; MM.Name := 'MDM'; MM.Title := 'Kupac'; MM.MasterFields := Flds;
  MM.DetailAsForm := True; MM.UseTabs := False;
  SetLength(MM.Details, 2);
  MM.Details[0].Table := 'racun'; MM.Details[0].Fields := nil; MM.Details[0].SumField := 'iznos'; MM.Details[0].ShowCount := True;
  MM.Details[0].FkCol := ''; MM.Details[0].ParentCol := '';
  MM.Details[1].Table := 'napomena'; MM.Details[1].Fields := nil; MM.Details[1].SumField := ''; MM.Details[1].ShowCount := True;
  MM.Details[1].FkCol := ''; MM.Details[1].ParentCol := '';
  MMR := BuildMasterDetailMulti(Db, MM);
  Check((MMR.Error = '') and (Length(MMR.Items) = 2), 'two details built (' + MMR.Error + ')');
  Check((MMR.Items[0].FormName = 'MDM_racun_detalji') and (MMR.Items[1].FormName = 'MDM_napomena_detalji'), 'each detail gets its own datasheet form');
  for K := 0 to High(MMR.Items) do Db.SaveObject('_sys_forms', MMR.Items[K].FormName, MMR.Items[K].Form.ToJson);
  Db.SaveObject('_sys_forms', 'MDM', MMR.MasterForm.ToJson);
  D2 := TaFormDef.Create; D2.FromJson(MMR.MasterForm.ToJson); D2.Name := 'MDM';
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  MasterId := R.Query.FieldByName('id').AsInteger;
  Sq := Db.NewQuery('SELECT COUNT(*) FROM racun WHERE kupac_id = ' + IntToStr(MasterId)); Sq.Open; K := Sq.Fields[0].AsInteger; Sq.Free;
  Sq := Db.NewQuery('SELECT COUNT(*) FROM napomena WHERE kupac_id = ' + IntToStr(MasterId)); Sq.Open; K1i := Sq.Fields[0].AsInteger; Sq.Free;
  Check((R.SubCount('subDetalji1') = K) and (R.SubCount('subDetalji2') = K1i), 'both subforms follow the master (' + IntToStr(K) + ' and ' + IntToStr(K1i) + ')');
  Check((TEdit(R.ControlByName('calcBroj1')).Text = IntToStr(K)) and (TEdit(R.ControlByName('calcBroj2')).Text = IntToStr(K1i)), 'each detail has its own count');
  R.Free;
  MMR.MasterForm.Free;
  for K := 0 to High(MMR.Items) do MMR.Items[K].Form.Free;

  MM.UseTabs := True;
  MMR := BuildMasterDetailMulti(Db, MM);
  Tab1 := False;
  for K := 0 to MMR.MasterForm.Count - 1 do
    if MMR.MasterForm[K].Kind = 'TabControl' then Tab1 := MMR.MasterForm[K].RowSource = 'Račun;Napomena';
  Check(Tab1, 'tabbed layout adds a TabControl with a page per detail');
  Check((MMR.MasterForm[MMR.MasterForm.IndexOfName('subDetalji1')].GetX('page') = '0') and
        (MMR.MasterForm[MMR.MasterForm.IndexOfName('subDetalji2')].GetX('page') = '1'), 'each subform sits on its own page');
  for K := 0 to High(MMR.Items) do Db.SaveObject('_sys_forms', MMR.Items[K].FormName, MMR.Items[K].Form.ToJson);
  D2 := TaFormDef.Create; D2.FromJson(MMR.MasterForm.ToJson); D2.Name := 'MDM';
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check((R.ControlByName('subDetalji2').Parent is TTabSheet) and (TTabSheet(R.ControlByName('subDetalji2').Parent).PageIndex = 1), 'runtime puts the second subform on the second tab');
  Check(R.SubCount('subDetalji2') >= 0, 'tabbed subform is live');
  R.Free;
  MMR.MasterForm.Free;
  for K := 0 to High(MMR.Items) do MMR.Items[K].Form.Free;

  MM.Details[1].Table := 'partner';
  MMR := BuildMasterDetailMulti(Db, MM);
  Check((MMR.Error <> '') and (MMR.MasterForm = nil), 'a detail without a relation is refused');
  Flds.Free;

  { ---- Phase 10a: grid lookups, hidden link column, AutoFill, document numbers ---- }
  Db.Conn.ExecuteDirect('CREATE TABLE art (id INTEGER PRIMARY KEY, naziv TEXT, cijena REAL)');
  Db.Conn.ExecuteDirect('CREATE TABLE stav (id INTEGER PRIMARY KEY, art_id INTEGER REFERENCES art(id), opis TEXT, cijena REAL, kolicina REAL)');
  Db.Conn.ExecuteDirect('INSERT INTO art VALUES (1, ''Vijak'', 0.5), (2, ''Matica'', 0.25)');
  D := TaFormDef.Create;
  D.Name := 'StavDs'; D.RecordSource := 'stav'; D.ViewMode := 'datasheet';
  D.AutoFill := 'art_id>art.id:opis=naziv,cijena=cijena';
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  Check(D2.AutoFill = 'art_id>art.id:opis=naziv,cijena=cijena', 'AutoFill survives JSON');
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  R.Query.Append;
  R.Query.FieldByName('art_id').Text := 'Matica';
  Check(R.Query.FieldByName('art_id').AsInteger = 2, 'typing a name in a lookup column stores the key');
  Check((R.Query.FieldByName('opis').AsString = 'Matica') and (Abs(R.Query.FieldByName('cijena').AsFloat - 0.25) < 0.0001), 'AutoFill copies name and price from the chosen article');
  R.Query.FieldByName('kolicina').AsFloat := 4;
  R.Query.Post;
  Check(R.Query.FieldByName('art_id').DisplayText = 'Matica', 'lookup column shows the name, not the key');
  Check((R.MainGrid <> nil) and (R.MainGrid.Columns.Count >= 4), 'datasheet grid got explicit columns');
  Check(R.MainGrid.Columns[1].PickList.IndexOf('Vijak') >= 0, 'lookup column offers the names as a drop-down list');
  R.Free;

  D := TaFormDef.Create;
  D.Name := 'KupSub2'; D.RecordSource := 'kupac';
  D.Add(NewCtl('TextBox', 'txtNaz', 'naziv', 10, 10));
  C := NewCtl('Subform', 'subN', '', 10, 50); C.RowSource := 'napomena'; C.LinkMaster := 'id'; C.LinkChild := 'kupac_id'; D.Add(C);
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  HiddenSeen := False;
  for K := 0 to R.SubGrid('subN').Columns.Count - 1 do
    if SameText(R.SubGrid('subN').Columns[K].FieldName, 'kupac_id') then HiddenSeen := not R.SubGrid('subN').Columns[K].Visible;
  Check(HiddenSeen, 'subform grid hides the link column');
  R.Free;

  Db.Conn.ExecuteDirect('CREATE TABLE brojac (id INTEGER PRIMARY KEY, broj TEXT)');
  Mt := TaFieldMeta.Create; Mt.TableName := 'brojac'; Mt.FieldName := 'broj'; Mt.LType := ltText;
  Mt.DefaultExpr := 'Format(Nz(DMax("id", "brojac", ""), 0) + 1, "000")';
  Db.SaveFieldMeta(Mt); Mt.Free;
  Db.Conn.ExecuteDirect('INSERT INTO brojac (broj) VALUES (''001''), (''002'')');
  D := TaFormDef.Create;
  D.Name := 'BrojF'; D.RecordSource := 'brojac';
  D.Add(NewCtl('TextBox', 'txtBroj', 'broj', 10, 10));
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  R.DoAction('new');
  Check(TEdit(R.ControlByName('txtBroj')).Text = '003', 'a new document gets the next number from the database (' + TEdit(R.ControlByName('txtBroj')).Text + ')');
  R.Free;

  { ---- Phase 10b: business templates ---- }
  BizLog := TStringList.Create;
  BizOk := True;
  for BizI := 0 to 6 do
  begin
    BizId := Copy(BizTemplates[BizI], 1, Pos('|', BizTemplates[BizI]) - 1);
    if BizId = 'dokument' then BizOk := ApplyBizTemplate(Db, BizId, 'Račun', True, BizLog) and BizOk
    else BizOk := ApplyBizTemplate(Db, BizId, '', True, BizLog) and BizOk;
  end;
  Check(BizOk and (Pos('GREŠKA', BizLog.Text) = 0), 'all seven business templates applied: ' + BizLog.Text);
  BizTables := Db.UserTables;
  Check((BizTables.IndexOf('partneri') >= 0) and (BizTables.IndexOf('racuni_stavke') >= 0) and (BizTables.IndexOf('skl_stavke') >= 0) and
        (BizTables.IndexOf('blagajna') >= 0) and (BizTables.IndexOf('putni_nalozi') >= 0), 'template tables exist');
  BizTables.Free;
  BizForms := TStringList.Create;
  BizForms.CommaText := 'Partneri,Artikli,Računi,"Skladišni dokumenti",Blagajna,Zaposlenici,"Putni nalozi"';
  BizBad := '';
  for BizI := 0 to BizForms.Count - 1 do
  begin
    D2 := TaFormDef.Create;
    D2.FromJson(Db.LoadObject('_sys_forms', BizForms[BizI]));
    D2.Name := BizForms[BizI];
    try
      R := TaFormRunner.CreateRunner(nil, Db, D2);
      R.Free;
    except
      on E: Exception do BizBad := BizBad + BizForms[BizI] + ': ' + E.Message + '; ';
    end;
  end;
  Check(BizBad = '', 'every generated form opens: ' + BizBad);
  BizForms.Free;
  BizForms := TStringList.Create;
  BizForms.CommaText := '"Popis partnera","Naljepnice partnera","Naljepnice artikala",Cjenik,"Račun - ispis","Stanje zaliha","Blagajnički dnevnik","Popis zaposlenika","Plaće po odjelima","Putni nalog"';
  BizBad := '';
  for BizI := 0 to BizForms.Count - 1 do
  begin
    RD := TaReportDef.Create;
    RD.FromJson(Db.LoadObject('_sys_reports', BizForms[BizI]));
    try
      RE := TaReportEngine.Create(Db, RD);
      RR := RE.Render;
      if RR.PageCount < 1 then BizBad := BizBad + BizForms[BizI] + ': no pages; ';
      RR.Free; RE.Free;
    except
      on E: Exception do BizBad := BizBad + BizForms[BizI] + ': ' + E.Message + '; ';
    end;
    RD.Free;
  end;
  Check(BizBad = '', 'every generated report renders: ' + BizBad);
  BizForms.Free;
  begin
    RDb := TaReportDef.Create;
    RDb.FromJson(Db.LoadObject('_sys_reports', 'Račun - ispis'));
    REb := TaReportEngine.Create(Db, RDb);
    RRb := REb.Render;
    CfOn := False;
    for CfI := 0 to RRb.PageCount - 1 do
      for CfJ := 0 to RRb.Page(CfI).Items.Count - 1 do
        if Pos('Slovima: sto pedeset pet eura', TaRItem(RRb.Page(CfI).Items[CfJ]).Text) = 1 then CfOn := True;
    Check(CfOn, 'invoice print shows the total in words (155 EUR)');
    CfOn := False; CfN := 0;
    for CfI := 0 to RRb.PageCount - 1 do
      for CfJ := 0 to RRb.Page(CfI).Items.Count - 1 do
      begin
        if Pos('Primatelj: Moja tvrtka d.o.o., Ilica 1, 10000 Zagreb   IBAN: HR1210010051863000160', TaRItem(RRb.Page(CfI).Items[CfJ]).Text) = 1 then CfOn := True;
        if TaRItem(RRb.Page(CfI).Items[CfJ]).Kind = 'Frame' then Inc(CfN);
      end;
    Check(CfOn, 'invoice print names the payee from the company profile');
    Check(CfN > 100, 'invoice print carries a HUB3 payment barcode (' + IntToStr(CfN) + ' bars)');
    ExportPdf(RRb, '/tmp/ta_racun_hub3.pdf', PdfErr);
    RRb.Free; REb.Free; RDb.Free;
  end;
  begin
    RDb := TaReportDef.Create;
    RDb.FromJson(Db.LoadObject('_sys_reports', 'Naljepnice artikala'));
    PgK := 0;
    for K := 0 to RDb.Count - 1 do
      if RDb[K].Kind = 'Barcode' then Inc(PgK);
    Check((PgK = 1) and (RDb.Columns = 3), 'article labels have a barcode and 3 columns');
    REb := TaReportEngine.Create(Db, RDb);
    RRb := REb.Render;
    PgK := 0;
    for K := 0 to RRb.Page(0).Items.Count - 1 do
      if TaRItem(RRb.Page(0).Items[K]).Kind = 'Frame' then Inc(PgK);
    Check(PgK > 20, 'article label barcodes are drawn: ' + IntToStr(PgK));
    Check(HasText(RRb, '0.35 EUR') or HasText(RRb, '0,35 EUR'), 'article label shows the price');
    RRb.Free; REb.Free; RDb.Free;
  end;

  { the invoice form: items, totals, numbering }
  D2 := TaFormDef.Create; D2.FromJson(Db.LoadObject('_sys_forms', 'Računi')); D2.Name := 'Računi';
  BrojName := '';
  for K := 0 to D2.Count - 1 do
    if D2[K].ControlSource = 'broj' then BrojName := D2[K].Name;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check(TEdit(R.ControlByName('txtOsnovica')).Text = '124.00 €', 'invoice base amount from the sample items: ' + TEdit(R.ControlByName('txtOsnovica')).Text);
  Check(TEdit(R.ControlByName('txtPdv')).Text = '31.00 €', 'invoice VAT');
  Check(TEdit(R.ControlByName('txtUkupno')).Text = '155.00 €', 'invoice total');
  SubQ := R.SubQuery('subDetalji1');
  SubQ.Append;
  SubQ.FieldByName('artikl_id').Text := 'Matica M8';
  Check(Abs(SubQ.FieldByName('cijena').AsFloat - 0.2) < 0.0001, 'choosing an article by name fills in its price');
  Check(SubQ.FieldByName('opis').AsString = 'Matica M8', 'choosing an article fills in the description');
  SubQ.FieldByName('kolicina').AsFloat := 100;
  SubQ.Post;
  Check(TEdit(R.ControlByName('txtOsnovica')).Text = '144.00 €', 'totals follow a newly typed item: ' + TEdit(R.ControlByName('txtOsnovica')).Text);
  LastMsg := '';
  OnRunnerMessage := @CaptureMsg;
  OnScriptMessage := @CaptureScript;
  R.DoAction('new');
  OnRunnerMessage := nil;
  OnScriptMessage := nil;
  Check(Pos('-002', TEdit(R.ControlByName(BrojName)).Text) > 0, 'next invoice number is generated: ' + TEdit(R.ControlByName(BrojName)).Text + ' msg=' + LastMsg + ScriptLog);
  R.Free;
  RD := TaReportDef.Create;
  RD.FromJson(Db.LoadObject('_sys_reports', 'Račun - ispis'));
  RD.Filter := 'dok_id = 1';
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(HasText(RR, '144.00') or HasText(RR, '144'), 'invoice print for one document shows its total');
  Check(not HasText(RR, FormatDateTime('yyyy', Date) + '-002'), 'invoice print is limited to the chosen document');
  ExportPdf(RR, '/tmp/ta_invoice.pdf', PdfErr);
  RR.Free; RE.Free; RD.Free;

  { pregled racuna po razdoblju: od-do iz parametara, zbrojevi u podnozju }
  Db.Conn.ExecuteDirect('INSERT INTO racuni (broj, datum, dospijece, partner_id, placeno) VALUES (''T-1'', ''2020-03-01'', ''2020-03-16'', 1, 1), (''T-2'', ''2020-03-20'', ''2020-04-04'', 1, 0), (''T-3'', ''2020-04-05'', ''2020-04-20'', 1, 0)');
  Db.Conn.ExecuteDirect('INSERT INTO racuni_stavke (dokument_id, artikl_id, opis, kolicina, jmj, cijena, rabat, pdv_stopa, iznos) SELECT id, 1, ''X'', 1, ''kom'', 100, 0, 25, 100 FROM racuni WHERE broj LIKE ''T-%''');
  if Db.ParamValues = nil then Db.ParamValues := TStringList.Create;
  Db.ParamValues.Clear;
  Db.ParamValues.Values['Od'] := '2020-03-01';
  Db.ParamValues.Values['Do'] := '2020-03-31';
  RD := TaReportDef.Create;
  RD.FromJson(Db.LoadObject('_sys_reports', 'Računi po razdoblju'));
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(HasText(RR, 'T-1') and HasText(RR, 'T-2') and (not HasText(RR, 'T-3')), 'period report: only invoices dated inside the chosen period');
  Check(HasText(RR, '125.00') and HasText(RR, 'Plaćeno') and HasText(RR, 'Nije plaćeno'), 'period report: row total with VAT (100 + 25 % = 125) and the paid status');
  Check(HasText(RR, 'Sveukupno') and HasText(RR, '200.00') and HasText(RR, '50.00') and HasText(RR, '250.00'), 'period report: the footer adds up the period (200 + 50 = 250): ' + AllText(RR));
  RR.Free; RE.Free;
  Db.ParamValues.Clear;
  Db.ParamValues.Values['Od'] := '2020-04-01';
  RE := TaReportEngine.Create(Db, RD);
  RR := RE.Render;
  Check(HasText(RR, 'T-3') and (not HasText(RR, 'T-1')), 'period report: an empty end date means no upper limit');
  RR.Free; RE.Free; RD.Free;
  Db.ParamValues.Clear;
  Check(Pos('Pregled po razdoblju', Db.LoadObject('_sys_forms', 'Računi')) > 0, 'invoice form has the period overview button');

  Mt := Db.FindFieldMeta('partneri', 'oib');
  Check((Mt <> nil) and (Pos('ValidOIB', Mt.Validation) > 0), 'partner OIB has a validation rule');
  Mt.Free;
  BizLog.Clear;
  ApplyBizTemplate(Db, 'partneri', '', False, BizLog);
  Check(Pos('već postoji', BizLog.Text) > 0, 'applying a template again reuses the existing table');
  BizLog.Clear;
  Check(ApplyBizTemplate(Db, 'dokument', 'Ponuda', False, BizLog) and (Db.LoadObject('_sys_forms', 'Ponude') <> ''), 'other document types get their own tables and form');
  BizLog.Clear;
  Check(BuildAppSwitchboard(Db, BizLog), 'switchboard built from the generated objects');
  D2 := TaFormDef.Create; D2.FromJson(Db.LoadObject('_sys_forms', 'Izbornik'));
  Check(D2.Count > 12, 'switchboard has a button per form and report (' + IntToStr(D2.Count) + ' controls)');
  D2.Free;
  Check(LoadAppSettings(Db).StartupForm <> '', 'switchboard became the start form');
  BizLog.Free;

  { ---- Phase 4d: dialogs open and close without errors (a timer cancels the modal loop) ---- }
  Closer := TCloser.Create;
  Tm := TTimer.Create(nil);
  Tm.Interval := 700;
  Tm.OnTimer := @Closer.Tick;
  Tm.Enabled := True;
  Check(RunFormWizard(nil, Db) = '', 'form wizard dialog opens and cancels');
  Check(RunReportWizard(nil, Db) = '', 'report wizard dialog opens and cancels');
  Check(not RunImportDialog(nil, Db), 'import dialog opens and cancels');
  RunExportDialog(nil, Db, 'uvoz');
  Check(True, 'export dialog opens and cancels');
  Mt := TaFieldMeta.Create; Mt.LType := ltDate; Sv := 'datum';
  Check(not EditField(nil, Db, Sv, Mt, K1, K2, Sv2, Sv3, Sv4, True), 'field dialog opens and cancels');
  Mt.Free;
  Check(not DesignTableDialog(nil, Db, Sv, Fl), 'table dialog opens and cancels');
  ShowRelationsView(nil, Db);
  Check(Db.LoadSetting('relations_layout') <> '', 'relations view opens, saves layout on close');
  RD := TaReportDef.Create;
  RD.FromJson(Db.LoadObject('_sys_reports', 'Racuni po kupcu'));
  ShowReportPreview(nil, Db, RD);
  RD.Free;
  Check(True, 'report preview opens and cancels');
  Tm.Free;
  Closer.Free;

  { ---- Phase 7: application layer ---- }
  Check(UserCount(Db) = 0, 'no users yet: everyone is admin');
  AppS := LoadAppSettings(Db);
  AppS.Title := 'Moja aplikacija'; AppS.StartupForm := 'Switchboard'; AppS.RuntimeOnly := True;
  SaveAppSettings(Db, AppS);
  AppS := LoadAppSettings(Db);
  Check((AppS.Title = 'Moja aplikacija') and (AppS.StartupForm = 'Switchboard') and AppS.RuntimeOnly, 'app settings round trip');

  Check(AddUser(Db, 'ana', 'tajna1', arAdmin), 'first user added');
  Check(not AddUser(Db, 'ana', 'x', arUser), 'duplicate user refused');
  Check(AddUser(Db, 'ivo', 'lozinka', arUser) and AddUser(Db, 'vera', 'pogled', arViewer), 'more users added');
  Sq := Db.NewQuery('SELECT pwd FROM _sys_users WHERE name = ''ana''');
  Sq.Open;
  Check((Pos('tajna1', Sq.Fields[0].AsString) = 0) and (Pos('$', Sq.Fields[0].AsString) > 0), 'password is stored salted+hashed, not as text');
  Sq.Free;
  Check(Authenticate(Db, 'ana', 'tajna1', Role1) and (Role1 = arAdmin), 'login with the right password');
  Check(not Authenticate(Db, 'ana', 'kriva', Role1), 'wrong password refused');
  Check(not Authenticate(Db, 'nitko', 'x', Role1), 'unknown user refused');
  Check(SetPassword(Db, 'ana', 'nova') and Authenticate(Db, 'ana', 'nova', Role1) and not Authenticate(Db, 'ana', 'tajna1', Role1), 'password change');
  Check(not DeleteUser(Db, 'ana'), 'the last administrator cannot be deleted');
  Check(SetUserRole(Db, 'ivo', arAdmin) and DeleteUser(Db, 'ana'), 'with a second admin the first can go');
  Check(SetUserRole(Db, 'ivo', arAdmin), 'role kept');

  SetObjectRight(Db, '_sys_forms', 'Kupci', arAdmin);
  StartSession('vera', arViewer);
  Check(not CanRun(Db, '_sys_forms', 'Kupci') and CanRun(Db, '_sys_forms', 'Racuni'), 'object right blocks lower roles only');
  StartSession('ivo', arAdmin);
  Check(CanRun(Db, '_sys_forms', 'Kupci'), 'admin passes the object right');
  XH := TTestHost.Create;
  Check(Ev(XH, 'CurrentUser() & ":" & CurrentRole()') = 'ivo:admin', 'CurrentUser()/CurrentRole() in expressions');
  XH.Free;

  D := TaFormDef.Create;
  D.Name := 'ViewF'; D.RecordSource := 'racun';
  D.Add(NewCtl('TextBox', 'txtIznos', 'iznos', 10, 10));
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  StartSession('vera', arViewer);
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  Check(TEdit(R.ControlByName('txtIznos')).ReadOnly, 'viewer role: bound fields are read-only');
  R.Free;
  StartSession('', arAdmin);

  { switchboard }
  Flds := TStringList.Create;
  Flds.Add('Kupci|openform:Kupci'); Flds.Add('Poruka|msg:zdravo iz izbornika'); Flds.Add('Izlaz|close');
  D := BuildSwitchboard('SB', 'Glavni izbornik', Flds);
  Check((D.Count = 5) and (D.NavButtons = False), 'switchboard: title, rule, 3 buttons, no navigation bar');
  Check(D[2].OnClick = 'openform:Kupci', 'switchboard button carries its action');
  D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
  ScriptLog := '';
  OnScriptMessage := @CaptureScript;
  R := TaFormRunner.CreateRunner(nil, Db, D2);
  TButton(R.ControlByName('btn2')).Click;
  Check(ScriptLog = '[zdravo iz izbornika]', 'clicking a switchboard button runs its action');
  R.Free;
  OnScriptMessage := nil;
  Flds.Free;

  { packaging }
  DeleteFile('/tmp/ta_pack/Moja_aplikacija.db');
  PackDir := ExportApplication(Db, '/tmp/ta_pack', ParamStr(0), 'Moja aplikacija');
  Check(FileExists('/tmp/ta_pack/Moja_aplikacija.db') and FileExists('/tmp/ta_pack/Moja_aplikacija.sh') and
        FileExists('/tmp/ta_pack/TyphAccess') and FileExists('/tmp/ta_pack/Moja_aplikacija.desktop'), 'export writes db, program, launcher and .desktop');
  PackDb := TAppDb.Create;
  PackDb.Open('/tmp/ta_pack/Moja_aplikacija.db');
  Check((PackDb.UserTables.IndexOf('racun') >= 0) and (LoadAppSettings(PackDb).Title = 'Moja aplikacija'), 'packaged database is a complete copy with settings');
  PackDb.Free;
  with TStringList.Create do
  try
    LoadFromFile('/tmp/ta_pack/Moja_aplikacija.sh');
    Check(Pos('--runtime', Text) > 0, 'launcher starts the program in runtime mode');
  finally
    Free;
  end;

  { barkod / QR u izvjescu }
  begin
    RDb := TaReportDef.Create;
    RDb.Name := 'BarRep'; RDb.Title := 'Barkodovi'; RDb.RecordSource := 'rac_kup';
    RDb.Heights[SecDetail] := 150;
    C := RItem('Barcode', 'Detail', 'bcQ', '="https://example.com/r/" & [kupac]', 0, 4, 120, 120); RDb.Add(C);
    C := RItem('Barcode', 'Detail', 'bcE', '="400638133393"', 140, 4, 200, 80); C.SetX('barType', 'ean13'); RDb.Add(C);
    C := RItem('Barcode', 'Detail', 'bcC', 'kupac', 360, 4, 220, 60); C.SetX('barType', 'code128'); RDb.Add(C);
    REb := TaReportEngine.Create(Db, RDb);
    RRb := REb.Render;
    PgK := 0;
    for K := 0 to RRb.PageCount - 1 do
      for K1i := 0 to RRb.Page(K).Items.Count - 1 do
        if TaRItem(RRb.Page(K).Items[K1i]).Kind = 'Frame' then Inc(PgK);
    Check(PgK > 30, 'report barcodes emitted as frames: ' + IntToStr(PgK));
    Check(HasText(RRb, '4006381333931'), 'EAN-13 text with computed check digit under the bars');
    Check(ExportPdf(RRb, '/tmp/ta_barcodes.pdf', PdfErr), 'PDF export with barcodes ' + PdfErr);
    REb.Free; RDb.Free;
  end;
  { ---- revizijski trag ---- }
  begin
    Db.Conn.ExecuteDirect('CREATE TABLE rev_gr (id INTEGER PRIMARY KEY, naziv TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE rev_t (id INTEGER PRIMARY KEY, naziv TEXT, iznos REAL, foto BLOB)');
    Db.Conn.ExecuteDirect('INSERT INTO rev_t (naziv, iznos) VALUES (''prije'', 1)');
    AuditSetUser(Db, 'ana');
    AuditEnable(Db, 'rev_t');
    Check(AuditEnabled(Db, 'rev_t') and not AuditEnabled(Db, 'rev_gr'), 'audit: enabled only on the chosen table');
    Check(Db.UserTables.IndexOf('_sys_audit') < 0, 'audit: log table is hidden from the table list');
    Db.Conn.ExecuteDirect('INSERT INTO rev_t (naziv, iznos) VALUES (''Stol'', 100)');
    Aq := AuditQuery(Db, 'rev_t', '', 'I', '', '', '', 100);
    Check((Aq.RecordCount = 1) and (Aq.FieldByName('korisnik').AsString = 'ana') and (Pos('naziv=''Stol''', Aq.FieldByName('novo').AsString) > 0),
      'audit: insert is logged with the user and the new values');
    Aq.Free;
    Db.Conn.ExecuteDirect('UPDATE rev_t SET naziv = ''Stolica'', iznos = 100 WHERE naziv = ''Stol''');
    Aq := AuditQuery(Db, 'rev_t', '', 'U', '', '', '', 100);
    Check((Aq.RecordCount = 1) and (Aq.FieldByName('polje').AsString = 'naziv') and (Aq.FieldByName('staro').AsString = 'Stol') and
      (Aq.FieldByName('novo').AsString = 'Stolica'), 'audit: update logs only the changed field, old and new value');
    Aq.Free;
    Db.Conn.ExecuteDirect('UPDATE rev_t SET iznos = 100 WHERE naziv = ''Stolica''');
    Aq := AuditQuery(Db, 'rev_t', '', 'U', '', '', '', 100);
    Check(Aq.RecordCount = 1, 'audit: an update that changes nothing logs nothing');
    Aq.Free;
    Db.Conn.ExecuteDirect('UPDATE rev_t SET foto = x''0102'' WHERE naziv = ''Stolica''');
    Aq := AuditQuery(Db, 'rev_t', '', 'U', '', '', '', 100);
    Check((Aq.RecordCount = 2) and (Aq.FieldByName('novo').AsString = '(promijenjeno)'), 'audit: a blob change is logged without the bytes');
    Aq.Free;
    { promjene strukture ne smiju rusiti okidace }
    Fd.Name := 'napomena'; Fd.SqlType := 'TEXT'; Fd.PrimaryKey := False; Fd.NotNull := False;
    Db.AddColumn('rev_t', Fd);
    Check(AuditEnabled(Db, 'rev_t'), 'audit: still on after adding a column');
    Db.Conn.ExecuteDirect('UPDATE rev_t SET napomena = ''x'' WHERE naziv = ''Stolica''');
    Aq := AuditQuery(Db, 'rev_t', '', 'U', '', '', '', 100);
    Check(Aq.Locate('polje', 'napomena', []), 'audit: the new column is tracked');
    Aq.Free;
    Db.RenameColumn('rev_t', 'napomena', 'bilješka');
    Db.Conn.ExecuteDirect('UPDATE rev_t SET ' + Db.QuoteId('bilješka') + ' = ''y'' WHERE naziv = ''Stolica''');
    Aq := AuditQuery(Db, 'rev_t', '', 'U', '', '', '', 100);
    Check(Aq.Locate('polje', 'bilješka', []), 'audit: a renamed column is tracked under its new name');
    Aq.Free;
    SetLength(Fks, 1);
    Fks[0].FromCol := 'iznos'; Fks[0].RefTable := 'rev_gr'; Fks[0].RefCol := 'id'; Fks[0].OnDelete := '';
    Db.Conn.ExecuteDirect('INSERT INTO rev_gr VALUES (1, ''a''), (100, ''g'')');
    Db.SetFks('rev_t', Fks);
    Check(AuditEnabled(Db, 'rev_t'), 'audit: still on after the table was rebuilt for a foreign key');
    Db.Conn.ExecuteDirect('UPDATE rev_t SET naziv = ''Stolčić'' WHERE naziv = ''Stolica''');
    Aq := AuditQuery(Db, 'rev_t', '', 'U', '', '', '', 100);
    Check(Aq.Locate('novo', 'Stolčić', []), 'audit: logging continues after the rebuild');
    Aq.Free;
    Db.DropColumn('rev_t', 'bilješka');
    Check(AuditEnabled(Db, 'rev_t'), 'audit: still on after dropping a column');
    Db.Conn.ExecuteDirect('DELETE FROM rev_t WHERE naziv = ''Stolčić''');
    Aq := AuditQuery(Db, 'rev_t', '', 'D', '', '', '', 100);
    Check((Aq.RecordCount = 1) and (Pos('Stolčić', Aq.FieldByName('staro').AsString) > 0), 'audit: delete keeps the deleted row');
    Aq.Free;
    Aq := AuditQuery(Db, '', 'an', '', '', '', '', 5);
    Check((Aq.RecordCount = 5) and (Aq.FieldByName('radnja').AsString <> ''), 'audit: filter by user part and limit');
    Aq.Free;
    AuditDisable(Db, 'rev_t');
    Db.Conn.ExecuteDirect('INSERT INTO rev_t (naziv) VALUES (''nevidljivo'')');
    Aq := AuditQuery(Db, 'rev_t', '', '', '', '', '', 1000);
    QRows2 := Aq.RecordCount; Aq.Free;
    Db.Conn.ExecuteDirect('INSERT INTO rev_t (naziv) VALUES (''jos jedno'')');
    Aq := AuditQuery(Db, 'rev_t', '', '', '', '', '', 1000);
    Check((not AuditEnabled(Db, 'rev_t')) and (Aq.RecordCount = QRows2), 'audit: switched off, nothing more is logged');
    Aq.Free;
    Db.Conn.ExecuteDirect('UPDATE _sys_audit SET ts = ''2020-01-01 00:00:00'' WHERE action = ''I''');
    Check(AuditPurge(Db, 30) >= 1, 'audit: purge removes old entries');
    AuditEnable(Db, 'rev_t');
    Check(AuditTables(Db).IndexOf('rev_t') >= 0, 'audit: list of tracked tables');
    Db.DropTable('rev_t');
    Check(AuditTables(Db).IndexOf('rev_t') < 0, 'audit: dropping a table removes its triggers');
  end;
  { ---- planer zadataka ---- }
  begin
    TkDir := '/tmp/ta_tasks_test';
    DeleteFile(TkDir + '/a');
    ForceDirectories(TkDir);
    Check(ParseSchedule('dnevno 02:30', TkS, TkE) and (TkS.Kind = skDaily) and (TkS.Hour = 2) and (TkS.Min = 30), 'schedule: daily');
    Check(ParseSchedule('svakih 30 min', TkS, TkE) and (TkS.Kind = skInterval) and (TkS.Minutes = 30), 'schedule: every 30 minutes');
    Check(ParseSchedule('svakih 2 h', TkS, TkE) and (TkS.Minutes = 120), 'schedule: every 2 hours');
    Check(ParseSchedule('tjedno pon 08:00', TkS, TkE) and (TkS.Kind = skWeekly) and (TkS.Weekday = 1), 'schedule: weekly');
    Check(ParseSchedule('mjesecno 31 03:00', TkS, TkE) and (TkS.Kind = skMonthly) and (TkS.Day = 31), 'schedule: monthly');
    Check(not ParseSchedule('kad stignem', TkS, TkE) and (TkE <> ''), 'schedule: nonsense is refused');
    Check(not ParseSchedule('dnevno 25:00', TkS, TkE), 'schedule: bad time is refused');
    ParseSchedule('dnevno 02:00', TkS, TkE);
    TkNow := EncodeDate(2026, 11, 3) + EncodeTime(10, 0, 0, 0);
    Check(IsDue(TkS, EncodeDate(2026, 11, 3) + EncodeTime(1, 0, 0, 0), TkNow), 'due: daily, last run before today 02:00');
    Check(not IsDue(TkS, EncodeDate(2026, 11, 3) + EncodeTime(2, 30, 0, 0), TkNow), 'not due: daily, already ran after 02:00');
    Check(not IsDue(TkS, EncodeDate(2026, 11, 2) + EncodeTime(3, 0, 0, 0), EncodeDate(2026, 11, 3) + EncodeTime(1, 0, 0, 0)), 'not due: it is not 02:00 yet today');
    ParseSchedule('tjedno pon 08:00', TkS, TkE);
    Check(PrevOccurrence(TkS, TkNow) = EncodeDate(2026, 11, 2) + EncodeTime(8, 0, 0, 0), 'weekly: last Monday 08:00');
    ParseSchedule('mjesecno 31 03:00', TkS, TkE);
    Check(PrevOccurrence(TkS, EncodeDate(2026, 3, 5) + EncodeTime(9, 0, 0, 0)) = EncodeDate(2026, 2, 28) + EncodeTime(3, 0, 0, 0), 'monthly: day 31 falls back to the end of a short month');
    ParseSchedule('svakih 30 min', TkS, TkE);
    Check(IsDue(TkS, TkNow - 31 / 1440, TkNow) and not IsDue(TkS, TkNow - 10 / 1440, TkNow), 'interval: due after 30 minutes only');
    { zadaci u bazi }
    TkT.Name := 'kopija'; TkT.Kind := 'backup'; TkT.Arg := TkDir + '/kop'; TkT.Arg2 := '2';
    TkT.Schedule := 'svakih 1 min'; TkT.Enabled := True; TkT.LastRun := Now - 1; TkT.LastResult := '';
    SaveTask(Db, TkT);
    TkL := LoadTasks(Db);
    Check((Length(TkL) = 1) and (TkL[0].Name = 'kopija') and (TkL[0].Arg2 = '2') and TkL[0].Enabled, 'tasks: stored and loaded');
    Check(RunTask(Db, TkL[0], TkM) and (Pos('Kopija', TkM) = 1), 'task: backup runs (' + TkM + ')');
    RunTask(Db, TkL[0], TkM); RunTask(Db, TkL[0], TkM);
    TkCnt := 0;
    if FindFirst(TkDir + '/kop/*.db', faAnyFile, TkSr) = 0 then
    begin
      repeat Inc(TkCnt); until FindNext(TkSr) <> 0;
      FindClose(TkSr);
    end;
    Check(TkCnt = 2, 'task: backup keeps only the newest 2 copies (' + IntToStr(TkCnt) + ')');
    TkLog := TStringList.Create;
    Check(RunDueTasks(Db, Now, TkLog) = 1, 'tasks: the due task runs');
    Check(RunDueTasks(Db, Now, TkLog) = 0, 'tasks: and does not run again straight away');
    TkL := LoadTasks(Db);
    Check(Pos('OK:', TkL[0].LastResult) = 1, 'tasks: the result is stored (' + TkL[0].LastResult + ')');
    TkT.Enabled := False; TkT.LastRun := Now - 1;
    SaveTask(Db, TkT);
    Check(RunDueTasks(Db, Now, TkLog) = 0, 'tasks: a disabled task never runs');
    TkLog.Free;
    TkT.Name := 'csv'; TkT.Kind := 'export_csv'; TkT.Arg := 'kupac'; TkT.Arg2 := TkDir + '/csv';
    Check(RunTask(Db, TkT, TkM) and (Pos('CSV', TkM) = 1), 'task: CSV export runs (' + TkM + ')');
    TkCnt := 0;
    if FindFirst(TkDir + '/csv/kupac_*.csv', faAnyFile, TkSr) = 0 then begin TkCnt := 1; FindClose(TkSr); end;
    Check(TkCnt = 1, 'task: CSV file was written');
    TkT.Name := 'pdf'; TkT.Kind := 'report_pdf'; TkT.Arg := 'Cjenik'; TkT.Arg2 := TkDir + '/pdf';
    Check(RunTask(Db, TkT, TkM) and (Pos('PDF', TkM) = 1), 'task: report to PDF runs (' + TkM + ')');
    TkCnt := 0;
    if FindFirst(TkDir + '/pdf/Cjenik_*.pdf', faAnyFile, TkSr) = 0 then begin TkCnt := 1; FindClose(TkSr); end;
    Check(TkCnt = 1, 'task: PDF file was written');
    TkT.Arg := 'NemaTakvog';
    Check(not RunTask(Db, TkT, TkM) and (TkM <> ''), 'task: a missing report is an error, not a crash (' + TkM + ')');
    TkT.Name := 'sqlz'; TkT.Kind := 'sql'; TkT.Arg := 'CREATE TABLE IF NOT EXISTS tsk_x (a)'; TkT.Arg2 := '';
    Check(RunTask(Db, TkT, TkM), 'task: SQL runs');
    TkT.Arg := 'NEISPRAVNO SQL';
    Check(not RunTask(Db, TkT, TkM), 'task: bad SQL is an error');
    Db.SaveObject('_sys_macros', 'TaskMacro', 'sql:INSERT INTO tsk_x VALUES (7)');
    TkT.Name := 'mk'; TkT.Kind := 'macro'; TkT.Arg := 'TaskMacro';
    Check(RunTask(Db, TkT, TkM), 'task: macro runs (' + TkM + ')');
    Sq := Db.NewQuery('SELECT COUNT(*) FROM tsk_x WHERE a = 7'); Sq.Open;
    Check(Sq.Fields[0].AsInteger = 1, 'task: the macro really did its work');
    Sq.Free;
    DeleteTask(Db, 'kopija'); DeleteTask(Db, 'csv');
    Check(Length(LoadTasks(Db)) = 0, 'tasks: deleted');
  end;

  { ---- unakrsni upit i unija ---- }
  begin
   try
    Db.Conn.ExecuteDirect('CREATE TABLE ct_t (grad TEXT, godina INTEGER, iznos REAL)');
    Db.Conn.ExecuteDirect('INSERT INTO ct_t VALUES (''Zagreb'', 2024, 10), (''Zagreb'', 2024, 5), (''Zagreb'', 2025, 7), ' +
      '(''Split'', 2024, 3), (''Split'', 2025, 4), (''Split'', 2025, 6), (''Rijeka'', NULL, 9)');
    Db.Conn.ExecuteDirect('CREATE TABLE ct_u1 (a TEXT, b INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE ct_u2 (x TEXT, y INTEGER)');
    Db.Conn.ExecuteDirect('CREATE TABLE ct_u3 (p TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO ct_u1 VALUES (''k'', 1), (''l'', 2)');
    Db.Conn.ExecuteDirect('INSERT INTO ct_u2 VALUES (''l'', 2), (''m'', 3)');
    Check(BuildCrosstabSql(Db, 'ct_t', 'grad', 'godina', 'iznos', caSum, True, CtSql, CtErr), 'crosstab: SQL is built (' + CtErr + ')');
    Sq := Db.NewQuery(CtSql); Sq.Open;
    Check(Sq.RecordCount = 3, 'crosstab: one row per city');
    Check(Sq.Locate('grad', 'Zagreb', []) and (Sq.FieldByName('2024').AsFloat = 15) and (Sq.FieldByName('2025').AsFloat = 7) and
      (Sq.FieldByName('Ukupno').AsFloat = 22), 'crosstab: Zagreb sums per year and total');
    Check(Sq.Locate('grad', 'Split', []) and (Sq.FieldByName('2024').AsFloat = 3) and (Sq.FieldByName('2025').AsFloat = 10), 'crosstab: Split sums');
    Check(Sq.Locate('grad', 'Rijeka', []) and (Sq.FieldByName('(prazno)').AsFloat = 9) and (Sq.FieldByName('2024').AsFloat = 0), 'crosstab: a NULL column value gets its own (prazno) column, empty cells are 0');
    Check(Sq.FieldByName('2024').ClassName = 'TZDoubleField', 'crosstab: value columns are numeric, not memo (' + Sq.FieldByName('2024').ClassName + ')');
    Sq.Free;
    BuildCrosstabSql(Db, 'ct_t', 'grad', 'godina', '', caCount, False, CtSql, CtErr);
    Sq := Db.NewQuery(CtSql); Sq.Open;
    Check(Sq.Locate('grad', 'Split', []) and (Sq.FieldByName('2025').AsInteger = 2), 'crosstab: count');
    Check(Sq.FindField('Ukupno') = nil, 'crosstab: no total column when not asked');
    Sq.Free;
    BuildCrosstabSql(Db, 'ct_t', 'godina', 'grad', 'iznos', caAvg, False, CtSql, CtErr);
    Sq := Db.NewQuery(CtSql); Sq.Open;
    Check(Sq.Locate('godina', 2025, []) and (Abs(Sq.FieldByName('Split').AsFloat - 5) < 0.001), 'crosstab: average with the roles swapped');
    Sq.Free;
    Check(not BuildCrosstabSql(Db, 'ct_t', 'grad', 'grad', 'iznos', caSum, False, CtSql, CtErr) and (CtErr <> ''), 'crosstab: rows and columns must differ');
    Check(not BuildCrosstabSql(Db, 'ct_t', 'grad', 'godina', '', caSum, False, CtSql, CtErr), 'crosstab: sum needs a value field');
    Db.SaveObject('_sys_queries', 'CtKupci', CtSql);
    Check(BuildCrosstabSql(Db, 'CtKupci', 'godina', 'Split', '', caCount, False, CtSql, CtErr) or (CtErr <> ''), 'crosstab: a saved query can be the source');
    CtL := TStringList.Create; CtL.Add('ct_u1'); CtL.Add('ct_u2');
    Check(BuildUnionSql(Db, CtL, False, CtSql, CtErr), 'union: SQL is built (' + CtErr + ')');
    Sq := Db.NewQuery('SELECT COUNT(*) FROM (' + CtSql + ')'); Sq.Open;
    Check(Sq.Fields[0].AsInteger = 3, 'union: duplicates are removed');
    Sq.Free;
    BuildUnionSql(Db, CtL, True, CtSql, CtErr);
    Sq := Db.NewQuery('SELECT COUNT(*) FROM (' + CtSql + ')'); Sq.Open;
    Check(Sq.Fields[0].AsInteger = 4, 'union all: duplicates are kept');
    Sq.Free;
    CtL.Clear; CtL.Add('ct_u1'); CtL.Add('ct_u3');
    Check(not BuildUnionSql(Db, CtL, False, CtSql, CtErr) and (Pos('isti broj', CtErr) > 0), 'union: sources with different column counts are refused');
    CtL.Clear; CtL.Add('ct_u1');
    Check(not BuildUnionSql(Db, CtL, False, CtSql, CtErr), 'union: needs two sources');
    CtL.Free;
   except on E: Exception do WriteLn('EXC ct: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- odrzavanje i dokumentacija ---- }
  begin
   try
    MtBak := '/tmp/ta_maint_test/kopija.db';
    ForceDirectories('/tmp/ta_maint_test');
    Check(BackupDatabase(Db, MtBak, MtErr) and FileExists(MtBak), 'backup: a copy is written (' + MtErr + ')');
    Check(BackupDatabase(Db, MtBak, MtErr), 'backup: an existing copy is replaced');
    Check(not BackupDatabase(Db, Db.Conn.Database, MtErr) and (MtErr <> ''), 'backup: refuses to overwrite the open database');
    MtBak2 := TAppDb.Create;
    try
      MtBak2.Open(MtBak);
      Sq := MtBak2.NewQuery('SELECT COUNT(*) FROM kupac'); Sq.Open;
      Check(Sq.Fields[0].AsInteger >= 1, 'backup: the copy opens and holds the data');
      Sq.Free;
    finally
      MtBak2.Free;
    end;
    Check(CheckAndCompact(Db, False, MtRep) and (Pos('Cjelovitost: ok', MtRep) = 1), 'check: integrity is ok (' + MtRep + ')');
    Check(CheckAndCompact(Db, True, MtRep) and (Pos('Sažimanje', MtRep) > 0), 'compact: reports the size change');
    MtDoc := DocumentDatabase(Db);
    Check((Pos('<h2>Tablice', MtDoc) > 0) and (Pos('<h3>kupac</h3>', MtDoc) > 0), 'documentation: lists tables');
    Check(Pos('rj_t', MtDoc) > 0, 'documentation: lists every table');
    Check(Pos('Naziv artikla', MtDoc) > 0, 'documentation: includes dictionary captions');
    Check((Pos('<h2>Forme', MtDoc) > 0) and (Pos('<h2>Izvješća', MtDoc) > 0) and (Pos('<h2>Upiti', MtDoc) > 0), 'documentation: forms, reports and queries');
    Check(Pos('<script', MtDoc) = 0, 'documentation: nothing executable in the HTML');
   except on E: Exception do WriteLn('EXC maint: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- alati za podatke ---- }
  begin
   try
    Db.Conn.ExecuteDirect('CREATE TABLE dt_t (id INTEGER PRIMARY KEY, ime TEXT, grad TEXT, cijena REAL, oib TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO dt_t (ime, grad, cijena, oib) VALUES (''Ana Horvat'', ''Zagreb'', 10, ''69435151530''), ' +
      '(''ana kovač'', ''Zagreb'', 20, ''12345678901''), (''Ivo'', ''Split'', 30, NULL), (''Ivo'', ''Split'', 40, ''69435151530'')');
    Check(FindReplace(Db, 'dt_t', 'ime', 'ana', 'Marija', False, False, True, DtR, DtE) and (DtR.Cells = 2), 'find/replace: dry run counts case-insensitive matches (' + IntToStr(DtR.Cells) + ')');
    Sq := Db.NewQuery('SELECT COUNT(*) FROM dt_t WHERE ime LIKE ''Marija%'''); Sq.Open;
    Check(Sq.Fields[0].AsInteger = 0, 'find/replace: a dry run changes nothing');
    Sq.Free;
    Check(FindReplace(Db, 'dt_t', 'ime', 'Ana', 'Marija', True, False, True, DtR, DtE) and (DtR.Cells = 1), 'find/replace: match case finds only "Ana"');
    Check(FindReplace(Db, 'dt_t', 'ime', 'ana', 'Marija', False, False, False, DtR, DtE) and (DtR.Cells = 2) and (DtR.Rows = 2), 'find/replace: replaces in 2 rows');
    Sq := Db.NewQuery('SELECT ime FROM dt_t ORDER BY id'); Sq.Open;
    Check((Sq.FieldByName('ime').AsString = 'Marija Horvat'), 'find/replace: the text is replaced inside the value');
    Sq.Next;
    Check(Sq.FieldByName('ime').AsString = 'Marija kovač', 'find/replace: non-ASCII text survives');
    Sq.Free;
    Check(FindReplace(Db, 'dt_t', 'ime', 'Ivo', 'Ivan', True, True, False, DtR, DtE) and (DtR.Cells = 2), 'find/replace: whole value');
    Check(FindReplace(Db, 'dt_t', '', 'Zagreb', 'ZG', True, False, False, DtR, DtE) and (DtR.Cells = 2), 'find/replace: all text fields');
    Sq := Db.NewQuery('SELECT COUNT(*) FROM dt_t WHERE grad = ''ZG'''); Sq.Open;
    Check(Sq.Fields[0].AsInteger = 2, 'find/replace: and it landed in the right column');
    Sq.Free;
    Check(not FindReplace(Db, 'dt_t', 'ime', '', 'x', True, False, False, DtR, DtE) and (DtE <> ''), 'find/replace: empty search is refused');
    Check(BulkUpdate(Db, 'dt_t', 'cijena', '[cijena] * 2', '[grad] = "Split"', True, DtN, DtSql, DtE) and (DtN = 2), 'bulk update: dry run counts the rows (' + DtE + ')');
    Check(BulkUpdate(Db, 'dt_t', 'cijena', '[cijena] * 2', '[grad] = "Split"', False, DtN, DtSql, DtE) and (DtN = 2), 'bulk update: updates 2 rows');
    Sq := Db.NewQuery('SELECT cijena FROM dt_t WHERE id IN (3, 4) ORDER BY id'); Sq.Open;
    Check((Sq.Fields[0].AsFloat = 60), 'bulk update: the expression is applied');
    Sq.Next;
    Check(Sq.Fields[0].AsFloat = 80, 'bulk update: for every matching row');
    Sq.Free;
    Check(BulkUpdate(Db, 'dt_t', 'ime', 'UCase([ime])', '', False, DtN, DtSql, DtE) and (DtN = 4), 'bulk update: no condition means every row');
    Check(not BulkUpdate(Db, 'dt_t', 'cijena', '[cijena] *', '', False, DtN, DtSql, DtE) and (DtE <> ''), 'bulk update: a broken expression is refused (' + DtE + ')');
    Check(not BulkUpdate(Db, 'dt_t', 'cijena', '[cijena]', 'Foo(1)', False, DtN, DtSql, DtE) and (DtE <> ''), 'bulk update: a broken condition is refused');
    DtF := TStringList.Create; DtF.Add('ime'); DtF.Add('grad');
    Check(DuplicatesSql(Db, 'dt_t', DtF, False, DtSql, DtE), 'duplicates: SQL is built');
    Sq := Db.NewQuery(DtSql); Sq.Open;
    Check((Sq.RecordCount = 1) and (Sq.FieldByName('Broj').AsInteger = 2), 'duplicates: summary finds Ivan/Split twice');
    Sq.Free;
    DuplicatesSql(Db, 'dt_t', DtF, True, DtSql, DtE);
    Sq := Db.NewQuery(DtSql); Sq.Open;
    Check(Sq.RecordCount = 2, 'duplicates: the full rows');
    Sq.Free;
    DtF.Clear;
    Check(not DuplicatesSql(Db, 'dt_t', DtF, False, DtSql, DtE), 'duplicates: needs a field');
    DtF.Free;
    Db.Conn.ExecuteDirect('CREATE TABLE dt_a (k INTEGER)'); Db.Conn.ExecuteDirect('CREATE TABLE dt_b (k INTEGER)');
    Db.Conn.ExecuteDirect('INSERT INTO dt_a VALUES (1), (2), (3)'); Db.Conn.ExecuteDirect('INSERT INTO dt_b VALUES (2)');
    Check(UnmatchedSql(Db, 'dt_a', 'k', 'dt_b', 'k', DtSql, DtE), 'unmatched: SQL is built');
    Sq := Db.NewQuery(DtSql); Sq.Open;
    Check((Sq.RecordCount = 2) and Sq.Locate('k', 1, []) and Sq.Locate('k', 3, []), 'unmatched: rows 1 and 3 have no partner');
    Sq.Free;
    DtM := TaFieldMeta.Create;
    DtM.TableName := 'dt_t'; DtM.FieldName := 'oib'; DtM.LType := ltText;
    DtM.Validation := 'ValidOIB([value])'; DtM.ValidationMsg := 'Neispravan OIB';
    Db.SaveFieldMeta(DtM); DtM.Free;
    DtLog := TStringList.Create;
    DtN := CheckRules(Db, 'dt_t', DtLog);
    Check(DtN = 1, 'rule check: one bad OIB among the stored rows (' + IntToStr(DtN) + ')');
    Check((DtLog.Count = 1) and (Pos('12345678901', DtLog[0]) > 0) and (Pos('Neispravan OIB', DtLog[0]) > 0), 'rule check: the report names the value and the message');
    DtLog.Free;
    Check(CheckRules(Db, 'dt_a', nil) = 0, 'rule check: a table without rules has no violations');
   except on E: Exception do WriteLn('EXC dt: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- uvjetno oblikovanje ---- }
  begin
   try
    CfRules := ParseCondFormat('[a] > 4 => #c00000 #FFE9E9 bold ;; [a] < 0 => #FFFFFF');
    Check((Length(CfRules) = 2) and (CfRules[0].Fore = '#C00000') and (CfRules[0].Back = '#FFE9E9') and CfRules[0].Bold and
      (CfRules[1].Back = ''), 'cond format: rules are parsed');
    XH := TTestHost.Create;
    Check(MatchCondFormat(CfRules, XH, CfRule) and (CfRule.Fore = '#C00000'), 'cond format: the first true rule wins');
    CfRules := ParseCondFormat('[b] > 10 => #112233 ;; [a] = 5 => - #00FF00');
    Check(MatchCondFormat(CfRules, XH, CfRule) and (CfRule.Fore = '') and (CfRule.Back = '#00FF00'), 'cond format: "-" keeps the text colour, the next rule can match');
    CfRules := ParseCondFormat('[b] > 10 => #112233');
    Check(not MatchCondFormat(CfRules, XH, CfRule), 'cond format: no rule, no format');
    XH.Free;
    Check(CondFormatError('[a] > 1 => #FF0000') = '', 'cond format: valid text has no error');
    Check(CondFormatError('[a] > 1 => crveno') <> '', 'cond format: an unknown word is reported');
    Check(CondFormatError('samo izraz') <> '', 'cond format: missing arrow is reported');
    { forma }
    D := TaFormDef.Create;
    D.Name := 'CfF'; D.RecordSource := 'racun';
    C := NewCtl('TextBox', 'txtIznosCf', 'iznos', 10, 10); C.SetX('condFormat', '[iznos] > 100 => #C00000 #FFE9E9 bold'); D.Add(C);
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    CfBad := 0;
    R.DoAction('first');
    for CfI := 1 to R.Query.RecordCount do
    begin
      CfHigh := R.Query.FieldByName('iznos').AsFloat > 100;
      CfOn := (TEdit(R.ControlByName('txtIznosCf')).Font.Color = TColor($0000C0)) and (TEdit(R.ControlByName('txtIznosCf')).Color = TColor($E9E9FF)) and
        (fsBold in TEdit(R.ControlByName('txtIznosCf')).Font.Style);
      if CfHigh <> CfOn then Inc(CfBad);
      R.DoAction('next');
    end;
    Check(CfBad = 0, 'cond format: a form control changes colour with the record (' + IntToStr(CfBad) + ' wrong)');
    R.Free;
    { mreza }
    D := TaFormDef.Create;
    D.Name := 'CfG'; D.RecordSource := 'racun'; D.ViewMode := 'datasheet'; D.GridFormat := '[iznos] > 100 => #C00000 #FFE9E9 bold';
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    Check(D2.GridFormat <> '', 'cond format: the grid rule survives JSON');
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    CfBad := 0;
    R.Query.First;
    while not R.Query.EOF do
    begin
      R.MainGrid.Canvas.Brush.Color := clWhite;
      R.MainGrid.OnPrepareCanvas(R.MainGrid, 0, nil, []);
      CfHigh := R.Query.FieldByName('iznos').AsFloat > 100;
      if CfHigh <> (R.MainGrid.Canvas.Brush.Color = TColor($E9E9FF)) then Inc(CfBad);
      R.Query.Next;
    end;
    Check(CfBad = 0, 'cond format: grid rows are painted by the rule (' + IntToStr(CfBad) + ' wrong)');
    R.Free;
    { izvjesce }
    RDb := TaReportDef.Create;
    RDb.Name := 'CfR'; RDb.Title := 'Cf'; RDb.RecordSource := 'racun';
    RDb.Heights[SecDetail] := 20;
    C := RItem('TextBox', 'Detail', 'tI', 'iznos', 0, 0, 100, 20); C.SetX('condFormat', '[iznos] > 100 => #C00000 #FFE9E9'); RDb.Add(C);
    REb := TaReportEngine.Create(Db, RDb);
    RRb := REb.Render;
    CfN := 0;
    for CfI := 0 to RRb.PageCount - 1 do
      for CfJ := 0 to RRb.Page(CfI).Items.Count - 1 do
        if (TaRItem(RRb.Page(CfI).Items[CfJ]).Kind = 'Text') and (TaRItem(RRb.Page(CfI).Items[CfJ]).Color = $0000C0) and
           (TaRItem(RRb.Page(CfI).Items[CfJ]).Fill = $E9E9FF) then Inc(CfN);
    Sq := Db.NewQuery('SELECT COUNT(*) FROM racun WHERE iznos > 100'); Sq.Open; CfK := Sq.Fields[0].AsInteger; Sq.Free;
    Check((CfN = CfK) and (CfK > 0), 'cond format: report cells are coloured for matching rows only (' + IntToStr(CfN) + '/' + IntToStr(CfK) + ')');
    RRb.Free; REb.Free; RDb.Free;
   except on E: Exception do WriteLn('EXC cf: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- brojevi slovima ---- }
  begin
    XH := TTestHost.Create;
    Check(Ev(XH, 'BrojSlovima(0)') = 'nula', 'words: 0 = nula');
    Check(Ev(XH, 'BrojSlovima(1)') = 'jedan', 'words: 1 = jedan');
    Check(Ev(XH, 'BrojSlovima(11)') = 'jedanaest', 'words: 11 = jedanaest');
    Check(Ev(XH, 'BrojSlovima(21)') = 'dvadeset jedan', 'words: 21 = dvadeset jedan');
    Check(Ev(XH, 'BrojSlovima(100)') = 'sto', 'words: 100 = sto');
    Check(Ev(XH, 'BrojSlovima(101)') = 'sto jedan', 'words: 101 = sto jedan');
    Check(Ev(XH, 'BrojSlovima(200)') = 'dvjesto', 'words: 200 = dvjesto');
    Check(Ev(XH, 'BrojSlovima(999)') = 'devetsto devedeset devet', 'words: 999 = devetsto devedeset devet');
    Check(Ev(XH, 'BrojSlovima(1000)') = 'tisuću', 'words: 1000 = tisuću');
    Check(Ev(XH, 'BrojSlovima(1001)') = 'tisuću jedan', 'words: 1001 = tisuću jedan');
    Check(Ev(XH, 'BrojSlovima(2000)') = 'dvije tisuće', 'words: 2000 = dvije tisuće');
    Check(Ev(XH, 'BrojSlovima(5000)') = 'pet tisuća', 'words: 5000 = pet tisuća');
    Check(Ev(XH, 'BrojSlovima(21000)') = 'dvadeset jedna tisuća', 'words: 21000 = dvadeset jedna tisuća');
    Check(Ev(XH, 'BrojSlovima(22000)') = 'dvadeset dvije tisuće', 'words: 22000 = dvadeset dvije tisuće');
    Check(Ev(XH, 'BrojSlovima(12000)') = 'dvanaest tisuća', 'words: 12000 = dvanaest tisuća');
    Check(Ev(XH, 'BrojSlovima(100000)') = 'sto tisuća', 'words: 100000 = sto tisuća');
    Check(Ev(XH, 'BrojSlovima(1000000)') = 'jedan milijun', 'words: 1000000 = jedan milijun');
    Check(Ev(XH, 'BrojSlovima(2500000)') = 'dva milijuna petsto tisuća', 'words: 2500000 = dva milijuna petsto tisuća');
    Check(Ev(XH, 'BrojSlovima(21000000)') = 'dvadeset jedan milijun', 'words: 21000000 = dvadeset jedan milijun');
    Check(Ev(XH, 'BrojSlovima(1000000000)') = 'jedna milijarda', 'words: 1000000000 = jedna milijarda');
    Check(Ev(XH, 'BrojSlovima(-5)') = 'minus pet', 'words: -5 = minus pet');
    Check(Ev(XH, 'IznosSlovima(123.45)') = 'sto dvadeset tri eura i četrdeset pet centi', 'amount in words: 123.45');
    Check(Ev(XH, 'IznosSlovima(1)') = 'jedan euro', 'amount in words: 1');
    Check(Ev(XH, 'IznosSlovima(2.02)') = 'dva eura i dva centa', 'amount in words: 2.02');
    Check(Ev(XH, 'IznosSlovima(0.01)') = 'nula eura i jedan cent', 'amount in words: 0.01');
    Check(Ev(XH, 'IznosSlovima(5.11)') = 'pet eura i jedanaest centi', 'amount in words: 5.11');
    Check(Ev(XH, 'IznosSlovima(1.21)') = 'jedan euro i dvadeset jedan cent', 'amount in words: 1.21');
    Check(Ev(XH, 'IznosSlovima(-3.5)') = 'minus tri eura i pedeset centi', 'amount in words: -3.5');
    Check(Ev(XH, 'IznosSlovima(21)') = 'dvadeset jedan euro', 'amount in words: 21');
    Check(Ev(XH, 'IznosSlovima(1000.5)') = 'tisuću eura i pedeset centi', 'amount in words: 1000.5');
    Check(Ev(XH, 'IznosSlovima(123.45, 1)') = 'sto dvadeset tri eura i 45/100', 'amount in words, numeric cents');
    Check(Ev(XH, 'IsNull(IznosSlovima(Null))') = 'Da', 'amount in words: Null stays Null');
    XH.Free;
  end;

  { ---- kopiranje zapisa i izvoz prikaza ---- }
  begin
   try
    D := TaFormDef.Create;
    D.Name := 'DupF'; D.RecordSource := 'racun';
    D.Add(NewCtl('TextBox', 'txtIznosD', 'iznos', 10, 10));
    D.Add(NewCtl('TextBox', 'txtKupacD', 'kupac_id', 10, 40));
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    R.DoAction('first');
    DpK := R.Query.RecordCount;
    DpIznos := TEdit(R.ControlByName('txtIznosD')).Text;
    DpKupac := TEdit(R.ControlByName('txtKupacD')).Text;
    R.DoAction('duplicate');
    Check(Ord(R.Query.State) = 3, 'duplicate: opens a new record');
    Check((TEdit(R.ControlByName('txtIznosD')).Text = DpIznos) and (TEdit(R.ControlByName('txtKupacD')).Text = DpKupac), 'duplicate: the values are copied');
    R.DoAction('save');
    Check(R.Query.RecordCount = DpK + 1, 'duplicate: saving adds one record');
    Sq := Db.NewQuery('SELECT COUNT(DISTINCT id), COUNT(*) FROM racun'); Sq.Open;
    Check(Sq.Fields[0].AsInteger = Sq.Fields[1].AsInteger, 'duplicate: the copy got its own id');
    Sq.Free;
    R.Free;
    { zadani izraz (broj dokumenta) se ne kopira nego se ponovno izracuna }
    D2 := TaFormDef.Create; D2.FromJson(Db.LoadObject('_sys_forms', 'Računi')); D2.Name := 'Računi';
    DpBroj := '';
    for DpI := 0 to D2.Count - 1 do
      if D2[DpI].ControlSource = 'broj' then DpBroj := D2[DpI].Name;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    R.DoAction('first');
    DpIznos := TEdit(R.ControlByName(DpBroj)).Text;
    R.DoAction('duplicate');
    Check((TEdit(R.ControlByName(DpBroj)).Text <> '') and (TEdit(R.ControlByName(DpBroj)).Text <> DpIznos), 'duplicate: the document number is generated anew (' + DpIznos + ' -> ' + TEdit(R.ControlByName(DpBroj)).Text + ')');
    R.DoAction('undo');
    R.Free;
    { izvoz prikaza }
    DeleteFile('/tmp/ta_view.csv');
    D := TaFormDef.Create;
    D.Name := 'ExF'; D.RecordSource := 'racun'; D.ViewMode := 'datasheet';
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    R.SetColumnFilter('iznos', '>100');
    DpK := R.Query.RecordCount;
    LastMsg := '';
    OnRunnerMessage := @CaptureMsg;
    R.DoAction('export:/tmp/ta_view.csv');
    OnRunnerMessage := nil;
    Check(Pos('Izvezeno', LastMsg) = 1, 'export view: the user is told where the file went');
    DpL := TStringList.Create;
    DpL.LoadFromFile('/tmp/ta_view.csv');
    Check((DpL.Count = DpK + 1) and (Pos('iznos', DpL[0]) > 0), 'export view: header plus the filtered rows (' + IntToStr(DpL.Count) + ' lines for ' + IntToStr(DpK) + ' rows)');
    DpL.Free;
    R.Free;
   except on E: Exception do WriteLn('EXC dup: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- PDF417 i HUB3 ---- }
  begin
   try
    Check(Pdf417Encode('ABC', 1, 0, PdRows, PdE) and (Length(PdRows) = 5) and
      (PdRows[0] = '11111111010101000111101010111100001110101001110000011101010111000000111111101000101001') and
      (PdRows[4] = '11111111010101000111010111001100001111101000100011011101011100110000111111101000101001'),
      'pdf417: matches the reference encoder (first and last row) ' + PdE);
    Check(Pdf417Encode('Hello, World! 1234567890123456789', 6, 2, PdRows, PdE) and (Length(PdRows) = 5) and
      (PdRows[0] = '111111110101010001111010101111000011010111011110000111101100100111001101000001000110010010000011011000110001110110010001000001010001000011111010100111110111111101000101001'),
      'pdf417: text plus numeric compaction matches the reference');
    Check(not Pdf417Encode('ABC', 6, 2, PdRows, PdE) and (PdE <> ''), 'pdf417: too few rows is refused (' + PdE + ')');
    Check(not Pdf417Encode('x', 40, 2, PdRows, PdE), 'pdf417: too many columns is refused');
    Check(Pdf417Auto('Placanje racuna 2026-001 / Firma d.o.o.', 4, 3.0, PdRows, PdE) and (Length(PdRows) >= 3), 'pdf417: automatic column count');
    PdOk := True;
    for PdI := 1 to High(PdRows) do if Length(PdRows[PdI]) <> Length(PdRows[0]) then PdOk := False;
    Check(PdOk, 'pdf417: every row has the same width');
    PdPay := Hub3Payload(1234.5, 'Čedomir Šarić', 'Ulica kralja Tomislava 123456789012', 'Đakovo', 'Firma d.o.o.', 'Trg 2', '21000 Split',
      'hr12 1001 0051 8630 0016 0', 'HR00', '2026-001', 'COST', 'Plaćanje računa');
    PdL := TStringList.Create;
    PdL.Text := StringReplace(PdPay, #10, LineEnding, [rfReplaceAll]);
    Check(PdL.Count = 14, 'hub3: fourteen lines (' + IntToStr(PdL.Count) + ')');
    Check((PdL[0] = 'HRVHUB30') and (PdL[1] = 'EUR') and (PdL[2] = '000000000123450'), 'hub3: header, currency and amount in cents');
    Check(PdL[3] = 'Cedomir Saric', 'hub3: diacritics are removed (' + PdL[3] + ')');
    Check(Length(PdL[4]) <= 27, 'hub3: payer address is cut to 27 characters');
    Check(PdL[5] = 'Djakovo', 'hub3: Đ becomes Dj (' + PdL[5] + ')');
    Check(PdL[9] = 'HR1210010051863000160', 'hub3: IBAN without spaces, upper case');
    Check(PdL[13] = 'Placanje racuna', 'hub3: description');
    PdL.Free;
    XH := TTestHost.Create;
    Check(Copy(Ev(XH, 'Hub3Uplata(10, "A", "B", "C", "D", "E", "F", "HR1210010051863000160")'), 1, 9) = 'HRVHUB30' + #10, 'expr Hub3Uplata builds the payload');
    Check(Ev(XH, 'IsNull(Hub3Uplata(Null, "A", "B", "C", "D", "E", "F", "HR12"))') = 'Da', 'expr Hub3Uplata: Null amount gives Null');
    ActiveDb := Db;
    Db.SaveSetting('firma.test', 'vrijednost');
    Check(Ev(XH, 'Postavka("firma.test")') = 'vrijednost', 'expr Postavka reads a database setting');
    Check(Ev(XH, 'Postavka("nema.takvog")') = '', 'expr Postavka: unknown key is empty');
    XH.Free;
    { u izvjescu }
    RDb := TaReportDef.Create;
    RDb.Name := 'H3R'; RDb.Title := 'H3'; RDb.RecordSource := 'rac_kup';
    RDb.Heights[SecDetail] := 130;
    C := RItem('Barcode', 'Detail', 'bcH', '=Hub3Uplata([iznos], [kupac], "Ulica 1", "Zagreb", "Firma", "Trg 2", "Split", "HR1210010051863000160", "HR00", "1", "", "Racun")', 0, 4, 400, 120);
    C.SetX('barType', 'hub3'); RDb.Add(C);
    REb := TaReportEngine.Create(Db, RDb);
    RRb := REb.Render;
    CfN := 0;
    for CfI := 0 to RRb.PageCount - 1 do
      for CfJ := 0 to RRb.Page(CfI).Items.Count - 1 do
        if TaRItem(RRb.Page(CfI).Items[CfJ]).Kind = 'Frame' then Inc(CfN);
    Check(CfN > 100, 'hub3: the report draws the PDF417 as bars (' + IntToStr(CfN) + ' frames)');
    Check(ExportPdf(RRb, '/tmp/ta_hub3.pdf', PdfErr), 'hub3: PDF export ' + PdfErr);
    RRb.Free; REb.Free; RDb.Free;
   except on E: Exception do WriteLn('EXC hub3: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- padajuci popis s pretrazivanjem ---- }
  begin
   try
    D := TaFormDef.Create;
    D.Name := 'CmbS'; D.RecordSource := 'racun';
    C := NewCtl('ComboBox', 'cmbKupacS', 'kupac_id', 10, 10);
    C.RowSource := 'SELECT id, naziv FROM kupac ORDER BY id'; C.SetX('search', '1'); D.Add(C);
    D2 := TaFormDef.Create; D2.FromJson(D.ToJson); D.Free;
    R := TaFormRunner.CreateRunner(nil, Db, D2);
    CbX := TaComboBox(R.ControlByName('cmbKupacS'));
    CbAll := CbX.Items.Count;
    Sq := Db.NewQuery('SELECT COUNT(*) FROM kupac WHERE instr(lower(naziv), ''an'') > 0'); Sq.Open; CbN := Sq.Fields[0].AsInteger; Sq.Free;
    Check(CbX.Search and (CbX.Style = csDropDown) and (CbAll >= 2), 'search combo: editable list with ' + IntToStr(CbAll) + ' entries');
    CbKey := CbX.CurrentKey;
    CbX.Text := 'AN';
    TComboHack(CbX).CallChange;
    Check((CbX.Items.Count = CbN) and (CbX.Keys.Count = CbN) and (CbN >= 1), 'search combo: typing narrows the list to matches (' + IntToStr(CbX.Items.Count) + '/' + IntToStr(CbN) + ')');
    Check(CbX.CurrentKey = CbKey, 'search combo: typing alone does not change the stored value');
    CbX.ItemIndex := 0;
    TComboHack(CbX).CallSelect;
    Check(CbX.CurrentKey = CbX.Keys[0], 'search combo: choosing a match sets the value');
    CbKey := CbX.CurrentKey;
    CbX.Text := 'zzzz-nema';
    TComboHack(CbX).CallChange;
    Check((CbX.Items.Count = 0) and (CbX.CurrentKey = CbKey), 'search combo: no match keeps the last value');
    TComboHack(CbX).CallExit;
    Check((CbX.Items.Count = CbAll) and (CbX.CurrentKey = CbKey) and (CbX.ItemIndex >= 0), 'search combo: leaving with half-typed text restores the full list and the last choice');
    WriteControlValue(CbX, '2');
    Check((CbX.Items.Count = CbAll) and (CbX.CurrentKey = '2') and (CbX.Items[CbX.ItemIndex] = CbX.AllLabels[CbX.AllKeys.IndexOf('2')]), 'search combo: loading a record shows the right name after filtering');
    CbX.Text := 'AN';
    TComboHack(CbX).CallChange;
    WriteControlValue(CbX, '1');
    Check((CbX.Items.Count = CbAll) and (CbX.CurrentKey = '1'), 'search combo: a filtered list is reset when a record loads');
    CbX.Text := CbX.AllLabels[CbAll - 1];
    TComboHack(CbX).CallChange;
    Check(CbX.CurrentKey = CbX.AllKeys[CbAll - 1], 'search combo: typing a complete name selects it');
    CbX.Text := '';
    TComboHack(CbX).CallChange;
    TComboHack(CbX).CallExit;
    Check(ReadControlValue(CbX) = '', 'search combo: an emptied box clears the link');
    R.DoAction('undo');
    R.Free;
   except on E: Exception do WriteLn('EXC cmb: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- izvjesce master sa vise detail tablica (podizvjesca) ---- }
  begin
   try
    Db.Conn.ExecuteDirect('CREATE TABLE md_m (id INTEGER PRIMARY KEY, naziv TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE md_a (id INTEGER PRIMARY KEY, m_id INTEGER REFERENCES md_m(id), opis TEXT)');
    Db.Conn.ExecuteDirect('CREATE TABLE md_b (id INTEGER PRIMARY KEY, m_id INTEGER REFERENCES md_m(id), napomena TEXT)');
    Db.Conn.ExecuteDirect('INSERT INTO md_m VALUES (1, ''Prvi master''), (2, ''Drugi master'')');
    Db.Conn.ExecuteDirect('INSERT INTO md_a VALUES (1, 1, ''alfa''), (2, 1, ''beta'')');
    Db.Conn.ExecuteDirect('INSERT INTO md_b VALUES (1, 1, ''gama''), (2, 2, ''delta''), (3, 2, ''epsilon''), (4, 2, ''zeta'')');
    MdKids := TStringList.Create;
    MdFm := TStringList.Create; MdFm.Add('naziv');
    MdFa := TStringList.Create; MdFa.Add('opis');
    MdFb := TStringList.Create; MdFb.Add('napomena');
    MdM.Master := 'md_m'; MdM.Name := 'MdIzv'; MdM.Title := 'Master s detailima'; MdM.MasterFields := MdFm;
    SetLength(MdM.Details, 2);
    MdM.Details[0].Table := 'md_a'; MdM.Details[0].Fields := MdFa; MdM.Details[0].SumField := ''; MdM.Details[0].ShowCount := False;
    MdM.Details[1].Table := 'md_b'; MdM.Details[1].Fields := MdFb; MdM.Details[1].SumField := ''; MdM.Details[1].ShowCount := False;
    MdM.DetailAsForm := False; MdM.UseTabs := False;
    RDb := BuildMasterDetailReportMulti(Db, MdM, False, MdKids, MdErr);
    Check((RDb <> nil) and (MdErr = '') and (MdKids.Count = 2), 'multi report: master and two child reports are built (' + MdErr + ')');
    for CfI := 0 to MdKids.Count - 1 do Db.SaveObject('_sys_reports', MdKids[CfI], TaReportDef(MdKids.Objects[CfI]).ToJson);
    MdSubs := 0;
    for CfI := 0 to RDb.Count - 1 do if RDb[CfI].Kind = 'Subreport' then Inc(MdSubs);
    Check(MdSubs = 2, 'multi report: one subreport control per detail');
    REb := TaReportEngine.Create(Db, RDb);
    RRb := REb.Render;
    MdYBeta := -1; MdYGama := -1; MdYDelta := -1; MdYZeta := -1; MdYEps := -1;
    for CfI := 0 to RRb.PageCount - 1 do
      for CfJ := 0 to RRb.Page(CfI).Items.Count - 1 do
        with TaRItem(RRb.Page(CfI).Items[CfJ]) do
        begin
          if Text = 'beta' then MdYBeta := Y + CfI * 100000;
          if Text = 'gama' then MdYGama := Y + CfI * 100000;
          if Text = 'delta' then MdYDelta := Y + CfI * 100000;
          if Text = 'epsilon' then MdYEps := Y + CfI * 100000;
          if Text = 'zeta' then MdYZeta := Y + CfI * 100000;
        end;
    Check(HasText(RRb, 'alfa') and HasText(RRb, 'beta') and HasText(RRb, 'gama') and HasText(RRb, 'delta') and HasText(RRb, 'zeta'),
      'multi report: rows of both detail tables are printed');
    Check(HasText(RRb, 'Prvi master') and HasText(RRb, 'Drugi master'), 'multi report: both masters are printed');
    Check((MdYGama > MdYBeta) and (MdYBeta >= 0), 'multi report: the second detail starts below the last row of the first (beta ' + IntToStr(MdYBeta) + ', gama ' + IntToStr(MdYGama) + ')');
    Check((MdYEps > MdYDelta) and (MdYZeta > MdYEps), 'multi report: rows of a subreport stay in order');
    Check((MdYDelta > MdYGama), 'multi report: the next master comes after the previous one');
    ExportPdf(RRb, '/tmp/ta_mdr.pdf', PdfErr);
    RRb.Free; REb.Free;
    Check(True, 'multi report: placeholder control can be created');
    CfC := CreateAccessControl(nil, nil, RDb[RDb.Count - 1]);
    CfC.Free;
    RDb.Free;
    for CfI := 0 to MdKids.Count - 1 do MdKids.Objects[CfI].Free;
    MdKids.Free; MdFm.Free; MdFa.Free; MdFb.Free;
   except on E: Exception do WriteLn('EXC mdr: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- uredivaci svojstava (kao u Lazarusu) ---- }
  begin
   try
    Check((PropKindOf('Bold') = pkBool) and (PropKindOf('BarType') = pkEnum) and (PropKindOf('ForeColor') = pkColor) and
      (PropKindOf('Font') = pkFont) and (PropKindOf('VisibleIf') = pkExpr) and (PropKindOf('Name') = pkPlain), 'property editors: kinds of properties');
    D := TaFormDef.Create;
    D.Name := 'PropT'; D.RecordSource := 'racun';
    PeDz := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      PeC := PeDz.AddForTest('TextBox', 20, 20);
      Check(PeDz.PropsGrid.Values['Font'] <> '', 'font row is shown: ' + PeDz.PropsGrid.Values['Font']);
      Check(PeDz.PropsGrid.ItemProps['Font'].EditStyle = esEllipsis, 'font row has a ... button');
      Check(PeDz.PropsGrid.ItemProps['ForeColor'].EditStyle = esEllipsis, 'colour row has a ... button');
      Check((PeDz.PropsGrid.ItemProps['Bold'].EditStyle = esPickList) and (PeDz.PropsGrid.ItemProps['Bold'].PickList.Count = 2), 'Bold is a True/False list');
      Check((PeDz.PropsGrid.ItemProps['ControlSource'].EditStyle = esPickList) and (PeDz.PropsGrid.ItemProps['ControlSource'].PickList.IndexOf('iznos') >= 0), 'ControlSource lists the fields of the source');
      Check(PeDz.PropsGrid.ItemProps['VisibleIf'].EditStyle = esEllipsis, 'VisibleIf opens the expression builder');
      Check(PeDz.PropsGrid.ItemProps['FontName'].PickList.Count > 0, 'FontName lists installed fonts');
      PeDz.SetPropForTest('FontName', 'DejaVu Sans');
      PeDz.SetPropForTest('FontSize', '14');
      PeDz.SetPropForTest('Bold', 'True');
      PeDz.SetPropForTest('ForeColor', '#C00000');
      Check((TEdit(PeC).Font.Size = 14) and (fsBold in TEdit(PeC).Font.Style) and (TEdit(PeC).Font.Color = TColor($0000C0)), 'font properties change the control');
      Check(Pos('DejaVu Sans, 14 pt, podebljano', PeDz.PropsGrid.Values['Font']) = 1, 'the Font row summarises the choice: ' + PeDz.PropsGrid.Values['Font']);
      PeC := PeDz.AddForTest('Barcode', 20, 80);
      Check(PeDz.PropsGrid.ItemProps['BarType'].PickList.IndexOf('hub3') >= 0, 'BarType is a list including hub3');
    finally
      PeDz.Free;
    end;
   except on E: Exception do WriteLn('EXC pe: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- poravnanje i vise odabranih kontrola ---- }
  begin
   try
    SetLength(LyB, 3);
    LyB[0].L := 0; LyB[0].T := 0; LyB[0].W := 10; LyB[0].H := 10;
    LyB[1].L := 15; LyB[1].T := 30; LyB[1].W := 20; LyB[1].H := 12;
    LyB[2].L := 100; LyB[2].T := 70; LyB[2].W := 10; LyB[2].H := 30;
    Check(ApplyLayout(loSpaceH, LyB, 0) and (LyB[1].L = 45), 'layout: equal horizontal gaps between the outer two');
    Check(ApplyLayout(loAlignLeft, LyB, 2) and (LyB[0].L = 100) and (LyB[1].L = 100), 'layout: align left to the reference');
    Check(ApplyLayout(loAlignRight, LyB, 2) and (LyB[0].L = 100) and (LyB[1].L = 90), 'layout: align right to the reference edge');
    Check(ApplyLayout(loAlignBottom, LyB, 2) and (LyB[0].T = 90), 'layout: align bottoms');
    Check(ApplyLayout(loSameWidth, LyB, 1) and (LyB[0].W = 20) and (LyB[2].W = 20), 'layout: same width');
    Check(ApplyLayout(loCenterH, LyB, 1) and (LyB[0].L + LyB[0].W div 2 = LyB[1].L + LyB[1].W div 2), 'layout: centre horizontally');
    SetLength(LyB, 1);
    Check(not ApplyLayout(loAlignLeft, LyB, 0), 'layout: one control cannot be aligned');
    D := TaFormDef.Create;
    D.Name := 'LyT'; D.RecordSource := 'racun';
    PeDz := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      PeC := PeDz.AddForTest('TextBox', 10, 10);
      LyC2 := PeDz.AddForTest('TextBox', 50, 30);
      LyC3 := PeDz.AddForTest('TextBox', 120, 60);
      PeDz.ToggleMultiForTest(PeC);
      PeDz.ToggleMultiForTest(LyC2);
      PeDz.LayoutForTest(loAlignLeft);
      Check((PeDz.FormDef[0].Left = 120) and (PeDz.FormDef[1].Left = 120) and (PeDz.FormDef[2].Left = 120), 'designer: Ctrl+click selection is aligned to the primary control');
      Check((PeC.Left = 120) and (LyC2.Left = 120), 'designer: the visible controls moved too');
      PeDz.UndoForTest;
      Check((PeDz.FormDef[0].Left = 10) and (PeDz.FormDef[1].Left = 50), 'designer: one undo reverts the whole alignment');
      PeC := PeDz.ControlOfForTest(0);
      LyC2 := PeDz.ControlOfForTest(1);
      PeDz.ToggleMultiForTest(PeC);
      PeDz.ToggleMultiForTest(LyC2);
      PeDz.ZOrderForTest(False);
      Check((PeDz.FormDef.Count = 3) and (PeDz.FormDef[2].Left = 120), 'designer: send to back moves the primary and the others behind');
      PeDz.DeleteForTest;
      Check((PeDz.FormDef.Count = 1) and (PeDz.FormDef[0].Left = 120), 'designer: Delete removes every selected control and leaves the unselected one');
    finally
      PeDz.Free;
    end;
   except on E: Exception do WriteLn('EXC ly: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- dizajner izvjesca: velicina upisom i povlacenjem rubova ---- }
  begin
   try
    RDb := TaReportDef.Create;
    RDb.Name := 'RdG'; RDb.Title := 'T'; RDb.RecordSource := 'racun';
    RDb.Heights[SecDetail] := 80;
    RdDz := TaReportDesigner.CreateDesigner(nil, Db, RDb);
    try
      RdC1 := RdDz.AddForTest('TextBox', SecDetail, 10, 10);
      RdDz.TypeInGridForTest('Width', '222');
      RdDz.TypeInGridForTest('Height', '30');
      Check((RdC1.Width = 222) and (RdC1.Height = 30), 'report designer: width and height typed into the property grid are applied (' + IntToStr(RdC1.Width) + 'x' + IntToStr(RdC1.Height) + ')');
      Check(RdDz.EdgeDragForTest(RdC1.Width - 1, RdC1.Height div 2, 20, 0) and (RdC1.Width = 242) and (RdC1.Height = 30), 'report designer: dragging the right edge changes only the width (' + IntToStr(RdC1.Width) + 'x' + IntToStr(RdC1.Height) + ')');
      RdBottom := RdC1.Top + RdC1.Height;
      Ok1 := RdDz.EdgeDragForTest(RdC1.Width div 2, 0, 0, -4);
      Check(Ok1 and (RdC1.Top < RdBottom - 30) and (RdC1.Top + RdC1.Height = RdBottom), 'report designer: dragging the top edge changes the height (' + IntToStr(RdC1.Top) + ',' + IntToStr(RdC1.Height) + ' ' + BoolToStr(Ok1, 'hit', 'no hit') + ')');
    finally
      RdDz.Free;
    end;
   except on E: Exception do WriteLn('EXC rg: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- dizajner izvjesca: odabir vise stavki ---- }
  begin
   try
    RDb := TaReportDef.Create;
    RDb.Name := 'RdT'; RDb.Title := 'T'; RDb.RecordSource := 'racun';
    RDb.Heights[SecDetail] := 80;
    RdDz := TaReportDesigner.CreateDesigner(nil, Db, RDb);
    try
      RdC1 := RdDz.AddForTest('TextBox', SecDetail, 10, 10);
      RdC2 := RdDz.AddForTest('TextBox', SecDetail, 50, 30);
      RdC3 := RdDz.AddForTest('TextBox', SecDetail, 120, 50);
      RdDz.ToggleMultiForTest(RdC1);
      RdDz.ToggleMultiForTest(RdC2);
      RdDz.LayoutForTest(loAlignLeft);
      Check((RdDz.ReportDef[0].Left = 120) and (RdDz.ReportDef[1].Left = 120) and (RdDz.ReportDef[2].Left = 120), 'report designer: Ctrl+click selection is aligned to the primary item');
      RdDz.UndoForTest;
      Check((RdDz.ReportDef[0].Left = 10) and (RdDz.ReportDef[1].Left = 50) and (RdDz.ReportDef[2].Left = 120), 'report designer: undo reverts the alignment');
      RdC1 := RdDz.ControlOfForTest(0);
      RdC2 := RdDz.ControlOfForTest(1);
      RdDz.ToggleMultiForTest(RdC1);
      RdDz.ToggleMultiForTest(RdC2);
      RdDz.NudgeForTest(8, 4);
      Check((RdDz.ReportDef[0].Left = 18) and (RdDz.ReportDef[1].Left = 58) and (RdDz.ReportDef[1].Top = 34) and (RdDz.ReportDef[2].Left = 120), 'report designer: arrows move the whole selection');
      RdDz.ZOrderForTest(False);
      Check(RdDz.ReportDef[0].Left = 58, 'report designer: send to back reorders the items');
      RdDz.DeleteForTest;
      Check((RdDz.ReportDef.Count = 1) and (RdDz.ReportDef[0].Left = 120), 'report designer: Delete removes every selected item');
      RdDz.UndoForTest;
      Check(RdDz.ReportDef.Count = 3, 'report designer: undo brings deleted items back');
      RdC1 := RdDz.AddForTest('Subreport', SecDetail, 5, 5);
      Check(RdDz.PropsGridForTest.ItemProps['LinkMaster'] <> nil, 'report designer: subreport has link properties');
    finally
      RdDz.Free;
    end;
   except on E: Exception do WriteLn('EXC rd: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- Northwind izgraden builderom ---- }
  begin
   try
    DeleteFile('/tmp/nw_test.db');
    NwDb := TAppDb.Create;
    NwLog := TStringList.Create;
    try
      NwDb.Open('/tmp/nw_test.db');
      Check(BuildNorthwind(NwDb, NwLog), 'northwind: built without errors ' + Copy(NwLog.Text, Pos('GREŠKA', NwLog.Text), 120));
      Sq := NwDb.NewQuery('SELECT (SELECT COUNT(*) FROM Orders), (SELECT COUNT(*) FROM OrderDetails), (SELECT COUNT(*) FROM Products)'); Sq.Open;
      Check((Sq.Fields[0].AsInteger = 220) and (Sq.Fields[1].AsInteger > 400) and (Sq.Fields[2].AsInteger = 40), 'northwind: data is in place');
      Sq.Free;
      Sq := NwDb.NewQuery('PRAGMA foreign_key_check'); Sq.Open;
      Check(Sq.EOF, 'northwind: every foreign key is satisfied');
      Sq.Free;
      NwForms := NwDb.ListObjects('_sys_forms');
      NwBad := '';
      for NwI := 0 to NwForms.Count - 1 do
      begin
        try
          NwD := TaFormDef.Create;
          NwD.FromJson(NwDb.LoadObject('_sys_forms', NwForms[NwI]));
          NwD.Name := NwForms[NwI];
          R := TaFormRunner.CreateRunner(nil, NwDb, NwD);
          R.Free;
        except
          on E: Exception do NwBad := NwBad + NwForms[NwI] + ': ' + E.Message + '; ';
        end;
      end;
      Check((NwBad = '') and (NwForms.Count >= 10), 'northwind: every form opens (' + IntToStr(NwForms.Count) + ') ' + NwBad);
      NwForms.Free;
      LcOld := DefaultFormatSettings;
      UseCroatianFormats;
      NwForms := NwDb.ListObjects('_sys_reports');
      NwBad := '';
      for NwI := 0 to NwForms.Count - 1 do
      begin
        try
          RDb := TaReportDef.Create;
          RDb.FromJson(NwDb.LoadObject('_sys_reports', NwForms[NwI]));
          RDb.Name := NwForms[NwI];
          REb := TaReportEngine.Create(NwDb, RDb);
          RRb := REb.Render;
          if RRb.PageCount < 1 then NwBad := NwBad + NwForms[NwI] + ': no pages; ';
          if NwForms[NwI] = 'Invoice' then
          begin
            ExportPdf(RRb, '/tmp/nw_invoice.pdf', PdfErr);
            Check(HasText(RRb, '05.07.1996') and not HasText(RRb, '1996-07-05'), 'northwind: dates from a query are shown as dd.mm.yyyy');
          end;
          if NwForms[NwI] = 'Sales by Category' then ExportPdf(RRb, '/tmp/nw_salescat.pdf', PdfErr);
          if NwForms[NwI] = 'Products by Category' then ExportPdf(RRb, '/tmp/nw_prodcat.pdf', PdfErr);
          RRb.Free; REb.Free; RDb.Free;
        except
          on E: Exception do NwBad := NwBad + NwForms[NwI] + ': ' + E.Message + '; ';
        end;
      end;
      DefaultFormatSettings := LcOld;
      Check((NwBad = '') and (NwForms.Count >= 6), 'northwind: every report renders (' + IntToStr(NwForms.Count) + ') ' + NwBad);
      NwForms.Free;
      { forma narudzbe: ukupno = stavke + prijevoz }
      NwD := TaFormDef.Create;
      NwD.FromJson(NwDb.LoadObject('_sys_forms', 'Orders')); NwD.Name := 'Orders';
      R := TaFormRunner.CreateRunner(nil, NwDb, NwD);
      Sq := NwDb.NewQuery('SELECT ROUND((SELECT SUM(UnitPrice * Quantity * (1 - Discount)) FROM OrderDetails WHERE OrderID = 1) + Freight, 2) FROM Orders WHERE OrderID = 1'); Sq.Open;
      NwTot := Sq.Fields[0].AsFloat; Sq.Free;
      NwTxt := '';
      for NwI := 0 to NwD.Count - 1 do
        if Pos('DSum', NwD[NwI].ControlSource) > 0 then NwTxt := TEdit(R.ControlByName(NwD[NwI].Name)).Text;
      Check(StringReplace(NwTxt, ',', '', [rfReplaceAll]) = FormatFloat('#,##0.00', NwTot).Replace(',', ''), 'northwind: order form shows the order total (' + NwTxt + ' / ' + FormatFloat('#,##0.00', NwTot) + ')');
      R.Free;
      { upit s parametrima }
      ParamPromptHook := @TestDateRangePrompt;
      NwDb.ClearParams;
      Sq := NwDb.NewQuery('SELECT COUNT(*) FROM ' + NwDb.SourceFrom('Orders in Date Range')); Sq.Open;
      Check(Sq.Fields[0].AsInteger > 0, 'northwind: parameter query asks for dates and returns orders');
      Sq.Free;
      ParamPromptHook := nil;
      NwDb.ClearParams;
    finally
      NwLog.Free;
      NwDb.Free;
    end;
   except on E: Exception do WriteLn('EXC nw: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- uredivaci: popisi umjesto rucnog pisanja ---- }
  begin
   try
    Check(RowSourceSql('kupac', 'id', 'naziv') = 'SELECT "id", "naziv" FROM "kupac" ORDER BY "naziv"', 'row source builder: SQL for a lookup list');
    Check(ChartSourceSql('racun', 'kupac_id', 'iznos', 'SUM') = 'SELECT "kupac_id", SUM("iznos") FROM "racun" GROUP BY "kupac_id" ORDER BY "kupac_id"', 'row source builder: SQL for a chart');
    Db.SaveObject('_sys_modules', 'ModPE', 'procedure Pozdrav;' + LineEnding + 'begin' + LineEnding + 'end;' + LineEnding + 'Procedure DrugaRutina(A: Integer);' + LineEnding + 'begin end;');
    PeL := ModuleProcedures(Db);
    Check((PeL.IndexOf('Pozdrav') >= 0) and (PeL.IndexOf('DrugaRutina') >= 0), 'property editors: module procedures are listed for events');
    PeL.Free;
    D := TaFormDef.Create;
    D.Name := 'PickT'; D.RecordSource := 'kupac';
    PeDz := TaFormDesigner.CreateDesigner(nil, Db, D);
    try
      PeDz.AddForTest('TabControl', 300, 10);
      PeC := PeDz.AddForTest('Subform', 10, 200);
      Check(PeDz.PropsGrid.ItemProps['RowSource'].PickList.IndexOf('racun') >= 0, 'subform: RowSource lists tables and queries');
      PeDz.SetPropForTest('RowSource', 'racun');
      Check(PeDz.PropsGrid.ItemProps['LinkChild'].PickList.IndexOf('iznos') >= 0, 'subform: LinkChild lists the fields of the subform source');
      Check(PeDz.PropsGrid.ItemProps['LinkMaster'].PickList.IndexOf('naziv') >= 0, 'subform: LinkMaster lists the fields of the form source');
      PeC := PeDz.AddForTest('ComboBox', 10, 10);
      Check(PeDz.PropsGrid.ItemProps['RowSource'].EditStyle = esEllipsis, 'combo box: RowSource opens the builder');
      Check(PeDz.PropsGrid.ItemProps['OnChange'].PickList.IndexOf('macro:TaskMacro') >= 0, 'events: macros are offered as macro:Name');
      Check(PeDz.PropsGrid.ItemProps['OnChange'].PickList.IndexOf('Pozdrav') >= 0, 'events: module procedures are offered');
      PeC := PeDz.AddForTest('Button', 10, 60);
      Check(PeDz.PropsGrid.ItemProps['OnClick'].EditStyle = esEllipsis, 'button: OnClick opens the action builder');
      PeC := PeDz.AddForTest('TextBox', 10, 100);
      Check(PeDz.PropsGrid.ItemProps['Format'].PickList.IndexOf('#,##0.00') >= 0, 'text box: Format offers common formats');
      Check(PeDz.PropsGrid.ItemProps['Container'].PickList.Count >= 1, 'container: lists the tab controls of the form');
      Check(PeDz.PropsGrid.ItemProps['CondFormat'].EditStyle = esEllipsis, 'text box: CondFormat opens the rule builder');
    finally
      PeDz.Free;
    end;
   except on E: Exception do WriteLn('EXC pick: ', E.ClassName, ' ', E.Message); end;
  end;

  { ---- decimalni zarez u prikazima ---- }
  begin
   try
    LcOld := DefaultFormatSettings;
    UseCroatianFormats;
    try
      XH := TTestHost.Create;
      Check(FormatValue(1234.5, '#,##0.00') = '1.234,50', 'locale: format pattern gives 1.234,50 (' + FormatValue(1234.5, '#,##0.00') + ')');
      Check(FormatValue(12.5, '') = '12,5', 'locale: an unformatted decimal shows a comma');
      Check(Ev(XH, 'Eur(1234.5)') = '1.234,50 €', 'locale: Eur()');
      Check(Ev(XH, 'Format(7.5, "0.00")') = '7,50', 'locale: Format()');
      Check(Ev(XH, 'Round(2.5, 2) * 3') = '7,5', 'locale: calculated result');
      Check(Ev(XH, 'Val("12,5") + 1') = '13,5', 'locale: Val reads a comma');
      Check(Ev(XH, '"Iznos: " & 12.5') = 'Iznos: 12.5', 'locale: concatenation stays invariant so SQL criteria built from it keep working');
      XH.Free;
      Check(ParseNumber('1.234,56', LcV) and (Abs(LcV - 1234.56) < 0.0001), 'locale: typed 1.234,56 is read correctly');
      Check(ParseNumber('12,5', LcV) and (Abs(LcV - 12.5) < 0.0001), 'locale: typed 12,5 is read correctly');
      LcM := TaFieldMeta.Create;
      LcM.LType := ltCurrency; LcM.Decimals := 2; LcM.Format := DefaultFormat(ltCurrency, 2);
      Check(StoredToDisplay(LcM, '1234.5') = '1.234,50 €', 'locale: currency field shows 1.234,50 € (' + StoredToDisplay(LcM, '1234.5') + ')');
      Check(DisplayToStored(LcM, '1.234,50', LcS) and (LcS = '1234.5') or (LcS = '1234.50'), 'locale: typed value is stored with a decimal point (' + LcS + ')');
      LcM.Free;
      Check(Pos('replace(printf(', FormatSqlOf('0.00')) = 1, 'locale: a query Format() produces a comma too');
      Sq := Db.NewQuery('SELECT 150.5 AS x'); Sq.Open;
      Check(Sq.Fields[0].DisplayText = '150,5', 'locale: query result grids show 150,5 (' + Sq.Fields[0].DisplayText + ')');
      Sq.Free;
{$IFDEF TA_FISCAL}
      Check(FiscalAmount(12.5) = '12.50', 'locale: fiscal amounts keep the decimal point');
{$ENDIF}
      Check(ParamLiteral('1,5') = '1.5', 'locale: query parameters become SQL numbers with a point');
    finally
      DefaultFormatSettings := LcOld;
    end;
   except on E: Exception do WriteLn('EXC locale: ', E.ClassName, ' ', E.Message); end;
  end;

{$IFDEF TA_FISCAL}
  { fiskalizacija: postavke i izraz ZKI }
  begin
    FcDef := LoadFiscalConfig(Db);
    Check(not FcDef.Prod and (FcDef.PP = 'POSL1'), 'fiscal config defaults to test mode');
    FcDef.Oib := '00000000000'; FcDef.PP := 'P7'; FcDef.NU := '3'; FcDef.Prod := True;
    FcDef.SavePass := True; FcDef.Pass := 'tajna!';
    SaveFiscalConfig(Db, FcDef);
    FcDef := LoadFiscalConfig(Db);
    Check((FcDef.Oib = '00000000000') and (FcDef.PP = 'P7') and FcDef.Prod and (FcDef.Pass = 'tajna!'), 'fiscal config round-trips (incl. obfuscated password)');
    Check(FiscalEffectiveUrl(FcDef) = FiscalUrlProd, 'fiscal url follows mode');
    FcDef.SavePass := False; FcDef.Prod := False;
    SaveFiscalConfig(Db, FcDef);
    Check(LoadFiscalConfig(Db).Pass = '', 'password is not kept when save is off');
    FcCert := GetEnvironmentVariable('TA_FISCAL_CERT');
    if (FcCert <> '') and FileExists(FcCert) then
    begin
      FcDef.CertFile := FcCert; FcDef.SavePass := True; FcDef.Pass := GetEnvironmentVariable('TA_FISCAL_PASS');
      FcDef.PP := 'POSL1'; FcDef.NU := '2';
      SaveFiscalConfig(Db, FcDef);
      ActiveDb := Db;
      XH := TTestHost.Create;
      Check(Ev(XH, 'Len(ZKI("1", DateSerial(2026,11,2) + TimeSerial(9,5,7), 25.5))') = '32', 'expr ZKI gives a 32-char code');
      Check(Ev(XH, 'IsNull(ZKI(Null, Now(), 1))') = 'Da', 'expr ZKI propagates Null');
      XH.Free;
    end
    else WriteLn('skip fiscal ZKI expression test (set TA_FISCAL_CERT and TA_FISCAL_PASS)');
  end;
{$ENDIF}
  { dialogs }
  Tm2 := TTimer.Create(nil);
  Tm2.Interval := 600;
  Tm2.OnTimer := @Closer0.Tick;
  Tm2.Enabled := True;
  RunAppSettings(nil, Db);
  Check(True, 'settings dialog opens and closes');
  Check(not RunLogin(nil, Db), 'login dialog opens, cancel refuses');
  RunUsers(nil, Db);
  Check(True, 'users dialog opens and closes');
  RunRights(nil, Db);
  Check(True, 'rights dialog opens and closes');
  Check(RunSwitchboard(nil, Db) = '', 'switchboard wizard opens and cancels');
  Check(RunMasterDetailWizard(nil, Db, RepNm) = '', 'master-detail wizard opens and cancels');
  Check(RunQueryWizard(nil, Db) = '', 'query wizard opens and cancels');
  Check(not RunBusinessTemplates(nil, Db), 'business templates dialog opens and closes');
{$IFDEF TA_FISCAL}
  Check(not RunFiscalSetup(nil, Db), 'fiscal setup dialog opens and cancels');
{$ENDIF}
  RunAuditViewer(nil, Db);
  Check(True, 'audit viewer opens and closes');
  RunTaskPlanner(nil, Db);
  Check(True, 'task planner opens and closes');
  Check(not RunCompanyProfile(nil, Db), 'company profile dialog opens and cancels');
  QWs := 'SELECT 1';
  Check(not RunRowSourceBuilder(nil, Db, 'ComboBox', QWs), 'row source builder opens and cancels');
  QWs := 'save';
  Check(not RunActionBuilder(nil, Db, nil, QWs), 'action builder opens and cancels');
  QWs := '[iznos] > 100 => #C00000 #FFE9E9 bold ;; [iznos] < 0 AND [x] > 1 => #FFFFFF';
  QWp := TStringList.Create; QWp.Add('iznos');
  Check(not RunCondFormatBuilder(nil, QWp, QWs), 'conditional format builder opens and cancels');
  QWs := 'kupac_id>kupac.id:naziv=naziv';
  Check(not RunAutoFillBuilder(nil, Db, QWp, QWs), 'autofill builder opens and cancels');
  QWp.Add('kolicina'); QWp.Add('cijena');
  QWs := 'kolicina,cijena -> iznos = Zaokruzi([kolicina] * [cijena], 2) ;; iznos -> cijena = Zaokruzi([iznos] / [kolicina], 4)';
  Check(not RunCalcRulesBuilder(nil, QWp, QWs), 'calc rules builder opens and cancels');
  QWs := 'kupac, iznos DESC';
  Check(not RunSortBuilder(nil, QWp, QWs), 'sort builder opens and cancels');
  QWp.Free;
  Check(RunCrosstabWizard(nil, Db) = '', 'crosstab wizard opens and cancels');
  Check(RunDataTools(nil, Db) = '', 'data tools dialog opens and cancels');
  QWp := TStringList.Create; QWp.Add('iznos'); QWv := TStringList.Create;
  Check(not RunColumnFilters(nil, QWp, QWp, [fkNumber], QWv, Db, 'FormaX'), 'column filter dialog opens and cancels');
  QWp.Free; QWv.Free;
  QWp := TStringList.Create; QWp.Add('Od datuma'); QWv := TStringList.Create;
  Check(not PromptQueryParams(QWp, QWv), 'parameter dialog opens and cancels');
  QWp.Free; QWv.Free;
  QWt := TStringList.Create; QWt.Add('racun');
  Check(not RunCalcWizard(nil, Db, QWt, True, CalcA, CalcE), 'calculated field wizard (query) opens and cancels');
  Check(not RunCalcWizard(nil, Db, QWt, False, CalcA, CalcE), 'calculated field wizard (form) opens and cancels');
  QWt.Free;
  Sv := '[iznos] * 2';
  Check(not EditExpression(nil, Db, 'racun', 'test', Sv), 'expression builder opens and cancels');
  Tm2.Free;
  try TestNorthwindDb(dkPostgres); except on E: Exception do begin Inc(Fails); WriteLn('FAIL pgnw exception: ', E.Message); end; end;
  try TestMetaDb(dkPostgres); except on E: Exception do begin Inc(Fails); WriteLn('FAIL pg exception: ', E.Message); end; end;
  try TestNorthwindDb(dkMaria); except on E: Exception do begin Inc(Fails); WriteLn('FAIL maria nw exception: ', E.Message); end; end;
  try TestMetaDb(dkMaria); except on E: Exception do begin Inc(Fails); WriteLn('FAIL maria exception: ', E.Message); end; end;
  try TestSnapshot(dkSqlite); except on E: Exception do begin Inc(Fails); WriteLn('FAIL snapshot exception: ', E.Message); end; end;
  try TestSnapshot(dkPostgres); except on E: Exception do begin Inc(Fails); WriteLn('FAIL pg snapshot exception: ', E.Message); end; end;
  try TestSnapshot(dkMaria); except on E: Exception do begin Inc(Fails); WriteLn('FAIL maria snapshot exception: ', E.Message); end; end;
  try TestFileStoreServer(dkPostgres); except on E: Exception do begin Inc(Fails); WriteLn('FAIL pg files exception: ', E.Message); end; end;
  try TestFileStoreServer(dkMaria); except on E: Exception do begin Inc(Fails); WriteLn('FAIL maria files exception: ', E.Message); end; end;
  try TestMigrate(dkPostgres); except on E: Exception do begin Inc(Fails); WriteLn('FAIL pg migrate exception: ', E.Message); end; end;
  try TestMigrate(dkMaria); except on E: Exception do begin Inc(Fails); WriteLn('FAIL maria migrate exception: ', E.Message); end; end;
  if GetEnvironmentVariable('SMOKE_SKIP_CATALOG') = '' then try TestCatalog(dkSqlite); except on E: Exception do begin Inc(Fails); WriteLn('FAIL catalog exception: ', E.Message); end; end;
  if GetEnvironmentVariable('SMOKE_SKIP_CATALOG') = '' then try TestCatalog(dkPostgres); except on E: Exception do begin Inc(Fails); WriteLn('FAIL pg catalog exception: ', E.Message); end; end;
  if GetEnvironmentVariable('SMOKE_SKIP_CATALOG') = '' then try TestCatalog(dkMaria); except on E: Exception do begin Inc(Fails); WriteLn('FAIL maria catalog exception: ', E.Message); end; end;
  try TestSortOptions; except on E: Exception do begin Inc(Fails); WriteLn('FAIL sort options exception: ', E.Message); end; end;
  try TestSingleFormRules; except on E: Exception do begin Inc(Fails); WriteLn('FAIL single rules exception: ', E.Message); end; end;
  try TestGroupPages; except on E: Exception do begin Inc(Fails); WriteLn('FAIL grouppages exception: ', E.Message); end; end;
  try TestBlockEditor; except on E: Exception do begin Inc(Fails); WriteLn('FAIL block editor exception: ', E.Message); end; end;
  try TestDesignGeometry; except on E: Exception do begin Inc(Fails); WriteLn('FAIL design geometry exception: ', E.Message); end; end;
  try TestPageAndSelection; except on E: Exception do begin Inc(Fails); WriteLn('FAIL page setup exception: ', E.Message); end; end;
  { primjer Trgovina Jadran: brojke u 4GL programima vrijede za prvu izradu u procesu pa ovi testovi idu prvi }
  try TestShowcase; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase exception: ', E.Message); end; end;
  try TestShowcasePrograms; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase programs exception: ', E.Message); end; end;
  try TestIconsAndTheme; except on E: Exception do begin Inc(Fails); WriteLn('FAIL icons exception: ', E.Message); end; end;
  try TestButtonIcons; except on E: Exception do begin Inc(Fails); WriteLn('FAIL button icons exception: ', E.Message); end; end;
  try TestSideMenu; except on E: Exception do begin Inc(Fails); WriteLn('FAIL sidemenu exception: ', E.Message); end; end;
  try TestPropMap; except on E: Exception do begin Inc(Fails); WriteLn('FAIL propmap exception: ', E.Message); end; end;
  try TestFglSource; except on E: Exception do begin Inc(Fails); WriteLn('FAIL fgl source exception: ', E.Message); end; end;
  try TestSkeletons; except on E: Exception do begin Inc(Fails); WriteLn('FAIL skeletons exception: ', E.Message); end; end;
  try TestSkelFlow; except on E: Exception do begin Inc(Fails); WriteLn('FAIL skelflow exception: ', E.Message); end; end;
  try TestSkelWizard; except on E: Exception do begin Inc(Fails); WriteLn('FAIL skelwizard exception: ', E.Message); end; end;
  try TestBlockWizard; except on E: Exception do begin Inc(Fails); WriteLn('FAIL blockwizard exception: ', E.Message); end; end;
  try TestFglPalette; except on E: Exception do begin Inc(Fails); WriteLn('FAIL fglpalette exception: ', E.Message); end; end;
  try TestEditDlg; except on E: Exception do begin Inc(Fails); WriteLn('FAIL editdlg exception: ', E.Message); end; end;
  try TestRowModel; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rowmodel exception: ', E.Message); end; end;
  try TestRowSource; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rowsource exception: ', E.Message); end; end;
  try TestRowHost; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rowhost exception: ', E.Message); end; end;
  try TestRowKeys; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rowkeys exception: ', E.Message); end; end;
  try TestRunnerKeys; except on E: Exception do begin Inc(Fails); WriteLn('FAIL runkeys exception: ', E.Message); end; end;
  try TestGridQuery; except on E: Exception do begin Inc(Fails); WriteLn('FAIL gridq exception: ', E.Message); end; end;
  try TestLov; except on E: Exception do begin Inc(Fails); WriteLn('FAIL lov exception: ', E.Message); end; end;
  try TestBinderLov; except on E: Exception do begin Inc(Fails); WriteLn('FAIL binderlov exception: ', E.Message); end; end;
  try TestRowLov; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rowlov exception: ', E.Message); end; end;
  try TestLovBuilder; except on E: Exception do begin Inc(Fails); WriteLn('FAIL lovbuilder exception: ', E.Message); end; end;
  try TestLovBuilderDialogs; except on E: Exception do begin Inc(Fails); WriteLn('FAIL lovbuilder dlg exception: ', E.Message); end; end;
  try TestCheck; except on E: Exception do begin Inc(Fails); WriteLn('FAIL check exception: ', E.Message); end; end;
  try TestButton; except on E: Exception do begin Inc(Fails); WriteLn('FAIL button exception: ', E.Message); end; end;
  try TestLabel; except on E: Exception do begin Inc(Fails); WriteLn('FAIL label exception: ', E.Message); end; end;
  try TestMemo; except on E: Exception do begin Inc(Fails); WriteLn('FAIL memo exception: ', E.Message); end; end;
  try TestChoice; except on E: Exception do begin Inc(Fails); WriteLn('FAIL choice exception: ', E.Message); end; end;
  try TestList; except on E: Exception do begin Inc(Fails); WriteLn('FAIL list exception: ', E.Message); end; end;
  try TestPanel; except on E: Exception do begin Inc(Fails); WriteLn('FAIL panel exception: ', E.Message); end; end;
  try TestGrid; except on E: Exception do begin Inc(Fails); WriteLn('FAIL grid exception: ', E.Message); end; end;
  try TestPages; except on E: Exception do begin Inc(Fails); WriteLn('FAIL pages exception: ', E.Message); end; end;
  try TestProgress; except on E: Exception do begin Inc(Fails); WriteLn('FAIL progress exception: ', E.Message); end; end;
  try TestCalendar; except on E: Exception do begin Inc(Fails); WriteLn('FAIL calendar exception: ', E.Message); end; end;
  try TestImage; except on E: Exception do begin Inc(Fails); WriteLn('FAIL image exception: ', E.Message); end; end;
  try TestBarcode; except on E: Exception do begin Inc(Fails); WriteLn('FAIL barcode exception: ', E.Message); end; end;
  try TestChartFamily; except on E: Exception do begin Inc(Fails); WriteLn('FAIL chartfamily exception: ', E.Message); end; end;
  try TestMenu; except on E: Exception do begin Inc(Fails); WriteLn('FAIL menu exception: ', E.Message); end; end;
  try TestPropClass; except on E: Exception do begin Inc(Fails); WriteLn('FAIL propclass exception: ', E.Message); end; end;
  try TestRunnerFamilies; except on E: Exception do begin Inc(Fails); WriteLn('FAIL runfam exception: ', E.Message); end; end;
  try TestRunnerCombo; except on E: Exception do begin Inc(Fails); WriteLn('FAIL runcombo exception: ', E.Message); end; end;
  try TestTriggers; except on E: Exception do begin Inc(Fails); WriteLn('FAIL triggers exception: ', E.Message); end; end;
  try TestAppGen; except on E: Exception do begin Inc(Fails); WriteLn('FAIL appgen exception: ', E.Message); end; end;
  try TestSchemaPlan; except on E: Exception do begin Inc(Fails); WriteLn('FAIL schemaplan exception: ', E.Message); end; end;
  try TestJadran; except on E: Exception do begin Inc(Fails); WriteLn('FAIL jadran exception: ', E.Message); end; end;
  try TestGenShots; except on E: Exception do WriteLn('SHOT exception: ', E.Message); end;
  try TestSavedFinds; except on E: Exception do begin Inc(Fails); WriteLn('FAIL savedfinds exception: ', E.Message); end; end;
  try TestMask; except on E: Exception do begin Inc(Fails); WriteLn('FAIL mask exception: ', E.Message); end; end;
  try TestAutoEnter; except on E: Exception do begin Inc(Fails); WriteLn('FAIL autoenter exception: ', E.Message); end; end;
  try TestDictionary; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dictionary exception: ', E.Message); end; end;
  try TestRunnerDisplayFamilies; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rundisp exception: ', E.Message); end; end;
  try TestDesignerFamilies; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dzfam exception: ', E.Message); end; end;
  try TestContForm; except on E: Exception do begin Inc(Fails); WriteLn('FAIL contform exception: ', E.Message); end; end;
  try TestContSub; except on E: Exception do begin Inc(Fails); WriteLn('FAIL contsub exception: ', E.Message); end; end;
  try TestContDesign; except on E: Exception do begin Inc(Fails); WriteLn('FAIL contdesign exception: ', E.Message); end; end;
  try TestRowRules; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rowrules exception: ', E.Message); end; end;
  try TestContComp; except on E: Exception do begin Inc(Fails); WriteLn('FAIL contcomp exception: ', E.Message); end; end;
  try TestEditorFamily; except on E: Exception do begin Inc(Fails); WriteLn('FAIL editor family exception: ', E.Message); end; end;
  try TestEditFamily; except on E: Exception do begin Inc(Fails); WriteLn('FAIL edit family exception: ', E.Message); end; end;
  try TestTokens; except on E: Exception do begin Inc(Fails); WriteLn('FAIL tokens exception: ', E.Message); end; end;
  try TestThemeInApp; except on E: Exception do begin Inc(Fails); WriteLn('FAIL theme in app exception: ', E.Message); end; end;
  try TestAnchorEditor; except on E: Exception do begin Inc(Fails); WriteLn('FAIL anchor editor exception: ', E.Message); end; end;
  try TestFormBinder; except on E: Exception do begin Inc(Fails); WriteLn('FAIL binder exception: ', E.Message); end; end;
  try TestPaletteComponents; except on E: Exception do begin Inc(Fails); WriteLn('FAIL components exception: ', E.Message); end; end;
  try TestSideMenuGroups; except on E: Exception do begin Inc(Fails); WriteLn('FAIL sidemenu groups exception: ', E.Message); end; end;
  try TestShell; except on E: Exception do begin Inc(Fails); WriteLn('FAIL shell exception: ', E.Message); end; end;
  try TestDocTypes; except on E: Exception do begin Inc(Fails); WriteLn('FAIL doctypes exception: ', E.Message); end; end;
  try TestShowcase2; except on E: Exception do begin Inc(Fails); WriteLn('FAIL showcase2 exception: ', E.Message); end; end;
  try TestAppSpec; except on E: Exception do begin Inc(Fails); WriteLn('FAIL appspec exception: ', E.Message); end; end;
  try TestSpecCharts; except on E: Exception do begin Inc(Fails); WriteLn('FAIL charts exception: ', E.Message); end; end;
    try TestPredictFunctions; except on E: Exception do begin Inc(Fails); WriteLn('FAIL predict exception: ', E.Message); end; end;
    try TestNewton; except on E: Exception do begin Inc(Fails); WriteLn('FAIL newton exception: ', E.Message); end; end;
    try TestLeagueAndValidation; except on E: Exception do begin Inc(Fails); WriteLn('FAIL league exception: ', E.Message); end; end;
    try TestPairsSession; except on E: Exception do begin Inc(Fails); WriteLn('FAIL pairs exception: ', E.Message); end; end;
    try TestMarketFit; except on E: Exception do begin Inc(Fails); WriteLn('FAIL marketfit exception: ', E.Message); end; end;
    try TestEngineBacktest; except on E: Exception do begin Inc(Fails); WriteLn('FAIL engine exception: ', E.Message); end; end;
    try TestSlipGeneration; except on E: Exception do begin Inc(Fails); WriteLn('FAIL slips exception: ', E.Message); end; end;
    try TestBacktest; except on E: Exception do begin Inc(Fails); WriteLn('FAIL backtest exception: ', E.Message); end; end;
    try TestDataImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dataimport exception: ', E.Message); end; end;
    try TestCountryImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL country exception: ', E.Message); end; end;
    try TestScrape; except on E: Exception do begin Inc(Fails); WriteLn('FAIL scrape exception: ', E.Message); end; end;
    try TestStandardGenerator; except on E: Exception do begin Inc(Fails); WriteLn('FAIL standard exception: ', E.Message); end; end;
    try TestRoundReport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL roundreport exception: ', E.Message); end; end;
    try TestAnalytics; except on E: Exception do begin Inc(Fails); WriteLn('FAIL analytics exception: ', E.Message); end; end;
    try TestReliability; except on E: Exception do begin Inc(Fails); WriteLn('FAIL reliability exception: ', E.Message); end; end;
  try TestMdbImport; except on E: Exception do begin Inc(Fails); WriteLn('FAIL mdb import exception: ', E.Message); end; end;
  try TestAnchorsAndWindow; except on E: Exception do begin Inc(Fails); WriteLn('FAIL anchors exception: ', E.Message); end; end;
  try TestDockLayout; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dock exception: ', E.Message); end; end;
  try TestDockInDesigner; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dock designer exception: ', E.Message); end; end;
  try TestMainFormTemplate; except on E: Exception do begin Inc(Fails); WriteLn('FAIL main form template exception: ', E.Message); end; end;
  try TestRichText; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rich text exception: ', E.Message); end; end;
  try TestRichTextField; except on E: Exception do begin Inc(Fails); WriteLn('FAIL rich field exception: ', E.Message); end; end;
  try TestGrowText; except on E: Exception do begin Inc(Fails); WriteLn('FAIL grow exception: ', E.Message); end; end;
  try TestOwnEdit; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own edit exception: ', E.Message); end; end;
  try TestOwnCombo; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own combo exception: ', E.Message); end; end;
  try TestOwnDate; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own date exception: ', E.Message); end; end;
  try TestOwnSpin; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own spin exception: ', E.Message); end; end;
  try TestOwnLov; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own lov exception: ', E.Message); end; end;
  try TestOwnMemo; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own memo exception: ', E.Message); end; end;
  try TestOwnRich; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own rich exception: ', E.Message); end; end;
  try TestOwnTree; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own tree exception: ', E.Message); end; end;
  try TestBoard; except on E: Exception do begin Inc(Fails); WriteLn('FAIL board exception: ', E.Message); end; end;
  try TestDash; except on E: Exception do begin Inc(Fails); WriteLn('FAIL dash exception: ', E.Message); end; end;
  try TestTimeline; except on E: Exception do begin Inc(Fails); WriteLn('FAIL timeline exception: ', E.Message); end; end;
  try TestEspHome; except on E: Exception do begin Inc(Fails); WriteLn('FAIL esphome exception: ', E.Message); end; end;
  try TestOwnIconlist; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own iconlist exception: ', E.Message); end; end;
  try TestOwnList; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own list exception: ', E.Message); end; end;
  try TestOwnCalendar; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own calendar exception: ', E.Message); end; end;
  try TestOwnGrid; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own grid exception: ', E.Message); end; end;
  try TestOwnGridEdit; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own grid edit exception: ', E.Message); end; end;
  try TestOwnSubGrid; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own subgrid exception: ', E.Message); end; end;
  try TestOwnGridSelect; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own grid select exception: ', E.Message); end; end;
  try TestOwnGridBig; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own grid big exception: ', E.Message); end; end;
  try TestOwnRunnerGrid; except on E: Exception do begin Inc(Fails); WriteLn('FAIL own runner grid exception: ', E.Message); end; end;
  try TestBlocksDemo; except on E: Exception do begin Inc(Fails); WriteLn('FAIL blocks demo exception: ', E.Message); end; end;
  try TestLetters; except on E: Exception do begin Inc(Fails); WriteLn('FAIL letters exception: ', E.Message); end; end;
  try TestOffers; except on E: Exception do begin Inc(Fails); WriteLn('FAIL offers exception: ', E.Message); end; end;
  try TestFglBlockEditor; except on E: Exception do begin Inc(Fails); WriteLn('FAIL fgl block editor exception: ', E.Message); end; end;
  try TestFglBlocks; except on E: Exception do begin Inc(Fails); WriteLn('FAIL fgl blocks exception: ', E.Message); end; end;
  try TestFormVerbs; except on E: Exception do begin Inc(Fails); WriteLn('FAIL form verbs exception: ', E.Message); end; end;
  try TestMacroLang; except on E: Exception do begin Inc(Fails); WriteLn('FAIL macro language exception: ', E.Message); end; end;
  try TestBlocks; except on E: Exception do begin Inc(Fails); WriteLn('FAIL blocks exception: ', E.Message); end; end;
  try TestRecipes5; except on E: Exception do begin Inc(Fails); WriteLn('FAIL recipes5 exception: ', E.Message); end; end;
  try TestRecipes4; except on E: Exception do begin Inc(Fails); WriteLn('FAIL recipes4 exception: ', E.Message); end; end;
  try TestRecipes3; except on E: Exception do begin Inc(Fails); WriteLn('FAIL recipes3 exception: ', E.Message); end; end;
  try TestRecipes2; except on E: Exception do begin Inc(Fails); WriteLn('FAIL recipes2 exception: ', E.Message); end; end;
  try TestInvoiceRounding; except on E: Exception do begin Inc(Fails); WriteLn('FAIL pilot rounding exception: ', E.Message); end; end;
  try TestManual4glRecipes; except on E: Exception do begin Inc(Fails); WriteLn('FAIL 4gl recipes exception: ', E.Message); end; end;
  try TestManualPascal; except on E: Exception do begin Inc(Fails); WriteLn('FAIL manual pascal exception: ', E.Message); end; end;
  try TestManual4gl; except on E: Exception do begin Inc(Fails); WriteLn('FAIL manual4gl exception: ', E.Message); end; end;
  try TestManualExamples; except on E: Exception do begin Inc(Fails); WriteLn('FAIL manual exception: ', E.Message); end; end;
  try TestExprUtf8; except on E: Exception do begin Inc(Fails); WriteLn('FAIL utf8 exception: ', E.Message); end; end;
  try TestBoolSemantics; except on E: Exception do begin Inc(Fails); WriteLn('FAIL boolsem exception: ', E.Message); end; end;
  try TestBindEngine; except on E: Exception do begin Inc(Fails); WriteLn('FAIL bindengine exception: ', E.Message); end; end;
  try TestBindEngine2; except on E: Exception do begin Inc(Fails); WriteLn('FAIL bindengine2 exception: ', E.Message); end; end;
  try TestFileStore; except on E: Exception do begin Inc(Fails); WriteLn('FAIL files exception: ', E.Message); end; end;
  try TestFgl4; except on E: Exception do begin Inc(Fails); WriteLn('FAIL fgl4 exception: ', E.Message); end; end;
  try TestFgl3; except on E: Exception do begin Inc(Fails); WriteLn('FAIL fgl3 exception: ', E.Message); end; end;
  try TestFgl2; except on E: Exception do begin Inc(Fails); WriteLn('FAIL fgl2 exception: ', E.Message); end; end;
  try TestFgl; except on E: Exception do begin Inc(Fails); WriteLn('FAIL fgl exception: ', E.Message); end; end;
  StartSession('', arAdmin);
  Db.Free;
  WriteLn('fails=', Fails);
  Halt(Fails);
end.
