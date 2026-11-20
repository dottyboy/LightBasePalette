function Dob(rodjen, na: string): Double;
begin
  { datumi su tekst oblika GGGG-MM-DD; godine razlike, bez dana u godini }
  Result := StrToNum(Copy(na, 1, 4)) - StrToNum(Copy(rodjen, 1, 4));
end;
// test: Dob("1980-05-17", "2026-11-05") => 46
