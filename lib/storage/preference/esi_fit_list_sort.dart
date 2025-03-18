part of 'preference.dart';

const _esiFitListSortMethodKey = 'esi_fit_list_sort_method';

enum EsiFitListSortMethod {
  preserve,
  ship,
  internalID;

  static const defaultValue = preserve;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_esiFitListSortMethodKey)) {
      prefs.setInt(_esiFitListSortMethodKey, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_esiFitListSortMethodKey, index);
  }

  static EsiFitListSortMethod get(SharedPreferences prefs) =>
      EsiFitListSortMethod.values[prefs.getInt(_esiFitListSortMethodKey) ?? 0];
}

const _esiFitListSortSequence = 'esi_fit_list_sort_sequence';

enum EsiFitListSortSequence {
  ascending,
  descending;

  static const defaultValue = ascending;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_esiFitListSortSequence)) {
      prefs.setInt(_esiFitListSortSequence, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_esiFitListSortSequence, index);
  }

  static EsiFitListSortSequence get(SharedPreferences prefs) =>
      EsiFitListSortSequence.values[prefs.getInt(_esiFitListSortSequence) ?? 0];
}
