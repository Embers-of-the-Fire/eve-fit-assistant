import "dart:async";
import "dart:io";

import "package:animated_text_kit/animated_text_kit.dart";
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

class _ProvisioningStepPageState extends ConsumerState<ProvisioningStepPage> {
  final _stateController = StreamController<MultiProvisionerState>.broadcast(sync: true);
  MultiProvisionerState _currentState = const MultiProvisionerFetching();
  bool _cancelled = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _stateController.stream.listen((s) {
      if (mounted) setState(() => _currentState = s);
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

    // Separate cached from to-download
    final toDownload = <ResourceIndex_Entry>[];
    var downloaded = 0;
    for (final entry in unionEntries) {
      final identHash = RepoHash.hashIdent(entry.resourceId);
      if (assetStore.blobExistsSync(identHash, entry.contentHash)) {
        downloaded++;
      } else {
        toDownload.add(entry);
      }
    }

    if (_cancelled) return;

    final unionTotal = unionEntries.length;
    _emit(MultiProvisionerDownloading(downloaded: downloaded, total: unionTotal));

    // Download blobs with concurrency = 4
    const concurrency = 4;
    final failedBlobs = <String>[];

    for (var i = 0; i < toDownload.length; i += concurrency) {
      if (_cancelled) return;

      final chunk = toDownload.skip(i).take(concurrency).toList();

      await Future.wait(
        chunk.map((entry) async {
          final identHash = RepoHash.hashIdent(entry.resourceId);
          final blobResult = await remoteCatalog.fetchBlob(identHash, entry.contentHash);
          if (blobResult.isRight()) {
            try {
              assetStore.writeBlobSync(identHash, blobResult.getRight().toNullable()!);
            } on FileSystemException {
              failedBlobs.add(entry.resourceId);
            }
          } else {
            failedBlobs.add(entry.resourceId);
            warning("Failed to fetch blob: ${entry.resourceId}");
          }
        }),
      );

      downloaded += chunk.length;

      _emit(MultiProvisionerDownloading(downloaded: downloaded, total: unionTotal));
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

    // Auto-complete after brief delay
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted && !_cancelled) {
      widget.onComplete();
    }
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
      warning("Failed to write server index for ${widget.channelName}", stackTrace: stackTrace);
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

    final showError = state is MultiProvisionerFatal;
    final showComplete = state is MultiProvisionerComplete;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacingXl, vertical: tokens.spacingLg),
          child: Column(
            children: [
              const Spacer(),
              // Logo
              SizedBox(
                height: 200,
                child: Center(
                  child: AnimatedTextKit(
                    repeatForever: true,
                    animatedTexts: [
                      ColorizeAnimatedText(
                        l10n.appTitle,
                        textStyle: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                        colors: const [Color(0xFF30B2E6), Color(0xFF1A7C9C)],
                        speed: const Duration(milliseconds: 400),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.spacingLg),
              // Status text
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
              ),
              SizedBox(height: tokens.spacingMd),
              // Progress bar
              if (state case MultiProvisionerDownloading(:final progress))
                SizedBox(width: 256, child: LinearProgressIndicator(value: progress)),
              // Error state
              if (showError) ...[
                SizedBox(height: tokens.spacingMd),
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
              ],
              // Complete state
              if (showComplete) ...[
                SizedBox(height: tokens.spacingMd),
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
              ],
              // Action buttons
              if (showError || showComplete) ...[
                SizedBox(height: tokens.spacingXl),
                if (showError)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(onPressed: widget.onBack, child: Text(l10n.welcomeBackButton)),
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
                  ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
