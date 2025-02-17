extension ListExt<T> on List<T> {
  void fillAll(T value) {
    fillRange(0, length, value);
  }
}
