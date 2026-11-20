# Plan: proizvodni pogoni s uređajima (ESP32, MQTT, rasporedi, više lokacija)

Primjer korištenja: `examples/aplikacije/procesi.opis` (serije, radnje, zaliha, trošak). Ovo je plan proširenja za pogone
s upravljanjem (svjetlo, navodnjavanje, ventilacija, senzori). Ništa od ovoga nije izrađeno osim aplikacije u prilogu.

## Polazište

* Uzgajalište ima 1–10 pogona, svaki svoj ESP32 sa senzorima i izlazima (releji, pumpice, ventilator, svjetlo).
* Podaci su 90 % lokalni, ali moramo moći povezati više lokacija i pratiti ih zajedno.
* Raspored se ili preuzme sa servera ili složi na licu mjesta (uređaj mora raditi i bez mreže).

## Tri razine

1. **Uređaj (ESP32 u pogonu).** Izvršava raspored sam. Raspored, granice i sigurnosna ograničenja drži u svojoj memoriji
   (flash). Radi i kad nema mreže, brokera ni PC-a. Sat: NTP kad ima mreže, a uz to RTC modul (DS3231) da raspored ne ovisi
   o mreži. Preporuka: ne pisati vlastiti firmware nego **ESPHome** (ili Tasmota): MQTT, releji, senzori (SHT3x, vlaga tla,
   EC/pH preko ADC) i vremenski rasporedi dolaze gotovi, a konfiguracija je jedna YAML datoteka po pogonu.
2. **Lokacija (lokalni poslužitelj: PC ili Raspberry).** Mosquitto (MQTT broker), *most* (bridge) i baza aplikacije. Most
   prepisuje MQTT u bazu i bazu u MQTT (vidi niže). TyphAccess vidi samo bazu: forme, izvješća, kanban, nadzorna ploča.
3. **Središte (nije obavezno).** Postgres s podacima svih lokacija za zajedničko praćenje i izvješća. Lokacija radi bez njega.

## Odluke (2026-11-17)

* Lokalna baza je **SQLite**; središte (ako ga bude) Postgres.
* Uređaji nisu zapisani u kodu nego u **katalogu** (`vrste_uredjaja`): senzori (temperatura zraka, tla i vode, vlaga zraka i tla, pH,
  EC, razina vode, svjetlo, CO₂) i izvršni članovi (svjetlo, pumpa, ventilator, grijač, prozor 0–100 %, dozator, zračna i cirkulacijska
  pumpa). Nova vrsta je novi redak, ne novi program.
* **Tehnologija** je svojstvo pogona (staklenik, hala, tunel, polje); o njemu ovise predloženi uređaji
  i predlošci rasporeda, a aplikacija ostaje ista.
* **Doziranje** je izvršni uređaj s kalibracijom (`ml_po_min`) i artiklom koji dozira. Svako doziranje je zapis u `naredbe` s
  količinom i ulazi izravno u **stanje zaliha** (zaliha gnojiva i regulatora pH pada, "Za dokupiti" to vidi).
* **Pravila automatike** (`pravila`): senzor, operator, prag, izvršni uređaj, akcija, količina, najkraći razmak i najviše puta
  dnevno. Pravilo izvršava most (ili sam uređaj ako ga ESPHome podržava); granice su uvijek i u firmwareu.
* Globalni ključ zapisa nije poseban stupac: dovoljan je par (`lokacija_id`, `id`).

## Podatkovni model (odmah u svakoj tablici)

Da se više lokacija kasnije može spojiti bez preseljenja podataka, sve tablice koje se dijele dobivaju od početka:

* `lokacija_id` (tko je napravio zapis); par (`lokacija_id`, `id`) je globalno jedinstven ključ.
* Zapisi koji nastaju samo dodavanjem (`mjerenja`, `naredbe`, `dogadjaji`, `alarmi`, `radnje`) ne mijenjaju se nakon upisa,
  pa se sinkroniziraju bez sukoba (ključ je (`lokacija_id`, `id`), ponovno slanje je bezopasno).

Tablice (uz postojeće iz primjera):

