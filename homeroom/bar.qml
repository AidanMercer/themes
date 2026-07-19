import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris
import "chalk.js" as Chalk

// homeroom: the corridor rail along the top — pale slate glass with the
// first sun leaking over its top edge and a chalk tray line running along
// the bottom (a chalk stub and the eraser parked at the right end).
//   center — the locker grid: ten tiny locker doors, one per workspace.
//            Closed slate when empty, ajar with a warm light seam when
//            occupied, swung OPEN with sunlight inside when active — and the
//            active door wears a small halo ring above it, because the
//            workspace you're in is the most alive thing in the room.
//            Switching is two-stage: latch-click, then swing.
//   left   — now playing as a taped note: paper, tape tab, slightly crooked,
//            re-settling whenever the track changes; a pencil progress line.
//   right  — the pin board: a thumbtack (sysinfo hover trigger), chalk
//            signal arcs, a chalk battery, the time, and the hand bell that
//            rings the control popup.
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

    readonly property color chalk: pal.text
    readonly property color halo: pal.neon
    readonly property color peri: pal.cyan
    readonly property color pink: pal.magenta
    readonly property color sun: pal.amber
    readonly property color slate: pal.dim
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }
    function periA(a)  { return Qt.rgba(peri.r, peri.g, peri.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot-in: everything is pinned up, staggered, with a small settle
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    // ── the rail itself ─────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: root.glassA(0.60) }
    Rectangle {   // sun over the top edge
        anchors.top: parent.top
        width: parent.width; height: Math.min(10, parent.height * 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.sunA(0.16) }
            GradientStop { position: 1.0; color: root.sunA(0.0) }
        }
    }
    Rectangle {   // the chalk tray lip against the desktop
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: root.slateA(0.55)
    }
    // the chalk stub and eraser, parked on the tray near the right end
    Rectangle {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
        x: parent.width - 210
        width: 12; height: 3; radius: 1.5
        color: root.chalkA(0.55)
        rotation: -4
    }
    Item {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
        x: parent.width - 190
        width: 16; height: 5
        rotation: 2
        opacity: 0.55
        Rectangle { width: 16; height: 5; radius: 1; color: root.slateA(1) }
        Rectangle { width: 16; height: 2; radius: 1; color: root.sunA(0.8) }
    }

    // ── center: the locker grid ─────────────────────────────────────────────
    Item {
        id: lockers
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 32
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
            model: lockers.wsCount
            delegate: Item {
                id: slot
                required property int index
                readonly property int wsId: lockers.pageBase + index
                readonly property bool isActive: lockers.activeWsId === wsId
                readonly property var windowsHere: Hyprland.toplevels.values
                    .filter(t => (t.workspace?.id ?? -1) === wsId)
                readonly property bool isOccupied: windowsHere.length > 0

                x: index * lockers.slotW
                width: lockers.slotW
                height: parent.height

                // the doorway: warm morning light inside the locker
                Rectangle {
                    id: doorway
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 26
                    radius: 1
                    color: root.sunA(slot.isActive ? 0.50 : slot.isOccupied ? 0.22 : 0.0)
                    Behavior on color { ColorAnimation { duration: 250 } }
                    // what's inside: the workspace's app
                    IconImage {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        visible: slot.isOccupied
                        source: slot.isOccupied ? lockers.iconForWindows(slot.windowsHere) : ""
                        opacity: slot.isActive ? 1 : 0.6
                    }
                }

                // the door, hinged on its left edge
                Rectangle {
                    id: door
                    x: doorway.x
                    y: doorway.y
                    width: 20; height: 26
                    radius: 1
                    color: root.periA(slot.isOccupied ? 0.55 : 0.30)
                    border.width: 1
                    border.color: root.slateA(0.8)
                    Behavior on color { ColorAnimation { duration: 250 } }

                    property real swing: slot.isActive ? 62 : 0
                    property real jolt: 0
                    transform: [
                        Translate { x: door.jolt },
                        Rotation {
                            origin.x: 0; origin.y: door.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: -door.swing
                        }
                    ]
                    // two-stage: the latch clicks, then the door swings
                    Behavior on swing {
                        SequentialAnimation {
                            SequentialAnimation {   // the latch click, both ways — metal never glides silently
                                NumberAnimation { target: door; property: "jolt"; to: 1.6; duration: 55 }
                                NumberAnimation { target: door; property: "jolt"; to: 0; duration: 55 }
                            }
                            NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
                        }
                    }

                    // stripe label
                    Rectangle {
                        x: 3; y: 4; width: 14; height: 3
                        color: slot.isOccupied ? Qt.rgba(root.pink.r, root.pink.g, root.pink.b, 0.85)
                                               : root.slateA(0.7)
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                    // vent slits
                    Rectangle { x: 5; y: 14; width: 10; height: 1; color: root.slateA(0.55) }
                    Rectangle { x: 5; y: 17; width: 10; height: 1; color: root.slateA(0.55) }
                    Rectangle { x: 5; y: 20; width: 10; height: 1; color: root.slateA(0.55) }
                    // warm seam at the latch edge while somebody's in there
                    Rectangle {
                        anchors.right: parent.right
                        width: 2; height: parent.height
                        color: root.sunA(slot.isOccupied && !slot.isActive ? 0.75 : 0)
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }

                // the halo above the open door — the one supernatural thing
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: doorway.y - 6
                    width: 12; height: 5; radius: 2.5
                    color: "transparent"
                    border.width: 1.6
                    border.color: root.halo
                    visible: opacity > 0.01
                    opacity: slot.isActive ? 0.95 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
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

    // ── left: now playing, a taped note ─────────────────────────────────────
    Item {
        id: media
        readonly property var player: {
            const ps = Mpris.players.values
            if (ps.length === 0) return null
            return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
        }
        readonly property bool active: player !== null
        readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing
        readonly property string trackKey: active ? (player.trackTitle || "") + "\n" + (player.trackArtist || "") : ""
        onTrackKeyChanged: if (active && root.bootT === 1) pinSettle.restart()

        visible: active
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: noteRow.width + 26
        height: Math.min(30, parent.height - 8)
        opacity: root.bootT
        rotation: -1.3
        transformOrigin: Item.TopLeft

        // track change: the note is re-pinned — drop and crooked settle
        SequentialAnimation {
            id: pinSettle
            ParallelAnimation {
                NumberAnimation { target: media; property: "rotation"; from: -4; to: -0.4; duration: 220; easing.type: Easing.OutQuad }
                NumberAnimation { target: media; property: "anchors.verticalCenterOffset"; from: -5; to: 1.5; duration: 220; easing.type: Easing.OutQuad }
            }
            ParallelAnimation {
                NumberAnimation { target: media; property: "rotation"; to: -1.3; duration: 160; easing.type: Easing.InOutQuad }
                NumberAnimation { target: media; property: "anchors.verticalCenterOffset"; to: 0; duration: 160; easing.type: Easing.InOutQuad }
            }
        }

        Rectangle {    // the paper
            anchors.fill: parent
            radius: 1
            color: Qt.rgba(0.97, 0.97, 0.99, 0.93)
        }
        Rectangle {    // the tape tab
            x: -5; y: -3
            width: 18; height: 7
            rotation: -38
            color: root.chalkA(0.45)
        }

        Row {
            id: noteRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 8
            Text {   // the note's own little melody mark, in pencil
                anchors.verticalCenter: parent.verticalCenter
                text: media.playing ? "♪" : "…"
                color: media.playing ? Qt.rgba(root.pink.r, root.pink.g, root.pink.b, 0.95)
                                     : root.glassA(0.7)
                font.family: root.mono
                font.pixelSize: 12
                font.weight: Font.Bold
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
                color: root.glassA(0.92)     // pencil on paper
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        // pencil progress line along the note's foot
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
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.bottomMargin: 4
            width: (parent.width - 16) * media.progress
            height: 1.5
            color: root.glassA(0.6)
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

    // ── right: the pin board ────────────────────────────────────────────────
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

    // hover flag shared with sysinfo.qml — the thumbtack writes "1"/"0" here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: rightRow
        spacing: 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        height: parent.height
        opacity: root.bootT

        // the thumbtack — hover to pin the duty board up.
        // gone while the readout is toggled off in settings.
        Item {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 22
            Rectangle {   // pin head
                anchors.horizontalCenter: parent.horizontalCenter
                y: 3
                width: 10; height: 10; radius: 5
                color: tackMa.containsMouse ? root.pink : Qt.rgba(root.pink.r, root.pink.g, root.pink.b, 0.55)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Rectangle {   // pin stem
                anchors.horizontalCenter: parent.horizontalCenter
                y: 13
                width: 1.6; height: 6
                color: root.slateA(0.9)
            }
            MouseArea {
                id: tackMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // chalk signal arcs — three arcs over a dot, drawn lit or ghost
        Canvas {
            id: netGlyph
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 20
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const lit = root.online ? (root.connType === "eth" ? 3 : 2 + (root.connType === "wifi" ? 1 : 0)) : 0
                for (let i = 0; i < 3; i++) {
                    ctx.beginPath()
                    ctx.arc(width / 2, height - 4, 3.5 + i * 4, Math.PI * 1.2, Math.PI * 1.8)
                    ctx.strokeStyle = String(root.chalkA(i < lit ? 0.85 : 0.22))
                    ctx.lineWidth = 1.8
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
                ctx.fillStyle = root.online ? String(root.chalkA(0.9))
                                            : String(Qt.rgba(root.pink.r, root.pink.g, root.pink.b, 0.95))
                ctx.beginPath()
                ctx.arc(width / 2, height - 4, 1.8, 0, Math.PI * 2)
                ctx.fill()
            }
            Connections {
                target: root
                function onOnlineChanged() { netGlyph.requestPaint() }
                function onConnTypeChanged() { netGlyph.requestPaint() }
            }
            Connections {
                target: root.pal
                function onTextChanged() { netGlyph.requestPaint() }
            }
        }

        // chalk battery (laptops only): outline + sunlight fill
        Item {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 12
            Rectangle {
                x: 0; y: 0; width: 22; height: 12
                color: "transparent"
                radius: 2
                border.width: 1.4
                border.color: root.chalkA(0.7)
            }
            Rectangle { x: 22; y: 4; width: 2.5; height: 4; radius: 1; color: root.chalkA(0.7) }
            Rectangle {
                x: 2.5; y: 2.5
                width: Math.max(0, 17 * Math.max(0, root.batteryPercent) / 100)
                height: 7
                radius: 1
                color: root.batteryCharging ? root.halo
                     : root.batteryPercent <= 15 ? root.pink
                     : root.sunA(0.95)
            }
        }

        // the time, small — the big one is chalked on the sky
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.chalkA(0.85)
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 2
        }

        // the hand bell — rings the control popup
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 22
            rotation: bellMa.containsMouse ? 8 : 0
            Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            Canvas {
                id: bellGlyph
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = String(bellMa.containsMouse ? root.sunA(1) : root.chalkA(0.75))
                    // the dome
                    ctx.beginPath()
                    ctx.arc(width / 2, 11, 6.5, Math.PI, 0)
                    ctx.lineTo(width / 2 + 8, 14)
                    ctx.lineTo(width / 2 - 8, 14)
                    ctx.closePath()
                    ctx.strokeStyle = c
                    ctx.lineWidth = 1.6
                    ctx.lineJoin = "round"
                    ctx.stroke()
                    // handle + clapper
                    ctx.beginPath()
                    ctx.moveTo(width / 2, 4.5); ctx.lineTo(width / 2, 2)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(width / 2, 16.5, 1.6, 0, Math.PI * 2)
                    ctx.fillStyle = c
                    ctx.fill()
                }
                Connections {
                    target: bellMa
                    function onContainsMouseChanged() { bellGlyph.requestPaint() }
                }
                Connections {
                    target: root.pal
                    function onTextChanged() { bellGlyph.requestPaint() }
                }
            }
            MouseArea {
                id: bellMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
