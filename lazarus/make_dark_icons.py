#!/usr/bin/env python3
"""Izradjuje tamne inacice ikona palete (resources/dark/*.png) iz svijetlih (resources/*.png).
Tamni dijelovi (obrisi, siva i tamnoplava) posvijetle se prema bijelom da se vide na tamnoj pozadini IDE-a;
zasicene boje (plava, zelena, narancasta, crvena) i bijelo ostaju. Pokretati nakon promjene ikona."""
import glob, os
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, 'resources', 'dark')
os.makedirs(out, exist_ok=True)

def lighten(px):
    r, g, b, a = px
    if a == 0:
        return px
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    sat = (max(r, g, b) - min(r, g, b)) / 255.0
    # tamno i slabo zasiceno (sivo, tamnoplavo): jako posvijetli; zasiceno srednje tamno: malo
    if lum < 0.5:
        k = 0.62 if sat < 0.45 else 0.28
        return (int(r + (255 - r) * k), int(g + (255 - g) * k), int(b + (255 - b) * k), a)
    return px

n = 0
for f in sorted(glob.glob(os.path.join(here, 'resources', 'TA*.png'))):
    im = Image.open(f).convert('RGBA')
    im.putdata([lighten(p) for p in im.getdata()])
    im.save(os.path.join(out, os.path.basename(f)))
    n += 1
print('tamne ikone:', n)
