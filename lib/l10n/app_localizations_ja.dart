// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Next DDL';

  @override
  String get settings => '設定';

  @override
  String get addTask => 'タスク追加';

  @override
  String get inProgressTab => '進行中';

  @override
  String get overdueTab => '期限超過';

  @override
  String inProgressSummary(int count) {
    return '進行中タスク $count 件、残り時間順';
  }

  @override
  String overdueSummary(int count) {
    return '期限超過タスク $count 件、超過時間順';
  }

  @override
  String get nextNode => '次のマイルストーン';

  @override
  String get finalDeadline => '最終締切';

  @override
  String get noFutureNodes => '今後のマイルストーンなし';

  @override
  String get allExpired => 'すべて期限超過';

  @override
  String get remainingTime => '残り時間';

  @override
  String get noTasksTitle => 'deadline タスクはまだありません';

  @override
  String get noTasksBody =>
      '最初のタスクを作成すると、次のマイルストーン、最終締切、リアルタイムのカウントダウンがここに表示されます。';

  @override
  String get createNow => '今すぐ作成';

  @override
  String get taskDetails => 'タスク詳細';

  @override
  String get taskNotFound => 'タスクが存在しないか、すでに削除されています';

  @override
  String get edit => '編集';

  @override
  String timezoneLabel(Object timezone) {
    return 'タイムゾーン: $timezone';
  }

  @override
  String nextNodeValue(Object value) {
    return '次のマイルストーン: $value';
  }

  @override
  String finalDeadlineValue(Object value) {
    return '最終締切: $value';
  }

  @override
  String get timeline => 'タイムライン';

  @override
  String get generatedNode => '自動生成';

  @override
  String get manualNode => '手動管理';

  @override
  String get reminderRules => '通知ルール';

  @override
  String get remindAtTime => '期限ちょうど';

  @override
  String get noReminder => '通知なし';

  @override
  String get deleteTask => 'タスク削除';

  @override
  String get deleteTaskTitle => 'タスク削除';

  @override
  String get deleteTaskBody => '削除すると、このタスクの今後の通知も一緒に削除されます。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get editTask => 'タスク編集';

  @override
  String get newTask => '新規タスク';

  @override
  String get taskTitle => 'タスク名';

  @override
  String get taskTitleHint => '例: 卒業制作の最終提出';

  @override
  String get note => 'メモ';

  @override
  String get noteHint => '背景、提出条件、注意点などを記録できます。';

  @override
  String get pickTime => '時間を選択';

  @override
  String get enableNotifications => 'システム通知を有効化';

  @override
  String get enableNotificationsHint =>
      'Android は通知権限を要求し、Windows はシステム通知を使います。';

  @override
  String get milestones => '中間マイルストーン';

  @override
  String get addMilestone => 'マイルストーン追加';

  @override
  String get editMilestone => 'マイルストーン編集';

  @override
  String get noMilestones => '中間マイルストーンはありません。アプリは最終締切を最後の重要時点として直接使います。';

  @override
  String get generated => '自動生成';

  @override
  String get manual => '手動';

  @override
  String get customReminder => 'カスタム通知';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get createTask => 'タスク作成';

  @override
  String get taskCreated => 'タスクを作成しました';

  @override
  String get taskUpdated => 'タスクを更新しました';

  @override
  String get fillTaskTitle => '先にタスク名を入力してください';

  @override
  String get milestoneBeforeFinal => 'すべての中間マイルストーンは最終締切より前である必要があります';

  @override
  String get milestoneName => 'マイルストーン名';

  @override
  String get milestoneTime => 'マイルストーン時刻';

  @override
  String get change => '変更';

  @override
  String get confirm => '確認';

  @override
  String get quantity => '数量';

  @override
  String get add => '追加';

  @override
  String get minutes => '分';

  @override
  String get hours => '時間';

  @override
  String get days => '日';

  @override
  String get atTimeReminder => '期限ちょうど';

  @override
  String advanceDays(int count) {
    return '$count日前';
  }

  @override
  String advanceHours(int count) {
    return '$count時間前';
  }

  @override
  String advanceMinutes(int count) {
    return '$count分前';
  }

  @override
  String advanceSeconds(int count) {
    return '$count秒前';
  }

  @override
  String get currentVersion => 'バージョン';

  @override
  String get loading => '読み込み中...';

  @override
  String get taskCount => 'タスク数';

  @override
  String taskCountValue(int count) {
    return '$count 件';
  }

  @override
  String get persistentNotification => 'Android 常駐通知';

  @override
  String get persistentNotificationAndroidHint =>
      '有効にすると、最も差し迫ったタスクが通知欄に常駐し、タスクや設定の変更時に自動更新されます。';

  @override
  String get persistentNotificationOtherHint =>
      'この機能は Android のみ有効です。他のプラットフォームでは設定値だけ保持され、常駐通知は表示されません。';

  @override
  String get persistentEnabled => '常駐通知を有効化しました';

  @override
  String get persistentDisabled => '常駐通知を無効化しました';

  @override
  String get language => '言語';

  @override
  String get followSystem => 'システムに従う';

  @override
  String get messageBarUnit => '通知欄の残り時間単位';

  @override
  String get unitByDay => '日';

  @override
  String get unitByHour => '時間';

  @override
  String get appTimezone => 'アプリのタイムゾーン';

  @override
  String get exportJson => 'JSON をエクスポート';

  @override
  String get exportJsonHint => '現在の全タスクデータをバックアップや移行用に書き出します。';

  @override
  String get importJson => 'JSON をインポート';

  @override
  String get importJsonHint => 'インポートするとローカルの全タスクデータを置き換え、通知を再構築します。';

  @override
  String get exportCancelled => 'エクスポートをキャンセルしました';

  @override
  String exportSuccess(Object path) {
    return 'エクスポート成功: $path';
  }

  @override
  String get importCancelled => 'インポートをキャンセルしました';

  @override
  String importSuccess(int count) {
    return '$count 件のタスクをインポートしました';
  }

  @override
  String get notificationNotice => '通知メモ';

  @override
  String get windowsNotificationNotice =>
      '現在の Windows 版は MSIX ではなく ZIP 形式で配布されています。表示済みのシステム通知は確実に取り消せない場合があり、タスク編集後に古いトーストが残ることがあります。';

  @override
  String get androidNotificationNotice =>
      'Android では通知を有効にしても通常の通知権限のみを要求し、アラームとリマインダー画面は開きません。保存・削除・インポート後には MIUI と相性のよい方式で今後の通知を再構築します。';

  @override
  String get chooseTimezone => 'アプリのタイムゾーンを選択';

  @override
  String get searchTimezone => 'タイムゾーン検索';

  @override
  String get searchTimezoneHint => '例: Asia/Shanghai';

  @override
  String timezoneUpdated(Object timezone) {
    return 'アプリのタイムゾーンを更新しました: $timezone';
  }

  @override
  String get timezoneInvalid => '無効なタイムゾーンです';

  @override
  String get localeSystem => 'システムに従う';

  @override
  String get localeZh => '简体中文';

  @override
  String get localeEn => 'English';

  @override
  String get localeJa => '日本語';

  @override
  String get timezoneAsiaShanghai => '上海';

  @override
  String get timezoneAsiaHongKong => '香港';

  @override
  String get timezoneAsiaTaipei => '台北';

  @override
  String get timezoneAsiaTokyo => '東京';

  @override
  String get timezoneAsiaSeoul => 'ソウル';

  @override
  String get timezoneUtc => 'UTC';

  @override
  String get timezoneEuropeLondon => 'ロンドン';

  @override
  String get timezoneAmericaNewYork => 'ニューヨーク';

  @override
  String get timezoneAmericaLosAngeles => 'ロサンゼルス';

  @override
  String get ongoingNoTask => '進行中のタスクはありません';

  @override
  String get persistentNotificationTitle => 'Next DDL';

  @override
  String get fileExportDialogTitle => 'Next DDL データをエクスポート';

  @override
  String get fileImportDialogTitle => 'Next DDL データをインポート';

  @override
  String get notificationPersistentChannelDescription => 'Next DDL の常駐ステータス通知';

  @override
  String get notificationMessageChannelDescription => 'マイルストーンと最終締切の通知';

  @override
  String notificationNowDue(Object title) {
    return '今が期限 · $title';
  }

  @override
  String notificationAdvanceDue(Object offset, Object title) {
    return '$offset前 · $title';
  }

  @override
  String get compactDaySuffix => '日';

  @override
  String get compactHourSuffix => '時間';

  @override
  String get countdownDaySuffix => '日';

  @override
  String get countdownOverduePrefix => '期限超過';

  @override
  String generatedMilestoneTitle(int percent) {
    return '$percent% チェックポイント';
  }

  @override
  String get unnamedMilestone => '名称未設定のノード';

  @override
  String get updates => 'アプリ更新';

  @override
  String get checkForUpdates => '更新を確認';

  @override
  String get checkingForUpdates => '更新を確認しています...';

  @override
  String get appUpToDate => '現在のバージョンは最新です';

  @override
  String updateAvailableStatus(Object version) {
    return '新しいバージョンがあります: $version';
  }

  @override
  String get updateDownloading => '更新をダウンロードしています...';

  @override
  String get updateInstallReady => 'インストーラーの準備ができました';

  @override
  String updateError(Object message) {
    return '更新に失敗しました: $message';
  }

  @override
  String get updateNow => '今すぐ更新';

  @override
  String get openReleasePage => 'Release ページを開く';

  @override
  String get updateReleaseNotes => '更新内容';

  @override
  String get noReleaseNotes => '更新内容はありません';

  @override
  String get updatePermissionRequired =>
      'このアプリに未知のアプリのインストールを許可してから、戻ってインストールを続けてください。';

  @override
  String get openInstallPermission => 'インストール権限を開く';

  @override
  String get windowsUpdateNotice =>
      'Windows 版は現在 GitHub Release ページを開くことのみ対応しており、ZIP の自動インストールには対応していません。';

  @override
  String get updateDialogTitle => '新しいバージョンがあります';

  @override
  String updateDialogMessage(Object version) {
    return '$version にアップデートできます。';
  }

  @override
  String publishedAtLabel(Object value) {
    return '公開日: $value';
  }

  @override
  String get later => 'あとで';
}
