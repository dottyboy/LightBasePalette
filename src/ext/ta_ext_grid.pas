unit ta_ext_grid;
{ Neobavezni pokretac obitelji Grid: TRxDBGrid (paket pl_RX) s pravim podnozjem zbrojeva. Registrira sve varijante mreze
  (readonly, editable, datasheet, entry) s pruzateljem 'rx'; ukljucuje se s SetPreferredProvider('rx').
  Bez ovog paketa obitelj koristi TDBGrid (ta_grid). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, DB, DBGrids, Grids, LCLType, rxdbgrid, ta_family, ta_grid;

type
  TaGridRxEngine = class(TaGridDataEngine)
  private
    FGrid: TRxDBGrid;
    FSumFields: string;
    FZebra: Boolean;
    procedure BuildColumns;
    procedure ApplyFooter;
    procedure GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GridKeyDownEntry(var Key: Word; Shift: TShiftState);
  protected
    function Kind: TaGridVariant; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    procedure SetSource(ASource: TDataSource); override;
    function InnerDBGrid: TDBGrid; override;
    function FooterText: string; override;
    property RxGrid: TRxDBGrid read FGrid;
  end;

  TaGridRxEditableEngine = class(TaGridRxEngine)
  protected
    function Kind: TaGridVariant; override;
  end;

  TaGridRxDatasheetEngine = class(TaGridRxEngine)
  protected
    function Kind: TaGridVariant; override;
  end;

  TaGridRxEntryEngine = class(TaGridRxEngine)
  protected
    function Kind: TaGridVariant; override;
  end;

implementation

uses
  ta_tokens;

constructor TaGridRxEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FGrid := TRxDBGrid.Create(nil);
  case Kind of
    gvReadOnly:
      begin
        FGrid.ReadOnly := True;
        FGrid.Options := FGrid.Options - [dgEditing] + [dgRowSelect];
      end;
    gvEditable:
      begin
        FGrid.ReadOnly := False;
        FGrid.Options := FGrid.Options + [dgEditing, dgTabs, dgCancelOnExit];
      end;
    gvDatasheet:
      begin
        FGrid.ReadOnly := False;
        FGrid.Options := FGrid.Options + [dgEditing, dgTabs] - [dgIndicator];
        FGrid.DefaultRowHeight := 22;
      end;
    gvEntry:
      begin
        FGrid.ReadOnly := False;
        FGrid.Options := FGrid.Options + [dgEditing, dgTabs, dgCancelOnExit];
      end;
  end;
  AttachInner(FGrid);
  { mreza je i sama unutarnja kontrola: AttachInner joj je zauzeo OnKeyDown, pa se lanac vraca ovdje }
  FGrid.OnKeyDown := @GridKeyDown;
end;

class function TaGridRxEngine.Provider: string;
begin
  Result := 'rx';
end;

function TaGridRxEngine.Kind: TaGridVariant;
begin
  Result := gvReadOnly;
end;

function TaGridRxEditableEngine.Kind: TaGridVariant;
begin
  Result := gvEditable;
end;

function TaGridRxDatasheetEngine.Kind: TaGridVariant;
begin
  Result := gvDatasheet;
end;

function TaGridRxEntryEngine.Kind: TaGridVariant;
begin
  Result := gvEntry;
end;

function TaGridRxEngine.GetText: string;
begin
  Result := '';
end;

procedure TaGridRxEngine.SetText(const AValue: string);
begin
end;

procedure TaGridRxEngine.SetReadOnly(AValue: Boolean);
begin
  if AValue then FGrid.ReadOnly := True else FGrid.ReadOnly := Kind = gvReadOnly;
end;

function TaGridRxEngine.InnerDBGrid: TDBGrid;
begin
  { TRxDBGrid je TCustomDBGrid, ne TDBGrid: za ispitivanje stupaca vidi RxGrid }
  Result := nil;
end;

{ stupci iz polja skupa podataka, da podnozje ima gdje zbrajati }
procedure TaGridRxEngine.BuildColumns;
var
  Ds: TDataSet;
  I: Integer;
  C: TRxColumn;
begin
  if FGrid.DataSource = nil then Exit;
  Ds := FGrid.DataSource.DataSet;
  if (Ds = nil) or not Ds.Active then Exit;
  if FGrid.Columns.Count > 0 then Exit;
  for I := 0 to Ds.FieldCount - 1 do
  begin
    C := TRxColumn(FGrid.Columns.Add);
    C.FieldName := Ds.Fields[I].FieldName;
    C.Title.Caption := Ds.Fields[I].DisplayLabel;
  end;
end;

procedure TaGridRxEngine.ApplyFooter;
var
  I: Integer;
  Names: TStringList;
begin
  Names := TStringList.Create;
  try
    Names.CommaText := StringReplace(FSumFields, ' ', '', [rfReplaceAll]);
    BuildColumns;
    FGrid.FooterOptions.Active := Names.Count > 0;
    if Names.Count > 0 then FGrid.FooterOptions.RowCount := 1;
    for I := 0 to FGrid.Columns.Count - 1 do
      if Names.IndexOf(FGrid.Columns[I].FieldName) >= 0 then
      begin
        TRxColumn(FGrid.Columns[I]).Footer.ValueType := fvtSum;
        TRxColumn(FGrid.Columns[I]).Footer.DisplayFormat := '#,##0.00';
      end
      else TRxColumn(FGrid.Columns[I]).Footer.ValueType := fvtNon;
  finally
    Names.Free;
  end;
end;

procedure TaGridRxEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaGridOptions then
  begin
    if TaGridOptions(AOptions).RowHeight > 0 then FGrid.DefaultRowHeight := TaGridOptions(AOptions).RowHeight;
    FZebra := TaGridOptions(AOptions).Zebra;
    if FZebra then FGrid.AlternateColor := TokenColor(ActiveTokens.Soft) else FGrid.AlternateColor := FGrid.Color;
    FSumFields := TaGridOptions(AOptions).SumFields;
    ApplyFooter;
  end;
end;

procedure TaGridRxEngine.SetSource(ASource: TDataSource);
begin
  FGrid.DataSource := ASource;
  ApplyFooter;
end;

function TaGridRxEngine.FooterText: string;
var
  I: Integer;
begin
  { zbrojevi stoje u podnozju mreze; ovdje samo popis stupaca koji se zbrajaju }
  Result := '';
  for I := 0 to FGrid.Columns.Count - 1 do
    if TRxColumn(FGrid.Columns[I]).Footer.ValueType = fvtSum then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + FGrid.Columns[I].FieldName;
    end;
end;

procedure TaGridRxEngine.GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Ds: TDataSet;
  Last: Integer;
begin
  GridKeyDownEntry(Key, Shift);
  if Key <> 0 then InnerKeyDown(Sender, Key, Shift);
end;

procedure TaGridRxEngine.GridKeyDownEntry(var Key: Word; Shift: TShiftState);
var
  Ds: TDataSet;
  Last: Integer;
begin
  if Kind <> gvEntry then Exit;
  if (Key <> VK_TAB) and (Key <> VK_RETURN) then Exit;
  if (ssShift in Shift) or FGrid.ReadOnly then Exit;
  Ds := nil;
  if FGrid.DataSource <> nil then Ds := FGrid.DataSource.DataSet;
  if (Ds = nil) or not Ds.Active then Exit;
  if FGrid.SelectedIndex < FGrid.Columns.Count - 1 then Exit;
  if Ds.State = dsInsert then Exit;
  if Ds.State = dsEdit then Ds.Post;
  Ds.DisableControls;
  try
    Last := Ds.RecNo;
    Ds.Next;
    if Ds.RecNo = Last then begin Ds.Append; Key := 0; end
    else Ds.Prior;
  finally
    Ds.EnableControls;
  end;
end;

initialization
  RegisterEngine('Grid', 'readonly', TaGridRxEngine);
  RegisterEngine('Grid', 'editable', TaGridRxEditableEngine);
  RegisterEngine('Grid', 'datasheet', TaGridRxDatasheetEngine);
  RegisterEngine('Grid', 'entry', TaGridRxEntryEngine);

end.
