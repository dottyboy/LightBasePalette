unit ta_skeleton;
{ Kosturi 4GL programa (.4glt), poglavlje 10 plana: 4GL tekst s tipiziranim utorima koji se pune iz baze.

  Datoteka:
    @format 1
    @kostur  Naziv
    @opis    Opis
    @kategorija  Popisi
    @utor   tablica : tablica                            "Koja tablica?"
    @utor   stupci  : stupci(tablica)  zadano=sviOsimId   "Koji stupci?"
    @preduvjet  tablica ima barem 2 stupca
    @predlazi   tablica ima stupac tipa datum  =>  preporuci
    ---
    tijelo programa s {utor}, {utor:lista} i blokovima  @each c IN stupci ... @end

  Vrste utora: tablica, stupac(t), stupci(t), stupac:broj(t), stupac:datum(t), stupac:tekst(t), veza(detalj,glavna),
  program, izvjesce, forma, tekst, broj, danet, izbor(a=oznaka;b=oznaka).
  Rezultat je obican 4GL program (bez skrivenih ovisnosti o kosturu). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, ta_meta, ta_types, ta_wizardgen;

type
  TaSlotKind = (tuTablica, tuStupac, tuStupci, tuStupacBroj, tuStupacDatum, tuStupacTekst, tuVeza,
    tuProgram, tuIzvjesce, tuForma, tuTekst, tuBroj, tuDaNe, tuIzbor);

  TaSkeletonSlot = record
    Name: string;
    Kind: TaSlotKind;
    Ref1, Ref2: string;      { nazivi utora s tablicom (stupci) ili detalj i glavna (veza) }
    Default: string;         { zadano= }
    Prompt: string;
    Choices: string;         { izbor(...): a=oznaka;b=oznaka }
  end;

  TaSkeleton = class
  public
    Name, Description, Category, FileName: string;
    FormatVersion: Integer;
    Slots: array of TaSkeletonSlot;
    Preconditions, Suggests, Contexts: TStringList;
    Body: string;
    constructor Create;
    destructor Destroy; override;
    function SlotIndex(const AName: string): Integer;
  end;

  TaSkeletonLibrary = class
  private
    FItems: TObjectList;
    function GetCount: Integer;
    function GetItem(I: Integer): TaSkeleton;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    { ucita sve *.4glt iz mape; vraca broj ucitanih, a greske dodaje u ALog }
    function LoadFolder(const ADir: string; ALog: TStrings = nil): Integer;
    function Find(const AName: string): TaSkeleton;
    procedure Categories(AList: TStrings);
    { kosturi koji odgovaraju kontekstu ('gumb', 'izvor', 'izvjesce', 'unos'): odabrana kontrola u dizajneru }
    procedure ForContext(const AContext: string; AOut: TStrings);
    property Count: Integer read GetCount;
    property Items[I: Integer]: TaSkeleton read GetItem; default;
  end;

{ parsira tekst kostura }
function ParseSkeleton(const AText, AFile: string; out ASk: TaSkeleton; out AErr: string): Boolean;
{ mapa kostura: uz izvrsnu datoteku, uz mapu projekta ili uz LightPalette; prazno ako je nema }
function FindSkeletonFolder(const AExtraDir: string = ''): string;

{ mogucnosti za utor (za padajuci popis) }
procedure SkeletonSlotChoices(ADb: TAppDb; ASk: TaSkeleton; const ASlot: string; AValues: TStrings; AOut: TStrings);
{ zadane vrijednosti utora iz podataka; vec postavljene vrijednosti u AValues ostaju }
procedure SkeletonDefaults(ADb: TAppDb; ASk: TaSkeleton; AValues: TStrings);
{ izgradi 4GL tekst; False + AErr kad utor nije popunjen ili je nepoznat }
function RenderSkeleton(ADb: TAppDb; ASk: TaSkeleton; AValues: TStrings; out AText, AErr: string): Boolean;
{ preduvjeti za tablicu; AWhy dobiva razlog kad ne vrijede }
function SkeletonApplies(ADb: TAppDb; ASk: TaSkeleton; const ATable: string; out AWhy: string): Boolean;
{ 0..100: koliko kostur odgovara tablici (preduvjeti + prijedlozi) }
function SkeletonScore(ADb: TAppDb; ASk: TaSkeleton; const ATable: string): Integer;

implementation

uses
  StrUtils;

{ ---------------- model ---------------- }

constructor TaSkeleton.Create;
begin
  Preconditions := TStringList.Create;
  Suggests := TStringList.Create;
  Contexts := TStringList.Create;
  FormatVersion := 1;
end;

destructor TaSkeleton.Destroy;
begin
  Preconditions.Free;
  Suggests.Free;
  Contexts.Free;
  inherited Destroy;
end;

function TaSkeleton.SlotIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Slots) do
    if SameText(Slots[I].Name, AName) then Exit(I);
  Result := -1;
