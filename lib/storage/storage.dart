import 'package:eve_fit_assistant/native/glue/fit_engine.dart';
import 'package:eve_fit_assistant/storage/character/storage.dart';
import 'package:eve_fit_assistant/storage/fit/storage.dart';
import 'package:eve_fit_assistant/storage/migrate/migrate.dart';
import 'package:eve_fit_assistant/storage/static/storage.dart';
import 'package:eve_fit_assistant/storage/version.dart';
import 'package:eve_fit_assistant/widgets/loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage.g.dart';

const String _storageLoadingKey = 'storage';

@riverpod
class GlobalStorageNotifier extends _$GlobalStorageNotifier {
  @override
  bool build() => false;

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
  final CharacterStorage _character = CharacterStorage();
  late final FitEngine _fitEngine;
  late VersionInfo _version;
  late PackageInfo _packageInfo;

  bool _initialized = false;
  bool _initializing = false;

  FitStorage get ship => _ship;

  StaticStorage get static => _static;

  CharacterStorage get character => _character;

  FitEngine get fitEngine => _fitEngine;

  VersionInfo get version => _version;

  PackageInfo get packageInfo => _packageInfo;

  Future<void> init(WidgetRef ref) async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;

    // await EasyLoading.show(status: '初始化');
    GlobalLoading().add(_storageLoadingKey, '初始化');
    final version = await getVersionInfo();
    _version = await executeMigrate(version);
    _packageInfo = await PackageInfo.fromPlatform();
    await _static.init();
    await _ship.init();
    await _character.init();
    _fitEngine = await FitEngine.init();
    await Future.delayed(const Duration(seconds: 1));
    _initialized = true;
    GlobalLoading().dismiss(_storageLoadingKey);
    ref.read(globalStorageNotifierProvider.notifier).initialized();
  }
}
