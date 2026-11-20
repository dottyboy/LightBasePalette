// pozovi iz BeforeUpdate
procedure ProvjeriTransakciju;
begin
  if GetNumber('txtIznos') = 0 then
  begin
    ShowMessage('Iznos ne može biti nula.');
    FocusControl('txtIznos');
    CancelEvent;
  end;
end;

// pozovi iz OnCurrent: pokaži upozorenje samo za velike rashode
procedure PrikaziUpozorenje;
begin
  SetVisible('lblUpozorenje', GetNumber('txtIznos') < -1000);
end;

// pozovi iz BeforeDelete: pitaj prije brisanja
procedure PitajPrijeBrisanja;
begin
  if not Confirm('Stvarno obrisati transakciju?') then
    CancelEvent;
end;
