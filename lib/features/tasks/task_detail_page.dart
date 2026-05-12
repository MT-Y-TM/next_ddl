import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/milestone.dart';
import '../../utils/countdown_formatter.dart';
import '../../utils/deadline_logic.dart';
import 'task_edit_page.dart';
import 'tasks_controller.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final matchedTasks =
        snapshot?.tasks.where((item) => item.id == taskId).toList() ?? const [];
    final task = matchedTasks.isEmpty ? null : matchedTasks.first;
    final now = ref.watch(nowProvider).valueOrNull ?? DateTime.now().toUtc();

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务详情')),
        body: const Center(child: Text('任务不存在或已被删除')),
      );
    }

    final nextMilestone = resolveNextMilestone(task, now);
    final timeline = [...task.milestones]
      ..sort((left, right) => left.dueAtUtc.compareTo(right.dueAtUtc));

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          IconButton(
            tooltip: '编辑',
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
                  Text('时区：${task.timezoneId}'),
                  const SizedBox(height: 8),
                  Text('下一个节点：${nextMilestone?.title ?? '已全部超时'}'),
                  if (nextMilestone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatCountdownFromDates(
                        now: now,
                        target: nextMilestone.dueAtUtc,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '最终截止：${formatCountdownFromDates(now: now, target: task.finalDueAtUtc)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '时间线',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final milestone in timeline)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(milestone.title),
              subtitle: Text(
                '${milestone.dueAtUtc.toLocal()} · ${milestone.source == MilestoneSource.generated ? '自动生成' : '手动维护'}',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: const Text('最终截止'),
            subtitle: Text(task.finalDueAtUtc.toLocal().toString()),
          ),
          const SizedBox(height: 12),
          Text(
            '提醒策略',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final offset in task.reminderOffsetsSeconds)
                Chip(
                  label: Text(offset == 0 ? '到点提醒' : '提前 ${_formatOffset(offset)}'),
                ),
              if (task.reminderOffsetsSeconds.isEmpty)
                const Chip(label: Text('未设置提醒')),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('删除任务'),
                  content: const Text('删除后会同步清除该任务的待提醒通知。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('删除'),
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
            label: const Text('删除任务'),
          ),
        ],
      ),
    );
  }

  String _formatOffset(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inDays >= 1 && duration.inHours.remainder(24) == 0) {
      return '${duration.inDays}天';
    }
    if (duration.inHours >= 1 && duration.inMinutes.remainder(60) == 0) {
      return '${duration.inHours}小时';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}分钟';
    }
    return '${duration.inSeconds}秒';
  }
}
