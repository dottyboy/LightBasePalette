unit ta_contform;
{ Neprekidna forma (poglavlje 20 plana): zaglavlje + redovi (TaRowsView) + podnozje.
  Odjeljci dolaze iz definicije forme: kontrole sa Section = header / detail / footer.
    Zaglavlje: oznake sa svojstvom sort=polje (klik = sortiranje, ▲▼), polja sa svojstvom filter=polje (filtar stupca),
               gumbi i sve ostalo kao obicne kontrole.
    Podnozje:  polja ciji ControlSource pocinje s "=": =Sum(iznos), =Count(), =Avg(iznos), =Min(...), =Max(...);
               racuna se SQL-om nad CIJELIM izvorom uz isti filtar i vezu (ne samo nad vidljivim redovima).
  Kontrole zaglavlja i podnozja poravnate su s detaljem (isti X, plus sirina birača zapisa). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, Variants, ta_meta, ta_formdef, ta_rowsource, ta_rowhost,
  ta_edit, ta_expr, ta_tokens;

type
  TaBodyButtonEvent = procedure(Sender: TObject; const AControlName: string; ARow: Integer) of object;

  TaContinuousBody = class(TPanel)
  private
    FOnButton: TaBodyButtonEvent;
    FDb: TAppDb;
    FDef: TaFormDef;
    FSource: TaRowSource;
    FHost: TaRowsView;
    FHeader, FFooter: TPanel;
    FHeadCtrls: TList;       { kontrole zaglavlja }
    FFootCtrls: TList;
    FHeadDefs, FFootDefs: TList;   { definicije, isti redoslijed kao kontrole }
    FSortField: string;
    FSortDesc: Boolean;
    FBaseFilter: string;
    procedure SectionButton(Sender: TObject);
    procedure RowButton(Sender: TObject; ADef: TaControlDef; ARow: Integer);
    procedure SortClick(Sender: TObject);
    procedure FilterChanged(Sender: TObject);
    procedure DataChanged(Sender: TObject);
    function BuildSection(APanel: TPanel; const ASection: string; AList: TList): Integer;
    function SectionControl(APanel: TPanel; ADef: TaControlDef; AList: TList): TControl;
    procedure UpdateSortCaptions;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(ADb: TAppDb; ADef: TaFormDef);
    { veza glavna-detalj za podformu }
    procedure SetMaster(const AChildField, AValue: string);
    { sastavi filtar iz polja zaglavlja i primijeni; poziva se i s tipkovnice }
    procedure ApplyFilters;
    procedure RefreshFooter;
    procedure SortBy(const AField: string; ADescending: Boolean);
    { za testove i skripte }
    function HeaderControl(AName: string): TControl;
    function FooterControl(AName: string): TControl;
    procedure ClickHeader(const AName: string);
    procedure TypeFilter(const AName, AText: string);
    function FooterText(const AName: string): string;
    { gumb u zaglavlju, redu ili podnozju: naziv kontrole i trenutni red }
    property OnButton: TaBodyButtonEvent read FOnButton write FOnButton;
    property Host: TaRowsView read FHost;
    property Source: TaRowSource read FSource;
    property Header: TPanel read FHeader;
    property Footer: TPanel read FFooter;
    property SortField: string read FSortField;
    property SortDescending: Boolean read FSortDesc;
  end;

implementation

constructor TaContinuousBody.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FHeadCtrls := TList.Create;
  FFootCtrls := TList.Create;
  FHeadDefs := TList.Create;
  FFootDefs := TList.Create;
  FHeader := TPanel.Create(Self);
  FHeader.Parent := Self;
  FHeader.Align := alTop;
  FHeader.BevelOuter := bvNone;
  FFooter := TPanel.Create(Self);
  FFooter.Parent := Self;
  FFooter.Align := alBottom;
  FFooter.BevelOuter := bvNone;
  FHost := TaRowsView.Create(Self);
  FHost.Parent := Self;
  FHost.Align := alClient;
  FHost.OnDataChange := @DataChanged;
  FHost.OnButton := @RowButton;
end;

destructor TaContinuousBody.Destroy;
begin
  FHeadCtrls.Free;
  FFootCtrls.Free;
  FHeadDefs.Free;
  FFootDefs.Free;
  FSource.Free;
  inherited Destroy;
end;

procedure TaContinuousBody.SectionButton(Sender: TObject);
var
  I: Integer;
  Nm: string;
begin
  Nm := '';
  I := TControl(Sender).Tag;
  if FHeadCtrls.IndexOf(Sender) >= 0 then Nm := TaControlDef(FHeadDefs[I]).Name
  else if FFootCtrls.IndexOf(Sender) >= 0 then Nm := TaControlDef(FFootDefs[I]).Name;
  if Assigned(FOnButton) then FOnButton(Self, Nm, FHost.Model.Current);
end;

procedure TaContinuousBody.RowButton(Sender: TObject; ADef: TaControlDef; ARow: Integer);
begin
  if Assigned(FOnButton) then FOnButton(Self, ADef.Name, ARow);
end;

function TaContinuousBody.SectionControl(APanel: TPanel; ADef: TaControlDef; AList: TList): TControl;
var
  K: string;
  Ed: TaEdit;
begin
  K := LowerCase(ADef.Kind);
  Result := nil;
  if K = 'label' then
  begin
    Result := TLabel.Create(APanel);
    TLabel(Result).Caption := ADef.Caption;
    TLabel(Result).Font.Bold := ADef.Bold;
    if ADef.GetX('sort') <> '' then
    begin
      TLabel(Result).Cursor := crHandPoint;
      TLabel(Result).OnClick := @SortClick;
      TLabel(Result).Font.Style := TLabel(Result).Font.Style + [fsBold];
    end;
  end
  else if K = 'button' then
  begin
    Result := TButton.Create(APanel);
    TButton(Result).Caption := ADef.Caption;
    TButton(Result).OnClick := @SectionButton;
  end
  else if (K = 'textbox') or (K = 'combobox') then
  begin
    Ed := TaEdit.Create(APanel);
    if K = 'combobox' then Ed.Variant := evCombo;
    if Copy(ADef.ControlSource, 1, 1) = '=' then
    begin
      Ed.ReadOnly := True;
      Ed.Alignment := taRightJustify;
    end;
    if ADef.GetX('filter') <> '' then Ed.OnChange := @FilterChanged;
    Result := Ed;
  end;
  if Result = nil then Exit;
  Result.Parent := APanel;
  Result.Name := '';
  Result.SetBounds(ADef.Left + FHost.SelectorWidth, ADef.Top, ADef.Width, ADef.Height);
  Result.Tag := AList.Count;
  AList.Add(Result);
  if AList = FHeadCtrls then FHeadDefs.Add(ADef) else FFootDefs.Add(ADef);
end;

function TaContinuousBody.BuildSection(APanel: TPanel; const ASection: string; AList: TList): Integer;
var
  I, MaxB: Integer;
  D: TaControlDef;
  C: TControl;
begin
  MaxB := 0;
  for I := 0 to FDef.Count - 1 do
  begin
    D := FDef[I];
    if not SameText(D.Section, ASection) then Continue;
    C := SectionControl(APanel, D, AList);
    if C <> nil then
    begin
      if D.Top + D.Height > MaxB then MaxB := D.Top + D.Height;
    end;
  end;
  Result := MaxB;
end;

procedure TaContinuousBody.Setup(ADb: TAppDb; ADef: TaFormDef);
var
  H, F: Integer;
begin
  FDb := ADb;
  FDef := ADef;
  FreeAndNil(FSource);
  FSource := TaRowSource.Create(ADb, ADef.RecordSource);
  FBaseFilter := ADef.Filter;
  if FBaseFilter <> '' then FSource.SetFilter(FBaseFilter);
  if ADef.OrderBy <> '' then FSortField := ADef.OrderBy;
  H := BuildSection(FHeader, 'header', FHeadCtrls);
  F := BuildSection(FFooter, 'footer', FFootCtrls);
  if ADef.HeaderHeight > 0 then H := ADef.HeaderHeight - 6;
  if ADef.FooterHeight > 0 then F := ADef.FooterHeight - 6;
  if H > 0 then FHeader.Height := H + 6 else FHeader.Height := 0;
  if F > 0 then FFooter.Height := F + 6 else FFooter.Height := 0;
  FHeader.Visible := H > 0;
  FFooter.Visible := F > 0;
  FHost.Setup(FSource, ADef, ADef.RowHeight);
  UpdateSortCaptions;
  RefreshFooter;
end;

procedure TaContinuousBody.SetMaster(const AChildField, AValue: string);
begin
  FSource.SetLink(AChildField, AValue);
  FHost.Reload;
  RefreshFooter;
end;

function TaContinuousBody.HeaderControl(AName: string): TControl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FHeadCtrls.Count - 1 do
    if SameText(TaControlDef(FHeadDefs[I]).Name, AName) or SameText(TaControlDef(FHeadDefs[I]).Caption, AName) then Exit(TControl(FHeadCtrls[I]));
end;

function TaContinuousBody.FooterControl(AName: string): TControl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FFootCtrls.Count - 1 do
    if SameText(TaControlDef(FFootDefs[I]).Name, AName) then Exit(TControl(FFootCtrls[I]));
end;

function TaContinuousBody.FooterText(const AName: string): string;
var
  C: TControl;
begin
  Result := '';
  C := FooterControl(AName);
  if C is TaEdit then Result := TaEdit(C).Text
  else if C is TLabel then Result := TLabel(C).Caption;
end;

procedure TaContinuousBody.UpdateSortCaptions;
var
  I: Integer;
  D: TaControlDef;
  L: TLabel;
  Base: string;
begin
  for I := 0 to FHeadCtrls.Count - 1 do
    if TControl(FHeadCtrls[I]) is TLabel then
    begin
      L := TLabel(FHeadCtrls[I]);
      D := TaControlDef(FHeadDefs[I]);
      if (D = nil) or (D.GetX('sort') = '') then Continue;
      Base := D.Caption;
      if SameText(D.GetX('sort'), FSortField) then
      begin
        if FSortDesc then Base := Base + ' ▼' else Base := Base + ' ▲';
      end;
      L.Caption := Base;
    end;
end;

procedure TaContinuousBody.SortBy(const AField: string; ADescending: Boolean);
begin
  if FHost.Model.Dirty then FHost.CommitRow;
  FSortField := AField;
  FSortDesc := ADescending;
  FSource.SetSort(AField, ADescending);
  FHost.Reload;
  UpdateSortCaptions;
end;

procedure TaContinuousBody.SortClick(Sender: TObject);
var
  D: TaControlDef;
  F: string;
begin
  D := TaControlDef(FHeadDefs[TControl(Sender).Tag]);
  F := D.GetX('sort');
  if SameText(F, FSortField) then SortBy(F, not FSortDesc) else SortBy(F, False);
end;

procedure TaContinuousBody.ClickHeader(const AName: string);
var
  C: TControl;
begin
  C := HeaderControl(AName);
  if C is TLabel then SortClick(C);
end;

procedure TaContinuousBody.ApplyFilters;
var
  I: Integer;
  D: TaControlDef;
  W, One: string;
begin
  W := '';
  if FBaseFilter <> '' then W := '(' + FBaseFilter + ')';
  for I := 0 to FHeadCtrls.Count - 1 do
    if TControl(FHeadCtrls[I]) is TaEdit then
    begin
      D := TaControlDef(FHeadDefs[I]);
      if D.GetX('filter') = '' then Continue;
      One := FSource.FilterClause(D.GetX('filter'), TaEdit(FHeadCtrls[I]).Text);
      if One = '' then Continue;
      if W <> '' then W := W + ' AND ';
      W := W + '(' + One + ')';
    end;
  if FHost.Model.Dirty then FHost.CommitRow;
  FSource.SetFilter(W);
  FHost.Reload;
  RefreshFooter;
end;

procedure TaContinuousBody.FilterChanged(Sender: TObject);
begin
  ApplyFilters;
end;

procedure TaContinuousBody.TypeFilter(const AName, AText: string);
var
  C: TControl;
begin
  C := HeaderControl(AName);
  if C is TaEdit then
  begin
    TaEdit(C).Text := AText;
    ApplyFilters;
  end;
end;

procedure TaContinuousBody.DataChanged(Sender: TObject);
begin
  RefreshFooter;
end;

procedure TaContinuousBody.RefreshFooter;
var
  I, P, Q: Integer;
  D: TaControlDef;
  Src, Fn, Fld, V: string;
  C: TControl;
begin
  for I := 0 to FFootCtrls.Count - 1 do
  begin
    C := TControl(FFootCtrls[I]);
    D := TaControlDef(FFootDefs[I]);
    if Copy(D.ControlSource, 1, 1) <> '=' then Continue;
    Src := Trim(Copy(D.ControlSource, 2, MaxInt));
    P := Pos('(', Src);
    Q := Pos(')', Src);
    if (P = 0) or (Q < P) then Continue;
    Fn := Trim(Copy(Src, 1, P - 1));
    Fld := Trim(Copy(Src, P + 1, Q - P - 1));
    if Fld = '' then Fld := '*';
    V := FSource.Aggregate(Fn, Fld);
    if (V <> '') and (D.Format <> '') then
      try
        V := FormatValue(StrToFloat(StringReplace(V, ',', '.', [])), D.Format);
      except
      end;
    if C is TaEdit then TaEdit(C).Text := V
    else if C is TLabel then TLabel(C).Caption := V;
  end;
end;

end.
