// test: Zaokruzi(2.3456, 2) => 2,35
// test: Rata(1000, 12, 12) => 88,85
function Zaokruzi(x: Double; decimale: Integer): Double;
var
  f: Double;
  i: Integer;
begin
  f := 1;
  for i := 1 to decimale do
    f := f * 10;
  Result := Round(x * f) / f;
end;

// glavnica, godišnja kamata u postocima, broj mjeseci
function Rata(glavnica, kamata: Double; mjeseci: Integer): Double;
var
  r, faktor: Double;
  i: Integer;
begin
  r := kamata / 12 / 100;
  faktor := 1;
  for i := 1 to mjeseci do
    faktor := faktor * (1 + r);
  Result := Zaokruzi(glavnica * r * faktor / (faktor - 1), 2);
end;
