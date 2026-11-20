# Paritetni skup (E10): osnovni snimak ponasanja TaFormRunner-a

Prije izdvajanja `TaBindingEngine` (plan, 8.2 i etapa E10) snimljeno je sadasnje ponasanje obrazaca,
da preinaka dokaze "stare forme rade isto".

* 20 definicija formi (`parity.pas`, `Case01`..`Case20`): osnovna forma, izracunata polja, vidljivost/omogucenost,
  uvjetno oblikovanje, combo s izvorom, zadane vrijednosti i pravila provjere, CalcRules, AutoFill, tablicni prikaz
  (sortiranje, filtri stupaca, podnozje), obrazac + mreza, podforma kao mreza i kao forma, neprekidna forma,
  racun s neprekidnom podformom (SubSum), filtar i pretraga, samo za citanje, grupa izbora i popis, izrazi u oznakama,
  mreza s uvjetnim oblikovanjem redaka, ukupno stavki (DSum).
* Svaki slucaj prolazi scenarij (otvaranje, kretanje, izmjene, spremanje, pogreske, brisanje). Nakon svakog koraka
  zapisuje se stanje svih kontrola (vrijednost, vidljivost, omogucenost, boje, podebljanje), polozaj u skupu zapisa i
  poruke korisniku; na kraju stanje tablica u bazi i snimka zaslona.
* `golden/NN_naziv.txt` i `.png` su snimka. `./run.sh` usporedi (izlaz 0 = isto, PNG bajt po bajt),
  `./run.sh record` ponovno snimi (samo kad je promjena ponasanja namjerna i pregledana).

## Sto je trebalo dodati u TaFormRunner da bi se mogao ispitivati
* `OnRunnerConfirm`: odgovor na "Obrisati zapis?" bez dijaloga (zadano ostaje dijalog).
* sve `ShowMessage` u `ta_formrun` idu preko `Notify` (zadano se ponasa isto: dijalog), pa ih `OnRunnerMessage` hvata.

## Nalazi pri snimanju (ponasanje je snimljeno kakvo jest, nije popravljano)
1. **`[aktivan] = 1` je bilo lazno za kvacicu** (logicko True se brojalo kao -1 po Accessu). **RIJESENO po odluci korisnika:**
   oznacena kvacica je 1, prazna 0 (`True = 1`, `True + True = 2`); `Not`, `And`, `Or` ostaju logicki. Slucaj 03 sada koristi
   `[aktivan] = 1` / `= 0` i ponovno je snimljen; ostalih 19 slucajeva ostalo je isto.
2. **Pristupno krsenje u `TDBGrid.GetDefaultWidth`** pri oslobadanju forme s mrezom (slucajevi 09, 10, 11, 19, 20).
   **POPRAVLJENO:** `TaFormRunner.Destroy` i `TaSubInfo.Destroy` odvoje izvor podataka od upita i ponistavaju polja stupaca mreze
   prije oslobadanja upita (stupci su drzali pokazivace na oslobodena polja, a Qt je mrezi javljao fokus tijekom unistavanja prozora).
   Svaka iznimka u dogadaju sada je neuspjeh paritetnog skupa (`IZNIMKA u dogadaju`).
3. U `TaFormRunner` zapisi jos nemaju upit po formi, tipkovnicki standard ni statusnu crtu; to je novo u E10 i
   nema usporedbe prije/poslije.

## Sto jos nedostaje za potpuni paritet (sljedeci koraci E10)
* ista definicija kroz `TaFormBinder` (adapter nad `TaBindingEngine`) i usporedba s ovim snimkama;
* postupno prebacivanje po svojstvu (vidljivost, omogucenost, uvjetno oblikovanje, izracuni, pravila), nakon svake
  promjene `./run.sh` mora ostati zelen.

## Korak 2 (2026-11-10): zajednicki stroj `ta_bindengine` i binder kroz iste definicije
* `TaBindingEngine` (`ta_bindengine`, nevizualan): `Condition` (VisibleIf/EnabledIf), `RuleFailed`, `Style` (uvjetno oblikovanje),
  `Value`. Koriste ga `TaFormRunner` (RecalcAll, ApplyCondFormat) i `TaFormBinder` (Refresh, Validate).
  Dogovorena pravila: uvjet je istinit prema `ExprIsTrue`; izraz s greskom ne daje odluku (kontrola ostaje); pravilo je
  prekrseno samo kad je izraz ispravan, nije Null i nije istinit; stil je prvo pravilo koje vrijedi.
* `./run.sh` sada radi dvije usporedbe: runner prema `golden/` i **isti scenarij kroz TaFormBinder prema istim snimkama**
  (slucajevi 02, 03, 04, 18; `parity binder`). Binder se gradi iz LCL kontrola (`TEdit`, `TCheckBox`, `TLabel`) i
  `TaFormBinder.Bindings`; ispisuje stanje u istom zapisu kao runner (bez naziva razreda).
* Razlike koje je usporedba otkrila i **ujednacene** (binder se prilagodio runneru): kvacica uz brojcano polje (0/1) nije
  bila oznacena; izraz s greskom u binderu je praznio kontrolu, a u runneru piše `#Err` (sad oba `#Err`); prikaz izracuna
  nije bio samo za citanje niti oblikovan prema `Format`; brojevi su u binderu imali nametnute dvije decimale i tisucice.
* U stroj su dodatno prebaceni (korak 3): zadane vrijednosti (`DefaultValue`, doslovni tekst ako nije izraz, `=` se skida),
  parser i izracun pravila `CalcRules` (`ParseCalcRuleDefs`, `CalcRuleStored`; koriste ga runner, mreza podforme i
  `TaRowsView`), parser i dohvat `AutoFill` (`ParseAutoFillDefs`, `AutoFillLookup`; forma i mreza u runneru), pravila
  `Validation` iz metapodataka u runneru (`RuleFailed`: izraz s greskom vise ne blokira spremanje, Null nije prekrsaj).
  `./run.sh` ima i binder-usporedbu slucaja 06 (zadane vrijednosti).
* **ODLUCENO (2026-11-11):** runner takoder boji kontrolu ciji je `Validation` prekrsen (`RuleBadColor` = #FFDDDD, isto kao binder),
  odmah pri unosu, ima prednost nad uvjetnim oblikovanjem, a boja nestaje cim vrijednost zadovolji pravilo. Poruka pri spremanju ostaje.
  Usporedba binder/runner vise ne zanemaruje tu boju.
* Jos nije u stroju: prikaz izracunatih polja (`=izraz`, oblikovanje), upis izracuna u polje (binder `Expression` + `FieldName`),
  `EvalDefault` u `ta_types` (isti rezultat, zasebna implementacija zbog zavisnosti jedinica).
