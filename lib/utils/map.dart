part of 'utils.dart';

class ReadonlyMap<K, V> {
  final Map<K, V> _map;

  const ReadonlyMap(this._map);

  V? operator [](K key) => _map[key];

  Iterable<K> get keys => _map.keys;

  Iterable<V> get values => _map.values;

  Iterable<MapEntry<K, V>> get entries => _map.entries;

  bool containsKey(K key) => _map.containsKey(key);

  Iterable<(K, V)> get tupleEntries => entries.map((e) => (e.key, e.value));

  int get length => _map.length;

  Map<String, dynamic> toJson() => _map as Map<String, dynamic>;

  Map<RK, RV> map<RK, RV>(MapEntry<RK, RV> Function(K, V) f) => _map.map(f);
}

class MapView<K, V> {
  final Map<K, V> _map;
  final ReadonlyMap<K, V> _read;

  ReadonlyMap<K, V> get read => _read;

  Map<K, V> get write => _map;

  Iterable<MapEntry<K, V>> get entries => _map.entries;

  Iterable<(K, V)> get tupleEntries => entries.map((e) => (e.key, e.value));

  MapView(this._map) : _read = ReadonlyMap(_map);
}

extension MapExt<K, V> on Map<K, V> {
  MapView<K, V> get view => MapView(this);

  ReadonlyMap<K, V> get readonly => ReadonlyMap(this);

  Iterable<(K, V)> get tupleEntries => entries.map((e) => (e.key, e.value));
}

class MapEqual<K, V> {
  final Map<K, V> _map;

  Map<K, V> get map => _map;

  const MapEqual(this._map);

  @override
  bool operator ==(Object other) {
    if (other is MapEqual<K, V>) {
      return const MapEquality().equals(_map, other._map);
    }
    return false;
  }

  @override
  int get hashCode => const MapEquality().hash(_map);
}
