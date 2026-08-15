import "dart:async";
import "dart:typed_data";

import "package:eve_fit_assistant/data/proto/categories.pb.dart" as pb_categories;
import "package:eve_fit_assistant/data/proto/collections.pb.dart";
import "package:eve_fit_assistant/data/proto/dogma_attributes.pb.dart" as pb_attrs;
import "package:eve_fit_assistant/data/proto/dogma_units.pb.dart" as pb_units;
import "package:eve_fit_assistant/data/proto/dynamic.pb.dart" as pb_dynamic;
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/data/proto/groups.pb.dart" as pb_groups;
import "package:eve_fit_assistant/data/proto/market_groups.pb.dart" as pb_market;
import "package:eve_fit_assistant/data/proto/meta_groups.pb.dart" as pb_meta;
import "package:eve_fit_assistant/data/proto/type_materials.pb.dart" as pb_materials;
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:protobuf/protobuf.dart";

/// Thrown by the chunked decoders when their [ChunkedDecodeOptions.isCancelled]
/// callback reports that the result is no longer needed.
class ChunkedDecodeCancelled implements Exception {
  const ChunkedDecodeCancelled();

  @override
  String toString() => "ChunkedDecodeCancelled";
}

/// Controls the cooperative pacing of the chunked decoders.
///
/// The web platform has no isolates, so large protobuf payloads must be
/// decoded on the main event loop. Decoding entry by entry and yielding to
/// the event loop between batches keeps the UI responsive at the cost of a
/// slightly longer total decode time.
class ChunkedDecodeOptions {
  const ChunkedDecodeOptions({
    this.isCancelled,
    this.yieldEvery = const Duration(milliseconds: 32),
  });

  /// Returns `true` when the decode result is no longer needed. The decoder
  /// then aborts with [ChunkedDecodeCancelled].
  final bool Function()? isCancelled;

  /// How long the decoder may run before yielding to the event loop.
  final Duration yieldEvery;
}

/// Decodes a `collections.Collection` message cooperatively.
///
/// Produces exactly the same [Collection] as `Collection.fromBuffer`, but
/// walks the wire format entry by entry and yields to the event loop
/// periodically so the main thread is never blocked for long. This matters on
/// web, where there is no background isolate for the decode.
Future<Collection> decodeCollectionChunked(
  Uint8List raw, [
  ChunkedDecodeOptions options = const ChunkedDecodeOptions(),
]) async {
  final collection = Collection();
  final reader = CodedBufferReader(raw);
  final pacemaker = ChunkedPacemaker(options);

  while (!reader.isAtEnd()) {
    final tag = reader.readTag();
    if (tag == 0) break;
    final wireType = getTagWireType(tag);
    if (wireType != WIRETYPE_LENGTH_DELIMITED) {
      reader.skipField(tag);
      await pacemaker.tick();
      continue;
    }

    switch (getTagFieldNumber(tag)) {
      // Map fields of `Collection` (see data/schema/collections.proto).
      case 1:
        _mergeUint32MessageEntry(reader, collection.types, pb_types.Type.fromBuffer);
      case 2:
        _mergeUint32MessageEntry(
          reader,
          collection.typeMaterials,
          pb_materials.TypeMaterial.fromBuffer,
        );
      case 3:
        _mergeUint32MessageEntry(reader, collection.categories, pb_categories.Category.fromBuffer);
      case 4:
        _mergeUint32MessageEntry(reader, collection.groups, pb_groups.Group.fromBuffer);
      case 5:
        _mergeUint32MessageEntry(reader, collection.marketGroups, pb_market.MarketGroup.fromBuffer);
      case 6:
        _mergeUint32MessageEntry(reader, collection.metaGroups, pb_meta.MetaGroup.fromBuffer);
      case 7:
        _mergeUint32MessageEntry(reader, collection.dogmaUnits, pb_units.DogmaUnit.fromBuffer);
      case 8:
        _mergeUint32MessageEntry(
          reader,
          collection.dogmaAttributes,
          pb_attrs.DogmaAttribute.fromBuffer,
        );
      case 9:
        _mergeUint32MessageEntry(reader, collection.ships, Ship.fromBuffer);
      case 10:
        _mergeUint32MessageEntry(reader, collection.subsystems, Subsystem.fromBuffer);
      case 11:
        // `slots` is a required sub-message, not a map. An unset message
        // getter returns a read-only default instance, so merge into a fresh
        // (or the already stored) message and assign it back.
        final slots = collection.hasSlots() ? collection.slots : Slots();
        reader.readMessage(slots, ExtensionRegistry.EMPTY);
        collection.slots = slots;
      case 12:
        _mergeUint32MessageEntry(
          reader,
          collection.dynamicMutators,
          pb_dynamic.DynamicMutator.fromBuffer,
        );
      case 13:
        _mergeUint32MessageEntry(
          reader,
          collection.dynamicTypeOptions,
          pb_dynamic.DynamicTypeOptions.fromBuffer,
        );
      case 14:
        _mergeStringMessageEntry(
          reader,
          collection.skillProfiles,
          Collection_SkillProfile.fromBuffer,
        );
      case 15:
        _mergeUint32MessageEntry(reader, collection.implantSets, ImplantSet.fromBuffer);
      default:
        // Unknown field: skip it the same way `mergeFromBuffer` would.
        reader.skipField(tag);
    }
    await pacemaker.tick();
  }

  return collection;
}

