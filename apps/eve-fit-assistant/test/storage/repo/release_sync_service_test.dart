import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

class _FakeRemoteCatalogService extends RemoteCatalogService {
  _FakeRemoteCatalogService({this.generationPointerResult, this.releaseIndexResult})
    : super(dio: Dio(), originUrl: "https://test.local");

  Either<CatalogError, Uint8List>? generationPointerResult;
  Either<CatalogError, Uint8List>? releaseIndexResult;

  @override
  Future<Either<CatalogError, ChannelRegistry>> fetchChannelRegistry({
    Map<String, dynamic>? cachedPayload,
  }) async => Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, ChannelHeadMeta>> fetchHeadMeta(
    String channelName, {
    Map<String, dynamic>? cachedPayload,
  }) async => Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchServerIndex(String generationHash) async =>
      Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchGenerationResources(String generationHash) async =>
      Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchGenerationPointer(String generationHash) async =>
      generationPointerResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchReleaseIndex(String snapshotHash) async =>
      releaseIndexResult ?? Left(const CatalogNetworkError(message: "not configured"));
}

GenerationPointer _makePointer(String snapshotHash) =>
    GenerationPointer(schemaVersion: 1, snapshotHash: snapshotHash);

Uint8List _encodePointer(GenerationPointer pointer) => Uint8List.fromList(pointer.writeToBuffer());

ReleaseIndex _makeReleaseIndex({required String id, required String version}) =>
    ReleaseIndex(schemaVersion: 1, id: id, version: version);

Uint8List _encodeReleaseIndex(ReleaseIndex index) => Uint8List.fromList(index.writeToBuffer());

