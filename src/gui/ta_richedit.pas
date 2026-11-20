unit ta_richedit;
{ Uredjivac formatiranog teksta ("laksi WordPad"): traka s gumbima iznad polja.
  Tekst se u bazu sprema kao mali HTML (ta_richtext), a ovdje se pretvara u i iz TRichMemo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics, Dialogs, LazUTF8, RichMemo, ta_richtext, ta_richbase;

type
  TaRichEdit = class(TaRichBase)
  private
    FBar: TPanel;
    FMemo: TRichMemo;
    FSize: TComboBox;
    FLoading: Boolean;
    FDefColor: Integer;
    FDefPt: Integer;
    FPending: Boolean;       { oblikovanje ceka da kontrola dobije prozor }
    FPendingHtml: string;
    FTries: Integer;
    procedure ApplyAttrs(const AHtml: string);
    procedure ApplyLater(Data: PtrInt);
    procedure Btn(const ACaption: string; AX, AW: Integer; ATag: Integer);
    procedure BarClick(Sender: TObject);
    procedure SizeChange(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure ToggleStyle(AStyle: TFontStyle);
    procedure ApplyColor;
    procedure SetAlign(AAlign: TParaAlignment);
    procedure ToggleBullet;
    procedure ClearFormat;
    function RunFor(AIndex: Integer): TRtRun;
    procedure Modify(AStart, ALen, AWhat: Integer; AStyle: TFontStyle; AAdd: Boolean; AColor: TColor; ASize: Integer);
  protected
    function GetHtml: string; override;
    procedure SetHtml(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Memo: TRichMemo read FMemo;
    { za testove: uredjivanje bez misa }
    procedure SelectRange(AStart, ALen: Integer); override;
    procedure ApplyBold; override;
    procedure ApplyItalic; override;
    procedure ApplyUnderline; override;
    procedure ApplyColorRgb(ARgb: Integer); override;
    procedure ApplySizePt(APt: Integer); override;
    procedure ApplyAlign(AAlign: TRtAlign); override;
    procedure ApplyBullet; override;
  end;

implementation

function MakeLcl(AOwner: TComponent): TaRichBase;
begin
  Result := TaRichEdit.Create(AOwner);
end;

destructor TaRichEdit.Destroy;
begin
  { odgodjeni poziv ne smije stici na vec uništenu kontrolu }
  Application.RemoveAsyncCalls(Self);
  inherited Destroy;
end;

const
  BulletPrefix = #$E2#$80#$A2' ';     { "• " }

constructor TaRichEdit.Create(AOwner: TComponent);
const
  Sizes: array[0..8] of string = ('8', '9', '10', '11', '12', '14', '16', '18', '24');
var
  I: Integer;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FBar := TPanel.Create(Self);
  FBar.Parent := Self;
  FBar.Align := alTop;
  FBar.Height := 30;
  FBar.BevelOuter := bvNone;
  FBar.Caption := '';
  Btn('B', 2, 28, 1);
  Btn('I', 32, 28, 2);
  Btn('U', 62, 28, 3);
  Btn('A', 96, 28, 4);
  FSize := TComboBox.Create(Self);
  FSize.Parent := FBar;
  FSize.SetBounds(128, 2, 56, 26);
  FSize.Style := csDropDown;
  for I := 0 to High(Sizes) do FSize.Items.Add(Sizes[I]);
  FSize.OnChange := @SizeChange;
  Btn('◀', 192, 28, 5);
  Btn('≡', 222, 28, 6);
  Btn('▶', 252, 28, 7);
  Btn('•', 286, 28, 8);
  Btn('✕', 320, 28, 9);
  FMemo := TRichMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.ScrollBars := ssAutoVertical;
  FMemo.WordWrap := True;
  FMemo.OnChange := @MemoChange;
  FDefColor := ColorToRGB(FMemo.Font.Color);
  FDefColor := ((FDefColor and $FF) shl 16) or (FDefColor and $FF00) or ((FDefColor shr 16) and $FF);
  FDefPt := FMemo.Font.Size;
  if FDefPt <= 0 then FDefPt := 10;
  Height := 160;
  Width := 360;
end;

procedure TaRichEdit.Btn(const ACaption: string; AX, AW: Integer; ATag: Integer);
var
  B: TButton;
begin
  B := TButton.Create(Self);
  B.Parent := FBar;
  B.Caption := ACaption;
  B.SetBounds(AX, 2, AW, 26);
  B.Tag := ATag;
  B.OnClick := @BarClick;
  B.TabStop := False;
  case ATag of
    1: B.Font.Style := [fsBold];
    2: B.Font.Style := [fsItalic];
    3: B.Font.Style := [fsUnderline];
  end;
end;

procedure TaRichEdit.BarClick(Sender: TObject);
begin
  if FReadOnly then Exit;
  case TButton(Sender).Tag of
    1: ToggleStyle(fsBold);
    2: ToggleStyle(fsItalic);
    3: ToggleStyle(fsUnderline);
    4: ApplyColor;
    5: SetAlign(paLeft);
    6: SetAlign(paCenter);
    7: SetAlign(paRight);
    8: ToggleBullet;
    9: ClearFormat;
  end;
  FMemo.SetFocus;
end;

procedure TaRichEdit.MemoChange(Sender: TObject);
begin
  if (not FLoading) and Assigned(FOnChanged) then FOnChanged(Self);
end;

procedure TaRichEdit.SetReadOnly(AValue: Boolean);
begin
  FReadOnly := AValue;
  FMemo.ReadOnly := AValue;
  FBar.Visible := not AValue;
end;

{ ---------------- oblikovanje oznacenog ---------------- }

procedure TaRichEdit.SelectRange(AStart, ALen: Integer);
begin
  FMemo.SelStart := AStart;
  FMemo.SelLength := ALen;
end;

{ RichMemo-ov SetRangeParams pod Qt6 ne razlikuje dijelove, pa se oblikuje znak po znak, a susjedni jednaki se spajaju }
procedure TaRichEdit.Modify(AStart, ALen, AWhat: Integer; AStyle: TFontStyle; AAdd: Boolean; AColor: TColor; ASize: Integer);
var
  I, RunStart: Integer;
  P, Prev: TFontParams;
  Have: Boolean;

  function Same(const A, B: TFontParams): Boolean;
  begin
    Result := (A.Name = B.Name) and (A.Size = B.Size) and (A.Color = B.Color) and (A.Style = B.Style);
  end;

begin
  Have := False;
  RunStart := AStart;
  FLoading := True;
  try
    for I := AStart to AStart + ALen - 1 do
    begin
      if not FMemo.GetTextAttributes(I, P) then Continue;
      case AWhat of
        1: if AAdd then P.Style := P.Style + [AStyle] else P.Style := P.Style - [AStyle];
        2: P.Color := AColor;
        3: P.Size := ASize;
      end;
      if Have and not Same(P, Prev) then
      begin
        FMemo.SetTextAttributes(RunStart, I - RunStart, Prev);
        RunStart := I;
      end;
      Prev := P;
      Have := True;
    end;
    if Have then FMemo.SetTextAttributes(RunStart, AStart + ALen - RunStart, Prev);
  finally
    FLoading := False;
  end;
end;

procedure TaRichEdit.ToggleStyle(AStyle: TFontStyle);
var
  Fp: TFontParams;
  Mid, N: Integer;
  Has: Boolean;
begin
  N := FMemo.SelLength;
  if N = 0 then Exit;
  Mid := FMemo.SelStart;
  { ako je cijeli odabir vec tako oblikovan, oblikovanje se skida }
  Has := FMemo.GetTextAttributes(Mid, Fp) and (AStyle in Fp.Style);
  Modify(Mid, N, 1, AStyle, not Has, 0, 0);
  FMemo.SelStart := Mid;
  FMemo.SelLength := N;
  MemoChange(nil);
end;

procedure TaRichEdit.ApplyBold; begin ToggleStyle(fsBold); end;
procedure TaRichEdit.ApplyItalic; begin ToggleStyle(fsItalic); end;
procedure TaRichEdit.ApplyUnderline; begin ToggleStyle(fsUnderline); end;

procedure TaRichEdit.ApplyColorRgb(ARgb: Integer);
var
  St, N: Integer;
begin
  if FMemo.SelLength = 0 then Exit;
  St := FMemo.SelStart;
  N := FMemo.SelLength;
  Modify(St, N, 2, fsBold, True, TColor(((ARgb and $FF) shl 16) or (ARgb and $FF00) or ((ARgb shr 16) and $FF)), 0);
  FMemo.SelStart := St;
  FMemo.SelLength := N;
  MemoChange(nil);
end;

procedure TaRichEdit.ApplyColor;
var
  D: TColorDialog;
begin
  if FMemo.SelLength = 0 then Exit;
  D := TColorDialog.Create(nil);
  try
    if D.Execute then
      ApplyColorRgb(((ColorToRGB(D.Color) and $FF) shl 16) or (ColorToRGB(D.Color) and $FF00) or ((ColorToRGB(D.Color) shr 16) and $FF));
  finally
    D.Free;
  end;
end;

procedure TaRichEdit.ApplySizePt(APt: Integer);
var
  St, N: Integer;
begin
  if (FMemo.SelLength = 0) or (APt < 4) or (APt > 96) then Exit;
  St := FMemo.SelStart;
  N := FMemo.SelLength;
  Modify(St, N, 3, fsBold, True, 0, APt);
  FMemo.SelStart := St;
  FMemo.SelLength := N;
  MemoChange(nil);
end;

procedure TaRichEdit.SizeChange(Sender: TObject);
begin
  if FLoading or FReadOnly then Exit;
  ApplySizePt(StrToIntDef(FSize.Text, 0));
end;

procedure TaRichEdit.SetAlign(AAlign: TParaAlignment);
var
  Len: Integer;
begin
  Len := FMemo.SelLength;
  if Len = 0 then Len := 1;
  FMemo.SetParaAlignment(FMemo.SelStart, Len, AAlign);
  MemoChange(nil);
end;

procedure TaRichEdit.ApplyAlign(AAlign: TRtAlign);
begin
  case AAlign of
    raLeft: SetAlign(paLeft);
    raCenter: SetAlign(paCenter);
    raRight: SetAlign(paRight);
  end;
end;

{ natuknica je znak "• " na pocetku odlomka }
procedure TaRichEdit.ToggleBullet;
var
  T: string;
  P, LS: Integer;
begin
  T := FMemo.Text;
  P := FMemo.SelStart;
  { pocetak odlomka u UTF-8 znakovima }
  LS := P;
  while (LS > 0) and (UTF8Copy(T, LS, 1) <> #10) do Dec(LS);
  if LS = 0 then FMemo.SelStart := 0 else FMemo.SelStart := LS;
  if UTF8Copy(T, LS + 1, 2) = BulletPrefix then
  begin
    FMemo.SelLength := 2;
    FMemo.SelText := '';
  end
  else
  begin
    FMemo.SelLength := 0;
    FMemo.SelText := BulletPrefix;
  end;
  FMemo.SelStart := P;
  MemoChange(nil);
end;

procedure TaRichEdit.ApplyBullet;
begin
  ToggleBullet;
end;

procedure TaRichEdit.ClearFormat;
var
  Fp: TFontParams;
begin
  if FMemo.SelLength = 0 then Exit;
  InitFontParams(Fp);
  Fp.Name := FMemo.Font.Name;
  Fp.Size := FDefPt;
  Fp.Color := FMemo.Font.Color;
  Fp.Style := [];
  FMemo.SetTextAttributes(FMemo.SelStart, FMemo.SelLength, Fp);
  MemoChange(nil);
end;

{ ---------------- pretvorba ---------------- }

function TaRichEdit.RunFor(AIndex: Integer): TRtRun;
var
  Fp: TFontParams;
  C: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Color := -1;
  if FMemo.GetTextAttributes(AIndex, Fp) then
  begin
    Result.Bold := fsBold in Fp.Style;
    Result.Italic := fsItalic in Fp.Style;
    Result.Underline := fsUnderline in Fp.Style;
    C := ColorToRGB(Fp.Color);
    C := ((C and $FF) shl 16) or (C and $FF00) or ((C shr 16) and $FF);
    if (C <> FDefColor) and (Fp.Color <> clDefault) then Result.Color := C;
    if (Fp.Size > 0) and (Fp.Size <> FDefPt) then Result.SizePt := Fp.Size;
  end;
end;

function TaRichEdit.GetHtml: string;
var
  Doc: TRtDoc;
  L: TStringList;
  I, K, Pos0, Len: Integer;
  P: TRtPara;
  R, Cur: TRtRun;
  Buf, Line: string;
  Al: TParaAlignment;
begin
  if FPending then Exit(FPendingHtml);
  if not FMemo.HandleAllocated then FMemo.HandleNeeded;
  Doc := TRtDoc.Create;
  L := TStringList.Create;
  try
    L.Text := FMemo.Text;
    if (L.Count = 0) then L.Add('');
    Pos0 := 0;
    for I := 0 to L.Count - 1 do
    begin
      Line := L[I];
      Len := UTF8Length(Line);
      P := Doc.AddPara;
      if UTF8Copy(Line, 1, 2) = BulletPrefix then
      begin
        P.Bullet := True;
        Line := UTF8Copy(Line, 3, MaxInt);
        Inc(Pos0, 2);
        Dec(Len, 2);
      end;
      FMemo.SelStart := Pos0;
      FMemo.SelLength := 0;
      if (Len > 0) and FMemo.GetParaAlignment(Pos0, Al) then
        case Al of
          paCenter: P.Align := raCenter;
          paRight: P.Align := raRight;
        end;
      Buf := '';
      FillChar(Cur, SizeOf(Cur), 0);
      Cur.Color := -1;
      for K := 0 to Len - 1 do
      begin
        R := RunFor(Pos0 + K);
        if (K > 0) and ((R.Bold <> Cur.Bold) or (R.Italic <> Cur.Italic) or (R.Underline <> Cur.Underline) or
           (R.Color <> Cur.Color) or (R.SizePt <> Cur.SizePt)) then
        begin
          Cur.Text := Buf;
          P.AddRun(Cur);
          Buf := '';
        end;
        Cur := R;
        Buf := Buf + UTF8Copy(Line, K + 1, 1);
      end;
      if Buf <> '' then
      begin
        Cur.Text := Buf;
        P.AddRun(Cur);
      end;
      Inc(Pos0, Len + 1);
      if P.Bullet then Pos0 := Pos0;
    end;
    Result := Doc.ToHtml;
  finally
    L.Free;
    Doc.Free;
  end;
end;

procedure TaRichEdit.SetHtml(const AValue: string);
var
  Doc: TRtDoc;
  I: Integer;
  Txt: string;
begin
  FPendingHtml := AValue;
  FLoading := True;
  Doc := TRtDoc.Create;
  try
    Doc.LoadHtml(AValue);
    Txt := '';
    for I := 0 to Doc.Count - 1 do
    begin
      if I > 0 then Txt := Txt + #10;
      if Doc[I].Bullet then Txt := Txt + BulletPrefix;
      Txt := Txt + Doc[I].PlainText;
    end;
    FMemo.Lines.Clear;
    FMemo.Text := Txt;
  finally
    Doc.Free;
    FLoading := False;
  end;
  { oblikovanje se moze upisati tek kad kontrola ima prozor (inace se tiho izgubi) }
  if FMemo.HandleAllocated and HandleAllocated then
  begin
    FPending := False;
    ApplyAttrs(AValue);
  end
  else
  begin
    FPending := True;
    FTries := 0;
    Application.QueueAsyncCall(@ApplyLater, 0);
  end;
end;

procedure TaRichEdit.ApplyLater(Data: PtrInt);
begin
  if not FPending then Exit;
  Inc(FTries);
  if FMemo.HandleAllocated and HandleAllocated then
  begin
    FPending := False;
    ApplyAttrs(FPendingHtml);
  end
  else if FTries < 50 then Application.QueueAsyncCall(@ApplyLater, 0)
  else begin FMemo.HandleNeeded; FPending := False; ApplyAttrs(FPendingHtml); end;
end;

procedure TaRichEdit.ApplyAttrs(const AHtml: string);
var
  Doc: TRtDoc;
  I, J, Pos0, Len: Integer;
  P: TRtPara;
  Fp: TFontParams;
  R: TRtRun;
  ParaStart: Integer;
  Total: Integer;
begin
  FLoading := True;
  Doc := TRtDoc.Create;
  try
    Doc.LoadHtml(AHtml);
    Total := UTF8Length(FMemo.Text);
    InitFontParams(Fp);
    Fp.Name := FMemo.Font.Name;
    Fp.Size := FDefPt;
    Fp.Color := FMemo.Font.Color;
    Fp.Style := [];
    if Total > 0 then FMemo.SetTextAttributes(0, Total, Fp);
    Pos0 := 0;
    for I := 0 to Doc.Count - 1 do
    begin
      P := Doc[I];
      if P.Bullet then Inc(Pos0, 2);
      ParaStart := Pos0;
      for J := 0 to High(P.Runs) do
      begin
        R := P.Runs[J];
        Len := UTF8Length(R.Text);
        if Len > 0 then
        begin
          Fp.Style := [];
          if R.Bold then Include(Fp.Style, fsBold);
          if R.Italic then Include(Fp.Style, fsItalic);
          if R.Underline then Include(Fp.Style, fsUnderline);
          if R.Color >= 0 then Fp.Color := TColor(((R.Color and $FF) shl 16) or (R.Color and $FF00) or ((R.Color shr 16) and $FF))
          else Fp.Color := FMemo.Font.Color;
          if R.SizePt > 0 then Fp.Size := R.SizePt else Fp.Size := FDefPt;
          FMemo.SetTextAttributes(Pos0, Len, Fp);
        end;
        Inc(Pos0, Len);
      end;
      case P.Align of
        raCenter: FMemo.SetParaAlignment(ParaStart, 1, paCenter);
        raRight: FMemo.SetParaAlignment(ParaStart, 1, paRight);
      end;
      Inc(Pos0);
    end;
  finally
    Doc.Free;
    FLoading := False;
  end;
end;

initialization
  RichLclFactory := @MakeLcl;

end.
