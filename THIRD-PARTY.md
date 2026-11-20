# Komponente trećih strana

Program se prevodi s CodeTyphonom/Lazarusom (FPC) i koristi sljedeće; svaka zadržava vlastitu licencu (provjeri točne uvjete u izvoru prije dijeljenja binarnih izdanja):

| Komponenta | Namjena | Licenca |
|---|---|---|
| FPC RTL/FCL i LCL (Lazarus) | jezik, sučelje | LGPL s iznimkom za statičko povezivanje |
| Zeos (pl_ZeosDBO) | pristup bazama (SQLite, PostgreSQL, MariaDB) | LGPL s iznimkom za povezivanje |
| pl_RichMemo | uređivač formatiranog teksta (LCL varijanta) | LGPL s iznimkom |
| pl_PascalScript | skriptni moduli | zlib-slična |
| pl_FpSpreadsheet | uvoz/izvoz tablica | LGPL s iznimkom |
| JetBrains Mono (mapa `fonts/` u LightPalette) | slova | SIL OFL 1.1 (tekst uz slova) |
| ESPHome (samo ako ga sam instaliraš) | prevođenje generiranih konfiguracija za ESP32 | MIT / GPLv3 dijelovi; ne isporučuje se |
| Mosquitto (samo ako ga sam instaliraš) | MQTT broker za most i probe | EPL/EDL |

Ikone su izvorno nacrtane (alat `tools/gen_icons.py`), nisu preuzete.
