#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generira src/core/ta_showcasedata.pas iz showcase/programs/*.4gl, showcase/module.pas i popisa funkcija
(tools/manual_src/functions.py). Pokretanje: python3 tools/gen_showcase.py (poziva ga i tools/build.sh)."""
import os, re, sys, glob
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'manual_src'))
from functions import FUNCS

def lit(s):
    return "'" + s.replace("'", "''") + "'"

def body(name, text):
    out = ['function %s: string;' % name, 'var', '  S: string;', 'begin', "  S := '';"]
    for ln in text.replace('\r', '').split('\n'):
        out.append('  S := S + %s + #10;' % lit(ln))
    out += ['  Result := S;', 'end;', '']
    return out

progs = []
for f in sorted(glob.glob(os.path.join(ROOT, 'showcase', 'programs', '*.4gl'))):
    t = open(f, encoding='utf-8').read().rstrip('\n')
    m = re.search(r'^-- naziv: (.+)$', t, re.M)
    progs.append((m.group(1).strip() if m else os.path.basename(f), t))
module = open(os.path.join(ROOT, 'showcase', 'module.pas'), encoding='utf-8').read().rstrip('\n')

o = ['unit ta_showcasedata;',
     '{ GENERIRANO (tools/gen_showcase.py): 4GL programi, PascalScript modul i popis funkcija za primjer "Trgovina Jadran". Ne uredjuj rucno. }',
     '', '{$mode objfpc}{$H+}', '', 'interface', '',
     'function ShowcaseProgramCount: Integer;',
     'function ShowcaseProgramName(AIndex: Integer): string;',
     'function ShowcaseProgramText(AIndex: Integer): string;',
     'function ShowcaseModuleText: string;',
     '{ skupina|naziv|potpis|opis|primjer }',
     'function ShowcaseFuncCount: Integer;',
     'function ShowcaseFuncRow(AIndex: Integer): string;', '', 'implementation', '']
for i, (n, t) in enumerate(progs):
    o += body('Prog%d' % i, t)
o += body('ModuleSrc', module)
o += ['function ShowcaseProgramCount: Integer;', 'begin', '  Result := %d;' % len(progs), 'end;', '',
      'function ShowcaseProgramName(AIndex: Integer): string;', 'begin', '  case AIndex of']
for i, (n, t) in enumerate(progs):
    o.append('    %d: Result := %s;' % (i, lit(n)))
o += ['  else Result := \'\';', '  end;', 'end;', '',
      'function ShowcaseProgramText(AIndex: Integer): string;', 'begin', '  case AIndex of']
for i, (n, t) in enumerate(progs):
    o.append('    %d: Result := Prog%d;' % (i, i))
o += ["  else Result := '';", '  end;', 'end;', '',
      'function ShowcaseModuleText: string;', 'begin', '  Result := ModuleSrc;', 'end;', '',
      'function ShowcaseFuncCount: Integer;', 'begin', '  Result := %d;' % len(FUNCS), 'end;', '',
      'function ShowcaseFuncRow(AIndex: Integer): string;', 'begin', '  case AIndex of']
for i, f in enumerate(FUNCS):
    row = '|'.join(x.replace('|', '¦') for x in (f[0], f[1], f[2], f[3], f[4]))
    o.append('    %d: Result := %s;' % (i, lit(row)))
o += ["  else Result := '';", '  end;', 'end;', '', 'end.', '']
open(os.path.join(ROOT, 'src', 'core', 'ta_showcasedata.pas'), 'w', encoding='utf-8').write('\n'.join(o))
print('showcase: %d programa, %d funkcija' % (len(progs), len(FUNCS)))
