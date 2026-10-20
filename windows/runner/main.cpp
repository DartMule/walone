#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  const bool autostart = std::find(command_line_arguments.begin(), command_line_arguments.end(), "--autostart") != command_line_arguments.end();

  // Повторный запуск возвращает существующее окно и не дублирует звук/глобальный ввод.
  HANDLE singleton = CreateMutexW(nullptr, FALSE, L"Local\\WaloneFlutter.Singleton");
  if (!singleton) { ::CoUninitialize(); return EXIT_FAILURE; }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    if (!autostart) {
      for (int attempt = 0; attempt < 20; ++attempt) {
        const HWND existing = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Walone");
        if (existing) {
          DWORD process = 0;
          GetWindowThreadProcessId(existing, &process);
          AllowSetForegroundWindow(process);
          PostMessage(existing, WM_APP + 46, 0, 0);
          break;
        }
        Sleep(50);
      }
    }
    CloseHandle(singleton);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, autostart);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(960, 860);
  if (!window.Create(L"Walone", origin, size)) {
    CloseHandle(singleton);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  CloseHandle(singleton);
  return EXIT_SUCCESS;
}
