import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/alarm_audio_item.dart';
import 'package:next_ddl/models/app_alarm_settings.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/app_theme_settings.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/models/update_release.dart';
import 'package:next_ddl/l10n/app_localizations_en.dart';
import 'package:next_ddl/l10n/app_localizations_ja.dart';
import 'package:next_ddl/l10n/app_localizations_zh.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:next_ddl/utils/countdown_formatter.dart';
import 'package:next_ddl/utils/deadline_logic.dart';
import 'package:next_ddl/utils/milestone_utils.dart';
import 'package:next_ddl/utils/timezone_labels.dart';
import 'package:next_ddl/utils/version_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  test('snapshot json round trip keeps task data', () {
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: DateTime.parse('2026-01-02T00:00:00.000Z'),
      persistentNotificationEnabled: true,
      preferredLocale: AppLocalePreference.ja,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.hour,
      tasks: [
        DeadlineTask(
          id: 'task_1',
          title: '毕业设计',
          note: '最终答辩',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: DateTime.parse('2026-01-01T00:00:00.000Z'),
          updatedAtUtc: DateTime.parse('2026-01-02T00:00:00.000Z'),
          finalDueAtUtc: DateTime.parse('2026-02-01T12:00:00.000Z'),
          milestones: [
            Milestone(
              id: 'm1',
              title: '开题',
              dueAtUtc: DateTime.parse('2026-01-10T12:00:00.000Z'),
              source: MilestoneSource.manual,
            ),
          ],
          reminderOffsetsSeconds: const [0, 3600, 86400],
          notificationsEnabled: true,
          alarmEnabled: true,
          alarmAudioItemsOverride: const [
            AlarmAudioItem(
              id: 'audio_task',
              displayName: 'Task tone',
              uri: 'content://task-tone',
            ),
          ],
        ),
      ],
      themeSettings: const AppThemeSettings(
        seedColorValue: 0xFF112233,
        cornerRadius: 14,
        backgroundMode: ThemeBackgroundMode.gradient,
        imageRotationDegrees: 37,
      ),
      alarmSettings: const AppAlarmSettings(
        enabled: true,
        globalAudioItems: [
          AlarmAudioItem(
            id: 'audio_global',
            displayName: 'Global tone',
            uri: 'content://global-tone',
          ),
        ],
      ),
    );

    final decoded = AppSnapshot.fromJson(snapshot.toJson());

    expect(decoded.schemaVersion, 1);
    expect(decoded.persistentNotificationEnabled, isTrue);
    expect(decoded.preferredLocale, AppLocalePreference.ja);
    expect(
      decoded.persistentNotificationTimeUnit,
      PersistentNotificationTimeUnit.hour,
    );
    expect(decoded.tasks.single.title, '毕业设计');
    expect(decoded.tasks.single.reminderOffsetsSeconds, [0, 3600, 86400]);
    expect(decoded.tasks.single.milestones.single.title, '开题');
    expect(decoded.tasks.single.alarmEnabled, isTrue);
    expect(
      decoded.tasks.single.alarmAudioItemsOverride.single.uri,
      'content://task-tone',
    );
    expect(decoded.themeSettings.cornerRadius, 14);
    expect(decoded.themeSettings.backgroundMode, ThemeBackgroundMode.gradient);
    expect(decoded.themeSettings.imageRotationDegrees, 37);
    expect(decoded.alarmSettings.enabled, isTrue);
    expect(
      decoded.alarmSettings.globalAudioItems.single.uri,
      'content://global-tone',
    );
  });

  test('legacy snapshot json falls back to default locale and time unit', () {
    final decoded = AppSnapshot.fromJson({
      'schemaVersion': 1,
      'exportedAtUtc': '2026-01-02T00:00:00.000Z',
      'tasks': const [],
    });

    expect(decoded.preferredLocale, AppLocalePreference.system);
    expect(
      decoded.persistentNotificationTimeUnit,
      PersistentNotificationTimeUnit.day,
    );
    expect(decoded.persistentNotificationEnabled, isFalse);
    expect(decoded.themeSettings.seedColorValue, 0xFF0E7490);
    expect(decoded.alarmSettings.enabled, isFalse);
  });

  test('legacy theme rotation quarter turns migrate to rotation degrees', () {
    final decoded = AppThemeSettings.fromJson({'imageRotationQuarterTurns': 3});

    expect(decoded.imageRotationDegrees, 270);
    expect(decoded.imageRotationQuarterTurns, 3);
  });

  test('generate default milestones creates 25 50 75 markers', () {
    final now = DateTime.utc(2026, 1, 1);
    final milestones = generateQuarterMilestones(
      nowUtc: now,
      finalDueAtUtc: DateTime.utc(2026, 1, 9),
      taskId: 'task_1',
      titleBuilder: (percent) => '$percent% checkpoint',
    );

    expect(milestones.length, 3);
    expect(milestones[0].title, '25% checkpoint');
    expect(milestones[1].title, '50% checkpoint');
    expect(milestones[2].title, '75% checkpoint');
    expect(
      milestones.every((item) => item.source == MilestoneSource.generated),
      isTrue,
    );
  });

  test('remaining progress counts down from creation to final deadline', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final task = DeadlineTask(
      id: 'task_1',
      title: '毕业设计',
      note: '',
      timezoneId: 'Asia/Shanghai',
      createdAtUtc: createdAt,
      updatedAtUtc: createdAt,
      finalDueAtUtc: DateTime.utc(2026, 1, 11),
      milestones: const [],
      reminderOffsetsSeconds: const [],
      notificationsEnabled: false,
    );

    expect(resolveRemainingProgress(task, createdAt), 1);
    expect(resolveRemainingProgress(task, DateTime.utc(2026, 1, 6)), 0.5);
    expect(resolveRemainingProgress(task, DateTime.utc(2026, 1, 11)), 0);
    expect(resolveRemainingProgress(task, DateTime.utc(2026, 1, 12)), 0);
  });

  test('remaining progress handles invalid task time range', () {
    final now = DateTime.utc(2026, 1, 1);
    final futureTask = DeadlineTask(
      id: 'task_1',
      title: '未来任务',
      note: '',
      timezoneId: 'Asia/Shanghai',
      createdAtUtc: DateTime.utc(2026, 1, 2),
      updatedAtUtc: now,
      finalDueAtUtc: DateTime.utc(2026, 1, 1, 12),
      milestones: const [],
      reminderOffsetsSeconds: const [],
      notificationsEnabled: false,
    );
    final overdueTask = futureTask.copyWith(
      finalDueAtUtc: DateTime.utc(2025, 12, 31),
    );

    expect(resolveRemainingProgress(futureTask, now), 1);
    expect(resolveRemainingProgress(overdueTask, now), 0);
  });

  test('active deadline point prefers nearest future milestone', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final task = DeadlineTask(
      id: 'task_1',
      title: '论文',
      note: '',
      timezoneId: 'Asia/Shanghai',
      createdAtUtc: now,
      updatedAtUtc: now,
      finalDueAtUtc: now.add(const Duration(days: 3)),
      milestones: [
        Milestone(
          id: 'm_overdue',
          title: '已过期节点',
          dueAtUtc: now.subtract(const Duration(hours: 2)),
          source: MilestoneSource.manual,
        ),
        Milestone(
          id: 'm_next',
          title: '最近节点',
          dueAtUtc: now.add(const Duration(hours: 6)),
          source: MilestoneSource.manual,
        ),
      ],
      reminderOffsetsSeconds: const [],
      notificationsEnabled: false,
    );

    expect(
      resolveActiveDeadlinePoint(task, now),
      now.add(const Duration(hours: 6)),
    );
  });

  test('in progress and overdue tasks are grouped and sorted separately', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final tasks = [
      DeadlineTask(
        id: 'final_soon',
        title: '最终截止更近',
        note: '',
        timezoneId: 'Asia/Shanghai',
        createdAtUtc: now,
        updatedAtUtc: now,
        finalDueAtUtc: now.add(const Duration(hours: 8)),
        milestones: const [],
        reminderOffsetsSeconds: const [],
        notificationsEnabled: false,
      ),
      DeadlineTask(
        id: 'milestone_soon',
        title: '节点更近',
        note: '',
        timezoneId: 'Asia/Shanghai',
        createdAtUtc: now,
        updatedAtUtc: now.add(const Duration(minutes: 10)),
        finalDueAtUtc: now.add(const Duration(days: 3)),
        milestones: [
          Milestone(
            id: 'm1',
            title: '阶段检查',
            dueAtUtc: now.add(const Duration(hours: 2)),
            source: MilestoneSource.manual,
          ),
        ],
        reminderOffsetsSeconds: const [],
        notificationsEnabled: false,
      ),
      DeadlineTask(
        id: 'overdue_old',
        title: '更早过期',
        note: '',
        timezoneId: 'Asia/Shanghai',
        createdAtUtc: now,
        updatedAtUtc: now,
        finalDueAtUtc: now.subtract(const Duration(days: 2)),
        milestones: const [],
        reminderOffsetsSeconds: const [],
        notificationsEnabled: false,
      ),
      DeadlineTask(
        id: 'overdue_new',
        title: '刚过期',
        note: '',
        timezoneId: 'Asia/Shanghai',
        createdAtUtc: now,
        updatedAtUtc: now,
        finalDueAtUtc: now.subtract(const Duration(hours: 1)),
        milestones: const [],
        reminderOffsetsSeconds: const [],
        notificationsEnabled: false,
      ),
    ];

    expect(
      sortInProgressTasks(
        inProgressTasks(tasks, now),
        now,
      ).map((task) => task.id).toList(),
      ['milestone_soon', 'final_soon'],
    );
    expect(
      sortOverdueTasks(
        overdueTasks(tasks, now),
      ).map((task) => task.id).toList(),
      ['overdue_old', 'overdue_new'],
    );
    expect(resolveMostUrgentInProgressTask(tasks, now)?.id, 'milestone_soon');
  });

  test('compact countdown formats day and hour units for notifications', () {
    final duration = const Duration(hours: 79);

    expect(
      formatCompactCountdown(
        duration,
        timeUnit: PersistentNotificationTimeUnit.day,
      ),
      '3.3天',
    );
    expect(
      formatCompactCountdown(
        duration,
        timeUnit: PersistentNotificationTimeUnit.hour,
      ),
      '79小时',
    );
  });

  test('empty milestone title stays empty instead of using a placeholder', () {
    expect(resolveMilestoneDisplayTitle(''), '');
    expect(resolveMilestoneDisplayTitle('  '), '');
  });

  test(
    'persistent notification title prefers next milestone then task title',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final taskWithMilestone = DeadlineTask(
        id: 'task_1',
        title: '论文终稿',
        note: '',
        timezoneId: 'Asia/Shanghai',
        createdAtUtc: now,
        updatedAtUtc: now,
        finalDueAtUtc: now.add(const Duration(days: 2)),
        milestones: [
          Milestone(
            id: 'm1',
            title: '阶段检查',
            dueAtUtc: now.add(const Duration(hours: 2)),
            source: MilestoneSource.manual,
          ),
        ],
        reminderOffsetsSeconds: const [],
        notificationsEnabled: false,
      );
      final taskWithoutMilestone = taskWithMilestone.copyWith(
        milestones: const [],
      );
      final taskWithBlankMilestone = taskWithMilestone.copyWith(
        milestones: [
          Milestone(
            id: 'm1',
            title: '   ',
            dueAtUtc: now.add(const Duration(hours: 2)),
            source: MilestoneSource.manual,
          ),
        ],
      );

      expect(
        resolvePersistentNotificationTargetTitle(taskWithMilestone, now),
        '阶段检查',
      );
      expect(
        resolvePersistentNotificationTargetTitle(taskWithoutMilestone, now),
        '论文终稿',
      );
      expect(
        resolvePersistentNotificationTargetTitle(taskWithBlankMilestone, now),
        '论文终稿',
      );
    },
  );

  test('timezone fallback labels are localized for zh en ja', () {
    expect(
      localizedTimezoneDisplayName(
        AppLocalizationsZh(),
        'America/Argentina/Buenos_Aires',
      ),
      'Buenos Aires（美洲 / Argentina）',
    );
    expect(
      localizedTimezoneDisplayName(
        AppLocalizationsEn(),
        'America/Argentina/Buenos_Aires',
      ),
      'Buenos Aires (America / Argentina)',
    );
    expect(
      localizedTimezoneDisplayName(
        AppLocalizationsJa(),
        'America/Argentina/Buenos_Aires',
      ),
      'Buenos Aires（アメリカ / Argentina）',
    );
  });

  test('semantic version comparison ignores leading v', () {
    expect(isNewerSemanticVersion('v1.1.2', '1.1.1'), isTrue);
    expect(isNewerSemanticVersion('v1.1.2', '1.1.2'), isFalse);
  });

  test('update release parses github latest release payload', () {
    final release = UpdateRelease.fromJson({
      'tag_name': 'v1.1.2',
      'published_at': '2026-01-02T00:00:00.000Z',
      'body': 'Release notes',
      'html_url': 'https://example.com/release',
      'assets': [
        {
          'name': 'app-release.apk',
          'browser_download_url': 'https://example.com/app-release.apk',
          'content_type': 'application/vnd.android.package-archive',
          'size': 123,
        },
      ],
    });

    expect(release.version, '1.1.2');
    expect(release.androidApkAsset?.name, 'app-release.apk');
    expect(release.htmlUrl, 'https://example.com/release');
  });

  test('windows update branch uses release html url', () {
    final release = UpdateRelease(
      tagName: 'v1.1.2',
      version: '1.1.2',
      publishedAtUtc: DateTime.utc(2026, 1, 2),
      body: '',
      htmlUrl: 'https://github.com/MT-Y-TM/next_ddl/releases/tag/v1.1.2',
      assets: const [],
    );

    expect(
      release.htmlUrl,
      'https://github.com/MT-Y-TM/next_ddl/releases/tag/v1.1.2',
    );
  });

  test('configured timezone converts selected wall time to utc', () async {
    SharedPreferences.setMockInitialValues({
      DeviceTimezoneService.storageKey: 'Asia/Shanghai',
    });
    final service = DeviceTimezoneService();
    await service.initialize();

    final utc = service.localToUtc(DateTime(2026, 1, 1, 20));

    expect(utc, DateTime.utc(2026, 1, 1, 12));
  });

  test('configured timezone converts utc to selected wall time', () async {
    SharedPreferences.setMockInitialValues({
      DeviceTimezoneService.storageKey: 'Asia/Shanghai',
    });
    final service = DeviceTimezoneService();
    await service.initialize();

    final local = service.utcToConfigured(DateTime.utc(2026, 1, 1, 12));

    expect(local.year, 2026);
    expect(local.month, 1);
    expect(local.day, 1);
    expect(local.hour, 20);
  });

  test('invalid configured timezone is ignored', () async {
    SharedPreferences.setMockInitialValues({
      DeviceTimezoneService.storageKey: 'Asia/Shanghai',
    });
    final service = DeviceTimezoneService();
    await service.initialize();

    final changed = await service.setTimezone('Not/A_Timezone');

    expect(changed, isFalse);
    expect(service.currentTimezoneId, 'Asia/Shanghai');
  });
}
