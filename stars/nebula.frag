#version 440
// stars/frostify: nebula haze — slate-blue and coral clouds drifting almost
// imperceptibly behind the starfield, upper sky only. Premultiplied overlay.
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

    float n = vnoise(uv * 3.0 + vec2(ubuf.time * 0.010, 0.0)) * 0.6
            + vnoise(uv * 7.0 - vec2(ubuf.time * 0.006, 0.0)) * 0.4;
    n = smoothstep(0.42, 0.85, n);

    float sky = smoothstep(0.72, 0.10, uv.y);          // upper sky only
    float a = n * sky * 0.085;

    // hue drifts between starlit slate and the coral horizon
    float h = vnoise(uv * 2.0 + vec2(0.0, ubuf.time * 0.004));
    vec3 tint = mix(vec3(0.28, 0.37, 0.52),            // starlit slate
                    vec3(0.85, 0.57, 0.62),            // coral cloud
                    smoothstep(0.35, 0.75, h) * 0.5);
    fragColor = vec4(tint * a, a) * ubuf.qt_Opacity;
}
