import "package:eve_fit_assistant/storage/chat/models.dart";

const int maxDialogExportLength = 50000;

String exportConversationMarkdown(ChatConversation conversation) {
  final buffer = StringBuffer();
  if (conversation.model.isNotEmpty) {
    buffer
      ..writeln("> Model: `${conversation.model}`")
      ..writeln();
  }
  for (final message in conversation.messages) {
    switch (message.role) {
      case ChatMessageRole.user:
        buffer
          ..writeln("**User:**")
          ..writeln(message.content);
      case ChatMessageRole.assistant:
        buffer.writeln("**Assistant:**");
        if (message.segments.isEmpty) {
          buffer.writeln(message.content);
        } else {
          for (final segment in message.segments) {
            switch (segment) {
              case ChatTextSegment(:final text):
                buffer.writeln(text);
              case ChatToolCallSegment(:final name, :final args, :final result):
                buffer.writeln("> Tool call: `$name`");
                if (args.isNotEmpty) buffer.writeln("> Args: `$args`");
                if (result.isNotEmpty) buffer.writeln("> Result: $result");
            }
          }
        }
    }
    buffer.writeln();
  }
  var output = buffer.toString().trim();
  if (output.length > maxDialogExportLength) {
    output = "${output.substring(0, maxDialogExportLength)}\n\n*(truncated)*";
  }
  return output;
}
