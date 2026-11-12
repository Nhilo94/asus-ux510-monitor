#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ID="com.github.nhilo94.pcmonitor"
OLD_PLUGIN_ID="com.asus.batterymonitor"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids"

echo "=== PC Monitor — KDE Plasma Widget ==="

# ── Detect the running Plasma major version ───────────────────────────────
# The QML APIs diverge too much between Plasma 5 and 6 to ship a single
# package (PlasmaCore.DataSource vs plasma5support, Item vs PlasmoidItem,
# PlasmaCore.Theme vs Kirigami.Theme), so we keep one source tree per major
# version and pick the right one here. Override with: install.sh 5|6
detect_plasma() {
    local v
    v="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"
    [ -z "$v" ] && v="$(kpackagetool6 --version >/dev/null 2>&1 && echo 6)"
    [ -z "$v" ] && v="$(kpackagetool5 --version >/dev/null 2>&1 && echo 5)"
    echo "${v:-6}"
}

case "$1" in
    5|--plasma5) PLASMA_MAJOR=5 ;;
    6|--plasma6) PLASMA_MAJOR=6 ;;
    "")          PLASMA_MAJOR="$(detect_plasma)" ;;
    *) echo "Usage: $0 [5|6]"; exit 1 ;;
esac

if [ "$PLASMA_MAJOR" = "6" ]; then
    SRC_DIR="$SCRIPT_DIR/plasmoid6"
else
    SRC_DIR="$SCRIPT_DIR/plasmoid"
fi
echo "Detected Plasma $PLASMA_MAJOR → using $(basename "$SRC_DIR")/"

# ── Stage a package: source tree + the shared sensor script ───────────────
# monitor.sh lives in shared/ so both packages stay in sync by construction.
stage_pkg() {
    local src="$1" dest="$2"
    rm -rf "$dest"
    mkdir -p "$dest/contents/code"
    cp -r "$src/." "$dest/"
    cp "$SCRIPT_DIR/shared/monitor.sh" "$dest/contents/code/monitor.sh"
    chmod +x "$dest/contents/code/monitor.sh"
}

# ── Install ───────────────────────────────────────────────────────────────
for old in "$OLD_PLUGIN_ID" "$PLUGIN_ID"; do
    if [ -d "$INSTALL_DIR/$old" ]; then
        echo "Removing previous version ($old)..."
        rm -rf "$INSTALL_DIR/$old"
    fi
    # Also clean up any stray kpackage/generic installs
    rm -rf "$HOME/.local/share/kpackage/generic/$old"
done

echo "Installing widget..."
mkdir -p "$INSTALL_DIR"
stage_pkg "$SRC_DIR" "$INSTALL_DIR/$PLUGIN_ID"

echo ""
echo "Done! Restart the plasma shell with:"
if [ "$PLASMA_MAJOR" = "6" ]; then
    echo "  kquitapp6 plasmashell && kstart plasmashell"
else
    echo "  kquitapp5 plasmashell && kstart5 plasmashell"
fi
echo ""
echo "Then add the widget:"
echo "  Right-click panel/desktop → Add Widgets → search 'PC Monitor'"
echo ""
echo "To uninstall:"
echo "  rm -rf $INSTALL_DIR/$PLUGIN_ID"
echo ""

# ── Build both .plasmoid archives for the KDE Store / OpenDesktop ─────────
if command -v zip &>/dev/null; then
    BUILD="$SCRIPT_DIR/.build"
    rm -rf "$BUILD"
    for pair in "plasmoid:pc-monitor-plasma5.plasmoid" "plasmoid6:pc-monitor-plasma6.plasmoid"; do
        src="${pair%%:*}"; out="$SCRIPT_DIR/${pair##*:}"
        stage_pkg "$SCRIPT_DIR/$src" "$BUILD/$src"
        rm -f "$out"
        (cd "$BUILD/$src" && zip -qr "$out" . -x "*.git*")
        echo "Package ready: $out"
    done
    rm -rf "$BUILD"
fi
