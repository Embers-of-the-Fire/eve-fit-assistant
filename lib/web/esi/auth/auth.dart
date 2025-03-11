import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/web/esi/meta/verify.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

part 'auth.freezed.dart';
part 'auth.g.dart';
part 'storage.dart';

@riverpod
Future<EsiAuthData?> getEsiAuthStorage(Ref ref) async {
  final auth = EsiAuth();
  final storage = auth._storage;
  if (storage != null && storage.isNotExpired) {
    return storage;
  }
  return null;
}

Future<void> showAuthPage(BuildContext context) async {
  if (GlobalPreference.esiAuthBehavior == EsiAuthBehavior.doubleCheck) {
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('授权确认'),
              content: const Text('你将要为该应用授权，这将允许该应用访问你的角色信息。\n你确定要继续吗？'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true), child: const Text('继续'))
              ],
            ));
    if (result != true || !context.mounted) {
      return;
    }
  }
  final state = const Uuid().v4();
  final url = _esiAuthEndpoint.replace(queryParameters: {
    'response_type': 'code',
    'redirect_uri': _esiRedirectURI.toString(),
    'client_id': _esiAppID,
    'scope': _esiAuthScope,
    'state': state,
    'realm': 'esi',
  });
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => OAuthWebView(
            authUrl: url.toString(),
            state: state,
            redirectUri: _esiRedirectURI.toString(),
          )));
}
