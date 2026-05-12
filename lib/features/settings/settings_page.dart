import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tasks/tasks_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
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
                        content: Text(
                          path == null ? '已取消导出' : '导出成功：$path',
                        ),
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
                    : 'Android 首次启用提醒时会请求通知权限，保存、删除或导入任务后会自动重建该任务的未来提醒。',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
