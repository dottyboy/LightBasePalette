unit ta_fglblocks;
{ Model blokova za 4GL (bez sucelja): program je lista redaka; svaki redak je blok. Strukture (MAIN, FUNCTION, IF,
  WHILE, FOR, FOREACH, CASE, MENU, INPUT, REPORT, SCREEN, RECORD, GLOBALS) otvaraju se prvom rijecju retka i
  zatvaraju retkom "END ..."; ELSE / WHEN / OTHERWISE / COMMAND / ON / FORMAT... su srednji dijelovi.
  Tekst <-> blokovi je bez gubitka: redak koji se ne dira ostaje znak po znak isti. Provjera sintakse ostaje na
  pravom parseru (ta_fgl); ovdje se provjerava samo uparenost struktura. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TaFglKind = (fkBlank, fkComment, fkPlain, fkOpen, fkMid, fkClose);

  TaFglBlocks = class
  private
    FLines: TStringList;
    FKinds: array of TaFglKind;
    FWord: array of string;       { prva rijec velikim slovima }
    FOpener: array of Integer;    { za mid/close: indeks otvaraca; za ostale -1 }
    FDepth: array of Integer;
    FProblems: TStringList;
    procedure Analyse;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadText(const AText: string);
    function Text: string;
    function Raw(AIndex: Integer): string;
    { postavi redak (uvlaka se preuzima iz razine retka ako AReindent) }
    procedure SetRaw(AIndex: Integer; const ALine: string);
    procedure InsertLine(AIndex: Integer; const ALine: string);
    procedure DeleteLine(AIndex: Integer);
    procedure MoveLine(AFrom, ATo: Integer);
    function Kind(AIndex: Integer): TaFglKind;
    function FirstWord(AIndex: Integer): string;
    { razina ugnjezdivanja za uvlacenje u prikazu (mid i close stoje u razini otvaraca) }
    function Depth(AIndex: Integer): Integer;
    function OpenerOf(AIndex: Integer): Integer;
    { indeks zatvaraca za otvarac; -1 ako ga nema }
    function CloserOf(AIndex: Integer): Integer;
    { opisi neuparenih struktura, jedan redak po problemu }
    function Problems: TStringList;
    property Count: Integer read GetCount;
  end;

  TaFglTemplate = record
    Cat, Name, Hint, Body: string;     { Body: retci odvojeni znakom |, uvlaka dva razmaka po razini }
  end;

function FglTemplateCount: Integer;
function FglTemplate(AIndex: Integer): TaFglTemplate;
function FglCategoryCount: Integer;
function FglCategoryName(AIndex: Integer): string;
{ retci predloska (bez uvlake po razini) }
procedure FglTemplateLines(AIndex: Integer; ALines: TStrings);

implementation

const
  Cats: array[0..4] of string = ('Program', 'Tijek', 'Baza', 'Ispis i unos', 'Ostalo');
  Tpl: array[0..29] of TaFglTemplate = (
    (Cat: 'Program'; Name: 'Glavni program (MAIN)'; Hint: 'Početak programa'; Body: 'MAIN|  DISPLAY "Pozdrav"|END MAIN'),
    (Cat: 'Program'; Name: 'Funkcija'; Hint: 'FUNCTION naziv() ... END FUNCTION'; Body: 'FUNCTION naziv()|  DISPLAY "u funkciji"|END FUNCTION'),
    (Cat: 'Program'; Name: 'Funkcija s povratnom vrijednošću'; Hint: 'FUNCTION f(a) RETURNING ...'; Body: 'FUNCTION naziv(a)|  RETURN a|END FUNCTION'),
    (Cat: 'Program'; Name: 'Varijabla (broj)'; Hint: 'DEFINE n INTEGER'; Body: 'DEFINE n INTEGER'),
    (Cat: 'Program'; Name: 'Varijabla (tekst)'; Hint: 'DEFINE t TEXT'; Body: 'DEFINE t TEXT'),
    (Cat: 'Program'; Name: 'Varijabla (iznos)'; Hint: 'DEFINE iznos DECIMAL(10,2)'; Body: 'DEFINE iznos DECIMAL(10,2)'),
    (Cat: 'Tijek'; Name: 'Uvjet (IF)'; Hint: 'IF uvjet THEN ... END IF'; Body: 'IF n > 0 THEN|  LET n = n - 1|END IF'),
    (Cat: 'Tijek'; Name: 'Uvjet s ELSE'; Hint: 'IF ... ELSE ... END IF'; Body: 'IF n > 0 THEN|  LET n = n - 1|ELSE|  LET n = 0|END IF'),
    (Cat: 'Tijek'; Name: 'Izbor (CASE)'; Hint: 'CASE WHEN ... OTHERWISE ... END CASE'; Body: 'CASE|  WHEN n < 10|    LET n = 10|  OTHERWISE|    LET n = 0|END CASE'),
    (Cat: 'Tijek'; Name: 'Petlja (WHILE)'; Hint: 'WHILE uvjet ... END WHILE'; Body: 'WHILE n > 0|  LET n = n - 1|END WHILE'),
    (Cat: 'Tijek'; Name: 'Petlja (FOR)'; Hint: 'FOR i = 1 TO 10'; Body: 'FOR n = 1 TO 10|  DISPLAY n|END FOR'),
    (Cat: 'Tijek'; Name: 'Postavi vrijednost (LET)'; Hint: 'LET varijabla = izraz'; Body: 'LET n = n + 1'),
    (Cat: 'Tijek'; Name: 'Pozovi funkciju (CALL)'; Hint: 'CALL naziv()'; Body: 'CALL naziv()'),
    (Cat: 'Tijek'; Name: 'Izađi iz petlje (EXIT)'; Hint: 'EXIT WHILE / EXIT FOR / EXIT FOREACH'; Body: 'EXIT WHILE'),
    (Cat: 'Tijek'; Name: 'Vrati vrijednost (RETURN)'; Hint: 'RETURN izraz'; Body: 'RETURN n'),
    (Cat: 'Baza'; Name: 'Dohvati jednu vrijednost (SELECT INTO)'; Hint: 'SELECT ... INTO varijabla FROM tablica'; Body: 'SELECT COUNT(*) INTO n FROM racun'),
    (Cat: 'Baza'; Name: 'Prolaz kroz retke (kursor)'; Hint: 'DECLARE c CURSOR FOR SELECT ... FOREACH c INTO ...'; Body: 'DECLARE c CURSOR FOR SELECT iznos FROM racun|FOREACH c INTO iznos|  DISPLAY iznos|END FOREACH'),
    (Cat: 'Baza'; Name: 'Dodaj redak (INSERT)'; Hint: 'INSERT INTO tablica ...'; Body: 'INSERT INTO racun (kupac, iznos) VALUES ("Ana", 10)'),
    (Cat: 'Baza'; Name: 'Izmijeni (UPDATE)'; Hint: 'UPDATE tablica SET ... WHERE ...'; Body: 'UPDATE racun SET iznos = iznos * 2 WHERE placeno = 0'),
    (Cat: 'Baza'; Name: 'Briši (DELETE)'; Hint: 'DELETE FROM tablica WHERE ...'; Body: 'DELETE FROM racun WHERE placeno = 1'),
    (Cat: 'Baza'; Name: 'Transakcija'; Hint: 'BEGIN WORK ... COMMIT WORK'; Body: 'BEGIN WORK|  UPDATE racun SET placeno = 1 WHERE id = 1|COMMIT WORK'),
    (Cat: 'Ispis i unos'; Name: 'Ispiši (DISPLAY)'; Hint: 'DISPLAY "tekst", varijabla'; Body: 'DISPLAY "Vrijednost: ", n'),
    (Cat: 'Ispis i unos'; Name: 'Poruka (MESSAGE)'; Hint: 'MESSAGE "tekst"'; Body: 'MESSAGE "Gotovo"'),
    (Cat: 'Ispis i unos'; Name: 'Pogreška (ERROR)'; Hint: 'ERROR "tekst"'; Body: 'ERROR "Nešto nije u redu"'),
    (Cat: 'Ispis i unos'; Name: 'Pitaj za unos (PROMPT)'; Hint: 'PROMPT "pitanje" FOR varijabla'; Body: 'PROMPT "Naziv: " FOR t'),
    (Cat: 'Ispis i unos'; Name: 'Izbornik (MENU)'; Hint: 'MENU "naslov" COMMAND ... END MENU'; Body: 'MENU "Izbornik"|  COMMAND "Prvo" "Prva stavka"|    DISPLAY "prvo"|  COMMAND "Izlaz" "Kraj"|    EXIT MENU|END MENU'),
    (Cat: 'Ostalo'; Name: 'Komentar'; Hint: '-- komentar'; Body: '-- komentar'),
    (Cat: 'Ostalo'; Name: 'Nastavi pri pogrešci baze'; Hint: 'WHENEVER ERROR CONTINUE'; Body: 'WHENEVER ERROR CONTINUE'),
    (Cat: 'Ostalo'; Name: 'Prazan redak'; Hint: 'razmak'; Body: ''),
    (Cat: 'Ostalo'; Name: 'Poziv PascalScript modula'; Hint: 'pas.Funkcija(...)'; Body: 'LET n = pas.Pdv(100)'));

function FglTemplateCount: Integer;
begin
  Result := Length(Tpl);
end;

function FglTemplate(AIndex: Integer): TaFglTemplate;
begin
  Result := Tpl[AIndex];
end;

function FglCategoryCount: Integer;
begin
  Result := Length(Cats);
end;

function FglCategoryName(AIndex: Integer): string;
begin
  Result := Cats[AIndex];
end;

procedure FglTemplateLines(AIndex: Integer; ALines: TStrings);
var
  S: string;
  P: Integer;
begin
  ALines.Clear;
  S := Tpl[AIndex].Body;
  if S = '' then begin ALines.Add(''); Exit; end;
  repeat
    P := Pos('|', S);
    if P = 0 then begin ALines.Add(S); Break; end;
    ALines.Add(Copy(S, 1, P - 1));
    S := Copy(S, P + 1, MaxInt);
  until False;
end;

{ ---------------- model ---------------- }

function FirstTok(const ALine: string): string;
var
  I, J: Integer;
  S: string;
begin
  S := Trim(ALine);
  I := 1;
  J := I;
  while (J <= Length(S)) and (S[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(J);
  Result := UpperCase(Copy(S, I, J - I));
end;

function SecondTok(const ALine: string): string;
var
  S: string;
  I, J: Integer;
begin
  S := Trim(ALine);
  I := 1;
  while (I <= Length(S)) and (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(I);
  while (I <= Length(S)) and (S[I] in [' ', #9]) do Inc(I);
  J := I;
  while (J <= Length(S)) and (S[J] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(J);
  Result := UpperCase(Copy(S, I, J - I));
end;

constructor TaFglBlocks.Create;
begin
  FLines := TStringList.Create;
  FProblems := TStringList.Create;
end;

destructor TaFglBlocks.Destroy;
begin
  FLines.Free;
  FProblems.Free;
  inherited Destroy;
end;

function TaFglBlocks.GetCount: Integer;
begin
  Result := FLines.Count;
end;

procedure TaFglBlocks.LoadText(const AText: string);
begin
  FLines.Text := AText;
  Analyse;
end;

function TaFglBlocks.Text: string;
begin
  Result := FLines.Text;
end;

function TaFglBlocks.Raw(AIndex: Integer): string;
begin
  Result := FLines[AIndex];
end;

procedure TaFglBlocks.SetRaw(AIndex: Integer; const ALine: string);
begin
  FLines[AIndex] := ALine;
  Analyse;
end;

procedure TaFglBlocks.InsertLine(AIndex: Integer; const ALine: string);
begin
  if AIndex < 0 then AIndex := 0;
  if AIndex > FLines.Count then AIndex := FLines.Count;
  FLines.Insert(AIndex, ALine);
  Analyse;
end;

procedure TaFglBlocks.DeleteLine(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FLines.Count) then Exit;
  FLines.Delete(AIndex);
  Analyse;
end;

procedure TaFglBlocks.MoveLine(AFrom, ATo: Integer);
begin
  if (AFrom < 0) or (AFrom >= FLines.Count) then Exit;
  if ATo < 0 then ATo := 0;
  if ATo >= FLines.Count then ATo := FLines.Count - 1;
  FLines.Move(AFrom, ATo);
  Analyse;
end;

function TaFglBlocks.Kind(AIndex: Integer): TaFglKind;
begin
  Result := FKinds[AIndex];
end;

function TaFglBlocks.FirstWord(AIndex: Integer): string;
begin
  Result := FWord[AIndex];
end;

function TaFglBlocks.Depth(AIndex: Integer): Integer;
begin
  Result := FDepth[AIndex];
end;

function TaFglBlocks.OpenerOf(AIndex: Integer): Integer;
begin
  Result := FOpener[AIndex];
end;

function TaFglBlocks.CloserOf(AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := AIndex + 1 to FLines.Count - 1 do
    if (FKinds[I] = fkClose) and (FOpener[I] = AIndex) then Exit(I);
end;

function TaFglBlocks.Problems: TStringList;
begin
  Result := TStringList.Create;
  Result.Assign(FProblems);
end;

{ je li srednji dio dopusten unutar otvaraca AOpen }
function MidAllowed(const AOpen, AWord: string): Boolean;
begin
  if AOpen = 'IF' then Exit(AWord = 'ELSE');
  if AOpen = 'CASE' then Exit((AWord = 'WHEN') or (AWord = 'OTHERWISE'));
  if AOpen = 'MENU' then Exit((AWord = 'COMMAND') or (AWord = 'ON') or (AWord = 'BEFORE') or (AWord = 'AFTER'));
  if AOpen = 'REPORT' then Exit((AWord = 'FORMAT') or (AWord = 'PAGE') or (AWord = 'FIRST') or (AWord = 'ON') or (AWord = 'AFTER') or (AWord = 'BEFORE'));
  if AOpen = 'INPUT' then Exit((AWord = 'ON') or (AWord = 'BEFORE') or (AWord = 'AFTER'));
  Result := False;
end;

procedure TaFglBlocks.Analyse;
var
  N, I, K, Top, D: Integer;
  S, W, W2, Last: string;
  InBrace: Boolean;
  Stack: array of Integer;
  Need: TStringList;

  function EndsWithWord(const A, AWord: string): Boolean;
  var
    T: string;
  begin
    T := UpperCase(Trim(A));
    Result := (Length(T) > Length(AWord)) and (Copy(T, Length(T) - Length(AWord) + 1, Length(AWord)) = AWord) and
      (T[Length(T) - Length(AWord)] in [' ', #9]);
  end;

begin
  N := FLines.Count;
  SetLength(FKinds, N);
  SetLength(FWord, N);
  SetLength(FOpener, N);
  SetLength(FDepth, N);
  FProblems.Clear;
  SetLength(Stack, N + 1);
  Top := -1;
  InBrace := False;
  { koji END X postoje u programu: nejasni otvaraci (INPUT, MENU...) su otvaraci samo ako imaju svoj END }
  Need := TStringList.Create;
  try
    Need.Sorted := True;
    Need.Duplicates := dupIgnore;
    for I := 0 to N - 1 do
      if FirstTok(FLines[I]) = 'END' then Need.Add(SecondTok(FLines[I]));
    for I := 0 to N - 1 do
    begin
      S := Trim(FLines[I]);
      W := FirstTok(S);
      FWord[I] := W;
      FOpener[I] := -1;
      FDepth[I] := Top + 1;
      if InBrace then
      begin
        FKinds[I] := fkComment;
        if Pos('}', S) > 0 then InBrace := False;
        Continue;
      end;
      if S = '' then begin FKinds[I] := fkBlank; Continue; end;
      if (S[1] = '#') or (Copy(S, 1, 2) = '--') then begin FKinds[I] := fkComment; Continue; end;
      if S[1] = '{' then
      begin
        FKinds[I] := fkComment;
        if Pos('}', S) = 0 then InBrace := True;
        Continue;
      end;
      W2 := SecondTok(S);
      FKinds[I] := fkPlain;
      if W = 'END' then
      begin
        FKinds[I] := fkClose;
        if (Top >= 0) and ((FWord[Stack[Top]] = W2) or ((FWord[Stack[Top]] = 'DEFINE') and (W2 = 'RECORD'))) then
        begin
          FOpener[I] := Stack[Top];
          Dec(Top);
          FDepth[I] := Top + 1;
        end
        else
        begin
          FProblems.Add('Redak ' + IntToStr(I + 1) + ': "' + S + '" nema odgovarajući početak.');
          FDepth[I] := Top + 1;
        end;
        Continue;
      end;
      { otvaraci }
      if (W = 'MAIN') or (W = 'FUNCTION') or (W = 'REPORT') or (W = 'IF') or (W = 'WHILE') or (W = 'FOR') or (W = 'FOREACH') or (W = 'CASE') or (W = 'SCREEN') or
         ((W = 'GLOBALS') and (W2 = '') and (Pos('"', S) = 0)) or
         (((W = 'MENU') or (W = 'INPUT') or (W = 'CONSTRUCT')) and (Need.IndexOf(W) >= 0)) or
         ((W = 'DEFINE') and EndsWithWord(S, 'RECORD') and (Pos(' END RECORD', UpperCase(S)) = 0)) then
      begin
        FKinds[I] := fkOpen;
        Inc(Top);
        Stack[Top] := I;
        FDepth[I] := Top;
        Continue;
      end;
      { srednji dijelovi }
      if (Top >= 0) and MidAllowed(FWord[Stack[Top]], W) then
      begin
        FKinds[I] := fkMid;
        FOpener[I] := Stack[Top];
        FDepth[I] := Top;
        Continue;
      end;
      { IF unutar CASE ... vec je otvarac; ostalo je obicna naredba }
    end;
  finally
    Need.Free;
  end;
  for K := Top downto 0 do
    FProblems.Add('Redak ' + IntToStr(Stack[K] + 1) + ': "' + Trim(FLines[Stack[K]]) + '" nije zatvoren (nedostaje END).');
  { dubina za mid/close: u razini otvaraca vec je postavljena; plain unutar bloka = dubina otvorenih }
end;

end.
