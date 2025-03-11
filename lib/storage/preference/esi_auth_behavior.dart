part of 'preference.dart';

const _esiAuthKey = 'esi_auth';

enum EsiAuthBehavior {
  immediate,
  doubleCheck;

  static const defaultValue = immediate;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_esiAuthKey)) {
      prefs.setInt(_esiAuthKey, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_esiAuthKey, index);
  }

  static EsiAuthBehavior get(SharedPreferences prefs) =>
      EsiAuthBehavior.values[prefs.getInt(_esiAuthKey) ?? 0];
}
