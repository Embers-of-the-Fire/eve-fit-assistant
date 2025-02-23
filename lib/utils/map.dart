part of 'utils.dart';

class ReadonlyMap<K, V> {
  final Map<K, V> _map;

  const ReadonlyMap(this._map);

  V? operator [](K key) => _map[key];

  Iterable<K> get keys => _map.keys;

  Iterable<V> get values => _map.values;

  Iterable<MapEntry<K, V>> get entries => _map.entries;

  bool containsKey(K key) => _map.containsKey(key);

  int get length => _map.length;

  Map<String, dynamic> toJson() => _map as Map<String, dynamic>;
}

class MapView<K, V> {
  final Map<K, V> _map;
  final ReadonlyMap<K, V> _read;

  ReadonlyMap<K, V> get read => _read;

  Map<K, V> get write => _map;

  MapView(this._map) : _read = ReadonlyMap(_map);
}

extension MapExt<K, V> on Map<K, V> {
  MapView<K, V> get view => MapView(this);

  ReadonlyMap<K, V> get readonly => ReadonlyMap(this);
}
