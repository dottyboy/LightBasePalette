> **ARHIVA:** objedinjeno u [../PLAN.md](../PLAN.md) (2026-11-07). Vrijedi samo taj plan.

# Plan: Light IDE ("Typhon Light") s našom paletom

Verzija: 2026-11-07. Ideja korisnika: umjesto da se naša paleta ubacuje u veliki CodeTyphon, napraviti **novi, lagani IDE** u kojem postoji samo naša paleta (16 obitelji univerzalnih kontrola, nevizualne komponente, 4GL, kosturi, čarobnjaci).

Dokument je namijenjen onome tko donosi odluku o smjeru razvoja i onome tko ga izvodi. Nadovezuje se na `PLAN-univerzalne-kontrole.md` i `PLAN-paleta-i-vizualno-programiranje.md`.

---

## 1. Što je "Light IDE" i kome služi

Danas postoje dva ekstrema:

| | CodeTyphon / Lazarus | TyphAccess |
|---|---|---|
| Stotine kontrola, urednik koda, otklanjanje grešaka, paketi, više platformi | **da** | ne |
| Vizualni dizajn formi i izvješća, 4GL, baza u jednoj datoteci, bez prevođenja | ne | **da** |
| Krivulja učenja | strma | blaga |
| Rezultat | prevedeni program | aplikacija u bazi + runtime |

**Light IDE je sredina:** onaj tko zna malo programirati (ili ne zna uopće) slaže poslovnu aplikaciju iz male palete, 4GL kostura i čarobnjaka, a po želji je prevodi u samostalan program. Ne zamjenjuje Lazarus za napredne korisnike; njima ostaje puni CodeTyphon s našom paletom kao paketom.

Ciljni korisnici:
1. **Slagač aplikacija** (poslovni korisnik, "citizen developer"): radi isključivo mišem, kosturi, blokovi, čarobnjaci.
2. **Programer Pascala** koji želi brzo složiti DB aplikaciju: koristi paletu, a po potrebi ručno piše kod.
3. **Naš tim:** brži razvoj internih alata.

## 2. Tri izvedbe (od najjeftinije do najskuplje)

### Izvedba A: "Light profil" CodeTyphona (bez ijednog retka koda IDE-a)

CodeTyphon i Lazarus dopuštaju korisniku konfiguraciju palete i izbornika. Light profil je **skup konfiguracijskih datoteka i paket** koji se instalira jednom.

- Profil (mapa postavki `~/.typhon64` ili zasebna `--pcp=`): paleta s **jednom stranicom "TyphAccess"** (16 obitelji + nevizualne), sve ostale stranice sakrivene; izbornici i prozori smanjeni; predlošci projekta i forme (TyphAccess aplikacija, forma nad tablicom).
- Paket `typhaccess_dsgn` (već postoji) predinstaliran.
- Pokretač `typhon-light.sh` koji pokreće IDE s tim profilom (`--pcp=`), pa se puni IDE i dalje koristi neovisno.

| Prednosti | Mane |
|---|---|
| za dan-dva; nema održavanja koda IDE-a; sve nadogradnje CodeTyphona dolaze besplatno | korisnik je i dalje u velikom IDE-u (izbornici, prozori); "Light" je samo izgled |
| nema pravnih ni naziv-pitanja | ne može se ukloniti ono što IDE ima ugrađeno |

### Izvedba B: pravi Light IDE kao prerađeni CodeTyphon IDE

CodeTyphon ima izvorni kod IDE-a (`typhon/ide`) i mehanizam statičkih paketa (`staticpackages.inc`, oznaka `CT_Is_BigIDE`). IDE se može **ponovno izgraditi s izabranim skupom paketa**: bez nepotrebnih (npr. debugger za više platformi, dijagrami, SynEdit proširenja), s našim paketima ugrađenim kao statičkim, s vlastitim imenom i naslovnim zaslonom i s pojednostavljenim izbornicima.

- Prijava naših paketa kao **statičkih** (uvijek prisutni, ne mogu se slučajno ukloniti).
- Vlastiti **izbornik Datoteka → Novo** s TyphAccess projektima (aplikacija, forma nad tablicom, program iz kostura).
- Pojednostavljeni **Inspektor objekata** (naši property editori; sakriti rijetka svojstva).
- Uklonjeni: dockiranje složenog rasporeda, profiler, dijagrami, pas2js, sve ne-Qt6 platforme.

