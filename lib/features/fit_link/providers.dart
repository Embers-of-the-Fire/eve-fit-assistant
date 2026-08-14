import "package:eve_fit_assistant/features/fit_link/boot_probe.dart";
import "package:eve_fit_assistant/features/fit_link/importer.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

sealed class PendingFitLink {
  const PendingFitLink(this.uri);

  final Uri uri;
}

final class BootFitLink extends PendingFitLink {
  const BootFitLink(super.uri);
}

final class ExternalFitLink extends PendingFitLink {
  const ExternalFitLink(super.uri);
}

final pendingFitLinkProvider = NotifierProvider<PendingFitLinkNotifier, PendingFitLink?>(
  PendingFitLinkNotifier.new,
);

class PendingFitLinkNotifier extends Notifier<PendingFitLink?> {
  @override
  PendingFitLink? build() {
    final bootUri = takeBootFitLink();
    return bootUri == null ? null : BootFitLink(bootUri);
  }

  void setBoot(Uri uri) => state = BootFitLink(uri);

  void setExternal(Uri uri) => state = ExternalFitLink(uri);

  void clear() => state = null;
}

final fitLinkImporterProvider = Provider<FitLinkImporter>(FitLinkImporter.new);
