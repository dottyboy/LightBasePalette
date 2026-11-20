#!/bin/bash
# Izrađuje ČISTO stablo za objavu (jedan repozitorij, nova povijest) iz TyphAccess + LightPalette.
#   tools/make_release.sh IZLAZNA_MAPA [OZNAKA]       npr. tools/make_release.sh ~/objava/typhaccess v0.1.0-alpha.1
# Što se NE prenosi: modul fiskalizacije, TESTBASE (tuđi materijali), prevedene datoteke (bin/lib/dist), certifikati, privatno (.claude, memorija).
# Rezultat: mapa s git repozitorijem i jednim početnim commitom (bez ikakve povijesti iz razvojnih repozitorija). Ništa se ne šalje na mrežu.
set -euo pipefail
OUT="${1:?izlazna mapa}"; TAG="${2:-}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LP="$(cd "$HERE/../LightPalette" && pwd)"
[ -e "$OUT" ] && [ -n "$(ls -A "$OUT" 2>/dev/null)" ] && { echo "izlazna mapa nije prazna: $OUT"; exit 1; }
mkdir -p "$OUT"
# TyphAccess: sve pod gitom, osim izuzetaka (src je u razvoju veza na ../LightPalette/src)
git -C "$HERE" ls-files -z | grep -zv -E '^(TESTBASE/|src$|cert/|dist/|bin/|lib/)' | (cd "$HERE" && tar --null -T - -cf -) | tar -C "$OUT" -xf -
# LightPalette (src, lazarus, fonts, themes, skeletons, tests/own, ...) u isto stablo; bez modula fiskalizacije i prevedenih binarki
git -C "$LP" ls-files -z | grep -zv -E '^(modules/|tests/wizards/wizard_smoke_test$|tests/rowspike/rowspike$|README\.md$|\.gitignore$)' | (cd "$LP" && tar --null -T - -cf -) | tar -C "$OUT" -xf -
mkdir -p "$OUT/docs/paleta"
git -C "$LP" show HEAD:README.md > "$OUT/docs/paleta/README.md"
{ git -C "$HERE" show HEAD:.gitignore; echo; git -C "$LP" show HEAD:.gitignore; } | awk '!seen[$0]++' > "$OUT/.gitignore"
printf '\n# lokalno (nije u objavi)\nmodules/\nTESTBASE/\ncert/\n' >> "$OUT/.gitignore"
cd "$OUT"
git init -q
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-Dottyboy}" -c user.email="${GIT_AUTHOR_EMAIL:-noreply@example.invalid}" commit -q -m "TyphAccess ${TAG:-alpha}: početno izdanje"
[ -n "$TAG" ] && git tag "$TAG"
echo "gotovo: $OUT ($(git ls-files | wc -l) datoteka)"
