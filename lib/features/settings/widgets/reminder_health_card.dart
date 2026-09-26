import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_alarm_settings.dart';
import '../../../models/deadline_task.dart';
import '../../../services/reminder_health_service.dart';
import 'reminder_health_strings.dart';

class ReminderHealthCard extends ConsumerStatefulWidget {
  const ReminderHealthCard({
    required this.tasks,
    required this.settings,
    this.enabled = true,
    this.service,
    super.key,
  });

  final List<DeadlineTask> tasks;
  final AppAlarmSettings settings;
  final bool enabled;
  final ReminderHealthService? service;

  @override
  ConsumerState<ReminderHealthCard> createState() => _ReminderHealthCardState();
}

class _ReminderHealthCardState extends ConsumerState<ReminderHealthCard>
    with WidgetsBindingObserver {
  ReminderHealthReport? _report;
  ReminderActionResult? _result;
  bool _loading = true;
  bool _acting = false;
  bool _failed = false;
  int _generation = 0;

  ReminderHealthService get _service =>
      widget.service ?? ref.read(reminderHealthServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant ReminderHealthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks ||
        oldWidget.settings != widget.settings ||
        oldWidget.service != widget.service) {
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    super.dispose();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _report = null;
    });
    try {
      final report = await _service.inspect(
        tasks: widget.tasks,
        settings: widget.settings,
      );
      if (mounted && generation == _generation) {
        setState(() => _report = report);
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _act(
    Future<ReminderActionResult> Function() action, {
    bool stop = false,
  }) async {
    if (_acting && !stop) return;
    if (!stop) setState(() => _acting = true);
    ReminderActionResult result;
    try {
      result = await action();
    } catch (_) {
      result = ReminderActionResult.failed;
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      if (!stop) _acting = false;
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = ReminderHealthStrings(Localizations.localeOf(context));
    final service = _service;
    final report = _report;
    final canAct = widget.enabled && !_acting;
    final testAudio = [
      ...widget.settings.globalAudioItems,
      for (final task in widget.tasks.where(
        (t) => !t.isCompleted && t.alarmEnabled,
      ))
        ...task.alarmAudioItemsOverride,
    ].take(1).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${s.global}: ${s.enabled(widget.settings.enabled)}'),
            if (_loading) const LinearProgressIndicator(),
            if (_failed) Text(s.failedCheck),
            if (report != null) ...[
              Text(
                '${s.notification}: ${s.permission(report.notificationPermission)}',
              ),
              Text('${s.exact}: ${s.permission(report.exactAlarmPermission)}'),
              const SizedBox(height: 12),
              Text(s.planned, style: Theme.of(context).textTheme.titleSmall),
              _expected(context, s, report.nextNotification, s.noNotification),
              _expected(context, s, report.nextAlarm, s.noAlarm),
              const SizedBox(height: 12),
              Text(
                s.registration,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(s.pending(report.pendingNotificationCount)),
              Text(s.alarms(report.pendingAlarmCount)),
              Text(s.registrationHint),
              const SizedBox(height: 12),
              Text(s.audio, style: Theme.of(context).textTheme.titleSmall),
              if (report.audio.isEmpty) Text(s.noAudio),
              for (final check in report.audio)
                Text('${check.item.displayName}: ${s.audioState(check.state)}'),
            ],
            const SizedBox(height: 12),
            Text(s.testHint),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: !_loading ? _refresh : null,
                  child: Text(s.refresh),
                ),
                OutlinedButton(
                  onPressed: canAct
                      ? () => _act(
                          () => service.testNotification(
                            title: s.testNotification,
                            body: s.testBody,
                          ),
                        )
                      : null,
                  child: Text(s.testNotification),
                ),
                OutlinedButton(
                  onPressed: canAct
                      ? () => _act(
                          () => service.testAlarm(
                            audio: testAudio,
                            title: s.testAlarm,
                          ),
                        )
                      : null,
                  child: Text(s.testAlarm),
                ),
                // Keep the stop control available during a slow/failing test request.
                OutlinedButton(
                  onPressed: () => _act(service.stopAlarm, stop: true),
                  child: Text(s.stop),
                ),
                if (service.platform == TargetPlatform.android) ...[
                  TextButton(
                    onPressed: canAct
                        ? () => _act(service.requestNotificationPermission)
                        : null,
                    child: Text(s.request),
                  ),
                  TextButton(
                    onPressed: canAct
                        ? () => _act(service.openNotificationSettings)
                        : null,
                    child: Text(s.notificationSettings),
                  ),
                  TextButton(
                    onPressed: canAct
                        ? () => _act(service.openExactAlarmSettings)
                        : null,
                    child: Text(s.exactSettings),
                  ),
                ],
              ],
            ),
            if (_result != null)
              Semantics(liveRegion: true, child: Text(s.result(_result!))),
            const SizedBox(height: 8),
            Text(
              !service.supported
                  ? s.unsupportedPlatform
                  : service.platform == TargetPlatform.android
                  ? s.androidHint
                  : s.windowsHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _expected(
    BuildContext context,
    ReminderHealthStrings s,
    ExpectedReminder? reminder,
    String empty,
  ) {
    if (reminder == null) return Text(empty);
    final local = reminder.atUtc.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatFullDate(local);
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final node = reminder.nodeTitle == null
        ? s.finalDeadline
        : reminder.nodeTitle!.trim().isEmpty
        ? s.unnamedNode
        : reminder.nodeTitle!;
    return Text(
      '${s.kind(reminder.kind)}: ${reminder.taskTitle} / $node\n$date $time (${local.timeZoneName})',
    );
  }
}
