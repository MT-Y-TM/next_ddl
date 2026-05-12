class Milestone {
  const Milestone({
    required this.id,
    required this.title,
    required this.dueAtUtc,
    required this.source,
  });

  final String id;
  final String title;
  final DateTime dueAtUtc;
  final MilestoneSource source;

  Milestone copyWith({
    String? id,
    String? title,
    DateTime? dueAtUtc,
    MilestoneSource? source,
  }) {
    return Milestone(
      id: id ?? this.id,
      title: title ?? this.title,
      dueAtUtc: dueAtUtc ?? this.dueAtUtc,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueAtUtc': dueAtUtc.toIso8601String(),
        'source': source.name,
      };

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'] as String,
      title: json['title'] as String,
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
