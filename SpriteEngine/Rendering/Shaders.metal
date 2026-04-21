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
