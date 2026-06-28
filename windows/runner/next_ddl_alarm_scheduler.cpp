#include "next_ddl_alarm_scheduler.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <mmsystem.h>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <ctime>
#include <iomanip>
#include <memory>
#include <optional>
#include <random>
#include <sstream>

#include "utils.h"

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr auto kMaxRingDuration = std::chrono::minutes(5);

std::string GetString(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return "";
  }
  if (const auto value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return "";
}

std::wstring Utf16FromUtf8String(const std::string& utf8_string) {
  if (utf8_string.empty()) {
    return std::wstring();
  }
  const int target_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
      static_cast<int>(utf8_string.length()), nullptr, 0);
  if (target_length == 0) {
    return std::wstring();
  }
  std::wstring utf16_string;
  utf16_string.resize(target_length);
  const int converted_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
      static_cast<int>(utf8_string.length()), utf16_string.data(),
      target_length);
  if (converted_length == 0) {
    return std::wstring();
  }
  return utf16_string;
}

bool GetBool(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return false;
  }
  if (const auto value = std::get_if<bool>(&it->second)) {
    return *value;
  }
  return false;
}

std::vector<int64_t> GetIntList(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return {};
  }
  const auto* list = std::get_if<EncodableList>(&it->second);
  if (!list) {
    return {};
  }
  std::vector<int64_t> result;
  for (const auto& item : *list) {
    if (const auto value = std::get_if<int32_t>(&item)) {
      result.push_back(*value);
    } else if (const auto value64 = std::get_if<int64_t>(&item)) {
      result.push_back(*value64);
    }
  }
  return result;
}

std::vector<std::wstring> ParseAudioPaths(const EncodableValue* value) {
  const auto* list = value == nullptr ? nullptr : std::get_if<EncodableList>(value);
  if (!list) {
    return {};
  }
  std::vector<std::wstring> result;
  for (const auto& item : *list) {
    const auto* map = std::get_if<EncodableMap>(&item);
    if (!map) {
      continue;
    }
    const auto uri = GetString(*map, "uri");
    if (uri.empty()) {
      continue;
    }
    result.push_back(Utf16FromUtf8String(uri));
  }
  return result;
}

std::optional<std::chrono::system_clock::time_point> ParseIsoUtc(
    const std::string& value) {
  if (value.size() < 19) {
    return std::nullopt;
  }
  std::tm tm = {};
  std::istringstream input(value.substr(0, 19));
  input >> std::get_time(&tm, "%Y-%m-%dT%H:%M:%S");
  if (input.fail()) {
    return std::nullopt;
  }
  tm.tm_isdst = 0;
  const auto seconds = _mkgmtime(&tm);
  if (seconds == -1) {
    return std::nullopt;
  }
  auto result = std::chrono::system_clock::from_time_t(seconds);
  const auto dot = value.find('.');
  if (dot != std::string::npos) {
    int millis = 0;
    int scale = 100;
    for (size_t i = dot + 1; i < value.size() && std::isdigit(value[i]) && scale > 0;
         ++i) {
      millis += (value[i] - '0') * scale;
      scale /= 10;
    }
    result += std::chrono::milliseconds(millis);
  }
  return result;
}

std::vector<std::chrono::system_clock::time_point> CollectDeadlinePoints(
    const EncodableMap& task) {
  std::vector<std::chrono::system_clock::time_point> result;
  if (const auto final_due = ParseIsoUtc(GetString(task, "finalDueAtUtc"))) {
    result.push_back(*final_due);
  }
  const auto milestones_it = task.find(EncodableValue("milestones"));
  if (milestones_it == task.end()) {
    return result;
  }
  const auto* milestones = std::get_if<EncodableList>(&milestones_it->second);
  if (!milestones) {
    return result;
  }
  for (const auto& item : *milestones) {
    const auto* milestone = std::get_if<EncodableMap>(&item);
    if (!milestone) {
      continue;
    }
    if (const auto due = ParseIsoUtc(GetString(*milestone, "dueAtUtc"))) {
      result.push_back(*due);
    }
  }
  return result;
}

