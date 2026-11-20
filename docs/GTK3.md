# GTK3: prvo ispitivanje (2026-11-11)

Cilj: vidjeti koliko posla traži GTK3 uz Qt6, na kojem je sve dosad građeno. Samo ispitivanje, ništa nije popravljano.

## Kako je ispitano
- CodeTyphon na ovoj mašini nema gotove LCL jedinice za GTK3 (samo qt6, gtk2, nogui). `typhonbuild --ws=gtk3` ih je sam preveo
  zajedno s ovisnostima (PascalScript, Zeos...), bez intervencije.
- Smoke projekt: kopija `tests/Smoke.ctpr` s izlazom `lib_gtk3` i imenom `smoke_gtk3`
  (`typhonbuild --pcp=$HOME/.typhon64 --ws=gtk3 tests/SmokeGtk3.ctpr`).
- Izvodi se u Xvfb-u (`DISPLAY=:99`), jer GTK3 nema offscreen način kao Qt.

## Rezultat
- **Prevođenje: bez ijedne greške** (cijeli kod, 90 hintova, 145 napomena).
- **Izvođenje: 2778 provjera prolazi, 13 pada**, a program se na kraju zaglavi pri gašenju (`INTERFACES finalize`, backtrace
  kroz `ta_richedit.ApplyLater`; `timeout` ga prekine s 124). Na Qt6 je isti paket 0 padova.

## Padovi (za daljnji razvoj)
| Skupina | Padovi | Moguć uzrok |
|---|---|---|
| Veličina u dizajneru | 3: širina upisana u Inspektoru (form i report designer), povlačenje desnog ruba (report designer) | GTK3 drukčije obrađuje `SetBounds` / minimalnu veličinu kontrole ili događaje miša; treba pogledati `ta_formdesign` i `ta_reportdesign` |
| Pristupna povreda | 2: `design geometry` (nakon Shift+strelice) i `dzfam` (nakon što su sve provjere prošle) | uništavanje dizajnera / kontrola pri `Free` na GTK3; vjerojatno redoslijed uništavanja djece ili izbornika |
| SideMenu | 1: "it paints" | `gtk_widget_draw: assertion '!alloc_needed'` — crtanje prije alokacije; treba crtati u `Paint`, ne izvana |
| Rich edit | 4: podebljano, poravnanje, boja, veličina nakon učitavanja | `TaRichEdit` (RichMemo) na GTK3 ne vraća oblikovanje; vjerojatno RichMemo nije potpuno podržan na GTK3 |
| Pisma | 3: blocks demo, offers (ugovor, aneks) | vjerojatno posljedica rich edita (tekst pisma ide kroz njega) |
| Gašenje | zaglavi pri izlazu | `ta_richedit.ApplyLater` se poziva iz `Application.Destroy` (odgođeni poziv nakon uništenja); isti uzrok bi trebalo popraviti i na Qt6 radi urednosti |

## Što NIJE ispitano
- Paritetni testovi (PNG snimke) na GTK3: razlike u pikselima su očekivane, treba posebne zlatne snimke.
- Light IDE na GTK3 i stvarno ponašanje u IDE-u (povlačenje na formu, palete).
- Pokretači treće strane (TAChart, RX grid) na GTK3.

## Procjena
Radi ugrubo: nema prepravke arhitekture. Preostaje oko 5 skupina sitnih popravaka, najveći je RichMemo (možda se ne može
popraviti bez zamjene kontrole). Dan do dva za sve osim rich edita.

## Vlastite kontrole na GTK3 (2026-11-17)
`tests/own/run_gtk3.sh` gradi isti skup scena (polja svih varijanti, popisi, kalendari, tablica u 4 stanja) za GTK3 i snima zaslon
u Xvfb-u (`GetFormImage` na GTK3 vraća crnu sliku). Sve scene se izvode bez rušenja i izgledaju isto kao na Qt-u: razlika je 3-8 % piksela, a to je
zaglađivanje teksta i fokus (bez upravitelja prozora GTK ne aktivira prozor, pa prvo polje nema fokusni okvir). Da bi i font bio isti, kontrole
same postavljaju pismo teme (`ApplyThemeFont`: obitelj i veličina iz tokena), a ne ovise o zadanom pismu sučelja.
Što to znači za plan: kontrole koje crtamo same nisu dio popisa padova iz prvog ispitivanja; ostaju samo rich edit (RichMemo) i izvorni dijalozi.
