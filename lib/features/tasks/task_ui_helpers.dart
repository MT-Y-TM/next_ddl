import 'package:flutter/material.dart';
import '../../models/deadline_task.dart';
import 'task_ui_strings.dart';

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
        SnackBar(
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
                        SnackBar(content: Text(strings.saved)),
                      );
                    } catch (_) {
                      if (!messenger.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text(strings.failed)),
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
      ).showSnackBar(SnackBar(content: Text(strings.failed)));
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
