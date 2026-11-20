// Poslovne funkcije trgovine: pozivaju se iz izraza (=RazredKupca([ukupno])), 4GL-a (pas.OibIspravan(oib)) i makroa (run:ZabiljeziDnevnik).
// test: Marza(1.60, 2.00) => 20
// test: RabatPoKolicini(3) => 0
// test: RabatPoKolicini(120) => 5
// test: RazredKupca(25000) => Zlatni
// test: RazredKupca(9000) => Srebrni
// test: RazredKupca(100) => Redovni
// test: Kamata(1000, 73) => 24
// test: Zaokruzi5(1.23) => 1.25
// test: OibIspravan("69435151530") => True
// test: OibIspravan("69435151531") => False
// test: SifraArtikla("Kava mljevena", 7) => KAV-007

function Marza(nabavna, prodajna: Double): Double;
begin
  if prodajna = 0 then
    Result := 0
  else
    Result := Round((prodajna - nabavna) / prodajna * 10000) / 100.0;
end;

function RabatPoKolicini(kol: Double): Double;
begin
  if kol >= 100 then
    Result := 5
  else if kol >= 50 then
    Result := 3
  else if kol >= 20 then
    Result := 1.5
  else
    Result := 0;
end;

function RazredKupca(ukupno: Double): string;
begin
  if ukupno >= 20000 then
    Result := 'Zlatni'
  else if ukupno >= 8000 then
    Result := 'Srebrni'
  else if ukupno >= 2000 then
    Result := 'Brončani'
  else
    Result := 'Redovni';
end;

function Kamata(osnovica: Double; dani: Integer): Double;
begin
  // zatezna kamata 12 % godišnje, jednostavna
  Result := Round(osnovica * 0.12 * dani / 365 * 100) / 100.0;
end;

function Zaokruzi5(x: Double): Double;
begin
  Result := Round(x * 20 + 0.0001) / 20.0;
end;

function OibIspravan(oib: string): Boolean;
var
  i, a, d: Integer;
begin
  Result := False;
  if Length(oib) <> 11 then Exit;
  a := 10;
  for i := 1 to 10 do
  begin
    d := Ord(oib[i]) - 48;
    if (d < 0) or (d > 9) then Exit;
    a := (a + d) mod 10;
    if a = 0 then a := 10;
    a := (a * 2) mod 11;
  end;
  d := (11 - a) mod 10;
  Result := (Ord(oib[11]) - 48) = d;
end;

function SifraArtikla(naziv: string; n: Integer): string;
var
  s, t: string;
begin
  s := UpperCase(Copy(naziv, 1, 3));
  t := IntToStr(n);
  while Length(t) < 3 do
    t := '0' + t;
  Result := s + '-' + t;
end;

procedure ZabiljeziDnevnik(izvor, poruka: string);
begin
  SqlExec('INSERT INTO dnevnik (vrijeme, izvor, poruka) VALUES (datetime(''now''), ''' + izvor + ''', ''' + poruka + ''')');
end;

procedure ZabiljeziZakljucak;
begin
  ZabiljeziDnevnik('zaključak', 'Mjesečni obračun je pokrenut');
end;
