#version 440
// bog: the pond's reflection. Samples the source item mirrored (uv.y flipped)
// with a sinusoidal x-wobble that grows with depth — the further under the
// waterline, the more the water breaks the image — and an alpha falloff so
// the ghost dissolves into the murk. `time` drifts slowly (gated by the
// widget); `amp` is the wobble strength in uv units.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float amp;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float depth = uv.y;                     // 0 at the waterline, 1 at the deepest
    float wob = sin(depth * 34.0 + ubuf.time * 1.3) * ubuf.amp * depth
              + sin(depth * 11.0 - ubuf.time * 0.7) * ubuf.amp * 0.6 * depth;
    vec2 s = vec2(uv.x + wob, 1.0 - uv.y);  // mirrored
    vec4 c = texture(source, s);
    float fade = (1.0 - depth * 1.15);
    fade = clamp(fade, 0.0, 1.0) * 0.55;
    fragColor = c * fade * ubuf.qt_Opacity;
}
