function PromijenjenaPolja(maska: Integer): string;
var
  bit, i: Integer;
  imena: string;
begin
  imena := 'ClientName,AccountBalance,AccountCurrent';
  Result := '';
  bit := 1;
  for i := 1 to 3 do
  begin
    if (maska and bit) <> 0 then
    begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + Trim(Copy(imena, 1, Pos(',', imena + ',') - 1));
    end;
    Delete(imena, 1, Pos(',', imena + ','));
    bit := bit * 2;
  end;
end;
// test: PromijenjenaPolja(5) => ClientName, AccountCurrent
// test: PromijenjenaPolja(2) => AccountBalance
// test: PromijenjenaPolja(0) => 
