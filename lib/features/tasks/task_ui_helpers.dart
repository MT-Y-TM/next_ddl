import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feedback.dart';
import '../../models/deadline_task.dart';
import 'task_ui_strings.dart';
import 'tasks_controller.dart';

List<String> parseTaskTags(String value) => value
    .split(RegExp('[,，\\n]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toSet()
    .toList();

List<DeadlineTask> filterTaskUi(
  List<DeadlineTask> tasks,
  String query, {
  String? tag,
  bool untagged = false,
}) {
  final needle = query.trim().toLowerCase();
  return tasks
      .where(
        (task) =>
            (needle.isEmpty ||
                task.title.toLowerCase().contains(needle) ||
                task.note.toLowerCase().contains(needle)) &&
            (tag == null || task.tags.contains(tag)) &&
            (!untagged || task.tags.isEmpty),
      )
      .toList();
}

String taskUiDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

Future<bool> runTaskUiAction(
  BuildContext context,
  Future<void> Function() action, {
  Future<void> Function()? undo,
}) async {
  final strings = TaskUiStrings(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (!context.mounted) return true;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          content: Text(strings.saved),
          action: undo == null
              ? null
              : SnackBarAction(
                  label: strings.undo,
                  onPressed: () async {
                    try {
                      await undo();
                      if (!messenger.mounted) return;
                      messenger.showSnackBar(
                        appSnackBar(content: Text(strings.saved)),
                      );
                    } catch (_) {
                      if (!messenger.mounted) return;
                      messenger.showSnackBar(
                        appSnackBar(content: Text(strings.failed)),
                      );
                    }
                  },
                ),
        ),
      );
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(appSnackBar(content: Text(strings.failed)));
    }
    return false;
  }
}

class TaskActionButton extends StatefulWidget {
  const TaskActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });
  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;
  @override
  State<TaskActionButton> createState() => _TaskActionButtonState();
}

class TaskWidgetStarButton extends ConsumerStatefulWidget {
  const TaskWidgetStarButton({
    required this.task,
    this.color,
    this.enabled = true,
    super.key,
  });

  final DeadlineTask task;
  final Color? color;
  final bool enabled;

  @override
  ConsumerState<TaskWidgetStarButton> createState() =>
      _TaskWidgetStarButtonState();
}

class _TaskWidgetStarButtonState extends ConsumerState<TaskWidgetStarButton> {
  bool _saving = false;

  Future<void> _toggle() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await runTaskUiAction(
        context,
        () => ref
            .read(tasksControllerProvider.notifier)
            .setWidgetPinned(widget.task.id, !widget.task.widgetPinned),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = TaskUiStrings(context);
    return IconButton(
      key: ValueKey('widget-star-${widget.task.id}'),
      tooltip: widget.task.widgetPinned
          ? strings.unpinWidget
          : strings.pinWidget,
      onPressed: _saving || !widget.enabled || widget.task.isCompleted
          ? null
          : _toggle,
      color: widget.color,
      iconSize: 22,
      icon: Icon(
        widget.task.widgetPinned
            ? Icons.star_rounded
            : Icons.star_border_rounded,
      ),
    );
  }
}

class _TaskActionButtonState extends State<TaskActionButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              await widget.onPressed();
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    icon: Icon(widget.icon),
    label: Text(widget.label),
  );
}
