#version 440
// nature/frostify: honey god-rays fanning out of the top-left corner, slowly
// shimmering while the music plays. Premultiplied overlay, no source texture.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;   // seconds while music plays, frozen otherwise
} ubuf;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 o = vec2(0.02, -0.06);            // the sun sits just off the corner
    vec2 d = uv - o;
    float ang = atan(d.y, d.x);
    float r = length(d);

    float beams = 0.5 + 0.5 * sin(ang * 9.0 + sin(ubuf.time * 0.12) * 1.6);
    beams = pow(beams, 3.0);
    float fall = exp(-r * 2.1);
    float a = beams * fall * 0.13;
    a *= smoothstep(1.25, 0.35, uv.x + uv.y);   // keep the light in the corner

    vec3 c = vec3(0.91, 0.71, 0.34) * a;        // honey gold
    fragColor = vec4(c, a) * ubuf.qt_Opacity;
}
