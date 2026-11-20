#!/bin/bash
# Samostalni test barkod modula: tools/barcode_test.sh [izlaz.pbm]
set -e
cd "$(dirname "$0")/.."
FPC=${FPC:-/usr/local/codetyphon/fpc/fpc64/bin/x86_64-linux/fpc}
mkdir -p tests/fl
"$FPC" -Fusrc/core -FUtests/fl -otests/barcode_test tests/barcode_test.pas | grep -E "Error|Fatal" || true
./tests/barcode_test "${1:-/tmp/qr.pbm}"
