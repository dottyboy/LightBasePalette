#!/usr/bin/env python3
"""Dodaje jedinice (i neobavezno pakete) u .lpk i .ctpkg: add_to_pkg.py <paket> <mapa_izvora:core|gui|editors> unit[,unit] [--req bs_x,bs_y]"""
import re, sys
pkg, folder, units = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
reqs = []
if '--req' in sys.argv:
    reqs = sys.argv[sys.argv.index('--req') + 1].split(',')
for fn in (pkg + '.lpk', pkg + '.ctpkg'):
    t = open(fn).read()
    lpk = fn.endswith('.lpk')
    if lpk:
        n = int(re.search(r'<Files Count="(\d+)"', t).group(1))
        add = [u for u in units if f'<UnitName Value="{u}"/>' not in t]
        t = t.replace(f'<Files Count="{n}">', f'<Files Count="{n+len(add)}">')
        blk = ''.join(f'      <Item{n+1+i}>\n        <Filename Value="../src/{folder}/{u}.pas"/>\n        <UnitName Value="{u}"/>\n      </Item{n+1+i}>\n' for i, u in enumerate(add))
    else:
        add = [u for u in units if f'<UnitName Value="{u}"/>' not in t]
        blk = ''.join(f'      <Item>\n        <Filename Value="..\\src\\{folder}\\{u}.pas"/>\n        <UnitName Value="{u}"/>\n      </Item>\n' for u in add)
    t = t.replace('    </Files>', blk + '    </Files>', 1)
    for r in reqs:
        if f'<PackageName Value="{r}"/>' in t:
            continue
        if lpk:
            n = int(re.search(r'<RequiredPkgs Count="(\d+)"', t).group(1))
            t = t.replace(f'<RequiredPkgs Count="{n}">', f'<RequiredPkgs Count="{n+1}">')
            t = t.replace('    </RequiredPkgs>', f'      <Item{n+1}>\n        <PackageName Value="{r}"/>\n      </Item{n+1}>\n    </RequiredPkgs>', 1)
        else:
            t = t.replace('    </RequiredPkgs>', f'      <Item>\n        <PackageName Value="{r}"/>\n      </Item>\n    </RequiredPkgs>', 1)
    open(fn, 'w').write(t)
print('ok', pkg, units, reqs)
