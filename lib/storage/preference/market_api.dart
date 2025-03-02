part of 'preference.dart';

const _marketApiKey = 'market_api';

enum MarketApi {
  cEveMarket,
  esi;

  static const defaultValue = esi;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_marketApiKey)) {
      prefs.setInt(_marketApiKey, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_marketApiKey, index);
  }

  static MarketApi get(SharedPreferences prefs) =>
      MarketApi.values[prefs.getInt(_marketApiKey) ?? 0];
}
