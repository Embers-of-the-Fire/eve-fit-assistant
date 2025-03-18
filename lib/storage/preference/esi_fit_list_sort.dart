part of 'preference.dart';

const _esiFitListSortKey = 'esi_fit_list_sort';

enum EsiFitListSort {
  preserve,
  ship,
  internalID;

  static const defaultValue = preserve;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_esiFitListSortKey)) {
      prefs.setInt(_esiFitListSortKey, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_esiFitListSortKey, index);
  }

  static EsiFitListSort get(SharedPreferences prefs) =>
      EsiFitListSort.values[prefs.getInt(_esiFitListSortKey) ?? 0];
}
