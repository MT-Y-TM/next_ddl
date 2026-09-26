import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../models/deadline_task.dart';
import '../../services/timezone_service.dart';
import '../../utils/countdown_formatter.dart';
import '../../utils/deadline_logic.dart';
import '../../utils/milestone_utils.dart';
import '../settings/settings_page.dart';
import 'task_detail_page.dart';
import 'task_edit_page.dart';
import 'tasks_controller.dart';
import 'task_ui_helpers.dart';
import 'task_ui_strings.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  final _search = TextEditingController();
  String? _tag;
  bool _untagged = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    _search.clear();
    _tag = null;
    _untagged = false;
  });

  Future<void> _manageTags() async {
    await showDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final strings = TaskUiStrings(context);
          final l10n = AppLocalizations.of(context)!;
          final tags =
              (ref.watch(tasksControllerProvider).valueOrNull?.tasks ??
                      <DeadlineTask>[])
                  .expand((task) => task.tags)
                  .toSet()
                  .toList()
                ..sort();
          return AlertDialog(
            title: Text(strings.manageTags),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(strings.removeTag),
                    if (tags.isEmpty) Text(strings.noTags),
                    for (final tag in tags)
                      ListTile(
                        title: Text(tag),
                        trailing: IconButton(
                          tooltip: l10n.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(tag),
                                content: Text(strings.removeTag),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: Text(l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            final success = await runTaskUiAction(
                              context,
                              () => ref
                                  .read(tasksControllerProvider.notifier)
                                  .removeTag(tag),
                            );
                            if (success && mounted && _tag == tag) {
                              setState(() => _tag = null);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.confirm),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(tasksControllerProvider);
    final inProgress = filterTaskUi(
      ref.watch(inProgressTasksProvider),
      _search.text,
      tag: _tag,
      untagged: _untagged,
    );
    final overdue = filterTaskUi(
      ref.watch(overdueTasksProvider),
      _search.text,
      tag: _tag,
      untagged: _untagged,
    );
    final archived = filterTaskUi(
      ref.watch(archivedTasksProvider),
      _search.text,
      tag: _tag,
      untagged: _untagged,
    );
    final strings = TaskUiStrings(context);
    final tags =
        (snapshotAsync.valueOrNull?.tasks ?? <DeadlineTask>[])
            .expand((task) => task.tags)
            .toSet()
            .toList()
          ..sort();
    final filtering =
        _search.text.trim().isNotEmpty || _tag != null || _untagged;
    final now = ref.watch(nowProvider).valueOrNull ?? DateTime.now().toUtc();
    ref.watch(timezoneRevisionProvider);
    final timezoneService = ref.watch(timezoneServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.inProgressTab),
              Tab(text: l10n.overdueTab),
              Tab(text: strings.archived),
            ],
          ),
          actions: [
            IconButton(
              tooltip: strings.manageTags,
              onPressed: _manageTags,
              icon: const Icon(Icons.sell_outlined),
            ),
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
          data: (_) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: strings.search,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: strings.clear,
                      onPressed: _clear,
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  strings.scope,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(strings.all),
                        selected: _tag == null && !_untagged,
                        onSelected: (_) => setState(() {
                          _tag = null;
                          _untagged = false;
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(strings.untagged),
                        selected: _untagged,
                        onSelected: (value) => setState(() {
                          _tag = null;
                          _untagged = value;
                        }),
                      ),
                    ),
                    for (final tag in tags)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tag),
                          selected: _tag == tag,
                          onSelected: (value) => setState(() {
                            _tag = value ? tag : null;
                            _untagged = false;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _TaskTabView(
                      filtering: filtering,
                      onClear: _clear,
                      tasks: inProgress,
                      nowUtc: now,
                      summary: l10n.inProgressSummary(inProgress.length),
                      toConfiguredTime: timezoneService.utcToConfigured,
                    ),
                    _TaskTabView(
                      filtering: filtering,
                      onClear: _clear,
                      tasks: overdue,
                      nowUtc: now,
                      summary: l10n.overdueSummary(overdue.length),
                      toConfiguredTime: timezoneService.utcToConfigured,
                    ),
                    _TaskTabView(
                      tasks: archived,
                      emptyMessage: strings.emptyArchive,
                      nowUtc: now,
                      summary: '${strings.archived} (${archived.length})',
                      toConfiguredTime: timezoneService.utcToConfigured,
                      filtering: filtering,
                      onClear: _clear,
                    ),
                  ],
                ),
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
    required this.filtering,
    required this.onClear,
    this.emptyMessage,
  });

  final bool filtering;
  final String? emptyMessage;
  final VoidCallback onClear;
  final List<DeadlineTask> tasks;
  final DateTime nowUtc;
  final String summary;
  final DateTime Function(DateTime value) toConfiguredTime;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      if (filtering) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(TaskUiStrings(context).noResults),
              TextButton(
                onPressed: onClear,
                child: Text(TaskUiStrings(context).clear),
              ),
            ],
          ),
        );
      }
      if (emptyMessage != null) {
        return Center(child: Text(emptyMessage!));
      }
      return _EmptyState(
        onCreate: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const TaskEditPage()));
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: tasks.length + 1,
      itemBuilder: (context, index) => index == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : _TaskCard(
              task: tasks[index - 1],
              nowUtc: nowUtc,
              toConfiguredTime: toConfiguredTime,
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
                  if (task.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final tag in task.tags) Chip(label: Text(tag)),
                      ],
                    ),
                  if (task.isCompleted)
                    Text(
                      '${TaskUiStrings(context).completed} · ${taskUiDate(toConfiguredTime(task.completedAtUtc!))}',
                    )
                  else ...[
                    Text(
                      task.finalDueAtUtc.isAfter(nowUtc)
                          ? l10n.inProgressTab
                          : l10n.overdueTab,
                    ),
                    _RemainingProgressBar(progress: progress),
                    const SizedBox(height: 16),
                    if (task.milestones.isNotEmpty) ...[
                      _CountdownRow(
                        label: l10n.nextNode,
                        title: nextMilestone == null
                            ? l10n.finalDeadline
                            : resolveMilestoneDisplayTitle(nextMilestone.title),
                        countdown: formatCountdownFromDates(
                          now: nowUtc,
                          target: nextMilestone?.dueAtUtc ?? task.finalDueAtUtc,
                          overduePrefix: l10n.countdownOverduePrefix,
                          daySuffix: l10n.countdownDaySuffix,
                        ),
                        time: toConfiguredTime(
                          nextMilestone?.dueAtUtc ?? task.finalDueAtUtc,
                        ),
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
            Text(
              l10n.remainingTime,
              style: Theme.of(context).textTheme.labelLarge,
            ),
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
    final hasTitle = title != null && title!.isNotEmpty;
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
              if (hasTitle) ...[
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
