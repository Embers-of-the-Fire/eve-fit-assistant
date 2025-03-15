import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/web/esi/auth/auth.dart';
import 'package:eve_fit_assistant/web/esi/esi/character/fittings.dart';
import 'package:eve_fit_assistant/web/esi/esi/character/skills.dart';
import 'package:eve_fit_assistant/web/esi/meta/verify.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:webview_flutter/webview_flutter.dart';

part 'character.dart';
part 'esi.freezed.dart';

String esiUrl(EsiAuthServer server) => switch (server) {
      EsiAuthServer.tranquility => 'https://esi.evetech.net',
      EsiAuthServer.serenity => 'https://ali-esi.evepc.163.com',
    };

final esiDataProvider = ChangeNotifierProvider((ref) => EsiDataStorage());

class EsiDataStorage extends ChangeNotifier {
  static final EsiDataStorage _instance = EsiDataStorage._();

  EsiDataStorage._();

  factory EsiDataStorage() => _instance;

  bool _authorized = false;

  bool get authorized => _authorized;

  Future<void> init() async {
    final token = await EsiAuth().getTokensAuthorized();
    _authorized = token != null && token.server == Preference().esiAuthServer;
    notifyListeners();
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

  List<Fitting>? _fittings;

  Future<List<Fitting>?> getFittings() async {
    if (!_authorized) return null;
    _fittings ??= await characterFittings();
    return _fittings;
  }

  Future<void> setAuthorized(EsiAuthTokens? storage) async {
    _authorized = true;
    await EsiAuth().setTokens(storage);
    notifyListeners();
  }

  Future<void> clearAuthorize() async {
    _authorized = false;
    _character = null;
    _characterSkills = null;
    await WebViewCookieManager().clearCookies();
    await EsiAuth().clearTokens();
    notifyListeners();
  }

  void clearCache() async {
    _character = null;
    _characterSkills = null;
    _fittings = null;
    notifyListeners();
  }
}
