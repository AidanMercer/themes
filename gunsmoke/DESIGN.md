# gunsmoke — the bounty ledger of a dead gunslinger

The wallpaper: a grim near-monochrome western (Hunt: Showdown). A gunslinger
in a battered hat aims a revolver through fog and rain, a skull at his belt, a
second silhouette behind him. Ash-grey, gunmetal, bone. The desktop is the
hunt itself: **fog, powder, iron, and paper**. Every widget is a page of the
dead man's ledger, or a piece of his kit — and the ledger keeps itself.

## The fiction

Somewhere a bounty ledger is still being written in a dead man's hand. The
bar is the loading gate of his revolver; the clock is a ledger entry stamped
each minute; notifications arrive as telegram slips torn off the wire; the
system readout is a condition report nailed to a post; the lock screen is a
wanted poster; the exposé is the wanted wall. Music is the band playing in
the fog — and killing a process is a gunshot.

## The laws

1. **SMOKE** — soft things appear the way smoke does: bloom, drift up, and
   dissipate. Reveals and exits are opacity + a slow upward drift, never a
   slide. Departures always take longer than arrivals (smoke lingers).
2. **HAMMER** — hard state changes are a single sharp strike: one frame of
   flash/recoil (stepped `PropertyAction` kicks, sub-100 ms scale slams),
   then settle. Workspace switch, digit change, keystroke, kill — all
   hammer events. Nothing hard ever eases in.
3. **LEDGER** — chrome is stamped and ruled like wanted-poster type and
   ledger paper: double hairline rules, corner rivets, letterspaced serif
   capitals (Noto Serif Black — the closest installed face to poster slab),
   tally marks for counting, "№" file numbers. Mono only for data columns.
4. **WITHHELD COLOR** — the world is greyscale: ash, bone, gunmetal. The
   single oxblood-red accent is *spent*, not worn — it appears only on
   danger / active / kill moments (the chamber under the hammer, a misfire,
   a critical dispatch, the kill flash) and never as decoration.

## Bespoke systems

- **The Cylinder** (bar) — workspaces are revolver chambers in a loading-gate
  strip. Occupied chambers hold a seated primer, the chamber under the hammer
  carries the one red primer dot, and chambers you emptied this session stay
  *struck* (a spent ✕ mark). The firing pin indexes to the active chamber
  and STRIKES on every switch — one-frame drop, chamber flash, and a wisp of
  powder smoke curling off the gate.
- **The tally renderer** — a Canvas glyph system that counts in gate-tally
  strokes (groups of five, fifth stroke slashed). The clock tallies the
  hour; the dispatch drawer tallies unread telegrams.
- **Powder-smoke language** — a shared one-shot smoke-puff motif (three soft
  motes: rise, grow, thin out) fired by every hammer event across bar,
  clock, lock, and the app chrome.
- **Fog-bank cava** — the visualizer is not bars: it is a fog bank along the
  bottom of the screen lit from *within*, each frequency bin a lantern-glow
  bloom inside the murk. Bass transients fire a muzzle flash in the fog —
  and only the very hottest shot shows a heartbeat of oxblood at its core.

## Palette (sampled from wallpaper.still.png)

- fog bright `#919ba0` / `#879094` → secondary, gunmetal blue-grey
- mid fog `#7d8689`, wall `#4f5355`, shadow `#484e52` → dims
- coat / iron `#283539` / `#2f393e`, night `#050a0d` → glass, bg
- bone white (skull, paper) → `#d9d3c5` text / primary
- tarnished brass (powder-burn warning) → `#a08a5f`
- oxblood (the spent accent) → `#9e2b25`

## Type

No slab/western face installed (`fc-list`: Noto + Adwaita only). Poster type
is therefore **stylized**: Noto Serif, Black weight, uppercase, wide
letterspacing = the stamp; Noto Sans Mono = the ledger's data hand.

## Motion budget

Idle desktop: fog drift only from particles.qml (sparse, gated on occluded);
everything else is event-driven one-shots. Silence parks cava's process and
its smoothing timer. Locked screen freezes everything.
