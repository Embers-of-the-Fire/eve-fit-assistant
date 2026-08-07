import "package:freezed_annotation/freezed_annotation.dart";

part "models.freezed.dart";
part "models.g.dart";

enum ChatMessageRole { user, assistant }

/// One ordered piece of an assistant reply. Text separated by tool calls is
/// split into distinct segments so the UI can render tool calls differently.
@freezed
sealed class ChatSegment with _$ChatSegment {
  const factory ChatSegment.text({required String text}) = ChatTextSegment;

  const factory ChatSegment.toolCall({
    required String id,
    required String name,
    @Default("") String args,
    @Default(false) bool done,
  }) = ChatToolCallSegment;

  factory ChatSegment.fromJson(Map<String, dynamic> json) => _$ChatSegmentFromJson(json);
}

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required ChatMessageRole role,
    required String content,
    required int timestamp,
    @Default([]) List<ChatSegment> segments,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
}

@freezed
abstract class ChatConversation with _$ChatConversation {
  const factory ChatConversation({
    required String id,
    required String title,
    required int createdAt,
    required int updatedAt,
    @Default("") String model,
    @Default([]) List<ChatMessage> messages,
  }) = _ChatConversation;

  factory ChatConversation.fromJson(Map<String, dynamic> json) => _$ChatConversationFromJson(json);
}
