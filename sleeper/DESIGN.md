# sleeper — THE OVERNIGHT BERTH

## Fiction

The desktop is the inside of a night sleeper-train compartment. Not the
railway — lonely-train owns the signage, the platforms, the cassette deck.
This is the private world INSIDE: your berth, your table, your tea in its
podstakannik, the rainy green city sliding past the window under a crescent
moon. Every widget is something the traveler keeps in the compartment:

- the clock is the brass plaque over the berth
- the bar is the table edge along the bottom of the compartment
- the workspaces are a paper ticket, and switching punches it
- the visualizer is the tea glass — music ripples the tea
- lyrics are lines caught in the window, lit word by word by passing lamps
- sysinfo is the berth card the attendant tucks in the door slot
- notifications are notes slid under the compartment door
- locking is a ticket check: the lamp goes out and your ticket gets punched

Voice: quiet, second-class-sleeper romantic. "NIGHT SERVICE", "CAR 7",
"DISTANCE", "SLEEP WELL". A little Cyrillic where the podstakannik earns it.

## Laws

1. **The bogie rhythm (bespoke system #1 — the shared sway clock).**
   The carriage rocks as ONE body. Every widget derives its sway phase from
   wall-clock time — `phase = (Date.now() % 4200ms) / 4200 · 2π` — so
   separate widget files are phase-locked with no shared object: the master
   rhythm IS time. Sway = gentle roll (`sin(phase)` → ±0.5°) plus a smaller
   double-frequency heave (`sin(2·phase+0.7)` → ~1px), rocking, never
   bouncing. It runs ONLY while music plays (or while a panel is revealed /
   surface interacted with), amplitude eases in/out over ~1.2s so the
   carriage settles instead of snapping. Idle desktop = perfectly still,
   timers parked.

2. **Light arrives as passing glows.** State changes are announced by a warm
   band of city light sweeping across the surface — lamps passing the
   window. Nothing pops or fades in place: light crosses it. (Track change,
   page turn, minute turn, popup open, overview reveal.)

3. **Paper tucks and slides.** Tickets, berth cards and notes slide in from
   an edge and tuck into place (with one damped sway-settle on the bogie
   rhythm). Perforations, punch-holes and stamps are the paper grammar:
   progress is shown by punching, danger is a red conductor's stamp.

## Bespoke systems

- **The bogie clock** (law 1) — wall-time phase-locked sway in bar, cava,
  clock, lyrics, sysinfo; one carriage, one rhythm.
- **The punched ticket** — the workspace indicator is a paper ticket strip
  with 10 perforated stubs; the active workspace is a punched hole (with a
  falling chad on punch). The same punch language runs the lock's passcode,
  sysinfo's meters, and the lyrics' "stop dots".
- **The tea glass cava** — a podstakannik on the table: the spectrum is the
  tea's surface (a low waveform across the rim), beats ring ripples out,
  steam rises with the music, and bass rattles the spoon against the holder.
  Silence = still tea, dead steam, parked process.
- **Passing-lamp lyrics** — the active line hangs in the window as unlit
  murky-green ghost letters; a warm lamp-glow sweeps across as the words are
  sung (karaoke fill = the lamp crossing the word), sung words hold a low
  amber afterglow that cools; a held note is the lamp lingering. No rain, no
  condensation devices (downpour / lonely-train own those).

## Palette (sampled from wallpaper.still.png)

- moon crescent `#b5c08f` → moon pale `#d9d5a3` (accent2)
- lit buildings `#2b3327` → murky city green `#a9c491` (accent — the window)
- lamp reflection `#382d1e` / tea `#5a2b1e` → tea amber `#d29a5b` (warn),
  stamp red `#c25b49` (danger)
- table wood `#2b2521`, walls `#111` → glass `#141712`, dim `#4a4f42`
- linen text `#e8e2d2`

Fonts: `Noto Sans Mono` (tickets, readouts) + `Noto Serif Display` (the
brass plaque, headers) — both verified in fc-list. Bar: bottom (the table).

## Slot map

clock (plaque, right wood wall) · bar (table edge, bottom) · cava (tea glass,
lower table) · lyrics (window, lower half) · particles (dust motes in window
light) · sysinfo (berth card, hover-reveal from bar trigger) · lock (bareLock
ticket check) · popup (night-service tray) · notif (notes under the door) ·
overview (the corridor) · frostify/mica/vellum/beryl/pulse/cobalt (berth
radio / luggage rack / night journal / observation car / samovar / sleeper).
