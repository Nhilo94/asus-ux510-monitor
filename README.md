# PC Monitor — KDE Plasma Widget

A KDE Plasma widget that monitors CPU temperatures, RAM, fan speeds, battery health
and other sensors. Sensors are auto-detected from `hwmon`, so it works on most Linux
laptops and desktops — not just the ASUS UX510UWK it was originally written for.

**Works on Plasma 5 and Plasma 6.**

## What it shows

| Section | Sensors |
|---------|---------|
| **Battery** | Cycles, capacity %, health %, energy (Wh), voltage, charge status — hidden on desktops |
| **CPU** | Per-core and package temps (`coretemp`, `k10temp`, `zenpower`, `k8temp`), load %, frequency |
| **GPU** | GPU temps (`amdgpu`, `radeon`, `nouveau`, `nvidia`) — hidden if absent |
| **RAM** | Used / total with usage bar |
| **Fans** | Every `fan*_input` exposed by any hwmon node — hidden if absent |
| **Other** | ACPI chassis, PCH chipset, WiFi adapter, NVMe temps |

Color-coded thresholds: green (OK), yellow (warm), orange (high), red (danger).

## Panel vs Desktop

- **Panel**: compact readout (CPU temp, load, RAM, frequency). Click to open the full popup.
- **Desktop**: full widget displayed directly.

## Install

```bash
git clone https://github.com/nhilo94/asus-ux510-monitor.git
cd asus-ux510-monitor
bash install.sh
```

`install.sh` detects your Plasma version and installs the matching package. Force it
with `bash install.sh 5` or `bash install.sh 6` if detection gets it wrong.

Restart the shell:

```bash
kquitapp6 plasmashell && kstart plasmashell    # Plasma 6
kquitapp5 plasmashell && kstart5 plasmashell   # Plasma 5
```

Then right-click your panel or desktop, **Add Widgets**, and search for **"PC Monitor"**.

### From the store

The widget is published as **PC Monitor** on the OpenDesktop/Pling network:
<https://www.opendesktop.org/p/2358290/>

Two files are offered — pick the one matching your Plasma version:

| File | For |
|------|-----|
| `pc-monitor-plasma6.plasmoid` | Plasma 6 |
| `pc-monitor-plasma5.plasmoid` | Plasma 5 |

Install a downloaded package with:

```bash
kpackagetool6 -t Plasma/Applet -i pc-monitor-plasma6.plasmoid   # Plasma 6
kpackagetool5 -t Plasma/Applet -i pc-monitor-plasma5.plasmoid   # Plasma 5
```

## Uninstall

```bash
rm -rf ~/.local/share/plasma/plasmoids/com.github.nhilo94.pcmonitor
```

## Structure

```
asus-ux510-monitor/
├── shared/
│   └── monitor.sh               # Sensor auto-discovery script (shared by both packages)
├── plasmoid/                    # Plasma 5 package (Qt 5 / KF5 QML)
│   ├── metadata.json
│   ├── metadata.desktop
│   └── contents/ui/main.qml
├── plasmoid6/                   # Plasma 6 package (Qt 6 / KF6 QML)
│   ├── metadata.json
│   └── contents/ui/main.qml
├── install.sh                   # Detects Plasma version, installs + builds both archives
├── LICENSE
└── README.md
```

### Why two packages?

The QML APIs diverge too much between Plasma 5 and 6 for a single package to load on
both: `PlasmaCore.DataSource` moved to `org.kde.plasma.plasma5support`, the applet root
became `PlasmoidItem`, `PlasmaCore.Theme` became `Kirigami.Theme`, `PlasmaCore.IconItem`
became `Kirigami.Icon`, and Plasma 6 requires `X-Plasma-API-Minimum-Version` in
`metadata.json`. So the UI exists once per major version.

`shared/monitor.sh` is the only place sensors are read — `install.sh` copies it into
whichever package it builds, so the two versions can't drift on sensor support. **Add new
sensors there and both widgets pick them up.**

## Compatibility

- **Hardware**: any Linux machine exposing sensors through `hwmon` (Intel/AMD CPUs,
  AMD/NVIDIA GPUs, NVMe, common WiFi chips). Sections with no matching sensor are hidden.
- **Desktop**: KDE Plasma 5 or 6
- **Dependencies**: None beyond a standard KDE Plasma desktop

## Related

- [asus-ux510-fan2](https://github.com/nhilo94/asus-ux510-fan2) — Hidden GPU fan controller for the same laptop

## License

MIT
