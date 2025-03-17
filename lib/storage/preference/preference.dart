import 'package:json_annotation/json_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'debug.dart';
part 'esi_auth_behavior.dart';
part 'item_list_behavior.dart';
part 'market_api.dart';
part 'preference.g.dart';

@riverpod
class GlobalPreference extends _$GlobalPreference {
  @override
  PreferenceState build() => PreferenceState(Preference(), 0);

  void modify(void Function(Preference) modifier) {
    modifier(state.preference);
    state = PreferenceState(state.preference, state.stats + 1);
  }
}

class PreferenceState {
  final Preference preference;
  int stats;

  PreferenceState(this.preference, this.stats);
}

class Preference {
  late final SharedPreferences _preference;
  static final Preference _instance = Preference._();

  Preference._();

  factory Preference() => _instance;

  Future<void> init() async {
    _preference = await SharedPreferences.getInstance();

    itemListPopBehavior.setDefault(_preference);
    marketApi.setDefault(_preference);
    debug.setDefault(_preference);
    esiAuthBehavior.setDefault(_preference);
    esiAuthServer.setDefault(_preference);
  }

  SharedPreferences get instance => _preference;

  ItemListPopBehavior get itemListPopBehavior => ItemListPopBehavior.get(_preference);

  ItemListDisplayStyle get itemListDisplayStyle => ItemListDisplayStyle.get(_preference);

  MarketApi get marketApi => MarketApi.get(_preference);

  Debug get debug => Debug.get(_preference);

  EsiAuthBehavior get esiAuthBehavior => EsiAuthBehavior.get(_preference);

  EsiAuthServer get esiAuthServer => EsiAuthServer.get(_preference);

  set itemListPopBehavior(ItemListPopBehavior value) => value.set(_preference);

  set itemListDisplayStyle(ItemListDisplayStyle value) => value.set(_preference);

  set marketApi(MarketApi value) => value.set(_preference);

  set debug(Debug value) => value.set(_preference);

  set esiAuthBehavior(EsiAuthBehavior value) => value.set(_preference);

  set esiAuthServer(EsiAuthServer value) => value.set(_preference);
}
