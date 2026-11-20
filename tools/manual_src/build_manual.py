#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gradi priručnik: generira referencu iz popisa u tools/manual_src/*.py, provjerava da je
popis jednak onome što stvarno postoji u kodu, piše tests/manual_examples.txt (primjeri koje
smoke test izvodi) i, ako postoji pandoc, sastavlja docs/manual/html/prirucnik.html."""
import os, re, sys, glob, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from functions import FUNCS

MAN = os.path.join(ROOT, 'docs', 'manual')
errors = []

def code_functions():
    s = open(os.path.join(ROOT, 'src/core/ta_expr.pas'), encoding='utf-8').read()
    a = s.index('function TParser.CallFn')
    names = []
    for m in re.finditer(r"AName = '([a-z_0-9]+)'", s[a:]):
        if m.group(1) not in names:
            names.append(m.group(1))
    return names

def check_functions():
    code = set(code_functions())
    doc = [f[1] for f in FUNCS]
    if len(doc) != len(set(doc)):
        errors.append('Funkcija je dokumentirana dvaput: ' + ', '.join(sorted(n for n in set(doc) if doc.count(n) > 1)))
    # funkcije koje trebaju stanje baze (nema samostalnog primjera) opisane su u poglavlju koje im pripada
    elsewhere = {'fgl': ('09-4gl-specifikacija.md', '`Fgl(')}
    for n in sorted(code - set(doc)):
        if n in elsewhere and elsewhere[n][1] in open(os.path.join(MAN, elsewhere[n][0]), encoding='utf-8').read():
            continue
        errors.append('Funkcija u kodu nije u priručniku: ' + n)
    for n in sorted(set(doc) - code):
        errors.append('Funkcija u priručniku ne postoji u kodu: ' + n)

def md_escape_cell(t):
    return t.replace('|', '\\|').replace('\n', ' ')

def write_functions():
    out = ['# Referenca: funkcije izraza', '',
           'Izrazi se pišu u formama (zadane vrijednosti, provjere, izračunata polja, uvjeti), izvješćima, upitima, makroima i u funkciji `Eval` modula. '
           'Argumenti se odvajaju zarezom, tekst ide u dvostruke ili jednostruke navodnike, a decimalni broj se piše s točkom (`12.5`). '
           'Imena funkcija ne razlikuju velika i mala slova. Rezultati u zadnjem stupcu prikazani su onako kako ih vidi korisnik programa (hrvatski zapis).', '',
           'Prazna vrijednost (Null) prenosi se kroz račun: `1 + Null` je Null. Funkcije `Nz`, `Coalesce` i `IsNull` služe za rukovanje praznim vrijednostima.', '']
    groups = []
    for f in FUNCS:
        if f[0] not in groups:
            groups.append(f[0])
    for g in groups:
        out += ['## ' + g, '', '| Funkcija | Opis | Primjer | Rezultat |', '|---|---|---|---|']
        for f in FUNCS:
            if f[0] != g:
                continue
            out.append('| `%s` | %s | `%s` | %s |' % (md_escape_cell(f[2]), md_escape_cell(f[3]), md_escape_cell(f[4]),
                       md_escape_cell(f[5]) if f[5] else ''))
        out.append('')
    out += ['## Zbrojevi u izvješćima', '',
            'Unutar izvješća (i podizvješća) mogu se koristiti zbrojevi nad redcima: `Sum`, `Count`, `Avg`, `Min`, `Max`, `First`, `Last`, `StDev`, `Var`, `Median`, '
            '`SumAll`, `CountAll`, `AvgAll`, `RunSum`, `RunCount`, `RunGSum`, `RunGCount`. Navode se s imenom polja u uglatim zagradama, npr. `=Sum([iznos])`. Pojedinosti u poglavlju o izvješćima.', '']
    open(os.path.join(MAN, 'referenca-izrazi.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')

def write_examples():
    lines = []
    for f in FUNCS:
        res = f[5]
        if res.startswith('('):
            continue
        if res == '(prazno)':
            res = ''
        lines.append(f[4].replace('\\', '') + '\t' + res)
    open(os.path.join(ROOT, 'tests', 'manual_examples.txt'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    return len(lines)

def check_images():
    """Svaka slika na koju upućuje priručnik mora postojati, a slika bez reference je greška (zastarjela)."""
    used = set()
    for f in glob.glob(os.path.join(MAN, '*.md')):
        for m in re.finditer(r"!\[[^\]]*\]\((slike/[^)]+)\)", open(f, encoding='utf-8').read()):
            used.add(m.group(1))
            if not os.path.exists(os.path.join(MAN, m.group(1))):
                errors.append('Slika ne postoji (pokreni tools/screenshots.sh): %s u %s' % (m.group(1), os.path.basename(f)))
    d = os.path.join(MAN, 'slike')
    if os.path.isdir(d):
        for f in sorted(os.listdir(d)):
            if f.endswith('.png') and 'slike/' + f not in used:
                errors.append('Slika nije nigdje korištena: slike/' + f)

def check_faq():
    """Naslovi poglavlja 12-poruke-faq.md (### „poruka”) moraju postojati u izvornom kodu (dijelovi odvojeni s ... ili …)."""
    path = os.path.join(MAN, '12-poruke-faq.md')
    if not os.path.exists(path):
        return
    code = ''
    for f in glob.glob(os.path.join(ROOT, 'src', '*', '*.pas')):
        if os.path.basename(f) in ('ta_manualdata.pas', 'ta_catalogdata.pas'):
            continue
        code += open(f, encoding='utf-8').read()
    for m in re.finditer(r"^### „(.*)”\s*$", open(path, encoding='utf-8').read(), re.M):
        for frag in re.split(r"…|\.\.\.", m.group(1)):
            frag = frag.strip().rstrip('.')
            frag = frag.strip()
            if len(frag) >= 8 and frag not in code and frag.replace('"', "'") not in code:
                errors.append('Poruka iz FAQ-a ne postoji u kodu: „%s”' % frag)

def check_controls():
    """Svaka vrsta kontrole iz koda mora biti opisana u poglavlju o formama, a svaka makro naredba u poglavlju o makroima."""
    code = open(os.path.join(ROOT, 'src/core/ta_controls.pas'), encoding='utf-8').read()
    a = code.index('function PropertyNamesFor')
    kinds = []
    for m in re.finditer(r"AKind = '([A-Za-z]+)'", code[a:a + 6000]):
        if m.group(1) not in kinds:
            kinds.append(m.group(1))
    forme = open(os.path.join(MAN, '04-forme.md'), encoding='utf-8').read()
    for k in kinds:
        if '`' + k + '`' not in forme:
            errors.append('Kontrola u kodu nije u priručniku (04-forme.md): ' + k)
    fr = open(os.path.join(ROOT, 'src/gui/ta_formrun.pas'), encoding='utf-8').read()
    verbs = set(re.findall(r"Verb = '([a-z]+)'", fr))
    sc = open(os.path.join(ROOT, 'src/core/ta_script.pas'), encoding='utf-8').read()
    verbs |= set(re.findall(r"Verb = '([a-z]+)'", sc))
    mak = open(os.path.join(MAN, '03-makroi-moduli.md'), encoding='utf-8').read()
    for v in sorted(verbs):
        if '`' + v + '`' not in mak and '`' + v + ':' not in mak:
            errors.append('Makro naredba u kodu nije u priručniku (03-makroi-moduli.md): ' + v)
    ev = set(re.findall(r"GetEv\('([A-Za-z]+)'\)", fr))
    for e in sorted(ev):
        if e not in mak:
            errors.append('Događaj u kodu nije u priručniku: ' + e)

def extract_4gl():
    """Cjeloviti programi iz tutoriala (```4gl) idu u tests/manual_4gl/ i provjeravaju se u smoke testu."""
    d = os.path.join(ROOT, 'tests', 'manual_4gl')
    os.makedirs(d, exist_ok=True)
    for f in glob.glob(os.path.join(d, '*.4gl')):
        os.remove(f)
    t = open(os.path.join(MAN, '07-4gl-tutorial.md'), encoding='utf-8').read()
    blocks = re.findall(r"```4gl\n(.*?)```", t, re.S)
    for i, b in enumerate(blocks, 1):
        open(os.path.join(d, 'primjer%02d.4gl' % i), 'w', encoding='utf-8').write(b)
    return len(blocks)

def extract_4gl_recipes():
    """Programi iz 11-4gl-recepti.md (```4gl) idu u tests/manual_4gl_recepti/; smoke test ih izvodi i provjerava '-- expect:' retke."""
    d = os.path.join(ROOT, 'tests', 'manual_4gl_recepti')
    os.makedirs(d, exist_ok=True)
    for f in glob.glob(os.path.join(d, '*.4gl')):
        os.remove(f)
    path = os.path.join(MAN, '11-4gl-recepti.md')
    if not os.path.exists(path):
        return 0
    blocks = re.findall(r"```4gl\n(.*?)```", open(path, encoding='utf-8').read(), re.S)
    for i, b in enumerate(blocks, 1):
        open(os.path.join(d, 'rec%02d.4gl' % i), 'w', encoding='utf-8').write(b)
    return len(blocks)

def extract_pascal():
    """Moduli iz vodica (```pascal) idu u tests/manual_pascal/; redci '// test: izraz => rezultat' u tests/manual_pascal.txt."""
    d = os.path.join(ROOT, 'tests', 'manual_pascal')
    os.makedirs(d, exist_ok=True)
    for f in glob.glob(os.path.join(d, '*.pas')):
        os.remove(f)
    t = ''
    for fn in ('03b-moduli-vodic.md', '16-recepti-iz-accessa.md'):
        t += open(os.path.join(MAN, fn), encoding='utf-8').read() + '\n'
    blocks = re.findall(r"```pascal\n(.*?)```", t, re.S)
    lines = []
    for i, b in enumerate(blocks, 1):
        open(os.path.join(d, 'modul%02d.pas' % i), 'w', encoding='utf-8').write(b)
        for m in re.finditer(r"^// test: (.*?) => (.*)$", b, re.M):
            lines.append('%02d\t%s\t%s' % (i, m.group(1), m.group(2)))
    open(os.path.join(ROOT, 'tests', 'manual_pascal.txt'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    return len(blocks), len(lines)

def build_html():
    css = os.path.join(MAN, 'stil.css')
    if not os.path.exists(css):
        open(css, 'w').write('body{font-family:sans-serif;max-width:60em;margin:2em auto;padding:0 1em;color:#222;line-height:1.5}'
                             'table{border-collapse:collapse;margin:.8em 0}th,td{border:1px solid #ccc;padding:4px 8px;vertical-align:top;font-size:.93em}'
                             'th{background:#f0f0f0}code{background:#f4f4f4;padding:0 3px}pre{background:#f4f4f4;padding:.6em;overflow:auto}'
                             'nav#TOC{background:#fafafa;border:1px solid #ddd;padding:.5em 1em}')
    # dodaci: specifikacija 4GL i format kataloga
    app = [('4gl', os.path.join(ROOT, 'docs', '4GL-SPEC.md'), '09-4gl-specifikacija.md'), ('katalog', os.path.join(ROOT, 'catalog', 'README.md'), '08-katalog.md')]
    for _, src, dst in app:
        if os.path.exists(src):
            t = open(src, encoding='utf-8').read()
            open(os.path.join(MAN, dst), 'w', encoding='utf-8').write(t)
    files = sorted(glob.glob(os.path.join(MAN, '*.md')))
    if not files:
        return
    os.makedirs(os.path.join(MAN, 'html'), exist_ok=True)
    cmd = ['pandoc', '-s', '--embed-resources', '--toc', '--toc-depth=2', '-f', 'markdown', '-t', 'html5', '--metadata', 'title=TyphAccess — priručnik',
           '--metadata', 'lang=hr', '-c', 'stil.css', '--include-after-body=' + os.path.join(ROOT, 'tools', 'manual_src', 'search.html'), '-o', os.path.join(MAN, 'html', 'prirucnik.html')] + files
    try:
        subprocess.run(cmd, check=True, cwd=MAN)
    except Exception as e:
        print('pandoc nije uspio:', e)

if __name__ == '__main__':
    os.makedirs(MAN, exist_ok=True)
    check_functions()
    check_controls()
    check_images()
    check_faq()
    if errors:
        print('\n'.join(errors))
        sys.exit(1)
    write_functions()
    n = write_examples()
    n4 = extract_4gl()
    npas, ntest = extract_pascal()
    nrec = extract_4gl_recipes()
    build_html()
    print('priručnik: %d funkcija dokumentirano, %d primjera za test, %d 4GL programa, %d modula (%d provjera), %d 4GL recepata' % (len(FUNCS), n, n4, npas, ntest, nrec))
