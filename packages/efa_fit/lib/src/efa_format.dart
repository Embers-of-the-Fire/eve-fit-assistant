import "dart:convert";
import "dart:math";
import "dart:typed_data";

import "package:archive/archive.dart";

const String efaFitLinkPayloadPrefix = "EFA2:";
const int maxEfaFitLinkEncodedPayloadChars = 7800;
const int maxEfaFitTextEncodedPayloadChars = 4 * 1024 * 1024;
const int maxEfaFitLinkDecodedJsonBytes = 1024 * 1024;
const int legacyEfaFitFormatVersion = 1;
const int currentEfaFitFormatVersion = 2;

final RegExp _textPrefixPattern = RegExp(r"^EFA(?:(\d+))?:");
final RegExp _base64UrlAlphabet = RegExp(r"^[A-Za-z0-9_-]*$");

enum EfaFitFormatErrorCode {
  invalidPrefix,
  unsupportedVersion,
  payloadTooLarge,
  invalidBase64,
  invalidCompression,
  decodedPayloadTooLarge,
  invalidJson,
}

class EfaFitFormatException implements Exception {
  const EfaFitFormatException(this.code, {this.detail});

  final EfaFitFormatErrorCode code;
  final String? detail;

  @override
  String toString() => "EfaFitFormatException($code, detail: $detail)";
}

class EfaFitTextPayload {
  const EfaFitTextPayload({required this.prefixVersion, required this.json});

  final int prefixVersion;
  final Map<String, dynamic> json;
}

Uint8List encodeEfaFitBinary(Map<String, dynamic> payload) {
  final jsonText = jsonEncode(payload);
  return Uint8List.fromList(const GZipEncoder().encodeBytes(utf8.encode(jsonText), level: 9));
}

Map<String, dynamic> decodeEfaFitBinary(Uint8List binary) =>
    _decodeJsonMap(_inflateBounded(binary));

String encodeEfaFitLinkPayload(Map<String, dynamic> payload) {
  final compressed = encodeEfaFitBinary(payload);
  final encoded = base64UrlEncode(compressed).replaceAll("=", "");
  return "$efaFitLinkPayloadPrefix$encoded";
}

Map<String, dynamic> decodeEfaFitLinkPayload(String payload) {
  if (payload.length > maxEfaFitLinkEncodedPayloadChars) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.payloadTooLarge);
  }
  if (!payload.startsWith(efaFitLinkPayloadPrefix)) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidPrefix);
  }
  final encoded = payload.substring(efaFitLinkPayloadPrefix.length);
  if (encoded.isEmpty || !_base64UrlAlphabet.hasMatch(encoded)) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidBase64);
  }
  final Uint8List compressed;
  try {
    compressed = base64Url.decode(base64Url.normalize(encoded));
  } on Object {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidBase64);
  }
  return _decodeJsonMap(_inflateBounded(compressed));
}

String encodeEfaFitTextPayload(
  Map<String, dynamic> payload, {
  int version = currentEfaFitFormatVersion,
}) => "EFA$version:${base64Encode(encodeEfaFitBinary(payload))}";

EfaFitTextPayload decodeEfaFitTextPayload(String text) {
  final trimmed = text.trim();
  final prefixMatch = _textPrefixPattern.matchAsPrefix(trimmed);
  if (prefixMatch == null) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.unsupportedVersion);
  }
  final explicitVersion = prefixMatch.group(1);
  final prefixVersion = explicitVersion == null
      ? legacyEfaFitFormatVersion
      : int.tryParse(explicitVersion);
  if (prefixVersion == null ||
      prefixVersion < legacyEfaFitFormatVersion ||
      prefixVersion > currentEfaFitFormatVersion) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.unsupportedVersion);
  }

  final encoded = trimmed.substring(prefixMatch.end).trim();
  if (encoded.length > maxEfaFitTextEncodedPayloadChars) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.payloadTooLarge);
  }
  final Uint8List compressed;
  try {
    compressed = base64Decode(encoded);
  } on Object {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidBase64);
  }
  return EfaFitTextPayload(
    prefixVersion: prefixVersion,
    json: _decodeJsonMap(_inflateBounded(compressed)),
  );
}

Map<String, dynamic> _decodeJsonMap(Uint8List bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on Object {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidJson);
  }
  if (decoded is! Map<String, dynamic>) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidJson);
  }
  return decoded;
}

Uint8List _inflateBounded(Uint8List compressed) {
  if (compressed.length < 2 || compressed[0] != 0x1f || compressed[1] != 0x8b) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidCompression);
  }
  final output = _BoundedInflateOutputStream(maxEfaFitLinkDecodedJsonBytes);
  try {
    const GZipDecoderWeb().decodeStream(InputMemoryStream(compressed), output);
  } on _EfaFitDecodedSizeExceededException {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.decodedPayloadTooLarge);
  } on Object {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidCompression);
  }
  return output.toBytes();
}

class _EfaFitDecodedSizeExceededException implements Exception {
  const _EfaFitDecodedSizeExceededException();
}

class _BoundedInflateOutputStream extends OutputStream {
  _BoundedInflateOutputStream(this._limit)
    : _buffer = Uint8List(min(_initialBufferSize, _limit)),
      super(byteOrder: ByteOrder.littleEndian);

  static const int _initialBufferSize = 0x8000;

  final int _limit;
  Uint8List _buffer;

  @override
  int length = 0;

  @override
  void clear() {
    length = 0;
  }

  @override
  void flush() {}

  void _reserve(int count) {
    final required = length + count;
    if (required > _limit) {
      throw const _EfaFitDecodedSizeExceededException();
    }
    if (required <= _buffer.length) {
      return;
    }
    var grown = _buffer.length * 2;
    while (grown < required) {
      grown *= 2;
    }
    _buffer = Uint8List(min(grown, _limit))..setRange(0, length, _buffer);
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    _buffer[length++] = value;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    _reserve(count);
    _buffer.setRange(this.length, this.length + count, bytes);
    this.length += count;
  }

  @override
  void writeStream(InputStream stream) {
    writeBytes(stream.toUint8List());
  }

  @override
  Uint8List subset(int start, [int? end]) {
    final from = start < 0 ? length + start : start;
    var to = end ?? length;
    if (to < 0) {
      to += length;
    }
    return Uint8List.view(_buffer.buffer, _buffer.offsetInBytes + from, to - from);
  }

  Uint8List toBytes() => Uint8List.view(_buffer.buffer, _buffer.offsetInBytes, length);
}
