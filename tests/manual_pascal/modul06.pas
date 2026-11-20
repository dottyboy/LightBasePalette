// test: NajveciTrosak() => -60
function NajveciTrosak: string;
begin
  Result := SqlValue('SELECT MIN(iznos) FROM transakcija');
end;
