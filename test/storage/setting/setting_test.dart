import "dart:convert";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_test/flutter_test.dart";
import "package:riverpod/riverpod.dart";

void main() {
  AppSetting testAppSetting(Locale locale) => AppSetting(
    locale: locale,
    enableDebugLog: false,
    shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
    showCheckoutImpactWarnings: true,
    typeListReturnBehavior: TypeListReturnBehavior.previousPage,
    developerMode: false,
  );

  test("localeProvider returns locale from overridden AppSettingService", () {
    final container = ProviderContainer(
      overrides: [appSettingServiceProvider.overrideWithValue(testAppSetting(Locale.zh))],
    );
    addTearDown(container.dispose);

    expect(container.read(localeProvider), Locale.zh);
  });

  test("fontScaleProvider returns default font scale from overridden AppSettingService", () {
    final container = ProviderContainer(
      overrides: [appSettingServiceProvider.overrideWithValue(testAppSetting(Locale.en))],
    );
    addTearDown(container.dispose);

    expect(container.read(fontScaleProvider), 1.0);
  });

  test("localeProvider falls back to en when appSetting is set to en", () {
    final container = ProviderContainer(
      overrides: [appSettingServiceProvider.overrideWithValue(testAppSetting(Locale.en))],
    );
    addTearDown(container.dispose);

    expect(container.read(localeProvider), Locale.en);
  });

  test("AiChatSetting parses legacy string model list", () {
    final setting = AiChatSetting.fromJson(
      jsonDecode(
            '{"baseUrl":"https://api.deepseek.com","model":"deepseek-v4-flash",'
            '"models":["deepseek-v4-flash","deepseek-v4-pro"]}',
          )
          as Map<String, dynamic>,
    );

    expect(setting.provider, ChatProvider.openAiCompatible);
    expect(setting.baseUrl, "https://api.deepseek.com");
    expect(setting.model, "deepseek-v4-flash");
    expect(setting.models, hasLength(2));
    expect(setting.models.first.id, "deepseek-v4-flash");
    expect(setting.models.first.ownedBy, isNull);
  });

  test("AiChatSetting roundtrips models with ownedBy", () {
    const setting = AiChatSetting(
      connections: {
        ChatProvider.deepSeek: AiChatConnection(
          models: [
            AiChatModel(id: "deepseek-v4-pro", ownedBy: "deepseek"),
            AiChatModel(id: "local-model"),
          ],
        ),
      },
    );

    final decoded = AiChatSetting.fromJson(
      jsonDecode(jsonEncode(setting.toJson())) as Map<String, dynamic>,
    );

    expect(decoded, setting);
    expect(
      decoded.connections[ChatProvider.deepSeek]!.models.first.ownedBy,
      "deepseek",
    );
  });

  test("AiChatSetting resolves provider defaults for blank connection", () {
    const setting = AiChatSetting(provider: ChatProvider.anthropic);

    expect(setting.baseUrl, ChatProvider.anthropic.defaultBaseUrl);
    expect(setting.model, ChatProvider.anthropic.defaultModel);
    expect(setting.models, isEmpty);
  });

  test("AiChatSetting withConnection keeps other providers untouched", () {
    const initial = AiChatSetting(
      provider: ChatProvider.deepSeek,
      connections: {
        ChatProvider.openAiCompatible: AiChatConnection(baseUrl: "http://localhost:11434/v1"),
      },
    );

    final updated = initial.withConnection(
      ChatProvider.deepSeek,
      (connection) => connection.copyWith(model: "deepseek-chat"),
    );

    expect(updated.model, "deepseek-chat");
    expect(
      updated.connections[ChatProvider.openAiCompatible]!.baseUrl,
      "http://localhost:11434/v1",
    );
  });

  test("AiChatSetting skips unknown provider keys in connections", () {
    final setting = AiChatSetting.fromJson(
      jsonDecode(
            '{"provider":"anthropic","connections":{"anthropic":{"model":"claude"},'
            '"unknownProvider":{"model":"x"}}}',
          )
          as Map<String, dynamic>,
    );

    expect(setting.provider, ChatProvider.anthropic);
    expect(setting.connections.keys, [ChatProvider.anthropic]);
    expect(setting.model, "claude");
  });
}
