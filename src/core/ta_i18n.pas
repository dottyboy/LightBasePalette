unit ta_i18n;
{ Prijevodi sucelja. Izvorni jezik je ENGLESKI: sve nove poruke, oznake i nazivi pisu se engleski kroz Tr('English text').
  Hrvatski (i drugi jezici) su tablica prijevoda koja se moze ukljuciti i iskljuciti (SetUiLanguage('en') = izvorni tekst).
  Tablica je hash: engleski tekst -> prijevod. Tekst bez prijevoda ostaje na engleskom, nista se ne lomi.
  Hrvatska tablica je u ta_i18n_hr (rucno, nove poruke) i ta_i18n_hr_ui (generirano alatom iz koda). }
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs;

{ 'en' = izvorni tekst, 'hr' = hrvatski (zadano za ovu aplikaciju) }
procedure SetUiLanguage(const ALang: string);
function UiLanguage: string;
{ prevodi engleski izvorni tekst; ako prijevoda nema, vraca izvorni }
function Tr(const AEnglish: string): string;
{ Tr s parametrima: Tr('Field %s is required', [Name]) }
function Tr(const AEnglish: string; const AArgs: array of const): string;
{ registrira prijevode: parovi 'English', 'Prijevod', ... }
procedure RegisterTranslations(const ALang: string; const APairs: array of string);
{ je li tekst preveden (za provjeru potpunosti prijevoda) }
function HasTranslation(const ALang, AEnglish: string): Boolean;
function TranslationCount(const ALang: string): Integer;
{ prevodi svaku stavku popisa odvojenog zarezima (CommaText s navodnicima); redoslijed ostaje, pa odabir po indeksu radi isto }
function TrCsv(const ACommaText: string): string;

implementation

var
  GLang: string = 'hr';
  GTables: TStringList;   { jezik -> TFPStringHashTable (engleski -> prijevod) }

function TableFor(const ALang: string; ACreate: Boolean): TFPStringHashTable;
var
  I: Integer;
begin
  Result := nil;
  I := GTables.IndexOf(LowerCase(ALang));
  if I >= 0 then Result := TFPStringHashTable(GTables.Objects[I])
  else if ACreate then
  begin
    Result := TFPStringHashTable.Create;
    GTables.AddObject(LowerCase(ALang), Result);
  end;
end;

procedure SetUiLanguage(const ALang: string);
begin
  GLang := LowerCase(Trim(ALang));
  if GLang = '' then GLang := 'en';
end;

function UiLanguage: string;
begin
  Result := GLang;
end;

function Tr(const AEnglish: string): string;
var
  T: TFPStringHashTable;
  S: string;
begin
  Result := AEnglish;
  if AEnglish = '' then Exit;
  T := TableFor(GLang, False);
  if T = nil then Exit;
  S := T.Items[AEnglish];
  if S <> '' then Result := S;
end;

function Tr(const AEnglish: string; const AArgs: array of const): string;
begin
  Result := Format(Tr(AEnglish), AArgs);
end;

procedure RegisterTranslations(const ALang: string; const APairs: array of string);
var
  T: TFPStringHashTable;
  I: Integer;
begin
  T := TableFor(ALang, True);
  I := 0;
  while I + 1 <= High(APairs) do
  begin
    try
      T.Add(APairs[I], APairs[I + 1]);
    except
      on EDuplicate do T.Items[APairs[I]] := APairs[I + 1];   { kasnija registracija nadjacava }
    end;
    Inc(I, 2);
  end;
end;

function HasTranslation(const ALang, AEnglish: string): Boolean;
var
  T: TFPStringHashTable;
begin
  T := TableFor(ALang, False);
  Result := (T <> nil) and (T.Items[AEnglish] <> '');
end;

function TranslationCount(const ALang: string): Integer;
var
  T: TFPStringHashTable;
begin
  T := TableFor(ALang, False);
  if T = nil then Result := 0 else Result := T.Count;
end;

function TrCsv(const ACommaText: string): string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.CommaText := ACommaText;
    for I := 0 to L.Count - 1 do L[I] := Tr(L[I]);
    Result := L.CommaText;
  finally
    L.Free;
  end;
end;

initialization
  GTables := TStringList.Create;
  { jezik se moze zadati pri pokretanju: TYPHACCESS_LANG=en (izvorni engleski tekst) ili hr }
  if GetEnvironmentVariable('TYPHACCESS_LANG') <> '' then SetUiLanguage(GetEnvironmentVariable('TYPHACCESS_LANG'));

finalization
  while GTables.Count > 0 do
  begin
    GTables.Objects[0].Free;
    GTables.Delete(0);
  end;
  GTables.Free;
end.
