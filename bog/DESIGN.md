# bog — SLOW NOON

A hand-painted folktale swamp: a frog and a hedgehog-ish friend fishing from
a leaf-sail raft in a dark mossy pond, tall sunlit grass behind, one thin
fishing line touching the water. Nobody is in a hurry. Nobody has ever been
in a hurry here.

## The fiction

**The desktop is the pond's surface.** Every widget is a thing that FLOATS
on it — a leaf, a bobber, a lily pad, a scrap of bark. The shell isn't
chrome; it's flotsam the pond happens to be carrying at slow noon.

## The laws

1. **Nothing is rigid.** Every widget rides its own gentle water line: a slow
   sine bob (2–4px, 5–9s periods, phase-offset so nothing moves in step) and
   sometimes a fraction of a degree of roll. All bobbing gates on `occluded`.
2. **Arrive by surfacing, leave by sinking.** Nothing fades or slides in from
   an edge. A widget rises from just under its waterline (translate up +
   opacity, heavy-damped OutSine) and pushes a ripple as it breaks the
   surface. Departure is the reverse: it settles under and is gone.
3. **State changes ripple.** Every event — a minute turning, a notification
   landing, a keystroke on the lock, a directory change — drops something
   into the pond, and the pond answers with expanding concentric rings.
   Rings are ELLIPSES (the pond seen at an angle), never circles.
4. **Folktale pace.** InOutSine / OutSine only, durations 600ms+, nothing
   snappy, nothing bouncy. The fastest thing in this world is a fish, and
   even the fish takes its time.
5. **What floats casts a reflection.** Major surfaces render a dim, wavering
   mirror of themselves below their waterline — the house rendering rule
   (shader-wobbled for the clock/lock, hand-mirrored dim strokes elsewhere).

## Bespoke systems (nothing else has these)

- **The waterline + reflection idiom** — a custom `reflect.frag` shader
  (mirrored resample, sinusoidal wobble growing with depth, alpha falling
  off) under the desktop clock and lock panel; cheaper hand-mirrored
  ellipse-smudges under bar pads and cava. Every widget declares where its
  waterline is; content lives above it, its ghost below.
- **The ripple engine** — a shared Canvas idiom (three staggered expanding
  ellipse rings, OutSine, 1.5–2s) duplicated per-file per the widget
  contract; the single visual verb for "something happened".
- **The fishing-float clock** — the time floats on open water lower-left; a
  two-tone cork bobber sits exactly where the wallpaper's painted fishing
  line meets the pond. When the minute turns the bobber DIPS (a bite), rings
  spread, the old minute sinks below the waterline while the new one
  surfaces through it.
- **The pond breathes music (cava)** — the spectrum IS the water surface: a
  band of open water whose surface curve deforms with the bins (bass swells,
  treble chops), lily pads riding the swell and tilting with the slope,
  dragonflies hovering over the running peaks. Flat, still, unpainted at
  silence. (Deliberately NOT grass/reeds — nature/ owns the meadow.)
- **Lily-pad workspaces + the hopping frog (bar)** — the bar is the pond's
  edge waterline; workspaces are lily pads; the active pad carries a tiny
  frog that HOPS pad-to-pad on switch (parabolic arc, small squash, a
  ripple where it lands).
- **Float-string gauges (sysinfo)** — "depth soundings": every metric is a
  string of ten cork floats on a line; load pulls floats UNDER the line one
  by one (submerged = dim moss below the waterline). CPU is the current,
  RAM the silt, GPU the deep pool, battery the firefly jar.

## Palette (sampled from wallpaper.still.png)

canopy light `#b4ad62`, sunlit grass top `#8f885c`, grass blade `#525028`,
glint `#4d5322`, hedgehog fur `#8a6324`, lit root `#5f4721`, deep water
`#13130e`, mid water `#1a1810`.

- accent      `#c9ba62` — sunlit-grass amber (pal.neon)
- accent2     `#8ea24e` — moss green (pal.cyan)
- accent3     `#b85c33` — rust / the bobber's bait-red (pal.magenta)
- accent_warn `#d29a41` — hedgehog amber (pal.amber)
- accent_dim  `#4d4a2e` — dry reed (pal.dim)
- text        `#e6dfb8` — warm straw
- glass       `#12140b` — murky water

Type: `Noto Serif Display` (Light) for anything storybook-sized — the pond
keeps a written folktale voice, lowercase, unhurried ("the pond remembers",
"still water", "choose a lily pad"). `Noto Sans Mono` for small readouts.

## Slot map

- clock — fishing-float clock, open water lower-left, shader reflection
- bar — waterline strip: lily-pad workspaces + hopping frog, media leaf,
  cattail sysinfo trigger, dragonfly net, firefly-jar battery, leaf-sail popup
- cava — the pond surface as spectrum + pads + dragonflies
- lyrics — words float on the waterline, soak sunlit as sung, sink when done
- sysinfo — hover-reveal float-string soundings, buoyant settle on reveal
- particles — pollen motes in the light shafts + the odd falling leaf
- lock — bareLock: video stays sharp; a leaf-raft panel surfaces beneath the
  raft; passcode is a string of floats pulled under per keystroke; wrong
  code pops them all back up and rocks the panel
- popup/notif/overview — pebble-drop chrome, ripple verbs, folktale voice
- frostify/mica/vellum/beryl/pulse/cobalt — waterline + ripple + one-shot
  fish-jump/pebble flourishes on the app's nav event, all gated per contract
