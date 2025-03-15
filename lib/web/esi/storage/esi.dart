import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/web/esi/auth/auth.dart';
import 'package:eve_fit_assistant/web/esi/esi/character/fittings.dart';
import 'package:eve_fit_assistant/web/esi/esi/character/skills.dart';
import 'package:eve_fit_assistant/web/esi/meta/verify.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:webview_flutter/webview_flutter.dart';

part 'character.dart';
part 'esi.freezed.dart';
part 'esi.g.dart';

String esiUrl(EsiAuthServer server) => switch (server) {
      EsiAuthServer.tranquility => 'https://esi.evetech.net',
      EsiAuthServer.serenity => 'https://ali-esi.evepc.163.com',
    };

@Riverpod(keepAlive: true)
class EsiDataStorage extends _$EsiDataStorage {
  static final EsiDataStorage _instance = EsiDataStorage._();

  /// This is a private constructor, use [EsiDataStorage.instance] to get the instance.
  /// Do not use `EsiDataStorage()` to get the storage instance.
  /// That constructor is used to create a riverpod provider.
  EsiDataStorage._();

  /// This constructor is only used to create the riverpod provider.
  /// To access the inner state, use [EsiDataStorage.instance].
  EsiDataStorage();

  static EsiDataStorage get instance => _instance;

  bool _authorized = false;

  // ignore: avoid_public_notifier_properties
  bool get authorized => _authorized;

  @override
  EsiDataStorage build() => _instance;

  Future<void> init() async {
    final token = await EsiAuth().getTokensAuthorized();
    _authorized = token != null && token.server == Preference().esiAuthServer;
  }

  Character? _character;

  Future<Character?> getCharacter() async {
    if (!_authorized) return null;
    _character ??= await Character.init();
    return _character;
  }

  CharacterSkills? _characterSkills;

  Future<CharacterSkills?> getCharacterSkills() async {
    if (!_authorized) return null;
    _characterSkills ??= await characterSkills();
    return _characterSkills;
  }

  Future<void> refreshCharacterSkills() async {
    if (!_authorized) return;
    _characterSkills = await characterSkills();
    ref.notifyListeners();
  }

  List<Fitting>? _fittings;

  Future<List<Fitting>?> getFittings() async {
    if (!_authorized) return null;
    _fittings ??= await characterFittings();
    return _fittings;
  }

  Future<void> setAuthorized(EsiAuthTokens? storage) async {
    _authorized = true;
    await EsiAuth().setTokens(storage);
    ref.notifyListeners();
  }

  Future<void> clearAuthorize() async {
    _authorized = false;
    _character = null;
    _characterSkills = null;
    await WebViewCookieManager().clearCookies();
    await EsiAuth().clearTokens();
    ref.notifyListeners();
  }

  void clearCache() async {
    _character = null;
    _characterSkills = null;
    _fittings = null;
    ref.notifyListeners();
  }
}
