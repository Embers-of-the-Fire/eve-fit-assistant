import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
// ── State machine ────────────────────────────────────────────────────────────

sealed class ProvisionerState {
  const ProvisionerState();
}

class ProvisionerPreparing extends ProvisionerState {
  const ProvisionerPreparing({this.totalBlobs = 0, this.cachedBlobs = 0});

  final int totalBlobs;
  final int cachedBlobs;
}

class ProvisionerDownloading extends ProvisionerState {
  const ProvisionerDownloading({
    required this.downloaded,
    required this.total,
    this.failedCount = 0,
    this.currentResourceId,
    this.elapsedSeconds = 0,
    this.filesPerSecond = 0,
    this.bytesPerSecond = 0,
  });

  final int downloaded;
  final int total;
  final int failedCount;
  final String? currentResourceId;
  final double elapsedSeconds;
  final double filesPerSecond;
  final double bytesPerSecond;

  double get progress => total > 0 ? downloaded / total : 0;
}

class ProvisionerFinalizing extends ProvisionerState {
  const ProvisionerFinalizing();
}

class ProvisionerComplete extends ProvisionerState {
  const ProvisionerComplete({
    required this.checkoutId,
    required this.resourceSnapshotHash,
    this.failedBlobs = const IList.empty(),
  });

  final String checkoutId;
  final String resourceSnapshotHash;
  final IList<String> failedBlobs;
}

class ProvisionerFatal extends ProvisionerState {
  const ProvisionerFatal({required this.message, this.retryable = true});

  final String message;
  final bool retryable;
}

// ── Provisioner ──────────────────────────────────────────────────────────────

/// Orchestrates checkout creation with progress reporting.
///
/// Downloads resource blobs, writes the resource snapshot, creates the checkout,
/// and emits [ProvisionerState] events on [state] for UI consumption.
///
/// Usage:
/// ```dart
/// final provisioner = CheckoutProvisioner(
///   remoteCatalog: ...,
///   assetStore: ...,
///   checkoutService: ...,
/// );
///
/// provisioner.configure(
///   channel: Channel.testing,
///   channelName: "testing",
///   serverId: "tranquility",
///   name: IMap({"en": "Tranquility"}),
///   generationHash: "abc123",
///   resourceSnapshotHash: "def456",
/// );
///
/// provisioner.state.listen((s) => print(s));
/// await provisioner.execute();
/// ```
class CheckoutProvisioner {
  CheckoutProvisioner({
    required this.remoteCatalog,
    required this.assetStore,
    required this.checkoutService,
  });

  final RemoteCatalogService remoteCatalog;
  final AssetStore assetStore;
  final CheckoutService checkoutService;

  final _stateController = StreamController<ProvisionerState>.broadcast(sync: true);

  /// Stream of provisioning state events.
  Stream<ProvisionerState> get state => _stateController.stream;

  Channel? _channel;
  String? _channelName;
  String? _serverId;
  IMap<String, String>? _name;
  String? _generationHash;
  String? _resourceSnapshotHash;
  bool _cancelled = false;

  /// Sets the parameters for the next [execute] call.
  void configure({
    required Channel channel,
    required String channelName,
    required String serverId,
    required IMap<String, String> name,
    required String generationHash,
    required String resourceSnapshotHash,
  }) {
    _channel = channel;
    _channelName = channelName;
    _serverId = serverId;
    _name = name;
    _generationHash = generationHash;
    _resourceSnapshotHash = resourceSnapshotHash;
    _cancelled = false;
  }

