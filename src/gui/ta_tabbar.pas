unit ta_tabbar;
{ Traka kartica za radni prostor aplikacije (svaka otvorena forma je jedna kartica sa zatvaranjem).
  Nacrtana je sama jer Qt6 sucelje ne crta tipke za zatvaranje na karticama. Boje prate svijetlu i tamnu temu,
  ikone dolaze iz zalihe. Sama traka ne drzi forme: javlja koja je kartica odabrana (OnSelect) ili trazena za zatvaranje (OnClose). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics;

type
  TaTabBar = class(TCustomControl)
  private
    FCaps: TStringList;
    FIcons: TStringList;
    FActive: Integer;
    FHot: Integer;
    FHotClose: Boolean;
    FScroll: Integer;
    FOnSelect: TNotifyEvent;
    FOnClose: TNotifyEvent;
    FCloseIndex: Integer;
    function TabWidth(AIndex: Integer): Integer;
    function TabLeft(AIndex: Integer): Integer;
    function TabAt(X: Integer; out OnClose: Boolean): Integer;
    function TotalWidth: Integer;
    procedure SetActive(AValue: Integer);
    procedure EnsureVisible(AIndex: Integer);
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddTab(const ACaption, AIcon: string): Integer;
    procedure DeleteTab(AIndex: Integer);
    procedure SetCaption(AIndex: Integer; const ACaption: string);
    function Count: Integer;
    { kartica za koju je zatrazeno zatvaranje (u OnClose) }
    property CloseIndex: Integer read FCloseIndex;
    property ActiveIndex: Integer read FActive write SetActive;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    { za testove: klik na karticu ili na njezin "x" }
    procedure ClickTab(AIndex: Integer; AOnCloseButton: Boolean);
  end;

implementation

uses
  Math, LCLType, ta_icons;

const
  BarH = 34;
  PadX = 10;
  CloseW = 18;
  MinW = 90;
  MaxW = 230;

type
  TTPal = record Bg, Tab, TabOn, Text, TextOn, Line, Accent, Hot: TColor; end;

function Pal: TTPal;
begin
  if IconDarkMode then
  begin
    Result.Bg := $2A170F; Result.Tab := $3B291E; Result.TabOn := $271811; Result.Text := $B8A89A; Result.TextOn := $F0E8E2;
    Result.Line := $554133; Result.Accent := $FAA560; Result.Hot := $554133;
  end
  else
  begin
    Result.Bg := $F9F5F1; Result.Tab := $EFE7DF; Result.TabOn := $FFFFFF; Result.Text := $6B5646; Result.TextOn := $3A2A1F;
    Result.Line := $E1D5CB; Result.Accent := $EB6325; Result.Hot := $E3D6CA;
  end;
end;

constructor TaTabBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaps := TStringList.Create;
  FIcons := TStringList.Create;
  FActive := -1;
  FHot := -1;
  FCloseIndex := -1;
  Height := BarH;
  Align := alTop;
  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csOpaque];
end;

destructor TaTabBar.Destroy;
begin
  FCaps.Free;
  FIcons.Free;
  inherited Destroy;
end;

function TaTabBar.Count: Integer;
begin
  Result := FCaps.Count;
end;

function TaTabBar.TabWidth(AIndex: Integer): Integer;
begin
  Canvas.Font.Style := [fsBold];
  Result := PadX + 16 + 6 + Canvas.TextWidth(FCaps[AIndex]) + 8 + CloseW + PadX;
  Canvas.Font.Style := [];
  if Result < MinW then Result := MinW;
  if Result > MaxW then Result := MaxW;
end;

