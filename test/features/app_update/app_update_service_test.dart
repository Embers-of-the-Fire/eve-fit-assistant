@TestOn("vm")
library;

import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:dio/io.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/app_update/app_update_service.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class _MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

class _FakeAppUpdatePlatform extends AppUpdatePlatform {
  List<String> abis = <String>[];
  bool canInstall = false;
  String? lastOpenedSettings;
  String? lastInstalledPath;

  @override
  Future<List<String>> getSupportedAbis() async => abis;

  @override
  Future<bool> canRequestPackageInstalls() async => canInstall;

  @override
  Future<void> openInstallPermissionSettings() async {
    lastOpenedSettings = "opened";
  }

  @override
  Future<void> installApk(String apkPath) async {
    lastInstalledPath = apkPath;
  }
}

class _ChunkedFakeAdapter implements HttpClientAdapter {
  _ChunkedFakeAdapter(this.data, {this.chunkSize = 16});

  final Uint8List data;
  final int chunkSize;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final controller = StreamController<Uint8List>.broadcast();
    var offset = 0;
    Timer.periodic(const Duration(milliseconds: 1), (timer) {
      if (offset >= data.length) {
        timer.cancel();
        controller.close();
        return;
      }
      final end = (offset + chunkSize).clamp(0, data.length);
      controller.add(data.sublist(offset, end));
      offset = end;
    });
    return ResponseBody(
      controller.stream,
      200,
      headers: {
        Headers.contentLengthHeader: [data.length.toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MockRemoteCatalogService remoteCatalog;
  late _FakeAppUpdatePlatform platform;
  late String tempDir;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_app_update_service_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    remoteCatalog = _MockRemoteCatalogService();
    platform = _FakeAppUpdatePlatform();
    tempDir = Directory.systemTemp.createTempSync("efa_app_update_service_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.cachesPath = tempDir;
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  AppUpdateService _service({Dio Function()? dioFactory}) => AppUpdateService(
    remoteCatalogService: remoteCatalog,
    platform: platform,
    dioFactory: dioFactory ?? (() => _createTestDio()),
  );

  AndroidArtifacts _artifacts({
    String? arm64Hash,
    int? arm64Size,
    String? generalHash,
    int? generalSize,
  }) {
    final aa = AndroidArtifacts();
    if (generalHash != null) {
      aa.general = AndroidArtifactVariant(
        identifier: "release://1.0.0/android/general",
        contentHash: generalHash,
        size: Int64(generalSize ?? 0),
      );
    }
    if (arm64Hash != null) {
      aa.arm64 = AndroidArtifactVariant(
        identifier: "release://1.0.0/android/arm64",
        contentHash: arm64Hash,
        size: Int64(arm64Size ?? 0),
      );
    }
    return aa;
  }

  test("resolveArtifact picks arm64 when ABI matches", () async {
    platform.abis = <String>["arm64-v8a"];
    final artifacts = _artifacts(arm64Hash: "aa" * 32, arm64Size: 100);

    final result = await _service().resolveArtifact(artifacts);

    expect(result.isRight(), isTrue);
    final artifact = result.getRight().toNullable()!;
    expect(artifact.variant, "arm64");
  });

  test("resolveArtifact falls back to general when ABI does not match", () async {
    platform.abis = <String>["x86_64"];
    final artifacts = _artifacts(
      generalHash: "bb" * 32,
      generalSize: 100,
      arm64Hash: "aa" * 32,
      arm64Size: 100,
    );

    final result = await _service().resolveArtifact(artifacts);

    expect(result.isRight(), isTrue);
    final artifact = result.getRight().toNullable()!;
    expect(artifact.variant, "general");
  });

  test("resolveArtifact returns error when no artifact available", () async {
    platform.abis = <String>[];
    final artifacts = AndroidArtifacts();

    final result = await _service().resolveArtifact(artifacts);

    expect(result.isLeft(), isTrue);
  });

  test("downloadArtifact writes file and verifies hash", () async {
    final apkData = Uint8List.fromList(List<int>.generate(1024, (index) => index % 256));
    final contentHash = sha256.convert(apkData).toString();
    final identifier = "release://1.0.0/android/general";
    final artifact = AppUpdateArtifact(
      variant: "general",
      identifier: identifier,
      contentHash: contentHash,
      size: apkData.length,
    );

    final tempApkFile = File("$tempDir/remote.apk");
    tempApkFile.writeAsBytesSync(apkData);

    final identHash = RepoHash.hashIdent(identifier);
    when(
      () => remoteCatalog.blobUri(identHash, contentHash),
    ).thenReturn(Uri.parse("http://localhost:0/${tempApkFile.path}"));

    Dio createDio() => Dio()..httpClientAdapter = _ChunkedFakeAdapter(apkData, chunkSize: 64);

    final progressEvents = <(int received, int total)>[];
    final result = await _service(dioFactory: createDio).downloadArtifact(
      artifact,
      onProgress: (received, total) => progressEvents.add((received, total)),
    );

    if (result.isLeft()) {
      fail("download failed: ${result.getLeft().toNullable()}");
    }
    final apkPath = result.getRight().toNullable()!;
    expect(File(apkPath).existsSync(), isTrue);
    expect(File(apkPath).lengthSync(), apkData.length);
    expect(progressEvents, isNotEmpty);
    final last = progressEvents.last;
    expect(last.$1, apkData.length);
    expect(last.$2, apkData.length);
  });

  test("downloadArtifact emits progress ending at full size", () async {
    final apkData = Uint8List.fromList(List<int>.generate(100, (index) => index % 256));
    final contentHash = sha256.convert(apkData).toString();
    final identifier = "release://1.0.0/android/general";
    final artifact = AppUpdateArtifact(
      variant: "general",
      identifier: identifier,
      contentHash: contentHash,
      size: apkData.length,
    );

    final tempApkFile = File("$tempDir/remote.apk");
    tempApkFile.writeAsBytesSync(apkData);

    final identHash = RepoHash.hashIdent(artifact.identifier);
    when(
      () => remoteCatalog.blobUri(identHash, artifact.contentHash),
    ).thenReturn(Uri.parse("http://localhost:0/${tempApkFile.path}"));

    Dio createDio() => Dio()..httpClientAdapter = _ChunkedFakeAdapter(apkData, chunkSize: 16);

    final progressEvents = <(int received, int total)>[];
    final result = await _service(dioFactory: createDio).downloadArtifact(
      artifact,
      onProgress: (received, total) => progressEvents.add((received, total)),
    );

    if (result.isLeft()) {
      fail("download failed: ${result.getLeft().toNullable()}");
    }
    final apkPath = result.getRight().toNullable()!;
    expect(File(apkPath).existsSync(), isTrue);
    expect(File(apkPath).lengthSync(), apkData.length);
    expect(progressEvents, isNotEmpty);
    final last = progressEvents.last;
    expect(last.$1, apkData.length);
    expect(last.$2, apkData.length);
  });

  test("install succeeds when permission granted", () async {
    platform.canInstall = true;

    final result = await _service().install("/tmp/test.apk");

    expect(result.isRight(), isTrue);
    expect(platform.lastInstalledPath, "/tmp/test.apk");
  });

  test("install fails when permission denied", () async {
    platform.canInstall = false;

    final result = await _service().install("/tmp/test.apk");

    expect(result.isLeft(), isTrue);
    expect(platform.lastInstalledPath, isNull);
  });

  test("resolveDownloadUri returns blob URI for matching ABI", () async {
    platform.abis = <String>["arm64-v8a"];
    final artifacts = _artifacts(arm64Hash: "aa" * 32, arm64Size: 100);
    final identHash = RepoHash.hashIdent("release://1.0.0/android/arm64");
    final expected = Uri.parse("https://example.com/blobs/$identHash/${"aa" * 32}");
    when(() => remoteCatalog.blobUri(identHash, "aa" * 32)).thenReturn(expected);

    final uri = await _service().resolveDownloadUri(artifacts);

    expect(uri, expected);
  });

  test("resolveDownloadUri falls back to general artifact", () async {
    platform.abis = <String>["x86_64"];
    final artifacts = _artifacts(generalHash: "bb" * 32, generalSize: 100);
    final identHash = RepoHash.hashIdent("release://1.0.0/android/general");
    final expected = Uri.parse("https://example.com/blobs/$identHash/${"bb" * 32}");
    when(() => remoteCatalog.blobUri(identHash, "bb" * 32)).thenReturn(expected);

    final uri = await _service().resolveDownloadUri(artifacts);

    expect(uri, expected);
  });

  test("resolveDownloadUri returns null when no artifact available", () async {
    platform.abis = <String>[];

    final uri = await _service().resolveDownloadUri(AndroidArtifacts());

    expect(uri, isNull);
  });

  test("clearCache removes update files", () async {
    final updatesDir = Directory("$tempDir/resources/updates");
    updatesDir.createSync(recursive: true);
    final file = File("${updatesDir.path}/test.apk");
    file.writeAsStringSync("test");

    _service().clearCache();

    expect(file.existsSync(), isFalse);
  });
}

Dio _createTestDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 1),
    sendTimeout: const Duration(seconds: 1),
    receiveTimeout: const Duration(seconds: 1),
  ),
);
