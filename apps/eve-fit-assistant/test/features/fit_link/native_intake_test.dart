@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/fit_link/native_intake.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late List<Uri> fitLinks;
  late List<Uri> internalLinks;
  late NativeFitLinkIntake intake;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_intake_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    fitLinks = [];
    internalLinks = [];
    intake = NativeFitLinkIntake(onFitLink: fitLinks.add, onInternalLink: internalLinks.add);
  });

  test("efa fit/raw links route to the fit importer", () {
    intake.dispatch(Uri.parse("efa://fit/raw?payload=EFA2:abc"));
    expect(fitLinks, hasLength(1));
    expect(internalLinks, isEmpty);
  });

  test("https app and share host links route to the fit importer", () {
    for (final host in [
      "share.platform.efa-tech.dev",
      "app.efa-tech.dev",
      "app-preview.efa-tech.dev",
    ]) {
      intake.dispatch(Uri.parse("https://$host/fit/raw?payload=EFA2:abc"));
    }
    expect(fitLinks, hasLength(3));
    expect(internalLinks, isEmpty);
  });

  test("other efa links delegate to the internal handler", () {
    intake
      ..dispatch(Uri.parse("efa://manual/fitting"))
      ..dispatch(Uri.parse("efa://fit/raw"));
    expect(internalLinks, hasLength(2));
    expect(fitLinks, isEmpty);
  });

  test("unknown hosts and schemes are dropped", () {
    intake
      ..dispatch(Uri.parse("https://example.com/fit/raw?payload=EFA2:abc"))
      ..dispatch(Uri.parse("https://app.efa-tech.dev/manual"))
      ..dispatch(Uri.parse("mailto:someone@example.com"));
    expect(fitLinks, isEmpty);
    expect(internalLinks, isEmpty);
  });
}
