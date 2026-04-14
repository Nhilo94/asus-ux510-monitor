#!/bin/bash
set -e

PLASMOID_DIR="$(cd "$(dirname "$0")/plasmoid" && pwd)"

echo "=== ASUS UX510 Monitor — KDE Plasma Widget ==="

# Remove old version if installed
if plasmapkg2 -l 2>/dev/null | grep -q com.asus.batterymonitor; then
    echo "Removing previous version..."
    plasmapkg2 -r com.asus.batterymonitor 2>/dev/null || true
fi

echo "Installing widget..."
plasmapkg2 -i "$PLASMOID_DIR"

echo ""
echo "Done! Add the widget to your panel:"
echo "  Right-click panel -> Add Widgets -> search 'ASUS UX510 Monitor'"
echo ""
echo "To uninstall:"
echo "  plasmapkg2 -r com.asus.batterymonitor"
