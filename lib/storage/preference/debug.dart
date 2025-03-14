part of 'preference.dart';

const _debugKey = 'debug';

enum Debug {
  enable,
  disable;

  static const defaultValue = disable;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_debugKey)) {
      prefs.setInt(_debugKey, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_debugKey, index);
  }

  static Debug get(SharedPreferences prefs) => Debug.values[prefs.getInt(_debugKey) ?? 0];
}
