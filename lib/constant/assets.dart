import "package:flutter/services.dart";
import "package:flutter/widgets.dart";

part "assets.g.dart";

class BundleKey {
  const BundleKey(this.key);

  final String key;

  Future<ByteData> get asset => rootBundle.load(key);
}
