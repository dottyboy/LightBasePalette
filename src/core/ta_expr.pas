unit ta_expr;
{ Expression language used by report items, calculated controls, default
  values, validation rules and visibility conditions. Access-like:

    [field]  'text'  "text"  #2026-01-31#  12.5  True  False  Null
    + - * / \ Mod ^ &   = <> < > <= >=   And Or Xor Not
    Like  Is Null  Is Not Null  Between a And b  In (a, b, c)
    Sum Count Avg Min Max([field])       DLookup DCount DSum DAvg DMin DMax
    Iif Switch Choose Nz IsNull IsNumeric IsDate
    Len Left Right Mid Trim UCase LCase InStr Replace Space String Chr Asc Proper
    Abs Int Fix Round Sqr Exp Log Sgn Max(a,b) Min(a,b)
    CInt CLng CDbl CStr CBool CDate Val
    Date Now Time Today Year Month Day Hour Minute Second Weekday MonthName
    WeekdayName DateAdd DateDiff DatePart DateSerial TimeSerial DateValue
    Format(value, fmt)
  plus host variables (Page, Pages, control names ...). Null propagates through
  arithmetic and comparison, as in Access. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, Math, DateUtils, LazUTF8, ta_parse, ta_words, ta_hub3, ta_richtext;

type
  EExpr = class(Exception);

  TaExprHost = class
  public
    function FieldValue(const AName: string): Variant; virtual; abstract;
    function Aggregate(const AFunc, AField: string): Variant; virtual; abstract;
    function Variable(const AName: string): Variant; virtual; abstract;
    { DLookup & co.; criteria is the text of a SQL WHERE clause. }
    function Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant; virtual;
    { SubSum('podforma', 'polje') i srodni: zbroj, broj... redaka podforme (neprekidne ili mreze) }
    function SubAggregate(const AFunc, ASub, AField: string): Variant; virtual;
  end;

{ Novcano zaokruzivanje: .5 uvijek na vecu apsolutnu vrijednost (1,005 -> 1,01), bez greske
  binarnog zapisa; ADec je broj decimala. Round() je bankarski (kao u Accessu). }
function RoundHalfUp(X: Double; ADec: Integer): Double;

type
  { Script functions callable from expressions: =Dvaput([iznos]) }
  TUserFunctionHook = function(const AName: string; const AArgs: array of Variant;
    out AResult: Variant): Boolean;

var
  { set at login: CurrentUser() and CurrentRole() }
  CurrentUserName: string = '';
  CurrentUserRole: string = 'admin';
  UserFunctionHook: TUserFunctionHook = nil;
  { ZKI(brojRacuna; datumVrijeme; iznos) - set by ta_fiscalcfg }
  FiscalZkiHook: function(const ABroj: string; ADt: TDateTime; AIznos: Double): string = nil;
  { Predict, PredictXG, PredictReset: predvidanja utakmica, postavlja ta_predict }
  PredictHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { RunReliability, RunProgression: izvjesce pouzdanosti i simulacija progresija, postavlja ta_reliability }
  StatsHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { RunAnalytics: analize nad zapisanim listicima, postavlja ta_analytics }
  AnalyticsHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { DownloadFile, ImportMatches, RefreshMain: preuzimanje i uvoz utakmica, postavlja ta_datarefresh }
  DataHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { RunBacktest: standardni backtest i banka, postavlja ta_backtest }
  BacktestHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { RunCombinations, RunSession, RunMonteCarlo: parovi, sesija po Kellyju i Monte Carlo, postavlja ta_pairs }
  PairsHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { RunLeagueOverview, TeamForm, RunHeadToHead, RunSeasonProfile: tablica lige, forma, medjusobni susreti, postavlja ta_league }
  LeagueHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { ValidateSeason(datoteka [, sezona]): provjera datoteke sezone prije uvoza, postavlja ta_validation }
  ValidationHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { RunEngineBacktest: vremenska kapsula jedne lige i sezone, postavlja ta_enginebt }
  EngineBacktestHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { GenerateSlips: generiranje listica po sustavu, postavlja ta_slipgen }
  GenerateSlipsHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { Postavka("firma.naziv") - vrijednost iz postavki baze, postavlja ta_exprdb }
  SettingHook: function(const AKey: string): string = nil;
  { Fgl("Program.Funkcija"; argumenti...): vrijednost koju 4GL funkcija vraca (postavlja ta_source) }
  FglHook: function(const AName: string; const A: array of Variant; N: Integer): Variant = nil;
  { upper-case names of the functions the scripts define; lets CheckExpr accept them }
  UserFunctionNames: TStringList = nil;

function EvalExpr(const S: string; AHost: TaExprHost): Variant;           { '#Err' on error }
function EvalExprEx(const S: string; AHost: TaExprHost; out AError: string): Variant;
{ Empty when the expression is syntactically fine. }
function CheckExpr(const S: string): string;
function ExprIsTrue(const V: Variant): Boolean;
function FormatValue(const V: Variant; const AFmt: string): string;
function FormatNamed(const V: Variant; const AFmt: string): string;

implementation

var
  EvalDepthNow: Integer = 0;

type
  { evaluates with every reference empty: finds syntax errors, not data errors }
  TCheckHost = class(TaExprHost)
  public
    function FieldValue(const AName: string): Variant; override;
    function Aggregate(const AFunc, AField: string): Variant; override;
    function Variable(const AName: string): Variant; override;
  end;



function TaExprHost.Domain(const AFunc, AExpr, ADomain, ACriteria: string): Variant;
begin
  Result := Null;
end;

function TaExprHost.SubAggregate(const AFunc, ASub, AField: string): Variant;
begin
  Result := Null;
end;

{ ---------------- coercion ---------------- }

function IsNullV(const V: Variant): Boolean;
begin
  Result := VarIsNull(V) or VarIsEmpty(V);
end;

function IsDateV(const V: Variant): Boolean;
begin
  Result := VarType(V) = varDate;
end;

function IsBoolV(const V: Variant): Boolean;
begin
  Result := VarType(V) = varBoolean;
end;

function IsNumV(const V: Variant): Boolean;
begin
  Result := VarIsNumeric(V) and not IsBoolV(V);
end;

function AsStr(const V: Variant): string;
begin
  if IsNullV(V) then Exit('');
  if IsBoolV(V) then
  begin
    if Boolean(V) then Exit('Da') else Exit('Ne');
  end;
  if IsDateV(V) then Exit(FormatDateTime('dd.mm.yyyy', V));
  if VarIsFloat(V) then Exit(FloatToStr(RoundTo(Double(V), -10), ParseFS));
  Result := VarToStr(V);
end;

function AsNum(const V: Variant): Double;
var
  D: Double;
begin
  if IsNullV(V) then Exit(0);
  if IsBoolV(V) then
  begin
    if Boolean(V) then Exit(1) else Exit(0);   { kvačica: označena = 1, prazna = 0 (ne Accessovo -1) }
  end;
  if IsDateV(V) then Exit(Double(TDateTime(V)));
  if VarIsNumeric(V) then Exit(Double(V));
  if ParseNumber(VarToStr(V), D) then Exit(D);
  raise EExpr.Create('Nije broj: ' + VarToStr(V));
end;

function AsDate(const V: Variant): TDateTime;
var
  D: TDateTime;
begin
  if IsDateV(V) then Exit(TDateTime(V));
  if IsNumV(V) then Exit(Double(V));
  if ParseAnyDateTime(VarToStr(V), D) then Exit(D);
  raise EExpr.Create('Nije datum: ' + VarToStr(V));
end;

function TryDate(const V: Variant; out D: TDateTime): Boolean;
begin
  Result := True;
  if IsDateV(V) then D := TDateTime(V)
  else if IsNullV(V) or IsNumV(V) or IsBoolV(V) then Result := False
  else Result := ParseAnyDateTime(VarToStr(V), D) and (Pos('-', VarToStr(V)) + Pos('.', VarToStr(V)) + Pos('/', VarToStr(V)) + Pos(':', VarToStr(V)) > 0);
end;

function ExprIsTrue(const V: Variant): Boolean;
begin
  if IsNullV(V) then Exit(False);
  if IsBoolV(V) then Exit(Boolean(V));
  if VarIsNumeric(V) then Exit(Double(V) <> 0);
  Result := SameText(VarToStr(V), 'true') or SameText(VarToStr(V), 'da') or (VarToStr(V) = '1');
end;

{ -1 / 0 / 1; both operands non-null. }
function CompareV(const A, B: Variant): Integer;
var
  Da, Db: TDateTime;
  X, Y: Double;
  Sa, Sb: string;
begin
  if (IsDateV(A) or IsDateV(B)) and TryDate(A, Da) and TryDate(B, Db) then
  begin
    X := Da; Y := Db;
    if X < Y then Exit(-1) else if X > Y then Exit(1) else Exit(0);
  end;
  if (IsNumV(A) or IsBoolV(A)) and (IsNumV(B) or IsBoolV(B)) then
  begin
    X := AsNum(A); Y := AsNum(B);
    if X < Y then Exit(-1) else if X > Y then Exit(1) else Exit(0);
  end;
  { a number against numeric text compares as numbers }
  if (IsNumV(A) or IsNumV(B)) and ParseNumber(VarToStr(A), X) and ParseNumber(VarToStr(B), Y) then
  begin
    if X < Y then Exit(-1) else if X > Y then Exit(1) else Exit(0);
  end;
  Sa := AsStr(A); Sb := AsStr(B);
  Result := CompareText(Sa, Sb);
  if Result < 0 then Result := -1 else if Result > 0 then Result := 1;
end;

function LikeMatch(const S, P: string; SI, PI: Integer): Boolean;
begin
  while PI <= Length(P) do
  begin
    case P[PI] of
      '*':
        begin
          if PI = Length(P) then Exit(True);
          while SI <= Length(S) + 1 do
          begin
            if LikeMatch(S, P, SI, PI + 1) then Exit(True);
            Inc(SI);
          end;
          Exit(False);
        end;
      '?': if SI > Length(S) then Exit(False);
      '#': if (SI > Length(S)) or not (S[SI] in ['0'..'9']) then Exit(False);
    else
      if (SI > Length(S)) or (UpCase(S[SI]) <> UpCase(P[PI])) then Exit(False);
    end;
    Inc(SI);
    Inc(PI);
  end;
  Result := SI > Length(S);
end;


{ ---------------- Croatian / business helpers ---------------- }

{ OIB: ISO 7064, MOD 11,10 }
function OibValid(const S: string): Boolean;
var
  I, A, D: Integer;
begin
  Result := False;
  if (Length(S) <> 11) then Exit;
  for I := 1 to 11 do
    if not (S[I] in ['0'..'9']) then Exit;
  A := 10;
  for I := 1 to 10 do
  begin
    A := (A + Ord(S[I]) - 48) mod 10;
    if A = 0 then A := 10;
    A := (A * 2) mod 11;
  end;
  D := 11 - A;
  if D = 10 then D := 0;
  Result := D = Ord(S[11]) - 48;
end;

function IbanValid(const AIban: string): Boolean;
var
  S, Moved: string;
  I, Rem, V: Integer;
  C: Char;
begin
  Result := False;
  S := '';
  for I := 1 to Length(AIban) do
    if AIban[I] <> ' ' then S := S + UpCase(AIban[I]);
  if (Length(S) < 15) or (Length(S) > 34) then Exit;
  Moved := Copy(S, 5, MaxInt) + Copy(S, 1, 4);
  Rem := 0;
  for I := 1 to Length(Moved) do
  begin
    C := Moved[I];
    if C in ['0'..'9'] then V := Ord(C) - 48
    else if C in ['A'..'Z'] then V := Ord(C) - 55
    else Exit;
    if V >= 10 then Rem := (Rem * 100 + V) mod 97 else Rem := (Rem * 10 + V) mod 97;
  end;
  Result := Rem = 1;
end;

function WorkDaysBetween(A, B: TDateTime): Integer;
var
  D, Last: TDateTime;
begin
  Result := 0;
  D := Int(A);
  Last := Int(B);
  if D > Last then begin D := Int(B); Last := Int(A); end;
  while D <= Last do
  begin
    if DayOfWeek(D) in [2..6] then Inc(Result);
    D := D + 1;
  end;
end;

{ Uskrs (gregorijanski): "anonymous" algoritam }
function EasterSunday(AYear: Integer): TDateTime;
var
  A, B, C, D, E, F, G, H, I, K, L, M, Mo, Dy: Integer;
begin
  A := AYear mod 19;
  B := AYear div 100;
  C := AYear mod 100;
  D := B div 4;
  E := B mod 4;
  F := (B + 8) div 25;
  G := (B - F + 1) div 3;
  H := (19 * A + B - D - G + 15) mod 30;
  I := C div 4;
  K := C mod 4;
  L := (32 + 2 * E + 2 * I - H - K) mod 7;
  M := (A + 11 * H + 22 * L) div 451;
  Mo := (H + L - 7 * M + 114) div 31;
  Dy := ((H + L - 7 * M + 114) mod 31) + 1;
  Result := EncodeDate(AYear, Mo, Dy);
end;

{ naziv hrvatskog blagdana ili praznog teksta }
function HrHoliday(ADate: TDateTime): string;
var
  Y, M, D: Word;
  E, Dt: TDateTime;
begin
  Result := '';
  Dt := Int(ADate);
  DecodeDate(Dt, Y, M, D);
  E := EasterSunday(Y);
  if (M = 1) and (D = 1) then Exit('Nova godina');
  if (M = 1) and (D = 6) then Exit('Sveta tri kralja');
  if Dt = E then Exit('Uskrs');
  if Dt = E + 1 then Exit('Uskrsni ponedjeljak');
  if (M = 5) and (D = 1) then Exit('Praznik rada');
  if Dt = E + 60 then Exit('Tijelovo');
  if (M = 5) and (D = 30) then Exit('Dan državnosti');
  if (M = 6) and (D = 22) then Exit('Dan antifašističke borbe');
  if (M = 8) and (D = 5) then Exit('Dan pobjede i domovinske zahvalnosti');
  if (M = 8) and (D = 15) then Exit('Velika Gospa');
  if (M = 11) and (D = 1) then Exit('Svi sveti');
  if (M = 11) and (D = 18) then Exit('Dan sjećanja na žrtve Domovinskog rata');
  if (M = 12) and (D = 25) then Exit('Božić');
  if (M = 12) and (D = 26) then Exit('Sveti Stjepan');
end;

function WorkDaysNoHolidays(A, B: TDateTime): Integer;
var
  D, Last: TDateTime;
begin
  Result := 0;
  D := Int(A);
  Last := Int(B);
  if D > Last then begin D := Int(B); Last := Int(A); end;
  while D <= Last do
  begin
    if (DayOfWeek(D) in [2..6]) and (HrHoliday(D) = '') then Inc(Result);
    D := D + 1;
  end;
end;

function SplitPart(const S, Sep: string; N: Integer): string;
var
  L: TStringList;
begin
  Result := '';
  if (Sep = '') or (N < 1) then Exit;
  L := TStringList.Create;
  try
    L.StrictDelimiter := True;
    L.Delimiter := Sep[1];
    L.DelimitedText := S;
    if N <= L.Count then Result := L[N - 1];
  finally
    L.Free;
  end;
end;

{ ---------------- formatting ---------------- }

function FormatNamed(const V: Variant; const AFmt: string): string;
var
  L: string;
begin
  L := LowerCase(AFmt);
  if L = 'currency' then Result := FormatFloat('#,##0.00 "€"', AsNum(V))
  else if L = 'fixed' then Result := FormatFloat('0.00', AsNum(V))
  else if L = 'standard' then Result := FormatFloat('#,##0.00', AsNum(V))
  else if L = 'percent' then Result := FormatFloat('0.00"%"', AsNum(V) * 100)
  else if L = 'scientific' then Result := FloatToStrF(AsNum(V), ffExponent, 4, 2)
  else if L = 'short date' then Result := FormatDateTime('dd.mm.yyyy', AsDate(V))
  else if L = 'long date' then Result := FormatDateTime('d. mmmm yyyy', AsDate(V))
  else if L = 'short time' then Result := FormatDateTime('hh:nn', AsDate(V))
  else if L = 'long time' then Result := FormatDateTime('hh:nn:ss', AsDate(V))
  else if L = 'general date' then Result := FormatDateTime('dd.mm.yyyy hh:nn', AsDate(V))
  else if L = 'yes/no' then begin if ExprIsTrue(V) then Result := 'Da' else Result := 'Ne'; end
  else if L = 'true/false' then begin if ExprIsTrue(V) then Result := 'True' else Result := 'False'; end
  else if L = 'on/off' then begin if ExprIsTrue(V) then Result := 'On' else Result := 'Off'; end
  else Result := '';
end;

function FormatValue(const V: Variant; const AFmt: string): string;
var
  Named: string;
  D: TDateTime;
begin
  if IsNullV(V) then Exit('');
  if AFmt <> '' then
  begin
    Named := FormatNamed(V, AFmt);
    if Named <> '' then Exit(Named);
    if AFmt = '>' then Exit(UpperCase(VarToStr(V)));
    if AFmt = '<' then Exit(LowerCase(VarToStr(V)));
  end;
  if IsDateV(V) then
  begin
    if AFmt = '' then
    begin
      if Frac(Double(TDateTime(V))) <> 0 then Result := FormatDateTime('dd.mm.yyyy hh:nn', V)
      else Result := FormatDateTime('dd.mm.yyyy', V);
    end
    else Result := FormatDateTime(AFmt, V);
  end
  else if IsNumV(V) and (AFmt <> '') then
    Result := FormatFloat(AFmt, Double(V))
  else if (AFmt <> '') and TryDate(V, D) and not IsNumV(V) then
    Result := FormatDateTime(AFmt, D)
  else if VarIsFloat(V) then
    Result := FloatToStr(RoundTo(Double(V), -10), DefaultFormatSettings)   { prikaz: 12,5 }
  else
    Result := AsStr(V);
end;

{ aggregate names the host understands; Min/Max with several arguments stay scalar }
function RoundHalfUp(X: Double; ADec: Integer): Double;
var
  F, V: Extended;
begin
  F := IntPower(10, ADec);
  V := Abs(X) * F;
  V := Floor(V + 0.5 + 1E-7);
  if X < 0 then Result := -(V / F) else Result := V / F;
end;

function IsAggName(const F: string): Boolean;
const
  Names: array[0..16] of string = ('sum', 'count', 'avg', 'min', 'max', 'first', 'last', 'stdev',
    'var', 'median', 'sumall', 'countall', 'avgall', 'runsum', 'runcount', 'rungsum', 'rungcount');
var
  I: Integer;
begin
  for I := 0 to High(Names) do
    if Names[I] = F then Exit(True);
  Result := False;
end;

{ ---------------- parser ---------------- }

type
  TVarArr = array of Variant;

  TParser = class
  public
    S: string;
    P: Integer;
    Host: TaExprHost;
    function Peek: Char;
    function WordAt: string;           { identifier at P without consuming }
    function TryWord(const W: string): Boolean;
    function ReadIdent: string;
    procedure Expect(C: Char);
    function ParseOr: Variant;
    function ParseXor: Variant;
    function ParseAnd: Variant;
    function ParseNot: Variant;
    function ParseCmp: Variant;
    function ParseConcat: Variant;
    function ParseAdd: Variant;
    function ParseMod: Variant;
    function ParseMul: Variant;
    function ParseUnary: Variant;
    function ParsePow: Variant;
    function ParsePrimary: Variant;
    function ParseArgs(out AArgs: TVarArr): Integer;
    function CallFn(const AName: string; const A: TVarArr; N: Integer): Variant;
  end;

function TParser.Peek: Char;
begin
  while (P <= Length(S)) and (S[P] in [' ', #9, #10, #13]) do Inc(P);
  if P > Length(S) then Result := #0 else Result := S[P];
end;

function TParser.WordAt: string;
var
  Q: Integer;
begin
  Peek;
  Result := '';
  Q := P;
  while (Q <= Length(S)) and (S[Q] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
  begin
    Result := Result + S[Q];
    Inc(Q);
  end;
end;

function TParser.TryWord(const W: string): Boolean;
begin
  Result := SameText(WordAt, W);
  if Result then Inc(P, Length(W));
end;

function TParser.ReadIdent: string;
begin
  Result := WordAt;
  Inc(P, Length(Result));
end;

procedure TParser.Expect(C: Char);
begin
  if Peek <> C then raise EExpr.Create('Očekivano "' + C + '"');
  Inc(P);
end;

function TParser.ParseOr: Variant;
var
  R: Variant;
begin
  Result := ParseXor;
  while TryWord('Or') do
  begin
    R := ParseXor;
    if (not IsNullV(Result) and ExprIsTrue(Result)) or (not IsNullV(R) and ExprIsTrue(R)) then Result := True
    else if IsNullV(Result) or IsNullV(R) then Result := Null
    else Result := False;
  end;
end;

function TParser.ParseXor: Variant;
var
  R: Variant;
begin
  Result := ParseAnd;
  while TryWord('Xor') do
  begin
    R := ParseAnd;
    if IsNullV(Result) or IsNullV(R) then Result := Null
    else Result := ExprIsTrue(Result) <> ExprIsTrue(R);
  end;
end;

function TParser.ParseAnd: Variant;
var
  R: Variant;
begin
  Result := ParseNot;
  while TryWord('And') do
  begin
    R := ParseNot;
    if (not IsNullV(Result) and not ExprIsTrue(Result)) or (not IsNullV(R) and not ExprIsTrue(R)) then Result := False
    else if IsNullV(Result) or IsNullV(R) then Result := Null
    else Result := True;
  end;
end;

function TParser.ParseNot: Variant;
var
  R: Variant;
begin
  if TryWord('Not') then
  begin
    R := ParseNot();
    if IsNullV(R) then Result := Null else Result := not ExprIsTrue(R);
  end
  else Result := ParseCmp;
end;

function TParser.ParseCmp: Variant;
var
  R, R2: Variant;
  Op: string;
  C: Integer;
  Neg, Found: Boolean;
begin
  Result := ParseConcat;
  repeat
    Peek;
    Op := '';
    if P <= Length(S) then
    begin
      if (P < Length(S)) and (Copy(S, P, 2) = '<>') then Op := '<>'
      else if (P < Length(S)) and (Copy(S, P, 2) = '<=') then Op := '<='
      else if (P < Length(S)) and (Copy(S, P, 2) = '>=') then Op := '>='
      else if S[P] = '=' then Op := '='
      else if S[P] = '<' then Op := '<'
      else if S[P] = '>' then Op := '>';
    end;
    if Op <> '' then
    begin
      Inc(P, Length(Op));
      R := ParseConcat;
      if IsNullV(Result) or IsNullV(R) then Result := Null
      else
      begin
        C := CompareV(Result, R);
        if Op = '=' then Result := C = 0
        else if Op = '<>' then Result := C <> 0
        else if Op = '<' then Result := C < 0
        else if Op = '>' then Result := C > 0
        else if Op = '<=' then Result := C <= 0
        else Result := C >= 0;
      end;
    end
    else if TryWord('Like') then
    begin
      R := ParseConcat;
      if IsNullV(Result) or IsNullV(R) then Result := Null
      else Result := LikeMatch(AsStr(Result), AsStr(R), 1, 1);
    end
    else if TryWord('Is') then
    begin
      Neg := TryWord('Not');
      if not TryWord('Null') then raise EExpr.Create('Očekivano Null nakon Is');
      Result := IsNullV(Result) <> Neg;
    end
    else if TryWord('Between') then
    begin
      R := ParseConcat;
      if not TryWord('And') then raise EExpr.Create('Očekivano And u Between');
      R2 := ParseConcat;
      if IsNullV(Result) or IsNullV(R) or IsNullV(R2) then Result := Null
      else Result := (CompareV(Result, R) >= 0) and (CompareV(Result, R2) <= 0);
    end
    else if TryWord('In') then
    begin
      Expect('(');
      Found := False;
      repeat
        R := ParseOr;
        if (not IsNullV(Result)) and (not IsNullV(R)) and (CompareV(Result, R) = 0) then Found := True;
        Peek;
        if (P <= Length(S)) and (S[P] = ',') then Inc(P) else Break;
      until False;
      Expect(')');
      if IsNullV(Result) then Result := Null else Result := Found;
    end
    else Break;
  until False;
end;

function TParser.ParseConcat: Variant;
var
  R: Variant;
begin
  Result := ParseAdd;
  while Peek = '&' do
  begin
    Inc(P);
    R := ParseAdd;
    Result := AsStr(Result) + AsStr(R);
  end;
end;

function TParser.ParseAdd: Variant;
var
  C: Char;
  R: Variant;
  X: Double;
begin
  Result := ParseMod;
  repeat
    C := Peek;
    if not (C in ['+', '-']) then Break;
    Inc(P);
    R := ParseMod;
    if IsNullV(Result) or IsNullV(R) then Result := Null
    else if (C = '+') and VarIsStr(Result) and VarIsStr(R) then
      Result := VarToStr(Result) + VarToStr(R)               { text + text joins }
    else if (C = '+') and ((VarIsStr(Result) and not IsDateV(R) and not ParseNumber(VarToStr(Result), X)) or
                           (VarIsStr(R) and not IsDateV(Result) and not ParseNumber(VarToStr(R), X))) then
      Result := AsStr(Result) + AsStr(R)
    else if IsDateV(Result) and not IsDateV(R) then
    begin
      if C = '+' then Result := VarFromDateTime(AsDate(Result) + AsNum(R))
      else Result := VarFromDateTime(AsDate(Result) - AsNum(R));
    end
    else if IsDateV(Result) and IsDateV(R) and (C = '-') then Result := AsNum(Result) - AsNum(R)
    else if C = '+' then Result := AsNum(Result) + AsNum(R)
    else Result := AsNum(Result) - AsNum(R);
  until False;
end;

function TParser.ParseMod: Variant;
var
  R: Variant;
  X, Y: Double;
begin
  Result := ParseMul;
  repeat
    if TryWord('Mod') then
    begin
      R := ParseMul;
      if IsNullV(Result) or IsNullV(R) then Result := Null
      else
      begin
        X := Round(AsNum(Result)); Y := Round(AsNum(R));
        if Y = 0 then Result := Null else Result := X - Y * Int(X / Y);
      end;
    end
    else Break;
  until False;
end;

function TParser.ParseMul: Variant;
var
  C: Char;
  R: Variant;
  Y: Double;
begin
  Result := ParseUnary;
  repeat
    C := Peek;
    if not (C in ['*', '/', '\']) then Break;
    Inc(P);
    R := ParseUnary;
    if IsNullV(Result) or IsNullV(R) then Result := Null
    else if C = '*' then Result := AsNum(Result) * AsNum(R)
    else
    begin
      Y := AsNum(R);
      if Y = 0 then Result := Null
      else if C = '/' then Result := AsNum(Result) / Y
      else Result := Trunc(AsNum(Result) / Y);
    end;
  until False;
end;

function TParser.ParseUnary: Variant;
begin
  if Peek = '-' then
  begin
    Inc(P);
    Result := ParseUnary();
    if not IsNullV(Result) then Result := -AsNum(Result);
  end
  else if Peek = '+' then
  begin
    Inc(P);
    Result := ParseUnary();
  end
  else Result := ParsePow;
end;

function TParser.ParsePow: Variant;
var
  R: Variant;
begin
  Result := ParsePrimary;
  while Peek = '^' do
  begin
    Inc(P);
    R := ParseUnary;
    if IsNullV(Result) or IsNullV(R) then Result := Null
    else Result := Power(AsNum(Result), AsNum(R));
  end;
end;

function TParser.ParseArgs(out AArgs: TVarArr): Integer;
begin
  { P is just after '(' }
  SetLength(AArgs, 0);
  Result := 0;
  if Peek = ')' then begin Inc(P); Exit; end;
  repeat
    SetLength(AArgs, Result + 1);
    AArgs[Result] := ParseOr;
    Inc(Result);
    if Peek = ',' then Inc(P) else Break;
  until False;
  Expect(')');
end;

function TParser.ParsePrimary: Variant;
var
  C: Char;
  Start: Integer;
  Fn, Arg, W: string;
  Args: TVarArr;
  N, Depth: Integer;
  InStr: Char;
  TopComma: Boolean;
  D: TDateTime;
  FS2: TFormatSettings;
begin
  C := Peek;
  if C = '(' then
  begin
    Inc(P);
    Result := ParseOr;
    Expect(')');
  end
  else if C in ['0'..'9', '.'] then
  begin
    Start := P;
    while (P <= Length(S)) and (S[P] in ['0'..'9', '.']) do Inc(P);
    FS2 := ParseFS;
    Result := StrToFloat(Copy(S, Start, P - Start), FS2);
  end
  else if C in ['''', '"'] then
  begin
    Inc(P);
    Result := '';
    while P <= Length(S) do
    begin
      if S[P] = C then
      begin
        if (P < Length(S)) and (S[P + 1] = C) then begin Result := VarToStr(Result) + C; Inc(P, 2); Continue; end;
        Break;
      end;
      Result := VarToStr(Result) + S[P];
      Inc(P);
    end;
    if P > Length(S) then raise EExpr.Create('Nezatvoren tekst');
    Inc(P);
  end
  else if C = '#' then
  begin
    Inc(P);
    Start := P;
    while (P <= Length(S)) and (S[P] <> '#') do Inc(P);
    if not ParseAnyDateTime(Copy(S, Start, P - Start), D) then raise EExpr.Create('Neispravan datum');
    Inc(P);
    Result := VarFromDateTime(D);
  end
  else if C = '[' then
  begin
    Inc(P);
    Start := P;
    while (P <= Length(S)) and (S[P] <> ']') do Inc(P);
    if P > Length(S) then raise EExpr.Create('Nezatvorena zagrada [');
    Arg := Copy(S, Start, P - Start);
    Inc(P);
    Result := Host.FieldValue(Arg);
  end
  else if C in ['A'..'Z', 'a'..'z', '_'] then
  begin
    W := WordAt;
    Fn := LowerCase(W);
    Inc(P, Length(W));
    if Fn = 'true' then Exit(True);
    if Fn = 'false' then Exit(False);
    if Fn = 'null' then Exit(Null);
    if Peek = '(' then
    begin
      Inc(P);
      if IsAggName(Fn) then
      begin
        { aggregate when the only argument is [field] or *; scalar Min/Max otherwise }
        Start := P;
        if Peek = '*' then
        begin
          Inc(P);
          Expect(')');
          Exit(Host.Aggregate(Fn, '*'));
        end;
        if Peek = '[' then
        begin
          Inc(P);
          N := P;
          while (P <= Length(S)) and (S[P] <> ']') do Inc(P);
          Arg := Copy(S, N, P - N);
          Inc(P);
          if Peek = ')' then begin Inc(P); Exit(Host.Aggregate(Fn, Arg)); end;
        end;
        { izraz kao jedini argument zbroja: Sum(Iif([placeno] = 1, [iznos], 0)); Min/Max ostaju skalarni }
        if (Fn <> 'min') and (Fn <> 'max') then
        begin
          Depth := 1; N := P; InStr := #0; TopComma := False;
          while (N <= Length(S)) and (Depth > 0) do
          begin
            if InStr <> #0 then begin if S[N] = InStr then InStr := #0; end
            else if (S[N] = '"') or (S[N] = '''') then InStr := S[N]
            else if S[N] = '(' then Inc(Depth)
            else if S[N] = ')' then Dec(Depth)
            else if (S[N] = ',') and (Depth = 1) then TopComma := True;
            Inc(N);
          end;
          if (Depth = 0) and not TopComma and (N - 2 >= P) then
          begin
            Arg := '=' + Trim(Copy(S, P, N - 1 - P));
            P := N;
            Exit(Host.Aggregate(Fn, Arg));
          end;
        end;
        P := Start;
      end;
      N := ParseArgs(Args);
      Result := CallFn(Fn, Args, N);
    end
    else
    begin
      Result := Host.Variable(W);
      if IsNullV(Result) and ((Fn = 'date') or (Fn = 'today') or (Fn = 'now') or (Fn = 'time')) then
      begin
        SetLength(Args, 0);
        Result := CallFn(Fn, Args, 0);
      end;
    end;
  end
  else
    raise EExpr.Create('Sintaksa');
end;

{ ---------------- functions ---------------- }

const
  MonthNames: array[1..12] of string = ('siječanj', 'veljača', 'ožujak', 'travanj', 'svibanj',
    'lipanj', 'srpanj', 'kolovoz', 'rujan', 'listopad', 'studeni', 'prosinac');
  DayNames: array[1..7] of string = ('nedjelja', 'ponedjeljak', 'utorak', 'srijeda', 'četvrtak',
    'petak', 'subota');

function IntervalOf(const S: string): string;
begin
  Result := LowerCase(Trim(S));
end;

function OptArg(const A: TVarArr; N, I: Integer): string;
begin
  if (I < N) and not IsNullV(A[I]) then Result := AsStr(A[I]) else Result := '';
end;

function TParser.CallFn(const AName: string; const A: TVarArr; N: Integer): Variant;
var
  I, K, Cl: Integer;
  Ch: string;
  X: Double;
  Sx, Sy: string;
  D, D2: TDateTime;
  Y, M, Dd, H, Mi, Sec, Ms: Word;
  Iv: string;
  YY, MM: Integer;

  procedure Need(Cnt: Integer);
  begin
    if N < Cnt then raise EExpr.Create('Funkciji ' + AName + ' nedostaju argumenti');
  end;

begin
  Result := Null;
  { ---- logic ---- }
  if AName = 'iif' then
  begin
    Need(3);
    if ExprIsTrue(A[0]) then Exit(A[1]) else Exit(A[2]);
  end;
  if AName = 'nz' then
  begin
    Need(1);
    if IsNullV(A[0]) then
    begin
      if N >= 2 then Exit(A[1]);
      Exit(0);
    end;
    Exit(A[0]);
  end;
  if AName = 'isnull' then begin Need(1); Exit(IsNullV(A[0])); end;
  if AName = 'isnumeric' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(False);
    Exit(IsNumV(A[0]) or ParseNumber(VarToStr(A[0]), X));
  end;
  if AName = 'isdate' then begin Need(1); Exit(TryDate(A[0], D)); end;
  if AName = 'switch' then
  begin
    K := 0;
    while K + 1 < N do
    begin
      if ExprIsTrue(A[K]) then Exit(A[K + 1]);
      Inc(K, 2);
    end;
    Exit(Null);
  end;
  if AName = 'choose' then
  begin
    Need(2);
    if IsNullV(A[0]) then Exit(Null);
    K := Trunc(AsNum(A[0]));
    if (K >= 1) and (K < N) then Exit(A[K]);
    Exit(Null);
  end;
  { ---- text ---- }
  if AName = 'len' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(UTF8Length(AsStr(A[0]))); end;
  if AName = 'left' then
  begin
    Need(2);
    if IsNullV(A[0]) then Exit(Null);
    Exit(UTF8Copy(AsStr(A[0]), 1, Trunc(AsNum(A[1]))));
  end;
  if AName = 'right' then
  begin
    Need(2);
    if IsNullV(A[0]) then Exit(Null);
    Sx := AsStr(A[0]);
    K := Trunc(AsNum(A[1]));
    if K > UTF8Length(Sx) then K := UTF8Length(Sx);
    Exit(UTF8Copy(Sx, UTF8Length(Sx) - K + 1, K));
  end;
  if AName = 'mid' then
  begin
    Need(2);
    if IsNullV(A[0]) then Exit(Null);
    if N >= 3 then Exit(UTF8Copy(AsStr(A[0]), Trunc(AsNum(A[1])), Trunc(AsNum(A[2]))))
    else Exit(UTF8Copy(AsStr(A[0]), Trunc(AsNum(A[1])), MaxInt));
  end;
  if AName = 'ucase' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(UTF8UpperCase(AsStr(A[0]))); end;
  if AName = 'lcase' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(UTF8LowerCase(AsStr(A[0]))); end;
  if AName = 'trim' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Trim(AsStr(A[0]))); end;
  if AName = 'ltrim' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(TrimLeft(AsStr(A[0]))); end;
  if AName = 'rtrim' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(TrimRight(AsStr(A[0]))); end;
  if AName = 'proper' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Sx := UTF8LowerCase(AsStr(A[0]));
    Sy := '';
    I := 1;
    K := 0;   { 0 = početak riječi }
    while I <= Length(Sx) do
    begin
      Cl := UTF8CharacterLength(PChar(@Sx[I]));
      if Cl < 1 then Cl := 1;
      Ch := Copy(Sx, I, Cl);
      if K = 0 then Sy := Sy + UTF8UpperCase(Ch) else Sy := Sy + Ch;
      if (Cl = 1) and (Ch[1] in [' ', '-', '.']) then K := 0 else K := 1;
      Inc(I, Cl);
    end;
    Exit(Sy);
  end;
  if AName = 'instr' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(Null);
    Exit(UTF8Pos(UTF8LowerCase(AsStr(A[1])), UTF8LowerCase(AsStr(A[0]))));
  end;
  if AName = 'replace' then
  begin
    Need(3);
    if IsNullV(A[0]) then Exit(Null);
    Exit(StringReplace(AsStr(A[0]), AsStr(A[1]), AsStr(A[2]), [rfReplaceAll, rfIgnoreCase]));
  end;
  if AName = 'space' then begin Need(1); Exit(StringOfChar(' ', Trunc(AsNum(A[0])))); end;
  if AName = 'string' then
  begin
    Need(2);
    Sx := AsStr(A[1]);
    if Sx = '' then Exit('');
    Sy := UTF8Copy(Sx, 1, 1);
    Result := '';
    for I := 1 to Trunc(AsNum(A[0])) do Result := Result + Sy;
    Exit;
  end;
  if AName = 'chr' then begin Need(1); Exit(Chr(Trunc(AsNum(A[0])) and 255)); end;
  if AName = 'asc' then
  begin
    Need(1);
    Sx := AsStr(A[0]);
    if Sx = '' then Exit(Null);
    Exit(Ord(Sx[1]));
  end;
  if AName = 'str' then begin Need(1); Exit(AsStr(A[0])); end;
  if AName = 'format' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit('');
    if N >= 2 then Exit(FormatValue(A[0], AsStr(A[1]))) else Exit(FormatValue(A[0], ''));
  end;
  { ---- math ---- }
  if AName = 'abs' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Abs(AsNum(A[0]))); end;
  if AName = 'int' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Floor(AsNum(A[0]))); end;
  if AName = 'fix' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Trunc(AsNum(A[0]))); end;
  if AName = 'sgn' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Sign(AsNum(A[0]))); end;
  if AName = 'sqr' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Sqrt(AsNum(A[0]))); end;
  if AName = 'exp' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Exp(AsNum(A[0]))); end;
  if AName = 'log' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Ln(AsNum(A[0]))); end;
  if AName = 'rnd' then Exit(Random);
  if AName = 'round' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    if N >= 2 then K := Trunc(AsNum(A[1])) else K := 0;
    Exit(RoundTo(AsNum(A[0]), -K));
  end;
  if AName = 'zaokruzi' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    if N >= 2 then K := Trunc(AsNum(A[1])) else K := 0;
    Exit(RoundHalfUp(AsNum(A[0]), K));
  end;
  if (AName = 'max') or (AName = 'min') then
  begin
    Need(1);
    Result := Null;
    for I := 0 to N - 1 do
    begin
      if IsNullV(A[I]) then Continue;
      if IsNullV(Result) then Result := A[I]
      else if (AName = 'max') and (CompareV(A[I], Result) > 0) then Result := A[I]
      else if (AName = 'min') and (CompareV(A[I], Result) < 0) then Result := A[I];
    end;
    Exit;
  end;
  { ---- conversion ---- }
  if (AName = 'cint') or (AName = 'clng') then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(Round(AsNum(A[0])));
  end;
  if AName = 'cdbl' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(AsNum(A[0])); end;
  if AName = 'cstr' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(AsStr(A[0])); end;
  if AName = 'cbool' then begin Need(1); Exit(ExprIsTrue(A[0])); end;
  if (AName = 'cdate') or (AName = 'datevalue') then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    D := AsDate(A[0]);
    if AName = 'datevalue' then D := Int(D);
    Exit(VarFromDateTime(D));
  end;
  if AName = 'val' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(0);
    if ParseNumber(VarToStr(A[0]), X) then Exit(X);
    Exit(0);
  end;
  { ---- dates ---- }
  if AName = 'currentuser' then Exit(CurrentUserName);
  if AName = 'currentrole' then Exit(CurrentUserRole);
  if (AName = 'date') or (AName = 'today') then Exit(VarFromDateTime(Date));
  if AName = 'now' then Exit(VarFromDateTime(Now));
  if AName = 'time' then Exit(VarFromDateTime(Frac(Now)));
  if AName = 'year' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(YearOf(AsDate(A[0]))); end;
  if AName = 'month' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(MonthOf(AsDate(A[0]))); end;
  if AName = 'day' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(DayOf(AsDate(A[0]))); end;
  if AName = 'hour' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(HourOf(AsDate(A[0]))); end;
  if AName = 'minute' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(MinuteOf(AsDate(A[0]))); end;
  if AName = 'second' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(SecondOf(AsDate(A[0]))); end;
  if AName = 'weekday' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(DayOfWeek(AsDate(A[0]))); end;
  if AName = 'monthname' then
  begin
    Need(1);
    K := Trunc(AsNum(A[0]));
    if (K >= 1) and (K <= 12) then Exit(MonthNames[K]);
    Exit(Null);
  end;
  if AName = 'weekdayname' then
  begin
    Need(1);
    K := Trunc(AsNum(A[0]));
    if (K >= 1) and (K <= 7) then Exit(DayNames[K]);
    Exit(Null);
  end;
  if AName = 'dateserial' then
  begin
    Need(3);
    YY := Trunc(AsNum(A[0])); MM := Trunc(AsNum(A[1]));
    { month overflow like Access: DateSerial(2026, 14, 1) = 2027-02-01 }
    K := YY * 12 + MM - 1;
    D := EncodeDate(K div 12, K mod 12 + 1, 1);
    Exit(VarFromDateTime(D + Trunc(AsNum(A[2])) - 1));
  end;
  if AName = 'timeserial' then
  begin
    Need(3);
    Exit(VarFromDateTime((AsNum(A[0]) * 3600 + AsNum(A[1]) * 60 + AsNum(A[2])) / 86400));
  end;
  if AName = 'dateadd' then
  begin
    Need(3);
    if IsNullV(A[2]) then Exit(Null);
    Iv := IntervalOf(AsStr(A[0]));
    K := Trunc(AsNum(A[1]));
    D := AsDate(A[2]);
    if Iv = 'yyyy' then D := IncYear(D, K)
    else if Iv = 'q' then D := IncMonth(D, 3 * K)
    else if Iv = 'm' then D := IncMonth(D, K)
    else if (Iv = 'd') or (Iv = 'y') or (Iv = 'w') then D := D + K
    else if Iv = 'ww' then D := D + 7 * K
    else if Iv = 'h' then D := D + K / 24
    else if Iv = 'n' then D := D + K / 1440
    else if Iv = 's' then D := D + K / 86400
    else raise EExpr.Create('Nepoznat interval: ' + Iv);
    Exit(VarFromDateTime(D));
  end;
  if AName = 'datediff' then
  begin
    Need(3);
    if IsNullV(A[1]) or IsNullV(A[2]) then Exit(Null);
    Iv := IntervalOf(AsStr(A[0]));
    D := AsDate(A[1]);
    D2 := AsDate(A[2]);
    if Iv = 'yyyy' then Exit(YearOf(D2) - YearOf(D))
    else if Iv = 'q' then Exit((YearOf(D2) * 4 + (MonthOf(D2) - 1) div 3) - (YearOf(D) * 4 + (MonthOf(D) - 1) div 3))
    else if Iv = 'm' then Exit((YearOf(D2) * 12 + MonthOf(D2)) - (YearOf(D) * 12 + MonthOf(D)))
    else if (Iv = 'd') or (Iv = 'y') or (Iv = 'w') then Exit(Trunc(Int(D2) - Int(D)))
    else if Iv = 'ww' then Exit(Trunc((Int(D2) - Int(D)) / 7))
    else if Iv = 'h' then Exit(Trunc((D2 - D) * 24))
    else if Iv = 'n' then Exit(Trunc((D2 - D) * 1440))
    else if Iv = 's' then Exit(Trunc((D2 - D) * 86400))
    else raise EExpr.Create('Nepoznat interval: ' + Iv);
  end;
  if AName = 'datepart' then
  begin
    Need(2);
    if IsNullV(A[1]) then Exit(Null);
    Iv := IntervalOf(AsStr(A[0]));
    D := AsDate(A[1]);
    if Iv = 'yyyy' then Exit(YearOf(D))
    else if Iv = 'q' then Exit((MonthOf(D) - 1) div 3 + 1)
    else if Iv = 'm' then Exit(MonthOf(D))
    else if Iv = 'd' then Exit(DayOf(D))
    else if Iv = 'y' then Exit(DayOfTheYear(D))
    else if Iv = 'w' then Exit(DayOfWeek(D))
    else if Iv = 'ww' then Exit(WeekOfTheYear(D))
    else if Iv = 'h' then Exit(HourOf(D))
    else if Iv = 'n' then Exit(MinuteOf(D))
    else if Iv = 's' then Exit(SecondOf(D))
    else raise EExpr.Create('Nepoznat interval: ' + Iv);
  end;
  { ---- text, extra ---- }
  if AName = 'startswith' then begin Need(2); if IsNullV(A[0]) then Exit(Null); Exit(Pos(UTF8LowerCase(AsStr(A[1])), UTF8LowerCase(AsStr(A[0]))) = 1); end;
  if AName = 'endswith' then
  begin
    Need(2);
    if IsNullV(A[0]) then Exit(Null);
    Sx := UTF8LowerCase(AsStr(A[0])); Sy := UTF8LowerCase(AsStr(A[1]));
    Exit((Length(Sy) <= Length(Sx)) and (Copy(Sx, Length(Sx) - Length(Sy) + 1, Length(Sy)) = Sy));
  end;
  if AName = 'contains' then begin Need(2); if IsNullV(A[0]) then Exit(Null); Exit(Pos(UTF8LowerCase(AsStr(A[1])), UTF8LowerCase(AsStr(A[0]))) > 0); end;
  if AName = 'lpad' then
  begin
    Need(2);
    Sx := AsStr(A[0]);
    if N >= 3 then Sy := AsStr(A[2]) else Sy := ' ';
    if Sy = '' then Sy := ' ';
    K := Trunc(AsNum(A[1]));
    Sy := UTF8Copy(Sy, 1, 1);
    while UTF8Length(Sx) < K do Sx := Sy + Sx;
    Exit(Sx);
  end;
  if AName = 'rpad' then
  begin
    Need(2);
    Sx := AsStr(A[0]);
    if N >= 3 then Sy := AsStr(A[2]) else Sy := ' ';
    if Sy = '' then Sy := ' ';
    K := Trunc(AsNum(A[1]));
    Sy := UTF8Copy(Sy, 1, 1);
    while UTF8Length(Sx) < K do Sx := Sx + Sy;
    Exit(Sx);
  end;
  if AName = 'strreverse' then
  begin
    Need(1);
    Sx := AsStr(A[0]); Sy := '';
    for I := 1 to UTF8Length(Sx) do Sy := UTF8Copy(Sx, I, 1) + Sy;
    Exit(Sy);
  end;
  if AName = 'concat' then
  begin
    Sx := '';
    for I := 0 to N - 1 do Sx := Sx + AsStr(A[I]);
    Exit(Sx);
  end;
  if AName = 'coalesce' then
  begin
    for I := 0 to N - 1 do
      if not IsNullV(A[I]) and not (VarIsStr(A[I]) and (VarToStr(A[I]) = '')) then Exit(A[I]);
    Exit(Null);
  end;
  if AName = 'nullif' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(A[0]);
    if CompareV(A[0], A[1]) = 0 then Exit(Null);
    Exit(A[0]);
  end;
  if AName = 'split' then
  begin
    Need(3);
    if IsNullV(A[0]) then Exit(Null);
    Exit(SplitPart(AsStr(A[0]), AsStr(A[1]), Trunc(AsNum(A[2]))));
  end;
  if AName = 'shorten' then
  begin
    Need(2);
    if IsNullV(A[0]) then Exit(Null);
    Sx := AsStr(A[0]);
    K := Trunc(AsNum(A[1]));
    if UTF8Length(Sx) > K then Sx := UTF8Copy(Sx, 1, K - 1) + '…';
    Exit(Sx);
  end;
  if AName = 'initials' then
  begin
    Need(1);
    Sy := '';
    Sx := AsStr(A[0]);
    K := 0;   { 0 = početak riječi }
    I := 1;
    while I <= Length(Sx) do
    begin
      Cl := UTF8CharacterLength(PChar(@Sx[I]));
      if Cl < 1 then Cl := 1;
      Ch := Copy(Sx, I, Cl);
      if Ch = ' ' then K := 0
      else
      begin
        if K = 0 then Sy := Sy + UTF8UpperCase(Ch);
        K := 1;
      end;
      Inc(I, Cl);
    end;
    Exit(Sy);
  end;
  { ---- numbers, extra ---- }
  if AName = 'ceil' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Ceil(AsNum(A[0]))); end;
  if AName = 'floor' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(Floor(AsNum(A[0]))); end;
  if AName = 'percent' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) or (AsNum(A[1]) = 0) then Exit(Null);
    Exit(AsNum(A[0]) / AsNum(A[1]) * 100);
  end;
  if AName = 'clamp' then
  begin
    Need(3);
    if IsNullV(A[0]) then Exit(Null);
    X := AsNum(A[0]);
    if X < AsNum(A[1]) then X := AsNum(A[1]);
    if X > AsNum(A[2]) then X := AsNum(A[2]);
    Exit(X);
  end;
  if AName = 'postavka' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    if Host is TCheckHost then Exit('');
    if not Assigned(SettingHook) then Exit('');
    Exit(SettingHook(AsStr(A[0])));
  end;
  if AName = 'fgl' then
  begin
    { Fgl("Funkcija"; arg; ...): prva vrijednost koju 4GL funkcija vraca (RETURN) }
    if N < 1 then raise EExpr.Create('Fgl trazi naziv funkcije');
    if Host is TCheckHost then Exit(Null);
    if not Assigned(FglHook) then raise EExpr.Create('4GL nije dostupan u izrazima');
    Exit(FglHook(AName, A, N));
  end;
  if AName = 'hub3uplata' then
  begin
    { Hub3Uplata(iznos, platitelj, adresa, mjesto, primatelj, adresa, mjesto, iban [, model, poziv, sifra, opis]) }
    if (N < 8) or (N > 12) then raise EExpr.Create('Hub3Uplata traži 8 do 12 argumenata');
    if IsNullV(A[0]) then Exit(Null);
    Exit(Hub3Payload(AsNum(A[0]), AsStr(A[1]), AsStr(A[2]), AsStr(A[3]), AsStr(A[4]), AsStr(A[5]), AsStr(A[6]), AsStr(A[7]),
      OptArg(A, N, 8), OptArg(A, N, 9), OptArg(A, N, 10), OptArg(A, N, 11)));
  end;
  if AName = 'brojslovima' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(NumberToWordsHr(Round(AsNum(A[0])), wgMasculine));
  end;
  if AName = 'iznosslovima' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    if N >= 2 then Exit(AmountToWordsHr(AsNum(A[0]), Trunc(AsNum(A[1]))));
    Exit(AmountToWordsHr(AsNum(A[0]), 0));
  end;
  if AName = 'eur' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit('');
    Exit(FormatFloat('#,##0.00 "€"', AsNum(A[0])));
  end;
  { ---- dates, extra ---- }
  if AName = 'eomonth' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    D := AsDate(A[0]);
    Exit(VarFromDateTime(Int(EndOfTheMonth(D))));
  end;
  if AName = 'bomonth' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(VarFromDateTime(StartOfTheMonth(AsDate(A[0]))));
  end;
  if AName = 'quarter' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit((MonthOf(AsDate(A[0])) - 1) div 3 + 1); end;
  if AName = 'weeknumber' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(WeekOfTheYear(AsDate(A[0]))); end;
  if AName = 'adddays' then begin Need(2); if IsNullV(A[0]) then Exit(Null); Exit(VarFromDateTime(AsDate(A[0]) + AsNum(A[1]))); end;
  if AName = 'addmonths' then begin Need(2); if IsNullV(A[0]) then Exit(Null); Exit(VarFromDateTime(IncMonth(AsDate(A[0]), Trunc(AsNum(A[1]))))); end;
  if AName = 'daysbetween' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(Null);
    Exit(Trunc(Int(AsDate(A[1])) - Int(AsDate(A[0]))));
  end;
  if AName = 'workdays' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(Null);
    Exit(WorkDaysBetween(AsDate(A[0]), AsDate(A[1])));
  end;
  if AName = 'eval' then
  begin
    { izraz zapisan kao tekst (npr. u polju baze); najvise 4 razine ugnjezdivanja }
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    if EvalDepthNow >= 4 then raise EExpr.Create('Eval je preduboko ugniježđen');
    Inc(EvalDepthNow);
    try
      Exit(EvalExpr(AsStr(A[0]), Host));
    finally
      Dec(EvalDepthNow);
    end;
  end;
  if AName = 'plaintext' then
  begin
    { formatirani tekst (polje RichText) kao obican tekst: za popise, pretrage i izvoz }
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(RtToPlain(AsStr(A[0])));
  end;
  if AName = 'between' then
  begin
    Need(3);
    if IsNullV(A[0]) or IsNullV(A[1]) or IsNullV(A[2]) then Exit(Null);
    Exit((AsNum(A[0]) >= AsNum(A[1])) and (AsNum(A[0]) <= AsNum(A[2])));
  end;
  if AName = 'inlist' then
  begin
    Need(2);
    for K := 1 to N - 1 do
      if SameText(AsStr(A[0]), AsStr(A[K])) then Exit(True);
    Exit(False);
  end;
  if AName = 'mod' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(Null);
    if Trunc(AsNum(A[1])) = 0 then Exit(Null);
    Exit(Trunc(AsNum(A[0])) mod Trunc(AsNum(A[1])));
  end;
  if AName = 'power' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(Null);
    Exit(Power(AsNum(A[0]), AsNum(A[1])));
  end;
  if AName = 'pi' then Exit(Pi);
  if AName = 'pmt' then
  begin
    { rata anuiteta: Pmt(kamata po razdoblju, broj razdoblja, glavnica) }
    Need(3);
    if IsNullV(A[0]) or IsNullV(A[1]) or IsNullV(A[2]) then Exit(Null);
    if AsNum(A[1]) <= 0 then Exit(Null);
    if Abs(AsNum(A[0])) < 1E-12 then Exit(AsNum(A[2]) / AsNum(A[1]));
    Exit(AsNum(A[2]) * AsNum(A[0]) / (1 - Power(1 + AsNum(A[0]), -AsNum(A[1]))));
  end;
  if AName = 'isweekend' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(DayOfWeek(AsDate(A[0])) in [1, 7]);
  end;
  if AName = 'addworkdays' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(Null);
    D := Int(AsDate(A[0]));
    K := Trunc(AsNum(A[1]));
    while K <> 0 do
    begin
      if K > 0 then D := D + 1 else D := D - 1;
      if DayOfWeek(D) in [2..6] then
        if K > 0 then Dec(K) else Inc(K);
    end;
    Exit(VarFromDateTime(D));
  end;
  if AName = 'boyear' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(VarFromDateTime(EncodeDate(YearOf(AsDate(A[0])), 1, 1)));
  end;
  if AName = 'eoyear' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(VarFromDateTime(EncodeDate(YearOf(AsDate(A[0])), 12, 31)));
  end;
  if AName = 'dayofyear' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    D := Int(AsDate(A[0]));
    Exit(Trunc(D - EncodeDate(YearOf(D), 1, 1)) + 1);
  end;
  if AName = 'daysinmonth' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    D := AsDate(A[0]);
    Exit(DaysInAMonth(YearOf(D), MonthOf(D)));
  end;
  if AName = 'monthsbetween' then
  begin
    { puni mjeseci izmedu dva datuma }
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(Null);
    D := Int(AsDate(A[0]));
    D2 := Int(AsDate(A[1]));
    K := (YearOf(D2) - YearOf(D)) * 12 + MonthOf(D2) - MonthOf(D);
    if (K > 0) and (DayOf(D2) < DayOf(D)) then Dec(K)
    else if (K < 0) and (DayOf(D2) > DayOf(D)) then Inc(K);
    Exit(K);
  end;
  if AName = 'praznik' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(HrHoliday(AsDate(A[0])));
  end;
  if AName = 'uskrs' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(VarFromDateTime(EasterSunday(Trunc(AsNum(A[0])))));
  end;
  if AName = 'radnidani' then
  begin
    Need(2);
    if IsNullV(A[0]) or IsNullV(A[1]) then Exit(Null);
    Exit(WorkDaysNoHolidays(AsDate(A[0]), AsDate(A[1])));
  end;
  if AName = 'age' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    D := AsDate(A[0]);
    if N >= 2 then D2 := AsDate(A[1]) else D2 := Date;
    K := YearOf(D2) - YearOf(D);
    if (MonthOf(D2) < MonthOf(D)) or ((MonthOf(D2) = MonthOf(D)) and (DayOf(D2) < DayOf(D))) then Dec(K);
    Exit(K);
  end;
  if AName = 'dayname' then
  begin
    Need(1);
    if IsNullV(A[0]) then Exit(Null);
    Exit(DayNames[DayOfWeek(AsDate(A[0]))]);
  end;
  if AName = 'isleapyear' then begin Need(1); Exit(IsLeapYear(Trunc(AsNum(A[0])))); end;
  { ---- checks ---- }
  if AName = 'validoib' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(OibValid(Trim(AsStr(A[0])))); end;
  if AName = 'validiban' then begin Need(1); if IsNullV(A[0]) then Exit(Null); Exit(IbanValid(AsStr(A[0]))); end;
  if AName = 'isempty' then begin Need(1); Exit(IsNullV(A[0]) or (VarIsStr(A[0]) and (Trim(VarToStr(A[0])) = ''))); end;
  if AName = 'zki' then
  begin
    Need(3);
    if IsNullV(A[0]) or IsNullV(A[1]) or IsNullV(A[2]) then Exit(Null);
    if Host is TCheckHost then Exit('');
    if not Assigned(FiscalZkiHook) then raise EExpr.Create('Fiskalizacija nije postavljena');
    Exit(FiscalZkiHook(AsStr(A[0]), AsDate(A[1]), AsNum(A[2])));
  end;
  { ---- podforme: SubSum('Stavke', 'iznos'), SubCount('Stavke') ---- }
  if (AName = 'subsum') or (AName = 'subcount') or (AName = 'subavg') or (AName = 'submin') or (AName = 'submax') then
  begin
    if AName = 'subcount' then
    begin
      Need(1);
      if Host is TCheckHost then Exit(0);
      Exit(Host.SubAggregate('count', AsStr(A[0]), '*'));
    end;
    Need(2);
    if Host is TCheckHost then Exit(0);
    Exit(Host.SubAggregate(Copy(AName, 4, MaxInt), AsStr(A[0]), AsStr(A[1])));
  end;
  { ---- domain aggregates ---- }
  if (AName = 'dlookup') or (AName = 'dcount') or (AName = 'dsum') or (AName = 'davg') or
     (AName = 'dmin') or (AName = 'dmax') then
  begin
    Need(2);
    Sx := '';
    if N >= 3 then Sx := AsStr(A[2]);
    Exit(Host.Domain(AName, AsStr(A[0]), AsStr(A[1]), Sx));
  end;
  if (AName = 'predict') or (AName = 'predictnewton') or (AName = 'predictmarket') then
  begin
    { Predict i PredictNewton(liga, domaci, gosti, datum, trziste, izbor): vjerojatnost iz modela predvidanja }
    Need(6);
    if Host is TCheckHost then Exit(0);
    if not Assigned(PredictHook) then raise EExpr.Create('Predviđanja nisu dostupna');
    Exit(PredictHook(AName, A, N));
  end;
  if AName = 'predictxg' then
  begin
    { PredictXG(liga, domaci, gosti, datum, dio): ocekivani golovi }
    Need(5);
    if Host is TCheckHost then Exit(0);
    if not Assigned(PredictHook) then raise EExpr.Create('Predviđanja nisu dostupna');
    Exit(PredictHook(AName, A, N));
  end;
  if AName = 'generateslips' then
  begin
    { GenerateSlips(sustav, datum [, min_vjerojatnost]): napise probne listice kola, vrati koliko ih je spremljeno }
    Need(2);
    if Host is TCheckHost then Exit(0);
    if not Assigned(GenerateSlipsHook) then raise EExpr.Create('Generiranje listica nije dostupno');
    Exit(GenerateSlipsHook(AName, A, N));
  end;
  if (AName = 'downloadfile') or (AName = 'importmatches') or (AName = 'refreshmain') or (AName = 'importcountries') or (AName = 'refreshcountries') or (AName = 'refreshcroatia') or (AName = 'refreshuefa') or (AName = 'roundreport') or (AName = 'latestround') then
  begin
    { DownloadFile(url, datoteka [, sekunde]); ImportMatches(datoteka [, sezona [, spoji]]); RefreshMain([sezona]) }
    if AName = 'downloadfile' then Need(2) else if (AName = 'importmatches') or (AName = 'importcountries') or (AName = 'roundreport') then Need(1);
    if Host is TCheckHost then Exit(0);
    if not Assigned(DataHook) then raise EExpr.Create('Preuzimanje i uvoz podataka nisu dostupni');
    Exit(DataHook(AName, A, N));
  end;
  if (AName = 'runreliability') or (AName = 'runprogression') then
  begin
    { RunReliability([ponavljanja [, sjeme]]); RunProgression([kola [, ponavljanja [, sjeme]]]) }
    if Host is TCheckHost then Exit(0);
    if not Assigned(StatsHook) then raise EExpr.Create('Izvjesce pouzdanosti nije dostupno');
    Exit(StatsHook(AName, A, N));
  end;
  if AName = 'runanalytics' then
  begin
    { RunAnalytics(): izracuna sve analize nad zapisanim listicima u tablice an_*; vraca broj redaka }
    Need(0);
    if Host is TCheckHost then Exit(0);
    if not Assigned(AnalyticsHook) then raise EExpr.Create('Analize nisu dostupne');
    Exit(AnalyticsHook(AName, A, N));
  end;
  if (AName = 'runcombinations') or (AName = 'runsession') or (AName = 'runmontecarlo') then
  begin
    { RunCombinations(liga, domaci, gosti [, datum]); RunSession(banka [, frakcija]); RunMonteCarlo(nacin, ...) }
    if AName = 'runcombinations' then Need(3) else Need(1);
    if Host is TCheckHost then Exit(0);
    if not Assigned(PairsHook) then raise EExpr.Create('Parovi i sesija nisu dostupni');
    Exit(PairsHook(AName, A, N));
  end;
  if (AName = 'runleagueoverview') or (AName = 'teamform') or (AName = 'runheadtohead') or (AName = 'runseasonprofile') then
  begin
    if AName = 'runleagueoverview' then Need(2)
    else if AName = 'runheadtohead' then Need(2)
    else Need(1);
    if Host is TCheckHost then Exit(0);
    if not Assigned(LeagueHook) then raise EExpr.Create('Pregled lige nije dostupan');
    Exit(LeagueHook(AName, A, N));
  end;
  if AName = 'validateseason' then
  begin
    Need(1);
    if Host is TCheckHost then Exit(0);
    if not Assigned(ValidationHook) then raise EExpr.Create('Provjera sezone nije dostupna');
    Exit(ValidationHook(AName, A, N));
  end;
  if AName = 'runenginebacktest' then
  begin
    { RunEngineBacktest(liga, sezona [, prag [, dani_do_ponovnog_fita]]) }
    Need(2);
    if Host is TCheckHost then Exit(0);
    if not Assigned(EngineBacktestHook) then raise EExpr.Create('Backtest nije dostupan');
    Exit(EngineBacktestHook(AName, A, N));
  end;
  if AName = 'runbacktest' then
  begin
    { RunBacktest(lige, dubina [, kombinacija [, banka [, trzista]]]): hod kroz sezone, rezultati u tablicama backtest_* }
    Need(2);
    if Host is TCheckHost then Exit(0);
    if not Assigned(BacktestHook) then raise EExpr.Create('Backtest nije dostupan');
    Exit(BacktestHook(AName, A, N));
  end;
  if AName = 'predictround' then
  begin
    { PredictRound([datum]): predvidanja utakmica kola u tablice kolo_utakmice i kolo_trzista; vraca broj utakmica }
    if Host is TCheckHost then Exit(0);
    if not Assigned(GenerateSlipsHook) then raise EExpr.Create('Predvidanja kola nisu dostupna');
    Exit(GenerateSlipsHook(AName, A, N));
  end;
  if AName = 'importfixtures' then
  begin
    { ImportFixtures(datoteka): doda u tablicu fixtures utakmice iz CSV rasporeda; vrati koliko je novih }
    Need(1);
    if Host is TCheckHost then Exit(0);
    if not Assigned(GenerateSlipsHook) then raise EExpr.Create('Uvoz rasporeda nije dostupan');
    Exit(GenerateSlipsHook(AName, A, N));
  end;
  if AName = 'predictreset' then
  begin
    { PredictReset(): zaboravi izracunate ocjene (nakon uvoza novih utakmica) }
    Need(0);
    if Host is TCheckHost then Exit(True);
    if Assigned(PredictHook) then PredictHook(AName, A, N);
    Exit(True);
  end;
  if AName = 'preuzmi' then
  begin
    { Preuzmi(tablica, polje, kljuc): vrijednost polja iz retka s tim primarnim kljucem (kratica za DLookup) }
    Need(3);
    if IsNullV(A[2]) or (Trim(AsStr(A[2])) = '') then Exit(Null);
    Exit(Host.Domain('preuzmi', AsStr(A[1]), AsStr(A[0]), AsStr(A[2])));
  end;
  if AName = 'pdvpostopama' then
  begin
    { PdvPoStopama(tablica, iznos_polje, stopa_polje [, uvjet]): osnovice se zbroje po stopi, PDV se zaokruzi po stopi }
    Need(3);
    Sx := '';
    if N >= 4 then Sx := AsStr(A[3]);
    if Host is TCheckHost then Exit(0);
    Exit(Host.Domain('pdvpostopama', AsStr(A[1]) + ',' + AsStr(A[2]), AsStr(A[0]), Sx));
  end;
  { user-defined (script) functions }
  if Host is TCheckHost then
  begin
    if (UserFunctionNames <> nil) and (UserFunctionNames.IndexOf(UpperCase(AName)) >= 0) then Exit(Null);
  end
  else if Assigned(UserFunctionHook) and UserFunctionHook(AName, A, Result) then Exit;
  raise EExpr.Create('Nepoznata funkcija: ' + AName);
