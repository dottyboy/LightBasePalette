#!/bin/bash
# Builds dist/TyphAccess-<version>-x86_64.AppImage from bin/TyphAccess (no appimagetool needed).
# Bundles Qt6 + libQt6Pas + their dependencies (not glibc / GPU drivers), the xcb/wayland Qt plugins,
# the examples and the manual. Needs: mksquashfs, an existing AppImage to borrow the runtime from
# (RUNTIME_FROM=/path/to/any-type2.AppImage) or a runtime file (RUNTIME=/path/to/runtime-x86_64).
# Usage: tools/make_appimage.sh [VERSION]
set -e
cd "$(dirname "$0")/.."
VER=${1:-$(date +%Y%m%d)}
BIN=${BIN:-bin/TyphAccess}
[ -x "$BIN" ] || { echo "missing $BIN (run tools/build.sh)"; exit 1; }
WORK=${WORK:-dist/appimage-work}
APP="$WORK/TyphAccess.AppDir"
OUT="dist/TyphAccess-$VER-x86_64.AppImage"
QTPLUG=${QTPLUG:-/usr/lib/x86_64-linux-gnu/qt6/plugins}

rm -rf "$WORK"; mkdir -p "$APP/usr/bin" "$APP/usr/lib" "$APP/usr/plugins" "$APP/usr/share/typhaccess" dist
cp "$BIN" "$APP/usr/bin/TyphAccess"; strip "$APP/usr/bin/TyphAccess"

for p in platforms/libqxcb.so platforms/libqwayland-egl.so platforms/libqwayland-generic.so \
         imageformats/libqjpeg.so imageformats/libqsvg.so imageformats/libqgif.so imageformats/libqwebp.so \
         platforminputcontexts iconengines xcbglintegrations wayland-decoration-client \
         wayland-graphics-integration-client wayland-shell-integration; do
  [ -e "$QTPLUG/$p" ] || continue
  mkdir -p "$APP/usr/plugins/$(dirname "$p")"; cp -a "$QTPLUG/$p" "$APP/usr/plugins/$(dirname "$p")/"
done

# system libraries that must come from the host (glibc, graphics stack, X/Wayland basics)
SKIP='^(linux-vdso|ld-linux|libc\.|libm\.|libdl\.|libpthread|librt\.|libutil|libresolv|libnsl|libGL|libEGL|libGLX|libOpenGL|libgbm|libdrm|libvulkan|libX11\.|libX11-xcb|libxcb\.|libwayland-(client|server|egl|cursor)|libnss|libgcc_s|libstdc\+\+|libasound|libpulse|libdbus-1|libsystemd|libudev|libselinux|libz\.|libfontconfig|libfreetype|libharfbuzz|libglib|libgobject|libgmodule|libgio|libffi|libpcre|libmount|libblkid|libcap|libsqlite3)'
copy_deps() {
  ldd "$1" 2>/dev/null | awk '/=>/ && $3 ~ /^\// {print $3}' | while read -r lib; do
    b=$(basename "$lib")
    echo "$b" | grep -Eq "$SKIP" && continue
    [ -e "$APP/usr/lib/$b" ] && continue
    cp -L "$lib" "$APP/usr/lib/$b"; copy_deps "$lib"
  done
}
copy_deps "$APP/usr/bin/TyphAccess"
find "$APP/usr/plugins" -name '*.so' | while read -r f; do copy_deps "$f"; done

cp -r examples "$APP/usr/share/typhaccess/examples" 2>/dev/null || true
find "$APP" -name __pycache__ -type d -prune -exec rm -rf {} + || true
[ -d docs/manual ] && mkdir -p "$APP/usr/share/typhaccess/docs" && cp -r docs/manual "$APP/usr/share/typhaccess/docs/" && rm -rf "$APP/usr/share/typhaccess/docs/manual/html" 2>/dev/null || true
cp LICENSE THIRD-PARTY.md "$APP/usr/share/typhaccess/" 2>/dev/null || true

cat > "$APP/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$HERE/usr/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/usr/plugins/platforms"
export DBUS_SESSION_BUS_ADDRESS=disabled:
exec "$HERE/usr/bin/TyphAccess" "$@"
RUN
chmod +x "$APP/AppRun"

cat > "$APP/typhaccess.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=TyphAccess
Comment=Business application builder (SQLite, PostgreSQL, MariaDB)
Exec=TyphAccess %f
Icon=typhaccess
Categories=Development;Database;
Terminal=false
DESK
cp tools/icons/32/app.png "$APP/typhaccess.png"
cp tools/icons/32/app.png "$APP/.DirIcon"

# runtime: first N bytes of a type-2 AppImage
if [ -z "$RUNTIME" ]; then
  [ -n "$RUNTIME_FROM" ] || { echo "set RUNTIME_FROM or RUNTIME"; exit 1; }
  OFF=$("$RUNTIME_FROM" --appimage-offset)
  head -c "$OFF" "$RUNTIME_FROM" > "$WORK/runtime"; RUNTIME="$WORK/runtime"
fi
mksquashfs "$APP" "$WORK/app.squashfs" -root-owned -noappend -comp zstd -quiet
cat "$RUNTIME" "$WORK/app.squashfs" > "$OUT"; chmod +x "$OUT"
ls -l "$OUT"
