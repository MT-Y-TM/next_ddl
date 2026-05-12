import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_snapshot.dart';

abstract class DeadlineRepository {
  Future<AppSnapshot> loadSnapshot();

  Future<void> saveSnapshot(AppSnapshot snapshot);

  Future<AppSnapshot?> importSnapshot();

  Future<String?> exportSnapshot(AppSnapshot snapshot);
}

final deadlineRepositoryProvider = Provider<DeadlineRepository>((ref) {
  throw UnimplementedError('deadlineRepositoryProvider must be overridden');
});
