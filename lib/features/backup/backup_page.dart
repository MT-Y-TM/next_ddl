import 'package:flutter/material.dart';
import '../../models/app_snapshot.dart';
import '../../services/backup_service.dart';
import 'backup_localizations.dart';

Future<bool> confirmSnapshotReplacement(
  BuildContext context,
  AppSnapshot snapshot,
) async {
  final l = BackupLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.confirm),
          content: Text(l.replacement(snapshot.tasks.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.confirm),
            ),
          ],
        ),
      ) ??
      false;
}

/// onRestored updates in-memory state and synchronizes reminders, without saving
/// again. If it throws, only that callback is retried, never the replacement.
class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    required this.service,
    required this.onRestored,
  });
  final BackupService service;
  final Future<void> Function(AppSnapshot) onRestored;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupEntry> _entries = [];
  bool _busy = false;
  String? _error;
  AppSnapshot? _pendingSync;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.service.listBackups();
      if (mounted) {
        setState(() {
          _entries = entries;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = BackupLocalizations.of(context).error(error));
      }
    }
  }

  Future<void> _restore(BackupEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final snapshot = await widget.service.readBackup(entry);
      if (!mounted || !await confirmSnapshotReplacement(context, snapshot)) {
        return;
      }
      await widget.service.replaceWithBackup(snapshot);
      _pendingSync = snapshot;
      await _sync();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = BackupLocalizations.of(context).error(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    final snapshot = _pendingSync;
    if (snapshot == null) return;
    try {
      await widget.onRestored(snapshot);
      _pendingSync = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(BackupLocalizations.of(context).saved)),
        );
      }
    } catch (_) {
      /* The retry UI explicitly distinguishes post-save sync. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = BackupLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.retention(widget.service.retentionCount)),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _busy ? null : _load, child: Text(l.retry)),
          ],
          if (_pendingSync != null) ...[
            Text(l.scheduleFailed),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await _sync();
                      if (mounted) setState(() => _busy = false);
                    },
              child: Text(l.retry),
            ),
          ],
          if (_entries.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(l.empty)),
          for (final entry in _entries)
            ListTile(
              title: Text(entry.createdAtUtc.toLocal().toString()),
              trailing: TextButton(
                onPressed: _busy || _pendingSync != null
                    ? null
                    : () => _restore(entry),
                child: Text(l.restore),
              ),
            ),
        ],
      ),
    );
  }
}
