import "dart:async";

import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:flutter/widgets.dart";
import "package:flutter_easyloading/flutter_easyloading.dart";

/// Builder for localized loading messages (no BuildContext needed).
typedef L10nMessageBuilder = String Function(AppLocalizations l10n);

class _LoadingMessage {
  final String key;
  final String? message;
  final L10nMessageBuilder? l10nBuilder;

  const _LoadingMessage(this.key, {this.message, this.l10nBuilder});

  String resolve(AppLocalizations? l10n) {
    if (l10nBuilder != null && l10n != null) {
      return l10nBuilder!(l10n);
    }
    return message ?? "";
  }
}

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
  final List<_LoadingMessage> _loadingMessages = [];

  /// Locale provider used to resolve AppLocalizations without a BuildContext.
  Locale Function()? _localeProvider;

  bool _isLoading = false;

  static void add(String key, String message) {
    _instance._loadingMessages.add(_LoadingMessage(key, message: message));
    _instance._update();
  }

  static void addLocalized(String key, L10nMessageBuilder builder) {
    _instance._loadingMessages.add(_LoadingMessage(key, l10nBuilder: builder));
    _instance._update();
  }

  static void dismiss(String key) {
    _instance._loadingMessages.removeWhere((t) => t.key == key);
    _instance._update();
  }

  /// Set locale provider for localized messages.
  static void setLocaleProvider(Locale Function() provider) {
    _instance._localeProvider = provider;
    _instance._update();
  }

  /// Force re-resolving the current status (useful after locale changes).
  static void refresh() => _instance._update();

  AppLocalizations? _resolveL10n() {
    final locale = _localeProvider?.call();
    if (locale == null) return null;
    return lookupAppLocalizations(locale);
  }

  void _update() {
    final l10n = _resolveL10n();
    if (_loadingMessages.isEmpty && _isLoading) {
      unawaited(EasyLoading.dismiss());
      _isLoading = false;
    } else if (_loadingMessages.isNotEmpty && !_isLoading) {
      final currentMessage = _loadingMessages.last;
      unawaited(EasyLoading.show(status: currentMessage.resolve(l10n)));
      _isLoading = true;
    } else if (_loadingMessages.isNotEmpty && _isLoading) {
      final currentMessage = _loadingMessages.last;
      EasyLoading.instance.key?.currentState?.updateStatus(currentMessage.resolve(l10n));
    }
  }
}
