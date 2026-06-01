int compareVersions(String a, String b) {
  final aParts = a.split(".").map(int.tryParse).toList();
  final bParts = b.split(".").map(int.tryParse).toList();

  final length = aParts.length > bParts.length ? aParts.length : bParts.length;

  for (var i = 0; i < length; i++) {
    final aVal = i < aParts.length ? (aParts[i] ?? 0) : 0;
    final bVal = i < bParts.length ? (bParts[i] ?? 0) : 0;
    final cmp = aVal.compareTo(bVal);
    if (cmp != 0) {
      return cmp;
    }
  }

  return 0;
}

bool isAppVersionBelow(String current, String required) {
  if (current.isEmpty || required.isEmpty) {
    return false;
  }
  return compareVersions(current, required) < 0;
}
