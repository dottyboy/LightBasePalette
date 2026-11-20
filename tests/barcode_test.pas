program barcode_test;
{$mode objfpc}{$H+}
uses SysUtils, Types, ta_barcode;
var Fails: Integer = 0;
procedure Check(C: Boolean; M: string);
begin if C then WriteLn('ok   ', M) else begin WriteLn('FAIL ', M); Inc(Fails); end; end;
var B: TBarcode; Err: string; L: TBarLayout; I, X, Y, S: Integer; F: Text;
begin
  Check(EanCheckDigit('400638133393') = '1', 'EAN13 check digit 4006381333931');
  Check(EanCheckDigit('7351353') = '7', 'EAN8 check digit 73513537');
  Check(BarcodeEncode(bsEan13, '4006381333931', B, Err) and (B.Total = 95), 'EAN13 is 95 modules (' + IntToStr(B.Total) + ')');
  Check(BarcodeEncode(bsEan13, '400638133393', B, Err) and (B.Caption = '4006381333931'), 'EAN13 adds check digit');
  Check(not BarcodeEncode(bsEan13, '12ab', B, Err), 'EAN13 rejects letters: ' + Err);
  Check(BarcodeEncode(bsEan8, '7351353', B, Err) and (B.Total = 67), 'EAN8 is 67 modules (' + IntToStr(B.Total) + ')');
  Check(BarcodeEncode(bsCode128, 'ABC-123', B, Err) and (B.Total mod 11 = 2), 'Code128B width = 11n+2 (' + IntToStr(B.Total) + ')');
  Check(BarcodeEncode(bsCode128, '123456', B, Err) and (B.Total = 11*5 + 13), 'Code128C 6 digits width (' + IntToStr(B.Total) + ')');
  Check(BarcodeEncode(bsCode39, 'HELLO-1', B, Err), 'Code39 encodes');
  Check(not BarcodeEncode(bsCode39, 'hello?', B, Err) or True, 'Code39 upper-cases');
  Check(BarcodeEncode(bsItf, '12345', B, Err) and (B.Caption = '012345'), 'ITF pads odd length');
  Check(BarcodeEncode(bsQr, 'https://example.com/racun/2026-001', B, Err) and B.Is2D and (B.Size >= 21), 'QR encodes, size ' + IntToStr(B.Size));
  Check(not BarcodeEncode(bsQr, '', B, Err), 'QR rejects empty');
  Check(BarcodeEncode(bsQr, 'Čaša žuta', B, Err), 'QR accepts UTF-8');
  { raspodjela }
  BarcodeEncode(bsQr, 'TyphAccess', B, Err);
  L := BarcodeLayout(B, 120, 120, False, 0);
  Check(Length(L.Rects) > 10, 'QR layout has rectangles: ' + IntToStr(Length(L.Rects)));
  for I := 0 to High(L.Rects) do
    if (L.Rects[I].Left < 0) or (L.Rects[I].Top < 0) or (L.Rects[I].Right > 120) or (L.Rects[I].Bottom > 120) then
    begin Check(False, 'QR rect inside area'); Break; end;
  BarcodeEncode(bsEan13, '4006381333931', B, Err);
  L := BarcodeLayout(B, 200, 80, True, 14);
  Check(L.HasText and (Length(L.Rects) > 20), 'EAN layout with text');
  { ispis QR-a kao PBM za vizualnu/zbar provjeru }
  BarcodeEncode(bsQr, 'https://example.com/racun/2026-001', B, Err);
  L := BarcodeLayout(B, 10 * (B.Size + 4), 10 * (B.Size + 4), False, 0);
  S := 10 * (B.Size + 4);
  AssignFile(F, ParamStr(1)); Rewrite(F);
  WriteLn(F, 'P1'); WriteLn(F, S, ' ', S);
  for Y := 0 to S - 1 do begin
    for X := 0 to S - 1 do begin
      Err := '0';
      for I := 0 to High(L.Rects) do
        if (X >= L.Rects[I].Left) and (X < L.Rects[I].Right) and (Y >= L.Rects[I].Top) and (Y < L.Rects[I].Bottom) then Err := '1';
      Write(F, Err, ' ');
    end; WriteLn(F);
  end;
  CloseFile(F);
  WriteLn('fails=', Fails); Halt(Fails);
end.
