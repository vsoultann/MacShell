#version 440
// Liquid Glass text for the MacLock clock (macOS 26/27 style).
//
// Build:  /usr/lib/qt6/bin/qsb --qt6 -o glasstext.frag.qsb glasstext.frag
//
// `mask` is the sharp rendered text (alpha = glyph coverage) and `hmap` a blurred copy of it, which serves as
// a height field: every stroke becomes a rounded glass rod. Its slope gives a surface normal, and from that:
//   * the backdrop is refracted through the rod (with a little chromatic dispersion)
//   * Fresnel brightening towards the edges, a specular highlight from the top-left, a soft inner shade bottom-right
// The body stays clear, so the wallpaper shows through the digits, bent.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // this item in px
    vec2 srcSize;       // backdrop texture size in px (logical)
    vec2 srcOffset;     // this item's top-left inside the backdrop, px
    float refract;      // backdrop shift at the steepest slope, px
    float bevel;        // slope scale (bigger = rounder, more pronounced edges)
    float lift;         // brightness added to the glass body
    float frost;        // 0..1 milky white mixed into the body
    float specAmt;      // specular highlight strength
    float fresnelAmt;   // edge brightening strength
};

layout(binding = 1) uniform sampler2D src;
layout(binding = 2) uniform sampler2D mask;
layout(binding = 3) uniform sampler2D hmap;

float H(vec2 uv) { return texture(hmap, uv).a; }

vec3 sampleBg(vec2 p, float lod)
{
    return textureLod(src, clamp(p / srcSize, vec2(0.001), vec2(0.999)), lod).rgb;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float a = texture(mask, uv).a;
    if (a <= 0.002) { fragColor = vec4(0.0); return; }

    // height-field slope (central differences, 1.5 px)
    vec2 d = 1.5 / itemSize;
    vec2 g = vec2(H(uv + vec2(d.x, 0.0)) - H(uv - vec2(d.x, 0.0)),
                  H(uv + vec2(0.0, d.y)) - H(uv - vec2(0.0, d.y))) * bevel;
    // surface normal: up the slope is "out" of the glass, z towards the viewer
    vec3 N = normalize(vec3(-g, 1.0));

    // refraction: the rod bends the backdrop towards its centre line (lens), plus dispersion per channel
    vec2 p = uv * itemSize + srcOffset;
    vec2 shift = -N.xy * refract;
    vec3 bg;
    bg.r = sampleBg(p + shift * 1.12, 0.4).r;
    bg.g = sampleBg(p + shift, 0.4).g;
    bg.b = sampleBg(p + shift * 0.88, 0.4).b;
    float l = dot(bg, vec3(0.299, 0.587, 0.114));
    bg = mix(vec3(l), bg, 1.3);

    vec3 col = bg * 1.08 + lift;
    col = mix(col, vec3(1.0), frost);

    // Fresnel: glancing edges reflect more
    float fres = pow(1.0 - N.z, 1.6);
    col += fres * fresnelAmt;

    // specular from the top-left, slightly towards the viewer
    vec3 L = normalize(vec3(-0.55, -0.75, 0.9));
    vec3 Hh = normalize(L + vec3(0.0, 0.0, 1.0));
    float spec = pow(max(dot(N, Hh), 0.0), 28.0) * step(0.02, 1.0 - N.z);
    col += spec * specAmt;

    // the far side of each stroke catches a little shade
    col -= max(dot(N.xy, vec2(0.45, 0.85)), 0.0) * 0.18;

    fragColor = vec4(clamp(col, 0.0, 1.0) * a, a) * qt_Opacity;
}
