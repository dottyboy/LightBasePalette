unit ta_gridview;
{ Prikaz tablice u izvrsitelju formi (datasheet, podforme): jedno sucelje, a iza njega ili izvorni TDBGrid ili vlastita tablica
  (ta_owngrid) kad je pruzatelj 'own'. Izvrsitelj ne pozna razliku: stupci se zadaju po imenu polja, a uvjetno bojanje redaka i
  klik na naslov stizu kroz dva dogadjaja. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, DB, DBGrids, Grids, ta_owngrid;

type
  TaGridKind = (gkMain, gkSplit, gkSub);

  TaViewTitleEvent = procedure(Sender: TObject; const AFieldName: string) of object;
  { boje retka; AFore/ABack su clNone ako ih mreza nije odredila }
  TaViewRowStyleEvent = procedure(Sender: TObject; ASelected: Boolean; var AFore, ABack: TColor; var ABold: Boolean) of object;

  TaGridView = class
  private
    FDb: TDBGrid;
    FOwn: TaOwnGrid;
    FOnTitle: TaViewTitleEvent;
    FOnRow: TaViewRowStyleEvent;
    procedure LclTitle(Column: TColumn);
    procedure LclPrepare(Sender: TObject; DataCol: Integer; Column: TColumn; AState: TGridDrawState);
    procedure OwnTitle(Sender: TObject; AColumn: TaGridColumn);
    procedure OwnPrepare(Sender: TObject; AColumn: TaGridColumn; ASelectedRow: Boolean; var AStyle: TaGridCellStyle);
    function GetControl: TWinControl;
    function GetReadOnly: Boolean;
    procedure SetReadOnly(AValue: Boolean);
    procedure SetOnRow(AValue: TaViewRowStyleEvent);
    procedure SetOnTitle(AValue: TaViewTitleEvent);
  public
    constructor Create(AOwner: TComponent; AParent: TWinControl; AKind: TaGridKind; AUseOwn, AReadOnly: Boolean; ASource: TDataSource);
    { omotava vec postojecu vlastitu tablicu (potkartica) }
    constructor Wrap(AOwn: TaOwnGrid);
    function ColCount: Integer;
    function ColFieldName(AIndex: Integer): string;
    function ColTitle(AIndex: Integer): string;
    function ColVisible(AIndex: Integer): Boolean;
    function ColField(AIndex: Integer): TField;
    procedure SetColTitle(AIndex: Integer; const AValue: string);
    procedure SetColWidth(AIndex, AWidth: Integer);
    procedure SetColVisible(AIndex: Integer; AValue: Boolean);
    procedure SetColReadOnly(AIndex: Integer);
    procedure SetColPick(AIndex: Integer; AItems: TStrings);
    procedure ClearColumns;
    function AddColumn(const AFieldName, ATitle: string): Integer;
    function SelectedField: TField;
    { oznaka sortiranja na naslovu stupca ('' = nema) }
    procedure ApplySort(const AFieldName: string; ADescending: Boolean);
    { odvoji stupce od polja prije nego se skup oslobodi }
    procedure ReleaseFields;
    property Control: TWinControl read GetControl;
    property DBGrid: TDBGrid read FDb;
    property Own: TaOwnGrid read FOwn;
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly;
    property OnTitleClick: TaViewTitleEvent read FOnTitle write SetOnTitle;
    property OnRowStyle: TaViewRowStyleEvent read FOnRow write SetOnRow;
  end;

function StripSortMark(const C: string): string;

implementation

function StripSortMark(const C: string): string;
begin
  Result := C;
  if (Length(Result) > 4) and ((Copy(Result, Length(Result) - 3, 4) = ' ' + #$E2#$96#$B2) or
     (Copy(Result, Length(Result) - 3, 4) = ' ' + #$E2#$96#$BC)) then
    Result := Copy(Result, 1, Length(Result) - 4);
end;

constructor TaGridView.Create(AOwner: TComponent; AParent: TWinControl; AKind: TaGridKind; AUseOwn, AReadOnly: Boolean; ASource: TDataSource);
begin
  inherited Create;
  if AUseOwn then
  begin
    FOwn := TaOwnGrid.Create(AOwner);
    FOwn.Parent := AParent;
    FOwn.DataSource := ASource;
    FOwn.OnTitleClick := @OwnTitle;
    case AKind of
      gkSplit:
        begin
          FOwn.Align := alBottom;
          FOwn.Height := 220;
          FOwn.AllowEdit := False;
          FOwn.ReadOnly := True;
        end;
      gkSub:
        begin
          FOwn.Align := alClient;
          FOwn.AllowEdit := True;
          FOwn.ReadOnly := AReadOnly;
        end;
    else
      FOwn.Align := alClient;
      FOwn.AllowEdit := True;
      FOwn.ReadOnly := AReadOnly;
    end;
  end
  else
  begin
    FDb := TDBGrid.Create(AOwner);
    FDb.Options := FDb.Options + [dgDisplayMemoText];
    FDb.Parent := AParent;
    FDb.DataSource := ASource;
    FDb.OnTitleClick := @LclTitle;
    case AKind of
      gkSplit:
        begin
          FDb.Align := alBottom;
          FDb.Height := 220;
          FDb.Options := FDb.Options - [dgEditing];
          FDb.ReadOnly := True;
        end;
      gkSub:
        begin
          FDb.Align := alClient;
          { redci se tipkaju izravno u mrezu: Dolje na zadnjem retku ili "+" dodaje jedan }
          FDb.Options := FDb.Options + [dgEditing, dgTabs, dgCancelOnExit, dgTitles, dgIndicator];
          FDb.ReadOnly := AReadOnly;
        end;
    else
      FDb.Align := alClient;
      FDb.ReadOnly := AReadOnly;
    end;
  end;
end;

constructor TaGridView.Wrap(AOwn: TaOwnGrid);
begin
  inherited Create;
  FOwn := AOwn;
  FOwn.OnTitleClick := @OwnTitle;
end;

function TaGridView.GetControl: TWinControl;
begin
  if FOwn <> nil then Result := FOwn else Result := FDb;
end;

function TaGridView.GetReadOnly: Boolean;
begin
  if FOwn <> nil then Result := FOwn.ReadOnly else Result := FDb.ReadOnly;
end;

procedure TaGridView.SetReadOnly(AValue: Boolean);
begin
  if FOwn <> nil then FOwn.ReadOnly := AValue else FDb.ReadOnly := AValue;
end;

procedure TaGridView.SetOnTitle(AValue: TaViewTitleEvent);
begin
  FOnTitle := AValue;
end;

procedure TaGridView.SetOnRow(AValue: TaViewRowStyleEvent);
begin
  FOnRow := AValue;
  if FOwn <> nil then
  begin
    if Assigned(AValue) then FOwn.OnPrepareCell := @OwnPrepare else FOwn.OnPrepareCell := nil;
  end
  else if Assigned(AValue) then FDb.OnPrepareCanvas := @LclPrepare
  else FDb.OnPrepareCanvas := nil;
end;

procedure TaGridView.LclTitle(Column: TColumn);
begin
  if (Column <> nil) and (Column.FieldName <> '') and Assigned(FOnTitle) then FOnTitle(Self, Column.FieldName);
end;

procedure TaGridView.OwnTitle(Sender: TObject; AColumn: TaGridColumn);
begin
  if (AColumn <> nil) and (AColumn.FieldName <> '') and Assigned(FOnTitle) then FOnTitle(Self, AColumn.FieldName);
end;

procedure TaGridView.LclPrepare(Sender: TObject; DataCol: Integer; Column: TColumn; AState: TGridDrawState);
var
  Fore, Back: TColor;
  Bold: Boolean;
begin
  if not Assigned(FOnRow) then Exit;
  Fore := FDb.Canvas.Font.Color;
  Back := FDb.Canvas.Brush.Color;
  Bold := fsBold in FDb.Canvas.Font.Style;
  FOnRow(Self, gdSelected in AState, Fore, Back, Bold);
  FDb.Canvas.Font.Color := Fore;
  FDb.Canvas.Brush.Color := Back;
  if Bold then FDb.Canvas.Font.Style := FDb.Canvas.Font.Style + [fsBold];
end;

procedure TaGridView.OwnPrepare(Sender: TObject; AColumn: TaGridColumn; ASelectedRow: Boolean; var AStyle: TaGridCellStyle);
begin
  if not Assigned(FOnRow) then Exit;
  FOnRow(Self, ASelectedRow, AStyle.Fore, AStyle.Back, AStyle.Bold);
end;

function TaGridView.ColCount: Integer;
begin
  if FOwn <> nil then Result := FOwn.Columns.Count else Result := FDb.Columns.Count;
end;

function TaGridView.ColFieldName(AIndex: Integer): string;
begin
  if FOwn <> nil then Result := FOwn.Columns[AIndex].FieldName else Result := FDb.Columns[AIndex].FieldName;
end;

function TaGridView.ColTitle(AIndex: Integer): string;
begin
  if FOwn <> nil then Result := FOwn.Columns[AIndex].Title else Result := FDb.Columns[AIndex].Title.Caption;
end;

function TaGridView.ColVisible(AIndex: Integer): Boolean;
begin
  if FOwn <> nil then Result := FOwn.Columns[AIndex].Visible else Result := FDb.Columns[AIndex].Visible;
end;

function TaGridView.ColField(AIndex: Integer): TField;
begin
  if FOwn <> nil then Result := FOwn.Columns[AIndex].Field else Result := FDb.Columns[AIndex].Field;
end;

procedure TaGridView.SetColTitle(AIndex: Integer; const AValue: string);
begin
  if FOwn <> nil then FOwn.Columns[AIndex].Title := AValue else FDb.Columns[AIndex].Title.Caption := AValue;
end;

procedure TaGridView.SetColWidth(AIndex, AWidth: Integer);
begin
  if FOwn <> nil then FOwn.Columns[AIndex].Width := AWidth else FDb.Columns[AIndex].Width := AWidth;
end;

procedure TaGridView.SetColVisible(AIndex: Integer; AValue: Boolean);
begin
  if FOwn <> nil then FOwn.Columns[AIndex].Visible := AValue else FDb.Columns[AIndex].Visible := AValue;
end;

procedure TaGridView.SetColReadOnly(AIndex: Integer);
begin
  if FOwn <> nil then FOwn.Columns[AIndex].ReadOnly := True else FDb.Columns[AIndex].ReadOnly := True;
end;

procedure TaGridView.SetColPick(AIndex: Integer; AItems: TStrings);
begin
  if FOwn <> nil then
  begin
    FOwn.Columns[AIndex].PickList.Assign(AItems);
    FOwn.Columns[AIndex].Alignment := taLeftJustify;
  end
  else
  begin
    FDb.Columns[AIndex].ButtonStyle := cbsPickList;
    FDb.Columns[AIndex].Alignment := taLeftJustify;
    FDb.Columns[AIndex].PickList.Assign(AItems);
  end;
end;

procedure TaGridView.ClearColumns;
begin
  if FOwn <> nil then FOwn.ClearColumns else FDb.Columns.Clear;
end;

function TaGridView.AddColumn(const AFieldName, ATitle: string): Integer;
var
  C: TaGridColumn;
  D: TColumn;
begin
  if FOwn <> nil then
  begin
    C := FOwn.AddFieldColumn(AFieldName);
    C.Title := ATitle;
    Result := C.Index;
  end
  else
  begin
    D := FDb.Columns.Add;
    D.FieldName := AFieldName;
    D.Title.Caption := ATitle;
    Result := D.Index;
  end;
end;

function TaGridView.SelectedField: TField;
begin
  if FOwn <> nil then Result := FOwn.SelectedField else Result := FDb.SelectedField;
end;

procedure TaGridView.ApplySort(const AFieldName: string; ADescending: Boolean);
var
  I: Integer;
  C: string;
begin
  if FOwn <> nil then
  begin
    FOwn.SortField := AFieldName;
    FOwn.SortDescending := ADescending;
    FOwn.Invalidate;
    Exit;
  end;
  for I := 0 to FDb.Columns.Count - 1 do
  begin
    C := StripSortMark(FDb.Columns[I].Title.Caption);
    if (AFieldName <> '') and SameText(FDb.Columns[I].FieldName, AFieldName) then
      if ADescending then C := C + ' ' + #$E2#$96#$BC else C := C + ' ' + #$E2#$96#$B2;
    FDb.Columns[I].Title.Caption := C;
  end;
end;

procedure TaGridView.ReleaseFields;
var
  I: Integer;
begin
  if FDb <> nil then
    for I := 0 to FDb.Columns.Count - 1 do FDb.Columns[I].Field := nil;
  if FOwn <> nil then FOwn.DataSource := nil;
end;

end.
