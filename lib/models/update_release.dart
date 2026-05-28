class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.contentType,
    required this.size,
  });

  final String name;
  final String browserDownloadUrl;
  final String contentType;
  final int size;

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    return UpdateAsset(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      size: json['size'] as int? ?? 0,
    );
  }
}

class UpdateRelease {
  const UpdateRelease({
    required this.tagName,
    required this.version,
    required this.publishedAtUtc,
    required this.body,
    required this.htmlUrl,
    required this.assets,
  });

  final String tagName;
  final String version;
  final DateTime publishedAtUtc;
  final String body;
  final String htmlUrl;
  final List<UpdateAsset> assets;

  UpdateAsset? get androidApkAsset {
    for (final asset in assets) {
      if (asset.name == 'app-release.apk') {
        return asset;
      }
    }
    return null;
  }

  factory UpdateRelease.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    return UpdateRelease(
      tagName: tagName,
      version: tagName.replaceFirst(RegExp(r'^[vV]'), ''),
      publishedAtUtc: DateTime.parse(
        json['published_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
      body: (json['body'] as String? ?? '').trim(),
      htmlUrl: json['html_url'] as String? ?? '',
      assets: ((json['assets'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
          .map(UpdateAsset.fromJson)
          .toList(),
    );
  }
}
