#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
};

struct InstanceData {
    float4x4 modelMatrix;
    float4 color;
};

struct Uniforms {
    float4x4 viewProjectionMatrix;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut instanced_billboard_vertex(uint vertexID [[vertex_id]],
                                            uint instanceID [[instance_id]],
                                            const device Vertex *vertices [[buffer(0)]],
                                            const device InstanceData *instances [[buffer(1)]],
                                            constant Uniforms &uniforms [[buffer(2)]]) {
    VertexOut out;
    float4 localPosition = float4(vertices[vertexID].position, 1.0);
    float4 worldPosition = instances[instanceID].modelMatrix * localPosition;
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    out.color = instances[instanceID].color;
    return out;
}

fragment float4 instanced_billboard_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
