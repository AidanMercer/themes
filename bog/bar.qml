import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// bog: the bar is the pond's edge — a strip of water along the top with one
// continuous waterline running through it, sun-glints riding the line.
// Workspaces are LILY PADS floating on that line; the active pad carries a
// tiny frog that HOPS pad-to-pad when you switch (a slow parabolic arc, a
// squash on landing, a ripple where it comes down). Apps rest above their
// pads like things drying in the sun. Left: the music floats by on a leaf —
// a cork pip that bobs while the song plays, the title, a row of surfacing
// progress dots. Right: a cattail (hover = the depth soundings), a perched
// dragonfly for the net, a firefly jar for the battery, the time in serif
// with its upside-down ghost beneath the line, and the leaf-sail for the
// control menu. Everything bobs on its own phase; everything sits still
// while occluded. No pixel is ever in a hurry.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color rust: pal.magenta
    readonly property color warm: pal.amber
    readonly property color reed: pal.dim
    readonly property color straw: pal.text
    readonly property color murk: pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a)  { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function reedA(a)  { return Qt.rgba(reed.r, reed.g, reed.b, a) }
    function strawA(a) { return Qt.rgba(straw.r, straw.g, straw.b, a) }
    function murkA(a)  { return Qt.rgba(murk.r, murk.g, murk.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor
    readonly property real waterY: Math.round(height * 0.60)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot: the light crosses the water left→right, then things surface
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1400; easing.type: Easing.OutSine }
    readonly property real surfaceT: Math.max(0, (bootT - 0.35) / 0.65)
    readonly property real bootRise: 8 * (1 - surfaceT)

    // ── the water ───────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: root.murkA(0.55) }
    Rectangle {   // beneath the waterline the murk deepens
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height - root.waterY
        color: root.murkA(0.35)
    }
    Rectangle {   // the pond's edge against the desktop
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.reedA(0.45)
    }
    // the waterline itself
    Rectangle {
        y: root.waterY
        width: parent.width * root.bootT
        height: 1
        color: root.reedA(0.5)
    }
    // sun-glints riding the line, skipping the lily-pad reach
    Repeater {
        model: Math.max(0, Math.floor(root.width / 46))
        Rectangle {
            required property int index
            readonly property real cx: index * 46 + 15
            x: cx
            y: root.waterY - 1
            width: index % 3 === 0 ? 22 : 11
            height: 2
            radius: 1
            color: root.sunA(index % 2 === 0 ? 0.22 : 0.12)
            visible: (cx / root.width) < root.bootT
                     && (cx + width < wsCluster.x - 6 || cx > wsCluster.x + wsCluster.width + 6)
        }
    }

    // ── center: the lily pads ───────────────────────────────────────────────
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
        opacity: root.surfaceT

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

                // each pad rides its own phase of the swell
                property real bobY: 0
                SequentialAnimation on bobY {
                    running: !root.occluded
                    loops: Animation.Infinite
                    PauseAnimation { duration: (slot.index * 617) % 1900 }
                    NumberAnimation { to: 1.2; duration: 3100 + (slot.index % 4) * 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -1.2; duration: 3100 + (slot.index % 4) * 500; easing.type: Easing.InOutSine }
                }

                // the pad: an ellipse leaf with a cut notch
                Canvas {
                    id: pad
                    width: 24; height: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.waterY - 5 + slot.bobY
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width, h = height, cx = w / 2, cy = h / 2
                        ctx.save()
                        ctx.translate(cx, cy)
                        ctx.scale(1, h / w)
                        ctx.beginPath()
                        // the notch: a wedge missing toward the upper right
                        ctx.moveTo(0, 0)
                        ctx.arc(0, 0, w / 2 - 1, -0.28, 2 * Math.PI - 0.95)
                        ctx.closePath()
                        ctx.restore()
                        ctx.fillStyle = String(slot.isActive ? root.mossA(0.95)
                                             : slot.isOccupied ? root.mossA(0.6)
                                             : root.reedA(0.7))
                        ctx.fill()
                        if (slot.isActive) {
                            ctx.strokeStyle = String(root.sunA(0.8))
                            ctx.lineWidth = 1
                            ctx.stroke()
                        }
                    }
                    Connections {
                        target: slot
                        function onIsActiveChanged() { pad.requestPaint() }
                        function onIsOccupiedChanged() { pad.requestPaint() }
                    }
                    Connections {
                        target: root.pal
                        function onCyanChanged() { pad.requestPaint() }
                        function onDimChanged() { pad.requestPaint() }
                    }
                }
                // the pad's ghost under the line
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.waterY + 4
                    width: 16; height: 3
                    radius: 1.5
                    color: slot.isActive ? root.mossA(0.25) : root.reedA(0.2)
                }

                // the app drying in the sun above its pad
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4 + root.bootRise + slot.bobY
                    width: 13; height: 13
                    visible: slot.isOccupied && !slot.isActive
                    source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                    opacity: 0.55
                }
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2 + root.bootRise + slot.bobY
                    width: 15; height: 15
                    visible: slot.isOccupied && slot.isActive
                    source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
            }
        }

        // ── the frog ────────────────────────────────────────────────────────
        Item {
            id: frog
            width: 16; height: 11

            // plain values, set only by the hop handler — live bindings on
            // activeSlot would race the Connections and start the hop from
            // the wrong pad
            property real startX: 0
            property real endX: 0
            property real hopT: 1
            property int facing: 1
            Component.onCompleted: {
                const nx = wsCluster.activeSlot * wsCluster.slotW + wsCluster.slotW / 2 - width / 2
                startX = nx; endX = nx
            }

            x: startX + (endX - startX) * hopT
            y: root.waterY - 13 - 11 * Math.sin(Math.PI * Math.min(1, hopT))
            transform: Scale {
                origin.x: frog.width / 2
                origin.y: frog.height
                xScale: frog.facing
                // the leap stretches mid-air and settles back on landing
                yScale: 1 + 0.14 * Math.pow(Math.sin(Math.PI * Math.min(1, frog.hopT)), 2)
            }

            NumberAnimation {
                id: hop
                target: frog; property: "hopT"
                from: 0; to: 1; duration: 720; easing.type: Easing.InOutSine
                onStopped: { frog.startX = frog.endX; landRings.splash() }
            }
            Connections {
                target: wsCluster
                function onActiveSlotChanged() {
                    const nx = wsCluster.activeSlot * wsCluster.slotW + wsCluster.slotW / 2 - frog.width / 2
                    frog.startX = frog.x
                    frog.facing = nx >= frog.startX ? 1 : -1
                    frog.endX = nx
                    hop.restart()
                }
            }

            Canvas {
                id: frogBody
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    // haunches
                    ctx.fillStyle = String(root.mossA(0.85))
                    ctx.beginPath(); ctx.arc(w * 0.22, h * 0.72, w * 0.2, 0, 2 * Math.PI); ctx.fill()
                    // body
                    ctx.beginPath()
                    ctx.save(); ctx.translate(w * 0.52, h * 0.62); ctx.scale(1, 0.62)
                    ctx.arc(0, 0, w * 0.38, 0, 2 * Math.PI)
                    ctx.restore()
                    ctx.fillStyle = String(root.moss)
                    ctx.fill()
                    // eyes
                    for (const ex of [0.66, 0.88]) {
                        ctx.beginPath(); ctx.arc(w * ex, h * 0.26, w * 0.11, 0, 2 * Math.PI)
                        ctx.fillStyle = String(root.moss); ctx.fill()
                        ctx.beginPath(); ctx.arc(w * ex + 0.8, h * 0.24, w * 0.045, 0, 2 * Math.PI)
                        ctx.fillStyle = String(Qt.rgba(0, 0, 0, 0.85)); ctx.fill()
                    }
                    // belly light
                    ctx.beginPath()
                    ctx.save(); ctx.translate(w * 0.52, h * 0.76); ctx.scale(1, 0.4)
                    ctx.arc(0, 0, w * 0.24, 0, 2 * Math.PI)
                    ctx.restore()
                    ctx.fillStyle = String(root.sunA(0.35))
                    ctx.fill()
                }
                Connections {
                    target: root.pal
                    function onCyanChanged() { frogBody.requestPaint() }
                }
            }

            // the landing ripple, dropped where the frog comes down
            Canvas {
                id: landRings
                property real t: -1
                visible: t >= 0
                width: 40; height: 12
                x: frog.width / 2 - width / 2
                y: 13
                onTChanged: requestPaint()
                function splash() { if (!root.occluded) lr.restart() }
                NumberAnimation {
                    id: lr
                    target: landRings; property: "t"
                    from: 0; to: 1; duration: 1200; easing.type: Easing.OutSine
                    onStopped: landRings.t = -1
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (t < 0) return
                    for (let k = 0; k < 2; k++) {
                        const tt = (t - k * 0.22) / (1 - k * 0.22)
                        if (tt <= 0 || tt >= 1) continue
                        const r = 4 + 14 * tt
                        ctx.save()
                        ctx.translate(width / 2, height / 2)
                        ctx.scale(1, 0.3)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(root.strawA(0.4 * (1 - tt)))
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
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

    // ── a floating leaf panel (soft pointed-oval glass) ─────────────────────
    component LeafPanel: Canvas {
        id: lp
        property color fill: root.murkA(0.85)
        property color stroke: root.mossA(0.45)
        onFillChanged: requestPaint()
        onStrokeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (width <= 0 || height <= 0) return
            const w = width, h = height
            ctx.beginPath()
            ctx.moveTo(2, h / 2)
            ctx.quadraticCurveTo(w * 0.12, 0.5, w / 2, 0.5)
            ctx.quadraticCurveTo(w * 0.88, 0.5, w - 2, h / 2)
            ctx.quadraticCurveTo(w * 0.88, h - 0.5, w / 2, h - 0.5)
            ctx.quadraticCurveTo(w * 0.12, h - 0.5, 2, h / 2)
            ctx.closePath()
            ctx.fillStyle = String(fill)
            ctx.fill()
            ctx.strokeStyle = String(stroke)
            ctx.lineWidth = 1
            ctx.stroke()
        }
    }

    // ── left: the music floats by on a leaf ─────────────────────────────────
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
        width: leafRow.width + 30
        height: 26
        y: Math.round(root.waterY - height * 0.62) + bobY - root.bootRise + 8 * (1 - root.surfaceT)
        opacity: root.surfaceT
        property real bobY: 0
        SequentialAnimation on bobY {
            running: !root.occluded && media.visible
            loops: Animation.Infinite
            NumberAnimation { to: 1.6; duration: 3900; easing.type: Easing.InOutSine }
            NumberAnimation { to: -1.6; duration: 3900; easing.type: Easing.InOutSine }
        }

        LeafPanel { anchors.fill: parent }

        Row {
            id: leafRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 8

            // the cork pip: bobbing while the song swims, still when it rests
            Item {
                id: pip
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 9
                property real dip: 0
                Rectangle { x: 0; y: 0 + pip.dip; width: 7; height: 4; radius: 2; color: media.playing ? root.rust : root.reedA(0.9) }
                Rectangle { x: 1; y: 3.4 + pip.dip; width: 5; height: 3.4; radius: 1.7; color: media.playing ? root.sunA(0.85) : root.reedA(0.6) }
                SequentialAnimation on dip {
                    running: media.playing && !root.occluded
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.6; duration: 1300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -0.6; duration: 1300; easing.type: Easing.InOutSine }
                }
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
                color: root.strawA(0.85)
                font.family: root.serif
                font.italic: true
                font.pixelSize: 12
            }
        }

        // progress: dots surfacing one by one as the song crosses the pond
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
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 3
            spacing: 4
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    readonly property bool up: index < Math.round(media.progress * 12)
                    width: 3; height: 3
                    radius: 1.5
                    color: up ? root.sunA(0.85) : root.reedA(0.5)
                    y: up ? 0 : 2
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

    // ── right: the pond's small residents ───────────────────────────────────
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

    // hover flag shared with sysinfo.qml — the cattail writes "1"/"0" here
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
        height: parent.height
        opacity: root.surfaceT

        // the cattail — hover to take the depth soundings.
        // gone while the readout is toggled off in settings.
        Item {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.bootRise / 2
            width: 22; height: 26
            property real bobY: 0
            SequentialAnimation on bobY {
                running: !root.occluded
                loops: Animation.Infinite
                NumberAnimation { to: 1.2; duration: 4700; easing.type: Easing.InOutSine }
                NumberAnimation { to: -1.2; duration: 4700; easing.type: Easing.InOutSine }
            }
            // stem + the brown sausage head + one thin blade
            Item {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: parent.bobY
                width: 14; height: 22
                rotation: cattailMa.containsMouse ? 4 : 0
                Behavior on rotation { NumberAnimation { duration: 500; easing.type: Easing.InOutSine } }
                Rectangle { x: 6; y: 0; width: 1.6; height: 22; color: root.mossA(0.8) }
                Rectangle {
                    x: 4; y: 2; width: 5.6; height: 10; radius: 2.8
                    color: cattailMa.containsMouse ? root.warm : Qt.rgba(root.warm.r, root.warm.g, root.warm.b, 0.6)
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Rectangle { x: 10; y: 4; width: 1.2; height: 17; rotation: 12; color: root.mossA(0.5) }
            }
            MouseArea {
                id: cattailMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // the dragonfly — perched while the pond is connected, gone when not
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 22
            property real bobY: 0
            SequentialAnimation on bobY {
                running: !root.occluded
                loops: Animation.Infinite
                NumberAnimation { to: 1.4; duration: 3600; easing.type: Easing.InOutSine }
                NumberAnimation { to: -1.4; duration: 3600; easing.type: Easing.InOutSine }
            }
            Canvas {
                id: dfly
                anchors.centerIn: parent
                anchors.verticalCenterOffset: parent.bobY
                width: 22; height: 14
                opacity: root.online ? 0.95 : 0.35
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    const tone = root.online ? root.moss : root.reed
                    // body: a thin arc, head dot
                    ctx.strokeStyle = String(Qt.rgba(tone.r, tone.g, tone.b, 0.95))
                    ctx.lineWidth = 1.8
                    ctx.beginPath()
                    ctx.moveTo(w * 0.08, h * 0.62)
                    ctx.quadraticCurveTo(w * 0.5, h * 0.42, w * 0.86, h * 0.56)
                    ctx.stroke()
                    ctx.beginPath(); ctx.arc(w * 0.9, h * 0.56, 1.8, 0, 2 * Math.PI)
                    ctx.fillStyle = String(tone); ctx.fill()
                    // wings: two pairs of thin sunlit ellipses
                    ctx.fillStyle = String(root.sunA(root.online ? 0.5 : 0.2))
                    for (const wing of [[0.42, -0.5], [0.58, -0.72], [0.40, 0.9], [0.56, 1.05]]) {
                        ctx.save()
                        ctx.translate(w * wing[0], h * 0.44)
                        ctx.rotate(wing[1])
                        ctx.scale(1, 0.3)
                        ctx.beginPath(); ctx.arc(0, -5, 5, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.fill()
                    }
                }
                Connections {
                    target: root
                    function onOnlineChanged() { dfly.requestPaint() }
                }
                Connections {
                    target: root.pal
                    function onCyanChanged() { dfly.requestPaint() }
                }
            }
            // offline: a rust droplet where the dragonfly should be drinking
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 4; height: 4; radius: 2
                color: root.rust
                visible: !root.online
            }
        }

        // the firefly jar (laptops only): the light left in the bottle
        Item {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 24
            Rectangle {   // cork
                anchors.horizontalCenter: parent.horizontalCenter
                y: 2; width: 6; height: 3
                color: root.reedA(1)
            }
            Rectangle {   // jar
                id: jar
                anchors.horizontalCenter: parent.horizontalCenter
                y: 5; width: 12; height: 17
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: root.reedA(0.9)
                Rectangle {   // the glow inside, level = charge
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 2
                    width: parent.width - 4
                    height: Math.max(2, (parent.height - 4) * Math.max(0, root.batteryPercent) / 100)
                    radius: 3
                    color: root.batteryPercent <= 15 ? root.rust
                         : root.batteryPercent <= 30 ? root.warm
                         : root.sunA(0.8)
                }
            }
            // charging: one firefly circling the neck
            Rectangle {
                id: fly
                width: 3; height: 3; radius: 1.5
                color: root.sun
                visible: root.batteryCharging
                x: 6; y: 0
                SequentialAnimation on opacity {
                    running: root.batteryCharging && !root.occluded
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }

        // the time, floating with its upside-down ghost under the line
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: tt.implicitWidth + 6
            height: parent.height
            property real bobY: 0
            SequentialAnimation on bobY {
                running: !root.occluded
                loops: Animation.Infinite
                NumberAnimation { to: 1.3; duration: 5200; easing.type: Easing.InOutSine }
                NumberAnimation { to: -1.3; duration: 5200; easing.type: Easing.InOutSine }
            }
            Text {
                id: tt
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.waterY - implicitHeight + parent.bobY
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.strawA(0.92)
                font.family: root.serif
                font.pixelSize: 16
                font.letterSpacing: 1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.waterY + 1 - parent.bobY * 0.5
                text: tt.text
                color: root.strawA(0.92)
                font: tt.font
                opacity: 0.16
                transform: Scale { origin.y: 0; yScale: -1 }
            }
        }

        // the leaf-sail — the raft's flag, and the way into the control menu
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 26
            Canvas {
                id: sail
                anchors.centerIn: parent
                width: 16; height: 22
                rotation: sailMa.containsMouse ? -6 : 0
                Behavior on rotation { NumberAnimation { duration: 500; easing.type: Easing.InOutSine } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    // mast
                    ctx.fillStyle = String(root.reedA(1))
                    ctx.fillRect(w * 0.2, 0, 1.8, h)
                    // the curved leaf-sail
                    ctx.beginPath()
                    ctx.moveTo(w * 0.3, h * 0.08)
                    ctx.quadraticCurveTo(w * 1.05, h * 0.18, w * 0.72, h * 0.62)
                    ctx.quadraticCurveTo(w * 0.55, h * 0.78, w * 0.3, h * 0.66)
                    ctx.closePath()
                    ctx.fillStyle = String(sailMa.containsMouse ? root.mossA(0.95) : root.mossA(0.65))
                    ctx.fill()
                    // midrib
                    ctx.strokeStyle = String(root.sunA(0.5))
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(w * 0.32, h * 0.14)
                    ctx.quadraticCurveTo(w * 0.72, h * 0.3, w * 0.6, h * 0.6)
                    ctx.stroke()
                }
                Connections {
                    target: root.pal
                    function onCyanChanged() { sail.requestPaint() }
                }
            }
            MouseArea {
                id: sailMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                onContainsMouseChanged: sail.requestPaint()
            }
        }
    }
}
