import "dart:async";

import "package:flutter_easyloading/flutter_easyloading.dart";

class GlobalLoading {
  factory GlobalLoading() => _instance;

  GlobalLoading._internal();
  static final GlobalLoading _instance = GlobalLoading._internal();

  static void init() {
    EasyLoading.instance
      ..dismissOnTap = false
      ..userInteractions = false;
  }

  /// List of loading messages
  final List<(String, String)> _loadingMessages = [];

  bool _isLoading = false;

  static void add(String key, String message) {
    _instance._loadingMessages.add((key, message));
    _instance._update();
  }

  static void dismiss(String key) {
    _instance._loadingMessages.removeWhere((t) => t.$1 == key);
    _instance._update();
  }

  void _update() {
    if (_loadingMessages.isEmpty && _isLoading) {
      unawaited(EasyLoading.dismiss());
      _isLoading = false;
    } else if (_loadingMessages.isNotEmpty && !_isLoading) {
      final currentMessage = _loadingMessages.last;
      unawaited(EasyLoading.show(status: currentMessage.$2));
      _isLoading = true;
    } else if (_loadingMessages.isNotEmpty && _isLoading) {
      final currentMessage = _loadingMessages.last;
      EasyLoading.instance.key?.currentState?.updateStatus(currentMessage.$2);
    }
  }
}
