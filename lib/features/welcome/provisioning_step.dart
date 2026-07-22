import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/components/wizard/wizard_tokens.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/welcome/multi_provisioner_state.dart";

import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ProvisioningStepPage extends ConsumerStatefulWidget {
  const ProvisioningStepPage({
    required this.channel,
    required this.channelName,
    required this.generationHash,
    required this.targets,
    required this.onComplete,
    required this.onBack,
    super.key,
  });

  final Channel channel;
  final String channelName;
  final String generationHash;
  final IList<ProvisioningTarget> targets;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  @override
  ConsumerState<ProvisioningStepPage> createState() => _ProvisioningStepPageState();
}

class ProvisioningTarget {
  const ProvisioningTarget({
    required this.serverId,
    required this.displayName,
    required this.snapshotHash,
  });

  final String serverId;
  final String displayName;
  final String snapshotHash;
}

class _ProvisioningStepPageState extends ConsumerState<ProvisioningStepPage>
    with TickerProviderStateMixin {
  final _stateController = StreamController<MultiProvisionerState>.broadcast(sync: true);
  MultiProvisionerState _currentState = const MultiProvisionerFetching();
  bool _cancelled = false;
  bool _started = false;
  late final AnimationController _enterAnimCtrl;
  late final AnimationController _titleAnimCtrl;

  @override
  void initState() {
    super.initState();
    _enterAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _enterAnimCtrl.addListener(() => setState(() {}));
    _titleAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _titleAnimCtrl.addListener(() => setState(() {}));
    unawaited(_titleAnimCtrl.repeat(reverse: true));
    _stateController.stream.listen((s) {
      if (mounted) {
        setState(() {
          _currentState = s;
          if (s is MultiProvisionerComplete && !_enterAnimCtrl.isAnimating) {
            unawaited(_enterAnimCtrl.forward());
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started) {
        _started = true;
        unawaited(_provision());
      }
    });
  }

  @override
  void dispose() {
    _enterAnimCtrl.dispose();
    _titleAnimCtrl.dispose();
    _cancelled = true;
    unawaited(_stateController.close());
    super.dispose();
  }

  void _emit(MultiProvisionerState s) {
    if (!_cancelled && !_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  Future<void> _provision() async {
    final l10n = context.l10n;
    final remoteCatalog = ref.read(remoteCatalogServiceProvider);
    final assetStore = ref.read(assetStoreProvider);
    final checkoutService = ref.read(checkoutServiceProvider);
    final targets = widget.targets;

    _cancelled = false;

    // Phase 1: Fetch all ResourceIndices in parallel
    _emit(MultiProvisionerFetching(total: targets.length));

    final futures = targets.map((target) async {
      final result = await remoteCatalog.fetchResourceIndex(target.snapshotHash);
      return (target, result);
    }).toList();

    final results = await Future.wait(futures);
    if (_cancelled) return;

    final targetToIndex = <ProvisioningTarget, ResourceIndex>{};
    for (final (target, result) in results) {
      if (_cancelled) return;
      result.match(
        (err) {
          final msg = err is CatalogNetworkError
              ? err.message
              : l10n.checkoutCreateProgressIndexFailed;
          _emit(MultiProvisionerFatal(message: msg, retryable: err is CatalogNetworkError));
        },
        (bytes) {
          targetToIndex[target] = ResourceIndex.fromBuffer(bytes);
        },
      );
      if (_currentState is MultiProvisionerFatal) return;
    }

    if (_cancelled || _currentState is MultiProvisionerFatal) return;

    _emit(MultiProvisionerFetching(done: targets.length, total: targets.length));

    // Phase 2: Compute union blob set (deduplicated by contentHash)
    final unionEntries = <ResourceIndex_Entry>[];
    final seen = <String>{};
    for (final index in targetToIndex.values) {
      for (final entry in index.entries) {
        if (seen.add(entry.contentHash)) {
          unionEntries.add(entry);
        }
      }
    }

    // Separate cached from to-download — pre-build identHash and blob path.
    final toDownload = <(ResourceIndex_Entry, String, String, int)>[];
    var downloaded = 0;
    var cachedBytes = 0;
    var totalBytes = 0;
    for (final entry in unionEntries) {
      final size = entry.size.toInt();
      totalBytes += size;
      final identHash = RepoHash.hashIdent(entry.resourceId);
      if (assetStore.blobExistsSync(identHash, entry.contentHash)) {
        downloaded++;
        cachedBytes += size;
      } else {
        toDownload.add((entry, identHash, RepoPaths.blobPath(identHash, entry.contentHash), size));
      }
    }

    toDownload.sort((a, b) => b.$4.compareTo(a.$4));

    if (_cancelled) return;

    final cachedCount = downloaded;
    final unionTotal = unionEntries.length;

    // Download blobs with sliding-window concurrency.
    const blobConcurrency = kBlobDownloadConcurrency;
    final failedBlobs = <String>[];
    var nextIdx = 0;
    var lastEmitMs = 0;
    const throttleMs = 200;
    final stopwatch = Stopwatch();
    Timer? progressTimer;
    final tracker = BlobTransferTracker(totalBytes: totalBytes, initialCompletedBytes: cachedBytes);

    void maybeEmit({bool force = false}) {
      if (_cancelled) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now - lastEmitMs < throttleMs && downloaded < unionTotal) return;
      lastEmitMs = now;
      final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
      final fps = elapsed > 0 ? (downloaded - cachedCount).toDouble() / elapsed : 0.0;
      _emit(
        MultiProvisionerDownloading(
          downloaded: downloaded,
          total: unionTotal,
          downloadedBytes: tracker.transferredBytes,
          totalBytes: tracker.totalBytes,
          elapsedSeconds: elapsed,
          filesPerSecond: fps,
          bytesPerSecond: tracker.bytesPerSecond,
        ),
      );
    }

    if (toDownload.isNotEmpty) {
      assetStore.ensureBlobIdentDirs(toDownload.map((d) => d.$2));
      stopwatch.start();
      // Periodic re-emit so the progress bar keeps moving and the reported
      // speed decays honestly while all workers are busy on large blobs.
      progressTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => maybeEmit(force: true),
      );

      Future<void> downloadNext() async {
        int idx;
        while ((idx = nextIdx++) < toDownload.length) {
          if (_cancelled) return;

          final dl = toDownload[idx];
          final entry = dl.$1;
          final identHash = dl.$2;
          final blobPath = dl.$3;
          final blobSize = dl.$4;

          final blobResult = await remoteCatalog.fetchBlob(
            identHash,
            entry.contentHash,
            onReceiveProgress: (received, _) {
              tracker.blobProgress(idx, received);
              maybeEmit();
            },
          );
          if (blobResult.isRight()) {
            try {
              await assetStore.writeBlobUncheckedAt(blobPath, blobResult.getRight().toNullable()!);
              downloaded++;
              tracker.blobComplete(idx, blobSize);
            } on FileSystemException {
              tracker.blobAborted(idx);
              failedBlobs.add(entry.resourceId);
            }
          } else {
            tracker.blobAborted(idx);
            failedBlobs.add(entry.resourceId);
            warning("Failed to fetch blob: ${entry.resourceId}");
          }

          maybeEmit();
        }
      }

      final tasks = <Future<void>>[
        for (var i = 0; i < blobConcurrency.clamp(1, toDownload.length); i++) downloadNext(),
      ];
      await Future.wait(tasks);
      progressTimer.cancel();
      stopwatch.stop();
    }

    // Final emit after all workers finish.
    if (toDownload.isNotEmpty) {
      maybeEmit(force: true);
    } else {
      _emit(
        MultiProvisionerDownloading(
          downloaded: downloaded,
          total: unionTotal,
          downloadedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
    }

    if (_cancelled) return;

    // Persist server index (shared across all servers in this channel)
    await _persistServerIndex(remoteCatalog);

    if (_cancelled) return;

    // Phase 3: Write snapshots and create checkouts
    _emit(MultiProvisionerCreating(total: targets.length));

    final checkoutIds = <String>[];
    for (final target in targets) {
      if (_cancelled) return;

      final resourceIndex = targetToIndex[target];
      if (resourceIndex == null) continue;

      // Write resource snapshot
      final metaResult = await remoteCatalog.fetchResourceSnapshotMeta(target.snapshotHash);
      final localSnapshotHash = metaResult.isRight()
          ? assetStore.writeResourceSnapshotSync(
              meta: metaResult.getRight().toNullable()!,
              resourceIndex: resourceIndex,
            )
          : assetStore.writeResourceSnapshotSync(
              meta: ResourceSnapshotMeta(
                schemaVersion: 1,
                serverId: target.serverId,
                gameBuild: "",
                gameVersion: "",
                resourceCount: resourceIndex.entries.length,
                createdAt: formatTimestamp(DateTime.now().toUtc()),
              ),
              resourceIndex: resourceIndex,
            );

      // Create checkout
      final nameMap = IMap({"en": target.displayName});
      final result = await checkoutService.createCheckout(
        channel: widget.channel,
        serverId: target.serverId,
        name: nameMap,
        generationHash: widget.generationHash,
        resourceSnapshotHash: localSnapshotHash,
      );

      if (result.isSome()) {
        checkoutIds.add(result.toNullable()!);
      }

      _emit(MultiProvisionerCreating(done: checkoutIds.length, total: targets.length));
    }

    if (_cancelled) return;

    if (checkoutIds.isEmpty) {
      _emit(
        MultiProvisionerFatal(message: l10n.checkoutCreateProgressCheckoutFailed, retryable: false),
      );
      return;
    }

    // Re-initialize repo state so the active checkout is picked up
    await ref.read(repoStateProvider.notifier).initialize();

    _emit(MultiProvisionerComplete(checkoutIds: checkoutIds.toIList()));
  }

  Future<void> _persistServerIndex(RemoteCatalogService remoteCatalog) async {
    final path = RepoPaths.channelServerIndexPath(widget.channel.value);
    if (File(path).existsSync()) return;

    final result = await remoteCatalog.fetchServerIndex(widget.generationHash);
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
      warning("Failed to write server index for ${widget.channelName}: $e", stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = WizardTokens.of(context);
    final l10n = context.l10n;
    final state = _currentState;
    final theme = Theme.of(context);

    final statusText = switch (state) {
      MultiProvisionerFetching() => l10n.checkoutCreateProgressFetchingIndex,
      MultiProvisionerDownloading(:final downloaded, :final total) =>
        l10n.checkoutCreateProgressDownloading2(current: downloaded, total: total),
      MultiProvisionerCreating() => l10n.checkoutCreateProgressCreatingCheckout,
      MultiProvisionerComplete() => l10n.checkoutCreateProgressComplete,
      MultiProvisionerFatal(:final message) => message,
    };

    final speedText = switch (state) {
      MultiProvisionerDownloading(:final filesPerSecond, :final bytesPerSecond) => [
        if (filesPerSecond > 0)
          l10n.downloadSpeedFilesPerSecond(value: filesPerSecond.toStringAsFixed(1)),
        if (bytesPerSecond > 0) formatBytesPerSec(bytesPerSecond),
      ].join("  "),
      _ => "",
    };

    final showError = state is MultiProvisionerFatal;
    final canRetry = showError && state.retryable;
    final showComplete = state is MultiProvisionerComplete;

    final t = _enterAnimCtrl.value;
    final fadeOutProgress = 1.0 - (t / 0.4).clamp(0.0, 1.0);
    final fadeInEnter = ((t - 0.6) / 0.4).clamp(0.0, 1.0);

    final progressValue = switch (state) {
      MultiProvisionerDownloading(:final progress) => progress,
      MultiProvisionerCreating(:final progress) => progress,
      MultiProvisionerComplete() => t < 0.4 ? 1.0 : null,
      _ => null as double?,
    };

    return Scaffold(
      body: GestureDetector(
        onTap: showComplete && fadeInEnter >= 0.5 ? widget.onComplete : null,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacingXl, vertical: tokens.spacingLg),
            child: Column(
              children: [
                const Spacer(),
                // Logo
                SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Color.lerp(
                          const Color(0xFF30B2E6),
                          const Color(0xFF1A7C9C),
                          _titleAnimCtrl.value,
                        ),
                      ),
                    ),
                  ),
                ),
                // Status + progress — fades out on complete
                Opacity(
                  opacity: showComplete ? fadeOutProgress : 1.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: tokens.spacingLg),
                      Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: tokens.spacingMd),
                      if (progressValue case final p)
                        SizedBox(width: 256, child: LinearProgressIndicator(value: p)),
                      if (speedText.isNotEmpty) ...[
                        SizedBox(height: tokens.spacingSm),
                        Text(
                          speedText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Error state
                if (showError) ...[
                  SizedBox(height: tokens.spacingMd),
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                ],
                // Complete state — fades in, user taps anywhere to enter
                if (showComplete) ...[
                  SizedBox(height: tokens.spacingMd),
                  Opacity(
                    opacity: fadeInEnter,
                    child: Text(
                      l10n.welcomeTapToEnter,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                // Action buttons
                if (showError || showComplete) ...[
                  SizedBox(height: tokens.spacingXl),
                  if (showError)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(onPressed: widget.onBack, child: Text(l10n.welcomeBackButton)),
                        if (canRetry) ...[
                          SizedBox(width: tokens.spacingLg),
                          FilledButton(
                            onPressed: () {
                              _cancelled = false;
                              _currentState = const MultiProvisionerFetching();
                              unawaited(_provision());
                            },
                            child: Text(l10n.fitPageRetryAction),
                          ),
                        ],
                      ],
                    ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
