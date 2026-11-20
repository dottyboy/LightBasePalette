function NazivKategorije(id: string): string;
begin
  Result := DLookup('naziv', 'kategorija', 'id = ' + id);
end;

procedure NakonOdabiraKategorije;
begin
  SetValue('opis', NazivKategorije(GetValue('kategorija_id')));
end;
// test: NazivKategorije("1") => Hrana
// test: NazivKategorije("3") => Prijevoz
