#version 440
// sailing/frostify: the dusk sea — a blush of horizon light, rolling wave
// contours and deep water gathering at the bottom of the window. Replaces the
// old Canvas swell. Premultiplied overlay.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds while music plays, becalmed otherwise
} ubuf;

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 col = vec3(0.0);
    float a = 0.0;

    const float horizon = 0.58;

    // dusk glow hugging the horizon line
    float glow = exp(-abs(uv.y - horizon) * 26.0) * 0.075;
    col += vec3(0.79, 0.63, 0.71) * glow;            // lavender-pink
    a += glow;

    // three wave contours rolling through the water
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float yk = horizon + 0.06 + fk * 0.10
                 + sin(uv.x * 7.0 + ubuf.time * 0.45 + fk * 2.1) * 0.012
                 + sin(uv.x * 13.0 - ubuf.time * 0.30 + fk * 4.3) * 0.006;
        float line = exp(-abs(uv.y - yk) * 260.0) * (0.11 - fk * 0.025);
        vec3 tint = (k == 0) ? vec3(0.79, 0.63, 0.71)   // catching the dusk
                             : vec3(0.50, 0.65, 0.59);  // sea glass
        col += tint * line;
        a += line;
    }

    // deep water at the hull
    float deep = smoothstep(horizon, 1.0, uv.y) * 0.10;
    col += vec3(0.04, 0.06, 0.12) * deep;
    a += deep;

    fragColor = vec4(col, a) * ubuf.qt_Opacity;
}
