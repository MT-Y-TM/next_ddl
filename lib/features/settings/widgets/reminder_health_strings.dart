import 'package:flutter/widgets.dart';

import '../../../services/reminder_health_service.dart';

/// Local to this feature: intentionally independent of generated ARB files.
class ReminderHealthStrings {
  const ReminderHealthStrings(this.locale);
  final Locale locale;

  String _t(String zh, String en, String ja) => switch (locale.languageCode) {
    'zh' => zh,
    'ja' => ja,
    _ => en,
  };

  String get title => _t('提醒可靠性检查', 'Reminder health', 'リマインダーの状態');
  String get refresh => _t('刷新检查', 'Refresh', '再確認');
  String get notification => _t('通知权限', 'Notification permission', '通知の権限');
  String get exact => _t('精确闹钟权限', 'Exact alarm permission', '正確なアラームの権限');
  String get global => _t('全局闹钟开关', 'Global alarms', '全体のアラーム設定');
  String enabled(bool value) =>
      value ? _t('开启', 'On', 'オン') : _t('关闭', 'Off', 'オフ');
  String permission(ReminderPermission value) => switch (value) {
    ReminderPermission.allowed => _t('已允许', 'Allowed', '許可済み'),
    ReminderPermission.denied => _t('未允许', 'Not allowed', '未許可'),
    ReminderPermission.unknown => _t(
      '未知，需手动检查',
      'Unknown; check manually',
      '不明・手動で確認',
    ),
    ReminderPermission.notApplicable => _t('不适用', 'Not applicable', '対象外'),
  };
  String get planned => _t(
    '下次预期提醒（按任务数据推算，非系统登记确认）',
    'Next expected reminders (calculated, not confirmed system registrations)',
    '次回の予定（タスクから算出・システム登録の確認ではありません）',
  );
  String kind(ReminderKind value) => value == ReminderKind.notification
      ? _t('通知', 'Notification', '通知')
      : _t('响铃', 'Alarm', 'アラーム');
  String get finalDeadline => _t('最终截止', 'Final deadline', '最終期限');
  String get unnamedNode => _t('未命名节点', 'Unnamed milestone', '名前のない中間期限');
  String get noNotification => _t(
    '没有未来通知：任务可能已完成、通知未开启、未设提前量或提醒时间已过。',
    'No future notification: tasks may be completed, notifications disabled, offsets empty, or reminder times past.',
    '今後の通知はありません。完了済み、通知オフ、通知タイミング未設定、または予定時刻を過ぎています。',
  );
  String get noAlarm => _t(
    '没有未来响铃：检查全局/任务闹钟开关、音频列表、提前量及完成状态。',
    'No future alarm: check global/task switches, audio lists, offsets and completion status.',
    '今後のアラームはありません。全体・タスク設定、音声、通知タイミング、完了状態を確認してください。',
  );
  String get registration => _t('登记状态', 'Registration status', '登録状態');
  String pending(int? count) => count == null
      ? _t('通知待处理记录：未知', 'Pending notification records: unknown', '通知の保留記録：不明')
      : _t(
          '插件报告通知待处理记录：$count 条',
          'Plugin-reported pending notifications: $count',
          'プラグインの通知保留記録：$count 件',
        );
  String alarms(int? count) => count == null
      ? _t(
          '闹钟系统登记状态：未知',
          'System alarm registration: unknown',
          'システムのアラーム登録状態：不明',
        )
      : _t(
          '原生查询闹钟登记：$count 条',
          'Native-reported alarm registrations: $count',
          'ネイティブのアラーム登録記録：$count 件',
        );
  String get registrationHint => _t(
    '待处理记录不证明系统一定送达，通知记录不含原生闹钟。',
    'Pending records do not guarantee delivery. Notification records exclude native alarms.',
    '保留記録は配信を保証しません。通知記録にはネイティブアラームは含まれません。',
  );
  String get audio => _t(
    '音频检查（全局与未完成任务的覆盖列表）',
    'Audio checks (global and active task overrides)',
    '音声の確認（全体と未完了タスクの個別設定）',
  );
  String get noAudio => _t(
    '未配置音频，响铃无法使用。',
    'No audio configured; alarms cannot play.',
    '音声が未設定のため、アラームを再生できません。',
  );
  String audioState(ReminderAudioState state) => switch (state) {
    ReminderAudioState.readable => _t(
      '文件可读；能否解码/播放未知',
      'File readable; decoding/playback unknown',
      '読み取り可能・デコードや再生は未確認',
    ),
    ReminderAudioState.unavailable => _t(
      '文件为空、缺失或不可读',
      'File empty, missing or unreadable',
      'ファイルが空、存在しない、または読み取り不可',
    ),
    ReminderAudioState.unknown => _t(
      '可用性未知，需实际测试',
      'Availability unknown; test manually',
      '利用可否は不明・実際のテストが必要',
    ),
  };
  String get testNotification => _t('测试通知', 'Test notification', '通知をテスト');
  String get testBody => _t(
    '这是一条测试通知，不改变任务计划。',
    'This test does not change task schedules.',
    'このテストはタスクの予定を変更しません。',
  );
  String get testAlarm => _t('测试响铃', 'Test alarm', 'アラームをテスト');
  String get stop => _t('停止当前响铃', 'Stop current alarm', '現在のアラームを停止');
  String get testHint => _t(
    '测试使用首个已配置音频（优先全局）。响铃最多 10 秒；停止也会停止正在响的真实闹钟。请亲自确认是否听到/看到提醒。',
    'Tests use the first configured audio (global preferred), for at most 10 seconds. Stop also stops a real alarm currently ringing. Confirm delivery by listening/looking.',
    '最初の設定済み音声を使用（全体設定を優先）、最大10秒です。停止は再生中の実際のアラームも止めます。音や表示を直接確認してください。',
  );
  String get request =>
      _t('请求通知权限', 'Request notification permission', '通知の権限をリクエスト');
  String get notificationSettings =>
      _t('系统通知设置', 'System notification settings', 'システムの通知設定');
  String get exactSettings =>
      _t('精确闹钟设置', 'Exact alarm settings', '正確なアラームの設定');
  String get androidHint => _t(
    'Android：通知采用非精确定时，省电/勿扰模式可能延迟或静音。MIUI/HyperOS 的自启动、后台运行和电池限制需手动检查；本应用无法验证这些设置。权限恢复后刷新不代表旧计划已重新登记。',
    'Android notifications use inexact timing. Battery saving / Do Not Disturb may delay or silence them. Manually check MIUI/HyperOS autostart, background access and battery restrictions; these cannot be verified here. Refreshing permissions does not re-register old schedules.',
    'Androidの通知時刻は非正確です。省電力・サイレントモードで遅延や消音の可能性があります。MIUI/HyperOSの自動起動、バックグラウンド実行、電池制限は手動確認が必要です。権限の再確認は予定の再登録を意味しません。',
  );
  String get windowsHint => _t(
    'Windows：响铃依赖应用进程，退出后不会继续响铃。通知权限、勿扰和音量需在系统设置中手动检查。',
    'Windows alarms require the app process and stop working after exit. Check notification permissions, Do Not Disturb and volume in system settings.',
    'Windowsのアラームにはアプリの実行が必要です。終了後は鳴りません。通知権限、応答不可モード、音量はシステム設定で確認してください。',
  );
  String get unsupportedPlatform => _t(
    '此平台尚无完整提醒诊断支持。',
    'Full reminder diagnostics are unavailable on this platform.',
    'このプラットフォームの診断機能は未対応です。',
  );
  String get failedCheck => _t(
    '检查失败，请刷新重试。',
    'Check failed; refresh to retry.',
    '確認に失敗しました。再確認してください。',
  );
  String result(ReminderActionResult value) => switch (value) {
    ReminderActionResult.requested => _t(
      '请求已发送；不代表提醒已送达或声音已播放，请实际确认。',
      'Request sent; delivery/playback is not confirmed. Verify manually.',
      'リクエストを送信しました。配信・再生は未確認です。実際に確認してください。',
    ),
    ReminderActionResult.unsupported => _t(
      '当前平台或版本不支持此操作。请手动打开系统应用设置；测试响铃需要原生接口接入。',
      'This platform/build does not support this action. Open system app settings manually; test alarms need the native bridge.',
      'この環境・バージョンは未対応です。システム設定は手動で開いてください。テスト再生にはネイティブ対応が必要です。',
    ),
    ReminderActionResult.failed => _t(
      '操作失败，请检查权限、音频和平台支持后重试。',
      'Action failed; check permissions, audio and platform support, then retry.',
      '操作に失敗しました。権限、音声、プラットフォーム対応を確認してください。',
    ),
    ReminderActionResult.noAudio => noAudio,
  };
}
