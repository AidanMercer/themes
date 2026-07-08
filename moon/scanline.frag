#version 440
// moon/frostify: CRT overlay — scanlines + vignette + rare cyan glitch lines,
// plus a `burst` uniform the theme spikes on track change for a glitch storm.
// Pure overlay (no source texture): outputs premultiplied color over the app.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds while music plays, frozen otherwise
    float burst;   // 1 -> 0 after a track change
    float height;  // item height in px, so the line pitch stays physical
} ubuf;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void main() {
    vec2 uv = qt_TexCoord0;

    // scanlines: one dark line every ~3px, drifting slowly upward
    float y = uv.y * ubuf.height;
    float scan = 0.5 + 0.5 * sin((y + ubuf.time * 6.0) * 2.0943951);
    float a = scan * 0.075;

    // vignette pulls the corners down like a curved tube
    float d = distance(uv, vec2(0.5));
    a += smoothstep(0.55, 0.95, d) * 0.22;

    vec3 c = vec3(0.0);

    // idle glitch: each second rolls a die; on a hit a thin cyan line flashes
    float slot = floor(ubuf.time * 1.3);
    if (hash(slot) > 0.82) {
        float gy = hash(slot + 17.0);
        float line = 1.0 - smoothstep(0.0, 2.5 / ubuf.height, abs(uv.y - gy));
        float g = line * 0.35 * hash(slot + 41.0);
        c += vec3(0.0, 0.9, 1.0) * g;
        a += g;
    }

    // track-change storm: several cyan/magenta slices tear across while burst decays
    if (ubuf.burst > 0.01) {
        float t = floor(ubuf.time * 24.0);
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float gy = hash(t + fi * 7.3);
            float th = (2.0 + 6.0 * hash(t + fi * 3.1)) / ubuf.height;
            float line = 1.0 - smoothstep(0.0, th, abs(uv.y - gy));
            float g = line * 0.30 * ubuf.burst;
            c += (hash(t + fi) > 0.5 ? vec3(0.0, 0.9, 1.0) : vec3(1.0, 0.18, 0.42)) * g;
            a += g * 0.8;
        }
    }

    fragColor = vec4(c, a) * ubuf.qt_Opacity;
}
