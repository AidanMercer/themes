# stillwater — the mirror at the end of the day

The wallpaper: a lone small figure standing ON perfectly still water that
reflects an enormous blue-to-rose twilight sky. A thin line of distant
shoreline lights splits the frame exactly in half (y ≈ 0.527). Everything
doubles. Nothing moves.

**Fiction.** The desktop is that infinite reflecting plane. Every widget is a
thing standing on the water at the end of the day — and still water is honest:
whatever stands on it is shown again beneath it, inverted, dimmer, faintly
broken. The far shore is other people's lights; your windows are lights too.

## Laws

1. **THE HORIZON IS LAW.** Every widget is built around a waterline and draws
   its own inverted, dimmed reflection below it. Bar, clock, cava, lyrics,
   lock, popup, notif, overview, sysinfo, app chrome — all reflected. A
   surface with no reflection does not exist in this world.
2. **Above the line, crisp and still. Below, faintly broken.** Reflections are
   dimmer, slightly squashed, and broken into horizontal slivers (the classic
   light-on-water streak). They shimmer ONLY when something earns it — audio,
   a state change, a reveal. The default state of the water is perfect
   stillness (and ~0 CPU).
3. **Appearance = rising out of the seam.** Things surface from their own
   waterline, reflection growing downward in step. **Departure = absorption**:
   the reflection takes the object back down into the line. No fades-in-place,
   no slides from screen edges.
4. **Scale is humble.** Small elements in enormous negative space, like the
   figure. No widget shouts; the biggest thing on screen is always the sky.
5. **Motion is near-stillness.** Long, slow, sine-eased. State changes are a
   single ripple ring or a slow rise/sink. Nothing bounces, snaps or glitches.

## Bespoke systems

- **The mirror shader** (`mirror.frag[.qsb]`) — a reusable reflection pass:
  samples its source flipped, fades with depth (quadratic), and displaces
  horizontally with two sine bands scaled by a `stir` uniform. `stir` is 0 at
  rest (a static image, zero repaints); events animate `time`+`stir` up and
  back down — the water stirs, then stills. The clock and lock are built on it.
- **Broken-sliver reflections** — hand-drawn light streaks (Canvas / stacked
  dashes) with gaps that widen and alpha that dies with depth. This is the
  house rendering rule for every small light's reflection (bar workspaces,
  cava pillars, notif lamps, app-chrome shores).
- **The far shore as workspace indicator** — the bar's workspaces ARE the
  distant shoreline lights: lit warm-white = occupied, haloed = active, dark
  glass = empty, each with its own streak in the water below the bar's
  internal waterline.
- **Light-pillar cava** — music raises thin pillars of light on the horizon
  (right of the figure), each with a longer, broken, wavering streak below
  the line; a peak glint hangs above each pillar and settles back to the
  water. Silence sinks everything into the line and stops the painter.

## Palette (sampled from the still)

- sky top `#09437d`, sky mid `#1f5c9a`, mauve band `#54578b`
- dusk rose (pinkest pixel) `#ad6b98` → accent3 `#c87da8`
- shore dark `#052036`, water deep `#0f4d86`
- lights: pure white with warm halo → accent `#f2e8d4` (distant-light warm white)
- config: accent2 twilight `#7fb2e8`, warn lantern `#d9b48a`, dim slate
  `#46608c`, text `#dfe9f6`, glass `#0c2136`, bg `#0a1c30`, fg `#d9e6f4`

## Type

- Time and display: **Noto Serif Display** (Light) — thin, calm, evening.
- Everything else: `pal.fontMono` small, letterspaced, low-contrast.

## Per-slot

- **clock** — digits standing on the wallpaper's real horizon (left sky,
  x≈7%), bottoms touching the line, mirror-shader reflection below. Minute
  turn = one ripple ring on the line + the reflection stirs ~5s, then stills.
- **bar** (bottom) — a strip of near water with its own internal waterline:
  far-shore workspaces center; ferry-light now-playing left (a light crossing
  a hairline); lighthouse net / lantern battery / mirrored clock / sounding
  trigger (sysinfo hover flag) / ring popup button right. Everything stands on
  the line; everything is doubled beneath it.
- **cava** — light pillars, described above. Full idle contract.
- **lyrics** — words surface on the mirror at the horizon: unsung words sit
  half-sunken and water-dimmed; the karaoke sweep lifts each word crisp above
  the line and gives it a reflection; sustains ripple the reflection; a done
  line is absorbed back into the water.
- **particles** — the water's own life: sparse 2px glints drifting below the
  horizon, and a rare single ripple ring blooming flat on the surface.
- **sysinfo** — hover/pin reveal, "SOUNDINGS": a small card that surfaces from
  the bar's waterline with a buoyant settle; strand-of-lights meters
  (current / depth / glow / reserve / far shore), each strand mirrored dimly.
- **lock** — `bareLock`. The world holds still, video sharp; the sky dims a
  little, the water keeps its light. The time stands on the real horizon with
  its shader reflection; the passcode is a row of shoreline lamps on the line
  — each keystroke lights one; wrong code flushes them rose and shivers the
  water; unlock = the reflection absorbs everything down into the line.
- **popup / notif / overview** — every card carries a waterline near its foot,
  lamps standing on it, broken streaks below. Overview = "lights on the far
  shore": each window tile gets a reflection slab beneath it; the hot tile's
  lamp lights.
- **app chrome** — one shared idiom, one signature each: mica "the far shore"
  (nav = a light crosses the water), vellum reading-gate shore + composing
  ripple, beryl a waterline seam under the tabs, pulse "soundings" (the
  waterline's calm is inversely the CPU — a hot machine disturbs the water;
  kill = a red light drops in), cobalt a restrained dim shore, frostify the
  night-swim radio (track change = a light crosses; voice: "carried across
  the water" / "held still" / "the water sleeps").

## What stillwater must NOT be

Not shiro's white restraint (this is deep twilight color), not stars'
constellation/vending seaside (no star-map, no catenary, no grid cava), not
sailing's ship furniture. The signature here is symmetry: everything is
doubled, and the double is the animation surface.
