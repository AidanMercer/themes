# sakura — HANAMI

Soft-focus cherry branches against a hazy spring sky, sun leaking through
top-right, loose petals already in the air. Flower-viewing weather. Nobody
under this tree is checking the time on purpose.

## The fiction

**The desktop is the air under the canopy.** Every widget is something the
breeze is holding up for a moment: a branch laid across the top of the
screen, a wish-plaque hanging off it, petals that only fall one at a time.
The shell isn't chrome; it's what drifted into the afternoon.

## The laws

1. **Everything speaks in bloom.** The theme's one glyph is the five-petal
   sakura blossom with the notched tip, drawn parametrically (a Canvas
   painter, `drawBlossom(ctx, r, bloom)`) at any stage from closed bud
   (bloom 0) to full open flower (bloom 1). State is always a bloom
   fraction: workspaces are buds on a twig and the active one opens; the
   visualizer's branch blooms with the music; the lock's passcode gathers
   petals one keystroke at a time. No gauges, no LEDs — buds and flowers.
2. **Arrive by opening, leave by letting go.** Nothing slides in from an
   edge or pops. A widget blooms into place (scale + unfold, OutSine); a
   departure is a petal released — a small shape falling on a curved path,
   turning once, fading. The minute changing on the clock releases exactly
   one petal.
3. **Chill pace, still air.** InOutSine / OutSine only, 400ms and up,
   small amplitudes. A silent, untouched desktop is still air: one ambient
   petal at a time from particles.qml, everything else parked. Sway is
   reserved for things that hang (the plaque on its cord).
4. **Dusk-plum glass defeats the bright sky.** Panels are near-solid
   `glass` (≥0.8) with petal-cream text; pink is light falling on things,
   never the paper itself. Floating text gets a plum scrim.

## The machinery (nowhere else)

- The parametric notched-petal blossom painter, shared idiom across bar /
  cava / lock / clock — bud→bloom is this theme's number system.
- cava: a low hanging branch whose blossom clusters open per-band with the
  music and shed single petals on peaks; at silence the branch fades away.
- lock (bareLock): the video keeps playing; typing gathers petals into a
  blossom — one petal per keystroke, wrong password scatters all five.

## Voice

lowercase, unhurried, hanami-flavored: "the afternoon held", "petals
drifted in", "drift to a window". Faces: Noto Sans Light for the airy
display type, Noto Sans Mono for readouts.
