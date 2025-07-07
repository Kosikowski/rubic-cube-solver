#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

struct InstanceUniforms {
    float4x4 modelMatrix;
    float3 faceColors[6];
};

struct Uniforms {
    float4x4 vpMatrix;
    float3 lightPos;
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float3 faceColor;
};

vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],
    constant Uniforms& uniforms [[buffer(2)]],
    constant InstanceUniforms* instances [[buffer(1)]],
    uint instanceID [[instance_id]],
    uint vertexID [[vertex_id]]
) {
    VertexOut out;
    const InstanceUniforms inst = instances[instanceID];
    float4 worldPos = inst.modelMatrix * float4(in.position, 1.0);
    out.position = uniforms.vpMatrix * worldPos;
    out.normal = normalize((inst.modelMatrix * float4(in.normal, 0.0)).xyz);
    uint face = (vertexID / 4) % 6;
    out.faceColor = inst.faceColors[face];
    return out;
}

fragment half4 fragment_main(VertexOut in [[stage_in]]) {
    float3 lightDir = normalize(float3(1,1,1));
    float diff = max(dot(in.normal, lightDir), 0.2);
    float3 displayColor = in.faceColor;
    if (all(displayColor == float3(0,0,0))) {
        displayColor = float3(0.15, 0.15, 0.15); // dark gray for internal/invisible faces
    }
    float3 color = displayColor * diff + 0.1;
    return half4(color.r, color.g, color.b, 1.0);
}
