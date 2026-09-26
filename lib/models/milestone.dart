class Milestone {
  const Milestone({
    required this.id,
    required this.title,
    required this.dueAtUtc,
    required this.source,
    this.completedAtUtc,
  });

  final String id;
  final String title;
  final DateTime dueAtUtc;
  final MilestoneSource source;
  final DateTime? completedAtUtc;
  bool get isCompleted => completedAtUtc != null;

  Milestone copyWith({
    String? id,
    String? title,
    DateTime? dueAtUtc,
    MilestoneSource? source,
    DateTime? completedAtUtc,
    bool clearCompletedAt = false,
  }) {
    return Milestone(
      id: id ?? this.id,
      title: title ?? this.title,
      dueAtUtc: dueAtUtc ?? this.dueAtUtc,
      source: source ?? this.source,
      completedAtUtc: clearCompletedAt ? null : completedAtUtc ?? this.completedAtUtc,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueAtUtc': dueAtUtc.toIso8601String(),
        'source': source.name,
        'completedAtUtc': completedAtUtc?.toIso8601String(),
      };

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'] as String,
      title: json['title'] as String,
      completedAtUtc: DateTime.tryParse(json['completedAtUtc'] as String? ?? '')?.toUtc(),
      dueAtUtc: DateTime.parse(json['dueAtUtc'] as String).toUtc(),
      source: MilestoneSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => MilestoneSource.manual,
      ),
    );
  }
}

enum MilestoneSource {
  manual,
  generated,
}
