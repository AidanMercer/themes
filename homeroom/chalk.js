// homeroom: the chalk renderer. A vector stroke font (digits + colon) and a
// stroke engine that draws polylines the way a hand draws chalk: subdivided
// with seeded jitter, a soft ghost pass under a grainy bright pass, alpha
// varying along the line, dust speckles at the wrist. Supports partial-length
// reveal so glyphs are WRITTEN tip-first, never faded in.
.pragma library

// ── seeded rng (mulberry32) — same seed, same handwriting ──────────────────
function rng(seed) {
    var a = (seed * 1315423911) >>> 0
    return function () {
        a |= 0; a = (a + 0x6D2B79F5) | 0
        var t = Math.imul(a ^ (a >>> 15), 1 | a)
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
}

// ── the stroke font: normalized 0..1 in a 0.72w × 1h box ───────────────────
// each glyph = array of strokes; each stroke = array of [x, y]
var GLYPHS = {
    "0": [[[0.50,0.06],[0.74,0.14],[0.84,0.42],[0.80,0.72],[0.58,0.94],[0.34,0.92],[0.17,0.68],[0.16,0.36],[0.30,0.10],[0.50,0.06]]],
    "1": [[[0.30,0.24],[0.52,0.06],[0.52,0.95]],
          [[0.30,0.95],[0.74,0.95]]],
    "2": [[[0.18,0.28],[0.24,0.11],[0.50,0.05],[0.76,0.13],[0.82,0.33],[0.62,0.58],[0.34,0.78],[0.17,0.95],[0.84,0.94]]],
    "3": [[[0.18,0.14],[0.46,0.05],[0.74,0.14],[0.79,0.30],[0.55,0.47],[0.79,0.62],[0.84,0.80],[0.56,0.95],[0.20,0.87]]],
    "4": [[[0.58,0.05],[0.14,0.62],[0.86,0.62]],
          [[0.68,0.36],[0.68,0.95]]],
    "5": [[[0.80,0.06],[0.22,0.06],[0.18,0.45],[0.50,0.40],[0.78,0.54],[0.82,0.75],[0.60,0.93],[0.20,0.87]]],
    "6": [[[0.74,0.08],[0.42,0.20],[0.22,0.48],[0.18,0.74],[0.38,0.93],[0.68,0.90],[0.82,0.70],[0.72,0.52],[0.42,0.50],[0.23,0.62]]],
    "7": [[[0.16,0.08],[0.84,0.06],[0.44,0.95]],
          [[0.30,0.52],[0.66,0.52]]],
    "8": [[[0.50,0.05],[0.73,0.14],[0.71,0.31],[0.50,0.44],[0.29,0.31],[0.27,0.14],[0.50,0.05]],
          [[0.50,0.44],[0.77,0.57],[0.80,0.80],[0.50,0.95],[0.20,0.80],[0.23,0.57],[0.50,0.44]]],
    "9": [[[0.79,0.22],[0.62,0.06],[0.35,0.06],[0.20,0.22],[0.22,0.42],[0.46,0.51],[0.70,0.45],[0.79,0.28]],
          [[0.79,0.22],[0.81,0.58],[0.68,0.88],[0.38,0.95]]],
    ":": [[[0.48,0.30],[0.54,0.33],[0.50,0.38],[0.46,0.33],[0.50,0.30]],
          [[0.48,0.66],[0.54,0.69],[0.50,0.74],[0.46,0.69],[0.50,0.66]]],
    " ": []
}

function segLen(pts, w, h) {
    var L = 0
    for (var i = 1; i < pts.length; i++) {
        var dx = (pts[i][0] - pts[i-1][0]) * w
        var dy = (pts[i][1] - pts[i-1][1]) * h
        L += Math.sqrt(dx * dx + dy * dy)
    }
    return L
}

function glyphLength(ch, w, h) {
    var g = GLYPHS[ch] || []
    var L = 0
    for (var s = 0; s < g.length; s++) L += segLen(g[s], w, h)
    return L
}

// ── the engine: one jittered chalk polyline in PIXEL coords ────────────────
// opts: { seed, color:"#hex"/css, alpha, width, reveal (px budget or -1),
//         ghost (bool), dust (0..1 density) }
// returns pixels of budget consumed
function strokePath(ctx, pts, opts) {
    if (pts.length < 2) return 0
    var rnd = rng(opts.seed || 1)
    var lw = opts.width || 3
    var alpha = opts.alpha === undefined ? 0.9 : opts.alpha
    var budget = opts.reveal === undefined ? -1 : opts.reveal
    var step = Math.max(3, lw * 1.6)

    // subdivide with perpendicular jitter into a wobble polyline
    var wob = [[pts[0][0], pts[0][1]]]
    for (var i = 1; i < pts.length; i++) {
        var x0 = pts[i-1][0], y0 = pts[i-1][1]
        var x1 = pts[i][0],   y1 = pts[i][1]
        var dx = x1 - x0, dy = y1 - y0
        var len = Math.sqrt(dx * dx + dy * dy)
        var n = Math.max(1, Math.round(len / step))
        var px = -dy / (len || 1), py = dx / (len || 1)
        for (var k = 1; k <= n; k++) {
            var t = k / n
            var j = (k === n && i === pts.length - 1) ? 0 : (rnd() - 0.5) * lw * 0.9
            wob.push([x0 + dx * t + px * j, y0 + dy * t + py * j])
        }
    }

    // ghost pass: the chalk's soft double, offset a hair
    if (opts.ghost !== false) {
        ctx.save()
        ctx.globalAlpha = alpha * 0.20
        ctx.strokeStyle = opts.color
        ctx.lineWidth = lw * 1.7
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()
        var spent0 = 0
        ctx.moveTo(wob[0][0] + lw * 0.35, wob[0][1] + lw * 0.35)
        for (var gi = 1; gi < wob.length; gi++) {
            var gl = Math.sqrt(Math.pow(wob[gi][0]-wob[gi-1][0],2) + Math.pow(wob[gi][1]-wob[gi-1][1],2))
            if (budget >= 0 && spent0 + gl > budget) break
            spent0 += gl
            ctx.lineTo(wob[gi][0] + lw * 0.35, wob[gi][1] + lw * 0.35)
        }
        ctx.stroke()
        ctx.restore()
    }

    // main pass: short grainy sub-strokes, alpha breathing along the line
    ctx.save()
    ctx.strokeStyle = opts.color
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    var spent = 0
    for (var m = 1; m < wob.length; m++) {
        var sl = Math.sqrt(Math.pow(wob[m][0]-wob[m-1][0],2) + Math.pow(wob[m][1]-wob[m-1][1],2))
        if (budget >= 0 && spent + sl > budget) break
        spent += sl
        ctx.globalAlpha = alpha * (0.55 + rnd() * 0.45)
        ctx.lineWidth = lw * (0.75 + rnd() * 0.45)
        ctx.beginPath()
        ctx.moveTo(wob[m-1][0], wob[m-1][1])
        ctx.lineTo(wob[m][0], wob[m][1])
        ctx.stroke()
        // dust speckles off the wrist
        if (opts.dust && rnd() < opts.dust) {
            ctx.globalAlpha = alpha * 0.20 * rnd()
            ctx.fillStyle = opts.color
            var ds = 1 + rnd() * 1.6
            ctx.fillRect(wob[m][0] + (rnd() - 0.5) * lw * 4,
                         wob[m][1] + (rnd() - 0.5) * lw * 4, ds, ds)
        }
    }
    ctx.restore()
    return spent
}

// ── a glyph, written into box (x, y, w, h). reveal 0..1 over total length ──
function drawGlyph(ctx, ch, x, y, w, h, opts) {
    var g = GLYPHS[ch] || []
    if (!g.length) return
    var total = glyphLength(ch, w, h)
    var budget = (opts.reveal === undefined ? 1 : Math.max(0, Math.min(1, opts.reveal))) * total
    for (var s = 0; s < g.length; s++) {
        if (budget <= 0.5) break
        var pts = []
        for (var i = 0; i < g[s].length; i++)
            pts.push([x + g[s][i][0] * w, y + g[s][i][1] * h])
        var spent = strokePath(ctx, pts, {
            seed: (opts.seed || 1) * 31 + s * 7 + ch.charCodeAt(0),
            color: opts.color,
            alpha: opts.alpha,
            width: opts.width || Math.max(2, w * 0.10),
            reveal: budget,
            ghost: opts.ghost,
            dust: opts.dust === undefined ? 0.10 : opts.dust
        })
        budget -= spent
    }
}

// ── an eraser smudge: a pale dry streak, density fading with t ─────────────
// t 0..1 — the wipe travels left→right across the box as it grows
function drawSmudge(ctx, x, y, w, h, t, color, seed) {
    if (t <= 0) return
    var rnd = rng((seed || 5) * 97)
    ctx.save()
    var edge = x + w * Math.min(1, t * 1.15)
    for (var i = 0; i < 14; i++) {
        var sx = x + rnd() * (edge - x)
        var sy = y + rnd() * h
        var sw = w * (0.10 + rnd() * 0.25)
        var sh = h * (0.06 + rnd() * 0.10)
        ctx.globalAlpha = 0.05 + rnd() * 0.06
        ctx.fillStyle = color
        ctx.fillRect(sx - sw / 2, sy - sh / 2, sw, sh)
    }
    ctx.restore()
}
