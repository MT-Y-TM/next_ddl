import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../models/milestone.dart';
import '../../services/timezone_service.dart';
import '../../utils/countdown_formatter.dart';
import '../../utils/deadline_logic.dart';
import '../../utils/timezone_labels.dart';
import 'task_edit_page.dart';
import 'tasks_controller.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final matchedTasks =
        snapshot?.tasks.where((item) => item.id == taskId).toList() ?? const [];
    final task = matchedTasks.isEmpty ? null : matchedTasks.first;
    final now = ref.watch(nowProvider).valueOrNull ?? DateTime.now().toUtc();
    ref.watch(timezoneRevisionProvider);
    final timezoneService = ref.watch(timezoneServiceProvider);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.taskDetails)),
        body: Center(child: Text(l10n.taskNotFound)),
      );
    }

    final nextMilestone = resolveNextMilestone(task, now);
    final progress = resolveRemainingProgress(task, now);
    final timeline = [...task.milestones]
      ..sort((left, right) => left.dueAtUtc.compareTo(right.dueAtUtc));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskDetails),
        actions: [
          IconButton(
            tooltip: l10n.edit,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TaskEditPage(existingTask: task),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (task.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(task.note),
                  ],
                  const SizedBox(height: 16),
                  _RemainingProgressBar(progress: progress),
                  const SizedBox(height: 16),
                  Text(
                    l10n.timezoneLabel(
                      localizedTimezoneLabel(
                        l10n,
                        timezoneService.currentTimezoneId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.nextNodeValue(nextMilestone?.title ?? l10n.allExpired),
                  ),
                  if (nextMilestone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatCountdownFromDates(
                        now: now,
                        target: nextMilestone.dueAtUtc,
                        overduePrefix: l10n.countdownOverduePrefix,
                        daySuffix: l10n.countdownDaySuffix,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    l10n.finalDeadlineValue(
                      formatCountdownFromDates(
                        now: now,
                        target: task.finalDueAtUtc,
                        overduePrefix: l10n.countdownOverduePrefix,
                        daySuffix: l10n.countdownDaySuffix,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.timeline, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final milestone in timeline)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(milestone.title),
              subtitle: Text(
                '${_formatDateTime(timezoneService.utcToConfigured(milestone.dueAtUtc))} · ${milestone.source == MilestoneSource.generated ? l10n.generatedNode : l10n.manualNode}',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: Text(l10n.finalDeadline),
            subtitle: Text(
              _formatDateTime(
                timezoneService.utcToConfigured(task.finalDueAtUtc),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.reminderRules, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final offset in task.reminderOffsetsSeconds)
                Chip(
                  label: Text(
                    offset == 0 ? l10n.remindAtTime : _formatOffset(offset, l10n),
                  ),
                ),
              if (task.reminderOffsetsSeconds.isEmpty)
                Chip(label: Text(l10n.noReminder)),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(l10n.deleteTaskTitle),
                  content: Text(l10n.deleteTaskBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) {
                return;
              }
              await ref
                  .read(tasksControllerProvider.notifier)
                  .deleteTask(task.id);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.deleteTask),
          ),
        ],
      ),
    );
  }

  String _formatOffset(int seconds, AppLocalizations l10n) {
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

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }
}

class _RemainingProgressBar extends StatelessWidget {
  const _RemainingProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final percent = (progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.remainingTime, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}
