#!/usr/bin/env python3
"""Upravljanje stvarnim GUI-jem u Xvfb-u (XTEST): click, dclick, drag, move, type, key.
Primjer: Xvfb :99 -screen 0 1400x900x24 &  ;  DISPLAY=:99 bin/TyphAccess ... &  ;  python3 tools/xdrive.py click 260 126
Snimka: DISPLAY=:99 import -window root slika.png  (trazi python3-xlib i ImageMagick). Ne koristiti pkill -f (ubije vlastitu ljusku)."""
import sys, time
from Xlib import X, display
from Xlib.ext import xtest
d = display.Display(':99')
def move(x,y):
    xtest.fake_input(d, X.MotionNotify, x=x, y=y); d.sync(); time.sleep(0.05)
def btn(b, down):
    xtest.fake_input(d, X.ButtonPress if down else X.ButtonRelease, b); d.sync(); time.sleep(0.05)
def click(x,y,b=1):
    move(x,y); btn(b,True); btn(b,False); time.sleep(0.3)
def dclick(x,y):
    move(x,y); btn(1,True); btn(1,False); btn(1,True); btn(1,False); time.sleep(0.5)
def drag(x1,y1,x2,y2,steps=8):
    move(x1,y1); btn(1,True)
    for i in range(1,steps+1):
        move(x1+(x2-x1)*i//steps, y1+(y2-y1)*i//steps); time.sleep(0.08)
    time.sleep(0.3); btn(1,False); time.sleep(0.4)
def typ(text):
    from Xlib import XK
    for ch in text:
        ks = XK.string_to_keysym(ch if ch!=' ' else 'space')
        kc = d.keysym_to_keycode(ks)
        xtest.fake_input(d, X.KeyPress, kc); xtest.fake_input(d, X.KeyRelease, kc); d.sync(); time.sleep(0.05)
def key(name):
    from Xlib import XK
    kc = d.keysym_to_keycode(XK.string_to_keysym(name))
    xtest.fake_input(d, X.KeyPress, kc); xtest.fake_input(d, X.KeyRelease, kc); d.sync(); time.sleep(0.3)
cmd=sys.argv[1]; a=[int(v) if v.lstrip('-').isdigit() else v for v in sys.argv[2:]]
{'click':click,'dclick':dclick,'drag':drag,'move':move,'type':lambda t: typ(str(t)),'key':key}[cmd](*a)
