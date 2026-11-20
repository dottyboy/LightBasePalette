#!/usr/bin/env python3
"""Ugradi docs/manual/html/prirucnik.html (s ugrađenim stilom) u src/gui/ta_manualdata.pas."""
import os, re
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, 'docs', 'manual', 'html', 'prirucnik.html')
css = os.path.join(root, 'docs', 'manual', 'stil.css')
dst = os.path.join(root, 'src', 'gui', 'ta_manualdata.pas')
if not os.path.exists(src):
    raise SystemExit('nema prirucnik.html: pokreni tools/manual_src/build_manual.py')
html = open(src, encoding='utf-8').read()
html = html.replace('<link rel="stylesheet" href="../stil.css" />', '<style>' + open(css, encoding='utf-8').read() + '</style>')
# FPC odbija procedure s previse naredbi ("too complex"), pa se HTML dijeli na dijelove u zasebnim funkcijama
step = 160
per_part = 1500
chunks = [html[i:i + step].replace("'", "''").replace('\n', "'#10'") for i in range(0, len(html), step)]
parts = [chunks[i:i + per_part] for i in range(0, len(chunks), per_part)]
out = ['unit ta_manualdata;', '{ GENERIRANO alatom tools/gen_manual.py iz docs/manual - ne uredivati rucno. }', '',
       '{$mode objfpc}{$H+}', '', 'interface', '', 'function ManualHtml: string;', '', 'implementation', '']
for n, part in enumerate(parts, 1):
    out += ['function ManualPart%d: string;' % n, 'var', '  S: string;', 'begin', "  S := '';"]
    for c in part:
        out.append("  S := S + '%s';" % c)
    out += ['  Result := S;', 'end;', '']
out += ['function ManualHtml: string;', 'begin', '  Result := ' + ' + '.join('ManualPart%d' % n for n in range(1, len(parts) + 1)) + ';', 'end;', '', 'end.']
new = '\n'.join(out) + '\n'
old = open(dst, encoding='utf-8').read() if os.path.exists(dst) else ''
if new != old:
    open(dst, 'w', encoding='utf-8').write(new)
    print('ta_manualdata.pas osvježen (%d KB HTML)' % (len(html) // 1024))
