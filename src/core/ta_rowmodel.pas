unit ta_rowmodel;
{ Model neprekidne forme (poglavlje 20 plana), bez sucelja i bez baze: koliko ima redova, koji je trenutni, koji se vide,
  je li trenutni red nespremljen, kamo ide Tab. Sav izracun je ovdje da se testira bez prozora.

  Redovi: 0 .. RecordCount-1 su zapisi; ako je AllowAdds, red RecordCount je virtualni "novi zapis". }

{$mode objfpc}{$H+}

interface

type
  TaRowModel = class
  private
    FRecordCount: Integer;
    FAllowAdds: Boolean;
    FViewRows: Integer;
    FOffset: Integer;
    FCurrent: Integer;
    FDirty: Boolean;
    function GetRowCount: Integer;
    function GetNewRow: Integer;
    procedure Clamp;
  public
    constructor Create;
    property RecordCount: Integer read FRecordCount;
    property AllowAdds: Boolean read FAllowAdds write FAllowAdds;
    property ViewRows: Integer read FViewRows;
    property Offset: Integer read FOffset;
    property Current: Integer read FCurrent;
    property Dirty: Boolean read FDirty;
    property RowCount: Integer read GetRowCount;
    { indeks virtualnog novog reda, -1 ako dodavanje nije dopusteno }
    property NewRow: Integer read GetNewRow;
    function IsNewRow(ARow: Integer): Boolean;
    procedure SetRecordCount(AValue: Integer);
    procedure SetViewRows(AValue: Integer);
    { klizanje: pomak prvog vidljivog reda (ogranicen na raspon) }
    procedure ScrollTo(AOffset: Integer);
    procedure ScrollBy(ADelta: Integer);
    procedure EnsureVisible(ARow: Integer);
    { prvi i zadnji vidljivi red; False ako nema redova }
    function VisibleRange(out AFirst, ALast: Integer): Boolean;
    { prelazak na red: ako je trenutni red nespremljen, ne ide; ANeedPost pokazuje da treba prvo Post }
    function MoveTo(ARow: Integer; out ANeedPost: Boolean): Boolean;
    function MoveNext(out ANeedPost: Boolean): Boolean;
    function MovePrev(out ANeedPost: Boolean): Boolean;
    function PageDown(out ANeedPost: Boolean): Boolean;
    function PageUp(out ANeedPost: Boolean): Boolean;
    function MoveFirst(out ANeedPost: Boolean): Boolean;
    { zadnji pravi zapis (Ctrl+End); novi red se dohvaca s MoveNew }
    function MoveLast(out ANeedPost: Boolean): Boolean;
    function MoveNew(out ANeedPost: Boolean): Boolean;
    procedure MarkDirty;
    procedure MarkClean;
    { Post uspio: ako je to bio novi red, pojavljuje se jedan zapis vise (a novi red je i dalje zadnji) }
    procedure RecordPosted;
    { Post/Cancel ostavljaju trenutni red; brisanje trenutnog zapisa }
    procedure RecordDeleted;
    { Tab / Shift+Tab: iz kontrole ACtl (0..ACtlCount-1) u retku ARow; vraca novi red i kontrolu.
      Nakon zadnje kontrole ide prva kontrola sljedeceg reda, prije prve zadnja prethodnog. False na rubu. }
    function TabTarget(ARow, ACtl, ACtlCount: Integer; ABack: Boolean; out ANewRow, ANewCtl: Integer): Boolean;
  end;

implementation

constructor TaRowModel.Create;
begin
  FAllowAdds := True;
  FViewRows := 10;
  FCurrent := 0;
end;

function TaRowModel.GetRowCount: Integer;
begin
  Result := FRecordCount;
  if FAllowAdds then Inc(Result);
end;

function TaRowModel.GetNewRow: Integer;
begin
  if FAllowAdds then Result := FRecordCount else Result := -1;
end;

function TaRowModel.IsNewRow(ARow: Integer): Boolean;
begin
  Result := FAllowAdds and (ARow = FRecordCount);
end;

procedure TaRowModel.Clamp;
var
  MaxOff: Integer;
begin
  if FCurrent >= RowCount then FCurrent := RowCount - 1;
  if FCurrent < 0 then FCurrent := 0;
  MaxOff := RowCount - FViewRows;
  if MaxOff < 0 then MaxOff := 0;
  if FOffset > MaxOff then FOffset := MaxOff;
  if FOffset < 0 then FOffset := 0;
end;

