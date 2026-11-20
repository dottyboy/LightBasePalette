# Implementation Plan — Pametni okvir čarobnjaka (E7 / Blok-čarobnjak)

## [Overview]

Proširenje **postojećeg sustava čarobnjaka** (`ta_wizards.pas`, `ta_wizardgen.pas`) s **"pametnim" okvirom** koji realizira etapu **E7** iz `docs/PLAN.md` (i Blok-čarobnjak iz poglavlja 19.2):
1. **Shvaća namjeru** iz naslova/opisa (npr. "popis partnera s filterom" → predlaže formu s DBGridom + filter poljima + gumb Osvježi; "unos stavki" → 4GL skripta za unos; "izvještaj po partneru" → grupirano izvješće sa zbrojevima).
2. **Nudi više rješenja s pouzdanošću** (Confidence 0–100) — korisnik bira najbolje rješenje.
3. **Generira filter polja za DBGrid** + gumb "Osvježi" s automatskim vezanjem: filter kontrole dobivaju konvenciju imena `flt_<Polje>` i/ili svojstvo `filterFor`, a `TaFormRunner` (i `TaBindingEngine`) pri akciji `refresh:` automatski prikuplja vrijednosti i gradi SQL `WHERE`. Time se dodatni filteri kasnije mogu samo dodati na formu bez izmjene koda.
4. **Dodaje 4GL skriptu** kao treći tip izlaza (pored forme i izvješća) — `MAIN` s `INPUT` / `CONSTRUCT` / `DISPLAY` blokovima prema `4GL-SPEC.md`.
5. **Isti dijalozi u CodeTyphon IDE-u i TyphAccess dizajneru** (sloj B): u TyphAccessu sprema u bazu (`_sys_forms`, `_sys_reports`, `_sys_programs`), a u IDE-u se aktivira preko `TaDatabase` (Component Editor / desni klik) ili alata s izborom baze.

---

## [Files]

### New files

| Putanja | Svrha |
|---|---|
| `src/core/ta_wizardframework.pas` | Jezgra okvira: `TaWizardSolution`, `TaWizardSolutions`, `TaFieldSuggestion`, `TaWizardResult`, `TaWizardContext`, `TaSmartWizardEngine`, `TaWizardStep` hijerarhija i registracija rješenja |
| `src/gui/ta_wizardformgrid_dlg.pas` | Specifični UI korak za "Formu s filterom" (odabir filter polja, prikaz predloženog rasporeda i gumba Osvježi) |
| `src/gui/ta_wizardfgl_dlg.pas` | Specifični UI korak za 4GL skriptu (odabir tipa: INPUT / CONSTRUCT / DISPLAY / MAIN) |
| `tests/wizards/wizard_smoke_test.pas` | Samostalni konzolni smoke test za 3 scenarija (bez pokretanja punog GUI-ja) |
| `tests/wizards/wizard_expected_outputs/` | Očekivani referentni izlazi (`.lfm`, JSON, 4GL) za automatsku usporedbu ("golden master") |

### Existing files to modify

| Putanja | Promjena |
|---|---|
| `src/core/ta_wizardgen.pas` | **DODAJ**: `BuildFormWithFilters`, `BuildFglScript`, `SuggestSolutions`; **PROŠIRI**: `TaFormOptions` s `FilterFields: TStrings` i `AddRefreshButton: Boolean` |
| `src/gui/ta_formrun.pas` | **DODAJ**: podrška za filter kontrole (`flt_*` / `filterFor`) u `BuildSql` pri `Requery` / akciji `refresh:` |
| `src/gui/ta_wizards.pas` | **DODAJ**: `TfrmSmartWizard` univerzalni host dijalog s koracima; zadržati kompatibilnost za postojeće `RunFormWizard` / `RunReportWizard`, dodati `RunSmartWizard` |
| `lazarus/ta_register.pas` | **DODAJ**: registracija `RunSmartWizard` u IDE (Component Editor na `TaDatabase` i izbornik alata) |
| `lazarus/typhaccess_dsgn.lpk`, `typhaccess_dsgn.ctpkg` | **AŽURIRAJ**: preusmjeriti putanje s `../../TyphAccess/src` na `../src/{core,gui}` (korak E0), dodati nove `.pas` uniti u `<Files>` |
| `docs/PLAN.md` | **AŽURIRAJ**: povezati etapu **E7** i poglavlje 19.2 (Blok-čarobnjak) s ovim pametnim okvirom |

