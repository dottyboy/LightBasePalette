#!/bin/bash
# Prevodi i pokrece paritetni skup (osnovni snimak ponasanja TaFormRunner-a).
#   run.sh          usporedi s golden/ (izlaz 0 = isto)
#   run.sh record   ponovno snimi golden/ (samo kad je promjena ponasanja namjerna i pregledana)
set -o pipefail
cd "$(dirname "$0")"
TB="${CODETYPHON_DIR:-/usr/local/codetyphon}/typhon/bin64/typhonbuild"
"$TB" --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=qt6 parity.ctpr 2>&1 | grep -E "Error|Fatal" && exit 1 || true
FILT="^(ok|snimljeno|RAZLIKA|NEMA|IZNIMKA u|slucajeva|  golden|  sada|  runner|  binder)"
run() { DBUS_SESSION_BUS_ADDRESS=disabled: QT_QPA_PLATFORM=offscreen timeout 600 ./parity "$@" 2>/dev/null | grep -aE "$FILT"; }
if [ "${1:-check}" = "record" ]; then run record; exit 0; fi
# 1) runner prema golden, 2) ista definicija kroz TaFormBinder prema istim golden snimkama
run check; R1=${PIPESTATUS[0]}
run binder; R2=${PIPESTATUS[0]}
exit $((R1 + R2))