| Prednosti | Mane |
|---|---|
| doista "svoj" IDE; sav urednik koda, prevođenje i otklanjanje grešaka ostaju | prvo moramo naučiti izgraditi IDE (nekoliko dana), zatim ga održavati kroz nove verzije CodeTyphona |
| zadržava Lazarusov dizajner formi (i `.lfm` zapis) | licenca i naziv: izvedeni IDE mora imati drugo ime (vidi 6) |

### Izvedba C: vlastiti IDE nad TyphAccessom (bez koda Lazarusa)

TyphAccess već ima **mali IDE**: dizajner formi i izvješća, uređivač 4GL-a s blokovima, graditelj upita, makroi, čarobnjaci, jezik izraza i runtime. Izvedba C ga proširuje do potpunog Light IDE-a: uredjivač Pascal koda (SynEdit), prevođenje (`fpc`), pokretanje i otklanjanje grešaka, upravljanje projektom, izvoz samostalnog programa.

| Prednosti | Mane |
|---|---|
| potpuno naše, jedno sučelje, bez ovisnosti o Lazarusovom IDE-u | **mjeseci rada**: urednik koda, ispravci, prevođenje, upravljanje paketima, otklanjanje grešaka, sve što IDE treba |
| aplikacija i IDE dijele isti kod (identično ponašanje bez dodatnog posla) | rizik da završimo s lošijim IDE-om od onoga koji već postoji |

## 3. Preporuka: tri stupnja, svaki koristan sam

| Stupanj | Što | Kad | Odluka nakon |
|---|---|---|---|
| **1. Light profil (A)** | profil palete + paket + predlošci + pokretač | odmah, 1–2 dana, uz prototip obitelji Edit | je li dovoljno? |
| **2. Light IDE (B)** | ponovna izgradnja IDE-a s našim statičkim paketima i skraćenim izbornicima | nakon što je paleta stabilna (faze 1–5 glavnog plana) | je li korisnicima "kopija Lazarusa" prihvatljiva? |
| **3. TyphAccess kao Light IDE (C)** | samo ako se pokaže da korisnici žele raditi **bez** prevođenja i bez Pascala | tek tada | ne počinjati prije |

**Zašto ne odmah B ili C:** paleta još ne postoji u konačnom obliku (univerzalne kontrole, prototip Edit). Pravi IDE oko nje bi se morao stalno prepravljati. Profil (A) daje isti doživljaj "samo naša paleta" za dan-dva i pokazuje što korisnici stvarno koriste.

**Što TyphAccess već jest:** za slagača aplikacija TyphAccess već *jest* Light IDE (dizajner, 4GL, runtime, čarobnjaci, bez prevođenja). Izvedba B znači dodati slagaču mogućnost prevođenja i Pascal koda; izvedba C znači dodati TyphAccessu ono što mu fali da zamijeni Lazarus. Treba odlučiti koji je smjer važniji.

## 4. Što bi Light IDE morao imati

| Područje | Light profil (A) | Light IDE (B) | TyphAccess-IDE (C) |
|---|---|---|---|
| Paleta (16 obitelji + nevizualne) | da | da | da (već) |
| Dizajner formi | Lazarus | Lazarus | naš |
| Dizajner izvješća | naš (u TyphAccessu) | naš | naš |
| Urednik 4GL-a i blokovi | naš | naš | naš |
| Kosturi i čarobnjaci | da | da | da |
| Urednik Pascal koda | Lazarus | Lazarus | **nadograditi** |
| Prevođenje i pokretanje | Lazarus | Lazarus | **izgraditi** (fpc) |
| Otklanjanje grešaka | Lazarus | Lazarus | **izgraditi** ili izostaviti |
| Paketi i ovisnosti | Lazarus | Lazarus | **izgraditi** |
| Izlaz | `.exe` + opcionalno baza | isto | baza + runtime (već) ili `.exe` |

## 5. Zajednički temelj (isti u sve tri izvedbe)

Bez obzira na izvedbu, sljedeće treba **ionako** napraviti, pa to ne ovisi o odluci:

1. 16 univerzalnih kontrola s `Variant` (plan univerzalnih kontrola).
2. Dijalozi i čarobnjaci kao funkcije (sloj B glavnog plana).
3. Kosturi `.4glt` i 4GL kao izvor podataka (faze 1–3 glavnog plana).
4. Stroj ponašanja `TaBindingEngine` (identično ponašanje).
5. Predlošci projekta ("TyphAccess aplikacija", "forma nad tablicom").

