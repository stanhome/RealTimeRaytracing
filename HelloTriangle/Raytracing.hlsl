//*********************************************************
//
// Copyright (c) Microsoft. All rights reserved.
// This code is licensed under the MIT License (MIT).
// THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
// IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
// PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
//
//*********************************************************

#ifndef RAYTRACING_HLSL
#define RAYTRACING_HLSL

#define HLSL
#include "RaytracingHlslCompat.h"

//Shader resources (SRV) correspond to the letter t.
RaytracingAccelerationStructure SceneBVH : register(t0, space0); //SRV0
//the register means the data is accessible in the first unordered access variable (UAV, identified by the letter u) bound to the shader.
RWTexture2D<float4> RenderTarget : register(u0); // UAV0
ByteAddressBuffer Indices : register(t1, space0); // SRV1
StructuredBuffer<Vertex> Vertices : register(t2, space0); //SRV2

//onstant buffers (CBV), can be accessed using the letter b.
ConstantBuffer<RayGenConstantBuffer> g_rayGenCB : register(b0); //CBV0
ConstantBuffer<SceneConstantBuffer> g_sceneCB : register(b1); //CBV1



// Load three 16 bit indices from a byte addressed buffer.
uint3 Load3x16BitIndices(uint offsetBytes)
{
	uint3 indices;

	// ByteAdressBuffer loads must be aligned at a 4 byte boundary.
	// Since we need to read three 16 bit indices: { 0, 1, 2 } 
	// aligned at a 4 byte boundary as: { 0 1 } { 2 0 } { 1 2 } { 0 1 } ...
	// we will load 8 bytes (~ 4 indices { a b | c d }) to handle two possible index triplet layouts,
	// based on first index's offsetBytes being aligned at the 4 byte boundary or not:
	//  Aligned:     { 0 1 | 2 - }
	//  Not aligned: { - 0 | 1 2 }
	const uint dwordAlignedOffset = offsetBytes & ~3;
	const uint2 four16BitIndices = Indices.Load2(dwordAlignedOffset);

	// Aligned: { 0 1 | 2 - } => retrieve first three 16bit indices
	if (dwordAlignedOffset == offsetBytes)
	{
		indices.x = four16BitIndices.x & 0xffff;
		indices.y = (four16BitIndices.x >> 16) & 0xffff;
		indices.z = four16BitIndices.y & 0xffff;
	}
	else // Not aligned: { - 0 | 1 2 } => retrieve last three 16bit indices
	{
		indices.x = (four16BitIndices.x >> 16) & 0xffff;
		indices.y = four16BitIndices.y & 0xffff;
		indices.z = (four16BitIndices.y >> 16) & 0xffff;
	}

	return indices;
}

typedef BuiltInTriangleIntersectionAttributes MyAttributes;
struct RayPayload
{
	float4 color;
};

bool IsInsideViewport(float2 p, Viewport viewport)
{
	return (p.x >= viewport.left && p.x <= viewport.right)
		&& (p.y >= viewport.top && p.y <= viewport.bottom);
}

// Generate a ray in world space for a camera pixel corresponding to an index from the dispatched 2D grid.
inline void GenerateCameraRay(uint2 index, out float3 origin, out float3 direction) {
	float2 xy = index + 0.5f; // center in the middle of the pixel
	float2 screenPos = xy / DispatchRaysDimensions().xy * 2.0 - 1.0; // [0, 1] => [-1, 1]

	// Invert Y for DirectX-style coordinates.
	screenPos.y = -screenPos.y;

	// Unproject the pixel coordinate into a ray
	float4 world = mul(float4(screenPos, 0, 1), g_sceneCB.projectionToWorld);
	world.xyz /= world.w;

	//origin = g_sceneCB.cameraPosition.xyz;
	//direction = normalize(world.xyz - origin);

	origin = (0, 0, 0);
	direction = float3(screenPos.x, screenPos.y, 1);
}


[shader("raygeneration")]
void MyRaygenShader()
{
	/*
		DispatchRaysDimensions():	uint3(width, height, depth) values
		DispatchRaysIndex(): Gets the current x and y location within the width and height obtained with DispatchRaysDimensions() system value intrinsic.
	*/
	float2 lerpValues = (float2)DispatchRaysIndex() / (float2)DispatchRaysDimensions();

	float3 origin;
	float3 rayDir;
	GenerateCameraRay(DispatchRaysIndex().xy, origin, rayDir);

	// Trace the ray.
	// Set the ray's extents.
	RayDesc ray;
	ray.Origin = origin;
	ray.Direction = rayDir;
	// Set TMin to a non-zero small value to avoid aliasing issues due to floating - point errors.
	// TMin should be kept small to prevent missing geometry at close contact areas.
	ray.TMin = 0.001;
	ray.TMax = 10000.0;
	RayPayload payload = { float4(0, 0, 0, 0) };

	//RAY_FLAG_CULL_BACK_FACING_TRIANGLES : Enables culling of back facing triangle
	/*
	Template<payload_t>
void TraceRay(RaytracingAccelerationStructure AccelerationStructure,
            uint RayFlags,
            uint InstanceInclusionMask,
            uint RayContributionToHitGroupIndex,
            uint MultiplierForGeometryContributionToHitGroupIndex,
            uint MissShaderIndex,
            RayDesc Ray,
            inout payload_t Payload);
	*/
	TraceRay(SceneBVH, RAY_FLAG_NONE, ~0, 0, 0, 0, ray, payload);

	// Write the raytraced color to the output texture.
	RenderTarget[DispatchRaysIndex().xy] = payload.color;
	//RenderTarget[DispatchRaysIndex().xy] = float4(rayDir, 1.0f);
	//RenderTarget[DispatchRaysIndex().xy] = float4(g_sceneCB.cameraPosition.y, 0, 0, 1.0f);

}

[shader("closesthit")]
void MyClosestHitShader(inout RayPayload payload, in MyAttributes attr)
{
	float3 barycentrics = float3(1 - attr.barycentrics.x - attr.barycentrics.y, attr.barycentrics.x, attr.barycentrics.y);
	//Retrieves the autogenerated index of the primitive within the geometry inside the bottom-level acceleration structure instance.
	uint vertexId = 3 * PrimitiveIndex();



	payload.color = float4(barycentrics, 1);
}

[shader("miss")]
void MyMissShader(inout RayPayload payload)
{
	//payload.color = float4(0, 0, 0, 1);

	uint2 launchIndex = DispatchRaysIndex();
	float2 dims = (float2)DispatchRaysDimensions();
	float ramp = launchIndex.y / dims.y;
	
	payload.color = float4(0.0, 0.2f, 0.7f - 0.3f * ramp, -1.0f);
}

#endif // RAYTRACING_HLSL