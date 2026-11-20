> **ARHIVA:** objedinjeno u [../PLAN.md](../PLAN.md) (2026-11-07). Vrijedi samo taj plan.

# Plan: mala paleta univerzalnih kontrola ("lagani Lazarus")

Verzija: 2026-11-07 (brzi plan; dopunjuje `PLAN-paleta-i-vizualno-programiranje.md`).

Ideja korisnika: umjesto tisuću kontrola (LCL, JVCL, RX, KControls, BGRA i drugi), koje su građene na istoj podlozi, a svaka radi nešto što druga ne, i neke ne rade ni osnovno kako treba, paleta ima **10 do 20 najčešćih kontrola**. Sve ostalo je **način rada (varijanta) iste kontrole**, koji se bira padajućim izbornikom: tekstno polje postaje padajući popis ako mu se postavi `Variant = combo` ili `droplist`; jedan gumb s opcijama zamjenjuje pedeset vrsta gumba. Time se smanjuje broj komponenti u paleti, a funkcije punog sustava ostaju.

---

## 1. Načelo

**Obitelj kontrole** = jedna palete-kontrola s više **varijanti**. Varijanta mijenja ponašanje i izgled, a zajednička svojstva (izvor podataka, pravila, uvjetno oblikovanje, radnje, oblik) ostaju ista kroz sve varijante i rade preko postojećeg stroja ponašanja (`TaBindingEngine`, `TaFormBinder`).

```
TaEdit  ── Variant ──►  text | memo | password | combo | droplist | lookup | spin | date | currency | mask | search
TaButton ─ Variant ──►  standard | flat | toggle | image | link | menu | split | default | cancel
```

Prednosti:
- korisnik uči **jednu kontrolu po obitelji**, ne dvadeset;
- promjena ideje ("neka to bude padajući popis") je promjena jednog svojstva, bez brisanja i ponovnog slaganja, uz zadržane veze, pravila i događaje;
- isto sučelje u CodeTyphonu i u TyphAccessu (TyphAccess već ima 19 vrsta kontrola; te vrste postaju varijante, vidi 4);
- vanjske biblioteke (JVCL, RX, KControls, BGRA) ostaju **neobavezni pokretači** varijanti, ne nova imena u paleti.

## 2. Obitelji (predloženih 16)

| # | Obitelj | Varijante | Danas u TyphAccessu |
|---|---|---|---|
| 1 | **Edit** (jednoredno polje) | text, password, mask, spin, date, time, currency, search, combo, droplist, lookup | TextBox, ComboBox |
| 2 | **Memo** (višeredno) | plain, rich (formatirani), code | MemoBox, RichText |
| 3 | **Label** (natpis) | text, hyperlink, html, status/badge | Label, Hyperlink |
| 4 | **Button** | standard, flat, toggle, image, link, menu, split, default, cancel | Button, ToggleButton |
| 5 | **Check** | checkbox, switch, radio, tri-state | CheckBox |
| 6 | **Choice** (grupa izbora) | radio group, check group, segmented | OptionGroup |
| 7 | **List** | list, checklist, icon list, tree | ListBox |
| 8 | **Grid** (tablica) | read-only, editable, datasheet, footer-sum, filter row | Subform / mreža |
| 9 | **Panel** (spremnik) | plain, group box, card, scroll, expander, splitter | Rectangle, Subform |
| 10 | **Pages** (kartice) | tabs, page list, wizard steps, accordion | TabControl |
| 11 | **Image** | picture, shape, gradient, svg/icon | Image, Rectangle, Line |
| 12 | **Chart** | bar, line, pie, gauge | Chart |
| 13 | **Code** (barkod) | code128, ean, qr, pdf417, HUB-3 | Barcode |
| 14 | **Menu** (navigacija) | side menu (XP traka), toolbar, tree menu, breadcrumb | SideMenu |
| 15 | **Progress** | bar, led, gauge, busy | (nema) |
| 16 | **Calendar** | month, range, agenda | (nema) |

Nevizualne obitelji (već postoje): `TaDatabase`, `TaExpression`, `TaReport`, `TaProgram`, `TaFormBinder`.

Svaka obitelj ima **zadanu varijantu** koja je najčešća; dodatne varijante dodaju se bez novih imena u paleti.

## 3. Kako se varijanta bira

