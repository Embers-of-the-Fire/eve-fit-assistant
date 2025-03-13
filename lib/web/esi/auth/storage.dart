// ignore_for_file: invalid_annotation_target

part of 'auth.dart';

const _esiAuthScope='esi-skills.read_skills.v1';

final Uri _esiAuthEndpointTq = Uri.parse(r'https://login.eveonline.com/v2/oauth/authorize');
final Uri _esiAuthEndpointSe = Uri.parse(r'https://login.evepc.163.com/v2/oauth/authorize');
final Uri _esiTokenEndpointTq = Uri.parse(r'https://login.eveonline.com/v2/oauth/token');
final Uri _esiTokenEndpointSe = Uri.parse(r'https://login.evepc.163.com/v2/oauth/token');

const _esiAppIDTq = '683084ab5f8848d4b187462ac3b97677';
const _esiAppIDSe = 'bc90aa496a404724a93f41b4f4e97761';
final Uri _esiRedirectURITq = Uri.parse('https://esi.evetech.net/ui/oauth2-redirect.html');
final Uri _esiRedirectURISe = Uri.parse('https://ali-esi.evepc.163.com/ui/oauth2-redirect.html');

Uri _esiAuthEndpoint(EsiAuthServer server) => switch (server) {
      EsiAuthServer.tranquility => _esiAuthEndpointTq,
      EsiAuthServer.serenity => _esiAuthEndpointSe,
    };

Uri _esiTokenEndpoint(EsiAuthServer server) => switch (server) {
      EsiAuthServer.tranquility => _esiTokenEndpointTq,
      EsiAuthServer.serenity => _esiTokenEndpointSe,
    };

String _esiAppID(EsiAuthServer server) => switch (server) {
      EsiAuthServer.tranquility => _esiAppIDTq,
      EsiAuthServer.serenity => _esiAppIDSe,
    };

Uri _esiRedirectURI(EsiAuthServer server) => switch (server) {
      EsiAuthServer.tranquility => _esiRedirectURITq,
      EsiAuthServer.serenity => _esiRedirectURISe,
    };

@freezed
abstract class EsiAuthResponse with _$EsiAuthResponse {
  @JsonSerializable()
  const factory EsiAuthResponse({
    @JsonKey(name: 'access_token') required String accessToken,
    @JsonKey(name: 'expires_in') required int expiresIn,
    @JsonKey(name: 'refresh_token') required String refreshToken,
  }) = _EsiAuthResponse;

  factory EsiAuthResponse.fromJson(Map<String, dynamic> json) => _$EsiAuthResponseFromJson(json);
}

@freezed
abstract class EsiAuthTokens with _$EsiAuthTokens {
  const factory EsiAuthTokens({
    required String accessToken,
    required int expiresTimestamp,
    required String refreshToken,
    required EsiAuthServer server,
  }) = _EsiAuthTokens;

  const EsiAuthTokens._();

  factory EsiAuthTokens.fromResponse(EsiAuthServer server, EsiAuthResponse response) =>
      EsiAuthTokens(
        accessToken: response.accessToken,
        expiresTimestamp: DateTime.now().millisecondsSinceEpoch + response.expiresIn * 1000,
        refreshToken: response.refreshToken,
        server: server,
      );

  factory EsiAuthTokens.fromJson(Map<String, dynamic> json) => _$EsiAuthTokensFromJson(json);

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresTimestamp;

  bool get isNotExpired => !isExpired;
}

class EsiAuth {
  static const _esiAccessTokenKey = 'esi_access_token';
  static const _esiExpiresTimestampKey = 'esi_expires_timestamp';
  static const _esiRefreshTokenKey = 'esi_refresh_token';
  static const _esiServerKey = 'esi_server';

  static final EsiAuth _instance = EsiAuth._();

  EsiAuthTokens? _tokens;

  Future<EsiAuthTokens?> getTokensAuthorized() async {
    await setTokens(await _read());
    if (_tokens?.isExpired ?? false) {
      await _refreshToken();
    }
    return _tokens;
  }

