#include <metal_stdlib>
using namespace metal;

// Input vertex data structure
// Contains the position and normal vector for each vertex
struct VertexIn {
    float3 position [[attribute(0)]]; // Vertex position in object space
    float3 normal [[attribute(1)]];   // Vertex normal vector in object space
};

// Per-instance uniform data
// Stores the model matrix to transform vertices from object to world space
// and an array of colors for each of the 6 faces of the cube
struct InstanceUniforms {
    float4x4 modelMatrix;  // Transformation matrix for this instance
    float3 faceColors[6];  // Colors assigned to each face of the cube
};

// Global uniform data shared across all instances and vertices
// Contains the view-projection matrix and the position of the light source
struct Uniforms {
    float4x4 vpMatrix;     // Combined view and projection matrix
    float3 lightPos;       // Position of the light source in world space
};

// Output structure from the vertex shader to the fragment shader
// Provides the transformed position, the transformed normal vector,
// and the color of the current face being rendered
struct VertexOut {
    float4 position [[position]]; // Clip space position of the vertex
    float3 normal;                // Normal vector transformed to world space
    float3 faceColor;             // Color of the current face
};

/* 
 Vertex Shader: vertex_main
 This function processes each vertex of the mesh. It transforms the vertex position
 from object space to clip space using the model and view-projection matrices.
 It also transforms the vertex normal vector to world space and determines the
 color of the face the vertex belongs to based on the vertex ID.
*/
vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],                         // Input vertex attributes
    constant Uniforms& uniforms [[buffer(2)]],       // Global uniform data
    constant InstanceUniforms* instances [[buffer(1)]], // Per-instance data array
    uint instanceID [[instance_id]],                  // Current instance index
    uint vertexID [[vertex_id]]                        // Current vertex index
) {
    VertexOut out;

    // Retrieve the instance-specific data for this instance
    const InstanceUniforms inst = instances[instanceID];

    // Transform vertex position from object space to world space
    float4 worldPos = inst.modelMatrix * float4(in.position, 1.0);

    // Transform the position from world space to clip space
    out.position = uniforms.vpMatrix * worldPos;

    // Transform normal vector to world space and normalize it
    out.normal = normalize((inst.modelMatrix * float4(in.normal, 0.0)).xyz);

    // Determine the face index based on the vertex ID (assuming 4 vertices per face)
    uint face = (vertexID / 4) % 6;

    // Assign face color based on the face index
    out.faceColor = inst.faceColors[face];

    return out;
}

/* 
 Fragment Shader: fragment_main
 This function computes the final color of each pixel. It calculates diffuse lighting
 based on the normal vector and a fixed light direction. It also handles special cases
 where the face color is black by substituting a default dark gray color.
*/
fragment half4 fragment_main(VertexOut in [[stage_in]]) {

    // Define a directional light coming from the vector (1,1,1)
    float3 lightDir = normalize(float3(1,1,1));

    // Calculate diffuse lighting factor using Lambert's cosine law
    // Clamp to a minimum of 0.2 to avoid completely dark areas
    float diff = max(dot(in.normal, lightDir), 0.2);

    // Start with the interpolated face color
    float3 displayColor = in.faceColor;

    // If the face color is black (0,0,0), replace it with a dark gray color
    // This helps visualize internal or invisible faces
    if (all(displayColor == float3(0,0,0))) {
        displayColor = float3(0.15, 0.15, 0.15);
    }

    // Combine the diffuse color with a small ambient term (0.1)
    float3 color = displayColor * diff + 0.1;

    // Return the final color with half opacity
    return half4(color.r, color.g, color.b, 0.5);
}
