#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLASMOID_DIR="$SCRIPT_DIR/plasmoid"
PLUGIN_ID="com.github.nhilo94.pcmonitor"
OLD_PLUGIN_ID="com.asus.batterymonitor"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids"

echo "=== PC Monitor — KDE Plasma Widget ==="

# Remove old versions if present
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
cp -r "$PLASMOID_DIR" "$INSTALL_DIR/$PLUGIN_ID"

echo ""
echo "Done! Restart the plasma shell with:"
echo "  kquitapp5 plasmashell && kstart5 plasmashell"
echo ""
echo "Then add the widget:"
echo "  Right-click panel/desktop → Add Widgets → search 'PC Monitor'"
echo ""
echo "To uninstall:"
echo "  rm -rf $INSTALL_DIR/$PLUGIN_ID"
echo ""

# ── Build .plasmoid archive for KDE Store upload ───────────────────────────
if command -v zip &>/dev/null; then
    OUT="$SCRIPT_DIR/pc-monitor.plasmoid"
    rm -f "$OUT"
    (cd "$PLASMOID_DIR" && zip -r "$OUT" . -x "*.git*")
    echo "Package ready for KDE Store: $OUT"
fi
