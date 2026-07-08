import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// guts: the left bar is a single vertical ink brush stroke — a blade of
// black laid down the screen edge, rough-edged, nicked by battle, fraying
// into dry-brush flecks at the bottom. Cut into it:
//   top    — a blood hanko seal (the control popup) above ten tally slashes,
//            one per workspace: scratches when empty, bold paper cuts when
//            occupied, the active one a red slash that bleeds a drip
//   bottom — a now-playing stamp that fills with red ink as the track runs,
//            a vertical brush clock reading top-to-bottom, and hanko-style
//            status seals (net / battery)
// Self-contained: Hyprland via Quickshell.Hyprland, battery+net polled here.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal

    readonly property color ink:   pal.text
    readonly property color blood: pal.neon
    readonly property color fresh: pal.magenta
    readonly property color dried: pal.amber
    readonly property color halft: pal.dim
    readonly property color paper: pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    readonly property string iconFont: "Symbols Nerd Font"
    function paperA(a) { return Qt.rgba(paper.r, paper.g, paper.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    // boot-in: the stroke is laid down from the top
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    // ── the blade: one rough brush stroke down the edge ─────────────────────
    Canvas {
        id: blade
        anchors.fill: parent
        Connections {
            target: root.pal
            function onTextChanged() { blade.requestPaint() }
            function onGlassChanged() { blade.requestPaint() }
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            ctx.beginPath()
            ctx.moveTo(0, 0)
            // brush lands: slight entry taper over the first 40px
            ctx.lineTo(w * 0.72, 0)
            ctx.quadraticCurveTo(w * 0.92, 18, w * 0.90, 44)
            // rough right edge, hand-wavered, with battle nicks
            const nickYs = [h * 0.22, h * 0.47, h * 0.71]
            let y = 44
            while (y < h - 90) {
                const wob = Math.sin(y * 0.045) * 1.6 + Math.sin(y * 0.013 + 2) * 2.2
                let edge = w * 0.90 + wob
                ctx.lineTo(edge, y)
                for (const ny of nickYs) {
                    if (y <= ny && y + 8 > ny) {     // a triangular cut into the edge
                        ctx.lineTo(edge - w * 0.22, y + 5)
                        ctx.lineTo(edge - 1, y + 11)
                    }
                }
                y += 8
            }
            // the stroke frays out at the bottom
            ctx.lineTo(w * 0.86, h - 78)
            ctx.quadraticCurveTo(w * 0.94, h - 46, w * 0.70, h - 18)
            ctx.quadraticCurveTo(w * 0.58, h - 6, w * 0.62, h)
            ctx.lineTo(0, h)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.93)
            ctx.fill()
            // dry-brush flecks trailing off the frayed end
            ctx.fillStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
            const fl = [[0.80, 14], [0.55, 30], [0.88, 44], [0.40, 8], [0.68, 58]]
            for (const f of fl) {
                ctx.beginPath()
                ctx.arc(w * f[0], h - f[1], 1.5, 0, Math.PI * 2)
                ctx.fill()
            }
            // the fuller — a faint groove of paper down the blade
            ctx.strokeStyle = root.paperA(0.10)
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(w * 0.30, 70)
            ctx.lineTo(w * 0.30, h - 110)
            ctx.stroke()
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.bootT
        transform: Translate { y: -14 * (1 - root.bootT) }

        // ── top: hanko seal (control popup) + tally slashes ──────────────────
        Column {
            anchors.top: parent.top
            anchors.topMargin: Math.round(12 * root.ui)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(9 * root.ui)

            // the seal button
            Item {
                width: Math.round(28 * root.ui); height: width
                anchors.horizontalCenter: parent.horizontalCenter
                rotation: -5
                scale: sealMa.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                Canvas {
                    id: sealBtn
                    anchors.fill: parent
                    Connections {
                        target: root.pal
                        function onNeonChanged() { sealBtn.requestPaint() }
                        function onGlassChanged() { sealBtn.requestPaint() }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width, h = height
                        ctx.fillStyle = root.blood
                        ctx.beginPath()
                        ctx.moveTo(2, 1); ctx.lineTo(w - 1, 2); ctx.lineTo(w - 2, h - 1)
                        ctx.lineTo(w * 0.4, h - 2); ctx.lineTo(1, h - 3)
                        ctx.closePath()
                        ctx.fill()
                        // the Brand, negative
                        root.brandPath(ctx, w * 0.26, h * 0.16, h * 0.50, root.paper, 0.95)
                    }
                }
                MouseArea {
                    id: sealMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                }
            }

            // a paper scratch dividing seal from tally
            Rectangle {
                width: Math.round(16 * root.ui); height: 2
                rotation: -28
                color: root.paperA(0.35)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // ten kills, ten slashes
            Item {
                width: Math.round(30 * root.ui)
                height: wsCol.height
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    id: wsCol
                    spacing: Math.round(4 * root.ui)

                    readonly property int wsCount: 10
                    readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
                    readonly property int pageBase: activeWsId >= 1
                        ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
                        : 1

                    // resolve the app icon: most-recently-focused window's .desktop
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
                        model: wsCol.wsCount
                        delegate: Item {
                            id: slot
                            required property int index
                            readonly property int wsId: wsCol.pageBase + index
                            readonly property bool isActive: wsCol.activeWsId === wsId
                            readonly property var windowsHere: Hyprland.toplevels.values
                                .filter(t => (t.workspace?.id ?? -1) === wsId)
                            readonly property bool isOccupied: windowsHere.length > 0

                            width: Math.round(30 * root.ui)
                            height: Math.round(18 * root.ui)

                            // the app that lives here — the slash cuts across it
                            IconImage {
                                anchors.centerIn: parent
                                visible: slot.isOccupied
                                width: Math.round(14 * root.ui)
                                height: width
                                source: slot.isOccupied ? wsCol.iconForWindows(slot.windowsHere) : ""
                                opacity: slot.isActive ? 0.9 : 0.5
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            // the slash — a diagonal cut through the blade
                            Rectangle {
                                anchors.centerIn: parent
                                rotation: -34
                                width: slot.isActive ? Math.round(26 * root.ui)
                                     : slot.isOccupied ? Math.round(20 * root.ui)
                                     : Math.round(12 * root.ui)
                                height: slot.isActive ? Math.round(3.5 * root.ui)
                                      : slot.isOccupied ? Math.round(2.5 * root.ui) : 1
                                color: slot.isActive ? root.fresh
                                     : root.paperA(slot.isOccupied ? 0.85 : 0.22)
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            // the active slash bleeds
                            Rectangle {
                                x: parent.width * 0.62
                                y: parent.height * 0.62
                                width: Math.max(1.5, Math.round(1.5 * root.ui))
                                height: slot.isActive ? Math.round(7 * root.ui) : 0
                                color: root.fresh
                                opacity: slot.isActive ? 0.85 : 0
                                Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
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

                // wheel over the tally cycles workspaces
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (w) => Hyprland.dispatch(w.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
                }
            }
        }

        // ── bottom: media stamp · brush clock · status seals ─────────────────
        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(14 * root.ui)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(10 * root.ui)

            // now-playing stamp: red ink rises as the track runs
            Item {
                visible: root.mediaActive
                width: Math.round(24 * root.ui); height: Math.round(24 * root.ui)
                anchors.horizontalCenter: parent.horizontalCenter
                rotation: 4

                Rectangle {   // stamp frame in paper
                    anchors.fill: parent
                    color: "transparent"
                    border.color: root.paperA(mediaMa.containsMouse ? 0.9 : 0.55)
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                Rectangle {   // the ink level = track progress
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 2
                    height: Math.max(0, (parent.height - 4) * root.mediaProgress)
                    color: root.blood
                    opacity: 0.85
                    Behavior on height { NumberAnimation { duration: 900 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.mediaPlaying ? String.fromCodePoint(0xF03E4) : String.fromCodePoint(0xF040A)
                    font.family: root.iconFont
                    font.pixelSize: Math.round(11 * root.ui)
                    color: root.paperA(0.95)
                    style: Text.Outline
                    styleColor: root.inkA(0.5)
                }
                MouseArea {
                    id: mediaMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.mediaActive && root.player.canTogglePlaying) root.player.togglePlaying()
                    onWheel: (w) => {
                        if (!root.mediaActive) return
                        if (w.modifiers & Qt.ShiftModifier) {
                            Quickshell.execDetached(["qs", "ipc", "call", "lyricOffset",
                                w.angleDelta.y > 0 ? "earlier" : "later"])
                            return
                        }
                        if (w.angleDelta.y > 0 && root.player.canGoNext) root.player.next()
                        else if (w.angleDelta.y < 0 && root.player.canGoPrevious) root.player.previous()
                    }
                }
            }

            // vertical brush clock — digits stacked, read top-to-bottom
            Column {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: [0, 1]
                    Text {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH")[index]
                        color: root.paperA(0.96)
                        font.family: root.serif
                        font.pixelSize: Math.round(17 * root.ui)
                        font.weight: Font.Black
                    }
                }
                // a red slash where a colon would be
                Item {
                    width: Math.round(14 * root.ui); height: Math.round(8 * root.ui)
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(11 * root.ui); height: 2
                        rotation: -34
                        color: root.fresh
                    }
                }
                Repeater {
                    model: [0, 1]
                    Text {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "mm")[index]
                        color: root.paperA(0.85)
                        font.family: root.serif
                        font.pixelSize: Math.round(17 * root.ui)
                        font.weight: Font.DemiBold
                    }
                }
            }

            // status seals — small stamps at the stroke's frayed end
            Column {
                spacing: Math.round(5 * root.ui)
                anchors.horizontalCenter: parent.horizontalCenter

                // notes seal: hover to ink in the margin notes (sysinfo);
                // gone while the readout is toggled off in settings
                Rectangle {
                    visible: root.pal.sysinfoOn !== false
                    width: Math.round(17 * root.ui); height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    rotation: -3
                    color: notesMa.containsMouse ? Qt.rgba(root.blood.r, root.blood.g, root.blood.b, 0.85) : "transparent"
                    border.color: notesMa.containsMouse ? root.blood : root.paperA(0.5)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(9 * root.ui); height: 1.6
                        rotation: -32
                        color: notesMa.containsMouse ? root.paperA(0.95) : root.paperA(0.7)
                    }
                    MouseArea {
                        id: notesMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
                    }
                }

                // net: paper seal when online, bleeds red when offline
                Rectangle {
                    width: Math.round(17 * root.ui); height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    rotation: -4
                    color: root.netOnline ? "transparent" : Qt.rgba(root.blood.r, root.blood.g, root.blood.b, 0.85)
                    border.color: root.netOnline ? root.paperA(0.5) : root.blood
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(root.netOnline
                            ? (root.netType === "eth" ? 0xF059F : 0xF05A9) : 0xF092F)
                        font.family: root.iconFont
                        font.pixelSize: Math.round(9 * root.ui)
                        color: root.paperA(0.9)
                    }
                }

                // battery: the seal fills with ink as it drains toward red
                Rectangle {
                    visible: root.batPct >= 0
                    width: Math.round(17 * root.ui); height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    rotation: 3
                    color: "transparent"
                    border.color: root.batPct >= 0 && root.batPct <= 20 && !root.batCharging
                        ? root.fresh : root.paperA(0.5)
                    border.width: 1
                    // ink rises as the charge drains — full red seal means empty
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 2
                        height: Math.max(0, (parent.height - 4) * (100 - Math.max(0, root.batPct)) / 100)
                        color: root.batCharging ? root.paperA(0.7)
                             : root.batPct <= 20 ? root.fresh : root.paperA(0.4)
                    }
                    Text {
                        visible: root.batCharging
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF0E7)   // nf-fa-bolt
                        font.family: root.iconFont
                        font.pixelSize: Math.round(8 * root.ui)
                        color: root.inkA(0.85)
                    }
                }
            }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // hover flag shared with sysinfo.qml — it watches this file and inks the
    // margin notes in while it reads "1" (same mirror-file idiom as AudioBus)
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    // Hyprland.toplevels is empty until refreshed; re-query on window events
    // so the tally slashes track occupancy.
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

    // ── the Brand path, shared by the seals ──────────────────────────────────
    function brandPath(ctx, x, y, s, col, alpha) {
        ctx.save()
        ctx.globalAlpha = alpha
        ctx.fillStyle = col
        ctx.strokeStyle = col
        ctx.lineWidth = Math.max(0.8, 0.09 * s)   // heavy stroke: tiny seal legibility
        ctx.lineJoin = "round"
        ctx.beginPath()
        ctx.moveTo(x + 0.02 * s, y + 0.32 * s)
        ctx.quadraticCurveTo(x + 0.10 * s, y + 0.02 * s, x + 0.38 * s, y + 0.00 * s)
        ctx.quadraticCurveTo(x + 0.62 * s, y - 0.01 * s, x + 0.66 * s, y + 0.20 * s)
        ctx.quadraticCurveTo(x + 0.68 * s, y + 0.34 * s, x + 0.52 * s, y + 0.44 * s)
        ctx.quadraticCurveTo(x + 0.34 * s, y + 0.55 * s, x + 0.24 * s, y + 0.78 * s)
        ctx.quadraticCurveTo(x + 0.14 * s, y + 1.00 * s, x + 0.14 * s, y + 1.22 * s)
        ctx.quadraticCurveTo(x + 0.10 * s, y + 0.98 * s, x + 0.20 * s, y + 0.72 * s)
        ctx.quadraticCurveTo(x + 0.28 * s, y + 0.50 * s, x + 0.40 * s, y + 0.36 * s)
        ctx.quadraticCurveTo(x + 0.52 * s, y + 0.22 * s, x + 0.44 * s, y + 0.14 * s)
        ctx.quadraticCurveTo(x + 0.34 * s, y + 0.06 * s, x + 0.20 * s, y + 0.16 * s)
        ctx.quadraticCurveTo(x + 0.08 * s, y + 0.24 * s, x + 0.02 * s, y + 0.32 * s)
        ctx.closePath()
        ctx.fill(); ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(x + 0.50 * s, y + 0.30 * s)
        ctx.quadraticCurveTo(x + 0.78 * s, y + 0.32 * s, x + 0.92 * s, y + 0.52 * s)
        ctx.quadraticCurveTo(x + 0.70 * s, y + 0.46 * s, x + 0.46 * s, y + 0.42 * s)
        ctx.closePath()
        ctx.fill(); ctx.stroke()
        ctx.beginPath()
        ctx.arc(x + 0.13 * s, y + 1.36 * s, 0.06 * s, 0, Math.PI * 2)
        ctx.fill()
        ctx.restore()
    }

    // ── mpris ────────────────────────────────────────────────────────────────
    readonly property var player: {
        const ps = Mpris.players.values
        if (ps.length === 0) return null
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
    }
    readonly property bool mediaActive: player !== null
    readonly property bool mediaPlaying: mediaActive && player.playbackState === MprisPlaybackState.Playing
    property real mediaProgress: 0
    Timer {
        interval: 1000; repeat: true
        running: root.mediaPlaying
        triggeredOnStart: true
        onTriggered: {
            const p = root.player
            root.mediaProgress = (p && p.length > 0 && p.position >= 0)
                ? Math.min(1, p.position / p.length) : 0
        }
    }

    // ── battery + net ────────────────────────────────────────────────────────
    property int batPct: -1
    property bool batCharging: false
    property bool netOnline: false
    property string netType: "wifi"

    function parseStatus(out) {
        const lines = out.trim().split("\n")
        for (const raw of lines) {
            const l = raw.trim()
            if (/^[0-9]+$/.test(l)) root.batPct = parseInt(l)
            else if (/^(Charging|Discharging|Full|Not charging)$/.test(l)) root.batCharging = l === "Charging"
            else if (l.startsWith("NET:")) {
                const t = l.slice(4)
                root.netOnline = t !== ""
                root.netType = t.indexOf("wireless") >= 0 ? "wifi" : "eth"
            }
        }
    }
    Process {
        id: statusProc
        command: ["sh", "-c",
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1; " +
            "printf 'NET:%s\\n' \"$(nmcli -t -f TYPE connection show --active 2>/dev/null | grep -v 'loopback\\|bridge\\|tun' | head -1)\"; true"]
        stdout: StdioCollector { onStreamFinished: root.parseStatus(text) }
    }
    Timer {
        interval: 8000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: statusProc.running = true
    }
}
