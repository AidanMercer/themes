import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// Cyberpunk: Edgerunners top bar for the "moon" wallpaper.
//
// Loaded by the quickshell bar wrapper while this wallpaper is showing, in place
// of the default bar. Self-contained (lives outside the repo's module tree), so
// it talks straight to the public Quickshell services and rebuilds the default
// bar's clusters, restyled as a cyberdeck readout:
//   • center — workspace tabs: app icon per occupied workspace, click to switch
//   • far left — mpris now-playing chip with a progress underline
// System info isn't here — it's a separate bottom-right widget (moon/sysinfo.qml).
// Chamfered dark panels with neon edges, a full-width HUD underline, no glitch.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null

    // injected by the loader (setSource initial property)
    required property var pal
    // injected by the loader — true while the session is locked, so pollers park
    property bool occluded: false
    readonly property color neon:    pal.neon
    readonly property color cyan:    pal.cyan
    readonly property color magenta: pal.magenta
    readonly property color amber:   pal.amber
    readonly property color dim:     pal.dim
    readonly property string mono:   pal.fontMono
    readonly property string icon:   "Symbols Nerd Font"

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    // ── split mode ──────────────────────────────────────────────────────────
    // The hypr scripts mirror what they did into a runtime file; themes can't
    // import shell singletons so we read it directly, same as the lyric offset.
    // While it says split, the deck splits with it: one panel per half, each
    // driving its own stack.
    property bool splitOn: false
    property int splitSeam: 0
    property int splitRight: 1
    property string splitZone: "l"
    property string splitMonitor: ""
    readonly property bool split: splitOn && barScreen && barScreen.name === splitMonitor
    readonly property string zoneScript: Quickshell.env("HOME") + "/dotfiles/.config/hypr/zone.sh"

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/world80-split"
        watchChanges: true
        blockLoading: true
        preload: true
        printErrors: false
        onLoaded: {
            // the writers truncate before writing, so a read can land on an empty
            // or half-written file. keep the last good values rather than reading
            // it as "not split" — that flipped the deck back to one centred panel
            // for a frame on every switch
            const t = text()
            if (!t || !t.trim()) return
            let s
            try {
                s = JSON.parse(t)
            } catch (e) {
                return
            }
            root.splitOn = !!s.on
            root.splitSeam = s.seam ?? 0
            root.splitRight = s.right ?? 1
            root.splitZone = s.zone ?? "l"
            root.splitMonitor = s.monitor ?? ""
        }
        onFileChanged: reload()
    }

    readonly property int regularActive: monitor?.activeWorkspace?.id ?? 1

    // one deck when whole, two when split — each centred in its own half
    readonly property var decks: root.split
        ? [{ side: "l", centre: root.splitSeam / 2, special: false },
           { side: "r", centre: root.splitSeam + (root.width - root.splitSeam) / 2, special: true }]
        : [{ side: "", centre: root.width / 2, special: false }]

    // keep the .desktop database observed so heuristicLookup() works
    readonly property int _keepAlive: DesktopEntries.applications.values.length

    // Hyprland.toplevels is empty until refreshed; re-query on window events
    // so each slot's app icon stays current.
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

    // boot-in: panels drop into place once on load (replays on theme reload).
    // bootMedia trails bootT so the chip lands a beat after the workspaces.
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
    readonly property real bootMedia: Math.max(0, (bootT - 0.35) / 0.65)

    // chamfered dark panel (cut top-left + bottom-right corners), neon edge
    function paintPanel(ctx, w, h, stroke) {
        const c = 9
        ctx.reset()
        ctx.beginPath()
        ctx.moveTo(c, 0)
        ctx.lineTo(w, 0)
        ctx.lineTo(w, h - c)
        ctx.lineTo(w - c, h)
        ctx.lineTo(0, h)
        ctx.lineTo(0, c)
        ctx.closePath()
        ctx.fillStyle = "rgba(8,8,10,0.66)"
        ctx.fill()
        ctx.strokeStyle = stroke
        ctx.lineWidth = 1.4
        ctx.stroke()
    }

    // ── the deck: workspace tabs, one per half while split ──────────────────
    Repeater {
        model: root.decks

        delegate: Item {
            id: deck
            required property var modelData
            readonly property bool special: modelData.special
            // whole-screen deck always reads as live; split decks light the one
            // holding focus so you can see where the next keystroke lands
            readonly property bool live: !root.split || root.splitZone === modelData.side
            readonly property int activeId: special ? root.splitRight : root.regularActive
            readonly property color edge: live ? root.neon : root.dim

            // both halves page the same way — ten slots, rolling over to the next
            // ten once that half's stack climbs past them
            readonly property var ids: {
                const cur = deck.activeId
                const base = cur >= 1 ? Math.floor((cur - 1) / 10) * 10 + 1 : 1
                const a = []
                for (let i = 0; i < 10; i++) a.push(base + i)
                return a
            }

            function windowsOn(id) {
                return deck.special
                    ? Hyprland.toplevels.values.filter(t => (t.workspace?.name ?? "") === "special:sp" + id)
                    : Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? -1) === id)
            }

            height: 30
            width: deckRow.width + 30
            x: Math.round(modelData.centre - width / 2)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6 * (1 - root.bootT)
            opacity: root.bootT * (live ? 1.0 : 0.72)

            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Canvas {
                id: deckBg
                anchors.fill: parent
                onPaint: root.paintPanel(getContext("2d"), width, height, deck.edge)
                onWidthChanged: requestPaint()
            }
            onEdgeChanged: deckBg.requestPaint()

            Row {
                id: deckRow
                anchors.centerIn: parent
                spacing: 9

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: deck.ids

                        delegate: Item {
                            id: slot
                            required property int modelData
                            readonly property int wsId: modelData
                            readonly property bool isActive: deck.activeId === wsId
                            readonly property var windowsHere: deck.windowsOn(wsId)
                            readonly property bool isOccupied: windowsHere.length > 0

                            width: 22
                            height: 24

                            // empty: a thin neon dash, dim
                            Rectangle {
                                anchors.centerIn: parent
                                visible: !slot.isOccupied
                                width: 8; height: 2
                                color: deck.edge
                                opacity: slot.isActive ? 0.9 : 0.3
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            // occupied: app icon, dimmed unless active
                            IconImage {
                                anchors.centerIn: parent
                                visible: slot.isOccupied
                                width: 16; height: 16
                                source: slot.isOccupied ? root.iconForWindows(slot.windowsHere) : ""
                                opacity: slot.isActive ? 1.0 : 0.55
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            // active marker: neon underline
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: slot.isActive
                                width: parent.width; height: 2
                                color: deck.edge
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                // split: go through zone.sh so the click switches
                                // THIS half, not whichever one happens to be focused
                                onClicked: {
                                    if (root.split)
                                        Quickshell.execDetached([root.zoneScript, "space",
                                            String(slot.wsId), deck.modelData.side])
                                    else
                                        Hyprland.dispatch(`workspace ${slot.wsId}`)
                                }
                            }
                        }
                    }
                }

                // divider + status button: toggles the control popup over IPC
                // (qs ipc → ControlBus → the per-screen ControlPopup in shell.qml)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1; height: 16
                    color: root.dim
                    opacity: 0.6
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 24

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF303)   // nf-linux-archlinux
                        font.family: root.icon
                        font.pixelSize: 15
                        color: deck.edge
                        opacity: statusMa.containsMouse ? 1.0 : 0.78
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: statusMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                    }
                }
            }
        }
    }

    // ── far left: now-playing (mpris / spotifyd), cyan-edged HUD chip ────────
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
        height: 30
        width: active ? mediaRow.width + 22 : 0
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -6 * (1 - root.bootMedia)
        opacity: root.bootMedia

        // track progress for the underline — mpris position re-read once a second
        property real progress: 0
        function updateProgress() {
            const p = media.player
            media.progress = (p && p.length > 0 && p.position >= 0)
                ? Math.min(1, p.position / p.length) : 0
        }
        Timer {
            interval: 1000; repeat: true
            running: media.playing && !root.occluded
            triggeredOnStart: true
            onTriggered: media.updateProgress()
        }

        Canvas {
            anchors.fill: parent
            visible: media.active
            onPaint: root.paintPanel(getContext("2d"), width, height, root.cyan)
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Row {
            id: mediaRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: media.playing ? String.fromCodePoint(0xF03E4) : String.fromCodePoint(0xF040A)
                color: root.neon
                font.family: root.icon
                font.pixelSize: 13
                opacity: mediaMa.containsMouse ? 1.0 : 0.85
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
                text: {
                    if (!media.active) return ""
                    const t = media.player.trackTitle || "—"
                    const a = media.player.trackArtist
                    return a ? t + "  ·  " + a : t
                }
                textFormat: Text.PlainText
                color: root.cyan
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 0.5
            }
        }

        // progress underline along the chip's bottom edge (stops short of the
        // chamfered corner)
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 2
            anchors.bottomMargin: 1
            height: 2
            width: Math.max(0, (parent.width - 12) * media.progress)
            color: root.cyan
            opacity: 0.85
            Behavior on width { NumberAnimation { duration: 900 } }
        }

        MouseArea {
            id: mediaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (media.active && media.player.canTogglePlaying) media.player.togglePlaying()
            onWheel: (w) => {
                if (!media.active) return
                // Shift+scroll nudges the live lyric offset (up = earlier, down =
                // later); the offset OSD flash on each monitor gives the feedback.
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

    // System info lives in its own bottom-right widget now (moon/sysinfo.qml),
    // loaded by the ThemeSysInfo overlay — not crammed into the top bar.
}
