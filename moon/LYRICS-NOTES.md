# Desktop lyric visualizer — notes

A Spotify lyric visualizer woven into the Hyprland desktop. The **engine**
(everything theme-independent) lives in the shell at
`~/.config/quickshell/modules/themelyrics/LyricsEngine.qml`; the loader injects
it into the active theme's `lyrics.qml` as `engine` (declare
`property var engine`, same grep handshake as `pal`). This theme's `lyrics.qml`
is **styling only** — the Edgerunners scatter/render. To give another theme
lyrics, drop a `lyrics.qml` in its folder that binds to the same engine surface.

## How it works (3 parts)

1. **Clock** — the engine reads spotifyd's position over MPRIS, re-anchors once
   a second and interpolates at 30fps → a smooth `estMs`. The re-anchor *slews*
   (eases small disagreements off over a few ticks) instead of snapping, so there's
   no 1s jump; a real seek/stall hard-snaps, and a scrub re-syncs immediately off
   `onPositionChanged`. `estMs = position + offsetMs` — the offset is applied here,
   once (see calibration below).
2. **Fetch** — on each track change it runs `~/.config/quickshell/scripts/lyricvis-fetch.py`.
   Source ladder: **AMLL** word-level TTML (`amll-ttml-db`, keyed by spotify id —
   real per-word onsets, thin coverage) → **LRCLIB** enhanced-LRC inline word tags
   (rare) → **LRCLIB** line-level. Normalized to `{lines:[{t,text,words:[…]}]}` and
   cached per-track in `~/.cache/lyricvis/`.
3. **Renderer** — the engine picks the active line, builds an ordered **token**
   list and paces the words (`tokens`, `tokenSpans`, `tokenState(i, estMs)`);
   the theme's `lyrics.qml` decides how they look.

## Word timing (the engine)

Each line is an ordered list of tokens `{text, bg, mainIdx, t, d}`:

- **Real timing** (AMLL / enhanced-LRC): every token has a real onset (`t`, and
  `t+d` when a duration is present) — used verbatim, no guessing.
- **Estimate** (LRCLIB line-level): main tokens are spread across the line by
  syllable weight, but only across a *capped* span (`naturalTotal * stretchSlack`)
  so the last words never smear out into a trailing instrumental gap. The last main
  word breathes as a capped sustain (`holdCapMs`).
- **Adlibs** — anything in `(parens)` is a background token (`bg:true`). It's pulled
  out of the **main** syllable budget so it can't push the real words off-beat, but
  kept *in source order* so it anchors to the word it follows. Wholly-parenthetical
  lines (e.g. `(You got it, mag)`) promote back to main so they still get a span.
  Adlibs render smaller / dimmer / italic cyan, still wrapped in their parens.
  Detection is done once in the fetcher; the renderer has the same paren-split as a
  fallback for old cached files that predate `words[]`.

### Tuning knobs (LyricsEngine.qml)
- `perSyllableMs` (220) — estimate sweep pace. Lower = faster.
- `baseWordMs` (60) — fixed per-word cost.
- `stretchSlack` (1.5) — how far past natural length onsets may stretch before the
  cap kicks in (stops smearing into instrumental gaps).
- `holdCapMs` (1500) — max end-of-line breath before settling.
- `offsetMs` — audio-latency offset; see calibration.

A theme may tweak the first three on its injected `engine` (e.g.
`Component.onCompleted: engine.perSyllableMs = 180`); the loader resets them to
defaults on every widget mount so a tweak can't leak into the next theme.

## Sync calibration (live, by ear)

Audible audio trails spotifyd's reported position (output + Bluetooth buffering),
so `offsetMs` shifts the lyric clock. **Negative = lyrics later.** Default `-250`.