---

## [Types]

Svi tipovi su usklađeni s **Free Pascal `{$mode objfpc}{$H+}`** standardom projekta (upotreba dinamičkih polja umjesto Delphi genericsa):

```pascal
// u src/core/ta_wizardframework.pas
type
  TaWizardResultKind = (wrkNone, wrkForm, wrkReport, wrkFgl);

  TaWizardResult = record
    Kind: TaWizardResultKind;
    FormDef: TaFormDef;        { vlasništvo rezultata, oslobađa pozivatelj }
    ReportDef: TaReportDef;    { vlasništvo rezultata, oslobađa pozivatelj }
    FglSource: string;         { generirani 4GL programski kod }
    SavedName: string;         { naziv spremljenog objekta u bazi ili na disku }
    Error: string;             { prazno ako je generiranje uspjelo }
  end;

  TaFieldSuggestion = record
    FieldName: string;
    Caption: string;
    LType: TaLogicalType;
    IsFilter: Boolean;         { heuristika: predloženo kao filter polje }
    Confidence: Integer;       { 0-100 }
  end;
  TaFieldSuggestions = array of TaFieldSuggestion;

  { Potpis generatora: vraća True ako je generiranje uspjelo i popunilo ACtx.Result }
  TWizardGenerateProc = function(ADb: TAppDb; var ACtx: TaWizardContext): Boolean;

  TaWizardSolution = record
    SolutionId: string;           { 'formgrid-filter', 'formgrid-readonly', 'form-card', 'report-group', 'fgl-input', 'fgl-construct' }
    Title: string;                { npr. 'Standardna forma s filterom' }
    Description: string;          { opis rješenja i što generira }
    Confidence: Integer;          { 0-100, pouzdanost na temelju analize namjere }
    Generate: TWizardGenerateProc; { funkcija generatora }
  end;
  TaWizardSolutions = array of TaWizardSolution;

  TaWizardContext = record
    Db: TAppDb;
    DataSource: string;           { tablica, upit ili fgl funkcija }
    Title: string;                { korisnički unos (namjera / naslov) }
    FieldSuggestions: TaFieldSuggestions; { popunjeno iz SourceFieldList + heuristike }
    Solutions: TaWizardSolutions; { ponuđena rješenja sortirana po Confidence opadajuće }
    SelectedSolution: string;     { odabrani SolutionId }
    FilterFields: TStrings;       { polja odabrana za filter iznad grida }
    FglScriptType: string;        { 'INPUT' | 'CONSTRUCT' | 'DISPLAY' | 'MAIN' }
    Result: TaWizardResult;
  end;

// u src/core/ta_wizardgen.pas (proširenje postojećeg zapisa)
type
  TaFormOptions = record
    Source, Name, Title: string;
    Fields: TStrings;
    Layout: TaFormLayout;
    SubTables: TStrings;          { podtablice za ugradnju kao subforms }
    FilterFields: TStrings;       { NOVO: polja za filter iznad grida (može biti nil) }
    AddRefreshButton: Boolean;    { NOVO: dodaj samostalni gumb 'Osvježi' }
  end;
```

---

## [Functions]

Ključne funkcije u `src/core/ta_wizardgen.pas` i `ta_wizardframework.pas`:

| Naziv | Potpis | Opis |
|---|---|---|
| `SuggestSolutions` | `function SuggestSolutions(ADb: TAppDb; const ASource, ATitle: string; const AFields: TaSourceFields): TaWizardSolutions;` | Analiza namjere iz naslova i polja: npr. "filter/pretraga" → `formgrid-filter` (90); "izvještaj/stanje" → `report-group` (85); "unos/evidentiraj" → `fgl-input` (85); zadano za običnu tablicu → `form-card` (80), `formgrid-filter` (75) |
| `BuildFormWithFilters` | `function BuildFormWithFilters(ADb: TAppDb; const AOpt: TaFormOptions): TaFormDef;` | Poziva `BuildFormEx`, zatim iznad grida postavlja panel s filter poljima (`flt_<Naziv>`, TagX `filterFor=<Naziv>`) i gumb "Osvježi" s akcijom `refresh:` |
| `BuildFglScript` | `function BuildFglScript(ADb: TAppDb; const ASource, ATitle, AScriptType: string; AFields: TStrings): string;` | Generira tekst 4GL koda: `MAIN` s blokovima `INPUT BY NAME` (unos), `CONSTRUCT` (kriterij pretrage) ili `DISPLAY ARRAY` (pregled) prema `4GL-SPEC.md` |
| `RegisterWizardSolution` | `procedure RegisterWizardSolution(const ASolution: TaWizardSolution);` | Registracija novih rješenja u okvir bez mijenjanja jezgre |

