// gumb na formi: prebacuje između svih transakcija i samo rashoda
procedure PrebaciRashode;
begin
  if Confirm('Prikazati samo rashode? (Ne = prikaži sve)') then
    DoAction('filter:iznos < 0')
  else
    DoAction('nofilter');
end;

procedure PregledMjeseca;
begin
  DoAction('openreport:Mjesecni@"datum >= ''2026-03-01''"');
end;
