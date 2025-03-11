import 'package:shared_preferences/shared_preferences.dart';

part 'debug.dart';
part 'esi_auth_behavior.dart';
part 'item_list_behavior.dart';
part 'market_api.dart';

class GlobalPreference {
  static late final SharedPreferences _instance;

  const GlobalPreference._();

  static Future<void> init() async {
    _instance = await SharedPreferences.getInstance();

    itemListPopBehavior.setDefault(_instance);
    marketApi.setDefault(_instance);
    debug.setDefault(_instance);
  }

  static SharedPreferences get instance => _instance;

  static ItemListPopBehavior get itemListPopBehavior => ItemListPopBehavior.get(_instance);

  static MarketApi get marketApi => MarketApi.get(_instance);

  static Debug get debug => Debug.get(_instance);

  static EsiAuthBehavior get esiAuthBehavior => EsiAuthBehavior.get(_instance);

  static set itemListPopBehavior(ItemListPopBehavior value) => value.set(_instance);

  static set marketApi(MarketApi value) => value.set(_instance);

  static set debug(Debug value) => value.set(_instance);

  static set esiAuthBehavior(EsiAuthBehavior value) => value.set(_instance);
}
