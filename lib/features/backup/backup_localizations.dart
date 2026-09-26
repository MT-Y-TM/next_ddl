import 'package:flutter/widgets.dart';
import '../../services/backup_service.dart';

class BackupLocalizations {
  BackupLocalizations(this.languageCode);
  factory BackupLocalizations.of(BuildContext context) =>
      BackupLocalizations(Localizations.localeOf(context).languageCode);
  final String languageCode;
  String text(String zh, String en, String ja) => languageCode == 'zh'
      ? zh
      : languageCode == 'ja'
      ? ja
      : en;
  String get title => text('数据备份与恢复', 'Backups and restore', 'バックアップと復元');
  String get empty => text('暂无备份', 'No backups yet', 'バックアップはありません');
  String get restore => text('恢复', 'Restore', '復元');
  String get cancel => text('取消', 'Cancel', 'キャンセル');
  String get confirm => text('确认替换', 'Replace data', 'データを置き換える');
  String get retry => text('重试', 'Retry', '再試行');
  String retention(int count) => text(
    '保留最近 $count 份备份。仅包含数据及媒体路径，不包含实际图片或音频文件。',
    'Keeps the latest $count backups. Includes data and media paths, not image or audio files.',
    '最新 $count 件を保存します。データとメディアのパスのみで、画像・音声ファイルは含みません。',
  );
  String replacement(int count) => text(
    '将导入 $count 个任务并替换全部现有数据与设置。替换前会自动备份当前数据。',
    'Import $count tasks and replace all current data and settings. Current data will be backed up first.',
    '$count 件のタスクを取り込み、現在のデータと設定をすべて置き換えます。先に現在のデータをバックアップします。',
  );
  String get saved => text('数据已恢复', 'Data restored', 'データを復元しました');
  String get scheduleFailed => text(
    '数据已保存，但提醒同步失败。请重试同步，无需再次导入。',
    'Data was saved, but reminder synchronization failed. Retry synchronization, not the import.',
    'データは保存されましたが、リマインダーの同期に失敗しました。再取り込みせず、同期を再試行してください。',
  );
  String error(Object error) {
    final reason = error is BackupException
        ? error.reason
        : BackupFailure.writeFailed;
    return switch (reason) {
      BackupFailure.invalidJson => text(
        '文件不是有效 JSON。原数据未替换。',
        'Invalid JSON. Existing data was not replaced.',
        'JSON が不正です。既存データは変更されていません。',
      ),
      BackupFailure.unsupportedSchema => text(
        '不支持此备份版本，请更新应用后重试。',
        'Unsupported backup version. Update the app and retry.',
        '未対応のバックアップ形式です。アプリを更新してください。',
      ),
      BackupFailure.invalidFields => text(
        '数据字段、日期或 ID 无效，请检查备份文件。',
        'Invalid fields, dates or IDs. Check the backup file.',
        '項目、日時、または ID が不正です。ファイルを確認してください。',
      ),
      BackupFailure.busy => text(
        '正在处理数据，请稍候。',
        'A data operation is in progress. Please wait.',
        'データ処理中です。お待ちください。',
      ),
      BackupFailure.writeFailed => text(
        '无法读取或保存备份。请检查存储空间并重试。',
        'Could not read or save the backup. Check storage and retry.',
        'バックアップを読み書きできません。空き容量を確認して再試行してください。',
      ),
    };
  }
}
