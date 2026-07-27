// nightshift — the window-grid renderer and the ripple scheduler.
//
// This is the theme's font, chart and meter, all one thing. A "facade" is a
// grid of rooms (cols x rows, row 0 at the TOP). A "plan" is a flat array of
// 0/1 the same length, saying which rooms should be lit. The plan builders
// below are the three grammars the theme speaks — a level fills bottom-up, a
// glyph spells a character in rooms, a series draws a skyline — and every one
// of them hands its result to the same ripple scheduler, which is why the
// clock, the load gauge and the visualizer all read as the same city.
//
// Stateless by design (.pragma library): the mutable cell state lives in the
// QML component that owns the canvas, so every widget can share this code
// without sharing a city.
.pragma library

// ── the font: 5x7 room maps ────────────────────────────────────────────────
// '#' is a lit room. Digits are drawn a little heavier than the letters
// because the clock sets them at size and they carry the most weight.
var _FONT = {
    "0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["###..", "#..#.", "#...#", "#...#", "#...#", "#..#.", "###.."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    ":": [".....", "..#..", "..#..", ".....", "..#..", "..#..", "....."],
    ".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
    "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
    " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."]
}

var GLYPH_W = 5
var GLYPH_H = 7

// a .pragma library exports its FUNCTIONS across the QML boundary but not its
// vars, so the font's dimensions have to be reachable as calls
function glyphW() { return GLYPH_W }
function glyphH() { return GLYPH_H }

// how wide a string is in rooms, at the given inter-character gap
function textWidth(str, gap) {
    var n = String(str).length
    if (n === 0) return 0
    return n * GLYPH_W + (n - 1) * (gap === undefined ? 1 : gap)
}

// ── plans ──────────────────────────────────────────────────────────────────
function blank(cols, rows) {
    var p = new Array(cols * rows)
    for (var i = 0; i < p.length; i++) p[i] = 0
    return p
}

// a 0..1 value as lit floors, bottom-up — a building empties from the top
// down, so it fills from the bottom up. The partial top floor lights a
// proportional run of rooms from the left so the value stays readable
// between whole floors instead of quantizing away.
function planLevel(plan, cols, rows, v, x0, w, y0, h) {
    x0 = x0 || 0; y0 = y0 || 0
    w = w || cols; h = h || rows
    v = Math.max(0, Math.min(1, v))
    var floors = v * h
    var whole = Math.floor(floors)
    var partial = floors - whole
    for (var f = 0; f < whole; f++) {
        var r = y0 + h - 1 - f
        for (var c = 0; c < w; c++) plan[r * cols + x0 + c] = 1
    }
    if (whole < h && partial > 0.02) {
        var pr = y0 + h - 1 - whole
        var lit = Math.max(1, Math.round(partial * w))
        for (var pc = 0; pc < lit; pc++) plan[pr * cols + x0 + pc] = 1
    }
    return plan
}

// stamp one character's room map at (x0, y0)
function planGlyph(plan, cols, rows, ch, x0, y0) {
    var g = _FONT[String(ch).toUpperCase()]
    if (!g) return plan
    for (var r = 0; r < GLYPH_H; r++) {
        var y = y0 + r
        if (y < 0 || y >= rows) continue
        var line = g[r]
        for (var c = 0; c < GLYPH_W; c++) {
            var x = x0 + c
            if (x < 0 || x >= cols) continue
            if (line.charAt(c) === "#") plan[y * cols + x] = 1
        }
    }
    return plan
}

// stamp a whole string
function planText(plan, cols, rows, str, x0, y0, gap) {
    gap = (gap === undefined) ? 1 : gap
    var s = String(str)
    var x = x0
    for (var i = 0; i < s.length; i++) {
        planGlyph(plan, cols, rows, s.charAt(i), x, y0)
        x += GLYPH_W + gap
    }
    return plan
}

// a series of 0..1 values as a skyline: each entry is a building `bw` rooms
// wide, its height quantized to whole floors
function planBars(plan, cols, rows, series, bw, gap) {
    bw = bw || 2; gap = (gap === undefined) ? 1 : gap
    var x = 0
    for (var i = 0; i < series.length && x + bw <= cols; i++) {
        var floors = Math.round(Math.max(0, Math.min(1, series[i])) * rows)
        for (var f = 0; f < floors; f++) {
            var r = rows - 1 - f
            for (var c = 0; c < bw; c++) plan[r * cols + x + c] = 1
        }
        x += bw + gap
    }
    return plan
}

// ── the cells: what the city currently believes ────────────────────────────
// one object per room. `on` is what the switch is set to, `v` is how bright
// the room actually is right now (it overshoots on the way up), `at` is when
// a pending change lands, `ph` is a fixed per-room phase so no two rooms
// flutter together.
function makeCells(n) {
    var cells = new Array(n)
    for (var i = 0; i < n; i++)
        cells[i] = { on: 0, tgt: 0, v: 0, at: 0, ph: Math.random() * 6.283, fl: 0 }
    return cells
}

