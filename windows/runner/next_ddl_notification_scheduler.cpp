#include "next_ddl_notification_scheduler.h"

#include "resource.h"
#include <algorithm>

namespace {
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::wstring ReadText(const EncodableMap& args, const char* key) {
  const auto it = args.find(EncodableValue(key));
  if (it == args.end()) return {};
  const auto* value = std::get_if<std::string>(&it->second);
  if (!value || value->empty()) return {};
  const auto length = MultiByteToWideChar(CP_UTF8, 0, value->data(),
      static_cast<int>(value->size()), nullptr, 0);
  std::wstring result(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value->data(), static_cast<int>(value->size()),
      result.data(), length);
  return result;
}

std::string ReadString(const EncodableMap& args, const char* key) {
  const auto it = args.find(EncodableValue(key));
  if (it == args.end()) return {};
  const auto* value = std::get_if<std::string>(&it->second);
  return value == nullptr ? std::string() : *value;
}

std::optional<int64_t> ReadInt64(const EncodableMap& args, const char* key) {
  const auto it = args.find(EncodableValue(key));
  if (it == args.end()) return std::nullopt;
  if (const auto* value = std::get_if<int64_t>(&it->second)) return *value;
  if (const auto* value = std::get_if<int32_t>(&it->second)) return *value;
  return std::nullopt;
}

std::wstring ClipText(const std::wstring& value, size_t capacity) {
  if (capacity == 0 || value.size() < capacity) return value;
  std::wstring clipped = value.substr(0, capacity - 1);
  if (!clipped.empty() && clipped.back() >= 0xD800 && clipped.back() <= 0xDBFF) {
    clipped.pop_back();
  }
  return clipped;
}
}

NextDdlNotificationScheduler::NextDdlNotificationScheduler(
    HWND window, flutter::BinaryMessenger* messenger)
    : window_(window) {
  icon_.cbSize = sizeof(icon_);
  icon_.hWnd = window_;
  icon_.uID = 76;
  icon_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  icon_.uCallbackMessage = kNextDdlNotificationMessage;
  icon_.hIcon = LoadIconW(GetModuleHandleW(nullptr),
                          MAKEINTRESOURCEW(IDI_APP_ICON));
  wcscpy_s(icon_.szTip, L"Next DDL notifications");
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "next_ddl/windows_notifications",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto* arguments = call.arguments()
        ? std::get_if<EncodableMap>(call.arguments())
        : nullptr;
    if (call.method_name() == "syncTask" && arguments != nullptr) {
      SyncTask(*arguments);
      result->Success();
      return;
    }
    if (call.method_name() == "removeTask" && arguments != nullptr) {
      RemoveTask(ReadString(*arguments, "taskId"));
      result->Success();
      return;
    }
    if (call.method_name() == "removeAll") {
      RemoveAll();
      result->Success();
      return;
    }
    if (call.method_name() == "pendingCount") {
      result->Success(EncodableValue(static_cast<int64_t>(PendingCount())));
      return;
    }
    result->NotImplemented();
  });
  scheduler_thread_ = std::thread([this] { SchedulerLoop(); });
}

NextDdlNotificationScheduler::~NextDdlNotificationScheduler() {
  channel_->SetMethodCallHandler(nullptr);
  {
    std::lock_guard<std::mutex> lock(mutex_);
    shutting_down_ = true;
    DismissNotificationLocked();
  }
  condition_.notify_all();
  if (scheduler_thread_.joinable()) scheduler_thread_.join();
}

