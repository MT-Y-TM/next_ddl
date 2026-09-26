import 'package:flutter/widgets.dart';

/// Kept separate from ARB to allow independent integration.
class TaskPlanningStrings {
  TaskPlanningStrings(Locale locale) : language = locale.languageCode;
  final String language;
  String text(String key) {
    final values = _values[key]!;
    return values[language == 'zh'
        ? 0
        : language == 'ja'
        ? 2
        : 1];
  }

  static const _values = <String, List<String>>{
    'title': ['重复任务与模板', 'Recurrence & templates', '繰り返しとテンプレート'],
    'templates': ['模板', 'Templates', 'テンプレート'],
    'series': ['重复系列', 'Recurring series', '繰り返しシリーズ'],
    'new': ['新建模板', 'New template', 'テンプレートを作成'],
    'fromTask': ['从任务保存模板', 'Save task as template', 'タスクをテンプレートに保存'],
    'empty': ['暂无规划', 'No plans yet', '計画はありません'],
    'edit': ['编辑', 'Edit', '編集'],
    'delete': ['删除模板', 'Delete template', 'テンプレートを削除'],
    'confirmDelete': [
      '确定删除？系列和已创建任务不受影响。',
      'Delete? Series and existing tasks are unaffected.',
      '削除しますか？シリーズと作成済みタスクには影響しません。',
    ],
    'preview': ['预览并创建', 'Preview & create', 'プレビューして作成'],
    'repeat': ['创建重复系列', 'Create recurring series', '繰り返しを作成'],
    'save': ['保存', 'Save', '保存'],
    'create': ['创建任务', 'Create task', 'タスクを作成'],
    'cancel': ['取消', 'Cancel', 'キャンセル'],
    'name': ['标题', 'Title', 'タイトル'],
    'note': ['备注', 'Note', 'メモ'],
    'nodes': [
      '节点：每行 标题|截止前分钟数',
      'Milestones: title|minutes before deadline, one per line',
      'マイルストーン：各行にタイトル|締切前の分数',
    ],
    'reminders': [
      '提醒：提前秒数，逗号分隔',
      'Reminders: seconds before, comma-separated',
      '通知：締切前の秒数、カンマ区切り',
    ],
    'notifications': ['启用通知', 'Enable notifications', '通知を有効にする'],
    'alarm': ['启用闹钟', 'Enable alarm', 'アラームを有効にする'],
    'date': [
      '基准/生效日期 YYYY-MM-DD',
      'Base / effective date YYYY-MM-DD',
      '基準・適用日 YYYY-MM-DD',
    ],
    'endDate': [
      '结束日期 YYYY-MM-DD（可留空）',
      'End date YYYY-MM-DD (optional)',
      '終了日 YYYY-MM-DD（省略可）',
    ],
    'time': ['当地时间 HH:mm', 'Local time HH:mm', '現地時刻 HH:mm'],
    'zone': ['IANA 时区', 'IANA timezone', 'IANA タイムゾーン'],
    'daily': ['每天', 'Daily', '毎日'],
    'weekly': ['每周', 'Weekly', '毎週'],
    'monthly': ['每月', 'Monthly', '毎月'],
    'weekdays': [
      '星期：1=周一，7=周日，逗号分隔',
      'Weekdays: 1=Mon, 7=Sun, comma-separated',
      '曜日：1=月曜、7=日曜、カンマ区切り',
    ],
    'monthDay': ['每月日期（1–31）', 'Day of month (1–31)', '毎月の日付（1–31）'],
    'clamp': [
      '不存在日期时取月底（否则跳过）',
      'Use month end for missing dates (otherwise skip)',
      '存在しない日付は月末にする（オフならスキップ）',
    ],
    'policy': [
      '按固定时区日历生成，不补历史期；DST 缺失时刻跳过，重复时刻取第一次。暂停/终止保留任务，关闭已生成未来实例的通知与闹钟。恢复不覆盖用户修改；暂停期间编辑过的任务请自行确认提醒开关。',
      'Fixed-zone calendar; no historical catch-up. DST gaps are skipped; folds use the first instant. Pause/terminate retains tasks and disables future-instance notifications and alarms. Resume preserves user edits; check reminder switches on tasks edited while paused.',
      '固定タイムゾーンの暦で生成し、過去分は補いません。夏時間の欠落はスキップ、重複は最初を使用。停止・終了時はタスクを残し、生成済みの将来分の通知とアラームを無効にします。再開時も編集を保持します。停止中に編集したタスクの通知設定はご確認ください。',
    ],
    'error': [
      '操作未完成，请检查输入或存储后重试。',
      'Could not finish. Check input or storage and retry.',
      '完了できませんでした。入力や保存状態を確認して再試行してください。',
    ],
    'success': ['已保存', 'Saved', '保存しました'],
    'active': ['运行中', 'Active', '実行中'],
    'paused': ['已暂停', 'Paused', '一時停止中'],
    'terminated': ['已终止', 'Terminated', '終了済み'],
    'pause': ['暂停', 'Pause', '一時停止'],
    'resume': ['恢复', 'Resume', '再開'],
    'terminate': ['终止系列', 'Terminate series', 'シリーズを終了'],
    'confirmTerminate': [
      '永久终止系列？已有任务保留，未来实例的通知与闹钟关闭，无法恢复系列。',
      'Permanently terminate this series? Tasks remain, but future-instance notifications and alarms are disabled. This cannot be resumed.',
      'シリーズを永久に終了しますか？タスクは残りますが、将来分の通知とアラームは無効になります。再開はできません。',
    ],
    'following': ['编辑后续', 'Edit following', '以降を編集'],
    'followingPolicy': [
      '生效日必须晚于所有已生成实例；已有任务请使用“仅本次”。',
      'Effective date must follow all issued instances; use “Only this” for existing tasks.',
      '適用日は生成済みの全日付より後にしてください。既存タスクは「今回のみ」で編集できます。',
    ],
    'upcoming': [
      '近期预览（最多 20 期 / 30 天）',
      'Upcoming (up to 20 / 30 days)',
      '今後の予定（最大20件・30日）',
    ],
    'skip': ['跳过本期', 'Skip occurrence', '今回をスキップ'],
    'confirmSkip': [
      '跳过后不会再次生成；若已创建，将删除任务及提醒。',
      'This date will not regenerate; an existing task and its reminders will be removed.',
      'この日付は再生成されません。作成済みのタスクと通知は削除されます。',
    ],
    'instances': ['已生成实例', 'Issued instances', '生成済みタスク'],
    'onlyThis': ['仅本次', 'Only this', '今回のみ'],
  };
}
