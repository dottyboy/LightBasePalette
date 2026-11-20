function Prazno(v: string): Boolean;
begin
  Result := Trim(v) = '';
end;

procedure ProvjeriNaziv;
begin
  if Prazno(GetValue('naziv')) then
  begin
    ShowMessage('Naziv je obavezan prije nego napustiš zapis');
    FocusControl('naziv');
    CancelEvent;
  end;
end;
// test: Prazno("") => Da
// test: Prazno("  ") => Da
// test: Prazno("Hrana") => Ne
