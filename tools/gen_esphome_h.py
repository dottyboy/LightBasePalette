#!/usr/bin/env python3
"""docs/esphome/procesi_raspored.h -> ../LightPalette/src/core/ta_esphome_h.inc (Pascal konstanta s tekstom zaglavlja)."""
import os
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, "..", "docs", "esphome", "procesi_raspored.h")
dst = os.path.join(here, "..", "..", "LightPalette", "src", "core", "ta_esphome_h.inc")
lines = open(src, encoding="utf-8").read().rstrip("\n").split("\n")
out = ["{ Izradeno alatom tools/gen_esphome_h.py iz docs/esphome/procesi_raspored.h; ne uredjivati rucno. }", "const", "  EspHomeRasporedH: string ="]
for i, l in enumerate(lines):
    q = "'" + l.replace("'", "''") + "'"
    out.append("    " + q + (" + LineEnding +" if i < len(lines) - 1 else " + LineEnding;"))
open(dst, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("zapisano", dst, len(lines), "redaka")
