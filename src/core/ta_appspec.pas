unit ta_appspec;
{ Opis aplikacije u jednoj tekstualnoj datoteci: tablice, forme, izvjesca, izbornik, vrste dokumenata, prava i postavke.
  Iz opisa se izradi cijela aplikacija (generira se isto sto i carobnjacima), a sto opis ne kaze, slozi se samo:
  tablica bez forme dobiva formu i popis, aplikacija bez izbornika dobiva izbornik.

  Oblik (uvlake su bitne, redak koji pocinje s // je komentar):

    aplikacija "Mali obrt"
      naslov: Mali obrt d.o.o.
      izbornik: bocni                  (bocni | gumbi | glavna)

    tablica partneri "Partneri"
      naziv   Text    obavezno
      oib     Text
        pravilo: OibIspravan([oib]) | OIB nije ispravan
      grad_id Integer veza=gradovi.id
      aktivan YesNo   zadano=1

    forma "Partneri"
      izvor: partneri
      raspored: dvastupca              (jedan | dvastupca | tablica | podijeljeno)
      detalji: stavke(dokument_id)
      raspored: ploca                  (kanban; uz njega ploca: polje stupaca | naslov kartice | polje, polje | forma za uredjivanje)

    izvjesce "Popis partnera"
      izvor: partneri
      grupa: grad

    izbornik
      # Sifrarnici
      Partneri -> forma Partneri
      Popis partnera -> izvjesce Popis partnera
      Izlaz -> zatvori

    vrsta otp "Otpremnica" prefiks=otp srodne=rv
    prava
      forma Postavke: admin
    postavke
      firma.naziv: Moja tvrtka }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, ta_meta;

type
  TSpecField = class
  public
    Name, Typ, Default, Ref, Rule, RuleMsg, Descr: string;
    Required, Cascade: Boolean;
    Line: Integer;
  end;

  TSpecTable = class
  public
    Name, Caption: string;
    NoForm, NoReport: Boolean;
    Fields: TObjectList;
    Line: Integer;
    constructor Create;
    destructor Destroy; override;
    function FieldByName(const AName: string): TSpecField;
  end;

  TSpecForm = class
  public
    Name, Source, Title, Layout, Fields, Group, DocType, DocNumber, Sum, Details, Board, Dash, Timeline: string;
    Calcs, CalcRules, AutoFill: TStringList;
    Line: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TSpecReport = class
  public
    Name, Source, Title, Kind, Fields, GroupBy, SortBy, Widths: string;
    Desc, Sums: Boolean;
    Line: Integer;
    Charts: TStringList;           { vrsta grafikoni: "Naslov | tip | upit ili SELECT" }
    constructor Create;
    destructor Destroy; override;
  end;

  TSpecQuery = class
  public
    Name, Sql: string;
    Line: Integer;
  end;

  { 4GL program: tijelo ispod naslova ili datoteka uz opis }
  TSpecProgram = class
  public
    Name, Text: string;
    Line: Integer;
  end;

  TSpecMenuItem = class
  public
    Caption, Action: string;
    IsGroup: Boolean;
    Line: Integer;
  end;

  TSpecType = class
  public
    Code, Name, Prefix, Format, Related: string;
    Line: Integer;
  end;

  TSpecRight = class
  public
    Kind, Name, Role: string;
    Line: Integer;
  end;

  TAppSpec = class
  public
    AppName, Title, Startup, MenuStyle: string;
    Tables, Forms, Reports, Queries, Programs, Menu, Types, Rights: TObjectList;
    Settings: TStringList;
    BaseDir: string;   { mapa opisa: odatle se citaju 'datoteka:' programa }
    Errors: TStringList;
    constructor Create;
    destructor Destroy; override;
    function FindTable(const AName: string): TSpecTable;
    { po nazivu, naslovu ili ljepsem nazivu tablice (automatska forma tablice zove se kao njezin naslov) }
    function FindTableByCaption(const AName: string): TSpecTable;
    function FindForm(const AName: string): TSpecForm;
    function FindReport(const AName: string): TSpecReport;
  end;

{ cita opis; False ako ima pogresaka (ASpec.Errors, svaka s brojem retka) }
function ParseAppSpec(const AText: string; ASpec: TAppSpec): Boolean;
{ provjerava veze izmedju dijelova opisa (tablice, polja, forme, izbornik...) }
function ValidateAppSpec(ASpec: TAppSpec): Boolean;
{ izradi aplikaciju u otvorenoj bazi }
function CompileAppSpec(ADb: TAppDb; ASpec: TAppSpec; ALog: TStrings): Boolean;
{ opis -> aplikacija; pogreske opisa idu u ALog (retci "GREŠKA retak N: ...") }
function BuildAppFromSpecText(ADb: TAppDb; const AText: string; ALog: TStrings; const ABaseDir: string = ''): Boolean;

implementation

uses
  ta_i18n,
  ta_types, ta_formdef, ta_reportdef, ta_wizardgen, ta_bizgen, ta_switchgen, ta_doctypes, ta_app, ta_iconmap;

{ ---------------- model ---------------- }

function SplitBar(const S: string): TStringList; forward;
function FindQuerySql(ASpec: TAppSpec; const AName: string): string; forward;

constructor TSpecReport.Create;
begin
  Charts := TStringList.Create;
end;

destructor TSpecReport.Destroy;
begin
  Charts.Free;
  inherited Destroy;
end;

constructor TSpecTable.Create;
begin
  Fields := TObjectList.Create(True);
end;

destructor TSpecTable.Destroy;
begin
  Fields.Free;
  inherited Destroy;
end;

function TSpecTable.FieldByName(const AName: string): TSpecField;
var
  I: Integer;
begin
  for I := 0 to Fields.Count - 1 do
    if SameText(TSpecField(Fields[I]).Name, AName) then Exit(TSpecField(Fields[I]));
  Result := nil;
end;

constructor TSpecForm.Create;
begin
  Calcs := TStringList.Create;
  CalcRules := TStringList.Create;
  AutoFill := TStringList.Create;
end;

destructor TSpecForm.Destroy;
begin
  Calcs.Free;
  CalcRules.Free;
  AutoFill.Free;
  inherited Destroy;
end;

constructor TAppSpec.Create;
begin
  Tables := TObjectList.Create(True);
  Forms := TObjectList.Create(True);
  Reports := TObjectList.Create(True);
  Queries := TObjectList.Create(True);
  Programs := TObjectList.Create(True);
  Menu := TObjectList.Create(True);
  Types := TObjectList.Create(True);
  Rights := TObjectList.Create(True);
  Settings := TStringList.Create;
  Errors := TStringList.Create;
  MenuStyle := 'bocni';
end;

destructor TAppSpec.Destroy;
begin
  Tables.Free; Forms.Free; Reports.Free; Queries.Free; Programs.Free; Menu.Free; Types.Free; Rights.Free;
  Settings.Free; Errors.Free;
  inherited Destroy;
end;

function TAppSpec.FindTable(const AName: string): TSpecTable;
var
  I: Integer;
begin
  for I := 0 to Tables.Count - 1 do
    if SameText(TSpecTable(Tables[I]).Name, AName) then Exit(TSpecTable(Tables[I]));
  Result := nil;
end;

function TAppSpec.FindTableByCaption(const AName: string): TSpecTable;
var
  I: Integer;
  T: TSpecTable;
begin
  for I := 0 to Tables.Count - 1 do
  begin
    T := TSpecTable(Tables[I]);
    if SameText(T.Name, AName) or ((T.Caption <> '') and SameText(T.Caption, AName)) or SameText(PrettyName(T.Name), AName) then Exit(T);
  end;
  Result := nil;
end;

function TAppSpec.FindForm(const AName: string): TSpecForm;
var
  I: Integer;
begin
  for I := 0 to Forms.Count - 1 do
    if SameText(TSpecForm(Forms[I]).Name, AName) then Exit(TSpecForm(Forms[I]));
  Result := nil;
end;

function TAppSpec.FindReport(const AName: string): TSpecReport;
var
  I: Integer;
begin
  for I := 0 to Reports.Count - 1 do
    if SameText(TSpecReport(Reports[I]).Name, AName) then Exit(TSpecReport(Reports[I]));
  Result := nil;
end;

{ ---------------- pomocne ---------------- }

function Fold(const S: string): string;
begin
  Result := IconFold(S);
end;

function IndentOf(const S: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
    if S[I] = ' ' then Inc(Result)
    else if S[I] = #9 then Inc(Result, 2)
    else Break;
end;

{ rastavlja na rijeci; "navodnici" drze razmake; ime=\"vrijednost s razmakom\" ostaje jedna rijec }
procedure Tokens(const S: string; AList: TStrings);
var
  I: Integer;
  Cur: string;
  Q: Boolean;
begin
  AList.Clear;
  Cur := '';
  Q := False;
  for I := 1 to Length(S) do
  begin
    if S[I] = '"' then Q := not Q
    else if (S[I] in [' ', #9]) and not Q then
    begin
      if Cur <> '' then begin AList.Add(Cur); Cur := ''; end;
    end
    else Cur := Cur + S[I];
  end;
  if Cur <> '' then AList.Add(Cur);
end;

{ "Naziv u navodnicima" ili prva rijec; ARest je ostatak retka }
function ReadName(const S: string; out ARest: string): string;
var
  P, Q: Integer;
  T: string;
begin
  T := Trim(S);
  if (T <> '') and (T[1] = '"') then
  begin
    Q := Pos('"', Copy(T, 2, MaxInt));
    if Q = 0 then begin Result := Copy(T, 2, MaxInt); ARest := ''; Exit; end;
    Result := Copy(T, 2, Q - 1);
    ARest := Trim(Copy(T, Q + 2, MaxInt));
  end
  else
  begin
    P := Pos(' ', T);
    if P = 0 then begin Result := T; ARest := ''; end
    else begin Result := Copy(T, 1, P - 1); ARest := Trim(Copy(T, P + 1, MaxInt)); end;
  end;
end;

{ "kljuc: vrijednost" -> kljuc (bez dijakritika, mala slova) i vrijednost }
function SplitProp(const S: string; out AKey, AValue: string): Boolean;
var
  P: Integer;
begin
  P := Pos(':', S);
  Result := P > 1;
  if Result then
  begin
    AKey := Fold(Trim(Copy(S, 1, P - 1)));
    AValue := Trim(Copy(S, P + 1, MaxInt));
  end;
end;

function YesNo(const S: string): Boolean;
var
  F: string;
begin
  F := Fold(S);
  Result := (F = 'da') or (F = '1') or (F = 'true') or (F = 'istina') or (F = 'yes');
end;

function CanonicalType(const S: string; out ADecimals: Integer): string;
var
  F, T: string;
  P: Integer;
begin
  ADecimals := -1;
  T := S;
  P := Pos('/', T);
  if P > 0 then begin ADecimals := StrToIntDef(Copy(T, P + 1, MaxInt), -1); T := Copy(T, 1, P - 1); end;
  F := Fold(T);
  Result := '';
  if (F = 'text') or (F = 'tekst') then Result := 'Text'
  else if (F = 'memo') or (F = 'biljeska') then Result := 'Memo'
  else if (F = 'integer') or (F = 'cijeli') or (F = 'cijelibroj') then Result := 'Integer'
  else if (F = 'decimal') or (F = 'decimalni') or (F = 'broj') then Result := 'Decimal'
  else if (F = 'currency') or (F = 'iznos') or (F = 'valuta') or (F = 'novac') then Result := 'Currency'
  else if (F = 'yesno') or (F = 'danene') or (F = 'logicki') or (F = 'boolean') then Result := 'YesNo'
  else if (F = 'date') or (F = 'datum') then Result := 'Date'
  else if (F = 'time') or (F = 'vrijeme') then Result := 'Time'
  else if (F = 'datetime') or (F = 'datumvrijeme') then Result := 'DateTime'
  else if (F = 'autonumber') or (F = 'autobroj') or (F = 'kljuc') then Result := 'AutoNumber'
  else if (F = 'picture') or (F = 'slika') then Result := 'Picture';
end;

procedure AddError(ASpec: TAppSpec; ALine: Integer; const AMsg: string);
begin
  ASpec.Errors.Add('retak ' + IntToStr(ALine) + ': ' + AMsg);
end;

{ ---------------- citanje ---------------- }

function ParseAppSpec(const AText: string; ASpec: TAppSpec): Boolean;
var
  L: TStringList;
  I, Ind, FieldInd: Integer;
  Raw, Line, Kw, Rest, Key, Val, Nm, R2: string;
  T: TSpecTable;
  Fld: TSpecField;
  Fm: TSpecForm;
  Rp: TSpecReport;
  Qy: TSpecQuery;
  Mi: TSpecMenuItem;
  Ty: TSpecType;
  Rg: TSpecRight;
  Tk: TStringList;
  Section: string;
  K, P, Dec: Integer;
  Typ: string;

  { sljedeci neprazni redak koji nije komentar; False na kraju }
  function Next(out ALineNo: Integer; out AIndent: Integer; out AText: string): Boolean;
  begin
    Result := False;
    while I < L.Count do
    begin
      Raw := L[I];
      Inc(I);
      Line := Trim(Raw);
      if (Line = '') or (Copy(Line, 1, 2) = '//') then Continue;
      ALineNo := I;
      AIndent := IndentOf(Raw);
      AText := Line;
      Exit(True);
    end;
  end;

  procedure ApplyFieldOption(AF: TSpecField; const AOpt: string; ALine: Integer);
  var
    F, V: string;
    Q: Integer;
  begin
    Q := Pos('=', AOpt);
    if Q > 0 then begin F := Fold(Copy(AOpt, 1, Q - 1)); V := Copy(AOpt, Q + 1, MaxInt); end
    else begin F := Fold(AOpt); V := ''; end;
    if (F = 'obavezno') or (F = 'obvezno') then AF.Required := True
    else if (F = 'kaskada') then AF.Cascade := True
    else if (F = 'zadano') then AF.Default := V
    else if (F = 'veza') then AF.Ref := V
    else if (F = 'opis') then AF.Descr := V
    else AddError(ASpec, ALine, 'nepoznato svojstvo polja "' + AOpt + '"');
  end;

  procedure ParseTable(const AHead: string; ALine: Integer);
  var
    Cap, Tail, Tb: string;
    LNo, LInd: Integer;
    LTxt: string;
    Pos0: Integer;
    J: Integer;
    Last: TSpecField;
  begin
    T := TSpecTable.Create;
    T.Line := ALine;
    T.Name := ReadName(AHead, Tail);
    Cap := '';
    if (Tail <> '') and (Tail[1] = '"') then begin Tb := Tail; Cap := ReadName(Tb, Tail); end;
    T.Caption := Cap;
    Tk := TStringList.Create;
    try
      Tokens(Tail, Tk);
      for J := 0 to Tk.Count - 1 do
      begin
        Tb := Fold(Tk[J]);
        if Tb = 'bezforme' then T.NoForm := True
        else if Tb = 'bezizvjesca' then T.NoReport := True
        else AddError(ASpec, ALine, 'nepoznata oznaka tablice "' + Tk[J] + '"');
      end;
    finally
      Tk.Free;
    end;
    if ASpec.FindTable(T.Name) <> nil then AddError(ASpec, ALine, 'tablica "' + T.Name + '" je vec opisana');
    ASpec.Tables.Add(T);
    Last := nil;
    FieldInd := -1;
    while True do
    begin
      Pos0 := I;
      if not Next(LNo, LInd, LTxt) then Break;
      if LInd = 0 then begin I := Pos0; Break; end;
      if FieldInd < 0 then FieldInd := LInd;
      if LInd > FieldInd then
      begin
        { svojstvo prethodnog polja: kljuc: vrijednost }
        if (Last = nil) or not SplitProp(LTxt, Key, Val) then begin AddError(ASpec, LNo, 'ocekivano "svojstvo: vrijednost"'); Continue; end;
        if Key = 'zadano' then Last.Default := Val
        else if Key = 'pravilo' then
        begin
          P := Pos('|', Val);
          if P > 0 then begin Last.Rule := Trim(Copy(Val, 1, P - 1)); Last.RuleMsg := Trim(Copy(Val, P + 1, MaxInt)); end
          else Last.Rule := Val;
        end
        else if Key = 'opis' then Last.Descr := Val
        else if Key = 'veza' then Last.Ref := Val
        else AddError(ASpec, LNo, 'nepoznato svojstvo polja "' + Key + '"');
        Continue;
      end;
      Tk := TStringList.Create;
      try
        Tokens(LTxt, Tk);
        if Tk.Count < 2 then begin AddError(ASpec, LNo, 'polje treba naziv i vrstu, npr. "naziv Text obavezno"'); Continue; end;
        Fld := TSpecField.Create;
        Fld.Line := LNo;
        Fld.Name := Tk[0];
        Typ := CanonicalType(Tk[1], Dec);
        if Typ = '' then AddError(ASpec, LNo, 'nepoznata vrsta polja "' + Tk[1] + '"')
        else
        begin
          Fld.Typ := Typ;
          if Dec >= 0 then Fld.Typ := Typ + '/' + IntToStr(Dec);
        end;
        for J := 2 to Tk.Count - 1 do ApplyFieldOption(Fld, Tk[J], LNo);
        if T.FieldByName(Fld.Name) <> nil then AddError(ASpec, LNo, 'polje "' + Fld.Name + '" je vec u tablici ' + T.Name);
        T.Fields.Add(Fld);
        Last := Fld;
      finally
        Tk.Free;
      end;
    end;
  end;

  procedure ParseForm(const AHead: string; ALine: Integer);
  var
    Tail: string;
    LNo, LInd, Pos0, Q2: Integer;
    LTxt: string;
  begin
    Fm := TSpecForm.Create;
    Fm.Line := ALine;
    Fm.Name := ReadName(AHead, Tail);
    if Tail <> '' then
    begin
      Tk := TStringList.Create;
      try
        Tokens(Tail, Tk);
        for Q2 := 0 to Tk.Count - 1 do
          if Fold(Copy(Tk[Q2], 1, 6)) = 'izvor=' then Fm.Source := Copy(Tk[Q2], 7, MaxInt)
          else AddError(ASpec, ALine, 'nepoznato uz formu: "' + Tk[Q2] + '"');
      finally
        Tk.Free;
      end;
    end;
    if ASpec.FindForm(Fm.Name) <> nil then AddError(ASpec, ALine, 'forma "' + Fm.Name + '" je vec opisana');
    ASpec.Forms.Add(Fm);
    while True do
    begin
      Pos0 := I;
      if not Next(LNo, LInd, LTxt) then Break;
      if LInd = 0 then begin I := Pos0; Break; end;
      if not SplitProp(LTxt, Key, Val) then begin AddError(ASpec, LNo, 'ocekivano "svojstvo: vrijednost"'); Continue; end;
      if (Key = 'izvor') or (Key = 'tablica') then Fm.Source := Val
      else if Key = 'naslov' then Fm.Title := Val
      else if Key = 'raspored' then Fm.Layout := Fold(Val)
      else if Key = 'crta' then begin Fm.Timeline := Val; if Fm.Layout = '' then Fm.Layout := 'crta'; end
      else if Key = 'nadzor' then begin Fm.Dash := Val; if Fm.Layout = '' then Fm.Layout := 'nadzor'; end
      else if Key = 'ploca' then begin Fm.Board := Val; if Fm.Layout = '' then Fm.Layout := 'ploca'; end
      else if Key = 'polja' then Fm.Fields := Val
      else if Key = 'detalji' then Fm.Details := Val
      else if Key = 'zbroj' then Fm.Sum := Val
      else if Key = 'izracun' then Fm.CalcRules.Add(Val)
      else if Key = 'autofill' then Fm.AutoFill.Add(Val)
      else if Key = 'izracunato' then Fm.Calcs.Add(Val)
      else if Key = 'skupina' then Fm.Group := Val
      else if Key = 'dokument' then
      begin
        P := Pos(',', Val);
        if P > 0 then begin Fm.DocType := Trim(Copy(Val, 1, P - 1)); Fm.DocNumber := Trim(Copy(Val, P + 1, MaxInt)); end
        else AddError(ASpec, LNo, 'dokument: polje_vrste, polje_broja');
      end
      else AddError(ASpec, LNo, 'nepoznato svojstvo forme "' + Key + '"');
    end;
  end;

  procedure ParseReport(const AHead: string; ALine: Integer);
  var
    Tail: string;
    LNo, LInd, Pos0: Integer;
    LTxt: string;
  begin
    Rp := TSpecReport.Create;
    Rp.Line := ALine;
    Rp.Name := ReadName(AHead, Tail);
    Rp.Kind := 'tablicno';
    if ASpec.FindReport(Rp.Name) <> nil then AddError(ASpec, ALine, 'izvjesce "' + Rp.Name + '" je vec opisano');
    ASpec.Reports.Add(Rp);
    while True do
    begin
      Pos0 := I;
      if not Next(LNo, LInd, LTxt) then Break;
      if LInd = 0 then begin I := Pos0; Break; end;
      if not SplitProp(LTxt, Key, Val) then begin AddError(ASpec, LNo, 'ocekivano "svojstvo: vrijednost"'); Continue; end;
      if Key = 'izvor' then Rp.Source := Val
      else if Key = 'naslov' then Rp.Title := Val
      else if Key = 'vrsta' then Rp.Kind := Fold(Val)
      else if Key = 'polja' then Rp.Fields := Val
      else if Key = 'grupa' then Rp.GroupBy := Val
      else if Key = 'poredak' then Rp.SortBy := Val
      else if (Key = 'sirine') or (Key = 'sirina') then Rp.Widths := Val
      else if (Key = 'opadajuce') then Rp.Desc := YesNo(Val)
      else if (Key = 'zbrojevi') then Rp.Sums := YesNo(Val)
      else if Key = 'grafikon' then Rp.Charts.Add(Val)
      else AddError(ASpec, LNo, 'nepoznato svojstvo izvjesca "' + Key + '"');
    end;
  end;

  procedure ParseQuery(const AHead: string; ALine: Integer);
  var
    Tail: string;
    LNo, LInd, Pos0: Integer;
    LTxt: string;
  begin
    Qy := TSpecQuery.Create;
    Qy.Line := ALine;
    Qy.Name := ReadName(AHead, Tail);
    ASpec.Queries.Add(Qy);
    while True do
    begin
      Pos0 := I;
      if not Next(LNo, LInd, LTxt) then Break;
      if LInd = 0 then begin I := Pos0; Break; end;
      if Qy.Sql <> '' then Qy.Sql := Qy.Sql + LineEnding;
      Qy.Sql := Qy.Sql + LTxt;
    end;
    if Qy.Sql = '' then AddError(ASpec, ALine, 'upit "' + Qy.Name + '" nema SQL');
  end;

  { program Naziv: tijelo je uvuceno ispod naslova (uvlaka prvog retka se skida, ostatak ostaje),
    ili jedan redak "datoteka: put.4gl" (put je relativan prema opisu) }
  procedure ParseProgram(const AHead: string; ALine: Integer);
  var
    Pg: TSpecProgram;
    Tail, Body, Path: string;
    LNo, LInd, Pos0, Base, K: Integer;
    LTxt: string;
    Fl: TStringList;
    First: Boolean;
  begin
    Pg := TSpecProgram.Create;
    Pg.Line := ALine;
    Pg.Name := ReadName(AHead, Tail);
    for K := 0 to ASpec.Programs.Count - 1 do
      if SameText(TSpecProgram(ASpec.Programs[K]).Name, Pg.Name) then
        AddError(ASpec, ALine, 'program "' + Pg.Name + '" je vec opisan');
    ASpec.Programs.Add(Pg);
    Body := '';
    Base := 0;
    First := True;
    while True do
    begin
      Pos0 := I;
      if not Next(LNo, LInd, LTxt) then Break;
      if LInd = 0 then begin I := Pos0; Break; end;
      if First then Base := Length(Raw) - Length(TrimLeft(Raw));
      if First and (Fold(Copy(LTxt, 1, 8)) = 'datoteka') and (Copy(Trim(Copy(LTxt, 9, MaxInt)), 1, 1) = ':') then
      begin
        Path := Trim(Copy(Trim(Copy(LTxt, 9, MaxInt)), 2, MaxInt));
        if (Path <> '') and (Path[1] <> '/') and (ASpec.BaseDir <> '') then Path := IncludeTrailingPathDelimiter(ASpec.BaseDir) + Path;
        if (Path <> '') and (Path[1] <> '/') then
          AddError(ASpec, LNo, 'program "' + Pg.Name + '": relativna datoteka se cita samo uz opis iz datoteke')
        else if not FileExists(Path) then
          AddError(ASpec, LNo, 'program "' + Pg.Name + '": nema datoteke "' + Path + '"')
        else
        begin
          Fl := TStringList.Create;
          try
            Fl.LoadFromFile(Path);
            Body := TrimRight(Fl.Text);
          finally
            Fl.Free;
          end;
        end;
        { sve ostalo ispod ovog retka se preskace }
        while True do
        begin
          Pos0 := I;
          if not Next(LNo, LInd, LTxt) then Break;
          if LInd = 0 then begin I := Pos0; Break; end;
          AddError(ASpec, LNo, 'program "' + Pg.Name + '": uz datoteka: nema drugih redaka');
        end;
        Break;
      end;
      First := False;
      if Body <> '' then Body := Body + LineEnding;
      if Length(Raw) - Length(TrimLeft(Raw)) >= Base then Body := Body + TrimRight(Copy(Raw, Base + 1, MaxInt))
      else Body := Body + LTxt;
    end;
    Pg.Text := Body;
    if Trim(Body) = '' then AddError(ASpec, ALine, 'program "' + Pg.Name + '" nema teksta');
  end;

  procedure ParseMenu(ALine: Integer);
  var
    LNo, LInd, Pos0, A: Integer;
    LTxt, Cap, Act, Verb, Arg: string;
  begin
    while True do
    begin
      Pos0 := I;
      if not Next(LNo, LInd, LTxt) then Break;
      if LInd = 0 then begin I := Pos0; Break; end;
      Mi := TSpecMenuItem.Create;
      Mi.Line := LNo;
      if LTxt[1] = '#' then
      begin
        Mi.IsGroup := True;
        Mi.Caption := Trim(Copy(LTxt, 2, MaxInt));
        ASpec.Menu.Add(Mi);
        Continue;
      end;
      A := Pos('->', LTxt);
      if A = 0 then begin AddError(ASpec, LNo, 'stavka izbornika: Natpis -> forma Naziv'); Mi.Free; Continue; end;
      Cap := Trim(Copy(LTxt, 1, A - 1));
      Act := Trim(Copy(LTxt, A + 2, MaxInt));
      Verb := Fold(Copy(Act, 1, Pos(' ', Act + ' ') - 1));
      Arg := Trim(Copy(Act, Pos(' ', Act + ' ') + 1, MaxInt));
      Mi.Caption := Cap;
      if Verb = 'forma' then
      begin
        { "forma Dokument vrsta=otp" -> openform:Dokument#vrsta=otp }
        P := Pos(' vrsta=', Arg);
        if P > 0 then Mi.Action := 'openform:' + Trim(Copy(Arg, 1, P - 1)) + '#vrsta=' + Trim(Copy(Arg, P + 7, MaxInt))
        else Mi.Action := 'openform:' + Arg;
      end
      else if Verb = 'izvjesce' then Mi.Action := 'openreport:' + Arg
      else if Verb = 'makro' then Mi.Action := 'macro:' + Arg
      else if Verb = 'program' then Mi.Action := 'fgl:' + Arg      { 4GL program iz baze (ne procedura modula) }
      else if Verb = 'zatvori' then Mi.Action := 'close'
      else if Pos(':', Act) > 0 then Mi.Action := Act
      else begin AddError(ASpec, LNo, 'nepoznata radnja "' + Act + '" (forma, izvjesce, makro, program, zatvori)'); Mi.Free; Continue; end;
      ASpec.Menu.Add(Mi);
    end;
  end;

  procedure ParseRights(ALine: Integer);
  var
    LNo, LInd, Pos0: Integer;
    LTxt, K0, Role: string;
  begin
    while True do
    begin
      Pos0 := I;
      if not Next(LNo, LInd, LTxt) then Break;
      if LInd = 0 then begin I := Pos0; Break; end;
      P := Pos(':', LTxt);
      if P = 0 then begin AddError(ASpec, LNo, 'prava: forma Naziv: korisnik'); Continue; end;
      Role := Fold(Trim(Copy(LTxt, P + 1, MaxInt)));
      K0 := Trim(Copy(LTxt, 1, P - 1));
      Rg := TSpecRight.Create;
      Rg.Line := LNo;
      Rg.Kind := Fold(Copy(K0, 1, Pos(' ', K0 + ' ') - 1));
      Rg.Name := Trim(Copy(K0, Pos(' ', K0 + ' ') + 1, MaxInt));
      if (Role = 'gost') or (Role = 'pregled') or (Role = 'viewer') then Rg.Role := 'viewer'
      else if (Role = 'korisnik') or (Role = 'user') then Rg.Role := 'user'
      else if (Role = 'admin') or (Role = 'administrator') then Rg.Role := 'admin'
      else begin AddError(ASpec, LNo, 'nepoznata uloga "' + Role + '" (pregled, korisnik, admin)'); Rg.Free; Continue; end;
      if (Rg.Kind <> 'forma') and (Rg.Kind <> 'izvjesce') and (Rg.Kind <> 'makro') and (Rg.Kind <> 'upit') then
      begin AddError(ASpec, LNo, 'prava se zadaju za forma, izvjesce, makro ili upit'); Rg.Free; Continue; end;
      ASpec.Rights.Add(Rg);
    end;
  end;

  procedure ParseKeyValueBlock(AIsApp: Boolean);
  var
    LNo, LInd, Pos0: Integer;
    LTxt: string;
  begin
    while True do
    begin
      Pos0 := I;
      if not Next(LNo, LInd, LTxt) then Break;
      if LInd = 0 then begin I := Pos0; Break; end;
      P := Pos(':', LTxt);
      if P = 0 then begin AddError(ASpec, LNo, 'ocekivano "kljuc: vrijednost"'); Continue; end;
      if AIsApp then
      begin
        SplitProp(LTxt, Key, Val);
        if Key = 'naslov' then ASpec.Title := Val
        else if (Key = 'pocetna') then ASpec.Startup := Val
        else if (Key = 'izbornik') then ASpec.MenuStyle := Fold(Val)
        else AddError(ASpec, LNo, 'nepoznato svojstvo aplikacije "' + Key + '"');
      end
      else
        ASpec.Settings.Add(Trim(Copy(LTxt, 1, P - 1)) + '=' + Trim(Copy(LTxt, P + 1, MaxInt)));
    end;
  end;

begin
  ASpec.Errors.Clear;
  L := TStringList.Create;
  try
    L.Text := AText;
    I := 0;
    while True do
    begin
      if not Next(K, Ind, Line) then Break;
      if Ind > 0 then begin AddError(ASpec, K, 'neocekivana uvlaka izvan odjeljka'); Continue; end;
      Kw := Fold(Copy(Line, 1, Pos(' ', Line + ' ') - 1));
      Rest := Trim(Copy(Line, Pos(' ', Line + ' ') + 1, MaxInt));
      if Kw = 'aplikacija' then begin ASpec.AppName := ReadName(Rest, R2); ParseKeyValueBlock(True); end
      else if Kw = 'tablica' then ParseTable(Rest, K)
      else if Kw = 'forma' then ParseForm(Rest, K)
      else if (Kw = 'izvjesce') or (Kw = 'izvjestaj') then ParseReport(Rest, K)
      else if Kw = 'upit' then ParseQuery(Rest, K)
      else if Kw = 'program' then ParseProgram(Rest, K)
      else if Kw = 'izbornik' then ParseMenu(K)
      else if Kw = 'prava' then ParseRights(K)
      else if Kw = 'postavke' then ParseKeyValueBlock(False)
      else if Kw = 'vrsta' then
      begin
        Ty := TSpecType.Create;
        Ty.Line := K;
        Ty.Code := ReadName(Rest, R2);
        Nm := '';
        if (R2 <> '') and (R2[1] = '"') then begin Key := R2; Nm := ReadName(Key, R2); end;
        Ty.Name := Nm;
        Tk := TStringList.Create;
        try
          Tokens(R2, Tk);
          for P := 0 to Tk.Count - 1 do
          begin
            Key := Fold(Copy(Tk[P], 1, Pos('=', Tk[P] + '=') - 1));
            Val := Copy(Tk[P], Pos('=', Tk[P] + '=') + 1, MaxInt);
            if Key = 'prefiks' then Ty.Prefix := Val
            else if Key = 'oblik' then Ty.Format := Val
            else if Key = 'srodne' then Ty.Related := Val
            else AddError(ASpec, K, 'nepoznato uz vrstu: "' + Tk[P] + '"');
          end;
        finally
          Tk.Free;
        end;
        ASpec.Types.Add(Ty);
      end
      else AddError(ASpec, K, 'nepoznat odjeljak "' + Copy(Line, 1, Pos(' ', Line + ' ') - 1) + '"');
    end;
  finally
    L.Free;
  end;
  Result := ASpec.Errors.Count = 0;
end;

{ ---------------- provjera ---------------- }

function SplitList(const S: string): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  Result.CommaText := S;
  for I := Result.Count - 1 downto 0 do
  begin
    Result[I] := Trim(Result[I]);
    if Result[I] = '' then Result.Delete(I);
  end;
end;

{ "stavke(dokument_id), druga" -> tablica|fk }
procedure ParseDetails(const S: string; AList: TStrings);
var
  L: TStringList;
  I, P: Integer;
  T, F: string;
begin
  AList.Clear;
  L := SplitList(S);
  try
    for I := 0 to L.Count - 1 do
    begin
      P := Pos('(', L[I]);
      if P > 0 then begin T := Trim(Copy(L[I], 1, P - 1)); F := Trim(Copy(L[I], P + 1, Pos(')', L[I]) - P - 1)); end
      else begin T := L[I]; F := ''; end;
      AList.Add(T + '|' + F);
    end;
  finally
    L.Free;
  end;
end;

function ValidateAppSpec(ASpec: TAppSpec): Boolean;
var
  I, J, P: Integer;
  T, T2: TSpecTable;
  F: TSpecField;
  Fm: TSpecForm;
  Rp: TSpecReport;
  Mi: TSpecMenuItem;
  Ty: TSpecType;
  Rg: TSpecRight;
  L, D: TStringList;
  Rt, Rc, Nm, Verb, Arg: string;
  Seen: TStringList;
begin
  { tablice: veze }
  for I := 0 to ASpec.Tables.Count - 1 do
  begin
    T := TSpecTable(ASpec.Tables[I]);
    if T.Fields.Count = 0 then AddError(ASpec, T.Line, 'tablica "' + T.Name + '" nema polja');
    for J := 0 to T.Fields.Count - 1 do
    begin
      F := TSpecField(T.Fields[J]);
      if F.Ref <> '' then
      begin
        P := Pos('.', F.Ref);
        if P = 0 then begin AddError(ASpec, F.Line, 'veza mora biti tablica.polje, a ne "' + F.Ref + '"'); Continue; end;
        Rt := Copy(F.Ref, 1, P - 1);
        Rc := Copy(F.Ref, P + 1, MaxInt);
        T2 := ASpec.FindTable(Rt);
        if (T2 = nil) then AddError(ASpec, F.Line, 'veza vodi na nepoznatu tablicu "' + Rt + '"')
        else if (not SameText(Rc, 'id')) and (T2.FieldByName(Rc) = nil) then AddError(ASpec, F.Line, 'tablica "' + Rt + '" nema polje "' + Rc + '"');
      end;
      if Pos('|', F.Default) > 0 then AddError(ASpec, F.Line, 'zadana vrijednost ne smije sadrzavati znak |');
    end;
  end;
  { forme }
  for I := 0 to ASpec.Forms.Count - 1 do
  begin
    Fm := TSpecForm(ASpec.Forms[I]);
    if Fm.Source = '' then Fm.Source := Fm.Name;
    if ((Fm.Dash <> '') or (Fm.Timeline <> '')) and ((FindQuerySql(ASpec, Fm.Source) <> '') or (ASpec.FindTable(Fm.Source) <> nil)) then Continue;   { nadzorna ploca nad upitom iz opisa }
    T := ASpec.FindTable(Fm.Source);
    if T = nil then begin AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": nema tablice "' + Fm.Source + '"'); Continue; end;
    Fm.Source := T.Name;
    if Fm.Board <> '' then
    begin
      L := TStringList.Create;
      try
        L.Delimiter := '|';
        L.StrictDelimiter := True;
        L.DelimitedText := Fm.Board;
        if (L.Count < 1) or (Trim(L[0]) = '') then AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": ploca trazi polje stupaca')
        else if (T.FieldByName(Trim(L[0])) = nil) then AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": tablica ' + T.Name + ' nema polje "' + Trim(L[0]) + '"')
        else if TSpecField(T.FieldByName(Trim(L[0]))).Ref = '' then AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": polje stupaca "' + Trim(L[0]) + '" mora imati vezu (veza=tablica.polje)');
        if (L.Count > 1) and (Trim(L[1]) <> '') and (T.FieldByName(Trim(L[1])) = nil) then
          AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": tablica ' + T.Name + ' nema polje "' + Trim(L[1]) + '"');
      finally
        L.Free;
      end;
    end;
    if Fm.Fields <> '' then
    begin
      L := SplitList(Fm.Fields);
      try
        for J := 0 to L.Count - 1 do
          if (T.FieldByName(L[J]) = nil) and not SameText(L[J], 'id') then AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": tablica ' + T.Name + ' nema polje "' + L[J] + '"');
      finally
        L.Free;
      end;
    end;
    if Fm.Details <> '' then
    begin
      D := TStringList.Create;
      try
        ParseDetails(Fm.Details, D);
        for J := 0 to D.Count - 1 do
        begin
          Nm := Copy(D[J], 1, Pos('|', D[J]) - 1);
          T2 := ASpec.FindTable(Nm);
          if T2 = nil then AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": detalji vode na nepoznatu tablicu "' + Nm + '"')
          else
          begin
            Rc := Copy(D[J], Pos('|', D[J]) + 1, MaxInt);
            if (Rc <> '') and (T2.FieldByName(Rc) = nil) then AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": tablica ' + Nm + ' nema polje "' + Rc + '"');
          end;
        end;
      finally
        D.Free;
      end;
    end;
    if (Fm.DocType <> '') and ((T.FieldByName(Fm.DocType) = nil) or (T.FieldByName(Fm.DocNumber) = nil)) then
      AddError(ASpec, Fm.Line, 'forma "' + Fm.Name + '": dokument: polja vrste i broja moraju biti u tablici ' + T.Name);
  end;
  { izvjesca }
  for I := 0 to ASpec.Reports.Count - 1 do
  begin
    Rp := TSpecReport(ASpec.Reports[I]);
    if Rp.Kind = 'grafikoni' then
    begin
      { vise grafikona na jednoj stranici; svaki "Naslov | bar/line/pie | upit iz opisa ili SELECT" }
      if Rp.Charts.Count = 0 then AddError(ASpec, Rp.Line, 'izvjesce "' + Rp.Name + '": vrsta grafikoni trazi barem jedan redak "grafikon: Naslov | tip | upit"');
      for J := 0 to Rp.Charts.Count - 1 do
      begin
        L := SplitBar(Rp.Charts[J]);
        try
          if L.Count <> 3 then AddError(ASpec, Rp.Line, 'izvjesce "' + Rp.Name + '": grafikon mora biti "Naslov | tip | upit"')
          else
          begin
            if (L[1] <> 'bar') and (L[1] <> 'line') and (L[1] <> 'pie') then AddError(ASpec, Rp.Line, 'izvjesce "' + Rp.Name + '": tip grafikona je bar, line ili pie');
            if (UpperCase(Copy(L[2], 1, 6)) <> 'SELECT') and (FindQuerySql(ASpec, L[2]) = '') then
              AddError(ASpec, Rp.Line, 'izvjesce "' + Rp.Name + '": nema upita "' + L[2] + '" za grafikon "' + L[0] + '"');
          end;
        finally
          L.Free;
        end;
      end;
      Continue;
    end;
    if Rp.Source = '' then begin AddError(ASpec, Rp.Line, 'izvjesce "' + Rp.Name + '" nema izvor'); Continue; end;
    T := ASpec.FindTable(Rp.Source);
    if T = nil then
    begin
      { izvor moze biti upit iz opisa }
      Seen := TStringList.Create;
      try
        for J := 0 to ASpec.Queries.Count - 1 do Seen.Add(TSpecQuery(ASpec.Queries[J]).Name);
        if Seen.IndexOf(Rp.Source) < 0 then AddError(ASpec, Rp.Line, 'izvjesce "' + Rp.Name + '": nema tablice ni upita "' + Rp.Source + '"');
      finally
        Seen.Free;
      end;
    end
    else if Rp.Fields <> '' then
    begin
      L := SplitList(Rp.Fields);
      try
        for J := 0 to L.Count - 1 do
          if (T.FieldByName(L[J]) = nil) and not SameText(L[J], 'id') then AddError(ASpec, Rp.Line, 'izvjesce "' + Rp.Name + '": tablica ' + T.Name + ' nema polje "' + L[J] + '"');
      finally
        L.Free;
      end;
    end;
    if (Rp.Kind <> 'tablicno') and (Rp.Kind <> 'stupcano') and (Rp.Kind <> 'naljepnice') and (Rp.Kind <> 'sazetak') then
      AddError(ASpec, Rp.Line, 'izvjesce "' + Rp.Name + '": nepoznata vrsta "' + Rp.Kind + '" (tablicno, stupcano, naljepnice, sazetak, grafikoni)');
  end;
  { izbornik: forme i izvjesca koja se otvaraju moraju postojati (u opisu, ili ce se sama izraditi) }
  for I := 0 to ASpec.Menu.Count - 1 do
  begin
    Mi := TSpecMenuItem(ASpec.Menu[I]);
    if Mi.IsGroup then Continue;
    P := Pos(':', Mi.Action);
    if P = 0 then Continue;
    Verb := LowerCase(Copy(Mi.Action, 1, P - 1));
    Arg := Copy(Mi.Action, P + 1, MaxInt);
    if Pos('#', Arg) > 0 then Arg := Copy(Arg, 1, Pos('#', Arg) - 1);
    if Verb = 'openform' then
    begin
      if (ASpec.FindForm(Arg) = nil) and (ASpec.FindTableByCaption(Arg) = nil) then
        AddError(ASpec, Mi.Line, 'izbornik: nema forme "' + Arg + '"');
    end
    else if Verb = 'openreport' then
    begin
      if (ASpec.FindReport(Arg) = nil) and not ((Copy(Arg, 1, 7) = 'Popis: ') and (ASpec.FindTableByCaption(Copy(Arg, 8, MaxInt)) <> nil)) then
        AddError(ASpec, Mi.Line, 'izbornik: nema izvjesca "' + Arg + '"');
    end;
  end;
  { vrste dokumenata: srodne moraju biti poznate }
  for I := 0 to ASpec.Types.Count - 1 do
  begin
    Ty := TSpecType(ASpec.Types[I]);
    L := SplitList(Ty.Related);
    try
      for J := 0 to L.Count - 1 do
      begin
        P := 0;
        while (P < ASpec.Types.Count) and not SameText(TSpecType(ASpec.Types[P]).Code, L[J]) do Inc(P);
        if P >= ASpec.Types.Count then AddError(ASpec, Ty.Line, 'vrsta "' + Ty.Code + '": srodna vrsta "' + L[J] + '" nije opisana');
      end;
    finally
      L.Free;
    end;
  end;
  { prava }
  for I := 0 to ASpec.Rights.Count - 1 do
  begin
    Rg := TSpecRight(ASpec.Rights[I]);
    if (Rg.Kind = 'forma') and (ASpec.FindForm(Rg.Name) = nil) and (ASpec.FindTableByCaption(Rg.Name) = nil) then
      AddError(ASpec, Rg.Line, 'prava: nema forme "' + Rg.Name + '"');
    if (Rg.Kind = 'izvjesce') and (ASpec.FindReport(Rg.Name) = nil) and not ((Copy(Rg.Name, 1, 7) = 'Popis: ') and (ASpec.FindTableByCaption(Copy(Rg.Name, 8, MaxInt)) <> nil)) then
      AddError(ASpec, Rg.Line, 'prava: nema izvjesca "' + Rg.Name + '"');
  end;
  Result := ASpec.Errors.Count = 0;
end;

{ ---------------- izrada ---------------- }

function TableCaption(T: TSpecTable): string;
begin
  if T.Caption <> '' then Result := T.Caption else Result := PrettyName(T.Name);
end;

procedure MakeTables(ADb: TAppDb; ASpec: TAppSpec; ALog: TStrings);
var
  Done: TStringList;
  I, J, Progress: Integer;
  T: TSpecTable;
  F: TSpecField;
  Specs: array of string;
  N: Integer;
  Ready: Boolean;
  Rt, Flags: string;
  Existing: TStringList;
  M: TaFieldMeta;
begin
  Done := TStringList.Create;
  Existing := ADb.UserTables;
  try
    repeat
      Progress := 0;
      for I := 0 to ASpec.Tables.Count - 1 do
      begin
        T := TSpecTable(ASpec.Tables[I]);
        if Done.IndexOf(T.Name) >= 0 then Continue;
        Ready := True;
        for J := 0 to T.Fields.Count - 1 do
        begin
          F := TSpecField(T.Fields[J]);
          if F.Ref = '' then Continue;
          Rt := Copy(F.Ref, 1, Pos('.', F.Ref) - 1);
          if SameText(Rt, T.Name) then Continue;
          if (Done.IndexOf(Rt) < 0) and (Existing.IndexOf(Rt) < 0) then Ready := False;
        end;
        if not Ready then Continue;
        SetLength(Specs, 0);
        N := 0;
        if T.FieldByName('id') = nil then
        begin
          SetLength(Specs, 1);
          Specs[0] := 'id|AutoNumber';
          N := 1;
        end;
        for J := 0 to T.Fields.Count - 1 do
        begin
          F := TSpecField(T.Fields[J]);
          Flags := '';
          if F.Required then Flags := Flags + 'R';
          if F.Cascade then Flags := Flags + 'C';
          SetLength(Specs, N + 1);
          Specs[N] := F.Name + '|' + F.Typ + '|' + F.Default + '|' + F.Ref + '|' + Flags;
          Inc(N);
        end;
        EnsureTable(ADb, ALog, T.Name, Specs);
        for J := 0 to T.Fields.Count - 1 do
        begin
          F := TSpecField(T.Fields[J]);
          if F.Rule <> '' then SetRule(ADb, T.Name, F.Name, F.Rule, F.RuleMsg);
          if F.Descr <> '' then
          begin
            M := ADb.FindFieldMeta(T.Name, F.Name);
            if M <> nil then
            try
              M.Description := F.Descr;
              ADb.SaveFieldMeta(M);
            finally
              M.Free;
            end;
          end;
        end;
        Done.Add(T.Name);
        Inc(Progress);
      end;
    until Progress = 0;
    for I := 0 to ASpec.Tables.Count - 1 do
      if Done.IndexOf(TSpecTable(ASpec.Tables[I]).Name) < 0 then
        raise Exception.Create(Tr('tables cannot be created because of circular references: ') + TSpecTable(ASpec.Tables[I]).Name);
  finally
    Existing.Free;
    Done.Free;
  end;
end;

function AllFields(ADb: TAppDb; const ATable: string): TStringList;
var
  Src: TaSourceFields;
  I: Integer;
begin
  Result := TStringList.Create;
  Src := SourceFieldList(ADb, ATable);
  for I := 0 to High(Src) do
    if not SameText(Src[I].Name, 'id') then Result.Add(Src[I].Name);
end;

procedure MakeForm(ADb: TAppDb; ASpec: TAppSpec; Fm: TSpecForm; ALog: TStrings);
var
  Fl: TStringList;
  Opt: TaFormOptions;
  MM: TaMDMulti;
  MR: TaMDMultiResult;
  Mf: TaFormDef;
  Det: TStringList;
  I, K, Y, W: Integer;
  Sub: TaControlDef;
  Calc, Cap, Expr, Fmt: string;
  Lay: TaFormLayout;
begin
  { raspored (vremenska crta): forma bez kontrola, samo postavka }
  if (Fm.Layout = 'crta') or (Fm.Timeline <> '') then
  begin
    Mf := TaFormDef.Create;
    try
      Mf.Name := Fm.Name;
      if Fm.Title <> '' then Mf.Caption := Fm.Title else Mf.Caption := Fm.Name;
      Mf.RecordSource := Fm.Source;
      Mf.ViewMode := 'timeline';
      Mf.Timeline := Fm.Timeline;
      Mf.Width := 900;
      Mf.Height := 460;
      Mf.NavButtons := False;
      Mf.ExclusiveGroup := Fm.Group;
      ADb.SaveObject('_sys_forms', Mf.Name, Mf.ToJson);
      ALog.Add('izrađen raspored ' + Mf.Name);
    finally
      Mf.Free;
    end;
    Exit;
  end;
  { nadzorna ploca: forma bez kontrola, samo postavka }
  if (Fm.Layout = 'nadzor') or (Fm.Dash <> '') then
  begin
    Mf := TaFormDef.Create;
    try
      Mf.Name := Fm.Name;
      if Fm.Title <> '' then Mf.Caption := Fm.Title else Mf.Caption := Fm.Name;
      Mf.RecordSource := Fm.Source;
      Mf.ViewMode := 'dash';
      Mf.Dash := Fm.Dash;
      Mf.Width := 1000;
      Mf.Height := 600;
      Mf.NavButtons := False;
      Mf.AllowEdits := True;      { prekidaci }
      Mf.AllowAdds := False;
      Mf.AllowDeletes := False;
      Mf.ExclusiveGroup := Fm.Group;
      ADb.SaveObject('_sys_forms', Mf.Name, Mf.ToJson);
      ALog.Add('izrađena nadzorna ploča ' + Mf.Name);
    finally
      Mf.Free;
    end;
    Exit;
  end;
  { kanban ploca: forma bez kontrola, samo postavka }
  if (Fm.Layout = 'ploca') or (Fm.Board <> '') then
  begin
    Mf := TaFormDef.Create;
    try
      Mf.Name := Fm.Name;
      if Fm.Title <> '' then Mf.Caption := Fm.Title else Mf.Caption := Fm.Name;
      Mf.RecordSource := Fm.Source;
      Mf.ViewMode := 'board';
      Mf.Board := Fm.Board;
      Mf.Width := 1100;
      Mf.Height := 600;
      Mf.NavButtons := False;
      Mf.ExclusiveGroup := Fm.Group;
      ADb.SaveObject('_sys_forms', Mf.Name, Mf.ToJson);
      ALog.Add('izrađena ploča ' + Mf.Name);
    finally
      Mf.Free;
    end;
    Exit;
  end;
  Fl := nil;
  if Fm.Fields <> '' then Fl := SplitList(Fm.Fields) else Fl := AllFields(ADb, Fm.Source);
  try
    Lay := flOneColumn;
    if (Fm.Layout = 'dvastupca') or (Fm.Layout = 'dva') then Lay := flTwoColumns
    else if (Fm.Layout = 'tablica') then Lay := flDatasheet
    else if (Fm.Layout = 'podijeljeno') then Lay := flSplit
    else if (Fm.Layout = '') and (Fl.Count > 10) then Lay := flTwoColumns;
    Mf := nil;
    if Fm.Details <> '' then
    begin
      Det := TStringList.Create;
      try
        ParseDetails(Fm.Details, Det);
        MM.Master := Fm.Source; MM.Name := Fm.Name; MM.Title := Fm.Title; MM.MasterFields := Fl;
        if MM.Title = '' then MM.Title := Fm.Name;
        MM.DetailAsForm := False; MM.UseTabs := Det.Count > 1;
        SetLength(MM.Details, Det.Count);
        for I := 0 to Det.Count - 1 do
        begin
          MM.Details[I].Table := Copy(Det[I], 1, Pos('|', Det[I]) - 1);
          MM.Details[I].Fields := nil;
          MM.Details[I].SumField := '';
          MM.Details[I].ShowCount := False;
          MM.Details[I].FkCol := Copy(Det[I], Pos('|', Det[I]) + 1, MaxInt);
          MM.Details[I].ParentCol := '';
        end;
        if (Det.Count = 1) then MM.Details[0].SumField := Fm.Sum;
        MR := BuildMasterDetailMulti(ADb, MM);
        if MR.Error <> '' then raise Exception.Create(Tr('form ') + Fm.Name + ': ' + MR.Error);
        Mf := MR.MasterForm;
        for I := 0 to High(MR.Items) do MR.Items[I].Form.Free;
      finally
        Det.Free;
      end;
      Sub := nil;
      for I := 0 to Mf.Count - 1 do
        if Mf[I].Kind = 'Subform' then begin Sub := Mf[I]; Break; end;
      if Sub <> nil then
      begin
        if Fm.CalcRules.Count > 0 then Sub.SetX('calcrules', StringReplace(Trim(Fm.CalcRules.Text), LineEnding, ' ;; ', [rfReplaceAll]));
        if Fm.AutoFill.Count > 0 then Sub.SetX('autofill', Trim(Fm.AutoFill[0]));
        Sub.Width := Mf.Width - 32;
        if Sub.Height < 180 then Sub.Height := 180;
      end;
    end
    else
    begin
      Opt.Source := Fm.Source; Opt.Name := Fm.Name; Opt.Title := Fm.Title; Opt.Fields := Fl; Opt.Layout := Lay; Opt.SubTables := nil;
      if Opt.Title = '' then Opt.Title := Fm.Name;
      Mf := BuildFormEx(ADb, Opt);
    end;
    { izracunata polja pri dnu forme: Naslov = izraz | oblik }
    if Fm.Calcs.Count > 0 then
    begin
      Y := BottomOf(Mf) + 10;
      W := Mf.Width;
      for K := 0 to Fm.Calcs.Count - 1 do
      begin
        Calc := Fm.Calcs[K];
        Cap := Trim(Copy(Calc, 1, Pos('=', Calc) - 1));
        Expr := Trim(Copy(Calc, Pos('=', Calc) + 1, MaxInt));
        Fmt := '';
        if Pos('|', Expr) > 0 then begin Fmt := Trim(Copy(Expr, Pos('|', Expr) + 1, MaxInt)); Expr := Trim(Copy(Expr, 1, Pos('|', Expr) - 1)); end;
        if Fmt = '' then Fmt := '#,##0.00';
        AddCalc(Mf, Cap + ':', 'txtIzr' + IntToStr(K + 1), '=' + Expr, Fmt, W - 16 - 130 - 6 - 130, Y + K * 28, 130, K = Fm.Calcs.Count - 1);
      end;
      Mf.Height := Y + Fm.Calcs.Count * 28 + 16;
    end;
    Mf.ExclusiveGroup := Fm.Group;
    Mf.DocTypeField := Fm.DocType;
    Mf.DocNumberField := Fm.DocNumber;
    ADb.SaveObject('_sys_forms', Mf.Name, Mf.ToJson);
    ALog.Add('izrađena forma ' + Mf.Name);
    Mf.Free;
  finally
    Fl.Free;
  end;
end;

{ "a | b | c" -> trimmed parts (tip u malim slovima) }
function SplitBar(const S: string): TStringList;
var
  T: string;
  P: Integer;
begin
  Result := TStringList.Create;
  T := S;
  repeat
    P := Pos('|', T);
    if (P = 0) or (Result.Count >= 2) then begin Result.Add(Trim(T)); Break; end;
    Result.Add(Trim(Copy(T, 1, P - 1)));
    T := Copy(T, P + 1, MaxInt);
  until False;
  if Result.Count > 1 then Result[1] := LowerCase(Result[1]);
end;

function FindQuerySql(ASpec: TAppSpec; const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to ASpec.Queries.Count - 1 do
    if SameText(TSpecQuery(ASpec.Queries[I]).Name, AName) then Exit(TSpecQuery(ASpec.Queries[I]).Sql);
end;

{ vise grafikona (oznaka, vrijednost iz SQL-a), po dva u retku }
procedure MakeChartReport(ADb: TAppDb; ASpec: TAppSpec; Rp: TSpecReport; ALog: TStrings);
var
  Rd: TaReportDef;
  C: TaControlDef;
  L: TStringList;
  I, X, Y, Rows, Col: Integer;
  Sql: string;
const
  CW = 350; CH = 200; Gap = 14;
begin
  Rd := TaReportDef.Create;
  try
    Rd.Name := Rp.Name;
    if Rp.Title <> '' then Rd.Title := Rp.Title else Rd.Title := Rp.Name;
    Rd.RecordSource := '';
    Rows := (Rp.Charts.Count + 1) div 2;
    Rd.Heights[SecReportHeader] := 34 + Rows * (CH + 20 + Gap) + 10;
    Rd.Heights[SecPageHeader] := 0;
    Rd.Heights[SecDetail] := 0;
    Rd.Heights[SecPageFooter] := 24;
    C := TaControlDef.Create;
    C.Kind := 'Label'; C.Name := 'lblNaslov'; C.Section := 'ReportHeader'; C.Caption := Rd.Title; C.Bold := True;
    C.Left := 0; C.Top := 0; C.Width := 714; C.Height := 24;
    Rd.Add(C);
    for I := 0 to Rp.Charts.Count - 1 do
    begin
      L := SplitBar(Rp.Charts[I]);
      try
        if L.Count <> 3 then Continue;
        Sql := L[2];
        if UpperCase(Copy(Sql, 1, 6)) <> 'SELECT' then Sql := FindQuerySql(ASpec, Sql);
        Col := I mod 2;
        X := Col * (CW + Gap);
        Y := 34 + (I div 2) * (CH + 20 + Gap);
        C := TaControlDef.Create;
        C.Kind := 'Label'; C.Name := Rd.UniqueName('lblGraf'); C.Section := 'ReportHeader'; C.Caption := L[0]; C.Bold := True;
        C.Left := X; C.Top := Y; C.Width := CW; C.Height := 18;
        Rd.Add(C);
        C := TaControlDef.Create;
        C.Kind := 'Chart'; C.Name := Rd.UniqueName('chart'); C.Section := 'ReportHeader'; C.RowSource := Sql;
        C.SetX('chartType', L[1]);
        C.Left := X; C.Top := Y + 20; C.Width := CW; C.Height := CH;
        Rd.Add(C);
      finally
        L.Free;
      end;
    end;
    SaveReport(ADb, ALog, Rd);        { SaveReport oslobada definiciju }
  except
    Rd.Free;
    raise;
  end;
end;

procedure MakeReport(ADb: TAppDb; ASpec: TAppSpec; Rp: TSpecReport; ALog: TStrings);
var
  Fl: TStringList;
  O: TaReportOptions;
begin
  if Rp.Kind = 'grafikoni' then begin MakeChartReport(ADb, ASpec, Rp, ALog); Exit; end;
  if ASpec.FindTable(Rp.Source) <> nil then
  begin
    if Rp.Fields <> '' then Fl := SplitList(Rp.Fields) else Fl := AllFields(ADb, Rp.Source);
  end
  else
  begin
    { upit: bez popisa polja uzimaju se svi stupci upita }
    if Rp.Fields <> '' then Fl := SplitList(Rp.Fields) else Fl := AllFields(ADb, Rp.Source);
  end;
  try
    O.Source := Rp.Source; O.Name := Rp.Name; O.Title := Rp.Title;
    if O.Title = '' then O.Title := Rp.Name;
    O.GroupField := Rp.GroupBy; O.SortField := Rp.SortBy; O.Fields := Fl;
    if Rp.Kind = 'stupcano' then O.Kind := rkColumnar
    else if Rp.Kind = 'naljepnice' then O.Kind := rkLabels
    else if Rp.Kind = 'sazetak' then O.Kind := rkSummary
    else O.Kind := rkTabular;
    O.Descending := Rp.Desc; O.Sums := Rp.Sums; O.PageBreakPerRecord := False; O.LabelColumns := 3; O.LabelLines := nil; O.Widths := Rp.Widths;
    SaveReport(ADb, ALog, BuildReportEx(ADb, O));
  finally
    Fl.Free;
  end;
end;

function CompileAppSpec(ADb: TAppDb; ASpec: TAppSpec; ALog: TStrings): Boolean;
var
  I, J, K: Integer;
  T: TSpecTable;
  Fm: TSpecForm;
  Rp: TSpecReport;
  Qy: TSpecQuery;
  Mi: TSpecMenuItem;
  Ty: TSpecType;
  Rg: TSpecRight;
  DT: TaDocType;
  Items: TStringList;
  Def: TaFormDef;
  Detail, HasForm, HasReport: TStringList;
  Det: TStringList;
  S: TaAppSettings;
  Kind, MenuName, Cap: string;
  Role: TaRole;
begin
  Result := True;
  Detail := TStringList.Create;
  HasForm := TStringList.Create;
  HasReport := TStringList.Create;
  Items := TStringList.Create;
  try
    try
      for I := 0 to ASpec.Settings.Count - 1 do
        ADb.SaveSetting(ASpec.Settings.Names[I], ASpec.Settings.ValueFromIndex[I]);
      MakeTables(ADb, ASpec, ALog);
      for I := 0 to ASpec.Queries.Count - 1 do
      begin
        Qy := TSpecQuery(ASpec.Queries[I]);
        SaveQuery(ADb, ALog, Qy.Name, Qy.Sql);
      end;
      for I := 0 to ASpec.Programs.Count - 1 do
      begin
        ADb.SaveObject('_sys_programs', TSpecProgram(ASpec.Programs[I]).Name, TSpecProgram(ASpec.Programs[I]).Text + LineEnding);
        ALog.Add('izrađen program ' + TSpecProgram(ASpec.Programs[I]).Name);
      end;
      { vrste dokumenata }
      if ASpec.Types.Count > 0 then EnsureDocTypes(ADb);
      for I := 0 to ASpec.Types.Count - 1 do
      begin
        Ty := TSpecType(ASpec.Types[I]);
        if not DocTypeLoad(ADb, Ty.Code, DT) then
        begin
          DT.Code := Ty.Code; DT.Last := 0; DT.Year := 0;
        end;
        DT.Name := Ty.Name; if DT.Name = '' then DT.Name := Ty.Code;
        DT.Prefix := Ty.Prefix; if DT.Prefix = '' then DT.Prefix := Ty.Code;
        DT.Format := Ty.Format; if DT.Format = '' then DT.Format := DefaultDocFormat;
        DT.Related := Ty.Related;
        DocTypeSave(ADb, DT);
        ALog.Add('vrsta dokumenta ' + Ty.Code);
      end;
      { tablice koje su detalji nekih formi ne dobivaju vlastitu formu ni popis }
      for I := 0 to ASpec.Forms.Count - 1 do
      begin
        Fm := TSpecForm(ASpec.Forms[I]);
        HasForm.Add(LowerCase(Fm.Source));
        Det := TStringList.Create;
        try
          ParseDetails(Fm.Details, Det);
          for J := 0 to Det.Count - 1 do Detail.Add(LowerCase(Copy(Det[J], 1, Pos('|', Det[J]) - 1)));
        finally
          Det.Free;
        end;
      end;
      for I := 0 to ASpec.Reports.Count - 1 do HasReport.Add(LowerCase(TSpecReport(ASpec.Reports[I]).Source));
      { forme: opisane, pa automatske }
      for I := 0 to ASpec.Forms.Count - 1 do MakeForm(ADb, ASpec, TSpecForm(ASpec.Forms[I]), ALog);
      for I := 0 to ASpec.Tables.Count - 1 do
      begin
        T := TSpecTable(ASpec.Tables[I]);
        if T.NoForm or (HasForm.IndexOf(LowerCase(T.Name)) >= 0) or (Detail.IndexOf(LowerCase(T.Name)) >= 0) then Continue;
        Fm := TSpecForm.Create;
        try
          Fm.Name := TableCaption(T); Fm.Source := T.Name; Fm.Title := TableCaption(T);
          MakeForm(ADb, ASpec, Fm, ALog);
        finally
          Fm.Free;
        end;
      end;
      { izvjesca }
      for I := 0 to ASpec.Reports.Count - 1 do MakeReport(ADb, ASpec, TSpecReport(ASpec.Reports[I]), ALog);
      for I := 0 to ASpec.Tables.Count - 1 do
      begin
        T := TSpecTable(ASpec.Tables[I]);
        if T.NoReport or (HasReport.IndexOf(LowerCase(T.Name)) >= 0) or (Detail.IndexOf(LowerCase(T.Name)) >= 0) then Continue;
        Rp := TSpecReport.Create;
        try
          Rp.Name := 'Popis: ' + TableCaption(T); Rp.Source := T.Name; Rp.Title := TableCaption(T); Rp.Kind := 'tablicno'; Rp.Sums := False;
          MakeReport(ADb, ASpec, Rp, ALog);
        finally
          Rp.Free;
        end;
      end;
      { izbornik }
      if ASpec.Menu.Count > 0 then
      begin
        for I := 0 to ASpec.Menu.Count - 1 do
        begin
          Mi := TSpecMenuItem(ASpec.Menu[I]);
          if Mi.IsGroup then Items.Add('# ' + Mi.Caption)
          else
          begin
            Cap := Mi.Caption;
            { openform:tablica bez forme s tim imenom -> automatska forma tablice }
            Items.Add(Cap + '|' + Mi.Action);
          end;
        end;
      end
      else
      begin
        Items.Add('# Podaci');
        for I := 0 to ASpec.Forms.Count - 1 do Items.Add(TSpecForm(ASpec.Forms[I]).Name + '|openform:' + TSpecForm(ASpec.Forms[I]).Name);
        for I := 0 to ASpec.Tables.Count - 1 do
        begin
          T := TSpecTable(ASpec.Tables[I]);
          if T.NoForm or (HasForm.IndexOf(LowerCase(T.Name)) >= 0) or (Detail.IndexOf(LowerCase(T.Name)) >= 0) then Continue;
          Items.Add(TableCaption(T) + '|openform:' + TableCaption(T));
        end;
        Items.Add('# Izvješća');
        for I := 0 to ASpec.Reports.Count - 1 do Items.Add(TSpecReport(ASpec.Reports[I]).Name + '|openreport:' + TSpecReport(ASpec.Reports[I]).Name);
        for I := 0 to ASpec.Tables.Count - 1 do
        begin
          T := TSpecTable(ASpec.Tables[I]);
          if T.NoReport or (HasReport.IndexOf(LowerCase(T.Name)) >= 0) or (Detail.IndexOf(LowerCase(T.Name)) >= 0) then Continue;
          Items.Add('Popis: ' + TableCaption(T) + '|openreport:Popis: ' + TableCaption(T));
        end;
        Items.Add('Izlaz|close');
      end;
      { stavke koje upucuju na tablicu umjesto forme: automatska forma ima naziv tablice }
      for I := 0 to Items.Count - 1 do
        if Pos('|openform:', Items[I]) > 0 then
        begin
          K := Pos('|openform:', Items[I]);
          Cap := Copy(Items[I], K + 10, MaxInt);
          if Pos('#', Cap) > 0 then Cap := Copy(Cap, 1, Pos('#', Cap) - 1);
          T := ASpec.FindTableByCaption(Cap);
          if (T <> nil) and (ASpec.FindForm(Cap) = nil) then
            Items[I] := Copy(Items[I], 1, K + 9) + TableCaption(T) + Copy(Items[I], K + 10 + Length(Cap), MaxInt);
        end;
      MenuName := ASpec.Startup;
      if MenuName = '' then MenuName := 'Izbornik';
      if ASpec.MenuStyle = 'gumbi' then Def := BuildSwitchboard(MenuName, ASpec.Title, Items)
      else if ASpec.MenuStyle = 'glavna' then Def := BuildMainForm(MenuName, ASpec.Title, Items)
      else Def := BuildSideBoard(MenuName, ASpec.Title, Items);
      if ASpec.Title = '' then Def.Caption := MenuName;
      ADb.SaveObject('_sys_forms', MenuName, Def.ToJson);
      Def.Free;
      ALog.Add('izrađen izbornik ' + MenuName);
      S := LoadAppSettings(ADb);
      if ASpec.Title <> '' then S.Title := ASpec.Title else if ASpec.AppName <> '' then S.Title := ASpec.AppName;
      S.StartupForm := MenuName;
      SaveAppSettings(ADb, S);
      { prava }
      for I := 0 to ASpec.Rights.Count - 1 do
      begin
        Rg := TSpecRight(ASpec.Rights[I]);
        if Rg.Role = 'admin' then Role := arAdmin else if Rg.Role = 'user' then Role := arUser else Role := arViewer;
        if Rg.Kind = 'forma' then Kind := '_sys_forms'
        else if Rg.Kind = 'izvjesce' then Kind := '_sys_reports'
        else if Rg.Kind = 'makro' then Kind := '_sys_macros'
        else Kind := '_sys_queries';
        SetObjectRight(ADb, Kind, Rg.Name, Role);
      end;
    except
      on E: Exception do
      begin
        ALog.Add('GREŠKA: ' + E.Message);
        Result := False;
      end;
    end;
  finally
    Items.Free;
    HasReport.Free;
    HasForm.Free;
    Detail.Free;
  end;
end;

function BuildAppFromSpecText(ADb: TAppDb; const AText: string; ALog: TStrings; const ABaseDir: string): Boolean;
var
  Spec: TAppSpec;
  I: Integer;
begin
  Spec := TAppSpec.Create;
  try
    Spec.BaseDir := ABaseDir;
    if not ParseAppSpec(AText, Spec) then
    begin
      for I := 0 to Spec.Errors.Count - 1 do ALog.Add('GREŠKA ' + Spec.Errors[I]);
      Exit(False);
    end;
    if not ValidateAppSpec(Spec) then
    begin
      for I := 0 to Spec.Errors.Count - 1 do ALog.Add('GREŠKA ' + Spec.Errors[I]);
      Exit(False);
    end;
    Result := CompileAppSpec(ADb, Spec, ALog);
  finally
    Spec.Free;
  end;
end;

end.
