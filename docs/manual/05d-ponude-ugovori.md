# Ponude i ugovori

Obrt radi **ponudu** za posao; kad se stranka odluči, nastaje **ugovor vezan uz tu ponudu**, a ako se naknadno pokaže da treba još nešto, radi se **dodatna ponuda** (s vezom na prvu) i **aneks ugovora**.
Poslovni predložak *Aplikacija → Poslovni predlošci → Ponude i ugovori* izrađuje sve što je za to potrebno; primjer s podacima je i u *Baza → Nova: primjer s blokovima (mali obrt)…*.

## Što je u predlošku

| Dio | Sadržaj |
|---|---|
| Forma **Ponude poslova** | zaglavlje (naručitelj, posao, vrsta *osnovna/dodatna*, osnovna ponuda, status, **avans %**, **dopušteno prekoračenje %**, **rok početka i završetka**, **uvjeti i dodatni troškovi**), tablica **stavki** (vrsta *Usluga* ili *Materijal*, faza, opis, količina, cijena, iznos) i tablica **faza** s rokovima; ispod su zbrojevi usluga, materijala, ukupno i iznos avansa te tri gumba |
| Forma **Ugovori** | ugovori i aneksi: cijena, avans, prekoračenje, rokovi, uvjeti i **plaćanje po fazama**; zbroj faza, najviši dopušteni iznos (cijena + prekoračenje), tablica **stvarnih troškova** i zbroj stvarnih troškova |
| Dopisi **Ugovor** i **Aneks ugovora** | tekst ugovora po člancima (predmet, cijena s razdiobom usluge/materijal, plaćanje s tablicom faza, rokovi, prekoračenje, dodatni troškovi), za Word, PDF ili ispis |
| Makroi (blokovi) | *Napravi ugovor*, *Napravi dodatnu ponudu*, *Napravi aneks*, *Ispis ugovora*, *Ugovor u Word*, *Napravi račun za fazu*, *Provjeri prekoračenje* |

## Tijek rada

1. **Ponuda.** Na formi *Ponude poslova* upiši posao, stavke (usluge i materijal, svaka u svojoj fazi), faze s rokovima, avans, dopušteno prekoračenje i uvjete.
2. **Ugovor.** Kad je ponuda prihvaćena, gumb **Napravi ugovor**: ugovor dobiva cijenu, avans, prekoračenje, rokove i uvjete iz ponude. Plaćanja nastaju ovako: prvo **avans** (postotak ukupne cijene), a ostatak se dijeli **po fazama** prema iznosu stavki svake faze; rok svake faze je rok iz ponude.
   Zaokruživanje: razlika do ugovorene cijene ide na zadnju fazu, pa se rate uvijek zbrajaju u točno ugovorenu cijenu. Ponuda dobiva status *prihvaćena*. Za jednu ponudu ugovor se može napraviti samo jednom.
3. **Dodatni posao.** Ako treba nešto što nije bilo u prvoj ponudi: gumb **Napravi dodatnu ponudu** na osnovnoj ponudi pravi novu ponudu (`…-D1`, `…-D2`) s vezom na nju. Upiši stavke dodatnih radova (obično bez avansa).
4. **Aneks.** Na dodatnoj ponudi gumb **Napravi aneks**: aneks se veže uz ugovor osnovne ponude i uz dodatnu ponudu, a njegova plaćanja nastaju istim pravilom. Aneks pokazuje i **ukupnu cijenu s aneksima**.
5. **Računi po fazama.** Na formi *Ugovori* gumb **Napravi račun za sljedeću fazu** pravi račun (u tablici *Računi*) za prvu fazu koja još nema račun: prvo avans, zatim faze po redu.
   Račun ide ugovornom naručitelju, ima jednu stavku *Radovi po ugovoru* (naziv: broj ugovora i faza) s iznosom faze i PDV-om 25 %, a faza se označi tim računom (stupac `racun_id`), pa se ništa ne naplati dvaput. Kad su sve faze naplaćene, gumb to javlja. Zbroj osnovica računa jednak je ugovorenoj cijeni.
6. **Ispis.** Na formi *Ugovori* gumb **Pregled ugovora / aneksa** otvara dopis prema vrsti zapisa; **U Word…** sprema dokument u `.docx` koji se dalje uređuje.

## Prekoračenje bez upozorenja

**Provjera prekoračenja.** Na formi *Ugovori* upisuj stvarne troškove u tablicu *Stvarni troškovi*. Gumb **Provjeri prekoračenje** upozorava tek kad zbroj troškova pređe ugovorenu cijenu uvećanu za dopušteni postotak (npr. 3.080 + 10 % = 3.388 €); ispod te granice, čak i iznad ugovorene cijene, kaže da upozorenje nije potrebno.

U ponudi i ugovoru zadaje se postotak (npr. 10 %) do kojeg izvođač smije prekoračiti ugovorenu cijenu bez prethodnog upozorenja. U ugovoru se to ispisuje u članku 5. kao postotak i u eurima, uz najviši iznos. Za veće prekoračenje potrebna je pisana suglasnost naručitelja (tekst članka možeš prilagoditi u uređivaču dopisa).

## Prilagodba

* Tekst ugovora i aneksa je običan **dopis**: *Dopis → Uredi dopis*. Možeš mijenjati članke, dodavati oznake (`[kupac]`, `[naziv]`, `[ukupno]`, `[avans_iznos]`, `[prekoracenje_iznos]`, `[najvise]`, `[usluge]`, `[materijal]`, `[rok_pocetka]`, `[rok_zavrsetka]`, `[uvjeti]`, `[ponuda_broj]`, `[osnovni_broj]`, `[ukupno_sa_aneksima]` i dr.) i tablicu faza. Podaci dolaze iz upita **ugovori podaci**.
* Makroi su složeni blokovima pa se mogu otvoriti u uređivaču blokova i izmijeniti (npr. drugačija razdioba avansa i faza).
* Ovaj tijek (dokument izveden iz drugog dokumenta s vezom na njega) ista je ideja kao *račun iz ponude*, *narudžbenica iz ponude* ili *aneks*: nova tablica s `parent_id`, makro koji prepisuje podatke i dopis za ispis.

## Napomene

* Iznosi faza i računa su osnovice; PDV se dodaje na računu (po pravilu koje predložak *Dokument sa stavkama* već koristi).
* Tekst ugovora je **primjer**; pravni sadržaj (odredbe, kazne, jamstva, nadležnost) neka pregleda pravnik ili obrtnička komora prije stvarne uporabe.
* Iznosi stavki su bez PDV-a; hoće li se PDV iskazivati u ugovoru i kako se zaokružuje, provjeri s računovođom.
