import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

const String sponsorshipUrl = "https://ifdian.net/a/embersofthefire";

/// Base URL of the online manual site (English at the root, Chinese under
/// `/zh`).
const String manualSiteBaseUrl = "https://docs.efa-tech.dev";

/// The manual doc explaining how to publish (upload) a fit to the platform.
const String publishingManualDocPath = "sharing/publishing-fits";

Future<void> openSponsorshipPage(BuildContext context) async {
  bool didLaunch = false;
  try {
    didLaunch = await launchUrl(Uri.parse(sponsorshipUrl), mode: LaunchMode.externalApplication);
  } on Object {
    didLaunch = false;
  }
  if (!didLaunch && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.sponsorshipOpenError)));
  }
}

/// Open the online manual site, localized to the current locale and
/// optionally deep-linked to [docPath] (e.g. [publishingManualDocPath]).
///
/// Used on platforms where the in-app manual is not provided (web).
Future<void> openWebManualPage(BuildContext context, {String? docPath}) async {
  final base = context.locale.languageCode == "zh" ? "$manualSiteBaseUrl/zh" : manualSiteBaseUrl;
  final uri = Uri.parse(docPath == null ? "$base/" : "$base/$docPath/");
  bool didLaunch = false;
  try {
    didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    didLaunch = false;
  }
  if (!didLaunch && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.reportOpenError)));
  }
}
