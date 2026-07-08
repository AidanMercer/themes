#version 440
// guts/frostify: printed-page pass — pulp grain and an ink vignette pressed
// into the paper. No time uniform on purpose: a page doesn't move, so this
// renders exactly once. Premultiplied overlay.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float width;   // item size, for per-pixel grain
    float height;
} ubuf;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = floor(uv * vec2(ubuf.width, ubuf.height));

    // pulp grain: sparse ink flecks pressed into the sheet
    float g = hash2(px);
    float fleck = step(0.94, g) * 0.045 + step(0.985, hash2(px + 31.0)) * 0.06;

    // ink vignette rolled onto the edges
    float d = distance(uv, vec2(0.5));
    float vin = smoothstep(0.55, 0.95, d) * 0.10;

    float a = fleck + vin;
    vec3 ink = vec3(0.086, 0.082, 0.10);
    fragColor = vec4(ink * a, a) * ubuf.qt_Opacity;
}
