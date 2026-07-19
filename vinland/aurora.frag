#version 440
// vinland: aurora curtains across the top of a surface — three slow ribbons
// breathing between aurora green and starlit ice, falling off into a faint
// downward glow. Premultiplied overlay, no source texture.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds while the host surface stirs, frozen otherwise
} ubuf;

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 col = vec3(0.0);
    float a = 0.0;

    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float y0 = 0.08 + 0.075 * fi
                 + 0.045 * sin(uv.x * 4.0 + ubuf.time * 0.22 + fi * 2.1)
                 + 0.020 * sin(uv.x * 9.5 - ubuf.time * 0.14 + fi * 4.7);
        float d = uv.y - y0;
        float core = exp(-d * d * 1400.0);                       // ribbon
        float veil = exp(-abs(d) * 26.0) * step(0.0, d) * 0.45;  // curtain below
        float s = core * 0.14 + veil * 0.09;
        vec3 tint = mix(vec3(0.47, 0.71, 0.59),                  // aurora green
                        vec3(0.56, 0.81, 0.93),                  // starlit ice
                        0.5 + 0.5 * sin(fi * 1.9 + ubuf.time * 0.11 + uv.x * 2.0));
        col += tint * s;
        a += s;
    }

    // keep it in the sky — fade fully out by mid-window
    float fade = 1.0 - smoothstep(0.30, 0.52, uv.y);
    fragColor = vec4(col * fade, a * fade) * ubuf.qt_Opacity;
}
