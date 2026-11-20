unit ta_pdf417;
{ PDF417 (ISO/IEC 15438): kompakcija teksta, brojeva i bajtova, Reed-Solomon,
  retci s indikatorima. Redoslijed kodnih rijeci provjeren naspram biblioteke
  pdf417gen (MIT). Koristi se za HUB3 barkod uplatnica. }

{$mode objfpc}{$H+}

interface

type
  TPdfWords = array of Integer;
  TPdfRows = array of string;     { svaki redak je niz '0'/'1' modula }

{ Visoke kodne rijeci: opis duljine + podaci + popuna + ispravak pogresaka. }
function Pdf417CodeWords(const AData: RawByteString; AColumns, ASecurity: Integer;
  out AWords: TPdfWords; out ARows: Integer; out AError: string): Boolean;
{ Moduli po retcima (bez smirenih zona). }
function Pdf417Encode(const AData: RawByteString; AColumns, ASecurity: Integer;
  out ARows: TPdfRows; out AError: string): Boolean;
{ Bira broj stupaca tako da je omjer sirine i visine blizu ATargetRatio (visina reda = 3 modula). }
function Pdf417Auto(const AData: RawByteString; ASecurity: Integer; ATargetRatio: Double;
  out ARows: TPdfRows; out AError: string): Boolean;

implementation

uses
  SysUtils, ta_pdf417data;

const
  StartChar = $1FEA8;
  StopChar = $3FA29;
  PadWord = 900;
  MaxWords = 928;
  MinRows = 3;
  MaxRows = 90;

type
  TMode = (mText, mByte, mNum);
  TChunk = record
    Mode: TMode;
    First, Count: Integer;     { raspon u ulaznim bajtovima }
  end;

procedure Push(var A: TPdfWords; V: Integer);
begin
  SetLength(A, Length(A) + 1);
  A[High(A)] := V;
end;

function ClassOf(B: Byte): TMode;
var
  K: Integer;
begin
  if (B >= 48) and (B <= 57) then Exit(mNum);
  if B < 128 then
    for K := 0 to 3 do
      if PdfTextChars[B, K] >= 0 then Exit(mText);
  Result := mByte;
end;

procedure CompactText(const D: RawByteString; First, Count: Integer; var Out_: TPdfWords);
var
  Sub, Want, K, I: Integer;
  B: Byte;
  Interim: TPdfWords;
  Pref: array[0..3] of Integer;
begin
  { prednost podnacina: LOWER, UPPER, MIXED, PUNCT }
  Pref[0] := 1; Pref[1] := 0; Pref[2] := 2; Pref[3] := 3;
  SetLength(Interim, 0);
  Sub := 0;   { UPPER }
  for I := First to First + Count - 1 do
  begin
    B := Byte(D[I]);
    if PdfTextChars[B, Sub] < 0 then
    begin
      Want := -1;
      for K := 0 to 3 do
        if PdfTextChars[B, Pref[K]] >= 0 then begin Want := Pref[K]; Break; end;
      for K := 0 to 1 do
        if PdfSwitch[Sub, Want, K] >= 0 then Push(Interim, PdfSwitch[Sub, Want, K]);
      Sub := Want;
    end;
    Push(Interim, PdfTextChars[B, Sub]);
  end;
  I := 0;
  while I < Length(Interim) do
  begin
    if I + 1 < Length(Interim) then Push(Out_, 30 * Interim[I] + Interim[I + 1])
    else Push(Out_, 30 * Interim[I] + 29);
    Inc(I, 2);
  end;
end;

procedure CompactBytes(const D: RawByteString; First, Count: Integer; var Out_: TPdfWords);
var
  P, K: Integer;
  V: QWord;
  W: array[0..4] of Integer;
begin
  P := First;
  while P + 5 <= First + Count - 1 do
  begin
    V := 0;
    for K := 0 to 5 do V := V * 256 + Byte(D[P + K]);
    for K := 4 downto 0 do
    begin
      W[K] := Integer(V mod 900);
      V := V div 900;
    end;
    for K := 0 to 4 do Push(Out_, W[K]);
    Inc(P, 6);
  end;
  while P <= First + Count - 1 do
  begin
    Push(Out_, Byte(D[P]));
    Inc(P);
  end;
end;

procedure CompactNumbers(const D: RawByteString; First, Count: Integer; var Out_: TPdfWords);
var
  Pos_, N, K, I, Rem, Cur: Integer;
  Dig: array[0..45] of Integer;
  Res: TPdfWords;
  Nonzero: Boolean;
  Q: array[0..45] of Integer;
  Len: Integer;
