#version 440
// road8: CRT glass. Hard scanlines on a 3px pitch, one soft interference
// band rolling slowly down, and the city's amber glow breathing up from the
// bottom edge. Runs behind (or over) the app chrome panes; `time` is gated
// by each host so a still window costs nothing.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float px;     // item height in pixels, for pixel-locked scanlines
    vec4 glow;    // the theme's amber
} ubuf;

void main() {
    vec2 uv = qt_TexCoord0;
    float yp = uv.y * ubuf.px;
    float scan = mod(yp, 3.0) < 1.0 ? 0.05 : 0.0;
    float d = fract(uv.y - ubuf.time * 0.04);
    float band = exp(-pow((d - 0.5) * 26.0, 2.0)) * 0.05;
    float g = pow(uv.y, 3.0) * (0.085 + 0.015 * sin(ubuf.time * 0.8));
    vec3 col = ubuf.glow.rgb * (band + g);
    float a = clamp(scan + band + g, 0.0, 1.0);
    fragColor = vec4(col, a) * ubuf.qt_Opacity;
}
