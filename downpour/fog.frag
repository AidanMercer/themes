#version 440
// downpour: condensation on the app glass — two scales of beads that SIT on
// the pane, swelling and drying over minutes (never falling — the falling
// is done by discrete droplet-run flourishes, not this field), plus a fog
// bank pooling along the bottom edge. Premultiplied overlay.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // seconds while the window is awake, frozen otherwise
    float density;   // 0..1 — how hard it's raining on this glass
    vec4 tint;       // pane-light color
} ubuf;

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float a = 0.0;
    float glint = 0.0;

    for (int L = 0; L < 2; L++) {
        float fl = float(L);
        float n = 26.0 + fl * 24.0;                 // cells across this layer
        vec2 g = uv * vec2(n, n * 0.62);
        vec2 id = floor(g);
        vec2 f = fract(g);
        vec2 h = hash2(id + fl * 31.0);
        if (h.x < ubuf.density) {
            vec2 c = 0.25 + 0.5 * hash2(id + 7.0 + fl);
            float r = 0.07 + 0.15 * h.y;
            // slow condensation cycle — a bead takes minutes to come and go
            float phase = 0.5 + 0.5 * sin(ubuf.time * (0.05 + 0.09 * h.y) + h.x * 6.2831);
            float rr = r * (0.55 + 0.45 * phase);
            vec2 d = f - c;
            d.y *= 0.82;                            // beads hang slightly tall
            float dist = length(d);
            a += smoothstep(rr, rr * 0.5, dist) * (0.09 + 0.10 * h.y) * phase;
            // the cold glint riding each bead's shoulder
            glint += smoothstep(rr * 0.45, 0.0,
                                length(d + vec2(rr * 0.33, rr * 0.33))) * 0.16 * phase;
        }
    }

    // the fog bank pooling along the bottom of the pane
    a += smoothstep(0.55, 1.0, uv.y) * 0.085;

    vec3 col = ubuf.tint.rgb * a + vec3(0.86, 0.93, 1.0) * glint;
    float alpha = clamp(a + glint, 0.0, 1.0);
    fragColor = vec4(col, alpha) * ubuf.qt_Opacity;
}
