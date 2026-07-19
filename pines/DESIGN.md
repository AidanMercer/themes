# pines — "STANDING WATCH"

## The fiction

A fire-watch lookout above the treeline, on a rainy night. The desktop is the
ranger's glass cab: the mountain outside (the wallpaper — jagged ridge, rain,
fog banks breathing between black pine tiers), and inside, on the sill, the
station's instruments — barograph, anemometer, plane table, wireless set, one
kerosene lamp. Everything on screen is either the weather, or an instrument
reading the weather. Nothing here is digital: ink on drum paper, damped
needles, pencil bearings, brass and glass. (moon owns HUD; this cab predates
HUD by a century.)

## The laws

1. **Everything condenses.** Nothing fades or slides in. UI *precipitates*
   out of the fog — arrives soft (defocused ghosts, desaturated, a touch
   large) and sharpens into focus — and dissolves back into it on leave.
   The house transition is the double-ghost condense (two offset low-alpha
   copies collapsing into the crisp one) on widgets, and a fog-breath shader
   (`fog.frag`) on app chrome: nav events exhale a breath of condensation
   onto the glass that clears.
2. **Every readout is a field instrument.** Continuous quantities are ink
   traces on rotating drum paper (the barograph). Levels are damped needles —
   they overshoot and settle, never snap. Positions are survey bearings: thin
   lines, degree ticks, benchmark triangles (the house glyph: ▵ with a
   center pip). Labels are letterspaced serif small-caps, values are mono —
   hand-calibrated, slightly analog.
3. **The lamp marks the living thing.** The palette is cold — slate blue,
   fog silver, black pine — and exactly one thing at a time gets the
   kerosene amber: the active workspace, the active word, the playing track,
   the fresh ink at the barograph pen. Danger is ember red (fire is the one
   thing a lookout fears). Everything else stays weather-cold.

## Bespoke systems

- **The barograph drum** (`cava.qml`): a continuous ink-trace renderer. The
  music is a storm front — a ring-buffer trace scrolls right-to-left across
  ruled drum paper, drawn by a pivoting pen arm whose nib is the only amber
  in the frame; fresh ink is warm, aging ink cools to silver; gusts leave
  red tick marks on the top rule. At silence the drum stops (full cava idle
  contract) and the paper dissolves back into fog.
- **The condensation transition**: the universal enter/leave. Ghost-condense
  in QML for bar/clock/notif/lock elements; `fog.frag` (fbm fog + a `burst`
  breath uniform) compiled to .qsb for mica/vellum/beryl/pulse/cobalt/
  frostify backdrops and overlays.
- **The triangulation motif**: plane-table chrome for the overview (compass
  ring with degree ticks, pencil bearing lines to every sighted window,
  benchmark marks, a live bearing readout for the selection) and the lock
  screen passcode (each keystroke plots a station mark on a bearing line;
  a wrong code "loses fix").

## Placement (from the wallpaper's composition)

Clock upper-left (moonlit sky, brightest negative space). Lyrics ride the
mid-right fog bank. Barograph bottom-center over the black pines. Sysinfo
(hover) hangs top-right. Fog particles drift in the lower third, between
pine tiers; rare condensation droplets run down the "glass".

## Palette (sampled from wallpaper.still.png)

sky #5186a6 · fog bank #21536d · mist #132f3b · pine black #031016

- accent      #e2a55c  kerosene amber — the one living light
- accent2     #a9c6d8  moon-silver fog blue
- accent3     #d96b4f  ember red — fire danger
- accent_warn #c9a161  weathered brass
- accent_dim  #2f4c60  graphite slate — rules, ticks, aging ink
- text        #dbe7ee  fog white
- glass       #0b1b27  cab-glass slate

Fonts: Noto Serif Display (Light) for numerals + station small-caps;
Noto Sans Mono for readouts; Symbols Nerd Font for the few icons.

## Voice

Station "PINES-9 LOOKOUT". Sysinfo = INSTRUMENT SHELF (WIND=CPU,
PRESSURE=RAM, GENERATOR=GPU, LAMP OIL=battery, W/T=network, ON WATCH=uptime).
Popup = FIELD DESK. Notif center = WATCH LOG. Overview = PLANE TABLE.
frostify = the wireless set ("▶ RECEIVING"). mica = CHART ROOM. vellum = the
log book. beryl = FAR SIGNALS. pulse = STORM GLASS. cobalt = DISTRICT LINE.