---

## [Classes]

| Datoteka | Klasa | Nasljeđuje | Svrha |
|---|---|---|---|
| `ta_wizardframework.pas` | `TaSmartWizardEngine` | `TObject` | Orkestrator: inicijalizacija konteksta, pokretanje koraka, registracija i rangiranje rješenja |
| `ta_wizardframework.pas` | `TaWizardStep` | `TObject` (abstract) | Apstraktni korak: `Execute(var ACtx: TaWizardContext): Boolean`, `CanGoNext`, `CanGoBack` |
| `ta_wizardframework.pas` | `TaDataSourceStep` | `TaWizardStep` | Korak 1: Odabir izvora podataka (tablica/pogled) i automatsko očitavanje polja |
| `ta_wizardframework.pas` | `TaTitleStep` | `TaWizardStep` | Korak 2: Unos naslova/namjere i izračun heurističkih prijedloga (`SuggestSolutions`) |
| `ta_wizardframework.pas` | `TaSolutionStep` | `TaWizardStep` | Korak 3: Prikaz rješenja rangiranih po postotku pouzdanosti (Confidence 0–100) i odabir |
| `ta_wizardframework.pas` | `TaFieldStep` | `TaWizardStep` | Korak 4: Fina prilagodba polja (odabir polja za prikaz, označavanje filter polja) |
| `ta_wizardframework.pas` | `TaResultStep` | `TaWizardStep` | Korak 5: Pregled generiranog rezultata (`.lfm`, JSON, 4GL), spremanje u bazu/datoteku |
| `ta_wizards.pas` | `TfrmSmartWizard` | `TForm` | Univerzalni GUI host za korake (isti dijalog za IDE i runtime dizajner) |
| `ta_wizardformgrid_dlg.pas` | `TfrmWizardFormGridDlg` | `TForm` / ugrađeni panel | Pomoćni UI za raspored filter polja iznad grida |
| `ta_wizardfgl_dlg.pas` | `TfrmWizardFglDlg` | `TForm` / ugrađeni panel | Pomoćni UI za konfiguraciju 4GL skripte (tip bloka, varijable, transakcije) |

---

## [Filter Runtime Mechanism in `ta_formrun.pas`]

Kako bi gumb "Osvježi" na formi automatski uvažavao filter polja bez potrebe za pisanjem skripte:
1. **Konvencija i metapodaci kontrole:**
   * Čarobnjak generira filter polja s imenom `flt_<Polje>` (npr. `flt_grad`, `flt_datum_od`) i postavlja `TagX` svojstvo `filterFor = '<Polje>'`.
   * Gumb "Osvježi" ima standardnu akciju `refresh:`.
2. **Proširenje u `TaFormRunner.BuildSql`:**
   * Pri izvršavanju `BuildSql` (kojeg poziva `Requery` na klik gumba "Osvježi"), runner prolazi kroz sve kontrole forme.
   * Za svaku kontrolu koja ima definiran `filterFor` (ili prefiks `flt_`) i nepraznu vrijednost:
     * Tekstualna polja (`ltString`, `ltMemo`) → dodaje `QuoteId(Polje) + ' LIKE ' + QuoteVal('%' + Val + '%')` ili precizni uvjet.
     * Brojčana i novčana polja → dodaje `>=` ili `=` ovisno o sufiksu `_od` / `_do`.
     * Datumska polja (`ltDate`) → dodaje `>=` za `_od` i `<=` za `_do`.
3. **Prednost za korisnika:**
   * Korisnik u dizajneru može naknadno dodati novu kontrolu `flt_status` iznad grida i povezati joj `filterFor = 'status'` — gumb "Osvježi" je odmah automatski uvažava bez ijedne linije dodatnog programiranja.

---

## [Testing]

### 3 scenarija za automatizirani smoke test (`wizard_smoke_test.pas`)

