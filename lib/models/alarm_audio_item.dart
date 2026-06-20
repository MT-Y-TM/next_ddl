class AlarmAudioItem {
  const AlarmAudioItem({
    required this.id,
    required this.displayName,
    required this.uri,
  });

  final String id;
  final String displayName;
  final String uri;

  AlarmAudioItem copyWith({
    String? id,
    String? displayName,
    String? uri,
  }) {
    return AlarmAudioItem(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      uri: uri ?? this.uri,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'uri': uri,
      };

  factory AlarmAudioItem.fromJson(Map<String, dynamic> json) {
    return AlarmAudioItem(
      id: (json['id'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      uri: (json['uri'] as String?) ?? '',
    );
  }
}
