import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// thicket: the bar is the hedge line — a strip of dark foliage along the top
// of the screen with a fringe of leaf silhouettes hanging off its lower edge.
// The workspaces are GAPS in the hedge: each slot is a parting between two
// leaves, and out of the active gap looks the EYESHINE — a pair of pale-iris
// glints. Switch workspace and the eyes blink shut, reopen in the new gap
// (one dart, no glide), the new gap's leaves springing wider. Occupied gaps
// hang their app like something spotted just past the leaves.
//   left  — now playing behind a leaf-bitten panel, an ember pip flicking
//           in hard steps while sound runs, progress as a creeping vine
//           with a leaf marking the spot
//   right — the watcher's eye (hover = sysinfo panel), a stem of signal
//           leaflets, a berry-cluster battery, the time, and a curled leaf
//           for the control popup
// Panels are leaf-bitten (LeafPanel), never clean rectangles. Motion is
// freeze→dart everywhere. Self-contained: Hyprland + /proc + nmcli.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    readonly property color emberRed: pal.magenta
    readonly property color dapple: pal.amber
    readonly property color leaf: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function emberA(a) { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function irisA(a)  { return Qt.rgba(iris.r, iris.g, iris.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function leafA(a)  { return Qt.rgba(leaf.r, leaf.g, leaf.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // boot: the hedge is already there; its contents dart in — one quick move
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 260; easing.type: Easing.OutQuint }

    // ── LeafPanel: a glass card with leaf silhouettes biting its corners ────
    component LeafPanel: Canvas {
        id: lp
        property color fill: root.glassA(0.82)
        property color stroke: root.leafA(0.55)
        property int seed: 1
        onFillChanged: requestPaint()
        onStrokeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        function leafShape(ctx, x, y, len, wid, ang, fill) {
            ctx.save()
            ctx.translate(x, y); ctx.rotate(ang)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
            ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
            ctx.closePath()
            ctx.fillStyle = fill
            ctx.fill()
            ctx.restore()
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (width <= 0 || height <= 0) return
            const w = width, h = height, r = 7
            ctx.beginPath()
            ctx.moveTo(r, 0.5)
            ctx.lineTo(w - r, 0.5); ctx.quadraticCurveTo(w - 0.5, 0.5, w - 0.5, r)
            ctx.lineTo(w - 0.5, h - r); ctx.quadraticCurveTo(w - 0.5, h - 0.5, w - r, h - 0.5)
            ctx.lineTo(r, h - 0.5); ctx.quadraticCurveTo(0.5, h - 0.5, 0.5, h - r)
            ctx.lineTo(0.5, r); ctx.quadraticCurveTo(0.5, 0.5, r, 0.5)
            ctx.closePath()
            ctx.fillStyle = String(fill)
            ctx.fill()
            ctx.strokeStyle = String(stroke)
            ctx.lineWidth = 1
            ctx.stroke()
            // the bite: leaves lying over the corners
            const dk = "rgba(7,12,10,0.9)"
            leafShape(ctx, -2, 3, 12 + root.rnd(seed * 7) * 6, 4, 0.5, dk)
            leafShape(ctx, w + 2, h - 3, 12 + root.rnd(seed * 13) * 6, 4, Math.PI - 0.4, dk)
            leafShape(ctx, w * (0.3 + root.rnd(seed * 3) * 0.4), h + 1, 10, 3.5, -Math.PI / 2 + 0.5, dk)
        }
    }

    // ── the hedge itself ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.glassA(0.60)
    }
    // fringe: leaf silhouettes hanging off the hedge's lower edge, one draw
    Canvas {
        id: fringe
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.bottom
        height: 10
        onWidthChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            let x = 0, i = 0
            while (x < width) {
                const len = 7 + root.rnd(i * 17 + 3) * 8
                const wid = 2.5 + root.rnd(i * 29 + 5) * 2.5
                const ang = Math.PI / 2 + (root.rnd(i * 11 + 1) - 0.5) * 0.9
                const teal = root.rnd(i * 41 + 6) < 0.25
                ctx.save()
                ctx.translate(x, -1); ctx.rotate(ang)
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                ctx.closePath()
                ctx.fillStyle = teal ? "rgba(31,58,50,0.75)" : "rgba(8,13,11,0.82)"
                ctx.fill()
                ctx.restore()
                x += 5 + root.rnd(i * 7 + 2) * 9
                i++
            }
        }
    }

    // ── center: gaps in the hedge ───────────────────────────────────────────
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

                // the gap: two leaves leaning over it; the active gap parts wide
                Canvas {
                    id: gapLeaves
                    anchors.fill: parent
                    property real part: slot.isActive ? 1 : 0
                    Behavior on part { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                    property bool occ: slot.isOccupied
                    onOccChanged: requestPaint()
                    onPartChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    function leafShape(ctx, x, y, len, wid, ang, fill) {
                        ctx.save()
                        ctx.translate(x, y); ctx.rotate(ang)
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                        ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = fill
                        ctx.fill()
                        ctx.restore()
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width, h = height
                        const cx = w / 2, cy = h * 0.52
                        // the dark of the gap, deeper when open
                        const g = ctx.createRadialGradient(cx, cy, 1, cx, cy, 12)
                        g.addColorStop(0, "rgba(3,6,5," + (0.55 + 0.35 * part) + ")")
                        g.addColorStop(1, "rgba(3,6,5,0)")
                        ctx.fillStyle = g
                        ctx.fillRect(0, 0, w, h)
                        // two leaves leaning across; parting swings them aside
                        const sw = 4 + part * 6
                        const sd = slot.isOccupied || slot.isActive ? 0.85 : 0.55
                        const c1 = slot.isActive ? "rgba(31,58,50," + sd + ")" : "rgba(9,14,12," + sd + ")"
                        leafShape(ctx, cx - sw, cy + 3, 13, 4.5, -2.2 - part * 0.55, c1)
                        leafShape(ctx, cx + sw, cy + 3, 13, 4.5, -0.9 + part * 0.55, c1)
                    }
                }

                // the app spotted past the leaves
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: slot.isActive ? -9 : 0
                    width: slot.isActive ? 14 : 12
                    height: width
                    visible: slot.isOccupied
                    source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                    opacity: slot.isActive ? 0.95 : 0.4
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
            }
        }

        // ── the eyeshine: a pair of pale glints out of the active gap ───────
        Item {
            id: eyes
            width: 18; height: 6
            y: Math.round(parent.height * 0.52) - 1
            x: Math.round(wsCluster.activeSlot * wsCluster.slotW + wsCluster.slotW / 2 - width / 2)
            transformOrigin: Item.Center

            // two almond glints, the left one a touch higher — like the frame
            Rectangle {
                x: 0; y: 1; width: 6; height: 4; radius: 2
                color: root.iris
                Rectangle { x: 1; y: 1; width: 2; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.9) }
            }
            Rectangle {
                x: 11; y: 0; width: 6; height: 4; radius: 2
                color: root.iris
                Rectangle { x: 1; y: 1; width: 2; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.9) }
            }

            // switch: blink shut, cross in the dark, open in the new gap
            property real targetX: Math.round(wsCluster.activeSlot * wsCluster.slotW + wsCluster.slotW / 2 - width / 2)
            // stop any idle blink first — both animations drive scaleY
            onTargetXChanged: { blink.stop(); hop.restart() }
            SequentialAnimation {
                id: hop
                NumberAnimation { target: eyes; property: "scaleY"; to: 0.08; duration: 80; easing.type: Easing.InQuad }
                PropertyAction { target: eyes; property: "x"; value: eyes.targetX }
                PauseAnimation { duration: 60 }
                NumberAnimation { target: eyes; property: "scaleY"; to: 1; duration: 150; easing.type: Easing.OutQuint }
            }
            // the slow deliberate blink while it watches
            SequentialAnimation {
                id: blink
                NumberAnimation { target: eyes; property: "scaleY"; to: 0.08; duration: 70; easing.type: Easing.InQuad }
                NumberAnimation { target: eyes; property: "scaleY"; to: 1; duration: 120; easing.type: Easing.OutQuint }
            }
            Timer {
                id: blinkTimer
                interval: 9000 + root.rnd(Math.floor(Date.now() / 9000)) * 8000
                repeat: true
                running: !root.occluded
                onTriggered: { if (!hop.running) blink.restart(); interval = 9000 + Math.random() * 8000 }
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

    // ── left: now playing ───────────────────────────────────────────────────
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
        x: 12
        y: Math.round((parent.height - height) / 2)
        width: brushRow.width + 26
        height: 28
        opacity: root.bootT

        LeafPanel { anchors.fill: parent; seed: 3 }

        Row {
            id: brushRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 8

            // the ember pip: flicks in hard steps while something's singing
            Rectangle {
                id: pip
                anchors.verticalCenter: parent.verticalCenter
                width: 5; height: 5; radius: 2.5
                property bool tick: true
                color: media.playing ? root.ember : root.leafA(0.9)
                opacity: media.playing ? (tick ? 1 : 0.3) : 0.5
                Timer {
                    interval: 700; repeat: true
                    running: media.playing && !root.occluded
                    onTriggered: pip.tick = !pip.tick
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 220)
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
                font.pixelSize: 11
            }
        }

        // the vine: a thin stem creeping across, a leaf marking how far
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
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 4
            height: 4
            Rectangle { y: 2; width: parent.width; height: 1; color: root.leafA(0.5) }
            Rectangle {
                y: 2
                width: Math.round(parent.width * media.progress)
                height: 1
                color: root.emberA(0.8)
            }
            // the marker leaf
            Rectangle {
                x: Math.max(0, Math.round(parent.width * media.progress) - 2)
                y: 0
                width: 5; height: 3; radius: 1.5
                rotation: -30
                color: root.ember
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

    // ── right: what the hedge holds ─────────────────────────────────────────
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

    // hover flag shared with sysinfo.qml — the watcher's eye writes "1"/"0"
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: rightRow
        spacing: 8
        anchors.right: parent.right
        anchors.rightMargin: 12
        height: parent.height
        opacity: root.bootT

        // the watcher's eye — hover to see what it knows.
        // gone while the readout is toggled off in settings.
        LeafPanel {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 24
            seed: 5
            stroke: eyeMa.containsMouse ? root.irisA(0.8) : root.leafA(0.55)
            // one almond eye; the glint brightens when met
            Item {
                anchors.centerIn: parent
                width: 14; height: 8
                Canvas {
                    anchors.fill: parent
                    property bool hot: eyeMa.containsMouse
                    onHotChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width, h = height
                        ctx.beginPath()
                        ctx.moveTo(0, h / 2)
                        ctx.quadraticCurveTo(w / 2, -h * 0.35, w, h / 2)
                        ctx.quadraticCurveTo(w / 2, h * 1.35, 0, h / 2)
                        ctx.closePath()
                        ctx.fillStyle = hot ? String(root.irisA(0.95)) : String(root.irisA(0.4))
                        ctx.fill()
                        ctx.beginPath()
                        ctx.arc(w / 2, h / 2, 1.8, 0, Math.PI * 2)
                        ctx.fillStyle = "rgba(6,10,8,0.95)"
                        ctx.fill()
                    }
                }
            }
            MouseArea {
                id: eyeMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // signal: a stem with four leaflets, lit while the connection is up
        // (wired lights the whole stem; wireless leaves the top leaflet dark)
        LeafPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 24
            seed: 7
            Item {
                anchors.centerIn: parent
                width: 16; height: 14
                Rectangle { x: 7; y: 0; width: 1; height: 14; color: root.leafA(0.9) }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        readonly property int lit: root.online ? (root.connType === "eth" ? 4 : 3) : 0
                        x: index % 2 === 0 ? 1 : 9
                        y: 10 - index * 3
                        width: 6; height: 3; radius: 1.5
                        rotation: index % 2 === 0 ? -28 : 28
                        color: index < lit ? root.emberA(0.9) : root.leafA(0.6)
                    }
                }
            }
            // cut stem: a red tip when offline
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 4
                width: 4; height: 4; radius: 2
                color: root.emberRed
                visible: !root.online
            }
        }

        // berry-cluster battery (laptops only): five berries ripen ember
        LeafPanel {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 24
            seed: 9
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        readonly property bool ripe: root.batteryPercent >= 0 && index < Math.ceil(root.batteryPercent / 20)
                        color: !ripe ? "transparent"
                             : root.batteryCharging ? root.iris
                             : root.batteryPercent <= 15 ? root.emberRed
                             : root.batteryPercent <= 30 ? root.dapple
                             : root.ember
                        border.width: 1
                        border.color: ripe ? "transparent" : root.leafA(0.7)
                    }
                }
            }
            Rectangle {   // the charge glint above the cluster
                x: 18; y: 3; width: 3; height: 3; radius: 1.5
                color: root.iris
                visible: root.batteryCharging
            }
        }

        // the time — small, mono, watched from cover
        LeafPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: timeText.implicitWidth + 18
            height: 24
            seed: 11
            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.inkA(0.9)
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 2
            }
        }

        // a curled leaf — the way into the control popup
        LeafPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 24
            seed: 13
            stroke: popMa.containsMouse ? root.emberA(0.9) : root.leafA(0.55)
            Canvas {
                anchors.centerIn: parent
                width: 14; height: 12
                property bool hot: popMa.containsMouse
                onHotChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = hot ? String(root.emberA(0.95)) : String(root.inkA(0.6))
                    ctx.strokeStyle = c
                    ctx.lineWidth = 1.4
                    ctx.beginPath()
                    ctx.moveTo(2, 10)
                    ctx.quadraticCurveTo(1, 3, 7, 2)
                    ctx.quadraticCurveTo(13, 1, 12, 6)
                    ctx.quadraticCurveTo(11, 10, 7, 9)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(2, 10); ctx.lineTo(7, 5.5)
                    ctx.stroke()
                }
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
