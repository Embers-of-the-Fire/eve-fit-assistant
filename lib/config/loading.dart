import 'dart:collection';

import 'package:flutter_easyloading/flutter_easyloading.dart';

class GlobalLoading {
  static final GlobalLoading _instance = GlobalLoading._internal();

  factory GlobalLoading() => _instance;

  GlobalLoading._internal();

  static void init() {
    EasyLoading.instance
      ..dismissOnTap = false
      ..userInteractions = false;
  }

  /// List of loading messages
  final LinkedHashMap<String, String> _loadingMessages = LinkedHashMap<String, String>();

  bool _isLoading = false;

  static void add(String key, String message) {
    _instance._loadingMessages[key] = message;
    _instance._update();
  }

  static void dismiss(String key) {
    _instance._loadingMessages.remove(key);
    _instance._update();
  }

  void _update() {
    if (_loadingMessages.isEmpty && _isLoading) {
      EasyLoading.dismiss();
      _isLoading = false;
    } else if (_loadingMessages.isNotEmpty && !_isLoading) {
      final currentMessage = _loadingMessages.values.last;
      EasyLoading.show(status: currentMessage);
      _isLoading = true;
    } else if (_loadingMessages.isNotEmpty && _isLoading) {
      final currentMessage = _loadingMessages.values.last;
      EasyLoading.instance.key?.currentState?.updateStatus(currentMessage);
    }
  }
}
