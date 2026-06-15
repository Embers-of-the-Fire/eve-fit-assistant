import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "checkout_index.freezed.dart";
part "checkout_index.g.dart";

@JsonEnum()
enum CheckoutState { installed, historical, known }

@freezed
abstract class CheckoutIndex with _$CheckoutIndex {
  const factory CheckoutIndex({
    required int schemaVersion,
    @Default(IMap<String, CheckoutEntry>.empty()) IMap<String, CheckoutEntry> entries,
  }) = _CheckoutIndex;

  factory CheckoutIndex.fromJson(Map<String, dynamic> json) => _$CheckoutIndexFromJson(json);
}

@freezed
abstract class CheckoutEntry with _$CheckoutEntry {
  const factory CheckoutEntry({required CheckoutState state}) = _CheckoutEntry;

  factory CheckoutEntry.fromJson(Map<String, dynamic> json) => _$CheckoutEntryFromJson(json);
}
