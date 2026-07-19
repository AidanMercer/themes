# homeroom — morning homeroom before anyone else arrives

The wallpaper: Arona asleep on her feet in front of the homeroom chalkboard,
photos taped over chalk doodles, pale sky pouring through the missing wall,
a bank of periwinkle lockers with pink stripe labels catching the first sun.
Nobody else is here yet. The desktop is that room: the board, the lockers,
the notice board, the light. You're the first one in; the widgets are the
things a classroom does when it thinks nobody's watching.

## Fiction

Morning homeroom, before the bell. Everything on screen is something IN the
room: chalk on slate, paper taped to a board, a locker door, a shaft of sun.
The room is cheerful but quiet — motion is morning-calm: settles, clicks,
strokes. Nothing bounces, nothing glows neon. Except one thing.

## Laws

1. **Things arrive by being PINNED or CHALK-DRAWN.**
   - Pinned: paper (notes, now-playing, panels) drops a few px, sticks, and
     settles slightly crooked (±1–3°) — tape tabs visible. Nothing paper is
     ever perfectly straight.
   - Chalk-drawn: strokes reveal tip-first with hand jitter, finished with a
     tiny puff of dust. Chalk never fades in — it is WRITTEN.
2. **Things leave by being ERASED or UNPINNED.** Chalk goes under an eraser
   smudge (a pale wipe, then gone); paper lifts a corner and drops away.
3. **Hardware moves in two stages.** Locker doors (workspaces) go
   latch-click → swing. A click is a 60ms jolt; the swing is a 200ms ease.
   Metal never glides silently.
4. **The halo is the one supernatural thing.** A clean glowing cyan ring,
   reserved for the most alive thing on screen: the clock's minute flourish,
   the active workspace's open locker, the lock screen, the focused tile in
   the exposé. Never used as decoration; if two things have halos, one is
   wrong.
5. **Morning-calm.** Idle desktop = still room. Loops gate on
   occluded/playing/open/awake; a silent untouched desktop costs ~0.

## Bespoke systems

1. **The chalk renderer (`chalk.js`)** — a vector stroke font (digits 0-9,
   colon) plus a stroke engine: polylines subdivided with seeded hand
   jitter, multi-pass grain (bright pass + offset ghost pass + dust
   speckles), partial-length reveal so glyphs are written stroke by stroke.
   Used by the clock (digits erase-and-rewrite on the minute), the lock
   screen time, and echoed by chalk rules/tallies in sysinfo, popup, lyrics.
2. **The locker-grid workspace strip (bar.qml)** — ten tiny locker doors:
   closed slate (empty), ajar with a warm light seam (occupied), swung open
   with sunlight inside and a small halo ring above (active). Switching
   plays latch-click → swing.
3. **The notice-board collage (notif.qml)** — notifications are taped notes
   (tape tab, pin dot in urgency color, chalk frame); the notification
   center is the whole board: bunting across the top, chalk doodles, quiet
   hours written in chalk when DND.
4. **The chalk waveform (cava.qml)** — someone is sketching the song: one
   continuous hand-jittered chalk line across the locker band whose shape is
   the spectrum, a slower "smudge ghost" line decaying behind it, a chalk
   stick riding the leading tip. Silence = the sketch is erased and the
   whole pipeline parks.

## Palette (sampled from the still)

- sky / morning blue `#b8dbfc` (sky-top), deep sky `#9bcdfd`
- locker periwinkle `#86b0ea`, shadowed locker `#8aaee1`
- chalkboard slate `#4d68a2` lit / `#2c3c63` deep — glass/panel base
- locker stripe pink `#d873b4` (lifted from the blue-washed `#9d68b9`)
- halo cyan `#8fd0f4` (ring `#569ccb` + glow `#a5b1f1`)
- sunlight warm white `#f2d79b` / chalk white `#f4f7fd`

config.toml: accent=halo cyan, accent2=periwinkle, accent3=stripe pink,
accent_warn=sunlight gold, accent_dim=slate, glass=deep slate. Terminal =
the chalkboard: bg `#18223a`, fg chalk `#e8eefb`.

## Slot map

- **clock** — upper-left sky. Time written in chalk (chalk.js), erased and
  rewritten digit-by-digit on the minute; halo ring flourish draws itself
  above the time when the minute lands, then fades. Date + "morning
  homeroom" letterspaced beneath a jittered chalk rule.
- **bar (top)** — the corridor rail: pale slate glass, sunlit top edge,
  chalk tray line along the bottom with a chalk stub + eraser parked right.
  Center: locker-grid workspaces. Left: now-playing as a taped note with a
  chalk progress line. Right: pin-board cluster — notice-board pin (sysinfo
  hover trigger), net flag, chalk battery, small time, school bell (control
  popup).
- **sysinfo** — hover/pin reveal: "the duty board", a small slate hanging
  from two tape tabs, settling on its pins (rotation sway). Subjects as
  gauges: MATH=CPU, MEMORY=RAM, ART=GPU, ENERGY=battery, ATTENDANCE=net —
  meters are chalk tally marks, five-bar gates, quantized.
- **cava** — the chalk waveform (system 4).
- **lyrics** — chalk karaoke: the line is hand-scattered (per-word seeded
  tilt/baseline), words fill left-to-right like being written, a jittered
  chalk underline grows under the active word, held notes shed dust, the
  finished line is wiped by an eraser smudge. Adlibs are small pink chalk
  margin notes.
- **particles** — sunlit dust motes drifting down the light shafts; the
  occasional chalk-dust fall below the board line.
- **lock (bareLock)** — the room holds its breath: video stays sharp, a
  white notice pins itself center ("homeroom — sign in"), time in chalk,
  the big halo ring draws in above — the lock screen is the halo's moment.
  Keystrokes chalk tally strokes onto the slate strip; wrong code = eraser
  wipe + pink flash + shake; unlock = ring flares and expands, "good
  morning".
- **popup** — the staff-room notice: slate panel, tape tabs, chalk frame,
  bunting header with three flags that lift on bass/mid/high, footer signs
  off "see you after class".
- **notif** — system 3.
- **overview** — class photo day: slate scrim with chalk doodles, tiles as
  taped photos (white mat + tape tab underlay), hot tile gets a chalk
  circle sketched around it, the focused tile wears the halo. Hint: "pick a
  seat · ⏎ sit down · esc slip out".
- **frostify** — morning broadcast: sun wash + bunting; each track change
  pins a fresh photo bottom-right. Voice: "♪ on air (quietly)".
- **mica** — the locker room: locker band along the bottom (Canvas,
  deterministic), sun from the top; every navigation clicks a door: warm
  seam flash + a hall-pass note pinned briefly. Wordmark "⌂ locker room".
- **vellum** — study hall: sunbeam + chalk margin rule; page-turn draws a
  chalk underline across the top and dust drifts only while reading.
- **beryl** — hall pass: chalk guide line under the tab strip, stripe-pink
  accent along the status bar, tiny bunting far right; navigation slides a
  paper note along the seam. Wordmark "☼ hall pass".
- **pulse** — health check: chalk-doodle morning sun whose rays grow with
  CPU load, chalk cloud filling with memLoad; re-sort = chalk underline
  sweep, kill = THE ERASER (big smudge wipe + pink flash — erasing a name
  from the board is the scariest thing this room can do).
- **cobalt** — staff room: nearly still. Faint chalk corner ticks + morning
  gradient under the glass; rail navigation = one chalk underline sweep
  under the titlebar. Wordmark "▪ staff room".
