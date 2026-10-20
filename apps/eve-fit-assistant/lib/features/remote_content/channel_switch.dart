import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "channel_switch.g.dart";

/// Switches the data channel to [channel]: discovers the registry, syncs the
/// target channel's generation (including the promoted history), re-binds
/// checkouts, commits the new channel to the stored settings, and invalidates
/// every consumer of channel state so tiles re-check immediately against the
/// new channel. The repo lifecycle is
/// re-initialized (never merely invalidated — a bare invalidate resets it to
/// `uninitialized` with no one left to re-run initialization, leaving the app
/// on the SchemaGuard spinner forever).
///
/// The setting is committed here (not by the caller) so the stored channel
/// cannot stay behind the checkout bindings when the requesting widget is
/// disposed mid-switch, and it is committed before the invalidations so the
/// first re-check of an invalidated consumer already resolves against the new
/// channel. The singleton [Ref] stays valid after the caller is disposed.
///
/// Returns an error message when discovery or sync fails; in that case the
/// switch aborts before re-binding, so checkouts stay on their original
/// channel (whose local head metadata is still present) and update checks
/// keep resolving against the previous channel state.
typedef ChannelSwitchAction = Future<String?> Function(String channel);

@riverpodSingleton
ChannelSwitchAction channelSwitchAction(Ref ref) => (channel) async {
  final repo = ref.read(repoServiceProvider);
  final discoverResult = await repo.discoverChannels();
  if (discoverResult.isLeft()) {
    return discoverResult.getLeft().toNullable()!;
  }
  final syncResult = await repo.syncChannelGeneration(channel);
  if (syncResult.isLeft()) {
    return syncResult.getLeft().toNullable()!;
  }
  await ref.read(dataUpdateServiceProvider).rebindCheckoutsToChannel(channel);
  ref
      .read(appSettingServiceProvider.notifier)
      .update((setting) => setting.copyWith.remoteContent(channel: channel));
  ref.invalidate(batchDataUpdateControllerProvider);
  for (final checkoutId in ref.read(installedCheckoutIdsProvider)) {
    ref.invalidate(checkoutUpdateControllerProvider(checkoutId));
  }
  ref.invalidate(appReleaseCheckStatusProvider);
  await ref.read(repoStateProvider.notifier).initialize();
  return null;
};
