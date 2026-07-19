# thicket — the watcher in the underbrush

Wallpaper: a painterly dark-anime close-up — a girl with pale iris eyes
peering through dense deep-teal foliage, ember red-orange light on skin and
cloth, dappled light through the canopy, letterboxed in black.

## Fiction

The desktop **is** the thicket, and you are being watched — calmly,
patiently, without malice. Every widget is something *glimpsed through the
leaves*: nothing presents itself, everything is spotted. The UI behaves like
an animal in cover — perfectly still until it decides to move, then one
quick, precise dart, then still again.

## Laws

1. **Nothing shows itself whole.** Every surface is partially occluded.
   Panels carry clusters of leaf silhouettes biting into their edges (the
   house `LeafSpray` renderer); content reveals by *parting* — leaves dart
   aside from the gap — and hides by closing. No clean rectangles anywhere.
2. **Freeze → dart.** Long holds, then one fast precise movement
   (160–260 ms, OutQuint), then stillness. No perpetual sway, no ambient
   drift loops. An idle desktop is a frozen thicket; state changes dart.
3. **Attention gets the light.** The focused / active / sung thing gets the
   dapple (a warm ember light patch) or the eyeshine. Everything else sits
   in shadow — dim, desaturated leaf grey-green.

## Bespoke systems

- **LeafSpray** — the leaf-mask renderer. A Canvas idiom (pasted per file —
  widgets can't share imports) that draws deterministic clusters of pointed
  leaf silhouettes along a panel edge in deep foliage tones, each leaf with
  its own size/angle/phase. `rustleT` drives a *rustle*: on state change
  every leaf darts a few px along its own axis and freezes back. Every
  panel in the theme is edged by it — the theme's signature shape.
- **Eyeshine** — a pair of pale-iris almond glints. In the bar it looks out
  of the gap of the *active workspace*, blinks occasionally (slow,
  deliberate), and on switch it blinks shut and reopens in the new gap —
  the dart. On the lock screen the eyes watch the passcode and flash ember
  on a wrong code. Rarely, a pair appears in a desktop corner for a few
  seconds (particles slot), then blinks out.
- **The parting hedge (cava)** — an *inverted* visualizer: a closed band of
  dark foliage sits across the lower screen; sound doesn't raise bars, it
  **parts the leaves** — per-bin gaps open and ember light spills through
  from behind. Loud = the thicket glows through open gaps; silence = the
  hedge closes and fades. Bass spikes startle a brief eyeshine glint in a
  random gap.
- **Lyrics darting out of cover** — every word of the line is on stage but
  hidden under a leaf cover; as the karaoke sweep reaches a word its leaf
  darts aside and the word appears lit by dapple; sung words settle into
  shadow; the line closes over when done. Words move like the animal: they
  don't fade in, they appear.

## Palette (sampled from wallpaper.still.png)

- ember accent `#e0785a` (lit cloth/skin edge), danger ember-red `#cf4b33`
- pale iris `#c6d0e2` (her eyes) — second accent / eyeshine
- dapple amber `#d8985c` — warning / light patches
- leaf grey-green `#465148` — dim traces (sampled `#565858`/`#6b6e67`)
- teal-black glass `#0b100e`, bg `#0a0f0d` (canopy `#1b1917`, teal leaf `#22413b`)
- text warm pale `#e9e0d2`, hue_green `#5d8272`, hue_blue `#8ba3c2`

## Type

- `Noto Sans Mono` for data (pal.fontMono)
- **Noto Serif Display** as the display face — painterly, storybook; the
  clock and lyrics speak in serif, italic for whispers. (fc-list verified.)

## Slot map

- **clock** — upper-left canopy dark: serif time sighted through a parted
  leaf frame; minute change = old digit darts down like a flicked leaf, new
  one appears; a dapple patch darts across once a minute. Caption: "STILL.
  THEN GONE."
- **bar** (top) — the hedge line: foliage strip with leaf fringe hanging
  from its lower edge; workspaces are *gaps* in the hedge, eyeshine looks
  out of the active gap; left = "heard in the brush" (now playing), right =
  watcher's eye (sysinfo hover trigger), signal, battery, small time, a
  curled leaf (popup).
- **sysinfo** — hover/pin reveal, "WHAT IT KNOWS": tally panel, rows
  CPU/MEM/GPU/NET/PWR metered in leaf pips; parts in with a rustle + settle
  sway; polls only while shown.
- **cava/cava.conf** — the parting hedge (28 bins, sleep_timer 5, full
  idle + process-gate contract).
- **lyrics** — words dart from cover (above), adlibs are italic whispers in
  iris blue.
- **particles** — rare single leaves: stillness, then one leaf darts down a
  short arc and is gone; the occasional corner eyeshine. Very sparse.
- **lock** — bareLock: the thicket closes. Leaf borders crowd in from the
  screen edges with progress; center gap panel blurs its own slice; berry
  pips fill ember as you type; eyes above the panel watch, flash ember on
  fail, part on unlock ("it lets you pass").
- **popup** — leaf-bitten dialog, eyeshine + THICKET header, 3-cluster
  rustle meter on the audio bus, footer "move slow — it sees you."
- **notif** — "something moved": leaf-bitten cards, single glint lamp in
  urgency color; center panel "FIELD SIGHTINGS", DND = "eyes closed."
- **overview** — the clearing: dark scrim, leaf vignette, hot tile gets the
  eyeshine pair beside it; hint "choose your path through the brush."
- **frostify** — the songbird: corner sprays, static dapple while singing,
  track change = rustle + the dapple darts to a new branch. Voice: "♪ IT
  SINGS", "… HUSHED", "■ FLOWN".
- **mica** — foraging: nav = a rustle darts across the top seam; wordmark
  "❧ foraging".
- **vellum** — the hide: dapple lies on the page while reading; page
  compose = one light sweep; nothing moves while typing (reading gate
  verbatim).
- **beryl** — tracking: hedge fringe on the tab band, nav = rustle along
  the seam; wordmark "❧ on the scent". Chrome bands only.
- **pulse** — the brush tenses: corner leaves lean/ember with host.load
  (binding, no loop); sort = light rustle; kill = ember flash, the brush
  goes still. wordmark "❧ heartbeat".
- **cobalt** — restrained: faint corner sprays under the glass, one quiet
  rustle line on nav. wordmark "thicket".

## Motion vocabulary (implementation)

dart-in: 180–240 ms OutQuint from a small offset; dart-out: 140 ms InQuint;
rustle: per-leaf offset with 0–80 ms per-index stagger, then freeze; blink:
scaleY 1→0.1→1 in two hard steps. Every infinite loop gates on
occluded/open/active/playing per the contract; blinks and rare events are
Timer-driven with long intervals and gated the same way.
