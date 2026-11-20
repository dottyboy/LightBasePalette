#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generira skup ikona (PNG 16, 24 i 32 px) iz vektorskog crteza (pycairo) i ugraduje ga u src/gui/ta_iconsdata.pas.
Isti crtez za sve velicine, pa su linije oštre. Stil: tanka linija u tamnoj boji, jedan plavi naglasak, zeleno za dodavanje,
crveno za brisanje, jantarno za upozorenje. Pokretanje: python3 tools/gen_icons.py  (poziva ga i tools/build.sh).
Pregled: tools/icons/preview.png"""
import base64, math, os, sys
import cairo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tools', 'icons')
SIZES = (16, 24, 32, 64, 128, 256)

def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

PALETTES = {
    'light': dict(INK='#475569', ACC='#2563EB', ACL='#DBEAFE', GRN='#16A34A', RED='#DC2626', AMB='#F59E0B',
                  PAP='#F8FAFC', LGT='#E2E8F0', WHT='#FFFFFF', MUT='#94A3B8', DRK='#1E293B', GRL='#BBF7D0',
                  REL='#FEE2E2', ONC='#FFFFFF', BRN='#B45309'),
    'dark': dict(INK='#CBD5E1', ACC='#60A5FA', ACL='#1E3A8A', GRN='#4ADE80', RED='#F87171', AMB='#FBBF24',
                 PAP='#1E293B', LGT='#334155', WHT='#0F172A', MUT='#64748B', DRK='#020617', GRL='#14532D',
                 REL='#7F1D1D', ONC='#F8FAFC', BRN='#FCD34D'),
}

def use_palette(name):
    """postavlja boje (globalne varijable) za svijetlu ili tamnu temu; crtezi ih citaju pri crtanju"""
    g = globals()
    for k, v in PALETTES[name].items():
        g[k] = rgb(v)

use_palette('light')

def _r(v):
    """boja iz palete po imenu (npr. 'INK'), n-torka kako jest, None = tamna linija"""
    if v is None:
        return INK
    if isinstance(v, str):
        return globals()[v]
    return v

class C:
    """Mali pomocnik nad cairo kontekstom na mrezi 24 x 24."""
    def __init__(self, ctx):
        self.c = ctx

    def stroke_style(self, col=None, w=1.5):
        self.c.set_source_rgb(*_r(col))
        self.c.set_line_width(w)
        self.c.set_line_cap(cairo.LINE_CAP_ROUND)
        self.c.set_line_join(cairo.LINE_JOIN_ROUND)

    def rrect_path(self, x, y, w, h, r=2.0):
        c = self.c
        r = min(r, w / 2, h / 2)
        c.new_sub_path()
        c.arc(x + w - r, y + r, r, -math.pi / 2, 0)
        c.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
        c.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
        c.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
        c.close_path()

    def box(self, x, y, w, h, r=2.0, fill='PAP', line='INK', lw=1.5):
        fill = _r(fill) if fill is not None else None
        line = _r(line) if line is not None else None
        self.rrect_path(x, y, w, h, r)
        if fill is not None:
            self.c.set_source_rgb(*fill)
            self.c.fill_preserve()
        if line is not None:
            self.stroke_style(line, lw)
            self.c.stroke()
        else:
            self.c.new_path()

    def line(self, x1, y1, x2, y2, col=None, lw=1.5):
        self.stroke_style(col, lw)
        self.c.move_to(x1, y1)
        self.c.line_to(x2, y2)
        self.c.stroke()

    def poly(self, pts, col=None, lw=1.5, close=False, fill=None):
        c = self.c
        fill = _r(fill) if fill is not None else None
        c.move_to(*pts[0])
        for p in pts[1:]:
            c.line_to(*p)
        if close:
            c.close_path()
        if fill is not None:
            c.set_source_rgb(*fill)
            c.fill_preserve()
        if col is not False:
            self.stroke_style(col, lw)
            c.stroke()
        else:
            c.new_path()

    def circle(self, x, y, r, fill=None, line='INK', lw=1.5):
        fill = _r(fill) if fill is not None else None
        line = _r(line) if line is not None else None
        self.c.new_sub_path()
        self.c.arc(x, y, r, 0, 2 * math.pi)
        if fill is not None:
            self.c.set_source_rgb(*fill)
            self.c.fill_preserve()
        if line is not None:
            self.stroke_style(line, lw)
            self.c.stroke()
        else:
            self.c.new_path()

    def arc(self, x, y, r, a1, a2, col=None, lw=1.5):
        self.c.new_sub_path()
        self.c.arc(x, y, r, a1, a2)
        self.stroke_style(col, lw)
        self.c.stroke()

    def text(self, s, x, y, size=8, col=None, bold=True):
        col = _r(col)
        c = self.c
        c.select_font_face('DejaVu Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
        c.set_font_size(size)
        ext = c.text_extents(s)
        c.set_source_rgb(*col)
        c.move_to(x - ext.x_bearing - ext.width / 2, y)
        c.show_text(s)

    def page(self, x=4.5, y=2.5, w=15, h=19, fold=5, fill=None):
        """list papira s presavijenim kutom"""
        c = self.c
        fill = _r(fill) if fill is not None else PAP
        c.move_to(x, y + 1.5)
        c.arc(x + 1.5, y + 1.5, 1.5, math.pi, 1.5 * math.pi)
        c.line_to(x + w - fold, y)
        c.line_to(x + w, y + fold)
        c.line_to(x + w, y + h - 1.5)
        c.arc(x + w - 1.5, y + h - 1.5, 1.5, 0, 0.5 * math.pi)
        c.line_to(x + 1.5, y + h)
        c.arc(x + 1.5, y + h - 1.5, 1.5, 0.5 * math.pi, math.pi)
        c.close_path()
        c.set_source_rgb(*fill)
        c.fill_preserve()
        self.stroke_style(None, 1.5)
        c.stroke()
        self.poly([(x + w - fold, y), (x + w - fold, y + fold), (x + w, y + fold)], None, 1.3)

    def arrow(self, x1, y1, x2, y2, col=None, lw=1.6, head=3.2):
        self.line(x1, y1, x2, y2, col, lw)
        a = math.atan2(y2 - y1, x2 - x1)
        for d in (2.5, -2.5):
            ax = x2 - head * math.cos(a + d * 0.22)
            ay = y2 - head * math.sin(a + d * 0.22)
            self.line(x2, y2, ax, ay, col, lw)

ICONS = {}

def icon(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco

# ---------------------------------------------------------------- objekti baze
@icon('table')
def _(g):
    g.box(3, 4, 18, 16, 2, fill=PAP)
    g.c.rectangle(3.8, 4.8, 16.4, 4.2); g.c.set_source_rgb(*ACL); g.c.fill()
    g.line(3, 9, 21, 9); g.line(9, 4, 9, 20); g.line(15, 4, 15, 20); g.line(3, 14.5, 21, 14.5, lw=1.2)

@icon('form')
def _(g):
    g.box(3, 3, 18, 18, 2.5)
    g.c.rectangle(3.8, 3.8, 16.4, 3.4); g.c.set_source_rgb(*ACL); g.c.fill()
    g.line(3, 7.2, 21, 7.2)
    g.box(6, 10, 12, 3, 1, fill=WHT, lw=1.2)
    g.box(6, 15, 6, 3.4, 1.2, fill=ACC, line=ACC)

@icon('query')
def _(g):
    g.box(3, 4, 12, 11, 1.8, fill=PAP, lw=1.3)
    g.line(3, 8, 15, 8, lw=1.2); g.line(9, 4, 9, 15, lw=1.2)
    g.circle(14.5, 14, 4.8, fill=WHT, line=ACC, lw=1.7)
    g.line(18, 17.6, 21.5, 21, ACC, 2)

@icon('report')
def _(g):
    g.page()
    g.c.rectangle(7, 14, 2.4, 4); g.c.set_source_rgb(*ACC); g.c.fill()
    g.c.rectangle(10.8, 11.5, 2.4, 6.5); g.c.set_source_rgb(*ACC); g.c.fill()
    g.c.rectangle(14.6, 9.2, 2.4, 8.8); g.c.set_source_rgb(*ACC); g.c.fill()
    g.line(7, 7.5, 12, 7.5, lw=1.2)

@icon('letter')
def _(g):
    g.box(2.5, 5.5, 19, 13, 2)
    g.poly([(3, 6.5), (12, 13.5), (21, 6.5)], ACC, 1.6)

@icon('module')
def _(g):
    g.poly([(9, 6.5), (3.5, 12), (9, 17.5)], ACC, 2)
    g.poly([(15, 6.5), (20.5, 12), (15, 17.5)], ACC, 2)
    g.line(13.4, 5.5, 10.6, 18.5, INK, 1.6)

@icon('macro')
def _(g):
    g.poly([(13.5, 2.5), (5.5, 13.5), (11.5, 13.5), (10, 21.5), (18.5, 10), (12.5, 10)], INK, 1.4, close=True, fill=AMB)

@icon('program')
def _(g):
    g.box(2.5, 4, 19, 16, 2.5, fill=DRK, line=INK)
    g.poly([(6, 9), (9.5, 12), (6, 15)], ACC, 1.8)
    g.line(11.5, 15.5, 17, 15.5, ACC, 1.8)

@icon('database')
def _(g):
    c = g.c
    g.line(4.5, 6, 4.5, 18, INK, 1.5); g.line(19.5, 6, 19.5, 18, INK, 1.5)
    for y in (6, 11, 16):
        c.save(); c.translate(12, y); c.scale(7.5, 2.8)
        c.new_sub_path(); c.arc(0, 0, 1, 0, math.pi if y != 6 else 2 * math.pi); c.restore()
        g.stroke_style(INK, 1.5); c.stroke()
    c.save(); c.translate(12, 6); c.scale(7.5, 2.8); c.new_sub_path(); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()
    c.set_source_rgb(*ACL); c.fill_preserve(); g.stroke_style(INK, 1.5); c.stroke()
    c.save(); c.translate(12, 18.2); c.scale(7.5, 2.8); c.new_sub_path(); c.arc(0, 0, 1, 0, math.pi); c.restore()
    g.stroke_style(INK, 1.5); c.stroke()

@icon('app')
def _(g):
    g.box(2, 2, 20, 20, 5, fill=ACC, line=None)
    g.c.rectangle(6, 7, 12, 2.5); g.c.set_source_rgb(*ONC); g.c.fill()
    g.c.rectangle(6, 11.3, 12, 2.5); g.c.set_source_rgb(*ONC); g.c.fill()
    g.c.rectangle(6, 15.6, 7, 2.5); g.c.set_source_rgb(*ACL); g.c.fill()

@icon('home')
def _(g):
    g.poly([(3, 12), (12, 3.5), (21, 12)], INK, 1.7)
    g.poly([(5.5, 10.5), (5.5, 20.5), (18.5, 20.5), (18.5, 10.5)], INK, 1.5, fill=PAP)
    g.box(10, 14, 4, 6.5, 0.8, fill=ACL, lw=1.3)

# ---------------------------------------------------------------- radnje
@icon('new')
def _(g):
    g.page(4, 2.5, 14, 19, 5)
    g.circle(17.5, 17.5, 5, fill=GRN, line=ONC, lw=1.2)
    g.line(17.5, 15, 17.5, 20, ONC, 1.8); g.line(15, 17.5, 20, 17.5, ONC, 1.8)

@icon('open')
def _(g):
    g.poly([(2.5, 7), (2.5, 19), (18.5, 19), (21.5, 11), (7, 11), (4.5, 19)], INK, 1.5, fill=ACL)
    g.poly([(2.5, 7), (2.5, 5), (8.5, 5), (10.5, 7), (17.5, 7), (17.5, 11)], INK, 1.5)

@icon('save')
def _(g):
    g.poly([(4, 3.5), (17, 3.5), (20.5, 7), (20.5, 20.5), (4, 20.5)], INK, 1.5, close=True, fill=PAP)
    g.box(7, 3.8, 8, 5, 0.8, fill=ACL, lw=1.3)
    g.box(6.5, 13, 11, 7.5, 1, fill=WHT, lw=1.3)
    g.line(9, 15.8, 15, 15.8, lw=1.1); g.line(9, 18.2, 13, 18.2, lw=1.1)

@icon('delete')
def _(g):
    g.line(4, 6.5, 20, 6.5, RED, 1.7)
    g.poly([(9, 6.5), (9, 4), (15, 4), (15, 6.5)], RED, 1.6)
    g.poly([(6, 6.5), (7, 20.5), (17, 20.5), (18, 6.5)], RED, 1.6, fill=REL)
    g.line(10.2, 10, 10.2, 17, RED, 1.3); g.line(13.8, 10, 13.8, 17, RED, 1.3)

@icon('duplicate')
def _(g):
    g.box(8.5, 8.5, 12, 12, 2, fill=ACL)
    g.box(3.5, 3.5, 12, 12, 2, fill=PAP)

@icon('undo')
def _(g):
    c = g.c
    c.move_to(9.5, 8.5); c.line_to(15.5, 8.5)
    c.arc(15.5, 13.5, 5, -math.pi / 2, math.pi / 2)
    c.line_to(8, 18.5)
    g.stroke_style(INK, 1.8); c.stroke()
    g.poly([(10.5, 4), (5, 8.5), (10.5, 13)], ACC, 2.0)

@icon('redo')
def _(g):
    c = g.c
    c.move_to(14.5, 8.5); c.line_to(8.5, 8.5)
    c.arc_negative(8.5, 13.5, 5, -math.pi / 2, math.pi / 2)
    c.line_to(16, 18.5)
    g.stroke_style(INK, 1.8); c.stroke()
    g.poly([(13.5, 4), (19, 8.5), (13.5, 13)], ACC, 2.0)

@icon('run')
def _(g):
    g.poly([(7, 4), (19.5, 12), (7, 20)], GRN, 1.4, close=True, fill=GRN)

@icon('preview')
def _(g):
    c = g.c
    c.move_to(2, 12); c.curve_to(6, 5.5, 18, 5.5, 22, 12); c.curve_to(18, 18.5, 6, 18.5, 2, 12)
    c.set_source_rgb(*PAP); c.fill_preserve(); g.stroke_style(INK, 1.5); c.stroke()
    g.circle(12, 12, 3.6, fill=ACC, line=None); g.circle(13.1, 10.9, 1.1, fill=WHT, line=None)

@icon('design')
def _(g):
    g.poly([(4, 20), (4.8, 15.5), (16.5, 3.8), (20.2, 7.5), (8.5, 19.2)], INK, 1.5, close=True, fill=ACL)
    g.line(14.5, 5.8, 18.2, 9.5, INK, 1.4)
    g.poly([(4, 20), (4.8, 15.5), (8.5, 19.2)], ACC, 1.2, close=True, fill=ACC)

@icon('refresh')
def _(g):
    g.arc(12, 12, 7, -0.2, math.pi * 1.2, ACC, 1.9)
    g.poly([(17.5, 3.5), (19.5, 9), (14, 9.5)], ACC, 1.9)
    g.arc(12, 12, 7, math.pi * 0.8, math.pi * 2.2, INK, 1.9)

@icon('search')
def _(g):
    g.circle(10.5, 10.5, 6.5, fill=WHT, line=INK, lw=1.8)
    g.line(15.4, 15.4, 21, 21, ACC, 2.4)

@icon('filter')
def _(g):
    g.poly([(3, 4.5), (21, 4.5), (14, 13), (14, 20), (10, 18), (10, 13)], INK, 1.5, close=True, fill=ACL)

@icon('print')
def _(g):
    g.box(7, 3.5, 10, 6, 1, fill=WHT)
    g.box(3, 9, 18, 8, 2.2, fill=LGT)
    g.box(7, 14, 10, 6.5, 1, fill=WHT)
    g.circle(18, 11.6, 0.9, fill=ACC, line=None)
    g.line(9, 16.5, 15, 16.5, lw=1.1); g.line(9, 18.5, 13, 18.5, lw=1.1)

@icon('pdf')
def _(g):
    g.page()
    g.text('PDF', 12, 15.2, 6.2, RED)
    g.line(7.5, 7.5, 12, 7.5, lw=1.2)

@icon('word')
def _(g):
    g.page()
    g.text('W', 12, 16, 9, ACC)

@icon('html')
def _(g):
    g.page()
    g.poly([(10, 11), (7.5, 13.5), (10, 16)], ACC, 1.6)
    g.poly([(14, 11), (16.5, 13.5), (14, 16)], ACC, 1.6)

@icon('export')
def _(g):
    g.poly([(4, 13), (4, 20), (20, 20), (20, 13)], INK, 1.6)
    g.arrow(12, 15, 12, 3.5, ACC, 1.9)

@icon('import')
def _(g):
    g.poly([(4, 13), (4, 20), (20, 20), (20, 13)], INK, 1.6)
    g.arrow(12, 3.5, 12, 15, ACC, 1.9)

@icon('settings')
def _(g):
    c = g.c
    pts = []
    for i in range(16):
        a = i * math.pi / 8
        r = 9.5 if (i % 2 == 0) else 7.6
        for da in (-0.14, 0.14):
            pts.append((12 + r * math.cos(a + da), 12 + r * math.sin(a + da)))
    g.poly(pts, INK, 1.4, close=True, fill=LGT)
    g.circle(12, 12, 3.2, fill=WHT, line=INK, lw=1.5)

@icon('help')
def _(g):
    g.circle(12, 12, 9, fill=ACL, line=ACC, lw=1.6)
    g.text('?', 12, 16.2, 12, ACC)

@icon('close')
def _(g):
    g.line(6, 6, 18, 18, INK, 2); g.line(18, 6, 6, 18, INK, 2)

@icon('add')
def _(g):
    g.circle(12, 12, 9, fill=GRN, line=None)
    g.line(12, 7, 12, 17, ONC, 2.2); g.line(7, 12, 17, 12, ONC, 2.2)

@icon('remove')
def _(g):
    g.circle(12, 12, 9, fill=RED, line=None)
    g.line(7, 12, 17, 12, ONC, 2.2)

@icon('up')
def _(g):
    g.arrow(12, 20, 12, 5, ACC, 2.2, 4)

@icon('down')
def _(g):
    g.arrow(12, 4, 12, 19, ACC, 2.2, 4)

@icon('check')
def _(g):
    g.poly([(4.5, 12.5), (10, 18), (19.5, 6.5)], GRN, 2.6)

@icon('warning')
def _(g):
    g.poly([(12, 3), (22, 20.5), (2, 20.5)], BRN, 1.5, close=True, fill=AMB)
    g.line(12, 9.5, 12, 14.8, INK, 2.0)
    g.circle(12, 17.7, 1.1, fill=INK, line=None)

@icon('info')
def _(g):
    g.circle(12, 12, 9, fill=ACL, line=ACC, lw=1.6)
    g.line(12, 11, 12, 17, ACC, 2.2)
    g.circle(12, 7.6, 1.3, fill=ACC, line=None)

@icon('first')
def _(g):
    g.line(5, 5, 5, 19, INK, 2)
    g.poly([(19, 5), (10, 12), (19, 19)], ACC, 2)

@icon('prev')
def _(g):
    g.poly([(16, 5), (7, 12), (16, 19)], ACC, 2.2)

@icon('next')
def _(g):
    g.poly([(8, 5), (17, 12), (8, 19)], ACC, 2.2)

@icon('last')
def _(g):
    g.line(19, 5, 19, 19, INK, 2)
    g.poly([(5, 5), (14, 12), (5, 19)], ACC, 2)

@icon('expression')
def _(g):
    g.text('fx', 12, 16.5, 11, ACC)

@icon('addfields')
def _(g):
    g.box(3, 4, 14, 16, 2)
    g.line(6, 9, 14, 9, lw=1.3); g.line(6, 13, 14, 13, lw=1.3); g.line(6, 17, 11, 17, lw=1.3)
    g.circle(18, 17, 5, fill=GRN, line=ONC, lw=1.1)
    g.line(18, 14.6, 18, 19.4, ONC, 1.8); g.line(15.6, 17, 20.4, 17, ONC, 1.8)

@icon('pagesetup')
def _(g):
    g.page(5, 2.5, 14, 19, 4)
    g.line(8, 9, 8, 9.01, lw=1)
    g.poly([(2.5, 7), (2.5, 4), (5.5, 4)], ACC, 1.4)
    g.poly([(21.5, 17), (21.5, 20), (18.5, 20)], ACC, 1.4)
    g.line(8, 11, 16, 11, lw=1.2); g.line(8, 14, 16, 14, lw=1.2)

@icon('labels')
def _(g):
    for (x, y) in ((3, 3.5), (13, 3.5), (3, 13), (13, 13)):
        g.box(x, y, 8, 7.5, 1.4, fill=PAP, lw=1.3)
        g.line(x + 1.8, y + 2.6, x + 6, y + 2.6, lw=1.1); g.line(x + 1.8, y + 5, x + 4.6, y + 5, lw=1.1)

@icon('anchors')
def _(g):
    g.box(3, 3, 18, 18, 2.5, fill=PAP, lw=1.3)
    g.box(8.5, 8.5, 7, 7, 1.2, fill=ACC, line=ACC)
    g.line(3.8, 12, 8, 12, ACC, 1.5); g.line(16, 12, 20.2, 12, ACC, 1.5)
    g.line(12, 3.8, 12, 8, ACC, 1.5); g.line(12, 16, 12, 20.2, ACC, 1.5)

# ---------------------------------------------------------------- kontrole (paleta dizajnera)
@icon('c_textbox')
def _(g):
    g.box(2.5, 7, 19, 10, 2, fill=WHT)
    g.line(6.5, 9.7, 6.5, 14.3, ACC, 1.6)
    g.line(9.5, 12, 16, 12, MUT, 1.3)

@icon('c_memo')
def _(g):
    g.box(3, 3.5, 18, 17, 2, fill=WHT)
    for y in (8, 11.5, 15):
        g.line(6.5, y, 17.5, y, MUT, 1.3)
    g.line(6.5, 18, 11, 18, MUT, 1.3)

@icon('c_richtext')
def _(g):
    g.box(2.5, 3.5, 19, 17, 2, fill=WHT)
    g.line(2.5, 8.5, 21.5, 8.5, lw=1.2)
    g.text('B', 6.2, 7.2, 5.5, INK)
    g.text('I', 10.2, 7.2, 5.5, ACC, bold=False)
    g.line(5.5, 12.5, 18.5, 12.5, MUT, 1.3)
    g.line(5.5, 15.5, 18.5, 15.5, RED, 1.5)
    g.line(5.5, 18.2, 12, 18.2, MUT, 1.3)

@icon('c_label')
def _(g):
    g.text('A', 12, 17, 16, INK)
    g.line(5, 20.5, 19, 20.5, ACC, 1.8)

@icon('c_button')
def _(g):
    g.box(2.5, 6.5, 19, 11, 3, fill=ACC, line=ACC)
    g.line(7.5, 12, 16.5, 12, ONC, 1.8)

@icon('c_checkbox')
def _(g):
    g.box(4, 4, 16, 16, 3, fill=WHT)
    g.poly([(7.5, 12.2), (11, 15.7), (16.8, 8.2)], GRN, 2.2)

@icon('c_combobox')
def _(g):
    g.box(2.5, 6.5, 19, 11, 2, fill=WHT)
    g.line(16, 6.5, 16, 17.5, lw=1.2)
    g.poly([(13.8, 10.8), (18.2, 10.8), (16, 14)], ACC, 1.2, close=True, fill=ACC)
    g.line(5.5, 12, 11.5, 12, MUT, 1.3)

@icon('c_listbox')
def _(g):
    g.box(3, 3.5, 18, 17, 2, fill=WHT)
    g.c.rectangle(4, 8.2, 16, 3.8); g.c.set_source_rgb(*ACL); g.c.fill()
    for y in (6, 10.1, 14.2, 18):
        g.line(6.5, y, 17.5, y, MUT if y != 10.1 else ACC, 1.3)

@icon('c_optiongroup')
def _(g):
    g.circle(7, 7.5, 3.2, fill=WHT, lw=1.4); g.circle(7, 7.5, 1.4, fill=ACC, line=None)
    g.circle(7, 16.5, 3.2, fill=WHT, lw=1.4)
    g.line(12.5, 7.5, 20, 7.5, MUT, 1.4); g.line(12.5, 16.5, 20, 16.5, MUT, 1.4)

@icon('c_togglebutton')
def _(g):
    g.box(2.5, 7.5, 19, 9, 4.5, fill=ACC, line=ACC)
    g.circle(17, 12, 3, fill=ONC, line=None)

@icon('c_subform')
def _(g):
    g.box(3, 3, 18, 18, 2, fill=PAP, lw=1.3)
    g.box(7, 10, 12, 9, 1.2, fill=WHT, lw=1.2)
    g.line(7, 13, 19, 13, lw=1.1); g.line(11.5, 10, 11.5, 19, lw=1.1)
    g.line(6, 6.5, 14, 6.5, ACC, 1.5)

@icon('c_tabcontrol')
def _(g):
    g.box(2.5, 9, 19, 12, 2, fill=WHT)
    g.poly([(2.5, 9), (2.5, 5.5), (6, 4.2), (10.5, 4.2), (11.5, 9)], INK, 1.4, fill=ACL)
    g.line(14, 6.8, 19, 6.8, MUT, 1.4)

@icon('c_image')
def _(g):
    g.box(2.5, 4, 19, 16, 2, fill=WHT)
    g.poly([(3.5, 17.5), (9, 11), (13, 15), (15.5, 12.5), (20.5, 17.5)], GRN, 1.5, fill=GRL)
    g.circle(16.5, 8.5, 2, fill=AMB, line=None)

@icon('c_chart')
def _(g):
    g.line(3.5, 3.5, 3.5, 20.5, INK, 1.5); g.line(3.5, 20.5, 21, 20.5, INK, 1.5)
    for x, h, col in ((6.5, 6, ACC), (11, 10, GRN), (15.5, 7.5, AMB)):
        g.c.rectangle(x, 20 - h, 3.2, h); g.c.set_source_rgb(*col); g.c.fill()

@icon('c_barcode')
def _(g):
    x = 3.5
    for w in (1.2, 2.2, 1.2, 1.2, 2.6, 1.2, 2, 1.2, 1.2, 2.2):
        g.c.rectangle(x, 4.5, w, 15); g.c.set_source_rgb(*INK); g.c.fill()
        x += w + 1

@icon('c_calendar')
def _(g):
    g.box(3, 4.5, 18, 16, 2, fill=WHT)
    g.box(3, 4.5, 18, 4.5, 2, fill=ACC, line=ACC)
    for r in (0, 1):
        for c in range(4):
            g.circle(6.8 + c * 3.5, 13 + r * 4, 1.0, fill=INK, line=None)

@icon('c_progress')
def _(g):
    g.box(2.5, 9, 19, 6, 3, fill=WHT)
    g.box(2.5, 9, 11, 6, 3, fill=ACC, line=ACC)

@icon('c_panel')
def _(g):
    g.box(3, 4.5, 18, 15, 2, fill=WHT, line=ACC, lw=1.6)
    g.line(3, 9, 21, 9, ACC, 1.4)
    g.box(6, 12, 5, 4.5, 1, fill=ACL, line=ACC, lw=1.2)
    g.box(13, 12, 5, 4.5, 1, fill=ACL, line=ACC, lw=1.2)

@icon('c_pages')
def _(g):
    g.box(3, 8, 18, 12, 2, fill=WHT, line=ACC, lw=1.6)
    g.box(3, 4.5, 7, 4.5, 1.5, fill=ACC, line=ACC)
    g.box(11, 5.5, 7, 3.5, 1.5, fill=ACL, line=ACC, lw=1.2)

@icon('c_hyperlink')
def _(g):
    g.box(2.5, 9, 10, 6, 3, fill=WHT, line=ACC, lw=1.8)
    g.box(11.5, 9, 10, 6, 3, fill=WHT, line=ACC, lw=1.8)
    g.line(9, 12, 15, 12, ACC, 1.8)

@icon('c_sidemenu')
def _(g):
    g.box(3.5, 3.5, 17, 5, 2, fill=ACL, line=ACC, lw=1.5)
    g.poly([(15.5, 5), (18, 5), (16.75, 7)], ACC, 1.0, fill=ACC)
    for y in (12, 16, 20):
        g.circle(6.5, y, 1.2, fill=ACC, line=None)
        g.line(9.5, y, 18.5, y, INK, 1.4)

@icon('c_rectangle')
def _(g):
    g.box(3.5, 5.5, 17, 13, 2, fill=ACL, line=ACC, lw=1.6)

@icon('c_line')
def _(g):
    g.line(4.5, 19, 19.5, 5, INK, 1.8)
    g.circle(4.5, 19, 1.8, fill=ACC, line=None); g.circle(19.5, 5, 1.8, fill=ACC, line=None)

@icon('c_pagebreak')
def _(g):
    g.box(4, 2.5, 16, 7, 1.5, fill=PAP, lw=1.3)
    g.box(4, 14.5, 16, 7, 1.5, fill=PAP, lw=1.3)
    for x in (3, 8, 13, 18):
        g.line(x, 12, x + 3, 12, ACC, 1.6)

@icon('c_subreport')
def _(g):
    g.page(3.5, 2.5, 17, 19, 4.5)
    g.box(7, 11, 10, 7, 1.2, fill=WHT, lw=1.2)
    g.line(7, 14, 17, 14, lw=1.1)

# ---------------------------------------------------------------- poravnanje (traka dizajnera)
def _bars(g, kind):
    """tri vodoravne/okomite trake poravnate prema rubu"""
    ink = INK
    if kind in ('al', 'ac', 'ar'):
        widths = [14, 8, 11]
        for i, w in enumerate(widths):
            y = 4 + i * 6.5
            x = 4.5 if kind == 'al' else (12 - w / 2 if kind == 'ac' else 19.5 - w)
            g.box(x, y, w, 4, 1, fill=ACL, line=ACC, lw=1.3)
        gx = 3.5 if kind == 'al' else (12 if kind == 'ac' else 20.5)
        g.line(gx, 2.5, gx, 21.5, ink, 1.5)
    else:
        heights = [14, 8, 11]
        for i, h in enumerate(heights):
            x = 4 + i * 6.5
            y = 4.5 if kind == 'at' else (12 - h / 2 if kind == 'am' else 19.5 - h)
            g.box(x, y, 4, h, 1, fill=ACL, line=ACC, lw=1.3)
        gy = 3.5 if kind == 'at' else (12 if kind == 'am' else 20.5)
        g.line(2.5, gy, 21.5, gy, ink, 1.5)

for _n in ('al', 'ac', 'ar', 'at', 'am', 'ab'):
    ICONS['align_' + _n] = (lambda k: (lambda g: _bars(g, k)))(_n)

@icon('same_width')
def _(g):
    g.box(4, 4, 16, 5, 1.2, fill=ACL, line=ACC, lw=1.3)
    g.box(4, 15, 16, 5, 1.2, fill=ACL, line=ACC, lw=1.3)
    g.arrow(4, 12, 20, 12, INK, 1.3, 2.6); g.arrow(20, 12, 4, 12, INK, 1.3, 2.6)

@icon('same_height')
def _(g):
    g.box(4, 4, 5, 16, 1.2, fill=ACL, line=ACC, lw=1.3)
    g.box(15, 4, 5, 16, 1.2, fill=ACL, line=ACC, lw=1.3)
    g.arrow(12, 4, 12, 20, INK, 1.3, 2.6); g.arrow(12, 20, 12, 4, INK, 1.3, 2.6)

@icon('distribute_h')
def _(g):
    for x in (3, 10.5, 18):
        g.box(x, 7, 3, 10, 1, fill=ACL, line=ACC, lw=1.3)
    g.line(2.5, 3.5, 2.5, 20.5, INK, 1.3); g.line(21.5, 3.5, 21.5, 20.5, INK, 1.3)

@icon('distribute_v')
def _(g):
    for y in (3, 10.5, 18):
        g.box(7, y, 10, 3, 1, fill=ACL, line=ACC, lw=1.3)
    g.line(3.5, 2.5, 20.5, 2.5, INK, 1.3); g.line(3.5, 21.5, 20.5, 21.5, INK, 1.3)

@icon('front')
def _(g):
    g.box(3, 3, 12, 12, 2, fill=PAP, lw=1.3)
    g.box(9, 9, 12, 12, 2, fill=ACL, line=ACC, lw=1.6)

@icon('back')
def _(g):
    g.box(9, 9, 12, 12, 2, fill=PAP, lw=1.3)
    g.box(3, 3, 12, 12, 2, fill=ACL, line=ACC, lw=1.6)

@icon('resize')
def _(g):
    g.box(3, 3, 14, 14, 2, fill=PAP, lw=1.3)
    g.arrow(11, 11, 21, 21, ACC, 1.9, 3.8)

# ====================================================================== zaliha ikona za primjere
# Poslovni objekti, vrste polja i radnje. Svaki crtez je na mrezi 24 x 24; grupe su u GROUPS (za indeks i pretrazivanje).
GROUPS = {}

def grp(group, names):
    for n in names.split():
        GROUPS[n] = group

def person(g, x, y, s=1.0, col=None, fill=None):
    """poprsje osobe: glava i ramena"""
    g.circle(x, y - 2.2 * s, 3.1 * s, fill=fill if fill is not None else 'PAP', line=col or 'INK', lw=1.5)
    g.c.move_to(x - 6 * s, y + 7.5 * s)
    g.c.curve_to(x - 6 * s, y + 2.2 * s, x + 6 * s, y + 2.2 * s, x + 6 * s, y + 7.5 * s)
    if fill is not None:
        g.c.set_source_rgb(*_r(fill)); g.c.fill_preserve()
    g.stroke_style(col, 1.5); g.c.stroke()

def cal(g, x=3, y=4, w=18, h=17, head=ACL):
    g.box(x, y, w, h, 2.2, fill='PAP')
    g.c.rectangle(x + 0.8, y + 0.8, w - 1.6, 4.2); g.c.set_source_rgb(*_r(head)); g.c.fill()
    g.line(x, y + 5, x + w, y + 5, None, 1.4)
    g.line(x + 5, y - 1.5, x + 5, y + 2, None, 1.7); g.line(x + w - 5, y - 1.5, x + w - 5, y + 2, None, 1.7)

def coin(g, x, y, r=5, txt='€', col=None, fill=None):
    g.circle(x, y, r, fill=fill if fill is not None else 'AMB', line='BRN', lw=1.3)
    g.text(txt, x, y + r * 0.38, r * 1.25, 'DRK')

def truck(g, x=2.5, y=7, k=1.0):
    g.box(x, y, 11 * k, 8 * k, 1.2, fill='ACL', line='INK', lw=1.4)
    g.poly([(x + 11 * k, y + 2.5 * k), (x + 16 * k, y + 2.5 * k), (x + 19 * k, y + 5.5 * k), (x + 19 * k, y + 8 * k), (x + 11 * k, y + 8 * k)], None, 1.4, close=True, fill='PAP')
    g.circle(x + 4 * k, y + 9 * k, 2, fill='INK', line=None); g.circle(x + 14.5 * k, y + 9 * k, 2, fill='INK', line=None)

def box3d(g, x=12, y=12, k=1.0, top='ACL'):
    pts_top = [(x, y - 8 * k), (x + 8 * k, y - 4 * k), (x, y), (x - 8 * k, y - 4 * k)]
    g.poly(pts_top, None, 1.5, close=True, fill=top)
    g.poly([(x - 8 * k, y - 4 * k), (x, y), (x, y + 9 * k), (x - 8 * k, y + 5 * k)], None, 1.5, close=True, fill='PAP')
    g.poly([(x + 8 * k, y - 4 * k), (x, y), (x, y + 9 * k), (x + 8 * k, y + 5 * k)], None, 1.5, close=True, fill='LGT')

def pin(g, x, y, col='ACC'):
    g.c.move_to(x, y + 8)
    g.c.curve_to(x - 8, y - 1, x - 6, y - 8, x, y - 8)
    g.c.curve_to(x + 6, y - 8, x + 8, y - 1, x, y + 8)
    g.c.set_source_rgb(*_r(col)); g.c.fill_preserve(); g.stroke_style(None, 1.4); g.c.stroke()
    g.circle(x, y - 2.5, 2.4, fill='ONC', line=None)

def chev(g, kind):
    pts = {'down': [(6, 9), (12, 15), (18, 9)], 'up': [(6, 15), (12, 9), (18, 15)],
           'left': [(15, 6), (9, 12), (15, 18)], 'right': [(9, 6), (15, 12), (9, 18)]}[kind]
    g.poly(pts, 'ACC', 2.2)

# ---- ljudi i tvrtke
@icon('customer')
def _(g):
    person(g, 12, 9.5, 1.0, 'INK', 'ACL')
    g.circle(18.3, 17.8, 3.4, fill='GRN', line='ONC', lw=1.1)
    g.poly([(16.8, 17.8), (18, 19), (20, 16.6)], 'ONC', 1.5)

@icon('supplier')
def _(g):
    truck(g, 2.5, 6.5)
    g.line(2.5, 18.5, 21.5, 18.5, 'MUT', 1.2)

@icon('company')
def _(g):
    g.box(5, 3.5, 14, 17, 1.5, fill='PAP')
    for y in (7, 11, 15):
        for x in (8, 13.2):
            g.box(x, y, 2.8, 2.4, 0.4, fill='ACL', lw=1.1)
    g.box(10.2, 17, 3.6, 3.5, 0.5, fill='ACC', line='ACC')

@icon('employee')
def _(g):
    person(g, 12, 9, 1.0, 'INK', 'ACL')
    g.poly([(12, 11.5), (10.6, 14), (12, 19), (13.4, 14)], 'ACC', 1.2, close=True, fill='ACC')

@icon('user')
def _(g):
    person(g, 12, 10, 1.1, 'INK', 'PAP')

@icon('users')
def _(g):
    person(g, 8, 10, 0.85, 'MUT', 'PAP')
    person(g, 15, 9.5, 0.95, 'INK', 'ACL')

@icon('idcard')
def _(g):
    g.box(2.5, 5.5, 19, 13, 2, fill='PAP')
    g.circle(8, 10.5, 2, fill='ACL', line='INK', lw=1.2)
    g.c.move_to(4.8, 16); g.c.curve_to(5, 13, 11, 13, 11.2, 16); g.stroke_style(None, 1.3); g.c.stroke()
    g.line(13.5, 9.5, 19, 9.5, None, 1.3); g.line(13.5, 12.5, 19, 12.5, 'MUT', 1.3); g.line(13.5, 15.5, 17, 15.5, 'MUT', 1.3)

@icon('bankcard')
def _(g):
    g.box(2.5, 5.5, 19, 13, 2.2, fill='ACL')
    g.line(2.5, 9.5, 21.5, 9.5, None, 3.4)
    g.box(5, 13, 5, 3, 0.8, fill='AMB', line='BRN', lw=1.1)
    g.line(13, 15, 19, 15, 'INK', 1.3)
grp('Ljudi i tvrtke', 'customer supplier company employee user users idcard bankcard')

# ---- dokumenti
@icon('invoice')
def _(g):
    g.page()
    g.text('€', 12, 15.6, 9.5, 'ACC')
    g.line(7.5, 7.5, 11.5, 7.5, None, 1.2)

@icon('offer')
def _(g):
    g.page()
    g.line(7.5, 8, 14, 8, None, 1.2); g.line(7.5, 11, 14, 11, 'MUT', 1.2)
    g.poly([(10.5, 19.5), (11.2, 16.8), (17.5, 10.5), (19.2, 12.2), (12.9, 18.8)], 'ACC', 1.2, close=True, fill='ACL')

@icon('order')
def _(g):
    g.page()
    for y in (8.5, 12, 15.5):
        g.line(7.2, y, 8.6, y + 1, 'GRN', 1.5); g.line(8.6, y + 1, 10.5, y - 1.2, 'GRN', 1.5)
        g.line(12, y, 16.5, y, 'MUT', 1.3)

@icon('deliverynote')
def _(g):
    g.page()
    truck(g, 6.5, 10.2, 0.55)

@icon('proforma')
def _(g):
    g.page()
    g.text('P', 12, 16.2, 11, 'AMB')

@icon('receipt')
def _(g):
    g.poly([(5.5, 3), (18.5, 3), (18.5, 21), (16, 19.2), (14, 21), (12, 19.2), (10, 21), (8, 19.2), (5.5, 21)], None, 1.5, close=True, fill='PAP')
    g.line(8, 7.5, 16, 7.5, 'MUT', 1.3); g.line(8, 10.5, 16, 10.5, 'MUT', 1.3); g.line(8, 13.5, 12, 13.5, None, 1.3)
    g.text('€', 14.2, 15.6, 5, 'ACC')

@icon('creditnote')
def _(g):
    g.page()
    g.circle(12, 14, 4, fill='RED', line=None)
    g.line(9.7, 14, 14.3, 14, 'ONC', 2)

@icon('contract')
def _(g):
    g.page()
    g.line(7.5, 7.5, 14, 7.5, None, 1.2); g.line(7.5, 10, 14, 10, 'MUT', 1.2)
    g.c.move_to(7.5, 17); g.c.curve_to(9, 13, 10, 18, 11.5, 15); g.c.curve_to(12.5, 13.5, 13, 17, 14.5, 15.5)
    g.stroke_style('ACC', 1.4); g.c.stroke()
    g.circle(16.3, 16.8, 2.2, fill='AMB', line='BRN', lw=1.1)

@icon('annex')
def _(g):
    g.page()
    g.circle(12, 14.2, 4.2, fill='ACC', line=None)
    g.line(12, 12, 12, 16.4, 'ONC', 1.8); g.line(9.8, 14.2, 14.2, 14.2, 'ONC', 1.8)

@icon('note')
def _(g):
    g.poly([(4, 4), (20, 4), (20, 15), (15, 20), (4, 20)], None, 1.5, close=True, fill='AMB')
    g.poly([(15, 20), (15, 15), (20, 15)], 'BRN', 1.3, close=True, fill='PAP')
    g.line(7, 8.5, 16.5, 8.5, 'DRK', 1.3); g.line(7, 12, 14, 12, 'DRK', 1.3)

@icon('clipboard')
def _(g):
    g.box(5, 4.5, 14, 16.5, 2, fill='PAP')
    g.box(8.5, 2.5, 7, 4, 1.2, fill='ACL', lw=1.3)
    g.line(8, 10.5, 16, 10.5, 'MUT', 1.3); g.line(8, 13.5, 16, 13.5, 'MUT', 1.3); g.line(8, 16.5, 13, 16.5, 'MUT', 1.3)

@icon('inventory')
def _(g):
    g.box(5, 4.5, 14, 16.5, 2, fill='PAP')
    g.box(8.5, 2.5, 7, 4, 1.2, fill='ACL', lw=1.3)
    for y in (10, 13.7, 17.4):
        g.line(7.5, y, 9, y + 1.2, 'GRN', 1.5); g.line(9, y + 1.2, 11, y - 1, 'GRN', 1.5)
        g.line(12.5, y, 16.5, y, 'MUT', 1.3)
grp('Dokumenti', 'invoice offer order deliverynote proforma receipt creditnote contract annex note clipboard inventory')

# ---- roba i skladiste
@icon('article')
def _(g):
    box3d(g, 12, 12.5, 1.1)

@icon('tag')
def _(g):
    g.poly([(3, 12), (12, 3), (21, 3), (21, 12), (12, 21)], None, 1.5, close=True, fill='ACL')
    g.circle(16.5, 7.5, 1.6, fill='PAP', line='INK', lw=1.3)

@icon('pricetag')
def _(g):
    g.poly([(3, 12), (12, 3), (21, 3), (21, 12), (12, 21)], None, 1.5, close=True, fill='AMB')
    g.text('€', 14.2, 14.6, 8, 'DRK')

@icon('category')
def _(g):
    for (x, y) in ((3.5, 3.5), (13.5, 3.5), (3.5, 13.5), (13.5, 13.5)):
        g.box(x, y, 7, 7, 1.6, fill='ACL' if (x, y) == (3.5, 3.5) else 'PAP', lw=1.4)

@icon('warehouse')
def _(g):
    g.poly([(2.5, 10), (12, 3.5), (21.5, 10), (21.5, 20.5), (2.5, 20.5)], None, 1.5, close=True, fill='PAP')
    g.box(6, 12.5, 5, 8, 0.6, fill='ACL', lw=1.2)
    g.box(13, 12.5, 5, 3.5, 0.6, fill='AMB', line='BRN', lw=1.1)
    g.box(13, 16.5, 5, 4, 0.6, fill='AMB', line='BRN', lw=1.1)

@icon('stockin')
def _(g):
    box3d(g, 12, 15.5, 0.8)
    g.arrow(12, 1.8, 12, 8.5, 'GRN', 2.0, 3.4)

@icon('stockout')
def _(g):
    box3d(g, 12, 15.5, 0.8)
    g.arrow(12, 8.5, 12, 1.8, 'RED', 2.0, 3.4)

@icon('cart')
def _(g):
    g.poly([(2.5, 4), (5.5, 4), (8, 15), (18.5, 15), (20.5, 7.5), (6.4, 7.5)], None, 1.5, fill='ACL')
    g.circle(9.5, 19, 1.7, fill='INK', line=None); g.circle(17, 19, 1.7, fill='INK', line=None)

@icon('barcodescan')
def _(g):
    x = 4.5
    for w in (1.2, 2.2, 1.2, 1.2, 2.4, 1.2, 1.8, 1.2):
        g.c.rectangle(x, 6.5, w, 11); g.c.set_source_rgb(*INK); g.c.fill(); x += w + 1.1
    g.line(2.5, 12, 21.5, 12, 'RED', 1.4)
grp('Roba i skladište', 'article tag pricetag category warehouse stockin stockout cart barcodescan')

# ---- novac
@icon('cashbook')
def _(g):
    g.box(3, 11, 18, 9, 2, fill='PAP')
    g.box(6, 3.5, 12, 7, 1.5, fill='ACL', lw=1.4)
    g.text('€', 12, 9.4, 6, 'ACC')
    g.line(6, 15, 18, 15, 'MUT', 1.3)

@icon('cash')
def _(g):
    g.box(2.5, 6, 19, 12, 1.8, fill='GRL', line='GRN')
    g.circle(12, 12, 3.4, fill='PAP', line='GRN', lw=1.4)
    g.text('€', 12, 13.8, 5, 'GRN')

@icon('coins')
def _(g):
    coin(g, 9, 15.5, 5.5)
    coin(g, 15, 9, 5.5)

@icon('payment')
def _(g):
    g.box(2.5, 5.5, 19, 13, 2.2, fill='PAP')
    g.line(2.5, 9.5, 21.5, 9.5, 'INK', 3.2)
    g.circle(17.5, 15.5, 3.8, fill='GRN', line='PAP', lw=1.2)
    g.poly([(15.8, 15.5), (17.1, 16.8), (19.4, 14.2)], 'ONC', 1.6)

@icon('bank')
def _(g):
    g.poly([(2.5, 9), (12, 3), (21.5, 9)], None, 1.5, close=True, fill='ACL')
    for x in (5, 9.5, 14, 18.5 - 1.5):
        g.c.rectangle(x, 10.5, 2, 7); g.c.set_source_rgb(*INK); g.c.fill()
    g.line(3, 19.5, 21, 19.5, None, 2)

@icon('wallet')
def _(g):
    g.box(3, 6, 18, 14, 2.5, fill='ACL')
    g.poly([(3, 9.5), (3, 6), (17, 4.5), (17, 6)], None, 1.4)
    g.box(14.5, 11.5, 6.5, 4.4, 1.5, fill='PAP', lw=1.3)
    g.circle(17.2, 13.7, 0.9, fill='ACC', line=None)

@icon('percent')
def _(g):
    g.circle(12, 12, 9, fill='ACL', line='ACC', lw=1.5)
    g.text('%', 12, 16.2, 12, 'ACC')

@icon('euro')
def _(g):
    g.circle(12, 12, 9, fill='AMB', line='BRN', lw=1.5)
    g.text('€', 12, 16.2, 13, 'DRK')

@icon('cost')
def _(g):
    coin(g, 9.5, 11, 6.2)
    g.circle(17.5, 17.5, 4.2, fill='RED', line='PAP', lw=1.1)
    g.line(15.3, 17.5, 19.7, 17.5, 'ONC', 1.9)

@icon('advance')
def _(g):
    coin(g, 8.5, 12, 6)
    g.arrow(15, 12, 22, 12, 'ACC', 2.0, 3.4)
grp('Novac', 'cashbook cash coins payment bank wallet percent euro cost advance')

# ---- putovanje i vrijeme
@icon('suitcase')
def _(g):
    g.box(3, 8, 18, 12, 2.2, fill='ACL')
    g.poly([(8.5, 8), (8.5, 5), (15.5, 5), (15.5, 8)], None, 1.5)
    g.line(3, 13, 21, 13, None, 1.3)
    g.box(10.5, 12, 3, 3, 0.6, fill='AMB', line='BRN', lw=1.1)

@icon('car')
def _(g):
    g.poly([(2.5, 15), (3.5, 10.5), (7, 7), (16, 7), (19.5, 10.5), (21.5, 11.5), (21.5, 17), (2.5, 17)], None, 1.5, close=True, fill='ACL')
    g.line(8, 7.2, 7.4, 11, None, 1.2); g.line(15.6, 7.2, 16.5, 11, None, 1.2); g.line(7.4, 11, 16.5, 11, None, 1.2)
    g.circle(7, 17.5, 2.3, fill='INK', line='PAP', lw=1); g.circle(17, 17.5, 2.3, fill='INK', line='PAP', lw=1)

@icon('route')
def _(g):
    g.circle(6, 18, 2.2, fill='ACC', line=None)
    pin(g, 17, 8)
    g.c.move_to(8, 17); g.c.curve_to(14, 20, 5, 12, 12, 11)
    g.stroke_style('MUT', 1.4); g.c.set_dash([2, 2.2]); g.c.stroke(); g.c.set_dash([])

@icon('fuel')
def _(g):
    g.box(4.5, 4, 9, 16.5, 1.5, fill='ACL')
    g.box(6.2, 6.5, 5.6, 4, 0.6, fill='PAP', lw=1.1)
    g.poly([(13.5, 8), (17, 8), (18.5, 10.5), (18.5, 17)], None, 1.5)
    g.circle(18.5, 18.2, 1.5, fill='AMB', line='BRN', lw=1)

@icon('calendar')
def _(g):
    cal(g)
    for (x, y) in ((6.5, 12), (10.5, 12), (14.5, 12), (6.5, 16), (10.5, 16)):
        g.c.rectangle(x, y, 2.4, 2.2); g.c.set_source_rgb(*_r('MUT')); g.c.fill()

@icon('deadline')
def _(g):
    cal(g, head='AMB')
    g.line(12, 11.2, 12, 15.6, 'RED', 2); g.circle(12, 18.1, 1, fill='RED', line=None)

@icon('clock')
def _(g):
    g.circle(12, 12, 9, fill='PAP', line='INK', lw=1.6)
    g.line(12, 6.5, 12, 12, 'ACC', 2); g.line(12, 12, 16.2, 14.4, 'ACC', 2)

@icon('overdue')
def _(g):
    g.circle(12, 12, 9, fill='REL', line='RED', lw=1.6)
    g.line(12, 6.5, 12, 12, 'RED', 2); g.line(12, 12, 16.2, 14.4, 'RED', 2)

@icon('history')
def _(g):
    g.arc(12.5, 12, 8, -2.4, 3.6, 'INK', 1.7)
    g.poly([(3, 6.5), (5.2, 10.2), (8.8, 7.4)], 'ACC', 1.9)
    g.line(12.5, 7.5, 12.5, 12, 'ACC', 1.8); g.line(12.5, 12, 15.5, 14, 'ACC', 1.8)

@icon('flag')
def _(g):
    g.line(6, 3.5, 6, 21, 'INK', 1.8)
    g.poly([(6.5, 4.5), (19, 4.5), (16, 8.5), (19, 12.5), (6.5, 12.5)], None, 1.4, close=True, fill='ACC')

@icon('milestone')
def _(g):
    g.line(5, 21, 5, 3.5, 'INK', 1.8)
    g.poly([(5.5, 4), (19.5, 8.5), (5.5, 13)], None, 1.4, close=True, fill='GRN')
grp('Vrijeme i putovanje', 'suitcase car route fuel calendar deadline clock overdue history flag milestone')

# ---- komunikacija i podaci
@icon('phone')
def _(g):
    g.c.move_to(6, 3.5); g.c.curve_to(3.5, 4.5, 3, 7, 5, 11.5); g.c.curve_to(7.5, 17, 12, 20.5, 17, 21)
    g.c.curve_to(20, 21, 21, 18.5, 20, 17); g.c.line_to(16.5, 14.8); g.c.curve_to(15, 14.2, 14, 15.4, 13.2, 15.6)
    g.c.curve_to(11.5, 14.8, 9.4, 12.6, 8.6, 10.8); g.c.curve_to(8.8, 10, 10, 9, 9.4, 7.5); g.c.line_to(7.4, 4); g.c.close_path()
    g.c.set_source_rgb(*_r('ACL')); g.c.fill_preserve(); g.stroke_style(None, 1.5); g.c.stroke()

@icon('at')
def _(g):
    g.circle(12, 12, 3.2, fill='ACL', line='ACC', lw=1.6)
    g.arc(12, 12, 8.4, 0.6, 5.3, 'INK', 1.7)
    g.line(15.2, 9, 15.2, 13.6, 'ACC', 1.7)
    g.arc(18.4, 13.5, 3.2, math.pi * 0.9, math.pi * 2, 'ACC', 1.5)

@icon('location')
def _(g):
    pin(g, 12, 11.5)
    g.c.save(); g.c.translate(12, 20.4); g.c.scale(5, 1.5); g.c.new_sub_path(); g.c.arc(0, 0, 1, 0, 2 * math.pi); g.c.restore()
    g.c.set_source_rgb(*_r('MUT')); g.c.fill()

@icon('globe')
def _(g):
    g.circle(12, 12, 9, fill='PAP', line='INK', lw=1.5)
    g.c.save(); g.c.translate(12, 12); g.c.scale(3.8, 9); g.c.new_sub_path(); g.c.arc(0, 0, 1, 0, 2 * math.pi); g.c.restore()
    g.stroke_style('ACC', 1.3); g.c.stroke()
    g.line(3, 12, 21, 12, 'ACC', 1.3); g.line(4.8, 7.5, 19.2, 7.5, 'MUT', 1.1); g.line(4.8, 16.5, 19.2, 16.5, 'MUT', 1.1)

@icon('send')
def _(g):
    g.poly([(3, 11), (21, 3), (14, 21), (11, 14)], None, 1.5, close=True, fill='ACL')
    g.line(11, 14, 21, 3, 'ACC', 1.4)

@icon('attach')
def _(g):
    g.c.move_to(16.5, 8); g.c.line_to(9, 15.5)
    g.c.curve_to(7.5, 17, 5.5, 15, 7, 13.4); g.c.line_to(14.6, 5.8)
    g.c.curve_to(17.2, 3.2, 20.8, 6.8, 18.2, 9.4); g.c.line_to(10.4, 17.2)
    g.c.curve_to(7.4, 20, 3.4, 16, 6.2, 13)
    g.stroke_style('INK', 1.6); g.c.stroke()

@icon('link')
def _(g):
    g.box(2.5, 9, 10, 6, 3, fill='PAP', line='ACC', lw=1.8)
    g.box(11.5, 9, 10, 6, 3, fill='PAP', line='ACC', lw=1.8)
    g.line(9, 12, 15, 12, 'ACC', 1.8)

@icon('unlink')
def _(g):
    g.box(2, 9, 8, 6, 3, fill='PAP', line='MUT', lw=1.6)
    g.box(14, 9, 8, 6, 3, fill='PAP', line='MUT', lw=1.6)
    g.line(10.5, 7, 9.5, 4.5, 'RED', 1.6); g.line(13.5, 17, 14.5, 19.5, 'RED', 1.6)

@icon('qr')
def _(g):
    for (x, y) in ((3.5, 3.5), (14, 3.5), (3.5, 14)):
        g.box(x, y, 6.5, 6.5, 1, fill='PAP', lw=1.5); g.c.rectangle(x + 2, y + 2, 2.5, 2.5); g.c.set_source_rgb(*INK); g.c.fill()
    for (x, y) in ((14, 14), (17.5, 14), (14, 17.5), (17.5, 17.5), (20, 20), (15.5, 20)):
        g.c.rectangle(x, y, 2.2, 2.2); g.c.set_source_rgb(*INK); g.c.fill()
grp('Podaci i komunikacija', 'phone at location globe send attach link unlink qr')

# ---- vrste polja
def ftext(g, s, col='ACC', size=9):
    g.box(2.5, 6, 19, 12, 2.2, fill='PAP')
    g.text(s, 12, 14.8, size, col)

@icon('f_text')
def _(g):
    ftext(g, 'Aa')

@icon('f_number')
def _(g):
    ftext(g, '123', 'ACC', 7.5)

@icon('f_date')
def _(g):
    cal(g, 3.5, 4.5, 17, 16)
    g.c.rectangle(7.5, 12, 3, 3); g.c.set_source_rgb(*_r('ACC')); g.c.fill()

@icon('f_currency')
def _(g):
    coin(g, 12, 12, 8.5)

@icon('f_percent')
def _(g):
    ftext(g, '%', 'ACC', 11)

@icon('f_bool')
def _(g):
    g.box(4, 4, 16, 16, 3, fill='WHT')
    g.poly([(7.5, 12.2), (11, 15.7), (16.8, 8.2)], 'GRN', 2.3)

@icon('f_memo')
def _(g):
    g.box(3.5, 4, 17, 16, 2.2, fill='PAP')
    for y in (8, 11.2, 14.4):
        g.line(6.5, y, 17.5, y, 'MUT', 1.3)
    g.line(6.5, 17.4, 11, 17.4, 'MUT', 1.3)

@icon('f_image')
def _(g):
    g.box(2.5, 4, 19, 16, 2.2, fill='WHT')
    g.poly([(3.5, 17.5), (9, 11), (13, 15), (15.5, 12.5), (20.5, 17.5)], 'GRN', 1.5, fill='GRL')
    g.circle(16.5, 8.5, 2, fill='AMB', line=None)

@icon('f_link')
def _(g):
    g.box(2, 9, 8.5, 6, 3, fill='PAP', line='ACC', lw=1.7)
    g.box(13.5, 9, 8.5, 6, 3, fill='PAP', line='ACC', lw=1.7)
    g.line(10, 12, 14, 12, 'ACC', 1.7)

@icon('f_id')
def _(g):
    ftext(g, '#', 'ACC', 12)

@icon('f_quantity')
def _(g):
    box3d(g, 8.5, 12, 0.7)
    g.text('×', 18, 15.5, 9, 'ACC')

@icon('f_unit')
def _(g):
    g.box(2.5, 8, 19, 8, 1.4, fill='AMB', line='BRN', lw=1.3)
    for x in (6, 9.5, 13, 16.5):
        g.line(x, 8.5, x, 11.5, 'DRK', 1.2)

@icon('f_code')
def _(g):
    g.box(2.5, 5, 19, 14, 2.2, fill='DRK')
    g.poly([(7, 9.5), (4.8, 12), (7, 14.5)], 'ACC', 1.7); g.poly([(17, 9.5), (19.2, 12), (17, 14.5)], 'ACC', 1.7)
    g.line(13, 8.5, 11, 15.5, 'ONC', 1.5)

@icon('f_status')
def _(g):
    g.circle(12, 12, 8.5, fill='GRL', line='GRN', lw=1.5)
    g.circle(12, 12, 3.4, fill='GRN', line=None)

@icon('f_color')
def _(g):
    g.c.move_to(12, 3); g.c.curve_to(21, 3, 22, 11, 17, 13.5); g.c.curve_to(14, 15, 15, 20, 11, 20.5)
    g.c.curve_to(5, 21, 2, 15, 2.5, 11); g.c.curve_to(3, 6, 7, 3, 12, 3)
    g.c.set_source_rgb(*_r('PAP')); g.c.fill_preserve(); g.stroke_style(None, 1.5); g.c.stroke()
    for (x, y, col) in ((7.5, 9, 'RED'), (11.5, 6.5, 'AMB'), (15.5, 8.5, 'GRN'), (7, 14, 'ACC')):
        g.circle(x, y, 1.6, fill=col, line=None)

@icon('f_phone')
def _(g):
    ftext(g, '☎', 'ACC', 11)

@icon('f_email')
def _(g):
    ftext(g, '@', 'ACC', 11)

@icon('f_url')
def _(g):
    ftext(g, 'www', 'ACC', 6.5)
grp('Vrste polja', 'f_text f_number f_date f_currency f_percent f_bool f_memo f_image f_link f_id f_quantity f_unit f_code f_status f_color f_phone f_email f_url')

# ---- izvjesca i analitika
@icon('piechart')
def _(g):
    g.circle(12, 12, 8.5, fill='ACL', line='INK', lw=1.5)
    g.c.move_to(12, 12); g.c.line_to(12, 3.5); g.c.arc(12, 12, 8.5, -math.pi / 2, math.pi * 0.35); g.c.close_path()
    g.c.set_source_rgb(*_r('ACC')); g.c.fill_preserve(); g.stroke_style(None, 1.4); g.c.stroke()

@icon('linechart')
def _(g):
    g.line(3.5, 3.5, 3.5, 20.5, None, 1.5); g.line(3.5, 20.5, 21, 20.5, None, 1.5)
    g.poly([(5.5, 16), (10, 11.5), (13.5, 14), (19.5, 6.5)], 'ACC', 2.0)
    for (x, y) in ((10, 11.5), (13.5, 14), (19.5, 6.5)):
        g.circle(x, y, 1.4, fill='PAP', line='ACC', lw=1.3)

@icon('trophy')
def _(g):
    g.poly([(7, 4), (17, 4), (16, 11), (12, 13.5), (8, 11)], None, 1.5, close=True, fill='AMB')
    g.arc(6.5, 7.5, 2.4, math.pi / 2, math.pi * 1.5, 'BRN', 1.4); g.arc(17.5, 7.5, 2.4, -math.pi / 2, math.pi / 2, 'BRN', 1.4)
    g.line(12, 13.5, 12, 17, 'BRN', 1.8); g.line(8.5, 20, 15.5, 20, 'BRN', 2.2); g.line(12, 17, 12, 20, 'BRN', 1.8)

@icon('star')
def _(g):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 9 if i % 2 == 0 else 4
        pts.append((12 + r * math.cos(a), 12.5 + r * math.sin(a)))
    g.poly(pts, 'BRN', 1.4, close=True, fill='AMB')

@icon('sigma')
def _(g):
    g.text('Σ', 12, 18, 17, 'ACC')

@icon('calculator')
def _(g):
    g.box(4.5, 2.5, 15, 19, 2.2, fill='PAP')
    g.box(7, 5, 10, 4, 0.8, fill='ACL', lw=1.2)
    for y in (12, 15, 18.2):
        for x in (7.5, 11.2, 14.9):
            g.c.rectangle(x, y, 2, 1.8); g.c.set_source_rgb(*_r('ACC' if (x, y) == (14.9, 18.2) else 'MUT')); g.c.fill()

@icon('count')
def _(g):
    g.text('#', 12, 17, 15, 'ACC')

@icon('sortasc')
def _(g):
    g.line(5, 7, 12, 7, 'INK', 1.7); g.line(5, 12, 15, 12, 'INK', 1.7); g.line(5, 17, 18, 17, 'INK', 1.7)
    g.arrow(20, 17, 20, 5, 'ACC', 1.8, 3.2)

@icon('sortdesc')
def _(g):
    g.line(5, 7, 18, 7, 'INK', 1.7); g.line(5, 12, 15, 12, 'INK', 1.7); g.line(5, 17, 12, 17, 'INK', 1.7)
    g.arrow(20, 5, 20, 17, 'ACC', 1.8, 3.2)

@icon('group')
def _(g):
    g.box(3, 3.5, 14, 6, 1.5, fill='ACL', lw=1.4)
    g.box(7, 9.5, 14, 6, 1.5, fill='PAP', lw=1.4)
    g.box(3, 15.5, 14, 5.5, 1.5, fill='PAP', lw=1.4)

@icon('dashboard')
def _(g):
    g.box(3, 3, 8.5, 10, 1.8, fill='ACL', lw=1.4); g.box(13, 3, 8, 6, 1.8, fill='PAP', lw=1.4)
    g.box(3, 15, 8.5, 6, 1.8, fill='PAP', lw=1.4); g.box(13, 11, 8, 10, 1.8, fill='ACL', lw=1.4)

@icon('list')
def _(g):
    for y in (6.5, 12, 17.5):
        g.circle(5, y, 1.3, fill='ACC', line=None); g.line(9, y, 20, y, 'INK', 1.7)

@icon('grid')
def _(g):
    for (x, y) in ((4, 4), (13.5, 4), (4, 13.5), (13.5, 13.5)):
        g.box(x, y, 6.5, 6.5, 1.2, fill='PAP', lw=1.4)
grp('Izvješća i analitika', 'piechart linechart trophy star sigma calculator count sortasc sortdesc group dashboard list grid')

# ---- radnje i sustav
@icon('lock')
def _(g):
    g.arc(12, 9, 4, math.pi, 2 * math.pi, 'INK', 1.7); g.line(8, 9, 8, 11, 'INK', 1.7); g.line(16, 9, 16, 11, 'INK', 1.7)
    g.box(5, 10.5, 14, 10, 2, fill='AMB', line='BRN', lw=1.4)
    g.circle(12, 15.3, 1.4, fill='DRK', line=None)

@icon('unlock')
def _(g):
    g.arc(15.5, 9, 4, math.pi, 2 * math.pi, 'INK', 1.7); g.line(11.5, 9, 11.5, 6.8, 'INK', 1.7); g.line(19.5, 9, 19.5, 10.5, 'INK', 1.7)
    g.box(5, 10.5, 14, 10, 2, fill='ACL', line='ACC', lw=1.4)
    g.circle(12, 15.3, 1.4, fill='ACC', line=None)

@icon('key')
def _(g):
    g.circle(8, 8, 4.5, fill='AMB', line='BRN', lw=1.5)
    g.circle(8, 8, 1.4, fill='PAP', line=None)
    g.line(11.5, 11.5, 20.5, 20.5, 'BRN', 1.8); g.line(17, 17, 19.5, 14.5, 'BRN', 1.7); g.line(14.5, 14.5, 16.5, 12.5, 'BRN', 1.7)

@icon('shield')
def _(g):
    g.poly([(12, 3), (20, 6), (20, 12), (12, 21), (4, 12), (4, 6)], None, 1.5, close=True, fill='ACL')
    g.poly([(8.5, 12), (11, 14.5), (16, 8.5)], 'GRN', 2.0)

@icon('bell')
def _(g):
    g.c.move_to(5.5, 17); g.c.curve_to(7.5, 15, 7, 12, 7, 10); g.c.curve_to(7, 6, 9.5, 4.5, 12, 4.5)
    g.c.curve_to(14.5, 4.5, 17, 6, 17, 10); g.c.curve_to(17, 12, 16.5, 15, 18.5, 17); g.c.close_path()
    g.c.set_source_rgb(*_r('AMB')); g.c.fill_preserve(); g.stroke_style('BRN', 1.5); g.c.stroke()
    g.arc(12, 19, 2, 0, math.pi, 'BRN', 1.5)

@icon('wrench')
def _(g):
    g.line(5, 19, 13, 11, 'INK', 3.2)
    g.arc(16, 8, 4.2, 0.6, 5.5, 'ACC', 2.6)

@icon('lightbulb')
def _(g):
    g.c.move_to(9, 16); g.c.curve_to(5, 13, 5, 5, 12, 4); g.c.curve_to(19, 5, 19, 13, 15, 16); g.c.close_path()
    g.c.set_source_rgb(*_r('AMB')); g.c.fill_preserve(); g.stroke_style('BRN', 1.5); g.c.stroke()
    g.line(9.5, 18.5, 14.5, 18.5, 'INK', 1.7); g.line(10.5, 20.8, 13.5, 20.8, 'INK', 1.7)

@icon('paste')
def _(g):
    g.box(4.5, 4.5, 13, 16, 2, fill='ACL')
    g.box(8, 2.5, 6, 4, 1.2, fill='PAP', lw=1.3)
    g.box(11, 10, 9.5, 11, 1.6, fill='PAP', lw=1.4)

@icon('cut')
def _(g):
    g.line(6, 4, 15, 15, 'INK', 1.6); g.line(18, 4, 9, 15, 'INK', 1.6)
    g.circle(7, 18, 3, fill='PAP', line='ACC', lw=1.6); g.circle(17, 18, 3, fill='PAP', line='ACC', lw=1.6)

@icon('archive')
def _(g):
    g.box(3, 4, 18, 5, 1.4, fill='ACL')
    g.box(4.5, 9, 15, 11.5, 1.4, fill='PAP')
    g.line(9, 13.5, 15, 13.5, 'INK', 1.7)

@icon('merge')
def _(g):
    g.line(5, 5, 12, 12, 'INK', 1.7); g.line(19, 5, 12, 12, 'INK', 1.7)
    g.arrow(12, 12, 12, 20, 'ACC', 1.9, 3.4)

@icon('sync')
def _(g):
    g.arc(12, 12, 7.2, math.pi * 1.05, math.pi * 1.95 + 0.5, 'ACC', 1.9)
    g.arc(12, 12, 7.2, math.pi * 0.05, math.pi * 0.95 + 0.5, 'INK', 1.9)
    g.poly([(19.5, 9.5), (19.7, 5.2), (15.5, 6.3)], 'ACC', 1.8); g.poly([(4.5, 14.5), (4.3, 18.8), (8.5, 17.7)], 'INK', 1.8)

@icon('power')
def _(g):
    g.arc(12, 13, 7, -math.pi * 0.32, math.pi * 1.32, 'INK', 2.0)
    g.line(12, 3.5, 12, 12, 'RED', 2.2)

@icon('edit')
def _(g):
    g.poly([(4, 20), (4.8, 15.5), (16.5, 3.8), (20.2, 7.5), (8.5, 19.2)], None, 1.5, close=True, fill='PAP')
    g.line(14.5, 5.8, 18.2, 9.5, None, 1.4); g.line(13, 20.5, 21, 20.5, 'MUT', 1.4)

@icon('adduser')
def _(g):
    person(g, 10, 10, 1.0, 'INK', 'ACL')
    g.circle(18.3, 17.8, 3.6, fill='GRN', line='ONC', lw=1.1)
    g.line(18.3, 16, 18.3, 19.6, 'ONC', 1.7); g.line(16.5, 17.8, 20.1, 17.8, 'ONC', 1.7)

@icon('checkcircle')
def _(g):
    g.circle(12, 12, 9, fill='GRN', line=None)
    g.poly([(7.5, 12.5), (10.8, 15.8), (16.8, 8.8)], 'ONC', 2.4)

@icon('errorcircle')
def _(g):
    g.circle(12, 12, 9, fill='RED', line=None)
    g.line(8.5, 8.5, 15.5, 15.5, 'ONC', 2.2); g.line(15.5, 8.5, 8.5, 15.5, 'ONC', 2.2)

@icon('menu')
def _(g):
    for y in (6.5, 12, 17.5):
        g.line(4.5, y, 19.5, y, 'INK', 2.0)

@icon('more')
def _(g):
    for x in (5.5, 12, 18.5):
        g.circle(x, 12, 1.9, fill='INK', line=None)

@icon('chev_down')
def _(g):
    chev(g, 'down')

@icon('chev_up')
def _(g):
    chev(g, 'up')

@icon('chev_left')
def _(g):
    chev(g, 'left')

@icon('chev_right')
def _(g):
    chev(g, 'right')

@icon('arrow_back')
def _(g):
    g.arrow(20, 12, 4.5, 12, 'ACC', 2.2, 4)

@icon('arrow_forward')
def _(g):
    g.arrow(4, 12, 19.5, 12, 'ACC', 2.2, 4)
grp('Radnje i sustav', 'lock unlock key shield bell wrench lightbulb paste cut archive merge sync power edit adduser checkcircle errorcircle menu more chev_down chev_up chev_left chev_right arrow_back arrow_forward')

def base_groups():
    grp('Objekti baze', 'table form query report letter module macro program database app home')
    grp('Radnje', 'new open save delete duplicate undo redo run preview design refresh search filter print pdf word html export import settings help close add remove up down check warning info first prev next last expression addfields pagesetup labels anchors')
    grp('Poravnanje i raspored', 'align_al align_ac align_ar align_at align_am align_ab same_width same_height distribute_h distribute_v front back resize')
    for n in list(ICONS):
        if n.startswith('c_'):
            GROUPS[n] = 'Kontrole'

# velicine ugradene u program (po temi): sve 16 i 24; 32 samo ikona programa
EMBED = (16, 24)
THEMES = (('light', 'svijetle'), ('dark', 'tamne'))

def draw(name, size, vector=None):
    if vector is not None:
        surf = vector
    else:
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    ctx = cairo.Context(surf)
    if vector is None:
        ctx.scale(size / 24.0, size / 24.0)
    ctx.set_antialias(cairo.ANTIALIAS_BEST)
    ICONS[name](C(ctx))
    return surf

def sheet(names, path, bg):
    cols = 14
    cell = 64
    rows = (len(names) + cols - 1) // cols
    sh = cairo.ImageSurface(cairo.FORMAT_ARGB32, cols * cell, rows * (cell + 14) + 4)
    cx = cairo.Context(sh)
    cx.set_source_rgb(*bg); cx.paint()
    lab = (0.3, 0.3, 0.3) if bg[0] > 0.5 else (0.75, 0.78, 0.85)
    for i, n in enumerate(names):
        x = (i % cols) * cell
        y = (i // cols) * (cell + 14)
        cx.set_source_surface(draw(n, 32), x + 16, y + 2); cx.paint()
        cx.set_source_surface(draw(n, 16), x + 4, y + 36); cx.paint()
        cx.set_source_rgb(*lab)
        cx.select_font_face('DejaVu Sans'); cx.set_font_size(7)
        cx.move_to(x + 24, y + 56); cx.show_text(n[:12])
    sh.write_to_png(path)

def main():
    base_groups()
    names = sorted(ICONS)
    cat = os.path.join(ROOT, 'ikone')
    data = {}
    for key, folder in THEMES:
        use_palette(key)
        for size in SIZES:
            d = os.path.join(cat, folder, 'png%d' % size)
            os.makedirs(d, exist_ok=True)
            for n in names:
                p = os.path.join(d, n + '.png')
                draw(n, size).write_to_png(p)
                if size in EMBED or n == 'app':
                    data[(n, size, key)] = open(p, 'rb').read()
        sd = os.path.join(cat, folder, 'svg')
        os.makedirs(sd, exist_ok=True)
        for n in names:
            vs = cairo.SVGSurface(os.path.join(sd, n + '.svg'), 24, 24)
            draw(n, 24, vs)
            vs.finish()
        sheet(names, os.path.join(cat, 'pregled-' + folder + '.png'), (1, 1, 1) if key == 'light' else (0.06, 0.09, 0.16))
    use_palette('light')
    svgs = {}
    for key, folder in THEMES:
        for n in names:
            svgs[(n, key)] = open(os.path.join(cat, folder, 'svg', n + '.svg'), encoding='utf-8').read()
    with open(os.path.join(cat, 'indeks.csv'), 'w', encoding='utf-8') as f:
        f.write('naziv;skupina;datoteke\n')
        for n in names:
            f.write('%s;%s;svijetle/svg/%s.svg, tamne/svg/%s.svg, png16/24/32/64/128/256\n' % (n, GROUPS.get(n, 'Ostalo'), n, n))
    with open(os.path.join(cat, 'README.md'), 'w', encoding='utf-8') as f:
        f.write('# Zaliha ikona\n\nSve ikone programa i primjera (%d) u svijetloj i tamnoj izvedbi, kao SVG (vektor) i PNG 16, 24, 32, 64, 128 i 256 točaka (veće za zaglavlja izvješća).\n\n'
                '* `svijetle/` za svijetlu pozadinu, `tamne/` za tamnu; isti nazivi u obje mape.\n'
                '* `indeks.csv`: naziv i skupina svake ikone. `pregled-svijetle.png` i `pregled-tamne.png` su pregledni listovi.\n'
                '* Ikone u programu su ugrađene (generira ih `tools/gen_icons.py`); dodavanje nove ikone je jedna funkcija u tom alatu, pa ponovno pokretanje.\n'
                '* Vlastite ikone: PNG datoteke u mapi `~/.config/TyphAccess/ikone/` s nazivom ikone (npr. `moja.png`) program učitava uz ugrađene.\n' % len(names))
    # ta_iconsdata.pas: sve je ugradjeno u program
    o = ['unit ta_iconsdata;',
         '{ GENERIRANO (tools/gen_icons.py): ikone kao PNG u base64, svijetle i tamne. Ne uredjuj rucno. }',
         '', '{$mode objfpc}{$H+}', '', 'interface', '',
         'function IconDataCount: Integer;',
         'function IconDataName(AIndex: Integer): string;',
         "function IconDataGroup(const AName: string): string;",
         '{ PNG u base64; ASize je 16, 24 ili 128 (32 samo za "app"); ADark = tamna izvedba }',
         'function IconDataPng(const AName: string; ASize: Integer; ADark: Boolean): string;',
         '{ vektorska ikona (SVG tekst) za velike slike u izvjescima }',
         'function IconDataSvg(const AName: string; ADark: Boolean): string;', '',
         'implementation', '', 'uses base64;', '']
    import re as _re
    def _min(t):
        t = _re.sub(r'<\?xml[^>]*\?>', '', t)
        return _re.sub(r'>\s+<', '><', t).strip()
    for n in names:
        for key, folder in THEMES:
            b = base64.b64encode(_min(svgs[(n, key)]).encode()).decode()
            o.append('function S_%s_%s: string;' % (n, key[0]))
            o.append('begin')
            o.append("  Result := ''")
            for k in range(0, len(b), 100):
                o.append("    + '%s'" % b[k:k + 100])
            o.append('  ;')
            o.append('end;')
            o.append('')
    for n in names:
        for key, folder in THEMES:
            for size in SIZES:
                if (n, size, key) not in data:
                    continue
                b = base64.b64encode(data[(n, size, key)]).decode()
                fn = 'I_%s_%d_%s' % (n, size, key[0])
                o.append('function %s: string;' % fn)
                o.append('begin')
                o.append("  Result := ''")
                for k in range(0, len(b), 100):
                    o.append("    + '%s'" % b[k:k + 100])
                o.append('  ;')
                o.append('end;')
                o.append('')
    o += ['function IconDataCount: Integer;', 'begin', '  Result := %d;' % len(names), 'end;', '',
          'function IconDataName(AIndex: Integer): string;', 'begin', '  case AIndex of']
    for i, n in enumerate(names):
        o.append("    %d: Result := '%s';" % (i, n))
    o += ["  else Result := '';", '  end;', 'end;', '',
          'function IconDataGroup(const AName: string): string;', 'begin', "  Result := '';"]
    for n in names:
        o.append("  if AName = '%s' then Exit('%s');" % (n, GROUPS.get(n, 'Ostalo').replace("'", "''")))
    o += ['end;', '',
          'function IconDataPng(const AName: string; ASize: Integer; ADark: Boolean): string;', 'begin', "  Result := '';"]
    for n in names:
        o.append("  if AName = '%s' then" % n)
        o.append('    case ASize of')
        for size in SIZES:
            if (n, size, 'light') in data:
                o.append('      %d: if ADark then Exit(I_%s_%d_d) else Exit(I_%s_%d_l);' % (size, n, size, n, size))
        o.append('    end;')
    o += ['end;', '', 'function IconDataSvg(const AName: string; ADark: Boolean): string;', 'begin', "  Result := '';"]
    for n in names:
        o.append("  if AName = '%s' then begin if ADark then Exit(DecodeStringBase64(S_%s_d)) else Exit(DecodeStringBase64(S_%s_l)); end;" % (n, n, n))
    o += ['end;', '', 'end.', '']
    open(os.path.join(ROOT, 'src', 'gui', 'ta_iconsdata.pas'), 'w', encoding='utf-8').write('\n'.join(o))
    print('ikone: %d, velicine %s, teme svijetla i tamna' % (len(names), SIZES))

if __name__ == '__main__':
    main()
