# TyphAccess: paleta za CodeTyphon / Lazarus

Paket `typhaccess_dsgn` (run + design time) stavlja komponente TyphAccessa u paletu, stranica **TyphAccess**.
Komponente: **TaSideMenu**, nevizualne **TaDatabase**, **TaExpression**, **TaReport**, **TaProgram** i **TaFormBinder** (opis nize).

**TaSideMenu** - bocni izbornik u stilu XP trake (kao TJvXPBar), sa skupinama koje se sklapaju,
harmonikom (otvorena jedna skupina), uskim nacinom samo s ikonama i pamcenjem zadnje stavke.

## Instalacija
- CodeTyphon: *Package -> Open Package File* -> `typhaccess_dsgn.ctpkg` -> *Compile*, pa *Install*
  (ili `typhonbuild --pcp=$HOME/.typhon64 --ws=qt6 typhaccess_dsgn.ctpkg` za samo prevodjenje).
- Lazarus: *Package -> Open Package File* -> `typhaccess_dsgn.lpk` -> *Use -> Install*.
  Izvorni kod je u `../src/core` i `../src/gui` (put je vec upisan u paket).
- Ikone palete su u `resources/` (`TASIDEMENU.png`, `_150`, `_200`).

## TaSideMenu: kako se puni (kao XPBar)
U inspektoru objekata svojstvo **Groups** otvara urednik zbirke:
1. *Add* skupinu: `Caption`, `IconName` (ime ikone iz zalihe) ili `ImageIndex` (uz `Images` = TImageList).
2. U skupini svojstvo **Items** je nova zbirka: *Add* stavku: `Caption`, `Action`, `IconName` / `ImageIndex`, `Visible`.
3. `Action` je ista radnja kao na gumbu u TyphAccessu: `openform:Racuni`, `openreport:Naziv`, `macro:M`, `fgl:Program`, `run:Procedura`.
4. Klik na stavku okida **OnItemClick(Sender, AGroup, AItem, AAction)**.

U kodu:
```pascal
G := Menu.Groups.Add; G.Caption := 'Kolo';
with G.Items.Add do begin Caption := 'Predvidi kolo'; Action := 'fgl:Predvidi kolo'; end;
```
ili tekstom (kako to radi runtime), istovremeno se pune i zbirke:
```pascal
Menu.Items := '# Kolo|calendar' + LineEnding + 'Predvidi kolo|fgl:Predvidi kolo';
```
Svojstva `Accordion`, `Compact` i `StateKey` (pamti otvorenu skupinu po korisniku) rade kao u TyphAccessu.


## Nevizualne komponente
Bacis ih na formu; povezuju se svojstvom `Database`.

| Komponenta | Sto radi | Najvaznije |
|---|---|---|
| `TaDatabase` | baza (SQLite, PostgreSQL, MariaDB), zadana baza za jezik izraza | `Engine`, `FileName` / `Host`..`Password`, `Active`; `ExecSQL`, `Scalar`, `NewQuery`, `Tables`, `LoadObject`, `Setting`; `AfterOpen`, `BeforeClose` |
| `TaExpression` | racuna izraze TyphAccessa (`[x] * 2`, `Zaokruzi`, `DSum("iznos","stavke")`, `Predict`...) | `Expression`, `Variables` (name=value), `OnGetVariable`, `Evaluate`, `Check`, `LastError`, `RaiseErrors` |
| `TaReport` | izvjesce iz baze | `ReportName`, `Parameters` (za `[?Naziv]`), `Render`, `ExportPdf`, `ExportHtml`, `Preview`, `ReportNames` |
| `TaProgram` | 4GL program iz baze (`ProgramName`) ili iz teksta (`Source`) | `Run` (izlazni kod), `Check`, `Output`, `OnDisplay`, `OnMessage`, `OnError`, `OnPrompt` |

Primjer:
```pascal
Db.FileName := 'baza/smartbet.db'; Db.Active := True;
Ex.Variables.Add('porez=0.25');
ShowMessage(VarToStr(Ex.Evaluate('Zaokruzi([porez] * 100, 0)')));
Rep.ReportName := 'Sustavi: kartice'; Rep.ExportPdf('kartice.pdf');
Prog.ProgramName := 'Sustavi'; Prog.OnDisplay := @PrikaziIspis; Prog.Run;
```
`TaDatabase` ne otvara bazu u vrijeme dizajna (samo pri pokretanju). Zadana baza (`MakeDefault`) je ona koju
koriste funkcije izraza, pa uz vise baza postavi `MakeDefault` samo na jednoj.

Paket trazi: adLCL, pl_ZeosDBO, pl_PascalScript, pl_FpSpreadsheet, pl_RichMemo, pl_Image32 (CodeTyphon).
U `.lpk` su imena paketa za Lazarus pretpostavljena i nisu provjerena.


## TaFormBinder: "Access" ponasanje na JVCL / RX / LCL kontrolama
Ne nasljeduje kontrole. Baci se na formu, `DataSource` pokazuje na skup podataka, a svaka stavka zbirke `Bindings`
opisuje jednu kontrolu (svojstvo `Control` je padajuci popis kontrola s forme):

