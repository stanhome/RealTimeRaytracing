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
RaytracingAccelerationStructure Scene : register(t0, space0); 
//the register means the data is accessible in the first unordered access variable (UAV, identified by the letter u) bound to the shader.
RWTexture2D<float4> RenderTarget : register(u0);
//onstant buffers (CBV), can be accessed using the letter b.
ConstantBuffer<RayGenConstantBuffer> g_rayGenCB : register(b0); 

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

[shader("raygeneration")]
void MyRaygenShader()
{
	/*
		DispatchRaysDimensions():	uint3(width, height, depth) values
		DispatchRaysIndex(): Gets the current x and y location within the width and height obtained with DispatchRaysDimensions() system value intrinsic.
	*/
	float2 lerpValues = (float2)DispatchRaysIndex() / (float2)DispatchRaysDimensions();

	// Orthographic projection since we're raytracing in screen space.
	float3 rayDir = float3(0, 0, 1);
	float3 origin = float3(
		lerp(g_rayGenCB.viewport.left, g_rayGenCB.viewport.right, lerpValues.x),
		lerp(g_rayGenCB.viewport.top, g_rayGenCB.viewport.bottom, lerpValues.y),
		0.0f);

	if (IsInsideViewport(origin.xy, g_rayGenCB.stencil))
	{
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

		TraceRay(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, ~0, 0, 1, 0, ray, payload);

		// Write the raytraced color to the output texture.
		RenderTarget[DispatchRaysIndex().xy] = payload.color;
	}
	else
	{
		// Render interpolated DispatchRaysIndex outside the stencil window
		RenderTarget[DispatchRaysIndex().xy] = float4(lerpValues, 0, 1);
	}
}

[shader("closesthit")]
void MyClosestHitShader(inout RayPayload payload, in MyAttributes attr)
{
	float3 barycentrics = float3(1 - attr.barycentrics.x - attr.barycentrics.y, attr.barycentrics.x, attr.barycentrics.y);
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