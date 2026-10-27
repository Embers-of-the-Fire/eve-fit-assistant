/// Resource Resolution Schema (RRS) client evaluation.
///
/// The schema is single-sourced in `data/schema/resource_resolution.toml`:
/// the generated library (`resource_resolution.g.dart`) carries the RRS
/// version, the `ResourceResolution` enum, the `ResourceResolutionContext`,
/// and the `resolveResource` evaluator compiled from the rule list. This
/// library re-exports them and adds the hand-written helpers below.
library;

import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/resource_resolution.g.dart";

export "package:eve_fit_assistant/storage/repo/resource_resolution.g.dart";

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