function TaTabBar.TabLeft(AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := 6 - FScroll;
  for I := 0 to AIndex - 1 do Inc(Result, TabWidth(I) + 2);
end;

function TaTabBar.TotalWidth: Integer;
var
  I: Integer;
begin
  Result := 12;
  for I := 0 to FCaps.Count - 1 do Inc(Result, TabWidth(I) + 2);
end;

function TaTabBar.TabAt(X: Integer; out OnClose: Boolean): Integer;
var
  I, L, W: Integer;
begin
  OnClose := False;
  Result := -1;
  for I := 0 to FCaps.Count - 1 do
  begin
    L := TabLeft(I);
    W := TabWidth(I);
    if (X >= L) and (X < L + W) then
    begin
      OnClose := X >= L + W - PadX - CloseW;
      Exit(I);
    end;
  end;
end;

procedure TaTabBar.EnsureVisible(AIndex: Integer);
var
  L, W: Integer;
begin
  if (AIndex < 0) or (AIndex >= FCaps.Count) then Exit;
  L := TabLeft(AIndex);
  W := TabWidth(AIndex);
  if L < 0 then Dec(FScroll, -L + 6)
  else if L + W > Width - 6 then Inc(FScroll, L + W - Width + 6);
  if FScroll < 0 then FScroll := 0;
end;

procedure TaTabBar.SetActive(AValue: Integer);
begin
  if (AValue < -1) or (AValue >= FCaps.Count) then Exit;
  FActive := AValue;
  EnsureVisible(AValue);
  Invalidate;
end;

function TaTabBar.AddTab(const ACaption, AIcon: string): Integer;
begin
  FCaps.Add(ACaption);
  FIcons.Add(AIcon);
  Result := FCaps.Count - 1;
  Invalidate;
end;

procedure TaTabBar.DeleteTab(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FCaps.Count) then Exit;
  FCaps.Delete(AIndex);
  FIcons.Delete(AIndex);
  if FActive >= FCaps.Count then FActive := FCaps.Count - 1;
  if FHot >= FCaps.Count then FHot := -1;
  if FScroll > Max(0, TotalWidth - Width) then FScroll := Max(0, TotalWidth - Width);
  Invalidate;
end;

procedure TaTabBar.SetCaption(AIndex: Integer; const ACaption: string);
begin
  if (AIndex < 0) or (AIndex >= FCaps.Count) then Exit;
  FCaps[AIndex] := ACaption;
  Invalidate;
end;

procedure TaTabBar.Paint;
var
  P: TTPal;
  I, L, W, Cx, Cy: Integer;
  Png: TPortableNetworkGraphic;
  Txt: string;
  On_: Boolean;
begin
  P := Pal;
  Canvas.Brush.Color := P.Bg;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Color := P.Line;
  Canvas.Line(0, Height - 1, Width, Height - 1);
  for I := 0 to FCaps.Count - 1 do
  begin
    L := TabLeft(I);
    W := TabWidth(I);
    if (L + W < 0) or (L > Width) then Continue;
    On_ := I = FActive;
    if On_ then Canvas.Brush.Color := P.TabOn
    else if I = FHot then Canvas.Brush.Color := P.Hot
    else Canvas.Brush.Color := P.Tab;
    Canvas.Pen.Color := P.Line;
    Canvas.RoundRect(L, 4, L + W, Height + 6, 8, 8);
    if On_ then
    begin
      Canvas.Pen.Color := P.TabOn;
      Canvas.Line(L + 1, Height - 1, L + W - 1, Height - 1);
      Canvas.Brush.Color := P.Accent;
      Canvas.Pen.Color := P.Accent;
      Canvas.Rectangle(L + 6, 4, L + W - 6, 7);
    end;
    Canvas.Brush.Style := bsClear;
    if FIcons[I] <> '' then
    begin
      Png := IconPng(FIcons[I], 16);
      if Png <> nil then Canvas.Draw(L + PadX, 11, Png);
    end;
    Txt := FCaps[I];
    Canvas.Font.Style := [];
    if On_ then begin Canvas.Font.Style := [fsBold]; Canvas.Font.Color := P.TextOn; end
    else Canvas.Font.Color := P.Text;
    { skrati tekst da stane uz "x" }
    while (Length(Txt) > 3) and (Canvas.TextWidth(Txt) > W - PadX - 16 - 6 - CloseW - PadX - 4) do
      Txt := Copy(Txt, 1, Length(Txt) - 2);
    if Txt <> FCaps[I] then Txt := Txt + '…';
    Canvas.TextOut(L + PadX + 22, 4 + (Height - 4 - Canvas.TextHeight('Ag')) div 2 - 1, Txt);
    Canvas.Font.Style := [];
    { x }
    Cx := L + W - PadX - CloseW div 2;
    Cy := 4 + (Height - 4) div 2 - 1;
    if (I = FHot) and FHotClose then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := $4B4BE0;
      Canvas.Pen.Color := $4B4BE0;
      Canvas.Ellipse(Cx - 8, Cy - 8, Cx + 8, Cy + 8);
      Canvas.Pen.Color := clWhite;
    end
    else
    begin
      if On_ or (I = FHot) then Canvas.Pen.Color := P.TextOn else Canvas.Pen.Color := P.Text;
    end;
    Canvas.Pen.Width := 2;
    Canvas.Line(Cx - 3, Cy - 3, Cx + 4, Cy + 4);
    Canvas.Line(Cx + 3, Cy - 3, Cx - 4, Cy + 4);
    Canvas.Pen.Width := 1;
  end;
end;

procedure TaTabBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  C: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  I := TabAt(X, C);
  if (I <> FHot) or (C <> FHotClose) then
  begin
    FHot := I;
    FHotClose := C and (I >= 0);
    Invalidate;
  end;
end;

procedure TaTabBar.MouseLeave;
begin
  inherited MouseLeave;
  if (FHot <> -1) then begin FHot := -1; FHotClose := False; Invalidate; end;
end;

procedure TaTabBar.ClickTab(AIndex: Integer; AOnCloseButton: Boolean);
begin
  if (AIndex < 0) or (AIndex >= FCaps.Count) then Exit;
  if AOnCloseButton then
  begin
    FCloseIndex := AIndex;
    if Assigned(FOnClose) then FOnClose(Self);
  end
  else if AIndex <> FActive then
  begin
    SetActive(AIndex);
    if Assigned(FOnSelect) then FOnSelect(Self);
  end;
end;

procedure TaTabBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  C: Boolean;
begin
  inherited MouseDown(Button, Shift, X, Y);
  I := TabAt(X, C);
  if I < 0 then Exit;
  if Button = mbMiddle then ClickTab(I, True)
  else if Button = mbLeft then ClickTab(I, C);
end;

function TaTabBar.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  FScroll := Max(0, Min(Max(0, TotalWidth - Width), FScroll - WheelDelta div 2));
  Invalidate;
  Result := True;
end;

end.