end;

constructor TaSkeletonLibrary.Create;
begin
  FItems := TObjectList.Create(True);
end;

destructor TaSkeletonLibrary.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TaSkeletonLibrary.Clear;
begin
  FItems.Clear;
end;

function TaSkeletonLibrary.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TaSkeletonLibrary.GetItem(I: Integer): TaSkeleton;
begin
  Result := TaSkeleton(FItems[I]);
end;

function TaSkeletonLibrary.Find(const AName: string): TaSkeleton;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if SameText(Items[I].Name, AName) then Exit(Items[I]);
  Result := nil;
end;

procedure TaSkeletonLibrary.Categories(AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to FItems.Count - 1 do
    if AList.IndexOf(Items[I].Category) < 0 then AList.Add(Items[I].Category);
end;

procedure TaSkeletonLibrary.ForContext(const AContext: string; AOut: TStrings);
var
  I: Integer;
begin
  AOut.Clear;
  for I := 0 to FItems.Count - 1 do
    if Items[I].Contexts.IndexOf(LowerCase(AContext)) >= 0 then AOut.Add(Items[I].Name);
end;

function TaSkeletonLibrary.LoadFolder(const ADir: string; ALog: TStrings): Integer;
var
  SR: TSearchRec;
  L: TStringList;
  Sk: TaSkeleton;
  Err: string;
  Dir: string;
begin
  Result := 0;
  Dir := IncludeTrailingPathDelimiter(ADir);
  if FindFirst(Dir + '*.4glt', faAnyFile, SR) <> 0 then Exit;
  try
    repeat
      L := TStringList.Create;
      try
        L.LoadFromFile(Dir + SR.Name);
        if ParseSkeleton(L.Text, Dir + SR.Name, Sk, Err) then
        begin
          FItems.Add(Sk);
          Inc(Result);
        end
        else if ALog <> nil then ALog.Add(SR.Name + ': ' + Err);
      finally
        L.Free;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function FindSkeletonFolder(const AExtraDir: string): string;
var
  Exe: string;
  Dirs: array[0..5] of string;
  I: Integer;
begin
  Exe := ExtractFilePath(ParamStr(0));
  Dirs[0] := AExtraDir;
  Dirs[1] := Exe + 'skeletons';
  Dirs[2] := Exe + '..' + PathDelim + 'skeletons';
  Dirs[3] := Exe + '..' + PathDelim + '..' + PathDelim + 'LightPalette' + PathDelim + 'skeletons';
  Dirs[4] := GetCurrentDir + PathDelim + 'skeletons';
  Dirs[5] := Exe + '..' + PathDelim + '..' + PathDelim + 'skeletons';
  for I := 0 to High(Dirs) do
    if (Dirs[I] <> '') and DirectoryExists(Dirs[I]) then Exit(ExpandFileName(Dirs[I]));
  Result := '';
end;

{ ---------------- parser ---------------- }

function KindFromName(const AName: string; out AKind: TaSlotKind): Boolean;
var
  N: string;
begin
  N := LowerCase(AName);
  Result := True;
  if N = 'tablica' then AKind := tuTablica
  else if N = 'stupac' then AKind := tuStupac
  else if N = 'stupci' then AKind := tuStupci
  else if N = 'stupac:broj' then AKind := tuStupacBroj
  else if N = 'stupac:datum' then AKind := tuStupacDatum
  else if N = 'stupac:tekst' then AKind := tuStupacTekst
  else if N = 'veza' then AKind := tuVeza
  else if N = 'program' then AKind := tuProgram
  else if N = 'izvjesce' then AKind := tuIzvjesce
  else if N = 'forma' then AKind := tuForma
  else if N = 'tekst' then AKind := tuTekst
  else if N = 'broj' then AKind := tuBroj
  else if N = 'danet' then AKind := tuDaNe
  else if N = 'izbor' then AKind := tuIzbor
  else Result := False;
end;

{ "ime : vrsta(arg) zadano=x "pitanje"" }
function ParseSlot(const ALine: string; out ASlot: TaSkeletonSlot; out AErr: string): Boolean;
var
  S, KindText, Args, Rest, Tmp: string;
  P, Q, E: Integer;
  Parts: TStringList;
begin
  Result := False;
  AErr := '';
  FillChar(ASlot, SizeOf(ASlot), 0);
  S := Trim(ALine);
  P := Pos(':', S);
  if P < 2 then begin AErr := 'Utor mora imati oblik "ime : vrsta"'; Exit; end;
  ASlot.Name := Trim(Copy(S, 1, P - 1));
  Rest := Trim(Copy(S, P + 1, MaxInt));
  { vrsta do prvog razmaka izvan zagrada }
  E := 1;
  Q := 0;
  while E <= Length(Rest) do
  begin
    if Rest[E] = '(' then Inc(Q)
    else if Rest[E] = ')' then Dec(Q)
    else if (Rest[E] = ' ') and (Q = 0) then Break;
    Inc(E);
  end;
  KindText := Copy(Rest, 1, E - 1);
  Rest := Trim(Copy(Rest, E, MaxInt));
  Args := '';
  P := Pos('(', KindText);
  if P > 0 then
  begin
    Args := Copy(KindText, P + 1, Length(KindText) - P - 1);
    KindText := Copy(KindText, 1, P - 1);
  end;
  if not KindFromName(KindText, ASlot.Kind) then begin AErr := 'Nepoznata vrsta utora "' + KindText + '"'; Exit; end;
  Parts := TStringList.Create;
  try
    if ASlot.Kind = tuIzbor then ASlot.Choices := Args
    else
    begin
      Parts.Delimiter := ',';
      Parts.StrictDelimiter := True;
      Parts.DelimitedText := Args;
      if Parts.Count > 0 then ASlot.Ref1 := Trim(Parts[0]);
      if Parts.Count > 1 then ASlot.Ref2 := Trim(Parts[1]);
    end;
  finally
    Parts.Free;
  end;
  if (ASlot.Kind in [tuStupac, tuStupci, tuStupacBroj, tuStupacDatum, tuStupacTekst]) and (ASlot.Ref1 = '') then
  begin
    AErr := 'Utor "' + ASlot.Name + '" mora navesti utor s tablicom, npr. stupci(tablica)';
    Exit;
  end;
  { zadano= i pitanje }
  P := Pos('zadano=', Rest);
  if P > 0 then
  begin
    Tmp := Copy(Rest, P + 7, MaxInt);
    if (Tmp <> '') and (Tmp[1] = '"') then
    begin
      Q := PosEx('"', Tmp, 2);
      if Q = 0 then Q := Length(Tmp) + 1;
      ASlot.Default := Copy(Tmp, 2, Q - 2);
      Rest := Copy(Rest, 1, P - 1) + ' ' + Copy(Tmp, Q + 1, MaxInt);
    end
    else
    begin
      Q := Pos(' ', Tmp);
      if Q = 0 then Q := Length(Tmp) + 1;
      ASlot.Default := Copy(Tmp, 1, Q - 1);
      Rest := Copy(Rest, 1, P - 1) + ' ' + Copy(Tmp, Q + 1, MaxInt);
    end;
  end;
  P := Pos('"', Rest);
  if P > 0 then
  begin
    Q := RPos('"', Rest);
    if Q > P then ASlot.Prompt := Copy(Rest, P + 1, Q - P - 1);
  end;
  Result := True;
end;

function ParseSkeleton(const AText, AFile: string; out ASk: TaSkeleton; out AErr: string): Boolean;
var
  L: TStringList;
  I, N: Integer;
  S, Dir, Arg: string;
  Slot: TaSkeletonSlot;
  Body: TStringList;
  InBody: Boolean;
begin
  Result := False;
  AErr := '';
  ASk := TaSkeleton.Create;
  ASk.FileName := AFile;
  L := TStringList.Create;
  Body := TStringList.Create;
  try
    L.Text := AText;
    InBody := False;
    for I := 0 to L.Count - 1 do
    begin
      S := L[I];
      if InBody then begin Body.Add(S); Continue; end;
      if Trim(S) = '---' then begin InBody := True; Continue; end;
      if (Trim(S) = '') or (Copy(Trim(S), 1, 2) = '//') then Continue;
      if Copy(S, 1, 1) <> '@' then
      begin
        AErr := 'redak ' + IntToStr(I + 1) + ': ocekujem direktivu (@...) ili ---';
        FreeAndNil(ASk);
        Exit;
      end;
      N := Pos(' ', S);
      if N = 0 then begin Dir := LowerCase(Copy(S, 2, MaxInt)); Arg := ''; end
      else begin Dir := LowerCase(Copy(S, 2, N - 2)); Arg := Trim(Copy(S, N + 1, MaxInt)); end;
      if Dir = 'format' then ASk.FormatVersion := StrToIntDef(Arg, 1)
      else if Dir = 'kostur' then ASk.Name := Arg
      else if Dir = 'opis' then ASk.Description := Arg
      else if Dir = 'kategorija' then ASk.Category := Arg
      else if Dir = 'preduvjet' then ASk.Preconditions.Add(Arg)
      else if Dir = 'predlazi' then ASk.Suggests.Add(Arg)
      else if Dir = 'kontekst' then ASk.Contexts.CommaText := LowerCase(Arg)
      else if Dir = 'utor' then
      begin
        if not ParseSlot(Arg, Slot, AErr) then
        begin
          AErr := 'redak ' + IntToStr(I + 1) + ': ' + AErr;
          FreeAndNil(ASk);
          Exit;
        end;
        SetLength(ASk.Slots, Length(ASk.Slots) + 1);
        ASk.Slots[High(ASk.Slots)] := Slot;
      end;
      { nepoznate direktive se tolerantno preskacu (nove verzije formata) }
    end;
    if not InBody then begin AErr := 'nedostaje crta --- ispred tijela'; FreeAndNil(ASk); Exit; end;
    if ASk.Name = '' then begin AErr := 'nedostaje @kostur'; FreeAndNil(ASk); Exit; end;
    ASk.Body := Body.Text;
    Result := True;
  finally
    L.Free;
    Body.Free;
  end;
end;

{ ---------------- podaci iz baze ---------------- }

function FourGlType(AType: TaLogicalType): string;
begin
  case AType of
    ltInteger, ltAutoNumber: Result := 'INTEGER';
    ltDecimal, ltCurrency: Result := 'DECIMAL(14,2)';
    ltYesNo: Result := 'BOOLEAN';
    ltDate: Result := 'DATE';
    ltDateTime, ltTime: Result := 'DATETIME';
  else
    Result := 'TEXT';
  end;
end;

function IsNumberType(AType: TaLogicalType): Boolean;
begin
  Result := AType in [ltInteger, ltDecimal, ltCurrency, ltAutoNumber];
end;

function IsDateType(AType: TaLogicalType): Boolean;
begin
  Result := AType in [ltDate, ltDateTime];
end;

function IsTextType(AType: TaLogicalType): Boolean;
begin
  Result := AType in [ltText, ltMemo];
end;

function TableColumns(ADb: TAppDb; const ATable: string): TaSourceFields;
begin
  SetLength(Result, 0);
  if (ADb = nil) or (ATable = '') then Exit;
  try
    Result := SourceFieldList(ADb, ATable);
  except
    SetLength(Result, 0);
  end;
end;

function FindColumn(const AFields: TaSourceFields; const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AFields) do
    if SameText(AFields[I].Name, AName) then Exit(I);
  Result := -1;
end;

function ValueOf(AValues: TStrings; const AName: string): string;
begin
  Result := AValues.Values[AName];
end;

procedure SplitList(const S: string; AList: TStrings);
var
  L: TStringList;
  I: Integer;
begin
  AList.Clear;
  L := TStringList.Create;
  try
    L.Delimiter := ',';
    L.StrictDelimiter := True;
    L.DelimitedText := S;
    for I := 0 to L.Count - 1 do
      if Trim(L[I]) <> '' then AList.Add(Trim(L[I]));
  finally
    L.Free;
  end;
end;

procedure SkeletonSlotChoices(ADb: TAppDb; ASk: TaSkeleton; const ASlot: string; AValues: TStrings; AOut: TStrings);
var
  K: Integer;
  Sl: TaSkeletonSlot;
  Tab, Det, Gl: string;
  Tables, Objs: TStringList;
  Cols: TaSourceFields;
  Fks: TaFkDefs;
  I: Integer;
  Tmp: TStringList;
begin
  AOut.Clear;
  K := ASk.SlotIndex(ASlot);
  if K < 0 then Exit;
  Sl := ASk.Slots[K];
  case Sl.Kind of
    tuTablica:
      begin
        Tables := ADb.UserTables;
        try
          AOut.AddStrings(Tables);
        finally
          Tables.Free;
        end;
      end;
    tuStupac, tuStupci, tuStupacBroj, tuStupacDatum, tuStupacTekst:
      begin
        Tab := ValueOf(AValues, Sl.Ref1);
        Cols := TableColumns(ADb, Tab);
        for I := 0 to High(Cols) do
          case Sl.Kind of
            tuStupacBroj: if IsNumberType(Cols[I].LType) then AOut.Add(Cols[I].Name);
            tuStupacDatum: if IsDateType(Cols[I].LType) then AOut.Add(Cols[I].Name);
            tuStupacTekst: if IsTextType(Cols[I].LType) then AOut.Add(Cols[I].Name);
          else
            AOut.Add(Cols[I].Name);
          end;
      end;
    tuVeza:
      begin
        Det := ValueOf(AValues, Sl.Ref1);
        Gl := ValueOf(AValues, Sl.Ref2);
        Fks := ADb.GetFks(Det);
        for I := 0 to High(Fks) do
          if (Gl = '') or SameText(Fks[I].RefTable, Gl) then AOut.Add(Fks[I].FromCol + '>' + Fks[I].RefCol);
      end;
    tuProgram, tuIzvjesce, tuForma:
      begin
        case Sl.Kind of
          tuProgram: Objs := ADb.ListObjects('_sys_programs');
          tuIzvjesce: Objs := ADb.ListObjects('_sys_reports');
        else
          Objs := ADb.ListObjects('_sys_forms');
        end;
        try
          AOut.AddStrings(Objs);
        finally
          Objs.Free;
        end;
      end;
    tuIzbor:
      begin
        Tmp := TStringList.Create;
        try
          Tmp.Delimiter := ';';
          Tmp.StrictDelimiter := True;
          Tmp.DelimitedText := Sl.Choices;
          for I := 0 to Tmp.Count - 1 do
            if Pos('=', Tmp[I]) > 0 then AOut.Add(Copy(Tmp[I], 1, Pos('=', Tmp[I]) - 1)) else AOut.Add(Tmp[I]);
        finally
          Tmp.Free;
        end;
      end;
    tuDaNe:
      begin
        AOut.Add('da');
        AOut.Add('ne');
      end;
  end;
end;

function ExpandDefault(const ATemplate: string; AValues: TStrings): string;
var
  I, J: Integer;
  Nm: string;
begin
  Result := '';
  I := 1;
  while I <= Length(ATemplate) do
  begin
    if ATemplate[I] = '{' then
    begin
      J := PosEx('}', ATemplate, I + 1);
      if J = 0 then begin Result := Result + Copy(ATemplate, I, MaxInt); Break; end;
      Nm := Copy(ATemplate, I + 1, J - I - 1);
      Result := Result + ValueOf(AValues, Nm);
      I := J + 1;
    end
    else
    begin
      Result := Result + ATemplate[I];
      Inc(I);
    end;
  end;
end;

procedure SkeletonDefaults(ADb: TAppDb; ASk: TaSkeleton; AValues: TStrings);
var
  K, I: Integer;
  Sl: TaSkeletonSlot;
  Cands: TStringList;
  Tab, Pk, Def, V: string;
  Cols: TaSourceFields;
  Found: Boolean;
begin
  Cands := TStringList.Create;
  try
    for K := 0 to High(ASk.Slots) do
    begin
      Sl := ASk.Slots[K];
      if ValueOf(AValues, Sl.Name) <> '' then Continue;
      V := '';
      Def := ExpandDefault(Sl.Default, AValues);
      SkeletonSlotChoices(ADb, ASk, Sl.Name, AValues, Cands);
      case Sl.Kind of
        tuTablica:
          begin
            if SameText(Def, 'imaFk') then
            begin
              for I := 0 to Cands.Count - 1 do
                if Length(ADb.GetFks(Cands[I])) > 0 then begin V := Cands[I]; Break; end;
            end
            else if Copy(LowerCase(Def), 1, 7) = 'ciljfk(' then
            begin
              { tablica na koju pokazuje prvi strani kljuc tablice iz drugog utora }
              Tab := ValueOf(AValues, Copy(Def, 8, Length(Def) - 8));
              if Tab <> '' then
                if Length(ADb.GetFks(Tab)) > 0 then V := ADb.GetFks(Tab)[0].RefTable;
            end
            else if (Def <> '') and (Cands.IndexOf(Def) >= 0) then V := Def;
            if V = '' then
              for I := 0 to Cands.Count - 1 do
              begin
                Cols := TableColumns(ADb, Cands[I]);
                if Length(Cols) >= 2 then begin V := Cands[I]; Break; end;
              end;
            if (V = '') and (Cands.Count > 0) then V := Cands[0];
          end;
        tuStupac, tuStupacBroj, tuStupacDatum, tuStupacTekst:
          begin
            Tab := ValueOf(AValues, Sl.Ref1);
            Pk := ADb.PrimaryKeyOf(Tab);
            if SameText(Def, 'kljuc') then V := Pk
            else if (Def <> '') and (Cands.IndexOf(Def) >= 0) then V := Def
            else
            begin
              Found := False;
              for I := 0 to Cands.Count - 1 do
                if not SameText(Cands[I], Pk) and not (Pos('_id', LowerCase(Cands[I])) > 0) then
                begin
                  V := Cands[I];
                  Found := True;
                  Break;
                end;
              if (not Found) and (Cands.Count > 0) then V := Cands[0];
            end;
          end;
        tuStupci:
          begin
            Tab := ValueOf(AValues, Sl.Ref1);
            Pk := ADb.PrimaryKeyOf(Tab);
            for I := 0 to Cands.Count - 1 do
              if not SameText(Cands[I], Pk) then V := V + IfThen(V = '', '', ',') + Cands[I];
            if V = '' then V := Cands.CommaText;
          end;
        tuVeza:
          if Cands.Count > 0 then V := Cands[0];
        tuIzbor:
          if (Def <> '') and (Cands.IndexOf(Def) >= 0) then V := Def
          else if Cands.Count > 0 then V := Cands[0];
        tuDaNe:
          if Def <> '' then V := Def else V := 'ne';
        tuTekst, tuBroj:
          V := Def;
        tuProgram, tuIzvjesce, tuForma:
          if (Def <> '') then V := Def
          else if Cands.Count > 0 then V := Cands[0];
      end;
      if V <> '' then AValues.Values[Sl.Name] := V;
    end;
  finally
    Cands.Free;
  end;
end;

{ ---------------- izgradnja teksta ---------------- }

function SlotTable(ASk: TaSkeleton; const ASlot: string; AValues: TStrings): string;
var
  K: Integer;
begin
  Result := '';
  K := ASk.SlotIndex(ASlot);
  if (K >= 0) and (ASk.Slots[K].Ref1 <> '') then Result := ValueOf(AValues, ASk.Slots[K].Ref1);
end;

{ jedna vrijednost stupca/utora u zadanom obliku }
function FormatElement(ADb: TAppDb; const AValue, ATable, AFmt: string): string;
var
  Cols: TaSourceFields;
  I: Integer;
begin
  Result := AValue;
  if AFmt = '' then Exit;
  if AFmt = 'naslov' then Exit(PrettyName(AValue));
  if AFmt = 'tip' then
  begin
    Cols := TableColumns(ADb, ATable);
    I := FindColumn(Cols, AValue);
    if I >= 0 then Exit(FourGlType(Cols[I].LType));
    Exit('TEXT');
  end;
end;

function FormatList(ADb: TAppDb; const AValue, ATable, AFmt: string): string;
var
  L: TStringList;
  I: Integer;
  Sep, Pref: string;
begin
  L := TStringList.Create;
  try
    SplitList(AValue, L);
    Result := '';
    Sep := '';
    { ispis, ispis_g, ispis_d: "g.a, "  ", g.b" (predlozak zapisa je r, g ili d) }
    Pref := 'r';
    if Copy(AFmt, 1, 5) = 'ispis' then
      if (Length(AFmt) > 6) and (AFmt[6] = '_') then Pref := Copy(AFmt, 7, 1);
    for I := 0 to L.Count - 1 do
    begin
      if (AFmt = '') or (AFmt = 'lista') then Result := Result + Sep + L[I]
      else if AFmt = 'tablicno' then Result := Result + Sep + ATable + '.' + L[I]
      else if Copy(AFmt, 1, 5) = 'ispis' then Result := Result + Sep + Pref + '.' + L[I] + ', "  "'
      else if AFmt = 'zapis' then Result := Result + Sep + 'r.' + L[I]
      else if AFmt = 'postavi' then Result := Result + Sep + L[I] + ' = $r.' + L[I]
      else if AFmt = 'vrijednosti' then Result := Result + Sep + '$r.' + L[I]
      else if AFmt = 'prvi' then Exit(L[I])
      else Result := Result + Sep + L[I];
      Sep := ', ';
    end;
    if (Copy(AFmt, 1, 5) = 'ispis') and (Length(Result) > 6) and (Copy(Result, Length(Result) - 5, 6) = ', "  "') then
      Result := Copy(Result, 1, Length(Result) - 6);
  finally
    L.Free;
  end;
end;

function RenderSkeleton(ADb: TAppDb; ASk: TaSkeleton; AValues: TStrings; out AText, AErr: string): Boolean;
var
  Lines, Out: TStringList;
  I, J, K, P: Integer;
  Line, VarName, SlotName, Fmt, Tab, Val: string;
  EachLines: TStringList;
  Elems: TStringList;
  BodyOpen: Boolean;
  Err: string;

  { zamjena {...} u jednom retku; AVar/AElem = promjenjiva petlje }
  function Subst(const ALine, AVar, AElem, AElemTable: string; out AFail: string): string;
  var
    A, B: Integer;
    Ref, Fm, Sl, Fmx: string;
    Idx: Integer;
  begin
    Result := '';
    AFail := '';
    A := 1;
    while A <= Length(ALine) do
    begin
      if ALine[A] = '{' then
      begin
        B := PosEx('}', ALine, A + 1);
        if B = 0 then begin Result := Result + Copy(ALine, A, MaxInt); Break; end;
        Ref := Copy(ALine, A + 1, B - A - 1);
        Fm := '';
        if Pos(':', Ref) > 0 then
        begin
          Fm := Copy(Ref, Pos(':', Ref) + 1, MaxInt);
          Ref := Copy(Ref, 1, Pos(':', Ref) - 1);
        end;
        if (AVar <> '') and SameText(Ref, AVar) then
          Result := Result + FormatElement(ADb, AElem, AElemTable, Fm)
        else
        begin
          Idx := ASk.SlotIndex(Ref);
          if Idx < 0 then begin AFail := 'Nepoznat utor {' + Ref + '}'; Exit; end;
          Sl := ValueOf(AValues, Ref);
          if Sl = '' then begin AFail := 'Utor "' + Ref + '" nije popunjen'; Exit; end;
          Fmx := Fm;
          if ASk.Slots[Idx].Kind in [tuStupci] then
            Result := Result + FormatList(ADb, Sl, SlotTable(ASk, Ref, AValues), Fmx)
          else if ASk.Slots[Idx].Kind = tuVeza then
          begin
            if Fmx = 'cilj' then Result := Result + Copy(Sl, Pos('>', Sl) + 1, MaxInt)
            else if Fmx = 'ciljtip' then
              Result := Result + FormatElement(ADb, Copy(Sl, Pos('>', Sl) + 1, MaxInt), ValueOf(AValues, ASk.Slots[Idx].Ref2), 'tip')
            else if Fmx = 'kolonatip' then
              Result := Result + FormatElement(ADb, Copy(Sl, 1, Pos('>', Sl) - 1), ValueOf(AValues, ASk.Slots[Idx].Ref1), 'tip')
            else Result := Result + Copy(Sl, 1, Pos('>', Sl) - 1);
          end
          else if ASk.Slots[Idx].Kind in [tuStupac, tuStupacBroj, tuStupacDatum, tuStupacTekst] then
            Result := Result + FormatElement(ADb, Sl, SlotTable(ASk, Ref, AValues), Fmx)
          else Result := Result + Sl;
        end;
        A := B + 1;
      end
      else
      begin
        Result := Result + ALine[A];
        Inc(A);
      end;
    end;
  end;

begin
  Result := False;
  AText := '';
  AErr := '';
  Lines := TStringList.Create;
  Out := TStringList.Create;
  EachLines := TStringList.Create;
  Elems := TStringList.Create;
  try
    Lines.Text := ASk.Body;
    I := 0;
    while I < Lines.Count do
    begin
      Line := Lines[I];
      if Copy(Trim(Line), 1, 6) = '@each ' then
      begin
        { @each var IN utor }
        P := Pos(' IN ', UpperCase(Trim(Line)));
        if P = 0 then begin AErr := 'redak tijela ' + IntToStr(I + 1) + ': @each ocekuje "@each var IN utor"'; Exit; end;
        VarName := Trim(Copy(Trim(Line), 7, P - 7));
        SlotName := Trim(Copy(Trim(Line), P + 4, MaxInt));
        EachLines.Clear;
        BodyOpen := True;
        J := I + 1;
        while (J < Lines.Count) do
        begin
          if Trim(Lines[J]) = '@end' then begin BodyOpen := False; Break; end;
          EachLines.Add(Lines[J]);
          Inc(J);
        end;
        if BodyOpen then begin AErr := 'blok @each nije zatvoren (@end)'; Exit; end;
        K := ASk.SlotIndex(SlotName);
        if K < 0 then begin AErr := 'Nepoznat utor "' + SlotName + '" u @each'; Exit; end;
        Val := ValueOf(AValues, SlotName);
        if Val = '' then begin AErr := 'Utor "' + SlotName + '" nije popunjen'; Exit; end;
        SplitList(Val, Elems);
        Tab := SlotTable(ASk, SlotName, AValues);
        for K := 0 to Elems.Count - 1 do
          for P := 0 to EachLines.Count - 1 do
          begin
            Out.Add(Subst(EachLines[P], VarName, Elems[K], Tab, Err));
            if Err <> '' then begin AErr := Err; Exit; end;
          end;
        I := J + 1;
        Continue;
      end;
      Out.Add(Subst(Line, '', '', '', Err));
      if Err <> '' then begin AErr := Err; Exit; end;
      Inc(I);
    end;
    AText := Out.Text;
    Result := True;
  finally
    Lines.Free;
    Out.Free;
    EachLines.Free;
    Elems.Free;
  end;
end;

{ ---------------- preduvjeti i prijedlozi ---------------- }

function RuleHolds(ADb: TAppDb; const ARule, ATable: string): Boolean;
var
  R: string;
  Cols: TaSourceFields;
  I, N: Integer;
  T: string;
  Fks: TaFkDefs;
begin
  R := LowerCase(Trim(ARule));
  if Pos('=>', R) > 0 then R := Trim(Copy(R, 1, Pos('=>', R) - 1));
  Cols := TableColumns(ADb, ATable);
  Result := True;
  if Pos('barem ', R) > 0 then
  begin
    N := StrToIntDef(Trim(Copy(R, Pos('barem ', R) + 6, 3)), 1);
    Exit(Length(Cols) >= N);
  end;
  if Pos('stupac tipa ', R) > 0 then
  begin
    T := Trim(Copy(R, Pos('stupac tipa ', R) + 12, MaxInt));
    for I := 0 to High(Cols) do
      if ((T = 'datum') and IsDateType(Cols[I].LType)) or ((T = 'broj') and IsNumberType(Cols[I].LType) and not SameText(Cols[I].Name, ADb.PrimaryKeyOf(ATable))) or
         ((T = 'tekst') and IsTextType(Cols[I].LType)) then Exit(True);
    Exit(False);
  end;
  if Pos('strani kljuc', R) > 0 then
  begin
    Fks := ADb.GetFks(ATable);
    Exit(Length(Fks) > 0);
  end;
  if Pos('stupac ', R) > 0 then
  begin
    T := Trim(Copy(R, Pos('stupac ', R) + 7, MaxInt));
    Exit(FindColumn(Cols, T) >= 0);
  end;
end;

function SkeletonApplies(ADb: TAppDb; ASk: TaSkeleton; const ATable: string; out AWhy: string): Boolean;
var
  I: Integer;
begin
  AWhy := '';
  Result := True;
  for I := 0 to ASk.Preconditions.Count - 1 do
    if not RuleHolds(ADb, ASk.Preconditions[I], ATable) then
    begin
      AWhy := 'preduvjet nije ispunjen: ' + ASk.Preconditions[I];
      Exit(False);
    end;
end;

function SkeletonScore(ADb: TAppDb; ASk: TaSkeleton; const ATable: string): Integer;
var
  I: Integer;
  Why: string;
begin
  if not SkeletonApplies(ADb, ASk, ATable, Why) then Exit(0);
  Result := 40;
  for I := 0 to ASk.Suggests.Count - 1 do
    if RuleHolds(ADb, ASk.Suggests[I], ATable) then Inc(Result, 30);
  if Result > 100 then Result := 100;
end;

end.