void main() {
  group("ReleaseSyncService", () {
    const snapshotHash = "sha256:abc123";
    const generationHash = "sha256:gen456";

    ReleaseSyncService _makeService({
      required _FakeRemoteCatalogService remote,
      String currentVersion = "1.0.0",
    }) => ReleaseSyncService(
      remoteCatalogService: remote,
      currentVersionProvider: () async => currentVersion,
    );

    test("returns Some when remote version is newer", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Right(_encodePointer(_makePointer(snapshotHash))),
        releaseIndexResult: Right(
          _encodeReleaseIndex(_makeReleaseIndex(id: "rel-2", version: "2.0.0")),
        ),
      );
      final service = _makeService(remote: remote, currentVersion: "1.0.0+42");

      final result = await service.check(generationHash: generationHash);

      expect(result.isRight(), isTrue);
      final release = result.getRight().toNullable()!.toNullable();
      expect(release, isNotNull);
      expect(release!.releaseId, "rel-2");
      expect(release.version, "2.0.0");
    });

    test("returns None when remote version equals installed", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Right(_encodePointer(_makePointer(snapshotHash))),
        releaseIndexResult: Right(
          _encodeReleaseIndex(_makeReleaseIndex(id: "rel-1", version: "1.0.0")),
        ),
      );
      final service = _makeService(remote: remote, currentVersion: "1.0.0");

      final result = await service.check(generationHash: generationHash);

      expect(result, const Right(None()));
    });

    test("returns None when remote version is older", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Right(_encodePointer(_makePointer(snapshotHash))),
        releaseIndexResult: Right(
          _encodeReleaseIndex(_makeReleaseIndex(id: "rel-0", version: "0.9.0")),
        ),
      );
      final service = _makeService(remote: remote, currentVersion: "1.0.0");

      final result = await service.check(generationHash: generationHash);

      expect(result, const Right(None()));
    });

    test("strips v prefix from both versions", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Right(_encodePointer(_makePointer(snapshotHash))),
        releaseIndexResult: Right(
          _encodeReleaseIndex(_makeReleaseIndex(id: "rel-2", version: "v2.0.0")),
        ),
      );
      final service = _makeService(remote: remote, currentVersion: "v1.0.0");

      final result = await service.check(generationHash: generationHash);

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
    });

    test("treats pre-release as older than release", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Right(_encodePointer(_makePointer(snapshotHash))),
        releaseIndexResult: Right(
          _encodeReleaseIndex(_makeReleaseIndex(id: "rel-1", version: "1.0.0-rc1")),
        ),
      );
      final service = _makeService(remote: remote, currentVersion: "1.0.0");

      final result = await service.check(generationHash: generationHash);

      expect(result, const Right(None()));
    });

    test("returns network error when generation pointer fetch fails", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Left(const CatalogNetworkError(message: "timeout")),
      );
      final service = _makeService(remote: remote);

      final result = await service.check(generationHash: generationHash);

      expect(result.isLeft(), isTrue);
      final error = result.getLeft().toNullable()!;
      expect(error, isA<ReleaseSyncNetworkError>());
      expect((error as ReleaseSyncNetworkError).message, "timeout");
    });

    test("returns network error when release index fetch fails", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Right(_encodePointer(_makePointer(snapshotHash))),
        releaseIndexResult: Left(const CatalogNetworkError(message: "not found")),
      );
      final service = _makeService(remote: remote);

      final result = await service.check(generationHash: generationHash);

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ReleaseSyncNetworkError>());
    });

    test("returns network error when snapshot hash is empty", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Right(_encodePointer(_makePointer(""))),
      );
      final service = _makeService(remote: remote);

      final result = await service.check(generationHash: generationHash);

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ReleaseSyncNetworkError>());
    });

    test("returns version parse error when installed version is invalid", () async {
      final remote = _FakeRemoteCatalogService(
        generationPointerResult: Right(_encodePointer(_makePointer(snapshotHash))),
        releaseIndexResult: Right(
          _encodeReleaseIndex(_makeReleaseIndex(id: "rel-2", version: "2.0.0")),
        ),
      );
      final service = _makeService(remote: remote, currentVersion: "not-a-version");

      final result = await service.check(generationHash: generationHash);

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ReleaseSyncVersionParseError>());
    });

    group("checkFromSnapshotHash", () {
      test("returns Some when remote version is newer", () async {
        final remote = _FakeRemoteCatalogService(
          releaseIndexResult: Right(
            _encodeReleaseIndex(_makeReleaseIndex(id: "rel-2", version: "2.0.0")),
          ),
        );
        final service = _makeService(remote: remote, currentVersion: "1.0.0");

        final result = await service.checkFromSnapshotHash(snapshotHash: snapshotHash);

        expect(result.isRight(), isTrue);
        final release = result.getRight().toNullable()!.toNullable();
        expect(release, isNotNull);
        expect(release!.releaseId, "rel-2");
      });

      test("returns None when remote version is older", () async {
        final remote = _FakeRemoteCatalogService(
          releaseIndexResult: Right(
            _encodeReleaseIndex(_makeReleaseIndex(id: "rel-0", version: "0.9.0")),
          ),
        );
        final service = _makeService(remote: remote, currentVersion: "1.0.0");

        final result = await service.checkFromSnapshotHash(snapshotHash: snapshotHash);

        expect(result, const Right(None()));
      });
    });

    group("checkStatusFromSnapshotHash", () {
      test("returns updateAvailable when remote version is newer", () async {
        final remote = _FakeRemoteCatalogService(
          releaseIndexResult: Right(
            _encodeReleaseIndex(_makeReleaseIndex(id: "rel-2", version: "2.0.0")),
          ),
        );
        final service = _makeService(remote: remote, currentVersion: "1.0.0");

        final result = await service.checkStatusFromSnapshotHash(snapshotHash: snapshotHash);

        expect(result.isRight(), isTrue);
        final status = result.getRight().toNullable()!;
        expect(status, isA<ReleaseCheckUpdateAvailable>());
        expect((status as ReleaseCheckUpdateAvailable).release.releaseId, "rel-2");
      });

      test("returns upToDate when remote version equals installed", () async {
        final remote = _FakeRemoteCatalogService(
          releaseIndexResult: Right(
            _encodeReleaseIndex(_makeReleaseIndex(id: "rel-1", version: "1.0.0")),
          ),
        );
        final service = _makeService(remote: remote, currentVersion: "1.0.0");

        final result = await service.checkStatusFromSnapshotHash(snapshotHash: snapshotHash);

        expect(result.isRight(), isTrue);
        expect(result.getRight().toNullable(), isA<ReleaseCheckUpToDate>());
      });

      test("returns aheadOfRemote when installed version is newer", () async {
        final remote = _FakeRemoteCatalogService(
          releaseIndexResult: Right(
            _encodeReleaseIndex(_makeReleaseIndex(id: "rel-0", version: "0.9.0")),
          ),
        );
        final service = _makeService(remote: remote, currentVersion: "1.0.0");

        final result = await service.checkStatusFromSnapshotHash(snapshotHash: snapshotHash);

        expect(result.isRight(), isTrue);
        final status = result.getRight().toNullable()!;
        expect(status, isA<ReleaseCheckAheadOfRemote>());
        expect((status as ReleaseCheckAheadOfRemote).remoteVersion, "0.9.0");
      });

      test("propagates network errors", () async {
        final remote = _FakeRemoteCatalogService(
          releaseIndexResult: Left(const CatalogNetworkError(message: "not found")),
        );
        final service = _makeService(remote: remote);

        final result = await service.checkStatusFromSnapshotHash(snapshotHash: snapshotHash);

        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), isA<ReleaseSyncNetworkError>());
      });

      group("ignoreBugfix", () {
        Future<ReleaseCheckStatus> _check({
          required String installed,
          required String remoteVersion,
          bool ignoreBugfix = true,
        }) async {
          final remote = _FakeRemoteCatalogService(
            releaseIndexResult: Right(
              _encodeReleaseIndex(_makeReleaseIndex(id: "rel-new", version: remoteVersion)),
            ),
          );
          final service = _makeService(remote: remote, currentVersion: installed);
          final result = await service.checkStatusFromSnapshotHash(
            snapshotHash: snapshotHash,
            ignoreBugfix: ignoreBugfix,
          );
          return result.getRight().toNullable()!;
        }

        test("suppresses a patch-only bump for 0.x", () async {
          final status = await _check(installed: "0.9.1", remoteVersion: "0.9.2");

          expect(status, isA<ReleaseCheckUpToDate>());
        });

        test("keeps a minor bump for 0.x visible", () async {
          final status = await _check(installed: "0.9.1", remoteVersion: "0.10.0");

          expect(status, isA<ReleaseCheckUpdateAvailable>());
        });

        test("suppresses a minor bump from 1.0 onward", () async {
          final status = await _check(installed: "1.2.3", remoteVersion: "1.3.0");

          expect(status, isA<ReleaseCheckUpToDate>());
        });

        test("suppresses a patch bump from 1.0 onward", () async {
          final status = await _check(installed: "1.2.3", remoteVersion: "1.2.4");

          expect(status, isA<ReleaseCheckUpToDate>());
        });

        test("keeps a major bump visible", () async {
          final status = await _check(installed: "1.2.3", remoteVersion: "2.0.0");

          expect(status, isA<ReleaseCheckUpdateAvailable>());
        });

        test("keeps prerelease changes visible", () async {
          final status = await _check(installed: "1.2.3", remoteVersion: "1.2.4-rc1");

          expect(status, isA<ReleaseCheckUpdateAvailable>());
        });

        test("disabled flag keeps bugfix bumps visible", () async {
          final status = await _check(
            installed: "1.2.3",
            remoteVersion: "1.2.4",
            ignoreBugfix: false,
          );

          expect(status, isA<ReleaseCheckUpdateAvailable>());
        });

        test("does not mask aheadOfRemote", () async {
          final status = await _check(installed: "1.2.3", remoteVersion: "1.2.2");

          expect(status, isA<ReleaseCheckAheadOfRemote>());
        });
      });
    });
  });
}
