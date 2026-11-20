#!/usr/bin/env python3
"""Ugradi catalog/*.json u src/core/ta_catalogdata.pas (program ne treba datoteke na disku)."""
import glob, json, os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
files = sorted(glob.glob(os.path.join(root, 'catalog', '*.json')))
out = ['unit ta_catalogdata;',
       '{ GENERIRANO alatom tools/gen_catalog.py iz catalog/*.json - ne uredivati rucno. }',
       '', '{$mode objfpc}{$H+}', '', 'interface', '',
       'function CatalogDataCount: Integer;',
       'function CatalogData(AIndex: Integer): string;', '', 'implementation', '']
for i, f in enumerate(files):
    with open(f, encoding='utf-8') as fh:
        doc = json.load(fh)          # greska u JSON-u prekida gradnju
    text = json.dumps(doc, ensure_ascii=False, separators=(',', ':'))
    out.append('function Data%d: string;' % i)
    out.append('begin')
    out.append("  Result := '';")
    for k in range(0, len(text), 150):
        chunk = text[k:k + 150].replace("'", "''")
        out.append("  Result := Result + '%s';" % chunk)
    out.append('end;')
    out.append('')
out.append('function CatalogDataCount: Integer;')
out.append('begin')
out.append('  Result := %d;' % len(files))
out.append('end;')
out.append('')
out.append('function CatalogData(AIndex: Integer): string;')
out.append('begin')
out.append("  Result := '';")
out.append('  case AIndex of')
for i in range(len(files)):
    out.append('    %d: Result := Data%d;' % (i, i))
out.append('  end;')
out.append('end;')
out.append('')
out.append('end.')
path = os.path.join(root, 'src', 'core', 'ta_catalogdata.pas')
new = '\n'.join(out) + '\n'
old = open(path, encoding='utf-8').read() if os.path.exists(path) else ''
if new != old:
    open(path, 'w', encoding='utf-8').write(new)
    print('ta_catalogdata.pas osvježen (%d domena)' % len(files))
