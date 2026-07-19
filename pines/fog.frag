#version 440
// pines: the cab glass. A thin drift of fog banks (fbm value noise) breathing
// across the pane while the surface is awake, plus a `burst` uniform the
// chrome spikes on nav/track/page events — a breath of condensation exhaled
// onto the glass that clears as burst decays 1 -> 0. `ember` tints the breath
// toward danger red (pulse's kill event). Pure overlay, premultiplied.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds while awake, frozen otherwise
    float burst;   // 1 -> 0 after an event: the breath of condensation
    float ember;   // 0..1 danger tint on the breath
} ubuf;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    v += 0.50 * vnoise(p);
    v += 0.25 * vnoise(p * 2.03 + 7.7);
    v += 0.125 * vnoise(p * 4.11 + 19.3);
    return v / 0.875;
}

void main() {
    vec2 uv = qt_TexCoord0;

    // fog banks drifting slowly leftward, denser toward the pane's foot
    vec2 p = vec2(uv.x * 2.6 + ubuf.time * 0.022, uv.y * 1.4);
    float bank = fbm(p);
    float density = smoothstep(0.45, 0.85, bank) * (0.35 + 0.65 * uv.y);
    float a = density * 0.075;

    // the breath: condensation blooming from the middle of the glass,
    // textured by a finer noise so it reads as droplet fog, not a disc
    float br = ubuf.burst;
    if (br > 0.004) {
        float d = distance(uv, vec2(0.5, 0.5));
        float bloom = smoothstep(0.75, 0.15, d);
        float grain = 0.55 + 0.45 * vnoise(uv * vec2(22.0, 14.0) + ubuf.time * 0.5);
        a += br * bloom * grain * 0.26;
    }

    // fog silver, warmed toward ember red only when danger breathes
    vec3 fogCol = mix(vec3(0.62, 0.74, 0.83), vec3(0.85, 0.42, 0.30), clamp(ubuf.ember, 0.0, 1.0));
    fragColor = vec4(fogCol * a, a) * ubuf.qt_Opacity;
}
