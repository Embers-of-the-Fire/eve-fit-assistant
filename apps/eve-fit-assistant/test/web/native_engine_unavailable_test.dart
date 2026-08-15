@TestOn("browser")
library;

import "package:eve_fit_assistant/config/engine_availability.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:riverpod/riverpod.dart";

/// Web degradation coverage: when the native engine is unavailable (no
/// cross-origin isolation or no wasm bundle), engine-facing calls must
/// degrade to an error state instead of touching the uninitialized FRB
/// bridge. The VM-only engine suite covers the native path.
ResourceIndex _engineIndex() {
  final ri = ResourceIndex()..schemaVersion = 1;
  for (final id in const [
    "resource://static/native/types.pb2",
    "resource://static/native/dogmaAttributes.pb2",
    "resource://static/native/dogmaEffects.pb2",
    "resource://static/native/typeDogma.pb2",
    "resource://static/native/dbuffcollections.pb2",
  ]) {
    ri.entries.add(
      ResourceIndex_Entry()
        ..resourceId = id
        ..contentHash = "0" * 64
        ..size = Int64(0),
    );
  }
  return ri;
}

void main() {
  setUp(() {
    NativeEngineAvailability.setAvailable(value: false);
  });

  test("engine-facing calls degrade to an error state instead of throwing", () async {
    final proxy = ResourceBlobProxy(AssetStore.forTest(MemoryBlobStore()), _engineIndex());
    final container = ProviderContainer(
      overrides: [resourceBlobProxyProvider.overrideWith((ref) async => proxy)],
    );
    addTearDown(container.dispose);

    await container.read(resourceBlobProxyProvider.future);
    await container.read(nativeFitEngineServiceProvider.notifier).retry();

    final state = container.read(nativeFitEngineServiceProvider);
    expect(state.debugOnlyDisplayState, contains("error"));
    expect(state.errorMessageKey, FitErrorMessageKey.fitCalculationsUnavailable);
  });
}
