import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/timezone_service.dart';
import '../tasks/tasks_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final versionAsync = ref.watch(appVersionProvider);
    ref.watch(timezoneRevisionProvider);
    final timezoneId = ref.watch(timezoneServiceProvider).currentTimezoneId;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('当前版本'),
              subtitle: Text(versionAsync.valueOrNull ?? '读取中...'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('任务总数'),
              subtitle: Text('${snapshot?.tasks.length ?? 0} 个'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.public_outlined),
              title: const Text('应用时区'),
              subtitle: Text(timezoneId),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTimezone(context, ref),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('导出 JSON'),
                  subtitle: const Text('导出当前全部任务数据，用于备份或迁移。'),
                  onTap: () async {
                    final path = await ref
                        .read(tasksControllerProvider.notifier)
                        .exportSnapshot();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(path == null ? '已取消导出' : '导出成功：$path'),
                      ),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('导入 JSON'),
                  subtitle: const Text('导入会替换本地全部任务数据，并重新同步通知。'),
                  onTap: () async {
                    final imported = await ref
                        .read(tasksControllerProvider.notifier)
                        .importSnapshot();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          imported == null
                              ? '已取消导入'
                              : '导入成功：${imported.tasks.length} 个任务',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('通知说明'),
              subtitle: Text(
                Platform.isWindows
                    ? '当前 Windows 版本使用 ZIP 形式发布而非 MSIX。已显示的系统通知可能无法被可靠取消，编辑任务后旧 toast 可能残留。'
                    : 'Android 首次启用提醒时只会请求普通通知权限，不再跳转“闹钟和提醒”。提醒会以更兼容 MIUI 的方式调度，保存、删除或导入任务后会自动重建未来提醒。',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTimezone(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(tasksControllerProvider.notifier);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _TimezonePickerDialog(
        currentTimezoneId: controller.timezoneId,
        timezoneIds: controller.timezoneIds,
      ),
    );
    if (selected == null || selected == controller.timezoneId) {
      return;
    }
    final changed = await controller.setTimezone(selected);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(changed ? '应用时区已更新：$selected' : '时区无效')),
    );
  }
}

class _TimezonePickerDialog extends StatefulWidget {
  const _TimezonePickerDialog({
    required this.currentTimezoneId,
    required this.timezoneIds,
  });

  final String currentTimezoneId;
  final List<String> timezoneIds;

  @override
  State<_TimezonePickerDialog> createState() => _TimezonePickerDialogState();
}

class _TimezonePickerDialogState extends State<_TimezonePickerDialog> {
  static const _commonTimezoneIds = [
    'Asia/Shanghai',
    'Asia/Hong_Kong',
    'Asia/Taipei',
    'Asia/Tokyo',
    'Asia/Seoul',
    'UTC',
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredTimezoneIds();
    return AlertDialog(
      title: const Text('选择应用时区'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: '搜索时区',
                hintText: '例如 Asia/Shanghai',
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final timezoneId = items[index];
                  final selected = timezoneId == widget.currentTimezoneId;
                  return ListTile(
                    dense: true,
                    leading: selected
                        ? const Icon(Icons.check)
                        : const SizedBox(width: 24),
                    title: Text(timezoneId),
                    onTap: () => Navigator.of(context).pop(timezoneId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  List<String> _filteredTimezoneIds() {
    final known = widget.timezoneIds.toSet();
    final common = [
      for (final timezoneId in _commonTimezoneIds)
        if (known.contains(timezoneId)) timezoneId,
    ];
    final rest = [
      for (final timezoneId in widget.timezoneIds)
        if (!common.contains(timezoneId)) timezoneId,
    ];
    final ordered = [...common, ...rest];
    if (_query.isEmpty) {
      return ordered;
    }
    return [
      for (final timezoneId in ordered)
        if (timezoneId.toLowerCase().contains(_query)) timezoneId,
    ];
  }
}
