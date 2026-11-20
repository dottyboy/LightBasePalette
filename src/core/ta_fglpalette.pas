unit ta_fglpalette;
{ Paleta 4GL blokova s poljima koja su padajuci popisi iz baze (poglavlje 11.2 plana).
  Blok je predlozak od jednog ili vise redaka s utorima {ime}. Bez sucelja:
    RenderBlock    blok + vrijednosti -> retci 4GL-a
    MatchLine      redak 4GL-a -> koji je to blok i koje su vrijednosti (dvosmjerno)
    SlotChoices    popis ponudenih vrijednosti utora (tablice, stupci, programi, forme, varijable, izvjesca)
    AnnotateLog    poruke parsera dobivaju naziv bloka kojem redak pripada (greske pokazuju na blok) }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, ta_meta, ta_wizardgen;

type
  TaPSlotKind = (pkTekst, pkIzraz, pkTablica, pkStupac, pkStupci, pkProgram, pkForma, pkVarijabla, pkIzvjesce, pkOdrediste);

  TaPSlot = record
    Name: string;
    Kind: TaPSlotKind;
    Ref: string;          { naziv utora s tablicom (za stupce) }
    Default: string;
    Prompt: string;
  end;

  TaPBlock = record
    Id, Cat, Name, Hint: string;
    Slots: array of TaPSlot;
    Body: string;         { retci odvojeni znakom |; uvlaka dva razmaka po razini }
  end;

function PaletteCount: Integer;
function PaletteBlock(AIndex: Integer): TaPBlock;
function PaletteFind(const AId: string): Integer;
function PaletteCategories: TStringList;      { poziva se Free }
function SlotIndex(const ABlock: TaPBlock; const AName: string): Integer;

{ ProgramText = tekst programa u kojem se blok umece (za varijable i izvjesca) }
procedure SlotChoices(ADb: TAppDb; const ABlock: TaPBlock; const ASlot: string; AValues: TStrings;
  const AProgramText: string; AOut: TStrings);
{ zadane vrijednosti: prva tablica, njezini stupci, prvi program... }
procedure BlockDefaults(ADb: TAppDb; const ABlock: TaPBlock; AValues: TStrings; const AProgramText: string);
procedure RenderBlock(const ABlock: TaPBlock; AValues: TStrings; ALines: TStrings);
{ prepoznaje prvi redak bloka; AIndex = -1 ako ne odgovara ni jednom }
function MatchLine(const ALine: string; out AValues: TStringList): Integer;
{ "prog.4gl:7: poruka" -> "Blok «Naziv» (redak 7): poruka"; redak bez bloka ostaje isti }
procedure AnnotateLog(const AProgramText: string; ALog: TStrings);

implementation

