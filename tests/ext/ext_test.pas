program ext_test;
{ Ispitivanje neobaveznog paketa typhaccess_ext: pokretaci TAChart (Chart) i TRxDBGrid (Grid), prebacivanje pruzatelja,
  povratak na LCL pokretace. Pokretanje: bash run.sh }

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Controls, Graphics, SysUtils, Classes, DB, DBGrids, LCLType, rxdbgrid, TAGraph, TASeries,
  ta_meta, ta_family, ta_chartbox, ta_grid, ta_ext_chart, ta_ext_grid;

var
  Fails: Integer = 0;

procedure Check(ACond: Boolean; const AMsg: string);
begin
  if ACond then WriteLn('ok   ', AMsg)
  else begin Inc(Fails); WriteLn('FAIL ', AMsg); end;
end;

procedure TestChart;
var
  Fm: TForm;
  C: TaChart;
  V: TaChartVariant;
begin
  Fm := TForm.CreateNew(nil);
  try
    SetPreferredProvider('');
    C := TaChart.Create(Fm); C.Parent := Fm;
    Check(C.Engine.Inner is TaChartPaint, 'ext chart: bez pruzatelja je vlastito crtanje');
    SetPreferredProvider('tachart');
    C.Free;
    C := TaChart.Create(Fm); C.Parent := Fm; C.SetBounds(0, 0, 300, 200);
    C.Items.Add('Sij=10'); C.Items.Add('Velj=25'); C.Items.Add('Ozu=15');
    C.Options.Title := 'Prihodi'; C.Options := C.Options;
    Check(C.Engine.Inner is TChart, 'ext chart: pruzatelj tachart daje TChart');
    Check((C.Engine is TaTaChartEngine) and (TaTaChartEngine(C.Engine).Source.Count = 3), 'ext chart: stavke postaju izvor podataka (3)');
    Check(TaTaChartEngine(C.Engine).Series is TBarSeries, 'ext chart: bar je TBarSeries');
    Check(Trim(TaTaChartEngine(C.Engine).Chart.Title.Text.Text) = 'Prihodi', 'ext chart: naslov');
    C.Variant := cvLine;
    Check(TaTaChartEngine(C.Engine).Series is TLineSeries, 'ext chart: line je TLineSeries');
    C.Variant := cvPie;
    Check(TaTaChartEngine(C.Engine).Series is TPieSeries, 'ext chart: pie je TPieSeries');
    C.Variant := cvGauge;
    Check(C.Engine.Inner is TaChartPaint, 'ext chart: gauge ostaje vlastito crtanje (nema ga u TAChartu)');
    C.Variant := cvBar;
    C.Items.Add('Tra=5');
    Check(TaTaChartEngine(C.Engine).Source.Count = 4, 'ext chart: nova stavka se vidi u izvoru');
    SetPreferredProvider('');
    C.Variant := cvLine;
    C.Variant := cvBar;
    Check(C.Engine.Inner is TaChartPaint, 'ext chart: povratak na LCL pokretac');
    V := cvBar;
    if V = cvPie then;
  finally
    SetPreferredProvider('');
    Fm.Free;
  end;
end;

procedure TestGrid;
var
  Fm: TForm;
  G: TaGrid;
  Db: TAppDb;
  Q: TDataSet;
  Ds: TDataSource;
  Key: Word;
begin
  Fm := TForm.CreateNew(nil);
  Db := TAppDb.Create;
  Ds := TDataSource.Create(nil);
  try
    if FileExists('/tmp/ta_ext_grid.db') then DeleteFile('/tmp/ta_ext_grid.db');
    Db.Open('/tmp/ta_ext_grid.db');
    Db.Conn.ExecuteDirect('CREATE TABLE st (id INTEGER PRIMARY KEY, naziv VARCHAR(20), iznos DECIMAL(12,2))');
    Db.Conn.ExecuteDirect('INSERT INTO st (naziv, iznos) VALUES (''a'', 10), (''b'', 20.5), (''c'', 5)');
    Q := Db.NewQuery('SELECT * FROM st ORDER BY id');
    Q.Open;
    Ds.DataSet := Q;
    SetPreferredProvider('');
    G := TaGrid.Create(Fm); G.Parent := Fm; G.SetBounds(0, 0, 400, 200);
    Check(G.Engine is TaGridEngine, 'ext grid: bez pruzatelja je TDBGrid');
    G.Free;
    SetPreferredProvider('rx');
    G := TaGrid.Create(Fm); G.Parent := Fm; G.SetBounds(0, 0, 400, 200);
    G.DataSource := Ds;
    Check((G.Engine is TaGridRxEngine) and (G.Engine.Inner is TRxDBGrid), 'ext grid: pruzatelj rx daje TRxDBGrid');
    Check(TaGridRxEngine(G.Engine).RxGrid.DataSource = Ds, 'ext grid: izvor podataka je prosljeden');
    Check(TaGridRxEngine(G.Engine).RxGrid.ReadOnly, 'ext grid: readonly');
    G.Options.SumFields := 'iznos'; G.Options := G.Options;
    Check(TaGridRxEngine(G.Engine).RxGrid.FooterOptions.Active, 'ext grid: podnozje je ukljuceno');
    Check(G.FooterText = 'iznos', 'ext grid: zbraja stupac iznos (' + G.FooterText + ')');
    G.Variant := gvEntry;
    Check((G.Engine.Inner is TRxDBGrid) and not TaGridRxEngine(G.Engine).RxGrid.ReadOnly, 'ext grid: entry je izmjenjiva mreza');
    Q.Last;
    TaGridRxEngine(G.Engine).RxGrid.SelectedIndex := TaGridRxEngine(G.Engine).RxGrid.Columns.Count - 1;
    Key := VK_TAB;
    TaGridRxEngine(G.Engine).RxGrid.OnKeyDown(TaGridRxEngine(G.Engine).RxGrid, Key, []);
    Check((Ord(Q.State) = 3) and (Key = 0), 'ext grid: entry - Tab iz zadnje celije dodaje red');
    Q.Cancel;
    SetPreferredProvider('');
    G.Variant := gvReadOnly;
    G.Variant := gvEditable;
    Check(G.Engine is TaGridEngine, 'ext grid: povratak na LCL pokretac');
    G.DataSource := nil;
    Q.Close;
    Q.Free;
  finally
    SetPreferredProvider('');
    Ds.Free;
    Db.Free;
    Fm.Free;
  end;
end;

begin
  Application.Initialize;
  try TestChart; except on E: Exception do begin Inc(Fails); WriteLn('FAIL chart exception: ', E.Message); end; end;
  try TestGrid; except on E: Exception do begin Inc(Fails); WriteLn('FAIL grid exception: ', E.Message); end; end;
  WriteLn('fails=', Fails);
  if Fails > 0 then Halt(1);
end.
