#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 viewProjection;
    float angWidth;
    float curve;
    float videoAspect;
    float radius;
    float showVideo;
    float rotation;
    float pad0;
    float pad1;
};

struct ScreenVertex {
    float2 uv;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

float2 rotateUV(float2 uv, float rotation) {
    if (rotation < 0.5) {
        return uv;
    }
    if (rotation < 1.5) {
        return float2(uv.y, 1.0 - uv.x);
    }
    if (rotation < 2.5) {
        return float2(1.0 - uv.x, 1.0 - uv.y);
    }
    return float2(1.0 - uv.y, uv.x);
}

vertex VertexOut theaterVertex(
    const device ScreenVertex *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    float2 uv = vertices[vid].uv;
    float halfAngle = max(uniforms.angWidth, 0.05) * 0.5;
    float theta = (uv.x - 0.5) * uniforms.angWidth;
    float radius = max(uniforms.radius, 0.2);
    float aspect = max(uniforms.videoAspect, 0.01);
    float halfWidth = radius * tan(halfAngle);
    float halfHeight = halfWidth / aspect;

    float xFlat = (uv.x - 0.5) * 2.0 * halfWidth;
    float y = (0.5 - uv.y) * 2.0 * halfHeight;
    float zFlat = -radius;
    float xCurved = sin(theta) * radius;
    float zCurved = -cos(theta) * radius;
    float curve = saturate(uniforms.curve);

    float3 position = float3(
        mix(xFlat, xCurved, curve),
        y,
        mix(zFlat, zCurved, curve)
    );

    VertexOut out;
    out.position = uniforms.viewProjection * float4(position, 1.0);
    out.uv = uv;
    return out;
}

float3 testCard(float2 uv) {
    float3 color = float3(0.027, 0.031, 0.047);
    float column = abs(fract(uv.x * 8.0) - 0.5);
    float row = abs(fract(uv.y * 5.0) - 0.5);
    if (column > 0.47 || row > 0.46) {
        color = float3(0.16, 0.17, 0.20);
    }
    if (abs(uv.y - 0.5) < 0.004) {
        color = float3(0.91, 0.69, 0.35);
    }
    if (abs(uv.x - 0.5) < 0.003) {
        color = float3(0.96, 0.94, 0.90);
    }
    if (abs(uv.x - 0.30) < 0.018 && abs(uv.y - 0.5) < 0.07) {
        color = float3(0.91, 0.69, 0.35);
    }
    return color;
}

fragment float4 theaterFragment(
    VertexOut in [[stage_in]],
    texture2d<float> video [[texture(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    float3 color;
    if (uniforms.showVideo > 0.5) {
        float2 sampleUV = rotateUV(in.uv, uniforms.rotation);
        color = video.sample(textureSampler, sampleUV).rgb;
    } else {
        color = testCard(in.uv);
    }

    float edgeX = min(in.uv.x, 1.0 - in.uv.x);
    float edgeY = min(in.uv.y, 1.0 - in.uv.y);
    if (edgeX < 0.012 || edgeY < 0.018) {
        color = mix(color, float3(0.91, 0.69, 0.35), 0.85);
    }
    return float4(color, 1.0);
}
