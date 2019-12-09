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

#pragma once

#include "DXSample.h"
#include "StepTimer.h"
#include "RaytracingHlslCompat.h"

using Microsoft::WRL::ComPtr;

namespace GlobalRootSignatureParams {
	enum Value {
		OutputViewSlot = 0,
		AccelerationStructureSlot,
		SceneConstantSlot,
		VertexBuffersSlot,
		Count,
	};
}

namespace LocalRootSignatureParams {
	enum Value {
		ViewportConstantSlot = 0,
		Count
	};
}

class D3D12HelloTriangle : public DXSample
{
public:
	D3D12HelloTriangle(UINT width, UINT height, std::wstring name);

	// IDeviceNotify
	virtual void OnDeviceLost() override;
	virtual void OnDeviceRestored() override;

	// Messages
	virtual void OnInit();
	virtual void OnUpdate();
	virtual void OnRender();
	virtual void OnSizeChanged(UINT width, UINT height, bool minimized);
	virtual void OnDestroy();
	virtual IDXGISwapChain* GetSwapchain() { return m_deviceResources->GetSwapChain(); }

	virtual void onMouseMoveOriginal(UINT8 wParam, UINT32 lParam) override;
	virtual void onLeftButtonDownOriginal(UINT32 lParam) override;

private:

	static const UINT FrameCount = 3;

	// We'll allocate space for serveral of these  and the will need to padded for alignment.
	static_assert(sizeof(SceneConstantBuffer) < D3D12_CONSTANT_BUFFER_DATA_PLACEMENT_ALIGNMENT, "Checking the size here");

	union AlignedSceneConstantBuffer {
		SceneConstantBuffer constants;
		uint8_t alignmentPadding[D3D12_CONSTANT_BUFFER_DATA_PLACEMENT_ALIGNMENT];
	};
	AlignedSceneConstantBuffer *_mappedConstantData;
	ComPtr<ID3D12Resource> _perFrameConstants;

	// DirectX Raytracing (DXR) attributes
	ComPtr<ID3D12Device5> m_dxrDevice;
	ComPtr<ID3D12GraphicsCommandList4> m_dxrCommandList;
	ComPtr<ID3D12StateObject> m_dxrStateObject;

	// Root signatures
	ComPtr<ID3D12RootSignature> m_raytracingGlobalRootSignature;
	ComPtr<ID3D12RootSignature> m_raytracingLocalRootSignature;

	// Descriptors
	ComPtr<ID3D12DescriptorHeap> m_descriptorHeap;
	UINT m_descriptorsAllocated;
	UINT m_descriptorSize;

	// Raytracing scene
	RayGenConstantBuffer m_rayGenCB;

	// Geometry
	struct D3DBuffer {
		ComPtr<ID3D12Resource> resource;
		D3D12_CPU_DESCRIPTOR_HANDLE cpuDescriptorHandle;
		D3D12_GPU_DESCRIPTOR_HANDLE gpuDescriptorHandle;
	};
	D3DBuffer m_indexBuffer;
	D3DBuffer m_vertexBuffer;

	// added by stan
	// Acceleration structure
	//struct AccelerationStructureInstance {
	//	// Bottom-level AS
	//	ID3D12Resource *bottomLevelAS;
	//	// transform matrix
	//	const DirectX::XMMATRIX &transform;
	//	// instance id visible in the shader
	//	UINT instanceId;
	//	// hit group index used to fetch the shaders from the SBT
	//	UINT hitGroupIndex;

	//	AccelerationStructureInstance(ID3D12Resource *blAS, const DirectX::XMMATRIX &t, UINT iId, UINT hgId)
	//		: bottomLevelAS(blAS), transform(t), instanceId(iId), hitGroupIndex(hgId) {};
	//};

	ComPtr<ID3D12Resource> m_accelerationStructure;
	ComPtr<ID3D12Resource> m_bottomLevelAccelerationStructure;
	UINT _instanceCount = 1;
	std::vector<std::pair<ComPtr<ID3D12Resource>, DirectX::XMMATRIX>> _instances;
	ComPtr<ID3D12Resource> m_topLevelAccelerationStructure;

	// Raytracing output
	ComPtr<ID3D12Resource> m_raytracingOutput;
	D3D12_GPU_DESCRIPTOR_HANDLE m_raytracingOutputResourceUAVGpuDescriptor;
	UINT m_raytracingOutputResourceUAVDescriptorHeapIndex;

	// Shader tables
	static const wchar_t* c_hitGroupName;
	static const wchar_t* c_raygenShaderName;
	static const wchar_t* c_closestHitShaderName;
	static const wchar_t* c_missShaderName;
	ComPtr<ID3D12Resource> m_missShaderTable;
	ComPtr<ID3D12Resource> m_hitGroupShaderTable;
	ComPtr<ID3D12Resource> m_rayGenShaderTable;

	// Application state
	StepTimer m_timer;

	void RecreateD3D();
	void DoRaytracing();
	void CreateDeviceDependentResources();
	void CreateWindowSizeDependentResources();
	void ReleaseDeviceDependentResources();
	void ReleaseWindowSizeDependentResources();
	void CreateRaytracingInterfaces();
	void SerializeAndCreateRaytracingRootSignature(D3D12_ROOT_SIGNATURE_DESC& desc, ComPtr<ID3D12RootSignature>* rootSig);
	void CreateRootSignatures();
	void CreateLocalRootSignatureSubobjects(CD3DX12_STATE_OBJECT_DESC* raytracingPipeline);
	void CreateRaytracingPipelineStateObject();
	void CreateDescriptorHeap();
	void CreateRaytracingOutputResource();
	void BuildGeometry();
	void CreateConstantBuffers();
	void BuildAccelerationStructures();
	void BuildShaderTables();
	void UpdateForSizeChange(UINT clientWidth, UINT clientHeight);
	void CopyRaytracingOutputToBackbuffer();
	void CalculateFrameStats();
	UINT AllocateDescriptor(D3D12_CPU_DESCRIPTOR_HANDLE* cpuDescriptor, UINT descriptorIndexToUse = UINT_MAX);

	// #DXR Extra: Perspective Camera
	void updateCameraMatrices();
	SceneConstantBuffer _sceneCB[FrameCount];

	void initializeScene();

	UINT createBufferSRV(D3DBuffer *buffer, UINT numElements, UINT elementSize);
};
