unit ta_owndash;
{ Nadzorna ploca (vlastita kontrola): kartica po skupini (npr. pogon), u njoj redak po mjernoj vrijednosti s bojom stanja
  i malim grafom (sparkline) zadnjih vrijednosti. Kartice se slazu u mrezu prema sirini, kotacic pomice okomito.
  Ne zna podatke: puni se pozivima Clear, AddItem i EndUpdate (vidi ta_formdash). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, LazUTF8;

type
  { stanje retka: 0 u redu, 1 izvan granica, 2 nema podataka }
  TaDashItem = class
  public
    Group, Info, Name, Value, Unit_: string;
    State: Integer;
    { prekidac (izvrsni uredjaj): Kind = 1; On je stvarno stanje, Pending znaci da naredba jos nije potvrdjena }
    Kind: Integer;
    On, Pending: Boolean;
    Alerts: Integer;
    Series: array of Double;
    Id: string;
  end;

  TaDashItemEvent = procedure(Sender: TObject; const AId: string) of object;

  TaOwnDash = class(TCustomControl)
  private
    FItems: TList;
    FGroups: TStringList;      { nazivi skupina po redu }
    FTop: Integer;
    FOnItem: TaDashItemEvent;
    function CardW: Integer;
    function Cols: Integer;
    function RowH: Integer;
    function HeadH: Integer;
    function GroupItems(AIndex: Integer): TList;
    function CardH(AIndex: Integer): Integer;
    function ContentH: Integer;
    function GroupWorst(AIndex: Integer): Integer;
    function CardPos(AIndex: Integer): TPoint;
    procedure ClampTop;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function AddItem(const AId, AGroup, AInfo, AName, AValue, AUnit: string; AState: Integer; const ASeries: array of Double): TaDashItem;
    procedure EndUpdate;
    function GroupCount: Integer;
    function ItemCount: Integer;
    function ItemAt(AIndex: Integer): TaDashItem;
    function WorstState(const AGroup: string): Integer;
    function GroupAlerts(const AGroup: string): Integer;
    property OnItemClick: TaDashItemEvent read FOnItem write FOnItem;
  end;

implementation

uses
  Math, ta_tokens;

const
  Gap = 12;
  Pad = 10;
  MinCardW = 300;

constructor TaOwnDash.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse];
  Width := 640;
  Height := 400;
  FItems := TList.Create;
  FGroups := TStringList.Create;
end;

destructor TaOwnDash.Destroy;
begin
  Clear;
  FItems.Free;
  FGroups.Free;
  inherited Destroy;
end;

procedure TaOwnDash.Clear;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do TaDashItem(FItems[I]).Free;
  FItems.Clear;
  FGroups.Clear;
  Invalidate;
end;

function TaOwnDash.AddItem(const AId, AGroup, AInfo, AName, AValue, AUnit: string; AState: Integer; const ASeries: array of Double): TaDashItem;
var
  I: Integer;
begin
  Result := TaDashItem.Create;
  Result.Id := AId;
  Result.Group := AGroup;
  Result.Info := AInfo;
  Result.Name := AName;
  Result.Value := AValue;
  Result.Unit_ := AUnit;
  Result.State := AState;
  SetLength(Result.Series, Length(ASeries));
  for I := 0 to High(ASeries) do Result.Series[I] := ASeries[I];
  FItems.Add(Result);
  if FGroups.IndexOf(AGroup) < 0 then FGroups.Add(AGroup);
end;

procedure TaOwnDash.EndUpdate;
begin
  ClampTop;
  Invalidate;
end;

function TaOwnDash.GroupCount: Integer;
begin
  Result := FGroups.Count;
end;

function TaOwnDash.ItemCount: Integer;
begin
  Result := FItems.Count;
end;

function TaOwnDash.ItemAt(AIndex: Integer): TaDashItem;
begin
  Result := TaDashItem(FItems[AIndex]);
end;

