#ifndef RUNNER_NEXT_DDL_ALARM_SCHEDULER_H_
#define RUNNER_NEXT_DDL_ALARM_SCHEDULER_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class NextDdlAlarmScheduler {
 public:
  explicit NextDdlAlarmScheduler(flutter::BinaryMessenger* messenger);
  ~NextDdlAlarmScheduler();

 private:
  struct Trigger {
    std::string id;
    std::string task_id;
    std::string task_title;
    std::chrono::system_clock::time_point trigger_at;
    std::vector<std::wstring> audio_paths;
  };

  void SyncAlarms(const flutter::EncodableMap& arguments);
  void RemoveTask(const std::string& task_id);
  void RemoveAll();
  void StopCurrentAlarm();
  void StartSchedulerThread();
  void SchedulerLoop();
  void FireTrigger(const Trigger& trigger);
  void StartPlayback(const std::wstring& audio_path);
  void StopPlaybackLocked();

  std::mutex mutex_;
  std::condition_variable condition_;
  std::vector<Trigger> triggers_;
  std::thread scheduler_thread_;
  std::atomic<bool> shutting_down_ = false;
  std::wstring current_alias_;
};

#endif  // RUNNER_NEXT_DDL_ALARM_SCHEDULER_H_
