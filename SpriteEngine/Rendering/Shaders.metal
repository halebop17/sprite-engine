#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
};

// Full-screen quad via vertex_id — no vertex buffer needed.
// Triangle strip order: BL, BR, TL, TR.
vertex VertexOut vertex_passthrough(uint vid [[vertex_id]]) {
    constexpr float2 pos[4] = {
        { -1.0,  1.0 },
        {  1.0,  1.0 },
        { -1.0, -1.0 },
        {  1.0, -1.0 },
    };
    // UV origin is top-left; NDC Y is inverted relative to texture Y.
    constexpr float2 uv[4] = {
        { 0.0, 0.0 },
        { 1.0, 0.0 },
        { 0.0, 1.0 },
        { 1.0, 1.0 },
    };
    VertexOut out;
    out.position  = float4(pos[vid], 0.0, 1.0);
    out.texCoords = uv[vid];
    return out;
}

// Sharp — nearest-neighbor, integer-scale look.
fragment float4 fragment_sharp(VertexOut        in  [[stage_in]],
                               texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::nearest, address::clamp_to_edge);
    return tex.sample(s, in.texCoords);
}

// Smooth — bilinear, for non-integer window sizes.
fragment float4 fragment_smooth(VertexOut        in  [[stage_in]],
                                texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    return tex.sample(s, in.texCoords);
}

// CRT — bilinear sample + sine-based scanlines + vignette.
fragment float4 fragment_crt(VertexOut        in  [[stage_in]],
                             texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 color = tex.sample(s, in.texCoords);

    // Sine-based scanline: one full cycle per source texel row.
    // Maps UV [0,1] → [0, texHeight] pixel rows, modulates luminance.
    float texH       = float(tex.get_height());
    float scanPhase  = in.texCoords.y * texH * M_PI_F;
    float scanline   = 0.78 + 0.22 * sin(scanPhase);
    color.rgb       *= scanline;

    // Phosphor decay: slight RGB channel offset (1-pixel horizontal shift).
    float texW      = float(tex.get_width());
    float dx        = 0.4 / texW;
    float4 left     = tex.sample(s, float2(in.texCoords.x - dx, in.texCoords.y));
    float4 right    = tex.sample(s, float2(in.texCoords.x + dx, in.texCoords.y));
    color.r         = max(color.r, left.r  * 0.18);
    color.g         = color.g;
    color.b         = max(color.b, right.b * 0.18);

    // Vignette: darken corners/edges.
    float2 vig  = in.texCoords * 2.0 - 1.0;
    float vignette = 1.0 - dot(vig * float2(0.32, 0.38), vig * float2(0.32, 0.38));
    vignette    = saturate(pow(vignette, 0.55));
    color.rgb  *= vignette;

    return color;
}