std::wstring QuoteMciPath(const std::wstring& path) {
  std::wstring escaped;
  escaped.reserve(path.size());
  for (const auto ch : path) {
    escaped.push_back(ch == L'"' ? L'\'' : ch);
  }
  return L"\"" + escaped + L"\"";
}

}  // namespace

NextDdlAlarmScheduler::NextDdlAlarmScheduler(
    flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "next_ddl/alarm",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const auto method = call.method_name();
        if (method == "canScheduleExactAlarms") {
          result->Success(EncodableValue(true));
          return;
        }
        if (method == "openExactAlarmSettings") {
          result->Success();
          return;
        }
        if (method == "syncAlarms") {
          const auto* arguments = std::get_if<EncodableMap>(call.arguments());
          if (arguments) {
            SyncAlarms(*arguments);
          }
          result->Success();
          return;
        }
        if (method == "removeTaskAlarms") {
          const auto* arguments = std::get_if<EncodableMap>(call.arguments());
          if (arguments) {
            RemoveTask(GetString(*arguments, "taskId"));
          }
          result->Success();
          return;
        }
        if (method == "removeAllAlarms") {
          RemoveAll();
          result->Success();
          return;
        }
        if (method == "stopCurrentAlarm") {
          StopCurrentAlarm();
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  StartSchedulerThread();
}

NextDdlAlarmScheduler::~NextDdlAlarmScheduler() {
  shutting_down_ = true;
  condition_.notify_all();
  if (scheduler_thread_.joinable()) {
    scheduler_thread_.join();
  }
  std::lock_guard<std::mutex> lock(mutex_);
  StopPlaybackLocked();
}

void NextDdlAlarmScheduler::SyncAlarms(const EncodableMap& arguments) {
  std::vector<Trigger> next_triggers;
  const auto settings_it = arguments.find(EncodableValue("settings"));
  const auto tasks_it = arguments.find(EncodableValue("tasks"));
  const auto* settings = settings_it == arguments.end()
                             ? nullptr
                             : std::get_if<EncodableMap>(&settings_it->second);
  const auto* tasks = tasks_it == arguments.end()
                          ? nullptr
                          : std::get_if<EncodableList>(&tasks_it->second);
  if (!settings || !tasks || !GetBool(*settings, "enabled")) {
    RemoveAll();
    return;
  }
  const auto global_it = settings->find(EncodableValue("globalAudioItems"));
  const auto global_audio = ParseAudioPaths(
      global_it == settings->end() ? nullptr : &global_it->second);
  const auto now = std::chrono::system_clock::now();
  for (const auto& item : *tasks) {
    const auto* task = std::get_if<EncodableMap>(&item);
    if (!task || !GetBool(*task, "alarmEnabled")) {
      continue;
    }
    const auto task_id = GetString(*task, "id");
    if (task_id.empty()) {
      continue;
    }
    auto task_title = GetString(*task, "title");
    if (task_title.empty()) {
      task_title = "Next DDL";
    }
    const auto offsets = GetIntList(*task, "reminderOffsetsSeconds");
    if (offsets.empty()) {
      continue;
    }
    const auto override_it = task->find(EncodableValue("alarmAudioItemsOverride"));
    auto audio = ParseAudioPaths(
        override_it == task->end() ? nullptr : &override_it->second);
    if (audio.empty()) {
      audio = global_audio;
    }
    if (audio.empty()) {
      continue;
    }
    for (const auto target : CollectDeadlinePoints(*task)) {
      const auto target_ms =
          std::chrono::duration_cast<std::chrono::milliseconds>(
              target.time_since_epoch())
              .count();
      for (const auto offset_seconds : offsets) {
        const auto trigger_at =
            target - std::chrono::seconds(offset_seconds);
        if (trigger_at <= now) {
          continue;
        }
        next_triggers.push_back(Trigger{
            task_id + ":" + std::to_string(target_ms) + ":" +
                std::to_string(offset_seconds),
            task_id,
            task_title,
            trigger_at,
            audio,
        });
      }
    }
  }
  {
    std::lock_guard<std::mutex> lock(mutex_);
    triggers_ = std::move(next_triggers);
    std::sort(triggers_.begin(), triggers_.end(), [](const auto& a, const auto& b) {
      return a.trigger_at < b.trigger_at;
    });
  }
  condition_.notify_all();
}

void NextDdlAlarmScheduler::RemoveTask(const std::string& task_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  triggers_.erase(std::remove_if(triggers_.begin(), triggers_.end(),
                                 [&](const auto& trigger) {
                                   return trigger.task_id == task_id;
                                 }),
                  triggers_.end());
  condition_.notify_all();
}

void NextDdlAlarmScheduler::RemoveAll() {
  std::lock_guard<std::mutex> lock(mutex_);
  triggers_.clear();
  StopPlaybackLocked();
  condition_.notify_all();
}

void NextDdlAlarmScheduler::StopCurrentAlarm() {
  std::lock_guard<std::mutex> lock(mutex_);
  StopPlaybackLocked();
}

void NextDdlAlarmScheduler::StartSchedulerThread() {
  scheduler_thread_ = std::thread([this] { SchedulerLoop(); });
}

void NextDdlAlarmScheduler::SchedulerLoop() {
  std::unique_lock<std::mutex> lock(mutex_);
  while (!shutting_down_) {
    if (triggers_.empty()) {
      condition_.wait(lock, [this] {
        return shutting_down_ || !triggers_.empty();
      });
      continue;
    }
    const auto next_time = triggers_.front().trigger_at;
    if (condition_.wait_until(lock, next_time, [this, next_time] {
          return shutting_down_ || triggers_.empty() ||
                 triggers_.front().trigger_at != next_time;
        })) {
      continue;
    }
    if (shutting_down_ || triggers_.empty()) {
      continue;
    }
    const auto trigger = triggers_.front();
    triggers_.erase(triggers_.begin());
    lock.unlock();
    FireTrigger(trigger);
    lock.lock();
  }
}

void NextDdlAlarmScheduler::FireTrigger(const Trigger& trigger) {
  if (trigger.audio_paths.empty()) {
    return;
  }
  static thread_local std::mt19937 generator{std::random_device{}()};
  std::uniform_int_distribution<size_t> distribution(
      0, trigger.audio_paths.size() - 1);
  StartPlayback(trigger.audio_paths[distribution(generator)]);
}

void NextDdlAlarmScheduler::StartPlayback(const std::wstring& audio_path) {
  std::lock_guard<std::mutex> lock(mutex_);
  StopPlaybackLocked();
  current_alias_ = L"nextddl_alarm_" +
                   std::to_wstring(GetTickCount64());
  const auto open_command = L"open " + QuoteMciPath(audio_path) +
                            L" alias " + current_alias_;
  if (mciSendStringW(open_command.c_str(), nullptr, 0, nullptr) != 0) {
    current_alias_.clear();
    return;
  }

  wchar_t status_buffer[64] = {};
  int duration_ms = 0;
  const auto status_command = L"status " + current_alias_ + L" length";
  if (mciSendStringW(status_command.c_str(), status_buffer, 64, nullptr) == 0) {
    duration_ms = _wtoi(status_buffer);
  }
  const auto max_start = duration_ms - 30'000;
  if (max_start > 0) {
    static thread_local std::mt19937 generator{std::random_device{}()};
    std::uniform_int_distribution<int> distribution(0, max_start);
    const auto seek_command =
        L"seek " + current_alias_ + L" to " +
        std::to_wstring(distribution(generator));
    mciSendStringW(seek_command.c_str(), nullptr, 0, nullptr);
  }
  const auto play_command = L"play " + current_alias_ + L" repeat";
  mciSendStringW(play_command.c_str(), nullptr, 0, nullptr);
  std::thread([this, alias = current_alias_] {
    std::this_thread::sleep_for(kMaxRingDuration);
    std::lock_guard<std::mutex> timer_lock(mutex_);
    if (current_alias_ == alias) {
      StopPlaybackLocked();
    }
  }).detach();
}

void NextDdlAlarmScheduler::StopPlaybackLocked() {
  if (current_alias_.empty()) {
    return;
  }
  const auto stop_command = L"stop " + current_alias_;
  const auto close_command = L"close " + current_alias_;
  mciSendStringW(stop_command.c_str(), nullptr, 0, nullptr);
  mciSendStringW(close_command.c_str(), nullptr, 0, nullptr);
  current_alias_.clear();
}