- **Inspektor objekata (CodeTyphon/Lazarus):** objavljeno svojstvo `Variant` (padajući popis). Kontekstni izbornik komponente nudi "Prikaži kao ▸" s istim izborom i sličicama.
- **Dizajner TyphAccessa:** isti padajući popis na vrhu popisa svojstava i isti kontekstni izbornik.
- **Svojstva koja ovise o varijanti** (npr. `DropDownCount` samo za combo) sakrivaju se tako da je svojstvo `Options` **podobjekt čija klasa ovisi o varijanti** (`TaComboOptions`, `TaDateOptions`...). Tako Inspektor pokazuje samo ono što varijanta stvarno ima. Zajednička svojstva (izvor, pravila, radnje, oblik) su uvijek vidljiva.
- Promjena varijante **čuva** zajednička svojstva i vrijednosti; svojstva koja nova varijanta nema ostaju zapamćena u definiciji (da se vrate ako korisnik povrati varijantu).

## 4. Izvedba: obitelj nad pokretačem

```
TaEdit (TWinControl)                     ← jedna klasa obitelji, objavljena svojstva i zajednički API
   └─ FEngine: IaEngine                  ← pokretač varijante (zamjenjiv)
        ├─ TaLclEditEngine      (TEdit / TComboBox / TSpinEdit ...)     ← uvijek dostupan
        ├─ TaJvclEditEngine     (TJvCalcEdit, TJvxCurrencyEdit ...)     ← neobavezni paket
        └─ TaRxEditEngine       (TRxDBDateEdit, TRxLookupEdit ...)      ← neobavezni paket
```

- Obitelj je **domaćin** (host): drži stvarnu kontrolu kao dijete i prosljeđuje Fokus, Tab, Anchors, Font, Color i događaje. Kad se varijanta promijeni, pokretač se zamijeni.
- **Pokretač je zamjenjiv po mogućnostima:** registar (`TaEngineRegistry`) zna koji pokretači postoje u programu. Za varijantu bira prvi dostupan (zadano LCL; ako je prisutan JVCL ili RX paket i korisnik to želi, njihov). Programi bez JVCL/RX rade s LCL pokretačima, bez ikakve promjene definicije.
- **Zajedničko sučelje pokretača** (`IaEngine`): `Value` (Variant), `Text`, `ReadOnly`, `SetItems`, `SetFormat`, `OnChange`, `DataBind(DataSource, Field)`. Time `TaBindingEngine` radi isto bez obzira na pokretača.
- **Podaci:** obitelj prihvaća `TaSourceDef` (izvor može biti tablica, SQL, izraz, popis ili 4GL, vidi glavni plan, poglavlje 3).

Zašto domaćin, a ne nasljeđivanje jedne LCL klase: varijanta se mijenja u hodu, a LCL klase se ne mogu mijenjati. Cijena domaćina (jedna razina više za fokus i događaje) je mala i testira se u prvom prototipu.

### Zašto ne uzeti JVCL/RX/KControls/BGRA izravno

- Imaju iste ideje u različitim imenima i s različitim greškama. Korisnik bi morao znati koji gumb radi što.
- Neke komponente ne rade ispravno na Qt6 (spike je pokazao dobro stanje za 23 kontrole, ali samo osnovno ponašanje).
- Ne postoji jedinstveno svojstveno sučelje (isti pojam ima različita imena).

Naš sloj tu ništa ne briše: ako korisnik želi čistu JVCL kontrolu, može je i dalje baciti na formu, a `TaFormBinder` radi s njom (već izrađeno).

## 5. Veza s TyphAccessom (svjetlo u radu, isto u IDE-u)

- **Definicija forme se ne mijenja:** `TaControlDef.Kind` ostaje (npr. `ComboBox`), ali postaje **alias** za `Edit` + varijantu `combo`. Postojeće aplikacije se učitavaju bez promjene; novi zapisi pišu `Kind = Edit`, `variant = combo`.
- **Dizajner:** na paleti ostaje 16 obitelji; padajući izbornik varijante je ugrađen u popis svojstava.
- **Runtime:** `TaFormRunner` stvara obitelj i postavlja varijantu, pa ponašanje (izrazi, pravila, boje) ide kroz isti stroj kao u IDE-u.
- **Dijalozi i čarobnjaci:** jedan skup (sloj B), vidi glavni plan, poglavlje 5.

## 6. Kratki redoslijed rada

