import 'dart:convert';
import 'dart:io';

import 'package:eve_fit_assistant/config/logger.dart';
import 'package:eve_fit_assistant/storage/fit/manager.dart';
import 'package:eve_fit_assistant/storage/fit/schema.dart';
import 'package:eve_fit_assistant/utils/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'service.freezed.dart';
part 'service.g.dart';

@freezed
abstract class FitServiceStatus with _$FitServiceStatus {
  const factory FitServiceStatus.uninitialized() = _FitServiceStatusUninitialized;
  const factory FitServiceStatus.error({required String message}) = _FitServiceStatusError;
  const factory FitServiceStatus.syncing() = _FitServiceStatusSyncing;
  const factory FitServiceStatus.loaded({required DateTime lastSync}) = _FitServiceStatusLoaded;
}

@freezed
abstract class FitServiceState with _$FitServiceState {
  const factory FitServiceState.notInitialized() = _FitServiceStateNotInitialized;
  const factory FitServiceState.loaded({
    required FitServiceStatus status,
    required FitStorage fit,
  }) = _FitServiceStateLoaded;

  const FitServiceState._();
  bool get isInitialized => when(notInitialized: () => false, loaded: (status, fit) => true);
  FitStorage get fit => when(
    notInitialized: () {
      final stackTrace = StackTrace.current;
      error("Invalid fit service access: fit not initialized", stackTrace: stackTrace);
      throw StateError("Fit service not initialized");
    },
    loaded: (status, fit) => fit,
  );
  FitServiceStatus get status =>
      when(notInitialized: () => FitServiceStatus.uninitialized(), loaded: (status, fit) => status);
}

@riverpod
FitStorage fit(Ref ref) => ref.watch(fitServiceProvider.select((value) => value.fit));

@riverpod
FitServiceStatus fitStatus(Ref ref) =>
    ref.watch(fitServiceProvider.select((value) => value.status));

@riverpodSingleton
class FitService extends _$FitService {
  @override
  FitServiceState build() {
    return FitServiceState.notInitialized();
  }

  Future<void> _loadFromDisk(String fitId) async {
    if (state.isInitialized) {
      warning("Fit service already initialized, force loading");
    }
    state = FitServiceState.notInitialized();
    final path = File(FitStorage.fitStoragePathForId(fitId));
    if (!await path.exists()) {
      error("Fit file does not exist: ${path.path}");
      throw StateError("Fit file does not exist: ${path.path}");
    }
    final text = await path.readAsString();
    final json = jsonDecode(text) as Map<String, dynamic>;
    final fit = FitStorage.fromJson(json);
    state = FitServiceState.loaded(
      status: FitServiceStatus.loaded(lastSync: DateTime.now()),
      fit: fit,
    );
  }

  Future<void> _syncToDisk({bool setState = true}) async {
    if (!state.isInitialized) {
      error("Cannot sync fit service: not initialized");
      return;
    }
    final fit = state.fit;
    state = FitServiceState.loaded(status: FitServiceStatus.syncing(), fit: fit);
    final path = File(fit.fitStoragePath);
    final text = jsonEncode(fit.toJson());
    if (!await path.exists()) {
      await path.parent.create(recursive: true);
    }
    await path.writeAsString(text);
    if (setState) {
      state = FitServiceState.loaded(
        status: FitServiceStatus.loaded(lastSync: DateTime.now()),
        fit: state.fit,
      );
    }
  }

  Future<void> mount(String fitId) async {
    await _loadFromDisk(fitId);
  }

  Future<void> unmount() async {
    await _syncToDisk();
    state = FitServiceState.notInitialized();
  }

  Future<void> update(FitStorage Function(FitStorage) updater) async {
    if (!state.isInitialized) {
      error("Cannot update fit service: not initialized");
      return;
    }
    final fit = updater(
      state.fit,
    ).copyWith(metadata: state.fit.metadata.copyWith(lastModified: DateTime.now().second));
    state = FitServiceState.loaded(status: FitServiceStatus.syncing(), fit: fit);
    ref.read(fitRegistryManagerProvider.notifier).updateFit(fit.metadata);
    await _syncToDisk(setState: false);
  }
}
