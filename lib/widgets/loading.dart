import 'package:flutter_easyloading/flutter_easyloading.dart';

class GlobalLoading {
  static final GlobalLoading _instance = GlobalLoading._internal();

  factory GlobalLoading() => _instance;

  GlobalLoading._internal();

  void init() => _configEasyLoading();

  /// List of loading messages
  ///
  /// - `String.$1`: Key, to identify the loading message
  /// - `String.$2`: Value, the loading message
  final List<(String, String)> _loadingList = [];

  void add(String key, String value) {
    _loadingList.add((key, value));
    _update();
  }

  void dismiss(String key) {
    _loadingList.removeWhere((element) => element.$1 == key);
    _update();
  }

  void _update() {
    if (_loadingList.isEmpty) {
      EasyLoading.dismiss();
    } else {
      EasyLoading.show(status: _loadingList.first.$2);
    }
  }
}

void _configEasyLoading() {
  EasyLoading.instance
    ..dismissOnTap = false
    ..userInteractions = false;
}
