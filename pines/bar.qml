import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// pines: the bar is the instrument sill — the shelf at the foot of the cab's
// glass. A cold slate strip with a survey traverse running through its
// middle: ten benchmark triangles (the workspaces) on a hairline, and the
// kerosene lamp hanging at the active station. The lamp never slides — it
// dissolves into fog at the old station and CONDENSES at the new one (the
// house transition). Apps on a station hang above its mark like sighting
// flags. Left, the wireless set: W/T plate, a breathing valve pip, the
// track, and an ink progress trace on ruled paper. Right: the instrument-
// shelf trigger (hover = the readout condenses down), the W/T signal pip,
// the LAMP OIL vial (battery), the time in thin serif, and the lamp that
// opens the field desk. Self-contained: Quickshell.Hyprland, /proc, nmcli.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color lamp: pal.neon
    readonly property color fogSilver: pal.cyan
    readonly property color ember: pal.magenta
    readonly property color brass: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function lampA(a)   { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function silverA(a) { return Qt.rgba(fogSilver.r, fogSilver.g, fogSilver.b, a) }
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a)  { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot: the sill condenses — opacity up while the soft-focus settles
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    // ── the benchmark triangle, drawn small ─────────────────────────────────
    component BenchMark: Canvas {
        id: bm
        property color tone: root.silverA(0.7)
        property real side: 9
        width: side + 2; height: side
        onToneChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = String(tone)
            ctx.lineWidth = 1.1
            ctx.beginPath()
            ctx.moveTo(width / 2, 0.8)
            ctx.lineTo(width - 0.8, height - 1)
            ctx.lineTo(0.8, height - 1)
            ctx.closePath()
            ctx.stroke()
            ctx.fillStyle = String(tone)
            ctx.fillRect(width / 2 - 0.8, height * 0.5, 1.6, 1.6)
        }
    }

    // ── the glass of the sill ───────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: root.glassA(0.60) }
    Rectangle {   // the sill's front edge, against the desktop
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: root.slateA(0.55)
    }
    Rectangle {   // a whisper of moonlight along the top
        width: parent.width; height: 1
        color: root.silverA(0.10)
    }

    // ── center: the survey traverse ─────────────────────────────────────────
    Item {
        id: wsCluster
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 34
        readonly property int activeSlot: activeWsId - pageBase
        width: wsCount * slotW
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.bootT

        // the traverse hairline, running under every station
        Rectangle {
            x: -10; y: Math.round(parent.height * 0.66)
            width: parent.width + 20; height: 1
            color: root.slateA(0.8)
        }

        function iconForWindows(wins) {
            let best = null, bestFh = Infinity
            for (const w of wins) {
                const cls = w.lastIpcObject?.class ?? ""
                if (!cls) continue
                const fh = w.lastIpcObject?.focusHistoryID ?? Infinity
                if (fh < bestFh) { best = w; bestFh = fh }
            }
            if (!best) return Quickshell.iconPath("application-x-executable")
            const entry = DesktopEntries.heuristicLookup(best.lastIpcObject.class)
            const name = (entry && entry.icon) ? entry.icon : best.lastIpcObject.class.toLowerCase()
            return Quickshell.iconPath(name, "application-x-executable")
        }

        Repeater {
            model: wsCluster.wsCount
            delegate: Item {
                id: slot
                required property int index
                readonly property int wsId: wsCluster.pageBase + index
                readonly property bool isActive: wsCluster.activeWsId === wsId
                readonly property var windowsHere: Hyprland.toplevels.values
                    .filter(t => (t.workspace?.id ?? -1) === wsId)
                readonly property bool isOccupied: windowsHere.length > 0

                x: index * wsCluster.slotW
                width: wsCluster.slotW
                height: parent.height

                // the station mark on the traverse
                BenchMark {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(slot.height * 0.66) - height + 1
                    tone: slot.isActive ? root.lampA(0.95)
                        : slot.isOccupied ? root.silverA(0.75)
                        : root.slateA(0.9)
                }
                // the sighting flag: whatever app rides this station
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: slot.isActive ? 15 : 13
                    height: width
                    visible: slot.isOccupied
                    source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                    opacity: slot.isActive ? 1 : 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
            }
        }

        // ── the lamp: hangs at the active station, re-condenses on switch ──
        Item {
            id: lampAt
            property int slotIdx: wsCluster.activeSlot
            property real t: 1   // 1 condensed, 0 fog
            x: slotIdx * wsCluster.slotW + wsCluster.slotW / 2 - width / 2
            y: Math.round(parent.height * 0.66) + 3
            width: 8; height: 8

            Rectangle {   // halo
                anchors.centerIn: parent
                width: 20; height: 20; radius: 10
                color: root.lampA(0.14 * lampAt.t)
            }
            Rectangle {   // flame
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                color: root.lamp
                opacity: lampAt.t * lampAt.t
                scale: 1 + 0.5 * (1 - lampAt.t)
            }
            // fog ghosts while transitioning
            Rectangle {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -5 * (1 - lampAt.t)
                width: 6; height: 6; radius: 3
                color: root.silverA(0.5)
                opacity: 0.5 * (1 - lampAt.t) * Math.min(1, lampAt.t * 4 + 0.3)
            }

            SequentialAnimation {
                id: relight
                NumberAnimation { target: lampAt; property: "t"; to: 0; duration: 150; easing.type: Easing.InQuad }
                ScriptAction { script: lampAt.slotIdx = wsCluster.activeSlot }
                NumberAnimation { target: lampAt; property: "t"; to: 1; duration: 340; easing.type: Easing.OutCubic }
            }
            Connections {
                target: wsCluster
                function onActiveSlotChanged() { relight.restart() }
            }
        }
    }

    // keep workspace occupancy fresh — toplevels are empty until refreshed
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
    Component.onCompleted: Hyprland.refreshToplevels()

    // ── left: the wireless set ──────────────────────────────────────────────
    Item {
        id: media
        readonly property var player: {
            const ps = Mpris.players.values
            if (ps.length === 0) return null
            return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
        }
        readonly property bool active: player !== null
        readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing

        visible: active
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: radioRow.width + 22
        height: Math.min(parent.height - 6, 30)
        opacity: root.bootT

        Rectangle {   // the set's plate: cold glass, hairline edge
            anchors.fill: parent
            radius: 3
            color: root.glassA(0.7)
            border.width: 1
            border.color: root.slateA(0.8)
        }

        Row {
            id: radioRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "W/T"
                color: root.lampA(0.9)
                font.family: root.serif
                font.pixelSize: 10
                font.letterSpacing: 2
            }
            // the valve pip: breathes while receiving — a warm tube, not an LED
            Rectangle {
                id: valve
                anchors.verticalCenter: parent.verticalCenter
                width: 5; height: 5; radius: 2.5
                color: media.playing ? root.lamp : root.slateA(0.9)
                SequentialAnimation on opacity {
                    running: media.playing && !root.occluded
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                }
                onVisibleChanged: opacity = 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 230)
                elide: Text.ElideRight
                text: {
                    if (!media.active) return ""
                    const t = media.player.trackTitle || "—"
                    const a = media.player.trackArtist
                    return a ? t + " · " + a : t
                }
                textFormat: Text.PlainText
                color: root.inkA(0.85)
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        // the ink trace: track progress drawn on ruled paper
        property real progress: 0
        Timer {
            interval: 1000; repeat: true
            running: media.playing && !root.occluded
            triggeredOnStart: true
            onTriggered: {
                const p = media.player
                media.progress = (p && p.length > 0 && p.position >= 0)
                    ? Math.min(1, p.position / p.length) : 0
            }
        }
        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.bottomMargin: 4
            height: 3
            Rectangle { width: parent.width; height: 1; y: 1; color: root.slateA(0.6) }
            Repeater {   // paper ruling ticks
                model: 7
                Rectangle {
                    required property int index
                    x: (index + 1) * parent.width / 8
                    width: 1; height: 3
                    color: root.slateA(0.5)
                }
            }
            Rectangle {   // the ink
                width: parent.width * media.progress
                height: 1; y: 1
                color: root.lampA(0.85)
            }
        }

        MouseArea {
            anchors.fill: parent
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

    // ── right: the shelf's fittings ─────────────────────────────────────────
    property bool online: false
    property string connType: ""
    property int batteryPercent: -1
    property bool batteryCharging: false
    property bool hasBattery: false

    Timer {
        interval: 10000; running: !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = true; batProc.running = true }
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line) { root.online = false; root.connType = ""; return }
                const t = line.slice(line.lastIndexOf(":") + 1)
                root.connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
                root.online = true
            }
        }
    }
    Process {
        id: batProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const cap = parseInt(lines[0])
                if (lines[0] === "" || isNaN(cap)) { root.hasBattery = false; return }
                root.hasBattery = true
                root.batteryPercent = cap
                root.batteryCharging = (lines[1] || "").trim() === "Charging"
            }
        }
    }

    // hover flag shared with sysinfo.qml — the instrument trigger writes here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: rightRow
        spacing: 9
        anchors.right: parent.right
        anchors.rightMargin: 14
        height: parent.height
        opacity: root.bootT

        // the instrument shelf trigger: a tiny barograph drum. Hover pulls
        // the readout down. Gone while the readout is toggled off in settings.
        Item {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 24
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: root.glassA(0.7)
                border.width: 1
                border.color: instMa.containsMouse ? root.lampA(0.85) : root.slateA(0.8)
            }
            // drum paper + a little ink trace
            Canvas {
                id: miniDrum
                anchors.centerIn: parent
                width: 20; height: 11
                property bool hot: instMa.containsMouse
                onHotChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = String(root.slateA(0.9))
                    ctx.lineWidth = 1
                    ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
                    ctx.beginPath()
                    ctx.moveTo(2, 7)
                    ctx.bezierCurveTo(6, 3, 9, 9, 12, 5)
                    ctx.bezierCurveTo(14, 3, 16, 7, 18, 4)
                    ctx.strokeStyle = String(hot ? root.lampA(0.95) : root.silverA(0.8))
                    ctx.stroke()
                }
            }
            MouseArea {
                id: instMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // W/T signal: a silver pip while the set hears the valley; ember when dead
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 24
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: root.glassA(0.7)
                border.width: 1
                border.color: root.slateA(0.8)
            }
            Row {
                anchors.centerIn: parent
                spacing: 4
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5
                    color: root.online ? root.silverA(0.95) : root.ember
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.online ? (root.connType === "eth" ? "L" : "W") : "×"
                    color: root.online ? root.inkA(0.6) : root.ember
                    font.family: root.mono
                    font.pixelSize: 9
                }
            }
        }

        // LAMP OIL: the battery as a vial with an oil level
        Item {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 24
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: root.glassA(0.7)
                border.width: 1
                border.color: root.slateA(0.8)
            }
            Item {
                anchors.centerIn: parent
                width: 26; height: 10
                Rectangle {   // the vial
                    anchors.fill: parent
                    radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: root.slateA(1)
                }
                Rectangle {   // the oil
                    x: 2; y: 2
                    width: Math.max(0, (parent.width - 4) * Math.max(0, root.batteryPercent) / 100)
                    height: parent.height - 4
                    radius: 1
                    color: root.batteryCharging ? root.fogSilver
                         : root.batteryPercent <= 15 ? root.ember
                         : root.batteryPercent <= 30 ? root.brass
                         : root.lampA(0.9)
                }
            }
        }

        // the time, thin serif — the shelf chronometer
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: timeText.implicitWidth + 18
            height: 24
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: root.glassA(0.7)
                border.width: 1
                border.color: root.slateA(0.8)
            }
            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.inkA(0.92)
                font.family: root.serif
                font.pixelSize: 14
                font.letterSpacing: 2
            }
        }

        // the lamp — opens the field desk
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 24
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: root.glassA(0.7)
                border.width: 1
                border.color: deskMa.containsMouse ? root.lampA(0.9) : root.slateA(0.8)
            }
            // a little lantern: flame dot in a wire frame
            Item {
                anchors.centerIn: parent
                width: 10; height: 12
                readonly property color wire: deskMa.containsMouse ? root.lampA(0.95) : root.inkA(0.55)
                Rectangle { x: 2; y: 0; width: 6; height: 1.4; color: parent.wire }
                Rectangle { x: 0; y: 2; width: 1.4; height: 8; color: parent.wire }
                Rectangle { x: 8.6; y: 2; width: 1.4; height: 8; color: parent.wire }
                Rectangle { x: 2; y: 10.6; width: 6; height: 1.4; color: parent.wire }
                Rectangle {
                    x: 3.4; y: 4.4; width: 3.2; height: 3.2; radius: 1.6
                    color: root.lamp
                    opacity: deskMa.containsMouse ? 1 : 0.7
                }
            }
            MouseArea {
                id: deskMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
