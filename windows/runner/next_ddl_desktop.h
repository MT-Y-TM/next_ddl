#ifndef RUNNER_NEXT_DDL_DESKTOP_H_
#define RUNNER_NEXT_DDL_DESKTOP_H_
#include <windows.h>
#include <shellapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <optional>
#include <string>

inline constexpr UINT kNextDdlExitMessage = WM_APP + 74;

class NextDdlDesktop {
 public:
  NextDdlDesktop(HWND window, flutter::BinaryMessenger* messenger);
  ~NextDdlDesktop();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
 private:
  void UpdateIcon();
  void RemoveIcon();
  void ShowMenu();
  void RestoreWindow();
  HWND window_;
  UINT taskbar_created_;
  NOTIFYICONDATAW icon_{};
  bool added_ = false;
  bool enabled_ = false;
  std::wstring title_, remaining_, open_label_, exit_label_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
#endif
