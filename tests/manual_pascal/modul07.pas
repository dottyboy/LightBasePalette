procedure DodajKategoriju;
var
  naziv: string;
begin
  naziv := InputBox('Nova kategorija', 'Naziv:', '');
  if naziv = '' then
    Exit;
  if SqlValue('SELECT COUNT(*) FROM kategorija WHERE naziv = ''' + naziv + '''') <> '0' then
  begin
    ShowMessage('Kategorija već postoji.');
    Exit;
  end;
  SqlExec('INSERT INTO kategorija (naziv, vrsta) VALUES (''' + naziv + ''', ''Rashod'')');
  ShowMessage('Dodano: ' + naziv);
end;
