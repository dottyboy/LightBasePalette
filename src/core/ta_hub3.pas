unit ta_hub3;
{ HUB3 (HRVHUB30): sadrzaj 2D barkoda uplatnice koji citaju hrvatske mobilne
  aplikacije banaka. Polja se odvajaju znakom LF, bez dijakritika, uz
  ogranicenja duljine. Tekst se kodira u PDF417 (BarType = pdf417). }

{$mode objfpc}{$H+}

interface

function StripDiacritics(const S: string): string;
function Hub3Payload(AAmount: Double; const APayerName, APayerAddress, APayerCity,
  AReceiverName, AReceiverAddress, AReceiverCity, AIban, AModel, AReference, APurpose,
  ADescription: string; const ACurrency: string = 'EUR'): string;

implementation

uses
  SysUtils;

function StripDiacritics(const S: string): string;
const
  Map: array[0..19, 0..1] of string = (
    ('č', 'c'), ('ć', 'c'), ('š', 's'), ('ž', 'z'), ('đ', 'dj'),
    ('Č', 'C'), ('Ć', 'C'), ('Š', 'S'), ('Ž', 'Z'), ('Đ', 'Dj'),
    ('á', 'a'), ('é', 'e'), ('í', 'i'), ('ó', 'o'), ('ú', 'u'),
    ('ä', 'a'), ('ö', 'o'), ('ü', 'u'), ('ß', 'ss'), ('€', 'EUR'));
var
  I: Integer;
begin
  Result := S;
  for I := 0 to High(Map) do
    Result := StringReplace(Result, Map[I, 0], Map[I, 1], [rfReplaceAll]);
end;

function Clean(const S: string; AMax: Integer): string;
var
  I: Integer;
begin
  Result := StripDiacritics(Trim(S));
  for I := 1 to Length(Result) do
    if (Result[I] < ' ') or (Result[I] > '~') then Result[I] := ' ';
  Result := Trim(Result);
  if Length(Result) > AMax then Result := Trim(Copy(Result, 1, AMax));
end;

function Hub3Payload(AAmount: Double; const APayerName, APayerAddress, APayerCity,
  AReceiverName, AReceiverAddress, AReceiverCity, AIban, AModel, AReference, APurpose,
  ADescription: string; const ACurrency: string): string;
var
  Cents: Int64;
  Iban, Cur: string;
begin
  Cents := Round(Abs(AAmount) * 100);
  Iban := StringReplace(UpperCase(Clean(AIban, 40)), ' ', '', [rfReplaceAll]);
  if Length(Iban) > 21 then Iban := Copy(Iban, 1, 21);
  Cur := UpperCase(Clean(ACurrency, 3));
  if Cur = '' then Cur := 'EUR';
  Result := 'HRVHUB30' + #10 +
    Cur + #10 +
    Format('%.15d', [Cents]) + #10 +
    Clean(APayerName, 30) + #10 +
    Clean(APayerAddress, 27) + #10 +
    Clean(APayerCity, 27) + #10 +
    Clean(AReceiverName, 25) + #10 +
    Clean(AReceiverAddress, 25) + #10 +
    Clean(AReceiverCity, 27) + #10 +
    Iban + #10 +
    Clean(AModel, 4) + #10 +
    Clean(AReference, 22) + #10 +
    Clean(APurpose, 4) + #10 +
    Clean(ADescription, 35);
end;

end.
