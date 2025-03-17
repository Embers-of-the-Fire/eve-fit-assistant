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

const _itemListDisplayStyle = 'item_list_display_style';

enum ItemListDisplayStyle {
  marketGroup,
  group;

  static const defaultValue = marketGroup;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_itemListDisplayStyle)) {
      prefs.setInt(_itemListDisplayStyle, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_itemListDisplayStyle, index);
  }

  static ItemListDisplayStyle get(SharedPreferences prefs) =>
      ItemListDisplayStyle.values[prefs.getInt(_itemListDisplayStyle) ?? 0];
}

const _itemListShowUnpublished = 'item_list_show_unpublished';

enum ItemListShowUnpublished {
  show,
  hide;

  static const defaultValue = hide;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_itemListShowUnpublished)) {
      prefs.setInt(_itemListShowUnpublished, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_itemListShowUnpublished, index);
  }

  static ItemListShowUnpublished get(SharedPreferences prefs) =>
      ItemListShowUnpublished.values[prefs.getInt(_itemListShowUnpublished) ?? 0];
}
