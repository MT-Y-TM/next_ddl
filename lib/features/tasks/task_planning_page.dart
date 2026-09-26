import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../models/deadline_task.dart';
import '../../models/task_recurrence.dart';
import '../../models/task_template.dart';
import '../../services/task_planning_service.dart';
import 'task_planning_strings.dart';

/// Host owns/initializes the service and pushes this page on its root Navigator.
/// This widget never materializes instances automatically.
class TaskPlanningPage extends StatefulWidget {
  const TaskPlanningPage({
    super.key,
    required this.service,
    this.sourceTasks = const [],
    this.timezoneId = 'UTC',
  });
  final TaskPlanningService service;
  final List<DeadlineTask> sourceTasks;
  final String timezoneId;
  @override
  State<TaskPlanningPage> createState() => _TaskPlanningPageState();
}

class _TaskPlanningPageState extends State<TaskPlanningPage> {
  bool _busy = false;
  TaskPlanningStrings get s =>
      TaskPlanningStrings(Localizations.localeOf(context));
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.text('error'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String key) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(s.text(key)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.text('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.text('save')),
            ),
          ],
        ),
      ) ??
      false;

  Future<_PlanningEdit?> _editor(
    TaskTemplate? template, {
    TaskRecurrenceRule? rule,
    bool schedule = false,
    bool repeat = false,
    String? fromDate,
  }) => showDialog<_PlanningEdit>(
    context: context,
    builder: (_) => _PlanningEditor(
      template: template,
      rule: rule,
      timezoneId: widget.timezoneId,
      schedule: schedule,
      repeat: repeat,
      fromDate: fromDate,
    ),
  );

  Future<void> _templatePreview(TaskTemplate template) async {
    final edit = await _editor(template, schedule: true);
    if (edit == null || !mounted) return;
    final rule = edit.rule!;
    final due = rule.dueOn(parsePlanningDate(rule.startDate));
    if (due == null) throw StateError('DST gap');
    final task = widget.service.previewTemplate(
      edit.template,
      due,
      rule.timezoneId,
    );
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.note),
              Text(
                '${tz.TZDateTime.from(due, tz.getLocation(rule.timezoneId))} (${rule.timezoneId})',
              ),
              for (final m in task.milestones)
                Text(
                  '${m.title}: ${tz.TZDateTime.from(m.dueAtUtc, tz.getLocation(rule.timezoneId))}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.text('create')),
          ),
        ],
      ),
    );
    if (create == true) await widget.service.createFromPreview(task);
  }

  Future<void> _series(
    TaskTemplate template, {
    TaskRecurrence? existing,
  }) async {
    final latest = existing?.revisions.last;
    final edit = await _editor(
      template,
      rule: latest?.rule,
      schedule: true,
      repeat: true,
      fromDate: existing == null ? null : _nextUnissuedDate(existing),
    );
    if (edit == null) return;
    final revision = RecurrenceRevision(
      fromDate: edit.rule!.startDate,
      rule: edit.rule!,
      template: edit.template,
    );
    if (existing == null) {
      await widget.service.createSeries(
        TaskRecurrence(id: TaskPlanningService.newId(), revisions: [revision]),
      );
    } else {
      await widget.service.editFollowing(existing.id, revision);
    }
  }

  String _nextUnissuedDate(TaskRecurrence series) {
    final zone = tz.getLocation(series.revisions.last.rule.timezoneId);
    var date = planningDateKey(
      tz.TZDateTime.from(widget.service.clock(), zone),
    );
    final prefix = 'planning/${Uri.encodeComponent(series.id)}/';
    for (final id in widget.service.snapshot.issued.where(
      (id) => id.startsWith(prefix),
    )) {
      final next = planningDateKey(
        parsePlanningDate(
          id.substring(prefix.length),
        ).add(const Duration(days: 1)),
      );
      if (next.compareTo(date) > 0) date = next;
    }
    return date;
  }

  Future<void> _onlyThis(
    TaskRecurrence series,
    String date,
    DeadlineTask task,
  ) async {
    final local = tz.TZDateTime.from(
      task.finalDueAtUtc,
      tz.getLocation(task.timezoneId),
    );
    final edit = await _editor(
      TaskTemplate.fromTask(task, id: 'edit'),
      schedule: true,
      rule: TaskRecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        timezoneId: task.timezoneId,
        startDate: planningDateKey(local),
        hour: local.hour,
        minute: local.minute,
      ),
    );
    if (edit == null) return;
    final rule = edit.rule!;
    final due = rule.dueOn(parsePlanningDate(rule.startDate));
    if (due == null) throw StateError('DST gap');
    final preview = widget.service.previewTemplate(
      edit.template,
      due,
      rule.timezoneId,
      taskId: task.id,
    );
    await widget.service.editOnlyThis(
      series.id,
      date,
      task.copyWith(
        title: preview.title,
        note: preview.note,
        finalDueAtUtc: preview.finalDueAtUtc,
        timezoneId: preview.timezoneId,
        notificationsEnabled: preview.notificationsEnabled,
        alarmEnabled: preview.alarmEnabled,
        reminderOffsetsSeconds: preview.reminderOffsetsSeconds,
        milestones: [
          for (var i = 0; i < preview.milestones.length; i++)
            i < task.milestones.length
                ? preview.milestones[i].copyWith(
                    id: task.milestones[i].id,
                    completedAtUtc: task.milestones[i].completedAtUtc,
                  )
                : preview.milestones[i],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final snapshot = widget.service.snapshot;
      final upcoming = widget.service.preview(nowUtc: widget.service.clock());
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(s.text('title'))),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              Text(s.text('policy')),
              const SizedBox(height: 16),
              Text(
                s.text('templates'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => _run(() async {
                      final edit = await _editor(null);
                      if (edit != null) {
                        await widget.service.saveTemplate(edit.template);
                      }
                    }),
                    child: Text(s.text('new')),
                  ),
                  if (widget.sourceTasks.isNotEmpty)
                    OutlinedButton(
                      onPressed: () => _run(() async {
                        final task = await showDialog<DeadlineTask>(
                          context: context,
                          builder: (context) => SimpleDialog(
                            title: Text(s.text('fromTask')),
                            children: [
                              for (final task in widget.sourceTasks)
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(context, task),
                                  child: Text(task.title),
                                ),
                            ],
                          ),
                        );
                        if (task != null) {
                          await widget.service.saveTemplate(
                            TaskTemplate.fromTask(
                              task,
                              id: TaskPlanningService.newId(),
                            ),
                          );
                        }
                      }),
                      child: Text(s.text('fromTask')),
                    ),
                ],
              ),
              if (snapshot.templates.isEmpty) Text(s.text('empty')),
              for (final template in snapshot.templates.values)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(template.note),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _run(() async {
                                final edit = await _editor(template);
                                if (edit != null) {
                                  await widget.service.saveTemplate(
                                    edit.template,
                                  );
                                }
                              }),
                              child: Text(s.text('edit')),
                            ),
                            TextButton(
                              onPressed: () => _run(() async {
                                if (await _confirm('confirmDelete')) {
                                  await widget.service.deleteTemplate(
                                    template.id,
                                  );
                                }
                              }),
                              child: Text(s.text('delete')),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _run(() => _templatePreview(template)),
                              child: Text(s.text('preview')),
                            ),
                            TextButton(
                              onPressed: () => _run(() => _series(template)),
                              child: Text(s.text('repeat')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Text(
                s.text('series'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(s.text('followingPolicy')),
              for (final series in snapshot.series.values)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${series.revisions.last.template.title} · ${s.text(series.status.name)}',
                        ),
                        Text(
                          '${s.text(series.revisions.last.rule.frequency.name)} · ${series.revisions.last.rule.timezoneId}',
                        ),
                        if (series.status != RecurrenceStatus.terminated)
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: () => _run(
                                  () => widget.service.setStatus(
                                    series.id,
                                    series.status == RecurrenceStatus.active
                                        ? RecurrenceStatus.paused
                                        : RecurrenceStatus.active,
                                  ),
                                ),
                                child: Text(
                                  s.text(
                                    series.status == RecurrenceStatus.active
                                        ? 'pause'
                                        : 'resume',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _run(() async {
                                  if (await _confirm('confirmTerminate')) {
                                    await widget.service.setStatus(
                                      series.id,
                                      RecurrenceStatus.terminated,
                                    );
                                  }
                                }),
                                child: Text(s.text('terminate')),
                              ),
                              TextButton(
                                onPressed: () => _run(
                                  () => _series(
                                    series.revisions.last.template,
                                    existing: series,
                                  ),
                                ),
                                child: Text(s.text('following')),
                              ),
                            ],
                          ),
                        Text(s.text('instances')),
                        for (final id in snapshot.issued.where(
                          (id) => id.startsWith(
                            'planning/${Uri.encodeComponent(series.id)}/',
                          ),
                        ))
                          if (widget.service.findTask(id) case final task?)
                            ListTile(
                              title: Text(task.title),
                              subtitle: Text(id.split('/').last),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => _run(() async {
                                  final date = id.split('/').last;
                                  if (action == 'onlyThis') {
                                    await _onlyThis(series, date, task);
                                  } else if (await _confirm('confirmSkip')) {
                                    await widget.service.skip(series.id, date);
                                  }
                                }),
                                itemBuilder: (_) => [
                                  for (final key in ['onlyThis', 'skip'])
                                    PopupMenuItem(
                                      value: key,
                                      child: Text(s.text(key)),
                                    ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              Text(
                s.text('upcoming'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final occurrence in upcoming)
                ListTile(
                  title: Text(occurrence.task.title),
                  subtitle: Text(
                    '${occurrence.date} · ${tz.TZDateTime.from(occurrence.task.finalDueAtUtc, tz.getLocation(occurrence.task.timezoneId))}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _run(() async {
                      if (await _confirm('confirmSkip')) {
                        await widget.service.skip(
                          occurrence.seriesId,
                          occurrence.date,
                        );
                      }
                    }),
                    child: Text(s.text('skip')),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _PlanningEdit {
  const _PlanningEdit(this.template, this.rule);
  final TaskTemplate template;
  final TaskRecurrenceRule? rule;
}

class _PlanningEditor extends StatefulWidget {
  const _PlanningEditor({
    this.template,
    this.rule,
    required this.timezoneId,
    required this.schedule,
    required this.repeat,
    this.fromDate,
  });
  final TaskTemplate? template;
  final TaskRecurrenceRule? rule;
  final String timezoneId;
  final bool schedule;
  final bool repeat;
  final String? fromDate;
  @override
  State<_PlanningEditor> createState() => _PlanningEditorState();
}

class _PlanningEditorState extends State<_PlanningEditor> {
  final fields = <String, TextEditingController>{};
  late RecurrenceFrequency frequency;
  late bool notifications, alarm, clamp;
  bool invalid = false;
  @override
  void initState() {
    super.initState();
    final t = widget.template;
    final r = widget.rule;
    frequency = r?.frequency ?? RecurrenceFrequency.daily;
    notifications = t?.notificationsEnabled ?? false;
    alarm = t?.alarmEnabled ?? false;
    clamp = r?.monthEndPolicy == MonthEndPolicy.lastDay;
    final zone = r?.timezoneId ?? widget.timezoneId;
    final now = tz.TZDateTime.now(tz.getLocation(zone));
    final values = {
      'name': t?.title ?? '',
      'note': t?.note ?? '',
      'nodes':
          t?.milestones
              .map((m) => '${m.title}|${-m.offsetSeconds / 60}')
              .join('\n') ??
          '',
      'reminders': t?.reminderOffsetsSeconds.join(',') ?? '',
      'date': widget.fromDate ?? r?.startDate ?? planningDateKey(now),
      'endDate': r?.endDate ?? '',
      'time':
          '${(r?.hour ?? 9).toString().padLeft(2, '0')}:${(r?.minute ?? 0).toString().padLeft(2, '0')}',
      'zone': zone,
      'weekdays': (r?.weekdays ?? {1}).join(','),
      'monthDay': '${r?.monthDay ?? 1}',
    };
    for (final entry in values.entries) {
      fields[entry.key] = TextEditingController(text: entry.value);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String value(String key) => fields[key]!.text.trim();
  void save() {
    try {
      final nodes = value('nodes').isEmpty
          ? <TemplateMilestone>[]
          : value('nodes').split('\n').map((line) {
              final split = line.lastIndexOf('|');
              if (split < 0) throw const FormatException();
              return TemplateMilestone(
                title: line.substring(0, split),
                offsetSeconds: -(double.parse(line.substring(split + 1)) * 60)
                    .round(),
              );
            }).toList();
      final template = TaskTemplate(
        id: widget.template?.id ?? TaskPlanningService.newId(),
        title: value('name'),
        note: value('note'),
        milestones: nodes,
        reminderOffsetsSeconds: value('reminders').isEmpty
            ? []
            : value(
                'reminders',
              ).split(',').map((v) => int.parse(v.trim())).toList(),
        notificationsEnabled: notifications,
        alarmEnabled: alarm,
        alarmAudioItems: widget.template?.alarmAudioItems ?? [],
      );
      TaskRecurrenceRule? rule;
      if (widget.schedule) {
        final time = value('time').split(':');
        if (time.length != 2) throw const FormatException();
        rule = TaskRecurrenceRule(
          frequency: widget.repeat ? frequency : RecurrenceFrequency.daily,
          endDate: widget.repeat && value('endDate').isNotEmpty
              ? value('endDate')
              : null,
          timezoneId: value('zone'),
          startDate: value('date'),
          hour: int.parse(time[0]),
          minute: int.parse(time[1]),
          weekdays: value(
            'weekdays',
          ).split(',').map((v) => int.parse(v.trim())).toSet(),
          monthDay: int.parse(value('monthDay')),
          monthEndPolicy: clamp ? MonthEndPolicy.lastDay : MonthEndPolicy.skip,
        );
      }
      Navigator.pop(context, _PlanningEdit(template, rule));
    } catch (_) {
      setState(() => invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = TaskPlanningStrings(Localizations.localeOf(context));
    Widget field(String key, {int lines = 1}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: fields[key],
        maxLines: lines,
        decoration: InputDecoration(labelText: s.text(key)),
      ),
    );
    return AlertDialog(
      title: Text(s.text(widget.repeat ? 'repeat' : 'edit')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field('name'),
              field('note', lines: 3),
              field('nodes', lines: 4),
              field('reminders'),
              SwitchListTile(
                title: Text(s.text('notifications')),
                value: notifications,
                onChanged: (v) => setState(() => notifications = v),
              ),
              SwitchListTile(
                title: Text(s.text('alarm')),
                value: alarm,
                onChanged: (v) => setState(() => alarm = v),
              ),
              if (widget.schedule) ...[
                field('date'),
                field('time'),
                field('zone'),
              ],
              if (widget.repeat) ...[
                field('endDate'),
                DropdownButton<RecurrenceFrequency>(
                  value: frequency,
                  isExpanded: true,
                  items: [
                    for (final f in RecurrenceFrequency.values)
                      DropdownMenuItem(value: f, child: Text(s.text(f.name))),
                  ],
                  onChanged: (v) => setState(() => frequency = v!),
                ),
                if (frequency == RecurrenceFrequency.weekly) field('weekdays'),
                if (frequency == RecurrenceFrequency.monthly) ...[
                  field('monthDay'),
                  SwitchListTile(
                    title: Text(s.text('clamp')),
                    value: clamp,
                    onChanged: (v) => setState(() => clamp = v),
                  ),
                ],
                Text(s.text('policy')),
              ],
              if (invalid)
                Text(
                  s.text('error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.text('cancel')),
        ),
        FilledButton(onPressed: save, child: Text(s.text('save'))),
      ],
    );
  }
}
