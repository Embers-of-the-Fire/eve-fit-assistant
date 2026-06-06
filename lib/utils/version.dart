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

String stripBuildNumber(String version) {
  final plusIndex = version.indexOf("+");
  if (plusIndex == -1) return version;
  return version.substring(0, plusIndex);
}

int compareAppVersions(String a, String b) {
  final aStripped = stripBuildNumber(a);
  final bStripped = stripBuildNumber(b);

  final aParts = _splitSemver(aStripped);
  final bParts = _splitSemver(bStripped);

  final coreCmp = _compareDotSeparatedInts(aParts.core, bParts.core);
  if (coreCmp != 0) return coreCmp;

  if (aParts.pre == null && bParts.pre == null) return 0;
  if (aParts.pre == null) return 1;
  if (bParts.pre == null) return -1;

  final aPre = _parsePreRelease(aParts.pre!);
  final bPre = _parsePreRelease(bParts.pre!);

  final labelCmp = aPre.label.compareTo(bPre.label);
  if (labelCmp != 0) return labelCmp;

  return aPre.num.compareTo(bPre.num);
}

({String core, String? pre}) _splitSemver(String version) {
  final dashIndex = version.indexOf("-");
  if (dashIndex == -1) return (core: version, pre: null);
  return (core: version.substring(0, dashIndex), pre: version.substring(dashIndex + 1));
}

int _compareDotSeparatedInts(String a, String b) => compareVersions(a, b);

({String label, int num}) _parsePreRelease(String pre) {
  final lastDot = pre.lastIndexOf(".");
  if (lastDot == -1) return (label: pre, num: 0);
  final label = pre.substring(0, lastDot);
  final num = int.tryParse(pre.substring(lastDot + 1)) ?? 0;
  return (label: label, num: num);
}
