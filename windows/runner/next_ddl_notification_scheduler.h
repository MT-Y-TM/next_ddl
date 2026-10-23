#ifndef RUNNER_NEXT_DDL_NOTIFICATION_SCHEDULER_H_
#define RUNNER_NEXT_DDL_NOTIFICATION_SCHEDULER_H_

#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>
#include <condition_variable>
#include <chrono>

inline constexpr UINT kNextDdlNotificationMessage = WM_APP + 76;

class NextDdlNotificationScheduler {
 public:
  NextDdlNotificationScheduler(HWND window, flutter::BinaryMessenger* messenger);
  ~NextDdlNotificationScheduler();
  std::optional<LRESULT> HandleMessage(UINT message, LPARAM lparam);

 private:
  struct Notification {
    int64_t id;
    std::string task_id;
    std::chrono::system_clock::time_point trigger_at;
    std::wstring title;
    std::wstring body;
  };

  void SyncTask(const flutter::EncodableMap& arguments);
  void RemoveTask(const std::string& task_id);
  void RemoveAll();
  int PendingCount();
  void SchedulerLoop();
  void ShowNotification(const Notification& notification);
  void DismissNotificationLocked();

  HWND window_;
  std::mutex mutex_;
  std::condition_variable condition_;
  std::vector<Notification> notifications_;
  std::thread scheduler_thread_;
  bool shutting_down_ = false;
  bool icon_added_ = false;
  int64_t active_id_ = 0;
  std::string active_task_id_;
  NOTIFYICONDATAW icon_{};
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif
