unit ta_ownedit;
{ Vlastito jednoredno polje (pruzatelj 'own'): crta se samo (TCustomControl), pa izgleda i radi isto na Qt-u, GTK-u i drugdje.
  Ne ovisi o izvornoj kontroli TEdit. Zna: unos i brisanje (UTF-8), kursor i oznacavanje tipkama i misem, rijeci (Ctrl+strelice,
  dvoklik), Ctrl+A/C/X/V/Z/Y, lozinku, samo citanje, poravnanje, najvecu duljinu, pomicanje teksta u uskom polju, boje iz teme.
  Ne zna (zasad): unos preko IME-a (kompozicija), kontekstni izbornik, povlacenje teksta.

  Pokretaci za obitelj Edit (text, password, currency) registriraju se kao pruzatelj 'own'; ukljucuju se
  varijablom okoline TYPHACCESS_PROVIDER=own ili SetPreferredProvider('own'). Ostale varijante i dalje rade preko LCL-a. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, LCLType, Clipbrd, LazUTF8, Variants, ta_family, ta_edit;

type
  TaOwnEdit = class(TCustomControl)
  protected
    FRightPad: Integer;            { desni prostor rezerviran za potomke (strelica padajuceg popisa) }
    FPlain: Boolean;               { bez kursora i oznake: potomak sam prikazuje vrijednost (padajuci popis) }
    function PtInRightPad(X: Integer): Boolean;
    procedure PaintExtras(ARect: TRect); virtual;
    procedure TextTyped; virtual;  { poziva se nakon unosa znakova tipkama }
    procedure SetShownText(const AValue: string);
  protected
    FText: string;
    FLen: Integer;
    FCaret, FAnchor: Integer;      { 0..FLen, u znakovima (ne bajtovima) }
    FScroll: Integer;
    FReadOnly: Boolean;
    FAlign: TAlignment;
    FMaxLength: Integer;
    FPasswordChar: Char;
    FOnChange: TNotifyEvent;
    FCaretOn, FDragging: Boolean;
    FTimer: TTimer;
    FUndo, FRedo: TStringList;     { stanja teksta; Objects = polozaj kursora }
    FSilent: Boolean;
    procedure TimerTick(Sender: TObject);
    procedure SetAlign(AValue: TAlignment);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetPasswordChar(AValue: Char);
    procedure SetMaxLength(AValue: Integer);
    function GetSelStart: Integer;
    procedure SetSelStart(AValue: Integer);
    function GetSelLength: Integer;
    procedure SetSelLength(AValue: Integer);
    function Shown: string;
    function WidthTo(ACount: Integer): Integer;
    function Avail: Integer;
    function Origin: Integer;
    function IndexAt(X: Integer): Integer;
    procedure KeepCaretVisible;
    procedure MoveCaret(ANew: Integer; AExtend: Boolean);
    procedure PushUndo;
    procedure Changed;
    function WordLeft(AFrom: Integer): Integer;
    function WordRight(AFrom: Integer): Integer;
    function SelectedText: string;
    procedure DeleteSelection;
    procedure DoUndo(AFrom, ATo: TStringList);
  protected
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure EnabledChanged; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure InsertText(const AText: string);
    procedure SelectAll;
    procedure CopyToClipboard;
    procedure CutToClipboard;
    procedure PasteFromClipboard;
    property Text;
    property SelStart: Integer read GetSelStart write SetSelStart;
    property SelLength: Integer read GetSelLength write SetSelLength;
    property CharCount: Integer read FLen;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
    property Alignment: TAlignment read FAlign write SetAlign;
    property MaxLength: Integer read FMaxLength write SetMaxLength;
    property PasswordChar: Char read FPasswordChar write SetPasswordChar;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  { ---------------- pokretaci pruzatelja 'own' ---------------- }

  TaOwnTextEngine = class(TaEngine)
  private
    FEdit: TaOwnEdit;
    FMask: string;
    FMaskBusy: Boolean;
    procedure MaskChange(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    class function Provider: string; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure SetAlignment(AValue: TAlignment); override;
    procedure SetMaxLength(AValue: Integer); override;
    procedure SetMask(const AValue: string); override;
  end;

  TaOwnPasswordEngine = class(TaOwnTextEngine)
  public
    constructor Create(AHost: TaFamilyHost); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  TaOwnCurrencyEngine = class(TaOwnTextEngine)
  private
    FDecimals: Integer;
    FSymbol: string;
    function FormatNumber(AValue: Double): string;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    procedure Commit; override;
  end;

implementation

uses
  Math, ta_tokens, ta_mask;

{ ---------------- TaOwnEdit ---------------- }

constructor TaOwnEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ApplyThemeFont(Font);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents, csDoubleClicks];
  TabStop := True;
  Cursor := crIBeam;
  Width := 120;
  Height := 26;
  FUndo := TStringList.Create;
  FRedo := TStringList.Create;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 530;
  FTimer.OnTimer := @TimerTick;
  FAlign := taLeftJustify;
end;

destructor TaOwnEdit.Destroy;
begin
  FTimer.Enabled := False;
  FUndo.Free;
  FRedo.Free;
  inherited Destroy;
end;

function TaOwnEdit.PtInRightPad(X: Integer): Boolean;
begin
  Result := (FRightPad > 0) and (X >= Width - FRightPad);
end;

procedure TaOwnEdit.PaintExtras(ARect: TRect);
begin
end;

procedure TaOwnEdit.TextTyped;
begin
end;

{ tekst bez poruke o promjeni ni ponistavanja (potomak ga postavlja pri odabiru) }
procedure TaOwnEdit.SetShownText(const AValue: string);
begin
  if AValue = FText then Exit;
  FText := AValue;
  FLen := UTF8Length(FText);
  FCaret := 0;
  FAnchor := 0;
  FScroll := 0;
  Invalidate;
end;

procedure TaOwnEdit.TimerTick(Sender: TObject);
begin
  FCaretOn := not FCaretOn;
  Invalidate;
end;

function TaOwnEdit.RealGetText: TCaption;
begin
  Result := FText;
end;

procedure TaOwnEdit.RealSetText(const AValue: TCaption);
var
  S: string;
begin
  S := AValue;
  if (FMaxLength > 0) and (UTF8Length(S) > FMaxLength) then S := UTF8Copy(S, 1, FMaxLength);
  if S = FText then Exit;
  FText := S;
  FLen := UTF8Length(FText);
  FCaret := FLen;
  FAnchor := FLen;
  FScroll := 0;
  FUndo.Clear;
  FRedo.Clear;
  KeepCaretVisible;
  Invalidate;
  Changed;
end;

procedure TaOwnEdit.Changed;
begin
  if (not FSilent) and Assigned(FOnChange) then FOnChange(Self);
end;

function TaOwnEdit.Shown: string;
begin
  if FPasswordChar <> #0 then Result := StringOfChar(FPasswordChar, FLen) else Result := FText;
end;

function TaOwnEdit.WidthTo(ACount: Integer): Integer;
begin
  Canvas.Font.Assign(Font);
  if ACount <= 0 then Exit(0);
  Result := Canvas.TextWidth(UTF8Copy(Shown, 1, ACount));
end;

function TaOwnEdit.Avail: Integer;
begin
  Result := Width - 2 * 7 - FRightPad;
  if Result < 1 then Result := 1;
end;

function TaOwnEdit.Origin: Integer;
var
  Tw: Integer;
begin
  Tw := WidthTo(FLen);
  if Tw >= Avail then Exit(7 - FScroll);
  case FAlign of
    taRightJustify: Result := Width - 7 - FRightPad - Tw;
    taCenter: Result := 7 + (Avail - Tw) div 2;
  else
    Result := 7;
  end;
end;

function TaOwnEdit.IndexAt(X: Integer): Integer;
var
  I, A, B, O: Integer;
begin
  O := Origin;
  for I := 0 to FLen - 1 do
  begin
    A := O + WidthTo(I);
    B := O + WidthTo(I + 1);
    if X < (A + B) div 2 then Exit(I);
  end;
  Result := FLen;
end;

procedure TaOwnEdit.KeepCaretVisible;
var
  Tw, Cx: Integer;
begin
  Tw := WidthTo(FLen);
  if Tw <= Avail then begin FScroll := 0; Exit; end;
  Cx := WidthTo(FCaret);
  if Cx - FScroll > Avail then FScroll := Cx - Avail;
  if Cx - FScroll < 0 then FScroll := Cx;
  if FScroll > Tw - Avail + 2 then FScroll := Max(0, Tw - Avail + 2);
end;

procedure TaOwnEdit.MoveCaret(ANew: Integer; AExtend: Boolean);
begin
  if ANew < 0 then ANew := 0;
  if ANew > FLen then ANew := FLen;
  FCaret := ANew;
  if not AExtend then FAnchor := FCaret;
  FCaretOn := True;
  KeepCaretVisible;
  Invalidate;
end;

procedure TaOwnEdit.PushUndo;
begin
  FUndo.AddObject(FText, TObject(PtrInt(FCaret)));
  if FUndo.Count > 200 then FUndo.Delete(0);
  FRedo.Clear;
end;

procedure TaOwnEdit.DoUndo(AFrom, ATo: TStringList);
var
  I: Integer;
begin
  if AFrom.Count = 0 then Exit;
  I := AFrom.Count - 1;
  ATo.AddObject(FText, TObject(PtrInt(FCaret)));
  FText := AFrom[I];
  FCaret := PtrInt(AFrom.Objects[I]);
  AFrom.Delete(I);
  FLen := UTF8Length(FText);
  if FCaret > FLen then FCaret := FLen;
  FAnchor := FCaret;
  KeepCaretVisible;
  Invalidate;
  Changed;
end;

function IsWordChar(const AChar: string): Boolean;
begin
  if AChar = '' then Exit(False);
  Result := (Ord(AChar[1]) >= 128) or (AChar[1] in ['0'..'9', 'a'..'z', 'A'..'Z', '_']);
end;

function TaOwnEdit.WordLeft(AFrom: Integer): Integer;
begin
  Result := AFrom;
  while (Result > 0) and not IsWordChar(UTF8Copy(FText, Result, 1)) do Dec(Result);
  while (Result > 0) and IsWordChar(UTF8Copy(FText, Result, 1)) do Dec(Result);
end;

function TaOwnEdit.WordRight(AFrom: Integer): Integer;
begin
  Result := AFrom;
  while (Result < FLen) and IsWordChar(UTF8Copy(FText, Result + 1, 1)) do Inc(Result);
  while (Result < FLen) and not IsWordChar(UTF8Copy(FText, Result + 1, 1)) do Inc(Result);
end;

function TaOwnEdit.GetSelStart: Integer;
begin
  Result := Min(FCaret, FAnchor);
end;

procedure TaOwnEdit.SetSelStart(AValue: Integer);
begin
  MoveCaret(AValue, False);
end;

function TaOwnEdit.GetSelLength: Integer;
begin
  Result := Abs(FCaret - FAnchor);
end;

procedure TaOwnEdit.SetSelLength(AValue: Integer);
begin
  FCaret := Min(FLen, Min(FCaret, FAnchor) + Max(0, AValue));
  FAnchor := Min(FAnchor, FCaret);
  Invalidate;
end;

function TaOwnEdit.SelectedText: string;
begin
  Result := UTF8Copy(FText, GetSelStart + 1, GetSelLength);
end;

procedure TaOwnEdit.DeleteSelection;
var
  S, N: Integer;
begin
  N := GetSelLength;
  if N = 0 then Exit;
  S := GetSelStart;
  UTF8Delete(FText, S + 1, N);
  FLen := UTF8Length(FText);
  FCaret := S;
  FAnchor := S;
end;

procedure TaOwnEdit.InsertText(const AText: string);
var
  S: string;
  P, Room: Integer;
begin
  if FReadOnly then Exit;
  S := AText;
  P := Pos(#10, S);
  if P > 0 then S := Copy(S, 1, P - 1);
  P := Pos(#13, S);
  if P > 0 then S := Copy(S, 1, P - 1);
  PushUndo;
  DeleteSelection;
  if FMaxLength > 0 then
  begin
    Room := FMaxLength - FLen;
    if Room <= 0 then S := '' else if UTF8Length(S) > Room then S := UTF8Copy(S, 1, Room);
  end;
  if S = '' then begin Invalidate; Changed; Exit; end;
  UTF8Insert(S, FText, FCaret + 1);
  Inc(FCaret, UTF8Length(S));
  FLen := UTF8Length(FText);
  FAnchor := FCaret;
  FCaretOn := True;
  KeepCaretVisible;
  Invalidate;
  Changed;
end;

procedure TaOwnEdit.SelectAll;
begin
  FAnchor := 0;
  FCaret := FLen;
  KeepCaretVisible;
  Invalidate;
end;

procedure TaOwnEdit.CopyToClipboard;
begin
  if (GetSelLength > 0) and (FPasswordChar = #0) then Clipboard.AsText := SelectedText;
end;

procedure TaOwnEdit.CutToClipboard;
begin
  if FReadOnly or (FPasswordChar <> #0) then Exit;
  CopyToClipboard;
  if GetSelLength > 0 then
  begin
    PushUndo;
    DeleteSelection;
    KeepCaretVisible;
    Invalidate;
    Changed;
  end;
end;

procedure TaOwnEdit.PasteFromClipboard;
begin
  if Clipboard.HasFormat(CF_TEXT) then InsertText(Clipboard.AsText);
end;

procedure TaOwnEdit.SetAlign(AValue: TAlignment);
begin
  if FAlign = AValue then Exit;
  FAlign := AValue;
  Invalidate;
end;

procedure TaOwnEdit.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  Invalidate;
end;

procedure TaOwnEdit.SetPasswordChar(AValue: Char);
begin
  if FPasswordChar = AValue then Exit;
  FPasswordChar := AValue;
  KeepCaretVisible;
  Invalidate;
end;

procedure TaOwnEdit.SetMaxLength(AValue: Integer);
begin
  FMaxLength := AValue;
  if (FMaxLength > 0) and (FLen > FMaxLength) then
  begin
    FText := UTF8Copy(FText, 1, FMaxLength);
    FLen := FMaxLength;
    if FCaret > FLen then FCaret := FLen;
    if FAnchor > FLen then FAnchor := FLen;
    Invalidate;
    Changed;
  end;
end;

procedure TaOwnEdit.Paint;
var
  T: TaThemeTokens;
  Bg, Br, Tx, SelBg, SelTx: TColor;
  R, S0, S1, X0, Ty, Cx: Integer;
  Foc: Boolean;
begin
  T := ActiveTokens;
  Foc := Focused;
  if Enabled and not FReadOnly then Bg := TokenColor(T.Surface) else Bg := TokenColor(T.Soft);
  if Foc then Br := TokenColor(T.Accent) else Br := TokenColor(T.Border);
  if Enabled then Tx := TokenColor(T.Text) else Tx := TokenColor(T.TextSoft);
  if Enabled and (Font.Color <> clWindowText) and (Font.Color <> clDefault) then Tx := Font.Color;
  SelBg := TokenColor(T.Accent);
  SelTx := TokenColor(T.OnAccent);
  R := T.RadiusField;
  if R > Height div 2 then R := Height div 2;
  { pozadina roditelja (uglovi), pa zaobljeno polje }
  if Parent <> nil then Canvas.Brush.Color := Parent.Color else Canvas.Brush.Color := Bg;
  Canvas.Pen.Style := psClear;
  Canvas.FillRect(0, 0, Width, Height);
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Color := Bg;
  Canvas.Pen.Color := Br;
  if Foc then Canvas.Pen.Width := 2 else Canvas.Pen.Width := 1;
  if R > 0 then Canvas.RoundRect(0, 0, Width, Height, R * 2, R * 2)
  else Canvas.Rectangle(0, 0, Width, Height);
  Canvas.Pen.Width := 1;
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := Tx;
  Ty := (Height - Canvas.TextHeight('Ag')) div 2;
  Canvas.ClipRect := Rect(6, 2, Width - 6 - FRightPad, Height - 2);
  Canvas.Clipping := True;
  X0 := Origin;
  S0 := GetSelStart;
  S1 := S0 + GetSelLength;
  if FPlain then S1 := S0;
  if (S1 > S0) and Foc then
  begin
    Canvas.Brush.Color := SelBg;
    Canvas.FillRect(X0 + WidthTo(S0), Ty - 1, X0 + WidthTo(S1), Ty + Canvas.TextHeight('Ag') + 1);
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := Tx;
  if (S1 > S0) and Foc then
  begin
    { tri dijela: prije oznake, oznaka (u boji za oznaku), poslije }
    Canvas.TextOut(X0, Ty, UTF8Copy(Shown, 1, S0));
    Canvas.Font.Color := SelTx;
    Canvas.TextOut(X0 + WidthTo(S0), Ty, UTF8Copy(Shown, S0 + 1, S1 - S0));
    Canvas.Font.Color := Tx;
    Canvas.TextOut(X0 + WidthTo(S1), Ty, UTF8Copy(Shown, S1 + 1, FLen - S1));
  end
  else Canvas.TextOut(X0, Ty, Shown);
  Canvas.Brush.Style := bsSolid;
  if Foc and FCaretOn and (S1 = S0) and not FReadOnly and not FPlain then
  begin
    Cx := X0 + WidthTo(FCaret);
    Canvas.Pen.Color := Tx;
    Canvas.Line(Cx, Ty, Cx, Ty + Canvas.TextHeight('Ag'));
  end;
  Canvas.Clipping := False;
  PaintExtras(Rect(Width - FRightPad, 0, Width, Height));
end;

procedure TaOwnEdit.KeyDown(var Key: Word; Shift: TShiftState);
var
  Ext, Ctl: Boolean;
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then Exit;
  Ext := ssShift in Shift;
  Ctl := ssCtrl in Shift;
  case Key of
    VK_LEFT:
      begin
        if (GetSelLength > 0) and not Ext then MoveCaret(GetSelStart, False)
        else if Ctl then MoveCaret(WordLeft(FCaret), Ext)
        else MoveCaret(FCaret - 1, Ext);
        Key := 0;
      end;
    VK_RIGHT:
      begin
        if (GetSelLength > 0) and not Ext then MoveCaret(GetSelStart + GetSelLength, False)
        else if Ctl then MoveCaret(WordRight(FCaret), Ext)
        else MoveCaret(FCaret + 1, Ext);
        Key := 0;
      end;
    VK_HOME: begin MoveCaret(0, Ext); Key := 0; end;
    VK_END: begin MoveCaret(FLen, Ext); Key := 0; end;
    VK_BACK:
      begin
        if not FReadOnly then
        begin
          PushUndo;
          if GetSelLength = 0 then
          begin
            if Ctl then FAnchor := WordLeft(FCaret) else FAnchor := Max(0, FCaret - 1);
          end;
          if GetSelLength > 0 then begin DeleteSelection; KeepCaretVisible; Invalidate; Changed; end
          else if FUndo.Count > 0 then FUndo.Delete(FUndo.Count - 1);
        end;
        Key := 0;
      end;
    VK_DELETE:
      begin
        if Ext and not Ctl then begin CutToClipboard; Key := 0; Exit; end;
        if not FReadOnly then
        begin
          PushUndo;
          if GetSelLength = 0 then
          begin
            if Ctl then FAnchor := WordRight(FCaret) else FAnchor := Min(FLen, FCaret + 1);
          end;
          if GetSelLength > 0 then
          begin
            DeleteSelection;
            KeepCaretVisible;
            Invalidate;
            Changed;
          end
          else if FUndo.Count > 0 then FUndo.Delete(FUndo.Count - 1);
        end;
        Key := 0;
      end;
    VK_INSERT:
      begin
        if Ext then PasteFromClipboard else if Ctl then CopyToClipboard;
        Key := 0;
      end;
    VK_A: if Shift = [ssCtrl] then begin SelectAll; Key := 0; end;
    VK_C: if Shift = [ssCtrl] then begin CopyToClipboard; Key := 0; end;
    VK_X: if Shift = [ssCtrl] then begin CutToClipboard; Key := 0; end;
    VK_V: if Shift = [ssCtrl] then begin PasteFromClipboard; Key := 0; end;
    VK_Z:
      if Shift = [ssCtrl] then begin if not FReadOnly then DoUndo(FUndo, FRedo); Key := 0; end
      else if Shift = [ssCtrl, ssShift] then begin if not FReadOnly then DoUndo(FRedo, FUndo); Key := 0; end;
    VK_Y: if Shift = [ssCtrl] then begin if not FReadOnly then DoUndo(FRedo, FUndo); Key := 0; end;
  end;
end;

procedure TaOwnEdit.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  inherited UTF8KeyPress(UTF8Key);
  if UTF8Key = '' then Exit;
  if (Length(UTF8Key) = 1) and ((Ord(UTF8Key[1]) < 32) or (Ord(UTF8Key[1]) = 127)) then Exit;
  if FReadOnly then begin UTF8Key := ''; Exit; end;
  InsertText(UTF8Key);
  UTF8Key := '';
  TextTyped;
end;

procedure TaOwnEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if CanFocus and not Focused then SetFocus;
  MoveCaret(IndexAt(X), ssShift in Shift);
  FDragging := True;
end;

procedure TaOwnEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging and (ssLeft in Shift) then MoveCaret(IndexAt(X), True);
end;

procedure TaOwnEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragging := False;
end;

procedure TaOwnEdit.DblClick;
begin
  inherited DblClick;
  FAnchor := WordLeft(Min(FLen, FCaret + 1));
  FCaret := WordRight(FAnchor);
  { WordRight preskace i razmake iza rijeci: vrati na kraj rijeci }
  while (FCaret > FAnchor) and not IsWordChar(UTF8Copy(FText, FCaret, 1)) do Dec(FCaret);
  KeepCaretVisible;
  Invalidate;
end;

procedure TaOwnEdit.DoEnter;
begin
  inherited DoEnter;
  FCaretOn := True;
  FTimer.Enabled := not FPlain;
  if not FPlain then SelectAll;
end;

procedure TaOwnEdit.DoExit;
begin
  FTimer.Enabled := False;
  FCaretOn := False;
  FDragging := False;
  FScroll := 0;
  inherited DoExit;
  Invalidate;
end;

procedure TaOwnEdit.EnabledChanged;
begin
  inherited EnabledChanged;
  Invalidate;
end;

procedure TaOwnEdit.Resize;
begin
  inherited Resize;
  KeepCaretVisible;
end;

{ ---------------- pokretaci ---------------- }

function ParseNumberOwn(const AText: string; out AValue: Double): Boolean;
var
  S: string;
begin
  S := StringReplace(Trim(AText), ' ', '', [rfReplaceAll]);
  if S = '' then Exit(False);
  if DefaultFormatSettings.DecimalSeparator = ',' then S := StringReplace(S, '.', '', [rfReplaceAll])
  else S := StringReplace(S, ',', '', [rfReplaceAll]);
  Result := TryStrToFloat(S, AValue, DefaultFormatSettings);
end;

constructor TaOwnTextEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FEdit := TaOwnEdit.Create(nil);
  FEdit.OnChange := @MaskChange;
  AttachInner(FEdit);
end;

class function TaOwnTextEngine.Provider: string;
begin
  Result := 'own';
end;

function TaOwnTextEngine.GetText: string;
begin
  Result := FEdit.Text;
end;

procedure TaOwnTextEngine.SetText(const AValue: string);
begin
  if FEdit.Text <> AValue then FEdit.Text := AValue;
end;

procedure TaOwnTextEngine.SetReadOnly(AValue: Boolean);
begin
  FEdit.ReadOnly := AValue;
end;

procedure TaOwnTextEngine.SetAlignment(AValue: TAlignment);
begin
  FEdit.Alignment := AValue;
end;

procedure TaOwnTextEngine.SetMaxLength(AValue: Integer);
begin
  FEdit.MaxLength := AValue;
end;

procedure TaOwnTextEngine.MaskChange(Sender: TObject);
var
  F: string;
begin
  if FMaskBusy then Exit;
  if FMask <> '' then
  begin
    F := ApplyMask(FMask, FEdit.Text);
    if F <> FEdit.Text then
    begin
      FMaskBusy := True;
      try
        FEdit.Text := F;
        FEdit.SelStart := UTF8Length(F);
      finally
        FMaskBusy := False;
      end;
    end;
  end;
  InnerChanged(Sender);
end;

procedure TaOwnTextEngine.SetMask(const AValue: string);
begin
  FMask := AValue;
  if FMask <> '' then FEdit.MaxLength := Length(FMask);
  if (FMask <> '') and (ApplyMask(FMask, FEdit.Text) <> FEdit.Text) then FEdit.Text := ApplyMask(FMask, FEdit.Text);
end;

constructor TaOwnPasswordEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FEdit.PasswordChar := '*';
end;

procedure TaOwnPasswordEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaPasswordOptions then
    if TaPasswordOptions(AOptions).PasswordChar <> #0 then FEdit.PasswordChar := TaPasswordOptions(AOptions).PasswordChar;
end;

constructor TaOwnCurrencyEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FDecimals := 2;
  FEdit.Alignment := taRightJustify;
end;

function TaOwnCurrencyEngine.FormatNumber(AValue: Double): string;
begin
  if FDecimals <= 0 then Result := FormatFloat('#,##0', AValue, DefaultFormatSettings)
  else Result := FormatFloat('#,##0.' + StringOfChar('0', FDecimals), AValue, DefaultFormatSettings);
  if FSymbol <> '' then Result := Result + ' ' + FSymbol;
end;

function TaOwnCurrencyEngine.GetValue: Variant;
var
  D: Double;
  S: string;
begin
  S := FEdit.Text;
  if (FSymbol <> '') and (Pos(FSymbol, S) > 0) then S := Trim(StringReplace(S, FSymbol, '', [rfReplaceAll]));
  if ParseNumberOwn(S, D) then Result := D else Result := Null;
end;

procedure TaOwnCurrencyEngine.SetValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then FEdit.Text := ''
  else FEdit.Text := FormatNumber(AValue);
end;

procedure TaOwnCurrencyEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaCurrencyOptions then
  begin
    FDecimals := TaCurrencyOptions(AOptions).DecimalPlaces;
    FSymbol := TaCurrencyOptions(AOptions).Symbol;
  end;
end;

procedure TaOwnCurrencyEngine.Commit;
var
  V: Variant;
begin
  V := GetValue;
  if not VarIsNull(V) then
  begin
    FEdit.OnChange := nil;
    try
      FEdit.Text := FormatNumber(V);
    finally
      FEdit.OnChange := @MaskChange;
    end;
  end;
end;

initialization
  RegisterEngine(EditFamily, 'text', TaOwnTextEngine);
  RegisterEngine(EditFamily, 'password', TaOwnPasswordEngine);
  RegisterEngine(EditFamily, 'currency', TaOwnCurrencyEngine);
  if SameText(GetEnvironmentVariable('TYPHACCESS_PROVIDER'), 'own') then SetPreferredProvider('own');

end.