begin
  Pos_ := First;
  while Pos_ <= First + Count - 1 do
  begin
    N := First + Count - Pos_;
    if N > 44 then N := 44;
    { vrijednost = "1" + znamenke, u bazi 10 -> baza 900 }
    Len := N + 1;
    Dig[0] := 1;
    for K := 1 to N do Dig[K] := Byte(D[Pos_ + K - 1]) - 48;
    SetLength(Res, 0);
    repeat
      Rem := 0;
      Nonzero := False;
      for I := 0 to Len - 1 do
      begin
        Cur := Rem * 10 + Dig[I];
        Q[I] := Cur div 900;
        Rem := Cur mod 900;
        if Q[I] <> 0 then Nonzero := True;
      end;
      Push(Res, Rem);
      for I := 0 to Len - 1 do Dig[I] := Q[I];
    until not Nonzero;
    for I := High(Res) downto 0 do Push(Out_, Res[I]);
    Inc(Pos_, N);
  end;
end;

function Compact(const D: RawByteString): TPdfWords;
var
  Chunks: array of TChunk;
  Merged: array of TChunk;
  N, I, M: Integer;
  Cls: TMode;
  ShortNum, Borders: Boolean;
begin
  SetLength(Result, 0);
  if Length(D) = 0 then Exit;
  { 1. podjela na grupe istog razreda }
  N := 0;
  SetLength(Chunks, Length(D));
  for I := 1 to Length(D) do
  begin
    Cls := ClassOf(Byte(D[I]));
    if (N > 0) and (Chunks[N - 1].Mode = Cls) then Inc(Chunks[N - 1].Count)
    else
    begin
      Chunks[N].Mode := Cls; Chunks[N].First := I; Chunks[N].Count := 1;
      Inc(N);
    end;
  end;
  SetLength(Chunks, N);
  { 2. kratki brojevi uz tekst postaju tekst }
  for I := 0 to N - 1 do
    if Chunks[I].Mode = mNum then
    begin
      ShortNum := Chunks[I].Count < 13;
      Borders := ((I > 0) and (Chunks[I - 1].Mode = mText)) or ((I < N - 1) and (Chunks[I + 1].Mode = mText));
      if ShortNum and Borders then Chunks[I].Mode := mText;
    end;
  { 3. spajanje susjednih istog razreda }
  M := 0;
  SetLength(Merged, N);
  for I := 0 to N - 1 do
    if (M > 0) and (Merged[M - 1].Mode = Chunks[I].Mode) then Inc(Merged[M - 1].Count, Chunks[I].Count)
    else begin Merged[M] := Chunks[I]; Inc(M); end;
  { 4. kodiranje }
  for I := 0 to M - 1 do
  begin
    if (I > 0) or (Merged[I].Mode <> mText) then
      case Merged[I].Mode of
        mText: Push(Result, 900);
        mByte: if Merged[I].Count mod 6 = 0 then Push(Result, 924) else Push(Result, 901);
        mNum: Push(Result, 902);
      end;
    case Merged[I].Mode of
      mText: CompactText(D, Merged[I].First, Merged[I].Count, Result);
      mByte: CompactBytes(D, Merged[I].First, Merged[I].Count, Result);
      mNum: CompactNumbers(D, Merged[I].First, Merged[I].Count, Result);
    end;
  end;
end;

function ErrorWords(const AData: TPdfWords; ALevel: Integer): TPdfWords;
var
  Cnt, I, X, Off, Temp, W: Integer;
  Ec: array of Integer;
begin
  Cnt := 1 shl (ALevel + 1);
  Off := PdfEcOffsets[ALevel];
  SetLength(Ec, Cnt);
  for I := 0 to Cnt - 1 do Ec[I] := 0;
  for I := 0 to High(AData) do
  begin
    Temp := (AData[I] + Ec[Cnt - 1]) mod 929;
    for X := Cnt - 1 downto 0 do
    begin
      if X > 0 then W := Ec[X - 1] else W := 0;
      Ec[X] := (W + 929 - (Temp * PdfEcFactors[Off + X]) mod 929) mod 929;
    end;
  end;
  SetLength(Result, Cnt);
  for I := 0 to Cnt - 1 do
  begin
    X := Ec[Cnt - 1 - I];
    if X > 0 then Result[I] := 929 - X else Result[I] := 0;
  end;
end;

function Pdf417CodeWords(const AData: RawByteString; AColumns, ASecurity: Integer;
  out AWords: TPdfWords; out ARows: Integer; out AError: string): Boolean;
var
  Data, Ec, All: TPdfWords;
  EcCount, Total, Pad, I, Desc: Integer;
