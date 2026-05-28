List<int> parseSemanticVersion(String value) {
  final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
  final core = normalized.split('-').first;
  final parts = core.split('.');
  return [
    for (var index = 0; index < 3; index++)
      if (index < parts.length) int.tryParse(parts[index]) ?? 0 else 0,
  ];
}

int compareSemanticVersions(String left, String right) {
  final leftParts = parseSemanticVersion(left);
  final rightParts = parseSemanticVersion(right);
  for (var index = 0; index < 3; index++) {
    final delta = leftParts[index].compareTo(rightParts[index]);
    if (delta != 0) {
      return delta;
    }
  }
  return 0;
}

bool isNewerSemanticVersion(String candidate, String current) {
  return compareSemanticVersions(candidate, current) > 0;
}
