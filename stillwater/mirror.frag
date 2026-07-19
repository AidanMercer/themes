#version 440
// stillwater: the mirror pass. Samples its source flipped (a reflection),
// fades quadratically with depth, tints faintly toward the water, and
// displaces horizontally with two slow sine bands whose amplitude rides
// `stir` — 0 at rest (a static image, zero repaints), raised briefly when
// an event disturbs the water, then eased back to dead calm.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float stir;      // 0 = still water … 1 = freshly disturbed
    float strength;  // overall reflection alpha at the waterline
    vec4 water;      // deep-water tint
} ubuf;
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float depth = uv.y;                        // 0 at the waterline, 1 deep
    float wob = sin(depth * 30.0 - ubuf.time * 2.1) * 0.010 * (0.2 + depth)
              + sin(depth * 83.0 + ubuf.time * 1.3) * 0.004;
    vec2 suv = vec2(uv.x + wob * ubuf.stir, 1.0 - depth);
    vec4 c = texture(source, suv);
    // horizontal sliver breakup: thin dark interruptions that widen with depth
    float sliver = 0.75 + 0.25 * step(0.28 * (0.3 + depth), fract(depth * 26.0 + wob * 40.0));
    float a = (1.0 - depth) * (1.0 - depth) * ubuf.strength * sliver;
    vec3 col = mix(c.rgb, ubuf.water.rgb * c.a, 0.35 * (0.4 + 0.6 * depth));
    fragColor = vec4(col, c.a) * a * ubuf.qt_Opacity;
}
