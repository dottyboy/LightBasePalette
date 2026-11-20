# Zlatne snimke vlastitih kontrola

`ownshots.pas` crta po jednu scenu vlastitih kontrola (`TYPHACCESS_PROVIDER=own`): polja svih varijanti, otvoren popis combo-a i
kalendar datuma, memo i popisi, formatirani tekst, stablo, kalendari, tablica (pregled sa zebrom i podnožjem, uređivanje u ćeliji, potkartica, zamrznuti
stupci). Svaka scena je PNG usporedjen bajt po bajt s `golden/`.

* `./run.sh` usporedi (izlaz 0 = isto)
* `./run.sh record` ponovno snimi (samo kad je promjena izgleda namjerna i pregledana)

Snimke su napravljene na Qt6 (offscreen). Isti program se može izgraditi za GTK3 i snimiti u zasebnu mapu da se vidi koliko
se izgled razlikuje (kontrole crtaju same sebe, pa bi razlika trebala biti samo u fontu).
