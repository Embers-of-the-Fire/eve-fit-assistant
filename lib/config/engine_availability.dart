/// Whether the native fit engine bridge is available for this session.
///
/// Captured once at startup (see `init.dart`): native builds always have it,
/// while web builds only do when the origin is cross-origin isolated and the
/// wasm bundle is present, since the threaded engine needs SharedArrayBuffer.
///
/// When false the engine must never be touched — the FRB bridge was never
/// initialized, so any call would throw — and callers degrade gracefully
/// (fits still load, emulated stats are unavailable).
abstract final class NativeEngineAvailability {
  static bool _available = false;

  static bool get available => _available;

  /// Marks the native engine as available (or not) for the current session.
  ///
  /// Called once from startup after the bridge init attempt.
  static void setAvailable({required bool value}) => _available = value;
}
