// Ispitivanje docs/esphome/procesi_raspored.h na računalu: g++ -I../docs/esphome esphome_raspored_test.cpp -o /tmp/t && /tmp/t
#include <stdio.h>
#include "procesi_raspored.h"
static int fails = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s (redak %d)\n", #c, __LINE__); fails++; } else printf("ok   %s\n", #c); } while (0)
int main() {
  CHECK(proces_maska("12345") == 0x1F);
  CHECK(proces_maska("67") == 0x60);
  CHECK(proces_maska("") == 0x7F);
  CHECK(proces_minute("06:15", -1) == 375);
  CHECK(proces_minute("24:00", -1) == 1440);
  CHECK(proces_minute("x", 7) == 7);
  CHECK(proces_minute(nullptr, 9) == 9);
  ProcesRaspored r;
  CHECK(proces_promjena(r, true) == -1);                   // raspored još nije stigao
  proces_obrisi(r);
  proces_dodaj(r, "12345", "06:00", "22:00", 0, 0);
  CHECK(proces_ukljuceno(r, 1, 12 * 60, 0));               // ponedjeljak podne
  CHECK(!proces_ukljuceno(r, 1, 23 * 60, 0));              // ponedjeljak 23:00
  CHECK(!proces_ukljuceno(r, 6, 12 * 60, 0));              // subota podne: nije u danima
  ProcesRaspored n;
  proces_obrisi(n);
  proces_dodaj(n, "1234567", "22:00", "06:00", 0, 0);       // preko ponoći
  CHECK(proces_ukljuceno(n, 3, 23 * 60, 0));
  CHECK(proces_ukljuceno(n, 4, 2 * 60, 0));                // sutradan u 02:00 još traje
  CHECK(!proces_ukljuceno(n, 4, 12 * 60, 0));
  ProcesRaspored p;
  proces_obrisi(p);
  proces_dodaj(p, "6", "20:00", "02:00", 0, 0);             // samo subota navečer
  CHECK(proces_ukljuceno(p, 6, 21 * 60, 0));
  CHECK(proces_ukljuceno(p, 7, 60, 0));                    // nedjelja 01:00 je nastavak subote
  CHECK(!proces_ukljuceno(p, 6, 60, 0));                   // subota 01:00 nije (petak nije u danima)
  ProcesRaspored v;
  proces_obrisi(v);
  proces_dodaj(v, "1234567", nullptr, nullptr, 180, 120);   // svaka 3 sata po 2 minute
  CHECK(proces_ukljuceno(v, 2, 3 * 60, 30));
  CHECK(!proces_ukljuceno(v, 2, 3 * 60 + 2, 1));
  CHECK(proces_ukljuceno(v, 2, 6 * 60 + 1, 59));
  // rubno okidanje
  ProcesRaspored e;
  proces_obrisi(e);
  proces_dodaj(e, "1234567", "06:00", "22:00", 0, 0);
  CHECK(proces_promjena(e, true) == 1);                    // prvi put: primijeni
  CHECK(proces_promjena(e, true) == -1);                   // isto stanje: ne dira (ručna naredba ostaje)
  CHECK(proces_promjena(e, false) == 0);                   // rub: isključi
  // prazan raspored: izlaz isključen
  ProcesRaspored z;
  proces_obrisi(z);
  CHECK(!proces_ukljuceno(z, 1, 600, 0));
  CHECK(proces_promjena(z, false) == 0);
  // granica broja stavki
  ProcesRaspored g;
  proces_obrisi(g);
  bool svi = true;
  for (int i = 0; i < PROCES_MAX_STAVKI; i++) svi = svi && proces_dodaj(g, "1", "01:00", "02:00", 0, 0);
  CHECK(svi && !proces_dodaj(g, "1", "01:00", "02:00", 0, 0));
  CHECK(&proces_rasp(0) != &proces_rasp(1));
  CHECK(&proces_rasp(3) == &proces_rasp(3));
  proces_obrisi(proces_rasp(2));
  CHECK(proces_rasp(2).postoji && !proces_rasp(5).postoji);
  printf(fails ? "ima pogrešaka\n" : "svi pokusi su prošli\n");
  return fails ? 1 : 0;
}
