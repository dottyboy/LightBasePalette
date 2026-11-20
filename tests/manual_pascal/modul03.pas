// test: Inicijali("Ana Marija Horvat") => AMH
// test: Obrni("Zagreb") => bergaZ
// test: BrojRijeci("jedan dva tri") => 3
function Inicijali(s: string): string;
var
  i: Integer;
  novaRijec: Boolean;
begin
  Result := '';
  novaRijec := True;
  for i := 1 to Length(s) do
  begin
    if s[i] = ' ' then
      novaRijec := True
    else
    begin
      if novaRijec then
        Result := Result + UpperCase(s[i]);
      novaRijec := False;
    end;
  end;
end;

function Obrni(s: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := Length(s) downto 1 do
    Result := Result + s[i];
end;

function BrojRijeci(s: string): Integer;
var
  i: Integer;
  uRijeci: Boolean;
begin
  Result := 0;
  uRijeci := False;
  for i := 1 to Length(s) do
  begin
    if s[i] <> ' ' then
    begin
      if not uRijeci then
        Result := Result + 1;
      uRijeci := True;
    end
    else
      uRijeci := False;
  end;
end;
