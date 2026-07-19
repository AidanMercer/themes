# encore — "the encore, from the diva's side of the stage"

The wallpaper is the last second of a concert: Miku fills the frame, V-sign
up, headset still hot, magenta rig-lights glinting off her hair clips, the
dark of the hall behind her. This desktop is everything she can see from
there — **the stage rig at the encore**. The bar is the mixing/light desk at
the lip of the stage. The clock is the venue's cue clock. Lyrics are the
piano roll her voice is printed on. Cava is the sea of glowsticks in the
dark. The lock screen is the stage door.

## Laws

1. **Everything is quantized to the bar.** The rig runs an internal count
   (~120 BPM, 8th-note grid). Nothing drifts: blinks are metronome ticks,
   sweeps land on beats, meters step in whole segments like an LED ladder.
   While audio plays, motion rides the audio pulse; the grid is the fiction's
   physics even when derived from a timer.
2. **Light is stagecraft.** Things APPEAR by spotlight — iris up from black,
   scale from a point of light — and LEAVE by blackout/hard cut. Never
   fade-drift, never slide-in-from-offscreen. A state change is a lighting
   cue: snap, then hold.
3. **Silence = house lights.** No music → the stage rests. Glowsticks die,
   the roll stops, meters park at zero, nothing loops. A silent desktop is a
   dark, still hall (idle-cheap by fiction, not just by contract).
4. **Two voices, never blended.** Teal is the diva — primary, melody,
   everything that sings. Magenta is the crowd/alert — response, danger,
   applause. They alternate and answer each other (call-and-response) but
   never gradient into each other. Warm spot-white is the follow spot,
   reserved for the "now" (active word, focused window, the beat).
5. **The language is musical-theatrical**, never military-digital: note
   blocks, piano-roll lanes, VU needles and LED ladders, spotlight cones,
   glowsticks, cue sheets, setlists, stage doors. No glitch, no scanlines,
   no HUD brackets, no reticles (moon owns those).

## Bespoke systems

- **The piano roll (lyrics.qml).** Lyrics render as a real scrolling
  piano-roll: each word is a NOTE BLOCK whose lane (row) is a pitch hashed
  from the word, whose length is its duration, sitting on beat-gridded lanes.
  The karaoke sweep is the PLAYHEAD — a vertical cue line with a follow-spot
  glow; blocks light teal as the playhead crosses them, adlibs are short
  magenta ghost-notes in the upper lanes. Sung text prints beneath the roll
  as the "lyric sheet" line. Nothing like it in any sibling theme.
- **The glowstick sea (cava.qml).** Not bars: a CROWD. ~48 glowsticks in
  three depth rows across the bottom of the screen, each a thin capsule of
  light held by an invisible hand. Each stick's tilt/lift follows its
  spectrum bin — the crowd sways with the mix, lifts on the drop. Teal
  sticks with a scattered minority of magenta ones (the crowd answering).
  At silence the sea goes dark stick by stick and the process parks.
- **The beat grid / cue system (shared idiom).** A reusable motion idiom
  every widget speaks: `beat` timers at 500ms (120 BPM) drive hard
  two-frame blinks (cue lamps), stepped LED ladders (whole segments only),
  and the spotlight-iris transition (scale 0→1 with OutBack from a glow
  point + a snap to full opacity — appear; opacity 1→0 in <90ms — blackout).

## Slots, in the fiction

- **clock.qml** — the CUE CLOCK, upper-right against the dark hall: big
  Noto Sans Mono time as "SET TIME", a beat-blinking cue lamp, the date as a
  tour date ("ON STAGE · FRI 18 JUL"), and a bar-count strip of 8 segment
  lamps that steps once a second (the count-in). Once a minute: a spotlight
  flourish — the digits blackout-cut and iris back.
- **bar.qml** — the LIGHT DESK, top edge: left = now-playing as the "PGM"
  program monitor with a stepped VU ladder; center = workspaces as a
  CHANNEL STRIP of 10 faders (active channel's fader up + lit, occupied
  channels cue-lamped with app icons); right = a stage-door sysinfo lamp
  ("DESK"), net/battery as desk tell-tales, time, and the [CUE] button for
  the popup. Panels are flat dark desk metal with a 2px teal edge-strip.
- **sysinfo.qml** — the PATCH BAY, hover-reveal from the DESK lamp: a rack
  panel that drops on a lighting batten (settle = the batten bounce), rows
  CH1 VOX (CPU) / CH2 KEYS (MEM) / CH3 SYNTH (GPU) / CH4 FOH (NET) / CH5
  PWR (battery) each with an LED ladder meter stepping in whole segments.
- **particles.qml** — DUST IN THE BEAM: two faint spotlight cones from the
  top corners (teal from stage-left, warm white from stage-right), slow
  bright motes drifting through them. Sparse, dim, resting-stage calm.
- **lock.qml** — bareLock: the STAGE DOOR. Video stays sharp; a dark door
  panel irises up center with "STAGE DOOR — PASS REQUIRED", the time as the
  call time, passcode as a row of PASS lamps that light teal per keystroke;
  wrong code = the whole row flashes magenta + the panel knocks; unlock =
  "ENCORE!" and a full-screen spotlight iris wipe.
- **popup.qml** — the CUE SHEET: dark desk card, teal edge-strip header
  "CUE SHEET // FOH DESK" with a live 3-lamp EQ, footer signs "V// FROM THE
  STAGE" with a beat-blinking block.
- **notif.qml** — STAGE NOTES: cards get a left lane-strip like one piano
  roll lane with a note block sitting on it (urgency-tinted); panel =
  "SETLIST" with beat tick.
- **overview.qml** — the SETLIST / monitor wall: scrim is the dark hall,
  backdrop draws spotlight beams down to the real tile ring + a glowstick
  row along the bottom; selected tile gets a follow-spot cone from above
  (tileOverlay), center tile a small "ON AIR" tag.
- **app chrome** — one grammar: a piano-roll lane strip along the bottom
  (mica: directories are measures — nav = a note block pulse runs the lane;
  frostify: the roll lives under the panes and the playhead runs while
  playing; vellum: the page is the score — reading gate, page-turn = one
  playhead sweep; beryl: tab seam = the lane, nav = note pulse; pulse:
  the desk's main VU — load breathes the lamp ladder, kill = magenta
  blackout cue; cobalt: quiet lane + wordmark only, restrained).

## Palette (sampled from wallpaper.still.png)

- teal / diva primary `#56c8d8` (brightened from hair-light #7ea5b4 /
  #7fb2d3, eye teal #639eac)
- nail-lacquer mid-blue `#4aa4e4` (nails #46acea) — secondary
- crowd magenta `#e0338c` (clip glint #c82a7c) — alert
- follow-spot warm white `#f6dfd2` (skin light #f4d1dc, de-pinked) — warn
- steel-blue dim `#3c5878` (hair shadow #304d75 / #3d6681)
- text `#e4f0f6`, glass `#070a12` (stage black #05040b)
- bg `#05070e`, fg `#dceaf4`, hue_green `#4ecfb0`, hue_blue `#4aa4e4`

Fonts: Noto Sans Mono (rig labels, mono), Noto Sans (display). No CJK.

## Uniqueness check

moon is the nearest neighbor (cyan/dark). moon = military netrunner HUD:
glitch storms, scanline shader, chromatic fringe, corner brackets. encore
uses NONE of those — its dialect is lanes/notes/lamps/cones, its motion is
beat-quantized cues and iris/blackout, its shapes are rounded capsules
(glowsticks, faders, note blocks) not chamfered chassis. stars owns
vending-grid cava + constellations; road8 owns the pixel font; no overlap.
