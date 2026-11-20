unit ta_mask;
{ Maska unosa (rjecnik podataka: kljuc "mask"). Znakovi maske: 9 = znamenka, A = slovo, X = slovo ili znamenka, svi ostali
  su fiksni znakovi koji se ubacuju sami (npr. "HR99 9999 9999 9999 9999 9" ili "99/99/9999"). Sve ostalo sto se upise i ne
  odgovara se odbacuje. Cista logika (bez sucelja). }
{$mode objfpc}{$H+}

interface

{ je li znak u maski vrsta (9, A, X) }
function MaskIsClass(C: Char): Boolean;
{ oblikuje upisano prema maski: odbaci nedopustene znakove i ubaci fiksne }
function ApplyMask(const AMask, ARaw: string): string;
{ je li tekst potpuno popunjen prema maski }
function MaskComplete(const AMask, AText: string): Boolean;

implementation

function MaskIsClass(C: Char): Boolean;
begin
  Result := C in ['9', 'A', 'X'];
end;

function Matches(AClass, C: Char): Boolean;
begin
  case AClass of
    '9': Result := C in ['0'..'9'];
    'A': Result := C in ['A'..'Z', 'a'..'z'];
  else
    Result := C in ['0'..'9', 'A'..'Z', 'a'..'z'];
  end;
end;

function ApplyMask(const AMask, ARaw: string): string;
var
  K, I: Integer;
  M: Char;
begin
  Result := '';
  if AMask = '' then Exit(ARaw);
  I := 1;
  for K := 1 to Length(AMask) do
  begin
    M := AMask[K];
    if MaskIsClass(M) then
    begin
      while (I <= Length(ARaw)) and not Matches(M, ARaw[I]) do Inc(I);
      if I > Length(ARaw) then Break;
      Result := Result + ARaw[I];
      Inc(I);
    end
    else
    begin
      { fiksni znak se dodaje samo kad ima jos unosa iza njega }
      if I > Length(ARaw) then Break;
      Result := Result + M;
      if ARaw[I] = M then Inc(I);
    end;
  end;
end;

function MaskComplete(const AMask, AText: string): Boolean;
begin
  if AMask = '' then Exit(True);
  Result := (Length(AText) = Length(AMask)) and (ApplyMask(AMask, AText) = AText);
end;

end.
