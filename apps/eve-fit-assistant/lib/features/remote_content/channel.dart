import "package:flutter/foundation.dart";

enum Channel {
  testing("testing"),
  stable("stable");

  const Channel(this.value);

  final String value;

  static const defaultChannel = kDebugMode ? Channel.testing : Channel.stable;

  static Channel? tryParse(String value) {
    for (final channel in Channel.values) {
      if (channel.value == value) {
        return channel;
      }
    }
    return null;
  }

  static Channel parse(String value) {
    final channel = tryParse(value);
    if (channel == null) {
      throw ArgumentError.value(value, "value", "Unknown channel");
    }
    return channel;
  }
}
