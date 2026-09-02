@TestOn("vm")
library;

import "dart:async";
import "dart:io";

import "package:efa_acl/efa_acl.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations_zh.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/fit_io/share_operation.dart";
import "package:eve_fit_assistant/features/fit_io/snapshot_upload_api.dart";
import "package:eve_fit_assistant/features/fit_io/upload_request.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitStorage _makeFit() => FitStorage(
  metadata: const FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 12017,
    name: "Test Fit",
    lastModified: 0,
    description: "",
    checkoutRef: CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: const FitStorageBody(
    shipTypeId: 12017,
    characterId: "predefined_all_5",
    damageProfile: FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: IList.empty(),
      medium: IList.empty(),
      low: IList.empty(),
      rig: IList.empty(),
      subsystem: IList.empty(),
      service: IList.empty(),
      tacticalMode: None(),
    ),
    drones: IList.empty(),
    fighters: IList.empty(),
    implants: IList.empty(),
    boosters: IList.empty(),
  ),
  dynamicRegistry: const FitDynamicRegistry(dynamicItems: IMap.empty()),
);

const _result = FitPostSubmitResult(
  postId: "post-1",
  fitHash: "abc123",
  alreadyExisted: false,
  postUrl: "https://platform.efa-tech.dev/post/post-1",
  origin: platformApiProductionOrigin,
);

