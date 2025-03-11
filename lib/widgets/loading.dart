import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

final loadingKey = GlobalKey();

class GlobalLoading {
  static final GlobalLoading _instance = GlobalLoading._internal();

  factory GlobalLoading() => _instance;

  GlobalLoading._internal();

  void init() {
    EasyLoading.instance
      ..dismissOnTap = false
      ..userInteractions = false;
  }

  /// List of loading messages
  ///
  /// - `String.$1`: Key, to identify the loading message
  /// - `String.$2`: Value, the loading message
  final List<(String, String)> _loadingList = [];

  bool _isLoading = false;

  void add(String key, String value) {
    _loadingList.add((key, value));
    _update();
  }

  void dismiss(String key) {
    _loadingList.removeWhere((element) => element.$1 == key);
    _update();
  }

  void _update() {
    if (_loadingList.isEmpty && _isLoading) {
      EasyLoading.dismiss();
      _isLoading = false;
    } else if (_loadingList.isNotEmpty && !_isLoading) {
      EasyLoading.show(status: _loadingList.last.$2);
      _isLoading = true;
    } else if (_loadingList.isNotEmpty && _isLoading) {
      EasyLoading.instance.key?.currentState?.updateStatus(_loadingList.last.$2);
    }
  }
}
