# Plan: vlastita tablica (Grid pružatelja `own`)

Cilj: tablica koja se crta sama (kao ostale vlastite kontrole), pa izgleda i radi isto na Qt-u, GTK-u i drugdje, bez `TDBGrid`-a.
Stanje 2026-11-17: vlastiti su Edit (svih 8 varijanti), Memo plain, List (list, checklist) i Calendar (3 varijante).
Grid je najveći dio jer ga rabe obitelj Grid (readonly, editable, datasheet, entry), svi datasheet prikazi i podforme izvršitelja
formi (`ta_formrun`), upit po formi (F7), popis vrijednosti u ćeliji (F9), uvjetno bojanje redaka i zbrojevi u podnožju.

## Što `TDBGrid` danas radi za nas (popis obveza)
- redci iz skupa podataka (`TDataSource`), tekuci redak prati kursor skupa; 600+ redaka bez zastoja
- stupci: polje, naslov, širina (iz rječnika `colwidth`), poravnanje, samo čitanje, vidljivost, padajući popis (strani ključ)
- prikaz: `TField.DisplayText` (formati datuma/iznosa kroz `OnGetText`), memo polja kao tekst, kvačica/prekidač za logička
- naslov: klik sortira (oznaka smjera), povlačenje ruba mijenja širinu
- uvjetno oblikovanje (`OnPrepareCanvas`): boja retka/ćelije po pravilima; zebra; visina retka
- uređivanje u ćeliji: tekst, padajući popis, datum, LOV (F9), potvrda i otkazivanje, novi i brisanje retka, spremanje pri izlasku iz retka
- tipke: strelice, Tab/Enter, PgUp/PgDn, Home/End, Ctrl+Home/End, Insert/Delete; kotačić; pomicanje klizačem
- podnožje sa zbrojevima (varijanta s RX-om) i brojač zapisa
- upit po formi u tablici (traka s poljem po stupcu, F7/F8)

## Etape
| Etapa | Posao | Procjena |
|---|---|---|
| **0. Popis i sučelje** (GOTOVO 2026-11-17: obitelj Grid ne ovisi o izvršitelju formi; `TaGridDataEngine.InnerDBGrid` ostaje samo za LCL/RX pružatelje; izvršitelj ima vlastiti `TDBGrid` kod, to je etapa 5) | popisati sve upotrebe `TDBGrid` u kodu (ta_formrun, ta_grid, ta_mainform, ta_querydesign, ta_lovdlg, ta_rowhost) i izdvojiti sučelje što izvršitelj traži (`TaGridHost`: stupci, događaji, trenutno polje, odabir); zadržati `TDBGrid` kao pružatelja `lcl` (zamjena po pružatelju, kao kod ostalih) | 1 dan |
| **1. Pregled** (GOTOVO 2026-11-17) | `TaOwnGrid`: model nad skupom podataka (čitanje prozora redaka oko kursora, `MoveBy`, bez kopiranja cijele tablice), zaglavlje, redci, zebra, poravnanje, širine, okomiti i vodoravni klizač, indikator, tekući redak i ćelija, tipke i miš za kretanje, sinkronizacija s kursorom skupa, sortiranje klikom na naslov, širina povlačenjem | 4–5 dana |
| **2. Izgled** (GOTOVO 2026-11-17 za varijante readonly i datasheet obitelji Grid) | uvjetno oblikovanje (događaj stila ćelije umjesto `OnPrepareCanvas`), visina retka, zbrojevi u podnožju, logička polja kao kvačica/prekidač, memo polja, tema (tokeni); zamjena u varijantama readonly i datasheet obitelji Grid; pariteti | 3–4 dana |
| **3. Uređivanje** (GOTOVO 2026-11-17) | uređivač u ćeliji (vlastiti Edit/Combo/Date/Spin po vrsti polja) preko ćelije; potvrda (Enter, Tab, izlazak iz retka) i odustajanje (Esc); novi redak, brisanje, upis u skup; padajući popis za strani ključ; F9 LOV; samo čitanje i obavezna polja; poruke o greškama | 5–6 dana |
| **4. Dodaci** (GOTOVO 2026-11-17: oznacavanje vise redaka Ctrl/Shift/Ctrl+A, kopiranje Ctrl+C/Ctrl+Insert u TSV, brisanje oznacenih, preraspored stupaca povlacenjem naslova, sirina po sadrzaju dvoklikom na rub, osvijetljen redak ispod misa, potkartica kao u Accessu, 100.000 redaka bez zastoja; ostaje traka upita po formi u vlastitoj mrezi i izvoz) | označavanje više redaka, kopiranje ćelija, preraspored stupaca, trake upita po formi (F7/F8), izvoz, performanse na 100.000 redaka (predmemorija prozora, bez ponovnog mjerenja teksta) | 2–3 dana |
| **5. Zamjena i čišćenje** | ostali prikazi (mreža glavnog prozora, rezultati upita, popis vrijednosti), uklanjanje zaobilaženja memo teksta (`TaGridFmtDraw`), zlatne snimke, GTK3 provjera, dokumentacija | 2 dana |

Ukupno oko 3 tjedna. Etape 0–2 daju samo-za-pregled mrežu koja je dovoljna za sve popise i izvješćne prikaze; uređivanje (3) je
najrizičnije jer zamjenjuje i ponašanje pri spremanju.

## Rizici i kako ih smanjujemo
- **Kursor skupa**: LCL skupovi se pomiču kursorom, ne indeksom. Model čita prozor redaka oko tekućeg i vraća kursor (`DisableControls`), a za veliki skup koristi `RecNo`/`RecordCount` gdje ih skup podržava.
- **Ponašanje pri spremanju** (autoenter, serijski brojevi, okidači): uređivanje ide istim putem kroz skup kao danas, a ne zaobilazi ga.
- **Opseg**: zasebno pustiti Grid iza zastavice pružatelja (`TYPHACCESS_PROVIDER=own`) dok ne prođu svi smoke i parity testovi.
- **Pristupačnost i IME**: kao kod Edita (nije podržano zasad); ostaje `lcl` kao rezerva.

## Redoslijed rada
0 → 1 → 2 daje odmah vidljivu korist (popisi i podforme izgledaju isto svugdje); 3 tek nakon pregleda.

## Dodano nakon etape 5 (2026-11-17)
- zamrznuti stupci (`FrozenColumns`, i u `TaGridOptions`), Tab pomiče izmedju ćelija u uređivačkim varijantama, opis ćelije kad tekst ne stane
- zlatne snimke vlastitih kontrola: `tests/own/run.sh` (9 scena: polja, popisi, kalendari, tablica u 4 stanja)
- preostaje: GTK3 provjera (isti program sa `--ws=gtk3` u zasebnu mapu snimki), traka upita po formi u vlastitoj mrezi (radi kroz adapter, izgled nije pregledan)
