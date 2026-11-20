unit ta_dict;
{ Rjecnik podataka upravlja formama (plan: PLAN-rjecnik-okidaci.md, korak 1).
  Polje se opise jednom u rjecniku (TaFieldMeta: tip, format, provjera, naslov, opis + Extra), a kontrola vezana uz polje
  to nasljeduje. VLASTITO SVOJSTVO KONTROLE UVIJEK NADJACAVA RJECNIK (isto pravilo kao kod klasa svojstava).
  Kljucevi u TaFieldMeta.Extra (engleski, kao u definiciji kontrole):
    required=1      polje je obavezno: prazno blokira spremanje
    onEnter/onExit/onValidate/onKey=<procedura>   okidaci polja (kontrola > rjecnik > zadani okidac forme FieldOn...)
    mask=<maska>    maska unosa (ta_mask): 9 znamenka, A slovo, X slovo/znamenka, ostalo fiksno; nepotpun unos blokira spremanje
    readonly=1      polje se ne moze mijenjati (kontrola je zakljucana)
    align=left|center|right
    variant=<naziv varijante obitelji>   npr. switch, combo, currency
    rowsource=<izvor popisa>             list:A;B, sql:..., tablica
    lov=<izvor LOV-a>, lovmap=<preslikavanje>
    class=<klasa svojstava>
  Ovdje je cista logika (bez sucelja) da se lako ispita. }
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_formdef, ta_types;

{ kontrole koje dobivaju vrijednosti iz rjecnika }
function DictAppliesTo(const AKind: string): Boolean;
{ prazna svojstva kontrole popunjava iz rjecnika; vraca broj popunjenih }
function ApplyDictionaryDefaults(D: TaControlDef; M: TaFieldMeta): Integer;
{ vrijednost svojstva kontrole koju daje rjecnik (prazno ako je rjecnik ne daje); AProp je naziv svojstva u Inspektoru }
function DictValueFor(M: TaFieldMeta; const AProp: string): string;
{ oznaka ispred naslijedene vrijednosti u Inspektoru ("(rjecnik) ..."): ne upisuje se kao vrijednost }
function DictInheritedMarker: string;
{ procedura okidaca kontrole: prvo vlastiti kljuc kontrole, zatim rjecnik (vec spojen u definiciju), zatim zadani okidac forme
  (FieldOnEnter, FieldOnExit, FieldOnValidate, FieldOnKey); AKey je onEnter, onExit, onValidate, onKey }
function EffectiveEvent(D: TaControlDef; AForm: TaFormDef; const AKey: string): string;
function DictRequired(M: TaFieldMeta): Boolean;
{ poruka koja se prikazuje kad obavezno polje nije popunjeno }
function RequiredMessage(const AField, ACaption: string): string;

implementation

uses
  ta_i18n, ta_i18n_hr;

function DictAppliesTo(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'TextBox') or SameText(AKind, 'ComboBox') or SameText(AKind, 'CheckBox') or
    SameText(AKind, 'MemoBox') or SameText(AKind, 'OptionGroup') or SameText(AKind, 'ListBox') or
    SameText(AKind, 'Calendar') or SameText(AKind, 'ToggleButton');
end;

procedure Fill(D: TaControlDef; const AKey, AValue: string; var N: Integer);
begin
  if (AValue <> '') and (D.GetX(AKey) = '') then
  begin
    D.SetX(AKey, AValue);
    Inc(N);
  end;
end;

function ApplyDictionaryDefaults(D: TaControlDef; M: TaFieldMeta): Integer;
var
  S: string;
begin
  Result := 0;
  if (D = nil) or (M = nil) or not DictAppliesTo(D.Kind) then Exit;
  Fill(D, 'variant', M.GetX('variant'), Result);
  Fill(D, 'lov', M.GetX('lov'), Result);
  Fill(D, 'lovmap', M.GetX('lovmap'), Result);
  Fill(D, 'mask', M.GetX('mask'), Result);
  { okidaci polja iz rjecnika: vrijede za svaku kontrolu vezanu uz polje, osim ako kontrola ima vlastiti }
  Fill(D, 'onEnter', M.GetX('onEnter'), Result);
  Fill(D, 'onExit', M.GetX('onExit'), Result);
  Fill(D, 'onValidate', M.GetX('onValidate'), Result);
  Fill(D, 'onKey', M.GetX('onKey'), Result);
  Fill(D, 'class', M.GetX('class'), Result);
  S := LowerCase(M.GetX('align'));
  if ((S = 'left') or (S = 'center') or (S = 'right')) and (D.Align = '') then
  begin
    D.Align := S;
    Inc(Result);
  end;
  if (D.RowSource = '') and (M.GetX('rowsource') <> '') then
  begin
    D.RowSource := M.GetX('rowsource');
    Inc(Result);
  end;
  { automatski uneseno polje korisnik ne mijenja (osim izraza i konstante) }
  if (D.GetX('locked') = '') and (M.GetX('autoenter') <> '') and
     not SameText(M.GetX('autoenter'), 'expr') and not SameText(M.GetX('autoenter'), 'const') and
     not SameText(M.GetX('autoenter'), 'copy') then
  begin
    D.SetX('locked', '1');
    Inc(Result);
  end;
  if (M.GetX('readonly') = '1') and (D.GetX('locked') = '') then
  begin
    D.SetX('locked', '1');
    Inc(Result);
  end;
end;

function DictInheritedMarker: string;
begin
  Result := Tr('(dictionary)') + ' ';
end;

function DictValueFor(M: TaFieldMeta; const AProp: string): string;
begin
  Result := '';
  if M = nil then Exit;
  if AProp = 'Variant' then Result := M.GetX('variant')
  else if AProp = 'RowSource' then Result := M.GetX('rowsource')
  else if AProp = 'Lov' then Result := M.GetX('lov')
  else if AProp = 'LovMap' then Result := M.GetX('lovmap')
  else if AProp = 'Mask' then Result := M.GetX('mask')
  else if AProp = 'Align' then Result := M.GetX('align')
  else if AProp = 'PropertyClass' then Result := M.GetX('class')
  else if AProp = 'Locked' then
  begin
    if (M.GetX('readonly') = '1') or ((M.GetX('autoenter') <> '') and not SameText(M.GetX('autoenter'), 'expr') and
       not SameText(M.GetX('autoenter'), 'const') and not SameText(M.GetX('autoenter'), 'copy')) then Result := 'True';
  end;
end;

function EffectiveEvent(D: TaControlDef; AForm: TaFormDef; const AKey: string): string;
begin
  Result := '';
  if D <> nil then Result := D.GetX(AKey);
  if (Result = '') and (AForm <> nil) and (AKey <> '') then
    Result := AForm.GetEv('Field' + UpperCase(Copy(AKey, 1, 1)) + Copy(AKey, 2, MaxInt));
end;

function DictRequired(M: TaFieldMeta): Boolean;
begin
  Result := (M <> nil) and (M.GetX('required') = '1');
end;

function RequiredMessage(const AField, ACaption: string): string;
var
  Name: string;
begin
  Name := ACaption;
  if Name = '' then Name := AField;
  Result := Tr('%s: value is required', [Name]);
end;

end.
