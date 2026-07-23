import "dart:io" show Platform;

/// Target platforms for announcement entries.
///
/// Values must match [Platform.operatingSystem] strings and the
/// `AnnouncementPlatform` enum in `bootstrap/docs/announcements_remote.py`.
enum AnnouncementPlatform {
  android,
  ios,
  linux,
  macos,
  windows,
  fuchsia,

  /// Forward-compat sentinel for platforms published by a newer server
  /// schema that this client does not know yet.
  unknown;

  static final Map<String, AnnouncementPlatform> _byName = values.asNameMap();

  /// Resolve a [Platform.operatingSystem] string to a platform, or null if
  /// the OS is not a known announcement platform.
  static AnnouncementPlatform? fromOperatingSystem(String operatingSystem) =>
      _byName[operatingSystem];

  /// The platform the app is currently running on, or null if unknown.
  static AnnouncementPlatform? get current => fromOperatingSystem(Platform.operatingSystem);
}
