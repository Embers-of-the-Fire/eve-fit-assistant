/// Killboard source for killmail imports.
///
/// zKillboard covers Tranquility and exposes `GET /api/killID/<id>/`
/// returning an ESI-format killmail. Additional killboards that implement
/// the same endpoint shape can be added as new enum values; the import
/// dialog's server switcher picks them up automatically.
enum KillboardServer {
  zkillboard;

  String get host => switch (this) {
    KillboardServer.zkillboard => "zkillboard.com",
  };

  Uri killmailApiUri(int killmailId) => Uri.https(host, "/api/killID/$killmailId/");

  Uri killmailPageUri(int killmailId) => Uri.https(host, "/kill/$killmailId/");

  static KillboardServer? forHost(String host) {
    final normalized = host.toLowerCase();
    for (final server in values) {
      if (normalized == server.host || normalized == "www.${server.host}") {
        return server;
      }
    }
    return null;
  }
}
