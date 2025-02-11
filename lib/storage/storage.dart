import 'dart:developer';

import 'package:eve_fit_assistant/storage/fit/storage.dart';
import 'package:eve_fit_assistant/storage/migrate/migrate.dart';
import 'package:eve_fit_assistant/storage/static/storage.dart';
import 'package:eve_fit_assistant/storage/version.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage.g.dart';

@riverpod
class GlobalStorageNotifier extends _$GlobalStorageNotifier {
  @override
  bool build() {
    return false;
  }

  void initialized() {
    state = true;
  }
}

class GlobalStorage {
  static final GlobalStorage _instance = GlobalStorage._internal();

  factory GlobalStorage() => _instance;

  GlobalStorage._internal();

  final FitStorage _ship = FitStorage();
  final StaticStorage _static = StaticStorage();
  late VersionInfo _version;
  bool _initialized = false;
  bool _initializing = false;

  FitStorage get ship => _ship;

  StaticStorage get static => _static;

  VersionInfo get version => _version;

  Future<void> init(WidgetRef ref) async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;

    final version = await getVersionInfo();
    _version = await executeMigrate(version);
    await _ship.init();
    await _static.init();
    await Future.delayed(Duration(seconds: 5));
    _initialized = true;
    ref.read(globalStorageNotifierProvider.notifier).initialized();
  }
}
