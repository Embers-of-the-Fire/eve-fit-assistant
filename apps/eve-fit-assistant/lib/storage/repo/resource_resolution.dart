import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/constant/resource_vocabulary.g.dart";

/// Version of the Resource Resolution Schema (RRS) shipped with the app.
///
/// The RRS is the app's declarative rule set deciding which checkout
/// resources are downloaded eagerly, lazily, or not at all. Bump this when
/// the rule list changes in a behaviorally meaningful way. The version is a
/// property of the app release (like the per-DB schema versions); it is
/// surfaced on the version settings page but is not persisted into the
/// repository and triggers no migration.
const int kResourceResolutionSchemaVersion = 1;

/// The download decision for a single `ResourceIndex.Entry`, made by the
/// client through the Resource Resolution Schema.
///
/// The resolution **replaces** the server-stamped `download_policy` for new
/// clients; the stamped policy remains meaningful only to older clients and
/// to resolution-less tooling.
enum ResourceResolution {
  /// Downloaded ahead of time during provisioning and data updates. Expected
  /// present; a missing blob is a verification failure subject to repair.
  eager,

  /// Not downloaded ahead of time. Fetched on first access through the
  /// on-demand blob path. A missing blob is expected and never a verification
  /// failure; a present blob is still hash-verified.
  lazy,

  /// Never downloaded and never expected. Invisible to provisioning, updates,
  /// verification, and size previews. Used for superseded resources retained
  /// only for older clients.
  excluded,
}

/// Client-side state available to RRS rule evaluation.
///
/// The context is read at the moment of evaluation. Provisioning, data
/// updates, and size previews evaluate with the **current app locale**; in
/// the welcome wizard this is the locale chosen in the language step, which
/// precedes provisioning.
final class ResourceResolutionContext {
  const ResourceResolutionContext({required this.locale});

  /// The active app locale (e.g. `"en"`, `"zh"`).
  final String locale;
}

/// Evaluates the Resource Resolution Schema (RRS v1) for [entry] against
/// [index] and [context], returning the first matching rule's resolution.
///
/// Rules, in order (first match wins):
/// - **R1** the legacy combined localization db is `excluded` when the index
///   provides per-locale replacements, `eager` otherwise (compatibility
///   hinge: a new app on an old snapshot behaves like an old app).
/// - **R2** the active locale's per-locale db is `eager`.
/// - **R3** other per-locale dbs are `lazy`.
/// - **R4** static images are `lazy`.
/// - **R5** everything else is `eager` — fail closed toward availability.
ResourceResolution resolveResource(
  ResourceIndex index,
  ResourceIndex_Entry entry,
  ResourceResolutionContext context,
) {
  final id = entry.resourceId;

  // R1: legacy combined localization db.
  if (id == kLegacyLocalizationDbResourceId) {
    final hasPerLocale = index.entries.any(
      (e) => e.resourceId.startsWith(kLocalizationLocalesResourcePrefix),
    );
    return hasPerLocale ? ResourceResolution.excluded : ResourceResolution.eager;
  }

  // R2: the active locale's per-locale db.
  final activeLocaleDbId = kLocaleLocalizationDbResourcePattern.replaceAll(
    kLocalePlaceholder,
    context.locale,
  );
  if (id == activeLocaleDbId) return ResourceResolution.eager;

  // R3: any other per-locale db.
  if (id.startsWith(kLocalizationLocalesResourcePrefix)) return ResourceResolution.lazy;

  // R4: static images.
  if (id.startsWith(kStaticImagesResourcePrefix)) return ResourceResolution.lazy;

  // R5: default — fail closed toward availability.
  return ResourceResolution.eager;
}

/// Counts the entries of [index] that blob verification visits under
/// [context]: every entry whose RRS resolution is not
/// [ResourceResolution.excluded].
///
/// Verification progress totals and offsets must use this count rather than
/// `index.entries.length`, since excluded entries are neither checked nor
/// counted during verification.
int countVerificationTargets(ResourceIndex index, ResourceResolutionContext context) => index
    .entries
    .where((e) => resolveResource(index, e, context) != ResourceResolution.excluded)
    .length;
