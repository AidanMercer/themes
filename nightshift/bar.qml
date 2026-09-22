import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris
import "windows.js" as W

// nightshift: the street the city stands on — a dark band across the top with
// the blocks set out along it. Workspaces are buildings: a building's lit
// floors count the windows open there, the active one burns sodium all the way
// up, and switching workspaces relights both blocks room by room. On the right
// the vitals are buildings too — cpu and mem fill bottom-up under plain
// labels, and the now-playing strip lights its rooms as the track runs.
//
// Everything on this bar is the same primitive as the clock: rooms, lit or not.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color sodium: pal.neon
    readonly property color haze: pal.cyan
    readonly property color beacon: pal.magenta
    readonly property color lampAmber: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string sans: "Noto Sans"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property real ui: pal.uiScale
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function hazeA(a)   { return Qt.rgba(haze.r, haze.g, haze.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function sodiumA(a) { return Qt.rgba(sodium.r, sodium.g, sodium.b, a) }
    function glassA(a)  { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    readonly property int wsCount: 10
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
    readonly property real slotW: Math.round(31 * ui)
    readonly property real stripW: wsCount * slotW
    // where the single strip sits when the screen is whole: just past the door
    // and its divider in the left row
    readonly property real homeCentre: Math.round((14 + 26 + 12 + 12) * ui) + 1 + stripW / 2

    // ── split mode ──────────────────────────────────────────────────────────
    // Super+D cuts the monitor into two halves that each run their own stack of
    // spaces. The hypr scripts mirror that into a runtime file; themes can't
    // import shell singletons, so read it directly (same as the lyric offset).
    // When the screen splits, the street splits: one district of blocks centred
    // in each half, and only the half holding focus keeps its lights up.
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
        onFileChanged: reload()
        onLoaded: {
            // the writers truncate before writing, so a read can land on an
            // empty or half-written file — hold the last good state rather than
            // reading it as "not split", which flips both districts back into
            // one strip for a frame on every switch
            const t = text()
            if (!t || !t.trim()) return
            let s
            try { s = JSON.parse(t) } catch (e) { return }
            root.splitOn = !!s.on
            root.splitSeam = s.seam ?? 0
            root.splitRight = s.right ?? 1
            root.splitZone = s.zone ?? "l"
            root.splitMonitor = s.monitor ?? ""
        }
    }

    // One district when the screen is whole, two when it's split — each centred
    // in its own half. The right half runs Hyprland's special workspaces, so it
    // pages off `splitRight` and matches windows by name instead of id.
    //
    // Every slot a delegate needs is baked in HERE. A delegate's first bindings
    // evaluate before its outer scope is linked, so reading root.* from one
    // comes up undefined and the whole strip renders dark — passing the page
    // maths down as model data keeps each delegate self-contained.
    function _slots(base, act, special, side) {
        const out = []
        // Super+` scratchpad rides in front of workspace 1 as slot 0 while it
        // holds windows — regular deck only (the right half's specials are its
        // own). pal.scratchpad is the shell's tracker (count / id / shown).
        if (!special && (pal.scratchpad?.count ?? 0) > 0)
            out.push({ id: pal.scratchpad.id, special: false, side: side,
                       active: pal.scratchpad.shown[monitor?.name ?? ""] === true })
        for (let i = 0; i < wsCount; i++)
            out.push({ id: base + i, active: (base + i) === act, special: special, side: side })
        return out
    }
    function _base(cur) { return cur >= 1 ? Math.floor((cur - 1) / wsCount) * wsCount + 1 : 1 }

    readonly property var decks: {
        if (!split)
            return [{ centre: homeCentre, live: true, side: "",
                      slots: _slots(_base(activeWsId), activeWsId, false, "") }]
        return [
            { centre: splitSeam / 2, live: splitZone === "l", side: "l",
              slots: _slots(_base(activeWsId), activeWsId, false, "l") },
            { centre: splitSeam + (width - splitSeam) / 2, live: splitZone === "r", side: "r",
              slots: _slots(_base(splitRight), splitRight, true, "r") }
        ]
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    // ── the band ────────────────────────────────────────────────────────────
    // near-solid: the wallpaper's brightest sky band sits directly behind the
    // bar, so the street has to be its own darkness
    Rectangle { anchors.fill: parent; color: root.glassA(0.90) }
    Rectangle {   // kerb light along the bottom edge
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: root.hazeA(0.30)
    }

    Item {
        anchors.fill: parent
        opacity: root.bootT

        // ── left: the door, then the blocks ──────────────────────────────────
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(14 * root.ui)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(12 * root.ui)

            // the lit door — opens the control menu
            Item {
                width: Math.round(26 * root.ui); height: Math.round(26 * root.ui)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(24 * root.ui); height: width; radius: 3
                    color: doorMa.containsMouse ? root.sodiumA(0.14) : "transparent"
                    Behavior on color { ColorAnimation { duration: 240 } }
                }
                // a doorway: two dark rooms and one lit one above the threshold
                Column {
                    anchors.centerIn: parent
                    spacing: Math.max(1, Math.round(1.5 * root.ui))
                    Row {
                        spacing: Math.max(1, Math.round(1.5 * root.ui))
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                width: Math.round(4 * root.ui); height: width
                                color: index === 1 ? root.sodium : root.slateA(0.75)
                                opacity: index === 1 ? (doorMa.containsMouse ? 1 : 0.9) : 1
                            }
                        }
                    }
                    Row {
                        spacing: Math.max(1, Math.round(1.5 * root.ui))
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                width: Math.round(4 * root.ui); height: width
                                color: doorMa.containsMouse && index === 1 ? root.sodium : root.slateA(0.75)
                            }
                        }
                    }
                    Rectangle {   // the doorway itself
                        width: Math.round(4 * root.ui); height: Math.round(6 * root.ui)
                        x: Math.round(5.5 * root.ui)
                        color: doorMa.containsMouse ? root.sodiumA(0.9) : root.hazeA(0.55)
                    }
                }
                MouseArea {
                    id: doorMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                }
            }

            Rectangle {
                width: 1; height: Math.round(20 * root.ui)
                anchors.verticalCenter: parent.verticalCenter
                color: root.slateA(0.85)
            }
        }

        // ── the districts: one strip of blocks per half of the screen ────────
        // One building per workspace, its lit floors counting the windows open
        // there, the active one burning all the way up. Whole screen → one
        // district sitting by the door. Split → two, each centred in its half,
        // and the half that doesn't hold focus goes to half brightness so you
        // can see where the next keystroke lands.
        Repeater {
            model: root.decks

            delegate: Item {
                id: deck
                required property var modelData        // { centre, live, side, slots }
                readonly property bool live: modelData.live

                width: deck.modelData.slots.length * root.slotW   // 11 wide while the scratchpad rides
                height: root.height
                x: Math.round(modelData.centre - width / 2)
                anchors.verticalCenter: parent.verticalCenter
                opacity: deck.live ? 1.0 : 0.62

                // the district slides to its half rather than cutting there
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Repeater {
                    model: deck.modelData.slots
                    delegate: Item {
                        id: slot
                        required property int index
                        required property var modelData    // { id, active, special, side }
                        readonly property int wsId: modelData.id
                        readonly property bool isActive: modelData.active
                        readonly property bool isSpecial: modelData.special
                        // the right half lives on special workspaces, which match
                        // by name (special:spN) rather than by id
                        readonly property var windowsHere: Hyprland.toplevels.values
                            .filter(t => slot.isSpecial
                                ? (t.workspace?.name ?? "") === "special:sp" + slot.wsId
                                : (t.workspace?.id ?? -1) === slot.wsId)
                        readonly property int winCount: windowsHere.length
                        readonly property bool isOccupied: winCount > 0

                        x: index * root.slotW
                        width: root.slotW
                        height: parent.height

                        IconImage {
                            id: wsIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(3 * root.ui)
                            width: Math.round(16 * root.ui)
                            height: width
                            visible: slot.isOccupied
                            source: slot.isOccupied ? root.iconForWindows(slot.windowsHere) : ""
                            opacity: slot.isActive ? 1 : 0.82
                        }

                        Facade {
                            id: bldg
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(22 * root.ui)
                            cols: 3
                            rows: 3
                            cell: Math.round(5 * root.ui)
                            gap: Math.max(1, Math.round(1.5 * root.ui))
                            lit: root.sodium
                            dark: root.slate
                            darkAlpha: slot.isActive ? 0.5 : 0.3
                            dim: slot.isActive ? 1.0 : 0.5
                            occluded: root.occluded
                            spread: 300
                            plan: {
                                const p = W.blank(3, 3)
                                if (slot.isActive) {
                                    for (let i = 0; i < 9; i++) p[i] = 1
                                } else if (slot.isOccupied) {
                                    // one lit floor per window, up to the roof
                                    W.planLevel(p, 3, 3, Math.min(1, slot.winCount / 3))
                                }
                                return p
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // while split, route through zone.sh so the click
                            // switches THIS half, not whichever holds focus
                            onClicked: {
                                if (slot.wsId < 0)
                                    Hyprland.dispatch("togglespecialworkspace scratchpad")
                                else if (root.split)
                                    Quickshell.execDetached([root.zoneScript, "space",
                                        String(slot.wsId), slot.modelData.side])
                                else
                                    Hyprland.dispatch(`workspace ${slot.wsId}`)
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (w) => {
                        if (root.split) {
                            // scrolling a district walks that half's own stack
                            const cur = deck.modelData.slots.find(s => s.active)
                            const step = w.angleDelta.y > 0 ? -1 : 1
                            const next = Math.max(1, Math.min(root.wsCount,
                                (cur ? cur.id : 1) + step))
                            Quickshell.execDetached([root.zoneScript, "space",
                                String(next), deck.modelData.side])
                        } else {
                            Hyprland.dispatch(w.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
                        }
                    }
                }
            }
        }

        // ── centre: the hour, plainly ────────────────────────────────────────
        Row {
            anchors.centerIn: parent
            spacing: Math.round(12 * root.ui)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.inkA(1)
                font.family: root.mono
                font.pixelSize: Math.round(16 * root.ui)
                font.letterSpacing: 1.5
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(4 * root.ui); height: width
                color: root.sodium
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM").toLowerCase()
                color: root.inkA(0.86)
                font.family: root.sans
                font.pixelSize: Math.round(13 * root.ui)
                font.weight: Font.Medium
                font.letterSpacing: 1.2
            }
        }

        // ── right: track · cpu · mem · net · battery ─────────────────────────
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(16 * root.ui)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(18 * root.ui)

            // now playing — the strip of rooms under the title lights as the
            // track runs, so progress is told in windows like everything else
            Item {
                visible: root.mediaActive
                width: mediaCol.width
                height: mediaCol.height
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    id: mediaCol
                    spacing: Math.round(3 * root.ui)
                    Row {
                        spacing: Math.round(7 * root.ui)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(5 * root.ui); height: width
                            color: root.mediaPlaying ? root.sodium : root.slateA(0.9)
                        }
                        Text {
                            id: mediaTitle
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.mediaLabel
                            textFormat: Text.PlainText
                            color: root.inkA(0.92)
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, Math.round(240 * root.ui))
                            font.family: root.mono
                            font.pixelSize: Math.round(12 * root.ui)
                        }
                    }
                    Facade {
                        id: trackStrip
                        cols: 30
                        rows: 1
                        cell: Math.round(4 * root.ui)
                        gap: Math.max(1, Math.round(1.5 * root.ui))
                        lit: root.sodium
                        dark: root.slate
                        darkAlpha: 0.32
                        flicker: false
                        occluded: root.occluded
                        spread: 260
                        dim: root.mediaPlaying ? 1.0 : 0.55
                        plan: {
                            const p = W.blank(30, 1)
                            const n = Math.round(root.mediaProgress * 30)
                            for (let i = 0; i < n; i++) p[i] = 1
                            return p
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.mediaActive && root.player.canTogglePlaying) root.player.togglePlaying()
                    onWheel: (w) => {
                        if (!root.mediaActive) return
                        // shift+scroll nudges the live lyric offset, house standard
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

            // vitals — plain labels, buildings for values. Hovering pulls the
            // full board down; hidden entirely when the sysinfo slot is off.
            Row {
                id: vitals
                spacing: Math.round(16 * root.ui)
                anchors.verticalCenter: parent.verticalCenter
                visible: root.pal.sysinfoOn !== false
                HoverHandler {
                    enabled: root.pal.sysinfoOn !== false
                    onHoveredChanged: sysFlag.setText(hovered ? "1" : "0")
                }

                Row {
                    spacing: Math.round(7 * root.ui)
                    anchors.verticalCenter: parent.verticalCenter
                    Facade {
                        anchors.verticalCenter: parent.verticalCenter
                        cols: 4; rows: 4
                        cell: Math.round(4 * root.ui)
                        gap: Math.max(1, Math.round(1.5 * root.ui))
                        lit: root.cpuPct > 0.9 ? root.beacon
                           : root.cpuPct > 0.75 ? root.lampAmber : root.sodium
                        dark: root.slate
                        darkAlpha: 0.34
                        flicker: false
                        occluded: root.occluded
                        spread: 300
                        plan: W.planLevel(W.blank(4, 4), 4, 4, root.cpuPct)
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            text: "cpu"
                            color: root.hazeA(0.9)
                            font.family: root.sans
                            font.pixelSize: Math.round(10 * root.ui)
                            font.letterSpacing: 1.4
                        }
                        Text {
                            text: Math.round(root.cpuPct * 100) + "%"
                            color: root.inkA(0.92)
                            font.family: root.mono
                            font.pixelSize: Math.round(12 * root.ui)
                        }
                    }
                }

                Row {
                    spacing: Math.round(7 * root.ui)
                    anchors.verticalCenter: parent.verticalCenter
                    Facade {
                        anchors.verticalCenter: parent.verticalCenter
                        cols: 4; rows: 4
                        cell: Math.round(4 * root.ui)
                        gap: Math.max(1, Math.round(1.5 * root.ui))
                        lit: root.memPct > 0.9 ? root.beacon
                           : root.memPct > 0.75 ? root.lampAmber : root.sodium
                        dark: root.slate
                        darkAlpha: 0.34
                        flicker: false
                        occluded: root.occluded
                        spread: 300
                        plan: W.planLevel(W.blank(4, 4), 4, 4, root.memPct)
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            text: "mem"
                            color: root.hazeA(0.9)
                            font.family: root.sans
                            font.pixelSize: Math.round(10 * root.ui)
                            font.letterSpacing: 1.4
                        }
                        Text {
                            text: Math.round(root.memPct * 100) + "%"
                            color: root.inkA(0.92)
                            font.family: root.mono
                            font.pixelSize: Math.round(12 * root.ui)
                        }
                    }
                }
            }

            // the wire in: haze blue while the city is reachable, beacon when not
            Row {
                spacing: Math.round(6 * root.ui)
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(root.connType === "ethernet" ? 0xF059F
                        : root.connType === "wifi" ? 0xF05A9 : 0xF092F)
                    font.family: root.iconFont
                    font.pixelSize: Math.round(15 * root.ui)
                    color: root.connType === "none" ? root.beacon : root.hazeA(0.95)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.connType === "none" ? "offline" : root.connType
                    color: root.connType === "none" ? root.beacon : root.inkA(0.82)
                    font.family: root.sans
                    font.pixelSize: Math.round(11 * root.ui)
                    font.letterSpacing: 0.8
                }
            }

            // battery, when there is one
            Row {
                visible: root.batPct >= 0
                spacing: Math.round(7 * root.ui)
                anchors.verticalCenter: parent.verticalCenter
                Facade {
                    anchors.verticalCenter: parent.verticalCenter
                    cols: 5; rows: 3
                    cell: Math.round(4 * root.ui)
                    gap: Math.max(1, Math.round(1.5 * root.ui))
                    lit: root.batCharging ? root.haze
                       : root.batPct <= 15 ? root.beacon
                       : root.batPct <= 30 ? root.lampAmber : root.sodium
                    dark: root.slate
                    darkAlpha: 0.34
                    flicker: false
                    occluded: root.occluded
                    plan: W.planLevel(W.blank(5, 3), 5, 3, Math.max(0, root.batPct) / 100)
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        text: root.batCharging ? "batt +" : "batt"
                        color: root.hazeA(0.9)
                        font.family: root.sans
                        font.pixelSize: Math.round(10 * root.ui)
                        font.letterSpacing: 1.4
                    }
                    Text {
                        text: root.batPct + "%"
                        color: root.batPct <= 15 && !root.batCharging ? root.beacon : root.inkA(0.92)
                        font.family: root.mono
                        font.pixelSize: Math.round(12 * root.ui)
                    }
                }
            }
        }
    }

    // hover flag shared with sysinfo.qml — the vitals row writes here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    // ── mpris ────────────────────────────────────────────────────────────────
    readonly property var player: {
        const ps = Mpris.players.values
        if (ps.length === 0) return null
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
    }
    readonly property bool mediaActive: player !== null
    readonly property bool mediaPlaying: mediaActive && player.playbackState === MprisPlaybackState.Playing
    readonly property string mediaLabel: {
        if (!mediaActive) return ""
        const t = player.trackTitle || "—"
        const a = player.trackArtist
        return a ? t + " · " + a : t
    }
    property real mediaProgress: 0
    Timer {
        interval: 1000; repeat: true
        running: root.mediaPlaying && !root.occluded
        triggeredOnStart: true
        onTriggered: {
            const p = root.player
            root.mediaProgress = (p && p.length > 0 && p.position >= 0)
                ? Math.min(1, p.position / p.length) : 0
        }
    }

    // ── vitals + net + battery, one poll ─────────────────────────────────────
    property string connType: "none"
    property real cpuPct: 0
    property real memPct: 0
    property int batPct: -1
    property bool batCharging: false
    property var _prevCpu: null

    function parseStats(out) {
        let memT = 0, memA = 0
        for (const raw of out.trim().split("\n")) {
            const l = raw.trim()
            if (l.startsWith("net:")) root.connType = l.slice(4) || "none"
            else if (l.startsWith("cpu ")) {
                const f = l.split(/\s+/).slice(1).map(Number)
                const tot = f.reduce((a, b) => a + b, 0)
                const idle = f[3] + (f[4] || 0)
                if (root._prevCpu) {
                    const dt = tot - root._prevCpu.tot, di = idle - root._prevCpu.idle
                    if (dt > 0) root.cpuPct = Math.max(0, Math.min(1, (dt - di) / dt))
                }
                root._prevCpu = { tot: tot, idle: idle }
            }
            else if (l.startsWith("MemTotal")) memT = parseInt(l.split(/\s+/)[1])
            else if (l.startsWith("MemAvailable")) memA = parseInt(l.split(/\s+/)[1])
            else if (/^[0-9]+$/.test(l)) root.batPct = parseInt(l)
            else if (/^(Charging|Discharging|Full|Not charging)$/.test(l)) root.batCharging = l === "Charging"
        }
        if (memT > 0) root.memPct = Math.max(0, Math.min(1, 1 - memA / memT))
    }
    Process {
        id: statProc
        command: ["bash", "-c",
            'printf "net:%s\\n" "$(nmcli -t -f TYPE,STATE d 2>/dev/null | grep -m1 \':connected$\' | cut -d: -f1)"; ' +
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; " +
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1; true"]
        stdout: StdioCollector { onStreamFinished: root.parseStats(text) }
    }
    Timer {
        interval: 3000; repeat: true; running: !root.occluded; triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    // ── workspace icon lookup ────────────────────────────────────────────────
    // keep the .desktop database observed so heuristicLookup() works
    readonly property int _keepAlive: DesktopEntries.applications.values.length
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
}
