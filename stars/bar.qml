import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// stars: the telephone wire. A thin catenary sags gently across the top of
// the screen and everything on the bar hangs from it like the wire's own
// hardware:
//   left   — a now-playing sign swinging on two drop lines (star pip pulses
//            with playback, title in pale starlight)
//   center — workspaces as a row of little bottles strung on the wire; the
//            active one glows vending-amber, occupied ones are dimly lit,
//            empty ones hang dark
//   right  — tiny hanging plates: net, battery, the time as a small sign,
//            and a ✦ button for the control popup
// A small cat sits on the wire off to the right and flicks its tail once in
// a while. Self-contained: hyprland via Quickshell.Hyprland, /proc + nmcli.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color coral: pal.cyan
    readonly property color alert: pal.magenta
    readonly property color warn:  pal.amber
    readonly property color slate: pal.dim
    readonly property color ink:   pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }
    // the cat is a silhouette a shade darker than the panel glass
    readonly property color catInk: Qt.darker(glass, 1.35)

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // the catenary: endpoints high, sagging through the middle. quadratic with
    // the control point at mid-x, so x(t) = t*w exactly and wireY is cheap.
    readonly property real wy0: 8
    readonly property real wyc: 28
    function wireY(x) {
        const t = width > 0 ? x / width : 0
        const u = 1 - t
        return u * u * wy0 + 2 * u * t * wyc + t * t * wy0
    }

    // boot-in: the wire sweeps across, then everything drops onto it
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
    readonly property real bootDrop: Math.max(0, (bootT - 0.45) / 0.55)

    // ── the wire ────────────────────────────────────────────────────────────
    Canvas {
        id: wire
        anchors.fill: parent
        onWidthChanged: requestPaint()
        Connections {
            target: root.pal
            function onDimChanged() { wire.requestPaint() }
            function onNeonChanged() { wire.requestPaint() }
        }
        readonly property real sweep: root.bootT
        onSweepChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (width <= 0) return
            const n = 48
            const upTo = Math.max(2, Math.round(n * Math.min(1, sweep / 0.45)))
            ctx.strokeStyle = root.slateA(0.85)
            ctx.lineWidth = 1.4
            ctx.beginPath()
            ctx.moveTo(0, root.wireY(0))
            for (let i = 1; i <= upTo; i++) {
                const x = width * i / n
                ctx.lineTo(x, root.wireY(x))
            }
            ctx.stroke()
            // a fainter second wire slung a touch lower, like the wallpaper's pair
            ctx.strokeStyle = root.slateA(0.30)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(0, root.wireY(0) + 4)
            for (let i = 1; i <= upTo; i++) {
                const x = width * i / n
                ctx.lineTo(x, root.wireY(x) + 4 + 2 * Math.sin(Math.PI * i / n))
            }
            ctx.stroke()
        }
    }

    // a small hanging sign plate: night glass, faint amber lip along the top
    component Plate: Rectangle {
        radius: 5
        color: root.glassA(0.78)
        border.width: 1
        border.color: root.slateA(0.55)
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 10
            height: 1
            y: 1
            color: root.amberA(0.4)
        }
    }

    // ── center: bottles on the wire (workspaces) ────────────────────────────
    Item {
        id: wsCluster
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 24
        width: wsCount * slotW
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.bootDrop

        // resolve the app icon for the message-in-a-bottle: pick the
        // most-recently-focused window on the workspace, look up its .desktop
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
                readonly property real absX: wsCluster.x + index * wsCluster.slotW + wsCluster.slotW / 2
                readonly property real hangY: root.wireY(absX)

                x: index * wsCluster.slotW
                width: wsCluster.slotW
                height: parent.height

                // drop thread from the wire
                Rectangle {
                    x: wsCluster.slotW / 2 - 0.5
                    y: slot.hangY - wsCluster.y
                    width: 1
                    height: bottle.y - (slot.hangY - wsCluster.y)
                    color: root.slateA(0.7)
                }
                Rectangle {   // knot on the wire
                    x: wsCluster.slotW / 2 - 1.5
                    y: slot.hangY - wsCluster.y - 1.5
                    width: 3; height: 3; radius: 1.5
                    color: root.slate
                }

                // the bottle: cap + rounded body, swings when it lights up
                Item {
                    id: bottle
                    width: 11
                    height: 17
                    x: wsCluster.slotW / 2 - width / 2
                    y: slot.hangY - wsCluster.y + 6 - 4 * (1 - root.bootDrop)
                    transformOrigin: Item.Top
                    rotation: 0

                    // amber halo behind the active bottle
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24; height: 26; radius: 12
                        color: root.amber
                        opacity: slot.isActive ? 0.22 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                    }
                    Rectangle {   // cap
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        width: 5; height: 3; radius: 1
                        color: slot.isActive ? root.amber : root.slateA(0.9)
                        Behavior on color { ColorAnimation { duration: 260 } }
                    }
                    Rectangle {   // body
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 3
                        width: 11; height: 14; radius: 4
                        color: slot.isActive ? root.amber
                             : slot.isOccupied ? root.amberA(0.34)
                             : "transparent"
                        border.width: 1
                        border.color: slot.isActive ? root.amberA(0.9)
                                    : slot.isOccupied ? root.amberA(0.5)
                                    : root.slateA(0.6)
                        Behavior on color { ColorAnimation { duration: 260 } }
                        // the little highlight on the glass
                        Rectangle {
                            x: 2; y: 2
                            width: 2; height: 6; radius: 1
                            color: root.inkA(slot.isActive ? 0.55 : 0.18)
                        }
                    }

                    // the message in the bottle: the app's icon, corked inside
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6
                        width: 9
                        height: 9
                        visible: slot.isOccupied
                        source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                        opacity: slot.isActive ? 1.0 : 0.72
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    // a small swing when this bottle becomes the active one
                    SequentialAnimation {
                        id: swing
                        NumberAnimation { target: bottle; property: "rotation"; to: -7; duration: 120; easing.type: Easing.OutQuad }
                        NumberAnimation { target: bottle; property: "rotation"; to: 0; duration: 500; easing.type: Easing.OutBack }
                    }
                    Connections {
                        target: slot
                        function onIsActiveChanged() { if (slot.isActive) swing.restart() }
                    }
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

    // ── left: now-playing sign ──────────────────────────────────────────────
    Item {
        id: media
        readonly property var player: {
            const ps = Mpris.players.values
            if (ps.length === 0) return null
            return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
        }
        readonly property bool active: player !== null
        readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing
        readonly property real absX: x + width / 2

        visible: active
        width: mediaRow.width + 20
        height: 22
        x: 14
        y: root.wireY(absX) + 7 - 5 * (1 - root.bootDrop)
        opacity: root.bootDrop

        // two drop lines up from the sign's shoulders to the wire (children may
        // draw above the item — nothing here clips)
        Rectangle {
            x: 8
            height: Math.max(0, media.y - root.wireY(media.x + 8))
            y: -height
            width: 1
            color: root.slateA(0.7)
        }
        Rectangle {
            x: media.width - 8
            height: Math.max(0, media.y - root.wireY(media.x + media.width - 8))
            y: -height
            width: 1
            color: root.slateA(0.7)
        }

        Plate { anchors.fill: parent }

        Row {
            id: mediaRow
            anchors.centerIn: parent
            spacing: 7

            // star pip: steady amber while playing, dim when paused
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "✦"
                color: root.amber
                font.pixelSize: 10
                opacity: media.playing ? 1 : 0.35
                SequentialAnimation on scale {
                    running: media.playing
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.25; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
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
                color: root.inkA(0.85)
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        // track progress: a thin amber trickle along the sign's bottom edge
        property real progress: 0
        Timer {
            interval: 1000; repeat: true
            running: media.playing
            triggeredOnStart: true
            onTriggered: {
                const p = media.player
                media.progress = (p && p.length > 0 && p.position >= 0)
                    ? Math.min(1, p.position / p.length) : 0
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 4
            anchors.bottomMargin: 1
            height: 1.5
            width: Math.max(0, (parent.width - 8) * media.progress)
            color: root.amberA(0.9)
            Behavior on width { NumberAnimation { duration: 900 } }
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

    // ── right: hanging status plates ────────────────────────────────────────
    // net + battery polled here; the clock sign and the ✦ popup button
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

    // hover flag shared with sysinfo.qml — it watches this file and opens the
    // service panel while it reads "1" (same mirror-file idiom as AudioBus)
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
        y: 0
        height: parent.height
        opacity: root.bootDrop

        // service bottle — hover to open the machine's service panel (sysinfo);
        // gone while the readout is toggled off in settings
        Item {
            id: svcSlot
            visible: root.pal.sysinfoOn !== false
            width: svcPlate.width
            height: parent.height
            readonly property real absX: rightRow.x + x + width / 2
            Rectangle { x: svcSlot.width / 2 - 0.5; y: root.wireY(svcSlot.absX); width: 1; height: svcPlate.y - root.wireY(svcSlot.absX); color: root.slateA(0.7) }
            Rectangle { x: svcSlot.width / 2 - 1.5; y: root.wireY(svcSlot.absX) - 1.5; width: 3; height: 3; radius: 1.5; color: root.slate }
            Plate {
                id: svcPlate
                width: 20
                height: 20
                y: root.wireY(svcSlot.absX) + 8 - 5 * (1 - root.bootDrop)
                // a tiny lit bottle
                Item {
                    anchors.centerIn: parent
                    width: 7; height: 13
                    scale: svcMa.containsMouse ? 1.2 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: 7; height: 10; radius: 2.5
                        color: svcMa.containsMouse ? root.amber : root.amberA(0.45)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 3; height: 3
                        color: svcMa.containsMouse ? root.amberA(0.9) : root.slateA(0.9)
                    }
                }
                MouseArea {
                    id: svcMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
                }
            }
        }

        // net plate
        Item {
            id: netSlot
            width: netPlate.width
            height: parent.height
            readonly property real absX: rightRow.x + x + width / 2
            Rectangle { x: netSlot.width / 2 - 0.5; y: root.wireY(netSlot.absX); width: 1; height: netPlate.y - root.wireY(netSlot.absX); color: root.slateA(0.7) }
            Rectangle { x: netSlot.width / 2 - 1.5; y: root.wireY(netSlot.absX) - 1.5; width: 3; height: 3; radius: 1.5; color: root.slate }
            Plate {
                id: netPlate
                width: netGlyph.width + 14
                height: 20
                y: root.wireY(netSlot.absX) + 8 - 5 * (1 - root.bootDrop)
                Text {
                    id: netGlyph
                    anchors.centerIn: parent
                    text: root.online
                        ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                        : String.fromCodePoint(0xF092F)
                    font.family: root.icon
                    font.pixelSize: 11
                    color: root.online ? root.inkA(0.8) : root.alert
                }
            }
        }

        // battery plate (laptops only)
        Item {
            id: batSlot
            visible: root.hasBattery
            width: visible ? batPlate.width : 0
            height: parent.height
            readonly property real absX: rightRow.x + x + width / 2
            Rectangle { x: batSlot.width / 2 - 0.5; y: root.wireY(batSlot.absX); width: 1; height: batPlate.y - root.wireY(batSlot.absX); color: root.slateA(0.7) }
            Rectangle { x: batSlot.width / 2 - 1.5; y: root.wireY(batSlot.absX) - 1.5; width: 3; height: 3; radius: 1.5; color: root.slate }
            Plate {
                id: batPlate
                width: batRow.width + 14
                height: 20
                y: root.wireY(batSlot.absX) + 8 - 5 * (1 - root.bootDrop)
                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryCharging ? String.fromCodePoint(0xF0084)
                            : String.fromCodePoint(0xF0079 + Math.max(0, Math.min(9, Math.floor(root.batteryPercent / 10))))
                        font.family: root.icon
                        font.pixelSize: 11
                        color: root.batteryCharging ? root.coral
                             : root.batteryPercent <= 15 ? root.alert
                             : root.inkA(0.8)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryPercent + "%"
                        font.family: root.mono
                        font.pixelSize: 9
                        color: root.inkA(0.7)
                    }
                }
            }
        }

        // the time, a small hanging sign on two lines
        Item {
            id: timeSlot
            width: timePlate.width
            height: parent.height
            readonly property real absX: rightRow.x + x + width / 2
            readonly property real absL: rightRow.x + x + 8
            readonly property real absR: rightRow.x + x + width - 8
            Rectangle { x: 8; y: root.wireY(timeSlot.absL); width: 1; height: timePlate.y - root.wireY(timeSlot.absL); color: root.slateA(0.7) }
            Rectangle { x: timeSlot.width - 8; y: root.wireY(timeSlot.absR); width: 1; height: timePlate.y - root.wireY(timeSlot.absR); color: root.slateA(0.7) }
            Plate {
                id: timePlate
                width: timeText.width + 18
                height: 22
                y: root.wireY(timeSlot.absX) + 7 - 5 * (1 - root.bootDrop)
                Text {
                    id: timeText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.family: root.mono
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.amber
                }
            }
        }

        // ✦ button — the control popup
        Item {
            id: starSlot
            width: 20
            height: parent.height
            readonly property real absX: rightRow.x + x + width / 2
            Rectangle { x: starSlot.width / 2 - 0.5; y: root.wireY(starSlot.absX); width: 1; height: starBtn.y - root.wireY(starSlot.absX); color: root.slateA(0.7) }
            Item {
                id: starBtn
                width: 20; height: 20
                y: root.wireY(starSlot.absX) + 8 - 5 * (1 - root.bootDrop)
                Text {
                    anchors.centerIn: parent
                    text: "✦"
                    font.pixelSize: 13
                    color: root.amber
                    opacity: starMa.containsMouse ? 1.0 : 0.7
                    scale: starMa.containsMouse ? 1.2 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: starMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                }
            }
        }
    }

    // ── the cat, sitting on the wire at ~72% across ─────────────────────────
    Item {
        id: cat
        readonly property real absX: root.width * 0.72
        width: 16
        height: 14
        x: absX - width / 2
        y: root.wireY(absX) - height + 1
        opacity: root.bootDrop * 0.95

        // tail: a thin arc that flicks once in a while
        Item {
            id: tail
            x: 13; y: 8
            width: 6; height: 6
            transformOrigin: Item.TopLeft
            rotation: 12
            Rectangle { x: 0; y: 0; width: 1.6; height: 6; radius: 1; color: root.catInk }
        }
        SequentialAnimation {
            id: tailFlick
            NumberAnimation { target: tail; property: "rotation"; to: 55; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { target: tail; property: "rotation"; to: 12; duration: 700; easing.type: Easing.OutBounce }
        }
        Timer {
            running: root.visible
            repeat: true
            interval: 34000 + Math.floor(Math.random() * 30000)
            onTriggered: { tailFlick.restart(); interval = 34000 + Math.floor(Math.random() * 30000) }
        }

        Canvas {
            id: catBody
            anchors.fill: parent
            Connections {
                target: root.pal
                function onGlassChanged() { catBody.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = String(root.catInk)
                // seated body
                ctx.beginPath()
                ctx.moveTo(3, 14)
                ctx.quadraticCurveTo(2, 6, 6, 5)
                ctx.quadraticCurveTo(10, 4.4, 11.5, 8)
                ctx.quadraticCurveTo(13, 11, 13, 14)
                ctx.closePath()
                ctx.fill()
                // head
                ctx.beginPath()
                ctx.arc(6.5, 4.6, 3.1, 0, Math.PI * 2)
                ctx.fill()
                // ears
                ctx.beginPath()
                ctx.moveTo(4.1, 3.2); ctx.lineTo(4.4, 0.6); ctx.lineTo(6.1, 2.0); ctx.closePath(); ctx.fill()
                ctx.beginPath()
                ctx.moveTo(7.1, 2.0); ctx.lineTo(8.8, 0.8); ctx.lineTo(8.9, 3.4); ctx.closePath(); ctx.fill()
            }
        }
    }
}
