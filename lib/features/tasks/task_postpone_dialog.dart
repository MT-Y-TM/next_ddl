import 'package:flutter/material.dart';
import 'package:next_ddl/l10n/app_localizations.dart';
import '../../models/deadline_task.dart';
import '../../services/timezone_service.dart';
import '../../utils/task_actions.dart';
import 'task_ui_helpers.dart';
import 'task_ui_strings.dart';

class TaskPostponeChoice {
  const TaskPostponeChoice(this.dueUtc, this.shift);
  final DateTime dueUtc;
  final bool shift;
}

class TaskPostponeDialog extends StatefulWidget {
  const TaskPostponeDialog({
    required this.task,
    required this.timezone,
    super.key,
  });
  final DeadlineTask task;
  final TimezoneService timezone;
  @override
  State<TaskPostponeDialog> createState() => _TaskPostponeDialogState();
}

class _TaskPostponeDialogState extends State<TaskPostponeDialog> {
  late DateTime due = widget.task.finalDueAtUtc.add(const Duration(hours: 1));
  bool shift = false;

  Future<void> pick() async {
    final local = widget.timezone.utcToConfigured(due);
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(local.year < 2000 ? local.year : 2000),
      lastDate: DateTime(local.year > 2100 ? local.year : 2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null || !mounted) return;
    setState(
      () => due = widget.timezone.localToUtc(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = TaskUiStrings(context);
    final l = AppLocalizations.of(context)!;
    DeadlineTask? preview;
    try {
      preview = postponeDeadlineTask(
        widget.task,
        due,
        nowUtc: DateTime.now().toUtc(),
        shiftFutureMilestones: shift,
      );
    } on ArgumentError {
      /* Validation is displayed below. */
    }
    return AlertDialog(
      title: Text(s.postpone),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => due = widget.task.finalDueAtUtc.add(
                        const Duration(hours: 1),
                      ),
                    ),
                    child: Text(s.hour),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => due = widget.task.finalDueAtUtc.add(
                        const Duration(days: 1),
                      ),
                    ),
                    child: Text(s.day),
                  ),
                  TextButton(onPressed: pick, child: Text(s.custom)),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.shift),
                subtitle: Text(s.shiftHint),
                value: shift,
                onChanged: (value) => setState(() => shift = value),
              ),
              Text(
                '${s.preview} (${widget.timezone.currentTimezoneId})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${taskUiDate(widget.timezone.utcToConfigured(widget.task.finalDueAtUtc))} → ${taskUiDate(widget.timezone.utcToConfigured(due))}',
              ),
              if (preview == null)
                Text(
                  s.invalid,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (preview != null)
                for (final node in preview.milestones)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      node.title.isEmpty ? l.milestoneTime : node.title,
                    ),
                    subtitle: Text(
                      taskUiDate(
                        widget.timezone.utcToConfigured(node.dueAtUtc),
                      ),
                    ),
                    leading: Icon(
                      node.isCompleted
                          ? Icons.check_circle_outline
                          : Icons.flag_outlined,
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: preview == null
              ? null
              : () {
                  try {
                    postponeDeadlineTask(
                      widget.task,
                      due,
                      nowUtc: DateTime.now().toUtc(),
                      shiftFutureMilestones: shift,
                    );
                    Navigator.pop(context, TaskPostponeChoice(due, shift));
                  } on ArgumentError {
                    setState(() {});
                  }
                },
          child: Text(l.confirm),
        ),
      ],
    );
  }
}