const
  Blocks: array[0..18] of record
    Id, Cat, Name, Hint, Slots, Body: string;
  end = (
    (Id: 'main'; Cat: 'Program'; Name: 'Glavni program'; Hint: 'MAIN ... END MAIN'; Slots: '';
     Body: 'MAIN|  DISPLAY "Pozdrav"|END MAIN'),
    (Id: 'zapis'; Cat: 'Program'; Name: 'Zapis tablice'; Hint: 'DEFINE r RECORD LIKE tablica.*'; Slots: 'zapis:tekst:r;tablica:tablica';
     Body: 'DEFINE {zapis} RECORD LIKE {tablica}.*'),
    (Id: 'varijabla'; Cat: 'Program'; Name: 'Varijabla'; Hint: 'DEFINE ime tip'; Slots: 'ime:tekst:n;tip:tekst:INTEGER';
     Body: 'DEFINE {ime} {tip}'),
    (Id: 'otvori'; Cat: 'Baza'; Name: 'Otvori tablicu'; Hint: 'DECLARE kursor CURSOR FOR SELECT * FROM tablica';
     Slots: 'kursor:tekst:c;tablica:tablica';
     Body: 'DECLARE {kursor} CURSOR FOR SELECT * FROM {tablica}'),
    (Id: 'otvorifilter'; Cat: 'Baza'; Name: 'Otvori tablicu s filtrom po stupcu'; Hint: 'SELECT ... WHERE stupac = $varijabla';
     Slots: 'kursor:tekst:c;tablica:tablica;stupac:stupac(tablica);varijabla:varijabla';
     Body: 'DECLARE {kursor} CURSOR FOR SELECT * FROM {tablica} WHERE {stupac} = ${varijabla}'),
    (Id: 'zasvaki'; Cat: 'Baza'; Name: 'Za svaki redak'; Hint: 'FOREACH kursor INTO zapis.* ... END FOREACH';
     Slots: 'kursor:tekst:c;zapis:varijabla';
     Body: 'FOREACH {kursor} INTO {zapis}.*|  DISPLAY {zapis}.*|END FOREACH'),
    (Id: 'upisi'; Cat: 'Baza'; Name: 'Upiši u tablicu'; Hint: 'INSERT INTO tablica (stupci) VALUES (vrijednosti)';
     Slots: 'tablica:tablica;stupci:stupci(tablica);vrijednosti:izraz';
     Body: 'INSERT INTO {tablica} ({stupci}) VALUES ({vrijednosti})'),
    (Id: 'ako'; Cat: 'Tijek'; Name: 'Ako'; Hint: 'IF uvjet THEN ... END IF'; Slots: 'uvjet:izraz';
     Body: 'IF {uvjet} THEN|  DISPLAY "da"|END IF'),
    (Id: 'postavi'; Cat: 'Tijek'; Name: 'Postavi varijablu'; Hint: 'LET varijabla = izraz'; Slots: 'varijabla:varijabla;izraz:izraz';
     Body: 'LET {varijabla} = {izraz}'),
    (Id: 'pitaj'; Cat: 'Ispis i unos'; Name: 'Pitaj korisnika'; Hint: 'PROMPT "pitanje" FOR varijabla'; Slots: 'pitanje:tekst:Unos;varijabla:varijabla';
     Body: 'PROMPT "{pitanje}" FOR {varijabla}'),
    (Id: 'prikazi'; Cat: 'Ispis i unos'; Name: 'Prikaži'; Hint: 'DISPLAY izrazi'; Slots: 'izraz:izraz';
     Body: 'DISPLAY {izraz}'),
    (Id: 'izvjesce'; Cat: 'Izvješća'; Name: 'Izvješće nad tablicom'; Hint: 'REPORT naziv(r) ... END REPORT';
     Slots: 'naziv:tekst:popis;tablica:tablica;stupci:stupci(tablica)';
     Body: 'REPORT {naziv}(r)|  DEFINE r RECORD LIKE {tablica}.*|  OUTPUT PAGE LENGTH 60|  FORMAT|    PAGE HEADER|      PRINT "{tablica}", COLUMN 60, "Str. ", PAGENO|      SKIP 1 LINES|    ON EVERY ROW|      PRINT {stupci:r}|END REPORT'),
    (Id: 'pokreniizv'; Cat: 'Izvješća'; Name: 'Pokreni izvješće'; Hint: 'START REPORT naziv TO SCREEN'; Slots: 'izvjesce:izvjesce';
     Body: 'START REPORT {izvjesce} TO SCREEN'),
    (Id: 'pdf'; Cat: 'Izvješća'; Name: 'Izvezi u PDF'; Hint: 'START REPORT naziv TO PDF "datoteka"'; Slots: 'izvjesce:izvjesce;datoteka:tekst:izvjesce.pdf';
     Body: 'START REPORT {izvjesce} TO PDF "{datoteka}"'),
    (Id: 'redakizv'; Cat: 'Izvješća'; Name: 'Redak u izvješće'; Hint: 'OUTPUT TO REPORT naziv(zapis.*)'; Slots: 'izvjesce:izvjesce;zapis:varijabla';
     Body: 'OUTPUT TO REPORT {izvjesce}({zapis}.*)'),
    (Id: 'zavrsiizv'; Cat: 'Izvješća'; Name: 'Završi izvješće'; Hint: 'FINISH REPORT naziv'; Slots: 'izvjesce:izvjesce';
     Body: 'FINISH REPORT {izvjesce}'),
    (Id: 'pozovi'; Cat: 'Program'; Name: 'Pozovi program'; Hint: 'CALL program()'; Slots: 'program:program';
     Body: 'CALL {program}()'),
    (Id: 'forma'; Cat: 'Ispis i unos'; Name: 'Otvori formu'; Hint: 'OPEN FORM ime FROM "forma"'; Slots: 'ime:tekst:f;forma:forma';
     Body: 'OPEN FORM {ime} FROM "{forma}"'),
    (Id: 'vrati'; Cat: 'Tijek'; Name: 'Vrati vrijednost'; Hint: 'RETURN izraz'; Slots: 'izraz:izraz';
     Body: 'RETURN {izraz}'));

function ParseSlots(const S: string): TaPBlock;
var
  Parts, F: TStringList;
  I, P: Integer;
  K: string;
