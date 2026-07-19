#version 440
// lonely-train: rain on the carriage window — two depths of thin diagonal
// streaks, shared by every app-chrome slot (frostify/mica/vellum/beryl/
// pulse/cobalt). `time` advances only while the host's gate is open, so a
// frozen clock is a dry window. Premultiplied overlay.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;   // seconds while music plays, frozen otherwise
} ubuf;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void main() {
    vec2 uv = qt_TexCoord0;
    float a = 0.0;

    for (int L = 0; L < 2; L++) {
        float fl = float(L);
        float cols = 70.0 + fl * 50.0;                    // streak density per layer
        float x = uv.x * cols + uv.y * cols * (0.10 + fl * 0.06);  // slight slant
        float col = floor(x);
        float fx = fract(x);
        float speed = 0.45 + 0.4 * hash(col + fl * 77.0);
        float phase = fract(uv.y * (0.6 + fl * 0.3) - ubuf.time * speed + hash(col * 1.7 + fl));
        float dash = smoothstep(0.0, 0.10, phase) * smoothstep(0.30, 0.10, phase);
        float thin = smoothstep(0.40, 0.5, fx) * smoothstep(0.60, 0.5, fx);
        a += dash * thin * (0.045 + 0.035 * fl);
    }

    vec3 c = vec3(0.55, 0.65, 0.85) * a;   // cold window-blue
    fragColor = vec4(c, a) * ubuf.qt_Opacity;
}