  /// Runs the provisioning pipeline: fetch index → download blobs → write
  /// snapshot → create checkout. Emits state events on [state] throughout.
  ///
  /// Safe to call at most once per [configure]; re-configure before re-executing.
  Future<void> execute() async {
    final channel = _channel;
    final channelName = _channelName;
    final serverId = _serverId;
    final name = _name;
    final generationHash = _generationHash;
    final resourceSnapshotHash = _resourceSnapshotHash;

    if (channel == null ||
        channelName == null ||
        serverId == null ||
        name == null ||
        generationHash == null ||
        resourceSnapshotHash == null) {
      _emit(const ProvisionerFatal(message: "Provisioner not configured"));
      return;
    }

    _cancelled = false;

    // 1. Fetch ResourceIndex
    _emit(const ProvisionerPreparing());

    final indexResult = await remoteCatalog.fetchResourceIndex(resourceSnapshotHash);
    if (_cancelled) return;
    if (indexResult.isLeft()) {
      final err = indexResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch resource index";
      _emit(ProvisionerFatal(message: msg, retryable: err is CatalogNetworkError));
      return;
    }

    final resourceIndex = ResourceIndex.fromBuffer(indexResult.getRight().toNullable()!);
    final totalEntries = resourceIndex.entries.length;

    // 2. Partition cached vs. to-download — pre-build identHash and blob
    // path once per entry so the hot loop has zero alloc overhead.
    final toDownload = <(ResourceIndex_Entry, String, String)>[];
    var cachedCount = 0;
    for (final entry in resourceIndex.entries) {
      final identHash = RepoHash.hashIdent(entry.resourceId);
      if (assetStore.blobExistsSync(identHash, entry.contentHash)) {
        cachedCount++;
      } else {
        toDownload.add((entry, identHash, RepoPaths.blobPath(identHash, entry.contentHash)));
      }
    }

    if (_cancelled) return;

    _emit(ProvisionerPreparing(totalBlobs: totalEntries, cachedBlobs: cachedCount));

    // 3. Download missing blobs with sliding-window concurrency.
    const blobConcurrency = 64;
    var downloaded = cachedCount;
    final failedBlobs = <String>[];

    if (toDownload.isEmpty) {
      _emit(ProvisionerDownloading(downloaded: downloaded, total: totalEntries));
    }

    var nextIdx = 0;
    var lastEmitMs = 0;
    const throttleMs = 200;
    final stopwatch = Stopwatch();

    if (toDownload.isNotEmpty) {
      assetStore.ensureBlobIdentDirs(toDownload.map((d) => d.$2));
      stopwatch.start();

      Future<void> downloadNext() async {
        int idx;
        while ((idx = nextIdx++) < toDownload.length) {
          if (_cancelled) return;

          final dl = toDownload[idx];
          final entry = dl.$1;
          final identHash = dl.$2;
          final blobPath = dl.$3;

          final blobResult = await remoteCatalog.fetchBlob(identHash, entry.contentHash);
          if (blobResult.isRight()) {
            try {
              await assetStore.writeBlobUncheckedAt(blobPath, blobResult.getRight().toNullable()!);
              downloaded++;
            } on FileSystemException {
              failedBlobs.add(entry.resourceId);
            }
          } else {
            failedBlobs.add(entry.resourceId);
            warning("Failed to fetch blob: ${entry.resourceId}");
          }

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastEmitMs >= throttleMs || downloaded >= totalEntries) {
            final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
            final fps = elapsed > 0 ? (downloaded - cachedCount).toDouble() / elapsed : 0.0;
            _emit(
              ProvisionerDownloading(
                downloaded: downloaded,
                total: totalEntries,
                failedCount: failedBlobs.length,
                elapsedSeconds: elapsed,
                filesPerSecond: fps,
              ),
            );
            lastEmitMs = now;
          }
        }
      }

      final tasks = <Future<void>>[
        for (var i = 0; i < blobConcurrency.clamp(1, toDownload.length); i++) downloadNext(),
      ];
      await Future.wait(tasks);
      stopwatch.stop();
    }

    // Final emit after all workers finish (ensures 100% shown).
    if (toDownload.isNotEmpty) {
      final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
      final fps = elapsed > 0 ? (downloaded - cachedCount).toDouble() / elapsed : 0.0;
      _emit(
        ProvisionerDownloading(
          downloaded: downloaded,
          total: totalEntries,
          failedCount: failedBlobs.length,
          elapsedSeconds: elapsed,
          filesPerSecond: fps,
        ),
      );
    }

    if (_cancelled) return;

    // 4. Fetch and persist server index so checkout creation can read metadata
    await _persistServerIndex(generationHash, channelName, channel);

    if (_cancelled) return;

    // 5. Write resource snapshot
    _emit(const ProvisionerFinalizing());

    final metaResult = await remoteCatalog.fetchResourceSnapshotMeta(resourceSnapshotHash);
    if (metaResult.isLeft()) {
      final err = metaResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError
          ? err.message
          : "Failed to fetch resource snapshot metadata";
      _emit(ProvisionerFatal(message: msg, retryable: err is CatalogNetworkError));
      return;
    }
    final localSnapshotHash = assetStore.writeResourceSnapshotSync(
      meta: metaResult.getRight().toNullable()!,
      resourceIndex: resourceIndex,
    );

    if (_cancelled) return;

    // 6. Create checkout
    final result = await checkoutService.createCheckout(
      channel: channel,
      serverId: serverId,
      name: name,
      generationHash: generationHash,
      resourceSnapshotHash: localSnapshotHash,
    );

    if (result.isNone()) {
      _emit(const ProvisionerFatal(message: "Failed to create checkout", retryable: false));
      return;
    }

    _emit(
      ProvisionerComplete(
        checkoutId: result.toNullable()!,
        resourceSnapshotHash: localSnapshotHash,
        failedBlobs: failedBlobs.toIList(),
      ),
    );
  }

  /// Cancels an in-progress [execute] call. The pipeline will stop before the
  /// next phase boundary — no partial checkout is created.
  void cancel() {
    _cancelled = true;
  }

  /// Disposes the underlying stream controller.
  void dispose() {
    unawaited(_stateController.close());
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _emit(ProvisionerState s) {
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  /// Fetches the server index protobuf and writes it to disk so
  /// [CheckoutService.createCheckout] can read server metadata.
  Future<void> _persistServerIndex(
    String generationHash,
    String channelName,
    Channel channel,
  ) async {
    final path = RepoPaths.channelServerIndexPath(channel.value);

    // Skip if already on disk (from a prior sync)
    if (File(path).existsSync()) return;

    final result = await remoteCatalog.fetchServerIndex(generationHash);
    if (result.isLeft()) return;

    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsBytesSync(result.getRight().toNullable()!, flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write server index for $channelName", stackTrace: stackTrace);
    }
  }
}
