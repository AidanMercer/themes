# nightshift — "STILL UP"

## The fiction

The small hours over a hillside city, seen from a stair landing. Almost
everyone down there is asleep. The theme's world is the set of people who
aren't — and you can see exactly who they are, because their windows are lit.

The desktop is a census of the awake. Machine state isn't drawn as bars or
arcs; it's drawn as *which windows are burning*. CPU load is how many rooms
in a block have someone in them. The clock is a building whose lit windows
spell the hour. The visualizer is the skyline itself, lighting up floor by
floor. (moon owns HUD, road8 owns the pixel grid — this grid isn't pixels,
it's rooms, and the difference is that rooms belong to somebody.)

## The laws

1. **Everything is a lit window.** The atom of this theme is a small
   rectangle on a dark facade: lit, or not. Quantities are how many windows
   in a block are burning, and a block fills **bottom-up** — the lower floors
   go first, because that's the order a building wakes up in. Nothing draws a
   curve where it could light a row of rooms instead.

2. **Nothing switches instantly, and nothing switches together.** A window
   doesn't fade — somebody gets up and hits a switch. Every state change
   propagates room by room on a jittered 250–450ms scatter (the *ripple*),
   each window snapping on hard with a brief overshoot bloom, then settling.
   Lit windows carry a slow sodium flutter, per-window out of phase, so the
   city is never quite still and never in step with itself. This is the
   motion language everywhere: bar, clock, visualizer, lock. Nothing tweens.

3. **One warm room.** The palette is cold — haze blue, unlit slate, navy
   glass — and the sodium window glow marks the one thing that's live: the
   active workspace, the current lyric word, the playing track, the block
   under the cursor. Everything else stays dark or blue. Alert is the tower
   beacon, the single red light in the city, and it **blinks** rather than
   glows — a red that holds steady would be a different world.

## Bespoke systems

- **The window-grid renderer** (`windows.js` + the `Facade` component) — the
  theme's font, chart and meter, all one thing. `Facade` paints a block of
  rooms on a dark elevation and takes a *lighting plan*: `planLevel(v)` lights
  floors bottom-up for a 0..1 value, `planGlyph(ch)` looks the character up in
  a 5×7 room-map so digits and letters are spelled in lit windows, and
  `planBars(series)` turns a series into a skyline. One renderer, three
  grammars — which is why the clock, the load gauge and the visualizer all
  read as the same city.

- **The ripple scheduler** (`windows.js`) — the shared physics. Hand it the
  set of rooms that *should* be lit; it diffs against what *is* lit, assigns
  each changed room a jittered delay, and drives per-room bloom + decay
  envelopes plus a persistent flicker phase seeded per room. Every widget in
  the theme feeds the same scheduler, which is what makes sixteen separate
  files feel like one city changing its mind.

- **The census skyline** (`cava.qml`) — the visualizer is the city's own
  lower rooftops, spanning the full width of the display. Each frequency
  bucket is a building whose height quantizes to whole floors and whose rooms
  light with that band's energy; bass lights ground floors across the whole
  city at once, treble puts single rooms on at the top. At silence the city
  goes dark from the top down, floor by floor, and the cava process parks.

- **The cable run** (`lyrics.qml`) — the lyric line is strung across the
  hillside as a run of overhead cable. Every word is plotted as a window out in
  the district: its height quantized to whole storeys (the wire steps, it never
  slides) and its size quantized to three distances, so a line reads as near
  windows and far ones. Between each window and the next hangs a quadratic sag
  cut into segments, and the karaoke fill is metered in those segments — a bead
  of current crawls the span and the room SNAPS on when it arrives, sodium
  while it's the word being sung, cooling to haze once it's past. When the line
  is over the run goes dark from the top down, storey by storey, on the ripple.

- **The haze slice** (`haze.frag`) — a scrolling fbm haze with a `warm`
  uniform, compiled to .qsb, used behind app chrome. Nav events push a wave of
  sodium warmth through the haze that cools back to blue, so the six apps
  share the desktop's one-warm-room law.

## Placement (from the wallpaper's composition, 5120×1440)

The figure stands dead center (roughly x 2200–2900) — that column stays
clear. Clock upper-left over the dark building wall. Sysinfo (hover) hangs
upper-right by the bare branches. The cava skyline runs along the bottom
edge, full width, sitting where the real rooftops are. Lyrics ride the
right-of-center haze band, clear of the figure. Particles: cold haze drifting
left, with rare warm motes rising off the vents below.

## Palette (sampled from the video)

void #030917 · deep blue #0a1d42 · haze #194180 · sky band #2467e7 ·
window sodium #b5c997 (the only non-blue light in the entire frame)

- accent      #c8dc9e  sodium window light — the one room that's awake
- accent2     #6fa2f2  city haze blue — rules, traces, the cold majority
- accent3     #e0574a  tower beacon — blinks, never glows
- accent_warn #e0a860  street lamp amber
- accent_dim  #2c4a7d  unlit slate — dark windows, facades, hairlines
- text        #cfdcef  pale blue-white
- glass       #071426  deep navy glass

Fonts: Noto Sans Medium (letterspaced, for labels), Noto Sans Mono (values),
Symbols Nerd Font (the few icons). Display type is drawn as windows, not set.

## Voice

Labels stay plain — `cpu`, `mem`, `gpu`, `net`, `up`, `batt` — the city does
the world-building, not the nameplates. Wordmarks carry the dialect:
frostify "▶ still up", mica "◧ floors", vellum "▤ nightdesk", beryl
"◇ far windows", pulse "▦ the grid", cobalt "◉ on call".
