// test: Saldo() => 1364,5
// test: Potroseno("Hrana") => 105,5
// test: BrojTransakcija() => 4
function Saldo: Double;
begin
  Result := DSum('iznos', 'transakcija', '');
end;

function Potroseno(kategorija: string): Double;
begin
  Result := -DSum('iznos', 'transakcija',
    'kategorija_id = (SELECT id FROM kategorija WHERE naziv = ''' + kategorija + ''')');
end;

function BrojTransakcija: Integer;
begin
  Result := DCount('transakcija', '');
end;
