import "dart:io";

import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/fit_io/share_dialog.dart";
import "package:eve_fit_assistant/features/fit_io/share_operation.dart";
import "package:eve_fit_assistant/features/fit_io/snapshot_upload_api.dart";
import "package:eve_fit_assistant/features/fit_io/upload_request.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

import "../../test_helpers.dart";

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

const _postUrl = "https://platform.efa-tech.dev/post/11111111-1111-4111-8111-111111111111";

void main() {
  final clipboardWrites = <String>[];
  final launchedUrls = <Uri>[];

  // Failure paths log through the global logger; initialize it once (it is
  // `late final`) with a throwaway file target.
  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa-share-dialog-test").path,
      enableDebugLog: false,
    );
  });

  setUp(() {
    clipboardWrites.clear();
    launchedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == "Clipboard.setData") {
          clipboardWrites.add((call.arguments as Map)["text"] as String);
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Widget buildDialog(FitStorage fit, {FitSnapshotUploadFn? uploadFn}) => ProviderScope(
    overrides: [
      appSettingServiceProvider.overrideWithValue(
        const AppSetting(
          locale: Locale.zh,
          enableDebugLog: false,
          shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
          showCheckoutImpactWarnings: true,
          typeListReturnBehavior: TypeListReturnBehavior.previousPage,
          developerMode: false,
        ),
      ),
      fitSnapshotUploadFnProvider.overrideWithValue(
        uploadFn ??
            (ref, {required fitId, required fit}) async => const FitPostSubmitResult(
              postId: "11111111-1111-4111-8111-111111111111",
              fitHash: "0123456789abcdef0123456789abcdef",
              alreadyExisted: false,
              postUrl: _postUrl,
              origin: platformApiProductionOrigin,
            ),
      ),
      fitShareUrlLauncherProvider.overrideWithValue((uri) async {
        launchedUrls.add(uri);
        return true;
      }),
    ],
    child: testApp(
      Scaffold(body: FitShareDialog(fitId: fit.metadata.fitId, initialFit: fit)),
    ),
  );

  testWidgets("renders the fit name and the share description", (tester) async {
    await tester.pumpWidget(buildDialog(_makeFit()));
    await tester.pumpAndSettle();

    expect(find.text("分享配置"), findsOneWidget);
    expect(find.text("Test Fit"), findsOneWidget);
    expect(find.text("将该配置发布到平台，并在浏览器中打开帖子页面。"), findsOneWidget);
    expect(find.text("分享"), findsOneWidget);
  });

  testWidgets("share redirects to the post page and offers copy/open actions", (tester) async {
    await tester.pumpWidget(buildDialog(_makeFit()));
    await tester.pumpAndSettle();

    await tester.tap(find.text("分享"));
    await tester.pumpAndSettle();

    // Success view; the share operation already redirected to the
    // worker-provided post page URL.
    expect(find.text("配置已发布至平台，帖子页面已在浏览器中打开。"), findsOneWidget);
    expect(launchedUrls, [Uri.parse(_postUrl)]);

    await tester.tap(find.text("查看帖子"));
    await tester.pumpAndSettle();
    expect(launchedUrls, [Uri.parse(_postUrl), Uri.parse(_postUrl)]);

    await tester.tap(find.text("复制链接"));
    await tester.pumpAndSettle();
    expect(clipboardWrites, [_postUrl]);
  });

  testWidgets("reports an existing fit without a second upload", (tester) async {
    await tester.pumpWidget(
      buildDialog(
        _makeFit(),
        uploadFn: (ref, {required fitId, required fit}) async => const FitPostSubmitResult(
          postId: "11111111-1111-4111-8111-111111111111",
          fitHash: "0123456789abcdef0123456789abcdef",
          alreadyExisted: true,
          postUrl: _postUrl,
          origin: platformApiProductionOrigin,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("分享"));
    await tester.pumpAndSettle();

    expect(find.text("平台已存在相同配置，帖子页面已在浏览器中打开。"), findsOneWidget);
  });

  testWidgets("shows the mapped error inline when the platform rejects the fit", (tester) async {
    await tester.pumpWidget(
      buildDialog(
        _makeFit(),
        uploadFn: (ref, {required fitId, required fit}) async =>
            throw const FitUploadException(FitUploadErrorCode.forbidden),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("分享"));
    await tester.pumpAndSettle();

    expect(find.text("当前账号无权向平台发布配置。"), findsOneWidget);
    expect(launchedUrls, isEmpty);
    // The dialog stays on the ready view so the user can retry.
    expect(find.text("分享"), findsOneWidget);
  });
}
