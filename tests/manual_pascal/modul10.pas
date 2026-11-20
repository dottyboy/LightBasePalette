function PostanskiBrojOk(drzava, broj: string): Boolean;
var
  n: Integer;
begin
  n := Length(broj);
  Result := True;
  if (drzava = 'France') or (drzava = 'Italy') or (drzava = 'Spain') then
    Result := n = 5
  else if (drzava = 'Australia') or (drzava = 'Singapore') then
    Result := n = 4;
end;

procedure ProvjeriPostanskiBroj;
begin
  if not PostanskiBrojOk(GetValue('Country'), GetValue('PostalCode')) then
  begin
    ShowMessage('Poštanski broj nije ispravne duljine za tu državu');
    FocusControl('PostalCode');
    CancelEvent;
  end;
end;
// test: PostanskiBrojOk("France", "75001") => Da
// test: PostanskiBrojOk("France", "7500") => Ne
// test: PostanskiBrojOk("Australia", "2000") => Da
// test: PostanskiBrojOk("Croatia", "10000") => Da
