import "package:eve_fit_assistant/features/chat/model_list.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  tearDown(() => debugModelListLastFetchTime = null);

  test("no cooldown before the first fetch", () {
    expect(modelListFetchCooldownRemaining(), Duration.zero);
  });

  test("cooldown counts down from the last fetch", () {
    final fetchedAt = DateTime(2026, 8, 7, 12);
    debugModelListLastFetchTime = fetchedAt;

    expect(
      modelListFetchCooldownRemaining(fetchedAt.add(const Duration(seconds: 10))),
      const Duration(seconds: 20),
    );
    expect(
      modelListFetchCooldownRemaining(fetchedAt.add(chatModelListFetchCooldown)),
      Duration.zero,
    );
    expect(
      modelListFetchCooldownRemaining(
        fetchedAt.add(chatModelListFetchCooldown + const Duration(minutes: 1)),
      ),
      Duration.zero,
    );
  });
}
