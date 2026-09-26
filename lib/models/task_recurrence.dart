import 'package:timezone/timezone.dart' as tz;
import 'task_template.dart';

enum RecurrenceFrequency { daily, weekly, monthly }

enum MonthEndPolicy { skip, lastDay }

enum RecurrenceStatus { active, paused, terminated }

/// ISO civil date, independent of the host's timezone.
String planningDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parsePlanningDate(String value) {
  final d = DateTime.tryParse('${value}T00:00:00Z');
  if (d == null || planningDateKey(d) != value) {
    throw const FormatException('Invalid civil date');
  }
  return d;
}

class TaskRecurrenceRule {
  TaskRecurrenceRule({
    required this.frequency,
    required this.timezoneId,
    required this.startDate,
    this.endDate,
    this.hour = 9,
    this.minute = 0,
    Set<int> weekdays = const {1},
    this.monthDay = 1,
    this.monthEndPolicy = MonthEndPolicy.skip,
  }) : weekdays = Set.unmodifiable(weekdays) {
    parsePlanningDate(startDate);
    if (endDate != null) parsePlanningDate(endDate!);
    tz.getLocation(timezoneId);
    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        monthDay < 1 ||
        monthDay > 31 ||
        weekdays.isEmpty ||
        weekdays.any((d) => d < 1 || d > 7) ||
        (endDate != null && endDate!.compareTo(startDate) < 0)) {
      throw const FormatException('Invalid recurrence rule');
    }
  }
  final RecurrenceFrequency frequency;
  final String timezoneId;
  final String startDate;
  final String? endDate;
  final int hour;
  final int minute;
  final Set<int> weekdays;
  final int monthDay;
  final MonthEndPolicy monthEndPolicy;

  /// DST gaps are skipped; folds choose the earlier UTC instant. Enumerating
  /// zone offsets avoids relying on timezone's constructor normalization.
  DateTime? dueOn(DateTime date) {
    final key = planningDateKey(date);
    if (key.compareTo(startDate) < 0 ||
        (endDate != null && key.compareTo(endDate!) > 0)) {
      return null;
    }
    if (frequency == RecurrenceFrequency.weekly &&
        !weekdays.contains(date.weekday)) {
      return null;
    }
    final last = DateTime.utc(date.year, date.month + 1, 0).day;
    final target = monthEndPolicy == MonthEndPolicy.lastDay && monthDay > last
        ? last
        : monthDay;
    if (frequency == RecurrenceFrequency.monthly && date.day != target) {
      return null;
    }
    final location = tz.getLocation(timezoneId);
    final wall = DateTime.utc(date.year, date.month, date.day, hour, minute);
    DateTime? earliest;
    for (final offset in location.zones.map((z) => z.offset).toSet()) {
      final candidate = wall.subtract(Duration(milliseconds: offset));
      final local = tz.TZDateTime.from(candidate, location);
      if (local.year == date.year &&
          local.month == date.month &&
          local.day == date.day &&
          local.hour == hour &&
          local.minute == minute &&
          (earliest == null || candidate.isBefore(earliest))) {
        earliest = candidate;
      }
    }
    return earliest;
  }

  Map<String, dynamic> toJson() => {
    'frequency': frequency.name,
    'timezoneId': timezoneId,
    'startDate': startDate,
    'endDate': endDate,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays.toList()..sort(),
    'monthDay': monthDay,
    'monthEndPolicy': monthEndPolicy.name,
  };
  factory TaskRecurrenceRule.fromJson(Map<String, dynamic> j) =>
      TaskRecurrenceRule(
        frequency: RecurrenceFrequency.values.byName(j['frequency'] as String),
        timezoneId: j['timezoneId'] as String? ?? 'UTC',
        startDate: j['startDate'] as String,
        endDate: j['endDate'] as String?,
        hour: j['hour'] as int? ?? 9,
        minute: j['minute'] as int? ?? 0,
        weekdays: (j['weekdays'] as List? ?? [1]).cast<int>().toSet(),
        monthDay: j['monthDay'] as int? ?? 1,
        monthEndPolicy: MonthEndPolicy.values.byName(
          j['monthEndPolicy'] as String? ?? 'skip',
        ),
      );
}

class RecurrenceRevision {
  RecurrenceRevision({
    required this.fromDate,
    required this.rule,
    required this.template,
  }) {
    parsePlanningDate(fromDate);
  }
  final String fromDate;
  final TaskRecurrenceRule rule;
  final TaskTemplate template;
  Map<String, dynamic> toJson() => {
    'fromDate': fromDate,
    'rule': rule.toJson(),
    'template': template.toJson(),
  };
  factory RecurrenceRevision.fromJson(Map<String, dynamic> j) =>
      RecurrenceRevision(
        fromDate: j['fromDate'] as String,
        rule: TaskRecurrenceRule.fromJson(
          Map<String, dynamic>.from(j['rule'] as Map),
        ),
        template: TaskTemplate.fromJson(
          Map<String, dynamic>.from(j['template'] as Map),
        ),
      );
}

class TaskRecurrence {
  TaskRecurrence({
    required this.id,
    required List<RecurrenceRevision> revisions,
    this.status = RecurrenceStatus.active,
  }) : revisions = List.unmodifiable(revisions) {
    if (id.isEmpty || revisions.isEmpty) {
      throw const FormatException('Invalid series');
    }
    for (var i = 1; i < revisions.length; i++) {
      if (revisions[i - 1].fromDate.compareTo(revisions[i].fromDate) >= 0) {
        throw const FormatException('Unsorted revisions');
      }
    }
  }
  final String id;
  final List<RecurrenceRevision> revisions;
  final RecurrenceStatus status;
  TaskRecurrence copyWith({
    List<RecurrenceRevision>? revisions,
    RecurrenceStatus? status,
  }) => TaskRecurrence(
    id: id,
    revisions: revisions ?? this.revisions,
    status: status ?? this.status,
  );
  RecurrenceRevision? revisionOn(String date) {
    for (final revision in revisions.reversed) {
      if (revision.fromDate.compareTo(date) <= 0) return revision;
    }
    return null;
  }

  String instanceId(String date) => 'planning/${Uri.encodeComponent(id)}/$date';
  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.name,
    'revisions': revisions.map((r) => r.toJson()).toList(),
  };
  factory TaskRecurrence.fromJson(Map<String, dynamic> j) => TaskRecurrence(
    id: j['id'] as String,
    status: RecurrenceStatus.values.byName(j['status'] as String? ?? 'active'),
    revisions: (j['revisions'] as List)
        .map(
          (r) =>
              RecurrenceRevision.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList(),
  );
}