| Scenarij | Ulazni parametri | Očekivani rezultat |
|---|---|---|
| **1. Forma s filterom** | Izvor `partneri`, naslov "Popis partnera s filterom po gradu i datumu", označena filter polja `grad`, `datum_rodjenja` | Generiran `TaFormDef` s `ViewMode = 'datasheet'` / `flDatasheet` (ili ugrađeni grid), 2 filter kontrole (`flt_grad`, `flt_datum_rodjenja`), gumb "Osvježi" s akcijom `refresh:`. JSON i `.lfm` odgovaraju golden-master predlošku. |
| **2. Izvještaj** | Izvor `racuni`, naslov "Mjesečni izvještaj računa po partneru", grupiranje po `partner_id` | Generiran `TaReportDef` s `Kind = rkTabular`, `GroupField = 'partner_id'`, uključenim zbrojevima za numerička polja (`Sums = True`). |
| **3. 4GL skripta** | Izvor `stavke`, naslov "Unos stavki računa", tip `INPUT` | Generiran sintaksno ispravan 4GL kod: `MAIN` s `DEFINE r_stavke RECORD LIKE stavke.*`, blok `INPUT BY NAME` i `INSERT` naredba koja prolazi provjeru. |

---

## [Implementation Order]

1. **E0 — Osamostaljivanje paketa `LightPalette`:**
   * Ažurirati `lazarus/typhaccess_dsgn.lpk` tako da putanje referenciraju lokalne mape `../src/core` i `../src/gui` umjesto `../../TyphAccess/src/`.
2. **Filter podrška u `ta_formrun.pas`:**
   * Dopuniti `BuildSql` za detekciju kontrola s oznakom `filterFor` ili `flt_*`.
3. **Jezgra okvira `src/core/ta_wizardframework.pas`:**
   * Definirati sve tipove (`TaWizardSolution`, `TaWizardSolutions`, `TaFieldSuggestions`, `TaWizardResult`, `TaWizardContext`).
   * Implementirati `TaSmartWizardEngine` i bazne korake `TaWizardStep`.
4. **Proširenje generatora `src/core/ta_wizardgen.pas`:**
   * Implementirati `SuggestSolutions` (bodovanje namjere).
   * Implementirati `BuildFormWithFilters` (proširenje `BuildFormEx`).
   * Implementirati `BuildFglScript` (4GL predlošci).
5. **UI dijalog `src/gui/ta_wizards.pas` i pomoćni dijalozi:**
   * Implementirati `TfrmSmartWizard` kao host koji lista korake i omogućuje Naprijed/Natrag/Završi.
   * Implementirati pomoćne panele `ta_wizardformgrid_dlg.pas` i `ta_wizardfgl_dlg.pas`.
6. **Integracija i registracija:**
   * Dodati registraciju u `lazarus/ta_register.pas` (Component Editor za `TaDatabase`).
   * Dodati nove `.pas` uniti u `typhaccess_dsgn.lpk`.
7. **Smoke testovi:**
   * Izraditi `tests/wizards/wizard_smoke_test.pas` i spremiti referentne datoteke u `wizard_expected_outputs/`.
8. **Ažuriranje dokumentacije:**
   * Povezati etapu **E7** i poglavlje 19.2 u `docs/PLAN.md`.

---

## [Key Architecture Principles]

| Stari pristup (izbjegnuto) | Ispravljeni pristup (temeljen na postojećem kodu) |
|---|---|
| Pisanje novih generatora od nule (`ta_wizardformgrid.pas`, `ta_wizardreport.pas`) | **Ponovna upotreba i proširenje**: `BuildFormEx` dobiva filtere (`BuildFormWithFilters`), a izvješća koriste postojeći `BuildReportEx` |
| Novi 4GL parser/generator od nule | **Korištenje `4GL-SPEC.md` i `ta_fgl.pas`** za standardizirani tekstualni izlaz |
| Izolirani dijalog bez veze s runtimeom | **Univerzalni host (sloj B)**: isti dijalog radi u CodeTyphon IDE-u i TyphAccess aplikaciji |
| Delphi generici (`TList<T>`) | **Free Pascal idiom**: dinamička polja (`array of ...`) usklađena s `{$mode objfpc}` |
| "Magični" gumb za osvježavanje bez mehanizma | **Jasna veza u `TaFormRunner`**: automatsko mapiranje `filterFor` / `flt_*` kontrola u SQL `WHERE` |