void main() {
  // The operation logs a warning when opening the post page fails; initialize
  // the global logger once (it is `late final`) with a throwaway file target.
  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa-share-test").path,
      enableDebugLog: false,
    );
  });

  group("FitShareOperation.share", () {
    Future<WidgetRef> pumpRef(
      WidgetTester tester, {
      required Future<bool> Function(Uri) launcher,
      FitSnapshotUploadFn? uploadFn,
    }) async {
      late WidgetRef captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fitSnapshotUploadFnProvider.overrideWithValue(
              uploadFn ??
                  (
                    ref, {
                    required fitId,
                    required fit,
                    allowLatestSnapshotFallback = false,
                  }) async => _result,
            ),
            fitShareUrlLauncherProvider.overrideWithValue(launcher),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets("uploads and returns the result without opening the post page", (tester) async {
      final launched = <Uri>[];
      final ref = await pumpRef(
        tester,
        launcher: (uri) async {
          launched.add(uri);
          return true;
        },
      );

      final outcome = await const FitShareOperation().share(
        ref,
        fitId: "test-fit-1",
        fit: _makeFit(),
      );

      expect(outcome, _result);
      // The post page is only opened on explicit user request: the site may
      // still be processing the upload right after submission.
      expect(launched, isEmpty);
    });

    testWidgets("forwards the latest-snapshot fallback consent to the upload", (tester) async {
      final seen = <bool>[];
      final ref = await pumpRef(
        tester,
        launcher: (uri) async => true,
        uploadFn: (ref, {required fitId, required fit, allowLatestSnapshotFallback = false}) async {
          seen.add(allowLatestSnapshotFallback);
          return _result;
        },
      );

      await const FitShareOperation().share(ref, fitId: "test-fit-1", fit: _makeFit());
      await const FitShareOperation().share(
        ref,
        fitId: "test-fit-1",
        fit: _makeFit(),
        allowLatestSnapshotFallback: true,
      );

      expect(seen, [false, true]);
    });

    testWidgets("upload failures propagate without launching anything", (tester) async {
      final launched = <Uri>[];
      final ref = await pumpRef(
        tester,
        launcher: (uri) async {
          launched.add(uri);
          return true;
        },
        uploadFn:
            (ref, {required fitId, required fit, allowLatestSnapshotFallback = false}) async =>
                throw const FitUploadException(FitUploadErrorCode.forbidden),
      );

      await expectLater(
        () => const FitShareOperation().share(ref, fitId: "test-fit-1", fit: _makeFit()),
        throwsA(isA<FitUploadException>()),
      );
      expect(launched, isEmpty);
    });
  });

  group("FitShareOperation.openPost", () {
    Future<WidgetRef> pumpRef(
      WidgetTester tester, {
      required Future<bool> Function(Uri) launcher,
    }) async {
      late WidgetRef captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fitSnapshotUploadFnProvider.overrideWithValue(
              (ref, {required fitId, required fit, allowLatestSnapshotFallback = false}) async =>
                  _result,
            ),
            fitShareUrlLauncherProvider.overrideWithValue(launcher),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets("launches the post page URL", (tester) async {
      final launched = <Uri>[];
      final ref = await pumpRef(
        tester,
        launcher: (uri) async {
          launched.add(uri);
          return true;
        },
      );

      await const FitShareOperation().openPost(ref, _result.postUrl);

      expect(launched, [Uri.parse(_result.postUrl)]);
    });

    testWidgets("a failed launch is non-fatal", (tester) async {
      final ref = await pumpRef(tester, launcher: (uri) async => false);

      await const FitShareOperation().openPost(ref, _result.postUrl);
    });

    testWidgets("a throwing launcher is non-fatal", (tester) async {
      final ref = await pumpRef(
        tester,
        launcher: (uri) async => throw StateError("no browser available"),
      );

      await const FitShareOperation().openPost(ref, _result.postUrl);
    });
  });

  group("describeFitShareError", () {
    final l10n = AppLocalizationsZh();

    test("maps the data-not-ready exception", () {
      expect(
        describeFitShareError(l10n, const FitUploadNotReadyException()),
        l10n.fitShareErrorDataNotReady,
      );
    });

    test("maps the auth-required exception to the unauthorized message", () {
      expect(
        describeFitShareError(l10n, const PlatformAuthRequiredException()),
        l10n.fitShareErrorUnauthorized,
      );
    });

    test("maps upload exceptions by code", () {
      expect(
        describeFitShareError(l10n, const FitUploadException(FitUploadErrorCode.forbidden)),
        l10n.fitShareErrorForbidden,
      );
      expect(
        describeFitShareError(l10n, const FitUploadException(FitUploadErrorCode.network)),
        l10n.fitShareErrorNetwork,
      );
      expect(
        describeFitShareError(
          l10n,
          const FitUploadException(FitUploadErrorCode.unknownType, "type 12345"),
        ),
        l10n.fitShareErrorUnknownType(message: "type 12345"),
      );
    });

    test("joins the validation message and issues", () {
      const issues = [
        {"slot_type": "High", "index": 0},
      ];
      expect(
        describeFitShareError(
          l10n,
          const FitUploadException(FitUploadErrorCode.validationFailed, "bad fit", issues),
        ),
        l10n.fitShareErrorValidation(message: 'bad fit — [{"slot_type":"High","index":0}]'),
      );
    });

    test("falls back to the generic message for unknown errors", () {
      expect(describeFitShareError(l10n, StateError("boom")), l10n.fitShareErrorGeneric);
    });
  });

  group("fitShareEligibilityProvider", () {
    Future<bool> resolveEligibility({
      required bool signedIn,
      Acl? acl,
      bool aclPending = false,
    }) async {
      // A synchronous controller delivers the identity event straight to the
      // provider (Stream.value's emission does not reliably reach it in
      // tests); the zero delay lets the ACL future resolve afterwards.
      final identityController = StreamController<PlatformIdentity?>(sync: true);
      addTearDown(identityController.close);
      final container = ProviderContainer(
        overrides: [
          platformIdentityProvider.overrideWith((ref) => identityController.stream),
          accountAclProvider.overrideWith(
            (ref) => aclPending
                ? Completer<Acl>().future
                : Future.value(acl ?? aclForRoles(aclDefaultRoles.map((role) => role.name))),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(fitShareEligibilityProvider, (_, _) {});
      addTearDown(subscription.close);

      identityController.add(
        signedIn ? const PlatformIdentity(userId: "user-1", email: "user@example.com") : null,
      );
      await Future<void>.delayed(Duration.zero);
      return container.read(fitShareEligibilityProvider);
    }

    test("is false when signed out", () async {
      expect(await resolveEligibility(signedIn: false), isFalse);
    });

    test("is true for a signed-in account with the default roles (post:create)", () async {
      expect(await resolveEligibility(signedIn: true), isTrue);
    });

    test("is false for a signed-in account without post:create", () async {
      expect(await resolveEligibility(signedIn: true, acl: Acl(const {})), isFalse);
    });

    test("fails closed while the ACL is still loading", () async {
      expect(await resolveEligibility(signedIn: true, aclPending: true), isFalse);
    });
  });
}