/// One decoded `map<K, V>` entry: the key plus the raw value bytes (a message
/// payload or UTF-8 string, depending on the map's value type).
class _MapEntry {
  const _MapEntry(this.key, this.messageView);

  final Object key;
  final Uint8List? messageView;
}

/// Reads a single length-delimited map entry and decodes its envelope
/// (field 1 = key, field 2 = value) without decoding the value itself.
_MapEntry _readEntry(CodedBufferReader reader) {
  final entryBytes = reader.readBytesAsView();
  final entryReader = CodedBufferReader(entryBytes);

  Object key = 0;
  Uint8List? messageView;

  while (!entryReader.isAtEnd()) {
    final entryTag = entryReader.readTag();
    if (entryTag == 0) break;
    switch (getTagFieldNumber(entryTag)) {
      case 1:
        key = getTagWireType(entryTag) == WIRETYPE_LENGTH_DELIMITED
            ? entryReader.readString()
            : entryReader.readUint32();
      case 2:
        if (getTagWireType(entryTag) == WIRETYPE_LENGTH_DELIMITED) {
          messageView = entryReader.readBytesAsView();
        } else {
          entryReader.skipField(entryTag);
        }
      default:
        entryReader.skipField(entryTag);
    }
  }

  return _MapEntry(key, messageView);
}

void _mergeUint32MessageEntry<V extends GeneratedMessage>(
  CodedBufferReader reader,
  Map<int, V> target,
  V Function(List<int>) decodeValue,
) {
  final entry = _readEntry(reader);
  // A missing value field decodes as the default instance, matching
  // `mergeFromBuffer` semantics.
  target[entry.key as int] = decodeValue(entry.messageView ?? Uint8List(0));
}

void _mergeStringMessageEntry<V extends GeneratedMessage>(
  CodedBufferReader reader,
  Map<String, V> target,
  V Function(List<int>) decodeValue,
) {
  final entry = _readEntry(reader);
  target[entry.key as String] = decodeValue(entry.messageView ?? Uint8List(0));
}

/// Paces a decode loop: runs the stopwatch down, then yields to the event
/// loop (a macrotask, so the browser may render between chunks) and checks
/// for cancellation.
class ChunkedPacemaker {
  ChunkedPacemaker(this._options) : _stopwatch = Stopwatch()..start();

  final ChunkedDecodeOptions _options;
  final Stopwatch _stopwatch;

  Future<void> tick() async {
    if (_stopwatch.elapsed < _options.yieldEvery) return;
    _stopwatch.reset();
    final isCancelled = _options.isCancelled;
    if (isCancelled != null && isCancelled()) {
      throw const ChunkedDecodeCancelled();
    }
    await Future<void>.delayed(Duration.zero);
  }
}
