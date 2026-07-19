import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// downpour: the bar is the window's upper sash — the strip of glass where
// condensation gathers first. Its bottom edge is a meniscus: an irregular
// waterline, never a rule. The workspaces are breath marks — small fog
// circles on the glass, the app living in each one dimly visible through
// its mark; the active mark is wiped clear (a bright ring, the glass seen
// true). Switching spends a droplet: a bead breaks off the old mark and
// runs to the sash's edge. Left, the playing track is written small on the
// glass in her hand, a waterline creeping under it for progress. Right,
// hushed readings: the breath mark that reveals the sysinfo patch, the
// signal, a vial of charge, the hour, a fingertip for the control menu.
// Self-contained: hyprland via Quickshell.Hyprland, /proc + nmcli.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color paneLight: pal.neon
    readonly property color skinLight: pal.cyan
    readonly property color warmth: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string serif: "Noto Serif"
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function paneA(a)  { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot: the sash condenses into being — nothing drops, nothing slides
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine }

    // ── the glass strip + its meniscus edge ─────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.glassA(0.52)
    }
    Canvas {
        id: waterline
        anchors.bottom: parent.bottom
        width: parent.width
        height: 7
        onWidthChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: root.pal
            function onNeonChanged() { waterline.requestPaint() }
            function onDimChanged() { waterline.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width
            // the waterline sags between hashed anchor points
            ctx.beginPath()
            ctx.moveTo(0, 2)
            const seg = 130
            let px = 0, py = 2
            for (let x = seg; x <= w + seg; x += seg) {
                const ny = 1.5 + 3.5 * root.rnd(Math.floor(x / seg) * 17 + 3)
                ctx.quadraticCurveTo(px + seg * 0.5, py + 2.2, Math.min(x, w), ny)
                px = x; py = ny
            }
            ctx.strokeStyle = String(root.paneA(0.30))
            ctx.lineWidth = 1.1
            ctx.stroke()
            // a few beads hanging off the line
            for (let i = 0; i < Math.floor(w / 260); i++) {
                const bx = w * root.rnd(i * 41 + 9)
                const by = 2 + 3 * root.rnd(i * 23 + 4)
                ctx.beginPath()
                ctx.ellipse(bx, by, 3.4, 4.2)
                ctx.fillStyle = String(root.paneA(0.38))
                ctx.fill()
            }
        }
    }

    // ── center: breath marks ────────────────────────────────────────────────
    Item {
        id: wsCluster
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 36
        readonly property int activeSlot: activeWsId - pageBase
        width: wsCount * slotW
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.bootT

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

                // the breath mark: a fog circle on the glass
                Rectangle {
                    anchors.centerIn: parent
                    width: 24; height: 24
                    radius: 12
                    color: root.inkA(slot.isActive ? 0.02 : slot.isOccupied ? 0.10 : 0.05)
                    Behavior on color { ColorAnimation { duration: 500 } }
                }
                // the wiped-clear ring around the active mark
                Rectangle {
                    anchors.centerIn: parent
                    width: 26; height: 26
                    radius: 13
                    color: "transparent"
                    border.width: 1.4
                    border.color: root.paneA(slot.isActive ? 0.85 : 0)
                    scale: slot.isActive ? 1 : 0.7
                    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.InOutSine } }
                    Behavior on border.color { ColorAnimation { duration: 400 } }
                    // the glint where light crosses the cleared glass
                    Rectangle {
                        x: 4; y: 3
                        width: 5; height: 2
                        radius: 1
                        rotation: -35
                        color: root.inkA(slot.isActive ? 0.7 : 0)
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }
                // the app, dimly visible through its mark
                IconImage {
                    anchors.centerIn: parent
                    width: 14; height: 14
                    visible: slot.isOccupied
                    source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                    opacity: slot.isActive ? 0.95 : 0.38
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }
                // an empty mark keeps one faint seed at its heart
                Rectangle {
                    anchors.centerIn: parent
                    width: 3; height: 3
                    radius: 1.5
                    visible: !slot.isOccupied && !slot.isActive
                    color: root.slateA(0.8)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
            }
        }

        // switching spends a droplet off the old mark
        Item {
            id: wsDrop
            property real t: -1
            property real fromX: 0
            visible: t >= 0
            x: fromX
            y: wsCluster.height / 2 + 8
            Rectangle {
                x: -2.5
                y: (wsCluster.height / 2 - 12) * Math.max(0, wsDrop.t) * Math.max(0, wsDrop.t)
                width: 5; height: 6.5
                radius: 2.5
                color: root.paneA(0.8 * (1 - Math.max(0, wsDrop.t) * 0.6))
                Rectangle { x: 1; y: 1; width: 1.5; height: 1.5; radius: 0.8; color: root.inkA(0.85) }
            }
            SequentialAnimation {
                id: wsDropAnim
                NumberAnimation { target: wsDrop; property: "t"; from: 0; to: 1; duration: 480 }
                PropertyAction { target: wsDrop; property: "t"; value: -1 }
            }
        }
        property int prevSlot: -1
        onActiveSlotChanged: {
            if (prevSlot >= 0 && !root.occluded) {
                wsDrop.fromX = prevSlot * slotW + slotW / 2
                wsDropAnim.restart()
            }
            prevSlot = activeSlot
        }
        Component.onCompleted: prevSlot = activeSlot
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

    // ── left: the track, written on the glass ───────────────────────────────
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
        x: 16
        height: parent.height
        width: mediaRow.width + 8
        opacity: root.bootT

        Row {
            id: mediaRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            spacing: 9

            // the bead that listens: swells gently while music plays
            Rectangle {
                id: pip
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 8.5
                radius: 4
                color: media.playing ? root.paneA(0.85) : root.slateA(0.9)
                Behavior on color { ColorAnimation { duration: 500 } }
                Rectangle { x: 1.4; y: 1.6; width: 2; height: 2; radius: 1; color: root.inkA(0.85) }
                SequentialAnimation on scale {
                    running: media.playing && !root.occluded
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.18; duration: 2100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.92; duration: 2100; easing.type: Easing.InOutSine }
                    onStopped: pip.scale = 1
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 240)
                elide: Text.ElideRight
                text: {
                    if (!media.active) return ""
                    const t = media.player.trackTitle || "—"
                    const a = media.player.trackArtist
                    return (a ? t + " · " + a : t).toLowerCase()
                }
                textFormat: Text.PlainText
                color: root.inkA(0.78)
                font.family: root.serif
                font.italic: true
                font.pixelSize: 13
            }
        }

        // progress: a waterline creeping under the written words
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
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            x: 16
            width: Math.max(0, (mediaRow.width - 16) * media.progress)
            height: 1
            color: root.paneA(0.5)
            // the bead at the waterline's leading edge
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - 1.5
                width: 3.5; height: 4.5
                radius: 2
                color: root.paneA(0.8)
                visible: media.progress > 0.01
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

    // ── right: hushed readings ──────────────────────────────────────────────
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

    // hover flag shared with sysinfo.qml — the breath mark writes "1"/"0" here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: rightRow
        spacing: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        height: parent.height
        opacity: root.bootT

        // the breath mark you lean close to — reveals the sysinfo patch.
        // gone while the readout is toggled off in settings.
        Item {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            Rectangle {
                anchors.centerIn: parent
                width: 18; height: 18
                radius: 9
                color: root.inkA(sysMa.containsMouse ? 0.16 : 0.08)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
            // fog swirl hint: two faint arcs
            Canvas {
                anchors.fill: parent
                opacity: sysMa.containsMouse ? 0.9 : 0.45
                Behavior on opacity { NumberAnimation { duration: 300 } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = String(root.paneA(0.8))
                    ctx.lineWidth = 1.1
                    ctx.beginPath(); ctx.arc(13, 13, 5.5, 0.4, 2.6); ctx.stroke()
                    ctx.beginPath(); ctx.arc(13, 13, 3, 3.5, 5.6); ctx.stroke()
                }
                Component.onCompleted: requestPaint()
            }
            MouseArea {
                id: sysMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // the signal, dim on the glass
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(root.online
                ? (root.connType === "eth" ? 0xF059F : 0xF05A9) : 0xF092F)
            font.family: root.icon
            font.pixelSize: 13
            color: root.online ? root.inkA(0.55) : Qt.rgba(root.warmth.r, root.warmth.g, root.warmth.b, 0.8)
        }

        // a vial of charge: water level in a sliver of glass (laptops only)
        Item {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 9; height: 20
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: root.slateA(1)
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1.5
                anchors.horizontalCenter: parent.horizontalCenter
                width: 6
                height: Math.max(1, (parent.height - 3) * Math.max(0, root.batteryPercent) / 100)
                radius: 2.5
                color: root.batteryCharging ? Qt.rgba(root.skinLight.r, root.skinLight.g, root.skinLight.b, 0.9)
                     : root.batteryPercent <= 15 ? Qt.rgba(root.warmth.r, root.warmth.g, root.warmth.b, 0.9)
                     : root.paneA(0.8)
            }
        }

        // the hour, written plainly
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.inkA(0.85)
            font.family: root.serif
            font.weight: Font.Light
            font.pixelSize: 16
            font.letterSpacing: 2
        }

        // the fingertip — press to open the control menu
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22
            Rectangle {
                anchors.centerIn: parent
                width: 15; height: 15
                radius: 7.5
                color: "transparent"
                border.width: 1.2
                border.color: popMa.containsMouse ? root.paneA(0.9) : root.slateA(1)
                Behavior on border.color { ColorAnimation { duration: 250 } }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 5; height: 5
                radius: 2.5
                color: popMa.containsMouse ? root.paneA(0.9) : root.inkA(0.5)
                Behavior on color { ColorAnimation { duration: 250 } }
            }
            MouseArea {
                id: popMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