| Svojstvo | Znacenje |
|---|---|
| `FieldName` | polje; kontrole s `DataSource`/`DataField` (TRxDB*, TJvDB*, TDB*) dobiju vezu same |
| `Expression` | izracun, npr. `Zaokruzi(Nz([kolicina],0) * Nz([cijena],0), 2)`; uz `FieldName` upisuje se u polje dok se zapis ureduje, bez njega samo se prikaze |
| `Rule`, `RuleMessage` | pravilo provjere (`[kolicina] > 0`); neispunjeno oboja kontrolu, a `Post` se odbija s `EBinderValidation` |
| `DefaultValue` | izraz za zadanu vrijednost kod novog zapisa (`Date()`) |
| `VisibleIf`, `EnabledIf` | izraz koji prikazuje / omogucuje kontrolu |
| `CondFormat` | uvjetno oblikovanje: `[iznos] > 1000 => #C00000 #FFE9E9 bold` |
| `Format` | oblik prikaza (`#,##0.00`, `0.##`): ide u `DisplayFormat`/`DecimalPlaces` kontrole i polja |

Procedura `ApplyCroatianLocale` (unit `ta_binder`) postavlja hrvatske oblike odmah; pozovi je u `.lpr` prije
`Application.CreateForm`, jer neke kontrole pamte oblike pri stvaranju i kasnije ih ne mijenjaju.
**Spin (`TFloatSpinEdit`, `TRxDBSpinEdit`) na Qt-u sam crta decimalni znak iz okoline procesa**, ne iz FPC postavki:
da pokaze `2,51`, a ne `2.51`, program treba pokrenuti s `LC_NUMERIC=hr_HR.UTF-8` (u pokretacu: `export LC_NUMERIC=hr_HR.UTF-8`).
Unos prihvaca i zarez i tocku. Ako to ne zelis, decimalne kolicine radije vodi u `TRxDBCurrEdit` s `Format = '#,##0.###'`.
`Locale = blCroatian` (zadano) pri pokretanju postavlja hrvatske oblike (1.234,50 i 31.12.2026.) u globalne postavke
programa; `blSystem` ih ne dira. Izrazi vide polja tekuceg zapisa kao `[ime]` i sve funkcije jezika, a s `Database`
i `DLookup`, `DSum` i ostale domenske funkcije. Kad se forma sastavlja u kodu, nakon dodavanja stavki pozovi `Binder.Activate`.
`Validate` radi provjeru i prije `Post`, a `Errors` daje poruke. Dogadjaj `OnValidationFailed` moze dopustiti spremanje.

Bilješke iz primjera: Zeos preslikava stupce `TEXT` u memo (mreza pokazuje "(MEMO)"), pa u tablicama za RX mreze
koristi `VARCHAR(n)`; stupci `DATE` moraju biti deklarirani kao `DATE` da bi `TRxDBDateEdit` radio.
`TRxDBSpinEdit` sam ponovno postavlja decimale iz polja pri svakom pomaku; binder ih ispravlja prema `Format`. Zbroj u
podnozju `TRxDBGrid` trazi `FooterOptions.Active := True` i `FooterOptions.RowCount := 1`.
Vise stavki na istoj kontroli je dopusteno: uvjetna oblikovanja se zbrajaju, a neispunjeno pravilo ima prednost.

## Primjer: demo/binderdemo
`demo/binderdemo.pas` (+ `binderdemo.ctpr`) je prozor racuna sastavljen u kodu: `TaSideMenu`, `TRxDBGrid`,
`TRxDBLookupCombo`, `TRxDBDateEdit`, `TRxDBSpinEdit`, `TRxDBCurrEdit`, `TJvxCurrencyEdit` i `TaFormBinder`.
Prevodi se s `typhonbuild --pcp=$HOME/.typhon64 --ws=qt6 binderdemo.ctpr`, a `./binderdemo` otvara prozor.
S `--snimke=mapa` izvede scenarij (novi zapis, izracun, uvjetno oblikovanje, neispunjeno pravilo, spremanje)
i snimi PNG korake (vec su u `demo/snimke/`).


## Paketi (od E0)

| Paket | Sadrzaj | Ovisi o |
|---|---|---|
| `typhaccess_core` | jezgra: `src/core` + 5 `src/gui` jedinica koje jezgra koristi (`ta_sidemenu`, `ta_icons`, `ta_iconsdata`, `ta_richedit`, `ta_pagesetup`) | LCL, Zeos, PascalScript, FPSpreadsheet, RichMemo, Image32 |
| `typhaccess_editors` | dijalozi i carobnjaci (sloj B) u `src/editors` | `typhaccess_core` |
| `typhaccess_dsgn` | paleta: `ta_register`, `TaDatabase`/`TaExpression`/`TaReport`/`TaProgram`, `TaFormBinder`, property i component editori | oba gore + `bs_ideintf` |

Redoslijed prevodenja: `typhonbuild --pcp=$HOME/.typhon64 --ws=qt6` za `typhaccess_core.ctpkg`, zatim `typhaccess_editors.ctpkg`, zatim `typhaccess_dsgn.ctpkg`.
Aplikacija TyphAccess i smoke test ne koriste pakete nego putanje `src/core;src/gui;src/editors`.
