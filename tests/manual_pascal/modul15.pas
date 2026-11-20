function IdKategorije(naziv: string): string;
begin
  Result := SqlValue('SELECT id FROM kategorija WHERE naziv = ''' + naziv + '''');
end;

procedure KategorijaIzUnosa;
var
  naziv: string;
begin
  naziv := Copy(Trim(GetValue('kategorija_naziv')), 1, 15);
  if (naziv <> '') and (IdKategorije(naziv) = '') then
    if Confirm('Kategorije "' + naziv + '" nema. Dodati je?') then
      SqlExec('INSERT INTO kategorija (naziv, vrsta) VALUES (''' + naziv + ''', ''Rashod'')');
  SetValue('kategorija_id', IdKategorije(naziv));
end;
// test: IdKategorije("Hrana") => 1
// test: IdKategorije("Nema je") => 
