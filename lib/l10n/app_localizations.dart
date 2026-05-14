import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Next DDL'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// No description provided for @inProgressTab.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgressTab;

  /// No description provided for @overdueTab.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueTab;

  /// No description provided for @inProgressSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} in-progress tasks, sorted by remaining time'**
  String inProgressSummary(int count);

  /// No description provided for @overdueSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue tasks, sorted by how long they have been overdue'**
  String overdueSummary(int count);

  /// No description provided for @nextNode.
  ///
  /// In en, this message translates to:
  /// **'Next milestone'**
  String get nextNode;

  /// No description provided for @finalDeadline.
  ///
  /// In en, this message translates to:
  /// **'Final deadline'**
  String get finalDeadline;

  /// No description provided for @noFutureNodes.
  ///
  /// In en, this message translates to:
  /// **'No future milestones'**
  String get noFutureNodes;

  /// No description provided for @allExpired.
  ///
  /// In en, this message translates to:
  /// **'All expired'**
  String get allExpired;

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'Remaining time'**
  String get remainingTime;

  /// No description provided for @noTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'No deadline tasks yet'**
  String get noTasksTitle;

  /// No description provided for @noTasksBody.
  ///
  /// In en, this message translates to:
  /// **'Create your first task to see the next milestone, final deadline, and live countdown here.'**
  String get noTasksBody;

  /// No description provided for @createNow.
  ///
  /// In en, this message translates to:
  /// **'Create now'**
  String get createNow;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetails;

  /// No description provided for @taskNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found or already deleted'**
  String get taskNotFound;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @timezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Timezone: {timezone}'**
  String timezoneLabel(Object timezone);

  /// No description provided for @nextNodeValue.
  ///
  /// In en, this message translates to:
  /// **'Next milestone: {value}'**
  String nextNodeValue(Object value);

  /// No description provided for @finalDeadlineValue.
  ///
  /// In en, this message translates to:
  /// **'Final deadline: {value}'**
  String finalDeadlineValue(Object value);

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @generatedNode.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get generatedNode;

  /// No description provided for @manualNode.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualNode;

  /// No description provided for @reminderRules.
  ///
  /// In en, this message translates to:
  /// **'Reminder rules'**
  String get reminderRules;

  /// No description provided for @remindAtTime.
  ///
  /// In en, this message translates to:
  /// **'At time'**
  String get remindAtTime;

  /// No description provided for @noReminder.
  ///
  /// In en, this message translates to:
  /// **'No reminders'**
  String get noReminder;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get deleteTask;

  /// No description provided for @deleteTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get deleteTaskTitle;

  /// No description provided for @deleteTaskBody.
  ///
  /// In en, this message translates to:
  /// **'Deleting will also remove future scheduled reminders for this task.'**
  String get deleteTaskBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTask;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskTitle;

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Final thesis submission'**
  String get taskTitleHint;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Add context, deliverables, or anything you want to remember.'**
  String get noteHint;

  /// No description provided for @pickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick time'**
  String get pickTime;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable reminders'**
  String get enableNotifications;

  /// No description provided for @enableNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Android requests notification permission; Windows uses system notifications.'**
  String get enableNotificationsHint;

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @addMilestone.
  ///
  /// In en, this message translates to:
  /// **'Add milestone'**
  String get addMilestone;

  /// No description provided for @editMilestone.
  ///
  /// In en, this message translates to:
  /// **'Edit milestone'**
  String get editMilestone;

  /// No description provided for @noMilestones.
  ///
  /// In en, this message translates to:
  /// **'There are no milestones yet. The app will use the final deadline as the last key point directly.'**
  String get noMilestones;

  /// No description provided for @generated.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get generated;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @customReminder.
  ///
  /// In en, this message translates to:
  /// **'Custom reminder'**
  String get customReminder;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @createTask.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get createTask;

  /// No description provided for @taskCreated.
  ///
  /// In en, this message translates to:
  /// **'Task created'**
  String get taskCreated;

  /// No description provided for @taskUpdated.
  ///
  /// In en, this message translates to:
  /// **'Task updated'**
  String get taskUpdated;

  /// No description provided for @fillTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a task title'**
  String get fillTaskTitle;

  /// No description provided for @milestoneBeforeFinal.
  ///
  /// In en, this message translates to:
  /// **'All milestones must be earlier than the final deadline'**
  String get milestoneBeforeFinal;

  /// No description provided for @milestoneName.
  ///
  /// In en, this message translates to:
  /// **'Milestone name'**
  String get milestoneName;

  /// No description provided for @milestoneTime.
  ///
  /// In en, this message translates to:
  /// **'Milestone time'**
  String get milestoneTime;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @atTimeReminder.
  ///
  /// In en, this message translates to:
  /// **'At time'**
  String get atTimeReminder;

  /// No description provided for @advanceDays.
  ///
  /// In en, this message translates to:
  /// **'{count} day(s) early'**
  String advanceDays(int count);

  /// No description provided for @advanceHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hour(s) early'**
  String advanceHours(int count);

  /// No description provided for @advanceMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minute(s) early'**
  String advanceMinutes(int count);

  /// No description provided for @advanceSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count} second(s) early'**
  String advanceSeconds(int count);

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get currentVersion;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @taskCount.
  ///
  /// In en, this message translates to:
  /// **'Task count'**
  String get taskCount;

  /// No description provided for @taskCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} task(s)'**
  String taskCountValue(int count);

  /// No description provided for @persistentNotification.
  ///
  /// In en, this message translates to:
  /// **'Android persistent notification'**
  String get persistentNotification;

  /// No description provided for @persistentNotificationAndroidHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the most urgent task stays in the notification shade and updates automatically when tasks or settings change.'**
  String get persistentNotificationAndroidHint;

  /// No description provided for @persistentNotificationOtherHint.
  ///
  /// In en, this message translates to:
  /// **'This only works on Android. Other platforms keep the setting but do not show a persistent notification.'**
  String get persistentNotificationOtherHint;

  /// No description provided for @persistentEnabled.
  ///
  /// In en, this message translates to:
  /// **'Persistent notification enabled'**
  String get persistentEnabled;

  /// No description provided for @persistentDisabled.
  ///
  /// In en, this message translates to:
  /// **'Persistent notification disabled'**
  String get persistentDisabled;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @messageBarUnit.
  ///
  /// In en, this message translates to:
  /// **'Notification time unit'**
  String get messageBarUnit;

  /// No description provided for @unitByDay.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get unitByDay;

  /// No description provided for @unitByHour.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get unitByHour;

  /// No description provided for @appTimezone.
  ///
  /// In en, this message translates to:
  /// **'App timezone'**
  String get appTimezone;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get exportJson;

  /// No description provided for @exportJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Export all current task data for backup or migration.'**
  String get exportJsonHint;

  /// No description provided for @importJson.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get importJson;

  /// No description provided for @importJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Import replaces all local task data and rebuilds notifications.'**
  String get importJsonHint;

  /// No description provided for @exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get exportCancelled;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Exported: {path}'**
  String exportSuccess(Object path);

  /// No description provided for @importCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import cancelled'**
  String get importCancelled;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported: {count} task(s)'**
  String importSuccess(int count);

  /// No description provided for @notificationNotice.
  ///
  /// In en, this message translates to:
  /// **'Notification notes'**
  String get notificationNotice;

  /// No description provided for @windowsNotificationNotice.
  ///
  /// In en, this message translates to:
  /// **'The current Windows build is distributed as a ZIP instead of MSIX. Displayed system notifications may not be cancelled reliably, and old toasts may remain after editing tasks.'**
  String get windowsNotificationNotice;

  /// No description provided for @androidNotificationNotice.
  ///
  /// In en, this message translates to:
  /// **'On Android, enabling reminders only requests standard notification permission and no longer opens the Alarms & reminders page. Reminders are scheduled in a MIUI-friendlier way and rebuild automatically after saving, deleting, or importing tasks.'**
  String get androidNotificationNotice;

  /// No description provided for @chooseTimezone.
  ///
  /// In en, this message translates to:
  /// **'Choose app timezone'**
  String get chooseTimezone;

  /// No description provided for @searchTimezone.
  ///
  /// In en, this message translates to:
  /// **'Search timezones'**
  String get searchTimezone;

  /// No description provided for @searchTimezoneHint.
  ///
  /// In en, this message translates to:
  /// **'For example Asia/Shanghai'**
  String get searchTimezoneHint;

  /// No description provided for @timezoneUpdated.
  ///
  /// In en, this message translates to:
  /// **'App timezone updated: {timezone}'**
  String timezoneUpdated(Object timezone);

  /// No description provided for @timezoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid timezone'**
  String get timezoneInvalid;

  /// No description provided for @localeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get localeSystem;

  /// No description provided for @localeZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get localeZh;

  /// No description provided for @localeEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeEn;

  /// No description provided for @localeJa.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get localeJa;

  /// No description provided for @timezoneAsiaShanghai.
  ///
  /// In en, this message translates to:
  /// **'Shanghai'**
  String get timezoneAsiaShanghai;

  /// No description provided for @timezoneAsiaHongKong.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong'**
  String get timezoneAsiaHongKong;

  /// No description provided for @timezoneAsiaTaipei.
  ///
  /// In en, this message translates to:
  /// **'Taipei'**
  String get timezoneAsiaTaipei;

  /// No description provided for @timezoneAsiaTokyo.
  ///
  /// In en, this message translates to:
  /// **'Tokyo'**
  String get timezoneAsiaTokyo;

  /// No description provided for @timezoneAsiaSeoul.
  ///
  /// In en, this message translates to:
  /// **'Seoul'**
  String get timezoneAsiaSeoul;

  /// No description provided for @timezoneUtc.
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get timezoneUtc;

  /// No description provided for @timezoneEuropeLondon.
  ///
  /// In en, this message translates to:
  /// **'London'**
  String get timezoneEuropeLondon;

  /// No description provided for @timezoneAmericaNewYork.
  ///
  /// In en, this message translates to:
  /// **'New York'**
  String get timezoneAmericaNewYork;

  /// No description provided for @timezoneAmericaLosAngeles.
  ///
  /// In en, this message translates to:
  /// **'Los Angeles'**
  String get timezoneAmericaLosAngeles;

  /// No description provided for @ongoingNoTask.
  ///
  /// In en, this message translates to:
  /// **'No in-progress tasks right now'**
  String get ongoingNoTask;

  /// No description provided for @persistentNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Next DDL'**
  String get persistentNotificationTitle;

  /// No description provided for @fileExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Next DDL data'**
  String get fileExportDialogTitle;

  /// No description provided for @fileImportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Next DDL data'**
  String get fileImportDialogTitle;

  /// No description provided for @notificationPersistentChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Persistent status notification for Next DDL'**
  String get notificationPersistentChannelDescription;

  /// No description provided for @notificationMessageChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Deadline milestone and final deadline reminders'**
  String get notificationMessageChannelDescription;

  /// No description provided for @notificationNowDue.
  ///
  /// In en, this message translates to:
  /// **'Due now · {title}'**
  String notificationNowDue(Object title);

  /// No description provided for @notificationAdvanceDue.
  ///
  /// In en, this message translates to:
  /// **'{offset} early · {title}'**
  String notificationAdvanceDue(Object offset, Object title);

  /// No description provided for @compactDaySuffix.
  ///
  /// In en, this message translates to:
  /// **' days'**
  String get compactDaySuffix;

  /// No description provided for @compactHourSuffix.
  ///
  /// In en, this message translates to:
  /// **' hours'**
  String get compactHourSuffix;

  /// No description provided for @countdownDaySuffix.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get countdownDaySuffix;

  /// No description provided for @countdownOverduePrefix.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get countdownOverduePrefix;

  /// No description provided for @generatedMilestoneTitle.
  ///
  /// In en, this message translates to:
  /// **'{percent}% checkpoint'**
  String generatedMilestoneTitle(int percent);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