begin
  SetLength(Result.Slots, 0);
  if S = '' then Exit;
  Parts := TStringList.Create;
  F := TStringList.Create;
  try
    Parts.Delimiter := ';';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := S;
    SetLength(Result.Slots, Parts.Count);
    for I := 0 to Parts.Count - 1 do
    begin
      F.Delimiter := ':';
      F.StrictDelimiter := True;
      F.DelimitedText := Parts[I];
      Result.Slots[I].Name := F[0];
      Result.Slots[I].Ref := '';
      Result.Slots[I].Default := '';
      Result.Slots[I].Prompt := F[0];
      K := '';
      if F.Count > 1 then K := F[1];
      P := Pos('(', K);
      if P > 0 then
      begin
        Result.Slots[I].Ref := Copy(K, P + 1, Length(K) - P - 1);
        K := Copy(K, 1, P - 1);
      end;
      if K = 'tablica' then Result.Slots[I].Kind := pkTablica
      else if K = 'stupac' then Result.Slots[I].Kind := pkStupac
      else if K = 'stupci' then Result.Slots[I].Kind := pkStupci
      else if K = 'program' then Result.Slots[I].Kind := pkProgram
      else if K = 'forma' then Result.Slots[I].Kind := pkForma
      else if K = 'varijabla' then Result.Slots[I].Kind := pkVarijabla
      else if K = 'izvjesce' then Result.Slots[I].Kind := pkIzvjesce
      else if K = 'izraz' then Result.Slots[I].Kind := pkIzraz
      else Result.Slots[I].Kind := pkTekst;
      if (F.Count > 2) and (Result.Slots[I].Kind in [pkTekst, pkIzraz]) then Result.Slots[I].Default := F[2];
    end;
  finally
    Parts.Free;
    F.Free;
  end;
end;

function PaletteCount: Integer;
begin
  Result := Length(Blocks);
end;

function PaletteBlock(AIndex: Integer): TaPBlock;
begin
  Result := ParseSlots(Blocks[AIndex].Slots);
  Result.Id := Blocks[AIndex].Id;
  Result.Cat := Blocks[AIndex].Cat;
  Result.Name := Blocks[AIndex].Name;
  Result.Hint := Blocks[AIndex].Hint;
  Result.Body := Blocks[AIndex].Body;
end;

function PaletteFind(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Blocks) do
    if SameText(Blocks[I].Id, AId) then Exit(I);
  Result := -1;
end;

function PaletteCategories: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(Blocks) do
    if Result.IndexOf(Blocks[I].Cat) < 0 then Result.Add(Blocks[I].Cat);
end;

