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

#include "stdafx.h"
#include "DXSample.h"

using namespace Microsoft::WRL;
using namespace std;

DXSample::DXSample(UINT width, UINT height, std::wstring name) :
	m_width(width),
	m_height(height),
	m_windowBounds{ 0,0,0,0 },
	m_title(name),
	m_aspectRatio(0.0f),
	m_enableUI(true),
	m_adapterIDoverride(UINT_MAX)
{
	WCHAR assetsPath[512];
	GetAssetsPath(assetsPath, _countof(assetsPath));
	m_assetsPath = assetsPath;

	UpdateForSizeChange(width, height);
}

DXSample::~DXSample()
{
}

void DXSample::UpdateForSizeChange(UINT clientWidth, UINT clientHeight)
{
	m_width = clientWidth;
	m_height = clientHeight;
	m_aspectRatio = static_cast<float>(clientWidth) / static_cast<float>(clientHeight);
}

// Helper function for resolving the full path of assets.
std::wstring DXSample::GetAssetFullPath(LPCWSTR assetName)
{
	return m_assetsPath + assetName;
}


// Helper function for acquiring the first available hardware adapter that supports Direct3D 12.
// If no such adapter can be found, *ppAdapter will be set to nullptr.
_Use_decl_annotations_
void DXSample::GetHardwareAdapter(IDXGIFactory2* pFactory, IDXGIAdapter1** ppAdapter)
{
	ComPtr<IDXGIAdapter1> adapter;
	*ppAdapter = nullptr;

	for (UINT adapterIndex = 0; DXGI_ERROR_NOT_FOUND != pFactory->EnumAdapters1(adapterIndex, &adapter); ++adapterIndex)
	{
		DXGI_ADAPTER_DESC1 desc;
		adapter->GetDesc1(&desc);

		if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
		{
			// Don't select the Basic Render Driver adapter.
			// If you want a software adapter, pass in "/warp" on the command line.
			continue;
		}

		// Check to see if the adapter supports Direct3D 12, but don't create the
		// actual device yet.
		if (SUCCEEDED(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0, _uuidof(ID3D12Device), nullptr)))
		{
			break;
		}
	}

	*ppAdapter = adapter.Detach();
}

// Helper function for setting the window's title text.
void DXSample::SetCustomWindowText(LPCWSTR text)
{
	std::wstring windowText = m_title + L": " + text;
	SetWindowText(Win32Application::GetHwnd(), windowText.c_str());
}

// Helper function for parsing any supplied command line args.
_Use_decl_annotations_
void DXSample::ParseCommandLineArgs(WCHAR* argv[], int argc)
{
	for (int i = 1; i < argc; ++i)
	{
		// -disableUI
		if (_wcsnicmp(argv[i], L"-disableUI", wcslen(argv[i])) == 0 ||
			_wcsnicmp(argv[i], L"/disableUI", wcslen(argv[i])) == 0)
		{
			m_enableUI = false;
		}
		// -forceAdapter [id]
		else if (_wcsnicmp(argv[i], L"-forceAdapter", wcslen(argv[i])) == 0 ||
			_wcsnicmp(argv[i], L"/forceAdapter", wcslen(argv[i])) == 0)
		{
			ThrowIfFalse(i + 1 < argc, L"Incorrect argument format passed in.");

			m_adapterIDoverride = _wtoi(argv[i + 1]);
			i++;
		}
	}

}

void DXSample::SetWindowBounds(int left, int top, int right, int bottom)
{
	m_windowBounds.left = static_cast<LONG>(left);
	m_windowBounds.top = static_cast<LONG>(top);
	m_windowBounds.right = static_cast<LONG>(right);
	m_windowBounds.bottom = static_cast<LONG>(bottom);
}