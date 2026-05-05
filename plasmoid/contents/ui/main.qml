import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: root

    // Battery
    property string cycles: "—"
    property string capacity: "—"
    property string energyFull: "0"
    property string energyFullDesign: "0"
    property string batteryStatus: "—"
    property string healthPercent: "0"
    property string batteryVoltage: "—"

    // CPU temps
    property string cpuPackageTemp: "—"
    property string cpuCore0Temp: "—"
    property string cpuCore1Temp: "—"

    // Fans
    property string fan1Rpm: "—"
    property string fan2Status: "—"

    // Other sensors
    property string acpiTemp: "—"
    property string pchTemp: "—"
    property string wifiTemp: "—"

    // System
    property string cpuLoad: "—"
    property string ramUsed: "—"
    property string ramTotal: "—"
    property string cpuFreq: "—"

    // Panel: compact icon, click opens popup
    // Desktop: full widget shown directly
    Plasmoid.preferredRepresentation: plasmoid.formFactor === PlasmaCore.Types.Planar
        ? Plasmoid.fullRepresentation
        : Plasmoid.compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground

    PlasmaCore.DataSource {
        id: dataSource
        engine: "executable"
        connectedSources: []

        property string cmd: "bash -c '" +
            "echo CYCLES=$(cat /sys/class/power_supply/BAT0/cycle_count 2>/dev/null || echo 0);" +
            "echo CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0);" +
            "echo EFULL=$(cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null || echo 0);" +
            "echo EDESIGN=$(cat /sys/class/power_supply/BAT0/energy_full_design 2>/dev/null || echo 0);" +
            "echo STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown);" +
            "echo VOLTAGE=$(cat /sys/class/power_supply/BAT0/voltage_now 2>/dev/null || echo 0);" +
            "echo CPULOAD=$(vmstat 1 2 | tail -1 | awk \"{print 100-\\$15}\");" +
            "free -m | awk \"/^Mem:/{print \\\"RAMUSED=\\\" \\$3; print \\\"RAMTOTAL=\\\" \\$2}\";" +
            "echo CPUFREQ=$(grep \"cpu MHz\" /proc/cpuinfo | awk \"{sum+=\\$4; count++} END{printf \\\"%.1f\\\", sum/count/1000}\");" +
            "for h in /sys/class/hwmon/hwmon*; do " +
            "  n=$(cat $h/name 2>/dev/null); " +
            "  if [ \"$n\" = asus ] && [ -f $h/fan1_input ]; then echo FAN1=$(cat $h/fan1_input); fi; " +
            "  if [ \"$n\" = coretemp ]; then " +
            "    [ -f $h/temp1_input ] && echo CPUPKG=$(cat $h/temp1_input); " +
            "    [ -f $h/temp2_input ] && echo CORE0=$(cat $h/temp2_input); " +
            "    [ -f $h/temp3_input ] && echo CORE1=$(cat $h/temp3_input); " +
            "  fi; " +
            "  [ \"$n\" = acpitz ] && [ -f $h/temp1_input ] && echo ACPI=$(cat $h/temp1_input); " +
            "  [ \"$n\" = pch_skylake ] && [ -f $h/temp1_input ] && echo PCH=$(cat $h/temp1_input); " +
            "  [ \"$n\" = iwlwifi_1 ] && [ -f $h/temp1_input ] && echo WIFI=$(cat $h/temp1_input); " +
            "done" +
            "'"

        onNewData: {
            var lines = data.stdout.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var eq = lines[i].indexOf("=");
                if (eq < 1) continue;
                var key = lines[i].substring(0, eq);
                var val = lines[i].substring(eq + 1).trim();
                if (key === "CYCLES") cycles = val;
                else if (key === "CAPACITY") capacity = val;
                else if (key === "EFULL") { energyFull = val; updateHealth(); }
                else if (key === "EDESIGN") { energyFullDesign = val; updateHealth(); }
                else if (key === "STATUS") batteryStatus = val;
                else if (key === "VOLTAGE") batteryVoltage = (parseInt(val) / 1e6).toFixed(2);
                else if (key === "CPULOAD") cpuLoad = val;
                else if (key === "RAMUSED") ramUsed = val;
                else if (key === "RAMTOTAL") ramTotal = val;
                else if (key === "CPUFREQ") cpuFreq = val;
                else if (key === "CPUPKG") cpuPackageTemp = (parseInt(val) / 1000).toFixed(0);
                else if (key === "CORE0") cpuCore0Temp = (parseInt(val) / 1000).toFixed(0);
                else if (key === "CORE1") cpuCore1Temp = (parseInt(val) / 1000).toFixed(0);
                else if (key === "FAN1") fan1Rpm = val;
                else if (key === "ACPI") acpiTemp = (parseInt(val) / 1000).toFixed(0);
                else if (key === "PCH") pchTemp = (parseInt(val) / 1000).toFixed(0);
                else if (key === "WIFI") wifiTemp = (parseInt(val) / 1000).toFixed(0);
            }
            disconnectSource(sourceName);
        }
    }

    function updateHealth() {
        var full = parseFloat(energyFull);
        var design = parseFloat(energyFullDesign);
        if (design > 0) healthPercent = (full / design * 100).toFixed(1);
    }

    function cpuTempColor(t) {
        var v = parseInt(t); if (isNaN(v)) return PlasmaCore.Theme.textColor;
        if (v >= 90) return "#ef4444";
        if (v >= 80) return "#f97316";
        if (v >= 60) return "#fbbf24";
        return "#4ade80";
    }
    function cpuLoadColor(l) {
        var v = parseInt(l); if (isNaN(v)) return PlasmaCore.Theme.textColor;
        if (v >= 90) return "#ef4444";
        if (v >= 70) return "#f97316";
        if (v >= 50) return "#fbbf24";
        return "#4ade80";
    }
    function ramColor(used, total) {
        var u = parseInt(used); var t = parseInt(total);
        if (isNaN(u) || isNaN(t) || t === 0) return PlasmaCore.Theme.textColor;
        var pct = u * 100 / t;
        if (pct >= 90) return "#ef4444";
        if (pct >= 75) return "#f97316";
        if (pct >= 50) return "#fbbf24";
        return "#4ade80";
    }
    function pchTempColor(t) {
        var v = parseInt(t); if (isNaN(v)) return PlasmaCore.Theme.textColor;
        if (v >= 80) return "#f97316";
        if (v >= 65) return "#fbbf24";
        return "#4ade80";
    }
    function wifiTempColor(t) {
        var v = parseInt(t); if (isNaN(v)) return PlasmaCore.Theme.textColor;
        if (v >= 55) return "#f97316";
        if (v >= 45) return "#fbbf24";
        return "#4ade80";
    }
    function fanRpmColor(r) {
        var v = parseInt(r); if (isNaN(v)) return PlasmaCore.Theme.textColor;
        if (v >= 4000) return "#f97316";
        if (v >= 2000) return "#4ade80";
        return "#60a5fa";
    }
    function healthColor() {
        var h = parseFloat(healthPercent);
        if (h >= 80) return "#4ade80";
        if (h >= 50) return "#fbbf24";
        return "#ef4444";
    }
    function statusIcon() {
        if (batteryStatus === "Charging") return "⚡";
        if (batteryStatus === "Discharging") return "🔋";
        if (batteryStatus === "Full") return "✅";
        return "🔌";
    }
    function statusColor() {
        if (batteryStatus === "Charging") return "#4ade80";
        if (batteryStatus === "Discharging") return "#fbbf24";
        if (batteryStatus === "Full") return "#4ade80";
        return "#60a5fa";
    }
    function tempLevel(t) {
        var v = parseInt(t); if (isNaN(v)) return "";
        if (v >= 90) return "  ⛔ DANGER";
        if (v >= 80) return "  🔥 HIGH";
        if (v >= 60) return "  ⚠ WARM";
        return "  ✅ OK";
    }
    function panelIconColor() {
        var v = parseInt(cpuPackageTemp);
        if (isNaN(v)) return PlasmaCore.Theme.textColor;
        if (v >= 90) return "#ef4444";
        if (v >= 80) return "#f97316";
        if (v >= 60) return "#fbbf24";
        return "#4ade80";
    }
    function ramGb(mb) {
        var v = parseInt(mb);
        return isNaN(v) ? "—" : (v / 1024).toFixed(1);
    }
    function ramPct() {
        var u = parseInt(ramUsed); var t = parseInt(ramTotal);
        if (isNaN(u) || isNaN(t) || t === 0) return "—";
        return (u * 100 / t).toFixed(0);
    }

    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: dataSource.connectSource(dataSource.cmd)
    }

    // ══════════ COMPACT: panel icon, click opens popup ══════════
    Plasmoid.compactRepresentation: Item {
        id: compactRoot
        Layout.minimumWidth: row.implicitWidth + 6
        Layout.preferredWidth: row.implicitWidth + 6
        Layout.minimumHeight: units.iconSizes.small

        MouseArea {
            anchors.fill: parent
            onClicked: plasmoid.expanded = !plasmoid.expanded
            hoverEnabled: true

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 6

                PlasmaCore.IconItem {
                    source: "computer"
                    implicitWidth: units.iconSizes.small
                    implicitHeight: units.iconSizes.small
                }

                PlasmaComponents.Label {
                    text: root.cpuPackageTemp + "°"
                    font.pixelSize: 12; font.bold: true
                    color: panelIconColor()
                }

                RowLayout {
                    spacing: 4
                    Text { text: "⚙"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter; color: cpuLoadColor(root.cpuLoad) }
                    PlasmaComponents.Label {
                        text: root.cpuLoad + "%"
                        font.pixelSize: 12; font.bold: true
                        color: cpuLoadColor(root.cpuLoad)
                    }
                }

                RowLayout {
                    spacing: 4
                    Text { text: "💾"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter; color: ramColor(root.ramUsed, root.ramTotal) }
                    PlasmaComponents.Label {
                        text: ramGb(root.ramUsed) + "Go"
                        font.pixelSize: 12; font.bold: true
                        color: ramColor(root.ramUsed, root.ramTotal)
                    }
                }

                RowLayout {
                    spacing: 4
                    Text { text: "⚡"; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter; color: "#60a5fa" }
                    PlasmaComponents.Label {
                        text: root.cpuFreq + "Ghz"
                        font.pixelSize: 12; font.bold: true
                        color: "#60a5fa"
                    }
                }
            }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: "PC Monitor"
            subText: "CPU: " + root.cpuPackageTemp + "°C | Load: " + root.cpuLoad + "% | Fréq: " + root.cpuFreq + " GHz\n" +
                     "RAM: " + ramGb(root.ramUsed) + " / " + ramGb(root.ramTotal) + " Go (" + ramPct() + "%)\n" +
                     "Fan: " + root.fan1Rpm + " RPM | Batterie: " + root.capacity + "% (" + root.batteryStatus + ")\n" +
                     "Santé: " + root.healthPercent + "%"
        }
    }

    // ══════════ FULL: popup / desktop widget ══════════
    Plasmoid.fullRepresentation: ColumnLayout {
        Layout.preferredWidth: 300
        Layout.preferredHeight: implicitHeight + 16
        Layout.minimumWidth: 280
        spacing: 5

        // Header
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: statusIcon() + "  PC Monitor"
            font.pixelSize: 15; font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        // ── BATTERY ──
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        PlasmaComponents.Label {
            text: "🔋  Battery"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8
        }
        GridLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
            columns: 2; rowSpacing: 3; columnSpacing: 8

            PlasmaComponents.Label { text: "Cycles"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.cycles; font.bold: true; font.pixelSize: 12 }

            PlasmaComponents.Label { text: "Capacité"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.capacity + "%"; font.bold: true; font.pixelSize: 12 }

            PlasmaComponents.Label { text: "Santé"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.healthPercent + "%"; font.bold: true; font.pixelSize: 12; color: healthColor() }

            PlasmaComponents.Label { text: "Énergie"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label {
                text: (parseFloat(root.energyFull)/1e6).toFixed(1) + " / " + (parseFloat(root.energyFullDesign)/1e6).toFixed(1) + " Wh"
                font.bold: true; font.pixelSize: 12
            }

            PlasmaComponents.Label { text: "Tension"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.batteryVoltage + " V"; font.bold: true; font.pixelSize: 12 }

            PlasmaComponents.Label { text: "Status"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.batteryStatus; font.bold: true; font.pixelSize: 12; color: statusColor() }
        }
        // Health bar
        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 16; Layout.leftMargin: 12; Layout.rightMargin: 12
            Rectangle { anchors.fill: parent; radius: 3; color: PlasmaCore.Theme.textColor; opacity: 0.08 }
            Rectangle {
                width: parent.width * Math.min(parseFloat(root.healthPercent), 100) / 100
                height: parent.height; radius: 3; color: healthColor(); opacity: 0.7
                Behavior on width { NumberAnimation { duration: 400 } }
            }
            PlasmaComponents.Label { anchors.centerIn: parent; text: "Santé: " + root.healthPercent + "%"; font.pixelSize: 10; font.bold: true }
        }

        // ── CPU ──
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        PlasmaComponents.Label { text: "🌡  CPU — coretemp"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }
        GridLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
            columns: 2; rowSpacing: 3; columnSpacing: 8

            PlasmaComponents.Label { text: "Package"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.cpuPackageTemp + "°C" + tempLevel(root.cpuPackageTemp); font.bold: true; font.pixelSize: 12; color: cpuTempColor(root.cpuPackageTemp) }

            PlasmaComponents.Label { text: "Core 0"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.cpuCore0Temp + "°C" + tempLevel(root.cpuCore0Temp); font.bold: true; font.pixelSize: 12; color: cpuTempColor(root.cpuCore0Temp) }

            PlasmaComponents.Label { text: "Core 1"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.cpuCore1Temp + "°C" + tempLevel(root.cpuCore1Temp); font.bold: true; font.pixelSize: 12; color: cpuTempColor(root.cpuCore1Temp) }

            PlasmaComponents.Label { text: "Charge"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.cpuLoad + "%"; font.bold: true; font.pixelSize: 12; color: cpuLoadColor(root.cpuLoad) }

            PlasmaComponents.Label { text: "Fréquence"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.cpuFreq + " GHz"; font.bold: true; font.pixelSize: 12; color: "#60a5fa" }
        }
        // CPU load bar
        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 16; Layout.leftMargin: 12; Layout.rightMargin: 12
            Rectangle { anchors.fill: parent; radius: 3; color: PlasmaCore.Theme.textColor; opacity: 0.08 }
            Rectangle {
                width: parent.width * Math.min(parseInt(root.cpuLoad) || 0, 100) / 100
                height: parent.height; radius: 3; color: cpuLoadColor(root.cpuLoad); opacity: 0.7
                Behavior on width { NumberAnimation { duration: 400 } }
            }
            PlasmaComponents.Label { anchors.centerIn: parent; text: "CPU: " + root.cpuLoad + "%"; font.pixelSize: 10; font.bold: true }
        }

        // ── RAM ──
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        PlasmaComponents.Label { text: "💾  Mémoire RAM"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }
        GridLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
            columns: 2; rowSpacing: 3; columnSpacing: 8

            PlasmaComponents.Label { text: "Utilisée"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label {
                text: ramGb(root.ramUsed) + " / " + ramGb(root.ramTotal) + " Go"
                font.bold: true; font.pixelSize: 12; color: ramColor(root.ramUsed, root.ramTotal)
            }
        }
        // RAM bar
        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 16; Layout.leftMargin: 12; Layout.rightMargin: 12
            Rectangle { anchors.fill: parent; radius: 3; color: PlasmaCore.Theme.textColor; opacity: 0.08 }
            Rectangle {
                width: {
                    var u = parseInt(root.ramUsed); var t = parseInt(root.ramTotal);
                    return (isNaN(u) || isNaN(t) || t === 0) ? 0 : parent.width * Math.min(u, t) / t;
                }
                height: parent.height; radius: 3; color: ramColor(root.ramUsed, root.ramTotal); opacity: 0.7
                Behavior on width { NumberAnimation { duration: 400 } }
            }
            PlasmaComponents.Label { anchors.centerIn: parent; text: "RAM: " + ramPct() + "%"; font.pixelSize: 10; font.bold: true }
        }

        // ── FANS ──
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        PlasmaComponents.Label { text: "💨  Fans"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }
        GridLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
            columns: 2; rowSpacing: 3; columnSpacing: 8

            PlasmaComponents.Label { text: "CPU Fan"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.fan1Rpm + " RPM"; font.bold: true; font.pixelSize: 12; color: fanRpmColor(root.fan1Rpm) }

            PlasmaComponents.Label { text: "GPU Fan"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.fan2Status !== "—" ? root.fan2Status : "N/A"; font.bold: true; font.pixelSize: 12; color: root.fan2Status === "ON" ? "#4ade80" : "#60a5fa" }
        }

        // ── OTHER SENSORS ──
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        PlasmaComponents.Label { text: "📊  Other Sensors"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }
        GridLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
            columns: 2; rowSpacing: 3; columnSpacing: 8

            PlasmaComponents.Label { text: "ACPI (Chassis)"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.acpiTemp + "°C"; font.bold: true; font.pixelSize: 12; color: cpuTempColor(root.acpiTemp) }

            PlasmaComponents.Label { text: "PCH (Chipset)"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.pchTemp + "°C"; font.bold: true; font.pixelSize: 12; color: pchTempColor(root.pchTemp) }

            PlasmaComponents.Label { text: "WiFi (iwlwifi)"; opacity: 0.6; font.pixelSize: 12 }
            PlasmaComponents.Label { text: root.wifiTemp + "°C"; font.bold: true; font.pixelSize: 12; color: wifiTempColor(root.wifiTemp) }
        }

        // ── LEGEND ──
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 12
            PlasmaComponents.Label { text: "✅ OK"; font.pixelSize: 10; color: "#4ade80" }
            PlasmaComponents.Label { text: "⚠ Warm"; font.pixelSize: 10; color: "#fbbf24" }
            PlasmaComponents.Label { text: "🔥 High"; font.pixelSize: 10; color: "#f97316" }
            PlasmaComponents.Label { text: "⛔ Danger"; font.pixelSize: 10; color: "#ef4444" }
        }

        Item { Layout.fillHeight: true }
    }
}