function resizeCells(cells, n) {
    if (cells.length === n) return cells
    if (cells.length > n) return cells.slice(0, n)
    var out = cells.slice()
    for (var i = cells.length; i < n; i++)
        out.push({ on: 0, tgt: 0, v: 0, at: 0, ph: Math.random() * 6.283, fl: 0 })
    return out
}

// THE RIPPLE. Diff the plan against what's actually lit and give every
// changed room its own delay inside a 250-450ms scatter, so a value change
// arrives room by room instead of as one synchronized flip. Returns true if
// anything is now pending.
function applyPlan(cells, plan, now, spread) {
    spread = spread || 380
    var pending = false
    var n = Math.min(cells.length, plan.length)
    for (var i = 0; i < n; i++) {
        var want = plan[i] ? 1 : 0
        var c = cells[i]
        if (c.tgt !== want) {
            c.tgt = want
            // lights go ON over the full scatter and OFF a touch quicker —
            // people turn a lamp on deliberately and off on their way past
            c.at = now + Math.random() * (want ? spread : spread * 0.6)
            pending = true
        } else if (c.at > 0) pending = true
    }
    return pending
}

// light the whole facade instantly (boot, or a hard reset) with no ripple
function setPlan(cells, plan) {
    var n = Math.min(cells.length, plan.length)
    for (var i = 0; i < n; i++) {
        var want = plan[i] ? 1 : 0
        cells[i].tgt = want; cells[i].on = want; cells[i].at = 0
        cells[i].v = want
    }
}

// one room flutters — the rare sodium flicker. Picking a single random lit
// room every couple of seconds keeps the city alive without pinning a
// repaint loop to the render thread forever.
function flutter(cells) {
    var lit = []
    for (var i = 0; i < cells.length; i++) if (cells[i].on && cells[i].v > 0.5) lit.push(i)
    if (lit.length === 0) return false
    cells[lit[Math.floor(Math.random() * lit.length)]].fl = 1
    return true
}

// advance the city one frame. Returns true while anything is still moving —
// the owner stops its timer when this goes false, so a settled facade costs
// nothing until the next state change.
function tick(cells, now) {
    var busy = false
    for (var i = 0; i < cells.length; i++) {
        var c = cells[i]
        if (c.at > 0 && now >= c.at) {
            c.at = 0
            c.on = c.tgt
            if (c.on) c.v = 1.5      // the bloom as the switch snaps
        }
        if (c.at > 0) busy = true

        var target = c.on ? 1 : 0
        if (c.v !== target) {
            // coming up: decay out of the bloom. going down: a switch, not a dimmer
            c.v += (target - c.v) * (c.on ? 0.20 : 0.42)
            if (Math.abs(c.v - target) < 0.01) c.v = target
            else busy = true
        }
        if (c.fl > 0) {
            c.fl -= 0.055
            if (c.fl < 0) c.fl = 0
            else busy = true
        }
    }
    return busy
}

// the brightness a room should paint at, flutter included
function bright(c) {
    if (c.v <= 0) return 0
    var b = c.v
    if (c.fl > 0) {
        // a sodium tube stuttering: two quick dips inside the envelope
        b *= 0.35 + 0.65 * Math.abs(Math.sin(c.fl * 9.0 + c.ph))
    }
    return b
}

// ── the draw ───────────────────────────────────────────────────────────────
// One pass for the dark rooms (a single fillStyle) and one for the lit ones.
// `litCss` / `darkCss` are plain color strings; alpha rides globalAlpha so we
// never build a color string per room.
function draw(ctx, cells, cols, rows, cw, ch, gap, darkCss, litCss, dim) {
    if (cols <= 0 || rows <= 0) return
    var pitchX = cw + gap, pitchY = ch + gap
    var i, r, c, cell

    ctx.globalAlpha = 1
    ctx.fillStyle = darkCss
    for (r = 0; r < rows; r++) {
        for (c = 0; c < cols; c++) {
            cell = cells[r * cols + c]
            if (cell && cell.v > 0.03) continue
            ctx.fillRect(c * pitchX, r * pitchY, cw, ch)
        }
    }

    ctx.fillStyle = litCss
    for (r = 0; r < rows; r++) {
        for (c = 0; c < cols; c++) {
            i = r * cols + c
            cell = cells[i]
            if (!cell || cell.v <= 0.03) continue
            var b = bright(cell)
            ctx.globalAlpha = Math.min(1, b * (dim === undefined ? 1 : dim))
            ctx.fillRect(c * pitchX, r * pitchY, cw, ch)
            // the bloom spill while a room is still snapping on
            if (b > 1.02) {
                ctx.globalAlpha = Math.min(0.5, (b - 1) * 0.7)
                ctx.fillRect(c * pitchX - 1, r * pitchY - 1, cw + 2, ch + 2)
            }
        }
    }
    ctx.globalAlpha = 1
}

// how many whole rooms fit, and the leftover — used to keep facades on a
// crisp room pitch instead of fractional pixels
function fit(span, cw, gap) {
    return Math.max(1, Math.floor((span + gap) / (cw + gap)))
}
