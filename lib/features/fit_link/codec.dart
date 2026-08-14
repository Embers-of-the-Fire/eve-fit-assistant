import "dart:convert";
import "dart:math";
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
  final output = _BoundedInflateOutputStream(maxFitLinkDecodedJsonBytes);
  try {
    const GZipDecoderWeb().decodeStream(InputMemoryStream(compressed), output);
  } on _FitLinkDecodedSizeExceededException {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.decodedPayloadTooLarge);
  } on Object {
    throw const FitLinkFormatException(FitLinkFormatErrorCode.invalidCompression);
  }
  return output.toBytes();
}

class _FitLinkDecodedSizeExceededException implements Exception {
  const _FitLinkDecodedSizeExceededException();
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
      throw const _FitLinkDecodedSizeExceededException();
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
