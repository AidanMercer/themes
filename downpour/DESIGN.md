# downpour — the rain-side of the glass

Wallpaper: blue-hour anime interior — Reze in profile at a rain-drenched
window at night, storm clouds outside, everything washed in deep blues, her
skin catching cold light. The droplets are already beading on the pane in the
frame itself: the theme grows out of them.

## Fiction

**The last quiet hour before a storm confession.** The desktop is not the
room and not the storm — it is the windowpane between them. Every widget
lives ON the glass: a patch where someone breathed, a word written with a
fingertip, a bead of rain waiting to fall. Nothing announces itself. Things
condense, are written, and are slowly taken back by the mist. She hasn't
said it yet. The rain is doing the talking.

## Laws

1. **Every surface is breathed-on glass.** Panels are condensation patches —
   soft-edged, irregular, faintly paler than the night behind them, with a
   few beads riding their rims. Where the platform allows real sampling
   (bareLock's `backgroundItem`, app-chrome windows) the patch genuinely
   blurs what's behind it; on desktop layers it is a breath-haze (layered
   radial pale washes on dark glass). No opaque plastic, no hard chrome.
2. **Text is finger-writing on fog.** Words arrive by wipe-in — a clear
   leading edge moving left→right, the letters surfacing behind it — and
   they leave by re-misting: a slow fade as the glass fogs back over.
   Nothing pops, nothing slides in from off-screen.
3. **Droplets are the event language.** A state change is a bead that grows,
   trembles, breaks, and RUNS — a short vertical fall leaving a fading
   trail. Notification arrival, track change, minute turn, wrong passcode,
   directory change: each spends exactly one droplet. Runs are discrete,
   vertical, gravity-sudden. (Deliberately different in kind from
   lonely-train's continuous diagonal rain-streak shader: downpour's water
   *sits* and *breaks*; it never falls as lines.)
4. **Hushed, always.** Low contrast, slow curves (400–1500ms, InOut), one
   warm color in a cold world. The only fast motion permitted is the moment
   gravity wins — a droplet's break (~500ms, OutQuad). No blinking, no
   bouncing, no glitching.

## Bespoke systems

- **The breath-fog pane** — a house Canvas component (redrawn per widget):
  an irregularly-rounded condensation blob — per-corner radii wobbled by a
  deterministic hash, an inner breath-haze radial, a brighter meniscus line
  pooling along its bottom edge, and 3–6 rim beads seeded from the same
  hash. Every chrome surface in the theme (clock haze, sysinfo wipe-patch,
  lock pane, popup, notif cards, overview tiles) is this one surface.
  Exit is always re-misting.
- **The droplet run** — a house one-shot: bead swells at a fixed point,
  quivers once, breaks, falls 40–120px with a thinning trail, gone. Used
  sparingly as THE flourish across bar, notif, mica/beryl/frostify/pulse.
- **The rain gauge (cava)** — the visualizer is a window rail (hairline
  sill) with 28 beads *hanging beneath it*: each bead's size and stretch is
  its band's level; a loud band's bead elongates past its surface tension
  and lets a drop fall. Silence = the rail dries to nothing and every
  painter stops. No bars anywhere.
- **Finger-written lyrics** — each word is wiped onto the glass by the
  karaoke sweep (clip-reveal with a pale fingertip smear leading it); a
  held note gathers a droplet under the word that stretches until release;
  a finished line re-mists. Adlibs are smaller, colder, parenthesized.

## Palette (sampled from wallpaper.still.png)

- glass highlight `#77a2cb` (lit pane streak) → accent `#7fb0d6` (pal.neon)
- her cold-lit skin `#538fb6` → accent2 `#5b93b8` (pal.cyan)
- the one warmth — the unsaid thing: muted rose `#c98f7e` → accent3
  (pal.magenta; failure/urgency = the confession almost surfacing)
- warm candle dim `#c2a178` → accent_warn
- window-frame slate `#213a63` → accent_dim `#2e4a6e`
- night behind the pane `#081222` → bg; hair `#000619` grounds the darks
- pale glass light → text `#d4e3f0`; glass tint `#0a1424`

Faces: Noto Serif (Light + Italic — the finger-writing hand),
Noto Sans Mono (data), Symbols Nerd Font (status glyphs only).

## Slot map

- **clock** — upper-left on the pane: "the hour, written on fog". Breath
  haze blooms, time wipes in in light serif; on the minute the old minute
  re-mists and the new one is written; one droplet spent per hour turn.
- **bar (top)** — the upper sash. Workspaces are breath marks (fog dots);
  the active one is a wiped-clear ring; switching spends a droplet from the
  mark's rim. Now-playing written small-italic on the left; net/battery/
  time/sysinfo-breath/popup-press on the right. The bar's bottom edge is a
  meniscus — an irregular condensation waterline, not a rule.
- **sysinfo** — hover the bar's breath mark (or Super+.): a hand-wiped
  clear patch reveals the readouts; meters are water levels (bead rows).
  Settle = the wipe's arc (rotation damping). Flag-file plumbing verbatim.
- **cava** — the rain gauge (above). **lyrics** — finger-writing (above).
- **particles** — condensation life on the whole pane: ~12 beads that
  condense, dwell, occasionally break and run. Sparse, dim, gated.
- **lock** — bareLock. The storm gets the whole pane, video sharp; a
  breath-fog pane blooms center with real blurred slices; passcode is a
  row of condensing beads on a hairline; wrong code — every bead breaks
  and runs at once, warmed rose; unlock — the fog wipes away.
- **popup / notif / overview / frostify / mica / vellum / beryl / pulse /
  cobalt** — the same pane grammar per slot contract; pulse maps
  host.load → how hard it is raining on the monitor's glass; kill = one
  heavy drop bursts. Voices are lowercase, hushed: "still raining",
  "held breath", "while you were away", "no one at the window".
