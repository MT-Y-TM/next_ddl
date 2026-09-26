import 'package:flutter/widgets.dart';

class TaskUiStrings {
  TaskUiStrings(BuildContext context)
    : language = Localizations.localeOf(context).languageCode;
  final String language;
  String t(String zh, String en, String ja) => switch (language) {
    'zh' => zh,
    'ja' => ja,
    _ => en,
  };
  String get archived => t('归档', 'Archived', 'アーカイブ');
  String get completed => t('已完成', 'Completed', '完了');
  String get emptyArchive => t('暂无归档任务', 'No archived tasks', 'アーカイブはありません');
  String get noTags => t('暂无标签', 'No tags yet', 'タグはありません');
  String get completeMilestone => t('完成节点', 'Complete milestone', '中間期限を完了');
  String get reopenMilestone => t('撤销节点完成', 'Reopen milestone', '中間期限を未完了に戻す');
  String get complete => t('完成任务', 'Complete task', 'タスクを完了');
  String get restore => t('撤销完成', 'Reopen', '未完了に戻す');
  String get undo => t('撤销', 'Undo', '元に戻す');
  String get saved => t('已更新', 'Updated', '更新しました');
  String get failed => t(
    '操作或提醒调度未完成，请检查状态后重试',
    'Operation or reminder scheduling failed. Check the current state and retry.',
    '操作または通知の設定に失敗しました。状態を確認して再試行してください。',
  );
  String get search => t('搜索标题和备注', 'Search titles and notes', 'タイトル・メモを検索');
  String get scope => t(
    '搜索范围：当前选项卡（归档单独搜索）',
    'Search scope: current tab (archives searched separately)',
    '検索範囲：現在のタブ（アーカイブは別）',
  );
  String get clear => t('清除筛选', 'Clear filters', '絞り込みを解除');
  String get noResults => t('没有匹配的任务', 'No matching tasks', '一致するタスクはありません');
  String get tags => t('标签', 'Tags', 'タグ');
  String get tagsHint => t(
    '以逗号分隔；留空移除全部标签',
    'Separate with commas; leave empty to remove all tags',
    'カンマ区切り。空欄ですべてのタグを削除',
  );
  String get all => t('全部标签', 'All tags', 'すべてのタグ');
  String get untagged => t('未分类', 'Untagged', '未分類');
  String get manageTags => t('管理标签', 'Manage tags', 'タグを管理');
  String get removeTag => t(
    '删除标签会从所有任务中移除该标签，但保留任务。',
    'Remove this tag from all tasks without deleting any tasks.',
    'すべてのタスクからこのタグを削除します。タスクは削除されません。',
  );
  String get postpone => t('快捷延期', 'Postpone', '期限を延長');
  String get hour => t('延后 1 小时', '+1 hour', '1時間延長');
  String get day => t('延后 1 天', '+1 day', '1日延長');
  String get custom => t('自定义时间', 'Custom time', '日時を指定');
  String get shift =>
      t('同步平移后续未完成节点', 'Shift future incomplete milestones', '今後の未完了の中間期限も移動');
  String get shiftHint => t(
    '关闭时仅修改最终截止；开启时仅平移当前时刻之后的未完成节点，保留历史及已完成节点。',
    'Off: change only the final deadline. On: shift only future incomplete milestones; keep past and completed milestones unchanged.',
    'オフ：最終期限のみ変更。オン：今後の未完了の中間期限のみ移動し、過去・完了済みの日時は維持します。',
  );
  String get preview => t('新时间预览', 'New time preview', '変更後の日時');
  String get invalid => t(
    '新截止必须晚于当前时间，且所有节点必须早于最终截止。',
    'The new deadline must be in the future and after every milestone.',
    '新しい期限は現在時刻より後、かつすべての中間期限より後にしてください。',
  );
}
