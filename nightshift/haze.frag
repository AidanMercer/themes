#version 440

// nightshift — the haze that hangs over the district, used behind app chrome.
// Cheap 3-octave value-noise fbm scrolling slowly leftward, tinted cold. The
// `warm` uniform pushes a wave of sodium through it: nav events in the apps
// (a page turn, a directory change, a kill) raise it to 1 and it cools back to
// 0, which is how the six apps share the desktop's one-warm-room law.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // seconds, driven by the chrome's animator
    float warm;      // 0..1 sodium surge
    float density;   // how much haze there is at all
    vec4 coolCol;    // the night blue
    vec4 warmCol;    // the window sodium
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        v += amp * vnoise(p);
        p *= 2.03;
        amp *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;

    // the haze drifts left and very slowly settles downward
    vec2 p = vec2(uv.x * 3.4 + time * 0.045, uv.y * 2.1 - time * 0.012);
    float n = fbm(p);

    // banked thicker toward the bottom, the way it sits in the valley
    float bank = smoothstep(0.05, 1.0, uv.y);
    float a = n * density * (0.35 + 0.65 * bank);

    // the sodium surge rides through on a horizontal wave so it reads as
    // something passing, not the whole panel changing colour at once
    float wave = smoothstep(0.0, 0.55, warm) * exp(-pow((uv.x - (1.0 - warm * 1.25)) * 2.4, 2.0));
    vec3 col = mix(coolCol.rgb, warmCol.rgb, clamp(wave + warm * 0.18, 0.0, 1.0));

    a = clamp(a + wave * 0.16, 0.0, 1.0);
    fragColor = vec4(col * a, a) * qt_Opacity;
}
