import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

const String sponsorshipUrl = "https://ifdian.net/a/embersofthefire";

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
