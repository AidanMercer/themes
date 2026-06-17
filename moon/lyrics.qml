import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// STEP 4 — line-level lyrics with per-word karaoke effects.
//
// Loaded by the quickshell themelyrics module while the moon wallpaper is
// showing. Builds on the step-1 clock (MPRIS position re-anchored each second +
// interpolated at 30fps) and the step-2 fetch (lyricvis-fetch.py over a Process
// → [{t, text}] lines, cached). This step renders the active line word-by-word:
//   - each line's time span is divided across its words by SYLLABLE weight;
//   - a word FILLS (a clip-reveal colour sweep) over at most fillCapMs, then
//     SUSTAINS — breathing/glowing for the rest of its slice, so a held note
//     keeps glowing instead of being swept off (end-of-line + long-vowel holds);
//   - active = neon + glow, already-sung = white, upcoming = grey.
// Mid-line single held words still need the v2 audio-onset pass to place exactly.
//
// Self-contained on purpose (lives outside the repo module tree, like clock.qml).
Item {
    id: root
    anchors.fill: parent

    MoonPalette { id: pal }
    readonly property color neon:    pal.neon
    readonly property color cyan:    pal.cyan
    readonly property color magenta: pal.magenta
    readonly property color dim:     pal.dim
    readonly property string mono:   "Noto Sans Mono"

    // ---- player selection ---------------------------------------------------
    // Re-evaluates whenever the set of MPRIS players changes. Prefer spotifyd;
    // fall back to whatever's playing, then to the first player there is.
    property var player: pickPlayer(Mpris.players ? Mpris.players.values : [])

    function pickPlayer(list) {
        if (!list || list.length === 0) return null
        let playing = null
        let supported = null
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            const tag = ((p.dbusName || "") + " " + (p.identity || "")).toLowerCase()
            if (tag.indexOf("spotify") !== -1) return p
            if (!supported && p.positionSupported) supported = p
            if (!playing && p.isPlaying) playing = p
        }
        // prefer something actually playing, then anything that reports a position,
        // so a browser tab that exposes no position can't hijack the readout
        return playing || supported || list[0]
    }

    // ---- interpolation clock ------------------------------------------------
    property real anchorPosMs: 0     // last real position read off MPRIS
    property real anchorWall: 0      // Date.now() when we read it
    property real estMs: 0           // smoothed estimate, updated at 30fps
    readonly property real lengthMs: player ? player.length * 1000 : 0
    readonly property bool playing: player ? player.isPlaying : false

    // Manual nudge (ms) to compensate for output buffering — the offset knob from
    // the plan. Wired to a hotkey later; fixed at 0 for now.
    property int offsetMs: 0

    function reanchor() {
        if (!player) return
        anchorPosMs = player.position * 1000   // Quickshell computes position live on read
        anchorWall = Date.now()
        tick()
    }

    // On a track change the player's last-known position is still the *previous*
    // track's for a beat, so don't trust it — zero out and let the 1s re-read catch
    // up. Worst case the readout starts at 0:00 and snaps to truth within a second.
    function resetAnchor() {
        anchorPosMs = 0
        anchorWall = Date.now()
        estMs = 0
    }

    function tick() {
        if (!player) { estMs = 0; return }
        let e = anchorPosMs + offsetMs
        if (playing) e += (Date.now() - anchorWall)
        if (lengthMs > 0) e = Math.max(0, Math.min(e, lengthMs))
        estMs = e
    }

    function fmt(ms) {
        if (ms < 0 || isNaN(ms)) ms = 0
        const t = Math.floor(ms / 1000)
        const m = Math.floor(t / 60)
        const s = t % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    onPlayerChanged: { reanchor(); clearLyrics(); fetchDebounce.restart() }
    Component.onCompleted: if (player) fetchDebounce.restart()

    // Re-read the authoritative position once a second; pause/resume and track
    // changes re-anchor immediately off their own signals. Quickshell computes
    // position live on read and never emits positionChanged itself, so a manual
    // scrub only re-syncs on the next 1s tick.
    Timer { interval: 1000; repeat: true; running: root.player !== null; onTriggered: root.reanchor() }
    Timer { interval: 33;   repeat: true; running: root.playing;         onTriggered: root.tick() }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onIsPlayingChanged()  { root.reanchor() }
        // title fires early (metadata still settling) — reset the display now;
        // postTrackChanged fires once metadata is coherent and drives the fetch.
        function onTrackTitleChanged() { root.resetAnchor(); root.clearLyrics(); fetchDebounce.restart() }
        function onPostTrackChanged()  { fetchDebounce.restart() }
    }

    // ---- lyrics fetch --------------------------------------------------------
    // [{t: ms, text}] for the current track, or [] if none / not yet loaded.
    property var lines: []
    property bool lyricsSynced: false
    property bool lyricsLoaded: false      // got an answer for the wanted track?
    property string wantKey: ""            // track we want lyrics for
    property string loadedKey: ""          // track currently displayed
    property string fetchingKey: ""        // track in flight ("" = idle)

    // Stable per-track key: prefer the spotify id from MPRIS metadata, else
    // title|artist. Dedupes fetches and (via the script) becomes the cache key.
    function trackKey() {
        if (!player) return ""
        let url = ""
        const m = player.metadata
        try { url = m ? (m["xesam:url"] || "") : "" } catch (e) { url = "" }
        if (url) {
            if (url.indexOf("spotify:track:") === 0) return url
            const i = url.indexOf("/track/")
            if (i !== -1) return "spotify:track:" + url.substring(i + 7).split("?")[0].split("/")[0]
        }
        return (player.trackTitle || "") + "|" + (player.trackArtist || "")
    }

    // Clear the displayed lyrics immediately on a track change so a stale line
    // from the previous song can never flash while the new fetch is in flight.
    function clearLyrics() {
        lines = []
        lyricsSynced = false
        lyricsLoaded = false
        loadedKey = ""
    }

    function requestLyrics() {
        if (!player || !player.trackTitle) return
        wantKey = trackKey()
        pump()
    }

    // Start a fetch for wantKey unless we already have it or one's in flight.
    // Quickshell's Process.running=true is a no-op while running and won't adopt
    // a reassigned command, so we never reassign mid-flight — onRunningChanged
    // re-pumps once the current run ends, so a skip during a fetch isn't lost.
    function pump() {
        if (!player) return
        if (fetchProc.running) return
        if (wantKey === "" || wantKey === loadedKey) return
        fetchingKey = wantKey
        // bash -c with --opt=value argv: $HOME expands, metadata passes safely as
        // argv (no shell injection), and '='-form survives titles starting with '-'
        fetchProc.command = [
            "bash", "-c",
            'exec python3 "$HOME/.config/quickshell/scripts/lyricvis-fetch.py" "$@"',
            "bash",
            "--id=" + wantKey,
            "--artist=" + (player.trackArtist || ""),
            "--title=" + (player.trackTitle || ""),
            "--album=" + (player.trackAlbum || ""),
            "--duration=" + String(Math.round(player.length || 0)),
        ]
        fetchProc.running = true
    }

    function applyLyrics(text) {
        let d = null
        try { d = JSON.parse(text) } catch (e) { d = null }
        // accept only a result for the track we still want — guards against a
        // late result for a track we've since skipped past, and empty output
        if (d && d.reqId === wantKey) {
            lines = d.lines || []
            lyricsSynced = !!d.synced
            lyricsLoaded = true
            loadedKey = wantKey
        }
        fetchingKey = ""
        pump()   // wantKey may have moved on while we were fetching
    }

    // Coalesce the title-change + postTrackChanged signals into one fetch, by
    // which point metadata (url/album/length) has settled.
    Timer { id: fetchDebounce; interval: 250; repeat: false; onTriggered: root.requestLyrics() }

    Process {
        id: fetchProc
        // applyLyrics() ends with pump(), so a skip that lands mid-fetch is
        // picked up when this run finishes — no onRunningChanged needed.
        stdout: StdioCollector { onStreamFinished: root.applyLyrics(text) }
    }

    // ---- active line / word --------------------------------------------------
    // Index of the last line whose timestamp is <= the smoothed clock, or -1
    // before the first line. Re-evaluates as estMs ticks.
    readonly property int activeIndex: {
        const L = lines
        const ms = estMs
        if (!L || L.length === 0 || ms < L[0].t) return -1
        let lo = 0, hi = L.length - 1, ans = -1
        while (lo <= hi) {
            const mid = (lo + hi) >> 1
            if (L[mid].t <= ms) { ans = mid; lo = mid + 1 } else hi = mid - 1
        }
        return ans
    }

    function lineText(i) {
        return (i >= 0 && lines[i]) ? (lines[i].text || "") : ""
    }
    function lineEnd(i) {
        if (i + 1 < lines.length) return lines[i + 1].t
        // last line: hold until track end, but guard a stale/short length that
        // would collapse the span (then the line would snap through instantly)
        if (lines[i] && lengthMs > lines[i].t) return lengthMs
        return lines[i] ? lines[i].t + 4000 : 0
    }

    readonly property var activeWords:
        (activeIndex >= 0 && lineText(activeIndex).length)
            ? lineText(activeIndex).split(/\s+/).filter(function (w) { return w.length })
            : []

    // ---- per-word timing (syllable-paced) + held-note sustain ---------------
    // Each word gets a *natural* duration from its syllables, packed from the line
    // start. If the line is sung faster than that estimate we compress to fit; if
    // there's slack (the common slow-song case) the LAST word absorbs it as a
    // sustain — an end-of-line hold that breathes until the next line. This tracks
    // the real vocal onset instead of smearing words across a long trailing gap.
    property int baseWordMs: 60         // fixed per-word cost
    property int perSyllableMs: 220     // added per syllable (lower = faster sweep)
    // Cap the last-word breath. Without audio we can't tell a held vocal from an
    // instrumental gap, and a long gap to the next line is *usually* just a beat,
    // so keep the end-hold short and settle to 'sung' rather than breathe falsely.
    property int holdCapMs: 1500

    function syllables(word) {
        const w = word.toLowerCase().replace(/[^a-z]/g, "")
        if (!w.length) return 1
        const m = w.match(/[aeiouy]+/g)
        let n = m ? m.length : 1
        if (w.length > 2 && w.charAt(w.length - 1) === "e"
            && "aeiouy".indexOf(w.charAt(w.length - 2)) === -1) n -= 1   // silent e
        return Math.max(1, n)
    }

    // [{start, fillEnd, end}] ms per word of the active line. fill (colour sweep)
    // is [start, fillEnd]; sustain (breath) is [fillEnd, end], non-empty only for
    // a held word (the last one, which extends to the next line). Recomputed on
    // line change only — does NOT read estMs.
    readonly property var wordSpans: {
        const ai = activeIndex
        const ws = activeWords
        const n = ws.length
        if (ai < 0 || n === 0) return []
        const start = lines[ai].t
        const span = Math.max(1, lineEnd(ai) - start)
        let dur = [], total = 0
        for (let i = 0; i < n; i++) {
            const d = baseWordMs + perSyllableMs * syllables(ws[i])
            dur.push(d); total += d
        }
        const k = total > span ? span / total : 1   // compress only if sung fast
        let out = [], onset = start
        for (let i = 0; i < n; i++) {
            const d = dur[i] * k
            out.push({ start: onset, fillEnd: onset + d, end: onset + d })
            onset += d
        }
        // last word holds the slack as a sustain, capped so a long instrumental gap
        // doesn't leave one word breathing forever — it settles to 'sung' after holdCapMs
        const le = lineEnd(ai)
        out[n - 1].end = Math.max(out[n - 1].fillEnd, Math.min(le, out[n - 1].fillEnd + holdCapMs))
        return out
    }

    // Per-word render state at time `est`: fill 0..1 plus active/sustain phase.
    // est is passed in so the binding tracks the 30fps clock.
    function wordState(i, est) {
        const sp = wordSpans
        if (i < 0 || i >= sp.length) return { fill: 0, active: false, sustain: false }
        const s = sp[i].start, fe = sp[i].fillEnd, e = sp[i].end
        if (est >= e) return { fill: 1, active: false, sustain: false }   // already sung
        if (est < s)  return { fill: 0, active: false, sustain: false }   // upcoming
        if (est < fe && fe > s) return { fill: (est - s) / (fe - s), active: true, sustain: false }
        return { fill: 1, active: true, sustain: true }                   // held: breathing
    }

    // ---- rendering helpers ---------------------------------------------------
    function hex(c) {
        function h(x) { let v = Math.round(x * 255).toString(16); return v.length < 2 ? "0" + v : v }
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }

    readonly property real uiScale: pal.uiScale
    readonly property real lyricWidth: Math.min(root.width * 0.62, 1100)

    // ---- lyric display -------------------------------------------------------
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.12)
        width: backing.width
        height: backing.height
        scale: root.uiScale
        transformOrigin: Item.Bottom
        visible: root.player !== null

        Rectangle {
            id: backing
            width: col.width + 56
            height: col.height + 36
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.45)
            border.color: Qt.rgba(root.neon.r, root.neon.g, root.neon.b, 0.30)
            border.width: 1

            Column {
                id: col
                anchors.centerIn: parent
                width: root.lyricWidth
                spacing: 10

                // previous line (context, faint)
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    visible: root.activeIndex > 0
                    text: root.lineText(root.activeIndex - 1)
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: root.mono
                    font.pixelSize: 18
                }

                // current line — per-word karaoke (clip-reveal fill + neon glow +
                // held-note breath), or a fallback status when there's no line.
                Item {
                    width: parent.width
                    height: 72

                    Row {
                        id: wordRow
                        anchors.centerIn: parent
                        spacing: 12
                        visible: root.activeWords.length > 0
                        // keep the line on one row: shrink to fit, but not unreadable
                        scale: Math.max(0.62, implicitWidth > root.lyricWidth ? root.lyricWidth / implicitWidth : 1)
                        transformOrigin: Item.Center

                        Repeater {
                            model: root.activeWords
                            delegate: Item {
                                id: wd
                                required property int index
                                required property string modelData
                                readonly property var st: root.wordState(index, root.estMs)
                                readonly property real fill: st.fill
                                readonly property bool lit: st.active || st.sustain   // neon vs white/grey
                                property real pulse: 0

                                width: wbase.implicitWidth
                                height: wbase.implicitHeight
                                scale: 1 + (st.active ? 0.06 : 0) + pulse * 0.05
                                transformOrigin: Item.Center

                                Text {
                                    id: wbase
                                    text: wd.modelData
                                    textFormat: Text.PlainText
                                    color: "#8a8a93"                                  // upcoming
                                    font.family: root.mono; font.pixelSize: 30; font.bold: true
                                }
                                // neon halo behind the lit fill only
                                Glow {
                                    anchors.fill: wfillClip
                                    source: wfillClip
                                    visible: wd.lit
                                    color: root.neon
                                    radius: 5 + wd.pulse * 7
                                    samples: 25
                                    spread: 0.25
                                }
                                // filled portion, revealed left→right by fill
                                Item {
                                    id: wfillClip
                                    width: parent.width * Math.max(0, Math.min(1, wd.fill))
                                    height: parent.height
                                    clip: true
                                    Text {
                                        width: wbase.width
                                        text: wd.modelData
                                        textFormat: Text.PlainText
                                        color: wd.lit ? root.neon : "#ffffff"         // active vs sung
                                        font.family: root.mono; font.pixelSize: 30; font.bold: true
                                    }
                                }
                                // held-note breath while sustaining; reset when it ends
                                SequentialAnimation {
                                    running: wd.st.sustain
                                    loops: Animation.Infinite
                                    NumberAnimation { target: wd; property: "pulse"; to: 1; duration: 480; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: wd; property: "pulse"; to: 0; duration: 480; easing.type: Easing.InOutSine }
                                }
                                onLitChanged: if (!lit) pulse = 0
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.activeWords.length === 0
                        textFormat: Text.RichText
                        horizontalAlignment: Text.AlignHCenter
                        font.family: root.mono
                        font.pixelSize: 30
                        text: !root.lyricsLoaded ? "<span style='color:#8a8a93'>…</span>"
                              : !root.lyricsSynced ? "<span style='color:#8a8a93'>♪ no synced lyrics</span>"
                              : "<span style='color:" + root.hex(root.neon) + "'>♪</span>"
                    }
                }

                // next line (context, faint)
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    visible: root.activeIndex + 1 < root.lines.length
                    text: root.lineText(root.activeIndex + 1)
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: root.mono
                    font.pixelSize: 18
                }

            }
        }
    }

    // Nothing playing on any player → quiet hint so we know it's alive, not stuck.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.12)
        visible: root.player === null
        text: "lyricvis: waiting for a player…"
        color: root.dim
        font.family: root.mono
        font.pixelSize: 14
    }
}
