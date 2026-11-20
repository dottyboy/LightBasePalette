function PrvoVeliko(s: string): string;
begin
  s := Trim(s);
  Result := UpperCase(Copy(s, 1, 1)) + Copy(s, 2, Length(s));
end;
// test: PrvoVeliko("  hrana i piće ") => Hrana i piće
// test: PrvoVeliko("iPhone") => IPhone
