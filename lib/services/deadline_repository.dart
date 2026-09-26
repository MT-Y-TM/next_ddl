import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_snapshot.dart';

abstract class DeadlineRepository {
  Future<AppSnapshot> loadSnapshot();

  Future<void> saveSnapshot(AppSnapshot snapshot);

  Future<AppSnapshot?> importSnapshot();

  Future<String?> exportSnapshot(AppSnapshot snapshot);
}

/// Serializes backup and replacement with ordinary saves.
abstract interface class ProtectedDeadlineRepository {
  Future<void> replaceSafely(
    AppSnapshot snapshot,
    Future<void> Function(AppSnapshot current) backup,
  );
}

final deadlineRepositoryProvider = Provider<DeadlineRepository>((ref) {
  throw UnimplementedError('deadlineRepositoryProvider must be overridden');
});
