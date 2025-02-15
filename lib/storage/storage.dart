import 'package:eve_fit_assistant/native/glue/fit_engine.dart';
import 'package:eve_fit_assistant/storage/character/character.dart';
import 'package:eve_fit_assistant/storage/fit/storage.dart';
import 'package:eve_fit_assistant/storage/migrate/migrate.dart';
import 'package:eve_fit_assistant/storage/static/storage.dart';
import 'package:eve_fit_assistant/storage/version.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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
  final CharacterStorage _character = CharacterStorage();
  late final FitEngine _fitEngine;
  late VersionInfo _version;
  bool _initialized = false;
  bool _initializing = false;

  FitStorage get ship => _ship;

  StaticStorage get static => _static;

  CharacterStorage get character => _character;

  FitEngine get fitEngine => _fitEngine;

  VersionInfo get version => _version;

  Future<void> init(WidgetRef ref) async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;

    EasyLoading.show(status: '初始化');
    final version = await getVersionInfo();
    _version = await executeMigrate(version);
    await _static.init(autoDismiss: false);
    await _ship.init();
    await _character.init();
    _fitEngine = await FitEngine.init();
    await Future.delayed(const Duration(seconds: 5));
    _initialized = true;
    EasyLoading.dismiss();
    ref.read(globalStorageNotifierProvider.notifier).initialized();
  }
}