function TaOwnDash.WorstState(const AGroup: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  if GroupAlerts(AGroup) > 0 then Exit(1);
  for I := 0 to FItems.Count - 1 do
    if TaDashItem(FItems[I]).Group = AGroup then
      if (TaDashItem(FItems[I]).State = 1) then Exit(1)
      else if TaDashItem(FItems[I]).State = 2 then Result := 2;
end;

function TaOwnDash.GroupAlerts(const AGroup: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FItems.Count - 1 do
    if TaDashItem(FItems[I]).Group = AGroup then Result := Max(Result, TaDashItem(FItems[I]).Alerts);
end;

function TaOwnDash.GroupWorst(AIndex: Integer): Integer;
begin
  Result := WorstState(FGroups[AIndex]);
end;

function TaOwnDash.RowH: Integer;
begin
  Canvas.Font.Assign(Font);
  Result := Canvas.TextHeight('Ag') + 12;
end;

function TaOwnDash.HeadH: Integer;
begin
  Canvas.Font.Assign(Font);
  Result := Canvas.TextHeight('Ag') * 2 + 14;
end;

function TaOwnDash.CardW: Integer;
var
  N: Integer;
begin
  N := Max(1, (Width - Gap) div (MinCardW + Gap));
  Result := (Width - Gap - N * Gap) div N;
end;

function TaOwnDash.Cols: Integer;
begin
  Result := Max(1, (Width - Gap) div (MinCardW + Gap));
end;

function TaOwnDash.GroupItems(AIndex: Integer): TList;
var
  I: Integer;
begin
  Result := TList.Create;
  for I := 0 to FItems.Count - 1 do
    if TaDashItem(FItems[I]).Group = FGroups[AIndex] then Result.Add(FItems[I]);
end;

function TaOwnDash.CardH(AIndex: Integer): Integer;
var
  L: TList;
begin
  L := GroupItems(AIndex);
  try
    Result := HeadH + L.Count * RowH + 8;
  finally
    L.Free;
  end;
end;

{ lijevi gornji kut kartice; kartice u istom retku imaju zajednicku visinu najvise }
function TaOwnDash.CardPos(AIndex: Integer): TPoint;
var
  Row, Col, I, Y, Hmax: Integer;
begin
  Col := AIndex mod Cols;
  Row := AIndex div Cols;
  Y := Gap;
  for I := 0 to Row - 1 do
  begin
    Hmax := 0;
    Hmax := Max(Hmax, CardH(I * Cols));
    for Col := 1 to Cols - 1 do
      if I * Cols + Col < FGroups.Count then Hmax := Max(Hmax, CardH(I * Cols + Col));
    Inc(Y, Hmax + Gap);
  end;
  Col := AIndex mod Cols;
  Result := Point(Gap + Col * (CardW + Gap), Y - FTop);
end;

function TaOwnDash.ContentH: Integer;
var
  P: TPoint;
begin
  if FGroups.Count = 0 then Exit(0);
  P := CardPos(FGroups.Count - 1);
  Result := P.Y + FTop + CardH(FGroups.Count - 1) + Gap;
end;

procedure TaOwnDash.ClampTop;
begin
  FTop := Max(0, Min(FTop, Max(0, ContentH - Height)));
end;

procedure TaOwnDash.Resize;
begin
  inherited Resize;
  if (Parent <> nil) and (FItems <> nil) then
  begin
    ClampTop;
    Invalidate;
  end;
end;

procedure TaOwnDash.Paint;
var
  T: TaThemeTokens;
  G, I, N, X, Y, Rh, Hh, Cw, Sw, Sx, K: Integer;
  P: TPoint;
  L: TList;
  It: TaDashItem;
  Br, Tx, Soft, Soft2, Ok, Bad, Warn, Cl, Acc2: TColor;
  Mn, Mx, V: Double;
  Txt: string;
begin
  T := ActiveTokens;
  Br := TokenColor(T.Border);
  Tx := TokenColor(T.Text);
  Soft := TokenColor(T.Soft);
  Soft2 := TokenColor(T.TextSoft);
  Ok := TokenColor(T.Success);
  Bad := TokenColor(T.Danger);
  Warn := TokenColor(T.Warning);
  Acc2 := TokenColor(T.Accent);
  Canvas.Brush.Color := TokenColor(T.Bg);
  Canvas.Pen.Style := psClear;
  Canvas.FillRect(0, 0, Width, Height);
  Canvas.Pen.Style := psSolid;
  Canvas.Font.Assign(Font);
  Rh := RowH;
  Hh := HeadH;
  Cw := CardW;
  for G := 0 to FGroups.Count - 1 do
  begin
    P := CardPos(G);
    L := GroupItems(G);
    try
      N := CardH(G);
      if (P.Y + N < 0) or (P.Y > Height) then Continue;
      Canvas.Brush.Color := TokenColor(T.Surface);
      if GroupWorst(G) = 1 then Canvas.Pen.Color := Bad else Canvas.Pen.Color := Br;
      if GroupWorst(G) = 1 then Canvas.Pen.Width := 2 else Canvas.Pen.Width := 1;
      Canvas.RoundRect(P.X, P.Y, P.X + Cw, P.Y + N, 10, 10);
      Canvas.Pen.Width := 1;
      { zaglavlje: tockica stanja, naziv, info }
      case GroupWorst(G) of
        0: Cl := Ok;
        1: Cl := Bad;
      else
        Cl := Warn;
      end;
      Canvas.Brush.Color := Cl;
      Canvas.Pen.Style := psClear;
      Canvas.Ellipse(P.X + Pad, P.Y + 14, P.X + Pad + 10, P.Y + 24);
      Canvas.Pen.Style := psSolid;
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := Tx;
      Txt := FGroups[G];
      K := Cw - 2 * Pad - 18;
      if GroupAlerts(FGroups[G]) > 0 then Dec(K, 70);
      while (UTF8Length(Txt) > 2) and (Canvas.TextWidth(Txt) > K) do
        Txt := UTF8Copy(Txt, 1, UTF8Length(Txt) - 2) + '…';
      Canvas.TextOut(P.X + Pad + 18, P.Y + 8, Txt);
      Canvas.Font.Style := [];
      Canvas.Font.Color := Soft2;
      if L.Count > 0 then
      begin
        Canvas.TextOut(P.X + Pad + 18, P.Y + 8 + Canvas.TextHeight('Ag') + 2, TaDashItem(L[0]).Info);
        if GroupAlerts(FGroups[G]) > 0 then
        begin
          Canvas.Font.Style := [fsBold];
          Canvas.Font.Color := Bad;
          Txt := IntToStr(GroupAlerts(FGroups[G])) + ' alarm';
          Canvas.TextOut(P.X + Cw - Pad - Canvas.TextWidth(Txt), P.Y + 8, Txt);
          Canvas.Font.Style := [];
          Canvas.Font.Color := Soft2;
        end;
      end;
      { crta ispod zaglavlja }
      Canvas.Pen.Color := Br;
      Canvas.Line(P.X + 1, P.Y + Hh, P.X + Cw - 1, P.Y + Hh);
      { redci }
      for I := 0 to L.Count - 1 do
      begin
        It := TaDashItem(L[I]);
        Y := P.Y + Hh + I * Rh;
        X := P.X + Pad;
        Canvas.Font.Style := [];
        Canvas.Font.Color := Tx;
        Canvas.TextOut(X, Y + (Rh - Canvas.TextHeight('Ag')) div 2, It.Name);
        if It.Kind = 1 then
        begin
          { prekidac }
          Sw := 40;
          Sx := P.X + Cw - Pad - Sw;
          if It.On then Canvas.Brush.Color := Acc2 else Canvas.Brush.Color := Br;
          Canvas.Pen.Style := psClear;
          Canvas.RoundRect(Sx, Y + (Rh - 20) div 2, Sx + Sw, Y + (Rh - 20) div 2 + 20, 20, 20);
          Canvas.Pen.Style := psSolid;
          Canvas.Brush.Color := TokenColor(T.Surface);
          if It.Pending then begin Canvas.Pen.Color := Warn; Canvas.Pen.Width := 2; end else Canvas.Pen.Style := psClear;
          if It.On then Cl := Sx + Sw - 18 else Cl := Sx + 2;
          Canvas.Ellipse(Cl, Y + (Rh - 20) div 2 + 2, Cl + 16, Y + (Rh - 20) div 2 + 18);
          Canvas.Pen.Style := psSolid;
          Canvas.Pen.Width := 1;
          Canvas.Font.Style := [];
          Canvas.Font.Color := Soft2;
          if It.Pending then Txt := 'čeka' else if It.On then Txt := 'uključeno' else Txt := 'isključeno';
          Canvas.TextOut(Sx - 10 - Canvas.TextWidth(Txt), Y + (Rh - Canvas.TextHeight('Ag')) div 2, Txt);
          Continue;
        end;
        { vrijednost }
        Txt := It.Value;
        if It.Unit_ <> '' then Txt := Txt + ' ' + It.Unit_;
        if Txt = '' then Txt := '-';
        Canvas.Font.Style := [fsBold];
        case It.State of
          0: Canvas.Font.Color := Tx;
          1: Canvas.Font.Color := Bad;
        else
          Canvas.Font.Color := Soft2;
        end;
        Sw := 76;
        Sx := P.X + Cw - Pad - Sw;
        Canvas.TextOut(Sx - 10 - Canvas.TextWidth(Txt), Y + (Rh - Canvas.TextHeight('Ag')) div 2, Txt);
        Canvas.Font.Style := [];
        { sparkline }
        if Length(It.Series) > 1 then
        begin
          Mn := It.Series[0]; Mx := It.Series[0];
          for K := 1 to High(It.Series) do
          begin
            Mn := Min(Mn, It.Series[K]);
            Mx := Max(Mx, It.Series[K]);
          end;
          if Mx - Mn < 1e-9 then begin Mn := Mn - 1; Mx := Mx + 1; end;
          if It.State = 1 then Canvas.Pen.Color := Bad else Canvas.Pen.Color := TokenColor(T.Accent);
          Canvas.Pen.Width := 2;
          for K := 0 to High(It.Series) do
          begin
            V := It.Series[K];
            Cl := Sx + K * Sw div High(It.Series);
            N := Y + Rh - 6 - Round((V - Mn) / (Mx - Mn) * (Rh - 12));
            if K = 0 then Canvas.MoveTo(Cl, N) else Canvas.LineTo(Cl, N);
          end;
          Canvas.Pen.Width := 1;
        end;
      end;
      Canvas.Brush.Style := bsSolid;
    finally
      L.Free;
    end;
  end;
  if (FGroups.Count > 0) and (ContentH > Height) then
  begin
    N := Max(24, Height * Height div ContentH);
    Y := (Height - N) * FTop div Max(1, ContentH - Height);
    Canvas.Brush.Color := Br;
    Canvas.Pen.Style := psClear;
    Canvas.RoundRect(Width - 8, Y, Width - 3, Y + N, 3, 3);
    Canvas.Pen.Style := psSolid;
  end;
  Soft := 0;
  X := 0;
end;

procedure TaOwnDash.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  G, I: Integer;
  P: TPoint;
  L: TList;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  for G := 0 to FGroups.Count - 1 do
  begin
    P := CardPos(G);
    if (X >= P.X) and (X < P.X + CardW) and (Y >= P.Y + HeadH) and (Y < P.Y + CardH(G)) then
    begin
      L := GroupItems(G);
      try
        I := (Y - P.Y - HeadH) div RowH;
        if (I >= 0) and (I < L.Count) and Assigned(FOnItem) then FOnItem(Self, TaDashItem(L[I]).Id);
      finally
        L.Free;
      end;
      Exit;
    end;
  end;
end;

function TaOwnDash.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := True;
  FTop := FTop - WheelDelta div 2;
  ClampTop;
  Invalidate;
end;

end.
