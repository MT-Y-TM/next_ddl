import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../models/deadline_task.dart';
import '../../models/milestone.dart';
import '../../services/timezone_service.dart';
import '../../utils/locale_utils.dart';
import '../../utils/milestone_utils.dart';
import 'tasks_controller.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  const TaskEditPage({this.existingTask, super.key});

  final DeadlineTask? existingTask;

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _finalDueLocal;
  late List<Milestone> _milestones;
  late List<int> _reminders;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _noteController = TextEditingController(text: task?.note ?? '');
    final timezoneService = ref.read(timezoneServiceProvider);
    _finalDueLocal = timezoneService.utcToConfigured(
      task?.finalDueAtUtc ??
          DateTime.now().toUtc().add(const Duration(days: 3)),
    );
    _milestones = [...(task?.milestones ?? const [])];
    _reminders = [...(task?.reminderOffsetsSeconds ?? const [0])];
    _notificationsEnabled = task?.notificationsEnabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTask != null;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? l10n.editTask : l10n.newTask)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.taskTitle,
              hintText: l10n.taskTitleHint,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.note,
              hintText: l10n.noteHint,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.finalDeadline),
            subtitle: Text(_formatDateTime(_finalDueLocal)),
            trailing: FilledButton.tonal(
              onPressed: _pickFinalDue,
              child: Text(l10n.pickTime),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
            title: Text(l10n.enableNotifications),
            subtitle: Text(l10n.enableNotificationsHint),
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: l10n.milestones,
            action: FilledButton.tonalIcon(
              onPressed: _addMilestone,
              icon: const Icon(Icons.add),
              label: Text(l10n.addMilestone),
            ),
          ),
          const SizedBox(height: 8),
          if (_milestones.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noMilestones),
              ),
            ),
          for (var index = 0; index < _milestones.length; index++)
            Card(
              child: ListTile(
                title: switch (
                  resolveMilestoneDisplayTitle(_milestones[index].title)
                ) {
                  final title when title.isNotEmpty => Text(title),
                  _ => null,
                },
                subtitle: Text(
                  '${_formatDateTime(ref.watch(configuredUtcToLocalProvider(_milestones[index].dueAtUtc)))} · '
                  '${_milestones[index].source == MilestoneSource.generated ? l10n.generated : l10n.manual}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: l10n.edit,
                      onPressed: () => _editMilestone(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: l10n.delete,
                      onPressed: () {
                        setState(() {
                          _milestones.removeAt(index);
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: l10n.reminderRules,
            action: FilledButton.tonalIcon(
              onPressed: _addCustomReminder,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(l10n.customReminder),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _quickReminderOptions)
                FilterChip(
                  selected: _reminders.contains(option),
                  label: Text(_labelForOffset(option)),
                  onSelected: (_) => _toggleReminder(option),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reminder in _reminders.toSet().toList()..sort())
                InputChip(
                  label: Text(_labelForOffset(reminder)),
                  onDeleted: () {
                    setState(() {
                      _reminders.remove(reminder);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(isEditing ? l10n.saveChanges : l10n.createTask),
          ),
        ],
      ),
    );
  }

  List<int> get _quickReminderOptions => const [
    0,
    10 * 60,
    30 * 60,
    60 * 60,
    24 * 60 * 60,
  ];

  Future<void> _pickFinalDue() async {
    final picked = await _pickDateTime(_finalDueLocal);
    if (picked != null) {
      setState(() {
        _finalDueLocal = picked;
      });
    }
  }

  Future<void> _addMilestone() async {
    final milestone = await _showMilestoneEditor();
    if (milestone == null) {
      return;
    }
    setState(() {
      _milestones.add(milestone);
      _sortMilestones();
    });
  }

  Future<void> _editMilestone(int index) async {
    final milestone = await _showMilestoneEditor(existing: _milestones[index]);
    if (milestone == null) {
      return;
    }
    setState(() {
      _milestones[index] = milestone;
      _sortMilestones();
    });
  }

  Future<Milestone?> _showMilestoneEditor({Milestone? existing}) async {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController(text: existing?.title ?? '');
    DateTime selected = existing == null
        ? _finalDueLocal
        : ref.read(timezoneServiceProvider).utcToConfigured(existing.dueAtUtc);

    final result = await showDialog<Milestone>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null ? l10n.addMilestone : l10n.edit,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: l10n.milestoneName),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.milestoneTime),
                subtitle: Text(_formatDateTime(selected)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await _pickDateTime(selected);
                    if (picked != null) {
                      setLocalState(() {
                        selected = picked;
                      });
                    }
                  },
                  child: Text(l10n.change),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                Navigator.of(dialogContext).pop(
                  Milestone(
                    id: existing?.id ?? _generateId(),
                    title: title,
                    dueAtUtc: ref.read(
                      timezoneAwareLocalToUtcProvider(selected),
                    ),
                    source: existing?.source ?? MilestoneSource.manual,
                  ),
                );
              },
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    return result;
  }

  Future<void> _addCustomReminder() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    _ReminderUnit unit = _ReminderUnit.minutes;
    const multiplierByUnit = {
      _ReminderUnit.minutes: 60,
      _ReminderUnit.hours: 60 * 60,
      _ReminderUnit.days: 24 * 60 * 60,
    };

    final seconds = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(l10n.customReminder),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.quantity),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_ReminderUnit>(
                initialValue: unit,
                items: _ReminderUnit.values
                    .map(
                      (value) => DropdownMenuItem<_ReminderUnit>(
                        value: value,
                        child: Text(_labelForReminderUnit(value, l10n)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setLocalState(() {
                    unit = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null || value <= 0) {
                  return;
                }
                Navigator.of(
                  dialogContext,
                ).pop(value * multiplierByUnit[unit]!);
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (seconds == null) {
      return;
    }
    setState(() {
      if (!_reminders.contains(seconds)) {
        _reminders.add(seconds);
      }
      _reminders.sort();
    });
  }

  void _toggleReminder(int seconds) {
    setState(() {
      if (_reminders.contains(seconds)) {
        _reminders.remove(seconds);
      } else {
        _reminders.add(seconds);
      }
      _reminders.sort();
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack(l10n.fillTaskTitle);
      return;
    }

    final finalDueUtc = ref.read(
      timezoneAwareLocalToUtcProvider(_finalDueLocal),
    );
    if (_milestones.any((item) => !item.dueAtUtc.isBefore(finalDueUtc))) {
      _showSnack(l10n.milestoneBeforeFinal);
      return;
    }

    final controller = ref.read(tasksControllerProvider.notifier);
    final task = DeadlineTask(
      id: widget.existingTask?.id ?? _generateId(),
      title: title,
      note: _noteController.text.trim(),
      timezoneId: controller.timezoneId,
      createdAtUtc: widget.existingTask?.createdAtUtc ?? DateTime.now().toUtc(),
      updatedAtUtc: DateTime.now().toUtc(),
      finalDueAtUtc: finalDueUtc,
      milestones: [..._milestones]
        ..sort((left, right) => left.dueAtUtc.compareTo(right.dueAtUtc)),
      reminderOffsetsSeconds: _reminders.toSet().toList()..sort(),
      notificationsEnabled: _notificationsEnabled,
    );

    if (_notificationsEnabled) {
      await controller.requestNotificationPermission();
    }
    await controller.addOrUpdateTask(task);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.existingTask == null ? l10n.taskCreated : l10n.taskUpdated,
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initialValue) async {
    final preferredLocale =
        resolvePreferredLocale(ref.read(localePreferenceProvider)) ??
        Localizations.localeOf(context);
    final date = await showDatePicker(
      context: context,
      initialDate: initialValue,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: preferredLocale,
    );
    if (date == null || !mounted) {
      return null;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
      builder: (context, child) => Localizations.override(
        context: context,
        locale: preferredLocale,
        child: child,
      ),
    );
    if (time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _sortMilestones() {
    _milestones.sort((left, right) => left.dueAtUtc.compareTo(right.dueAtUtc));
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }

  String _labelForOffset(int seconds) {
    final l10n = AppLocalizations.of(context)!;
    if (seconds == 0) {
      return l10n.atTimeReminder;
    }
    final duration = Duration(seconds: seconds);
    if (duration.inDays >= 1 && duration.inHours.remainder(24) == 0) {
      return l10n.advanceDays(duration.inDays);
    }
    if (duration.inHours >= 1 && duration.inMinutes.remainder(60) == 0) {
      return l10n.advanceHours(duration.inHours);
    }
    if (duration.inMinutes >= 1) {
      return l10n.advanceMinutes(duration.inMinutes);
    }
    return l10n.advanceSeconds(duration.inSeconds);
  }

  String _labelForReminderUnit(
    _ReminderUnit unit,
    AppLocalizations l10n,
  ) {
    return switch (unit) {
      _ReminderUnit.minutes => l10n.minutes,
      _ReminderUnit.hours => l10n.hours,
      _ReminderUnit.days => l10n.days,
    };
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}

enum _ReminderUnit { minutes, hours, days }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        action,
      ],
    );
  }
}
