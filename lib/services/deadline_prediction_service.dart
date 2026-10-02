import '../models/deadline_task.dart';

class DeadlinePrediction {
  const DeadlinePrediction({required this.duration, required this.sampleCount});

  final Duration duration;
  final int sampleCount;
}

class DeadlinePredictionService {
  const DeadlinePredictionService();

  DeadlinePrediction predict(
    List<DeadlineTask> tasks, {
    DateTime? nowUtc,
    String title = '',
    List<String> tags = const [],
  }) {
    final candidates = tasks
        .where((task) => task.createdAtUtc.isBefore(task.finalDueAtUtc))
        .toList();
    if (candidates.isEmpty) {
      return const DeadlinePrediction(
        duration: Duration(days: 3),
        sampleCount: 0,
      );
    }

    final normalizedTags = tags.map((tag) => tag.trim().toLowerCase()).toSet();
    final weighted = <({double value, double weight})>[];
    for (final task in candidates) {
      var weight = 1.0;
      final taskTags = task.tags.map((tag) => tag.toLowerCase()).toSet();
      final commonTags = normalizedTags.intersection(taskTags).length;
      if (commonTags > 0) weight += commonTags * 2.0;
      if (title.trim().isNotEmpty && _titleOverlap(title, task.title) > 0) {
        weight += 1.5;
      }
      if (task.isCompleted &&
          task.completedAtUtc!.isAfter(task.finalDueAtUtc)) {
        weight *= 1.25;
      }
      final hours =
          task.finalDueAtUtc.difference(task.createdAtUtc).inMinutes / 60.0;
      weighted.add((value: hours.clamp(1, 24 * 90), weight: weight));
    }

    weighted.sort((a, b) => a.value.compareTo(b.value));
    final totalWeight = weighted.fold<double>(
      0,
      (sum, item) => sum + item.weight,
    );
    var cursor = 0.0;
    var percentile = weighted.last.value;
    for (final item in weighted) {
      cursor += item.weight;
      if (cursor >= totalWeight * 0.75) {
        percentile = item.value;
        break;
      }
    }
    final average =
        weighted.fold<double>(
          0,
          (sum, item) => sum + item.value * item.weight,
        ) /
        totalWeight;
    final predictedHours = ((percentile * 0.7) + (average * 0.3)).clamp(
      1,
      24 * 90,
    );
    return DeadlinePrediction(
      duration: Duration(minutes: (predictedHours * 60).round()),
      sampleCount: candidates.length,
    );
  }

  double _titleOverlap(String left, String right) {
    final leftWords = _words(left);
    final rightWords = _words(right);
    if (leftWords.isEmpty || rightWords.isEmpty) return 0;
    return leftWords.intersection(rightWords).isNotEmpty ? 1 : 0;
  }

  Set<String> _words(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((item) => item.length >= 2)
      .toSet();
}
