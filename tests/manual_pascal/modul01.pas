// test: Dvaput(21) => 42
// test: Pozdrav("Ana") => Bok, Ana!
function Dvaput(x: Double): Double;
begin
  Result := x * 2;
end;

function Pozdrav(ime: string): string;
begin
  Result := 'Bok, ' + ime + '!';
end;
