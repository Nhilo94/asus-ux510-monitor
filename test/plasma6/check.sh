#!/bin/bash
# Static-checks the Plasma 6 package against a real Qt6/KF6/Plasma 6 runtime,
# from a machine that does not run Plasma 6.
#
# Why this exists: the dev machine is Debian 12 / Plasma 5.27, so the Plasma 6
# QML can never be loaded locally — `org.kde.plasma.plasma5support` and KF6
# simply are not installed. Everything that breaks a Plasma 6 plasmoid shows up
# here: a rejected metadata.json, an unresolved import, a type that no longer
# exists (PlasmaCore.DataSource, PlasmaCore.Theme, PlasmaCore.IconItem).
#
# Usage:  bash test/plasma6/check.sh
# Note:   rendering is NOT verified. plasmoidviewer draws nothing under
#         software rendering in a container — a stock applet (analogclock)
#         comes out just as blank, so a blank window proves nothing either way.

set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE="pcmonitor-plasma6-test"
STAGE="$(mktemp -d)"
PKG="$STAGE/com.github.nhilo94.pcmonitor"
trap 'rm -rf "$STAGE"' EXIT

echo "=== Building the Plasma 6 test image (cached after the first run) ==="
docker build -q -t "$IMAGE" "$ROOT/test/plasma6" >/dev/null

# Stage the package exactly as install.sh ships it: sources + shared sensor script.
mkdir -p "$PKG/contents/code"
cp -r "$ROOT/plasmoid6/." "$PKG/"
cp "$ROOT/shared/monitor.sh" "$PKG/contents/code/monitor.sh"
chmod +x "$PKG/contents/code/monitor.sh"

echo
echo "=== 1. Does Plasma 6 accept the package? ==="
docker run --rm -v "$PKG:/root/.local/share/plasma/plasmoids/com.github.nhilo94.pcmonitor:ro" \
    "$IMAGE" kpackagetool6 -t Plasma/Applet -s com.github.nhilo94.pcmonitor

echo
echo "=== 2. Do all imports and types resolve under Qt6/KF6? ==="
# Only `unresolved-type` and `missing-property` matter. `unqualified` is a style
# warning about accessing root properties without the `root.` prefix; it is
# harmless at runtime and the file has many of them by design.
docker run --rm -v "$PKG:/pkg:ro" "$IMAGE" \
    /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml /pkg/contents/ui/main.qml \
    > "$STAGE/lint.txt" 2>&1 || true

bad=$(grep -cE '\[(unresolved-type|missing-property)\]' "$STAGE/lint.txt" || true)
style=$(grep -c '\[unqualified\]' "$STAGE/lint.txt" || true)

echo "unresolved-type + missing-property : $bad"
echo "unqualified (style only)           : $style"

if [ "$bad" -gt 0 ]; then
    echo
    echo "FAILED — the Plasma 6 package uses types that do not exist in Plasma 6:"
    grep -E '\[(unresolved-type|missing-property)\]' "$STAGE/lint.txt" | head -20
    exit 1
fi

echo
echo "PASSED — package accepted, every import and type resolves under Plasma 6."
