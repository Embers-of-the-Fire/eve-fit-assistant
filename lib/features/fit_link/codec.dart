import "dart:convert";
import "dart:typed_data";

import "package:archive/archive.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";

const String fitLinkPayloadPrefix = "EFA2:";
const int maxFitLinkEncodedPayloadChars = 7800;
const int maxFitLinkDecodedJsonBytes = 1024 * 1024;

final RegExp _base64UrlAlphabet = RegExp(r"^[A-Za-z0-9_-]*$");

enum FitLinkFormatErrorCode {
  invalidPrefix,
  payloadTooLarge,
  invalidBase64,
  invalidCompression,
  decodedPayloadTooLarge,
  invalidJson,
}

class FitLinkFormatException implements Exception {
  const FitLinkFormatException(this.code, {this.detail});

  final FitLinkFormatErrorCode code;
  final String? detail;

  @override
  String toString() => "FitLinkFormatException($code, detail: $detail)";
}

String encodeFitLinkPayload(FitStorage fit) {
  final compressed = encodeNativeFitBinary(fit);
  final encoded = base64UrlEncode(compressed).replaceAll("=", "");
  return "$fitLinkPayloadPrefix$encoded";
}

Uint8List decodeFitLinkPayload(String payload) {
  if (payload.length > maxFitLinkEncodedPayloadChars) {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.payloadTooLarge);
  }
  if (!payload.startsWith(fitLinkPayloadPrefix)) {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.invalidPrefix);
  }
  final encoded = payload.substring(fitLinkPayloadPrefix.length);
  if (encoded.isEmpty || !_base64UrlAlphabet.hasMatch(encoded)) {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.invalidBase64);
  }
  final Uint8List compressed;
  try {
    compressed = base64Url.decode(base64Url.normalize(encoded));
  } on Object {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.invalidBase64);
  }
  if (compressed.length < 2 || compressed[0] != 0x1f || compressed[1] != 0x8b) {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.invalidCompression);
  }
  final List<int> jsonBytes;
  try {
    jsonBytes = const GZipDecoder().decodeBytes(compressed);
  } on Object {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.invalidCompression);
  }
  if (jsonBytes.length > maxFitLinkDecodedJsonBytes) {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.decodedPayloadTooLarge);
  }
  return Uint8List.fromList(jsonBytes);
}