Izvedbe A, B i C su samo različiti **ovitci** oko toga.

## 6. Pravna i organizacijska pitanja (treba provjeriti)

- **Licenca i naziv:** CodeTyphon je distribucija s više licenci (Lazarus: GPL/LGPL s iznimkom za komponente, FPC: GPL/LGPL, PilotLogic dodaci: vlastiti uvjeti). Izvedeni IDE (izvedba B) **ne smije nositi naziv CodeTyphon ni Lazarus**; treba provjeriti uvjete za preraspodjelu prerađenog IDE-a i vlastitih paketa. Provjera prije bilo kakve javne objave.
- **Vlastita upotreba:** unutarnja upotreba izvedbe A i B je bez problema; pitanje se javlja tek pri dijeljenju.
- **Naziv:** radni naziv "Typhon Light"; konačni naziv ne smije nalikovati nazivima trećih strana.

## 7. Plan rada (samo prvi stupanj je detaljan)

### Stupanj 1: Light profil (1–2 dana)

| Dan | Posao | Rezultat |
|---|---|---|
| 1 | Ispitati gdje CodeTyphon sprema konfiguraciju palete i izbornika (`~/.typhon64`); napraviti profil sa samo našom stranicom palete; pokretač `typhon-light.sh` | IDE se otvara s paletom "TyphAccess" i bez ostalih stranica |
| 1 | Predlošci projekta i forme: *TyphAccess aplikacija* (lpr s lokalizacijom, `TaDatabase`, izbornik), *Forma nad tablicom* | File → New nudi naše predloške |
| 2 | Dokument "Prvi sat": od praznog projekta do forme s izračunom, pravilom i 4GL gumbom | opis koji korisnik izvede mišem |

**Prihvaćanje:** nova osoba, uz upute, složi u 30 minuta aplikaciju s popisom, unosom, jednim izvješćem i jednim 4GL programom, bez izlaska iz Light profila.

### Stupanj 2: Light IDE (nakon stabilne palete, procjena 1–2 tjedna)

1. Izgraditi IDE iz izvora (`typhon/ide`) s našim paketima kao statičkim.
2. Skratiti izbornike i prozore; naš naslovni zaslon i naziv.
3. Pojednostavljen Inspektor objekata (sakrivanje rijetkih svojstava).
4. Paketna distribucija (jedan instalacijski paket s FPC-om, LCL-om, našim paketima).
5. Testovi: otvaranje, prevođenje i pokretanje svih primjera.

### Stupanj 3: TyphAccess kao IDE (tek po potrebi; mjeseci)

Samo ako anketa korisnika pokaže da prevođenje Pascala nije potrebno, ili da je Lazarusov IDE prevelika prepreka.

## 8. Otvorena pitanja

| # | Pitanje | Preporuka |
|---|---|---|
| 1 | Koji je stupanj dovoljan za prvu verziju? | **stupanj 1**; odluka o drugom nakon prototipa Edit |
| 2 | Treba li Light IDE moći prevoditi u samostalni `.exe`, ili je dovoljno "aplikacija u bazi + runtime"? | oboje: runtime kao zadano, `.exe` kao izbor (Lazarus ga već daje) |
| 3 | Spremaju li se forme kao `.lfm` (LCL tok) ili kao JSON u bazi? | odlučiti nakon prototipa Edit; `.lfm` daje prenosivost besplatno |
| 4 | Naziv proizvoda | radno "Typhon Light"; pravno provjeriti |
| 5 | Tko su prvi korisnici i što im je najvažnije? | slagač aplikacija, pa programer Pascala |

## 9. Rizici

| Rizik | Ublažavanje |
|---|---|
| Održavanje izvedenog IDE-a kroz nove verzije CodeTyphona (B) | ostati na stupnju 1 dok je moguće; kad se krene u B, ažurirati rijetko i s testom |
| Licenca/naziv | provjeriti prije javne distribucije |
| "Light" bude razočaravajuće bez Lazarusovih mogućnosti | jasna poruka korisnicima: za više, otvori puni IDE s istom paletom |
| Opseg stupnja 3 | ne počinjati bez dokaza potrebe |

Vidi i: [PLAN-paleta-izbor-tema-komponente.md](PLAN-paleta-izbor-tema-komponente.md) (izbor kontrola, tema, pretvorba u komponente).
