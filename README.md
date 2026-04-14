# ASUS UX510 Monitor — KDE Plasma Widget

A KDE Plasma 5 widget that monitors battery health, CPU temperatures, fan speeds and other sensors on the ASUS UX510UWK laptop.

## What it shows

| Section | Sensors |
|---------|---------|
| **Battery** | Cycles, capacity %, health %, energy (Wh), voltage, charge status |
| **CPU** | Package temp, Core 0, Core 1 (via `coretemp` hwmon) |
| **Fans** | CPU fan RPM (via `asus` hwmon), GPU fan status |
| **Other** | ACPI chassis temp, PCH chipset temp, WiFi adapter temp |

Color-coded thresholds: green (OK), yellow (warm), orange (high), red (danger).

## Panel vs Desktop

- **Panel**: compact icon with CPU temperature. Click to open the full popup.
- **Desktop**: full widget displayed directly.

## Install

```bash
git clone https://github.com/nhilo94/asus-ux510-monitor.git
cd asus-ux510-monitor
bash install.sh
```

Then right-click your panel, **Add Widgets**, search for **"ASUS UX510 Monitor"**.

## Uninstall

```bash
plasmapkg2 -r com.asus.batterymonitor
```

## Structure

```
asus-ux510-monitor/
├── plasmoid/                    # KDE Plasma widget package
│   ├── metadata.desktop         # Widget metadata
│   └── contents/
│       └── ui/
│           └── main.qml         # Widget UI and logic
├── install.sh                   # Install/update script
├── LICENSE
└── README.md
```

## Compatibility

- **Hardware**: ASUS UX510UWK (should work on similar ASUS laptops with minor adjustments)
- **OS**: Debian 12 (Bookworm) / KDE Plasma 5
- **Dependencies**: None beyond a standard KDE Plasma desktop

## Related

- [asus-ux510-fan2](https://github.com/nhilo94/asus-ux510-fan2) — Hidden GPU fan controller for the same laptop

## License

MIT
