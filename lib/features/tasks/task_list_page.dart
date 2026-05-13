import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final tasks = ref.watch(sortedTasksProvider);
    final now = ref.watch(nowProvider).valueOrNull ?? DateTime.now().toUtc();
    ref.watch(timezoneRevisionProvider);
    final timezoneService = ref.watch(timezoneServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Next DDL'),
        actions: [
          IconButton(
            tooltip: '设置',
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
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const TaskEditPage()));
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('新增任务'),
      ),
      body: snapshotAsync.when(
        data: (_) {
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
                  '共 ${tasks.length} 个任务，按紧急程度排序',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              for (final task in tasks)
                _TaskCard(
                  task: task,
                  nowUtc: now,
                  toConfiguredTime: timezoneService.utcToConfigured,
                ),
            ],
          );
        },
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('加载任务失败：$error'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
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
                      label: '下一个节点',
                      title: nextMilestone?.title ?? '无未来节点',
                      countdown: nextMilestone == null
                          ? '已全部超时'
                          : formatCountdownFromDates(
                              now: nowUtc,
                              target: nextMilestone.dueAtUtc,
                            ),
                      time: nextMilestone == null
                          ? null
                          : toConfiguredTime(nextMilestone.dueAtUtc),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _CountdownRow(
                    label: '最终截止',
                    title: '最终截止',
                    countdown: formatCountdownFromDates(
                      now: nowUtc,
                      target: task.finalDueAtUtc,
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
    final percent = (progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('剩余时间', style: Theme.of(context).textTheme.labelLarge),
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
  final String title;
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
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
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
              '还没有任何 deadline 任务',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '创建第一个任务后，这里会显示下一个节点、最终截止和实时倒计时。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('立即创建'),
            ),
          ],
        ),
      ),
    );
  }
}