end;

{ ---------------- entry points ---------------- }

function EvalExprEx(const S: string; AHost: TaExprHost; out AError: string): Variant;
var
  Pr: TParser;
begin
  AError := '';
  Result := Null;
  Pr := TParser.Create;
  try
    Pr.S := S;
    Pr.P := 1;
    Pr.Host := AHost;
    try
      Result := Pr.ParseOr;
      if Pr.Peek <> #0 then raise EExpr.Create('Neočekivani znak "' + Pr.S[Pr.P] + '"');
    except
      on E: Exception do
      begin
        AError := E.Message;
        Result := '#Err';
      end;
    end;
  finally
    Pr.Free;
  end;
end;

function EvalExpr(const S: string; AHost: TaExprHost): Variant;
var
  Err: string;
begin
  Result := EvalExprEx(S, AHost, Err);
end;

function TCheckHost.FieldValue(const AName: string): Variant;
begin
  Result := Null;
end;

function TCheckHost.Aggregate(const AFunc, AField: string): Variant;
begin
  Result := Null;
end;

function TCheckHost.Variable(const AName: string): Variant;
begin
  Result := Null;
end;

function CheckExpr(const S: string): string;
var
  H: TCheckHost;
  E: string;
begin
  H := TCheckHost.Create;
  try
    EvalExprEx(S, H, E);
    { evaluation errors caused by Null operands are not syntax problems }
    if (Pos('Nije broj', E) = 1) or (Pos('Nije datum', E) = 1) then E := '';
    Result := E;
  finally
    H.Free;
  end;
end;

initialization
  UserFunctionNames := TStringList.Create;
finalization
  UserFunctionNames.Free;
end.
