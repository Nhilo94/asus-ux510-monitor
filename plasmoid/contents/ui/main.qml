import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: root

    // ── Static properties ─────────────────────────────────────────────────
    property bool   hasBattery:        false
    property string cycles:            "—"
    property string capacity:          "—"
    property string energyFull:        "0"
    property string energyFullDesign:  "0"
    property string batteryStatus:     "—"
    property string healthPercent:     "0"
    property string batteryVoltage:    "—"
    property string cpuLoad:           "—"
    property string ramUsed:           "—"
    property string ramTotal:          "—"
    property string cpuFreq:           "—"
    property string cpuPkgTemp:        "—"   // best CPU temp for compact view

    // ── Dynamic sensor models ─────────────────────────────────────────────
    ListModel { id: cpuTempsModel }
    ListModel { id: gpuTempsModel }
    ListModel { id: fanModel }
    ListModel { id: otherSensorsModel }

    // ── Script path ───────────────────────────────────────────────────────
    property string scriptPath: Qt.resolvedUrl("../code/monitor.sh").toString().replace("file://", "")

    Plasmoid.preferredRepresentation: plasmoid.formFactor === PlasmaCore.Types.Planar
        ? Plasmoid.fullRepresentation
        : Plasmoid.compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground

    // ── Data source ───────────────────────────────────────────────────────
    PlasmaCore.DataSource {
        id: dataSource
        engine: "executable"
        connectedSources: []

        onNewData: {
            var lines = data.stdout.split("\n")
            var newCpu = [], newGpu = [], newFans = [], newOther = []
            var tempBat = false

            for (var i = 0; i < lines.length; i++) {
                var eq = lines[i].indexOf("=")
                if (eq < 1) continue
                var k = lines[i].substring(0, eq)
                var v = lines[i].substring(eq + 1).trim()

                if      (k === "HAS_BAT")  { tempBat = true }
                else if (k === "CYCLES")   { cycles = v }
                else if (k === "CAPACITY") { capacity = v }
                else if (k === "EFULL")    { energyFull = v;       updateHealth() }
                else if (k === "EDESIGN")  { energyFullDesign = v; updateHealth() }
                else if (k === "STATUS")   { batteryStatus = v }
                else if (k === "VOLTAGE")  { batteryVoltage = (parseInt(v) / 1e6).toFixed(2) }
                else if (k === "CPULOAD")  { cpuLoad = v }
                else if (k === "RAMUSED")  { ramUsed = v }
                else if (k === "RAMTOTAL") { ramTotal = v }
                else if (k === "CPUFREQ")  { cpuFreq = v }
                else if (k.indexOf("CPUTEMP_") === 0) {
                    var cpuLbl = k.substring(8).replace(/_/g, " ")
                    var cpuTc  = (parseInt(v) / 1000).toFixed(0)
                    newCpu.push({ label: cpuLbl, value: cpuTc, color: cpuTempColor(parseInt(cpuTc)) })
                }
                else if (k.indexOf("GPUTEMP_") === 0) {
                    var gpuLbl = k.substring(8).replace(/_/g, " ")
                    var gpuTc  = (parseInt(v) / 1000).toFixed(0)
                    newGpu.push({ label: gpuLbl, value: gpuTc, color: gpuTempColor(parseInt(gpuTc)) })
                }
                else if (k.indexOf("FAN_") === 0) {
                    var fanLbl = k.substring(4).replace(/_/g, " ")
                    var rpm    = parseInt(v)
                    newFans.push({ label: fanLbl, value: isNaN(rpm) ? "—" : rpm.toString(), color: fanRpmColor(rpm) })
                }
                else if (k.indexOf("OTHTEMP_") === 0) {
                    var othLbl = k.substring(8).replace(/_/g, " ")
                    var othTc  = (parseInt(v) / 1000).toFixed(0)
                    newOther.push({ label: othLbl, value: othTc, color: otherTempColor(parseInt(othTc)) })
                }
            }

            hasBattery = tempBat

            // Pick the most representative CPU temp for the compact view
            if (newCpu.length > 0) {
                cpuPkgTemp = newCpu[0].value
                for (var j = 0; j < newCpu.length; j++) {
                    var ll = newCpu[j].label.toLowerCase()
                    if (ll.indexOf("package") >= 0 || ll.indexOf("tdie") >= 0 || ll.indexOf("tctl") >= 0) {
                        cpuPkgTemp = newCpu[j].value
                        break
                    }
                }
            }

            updateModel(cpuTempsModel,    newCpu)
            updateModel(gpuTempsModel,    newGpu)
            updateModel(fanModel,         newFans)
            updateModel(otherSensorsModel, newOther)

            disconnectSource(sourceName)
        }
    }

    function updateModel(mdl, items) {
        mdl.clear()
        for (var i = 0; i < items.length; i++) mdl.append(items[i])
    }

    function updateHealth() {
        var full = parseFloat(energyFull)
        var design = parseFloat(energyFullDesign)
        if (design > 0) healthPercent = (full / design * 100).toFixed(1)
    }

    // ── Color helpers ─────────────────────────────────────────────────────
    function cpuTempColor(t) {
        var v = parseInt(t); if (isNaN(v)) return PlasmaCore.Theme.textColor
        if (v >= 90) return "#ef4444"; if (v >= 80) return "#f97316"
        if (v >= 60) return "#fbbf24"; return "#4ade80"
    }
    function gpuTempColor(t) {
        var v = parseInt(t); if (isNaN(v)) return PlasmaCore.Theme.textColor
        if (v >= 85) return "#ef4444"; if (v >= 75) return "#f97316"
        if (v >= 60) return "#fbbf24"; return "#4ade80"
    }
    function otherTempColor(t) {
        var v = parseInt(t); if (isNaN(v)) return PlasmaCore.Theme.textColor
        if (v >= 80) return "#ef4444"; if (v >= 60) return "#f97316"
        if (v >= 45) return "#fbbf24"; return "#4ade80"
    }
    function cpuLoadColor(l) {
        var v = parseInt(l); if (isNaN(v)) return PlasmaCore.Theme.textColor
        if (v >= 90) return "#ef4444"; if (v >= 70) return "#f97316"
        if (v >= 50) return "#fbbf24"; return "#4ade80"
    }
    function ramColor(used, total) {
        var u = parseInt(used); var t = parseInt(total)
        if (isNaN(u) || isNaN(t) || t === 0) return PlasmaCore.Theme.textColor
        var pct = u * 100 / t
        if (pct >= 90) return "#ef4444"; if (pct >= 75) return "#f97316"
        if (pct >= 50) return "#fbbf24"; return "#4ade80"
    }
    function fanRpmColor(r) {
        var v = parseInt(r); if (isNaN(v)) return PlasmaCore.Theme.textColor
        if (v >= 4000) return "#f97316"; if (v >= 2000) return "#4ade80"
        return "#60a5fa"
    }
    function healthColor() {
        var h = parseFloat(healthPercent)
        if (h >= 80) return "#4ade80"; if (h >= 50) return "#fbbf24"; return "#ef4444"
    }
    function statusIcon() {
        if (batteryStatus === "Charging")    return "⚡"
        if (batteryStatus === "Discharging") return "🔋"
        if (batteryStatus === "Full")        return "✅"
        return "🔌"
    }
    function statusColor() {
        if (batteryStatus === "Charging")    return "#4ade80"
        if (batteryStatus === "Discharging") return "#fbbf24"
        if (batteryStatus === "Full")        return "#4ade80"
        return "#60a5fa"
    }
    function tempLevel(t) {
        var v = parseInt(t); if (isNaN(v)) return ""
        if (v >= 90) return "  ⛔ DANGER"; if (v >= 80) return "  🔥 HIGH"
        if (v >= 60) return "  ⚠ WARM";   return "  ✅ OK"
    }
    function ramGb(mb) {
        var v = parseInt(mb); return isNaN(v) ? "—" : (v / 1024).toFixed(1)
    }
    function ramPct() {
        var u = parseInt(ramUsed); var t = parseInt(ramTotal)
        if (isNaN(u) || isNaN(t) || t === 0) return "—"
        return (u * 100 / t).toFixed(0)
    }

    // ── Polling timer (5 s) ───────────────────────────────────────────────
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: dataSource.connectSource("bash " + scriptPath)
    }

    // ══════════════════════════════════════════════════════════════════════
    // COMPACT — panel icon, click opens popup
    // ══════════════════════════════════════════════════════════════════════
    Plasmoid.compactRepresentation: Item {
        Layout.minimumWidth:  compactRow.implicitWidth + 6
        Layout.preferredWidth: compactRow.implicitWidth + 6
        Layout.minimumHeight: 22

        MouseArea {
            anchors.fill: parent
            onClicked: plasmoid.expanded = !plasmoid.expanded
            hoverEnabled: true

            RowLayout {
                id: compactRow
                anchors.centerIn: parent
                spacing: 12

                PlasmaCore.IconItem {
                    source: "computer"
                    implicitWidth: 16
                    implicitHeight: 16
                }

                PlasmaComponents.Label {
                    text: root.cpuPkgTemp + "°"
                    font.pixelSize: 12; font.bold: true
                    color: cpuTempColor(parseInt(root.cpuPkgTemp))
                }

                RowLayout {
                    spacing: 4
                    Text { text: "CPU"; font.pixelSize: 9; font.bold: true; verticalAlignment: Text.AlignVCenter; color: cpuLoadColor(root.cpuLoad) }
                    PlasmaComponents.Label { text: root.cpuLoad + "%"; font.pixelSize: 12; font.bold: true; color: cpuLoadColor(root.cpuLoad) }
                }

                RowLayout {
                    spacing: 4
                    Text { text: "RAM"; font.pixelSize: 9; font.bold: true; verticalAlignment: Text.AlignVCenter; color: ramColor(root.ramUsed, root.ramTotal) }
                    PlasmaComponents.Label { text: ramGb(root.ramUsed) + "G"; font.pixelSize: 12; font.bold: true; color: ramColor(root.ramUsed, root.ramTotal) }
                }

                RowLayout {
                    spacing: 4
                    Text { text: "FREQ"; font.pixelSize: 9; font.bold: true; verticalAlignment: Text.AlignVCenter; color: "#60a5fa" }
                    PlasmaComponents.Label { text: root.cpuFreq + "G"; font.pixelSize: 12; font.bold: true; color: "#60a5fa" }
                }
            }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: "PC Monitor"
            subText: "CPU: " + root.cpuPkgTemp + "°C | Load: " + root.cpuLoad + "% | Freq: " + root.cpuFreq + " GHz\n" +
                     "RAM: " + ramGb(root.ramUsed) + " / " + ramGb(root.ramTotal) + " GB (" + ramPct() + "%)" +
                     (fanModel.count > 0 ? "\nFan: " + fanModel.get(0).value + " RPM" : "") +
                     (root.hasBattery ? "\nBattery: " + root.capacity + "% | Health: " + root.healthPercent + "%" : "")
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // FULL — popup or desktop widget
    // ══════════════════════════════════════════════════════════════════════
    Plasmoid.fullRepresentation: ColumnLayout {
        Layout.preferredWidth: 300
        Layout.minimumWidth:   280
        spacing: 5

        // ── Header ──────────────────────────────────────────────────────
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: (root.hasBattery ? statusIcon() + "  " : "🖥  ") + "PC Monitor"
            font.pixelSize: 15; font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        // ── BATTERY (hidden on desktop PCs without a battery) ────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: root.hasBattery

            Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
            PlasmaComponents.Label { text: "🔋  Battery"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }

            GridLayout {
                Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                columns: 2; rowSpacing: 3; columnSpacing: 8

                PlasmaComponents.Label { text: "Cycles";   opacity: 0.6; font.pixelSize: 12 }
                PlasmaComponents.Label { text: root.cycles; font.bold: true; font.pixelSize: 12 }

                PlasmaComponents.Label { text: "Capacity"; opacity: 0.6; font.pixelSize: 12 }
                PlasmaComponents.Label { text: root.capacity + "%"; font.bold: true; font.pixelSize: 12 }

                PlasmaComponents.Label { text: "Health";   opacity: 0.6; font.pixelSize: 12 }
                PlasmaComponents.Label { text: root.healthPercent + "%"; font.bold: true; font.pixelSize: 12; color: healthColor() }

                PlasmaComponents.Label { text: "Energy";   opacity: 0.6; font.pixelSize: 12 }
                PlasmaComponents.Label {
                    text: (parseFloat(root.energyFull)/1e6).toFixed(1) + " / " + (parseFloat(root.energyFullDesign)/1e6).toFixed(1) + " Wh"
                    font.bold: true; font.pixelSize: 12
                }

                PlasmaComponents.Label { text: "Voltage";  opacity: 0.6; font.pixelSize: 12 }
                PlasmaComponents.Label { text: root.batteryVoltage + " V"; font.bold: true; font.pixelSize: 12 }

                PlasmaComponents.Label { text: "Status";   opacity: 0.6; font.pixelSize: 12 }
                PlasmaComponents.Label { text: root.batteryStatus; font.bold: true; font.pixelSize: 12; color: statusColor() }
            }

            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 16; Layout.leftMargin: 12; Layout.rightMargin: 12
                Rectangle { anchors.fill: parent; radius: 3; color: PlasmaCore.Theme.textColor; opacity: 0.08 }
                Rectangle {
                    width: parent.width * Math.min(parseFloat(root.healthPercent), 100) / 100
                    height: parent.height; radius: 3; color: healthColor(); opacity: 0.7
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
                PlasmaComponents.Label { anchors.centerIn: parent; text: "Health: " + root.healthPercent + "%"; font.pixelSize: 10; font.bold: true }
            }
        }

        // ── CPU ─────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        PlasmaComponents.Label { text: "🌡  CPU"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }

        Repeater {
            model: cpuTempsModel
            delegate: RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                PlasmaComponents.Label { text: model.label; opacity: 0.6; font.pixelSize: 12; Layout.fillWidth: true }
                PlasmaComponents.Label {
                    text: model.value + "°C" + tempLevel(model.value)
                    font.bold: true; font.pixelSize: 12; color: model.color
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
            PlasmaComponents.Label { text: "Load";      opacity: 0.6; font.pixelSize: 12; Layout.fillWidth: true }
            PlasmaComponents.Label { text: root.cpuLoad + "%"; font.bold: true; font.pixelSize: 12; color: cpuLoadColor(root.cpuLoad) }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
            PlasmaComponents.Label { text: "Frequency"; opacity: 0.6; font.pixelSize: 12; Layout.fillWidth: true }
            PlasmaComponents.Label { text: root.cpuFreq + " GHz"; font.bold: true; font.pixelSize: 12; color: "#60a5fa" }
        }

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

        // ── GPU (hidden if no GPU hwmon found) ───────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: gpuTempsModel.count > 0

            Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
            PlasmaComponents.Label { text: "🎮  GPU"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }

            Repeater {
                model: gpuTempsModel
                delegate: RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                    PlasmaComponents.Label { text: model.label; opacity: 0.6; font.pixelSize: 12; Layout.fillWidth: true }
                    PlasmaComponents.Label { text: model.value + "°C"; font.bold: true; font.pixelSize: 12; color: model.color }
                }
            }
        }

        // ── RAM ─────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        PlasmaComponents.Label { text: "◉  RAM"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }

        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
            PlasmaComponents.Label { text: "Used"; opacity: 0.6; font.pixelSize: 12; Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: ramGb(root.ramUsed) + " / " + ramGb(root.ramTotal) + " GB"
                font.bold: true; font.pixelSize: 12; color: ramColor(root.ramUsed, root.ramTotal)
            }
        }

        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 16; Layout.leftMargin: 12; Layout.rightMargin: 12
            Rectangle { anchors.fill: parent; radius: 3; color: PlasmaCore.Theme.textColor; opacity: 0.08 }
            Rectangle {
                width: {
                    var u = parseInt(root.ramUsed); var t = parseInt(root.ramTotal)
                    return (isNaN(u) || isNaN(t) || t === 0) ? 0 : parent.width * Math.min(u, t) / t
                }
                height: parent.height; radius: 3; color: ramColor(root.ramUsed, root.ramTotal); opacity: 0.7
                Behavior on width { NumberAnimation { duration: 400 } }
            }
            PlasmaComponents.Label { anchors.centerIn: parent; text: "RAM: " + ramPct() + "%"; font.pixelSize: 10; font.bold: true }
        }

        // ── FANS (hidden if no fan sensors found) ────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: fanModel.count > 0

            Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
            PlasmaComponents.Label { text: "💨  Fans"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }

            Repeater {
                model: fanModel
                delegate: RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                    PlasmaComponents.Label { text: model.label; opacity: 0.6; font.pixelSize: 12; Layout.fillWidth: true }
                    PlasmaComponents.Label { text: model.value + " RPM"; font.bold: true; font.pixelSize: 12; color: model.color }
                }
            }
        }

        // ── OTHER SENSORS (hidden if none found) ─────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: otherSensorsModel.count > 0

            Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
            PlasmaComponents.Label { text: "📊  Other Sensors"; font.pixelSize: 13; font.bold: true; Layout.leftMargin: 8 }

            Repeater {
                model: otherSensorsModel
                delegate: RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                    PlasmaComponents.Label { text: model.label; opacity: 0.6; font.pixelSize: 12; Layout.fillWidth: true }
                    PlasmaComponents.Label { text: model.value + "°C"; font.bold: true; font.pixelSize: 12; color: model.color }
                }
            }
        }

        // ── Legend ───────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: PlasmaCore.Theme.textColor; opacity: 0.15 }
        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 12
            PlasmaComponents.Label { text: "✅ OK";      font.pixelSize: 10; color: "#4ade80" }
            PlasmaComponents.Label { text: "⚠ Warm";    font.pixelSize: 10; color: "#fbbf24" }
            PlasmaComponents.Label { text: "🔥 High";   font.pixelSize: 10; color: "#f97316" }
            PlasmaComponents.Label { text: "⛔ Danger"; font.pixelSize: 10; color: "#ef4444" }
        }

        Item { Layout.fillHeight: true }
    }
}
