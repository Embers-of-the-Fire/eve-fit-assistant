part of 'preference.dart';

const _itemListPopBehaviorKey = 'item_list_pop_behavior';

enum ItemListPopBehavior {
  exit,
  prevPage;

  static const defaultValue = prevPage;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_itemListPopBehaviorKey)) {
    prefs.setInt(_itemListPopBehaviorKey, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_itemListPopBehaviorKey, index);
  }

  static ItemListPopBehavior get(SharedPreferences prefs) =>
      ItemListPopBehavior.values[prefs.getInt(_itemListPopBehaviorKey) ?? 0];
}
