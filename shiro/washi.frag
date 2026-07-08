#version 440
// shiro/frostify: washi — long paper fibers laid into the sheet, and a blush
// that breathes at the top of the page, slow as ink drying. Premultiplied.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds while music plays, still otherwise
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

    // fibers: noise stretched long and horizontal, like pulled mulberry pulp
    float fiber = vnoise(uv * vec2(26.0, 220.0));
    fiber = smoothstep(0.62, 0.95, fiber) * 0.028;
    vec3 ink = vec3(0.27, 0.24, 0.32);                 // ink-violet
    vec3 col = ink * fiber;
    float a = fiber;

    // the blush at the head of the page, breathing very slowly
    float breath = 0.7 + 0.3 * sin(ubuf.time * 0.12);
    float wash = smoothstep(0.30, 0.0, uv.y) * 0.030 * breath;
    col += vec3(0.74, 0.46, 0.56) * wash;              // blush rose
    a += wash;

    fragColor = vec4(col, a) * ubuf.qt_Opacity;
}
