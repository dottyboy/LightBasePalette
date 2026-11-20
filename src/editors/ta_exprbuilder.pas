unit ta_exprbuilder;
{ Expression builder: pick fields and functions by category, start from a ready
  example, type an expression and check it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ExtCtrls, StdCtrls, Graphics, ta_meta, ta_expr, ta_wizardgen, ta_editor;

{ ASource: table or saved query whose fields are offered. }
function EditExpression(AOwner: TComponent; ADb: TAppDb; const ASource, ATitle: string;
  var AExpr: string): Boolean;

{ "category|text to insert|description", exposed so the list can be tested }
function ExpressionCatalog: TStringList;

implementation

uses
  ta_i18n;


const
  Catalog: array[0..113] of string = (
    'Tekst|Len()|duljina teksta',
    'Tekst|Left(, 3)|prvih n znakova',
    'Tekst|Right(, 3)|zadnjih n znakova',
    'Tekst|Mid(, 2, 3)|dio teksta od mjesta, n znakova',
    'Tekst|Trim()|bez razmaka na rubovima',
    'Tekst|UCase()|VELIKA slova',
    'Tekst|LCase()|mala slova',
    'Tekst|Proper()|Svaka Riječ Velikim Početnim',
    'Tekst|InStr(, )|mjesto traženog teksta (0 = nema)',
    'Tekst|Replace(, , )|zamijeni tekst',
    'Tekst|Concat(, , )|spoji više vrijednosti (prazno = ništa)',
    'Tekst|Split(, ";", 1)|n-ti dio teksta rastavljenog znakom',
    'Tekst|Shorten(, 30)|skrati tekst na n znakova s …',
    'Tekst|LPad(, 6, "0")|dopuni slijeva (vodeće nule)',
    'Tekst|RPad(, 10, ".")|dopuni zdesna',
    'Tekst|StartsWith(, "")|počinje li tekst s…',
    'Tekst|EndsWith(, "")|završava li tekst s…',
    'Tekst|Contains(, "")|sadrži li tekst…',
    'Tekst|Initials()|inicijali (Ivo Horvat = IH)',
    'Tekst|Format(, "")|oblikuj broj ili datum',
    'Brojevi|Round(, 2)|zaokruži na n decimala',
    'Brojevi|Abs()|apsolutna vrijednost',
    'Brojevi|Int()|cijeli dio (dolje)',
    'Brojevi|Ceil()|zaokruži gore',
    'Brojevi|Floor()|zaokruži dolje',
    'Brojevi|Sqr()|korijen',
    'Brojevi|Max(, )|veći od dva (ili više)',
    'Brojevi|Min(, )|manji od dva (ili više)',
    'Brojevi|Percent(, )|koliko posto je prvi broj od drugog',
    'Brojevi|Clamp(, 0, 100)|ograniči na raspon',
    'Brojevi|Eur()|iznos kao 1.234,50 €',
    'Brojevi|Val()|tekst u broj',
    'Datum|Date()|današnji datum',
    'Datum|Now()|sada (datum i vrijeme)',
    'Datum|Year()|godina',
    'Datum|Month()|mjesec',
    'Datum|Day()|dan',
    'Datum|Weekday()|dan u tjednu (nedjelja = 1)',
    'Datum|DayName()|naziv dana',
    'Datum|MonthName()|naziv mjeseca (broj 1–12)',
    'Datum|Quarter()|kvartal',
    'Datum|WeekNumber()|broj tjedna',
    'Datum|EOMonth()|zadnji dan mjeseca',
    'Datum|BOMonth()|prvi dan mjeseca',
    'Datum|AddDays(, 30)|dodaj dane',
    'Datum|AddMonths(, 1)|dodaj mjesece',
    'Datum|DateAdd("d", 1, )|dodaj interval (yyyy, q, m, d, ww, h, n, s)',
    'Datum|DateDiff("d", , )|razlika dvaju datuma u intervalima',
    'Datum|DaysBetween(, )|broj dana između',
    'Datum|WorkDays(, )|radni dani između (pon–pet)',
    'Datum|Age()|godine od datuma do danas',
    'Datum|DateSerial(, , )|datum iz godine, mjeseca, dana',
    'Datum|CDate()|tekst u datum',
    'Logika|Iif(, , )|ako je uvjet istinit prvo, inače drugo',
    'Logika|Switch(, , , )|prvi istiniti uvjet daje vrijednost',
    'Logika|Choose(, , )|odaberi n-tu vrijednost',
    'Logika|Nz(, 0)|zamijeni prazno',
    'Logika|Coalesce(, , )|prva neprazna vrijednost',
    'Logika|NullIf(, )|prazno ako su jednaki',
    'Logika|IsNull()|je li prazno',
    'Logika|IsEmpty()|je li prazno ili samo razmaci',
    'Logika|And|i',
    'Logika|Or|ili',
    'Logika|Not|ne',
    'Logika|Between  And |unutar raspona',
    'Logika|In (, , )|jedna od vrijednosti',
    'Logika|Like "*"|usporedba s uzorkom (* ? #)',
    'Provjere|ValidOIB()|ispravan OIB',
    'Provjere|Hub3Uplata([ukupno], "Platitelj", "", "", "Primatelj", "", "", "HR...", "HR00", [broj], "", "Račun")|sadržaj HUB3 barkoda uplatnice (BarType = pdf417)',
    'Brojevi|IznosSlovima([ukupno])|iznos slovima: sto dvadeset tri eura i četrdeset pet centi',
    'Brojevi|BrojSlovima([broj])|cijeli broj slovima (tisuća, milijun...)',
    'Provjere|ValidIBAN()|ispravan IBAN',
    'Provjere|IsNumeric()|je li broj',
    'Provjere|IsDate()|je li datum',
    'Provjere|CurrentUser()|prijavljeni korisnik',
    'Provjere|CurrentRole()|uloga prijavljenog korisnika',
    'Agregati|Sum([])|zbroj (grupa ili izvješće)',
    'Agregati|Count(*)|broj redaka',
    'Agregati|Avg([])|prosjek',
    'Agregati|Min([])|najmanje',
    'Agregati|Max([])|najveće',
    'Agregati|Median([])|medijan',
    'Agregati|StDev([])|standardna devijacija',
    'Agregati|First([])|prva vrijednost',
    'Agregati|Last([])|zadnja vrijednost',
    'Agregati|SumAll([])|zbroj cijelog izvješća',
    'Agregati|CountAll(*)|broj redaka cijelog izvješća',
    'Agregati|RunSum([])|tekući zbroj od početka izvješća',
    'Agregati|RunGSum([])|tekući zbroj unutar grupe',
    'Agregati|RowNum|redni broj retka',
    'Agregati|GroupRow|redni broj retka u grupi',
    'Agregati|Page|broj stranice',
    'Agregati|Pages|ukupno stranica',
    'Agregati|SubSum("Podforma", "polje")|zbroj polja u podformi (neprekidnoj ili mreži)',
    'Agregati|SubCount("Podforma")|broj redaka podforme',
    'Agregati|SubAvg("Podforma", "polje")|prosjek polja u podformi',
    'Agregati|DLookup("", "", "")|vrijednost iz druge tablice',
    'Agregati|DSum("[]", "", "")|zbroj iz druge tablice',
    'Agregati|DCount("*", "", "")|broj redaka iz druge tablice',
    'Primjeri|[ime] & " " & [prezime]|puno ime',
    'Primjeri|Round([iznos] * 0.25, 2)|PDV 25 %',
    'Primjeri|Round([iznos] * 1.25, 2)|iznos s PDV-om',
    'Primjeri|Iif([iznos] > 1000, "Velik", "Običan")|uvjetni tekst',
    'Primjeri|Nz([iznos], 0)|prazno kao nula',
    'Primjeri|Age([datum_rodjenja])|starost u godinama',
    'Primjeri|AddDays([datum], 30)|dospijeće za 30 dana',
    'Primjeri|Iif(ValidOIB([oib]), "OK", "Neispravan OIB")|provjera OIB-a',
    'Primjeri|Percent([iznos], SumAll([iznos]))|udio retka u ukupnom (izvješće)',
    'Primjeri|RunSum([iznos])|tekući zbroj (izvješće)',
    'Primjeri|"Stranica " & Page & " / " & Pages|podnožje stranice',
    'Primjeri|DSum("[iznos]", "racun", "kupac_id = " & [id])|zbroj detalja za trenutni zapis (forma)',
    'Primjeri|DLookup("naziv", "kupac", "id = " & [kupac_id])|podatak iz povezane tablice',
    'Primjeri|LPad([broj], 6, "0")|broj s vodećim nulama',
    'Primjeri|Eur(Sum([iznos]))|zbroj kao iznos u eurima');


{ redak kataloga s prevedenom skupinom i opisom (izraz ostaje isti) }
function CatalogLine(AIndex: Integer): string;
var
  P1, P2: Integer;
  S: string;
begin
  S := Catalog[AIndex];
  P1 := Pos('|', S);
  P2 := P1 + Pos('|', Copy(S, P1 + 1, MaxInt));
  if (P1 = 0) or (P2 = P1) then Exit(S);
  Result := Tr(Copy(S, 1, P1 - 1)) + '|' + Copy(S, P1 + 1, P2 - P1 - 1) + '|' + Tr(Copy(S, P2 + 1, MaxInt));
end;

function ExpressionCatalog: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(Catalog) do Result.Add(CatalogLine(I));
end;

type
  TBuilder = class
  public
    Memo: TaEditor;
    Fields, Cats, Funcs: TListBox;
    Status, Desc: TLabel;
    Entries: TStringList;
    procedure InsertField(Sender: TObject);
    procedure InsertFunc(Sender: TObject);
    procedure CatChange(Sender: TObject);
    procedure FuncChange(Sender: TObject);
    procedure CheckClick(Sender: TObject);
    procedure Ins(const S: string);
  end;

procedure TBuilder.Ins(const S: string);
begin
  Memo.Syn.SelText := S;
  Memo.SetFocus;
end;

procedure TBuilder.InsertField(Sender: TObject);
begin
  if Fields.ItemIndex >= 0 then Ins('[' + Fields.Items[Fields.ItemIndex] + ']');
end;

procedure TBuilder.CatChange(Sender: TObject);
var
  I, P1, P2: Integer;
  Cat, Line: string;
begin
  Funcs.Items.Clear;
  Entries.Clear;
  if Cats.ItemIndex < 0 then Exit;
  Cat := Cats.Items[Cats.ItemIndex];
  for I := 0 to High(Catalog) do
  begin
    Line := CatalogLine(I);
    P1 := Pos('|', Line);
    if Copy(Line, 1, P1 - 1) <> Cat then Continue;
    P2 := Pos('|', Copy(Line, P1 + 1, MaxInt)) + P1;
    Funcs.Items.Add(Copy(Line, P1 + 1, P2 - P1 - 1));
    Entries.Add(Copy(Line, P2 + 1, MaxInt));
  end;
  Desc.Caption := '';
end;

procedure TBuilder.FuncChange(Sender: TObject);
begin
  if (Funcs.ItemIndex >= 0) and (Funcs.ItemIndex < Entries.Count) then
    Desc.Caption := Entries[Funcs.ItemIndex]
  else
    Desc.Caption := '';
end;

procedure TBuilder.InsertFunc(Sender: TObject);
begin
  if Funcs.ItemIndex >= 0 then Ins(Funcs.Items[Funcs.ItemIndex]);
end;

procedure TBuilder.CheckClick(Sender: TObject);
var
  E, Body: string;
begin
  Body := Trim(Memo.Text);
  if (Body <> '') and (Body[1] = '=') then Delete(Body, 1, 1);
  E := CheckExpr(Body);
  if E = '' then Status.Caption := Tr('The expression is valid.') else Status.Caption := Tr('Error: ') + E;
end;

function EditExpression(AOwner: TComponent; ADb: TAppDb; const ASource, ATitle: string;
  var AExpr: string): Boolean;
var
  F: TForm;
  B: TBuilder;
  L: TaSourceFields;
  I, P: Integer;
  Seen: TStringList;
begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  B := TBuilder.Create;
  B.Entries := TStringList.Create;
  Seen := TStringList.Create;
  try
    F.Caption := Tr('Expression: ') + ATitle;
    F.SetBounds(0, 0, 900, 560);
    F.Position := poOwnerFormCenter;
    B.Memo := TaEditor.Create(F);
    B.Memo.Parent := F;
    B.Memo.Variant := ewExpression;
    B.Memo.SetBounds(10, 10, 876, 130);
    B.Memo.Text := AExpr;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Fields'); SetBounds(10, 150, 200, 18); end;
    B.Fields := TListBox.Create(F);
    B.Fields.Parent := F;
    B.Fields.SetBounds(10, 170, 220, 280);
    B.Fields.OnDblClick := @B.InsertField;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Group'); SetBounds(244, 150, 200, 18); end;
    B.Cats := TListBox.Create(F);
    B.Cats.Parent := F;
    B.Cats.SetBounds(244, 170, 150, 280);
    B.Cats.OnClick := @B.CatChange;
    with TLabel.Create(F) do begin Parent := F; Caption := Tr('Functions and examples (double-click inserts)'); SetBounds(408, 150, 300, 18); end;
    B.Funcs := TListBox.Create(F);
    B.Funcs.Parent := F;
    B.Funcs.SetBounds(408, 170, 478, 280);
    B.Funcs.OnDblClick := @B.InsertFunc;
    B.Funcs.OnClick := @B.FuncChange;
    B.Desc := TLabel.Create(F);
    B.Desc.Parent := F;
    B.Desc.SetBounds(408, 456, 478, 18);
    B.Desc.Font.Style := [fsItalic];
    { categories in catalog order }
    for I := 0 to High(Catalog) do
    begin
      P := Pos('|', CatalogLine(I));
      if Seen.IndexOf(Copy(CatalogLine(I), 1, P - 1)) < 0 then
      begin
        Seen.Add(Copy(CatalogLine(I), 1, P - 1));
        B.Cats.Items.Add(Copy(CatalogLine(I), 1, P - 1));
      end;
    end;
    B.Cats.ItemIndex := 0;
    B.CatChange(nil);
    if (ASource <> '') and (ADb <> nil) then
      try
        L := SourceFieldList(ADb, ASource);
        for I := 0 to High(L) do B.Fields.Items.Add(L[I].Name);
      except
      end;
    B.Status := TLabel.Create(F);
    B.Status.Parent := F;
    B.Status.SetBounds(10, 486, 420, 36);
    B.Status.WordWrap := True;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Check'); SetBounds(570, 500, 90, 30); OnClick := @B.CheckClick; end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(672, 500, 100, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(782, 500, 100, 30); end;
    if F.ShowModal <> mrOk then Exit;
    AExpr := Trim(B.Memo.Text);
    Result := True;
  finally
    Seen.Free;
    B.Entries.Free;
    B.Free;
    F.Free;
  end;
end;

end.
