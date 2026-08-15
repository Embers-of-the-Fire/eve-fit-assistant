import "package:efa_compat/io.dart";

import "package:efa_proto/release_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// A manually downloadable artifact of a release for the current platform.
class ReleaseDownloadTarget {
  const ReleaseDownloadTarget({
    required this.variant,
    required this.identifier,
    required this.contentHash,
    required this.size,
  });

  /// Variant key within the platform artifact set (e.g. `appimage`, `native`).
  final String variant;

  /// Content-addressed identifier of the artifact blob.
  final String identifier;

  /// Expected SHA-256 of the artifact blob.
  final String contentHash;

  /// Artifact size in bytes.
  final int size;

  /// Resolves the content-addressed download URI for this target. The URI can
  /// be opened in a browser on any platform.
  Uri downloadUri(RemoteCatalogService catalog) =>
      catalog.blobUri(RepoHash.hashIdent(identifier), contentHash);
}

/// Platform-specific behavior for app release updates.
///
/// Implementations decide whether a release carries artifacts usable on the
/// current platform ([hasArtifacts]), whether the in-app download/install
/// session is supported ([supportsSelfUpdate]), and which artifacts are
/// offered for manual download ([downloadTargets]).
abstract class AppUpdatePlatformAdapter {
  const AppUpdatePlatformAdapter();

  /// Whether [index] carries at least one artifact usable on this platform.
  ///
  /// Releases without a usable artifact are not actionable and are filtered
  /// out of update notifications.
  bool hasArtifacts(ReleaseIndex index);

  /// Whether this platform supports the in-app download/install session.
  /// Platforms without self-update support surface manual-download UIs
  /// instead.
  bool get supportsSelfUpdate;

  /// Manually downloadable targets for this platform, in display order.
  List<ReleaseDownloadTarget> downloadTargets(ReleaseIndex index);
}

/// Android: in-app APK download/install with ABI variant selection.
class AndroidAppUpdateAdapter extends AppUpdatePlatformAdapter {
  const AndroidAppUpdateAdapter();

  @override
  bool hasArtifacts(ReleaseIndex index) => index.hasAndroid() && index.android.hasGeneral();

  @override
  bool get supportsSelfUpdate => true;

  @override
  List<ReleaseDownloadTarget> downloadTargets(ReleaseIndex index) {
    if (!hasArtifacts(index)) return const [];
    final artifacts = index.android;
    return [
      _androidTarget("general", artifacts.general),
      if (artifacts.hasArm64()) _androidTarget("arm64", artifacts.arm64),
      if (artifacts.hasArmv7()) _androidTarget("armv7", artifacts.armv7),
      if (artifacts.hasX64()) _androidTarget("x64", artifacts.x64),
    ];
  }

  ReleaseDownloadTarget _androidTarget(String variant, AndroidArtifactVariant artifact) =>
      ReleaseDownloadTarget(
        variant: variant,
        identifier: artifact.identifier,
        contentHash: artifact.contentHash,
        size: artifact.size.toInt(),
      );
}

/// Linux: no self-update support; the AppImage and the portable archive are
/// offered as manual downloads.
class LinuxAppUpdateAdapter extends AppUpdatePlatformAdapter {
  const LinuxAppUpdateAdapter();

  @override
  bool hasArtifacts(ReleaseIndex index) =>
      index.hasLinux() && (index.linux.hasAppimage() || index.linux.hasNative());

  @override
  bool get supportsSelfUpdate => false;

  @override
  List<ReleaseDownloadTarget> downloadTargets(ReleaseIndex index) {
    if (!hasArtifacts(index)) return const [];
    final artifacts = index.linux;
    return [
      if (artifacts.hasAppimage())
        ReleaseDownloadTarget(
          variant: "appimage",
          identifier: artifacts.appimage.identifier,
          contentHash: artifacts.appimage.contentHash,
          size: artifacts.appimage.size.toInt(),
        ),
      if (artifacts.hasNative())
        ReleaseDownloadTarget(
          variant: "native",
          identifier: artifacts.native.identifier,
          contentHash: artifacts.native.contentHash,
          size: artifacts.native.size.toInt(),
        ),
    ];
  }
}

/// Windows: no self-update support; the MSI installer and the portable
/// archive are offered as manual downloads.
class WindowsAppUpdateAdapter extends AppUpdatePlatformAdapter {
  const WindowsAppUpdateAdapter();

  @override
  bool hasArtifacts(ReleaseIndex index) =>
      index.hasWindows() && (index.windows.hasInstaller() || index.windows.hasNative());

  @override
  bool get supportsSelfUpdate => false;

  @override
  List<ReleaseDownloadTarget> downloadTargets(ReleaseIndex index) {
    if (!hasArtifacts(index)) return const [];
    final artifacts = index.windows;
    return [
      if (artifacts.hasInstaller())
        ReleaseDownloadTarget(
          variant: "installer",
          identifier: artifacts.installer.identifier,
          contentHash: artifacts.installer.contentHash,
          size: artifacts.installer.size.toInt(),
        ),
      if (artifacts.hasNative())
        ReleaseDownloadTarget(
          variant: "native",
          identifier: artifacts.native.identifier,
          contentHash: artifacts.native.contentHash,
          size: artifacts.native.size.toInt(),
        ),
    ];
  }
}

/// Fallback for platforms with no artifact support at all.
class UnsupportedAppUpdateAdapter extends AppUpdatePlatformAdapter {
  const UnsupportedAppUpdateAdapter();

  @override
  bool hasArtifacts(ReleaseIndex index) => false;

  @override
  bool get supportsSelfUpdate => false;

  @override
  List<ReleaseDownloadTarget> downloadTargets(ReleaseIndex index) => const [];
}

/// Detects the update behavior for the host platform.
AppUpdatePlatformAdapter detectAppUpdatePlatform() {
  if (Platform.isAndroid) return const AndroidAppUpdateAdapter();
  if (Platform.isLinux) return const LinuxAppUpdateAdapter();
  if (Platform.isWindows) return const WindowsAppUpdateAdapter();
  return const UnsupportedAppUpdateAdapter();
}

/// The active update platform adapter. Override in tests to simulate a
/// different platform.
final appUpdatePlatformAdapterProvider = Provider<AppUpdatePlatformAdapter>(
  (ref) => detectAppUpdatePlatform(),
);
