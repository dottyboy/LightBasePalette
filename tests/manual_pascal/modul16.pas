function RazdobljeOk(od, do_: string): Boolean;
begin
  Result := do_ >= od;
end;
// test: RazdobljeOk("2026-03-01", "2026-03-31") => Da
// test: RazdobljeOk("2026-03-31", "2026-03-01") => Ne
