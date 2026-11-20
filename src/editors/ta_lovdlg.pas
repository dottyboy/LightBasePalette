unit ta_lovdlg;
{ Popis vrijednosti (LOV, 19.5): skocni popis s filtriranjem upisom; izbor ostavlja skup podataka na odabranom retku. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, DB, Grids, ta_source;

type
  TLovPickHook = function(ADs: TDataSet; const ATitle, AInitial: string): Boolean;

var
  { kad je postavljen, zamjenjuje dijalog (ispitivanje, skriptiranje) }
  LovPickHook: TLovPickHook = nil;

{ ADs mora biti otvoren; True = odabran redak (ADs stoji na njemu), False = odustao. }
function RunLov(AOwner: TComponent; ADs: TDataSet; const ATitle, AInitial: string): Boolean;

implementation

uses
  ta_i18n;


const
  MaxRows = 20000;

type
  TLovHelper = class
  public
    Ds: TDataSet;
    Grid: TStringGrid;
    Edit: TEdit;
    Form: TForm;
    Rows: TStringList;      { tekst retka za pretragu (mala slova); Objects = redni broj retka u skupu podataka }
    Cells: array of array of string;
    Shown: array of Integer;  { redni brojevi retaka u Cells koji prolaze filtar }
    procedure Load;
    procedure Apply;
    function CurrentRow: Integer;
    procedure EditChange(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure EditKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GridKey(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

procedure TLovHelper.Load;
var
  I, N: Integer;
  S: string;
begin
  N := 0;
  Ds.DisableControls;
  try
    Ds.First;
    while not Ds.EOF and (N < MaxRows) do
    begin
      SetLength(Cells, N + 1);
      SetLength(Cells[N], Ds.FieldCount);
      S := '';
      for I := 0 to Ds.FieldCount - 1 do
      begin
        Cells[N][I] := Ds.Fields[I].AsString;
        S := S + LowerCase(Cells[N][I]) + #1;
      end;
      Rows.Add(S);
      Inc(N);
      Ds.Next;
    end;
  finally
    Ds.EnableControls;
  end;
end;

procedure TLovHelper.Apply;
var
  I, J, N: Integer;
  T: string;
begin
  T := LowerCase(Trim(Edit.Text));
  N := 0;
  SetLength(Shown, Rows.Count);
  for I := 0 to Rows.Count - 1 do
    if (T = '') or (Pos(T, Rows[I]) > 0) then
    begin
      Shown[N] := I;
      Inc(N);
    end;
  SetLength(Shown, N);
  Grid.RowCount := N + 1;
  for I := 0 to N - 1 do
    for J := 0 to Ds.FieldCount - 1 do
      Grid.Cells[J, I + 1] := Cells[Shown[I]][J];
  if N > 0 then Grid.Row := 1;
end;

function TLovHelper.CurrentRow: Integer;
begin
  Result := -1;
  if (Grid.Row >= 1) and (Grid.Row <= Length(Shown)) then Result := Shown[Grid.Row - 1];
end;

procedure TLovHelper.EditChange(Sender: TObject);
begin
  Apply;
end;

procedure TLovHelper.GridDblClick(Sender: TObject);
begin
  if CurrentRow >= 0 then Form.ModalResult := mrOk;
end;

procedure TLovHelper.EditKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    13: begin if CurrentRow >= 0 then Form.ModalResult := mrOk; Key := 0; end;
    40: begin if Grid.Row < Grid.RowCount - 1 then Grid.Row := Grid.Row + 1; Key := 0; end;
    38: begin if Grid.Row > 1 then Grid.Row := Grid.Row - 1; Key := 0; end;
  end;
end;

procedure TLovHelper.GridKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = 13) and (CurrentRow >= 0) then begin Form.ModalResult := mrOk; Key := 0; end;
end;

function RunLov(AOwner: TComponent; ADs: TDataSet; const ATitle, AInitial: string): Boolean;
var
  F: TForm;
  H: TLovHelper;
  Pn: TPanel;
  B: TButton;
  I, Row: Integer;
begin
  Result := False;
  if (ADs = nil) or not ADs.Active then Exit;
  if Assigned(LovPickHook) then Exit(LovPickHook(ADs, ATitle, AInitial));
  F := TForm.CreateNew(AOwner);
  H := TLovHelper.Create;
  H.Rows := TStringList.Create;
  try
    H.Form := F; H.Ds := ADs;
    H.Load;
    F.Caption := ATitle;
    F.Position := poOwnerFormCenter;
    F.SetBounds(0, 0, 520, 380);
    F.KeyPreview := True;
    Pn := TPanel.Create(F);
    Pn.Parent := F; Pn.Align := alTop; Pn.Height := 36; Pn.BevelOuter := bvNone;
    H.Edit := TEdit.Create(F);
    H.Edit.Parent := Pn;
    H.Edit.SetBounds(8, 6, 500, 24);
    H.Edit.TextHint := Tr('Enter part of the text to filter');
    H.Edit.OnKeyDown := @H.EditKey;
    Pn := TPanel.Create(F);
    Pn.Parent := F; Pn.Align := alBottom; Pn.Height := 38; Pn.BevelOuter := bvNone;
    B := TButton.Create(F); B.Parent := Pn; B.Caption := Tr('Select'); B.ModalResult := mrOk; B.SetBounds(F.Width - 190, 6, 86, 26);
    B := TButton.Create(F); B.Parent := Pn; B.Caption := Tr('Cancel'); B.ModalResult := mrCancel; B.SetBounds(F.Width - 98, 6, 86, 26);
    H.Grid := TStringGrid.Create(F);
    H.Grid.Parent := F; H.Grid.Align := alClient;
    H.Grid.FixedCols := 0; H.Grid.FixedRows := 1;
    H.Grid.ColCount := ADs.FieldCount;
    H.Grid.RowCount := 2;
    H.Grid.Options := H.Grid.Options + [goRowSelect] - [goEditing];
    for I := 0 to ADs.FieldCount - 1 do
    begin
      H.Grid.Cells[I, 0] := ADs.Fields[I].DisplayLabel;
      H.Grid.ColWidths[I] := 120;
    end;
    H.Grid.OnDblClick := @H.GridDblClick;
    H.Grid.OnKeyDown := @H.GridKey;
    H.Edit.OnChange := @H.EditChange;
    H.Edit.Text := AInitial;
    H.Apply;
    F.ActiveControl := H.Edit;
    if (F.ShowModal = mrOk) then
    begin
      Row := H.CurrentRow;
      if Row >= 0 then
      begin
        ADs.First;
        ADs.MoveBy(Row);
        Result := True;
      end;
    end;
  finally
    H.Rows.Free;
    H.Free;
    F.Free;
  end;
end;

initialization
  LovPicker := @RunLov;

end.
