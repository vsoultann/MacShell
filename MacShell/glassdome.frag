#version 440
// Thick Liquid Glass letters (Mac Hello): every stroke is a rounded glass dome lying on the scene.
//   * the height field `hmap` (the glyphs, heavily blurred) gives a surface normal everywhere inside the letter
//   * the scene is refracted through that normal — slightly per colour channel, like real glass dispersion
//   * Fresnel: the steep sides reflect more sky, so the letter brightens toward its edges
//   * a sharp specular highlight and a broad sheen from the light direction, and a soft shadow on the far side
// `mask` = sharp glyph coverage (anti-aliased edge).
// Build:  /usr/lib/qt6/bin/qsb --qt6 -o glassdome.frag.qsb glassdome.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // this item in px
    vec2 srcSize;       // backdrop texture size in px (logical)
    vec2 srcOffset;     // this item's top-left inside the backdrop, px
    float refract;      // how far the scene is bent at the steepest point, px
    float bevel;        // slope scale of the dome
    float intensity;    // frost: 0 clear … 1 milky
    vec2 lightDir;      // direction the light comes FROM (screen space)
};

layout(binding = 1) uniform sampler2D src;
layout(binding = 2) uniform sampler2D mask;
layout(binding = 3) uniform sampler2D hmap;

float H(vec2 uv) { return texture(hmap, uv).a; }
vec3 scene(vec2 p, float lod) { return textureLod(src, clamp(p / srcSize, vec2(0.001), vec2(0.999)), lod).rgb; }

void main()
{
    vec2 uv = qt_TexCoord0;
    float a = texture(mask, uv).a;
    if (a <= 0.002) { fragColor = vec4(0.0); return; }

    // surface normal of the dome
    vec2 d = 2.0 / itemSize;
    vec2 g = vec2(H(uv + vec2(d.x, 0.0)) - H(uv - vec2(d.x, 0.0)),
                  H(uv + vec2(0.0, d.y)) - H(uv - vec2(0.0, d.y)));
    vec3 n = normalize(vec3(-g * bevel, 1.0));
    float h = H(uv);

    // refraction: a thicker part of the letter bends more; red / blue a touch apart
    vec2 p = uv * itemSize + srcOffset;
    vec2 off = n.xy * refract * (0.55 + 0.45 * h);
    float lod = 0.4 + 2.5 * intensity;
    vec3 col;
    col.r = scene(p - off * 1.06, lod).r;
    col.g = scene(p - off, lod).g;
    col.b = scene(p - off * 0.94, lod).b;
    // clear glass is very slightly brighter and cooler than what is behind it
    col = col * 1.04 + vec3(0.025, 0.03, 0.04);
    col = mix(col, vec3(1.0), 0.06 + 0.5 * intensity);

    vec3 L = normalize(vec3(lightDir, 0.85));
    vec3 V = vec3(0.0, 0.0, 1.0);
    float fres = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.2);
    col += fres * 0.42;                                         // the sides catch the sky
    vec3 Hv = normalize(L + V);
    float nh = max(dot(n, Hv), 0.0);
    col += pow(nh, 90.0) * 1.1 + pow(nh, 12.0) * 0.10;          // sharp highlight + broad sheen
    float away = max(dot(normalize(n.xy + 1e-5), -normalize(lightDir)), 0.0);
    col *= 1.0 - 0.22 * fres * away;                            // the side facing away from the light is darker
    col += smoothstep(0.55, 1.0, fres) * 0.12;                  // a fine bright line right at the edge

    fragColor = vec4(clamp(col, 0.0, 1.0) * a, a) * qt_Opacity;
}
