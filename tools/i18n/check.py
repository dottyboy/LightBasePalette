#!/usr/bin/env python3
"""Provjera potpunosti prijevoda: svaki Tr('English') u kodu mora imati hrvatski par u ta_i18n_hr*.pas
(osim kljuceva koji su vec hrvatski i prevode se u en-tablici). Izlaz: popis kljuceva bez prijevoda; kod izlaza 1 ako ih ima."""
import re, glob, os, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
SRC = os.path.join(ROOT, 'src')
lit = r"'((?:[^']|'')*)'"
used = {}
for f in glob.glob(os.path.join(SRC, '**', '*.pas'), recursive=True):
    if 'i18n_' in os.path.basename(f) or os.path.basename(f) in ('ta_i18n.pas',):
        continue
    for n, line in enumerate(open(f, encoding='utf-8', errors='ignore'), 1):
        for m in re.finditer(r"\bTr\(" + lit, line):
            used.setdefault(m.group(1).replace("''", "'"), []).append((os.path.relpath(f, SRC), n))
hr = set()
en = set()
for f in glob.glob(os.path.join(SRC, 'core', 'ta_i18n_*.pas')):
    txt = open(f, encoding='utf-8').read()
    target = en if os.path.basename(f) == 'ta_i18n_en.pas' else hr
    # parovi 'kljuc', 'vrijednost' unutar RegisterTranslations
    for m in re.finditer(r"'((?:[^']|'')*)'\s*,\s*'((?:[^']|'')*)'", txt):
        target.add(m.group(1).replace("''", "'"))
missing = {k: v for k, v in used.items() if k not in hr and k not in en}
for k, v in sorted(missing.items()):
    print('%s:%d  %s' % (v[0][0], v[0][1], k[:100]))
print('Tr ključeva: %d, bez prijevoda: %d' % (len(used), len(missing)))
sys.exit(1 if missing else 0)
