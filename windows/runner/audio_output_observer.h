#ifndef WALONE_AUDIO_OUTPUT_OBSERVER_H_
#define WALONE_AUDIO_OUTPUT_OBSERVER_H_

#include <windows.h>
#include <mmdeviceapi.h>
#include <atomic>
#include <string>

constexpr UINT kWaloneOutputChanged = WM_APP + 42;

// Уведомления CoreAudio приходят с другого потока; UI получает только сообщение.
class AudioOutputObserver final : public IMMNotificationClient {
 public:
  explicit AudioOutputObserver(HWND window) : window_(window) {
    if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
        IID_PPV_ARGS(&enumerator_)))) return;
    IMMDevice* device = nullptr;
    if (SUCCEEDED(enumerator_->GetDefaultAudioEndpoint(eRender, eConsole, &device))) {
      LPWSTR id = nullptr;
      if (SUCCEEDED(device->GetId(&id))) { default_id_ = id; CoTaskMemFree(id); }
      device->Release();
    }
    enumerator_->RegisterEndpointNotificationCallback(this);
  }
  void Stop() {
    if (enumerator_) {
      enumerator_->UnregisterEndpointNotificationCallback(this);
      enumerator_->Release();
      enumerator_ = nullptr;
    }
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) override {
    if (!object) return E_POINTER;
    *object = nullptr;
    if (iid == __uuidof(IUnknown) || iid == __uuidof(IMMNotificationClient)) {
      *object = static_cast<IMMNotificationClient*>(this); AddRef(); return S_OK;
    }
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }
  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG remaining = --references_;
    if (!remaining) delete this;
    return remaining;
  }
  HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow flow, ERole role, LPCWSTR) override {
    if (flow == eRender && role == eConsole) PostMessage(window_, kWaloneOutputChanged, 0, 0);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR id, DWORD state) override {
    if (id && default_id_ == id && state != DEVICE_STATE_ACTIVE) PostMessage(window_, kWaloneOutputChanged, 0, 0);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR id) override {
    if (id && default_id_ == id) PostMessage(window_, kWaloneOutputChanged, 0, 0);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR, const PROPERTYKEY) override { return S_OK; }
 private:
  ~AudioOutputObserver() = default;
  std::atomic<ULONG> references_{1};
  HWND window_;
  IMMDeviceEnumerator* enumerator_ = nullptr;
  std::wstring default_id_;
};

#endif
