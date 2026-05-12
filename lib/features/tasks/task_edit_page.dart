import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/deadline_task.dart';
import '../../models/milestone.dart';
import 'tasks_controller.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  const TaskEditPage({
    this.existingTask,
    super.key,
  });

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
    _finalDueLocal = (task?.finalDueAtUtc ??
            DateTime.now().toUtc().add(const Duration(days: 3)))
        .toLocal();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑任务' : '新增任务'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '任务标题',
              hintText: '例如：毕业设计终稿',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '备注',
              hintText: '可写上下文、交付要求或提醒自己关注的点。',
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('最终截止'),
            subtitle: Text(_formatDateTime(_finalDueLocal)),
            trailing: FilledButton.tonal(
              onPressed: _pickFinalDue,
              child: const Text('选择时间'),
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
            title: const Text('启用系统提醒'),
            subtitle: const Text('Android 会请求通知权限，Windows 使用系统通知。'),
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: '中间节点',
            action: FilledButton.tonalIcon(
              onPressed: _addMilestone,
              icon: const Icon(Icons.add),
              label: const Text('新增节点'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _generateDefaultMilestones,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('自动生成 25% / 50% / 75%'),
          ),
          const SizedBox(height: 8),
          if (_milestones.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('当前没有中间节点，应用会直接用最终截止作为最后一个关键时间点。'),
              ),
            ),
          for (var index = 0; index < _milestones.length; index++)
            Card(
              child: ListTile(
                title: Text(_milestones[index].title),
                subtitle: Text(
                  '${_formatDateTime(_milestones[index].dueAtUtc.toLocal())} · ${_milestones[index].source == MilestoneSource.generated ? '自动生成' : '手动'}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: '编辑',
                      onPressed: () => _editMilestone(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: '删除',
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
            title: '提醒规则',
            action: FilledButton.tonalIcon(
              onPressed: _addCustomReminder,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('自定义提醒'),
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
            label: Text(isEditing ? '保存修改' : '创建任务'),
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
    final titleController = TextEditingController(text: existing?.title ?? '');
    DateTime selected = (existing?.dueAtUtc ?? _finalDueLocal).toLocal();
    final result = await showDialog<Milestone>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(existing == null ? '新增节点' : '编辑节点'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '节点名称'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('节点时间'),
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
                  child: const Text('修改'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  Milestone(
                    id: existing?.id ?? _generateId(),
                    title: title,
                    dueAtUtc:
                        ref.read(timezoneAwareLocalToUtcProvider(selected)),
                    source: existing?.source ?? MilestoneSource.manual,
                  ),
                );
              },
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    return result;
  }

  Future<void> _generateDefaultMilestones() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('替换现有中间节点'),
        content: const Text('自动生成会用 25% / 50% / 75% 节点替换当前所有中间节点。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('替换'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final taskId = widget.existingTask?.id ?? _generateId();
    final generated = ref
        .read(tasksControllerProvider.notifier)
        .generateQuarterNodes(
          ref.read(timezoneAwareLocalToUtcProvider(_finalDueLocal)),
          taskId,
        );
    setState(() {
      _milestones = generated;
      _sortMilestones();
    });
  }

  Future<void> _addCustomReminder() async {
    final controller = TextEditingController();
    String unit = '分钟';
    final multiplierByUnit = {
      '分钟': 60,
      '小时': 60 * 60,
      '天': 24 * 60 * 60,
    };
    final seconds = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('自定义提醒'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '数量'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: unit,
                items: multiplierByUnit.keys
                    .map(
                      (label) => DropdownMenuItem<String>(
                        value: label,
                        child: Text(label),
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
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null || value <= 0) {
                  return;
                }
                Navigator.of(dialogContext).pop(value * multiplierByUnit[unit]!);
              },
              child: const Text('添加'),
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
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('请先填写任务标题');
      return;
    }

    final finalDueUtc = ref.read(timezoneAwareLocalToUtcProvider(_finalDueLocal));
    if (_milestones.any((item) => !item.dueAtUtc.isBefore(finalDueUtc))) {
      _showSnack('所有中间节点都必须早于最终截止');
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
        content: Text(widget.existingTask == null ? '任务已创建' : '任务已更新'),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initialValue) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialValue,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return null;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
    );
    if (time == null) {
      return null;
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  void _sortMilestones() {
    _milestones.sort((left, right) => left.dueAtUtc.compareTo(right.dueAtUtc));
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }

  String _labelForOffset(int seconds) {
    if (seconds == 0) {
      return '到点提醒';
    }
    final duration = Duration(seconds: seconds);
    if (duration.inDays >= 1 && duration.inHours.remainder(24) == 0) {
      return '提前 ${duration.inDays} 天';
    }
    if (duration.inHours >= 1 && duration.inMinutes.remainder(60) == 0) {
      return '提前 ${duration.inHours} 小时';
    }
    if (duration.inMinutes >= 1) {
      return '提前 ${duration.inMinutes} 分钟';
    }
    return '提前 ${duration.inSeconds} 秒';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
  });

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        action,
      ],
    );
  }
}
