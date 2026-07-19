import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// sleeper: the bar is the table edge along the bottom of the compartment —
// dark wood with a warm rim where the lamp catches it. On the table:
//   left   — the now-playing as a LUGGAGE TAG: a little linen tag hanging by
//            its string from the table rim, swinging on the bogie rhythm
//            while the music plays; progress is a tear-line of perforation
//            dashes filling across the tag's foot
//   center — THE PUNCHED TICKET (house system): a paper strip of ten stubs
//            split by perforation dashes; the workspace you're on is a
//            punched hole — switch and the punch presses a new hole (the
//            chad drops off the ticket), occupied stubs carry their app
//   right  — the berth-card slot (hover = sysinfo card slides out), the
//            corridor lamp (net), a tiny tea glass as the battery (charge =
//            tea level, steam while charging), the time on a brass strip,
//            and the attendant's call button (control popup)
// Everything on the table heaves ~1px on the shared wall-time bogie clock
// while music plays; idle = a still table. Self-contained: Hyprland via
// Quickshell.Hyprland, /proc + nmcli polled here.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color green: pal.neon
    readonly property color moonpale: pal.cyan
    readonly property color stamp: pal.magenta
    readonly property color tea: pal.amber
    readonly property color wood: pal.dim
    readonly property color linen: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function linenA(a) { return Qt.rgba(linen.r, linen.g, linen.b, a) }
    function teaA(a)   { return Qt.rgba(tea.r, tea.g, tea.b, a) }
    function woodA(a)  { return Qt.rgba(wood.r, wood.g, wood.b, a) }
    function greenA(a) { return Qt.rgba(green.r, green.g, green.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── the bogie clock (shared wall-time phase — see DESIGN.md) ───────────
    readonly property real swayPeriod: 4200
    property real swayPhase: 0
    property real swayAmp: (media.playing && !occluded) ? 1 : 0
    Behavior on swayAmp { NumberAnimation { duration: 1400; easing.type: Easing.InOutSine } }
    Timer {
        interval: 50; repeat: true
        running: !root.occluded && (media.playing || root.swayAmp > 0.01)
        onTriggered: root.swayPhase = ((Date.now() % root.swayPeriod) / root.swayPeriod) * 2 * Math.PI
    }
    readonly property real rock: Math.sin(swayPhase) * swayAmp
    readonly property real heave: Math.sin(swayPhase * 2 + 0.7) * swayAmp

    // boot-in: the table's things tuck up from the bottom edge
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
    readonly property real bootLift: 8 * (1 - bootT)

    // ── the table itself ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.glassA(0.72)
    }
    Rectangle {   // lamp catching the table rim, against the desktop above
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: root.teaA(0.4)
    }
    Rectangle {   // the rim's shadow line
        anchors.top: parent.top
        anchors.topMargin: 1
        width: parent.width
        height: 1
        color: Qt.rgba(0, 0, 0, 0.4)
    }
    // faint wood grain, two long strokes
    Rectangle { y: parent.height * 0.55; width: parent.width * 0.34; x: parent.width * 0.03; height: 1; color: root.woodA(0.22) }
    Rectangle { y: parent.height * 0.75; width: parent.width * 0.28; x: parent.width * 0.62; height: 1; color: root.woodA(0.18) }

    // ── left: the luggage tag (now playing) ─────────────────────────────────
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
        y: Math.round((parent.height - height) / 2) + root.bootLift
        width: tagRow.width + 30
        height: Math.min(30, parent.height - 8)
        opacity: root.bootT

        // the tag swings on its string, pivoting at the punch hole
        rotation: root.rock * 1.8
        transformOrigin: Item.Left

        // tag paper
        Rectangle {
            anchors.fill: parent
            radius: 3
            color: root.glassA(0.9)
            border.width: 1
            border.color: root.teaA(0.35)
        }
        // punch hole + eyelet at the left end, where the string ties on
        Rectangle {
            id: eyelet
            anchors.left: parent.left
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: 1
            border.color: root.teaA(0.6)
        }
        // the string, up to the table rim
        Rectangle {
            x: 10; y: -media.y + 2
            width: 1
            height: media.y + media.height / 2 - 2
            color: root.linenA(0.25)
        }

        Row {
            id: tagRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            x: 22
            spacing: 8

            // the play pip: a small tea-amber lamp, breathing only while playing
            Rectangle {
                id: pip
                anchors.verticalCenter: parent.verticalCenter
                width: 5; height: 5; radius: 2.5
                color: media.playing ? root.tea : root.woodA(0.9)
                SequentialAnimation on opacity {
                    running: media.playing && !root.occluded
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
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
                color: root.linenA(0.85)
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        // the tear line: perforation dashes filling as the track plays
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
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.bottomMargin: 3
            spacing: 3
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    width: 5; height: 2; radius: 1
                    color: index < Math.round(media.progress * 14) ? root.teaA(0.9) : root.woodA(0.55)
                }
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

    // ── center: THE PUNCHED TICKET ──────────────────────────────────────────
    Item {
        id: ticket
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 32
        readonly property int activeSlot: activeWsId - pageBase

        width: wsCount * slotW
        height: Math.min(28, parent.height - 10)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.bootLift + root.heave * 1.2
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

        // ticket paper — a linen strip laid on the wood
        Rectangle {
            anchors.fill: parent
            radius: 2
            color: Qt.rgba(root.linen.r, root.linen.g, root.linen.b, 0.10)
            border.width: 1
            border.color: root.linenA(0.28)
        }
        // ticket header microprint along the top edge
        Text {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            text: "· НОЧНОЙ ПОЕЗД · NIGHT SERVICE ·"
            color: root.linenA(0.30)
            font.family: root.mono
            font.pixelSize: 6
            font.letterSpacing: 2
        }

        Repeater {
            model: ticket.wsCount
            delegate: Item {
                id: stub
                required property int index
                readonly property int wsId: ticket.pageBase + index
                readonly property bool isActive: ticket.activeWsId === wsId
                readonly property var windowsHere: Hyprland.toplevels.values
                    .filter(t => (t.workspace?.id ?? -1) === wsId)
                readonly property bool isOccupied: windowsHere.length > 0

                x: index * ticket.slotW
                width: ticket.slotW
                height: parent.height

                // perforation between stubs
                Column {
                    visible: stub.index > 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: 5
                        Rectangle { width: 1; height: 2; color: root.linenA(0.30) }
                    }
                }

                // stub number, printed small at the foot
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    text: String(stub.wsId)
                    color: stub.isActive ? root.teaA(0.9) : root.linenA(stub.isOccupied ? 0.55 : 0.3)
                    font.family: root.mono
                    font.pixelSize: 7
                }

                // the app riding this stub
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: 12; height: 12
                    visible: stub.isOccupied && !stub.isActive
                    source: stub.isOccupied ? ticket.iconForWindows(stub.windowsHere) : ""
                    opacity: 0.5
                }

                // THE PUNCH — the hole where you are
                Item {
                    id: punch
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: 12; height: 12
                    visible: stub.isActive
                    onVisibleChanged: if (visible) { press.restart(); chadDrop.restart() }

                    Rectangle {   // the hole: table-dark through the paper
                        id: hole
                        anchors.centerIn: parent
                        width: 10; height: 10; radius: 5
                        color: Qt.rgba(0, 0, 0, 0.62)
                        border.width: 1
                        border.color: root.teaA(0.75)
                    }
                    NumberAnimation {
                        id: press
                        target: hole; property: "scale"
                        from: 1.5; to: 1; duration: 180; easing.type: Easing.OutCubic
                    }
                    // the chad, dropping off the ticket
                    Rectangle {
                        id: chad
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 7; height: 7; radius: 3.5
                        color: root.linenA(0.5)
                        opacity: 0
                        property real fall: 0
                        y: 4 + fall * 22
                        rotation: fall * 100
                        ParallelAnimation {
                            id: chadDrop
                            NumberAnimation { target: chad; property: "fall"; from: 0; to: 1; duration: 420; easing.type: Easing.InQuad }
                            SequentialAnimation {
                                PropertyAction { target: chad; property: "opacity"; value: 0.85 }
                                PauseAnimation { duration: 240 }
                                NumberAnimation { target: chad; property: "opacity"; to: 0; duration: 180 }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${stub.wsId}`)
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

    // ── right: the traveler's things ────────────────────────────────────────
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

    // hover flag shared with sysinfo.qml — the card slot writes "1"/"0" here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: rightRow
        spacing: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.bootLift + root.heave * 1.2
        opacity: root.bootT

        // the berth-card slot — hover pulls the service card out (sysinfo).
        // gone while the readout is toggled off in settings.
        Item {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 22
            Rectangle {   // the slot
                anchors.fill: parent
                radius: 2
                color: root.glassA(0.85)
                border.width: 1
                border.color: cardMa.containsMouse ? root.teaA(0.8) : root.woodA(0.8)
            }
            Rectangle {   // the card, peeking out of the slot
                anchors.horizontalCenter: parent.horizontalCenter
                y: cardMa.containsMouse ? 2 : 5
                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                width: 22; height: 14; radius: 1
                color: Qt.rgba(root.linen.r, root.linen.g, root.linen.b, 0.16)
                border.width: 1
                border.color: root.linenA(0.4)
                Rectangle {   // its little punched corner hole
                    x: 3; y: 3; width: 3; height: 3; radius: 1.5
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
            }
            MouseArea {
                id: cardMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // the corridor lamp: lit green when online, red pip when not
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 22
            Rectangle {   // lamp stem
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: 2; height: 8
                color: root.woodA(1)
            }
            Rectangle {   // lamp shade
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: 12; height: 7
                radius: 2
                color: root.online ? (root.connType === "eth" ? root.greenA(0.9) : root.greenA(0.7))
                                   : root.woodA(0.8)
            }
            Rectangle {   // dead-lamp pip
                anchors.horizontalCenter: parent.horizontalCenter
                y: 13
                width: 4; height: 4; radius: 2
                color: root.stamp
                visible: !root.online
            }
        }

        // the battery is a tiny tea glass: charge = tea level
        Item {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 22
            Rectangle {   // glass walls
                x: 2; y: 4; width: 12; height: 16
                color: "transparent"
                border.width: 1
                border.color: root.linenA(0.5)
            }
            Rectangle {   // podstakannik band
                x: 1; y: 14; width: 14; height: 6
                color: "transparent"
                border.width: 1
                border.color: root.teaA(0.7)
            }
            Rectangle {   // the tea
                x: 4
                width: 8
                height: Math.max(1, Math.round(12 * Math.max(0, Math.min(100, root.batteryPercent)) / 100))
                y: 18 - height
                color: root.batteryPercent <= 15 ? root.stamp
                     : root.batteryPercent <= 30 ? root.teaA(0.9)
                     : root.teaA(0.75)
            }
            // steam while charging
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -4
                visible: root.batteryCharging
                text: "~"
                color: root.linenA(0.6)
                font.pixelSize: 8
            }
        }

        // the time, on a small brass strip
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: timeText.implicitWidth + 16
            height: 22
            radius: 2
            color: root.glassA(0.85)
            border.width: 1
            border.color: root.teaA(0.35)
            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.linenA(0.9)
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 2
            }
        }

        // the attendant's call button — the control popup
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; radius: 11
            color: root.glassA(0.9)
            border.width: 1
            border.color: callMa.containsMouse ? root.teaA(0.9) : root.woodA(0.9)
            Rectangle {
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                color: callMa.containsMouse ? root.tea : root.teaA(0.5)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            MouseArea {
                id: callMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
