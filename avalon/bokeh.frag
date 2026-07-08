#version 440
// avalon/frostify: sun-bokeh — soft gold and moss light-discs drifting up
// through the meadow glass, like light through petals. Premultiplied overlay.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds while music plays, frozen otherwise
    float width;   // item size, for square cells
    float height;
} ubuf;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 uv = qt_TexCoord0 * vec2(ubuf.width / ubuf.height, 1.0);
    vec3 col = vec3(0.0);
    float a = 0.0;

    for (int L = 0; L < 2; L++) {
        float fl = float(L);
        float scale = 5.0 + fl * 3.0;
        vec2 gv = uv * scale + vec2(0.0, ubuf.time * (0.018 + 0.012 * fl));
        vec2 id = floor(gv);
        vec2 f = fract(gv);
        vec2 c = vec2(hash2(id), hash2(id + 7.3)) * 0.6 + 0.2;
        float r = 0.10 + 0.12 * hash2(id + 3.1);
        float d = length(f - c);
        float disc = smoothstep(r, r * 0.25, d);
        float on = step(0.70, hash2(id + 11.0));           // sparse
        float s = disc * on * (0.045 + 0.030 * fl);
        vec3 tint = mix(vec3(0.90, 0.84, 0.42),            // buttercup gold
                        vec3(0.55, 0.74, 0.36),            // sunlit moss
                        hash2(id + 5.7));
        col += tint * s;
        a += s;
    }

    fragColor = vec4(col, a) * ubuf.qt_Opacity;
}
