import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../models/deadline_task.dart';
import '../../services/timezone_service.dart';
import '../../utils/countdown_formatter.dart';
import '../../utils/deadline_logic.dart';
import '../settings/settings_page.dart';
import 'task_detail_page.dart';
import 'task_edit_page.dart';
import 'tasks_controller.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(tasksControllerProvider);
    final inProgress = ref.watch(inProgressTasksProvider);
    final overdue = ref.watch(overdueTasksProvider);
    final now = ref.watch(nowProvider).valueOrNull ?? DateTime.now().toUtc();
    ref.watch(timezoneRevisionProvider);
    final timezoneService = ref.watch(timezoneServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.inProgressTab),
              Tab(text: l10n.overdueTab),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l10n.settings,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                );
              },
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TaskEditPage()),
            );
          },
          icon: const Icon(Icons.add_task_rounded),
          label: Text(l10n.addTask),
        ),
        body: snapshotAsync.when(
          data: (_) => TabBarView(
            children: [
              _TaskTabView(
                tasks: inProgress,
                nowUtc: now,
                summary: l10n.inProgressSummary(inProgress.length),
                toConfiguredTime: timezoneService.utcToConfigured,
              ),
              _TaskTabView(
                tasks: overdue,
                nowUtc: now,
                summary: l10n.overdueSummary(overdue.length),
                toConfiguredTime: timezoneService.utcToConfigured,
              ),
            ],
          ),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error.toString()),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _TaskTabView extends StatelessWidget {
  const _TaskTabView({
    required this.tasks,
    required this.nowUtc,
    required this.summary,
    required this.toConfiguredTime,
  });

  final List<DeadlineTask> tasks;
  final DateTime nowUtc;
  final String summary;
  final DateTime Function(DateTime value) toConfiguredTime;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _EmptyState(
        onCreate: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TaskEditPage()),
          );
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        for (final task in tasks)
          _TaskCard(
            task: task,
            nowUtc: nowUtc,
            toConfiguredTime: toConfiguredTime,
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.nowUtc,
    required this.toConfiguredTime,
  });

  final DeadlineTask task;
  final DateTime nowUtc;
  final DateTime Function(DateTime value) toConfiguredTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final urgency = resolveTaskUrgency(task, nowUtc);
    final nextMilestone = resolveNextMilestone(task, nowUtc);
    final scheme = Theme.of(context).colorScheme;
    final color = switch (urgency) {
      TaskUrgency.normal => scheme.primary,
      TaskUrgency.urgent => scheme.tertiary,
      TaskUrgency.overdue => scheme.error,
    };
    final progress = resolveRemainingProgress(task, nowUtc);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TaskDetailPage(taskId: task.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.72)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (task.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.note,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RemainingProgressBar(progress: progress),
                  const SizedBox(height: 16),
                  if (task.milestones.isNotEmpty) ...[
                _CountdownRow(
                      label: l10n.nextNode,
                      title: nextMilestone?.title ?? l10n.noFutureNodes,
                      countdown: nextMilestone == null
                          ? l10n.allExpired
                          : formatCountdownFromDates(
                              now: nowUtc,
                              target: nextMilestone.dueAtUtc,
                              overduePrefix: l10n.countdownOverduePrefix,
                              daySuffix: l10n.countdownDaySuffix,
                            ),
                      time: nextMilestone == null
                          ? null
                          : toConfiguredTime(nextMilestone.dueAtUtc),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _CountdownRow(
                    label: l10n.finalDeadline,
                    title: null,
                    countdown: formatCountdownFromDates(
                      now: nowUtc,
                      target: task.finalDueAtUtc,
                      overduePrefix: l10n.countdownOverduePrefix,
                      daySuffix: l10n.countdownDaySuffix,
                    ),
                    time: toConfiguredTime(task.finalDueAtUtc),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.label,
    required this.title,
    required this.countdown,
    required this.time,
  });

  final String label;
  final String? title;
  final String countdown;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    final localTime = time;
    final timeLabel = localTime == null
        ? '—'
        : '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} '
              '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.timelapse_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              if (title != null) ...[
                const SizedBox(height: 4),
                Text(
                  title!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                countdown,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(timeLabel),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noTasksTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noTasksBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.createNow),
            ),
          ],
        ),
      ),
    );
  }
}
