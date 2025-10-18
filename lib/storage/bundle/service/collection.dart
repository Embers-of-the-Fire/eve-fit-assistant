import 'dart:io';

import 'package:eve_fit_assistant/config/logger.dart';
import 'package:eve_fit_assistant/data/proto/collections.pb.dart';
import 'package:eve_fit_assistant/storage/bundle/service.dart';
import 'package:eve_fit_assistant/storage/bundle/service/paths.dart';
import 'package:eve_fit_assistant/utils/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collection.freezed.dart';
part 'collection.g.dart';

@freezed
abstract class BundleCollectionStatus with _$BundleCollectionStatus {
  const factory BundleCollectionStatus.notInitialized() = _BundleCollectionStatusNotInitialized;
  const factory BundleCollectionStatus.loading() = _BundleCollectionStatusLoading;
  const factory BundleCollectionStatus.loaded(Collection collection) =
      _BundleCollectionStatusLoaded;

  const BundleCollectionStatus._();

  Collection get collection {
    return when(
      notInitialized: () {
        error("BundleCollection is not initialized", stackTrace: StackTrace.current);
        throw StateError("BundleCollection is not initialized");
      },
      loading: () {
        error("BundleCollection is loading", stackTrace: StackTrace.current);
        throw StateError("BundleCollection is loading");
      },
      loaded: (collection) => collection,
    );
  }
}

@riverpodSingleton
class BundleCollection extends _$BundleCollection {
  static bool _isLoading = false;

  @override
  BundleCollectionStatus build() {
    ref.listen(bundleServiceProvider, (prev, next) {
      if (!next.isLoaded) return;
      _loadCollection();
    });
    return const BundleCollectionStatus.notInitialized();
  }

  Future<void> _loadCollection() async {
    // Load guard to prevent multiple simultaneous loads
    if (_isLoading) return;
    _isLoading = true;
    state = const BundleCollectionStatus.loading();
    final file = File(
      ref.read(bundlePathsProvider.select((provider) => provider.getCollectionPath())),
    );
    final bytes = await file.readAsBytes();
    final collection = Collection.fromBuffer(bytes);
    state = BundleCollectionStatus.loaded(collection);
  }
}
