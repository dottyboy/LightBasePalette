// Raspored izlaza na ESP32 (ESPHome), usklađen s mostom procesi_most.py.
// Čista logika bez ovisnosti o ESPHome-u: razumije stavke {dani, od, do, svakih_min, trajanje_s}
// i javlja promjenu stanja (rubno okidanje), pa ručna naredba traje do sljedeće promjene rasporeda.
#pragma once
#include <stdint.h>
#include <string.h>

#define PROCES_MAX_STAVKI 12

struct ProcesiStavka {
  uint8_t dani;       // bit 0 = ponedjeljak ... bit 6 = nedjelja
  int16_t od, doo;    // minute od ponoći; -1 = nije zadano
  int16_t svakih;     // ponavljanje u minutama; 0 = nema
  int16_t trajanje;   // sekunde uključenja pri ponavljanju
};

struct ProcesRaspored {
  ProcesiStavka s[PROCES_MAX_STAVKI];
  uint8_t n = 0;
  bool postoji = false;   // raspored je stigao (i prazan raspored je raspored: izlaz je isključen)
  int8_t zadnje = -1;     // zadnje izračunato stanje (-1 nepoznato)
};

// "12345" -> maska dana
inline uint8_t proces_maska(const char *dani) {
  uint8_t m = 0;
  if (!dani) return 0x7F;
  for (const char *p = dani; *p; p++)
    if (*p >= '1' && *p <= '7') m |= (1 << (*p - '1'));
  return m ? m : 0x7F;
}

// "HH:MM" -> minute; "24:00" = 1440; neispravno ili prazno -> zadano
inline int16_t proces_minute(const char *t, int16_t zadano) {
  if (!t || strlen(t) < 4) return zadano;
  const char *c = strchr(t, ':');
  if (!c) return zadano;
  int h = 0, m = 0;
  for (const char *p = t; p < c; p++) { if (*p < '0' || *p > '9') return zadano; h = h * 10 + (*p - '0'); }
  for (const char *p = c + 1; *p; p++) { if (*p < '0' || *p > '9') return zadano; m = m * 10 + (*p - '0'); }
  if (h > 24 || m > 59) return zadano;
  return (int16_t) (h * 60 + m);
}

inline void proces_obrisi(ProcesRaspored &r) { r.n = 0; r.postoji = true; r.zadnje = -1; }

inline bool proces_dodaj(ProcesRaspored &r, const char *dani, const char *od, const char *doo, int svakih, int trajanje) {
  if (r.n >= PROCES_MAX_STAVKI) return false;
  ProcesiStavka &s = r.s[r.n++];
  s.dani = proces_maska(dani);
  s.od = proces_minute(od, -1);
  s.doo = proces_minute(doo, -1);
  s.svakih = (int16_t) svakih;
  s.trajanje = (int16_t) trajanje;
  return true;
}

// Je li izlaz po rasporedu sada uključen. dan: 1 = ponedjeljak ... 7 = nedjelja.
inline bool proces_ukljuceno(const ProcesRaspored &r, int dan, int minute, int sekunda) {
  uint8_t danas = 1 << (dan - 1);
  uint8_t jucer = 1 << ((dan + 5) % 7);
  int sec = minute * 60 + sekunda;
  for (int i = 0; i < r.n; i++) {
    const ProcesiStavka &s = r.s[i];
    if (s.svakih > 0) {
      if ((s.dani & danas) && (sec % (s.svakih * 60)) < s.trajanje) return true;
      continue;
    }
    if (s.od < 0 || s.doo < 0) continue;
    if (s.od <= s.doo) {
      if ((s.dani & danas) && minute >= s.od && minute < s.doo) return true;
    } else {
      if ((s.dani & danas) && minute >= s.od) return true;      // do ponoći
      if ((s.dani & jucer) && minute < s.doo) return true;      // nastavak sljedećeg dana
    }
  }
  return false;
}

// Rubno okidanje: vraća 1 = uključi, 0 = isključi, -1 = ništa (stanje se nije promijenilo od zadnjeg računanja).
inline int proces_promjena(ProcesRaspored &r, bool sada) {
  if (!r.postoji) return -1;
  if (r.zadnje == (sada ? 1 : 0)) return -1;
  r.zadnje = sada ? 1 : 0;
  return r.zadnje;
}

// Stanje rasporeda svih izlaza: ESPHome unosi "includes" poslije deklaracija globals, pa se tip ne smije
// koristiti u globals; umjesto toga izlaz k ima raspored proces_rasp(k).
#define PROCES_MAX_IZLAZA 16
inline ProcesRaspored &proces_rasp(int k) {
  static ProcesRaspored r[PROCES_MAX_IZLAZA];
  return r[k < 0 || k >= PROCES_MAX_IZLAZA ? 0 : k];
}
