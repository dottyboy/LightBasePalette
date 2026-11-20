#!/usr/bin/env python3
"""Sastavlja ta_register.res: ikone komponenata za paletu (RCDATA, ime = veliko ime klase, uz _150 i _200).
  make_icons_res.py          svijetle ikone (resources/), za svijetlu temu IDE-a (zadano, to je u repozitoriju)
  make_icons_res.py dark     tamne ikone (resources/dark/, izradi ih make_dark_icons.py), za tamnu temu IDE-a
Pokretati nakon promjene ikona."""
import glob, os, struct, sys
here = os.path.dirname(os.path.abspath(__file__))

def pad4(n):
    return (4 - n % 4) % 4

def entry(name, data):
    nm = name.encode('utf-16le') + b'\0\0'
    tn = struct.pack('<HH', 0xFFFF, 10) + nm
    tn += b'\0' * pad4(8 + len(tn))
    hs = 8 + len(tn) + 16
    out = struct.pack('<II', len(data), hs) + tn + struct.pack('<IHHII', 0, 0x30, 0, 0, 0) + data
    return out + b'\0' * pad4(len(out))

res = struct.pack('<IIHHHHIHHII', 0, 32, 0xFFFF, 0, 0xFFFF, 0, 0, 0, 0, 0, 0)
n = 0
mode = sys.argv[1] if len(sys.argv) > 1 else 'light'
src = os.path.join(here, 'resources', 'dark') if mode == 'dark' else os.path.join(here, 'resources')
for f in sorted(glob.glob(os.path.join(src, 'TA*.png'))):
    name = os.path.splitext(os.path.basename(f))[0].upper()
    res += entry(name, open(f, 'rb').read())
    n += 1
open(os.path.join(here, 'ta_register.res'), 'wb').write(res)
print('ta_register.res:', n, 'ikona', '(' + mode + ')')
