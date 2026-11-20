// test: Faktorijel(5) => 120
// test: ZbrojDo(10) => 55
// test: Fibonacci(10) => 55
function Faktorijel(n: Integer): Integer;
var
  i: Integer;
begin
  Result := 1;
  for i := 2 to n do
    Result := Result * i;
end;

function ZbrojDo(n: Integer): Integer;
var
  i: Integer;
begin
  i := 1;
  Result := 0;
  while i <= n do
  begin
    Result := Result + i;
    i := i + 1;
  end;
end;

function Fibonacci(n: Integer): Integer;
var
  a, b, t, i: Integer;
begin
  a := 0;
  b := 1;
  for i := 1 to n do
  begin
    t := a + b;
    a := b;
    b := t;
  end;
  Result := a;
end;
