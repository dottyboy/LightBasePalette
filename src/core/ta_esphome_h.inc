{ Izradeno alatom tools/gen_esphome_h.py iz docs/esphome/procesi_raspored.h; ne uredjivati rucno. }
const
  EspHomeRasporedH: string =
    '// Raspored izlaza na ESP32 (ESPHome), usklađen s mostom procesi_most.py.' + LineEnding +
    '// Čista logika bez ovisnosti o ESPHome-u: razumije stavke {dani, od, do, svakih_min, trajanje_s}' + LineEnding +
    '// i javlja promjenu stanja (rubno okidanje), pa ručna naredba traje do sljedeće promjene rasporeda.' + LineEnding +
    '#pragma once' + LineEnding +
    '#include <stdint.h>' + LineEnding +
    '#include <string.h>' + LineEnding +
    '' + LineEnding +
    '#define PROCES_MAX_STAVKI 12' + LineEnding +
    '' + LineEnding +
    'struct ProcesiStavka {' + LineEnding +
    '  uint8_t dani;       // bit 0 = ponedjeljak ... bit 6 = nedjelja' + LineEnding +
    '  int16_t od, doo;    // minute od ponoći; -1 = nije zadano' + LineEnding +
    '  int16_t svakih;     // ponavljanje u minutama; 0 = nema' + LineEnding +
    '  int16_t trajanje;   // sekunde uključenja pri ponavljanju' + LineEnding +
    '};' + LineEnding +
    '' + LineEnding +
    'struct ProcesRaspored {' + LineEnding +
    '  ProcesiStavka s[PROCES_MAX_STAVKI];' + LineEnding +
    '  uint8_t n = 0;' + LineEnding +
    '  bool postoji = false;   // raspored je stigao (i prazan raspored je raspored: izlaz je isključen)' + LineEnding +
    '  int8_t zadnje = -1;     // zadnje izračunato stanje (-1 nepoznato)' + LineEnding +
    '};' + LineEnding +
    '' + LineEnding +
    '// "12345" -> maska dana' + LineEnding +
    'inline uint8_t proces_maska(const char *dani) {' + LineEnding +
    '  uint8_t m = 0;' + LineEnding +
    '  if (!dani) return 0x7F;' + LineEnding +
    '  for (const char *p = dani; *p; p++)' + LineEnding +
    '    if (*p >= ''1'' && *p <= ''7'') m |= (1 << (*p - ''1''));' + LineEnding +
    '  return m ? m : 0x7F;' + LineEnding +
    '}' + LineEnding +
    '' + LineEnding +
    '// "HH:MM" -> minute; "24:00" = 1440; neispravno ili prazno -> zadano' + LineEnding +
    'inline int16_t proces_minute(const char *t, int16_t zadano) {' + LineEnding +
    '  if (!t || strlen(t) < 4) return zadano;' + LineEnding +
    '  const char *c = strchr(t, '':'');' + LineEnding +
    '  if (!c) return zadano;' + LineEnding +
    '  int h = 0, m = 0;' + LineEnding +
    '  for (const char *p = t; p < c; p++) { if (*p < ''0'' || *p > ''9'') return zadano; h = h * 10 + (*p - ''0''); }' + LineEnding +
    '  for (const char *p = c + 1; *p; p++) { if (*p < ''0'' || *p > ''9'') return zadano; m = m * 10 + (*p - ''0''); }' + LineEnding +
    '  if (h > 24 || m > 59) return zadano;' + LineEnding +
    '  return (int16_t) (h * 60 + m);' + LineEnding +
    '}' + LineEnding +
    '' + LineEnding +
    'inline void proces_obrisi(ProcesRaspored &r) { r.n = 0; r.postoji = true; r.zadnje = -1; }' + LineEnding +
    '' + LineEnding +
    'inline bool proces_dodaj(ProcesRaspored &r, const char *dani, const char *od, const char *doo, int svakih, int trajanje) {' + LineEnding +
    '  if (r.n >= PROCES_MAX_STAVKI) return false;' + LineEnding +
    '  ProcesiStavka &s = r.s[r.n++];' + LineEnding +
    '  s.dani = proces_maska(dani);' + LineEnding +
    '  s.od = proces_minute(od, -1);' + LineEnding +
    '  s.doo = proces_minute(doo, -1);' + LineEnding +
    '  s.svakih = (int16_t) svakih;' + LineEnding +
    '  s.trajanje = (int16_t) trajanje;' + LineEnding +
    '  return true;' + LineEnding +
    '}' + LineEnding +
    '' + LineEnding +
    '// Je li izlaz po rasporedu sada uključen. dan: 1 = ponedjeljak ... 7 = nedjelja.' + LineEnding +
    'inline bool proces_ukljuceno(const ProcesRaspored &r, int dan, int minute, int sekunda) {' + LineEnding +
    '  uint8_t danas = 1 << (dan - 1);' + LineEnding +
    '  uint8_t jucer = 1 << ((dan + 5) % 7);' + LineEnding +
    '  int sec = minute * 60 + sekunda;' + LineEnding +
    '  for (int i = 0; i < r.n; i++) {' + LineEnding +
    '    const ProcesiStavka &s = r.s[i];' + LineEnding +
    '    if (s.svakih > 0) {' + LineEnding +
    '      if ((s.dani & danas) && (sec % (s.svakih * 60)) < s.trajanje) return true;' + LineEnding +
    '      continue;' + LineEnding +
    '    }' + LineEnding +
    '    if (s.od < 0 || s.doo < 0) continue;' + LineEnding +
    '    if (s.od <= s.doo) {' + LineEnding +
    '      if ((s.dani & danas) && minute >= s.od && minute < s.doo) return true;' + LineEnding +
    '    } else {' + LineEnding +
    '      if ((s.dani & danas) && minute >= s.od) return true;      // do ponoći' + LineEnding +
    '      if ((s.dani & jucer) && minute < s.doo) return true;      // nastavak sljedećeg dana' + LineEnding +
    '    }' + LineEnding +
    '  }' + LineEnding +
    '  return false;' + LineEnding +
    '}' + LineEnding +
    '' + LineEnding +
    '// Rubno okidanje: vraća 1 = uključi, 0 = isključi, -1 = ništa (stanje se nije promijenilo od zadnjeg računanja).' + LineEnding +
    'inline int proces_promjena(ProcesRaspored &r, bool sada) {' + LineEnding +
    '  if (!r.postoji) return -1;' + LineEnding +
    '  if (r.zadnje == (sada ? 1 : 0)) return -1;' + LineEnding +
    '  r.zadnje = sada ? 1 : 0;' + LineEnding +
    '  return r.zadnje;' + LineEnding +
    '}' + LineEnding +
    '' + LineEnding +
    '// Stanje rasporeda svih izlaza: ESPHome unosi "includes" poslije deklaracija globals, pa se tip ne smije' + LineEnding +
    '// koristiti u globals; umjesto toga izlaz k ima raspored proces_rasp(k).' + LineEnding +
    '#define PROCES_MAX_IZLAZA 16' + LineEnding +
    'inline ProcesRaspored &proces_rasp(int k) {' + LineEnding +
    '  static ProcesRaspored r[PROCES_MAX_IZLAZA];' + LineEnding +
    '  return r[k < 0 || k >= PROCES_MAX_IZLAZA ? 0 : k];' + LineEnding +
    '}' + LineEnding;
