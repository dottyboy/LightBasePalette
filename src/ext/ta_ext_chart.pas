unit ta_ext_chart;
{ Neobavezni pokretac obitelji Chart: TAChart (paket lz_taChart). Registrira varijante bar, line i pie s pruzateljem
  'tachart'; ukljucuje se s SetPreferredProvider('tachart') (ili FindEngine(..., 'tachart')). Bez ovog paketa
  obitelj crta vlastitim pokretacem (ta_chartbox). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, TAGraph, TASeries, TASources, TACustomSeries, ta_family, ta_chartbox;

type
  TaTaChartEngine = class(TaChartDataEngine)
  private
    FChart: TChart;
    FSource: TListChartSource;
    FSeries: TCustomChartSeries;
  protected
    function Kind: TaChartVariant; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetItems(AItems: TStrings); override;
    procedure SetData(ALabels: TStrings; const AValues: array of Double); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    property Chart: TChart read FChart;
    property Series: TCustomChartSeries read FSeries;
    property Source: TListChartSource read FSource;
  end;

  TaTaChartLineEngine = class(TaTaChartEngine)
  protected
    function Kind: TaChartVariant; override;
  end;

  TaTaChartPieEngine = class(TaTaChartEngine)
  protected
    function Kind: TaChartVariant; override;
  end;

implementation

uses
  TAChartUtils;

constructor TaTaChartEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FChart := TChart.Create(nil);
  FSource := TListChartSource.Create(FChart);
  case Kind of
    cvLine:
      begin
        FSeries := TLineSeries.Create(FChart);
        TLineSeries(FSeries).Source := FSource;
      end;
    cvPie:
      begin
        FSeries := TPieSeries.Create(FChart);
        TPieSeries(FSeries).Source := FSource;
      end;
  else
    FSeries := TBarSeries.Create(FChart);
    TBarSeries(FSeries).Source := FSource;
  end;
  FChart.AddSeries(FSeries);
  AttachInner(FChart);
end;

class function TaTaChartEngine.Provider: string;
begin
  Result := 'tachart';
end;

function TaTaChartEngine.Kind: TaChartVariant;
begin
  Result := cvBar;
end;

function TaTaChartLineEngine.Kind: TaChartVariant;
begin
  Result := cvLine;
end;

function TaTaChartPieEngine.Kind: TaChartVariant;
begin
  Result := cvPie;
end;

function TaTaChartEngine.GetText: string;
begin
  Result := Trim(FChart.Title.Text.Text);
end;

procedure TaTaChartEngine.SetText(const AValue: string);
begin
  FChart.Title.Text.Text := AValue;
  FChart.Title.Visible := AValue <> '';
end;

procedure TaTaChartEngine.SetItems(AItems: TStrings);
var
  Lb: TStringList;
  Vals: TaChartValues;
begin
  Lb := TStringList.Create;
  try
    ParseChartItems(AItems, Lb, Vals);
    SetData(Lb, Vals);
  finally
    Lb.Free;
  end;
end;

procedure TaTaChartEngine.SetData(ALabels: TStrings; const AValues: array of Double);
var
  I: Integer;
begin
  FSource.Clear;
  for I := 0 to High(AValues) do
    if I < ALabels.Count then FSource.Add(I, AValues[I], ALabels[I])
    else FSource.Add(I, AValues[I], '');
end;

procedure TaTaChartEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaChartOptions then SetText(TaChartOptions(AOptions).Title);
end;

initialization
  RegisterEngine('Chart', 'bar', TaTaChartEngine);
  RegisterEngine('Chart', 'line', TaTaChartLineEngine);
  RegisterEngine('Chart', 'pie', TaTaChartPieEngine);

end.
