import "package:efa_proto/release_index.pb.dart";
import "package:fixnum/fixnum.dart";
import "package:eve_fit_assistant/features/app_update/platform/update_platform.dart";
import "package:flutter_test/flutter_test.dart";

AndroidArtifactVariant _androidVariant(String name) =>
    AndroidArtifactVariant(identifier: "ident/$name", contentHash: "hash-$name", size: Int64(100));

LinuxArtifactVariant _linuxVariant(String name) =>
    LinuxArtifactVariant(identifier: "ident/$name", contentHash: "hash-$name", size: Int64(100));

WindowsArtifactVariant _windowsVariant(String name) =>
    WindowsArtifactVariant(identifier: "ident/$name", contentHash: "hash-$name", size: Int64(100));

ReleaseIndex _index({
  AndroidArtifacts? android,
  LinuxArtifacts? linux,
  WindowsArtifacts? windows,
}) => ReleaseIndex(
  schemaVersion: 1,
  id: "rel-1",
  version: "2.0.0",
  android: android,
  linux: linux,
  windows: windows,
);

void main() {
  group("AndroidAppUpdateAdapter", () {
    const adapter = AndroidAppUpdateAdapter();

    test("supports self update", () {
      expect(adapter.supportsSelfUpdate, isTrue);
    });

    test("hasArtifacts requires the general APK", () {
      expect(adapter.hasArtifacts(_index()), isFalse);
      expect(adapter.hasArtifacts(_index(android: AndroidArtifacts())), isFalse);
      expect(
        adapter.hasArtifacts(_index(android: AndroidArtifacts(general: _androidVariant("g")))),
        isTrue,
      );
    });

    test("downloadTargets lists present variants in order", () {
      final index = _index(
        android: AndroidArtifacts(
          general: _androidVariant("general"),
          arm64: _androidVariant("arm64"),
          x64: _androidVariant("x64"),
        ),
      );

      final targets = adapter.downloadTargets(index);

      expect(targets.map((t) => t.variant), ["general", "arm64", "x64"]);
      expect(targets.first.identifier, "ident/general");
      expect(targets.first.contentHash, "hash-general");
      expect(targets.first.size, 100);
    });

    test("downloadTargets is empty without artifacts", () {
      expect(adapter.downloadTargets(_index()), isEmpty);
    });
  });

  group("LinuxAppUpdateAdapter", () {
    const adapter = LinuxAppUpdateAdapter();

    test("does not support self update", () {
      expect(adapter.supportsSelfUpdate, isFalse);
    });

    test("hasArtifacts requires at least one linux variant", () {
      expect(adapter.hasArtifacts(_index()), isFalse);
      expect(adapter.hasArtifacts(_index(linux: LinuxArtifacts())), isFalse);
      expect(
        adapter.hasArtifacts(_index(linux: LinuxArtifacts(appimage: _linuxVariant("a")))),
        isTrue,
      );
      expect(
        adapter.hasArtifacts(_index(linux: LinuxArtifacts(native: _linuxVariant("n")))),
        isTrue,
      );
    });

    test("downloadTargets lists appimage before native", () {
      final index = _index(
        linux: LinuxArtifacts(appimage: _linuxVariant("appimage"), native: _linuxVariant("native")),
      );

      final targets = adapter.downloadTargets(index);

      expect(targets.map((t) => t.variant), ["appimage", "native"]);
      expect(targets.last.identifier, "ident/native");
      expect(targets.last.contentHash, "hash-native");
    });

    test("downloadTargets is empty without artifacts", () {
      expect(adapter.downloadTargets(_index()), isEmpty);
    });
  });

  group("WindowsAppUpdateAdapter", () {
    const adapter = WindowsAppUpdateAdapter();

    test("does not support self update", () {
      expect(adapter.supportsSelfUpdate, isFalse);
    });

    test("hasArtifacts requires at least one windows variant", () {
      expect(adapter.hasArtifacts(_index()), isFalse);
      expect(adapter.hasArtifacts(_index(windows: WindowsArtifacts())), isFalse);
      expect(
        adapter.hasArtifacts(_index(windows: WindowsArtifacts(installer: _windowsVariant("i")))),
        isTrue,
      );
      expect(
        adapter.hasArtifacts(_index(windows: WindowsArtifacts(native: _windowsVariant("n")))),
        isTrue,
      );
    });

    test("downloadTargets lists installer before native", () {
      final index = _index(
        windows: WindowsArtifacts(
          installer: _windowsVariant("installer"),
          native: _windowsVariant("native"),
        ),
      );

      final targets = adapter.downloadTargets(index);

      expect(targets.map((t) => t.variant), ["installer", "native"]);
      expect(targets.last.identifier, "ident/native");
      expect(targets.last.contentHash, "hash-native");
    });

    test("downloadTargets is empty without artifacts", () {
      expect(adapter.downloadTargets(_index()), isEmpty);
    });
  });

  group("UnsupportedAppUpdateAdapter", () {
    const adapter = UnsupportedAppUpdateAdapter();

    test("never has artifacts nor self update", () {
      expect(
        adapter.hasArtifacts(
          _index(
            android: AndroidArtifacts(general: _androidVariant("g")),
            linux: LinuxArtifacts(appimage: _linuxVariant("a")),
          ),
        ),
        isFalse,
      );
      expect(adapter.supportsSelfUpdate, isFalse);
      expect(adapter.downloadTargets(_index()), isEmpty);
    });
  });
}