| Korak | Posao | Rezultat | Procjena |
|---|---|---|---|
| 1 | Popis obitelji i varijanti (tablica 2), pregled što TyphAccess već ima po vrstama, odluka što je zadano | usvojen popis | 0,5 dana |
| 2 | Okvir: `IaEngine`, `TaEngineRegistry`, domaćin s prosljeđivanjem fokusa i događaja, `Variant` kao padajući popis, podobjekt `Options` | prazna obitelj koja zna zamijeniti pokretač | 1 dan |
| 3 | **Prototip: obitelj Edit** s varijantama text, password, combo, droplist, spin, date, currency | polje koje se jednim klikom pretvara u padajući popis; testovi (fokus, Tab, veza na bazu, pravila) | 2 dana |
| 4 | Obitelj Button (standard, flat, toggle, image, link, menu, split) | jedan gumb umjesto desetak | 1 dan |
| 5 | Obitelji Label, Check, Choice, List | pokrivene osnovne kontrole | 2 dana |
| 6 | Obitelji Grid, Panel, Pages | mreža s izvorom iz tablice/SQL-a/4GL-a | 3 dana |
| 7 | Obitelji Image, Chart, Code, Menu (TaSideMenu već postoji), Progress, Calendar | cijela paleta | 3 dana |
| 8 | Paleta: samo 16 obitelji + nevizualne; stare klase (`TaTextBox` itd.) ostaju registrirane, ali skrivene s palete radi kompatibilnosti | nova paleta | 1 dan |
| 9 | Dizajner TyphAccessa: padajući izbornik varijante i kontekstni izbornik "Prikaži kao"; alias starih vrsta | isti rad u oba okruženja | 2 dana |
| 10 | Neobavezni pokretači `typhaccess_ext` (JVCL, RX; KControls i BGRA po potrebi) | više varijanti bez novih imena | po varijanti |

Ukupno oko **dva do tri tjedna** za svih 16 obitelji; **prvi vidljivi rezultat (prototip Edit) je nakon 3 do 4 dana.**

## 7. Prihvaćanje

- Isto polje, mijenjano kroz sve varijante Edit obitelji u Inspektoru, **zadržava** izvor podataka, pravilo, zadanu vrijednost i radnju (test).
- Ista definicija forme otvorena u IDE-u i u TyphAccess dizajneru izgleda i radi jednako (offscreen snimke).
- **Pritisak Tab** i **fokus** prolaze kroz domaćina bez zastoja (test s redoslijedom tabulatora).
- Aplikacije izrađene prije promjene (SmartBetTA, Trgovina Jadran) učitavaju se i izgledaju isto (smoke test).
- Program bez JVCL/RX paketa radi sve varijante s LCL pokretačima.

## 8. Rizici i otvorena pitanja

| Rizik / pitanje | Prijedlog |
|---|---|
| Domaćin otežava dizajnerske ručke i redoslijed tabulatora | prototip Edit prije svega ostalog; ako ne radi, alternativa je jedna klasa nad `TCustomComboBox` s prepravljenim stilovima (za Edit/Combo) |
| Svojstva koja ovise o varijanti u Inspektoru | podobjekt `Options`; ako IDE ne dopusti, alternativa su kategorije i pojašnjenje u opisu |
| Ima li smisla da dizajner TyphAccessa sprema formu kao pravi `.lfm` (LCL tok)? | to bi dalo prenosivost forme besplatno (isti tok kao Lazarus), ali TyphAccess runtime bi morao čitati LCL tok. **Odlučiti nakon prototipa Edit** |
| Opseg (16 obitelji) | prva četiri koraka daju korist sama za sebe; ostalo ide po važnosti |
| Broj varijanti raste do kaosa | pravilo: nova varijanta samo ako se razlikuje po ponašanju, ne samo po izgledu (izgled ide u temu/stil) |

## 9. Što odlučiti sad

1. Odgovara li popis od 16 obitelji (tablica 2), ili nešto dodati/maknuti?
2. Prototip počinje s obitelji **Edit** (polje, padajući popis, datum, iznos). Slažeš li se?
3. Domaćin (host) kao osnovni način izvedbe, uz alternativu iz poglavlja 8 ako zapne.

---

## 10. Nastavak: Light IDE

Pitanje "treba li novi IDE samo s našom paletom" razrađeno je u `PLAN-light-ide.md` (tri izvedbe: profil CodeTyphona, prerađeni IDE, TyphAccess kao IDE; preporuka je krenuti od profila).

Vidi i: [PLAN-paleta-izbor-tema-komponente.md](PLAN-paleta-izbor-tema-komponente.md) (izbor kontrola, tema, pretvorba u komponente).