begin
  Result := False;
  SetLength(AWords, 0);
  ARows := 0;
  AError := '';
  if (AColumns < 1) or (AColumns > 30) then begin AError := 'PDF417: broj stupaca mora biti 1 do 30.'; Exit; end;
  if (ASecurity < 0) or (ASecurity > 8) then begin AError := 'PDF417: razina sigurnosti mora biti 0 do 8.'; Exit; end;
  if Length(AData) = 0 then begin AError := 'PDF417: nema podataka.'; Exit; end;
  Data := Compact(AData);
  EcCount := 1 shl (ASecurity + 1);
  Total := Length(Data) + EcCount + 1;
  Pad := 0;
  if Total mod AColumns > 0 then Pad := AColumns - Total mod AColumns;
  Desc := Length(Data) + Pad + 1;
  ARows := (Length(Data) + EcCount + Pad + 1 + AColumns - 1) div AColumns;
  if Desc > MaxWords then begin AError := 'PDF417: previše podataka (' + IntToStr(Desc) + ' kodnih riječi, najviše ' + IntToStr(MaxWords) + ').'; Exit; end;
  if ARows < MinRows then begin AError := 'PDF417: premalo redaka, smanji broj stupaca.'; Exit; end;
  if ARows > MaxRows then begin AError := 'PDF417: previše redaka, povećaj broj stupaca.'; Exit; end;
  SetLength(All, 0);
  Push(All, Desc);
  for I := 0 to High(Data) do Push(All, Data[I]);
  for I := 1 to Pad do Push(All, PadWord);
  Ec := ErrorWords(All, ASecurity);
  for I := 0 to High(Ec) do Push(All, Ec[I]);
  AWords := All;
  Result := True;
end;

function BitsOf(AValue: LongWord): string;
var
  Top, I: Integer;
begin
  Top := 31;
  while (Top > 0) and (AValue and (LongWord(1) shl Top) = 0) do Dec(Top);
  SetLength(Result, Top + 1);
  for I := 0 to Top do
    if AValue and (LongWord(1) shl (Top - I)) <> 0 then Result[I + 1] := '1' else Result[I + 1] := '0';
end;

function RowIndicator(ARow, ARows, ACols, ASec: Integer; ALeft: Boolean): Integer;
var
  X: Integer;
begin
  case ARow mod 3 of
    0: if ALeft then X := (ARows - 1) div 3 else X := ACols - 1;
    1: if ALeft then X := ASec * 3 + (ARows - 1) mod 3 else X := (ARows - 1) div 3;
  else
    if ALeft then X := ACols - 1 else X := ASec * 3 + (ARows - 1) mod 3;
  end;
  Result := 30 * (ARow div 3) + X;
end;

function Pdf417Encode(const AData: RawByteString; AColumns, ASecurity: Integer;
  out ARows: TPdfRows; out AError: string): Boolean;
var
  Words: TPdfWords;
  Rows, R, C, Cl: Integer;
  Line: string;
begin
  SetLength(ARows, 0);
  Result := Pdf417CodeWords(AData, AColumns, ASecurity, Words, Rows, AError);
  if not Result then Exit;
  SetLength(ARows, Rows);
  for R := 0 to Rows - 1 do
  begin
    Cl := R mod 3;
    Line := BitsOf(StartChar);
    Line := Line + BitsOf(PdfClusters[Cl][RowIndicator(R, Rows, AColumns, ASecurity, True)]);
    for C := 0 to AColumns - 1 do
      Line := Line + BitsOf(PdfClusters[Cl][Words[R * AColumns + C]]);
    Line := Line + BitsOf(PdfClusters[Cl][RowIndicator(R, Rows, AColumns, ASecurity, False)]);
    Line := Line + BitsOf(StopChar);
    ARows[R] := Line;
  end;
end;

function Pdf417Auto(const AData: RawByteString; ASecurity: Integer; ATargetRatio: Double;
  out ARows: TPdfRows; out AError: string): Boolean;
var
  Cols, BestCols, Rows: Integer;
  Words: TPdfWords;
  Err: string;
  Ratio, Best: Double;
begin
  Result := False;
  BestCols := 0;
  Best := 1E9;
  for Cols := 1 to 30 do
  begin
    if not Pdf417CodeWords(AData, Cols, ASecurity, Words, Rows, Err) then Continue;
    Ratio := ((Cols + 3) * 17 + 1) / (Rows * 3);
    if Abs(Ratio - ATargetRatio) < Best then begin Best := Abs(Ratio - ATargetRatio); BestCols := Cols; end;
  end;
  if BestCols = 0 then
  begin
    Pdf417CodeWords(AData, 30, ASecurity, Words, Rows, AError);
    if AError = '' then AError := 'PDF417: podaci se ne mogu smjestiti.';
    Exit;
  end;
  Result := Pdf417Encode(AData, BestCols, ASecurity, ARows, AError);
end;

end.
