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

/// Returns true when upgrading from [installed] to [remote] only changes the
/// "bugfix" component of the version: the patch component for 0.x versions,
/// or the minor/patch components for versions >= 1.0 (only major bumps are
/// considered feature updates there). Any prerelease change, downgrade, or
/// unparseable version is never bugfix-only.
bool isBugfixOnlyUpgrade({required String installed, required String remote}) {
  final installedVersion = _parseVersionComponents(installed);
  final remoteVersion = _parseVersionComponents(remote);
  if (installedVersion == null || remoteVersion == null) return false;
  if (installedVersion.pre != remoteVersion.pre) return false;
  if (remoteVersion.major != installedVersion.major) return false;
  if (installedVersion.major == 0) {
    return remoteVersion.minor == installedVersion.minor &&
        remoteVersion.patch > installedVersion.patch;
  }
  if (remoteVersion.minor != installedVersion.minor) {
    return remoteVersion.minor > installedVersion.minor;
  }
  return remoteVersion.patch > installedVersion.patch;
}

({int major, int minor, int patch, String? pre})? _parseVersionComponents(String version) {
  var value = stripBuildNumber(version).trim();
  if (value.toLowerCase().startsWith("v")) value = value.substring(1);
  final parts = _splitSemver(value);
  final segments = parts.core.split(".");
  int? segmentAt(int index) => index < segments.length ? int.tryParse(segments[index]) : 0;
  final major = segmentAt(0);
  final minor = segmentAt(1);
  final patch = segmentAt(2);
  if (major == null || minor == null || patch == null) return null;
  return (major: major, minor: minor, patch: patch, pre: parts.pre);
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
