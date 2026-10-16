#version 440
// Liquid Glass clock digits, the way macOS 26 / iOS 26 draw the lock screen time.
//
// Build:  /usr/lib/qt6/bin/qsb --qt6 -o glasstext.frag.qsb glasstext.frag
//
// Not a puffed-up lens: the digits are FLAT, frosted glass. The body shows the (already blurred) wallpaper,
// lifted and a touch milky, so it reads as light glass on any background; only a thin rim along the edges bends
// the backdrop and catches light — bright on the side facing the light (top-left), a faint dark line on the
// far side. `mask` = sharp glyph coverage; `hmap` = a SLIGHTLY blurred copy, used only to find the rim.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // this item in px
    vec2 srcSize;       // backdrop texture size in px (logical)
    vec2 srcOffset;     // this item's top-left inside the backdrop, px
    float refract;      // backdrop shift inside the rim, px
    float bevel;        // rim slope scale
    float lift;         // brightness added to the body
    float frost;        // 0..1 milky white mixed into the body
    float specAmt;      // lit rim strength
    float fresnelAmt;   // all-round rim strength
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

    // rim: slope of the lightly blurred glyphs (zero in the flat middle of a stroke)
    vec2 d = 2.0 / itemSize;
    vec2 g = vec2(H(uv + vec2(d.x, 0.0)) - H(uv - vec2(d.x, 0.0)),
                  H(uv + vec2(0.0, d.y)) - H(uv - vec2(0.0, d.y)));
    float slope = length(g);
    float rim = clamp(slope * bevel, 0.0, 1.0);          // 0 body .. 1 edge
    vec2 n = slope > 1e-5 ? -g / slope : vec2(0.0);      // outward edge direction (screen space)

    // body: the frosted wallpaper behind, lifted; only the rim bends it (a few px), with a hint of dispersion
    vec2 p = uv * itemSize + srcOffset;
    vec2 shift = n * refract * rim * rim;
    vec3 bg;
    bg.r = sampleBg(p - shift * 1.10, 1.2).r;
    bg.g = sampleBg(p - shift, 1.2).g;
    bg.b = sampleBg(p - shift * 0.90, 1.2).b;
    float l = dot(bg, vec3(0.299, 0.587, 0.114));
    bg = mix(vec3(l), bg, 1.25);                         // vibrancy: a little more colour than the wallpaper
    vec3 col = bg * 1.06 + lift;
    col = mix(col, vec3(1.0), frost);
    // glass catches more light at the top of each digit than at the bottom
    col += (0.5 - uv.y) * 0.08;

    // light from the top-left: the edge facing it glows, the far edge gets a faint dark line
    vec2 L = normalize(vec2(-0.6, -0.8));
    float facing = dot(n, L);
    // a soft sheen on the edges facing the light (no outline all the way round)
    float sheen = smoothstep(0.0, 1.0, rim);
    col += sheen * fresnelAmt;
    col += sheen * max(facing, 0.0) * specAmt;
    col -= sheen * max(-facing, 0.0) * 0.05;

    fragColor = vec4(clamp(col, 0.0, 1.0) * a, a) * qt_Opacity;
}
