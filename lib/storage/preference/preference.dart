import 'package:shared_preferences/shared_preferences.dart';

part 'item_list_behavior.dart';

class GlobalPreference {
  static late final SharedPreferences _instance;

  static Future<void> init() async {
    _instance = await SharedPreferences.getInstance();

    itemListPopBehavior.setDefault(_instance);
  }

  static SharedPreferences get instance => _instance;

  static ItemListPopBehavior get itemListPopBehavior => ItemListPopBehavior.get(_instance);

  static set itemListPopBehavior(ItemListPopBehavior value) => value.set(_instance);
}