- `$mod + ]` — lyrics **later**, `$mod + [` — lyrics **earlier** (20ms steps).
- `$mod + Shift + \` — reset to -250.

The value is owned by **one** IPC handler in `shell.qml` (`lyricOffset`, never
duplicated across monitors), written to `Quickshell.stateDir/lyric-offset`; every
per-monitor engine *watches* that file, so a nudge re-syncs all screens at once
and survives `qs kill; qs -d`. The engine fires `offsetNudged()` on each live
nudge; this theme hooks it to flash an OSD with the current value.

## Audio-reactive (silence-aware hold release)

A dedicated cava reader (`modules/themelyrics/cava-lyrics.conf`, autosens **off**
so energy is absolute) runs on the **primary screen only** (the engine's
`isPrimary`, wired by `ThemeLyrics`, so the theme on 3 monitors doesn't spawn 3
readers). When the mix drops to genuine silence it releases a held end-of-line
word to "sung" instead of glowing through an instrumental gap. Fully
**fail-open**: no cava feed → behaves exactly as the estimate alone. Also drives
a subtle bass swell on the active word. Thresholds `silenceEnter`/`silenceExit`
in `LyricsEngine.qml` may want tuning by ear (the default sink here is
Bluetooth, which scales differently from analog).

## Staging signals (the music-video layer)

Everything below is theme-independent and computed in the engine; themes stage
against it. All of it is **fail-open** — gate every effect on its ready flag
and the widget must degrade to the plain karaoke treatment.

- **Chorus detection** — `chorusMask` (bool per line), `isChorus(i)`,
  `inChorus`. Purely lexical: a normalized line that repeats elsewhere AND sits
  in a run of repeats (or is a 4+-times hook) is chorus. Songs where nearly
  everything repeats get an all-false mask (no contrast worth staging).
  Reference `chorusMask` itself in bindings so they re-evaluate when lyrics land.
- **Gap awareness** — `nextLineStartMs` / `nextLineInMs` (-1 with nothing
  ahead) count down to the next vocal, including before the first line;
  `inInterlude` flags a real instrumental break (line done + >4.5s dead air,
  intro/outro included). Themes recede in interludes and run a countdown when
  `nextLineInMs` drops under ~3s.
- **Energy** — `audioEnergy` (live full-band envelope, absolute),
  `audioEnergyAvg` (~4s rolling mean of raw frames), `audioLift` (their ratio:
  >1.2 ≈ hot section/drop, <0.7 ≈ breakdown). Primary screen only, like
  `audioPulse` — gate on `audioReady`.
- **Beat clock** — bass onsets from the same cava feed, inter-onset gaps folded
  into one tempo octave (80–160 BPM) and medianed: `bpm`, `beatPhase` (saws
  0..1 per beat, updated on the 30fps tick), `beatConfident`, and a `beat()`
  signal on each wrap. No drums / inconsistent gaps / no cava → `beatConfident`
  stays false. Resets on track change (~3–4s to reacquire).
- **Album-art palette** — `scripts/lyricvis-art.py` (ffmpeg decode, no Pillow)
  reduces the cover to three swatches cached in `~/.cache/lyricvis/art-*.json`:
  `trackPrimary` (dominant), `trackVivid` (most saturated, lum-normalized),
  `trackDeep` (darkest). `trackPaletteReady` gates them;
  `trackTint(base, amt)` blends a theme color toward `trackVivid` and is the
  identity until a palette loads, so it's always safe to call inline.

## Known limitations

- **AMLL coverage is thin** (CJK-skewed) — most Western tracks miss and fall through
  to LRCLIB line-level. Word-level is an opportunistic bonus, not the main path.
- **Estimate is still a guess.** Line-level data has no real per-word onset; the
  capped syllable spread is a good default but can't be exact.
- **Silence release is mix-level**, not vocal-isolated — it catches whole-track
  instrumental gaps, not a vocal stopping while instruments continue.

## Deferred / TODO

1. **Look rework** — presentation isn't final; the engine is stable.
2. **Line transitions** — fade/slide as the active line advances (currently snaps).
3. **Per-machine silence tuning** — auto-calibrate `silenceEnter`/`silenceExit`, or
   a vocal-band cava variant (crude, but a better silence proxy than the full mix).
4. **Heavy v2 (true accuracy)** — offline Demucs vocal isolation + WhisperX forced
   alignment → real word/syllable onsets for every track. Big pipeline, run once
   per track, cache.
