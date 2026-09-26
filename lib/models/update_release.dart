class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.contentType,
    required this.size,
    this.id,
    this.digest,
  });

  final String name;
  final String browserDownloadUrl;
  final String contentType;
  final int size;
  final int? id;
  final String? digest;

  String? get sha256 {
    final value = digest?.toLowerCase();
    return value != null && RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(value)
        ? value.substring(7)
        : null;
  }

  UpdateAsset withSha256(String value) => UpdateAsset(
    name: name,
    browserDownloadUrl: browserDownloadUrl,
    contentType: contentType,
    size: size,
    id: id,
    digest: 'sha256:$value',
  );

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    return UpdateAsset(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      id: json['id'] as int?,
      digest: json['digest'] as String?,
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

  UpdateRelease withApkChecksum(String checksum) => UpdateRelease(
    tagName: tagName,
    version: version,
    publishedAtUtc: publishedAtUtc,
    body: body,
    htmlUrl: htmlUrl,
    assets: assets
        .map((a) => a == androidApkAsset ? a.withSha256(checksum) : a)
        .toList(),
  );

  bool get hasChecksumSource =>
      androidApkAsset?.sha256 != null ||
      assets.any((a) => a.name == 'app-release.apk.sha256');

  String get notesSummary => body
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
      .replaceAll('`', '')
      .trim();

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
      assets:
          ((json['assets'] as List<dynamic>? ?? const [])
                  .cast<Map<String, dynamic>>())
              .map(UpdateAsset.fromJson)
              .toList(),
    );
  }
}
