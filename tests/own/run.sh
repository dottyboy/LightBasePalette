#!/bin/bash
# Zlatne snimke vlastitih kontrola (pruzatelj 'own'): run.sh = usporedi s golden/, run.sh record = ponovno snimi.
cd "$(dirname "$0")"
TB="${CODETYPHON_DIR:-/usr/local/codetyphon}/typhon/bin64/typhonbuild"
mkdir -p lib
"$TB" --pcp="${TYPHON_PCP:-$HOME/.typhon64}" --ws=qt6 own.ctpr 2>&1 | grep -E "Error|Fatal" && exit 1 || true
DBUS_SESSION_BUS_ADDRESS=disabled: QT_QPA_PLATFORM=offscreen timeout 300 ./ownshots "${1:-check}" 2>/dev/null | grep -aE "^(ok|snimljeno|RAZLIKA|NEMA|slucajeva)"
exit ${PIPESTATUS[0]}
