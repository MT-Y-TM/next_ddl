// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Next DDL';

  @override
  String get settings => 'Settings';

  @override
  String get addTask => 'Add Task';

  @override
  String get inProgressTab => 'In Progress';

  @override
  String get overdueTab => 'Overdue';

  @override
  String inProgressSummary(int count) {
    return '$count in-progress tasks, sorted by remaining time';
  }

  @override
  String overdueSummary(int count) {
    return '$count overdue tasks, sorted by how long they have been overdue';
  }

  @override
  String get nextNode => 'Next milestone';

  @override
  String get finalDeadline => 'Final deadline';

  @override
  String get noFutureNodes => 'No future milestones';

  @override
  String get allExpired => 'All expired';

  @override
  String get remainingTime => 'Remaining time';

  @override
  String get noTasksTitle => 'No deadline tasks yet';

  @override
  String get noTasksBody =>
      'Create your first task to see the next milestone, final deadline, and live countdown here.';

  @override
  String get createNow => 'Create now';

  @override
  String get taskDetails => 'Task details';

  @override
  String get taskNotFound => 'Task not found or already deleted';

  @override
  String get edit => 'Edit';

  @override
  String timezoneLabel(Object timezone) {
    return 'Timezone: $timezone';
  }

  @override
  String nextNodeValue(Object value) {
    return 'Next milestone: $value';
  }

  @override
  String finalDeadlineValue(Object value) {
    return 'Final deadline: $value';
  }

  @override
  String get timeline => 'Timeline';

  @override
  String get generatedNode => 'Generated';

  @override
  String get manualNode => 'Manual';

  @override
  String get reminderRules => 'Reminder rules';

  @override
  String get remindAtTime => 'At time';

  @override
  String get noReminder => 'No reminders';

  @override
  String get deleteTask => 'Delete task';

  @override
  String get deleteTaskTitle => 'Delete task';

  @override
  String get deleteTaskBody =>
      'Deleting will also remove future scheduled reminders for this task.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get editTask => 'Edit task';

  @override
  String get newTask => 'New task';

  @override
  String get taskTitle => 'Task title';

  @override
  String get taskTitleHint => 'For example: Final thesis submission';

  @override
  String get note => 'Note';

  @override
  String get noteHint =>
      'Add context, deliverables, or anything you want to remember.';

  @override
  String get pickTime => 'Pick time';

  @override
  String get enableNotifications => 'Enable reminders';

  @override
  String get enableNotificationsHint =>
      'Android requests notification permission; Windows uses system notifications.';

  @override
  String get milestones => 'Milestones';

  @override
  String get addMilestone => 'Add milestone';

  @override
  String get editMilestone => 'Edit milestone';

  @override
  String get noMilestones =>
      'There are no milestones yet. The app will use the final deadline as the last key point directly.';

  @override
  String get generated => 'Generated';

  @override
  String get manual => 'Manual';

  @override
  String get customReminder => 'Custom reminder';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get createTask => 'Create task';

  @override
  String get taskCreated => 'Task created';

  @override
  String get taskUpdated => 'Task updated';

  @override
  String get fillTaskTitle => 'Please enter a task title';

  @override
  String get milestoneBeforeFinal =>
      'All milestones must be earlier than the final deadline';

  @override
  String get milestoneName => 'Milestone name';

  @override
  String get milestoneTime => 'Milestone time';

  @override
  String get change => 'Change';

  @override
  String get confirm => 'Confirm';

  @override
  String get quantity => 'Quantity';

  @override
  String get add => 'Add';

  @override
  String get minutes => 'Minutes';

  @override
  String get hours => 'Hours';

  @override
  String get days => 'Days';

  @override
  String get atTimeReminder => 'At time';

  @override
  String advanceDays(int count) {
    return '$count day(s) early';
  }

  @override
  String advanceHours(int count) {
    return '$count hour(s) early';
  }

  @override
  String advanceMinutes(int count) {
    return '$count minute(s) early';
  }

  @override
  String advanceSeconds(int count) {
    return '$count second(s) early';
  }

  @override
  String get currentVersion => 'Version';

  @override
  String get loading => 'Loading...';

  @override
  String get taskCount => 'Task count';

  @override
  String taskCountValue(int count) {
    return '$count task(s)';
  }

  @override
  String get persistentNotification => 'Android persistent notification';

  @override
  String get persistentNotificationAndroidHint =>
      'When enabled, the most urgent task stays in the notification shade and updates automatically when tasks or settings change.';

  @override
  String get persistentNotificationOtherHint =>
      'This only works on Android. Other platforms keep the setting but do not show a persistent notification.';

  @override
  String get persistentEnabled => 'Persistent notification enabled';

  @override
  String get persistentDisabled => 'Persistent notification disabled';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get messageBarUnit => 'Notification time unit';

  @override
  String get unitByDay => 'Days';

  @override
  String get unitByHour => 'Hours';

  @override
  String get appTimezone => 'App timezone';

  @override
  String get exportJson => 'Export JSON';

  @override
  String get exportJsonHint =>
      'Export all current task data for backup or migration.';

  @override
  String get importJson => 'Import JSON';

  @override
  String get importJsonHint =>
      'Import replaces all local task data and rebuilds notifications.';

  @override
  String get exportCancelled => 'Export cancelled';

  @override
  String exportSuccess(Object path) {
    return 'Exported: $path';
  }

  @override
  String get importCancelled => 'Import cancelled';

  @override
  String importSuccess(int count) {
    return 'Imported: $count task(s)';
  }

  @override
  String get notificationNotice => 'Notification notes';

  @override
  String get windowsNotificationNotice =>
      'The current Windows build is distributed as a ZIP instead of MSIX. Displayed system notifications may not be cancelled reliably, and old toasts may remain after editing tasks.';

  @override
  String get androidNotificationNotice =>
      'On Android, enabling reminders only requests standard notification permission and no longer opens the Alarms & reminders page. Reminders are scheduled in a MIUI-friendlier way and rebuild automatically after saving, deleting, or importing tasks.';

  @override
  String get chooseTimezone => 'Choose app timezone';

  @override
  String get searchTimezone => 'Search timezones';

  @override
  String get searchTimezoneHint => 'For example Asia/Shanghai';

  @override
  String timezoneUpdated(Object timezone) {
    return 'App timezone updated: $timezone';
  }

  @override
  String get timezoneInvalid => 'Invalid timezone';

  @override
  String get localeSystem => 'Follow system';

  @override
  String get localeZh => '简体中文';

  @override
  String get localeEn => 'English';

  @override
  String get localeJa => '日本語';

  @override
  String get timezoneAsiaShanghai => 'Shanghai';

  @override
  String get timezoneAsiaHongKong => 'Hong Kong';

  @override
  String get timezoneAsiaTaipei => 'Taipei';

  @override
  String get timezoneAsiaTokyo => 'Tokyo';

  @override
  String get timezoneAsiaSeoul => 'Seoul';

  @override
  String get timezoneUtc => 'UTC';

  @override
  String get timezoneEuropeLondon => 'London';

  @override
  String get timezoneAmericaNewYork => 'New York';

  @override
  String get timezoneAmericaLosAngeles => 'Los Angeles';

  @override
  String get timezoneRegionAfrica => 'Africa';

  @override
  String get timezoneRegionAmerica => 'America';

  @override
  String get timezoneRegionAntarctica => 'Antarctica';

  @override
  String get timezoneRegionArctic => 'Arctic';

  @override
  String get timezoneRegionAsia => 'Asia';

  @override
  String get timezoneRegionAtlantic => 'Atlantic';

  @override
  String get timezoneRegionAustralia => 'Australia';

  @override
  String get timezoneRegionBrazil => 'Brazil';

  @override
  String get timezoneRegionCanada => 'Canada';

  @override
  String get timezoneRegionChile => 'Chile';

  @override
  String get timezoneRegionEtc => 'Other';

  @override
  String get timezoneRegionEurope => 'Europe';

  @override
  String get timezoneRegionIndian => 'Indian Ocean';

  @override
  String get timezoneRegionMexico => 'Mexico';

  @override
  String get timezoneRegionPacific => 'Pacific';

  @override
  String get timezoneRegionUs => 'United States';

  @override
  String get ongoingNoTask => 'No in-progress tasks right now';

  @override
  String get persistentNotificationTitle => 'Next DDL';

  @override
  String get fileExportDialogTitle => 'Export Next DDL data';

  @override
  String get fileImportDialogTitle => 'Import Next DDL data';

  @override
  String get notificationPersistentChannelDescription =>
      'Persistent status notification for Next DDL';

  @override
  String get notificationMessageChannelDescription =>
      'Deadline milestone and final deadline reminders';

  @override
  String notificationNowDue(Object title) {
    return 'Due now · $title';
  }

  @override
  String get notificationNowDueNoTitle => 'Due now';

  @override
  String notificationAdvanceDue(Object offset, Object title) {
    return '$offset early · $title';
  }

  @override
  String notificationAdvanceDueNoTitle(Object offset) {
    return '$offset early';
  }

  @override
  String get compactDaySuffix => ' days';

  @override
  String get compactHourSuffix => ' hours';

  @override
  String get countdownDaySuffix => 'd';

  @override
  String get countdownOverduePrefix => 'Overdue';

  @override
  String generatedMilestoneTitle(int percent) {
    return '$percent% checkpoint';
  }

  @override
  String get unnamedMilestone => 'Untitled milestone';

  @override
  String get updates => 'Updates';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking for updates...';

  @override
  String get appUpToDate => 'You\'re on the latest version';

  @override
  String get updateNoPublishedRelease =>
      'There is no published release available yet.';

  @override
  String updateAvailableStatus(Object version) {
    return 'New version available: $version';
  }

  @override
  String get updateDownloading => 'Downloading update...';

  @override
  String updateUsingCachedInstaller(Object version) {
    return 'Using cached installer for $version';
  }

  @override
  String get updateInstallReady => 'Installer is ready';

  @override
  String downloadPercent(int percent) {
    return '$percent%';
  }

  @override
  String get downloadProgressUnknown => 'Progress unavailable';

  @override
  String downloadSpeed(Object speed) {
    return '$speed';
  }

  @override
  String get downloadSpeedUnknown => 'Speed unavailable';

  @override
  String get updateErrorNetworkUnavailable =>
      'Can\'t reach the update service right now. Check your connection and try again.';

  @override
  String get updateErrorServiceUnavailable =>
      'The update service is temporarily unavailable. Please try again later.';

  @override
  String get updateErrorMissingAndroidAsset =>
      'The new release does not include a downloadable Android package.';

  @override
  String get updateErrorDownloadFailed =>
      'Failed to download the update package. Please try again later.';

  @override
  String get updateErrorInstallerOpenFailed =>
      'The update package was downloaded, but the system installer could not be opened.';

  @override
  String get updateErrorOpenReleasePageFailed =>
      'Couldn\'t open the Release page right now.';

  @override
  String get updateErrorOpenInstallPermissionFailed =>
      'Couldn\'t open the install unknown apps permission page right now.';

  @override
  String get updateErrorUnexpected =>
      'Update check failed. Please try again later.';

  @override
  String updateError(Object message) {
    return 'Update failed: $message';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get openReleasePage => 'Open Release page';

  @override
  String get clearCachedInstallers => 'Clear cached installers';

  @override
  String cachedInstallersCleared(int count) {
    return 'Cleared $count cached installer(s)';
  }

  @override
  String get noCachedInstallers => 'No cached installers to clear';

  @override
  String get updateReleaseNotes => 'Release notes';

  @override
  String get noReleaseNotes => 'No release notes';

  @override
  String get updatePermissionRequired =>
      'Allow this app to install unknown apps, then return to continue installation.';

  @override
  String get openInstallPermission => 'Open install permission';

  @override
  String get windowsUpdateNotice =>
      'Windows can open the GitHub Release page only. ZIP self-install is not supported in this version.';

  @override
  String get updateDialogTitle => 'New version available';

  @override
  String updateDialogMessage(Object version) {
    return 'Version $version is available.';
  }

  @override
  String publishedAtLabel(Object value) {
    return 'Published: $value';
  }

  @override
  String get later => 'Later';
}