| tablica | sadržaj |
|---|---|
| `lokacije` | naziv, vremenska zona, MQTT poslužitelj |
| `pogoni` | postojeći `pogoni` + tema (npr. `procesi/<lok>/<kont>`), zadnji signal (heartbeat) |
| `uredjaji` | pogon, vrsta (svjetlo, pumpa, ventilator, grijač, senzor), tema, jedinica, najdulje trajanje uključenja |
| `predlosci_rasporeda` | središnji predlošci s verzijom (npr. „Rajčica: rast 18 h svjetla") |
| `rasporedi` | uređaj, izvor (predložak i verzija ili „lokalno"), stavke (od, do, dani, ili „svakih N sati M minuta") |
| `naredbe` | ručno uključi/isključi, tko, kada, rezultat |
| `mjerenja` | uređaj, vrijeme, vrijednost (dodaje se samo) |
| `granice` / `alarmi` | min/max po uređaju i zapisi o prekoračenju ili gubitku signala |

## Raspored: server ili na licu mjesta

* **Predložak** se slaže u aplikaciji (središnje ili lokalno) i veže uz vrstu proizvodnje i fazu.
* **Raspored uređaja** je njegova kopija: ili „iz predloška vN" ili „lokalno". Svaka promjena upisuje se u bazu, a most
  je objavljuje na `procesi/<lok>/<kont>/<uređaj>/raspored` kao *retained* JSON, pa ga uređaj dobije čim se spoji.
* Uređaj se smije urediti i **na licu mjesta** (ESPHome web, gumb). Most ga javlja natrag i u bazi se raspored označi kao
  „lokalna izmjena" s vremenom. Pravilo sukoba: pobjeđuje novija izmjena, a stara ostaje u povijesti.
* Faza proizvodnje (kanban) može sama predložiti raspored: premještaj kartice u „Cvatnja" nudi predložak 12/12 h.

## Sigurnost uređaja (u firmwareu, ne u aplikaciji)

* Najdulje uključenje po izlazu (pumpa ne radi dulje od N minuta bez obzira na naredbu).
* Početno stanje izlaza pri pokretanju i pri gubitku veze (svjetlo prema rasporedu, pumpa isključena).
* *Last will* poruka brokeru: gubitak uređaja odmah postaje alarm.
* Zaštita od pregrijavanja i lokalna pravila (ventilator pri T > granica) rade bez PC-a.

## Povezivanje lokacija

Dvije mogućnosti, mogu se i kombinirati:

* **A. Slanje iz baze.** Most svake lokacije povremeno šalje nove zapise (`gid` još nema u središtu) u središnji Postgres i
  povlači nove verzije predložaka. Najjednostavnije i najpouzdanije (radi i uz prekide veze).
* **B. MQTT most među brokerima.** Mosquitto bridge prosljeđuje teme `procesi/<lok>/#` u središnji broker. Dobro za živi
  pregled (trenutne vrijednosti), ne za izvješća.

Preporuka: A za podatke, B samo ako treba živa nadzorna ploča svih lokacija. Svaka lokacija ima vlastite MQTT podatke
za prijavu i TLS prema središtu.

## Redoslijed izrade

| Faza | Što | Procjena |
|---|---|---|
| 0 | **Gotovo:** katalog uređaja, tehnologije, uređaji, rasporedi, pravila, očitanja, naredbe, alarmi u `procesi.opis`; simulator `procesi_simulator.py`; izvješća Trenutno stanje i Doziranje | 1 d |
| 1 | Most: MQTT u bazu (mjerenja, heartbeat, alarmi); nadzorna ploča pogona (trenutne vrijednosti, sparkline, alarmi) | 2 d |
| 2 | **Gotovo:** raspored: tablica + kontrola *vremenska crta* (tjedan × 24 h, povlačenje, dani) + objava na MQTT (retained) + lokalna izmjena s uređaja natrag u bazu | 3 d |
| 3 | **Gotovo:** naredbe (prekidač uređaja na ploči, potvrda uređaja, pogreška bez potvrde), granice i alarmi (otvaranje, zatvaranje, veza) | 2 d |
| 4 | Generator ESPHome YAML-a iz tablica `pogoni` i `uredjaji` (jedan klik: konfiguracija za svaki ESP32) | 2 d |
| 5 | Sinkronizacija s središtem (A), predlošci s verzijama, pregled svih lokacija | 3 d |

## Nove kontrole palete

1. **Vremenska crta rasporeda** (Schedule): 24-satna traka po uređaju, dijelovi se povlače rubovima, odabir dana; vlastita
   kontrola kao i kanban. Najveći posao.
2. **Prekidač uređaja** (DeviceSwitch): pokazuje stvarno stanje (ne samo naredbu), šalje naredbu preko tablice `naredbe`.
3. **Očitanje** (Gauge): živa vrijednost s bojom po granicama + zadnjih 24 h.
4. **Nadzorna ploča pogona:** forma s karticom po pogonu (može biti kanban-sličan prikaz: stupci su stanja).

## Otvorena pitanja

* `lokacija_id` još nije dodan u tablice koje se dijele (zasad samo u pogonima); dodaje se uz fazu 5.
* Jezik mosta: Python (paho) je najbrži za početak; može se kasnije prepisati u Pascal ako treba jedan program.
* Koji senzori (vlaga tla, EC, pH, CO₂, svjetlo) i koje pumpice/releji: o tome ovisi YAML generator.

## Stanje izrade (2026-11-17)

* Faza 0 gotova (model, simulator).
* Faza 1 gotova: **most** `examples/aplikacije/procesi_most.py` (samo standardna biblioteka + `mosquitto_sub`/`mosquitto_pub`): MQTT `stanje`
  i `status` u bazu, alarmi izvan granica i gubitka veze, pravila automatike, naredbe sa stanjem „cekanje" objavljene na `.../set` (doziranje s
  trajanjem iz kalibracije, ograničeno sigurnosnom granicom). Simulator ima način `mqtt` koji objavljuje kao ESP32 i reagira na doziranje.
  Isprobano s pravim brokerom (Mosquitto): očitanja stižu u bazu, pravilo za pH izda naredbu, ona stigne na temu uređaja.
  **Nadzorna ploča** (forma „Nadzorna ploča", prikaz `dash`): kartica po pogonu, redak po senzoru, sparkline, automatsko osvježavanje.
* Pokretanje: `mosquitto -p 1883` (ili postojeći broker), `procesi_most.py Procesi.db`, `procesi_simulator.py mqtt Procesi.db 100`.

* Faza 2 gotova: forma „Raspored (vremenska crta)" (prikaz `timeline`); most objavljuje raspored svakog izvršnog uređaja kao *retained* JSON na
  `<prefiks>/<uređaj>/raspored` (kad se promijeni zapis u bazi), a raspored složen na uređaju prima na `.../raspored/lokalno`, upisuje ga u bazu
  (izvor „lokalno") i bilježi napomenu. Simulator primi raspored, prema njemu računa je li izlaz uključen (od–do, ponoćni prijelaz, „svakih N min
  po M s") i javlja stanje, koje nadzorna ploča pokazuje (UKLJUČENO/isključeno). Oblik poruke:
  `{"izvor":"lokalno","verzija":"…","stavke":[{"dani":"12345","od":"06:00","do":"22:00"},{"dani":"1234567","svakih_min":180,"trajanje_s":120}]}`

* Faza 3 gotova:
  * **Prekidač uređaja** na nadzornoj ploči: klik šalje naredbu (`naredbe`, stanje `cekanje`) i pita za potvrdu.
  * **Potvrda uređaja:** most šalje naredbu s `id` na `.../set` (stanje `poslano`); uređaj odgovara na `.../ack` s `{"id":N}` (`izvrseno`).
    Bez potvrde u 30 s (`--ack-wait`) naredba je `pogreska` i diže se alarm.
  * **Alarmi:** granica (tek nakon dva uzastopna očitanja izvan granica, da jedan šum ne diže alarm), zatvaraju se sami kad je vrijednost opet u granicama;
    veza (last will `offline` ili nema signala dulje od `--silent-min`, zatvara se kad se pogon javi); doziranje preko dnevnog najviše;
    nepotvrđena naredba. Nema udvostručenja otvorenih alarma. Izvješće „Otvoreni alarmi" i program „Potvrdi alarme" zatvara sve.
  * **Zaliha** broji samo poslana i izvršena doziranja (ne ona u čekanju ili s pogreškom).
  * Ispitivanje: `examples/aplikacije/procesi_most_test.sh Procesi.db` (pravi Mosquitto, 10 provjera na kopiji baze).
  * Ispravljena greška mosta: pri gustom prometu poruka petlja nikad nije stizala do slanja naredbi.

* Faza 4 gotova: **ESPHome generator** (`ta_esphome`, izbornik Pogoni > Izradi ESPHome konfiguracije, ili `TyphAccess Procesi.db --esphome=mapa`).
  Za svaki pogon s MQTT temom nastaje `<ime>.yaml`, uz zajedničke `procesi_raspored.h` i `secrets.yaml.example`. Konfiguracija je ispitana pravim
  ESPHomeom 2026.10: shema je ispravna i **sva tri pogona iz primjera prevode se u ESP32 firmware** (`procesi_esphome_test.sh Procesi.db --compile`).
  * Uređaj ima model i priključke: senzori `dht22`, `sht3x`, `ds18b20`, `bh1750`, `adc` (kalibracija `kal_a`, `kal_b`); izlazi `rele` (pin, invertirano),
    `dozator` (skripta s trajanjem, ograničena sigurnosnom granicom), `prozor` (dva releja, vremenski pomični poklopac).
  * Protokol je isti kao u mostu: `.../stanje`, `.../set` (JSON, odgovor `.../ack`), `.../raspored` (zadržana poruka), `status` online/offline (birth/last will).
  * Raspored se izvršava na uređaju (`procesi_raspored.h`, ispitan zasebno C++ testom `tests/esphome_raspored_test.cpp`), a ručna naredba traje do sljedeće
    promjene rasporeda (rubno okidanje). Najdulje uključenje izlaza je skripta uz svaki relej s `najdulje_s`.
  * Poznata ograničenja: raspored se ne sprema u flash (nakon ponovnog pokretanja stigne opet kao zadržana MQTT poruka čim se uređaj spoji; do tada izlaz
    ostaje u zadnjem stanju za svjetlo, a isključen za pumpe i dozatore), najviše 16 izlaza s rasporedom, I2C pinovi su fiksni (GPIO21/22).

* Faza 5 gotova: **više lokacija** (`procesi_sync.py`, `procesi_sync_test.py`).
  * Svaka lokacija ima svoju SQLite bazu i radi bez središta. Središte je **ista aplikacija** (isti `procesi.opis`) koja skuplja sve lokacije, pa su
    nadzorna ploča, izvješća i troškovi odmah dostupni za sve (kartica pogona dobije ispred naziva lokaciju kad ih ima više).
  * **Ključ zapisa:** zapisi lokacije u središtu imaju id i sve vanjske ključeve pomaknute za `broj_lokacije * 1.000.000.000`
    (`id / 1e9` = broj lokacije), pa se lokacije ne sudaraju i ne treba dodatni stupac. Zajednički šifrarnici nisu pomaknuti.
  * **Gore** (lokacija → središte): očitanja samo nova od zadnjeg slanja, ostale tablice cijele (male su), uz brisanje središnjih zapisa te lokacije kojih
    lokalno više nema; ponovno slanje je bezopasno. **Dolje** (središte → lokacija): šifrarnici (vrste uređaja, tehnologije, grupe artikala, vrste radnji,
    vrste proizvodnje, faze) i predlošci rasporeda; urediti ih treba **samo u središtu**.
  * **Prijenos:** izravno u datoteku središnje baze (`sinkroniziraj --local L.db --site N --central S.db [--interval 300]`) ili preko paketa
    (`gore --paket`, `uvezi-gore`, `dolje --paket`, `uvezi-dolje`: JSON u gzipu, prenosi se rsync-om, scp-om ili USB-om).
  * **Predlošci rasporeda** (tablice `predlosci_rasporeda`/`predlosci_stavke`): verzija predloška raste sama kad se promijene stavke (otisak). Raspored
    koji prati predložak (`predlozak_id`) i ima `automatski` dobiva nove stavke sam (most), inače ga prijavljuje izvješće „Rasporedi zastarjeli".
    Izmjena rasporeda na uređaju odvaja ga od predloška.
  * Izvješće „Pregled lokacija": pogoni, otvoreni alarmi, zadnji signal i zadnja sinkronizacija po lokaciji.
  * **Postgres:** središte je zasad SQLite datoteka (na poslužitelju ili dijeljenoj mapi, ili paketi); Postgres bi tražio zaseban upravljački program u skripti
    (psycopg) i nije izrađen jer nije mogao biti ispitan.
