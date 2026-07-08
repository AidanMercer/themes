#version 440
// fuel/frostify: frozen ground-mist creeping under the canopy — icy cyan fog
// drifting sideways along the bottom of the window. Premultiplied overlay.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds while music plays, frozen otherwise
} ubuf;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void main() {
    vec2 uv = qt_TexCoord0;

    float n = vnoise(uv * vec2(4.0, 9.0) + vec2(ubuf.time * 0.06, 0.0)) * 0.65
            + vnoise(uv * vec2(9.0, 18.0) - vec2(ubuf.time * 0.04, 0.0)) * 0.35;

    float bank = smoothstep(0.62, 0.98, uv.y);      // hugs the ground
    float a = bank * n * 0.11;

    vec3 c = vec3(0.62, 0.83, 0.90) * a;            // icy fluorescent
    fragColor = vec4(c, a) * ubuf.qt_Opacity;
}
