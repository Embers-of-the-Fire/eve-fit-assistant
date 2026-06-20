/// Server metadata extracted from the ServerIndex protobuf.
///
/// Lightweight representation for UI display and channel navigation.
/// Not stored as a separate JSON file on the client — read from
/// channels/{channel}/server.pb2.
class ServerMeta {
  const ServerMeta({
    required this.serverId,
    required this.gameBuild,
    required this.gameVersion,
    this.name,
    this.region,
    this.sync,
    this.branch,
  });

  final String serverId;
  final String gameBuild;
  final String gameVersion;
  final Map<String, String>? name;
  final String? region;
  final String? sync;
  final String? branch;

  /// Returns the display name for [locale], falling back to serverId.
  String displayName(String locale) => name?[locale] ?? serverId;
}