procedure TaRowModel.SetRecordCount(AValue: Integer);
begin
  FRecordCount := AValue;
  if FRecordCount < 0 then FRecordCount := 0;
  Clamp;
end;

procedure TaRowModel.SetViewRows(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  FViewRows := AValue;
  Clamp;
end;

procedure TaRowModel.ScrollTo(AOffset: Integer);
begin
  FOffset := AOffset;
  Clamp;
end;

procedure TaRowModel.ScrollBy(ADelta: Integer);
begin
  ScrollTo(FOffset + ADelta);
end;

procedure TaRowModel.EnsureVisible(ARow: Integer);
begin
  if ARow < FOffset then FOffset := ARow
  else if ARow >= FOffset + FViewRows then FOffset := ARow - FViewRows + 1;
  Clamp;
end;

function TaRowModel.VisibleRange(out AFirst, ALast: Integer): Boolean;
begin
  AFirst := FOffset;
  ALast := FOffset + FViewRows - 1;
  if ALast >= RowCount then ALast := RowCount - 1;
  Result := ALast >= AFirst;
end;

function TaRowModel.MoveTo(ARow: Integer; out ANeedPost: Boolean): Boolean;
begin
  ANeedPost := False;
  if ARow < 0 then ARow := 0;
  if ARow >= RowCount then ARow := RowCount - 1;
  if ARow < 0 then Exit(False);
  if ARow = FCurrent then Exit(True);
  if FDirty then
  begin
    ANeedPost := True;
    Exit(False);
  end;
  FCurrent := ARow;
  EnsureVisible(FCurrent);
  Result := True;
end;

function TaRowModel.MoveNext(out ANeedPost: Boolean): Boolean;
begin
  Result := MoveTo(FCurrent + 1, ANeedPost);
end;

function TaRowModel.MovePrev(out ANeedPost: Boolean): Boolean;
begin
  Result := MoveTo(FCurrent - 1, ANeedPost);
end;

function TaRowModel.PageDown(out ANeedPost: Boolean): Boolean;
begin
  Result := MoveTo(FCurrent + FViewRows, ANeedPost);
end;

function TaRowModel.PageUp(out ANeedPost: Boolean): Boolean;
begin
  Result := MoveTo(FCurrent - FViewRows, ANeedPost);
end;

function TaRowModel.MoveFirst(out ANeedPost: Boolean): Boolean;
begin
  Result := MoveTo(0, ANeedPost);
end;

function TaRowModel.MoveLast(out ANeedPost: Boolean): Boolean;
begin
  if FRecordCount > 0 then Result := MoveTo(FRecordCount - 1, ANeedPost)
  else Result := MoveTo(0, ANeedPost);
end;

function TaRowModel.MoveNew(out ANeedPost: Boolean): Boolean;
begin
  if FAllowAdds then Result := MoveTo(FRecordCount, ANeedPost)
  else begin ANeedPost := False; Result := False; end;
end;

procedure TaRowModel.MarkDirty;
begin
  FDirty := True;
end;

procedure TaRowModel.MarkClean;
begin
  FDirty := False;
end;

procedure TaRowModel.RecordPosted;
var
  WasNew: Boolean;
begin
  WasNew := IsNewRow(FCurrent);
  FDirty := False;
  if WasNew then
  begin
    Inc(FRecordCount);
    { trenutni red ostaje taj isti zapis; ispod njega je novi prazan red }
    Clamp;
  end;
end;

procedure TaRowModel.RecordDeleted;
begin
  FDirty := False;
  if (FRecordCount > 0) and (FCurrent < FRecordCount) then Dec(FRecordCount);
  Clamp;
end;

function TaRowModel.TabTarget(ARow, ACtl, ACtlCount: Integer; ABack: Boolean; out ANewRow, ANewCtl: Integer): Boolean;
begin
  ANewRow := ARow;
  ANewCtl := ACtl;
  Result := False;
  if ACtlCount < 1 then Exit;
  if not ABack then
  begin
    if ACtl < ACtlCount - 1 then begin ANewCtl := ACtl + 1; Exit(True); end;
    if ARow < RowCount - 1 then begin ANewRow := ARow + 1; ANewCtl := 0; Exit(True); end;
  end
  else
  begin
    if ACtl > 0 then begin ANewCtl := ACtl - 1; Exit(True); end;
    if ARow > 0 then begin ANewRow := ARow - 1; ANewCtl := ACtlCount - 1; Exit(True); end;
  end;
end;

end.
