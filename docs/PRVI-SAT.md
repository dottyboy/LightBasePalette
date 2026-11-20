# Prvi sat: od praznog projekta do aplikacije (Light profil)

Cilj: u 30 minuta, samo mišem, složiti aplikaciju s popisom, unosom, jednim izvješćem i jednim 4GL programom.
Pretpostavka: instaliran CodeTyphon i ovaj projekt (LightPalette) u `~/Desktop/Development/LightPalette`.

## 0. Pokretanje
1. `light/typhon-light.sh` (prvi put stvara profil `~/.typhon-light` iz običnih postavki; ne mijenja ih).
2. U paleti su samo stranice: **TyphAccess**, Standard, Additional, Common Controls, Data Controls, Data Access, Dialogs. Ostalo je skriveno; puni IDE (`typhonstart64`) radi kao i prije.

## 1. Novi projekt
1. **File → New… → Project → TyphAccess aplikacija.** IDE stvara program i prvu formu, a paketi (Zeos, jezgra, dijalozi, paleta) su već dodani.
2. Spremi (Ctrl+S) u novu mapu.

## 2. Baza
1. Sa stranice **TyphAccess** baci na formu `TaDatabase`.
2. Desni klik na njega → **Pokreni pametni čarobnjak…** → odaberi tablicu, upiši što želiš ("popis partnera s filterom po gradu"), odaberi jedno od ponuđenih rješenja (svako ima postotak pouzdanosti) i spremi.

## 3. Forma s poljima
1. Sa stranice **TyphAccess** baci `TaEdit`. U Inspektoru objekata svojstvo **Variant** bira vrstu polja: text, password, combo, droplist, spin, date, currency.
2. Promijeni Variant u **combo**, upiši stavke u **Items**: tekst, izvor i pravila ostaju.
3. Svojstvo **Options** pokazuje samo ono što varijanta ima (npr. DropDownCount za combo, DecimalPlaces za spin).

## 4. Izračun i pravila
1. Baci `TaFormBinder`: kroz njega polje može imati izračun, pravilo (`Rule`), boju po uvjetu i vidljivost.
2. Isto kao u TyphAccess dizajneru: ista komponenta, isti zapisi.

## 5. Izvješće i 4GL
1. `TaReport` i `TaProgram` (stranica TyphAccess): dvoklik otvara izbor izvješća, odnosno uređivač programa (tekst / blokovi / kosturi).
2. Kosturi `.4glt` stižu u etapi E6; do tada program se piše u uređivaču ili gradi pametnim čarobnjakom.

## 6. Tema
1. U TyphAccessu: **Izgled → Boja teme** (Plava, Zelena, Crvena, …) i **Oblik**; tema se može spremiti u aplikaciju.

## Poznata ograničenja Light profila (E3)
- Paleta zasad još ima osnovne LCL stranice (Standard, Data Controls …) jer obitelji Label, Button, Check, Grid i ostale stižu u etapi E11; nakon toga ostaju samo naše stranice.
- Skrivanje stranica radi po popisu poznatih stranica; stranica novog paketa pojavit će se na kraju dok se ne doda u `light/make_light_profile.py`.
