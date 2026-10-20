#include "next_ddl_desktop.h"
#include "resource.h"

namespace {
constexpr UINT kTrayMessage = WM_APP + 73;
constexpr UINT kOpen = 1, kStop = 2, kExit = 3;
using flutter::EncodableMap;
using flutter::EncodableValue;
std::wstring ReadText(const EncodableMap& args, const char* key) {
  const auto it = args.find(EncodableValue(key));
  if (it == args.end()) return {};
  const auto* value = std::get_if<std::string>(&it->second);
  if (!value || value->empty()) return {};
  const auto count = MultiByteToWideChar(CP_UTF8, 0, value->data(),
      static_cast<int>(value->size()), nullptr, 0);
  std::wstring result(count, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value->data(), static_cast<int>(value->size()),
      result.data(), count);
  return result;
}
}
NextDdlDesktop::NextDdlDesktop(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window), taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")) {
  icon_.cbSize = sizeof(icon_);
  icon_.hWnd = window_;
  icon_.uID = 73;
  icon_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  icon_.uCallbackMessage = kTrayMessage;
  icon_.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON));
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "next_ddl/desktop", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "syncSummary") { result->NotImplemented(); return; }
    const auto* args = call.arguments() ? std::get_if<EncodableMap>(call.arguments()) : nullptr;
    if (!args) { result->Error("invalid_arguments", "Expected desktop summary"); return; }
    const auto enabled_it = args->find(EncodableValue("enabled"));
    const auto* enabled_value = enabled_it == args->end()
        ? nullptr
        : std::get_if<bool>(&enabled_it->second);
    enabled_ = enabled_value != nullptr && *enabled_value;
    title_ = ReadText(*args, "title");
    remaining_ = ReadText(*args, "remaining");
    open_label_ = ReadText(*args, "openLabel");
    stop_label_ = ReadText(*args, "stopLabel");
    exit_label_ = ReadText(*args, "exitLabel");
    if (!enabled_) {
      title_ = ReadText(*args, "appLabel");
      remaining_.clear();
    }
    UpdateIcon();
    if (!added_) { result->Error("tray_unavailable", "Windows notification area unavailable"); return; }
    result->Success();
  });
  title_ = L"Next DDL";
  open_label_ = L"Open Next DDL";
  stop_label_ = L"Stop current alarm";
  exit_label_ = L"Exit Next DDL";
  UpdateIcon();
}
NextDdlDesktop::~NextDdlDesktop() {
  channel_->SetMethodCallHandler(nullptr);
  if (added_) Shell_NotifyIconW(NIM_DELETE, &icon_);
}
void NextDdlDesktop::UpdateIcon() {
  auto tooltip = title_ + (remaining_.empty() ? L"" : L"\n" + remaining_);
  if (tooltip.size() > 127) tooltip.resize(127);
  if (!tooltip.empty() && tooltip.back() >= 0xD800 && tooltip.back() <= 0xDBFF) tooltip.pop_back();
  wcscpy_s(icon_.szTip, tooltip.c_str());
  if (added_ && Shell_NotifyIconW(NIM_MODIFY, &icon_)) return;
  added_ = Shell_NotifyIconW(NIM_ADD, &icon_) != FALSE;
  if (added_) {
    icon_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &icon_);
  }
}
void NextDdlDesktop::RemoveIcon() {
  if (!added_) return;
  Shell_NotifyIconW(NIM_DELETE, &icon_);
  added_ = false;
}
void NextDdlDesktop::RestoreWindow() {
  ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window_);
}
void NextDdlDesktop::ShowMenu() {
  HMENU menu = CreatePopupMenu();
  // Escape task-name ampersands so Windows does not turn them into mnemonics.
  std::wstring title;
  for (const auto c : title_) { title += c; if (c == L'&') title += c; }
  AppendMenuW(menu, MF_STRING | MF_DISABLED, 0, title.c_str());
  if (!remaining_.empty()) AppendMenuW(menu, MF_STRING | MF_DISABLED, 0, remaining_.c_str());
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kOpen, open_label_.c_str());
  AppendMenuW(menu, MF_STRING, kStop, stop_label_.c_str());
  AppendMenuW(menu, MF_STRING, kExit, exit_label_.c_str());
  POINT point{};
  GetCursorPos(&point);
  SetForegroundWindow(window_);
  const auto action = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
      point.x, point.y, 0, window_, nullptr);
  DestroyMenu(menu);
  PostMessageW(window_, WM_NULL, 0, 0);
  if (action == kOpen) RestoreWindow();
  if (action == kStop) PostMessageW(window_, kNextDdlStopAlarmMessage, 0, 0);
  if (action == kExit) PostMessageW(window_, kNextDdlExitMessage, 0, 0);
}
std::optional<LRESULT> NextDdlDesktop::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == taskbar_created_) {
    added_ = false;
    if (!title_.empty()) UpdateIcon();
    return 0;
  }
  if (message != kTrayMessage) return std::nullopt;
  switch (LOWORD(lparam)) {
    case NIN_SELECT:
    case NIN_KEYSELECT:
    case WM_LBUTTONDBLCLK: RestoreWindow(); break;
    case WM_RBUTTONUP:
    case WM_CONTEXTMENU: ShowMenu(); break;
  }
  return 0;
}
