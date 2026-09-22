import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// stillwater: the bar is the near water. A low strip of deep-water glass
// along the bottom edge with its own internal waterline running through it —
// everything on the bar stands ON that line, and everything is doubled
// beneath it as a broken streak, per the house law.
//   center — THE FAR SHORE: the workspaces are the distant shoreline lights.
//            occupied = a lamp lit warm-white, active = haloed with a long
//            streak, empty = a dark glass bead. switching workspaces blooms
//            one small ripple on the line under the newly lit lamp.
//   left   — the ferry light: now-playing title above the line, and the
//            track's progress as a single light crossing a hairline, its
//            streak trailing below.
//   right  — the sounding lead (hover = sysinfo), the lighthouse (net), a
//            floating lantern (battery), the time doubled in the water, and
//            a ring of light for the control popup.
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

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    readonly property color rose: pal.magenta
    readonly property color halo: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)   { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor
    // the bar's internal waterline
    readonly property real wl: Math.round(height * 0.52)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot: the shore surfaces out of the seam
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1200; easing.type: Easing.OutCubic }

    // ── the water ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.glassA(0.42) }
            GradientStop { position: 0.5; color: root.glassA(0.62) }
            GradientStop { position: 1.0; color: Qt.rgba(root.glass.r * 1.7, root.glass.g * 1.7, root.glass.b * 1.6, 0.72) }
        }
    }
    // the waterline, faint, full width
    Rectangle {
        y: root.wl
        width: parent.width
        height: 1
        color: root.skyA(0.22)
        opacity: root.bootT
    }

    // a lamp standing on the line + its broken streak in the water
    component ShoreLamp: Item {
        id: sl
        property color tone: root.lamp
        property real level: 1        // 0..1 — how lit this light is
        property bool haloed: false
        width: 8; height: 1
        // the light itself, its center pinned to the waterline
        Rectangle {
            id: dot
            anchors.horizontalCenter: parent.horizontalCenter
            y: -2
            width: 4; height: 4
            radius: 2
            color: Qt.rgba(sl.tone.r, sl.tone.g, sl.tone.b, 0.25 + 0.75 * sl.level)
            Behavior on color { ColorAnimation { duration: 500 } }
        }
        // upward glow — light on the evening haze
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: dot.top
            width: 6
            height: sl.haloed ? 9 : 4
            opacity: sl.level * (sl.haloed ? 0.5 : 0.2)
            Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.InOutSine } }
            Behavior on opacity { NumberAnimation { duration: 500 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(sl.tone.r, sl.tone.g, sl.tone.b, 0.8) }
            }
        }
        // the streak: broken slivers, dying with depth
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            spacing: 2
            Repeater {
                model: sl.haloed ? 4 : 2
                Rectangle {
                    required property int index
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 3 - (index > 1 ? 1 : 0)
                    height: 2
                    color: Qt.rgba(sl.tone.r, sl.tone.g, sl.tone.b,
                                   sl.level * (0.4 - index * 0.09))
                }
            }
        }
    }

    // ── center: the far shore ───────────────────────────────────────────────
    Item {
        id: shore
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 30
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
            model: shore.wsCount
            delegate: Item {
                id: slot
                required property int index
                readonly property int wsId: shore.pageBase + index
                readonly property bool isActive: shore.activeWsId === wsId
                readonly property var windowsHere: Hyprland.toplevels.values
                    .filter(t => (t.workspace?.id ?? -1) === wsId)
                readonly property bool isOccupied: windowsHere.length > 0

                x: index * shore.slotW
                width: shore.slotW
                height: parent.height

                ShoreLamp {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.wl
                    tone: slot.isActive ? root.lamp : slot.isOccupied ? root.lamp : root.slate
                    level: slot.isActive ? 1 : slot.isOccupied ? 0.55 : 0.18
                    haloed: slot.isActive
                }
                // the household behind the light
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.wl - 20
                    width: slot.isActive ? 13 : 11
                    height: width
                    visible: slot.isOccupied
                    source: slot.isOccupied ? shore.iconForWindows(slot.windowsHere) : ""
                    opacity: slot.isActive ? 0.95 : 0.45
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
            }
        }

        // arriving somewhere new blooms one ripple under its lamp
        Item {
            id: wsRipple
            y: root.wl
            x: shore.activeSlot * shore.slotW + shore.slotW / 2
            property real t: -1
            visible: t >= 0
            Rectangle {
                anchors.centerIn: parent
                width: 4 + 26 * Math.max(0, wsRipple.t)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: root.lampA(0.5 * (1 - Math.max(0, wsRipple.t)))
                transform: Scale { origin.y: (4 + 26 * Math.max(0, wsRipple.t)) / 2; yScale: 0.3 }
            }
            NumberAnimation {
                id: wsRippleAnim
                target: wsRipple; property: "t"
                from: 0; to: 1; duration: 700; easing.type: Easing.OutSine
                onStopped: wsRipple.t = -1
            }
        }
        Connections {
            target: shore
            function onActiveSlotChanged() { if (root.bootT === 1) wsRippleAnim.restart() }
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

    // ── left: the ferry light ───────────────────────────────────────────────
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
        width: Math.max(90, title.width + 14)
        height: parent.height
        opacity: root.bootT

        Text {
            id: title
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height - root.wl + 6
            width: Math.min(implicitWidth, 240)
            elide: Text.ElideRight
            text: {
                if (!media.active) return ""
                const t = media.player.trackTitle || "—"
                const a = media.player.trackArtist
                return a ? t + " · " + a : t
            }
            textFormat: Text.PlainText
            color: root.inkA(media.playing ? 0.85 : 0.5)
            font.family: root.mono
            font.pixelSize: 10
        }
        // its double, sunken and dim
        Text {
            id: titleGhost
            anchors.left: title.left
            y: root.wl + 3
            width: title.width
            elide: Text.ElideRight
            text: title.text
            textFormat: Text.PlainText
            color: root.skyA(0.55)
            font.family: root.mono
            font.pixelSize: 10
            opacity: 0.28
            // mid-height origin keeps the flipped glyphs inside the band
            // below the waterline (origin 0 would paint them above it)
            transform: Scale { yScale: -0.85; origin.y: titleGhost.height / 2 }
        }

        // the crossing: a hairline on the waterline, one light at progress
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
            x: 14
            y: root.wl
            width: Math.min(title.width, 160)
            height: 1
            color: root.slateA(0.5)
        }
        ShoreLamp {
            x: 14 + Math.min(title.width, 160) * media.progress - 4
            y: root.wl
            tone: media.playing ? root.lamp : root.slate
            level: media.playing ? 0.9 : 0.35
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

    // ── right: instruments standing on the line ─────────────────────────────
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

    // hover flag shared with sysinfo.qml — the sounding lead writes "1"/"0"
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: rightRow
        spacing: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        height: parent.height
        opacity: root.bootT

        // the sounding lead: a small weight on a drop line — hover reveals
        // the soundings card. gone while the readout is off in settings.
        Item {
            visible: root.pal.sysinfoOn !== false
            width: 16; height: parent.height
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.wl - 12
                width: 1; height: 8
                color: leadMa.containsMouse ? root.lampA(0.9) : root.slateA(0.8)
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.wl - 5
                width: 5; height: 5
                radius: 1
                color: leadMa.containsMouse ? root.lamp : root.slateA(0.9)
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.wl + 4
                spacing: 2
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 3; height: 2
                        color: leadMa.containsMouse ? root.lampA(0.4 - index * 0.15)
                                                    : root.slateA(0.3 - index * 0.1)
                    }
                }
            }
            MouseArea {
                id: leadMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // the lighthouse: lit while the far shore answers
        Item {
            width: 14; height: parent.height
            ShoreLamp {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.wl
                tone: root.online ? root.lamp : root.rose
                level: root.online ? (root.connType === "eth" ? 1 : 0.8) : 0.9
                haloed: root.online && root.connType === "eth"
            }
        }

        // the floating lantern (laptops only)
        Item {
            visible: root.hasBattery
            width: 18; height: parent.height
            Rectangle {   // shell, bottom edge resting on the line
                id: lantern
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.wl - 12
                width: 10; height: 12
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: root.slateA(0.9)
                Rectangle {   // the light inside, filling with charge
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    height: Math.max(1, (parent.height - 4) * Math.max(0, root.batteryPercent) / 100)
                    radius: 1
                    color: root.batteryCharging ? root.sky
                         : root.batteryPercent <= 15 ? root.rose
                         : root.batteryPercent <= 30 ? root.halo
                         : root.lampA(0.85)
                }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.wl + 4
                spacing: 2
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 5 - index * 2; height: 2
                        color: root.lampA((root.batteryPercent > 15 ? 0.3 : 0.1) - index * 0.1)
                    }
                }
            }
        }

        // the time, doubled in the water
        Item {
            width: timeText.width; height: parent.height
            Text {
                id: timeText
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height - root.wl + 4
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.inkA(0.9)
                font.family: root.mono
                font.pixelSize: 12
                font.letterSpacing: 2
            }
            Text {
                id: timeGhost
                anchors.left: timeText.left
                y: root.wl + 3
                text: timeText.text
                color: root.skyA(0.6)
                font.family: root.mono
                font.pixelSize: 12
                font.letterSpacing: 2
                opacity: 0.3
                // mid-height origin keeps the flipped digits below the line
                transform: Scale { yScale: -0.85; origin.y: timeGhost.height / 2 }
            }
        }

        // a ring of light — the control popup
        Item {
            width: 16; height: parent.height
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.wl - 11
                width: 9; height: 9
                radius: 4.5
                color: "transparent"
                border.width: 1.4
                border.color: ringMa.containsMouse ? root.lamp : root.inkA(0.6)
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.wl + 4
                spacing: 2
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 4 - index; height: 2
                        color: ringMa.containsMouse ? root.lampA(0.4 - index * 0.15)
                                                    : root.inkA(0.2 - index * 0.08)
                    }
                }
            }
            MouseArea {
                id: ringMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