function SlotIndex(const ABlock: TaPBlock; const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(ABlock.Slots) do
    if SameText(ABlock.Slots[I].Name, AName) then Exit(I);
  Result := -1;
end;

{ nazivi koje program vec ima: DEFINE a, b TIP / DEFINE r RECORD ... ; REPORT naziv( }
procedure ScanProgram(const AText: string; AVars, AReports: TStrings);
var
  L: TStringList;
  I, P: Integer;
  S, U, Names: string;
  Parts: TStringList;
  J: Integer;
begin
  L := TStringList.Create;
  Parts := TStringList.Create;
  try
    L.Text := AText;
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      U := UpperCase(S);
      if Copy(U, 1, 7) = 'DEFINE ' then
      begin
        Names := Copy(S, 8, MaxInt);
        { odrezi tip: prva rijec nakon zareza-popisa }
        P := Pos(' ', Trim(Names));
        if Pos(',', Names) > 0 then
        begin
          { "a, b TIP": tip je iza zadnjeg razmaka }
          P := LastDelimiter(' ', Trim(Names));
          if P > 0 then Names := Copy(Trim(Names), 1, P - 1);
        end
        else if P > 0 then Names := Copy(Trim(Names), 1, P - 1);
        Parts.CommaText := StringReplace(Names, ' ', '', [rfReplaceAll]);
        for J := 0 to Parts.Count - 1 do
          if (Parts[J] <> '') and (AVars.IndexOf(Parts[J]) < 0) then AVars.Add(Parts[J]);
      end
      else if Copy(U, 1, 7) = 'REPORT ' then
      begin
        Names := Copy(S, 8, MaxInt);
        P := Pos('(', Names);
        if P > 0 then Names := Copy(Names, 1, P - 1);
        Names := Trim(Names);
        if (Names <> '') and (AReports.IndexOf(Names) < 0) then AReports.Add(Names);
      end;
    end;
  finally
    L.Free;
    Parts.Free;
  end;
end;

procedure SlotChoices(ADb: TAppDb; const ABlock: TaPBlock; const ASlot: string; AValues: TStrings;
  const AProgramText: string; AOut: TStrings);
var
  K, I: Integer;
  Sl: TaPSlot;
  T, V, R: TStringList;
  Cols: TaSourceFields;
  Tab: string;
begin
  AOut.Clear;
  K := SlotIndex(ABlock, ASlot);
  if K < 0 then Exit;
  Sl := ABlock.Slots[K];
  case Sl.Kind of
    pkTablica:
      begin
        T := ADb.UserTables;
        try AOut.AddStrings(T); finally T.Free; end;
      end;
    pkStupac, pkStupci:
      begin
        Tab := AValues.Values[Sl.Ref];
        if Tab <> '' then
        begin
          Cols := SourceFieldList(ADb, Tab);
          for I := 0 to High(Cols) do AOut.Add(Cols[I].Name);
        end;
      end;
    pkProgram:
      begin
        T := ADb.ListObjects('_sys_programs');
        try AOut.AddStrings(T); finally T.Free; end;
      end;
    pkForma:
      begin
        T := ADb.ListObjects('_sys_forms');
        try AOut.AddStrings(T); finally T.Free; end;
      end;
    pkVarijabla, pkIzvjesce:
      begin
        V := TStringList.Create;
        R := TStringList.Create;
        try
          ScanProgram(AProgramText, V, R);
          if Sl.Kind = pkVarijabla then AOut.AddStrings(V) else AOut.AddStrings(R);
        finally
          V.Free;
          R.Free;
        end;
      end;
  end;
end;

procedure BlockDefaults(ADb: TAppDb; const ABlock: TaPBlock; AValues: TStrings; const AProgramText: string);
var
  I, J: Integer;
  Ch: TStringList;
  Sl: TaPSlot;
  V: string;
begin
  Ch := TStringList.Create;
  try
    for I := 0 to High(ABlock.Slots) do
    begin
      Sl := ABlock.Slots[I];
      if AValues.Values[Sl.Name] <> '' then Continue;
      V := Sl.Default;
      SlotChoices(ADb, ABlock, Sl.Name, AValues, AProgramText, Ch);
      case Sl.Kind of
        pkTablica, pkProgram, pkForma, pkVarijabla, pkIzvjesce:
          if Ch.Count > 0 then V := Ch[0];
        pkStupac:
          if Ch.Count > 1 then V := Ch[1] else if Ch.Count > 0 then V := Ch[0];
        pkStupci:
          begin
            V := '';
            { svi osim prvog (kljuca), odvojeni zarezom }
            for J := 1 to Ch.Count - 1 do V := V + IfThen(V = '', '', ', ') + Ch[J];
            if V = '' then V := Ch.CommaText;
          end;
      end;
      if V <> '' then AValues.Values[Sl.Name] := V;
    end;
  finally
    Ch.Free;
  end;
end;

{ "a, b" -> "r.a, r.b" }
function PrefixList(const AList: string): string;
var
  L: TStringList;
  I: Integer;
begin
  Result := '';
  L := TStringList.Create;
  try
    L.CommaText := StringReplace(AList, ' ', '', [rfReplaceAll]);
    for I := 0 to L.Count - 1 do Result := Result + IfThen(Result = '', '', ', ') + 'r.' + L[I];
  finally
    L.Free;
  end;
end;

procedure RenderBlock(const ABlock: TaPBlock; AValues: TStrings; ALines: TStrings);
var
  L: TStringList;
  I, K2: Integer;
  S: string;
begin
  ALines.Clear;
  L := TStringList.Create;
  try
    L.Delimiter := '|';
    L.StrictDelimiter := True;
    L.DelimitedText := ABlock.Body;
    for I := 0 to L.Count - 1 do
    begin
      S := L[I];
      for K2 := 0 to High(ABlock.Slots) do
      begin
        S := StringReplace(S, '{' + ABlock.Slots[K2].Name + '}', AValues.Values[ABlock.Slots[K2].Name], [rfReplaceAll]);
        S := StringReplace(S, '{' + ABlock.Slots[K2].Name + ':r}', PrefixList(AValues.Values[ABlock.Slots[K2].Name]), [rfReplaceAll]);
      end;
      ALines.Add(S);
    end;
  finally
    L.Free;
  end;
end;

{ razdvaja predlozak prvog retka na doslovne dijelove i imena utora: lit0 {s1} lit1 {s2} lit2 }
procedure SplitTemplate(const ALine: string; ALits, ANames: TStrings);
var
  P, Q: Integer;
  Rest: string;
begin
  Rest := ALine;
  repeat
    P := Pos('{', Rest);
    if P = 0 then begin ALits.Add(Rest); Break; end;
    Q := Pos('}', Rest);
    ALits.Add(Copy(Rest, 1, P - 1));
    ANames.Add(Copy(Rest, P + 1, Q - P - 1));
    Rest := Copy(Rest, Q + 1, MaxInt);
  until False;
end;

function TryMatch(const ABlockIndex: Integer; const ALine: string; AValues: TStringList): Boolean;
var
  Body: TStringList;
  Lits, Names: TStringList;
  U, Src: string;
  Pos0, P, I, K: Integer;
  V: string;
  Bk: TaPBlock;
begin
  Result := False;
  Body := TStringList.Create;
  Lits := TStringList.Create;
  Names := TStringList.Create;
  try
    Body.Delimiter := '|';
    Body.StrictDelimiter := True;
    Body.DelimitedText := Blocks[ABlockIndex].Body;
    SplitTemplate(Body[0], Lits, Names);
    Bk := PaletteBlock(ABlockIndex);
    Src := Trim(ALine);
    U := UpperCase(Src);
    if Copy(U, 1, Length(Lits[0])) <> UpperCase(Lits[0]) then Exit;
    Pos0 := Length(Lits[0]) + 1;
    for I := 0 to Names.Count - 1 do
    begin
      if I = Names.Count - 1 then
      begin
        { zadnji utor: do kraja, osim doslovnog zavrsetka }
        if Lits[I + 1] = '' then V := Copy(Src, Pos0, MaxInt)
        else
        begin
          if (Length(Src) - Length(Lits[I + 1]) + 1 < Pos0) or
             (UpperCase(Copy(Src, Length(Src) - Length(Lits[I + 1]) + 1, MaxInt)) <> UpperCase(Lits[I + 1])) then Exit;
          V := Copy(Src, Pos0, Length(Src) - Length(Lits[I + 1]) - Pos0 + 1);
        end;
      end
      else
      begin
        P := PosEx(UpperCase(Lits[I + 1]), U, Pos0);
        if (Lits[I + 1] = '') or (P = 0) then Exit;
        V := Copy(Src, Pos0, P - Pos0);
        Pos0 := P + Length(Lits[I + 1]);
      end;
      if V = '' then Exit;
      if Pos(':r', Names[I]) > 0 then
      begin
        Names[I] := Copy(Names[I], 1, Pos(':', Names[I]) - 1);
        V := StringReplace(V, 'r.', '', [rfReplaceAll]);
      end;
      K := SlotIndex(Bk, Names[I]);
      if (K >= 0) and (Bk.Slots[K].Kind in [pkTablica, pkStupac, pkProgram, pkForma, pkVarijabla, pkIzvjesce]) and
         (Pos(' ', V) > 0) then Exit;
      AValues.Values[Names[I]] := V;
    end;
    Result := True;
  finally
    Body.Free;
    Lits.Free;
    Names.Free;
  end;
end;

function MatchLine(const ALine: string; out AValues: TStringList): Integer;
var
  I: Integer;
begin
  AValues := TStringList.Create;
  for I := 0 to High(Blocks) do
  begin
    AValues.Clear;
    if TryMatch(I, ALine, AValues) then Exit(I);
  end;
  AValues.Clear;
  Result := -1;
end;

procedure AnnotateLog(const AProgramText: string; ALog: TStrings);
var
  Prog: TStringList;
  I, P, Q, LineNo, B: Integer;
  S, Num: string;
  V: TStringList;
begin
  Prog := TStringList.Create;
  try
    Prog.Text := AProgramText;
    for I := 0 to ALog.Count - 1 do
    begin
      S := ALog[I];
      { trazi ":broj:" ili ":broj:stupac:" nakon naziva datoteke }
      P := Pos('.4gl:', S);
      if P = 0 then Continue;
      Q := P + 5;
      Num := '';
      while (Q <= Length(S)) and (S[Q] in ['0'..'9']) do begin Num := Num + S[Q]; Inc(Q); end;
      LineNo := StrToIntDef(Num, 0);
      if (LineNo < 1) or (LineNo > Prog.Count) then Continue;
      B := MatchLine(Prog[LineNo - 1], V);
      try
        if B >= 0 then
          ALog[I] := 'Blok "' + Blocks[B].Name + '" (redak ' + IntToStr(LineNo) + '): ' + Trim(Copy(S, Q + 1, MaxInt));
      finally
        V.Free;
      end;
    end;
  finally
    Prog.Free;
  end;
end;

end.
