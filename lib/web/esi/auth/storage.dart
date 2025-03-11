// ignore_for_file: invalid_annotation_target

part of 'auth.dart';

const _esiAuthScope = 'esi-skills.read_skills.v1';

final Uri _esiAuthEndpoint = Uri.parse(r'https://login.eveonline.com/v2/oauth/authorize');
final Uri _esiTokenEndpoint = Uri.parse(r'https://login.eveonline.com/v2/oauth/token');

const _esiAppID = '683084ab5f8848d4b187462ac3b97677';
final Uri _esiRedirectURI = Uri.parse('https://esi.evetech.net/ui/oauth2-redirect.html');

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
  }) = _EsiAuthTokens;

  const EsiAuthTokens._();

  factory EsiAuthTokens.fromResponse(EsiAuthResponse response) => EsiAuthTokens(
        accessToken: response.accessToken,
        expiresTimestamp: DateTime.now().millisecondsSinceEpoch + response.expiresIn * 1000,
        refreshToken: response.refreshToken,
      );

  factory EsiAuthTokens.fromJson(Map<String, dynamic> json) => _$EsiAuthTokensFromJson(json);

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresTimestamp;

  bool get isNotExpired => !isExpired;
}

class EsiAuthData {
  final EsiAuthTokens tokens;
  final String? characterName;
  final int characterID;

  const EsiAuthData({
    required this.tokens,
    required this.characterName,
    required this.characterID,
  });

  bool get isExpired => tokens.isExpired;

  bool get isNotExpired => !isExpired;

  static Future<EsiAuthData> init(EsiAuthTokens tokens) async {
    final verifyResponse = await verify(tokens.accessToken);
    return EsiAuthData(
      tokens: tokens,
      characterName: verifyResponse.characterName,
      characterID: verifyResponse.characterID,
    );
  }
}

class EsiAuth {
  static const _esiAccessTokenKey = 'esi_access_token';
  static const _esiExpiresTimestampKey = 'esi_expires_timestamp';
  static const _esiRefreshTokenKey = 'esi_refresh_token';

  static final EsiAuth _instance = EsiAuth._();

  EsiAuthData? _storage;

  EsiAuthData? get storage => _storage;

  Future<EsiAuthData?> getStorage(BuildContext context) async {
    await setStorage(await _read());
    if (_storage?.isNotExpired ?? false) {
      return _storage;
    } else if (_storage?.isExpired ?? false) {
      await _refreshToken();
      return _storage;
    }
    log('here', name: 'EsiAuth.getStorage');
    if (!context.mounted) return null;
    await autoAuth(context);
    return _storage;
  }

  Future<void> _refreshToken() async {
    final raw = await http.post(
      _esiTokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _storage!.tokens.refreshToken,
        'client_id': _esiAppID,
      },
    );
    final response = EsiAuthResponse.fromJson(jsonDecode(raw.body));
    final storage = EsiAuthTokens.fromResponse(response);
    await setStorage(storage);
  }

  Future<void> setStorage(EsiAuthTokens? storage) async {
    _storage = await storage.map<Future<EsiAuthData>>((u) async => await EsiAuthData.init(u));
    if (storage != null) {
      const sec = FlutterSecureStorage();
      await sec.write(key: _esiAccessTokenKey, value: storage.accessToken);
      await sec.write(key: _esiExpiresTimestampKey, value: storage.expiresTimestamp.toString());
      await sec.write(key: _esiRefreshTokenKey, value: storage.refreshToken);
    }
  }

  Future<void> clearStorage() async {
    _storage = null;
    const sec = FlutterSecureStorage();
    await sec.delete(key: _esiAccessTokenKey);
    await sec.delete(key: _esiExpiresTimestampKey);
    await sec.delete(key: _esiRefreshTokenKey);
  }

  EsiAuth._();

  factory EsiAuth() => _instance;

  Future<void> autoAuth(BuildContext context) async {
    await setStorage(await _read());

    if (!context.mounted) return;

    if (_storage == null || (_storage != null && _storage!.isExpired)) {
      await showAuthPage(context);
    }
  }

  Future<EsiAuthTokens?> _read() async {
    const storage = FlutterSecureStorage();
    final accessToken = await storage.read(key: _esiAccessTokenKey);
    final expiresTimestamp =
        (await storage.read(key: _esiExpiresTimestampKey)).andThen(int.tryParse);
    final refreshToken = await storage.read(key: _esiRefreshTokenKey);
    if (accessToken != null && expiresTimestamp != null && refreshToken != null) {
      return EsiAuthTokens(
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
  final String redirectUri;

  const OAuthWebView({
    super.key,
    required this.authUrl,
    required this.state,
    required this.redirectUri,
  });

  @override
  State<OAuthWebView> createState() => _OAuthWebViewState();
}

class _OAuthWebViewState extends State<OAuthWebView> {
  late WebViewController _controller;
  bool _isLoading = true;

  Future<EsiAuthTokens> _exchangeCodeForToken(String code) async {
    final raw = await http.post(
      _esiTokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _esiRedirectURI.toString(),
        'state': widget.state,
        'client_id': _esiAppID,
      },
    );
    final response = EsiAuthResponse.fromJson(jsonDecode(raw.body));
    final storage = EsiAuthTokens.fromResponse(response);
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
          if (request.url.startsWith(widget.redirectUri)) {
            final uri = Uri.parse(request.url);
            final code = uri.queryParameters['code'];
            final state = uri.queryParameters['state'];

            if (code != null && state == widget.state) {
              final token = await _exchangeCodeForToken(code);
              await EsiAuth().setStorage(token);
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
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
}
