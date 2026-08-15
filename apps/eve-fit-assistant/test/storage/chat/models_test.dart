import "dart:convert";

import "package:eve_fit_assistant/storage/chat/models.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("ChatConversation JSON roundtrip preserves all fields", () {
    final conversation = ChatConversation(
      id: "conv-1",
      title: "Test conversation",
      createdAt: 1700000000000,
      updatedAt: 1700000001000,
      model: "gpt-4o-mini",
      messages: const [
        ChatMessage(
          id: "m-1",
          role: ChatMessageRole.user,
          content: "Hello",
          timestamp: 1700000000000,
        ),
        ChatMessage(
          id: "m-2",
          role: ChatMessageRole.assistant,
          content: "Hi there",
          timestamp: 1700000000500,
        ),
      ],
    );

    final decoded = ChatConversation.fromJson(
      jsonDecode(jsonEncode(conversation.toJson())) as Map<String, dynamic>,
    );

    expect(decoded, conversation);
    expect(decoded.messages, hasLength(2));
    expect(decoded.messages.first.role, ChatMessageRole.user);
    expect(decoded.messages.last.role, ChatMessageRole.assistant);
  });

  test("ChatConversation defaults tolerate missing optional fields", () {
    final decoded = ChatConversation.fromJson(
      jsonDecode('{"id":"c","title":"t","createdAt":1,"updatedAt":2}') as Map<String, dynamic>,
    );
    expect(decoded.model, "");
    expect(decoded.messages, isEmpty);
  });

  test("ChatSegment toolCall roundtrip preserves the tool result", () {
    const segment = ChatSegment.toolCall(
      id: "call-1",
      name: "search_manual",
      args: '{"keywords":["fit"]}',
      done: true,
      result: '{"hits":[]}',
    );
    final decoded = ChatSegment.fromJson(
      jsonDecode(jsonEncode(segment.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, segment);
  });

  test("ChatSegment toolCall tolerates legacy payloads without a result", () {
    final decoded = ChatSegment.fromJson(
      jsonDecode(
        '{"runtimeType":"toolCall","id":"call-1","name":"search_manual"}',
      ) as Map<String, dynamic>,
    );
    expect(
      decoded,
      const ChatSegment.toolCall(id: "call-1", name: "search_manual"),
    );
  });
}
