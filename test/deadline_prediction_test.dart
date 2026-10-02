import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/services/deadline_prediction_service.dart';

DeadlineTask _task(
  String id,
  DateTime created,
  Duration planned, {
  List<String> tags = const [],
  DateTime? completed,
}) => DeadlineTask(
  id: id,
  title: id,
  note: '',
  timezoneId: 'UTC',
  createdAtUtc: created,
  updatedAtUtc: created,
  finalDueAtUtc: created.add(planned),
  milestones: const [],
  reminderOffsetsSeconds: const [],
  notificationsEnabled: false,
  tags: tags,
  completedAtUtc: completed,
);

void main() {
  final now = DateTime.utc(2040, 1, 1);
  const service = DeadlinePredictionService();

  test('uses the stable three-day fallback without history', () {
    final result = service.predict(const [], nowUtc: now);
    expect(result.duration, const Duration(days: 3));
    expect(result.sampleCount, 0);
  });

  test('weights similar tags and keeps a conservative percentile', () {
    final tasks = [
      _task(
        'short',
        now.subtract(const Duration(days: 10)),
        const Duration(days: 1),
      ),
      _task(
        'similar',
        now.subtract(const Duration(days: 8)),
        const Duration(days: 5),
        tags: ['work'],
        completed: now.subtract(const Duration(days: 3)),
      ),
      _task(
        'similar-late',
        now.subtract(const Duration(days: 7)),
        const Duration(days: 7),
        tags: ['work'],
        completed: now,
      ),
    ];
    final result = service.predict(tasks, nowUtc: now, tags: ['work']);
    expect(result.sampleCount, 3);
    expect(result.duration, greaterThan(const Duration(days: 3)));
    expect(result.duration, lessThanOrEqualTo(const Duration(days: 7)));
  });

  test('legacy task data remains compatible with defaults', () {
    final task = _task('legacy', now, const Duration(days: 2));
    final decoded = DeadlineTask.fromJson(task.toJson());
    expect(decoded.tags, isEmpty);
    expect(decoded.finalDueAtUtc, task.finalDueAtUtc);
  });
}
