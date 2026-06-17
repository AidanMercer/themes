# Desktop lyric visualizer — notes

A Spotify lyric visualizer woven into the Hyprland desktop, currently built for
the **moon** theme. Loaded by the quickshell `themelyrics` module while the moon
wallpaper is showing (same per-theme mechanism as `clock.qml` / `cava.qml`); to
give another theme lyrics, drop a `lyrics.qml` in its folder.

## How it works (3 parts)

1. **Clock** — `lyrics.qml` reads spotifyd's position over MPRIS (`Quickshell.Services.Mpris`),
   re-anchors once a second, and interpolates at 30fps → a smooth `estMs`.
2. **Fetch** — on each track change it runs the shared
   `~/.config/quickshell/scripts/lyricvis-fetch.py` over a `Process`. That pulls
   line-level synced lyrics from **LRCLIB** (`/api/get`, then `/api/search`),
   normalizes to `{lines:[{t,text}]}`, and caches per-track in `~/.cache/lyricvis/`.
3. **Renderer** — `lyrics.qml` picks the active line, then paces words within it.

## Word timing (the engine)

- Each word gets a **natural duration** from its syllable count
  (`baseWordMs + perSyllableMs * syllables`), packed from the line's start.
- If the line is sung faster than that estimate → compress to fit. If there's
  slack (slow songs) → the **last word absorbs it as a sustain**.
- Two phases per word: **fill** (clip-reveal colour sweep) then **sustain**
  (breathing glow). active = neon + Glow, sung = white, upcoming = grey.

### Tuning knobs (top of lyrics.qml)
- `perSyllableMs` (220) — sweep pace. Lower = faster. **Main dial** if highlight
  lags (lower) or runs ahead (raise) the vocal.
- `baseWordMs` (60) — fixed per-word cost.
- `holdCapMs` (1500) — max end-of-line breath before settling (see below).
- `offsetMs` (0) — global sync nudge for output buffering. Not yet hotkeyed.

## Known limitations (line-level data ceiling)

- **End-word false holds.** The last word breathes during the gap to the next
  line — but a long gap is *usually just an instrumental beat*, not a held vocal,
  and line-level timing **cannot distinguish a held note from an instrumental
  gap**. `holdCapMs` keeps it short as a conservative default. Real fix = audio.
- **Mid-line held words** can't be placed exactly (a held 1-syllable word mid-line
  gets a short slice). Needs audio or true word-level data.

## Deferred / TODO (rough priority)

1. **Look rework** — styling is going to change; the engine is stable, the
   presentation isn't final.
2. **Line transitions** — fade/slide as the active line advances (currently snaps).
3. **Tuning hotkeys** — wire `offsetMs` + `perSyllableMs` to Super keybinds via
   `qs ipc` so sync/pace can be nudged live by ear.
4. **Word-level (AMLL)** — add the AMLL community word-level TTML DB as a source
   above LRCLIB; real per-word timing for covered songs (no faking, fixes holds
   for those songs).
5. **Cheap audio pass** — the moon theme already runs **cava** (`cava.qml`,
   `cava.conf`: 40 bars, raw ascii `;`-sep, 60fps, read via `Process`+`SplitParser`).
   Reuse that feed for: audio-reactive glow/pulse on the active word, and
   **silence-aware hold release** (release the end-hold when energy drops toward
   silence — reliable even in a full mix). A center-channel (mid−side) band is a
   crude vocal proxy. Tools present: `pw-cat`/`pw-record`/`parec`/`ffmpeg`
   (numpy NOT installed — would need it, or band-derive from cava).
6. **Heavy v2 (true accuracy)** — offline per-track: Demucs vocal isolation +
   WhisperX forced alignment → real word/syllable onsets, which would fix both
   limitations above. Big pre-processing pipeline; run once per track, cache.