void NextDdlNotificationScheduler::SyncTask(const EncodableMap& arguments) {
  const auto task_id = ReadString(arguments, "taskId");
  const auto notifications_it = arguments.find(EncodableValue("notifications"));
  const auto* notifications = notifications_it == arguments.end()
      ? nullptr
      : std::get_if<EncodableList>(&notifications_it->second);
  if (task_id.empty() || notifications == nullptr) return;

  std::vector<Notification> next;
  for (const auto& item : *notifications) {
    const auto* notification = std::get_if<EncodableMap>(&item);
    if (notification == nullptr) continue;
    const auto id = ReadInt64(*notification, "id");
    const auto trigger = ReadInt64(*notification, "triggerAtUtcMs");
    if (!id.has_value() || !trigger.has_value()) continue;
    next.push_back(Notification{
        *id,
        task_id,
        std::chrono::system_clock::time_point(std::chrono::milliseconds(*trigger)),
        ReadText(*notification, "title"),
        ReadText(*notification, "body"),
    });
  }
  {
    std::lock_guard<std::mutex> lock(mutex_);
    notifications_.erase(
        std::remove_if(notifications_.begin(), notifications_.end(),
                       [&](const auto& item) { return item.task_id == task_id; }),
        notifications_.end());
    notifications_.insert(notifications_.end(), next.begin(), next.end());
    std::sort(notifications_.begin(), notifications_.end(),
              [](const auto& left, const auto& right) {
                return left.trigger_at < right.trigger_at;
              });
  }
  condition_.notify_all();
}

void NextDdlNotificationScheduler::RemoveTask(const std::string& task_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  notifications_.erase(
      std::remove_if(notifications_.begin(), notifications_.end(),
                     [&](const auto& item) { return item.task_id == task_id; }),
      notifications_.end());
  if (active_task_id_ == task_id) DismissNotificationLocked();
  condition_.notify_all();
}

void NextDdlNotificationScheduler::RemoveAll() {
  std::lock_guard<std::mutex> lock(mutex_);
  notifications_.clear();
  DismissNotificationLocked();
  condition_.notify_all();
}

int NextDdlNotificationScheduler::PendingCount() {
  std::lock_guard<std::mutex> lock(mutex_);
  return static_cast<int>(notifications_.size());
}

void NextDdlNotificationScheduler::SchedulerLoop() {
  std::unique_lock<std::mutex> lock(mutex_);
  while (!shutting_down_) {
    const auto now = std::chrono::system_clock::now();
    if (!notifications_.empty() && notifications_.front().trigger_at <= now) {
      const auto notification = notifications_.front();
      notifications_.erase(notifications_.begin());
      lock.unlock();
      ShowNotification(notification);
      lock.lock();
      continue;
    }
    if (notifications_.empty()) {
      condition_.wait(lock);
    } else {
      condition_.wait_until(lock, notifications_.front().trigger_at);
    }
  }
}

void NextDdlNotificationScheduler::ShowNotification(
    const Notification& notification) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (shutting_down_) return;
  DismissNotificationLocked();
  icon_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_INFO;
  const auto title = ClipText(notification.title, ARRAYSIZE(icon_.szInfoTitle));
  const auto body = ClipText(notification.body, ARRAYSIZE(icon_.szInfo));
  wcscpy_s(icon_.szInfoTitle, title.c_str());
  wcscpy_s(icon_.szInfo, body.c_str());
  icon_.dwInfoFlags = NIIF_INFO;
  icon_.uTimeout = 10000;
  icon_added_ = Shell_NotifyIconW(NIM_ADD, &icon_) != FALSE;
  if (!icon_added_) return;
  active_id_ = notification.id;
  active_task_id_ = notification.task_id;
}

void NextDdlNotificationScheduler::DismissNotificationLocked() {
  if (icon_added_) Shell_NotifyIconW(NIM_DELETE, &icon_);
  icon_added_ = false;
  active_id_ = 0;
  active_task_id_.clear();
}

std::optional<LRESULT> NextDdlNotificationScheduler::HandleMessage(
    UINT message, LPARAM lparam) {
  if (message != kNextDdlNotificationMessage) return std::nullopt;
  const auto event = LOWORD(lparam);
  if (event == NIN_BALLOONUSERCLICK || event == NIN_SELECT ||
      event == NIN_KEYSELECT) {
    std::string task_id;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      task_id = active_task_id_;
    }
    if (!task_id.empty()) {
      channel_->InvokeMethod("notificationTapped", EncodableValue(task_id));
    }
  }
  if (event == NIN_BALLOONHIDE || event == NIN_BALLOONTIMEOUT) {
    std::lock_guard<std::mutex> lock(mutex_);
    DismissNotificationLocked();
  }
  return 0;
}
