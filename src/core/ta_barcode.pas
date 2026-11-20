unit ta_barcode;
{ Barkodovi i QR kodovi bez ovisnosti o sucelju: kodira tekst u obrazac
  (moduli QR-a ili niz crnih/bijelih crta) i raspodjeljuje ga u pravokutnike
  zadane velicine. Isti pravokutnici crtaju se na formi i salju u izvjesca. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, fpbarcode, fpqrcodegen, ta_pdf417;

type
  TBarSymbology = (bsQr, bsCode128, bsEan13, bsEan8, bsCode39, bsItf, bsPdf417);

  TBarBar = record
    Black: Boolean;
    W: Integer;          { sirina u modulima }
  end;

  TBarcode = record
    Is2D: Boolean;
    Size: Integer;               { QR: modula po stranici }
    CellsW, CellsH: Integer;     { 2D: moduli po sirini i visini }
    AspectY: Integer;            { 2D: visina jednog reda u modulima (QR 1, PDF417 3) }
    Cells: array of Boolean;     { 2D: CellsW*CellsH }
    Bars: array of TBarBar;      { 1D }
    Total: Integer;              { 1D: ukupno modula }
    Caption: string;             { 1D: tekst ispod crta }
  end;

  TBarLayout = record
    Rects: array of TRect;       { crni pravokutnici }
    TextRect: TRect;             { prostor za tekst ispod (prazan ako ga nema) }
    HasText: Boolean;
  end;

function BarSymbologyOf(const AName: string): TBarSymbology;
function BarSymbologyName(ASym: TBarSymbology): string;
{ Kontrolna znamenka EAN-a za AZnamenke bez nje. }
function EanCheckDigit(const ADigits: string): Char;
function BarcodeEncode(ASym: TBarSymbology; const AText: string; out ABar: TBarcode;
  out AError: string): Boolean;
{ Raspodjela po povrsini AW x AH; sve koordinate su od (0, 0). }
function BarcodeLayout(const ABar: TBarcode; AW, AH: Integer; AShowText: Boolean;
  ATextH: Integer): TBarLayout;

implementation

function BarSymbologyOf(const AName: string): TBarSymbology;
var
  S: string;
begin
  S := LowerCase(Trim(AName));
  if (S = 'code128') or (S = '128') then Result := bsCode128
  else if S = 'ean13' then Result := bsEan13
  else if S = 'ean8' then Result := bsEan8
  else if (S = 'code39') or (S = '39') then Result := bsCode39
  else if (S = 'itf') or (S = '2of5') then Result := bsItf
  else if (S = 'pdf417') or (S = 'hub3') then Result := bsPdf417
  else Result := bsQr;
end;

function BarSymbologyName(ASym: TBarSymbology): string;
begin
  case ASym of
    bsCode128: Result := 'code128';
    bsEan13: Result := 'ean13';
    bsEan8: Result := 'ean8';
    bsCode39: Result := 'code39';
    bsItf: Result := 'itf';
    bsPdf417: Result := 'pdf417';
  else
    Result := 'qr';
  end;
end;

function EanCheckDigit(const ADigits: string): Char;
var
  I, Sum, D: Integer;
  FromRight: Integer;
begin
  Sum := 0;
  for I := 1 to Length(ADigits) do
  begin
    D := Ord(ADigits[I]) - 48;
    FromRight := Length(ADigits) - I;     { 0 = znamenka uz kontrolnu }
    if Odd(FromRight) then Sum := Sum + D else Sum := Sum + 3 * D;
  end;
  Result := Chr(48 + (10 - Sum mod 10) mod 10);
end;

function AllDigits(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in ['0'..'9']) then Exit(False);
end;

function EncodeQr(const AText: string; out ABar: TBarcode; out AError: string): Boolean;
var
  G: TQRCodeGenerator;
  X, Y, N: Integer;
begin
  Result := False;
  if AText = '' then begin AError := 'Prazan tekst'; Exit; end;
  G := TQRCodeGenerator.Create;
  try
    G.ErrorCorrectionLevel := EccMEDIUM;
    G.MinVersion := 1;
    G.MaxVersion := 40;
    try
      G.Generate(AText);
    except
      on E: Exception do begin AError := 'QR: ' + E.Message; Exit; end;
    end;
    N := G.Size;
    if N <= 0 then begin AError := 'QR: tekst je predug'; Exit; end;
    ABar.Is2D := True;
    ABar.Size := N;
    ABar.CellsW := N;
    ABar.CellsH := N;
    ABar.AspectY := 1;
    SetLength(ABar.Cells, N * N);
    for Y := 0 to N - 1 do
      for X := 0 to N - 1 do
        ABar.Cells[Y * N + X] := G.Bits[X, Y];
    Result := True;
  finally
    G.Free;
  end;
end;

function EncodePdf417(const AText: string; out ABar: TBarcode; out AError: string): Boolean;
var
  Rows: TPdfRows;
  X, Y: Integer;
begin
  Result := False;
  if AText = '' then begin AError := 'Prazan tekst'; Exit; end;
  if not Pdf417Auto(RawByteString(AText), 4, 3.0, Rows, AError) then Exit;
  ABar.Is2D := True;
  ABar.CellsH := Length(Rows);
  ABar.CellsW := Length(Rows[0]);
  ABar.Size := ABar.CellsW;
  ABar.AspectY := 3;
  SetLength(ABar.Cells, ABar.CellsW * ABar.CellsH);
  for Y := 0 to ABar.CellsH - 1 do
    for X := 0 to ABar.CellsW - 1 do
      ABar.Cells[Y * ABar.CellsW + X] := (X < Length(Rows[Y])) and (Rows[Y][X + 1] = '1');
  Result := True;
end;

function Encode1D(ASym: TBarSymbology; const AText: string; out ABar: TBarcode;
  out AError: string): Boolean;
var
  Enc: TBarcodeEncoding;
  S: string;
  Pars: TBarParamsArray;
  Wd: TBarWidthArray;
  I: Integer;
begin
  Result := False;
  AError := '';
  S := AText;
  ABar.Is2D := False;
  ABar.Caption := S;
  case ASym of
    bsEan13, bsEan8:
      begin
        I := 13;
        if ASym = bsEan8 then I := 8;
        if not AllDigits(S) then begin AError := 'EAN prima samo znamenke'; Exit; end;
        if Length(S) = I - 1 then S := S + EanCheckDigit(S)
        else if Length(S) = I then S := Copy(S, 1, I - 1) + EanCheckDigit(Copy(S, 1, I - 1))
        else begin AError := Format('EAN-%d traži %d ili %d znamenki', [I, I - 1, I]); Exit; end;
        ABar.Caption := S;
        if ASym = bsEan13 then Enc := beEAN13 else Enc := beEAN8;
      end;
    bsItf:
      begin
        if not AllDigits(S) then begin AError := 'ITF prima samo znamenke'; Exit; end;
        if Odd(Length(S)) then S := '0' + S;
        ABar.Caption := S;
        Enc := be2of5interleaved;
      end;
    bsCode39:
      begin
        S := UpperCase(S);
        ABar.Caption := S;
        Enc := be39;
        if (S = '') or not StringAllowsBarEncoding(S, Enc) then
        begin AError := 'Code 39 ne prima te znakove'; Exit; end;
      end;
  else
    begin
      if S = '' then begin AError := 'Prazan tekst'; Exit; end;
      if AllDigits(S) and not Odd(Length(S)) then Enc := be128C
      else
      begin
        Enc := be128B;
        if not StringAllowsBarEncoding(S, Enc) then
        begin AError := 'Code 128 ne prima te znakove'; Exit; end;
      end;
    end;
  end;
  try
    Pars := StringToBarcodeParams(S, Enc);
  except
    on E: Exception do begin AError := E.Message; Exit; end;
  end;
  if Length(Pars) = 0 then begin AError := 'Nema crta'; Exit; end;
  Wd := CalcBarWidths(Enc, 1, 2.0);
  SetLength(ABar.Bars, Length(Pars));
  ABar.Total := 0;
  for I := 0 to High(Pars) do
  begin
    ABar.Bars[I].Black := Pars[I].c = bcBlack;
    ABar.Bars[I].W := Wd[Pars[I].w];
    Inc(ABar.Total, ABar.Bars[I].W);
  end;
  Result := True;
end;

function BarcodeEncode(ASym: TBarSymbology; const AText: string; out ABar: TBarcode;
  out AError: string): Boolean;
begin
  FillChar(ABar, SizeOf(ABar), 0);
  ABar.Cells := nil;
  ABar.Bars := nil;
  AError := '';
  if ASym = bsQr then Result := EncodeQr(AText, ABar, AError)
  else if ASym = bsPdf417 then Result := EncodePdf417(AText, ABar, AError)
  else Result := Encode1D(ASym, AText, ABar, AError);
end;

function BarcodeLayout(const ABar: TBarcode; AW, AH: Integer; AShowText: Boolean;
  ATextH: Integer): TBarLayout;
const
  Quiet2D = 2;
  Quiet1D = 10;
var
  N, X, Y, X0, Y0, Run, I, Cnt, BarH, TotW, TotH, Wc, Hc: Integer;
  Cell: Double;
  Open: array of record R: TRect; Cell0: Integer; end;

  function Px(AIndex: Integer): Integer;
  begin
    Result := Round(AIndex * Cell);
  end;

  { visina reda: AspectY modula, plus smirena zona }
  function PxY(ARow: Integer): Integer;
  begin
    Result := Round((ARow * ABar.AspectY + Quiet2D) * Cell);
  end;

  procedure Add(const R: TRect);
  begin
    SetLength(Result.Rects, Length(Result.Rects) + 1);
    Result.Rects[High(Result.Rects)] := R;
  end;

begin
  SetLength(Result.Rects, 0);
  Result.TextRect := Rect(0, 0, 0, 0);
  Result.HasText := False;
  if (AW <= 0) or (AH <= 0) then Exit;
  if ABar.Is2D then
  begin
    Wc := ABar.CellsW + 2 * Quiet2D;
    Hc := ABar.CellsH * ABar.AspectY + 2 * Quiet2D;
    Cell := Int(Min(AW / Wc, AH / Hc));
    if Cell < 1 then Cell := Min(AW / Wc, AH / Hc);
    X0 := (AW - Round(Wc * Cell)) div 2;
    Y0 := (AH - Round(Hc * Cell)) div 2;
    { vodoravni nizovi crnih modula, uspravno spojeni kad su iste sirine }
    SetLength(Open, 0);
    for Y := 0 to ABar.CellsH - 1 do
    begin
      X := 0;
      while X < ABar.CellsW do
      begin
        if not ABar.Cells[Y * ABar.CellsW + X] then begin Inc(X); Continue; end;
        Run := 0;
        while (X + Run < ABar.CellsW) and ABar.Cells[Y * ABar.CellsW + X + Run] do Inc(Run);
        Cnt := -1;
        for I := 0 to High(Open) do
          if (Open[I].R.Left = X0 + Px(X + Quiet2D)) and
             (Open[I].R.Right = X0 + Px(X + Quiet2D + Run)) and (Open[I].Cell0 = Y - 1) then
          begin Cnt := I; Break; end;
        if Cnt >= 0 then
        begin
          Open[Cnt].R.Bottom := Y0 + PxY(Y + 1);
          Open[Cnt].Cell0 := Y;
        end
        else
        begin
          SetLength(Open, Length(Open) + 1);
          Open[High(Open)].R := Rect(X0 + Px(X + Quiet2D), Y0 + PxY(Y),
            X0 + Px(X + Quiet2D + Run), Y0 + PxY(Y + 1));
          Open[High(Open)].Cell0 := Y;
        end;
        Inc(X, Run);
      end;
    end;
    for I := 0 to High(Open) do Add(Open[I].R);
    Exit;
  end;
  { 1D }
  N := ABar.Total + 2 * Quiet1D;
  Cell := Int(AW / N);
  if Cell < 1 then Cell := AW / N;
  TotW := Round(N * Cell);
  X0 := (AW - TotW) div 2;
  TotH := AH;
  if AShowText and (ATextH > 0) and (AH > ATextH * 2) then
  begin
    Result.HasText := True;
    Result.TextRect := Rect(0, AH - ATextH, AW, AH);
    TotH := AH - ATextH;
  end;
  BarH := TotH;
  X := Quiet1D;
  for I := 0 to High(ABar.Bars) do
  begin
    if ABar.Bars[I].Black then
      Add(Rect(X0 + Px(X), 0, X0 + Px(X + ABar.Bars[I].W), BarH));
    Inc(X, ABar.Bars[I].W);
  end;
end;

end.
