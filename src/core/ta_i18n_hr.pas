unit ta_i18n_hr;
{ Hrvatski prijevodi (engleski izvorni tekst -> hrvatski). Dodaje se uz svaku novu poruku. }
{$mode objfpc}{$H+}

interface

implementation

uses
  ta_i18n, ta_i18n_hr_ui, ta_i18n_hr_core, ta_i18n_hr_more, ta_i18n_en;

initialization
  RegisterTranslations('hr', [
    'Value is required', 'Obavezno polje',
    '%s: value is required', '%s: obavezno polje',
    '%s: value does not satisfy the rule: %s', '%s: vrijednost ne zadovoljava pravilo: %s',
    '%s: value rejected', '%s: vrijednost odbijena',
    'No database is open', 'Nema otvorene baze',
    '%s: the value does not match the format %s', '%s: vrijednost ne odgovara obliku %s',
    'Input mask', 'Maska unosa',
    'Field events', 'Okidači polja',
    'Required', 'Obavezno',
    'Read only', 'Samo za čitanje',
    'Alignment', 'Poravnanje',
    'Control type', 'Vrsta kontrole',
    'List of values', 'Popis vrijednosti',
    'Lookup source', 'Izvor za LOV',
    'Lookup map', 'Preslikavanje LOV-a',
    'Property class', 'Klasa svojstava',
    'Auto-enter', 'Automatski unos',
    'Template / value', 'Predložak / vrijednost',
    'Restart yearly', 'Slijed po godini'
  ]);
end.
