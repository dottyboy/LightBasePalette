unit ta_ownlov;
{ Vlastito polje s gumbom za popis vrijednosti (pruzatelj 'own'): obicno polje s gumbom "..." uz desni rub; gumb ili F9 javlja
  zahtjev za popis (domacin ga prosljedjuje izvrsitelju forme). Pri samo citanju gumb je ugasen. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ta_family, ta_edit, ta_ownedit;

type
  TaOwnLovEdit = class(TaOwnEdit)
  private
    FOnLov, FOnF9: TNotifyEvent;
  protected
    procedure PaintExtras(ARect: TRect); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    { klik na gumb }
    property OnLov: TNotifyEvent read FOnLov write FOnLov;
    { F9 koji obicno nije preuzela tipkovnicka mapa forme (svaki prima odluku o tome) }
    property OnF9: TNotifyEvent read FOnF9 write FOnF9;
  end;

  TaOwnLovEngine = class(TaEngine)
  private
    FLov: TaOwnLovEdit;
    procedure LovClick(Sender: TObject);
    procedure F9Pressed(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
  end;

implementation

uses
  ta_tokens;

constructor TaOwnLovEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRightPad := 28;
end;

procedure TaOwnLovEdit.PaintExtras(ARect: TRect);
var
  T: TaThemeTokens;
  Cx, Cy: Integer;
begin
  T := ActiveTokens;
  if Enabled and not ReadOnly then Canvas.Brush.Color := TokenColor(T.Text) else Canvas.Brush.Color := TokenColor(T.TextSoft);
  Canvas.Pen.Style := psClear;
  Cx := (ARect.Left + ARect.Right) div 2;
  Cy := Height div 2;
  Canvas.Ellipse(Cx - 7, Cy - 1, Cx - 4, Cy + 2);
  Canvas.Ellipse(Cx - 1, Cy - 1, Cx + 2, Cy + 2);
  Canvas.Ellipse(Cx + 5, Cy - 1, Cx + 8, Cy + 2);
  Canvas.Pen.Style := psSolid;
end;

procedure TaOwnLovEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = VK_F9) and (Shift = []) and Assigned(FOnF9) and not ReadOnly then
  begin
    FOnF9(Self);
    Key := 0;
  end;
end;

procedure TaOwnLovEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and PtInRightPad(X) then
  begin
    if CanFocus and not Focused then SetFocus;
    if (not ReadOnly) and Assigned(FOnLov) then FOnLov(Self);
    Exit;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

constructor TaOwnLovEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FLov := TaOwnLovEdit.Create(nil);
  FLov.OnChange := @InnerChanged;
  FLov.OnLov := @LovClick;
  FLov.OnF9 := @F9Pressed;
  AttachInner(FLov);
end;

class function TaOwnLovEngine.Provider: string;
begin
  Result := 'own';
end;

procedure TaOwnLovEngine.LovClick(Sender: TObject);
begin
  if Host is TaEdit then TaEdit(Host).RequestLov;
end;

procedure TaOwnLovEngine.F9Pressed(Sender: TObject);
begin
  { F9 samo kad domacin nema vlastitu tipkovnicku mapu (neprekidna forma preuzima tipke preko OnInnerKeyDown) }
  if not Assigned(Host.OnInnerKeyDown) then LovClick(Sender);
end;

function TaOwnLovEngine.GetText: string;
begin
  Result := FLov.Text;
end;

procedure TaOwnLovEngine.SetText(const AValue: string);
begin
  if FLov.Text <> AValue then FLov.Text := AValue;
end;

procedure TaOwnLovEngine.SetReadOnly(AValue: Boolean);
begin
  FLov.ReadOnly := AValue;
end;

initialization
  RegisterEngine(EditFamily, 'lov', TaOwnLovEngine);

end.
