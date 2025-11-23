/// Extension methods for List
extension FirstWhereOrNull<T> on List<T> {
  /// Returns the first element that satisfies the given predicate, or null if no element satisfies it.
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
