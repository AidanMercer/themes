import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// lonely-train: bottom route strip. Station-sign plates (amber band along the
// top edge, night glass below) carry three clusters:
//   left   — LT line roundel (click: control popup) + a cassette now-playing
//            chip whose reels spin while music plays, tape counter progress
//   center — the route map: ten station dots on a line, a little lit train
//            slides to whichever station (workspace) you're stopped at
//   right  — net + battery + the time as a small platform clock
// Self-contained: hyprland via Quickshell.Hyprland, /proc + nmcli polled here.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color tail:  pal.magenta
    readonly property color warn:  pal.amber
    readonly property color dim:   pal.dim
    readonly property color ink:   pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // hover flag shared with sysinfo.qml — it watches this file and lights the
    // arrivals board while it reads "1"
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    // boot-in: plates rise from the platform edge
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 750; easing.type: Easing.OutCubic }
    readonly property real bootLate: Math.max(0, (bootT - 0.3) / 0.7)

    // a station-sign plate: night glass with the line-color band on top
    component Plate: Rectangle {
        radius: 7
        color: root.glassA(0.72)
        border.width: 1
        border.color: root.inkA(0.08)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 2
            radius: 1
            color: root.amberA(0.75)
        }
    }

    // ── net + battery polling ───────────────────────────────────────────────
    property bool online: false
    property string connType: ""
    property int batteryPercent: -1
    property bool batteryCharging: false
    property bool hasBattery: false

    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = true; batProc.running = true }
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseNet(text) }
    }
    function parseNet(raw) {
        const line = raw.trim()
        if (!line) { online = false; connType = ""; return }
        const t = line.slice(line.lastIndexOf(":") + 1)
        connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
        online = true
    }
    Process {
        id: batProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseBattery(text) }
    }
    function parseBattery(raw) {
        const lines = raw.trim().split("\n")
        const cap = parseInt(lines[0])
        if (lines[0] === "" || isNaN(cap)) { hasBattery = false; return }
        hasBattery = true
        batteryPercent = cap
        batteryCharging = (lines[1] || "").trim() === "Charging"
    }
    function batteryGlyph(level, charging) {
        if (charging) return String.fromCodePoint(0xF0084)
        if (level >= 95) return String.fromCodePoint(0xF0079)
        if (level < 10) return String.fromCodePoint(0xF0083)
        return String.fromCodePoint(0xF0079 + Math.floor(level / 10))
    }

    // ── left: LT roundel + cassette now-playing ─────────────────────────────
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 5 * (1 - root.bootT)
        opacity: root.bootT
        spacing: 8

        // the line roundel — station logo, toggles the control popup
        Plate {
            width: 30; height: 30
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 18; height: 18
                radius: 9
                color: "transparent"
                border.width: 2
                border.color: roundelMa.containsMouse ? root.amber : root.amberA(0.75)
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "LT"
                    color: root.amber
                    font.family: root.mono
                    font.pixelSize: 7
                    font.weight: Font.Black
                }
            }
            MouseArea {
                id: roundelMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }

        // cassette chip: spinning reels + track, progress as the tape winding
        Plate {
            id: media
            readonly property var player: {
                const ps = Mpris.players.values
                if (ps.length === 0) return null
                return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
            }
            readonly property bool active: player !== null
            readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing

            visible: active
            height: 30
            width: active ? mediaRow.width + 22 : 0
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.bootLate

            property real progress: 0
            property real reelSpin: 0
            function updateProgress() {
                const p = media.player
                media.progress = (p && p.length > 0 && p.position >= 0)
                    ? Math.min(1, p.position / p.length) : 0
            }
            Timer {
                interval: 1000; repeat: true
                running: media.playing
                triggeredOnStart: true
                onTriggered: media.updateProgress()
            }
            NumberAnimation on reelSpin {
                running: media.playing
                loops: Animation.Infinite
                from: 0; to: 360; duration: 2600
            }

            Row {
                id: mediaRow
                anchors.centerIn: parent
                spacing: 8

                // the two reels — the left pack empties as the right fills
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: 2
                        Item {
                            required property int index
                            width: 14; height: 14
                            // tape pack thickness follows track progress
                            readonly property real pack: index === 0 ? 1 - media.progress : media.progress
                            Rectangle {   // pack
                                anchors.centerIn: parent
                                width: 6 + 7 * parent.pack; height: width
                                radius: width / 2
                                color: root.duskA(0.35)
                                Behavior on width { NumberAnimation { duration: 800 } }
                            }
                            Rectangle {   // hub
                                anchors.centerIn: parent
                                width: 7; height: 7
                                radius: 3.5
                                color: "transparent"
                                border.width: 1.4
                                border.color: root.amberA(0.9)
                                rotation: media.reelSpin
                                Rectangle { width: 1.4; height: parent.height; anchors.centerIn: parent; color: root.amberA(0.9) }
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 210)
                    elide: Text.ElideRight
                    text: {
                        if (!media.active) return ""
                        const t = media.player.trackTitle || "—"
                        const a = media.player.trackArtist
                        return a ? t + "  ·  " + a : t
                    }
                    textFormat: Text.PlainText
                    color: root.duskA(0.95)
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 0.5
                }
            }

            // tape counter underline
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 4
                anchors.bottomMargin: 2
                height: 2
                radius: 1
                width: Math.max(0, (parent.width - 8) * media.progress)
                color: root.amberA(0.8)
                Behavior on width { NumberAnimation { duration: 900 } }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (media.active && media.player.canTogglePlaying) media.player.togglePlaying()
                onWheel: (w) => {
                    if (!media.active) return
                    if (w.modifiers & Qt.ShiftModifier) {
                        Quickshell.execDetached(["qs", "ipc", "call", "lyricOffset",
                            w.angleDelta.y > 0 ? "earlier" : "later"])
                        return
                    }
                    if (w.angleDelta.y > 0 && media.player.canGoNext) media.player.next()
                    else if (w.angleDelta.y < 0 && media.player.canGoPrevious) media.player.previous()
                }
            }
        }
    }

    // ── center: the route map ───────────────────────────────────────────────
    Plate {
        id: routePlate
        height: 30
        width: wsRow.width + 34
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 5 * (1 - root.bootT)
        opacity: root.bootT

        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property int activeSlot: activeWsId - pageBase

        // keep the .desktop database observed so heuristicLookup() works
        readonly property int _keepAlive: DesktopEntries.applications.values.length

        function iconForClass(cls) {
            if (!cls) return ""
            const entry = DesktopEntries.heuristicLookup(cls)
            const name = (entry && entry.icon) ? entry.icon : cls.toLowerCase()
            return Quickshell.iconPath(name, "application-x-executable")
        }
        function iconForWindows(wins) {
            let best = null, bestFh = Infinity
            for (const w of wins) {
                const cls = w.lastIpcObject?.class ?? ""
                if (!cls) continue
                const fh = w.lastIpcObject?.focusHistoryID ?? Infinity
                if (fh < bestFh) { best = w; bestFh = fh }
            }
            return best ? iconForClass(best.lastIpcObject.class)
                        : Quickshell.iconPath("application-x-executable")
        }

        // keep toplevels fresh so occupied stations stay lit
        Component.onCompleted: Hyprland.refreshToplevels()
        Connections {
            target: Hyprland
            function onRawEvent(event) {
                switch (event.name) {
                case "openwindow":
                case "closewindow":
                case "movewindow":
                case "movewindowv2":
                case "activewindowv2":
                    Hyprland.refreshToplevels()
                }
            }
        }

        // the continuous line under the dots
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: wsRow.width - 6
            height: 2
            color: root.duskA(0.4)
        }

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: routePlate.wsCount
                delegate: Item {
                    id: slot
                    required property int index
                    readonly property int wsId: routePlate.pageBase + index
                    readonly property bool isActive: routePlate.activeWsId === wsId
                    readonly property var windowsHere: Hyprland.toplevels.values
                        .filter(t => (t.workspace?.id ?? -1) === wsId)
                    readonly property bool isOccupied: windowsHere.length > 0

                    width: 26
                    height: 28

                    // empty station: a hollow halt on the line
                    Rectangle {
                        anchors.centerIn: parent
                        visible: !slot.isOccupied
                        width: 6; height: 6
                        radius: 3
                        color: "transparent"
                        border.width: 1.4
                        border.color: root.duskA(0.65)
                        opacity: slot.isActive ? 0 : 1     // the train parks on top
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    // occupied station: the app waiting on the platform
                    IconImage {
                        anchors.centerIn: parent
                        visible: slot.isOccupied
                        width: 15; height: 15
                        source: slot.isOccupied ? routePlate.iconForWindows(slot.windowsHere) : ""
                        opacity: slot.isActive ? 0 : 0.9   // the train parks on top
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                    }
                }
            }
        }

        // the train — slides along the line to the active station
        Item {
            id: trainCar
            width: 18; height: 9
            anchors.verticalCenter: parent.verticalCenter
            x: wsRow.x + routePlate.activeSlot * 26 + (26 - width) / 2
            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: 4.5
                color: root.amber
            }
            // two lit windows
            Row {
                anchors.centerIn: parent
                spacing: 2
                Rectangle { width: 4; height: 3; radius: 1; color: Qt.rgba(0, 0, 0, 0.55) }
                Rectangle { width: 4; height: 3; radius: 1; color: Qt.rgba(0, 0, 0, 0.55) }
            }
        }
    }

    // ── right: net · battery · platform clock ───────────────────────────────
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 5 * (1 - root.bootT)
        opacity: root.bootT
        spacing: 8

        Plate {
            height: 30
            width: statusRow.width + 22
            anchors.verticalCenter: parent.verticalCenter

            // hovering the guard's panel lights the arrivals board
            // (sysinfo.qml watches the shared hover flag file)
            HoverHandler {
                onHoveredChanged: sysFlag.setText(hovered ? "1" : "0")
            }

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.online
                        ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                        : String.fromCodePoint(0xF092F)
                    font.family: root.icon
                    font.pixelSize: 12
                    color: root.online ? root.duskA(0.9) : root.tail
                }

                Row {
                    visible: root.hasBattery
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryGlyph(root.batteryPercent, root.batteryCharging)
                        font.family: root.icon
                        font.pixelSize: 12
                        color: root.batteryCharging ? root.dusk
                            : root.batteryPercent <= 15 ? root.tail
                            : root.batteryPercent <= 30 ? root.warn : root.amberA(0.9)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryPercent >= 0 ? root.batteryPercent + "%" : ""
                        color: root.inkA(0.6)
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 14
                    color: root.inkA(0.14)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: root.inkA(0.92)
                    font.family: root.mono
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd dd").toUpperCase()
                    color: root.duskA(0.65)
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 2
                }
            }
        }
    }
}
