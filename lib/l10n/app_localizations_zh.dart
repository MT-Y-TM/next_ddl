// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Next DDL';

  @override
  String get settings => '设置';

  @override
  String get addTask => '新增任务';

  @override
  String get inProgressTab => '进行中';

  @override
  String get overdueTab => '已过期';

  @override
  String inProgressSummary(int count) {
    return '共 $count 个进行中任务，按剩余时间排序';
  }

  @override
  String overdueSummary(int count) {
    return '共 $count 个已过期任务，按超时先后排序';
  }

  @override
  String get nextNode => '下一个节点';

  @override
  String get finalDeadline => '最终截止';

  @override
  String get noFutureNodes => '无未来节点';

  @override
  String get allExpired => '已全部超时';

  @override
  String get remainingTime => '剩余时间';

  @override
  String get noTasksTitle => '还没有任何 deadline 任务';

  @override
  String get noTasksBody => '创建第一个任务后，这里会显示下一个节点、最终截止和实时倒计时。';

  @override
  String get createNow => '立即创建';

  @override
  String get taskDetails => '任务详情';

  @override
  String get taskNotFound => '任务不存在或已被删除';

  @override
  String get edit => '编辑';

  @override
  String timezoneLabel(Object timezone) {
    return '时区：$timezone';
  }

  @override
  String nextNodeValue(Object value) {
    return '下一个节点：$value';
  }

  @override
  String finalDeadlineValue(Object value) {
    return '最终截止：$value';
  }

  @override
  String get timeline => '时间线';

  @override
  String get generatedNode => '自动生成';

  @override
  String get manualNode => '手动维护';

  @override
  String get reminderRules => '提醒策略';

  @override
  String get remindAtTime => '到点提醒';

  @override
  String get noReminder => '未设置提醒';

  @override
  String get deleteTask => '删除任务';

  @override
  String get deleteTaskTitle => '删除任务';

  @override
  String get deleteTaskBody => '删除后会同步清除该任务的待提醒通知。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get editTask => '编辑任务';

  @override
  String get newTask => '新增任务';

  @override
  String get taskTitle => '任务标题';

  @override
  String get taskTitleHint => '例如：毕业设计终稿';

  @override
  String get note => '备注';

  @override
  String get noteHint => '可写上下文、交付要求或提醒自己关注的点。';

  @override
  String get pickTime => '选择时间';

  @override
  String get enableNotifications => '启用系统提醒';

  @override
  String get enableNotificationsHint => 'Android 会请求通知权限，Windows 使用系统通知。';

  @override
  String get milestones => '中间节点';

  @override
  String get addMilestone => '新增节点';

  @override
  String get editMilestone => '编辑节点';

  @override
  String get noMilestones => '当前没有中间节点，应用会直接用最终截止作为最后一个关键时间点。';

  @override
  String get generated => '自动生成';

  @override
  String get manual => '手动';

  @override
  String get customReminder => '自定义提醒';

  @override
  String get saveChanges => '保存修改';

  @override
  String get createTask => '创建任务';

  @override
  String get taskCreated => '任务已创建';

  @override
  String get taskUpdated => '任务已更新';

  @override
  String get fillTaskTitle => '请先填写任务标题';

  @override
  String get milestoneBeforeFinal => '所有中间节点都必须早于最终截止';

  @override
  String get milestoneName => '节点名称';

  @override
  String get milestoneTime => '节点时间';

  @override
  String get change => '修改';

  @override
  String get confirm => '确认';

  @override
  String get quantity => '数量';

  @override
  String get add => '添加';

  @override
  String get minutes => '分钟';

  @override
  String get hours => '小时';

  @override
  String get days => '天';

  @override
  String get atTimeReminder => '到点提醒';

  @override
  String advanceDays(int count) {
    return '提前 $count 天';
  }

  @override
  String advanceHours(int count) {
    return '提前 $count 小时';
  }

  @override
  String advanceMinutes(int count) {
    return '提前 $count 分钟';
  }

  @override
  String advanceSeconds(int count) {
    return '提前 $count 秒';
  }

  @override
  String get currentVersion => '当前版本';

  @override
  String get loading => '读取中...';

  @override
  String get taskCount => '任务总数';

  @override
  String taskCountValue(int count) {
    return '$count 个';
  }

  @override
  String get persistentNotification => 'Android 消息栏常驻提醒';

  @override
  String get persistentNotificationAndroidHint =>
      '开启后会在消息栏常驻显示最紧急任务摘要，并在任务或开关变化时自动更新。';

  @override
  String get persistentNotificationOtherHint =>
      '该功能仅在 Android 生效；其他平台会保留设置值但不会显示常驻通知。';

  @override
  String get persistentEnabled => '已开启消息栏常驻提醒';

  @override
  String get persistentDisabled => '已关闭消息栏常驻提醒';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get messageBarUnit => '消息栏剩余时间单位';

  @override
  String get unitByDay => '按天';

  @override
  String get unitByHour => '按小时';

  @override
  String get appTimezone => '应用时区';

  @override
  String get exportJson => '导出 JSON';

  @override
  String get exportJsonHint => '导出当前全部任务数据，用于备份或迁移。';

  @override
  String get importJson => '导入 JSON';

  @override
  String get importJsonHint => '导入会替换本地全部任务数据，并重新同步通知。';

  @override
  String get exportCancelled => '已取消导出';

  @override
  String exportSuccess(Object path) {
    return '导出成功：$path';
  }

  @override
  String get importCancelled => '已取消导入';

  @override
  String importSuccess(int count) {
    return '导入成功：$count 个任务';
  }

  @override
  String get notificationNotice => '通知说明';

  @override
  String get windowsNotificationNotice =>
      '当前 Windows 版本使用 ZIP 形式发布而非 MSIX。已显示的系统通知可能无法被可靠取消，编辑任务后旧 toast 可能残留。';

  @override
  String get androidNotificationNotice =>
      'Android 首次启用提醒时只会请求普通通知权限，不再跳转“闹钟和提醒”。提醒会以更兼容 MIUI 的方式调度，保存、删除或导入任务后会自动重建未来提醒。';

  @override
  String get chooseTimezone => '选择应用时区';

  @override
  String get searchTimezone => '搜索时区';

  @override
  String get searchTimezoneHint => '例如 Asia/Shanghai';

  @override
  String timezoneUpdated(Object timezone) {
    return '应用时区已更新：$timezone';
  }

  @override
  String get timezoneInvalid => '时区无效';

  @override
  String get localeSystem => '跟随系统';

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
  String get timezoneAsiaTokyo => '东京';

  @override
  String get timezoneAsiaSeoul => '首尔';

  @override
  String get timezoneUtc => '协调世界时';

  @override
  String get timezoneEuropeLondon => '伦敦';

  @override
  String get timezoneAmericaNewYork => '纽约';

  @override
  String get timezoneAmericaLosAngeles => '洛杉矶';

  @override
  String get timezoneRegionAfrica => '非洲';

  @override
  String get timezoneRegionAmerica => '美洲';

  @override
  String get timezoneRegionAntarctica => '南极洲';

  @override
  String get timezoneRegionArctic => '北极';

  @override
  String get timezoneRegionAsia => '亚洲';

  @override
  String get timezoneRegionAtlantic => '大西洋';

  @override
  String get timezoneRegionAustralia => '澳洲';

  @override
  String get timezoneRegionBrazil => '巴西';

  @override
  String get timezoneRegionCanada => '加拿大';

  @override
  String get timezoneRegionChile => '智利';

  @override
  String get timezoneRegionEtc => '其他';

  @override
  String get timezoneRegionEurope => '欧洲';

  @override
  String get timezoneRegionIndian => '印度洋';

  @override
  String get timezoneRegionMexico => '墨西哥';

  @override
  String get timezoneRegionPacific => '太平洋';

  @override
  String get timezoneRegionUs => '美国';

  @override
  String get ongoingNoTask => '当前没有进行中的任务';

  @override
  String get persistentNotificationTitle => 'Next DDL';

  @override
  String get fileExportDialogTitle => '导出 Next DDL 数据';

  @override
  String get fileImportDialogTitle => '导入 Next DDL 数据';

  @override
  String get notificationPersistentChannelDescription => 'Next DDL 常驻状态通知';

  @override
  String get notificationMessageChannelDescription => '任务节点与最终截止消息通知';

  @override
  String notificationNowDue(Object title) {
    return '现在到点 · $title';
  }

  @override
  String get notificationNowDueNoTitle => '现在到点';

  @override
  String notificationAdvanceDue(Object offset, Object title) {
    return '提前$offset · $title';
  }

  @override
  String notificationAdvanceDueNoTitle(Object offset) {
    return '提前$offset';
  }

  @override
  String get compactDaySuffix => '天';

  @override
  String get compactHourSuffix => '小时';

  @override
  String get countdownDaySuffix => '天';

  @override
  String get countdownOverduePrefix => '已超时';

  @override
  String generatedMilestoneTitle(int percent) {
    return '$percent% 节点';
  }

  @override
  String get unnamedMilestone => '未命名节点';

  @override
  String get updates => '应用更新';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkingForUpdates => '正在检查更新...';

  @override
  String get appUpToDate => '当前已是最新版本';

  @override
  String get updateNoPublishedRelease => '当前还没有可用的正式发布版本。';

  @override
  String updateAvailableStatus(Object version) {
    return '发现新版本：$version';
  }

  @override
  String get updateDownloading => '正在下载更新包...';

  @override
  String updateUsingCachedInstaller(Object version) {
    return '正在使用已缓存的 $version 安装包';
  }

  @override
  String get updateInstallReady => '安装包已准备就绪';

  @override
  String downloadPercent(int percent) {
    return '$percent%';
  }

  @override
  String get downloadProgressUnknown => '下载进度暂不可用';

  @override
  String downloadSpeed(Object speed) {
    return '$speed';
  }

  @override
  String get downloadSpeedUnknown => '下载速度暂不可用';

  @override
  String get updateErrorNetworkUnavailable => '暂时无法连接更新服务，请检查网络后重试。';

  @override
  String get updateErrorServiceUnavailable => '更新服务暂时不可用，请稍后重试。';

  @override
  String get updateErrorMissingAndroidAsset => '新版本缺少可下载的安装包。';

  @override
  String get updateErrorDownloadFailed => '下载更新包失败，请稍后重试。';

  @override
  String get updateErrorInstallerOpenFailed => '安装包已下载，但暂时无法打开系统安装器。';

  @override
  String get updateErrorOpenReleasePageFailed => '暂时无法打开 Release 页面。';

  @override
  String get updateErrorOpenInstallPermissionFailed => '暂时无法打开安装未知应用权限页面。';

  @override
  String get updateErrorUnexpected => '更新失败，请稍后重试。';

  @override
  String updateError(Object message) {
    return '更新失败：$message';
  }

  @override
  String get updateNow => '立即更新';

  @override
  String get openReleasePage => '打开 Release 页面';

  @override
  String get clearCachedInstallers => '清理本地安装包';

  @override
  String cachedInstallersCleared(int count) {
    return '已清理 $count 个本地安装包';
  }

  @override
  String get noCachedInstallers => '当前没有可清理的本地安装包';

  @override
  String get updateReleaseNotes => '更新说明';

  @override
  String get noReleaseNotes => '暂无更新说明';

  @override
  String get updatePermissionRequired => '请先允许此应用安装未知来源应用，返回后会继续安装。';

  @override
  String get openInstallPermission => '打开安装权限';

  @override
  String get windowsUpdateNotice =>
      'Windows 端当前仅支持打开 GitHub Release 页面，不支持 ZIP 自安装。';

  @override
  String get updateDialogTitle => '发现新版本';

  @override
  String updateDialogMessage(Object version) {
    return '当前可升级到 $version。';
  }

  @override
  String publishedAtLabel(Object value) {
    return '发布时间：$value';
  }

  @override
  String get later => '稍后';
}
