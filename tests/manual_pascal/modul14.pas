function ZadnjiOpis: string;
begin
  Result := SqlValue('SELECT opis FROM transakcija ORDER BY id DESC LIMIT 1');
end;

procedure PreuzmiOpis;
begin
  if GetValue('opis') = '' then SetValue('opis', ZadnjiOpis);
end;
// test: ZadnjiOpis() => Plac
