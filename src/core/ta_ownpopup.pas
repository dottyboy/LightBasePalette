unit ta_ownpopup;
{ Osnova vlastitih polja s popisom koji se otvara (combo, datum): rezervira mjesto za strelicu, postavlja popis preko forme
  (ne izvorni prozor), zatvara ga kad se klikne izvan polja i popisa i kad polje izgubi fokus. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Forms, LCLType, LMessages, ta_ownedit;

type
  TaOwnPopupEdit = class(TaOwnEdit)
  private
    FHooked: Boolean;
    FOpen: Boolean;
    FPopCtl: TControl;
    procedure AppInput(Sender: TObject; var Msg: TLMessage);
    procedure Hook(AOn: Boolean);
  protected
    function TopLevel: TControl;
    { stvara se pri prvom otvaranju; popis je dijete najvise kontrole (forme) }
    procedure SetPopupControl(AControl: TControl);
    { pokazuje popis ispod polja, a ako dolje nema mjesta iznad njega }
    procedure ShowPopupAt(AWidth, AHeight: Integer);
    procedure DoExit; override;
  public
    destructor Destroy; override;
    procedure ClosePopup; virtual;
    property IsOpen: Boolean read FOpen;
  end;

implementation

uses
  Math;

destructor TaOwnPopupEdit.Destroy;
begin
  Hook(False);
  inherited Destroy;
end;

function TaOwnPopupEdit.TopLevel: TControl;
begin
  Result := Self;
  while Result.Parent <> nil do Result := Result.Parent;
end;

procedure TaOwnPopupEdit.SetPopupControl(AControl: TControl);
begin
  FPopCtl := AControl;
end;

procedure TaOwnPopupEdit.Hook(AOn: Boolean);
begin
  if AOn = FHooked then Exit;
  FHooked := AOn;
  if AOn then Application.AddOnUserInputHandler(@AppInput)
  else Application.RemoveOnUserInputHandler(@AppInput);
end;

procedure TaOwnPopupEdit.AppInput(Sender: TObject; var Msg: TLMessage);
var
  P: TPoint;
  Rp, Rs: TRect;
begin
  if (not FOpen) or (FPopCtl = nil) then Exit;
  if (Msg.Msg <> LM_LBUTTONDOWN) and (Msg.Msg <> LM_RBUTTONDOWN) and (Msg.Msg <> LM_MBUTTONDOWN) then Exit;
  P := Mouse.CursorPos;
  Rs := Rect(ClientToScreen(Point(0, 0)).X, ClientToScreen(Point(0, 0)).Y, ClientToScreen(Point(Width, Height)).X, ClientToScreen(Point(Width, Height)).Y);
  Rp := Rect(FPopCtl.ClientToScreen(Point(0, 0)).X, FPopCtl.ClientToScreen(Point(0, 0)).Y,
    FPopCtl.ClientToScreen(Point(FPopCtl.Width, FPopCtl.Height)).X, FPopCtl.ClientToScreen(Point(FPopCtl.Width, FPopCtl.Height)).Y);
  if not (PtInRect(Rs, P) or PtInRect(Rp, P)) then ClosePopup;
end;

procedure TaOwnPopupEdit.ShowPopupAt(AWidth, AHeight: Integer);
var
  TopC: TControl;
  Sp: TPoint;
  Y: Integer;
begin
  if (FPopCtl = nil) or (Parent = nil) then Exit;
  TopC := TopLevel;
  Sp := TopC.ScreenToClient(ClientToScreen(Point(0, Height)));
  Y := Sp.Y;
  if (Y + AHeight > TopC.ClientHeight) and (TopC.ScreenToClient(ClientToScreen(Point(0, 0))).Y - AHeight >= 0) then
    Y := TopC.ScreenToClient(ClientToScreen(Point(0, 0))).Y - AHeight;
  FPopCtl.SetBounds(Sp.X, Y, AWidth, AHeight);
  FPopCtl.BringToFront;
  FPopCtl.Visible := True;
  FOpen := True;
  Hook(True);
  Invalidate;
end;

procedure TaOwnPopupEdit.ClosePopup;
begin
  if not FOpen then Exit;
  FOpen := False;
  Hook(False);
  if FPopCtl <> nil then FPopCtl.Visible := False;
  Invalidate;
end;

procedure TaOwnPopupEdit.DoExit;
begin
  ClosePopup;
  inherited DoExit;
end;

end.
