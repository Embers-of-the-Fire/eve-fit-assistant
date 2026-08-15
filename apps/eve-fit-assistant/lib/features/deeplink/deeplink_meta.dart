/// Agent-facing description of a linkable route.
///
/// Attach to a route in the route table via
/// `AutoRoute(..., meta: {DeepLinkMeta.key: const DeepLinkMeta(...)})`.
/// Routes without this entry are not exposed as in-app link targets.
class DeepLinkMeta {
  const DeepLinkMeta({required this.title, required this.usage});

  /// Key under which this entry is stored in route metadata.
  static const String key = "deeplink";

  /// Short label of the destination page.
  final String title;

  /// When linking here is appropriate, phrased for the chat agent.
  final String usage;
}
