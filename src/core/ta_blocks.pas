unit ta_blocks;
{ Blokovi za vizualno slaganje makroa. Model bez sucelja: makro-tekst <-> lista blokova,
  bez gubitka (nepromijenjeni blok cuva izvorni redak). Pravila citanja jednaka su onima
  u RunMacro (ta_script): prazni retci i komentari (# ili //), "stop", "if izraz then naredba",
  inace "naredba" ili "naredba: argument". }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs;

type
  TaBlockKind = (bkCommand, bkIf, bkStop, bkComment, bkBlank,
    bkIfBlock, bkElse, bkEndIf, bkWhile, bkEndWhile, bkRepeat, bkEndRepeat, bkLet);

  { vrsta argumenta naredbe: odreduje koji se alat nudi za unos }
  TaBlockArg = (baNone, baText, baSql, baExpr, baMacro, baForm, baReport, baProc, baControl, baFile, baAssign, baFetch);

  TaBlock = class
  public
    Kind: TaBlockKind;
    Verb, Arg: string;     { naredba i argument (bkCommand i akcija u bkIf; u bkIf "stop" je Verb = 'stop') }
    Cond: string;          { uvjet (bkIf, bkIfBlock, bkWhile), broj ponavljanja (bkRepeat), izraz (bkLet; ime varijable je u Arg) }
    Text: string;          { komentar bez oznake }
    Mark: string;          { oznaka komentara: '#' ili '//' }
    Raw: string;           { izvorni redak; prazno = generiraj iz polja }
    function Line: string; { redak makroa za ovaj blok }
    procedure Touch;       { blok je izmijenjen: odbaci izvorni redak }
  end;

  TIntArray = array of Integer;

  TaBlockProgram = class
  private
    FItems: TObjectList;
    function GetCount: Integer;
    function GetBlock(AIndex: Integer): TaBlock;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadText(const AText: string);
    function Text: string;
    function Add(ABlock: TaBlock): TaBlock;
    function Insert(AIndex: Integer; ABlock: TaBlock): TaBlock;
    procedure Delete(AIndex: Integer);
    { pomakni blok s FromIndex na ToIndex (nakon pomaka stoji na ToIndex) }
    procedure Move(AFromIndex, AToIndex: Integer);
    procedure Clear;
    { opisi problema (nepoznata naredba, if bez uvjeta, prazan argument...), jedan redak po problemu }
    function Problems: TStringList;
    { povezivanje blokova: za if/else/end if, while/end while, repeat/end repeat.
      Opener[i] = indeks bloka koji otvara (za else/end), ElseOf[i], EndOf[i] za otvarace; -1 = nema.
      False i AError (s brojem retka) ako struktura nije uskladena. }
    function Match(out AOpener, AElse, AEnd: TIntArray; out AError: string): Boolean;
    { dubina ugnjezdivanja bloka (za uvlacenje u prikazu) }
    function Depth(AIndex: Integer): Integer;
    property Count: Integer read GetCount;
    property Blocks[AIndex: Integer]: TaBlock read GetBlock; default;
  end;

{ jedan redak makroa -> blok }
function ParseBlockLine(const ALine: string): TaBlock;
function NewCommandBlock(const AVerb, AArg: string): TaBlock;
function NewIfBlock(const ACond, AVerb, AArg: string): TaBlock;
function NewCommentBlock(const AText: string): TaBlock;
function NewStopBlock: TaBlock;
function NewStructBlock(AKind: TaBlockKind; const ACond: string): TaBlock;
function NewLetBlock(const AName, AExpr: string): TaBlock;

{ paleta: naredbe koje makro razumije }
function BlockVerbCount: Integer;
function BlockVerbName(AIndex: Integer): string;
function BlockVerbArg(const AVerb: string): TaBlockArg;
function BlockVerbHint(const AVerb: string): string;
function BlockVerbKnown(const AVerb: string): Boolean;
{ kategorije palete i naredbe u njima }
function BlockCategoryCount: Integer;
function BlockCategoryName(AIndex: Integer): string;
function BlockVerbCategory(const AVerb: string): string;

implementation

type
  TVerbDef = record
    Name: string;
    Arg: TaBlockArg;
    Cat: string;
    Hint: string;
  end;

const
  Cats: array[0..4] of string = ('Tijek i poruke', 'Baza', 'Forma', 'Izvješće', 'Ostalo');
  Verbs: array[0..49] of TVerbDef = (
    (Name: 'msg'; Arg: baText; Cat: 'Tijek i poruke'; Hint: 'Prikaži poruku'),
    (Name: 'ask'; Arg: baText; Cat: 'Tijek i poruke'; Hint: 'Pitaj Da/Ne; odgovor je u [odgovor] (1 = Da)'),
    (Name: 'input'; Arg: baText; Cat: 'Tijek i poruke'; Hint: 'Pitaj za unos; tekst je u [unos]'),
    (Name: 'beep'; Arg: baNone; Cat: 'Tijek i poruke'; Hint: 'Zvučni signal'),
    (Name: 'macro'; Arg: baMacro; Cat: 'Tijek i poruke'; Hint: 'Pokreni drugi makro'),
    (Name: 'run4gl'; Arg: baText; Cat: 'Tijek i poruke'; Hint: 'Pokreni 4GL program spremljen u bazi (Skripta > 4GL programi); izlazni kod u [izlaz4gl]'),
    (Name: 'run'; Arg: baProc; Cat: 'Tijek i poruke'; Hint: 'Pozovi proceduru iz modula'),
    (Name: 'stop'; Arg: baNone; Cat: 'Tijek i poruke'; Hint: 'Prekini makro'),
    (Name: 'sql'; Arg: baSql; Cat: 'Baza'; Hint: 'Izvedi SQL naredbu ({varijabla} se ubacuje kao SQL vrijednost)'),
    (Name: 'fetch'; Arg: baFetch; Cat: 'Baza'; Hint: 'Dohvati vrijednost iz baze u varijablu: ime = SELECT ...'),
    (Name: 'copyrows'; Arg: baText; Cat: 'Baza'; Hint: 'Napravi dokument iz dokumenta: izvor WHERE uvjet -> cilj : polje = izraz, polje2 = izraz ... (novi id u [novi], broj redaka u [kopirano])'),
    (Name: 'importtable'; Arg: baFile; Cat: 'Baza'; Hint: 'Uvezi retke u postojeću tablicu: tablica < datoteka (.csv ili .xlsx, prvi redak su nazivi polja); [uvezeno], [preskoceno]'),
    (Name: 'exporttable'; Arg: baFile; Cat: 'Baza'; Hint: 'Izvezi tablicu ili upit: izvor > datoteka (.csv, .xlsx ili .json)'),
    (Name: 'copyfile'; Arg: baFile; Cat: 'Ostalo'; Hint: 'Kopiraj datoteku: izvor > odredište'),
    (Name: 'mailto'; Arg: baText; Cat: 'Ostalo'; Hint: 'Otvori novu poruku u programu za e-poštu: adresa ; predmet ; tekst'),
    (Name: 'compact'; Arg: baNone; Cat: 'Baza'; Hint: 'Provjeri i sažmi bazu; ishod se javlja porukom'),
    (Name: 'backup'; Arg: baFile; Cat: 'Baza'; Hint: 'Sigurnosna kopija baze u datoteku'),
    (Name: 'requery'; Arg: baNone; Cat: 'Baza'; Hint: 'Ponovo pročitaj podatke'),
    (Name: 'refresh'; Arg: baNone; Cat: 'Baza'; Hint: 'Ponovo pročitaj podatke'),
    (Name: 'filter'; Arg: baExpr; Cat: 'Baza'; Hint: 'Postavi filter forme (SQL uvjet)'),
    (Name: 'nofilter'; Arg: baNone; Cat: 'Baza'; Hint: 'Ukini filter'),
    (Name: 'save'; Arg: baNone; Cat: 'Forma'; Hint: 'Spremi zapis'),
    (Name: 'undo'; Arg: baNone; Cat: 'Forma'; Hint: 'Poništi nespremljene promjene'),
    (Name: 'new'; Arg: baNone; Cat: 'Forma'; Hint: 'Novi zapis'),
    (Name: 'duplicate'; Arg: baNone; Cat: 'Forma'; Hint: 'Kopiraj zapis'),
    (Name: 'delete'; Arg: baNone; Cat: 'Forma'; Hint: 'Briši zapis'),
    (Name: 'first'; Arg: baNone; Cat: 'Forma'; Hint: 'Prvi zapis'),
    (Name: 'prev'; Arg: baNone; Cat: 'Forma'; Hint: 'Prethodni zapis'),
    (Name: 'prior'; Arg: baNone; Cat: 'Forma'; Hint: 'Prethodni zapis'),
    (Name: 'next'; Arg: baNone; Cat: 'Forma'; Hint: 'Sljedeći zapis'),
    (Name: 'last'; Arg: baNone; Cat: 'Forma'; Hint: 'Zadnji zapis'),
    (Name: 'set'; Arg: baAssign; Cat: 'Forma'; Hint: 'Upiši vrijednost u polje: polje = izraz'),
    (Name: 'visible'; Arg: baAssign; Cat: 'Forma'; Hint: 'Prikaži/sakrij kontrolu: kontrola = izraz (1 prikaži, 0 sakrij)'),
    (Name: 'enabled'; Arg: baAssign; Cat: 'Forma'; Hint: 'Omogući/onemogući kontrolu: kontrola = izraz'),
    (Name: 'caption'; Arg: baAssign; Cat: 'Forma'; Hint: 'Promijeni natpis kontrole: kontrola = izraz'),
    (Name: 'find'; Arg: baAssign; Cat: 'Forma'; Hint: 'Postavi se na prvi zapis s vrijednošću: polje = izraz'),
    (Name: 'gotorecord'; Arg: baExpr; Cat: 'Forma'; Hint: 'Idi na zapis s rednim brojem (izraz; 1 = prvi)'),
    (Name: 'sort'; Arg: baText; Cat: 'Forma'; Hint: 'Poredaj prikaz po polju: polje [DESC], polje2 …'),
    (Name: 'goto'; Arg: baControl; Cat: 'Forma'; Hint: 'Premjesti fokus na kontrolu'),
    (Name: 'openform'; Arg: baForm; Cat: 'Forma'; Hint: 'Otvori formu'),
    (Name: 'close'; Arg: baNone; Cat: 'Forma'; Hint: 'Zatvori formu'),
    (Name: 'export'; Arg: baFile; Cat: 'Forma'; Hint: 'Izvezi prikaz forme u CSV'),
    (Name: 'audit'; Arg: baNone; Cat: 'Forma'; Hint: 'Povijest promjena zapisa'),
    (Name: 'openreport'; Arg: baReport; Cat: 'Izvješće'; Hint: 'Otvori izvješće (ime, ime@uvjet, ime#poredak=Naziv)'),
    (Name: 'exportpdf'; Arg: baReport; Cat: 'Izvješće'; Hint: 'Izvješće u PDF: ime > datoteka.pdf'),
    (Name: 'openletter'; Arg: baText; Cat: 'Izvješće'; Hint: 'Pregled dopisa: Naziv ili Naziv@ključ (jedan primatelj)'),
    (Name: 'exportletter'; Arg: baText; Cat: 'Izvješće'; Hint: 'Dopis u datoteku: Naziv > datoteka.docx (Word), .pdf ili .html'),
    (Name: 'exporthtml'; Arg: baReport; Cat: 'Izvješće'; Hint: 'Izvješće u HTML: ime > datoteka.html'),
    (Name: 'wait'; Arg: baText; Cat: 'Ostalo'; Hint: 'Pričekaj zadani broj sekundi (najviše 60)'),
    (Name: 'openurl'; Arg: baText; Cat: 'Ostalo'; Hint: 'Otvori adresu ili datoteku u pregledniku'));

function VerbIndex(const AVerb: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(Verbs) to High(Verbs) do
    if SameText(Verbs[I].Name, AVerb) then Exit(I);
end;

function BlockVerbCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Verbs) to High(Verbs) do
    if Verbs[I].Hint <> '' then Inc(Result);
end;

function BlockVerbName(AIndex: Integer): string;
var
  I, N: Integer;
begin
  Result := '';
  N := -1;
  for I := Low(Verbs) to High(Verbs) do
    if Verbs[I].Hint <> '' then
    begin
      Inc(N);
      if N = AIndex then Exit(Verbs[I].Name);
    end;
end;

function BlockVerbArg(const AVerb: string): TaBlockArg;
var
  I: Integer;
begin
  I := VerbIndex(AVerb);
  if I < 0 then Result := baText else Result := Verbs[I].Arg;
end;

function BlockVerbHint(const AVerb: string): string;
var
  I: Integer;
begin
  I := VerbIndex(AVerb);
  if I < 0 then Result := '' else Result := Verbs[I].Hint;
end;

function BlockVerbKnown(const AVerb: string): Boolean;
begin
  Result := (VerbIndex(AVerb) >= 0) and (Verbs[VerbIndex(AVerb)].Hint <> '');
end;

function BlockCategoryCount: Integer;
begin
  Result := Length(Cats);
end;

function BlockCategoryName(AIndex: Integer): string;
begin
  Result := Cats[AIndex];
end;

function BlockVerbCategory(const AVerb: string): string;
var
  I: Integer;
begin
  I := VerbIndex(AVerb);
  if I < 0 then Result := '' else Result := Verbs[I].Cat;
end;

{ naredba "verb: arg" kao u DoAction }
procedure SplitAction(const AAction: string; out AVerb, AArg: string);
var
  A: string;
  P: Integer;
begin
  A := Trim(AAction);
  P := Pos(':', A);
  if P > 0 then
  begin
    AVerb := LowerCase(Trim(Copy(A, 1, P - 1)));
    AArg := Trim(Copy(A, P + 1, MaxInt));
  end
  else
  begin
    AVerb := LowerCase(A);
    AArg := '';
  end;
end;

function ActionText(const AVerb, AArg: string): string;
begin
  if AArg = '' then Result := AVerb else Result := AVerb + ': ' + AArg;
end;

function TaBlock.Line: string;
begin
  if Raw <> '' then Exit(Raw);
  case Kind of
    bkBlank: Result := '';
    bkStop: Result := 'stop';
    bkComment: Result := Trim(Mark + ' ' + Text);
    bkIf: Result := 'if ' + Cond + ' then ' + ActionText(Verb, Arg);
    bkIfBlock: Result := 'if ' + Cond;
    bkElse: Result := 'else';
    bkEndIf: Result := 'end if';
    bkWhile: Result := 'while ' + Cond;
    bkEndWhile: Result := 'end while';
    bkRepeat: Result := 'repeat ' + Cond;
    bkEndRepeat: Result := 'end repeat';
    bkLet: Result := 'let ' + Arg + ' = ' + Cond;
  else
    Result := ActionText(Verb, Arg);
  end;
  if (Kind = bkComment) and (Mark = '') then Result := '# ' + Text;
end;

procedure TaBlock.Touch;
begin
  Raw := '';
end;

function ParseBlockLine(const ALine: string): TaBlock;
var
  Line, Low: string;
  P: Integer;
begin
  Result := TaBlock.Create;
  Result.Raw := ALine;
  Line := Trim(ALine);
  Low := LowerCase(Line);
  if Line = '' then
    Result.Kind := bkBlank
  else if Line[1] = '#' then
  begin
    Result.Kind := bkComment; Result.Mark := '#'; Result.Text := Trim(Copy(Line, 2, MaxInt));
  end
  else if Copy(Line, 1, 2) = '//' then
  begin
    Result.Kind := bkComment; Result.Mark := '//'; Result.Text := Trim(Copy(Line, 3, MaxInt));
  end
  else if Low = 'stop' then
    Result.Kind := bkStop
  else if Low = 'else' then
    Result.Kind := bkElse
  else if (Low = 'end if') or (Low = 'endif') then
    Result.Kind := bkEndIf
  else if (Low = 'end while') or (Low = 'wend') then
    Result.Kind := bkEndWhile
  else if (Low = 'end repeat') or (Low = 'endrepeat') then
    Result.Kind := bkEndRepeat
  else if Copy(Low, 1, 6) = 'while ' then
  begin
    Result.Kind := bkWhile; Result.Cond := Trim(Copy(Line, 7, MaxInt));
  end
  else if Copy(Low, 1, 7) = 'repeat ' then
  begin
    Result.Kind := bkRepeat; Result.Cond := Trim(Copy(Line, 8, MaxInt));
  end
  else if Copy(Low, 1, 4) = 'let ' then
  begin
    Result.Kind := bkLet;
    P := Pos('=', Line);
    if P = 0 then Result.Arg := Trim(Copy(Line, 5, MaxInt))
    else
    begin
      Result.Arg := Trim(Copy(Line, 5, P - 5));
      Result.Cond := Trim(Copy(Line, P + 1, MaxInt));
    end;
  end
  else if Copy(Low, 1, 3) = 'if ' then
  begin
    P := Pos(' then ', Low);
    if P = 0 then
    begin
      { "if uvjet" bez "then": blok koji se zatvara s "end if" }
      Result.Kind := bkIfBlock;
      Result.Cond := Trim(Copy(Line, 4, MaxInt));
    end
    else
    begin
      Result.Kind := bkIf;
      Result.Cond := Trim(Copy(Line, 4, P - 4));
      SplitAction(Copy(Line, P + 6, MaxInt), Result.Verb, Result.Arg);
    end;
  end
  else
  begin
    Result.Kind := bkCommand;
    SplitAction(Line, Result.Verb, Result.Arg);
  end;
end;

function NewCommandBlock(const AVerb, AArg: string): TaBlock;
begin
  Result := TaBlock.Create;
  if LowerCase(AVerb) = 'stop' then Result.Kind := bkStop
  else Result.Kind := bkCommand;
  Result.Verb := LowerCase(AVerb);
  Result.Arg := AArg;
end;

function NewIfBlock(const ACond, AVerb, AArg: string): TaBlock;
begin
  Result := TaBlock.Create;
  Result.Kind := bkIf;
  Result.Cond := ACond;
  Result.Verb := LowerCase(AVerb);
  Result.Arg := AArg;
end;

function NewCommentBlock(const AText: string): TaBlock;
begin
  Result := TaBlock.Create;
  Result.Kind := bkComment;
  Result.Mark := '#';
  Result.Text := AText;
end;

function NewStructBlock(AKind: TaBlockKind; const ACond: string): TaBlock;
begin
  Result := TaBlock.Create;
  Result.Kind := AKind;
  Result.Cond := ACond;
end;

function NewLetBlock(const AName, AExpr: string): TaBlock;
begin
  Result := TaBlock.Create;
  Result.Kind := bkLet;
  Result.Arg := AName;
  Result.Cond := AExpr;
end;

function NewStopBlock: TaBlock;
begin
  Result := TaBlock.Create;
  Result.Kind := bkStop;
  Result.Verb := 'stop';
end;

constructor TaBlockProgram.Create;
begin
  FItems := TObjectList.Create(True);
end;

destructor TaBlockProgram.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TaBlockProgram.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TaBlockProgram.GetBlock(AIndex: Integer): TaBlock;
begin
  Result := TaBlock(FItems[AIndex]);
end;

procedure TaBlockProgram.Clear;
begin
  FItems.Clear;
end;

procedure TaBlockProgram.LoadText(const AText: string);
var
  L: TStringList;
  I: Integer;
begin
  FItems.Clear;
  L := TStringList.Create;
  try
    L.Text := AText;
    for I := 0 to L.Count - 1 do FItems.Add(ParseBlockLine(L[I]));
  finally
    L.Free;
  end;
end;

function TaBlockProgram.Text: string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    for I := 0 to FItems.Count - 1 do L.Add(GetBlock(I).Line);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

function TaBlockProgram.Add(ABlock: TaBlock): TaBlock;
begin
  FItems.Add(ABlock);
  Result := ABlock;
end;

function TaBlockProgram.Insert(AIndex: Integer; ABlock: TaBlock): TaBlock;
begin
  if AIndex < 0 then AIndex := 0;
  if AIndex > FItems.Count then AIndex := FItems.Count;
  FItems.Insert(AIndex, ABlock);
  Result := ABlock;
end;

procedure TaBlockProgram.Delete(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FItems.Count) then FItems.Delete(AIndex);
end;

procedure TaBlockProgram.Move(AFromIndex, AToIndex: Integer);
begin
  if (AFromIndex < 0) or (AFromIndex >= FItems.Count) then Exit;
  if AToIndex < 0 then AToIndex := 0;
  if AToIndex >= FItems.Count then AToIndex := FItems.Count - 1;
  FItems.Move(AFromIndex, AToIndex);
end;

function TaBlockProgram.Match(out AOpener, AElse, AEnd: TIntArray; out AError: string): Boolean;
var
  I, Top, N: Integer;
  St: array of Integer;
  K: TaBlockKind;

  function Name(AK: TaBlockKind): string;
  begin
    case AK of
      bkIfBlock: Result := 'if';
      bkWhile: Result := 'while';
    else
      Result := 'repeat';
    end;
  end;

begin
  Result := False;
  AError := '';
  N := FItems.Count;
  SetLength(AOpener, N);
  SetLength(AElse, N);
  SetLength(AEnd, N);
  SetLength(St, N + 1);
  Top := -1;
  for I := 0 to N - 1 do begin AOpener[I] := -1; AElse[I] := -1; AEnd[I] := -1; end;
  for I := 0 to N - 1 do
  begin
    K := GetBlock(I).Kind;
    case K of
      bkIfBlock, bkWhile, bkRepeat:
        begin
          Inc(Top); St[Top] := I;
        end;
      bkElse:
        begin
          if (Top < 0) or (GetBlock(St[Top]).Kind <> bkIfBlock) or (AElse[St[Top]] >= 0) then
          begin AError := 'Redak ' + IntToStr(I + 1) + ': "else" bez odgovarajućeg "if".'; Exit; end;
          AElse[St[Top]] := I; AOpener[I] := St[Top];
        end;
      bkEndIf, bkEndWhile, bkEndRepeat:
        begin
          if (Top < 0) or
             ((K = bkEndIf) and (GetBlock(St[Top]).Kind <> bkIfBlock)) or
             ((K = bkEndWhile) and (GetBlock(St[Top]).Kind <> bkWhile)) or
             ((K = bkEndRepeat) and (GetBlock(St[Top]).Kind <> bkRepeat)) then
          begin AError := 'Redak ' + IntToStr(I + 1) + ': "' + GetBlock(I).Line + '" nema odgovarajući početak bloka.'; Exit; end;
          AEnd[St[Top]] := I; AOpener[I] := St[Top];
          Dec(Top);
        end;
    end;
  end;
  if Top >= 0 then
  begin
    AError := 'Redak ' + IntToStr(St[Top] + 1) + ': blok "' + Name(GetBlock(St[Top]).Kind) + '" nije zatvoren (nedostaje "end ' + Name(GetBlock(St[Top]).Kind) + '"; jednoredni uvjet treba "then").';
    Exit;
  end;
  Result := True;
end;

function TaBlockProgram.Depth(AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to AIndex - 1 do
    case GetBlock(I).Kind of
      bkIfBlock, bkWhile, bkRepeat: Inc(Result);
      bkEndIf, bkEndWhile, bkEndRepeat: Dec(Result);
    end;
  if Result < 0 then Result := 0;
  { else i end stoje u razini otvaraca }
  if (AIndex >= 0) and (AIndex < FItems.Count) and
     (GetBlock(AIndex).Kind in [bkElse, bkEndIf, bkEndWhile, bkEndRepeat]) and (Result > 0) then Dec(Result);
end;

function TaBlockProgram.Problems: TStringList;
var
  I: Integer;
  B: TaBlock;
  Pre, Err: string;
  Op, El, En: TIntArray;
begin
  Result := TStringList.Create;
  for I := 0 to FItems.Count - 1 do
  begin
    B := GetBlock(I);
    Pre := 'Redak ' + IntToStr(I + 1) + ': ';
    case B.Kind of
      bkIf:
        begin
          if B.Verb = '' then Result.Add(Pre + 'nedostaje "then" i naredba')
          else if (B.Cond = '') then Result.Add(Pre + 'uvjet je prazan');
          if (B.Verb <> '') and not BlockVerbKnown(B.Verb) then Result.Add(Pre + 'nepoznata naredba "' + B.Verb + '"');
        end;
      bkIfBlock, bkWhile:
        if B.Cond = '' then Result.Add(Pre + 'uvjet je prazan');
      bkRepeat:
        if B.Cond = '' then Result.Add(Pre + 'nedostaje broj ponavljanja');
      bkLet:
        if (B.Arg = '') or (B.Cond = '') then Result.Add(Pre + 'let traži oblik: let ime = izraz');
      bkCommand:
        begin
          if not BlockVerbKnown(B.Verb) then Result.Add(Pre + 'nepoznata naredba "' + B.Verb + '"')
          else if (BlockVerbArg(B.Verb) <> baNone) and (B.Arg = '') then Result.Add(Pre + 'naredba "' + B.Verb + '" traži argument')
          else if (BlockVerbArg(B.Verb) in [baAssign, baFetch]) and (Pos('=', B.Arg) = 0) then Result.Add(Pre + 'naredba "' + B.Verb + '" traži oblik: ime = izraz');
        end;
    end;
  end;
  if not Match(Op, El, En, Err) then Result.Add(Err);
end;

end.
