import QtQuick
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

    // injected by the loader (setSource initial property)
    required property var pal
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

    // True only on the primary-screen instance (set by ThemeLyrics' Loader once the
    // item exists). Gates the single cava silence-detector so the theme showing on
    // multiple monitors doesn't spawn one cava reader per screen.
    property bool isPrimary: false

    // ---- interpolation clock ------------------------------------------------
    property real anchorPosMs: 0          // last real position read off MPRIS
    property real anchorWall: Date.now()  // Date.now() when we read it
    property real estMs: 0                // smoothed estimate, updated at 30fps
    property bool anchored: false         // false until the first real position read
    readonly property real lengthMs: player ? player.length * 1000 : 0
    readonly property bool playing: player ? player.isPlaying : false

    // Audio-output latency offset (ms). estMs = reported position + offsetMs, so a
    // NEGATIVE value lights words LATER, in time with delayed (e.g. Bluetooth)
    // audio. Calibrated live by ear — the value is owned by shell.qml's lyricOffset
    // IPC handler and shared through a state file this instance watches (below).
    property int offsetMs: -250
    readonly property int offsetMin: -1500
    readonly property int offsetMax: 1500

    // Re-anchor smoothing. A fresh 1s position read rarely matches our extrapolation
    // exactly; instead of snapping estMs (a visible jump every second) we carry the
    // small disagreement as slewErr and bleed it off over a few ticks, keeping estMs
    // continuous. A big disagreement (real seek / stall / first read) snaps instead.
    readonly property int  slewMaxMs: 120
    readonly property real slewGain:  0.18
    property real slewErr: 0

    function reanchor() {
        if (!player) return
        const freshPos = player.position * 1000   // Quickshell computes position on read
        const now = Date.now()
        const predicted = anchorPosMs + (playing ? (now - anchorWall) : 0)
        const err = freshPos - predicted
        anchorPosMs = freshPos
        anchorWall = now
        if (!anchored || Math.abs(err) > slewMaxMs) {
            anchored = true
            slewErr = 0                           // snap: seek / stall / first read
        } else {
            slewErr = predicted - freshPos        // keep estMs continuous; decays to 0
        }
        tick()
    }

    // Force an immediate snap to truth (pause/resume — the position is reliable then).
    function hardAnchor() {
        if (!player) { resetAnchor(); return }
        anchorPosMs = player.position * 1000
        anchorWall = Date.now()
        anchored = true
        slewErr = 0
        tick()
    }

    // On a track change the player's last-known position is still the *previous*
    // track's for a beat, so don't trust it — zero out and let the 1s re-read catch
    // up. Worst case the readout starts at 0:00 and snaps to truth within a second.
    function resetAnchor() {
        anchorPosMs = 0
        anchorWall = Date.now()
        anchored = false
        slewErr = 0
        estMs = 0
    }

    function tick() {
        if (!player) { estMs = 0; return }
        let e = anchorPosMs + offsetMs            // offset applied ONCE, here
        if (playing) e += (Date.now() - anchorWall)
        if (slewErr !== 0) {                       // carry then decay the re-anchor error
            e += slewErr
            slewErr -= slewErr * slewGain
            if (Math.abs(slewErr) < 1) slewErr = 0
        }
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

    onPlayerChanged: { resetAnchor(); clearLyrics(); fetchDebounce.restart() }
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
        function onIsPlayingChanged()  { root.hardAnchor() }
        // Quickshell computes position lazily and only emits positionChanged on a
        // genuine seek/scrub, so this re-syncs a scrub immediately instead of waiting
        // for the next 1s tick. (A spurious emit just re-arms a ~0ms slew — harmless.)
        function onPositionChanged()   { root.reanchor() }
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

    // ---- offset calibration (shared via shell.qml's lyricOffset IPC) ---------
    // shell.qml owns the live offset (one IPC handler, never duplicated) and writes
    // it to this state file; every per-monitor instance just WATCHES the file, so a
    // by-ear nudge re-syncs all screens at once and survives `qs kill; qs -d`.
    property bool offsetReady: false
    FileView {
        id: offsetFile
        path: Quickshell.stateDir + "/lyric-offset"
        blockLoading: true
        preload: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyOffset()
    }
    function applyOffset() {
        const v = parseInt(offsetFile.text().trim(), 10)
        if (!isNaN(v)) root.offsetMs = Math.max(root.offsetMin, Math.min(root.offsetMax, v))
        root.tick()
        if (root.offsetReady) offsetOsd.flash()   // don't flash on the initial load
        root.offsetReady = true
    }

    // ---- audio-reactive feed: silence-aware hold release --------------------
    // PRIMARY instance only (running: isPrimary) so 3 monitors don't spawn 3 cava
    // readers. Its own conf (autosens off) makes the energy ABSOLUTE, so a real
    // instrumental gap reads as silence and the end-of-line breath is released
    // instead of glowing through the gap. Fully fail-open: no feed -> audioReady
    // stays false -> the hold behaves exactly as before.
    property bool audioSilent: false
    property real audioPulse: 0
    property bool audioReady: false
    property real _env: 0
    property real _pulseEnv: 0
    property real _lastAudioWall: 0
    property real _quietSinceWall: 0
    readonly property real silenceEnter: 0.040    // env below this counts as 'quiet'
    readonly property real silenceExit:  0.075    // must exceed this to count 'loud'
    readonly property int  silenceDebounceMs: 180

    function parseAudioFrame(line) {
        const parts = line.split(";")
        let sum = 0, cnt = 0, bass = 0, bn = 0
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "") continue
            let v = parseInt(parts[i]) / 1000
            if (v < 0.05) v = 0                    // same noise floor as the reactor
            if (i > 0) { sum += v; cnt++ }         // skip bin 0 (DC-ish)
            if (i <= 2) { bass += v; bn++ }
        }
        if (cnt === 0) return
        const inst = sum / cnt
        const bassInst = bn ? bass / bn : 0
        _env = inst > _env ? _env + (inst - _env) * 0.6 : _env + (inst - _env) * 0.25
        _pulseEnv = bassInst > _pulseEnv ? _pulseEnv + (bassInst - _pulseEnv) * 0.7
                                         : _pulseEnv + (bassInst - _pulseEnv) * 0.35
        audioPulse = _pulseEnv
        _lastAudioWall = Date.now()
        audioReady = true
        const now = Date.now()
        if (_env < silenceEnter) {
            if (_quietSinceWall === 0) _quietSinceWall = now
            if (now - _quietSinceWall >= silenceDebounceMs) audioSilent = true
        } else if (_env > silenceExit) {
            _quietSinceWall = 0
            audioSilent = false
        }
    }

    Process {
        id: audioCava
        running: root.isPrimary
        command: ["cava", "-p", Qt.resolvedUrl("cava-lyrics.conf").toString().replace("file://", "")]
        stdout: SplitParser { onRead: line => root.parseAudioFrame(line) }
        onRunningChanged: if (root.isPrimary && !running) audioCavaRestart.start()
    }
    Timer { id: audioCavaRestart; interval: 2000; onTriggered: if (root.isPrimary) audioCava.running = true }
    // If frames stop (cava died, not yet restarted), decay to not-ready so the
    // feature fails open rather than holding a stale 'silent'.
    Timer {
        interval: 500; repeat: true; running: root.isPrimary
        onTriggered: {
            if (root._lastAudioWall && Date.now() - root._lastAudioWall > 1500) {
                root.audioReady = false; root.audioPulse = 0; root.audioSilent = false
            }
        }
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

    // ---- token model: main vocal vs background adlib -------------------------
    // One ordered list of tokens {text, bg, mainIdx, t, d} for the active line.
    // The fetcher's per-line words[] is authoritative (adlibs already split out,
    // real onsets when it's a word-level source). If a stale pre-words[] cache file
    // is loaded we paren-split the text ourselves with the SAME rules. Background
    // adlibs (bg) are kept in source order so each anchors to the word it follows,
    // and carry zero main-vocal timing budget.
    function buildTokens(i) {
        if (i < 0 || !lines[i]) return []
        const w = lines[i].words
        if (w !== undefined && w !== null) {        // fetcher authoritative (may be [])
            let out = [], mi = 0
            for (let k = 0; k < w.length; k++) {
                const bg = !!w[k].bg
                out.push({ text: w[k].text, bg: bg, mainIdx: bg ? -1 : mi++,
                           t: (w[k].t || 0), d: (w[k].d || 0) })
            }
            return out
        }
        // FALLBACK for stale cache without words[]: paren-split here, mirroring the
        // fetcher (drop pure punctuation + (x4)-style markers; promote all-adlib lines).
        const txt = lineText(i)
        let all = [], mainCount = 0
        const re = /\(([^)]*)\)|([^\s()]+)/g
        let m
        while ((m = re.exec(txt)) !== null) {
            if (m[1] !== undefined) {
                const inner = m[1].trim()
                if (inner.length && !/^\s*(?:x\s*\d+|\d+\s*x|repeat)/i.test(inner))
                    all.push({ text: inner, bg: true })
            } else if (!/^[^0-9A-Za-z'’]+$/.test(m[2])) {
                all.push({ text: m[2], bg: false }); mainCount++
            }
        }
        if (all.length && mainCount === 0) for (let k = 0; k < all.length; k++) all[k].bg = false
        let out = [], mi = 0
        for (let k = 0; k < all.length; k++)
            out.push({ text: all[k].text, bg: all[k].bg, mainIdx: all[k].bg ? -1 : mi++, t: 0, d: 0 })
        return out
    }

    readonly property var tokens: buildTokens(activeIndex)

    // ---- per-token timing: real onsets, else capped syllable stretch --------
    property int baseWordMs: 60         // fixed per-word cost
    property int perSyllableMs: 220     // added per syllable (lower = faster sweep)
    property int holdCapMs: 1500        // max end-of-line breath before settling
    // The estimate spreads onsets across the line span, but never further than the
    // words could *naturally* fill — so a line followed by an instrumental gap
    // doesn't smear its last words out into the dead air.
    readonly property real stretchSlack: 1.5

    // Real per-word timing for line i? True if any word carries a duration or a
    // distinct onset (LRCLIB line-level gives every word the same line timestamp).
    function lineWordLevel(i) {
        const L = lines[i]
        if (!L || !L.words) return false
        for (let k = 0; k < L.words.length; k++) {
            const w = L.words[k]
            if (w.d > 0 || (w.t !== undefined && w.t !== L.t)) return true
        }
        return false
    }

    function syllables(word) {
        const w = word.toLowerCase().replace(/[^a-z]/g, "")
        if (!w.length) return 1
        const m = w.match(/[aeiouy]+/g)
        let n = m ? m.length : 1
        if (w.length > 2 && w.charAt(w.length - 1) === "e"
            && "aeiouy".indexOf(w.charAt(w.length - 2)) === -1) n -= 1   // silent e
        return Math.max(1, n)
    }

    // [{start, fillEnd, end}] ms per token. Real path: pass each onset (and onset+d,
    // or a short default) straight through. Estimate path: MAIN tokens are spread by
    // syllable weight across a capped span (not packed at the front); each bg adlib
    // hangs briefly off the main word it follows (zero main budget); the last main
    // word absorbs trailing slack as a capped breath. Recomputed on line change only.
    readonly property var tokenSpans: {
        const ai = activeIndex, tk = tokens
        if (ai < 0 || tk.length === 0) return []
        const start = lines[ai].t
        const rawEnd = lineEnd(ai)
        let out = new Array(tk.length)

        if (lineWordLevel(ai)) {
            for (let i = 0; i < tk.length; i++) {
                const t = tk[i].t
                let nxt = rawEnd
                for (let j = i + 1; j < tk.length; j++) { if (tk[j].t > t) { nxt = tk[j].t; break } }
                const fe = tk[i].d > 0 ? t + tk[i].d : Math.min(nxt, t + 600)
                out[i] = { start: t, fillEnd: fe, end: fe }
            }
            return out
        }

        let syl = [], totalSyl = 0, naturalTotal = 0
        for (let i = 0; i < tk.length; i++) {
            const s = tk[i].bg ? 0 : syllables(tk[i].text)
            syl.push(s); totalSyl += s
            if (!tk[i].bg) naturalTotal += baseWordMs + perSyllableMs * s
        }
        totalSyl = Math.max(1, totalSyl)
        const span = Math.max(1, rawEnd - start)
        const effSpan = Math.min(span, Math.max(naturalTotal * stretchSlack, 1))
        let cum = 0, lastMain = -1
        for (let i = 0; i < tk.length; i++) {
            if (tk[i].bg) continue
            const onset = start + effSpan * (cum / totalSyl)
            cum += syl[i]
            const slice = effSpan * (syl[i] / totalSyl)
            const natural = baseWordMs + perSyllableMs * syl[i]
            out[i] = { start: onset, fillEnd: onset + Math.min(slice, natural), end: onset + slice }
            lastMain = i
        }
        for (let i = 0; i < tk.length; i++) {
            if (!tk[i].bg) continue
            let a = start
            for (let j = i - 1; j >= 0; j--) if (!tk[j].bg && out[j]) { a = out[j].fillEnd; break }
            out[i] = { start: a, fillEnd: a + 250, end: Math.min(rawEnd, a + 700) }
        }
        if (lastMain >= 0)
            out[lastMain].end = Math.max(out[lastMain].fillEnd,
                Math.min(rawEnd, out[lastMain].fillEnd + holdCapMs))
        return out
    }

    // Per-token render state at time `est`: fill 0..1 plus active/sustain phase.
    // est is root.estMs, which ALREADY includes offsetMs (applied once in tick()) —
    // do NOT re-add it here. A held word releases early to 'sung' when the mix has
    // gone genuinely silent (fail-open: only with a live audio feed while playing).
    function tokenState(i, est) {
        const sp = tokenSpans
        if (i < 0 || i >= sp.length) return { fill: 0, active: false, sustain: false }
        const s = sp[i].start, fe = sp[i].fillEnd, e = sp[i].end
        if (est >= e) return { fill: 1, active: false, sustain: false }   // already sung
        if (est < s)  return { fill: 0, active: false, sustain: false }   // upcoming
        if (est < fe && fe > s) return { fill: (est - s) / (fe - s), active: true, sustain: false }
        if (audioReady && playing && audioSilent) return { fill: 1, active: false, sustain: false }
        return { fill: 1, active: true, sustain: true }                   // held: breathing
    }

    // ---- scatter layout (Edgerunners kinetic text) -------------------------
    // One line at a time: the active line's words form a tight bunch that jumps
    // around a fixed box in the TOP-RIGHT (clear of the top bar and the mid-left
    // clock), seeded per line so each line gets a fresh arrangement.
    // Mono font → word width = chars * charW (exact layout). Big + bold.
    property real lyricSize: Math.round((ultrawide ? 58 : 40) * pal.uiScale)
    readonly property real charW: lyricSize * 0.58           // Noto Sans Mono advance

    // fixed bunch box, top-right (clear of the top bar and the mid-left clock).
    // On a 32:9 ultrawide (Samsung G9, aspect ~3.56) a 0.45-wide box spans a huge
    // horizontal stretch, so the scatter sprawls back toward the centre. Detect the
    // ultrawide by aspect ratio (vs a 16:9 laptop ~1.78) and use a narrower box so
    // the words cluster hard against the right edge. The scatter wraps to extra rows
    // when a word exceeds boxW, so a narrower box just stacks taller — safe.
    readonly property real aspect: root.height > 0 ? root.width / root.height : 1.78
    readonly property bool ultrawide: aspect > 2.4
    readonly property real boxW: Math.round(root.width * (ultrawide ? 0.24 : 0.45))
    readonly property real boxH: Math.round(root.height * (ultrawide ? 0.42 : 0.27))
    readonly property real boxX: Math.round(root.width * (ultrawide ? 0.95 : 0.965) - boxW)
    readonly property real boxY: Math.round(root.height * 0.07)

    function rng32(seed) {
        let a = seed >>> 0
        return function () {
            a = (a + 0x6D2B79F5) | 0
            let t = Math.imul(a ^ (a >>> 15), 1 | a)
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296
        }
    }

    function collides(rects, x, y, w, h) {
        for (let i = 0; i < rects.length; i++) {
            const o = rects[i]
            if (x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y) return true
        }
        return false
    }

    // [{x,y,size}] within the box — a jumping scatter where every word gets its
    // own size (some big, some small) and NO two words overlap: each word prefers
    // its jumping-path spot, then gets pushed clear of the already-placed words.
    // Seeded per line so each line lands in a fresh arrangement.
    function scatter(seedIdx, words) {
        const n = words.length
        if (n === 0) return []
        const r = rng32((seedIdx + 1) * 2654435761)
        const row = lyricSize * 1.15
        let out = [], placed = [], cx = 0, cy = 0
        for (let i = 0; i < n; i++) {
            const factor = r() < 0.25 ? (1.35 + r() * 0.5) : (0.9 + r() * 0.3)   // some words bigger
            const fpx = lyricSize * factor
            const cw = fpx * 0.58
            const wPx = Math.max(cw, words[i].length * cw)
            const hPx = fpx * 1.1
            const pad = 6
            if (cx + wPx > boxW) { cx = r() * boxW * 0.1; cy += row * (0.9 + r() * 0.4) }
            let px = Math.max(0, cx + (r() - 0.5) * cw * 0.5)
            let py = Math.max(0, cy + (r() - 0.5) * row * 0.3)
            let tries = 0
            while (tries < 80 && collides(placed, px - pad, py - pad, wPx + pad * 2, hPx + pad * 2)) {
                py += row * 0.45
                if (py + hPx > boxH) { py = r() * row * 0.4; px += wPx * 0.5 + cw }  // off the bottom → shift right
                tries++
            }
            out.push({ x: px, y: py, size: fpx })
            placed.push({ x: px, y: py, w: wPx, h: hPx })
            cx = px + wPx + cw * (0.6 + r() * 0.8)
            cy = py
            if (r() < 0.2) { cy += row * (0.6 + r() * 0.5); cx = r() * boxW * 0.2 }  // occasional jump down
        }
        return out
    }

    readonly property var curLayout: scatter(activeIndex, root.tokens.map(function (t) { return t.text }))

    // clear a finished line early: once its last word is done plus a short hold,
    // the line fades out instead of lingering through a long gap to the next line.
    readonly property real lineHoldMs: 300
    readonly property real lineDoneMs: {
        const sp = tokenSpans
        let mx = 0
        for (let i = 0; i < sp.length; i++) if (sp[i].end > mx) mx = sp[i].end
        return mx
    }
    readonly property bool lineExpired: activeIndex >= 0 && estMs > lineDoneMs + lineHoldMs

    // brief blank "cut" on each line change so the old line is fully gone before
    // the new one appears — guarantees only one line shows at a time.
    property bool gate: true
    onActiveIndexChanged: { gate = false; gateCut.restart() }
    Timer { id: gateCut; interval: 90; repeat: false; onTriggered: root.gate = true }

    // ---- lyric display (one line at a time, scattered top-right) ------------
    // The active line builds up word-by-word as a tight bunch in the top-right box,
    // full-strength neon, big & bold. On a line change it clears and the next line
    // appears in a fresh arrangement. Only ever one line on screen.
    Item {
        id: region
        anchors.fill: parent

        Repeater {
            model: root.tokens
            delegate: Item {
                id: wd
                required property int index
                required property var modelData          // {text, bg, mainIdx, t, d}
                readonly property bool bg: modelData.bg
                // touch audioSilent so a held-word release re-evaluates the instant
                // the silence signal flips, even if estMs is momentarily static.
                readonly property var st: (root.audioSilent, root.tokenState(index, root.estMs))
                readonly property bool shown: (st.active || st.fill >= 1) && !root.lineExpired && root.gate
                readonly property var p: root.curLayout[index] ? root.curLayout[index] : ({ x: 0, y: 0, size: root.lyricSize })
                readonly property bool ripple: !wd.bg && modelData.text.indexOf("?") !== -1   // ? words ripple
                property real phase: 0

                // adlibs render smaller, dimmer, italic cyan and sit a touch lower,
                // so the main vocal line still scans cleanly above the backing chatter.
                readonly property real sizePx: wd.bg ? wd.p.size * 0.62 : wd.p.size
                readonly property color baseCol: wd.bg ? root.cyan : root.neon
                readonly property real maxOpacity: wd.bg ? 0.7 : 1
                // subtle bass-driven swell on the active main word (no-op without cava)
                readonly property real pulseBoost:
                    (st.active && !st.sustain && !wd.bg && root.audioReady) ? root.audioPulse * 0.06 : 0

                x: root.boxX + p.x
                y: root.boxY + p.y + (wd.bg ? wd.p.size * 0.22 : 0)
                width: wd.ripple ? rippleRow.width : wt.width
                height: wd.ripple ? rippleRow.height : wt.height
                transformOrigin: Item.Center

                // words appear one-by-one as sung; the whole line fades out once
                // it's done (lineExpired) instead of lingering until the next line
                opacity: shown ? wd.maxOpacity : 0
                scale: shown ? (1 + pulseBoost) : 0.85
                Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }
                Behavior on scale  { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                // ripple driver — only for words containing '?'
                NumberAnimation on phase {
                    running: wd.ripple && wd.shown
                    from: 0; to: 6.2832; duration: 1100; loops: Animation.Infinite
                }

                // plain word (also the size reference for the delegate); adlibs keep
                // their parens so they read as backing vocals
                Text {
                    id: wt
                    visible: !wd.ripple
                    text: wd.bg ? ("(" + wd.modelData.text + ")") : wd.modelData.text.toUpperCase()
                    color: wd.baseCol
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                    font.family: root.mono
                    font.pixelSize: wd.sizePx
                    font.weight: wd.bg ? Font.DemiBold : Font.Black
                    font.italic: wd.bg
                    font.letterSpacing: 1
                }
                // rippling word — per-letter travelling sine wave
                Row {
                    id: rippleRow
                    visible: wd.ripple
                    Repeater {
                        model: wd.ripple ? wd.modelData.text.toUpperCase().split("") : []
                        delegate: Text {
                            required property int index
                            required property string modelData
                            text: modelData
                            y: Math.sin(wd.phase + index * 0.6) * (wd.sizePx * 0.18)
                            color: wd.baseCol
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.6)
                            font.family: root.mono
                            font.pixelSize: wd.sizePx
                            font.weight: Font.Black
                            font.letterSpacing: 1
                        }
                    }
                }
            }
        }

        // small status when a track's playing but there's no active lyric word
        Text {
            x: root.boxX
            y: root.boxY
            visible: root.player !== null && root.tokens.length === 0
            text: !root.lyricsLoaded ? "// SYNC…"
                  : !root.lyricsSynced ? "// NO LYRICS"
                  : "♪"
            color: root.neon
            opacity: 0.85
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.6)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.6)
            font.weight: Font.Black
            font.letterSpacing: 3
        }

        // live offset readout — flashes above the box as you calibrate by ear,
        // then auto-hides. Shown on every monitor since all watch the same offset.
        Text {
            id: offsetOsd
            function flash() { opacity = 1; osdHide.restart() }
            x: root.boxX
            y: root.boxY - root.lyricSize * 0.9
            opacity: 0
            text: "LYRIC OFFSET " + (root.offsetMs > 0 ? "+" : "") + root.offsetMs + " ms"
            color: root.neon
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.6)
            font.family: root.mono
            font.pixelSize: Math.round(root.lyricSize * 0.45)
            font.weight: Font.Black
            font.letterSpacing: 2
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Timer { id: osdHide; interval: 1200; onTriggered: offsetOsd.opacity = 0 }
        }
    }
}