  Future<EsiAuthTokens?> getTokens(BuildContext context) async {
    await setTokens(await _read());
    if (_tokens?.isNotExpired ?? false) {
      return _tokens;
    } else if (_tokens?.isExpired ?? false) {
      await _refreshToken();
      return _tokens;
    }
    if (!context.mounted) return null;
    await autoAuth(context);
    return _tokens;
  }

  Future<void> _refreshToken() async {
    final server = _tokens!.server;
    final raw = await http.post(
      _esiTokenEndpoint(server),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _tokens!.refreshToken,
        'client_id': _esiAppID(server),
      },
    );
    final response = EsiAuthResponse.fromJson(jsonDecode(raw.body));
    final storage = EsiAuthTokens.fromResponse(server, response);
    await setTokens(storage);
  }

  Future<void> setTokens(EsiAuthTokens? storage) async {
    _tokens = storage;
    if (storage != null) {
      const sec = FlutterSecureStorage();
      await sec.write(key: _esiAccessTokenKey, value: storage.accessToken);
      await sec.write(key: _esiExpiresTimestampKey, value: storage.expiresTimestamp.toString());
      await sec.write(key: _esiRefreshTokenKey, value: storage.refreshToken);
      await sec.write(key: _esiServerKey, value: storage.server.value.toString());
    }
  }

  Future<void> clearTokens() async {
    _tokens = null;
    const sec = FlutterSecureStorage();
    await sec.delete(key: _esiAccessTokenKey);
    await sec.delete(key: _esiExpiresTimestampKey);
    await sec.delete(key: _esiRefreshTokenKey);
    await sec.delete(key: _esiServerKey);
  }

  EsiAuth._();

  factory EsiAuth() => _instance;

  Future<void> autoAuth(BuildContext context) async {
    final server = Preference().esiAuthServer;

    await setTokens(await _read());

    if (!context.mounted) return;

    if (_tokens == null ||
        (_tokens != null && _tokens!.isExpired) ||
        (_tokens != null && _tokens!.server != server)) {
      await showAuthPage(context);
    }
  }

  Future<EsiAuthTokens?> _read() async {
    const storage = FlutterSecureStorage();
    final accessToken = await storage.read(key: _esiAccessTokenKey);
    final expiresTimestamp =
        (await storage.read(key: _esiExpiresTimestampKey)).andThen(int.tryParse);
    final refreshToken = await storage.read(key: _esiRefreshTokenKey);
    final server =
        (await storage.read(key: _esiServerKey)).andThen(int.tryParse).map((u) => EsiAuthServer(u));
    if (accessToken != null && expiresTimestamp != null && refreshToken != null && server != null) {
      return EsiAuthTokens(
        server: server,
        accessToken: accessToken,
        expiresTimestamp: expiresTimestamp,
        refreshToken: refreshToken,
      );
    } else {
      return null;
    }
  }
}

class OAuthWebView extends StatefulWidget {
  final String authUrl;
  final String state;
  final EsiAuthServer server;

  const OAuthWebView({
    super.key,
    required this.authUrl,
    required this.state,
    required this.server,
  });

  @override
  State<OAuthWebView> createState() => _OAuthWebViewState();
}

class _OAuthWebViewState extends State<OAuthWebView> {
  late WebViewController _controller;
  bool _isLoading = true;

  Future<EsiAuthTokens> _exchangeCodeForToken(String code) async {
    final raw = await http.post(
      _esiTokenEndpoint(widget.server),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _esiRedirectURI(widget.server).toString(),
        'state': widget.state,
        'client_id': _esiAppID(widget.server),
      },
    );
    final response = EsiAuthResponse.fromJson(jsonDecode(raw.body));
    final storage = EsiAuthTokens.fromResponse(widget.server, response);
    return storage;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => setState(() => _isLoading = true),
        onPageFinished: (url) => setState(() => _isLoading = false),
        onNavigationRequest: (request) async {
          if (request.url.startsWith(_esiRedirectURI(widget.server).toString())) {
            final uri = Uri.parse(request.url);
            final code = uri.queryParameters['code'];
            final state = uri.queryParameters['state'];

            if (code != null && state == widget.state) {
              final token = await _exchangeCodeForToken(code);
              await EsiDataStorage().setAuthorized(token);
              _finishAuth(token);
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  void _finishAuth(EsiAuthTokens storage) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('认证中...'),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
}
