#!/bin/bash
# Isti scene kao run.sh, ali na GTK3 (Xvfb :99, snimka zaslona ImageMagickom jer GetFormImage na GTK3 vraca crnu sliku).
# Usporedba s Qt snimkama je postotna (tekst se drukcije zaglađuje): izlaz 1 ako je neka scena preko 15 % drukcija.
cd "$(dirname "$0")"
TB="${CODETYPHON_DIR:-/usr/local/codetyphon}/typhon/bin64/typhonbuild"
sed -e 's#<Filename Value="ownshots"/>#<Filename Value="ownshots_gtk3"/>#; s#<UnitOutputDirectory Value="lib"/>#<UnitOutputDirectory Value="lib_gtk3"/>#' own.ctpr > OwnGtk3.ctpr
mkdir -p lib_gtk3
"$TB" --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=gtk3 OwnGtk3.ctpr 2>&1 | grep -E "Error|Fatal" && exit 1
pgrep Xvfb >/dev/null || { Xvfb :99 -screen 0 1400x900x24 >/dev/null 2>&1 & sleep 2; }
rm -rf out_gtk3; mkdir -p out out_gtk3
DISPLAY=:99 OWN_XSHOT=1 DBUS_SESSION_BUS_ADDRESS=disabled: timeout 300 ./ownshots_gtk3 >/dev/null 2>&1
cp out/*.png out_gtk3/
python3 - <<'PY'
import glob, os, sys
from PIL import Image, ImageChops
bad = 0
for f in sorted(glob.glob('golden/*.png')):
    n = os.path.basename(f)
    a = Image.open(f).convert('RGB'); b = Image.open('out_gtk3/' + n).convert('RGB')
    d = ImageChops.difference(a, b).convert('L').point(lambda v: 255 if v > 40 else 0)
    pct = 100.0 * sum(1 for p in d.getdata() if p) / (a.size[0] * a.size[1])
    print('%-28s %.1f %%' % (n, pct))
    if pct > 15: bad += 1
sys.exit(1 if bad else 0)
PY
