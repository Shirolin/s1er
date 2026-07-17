/// Assigns sequential [data-image-index] values within one post floor.
class PostImageIndexCounter {
  int _next = 0;

  int assign() => _next++;

  int get assignedCount => _next;

  /// Call at the start of each top-level post render so rebuilds do not
  /// accumulate indices across frames (false "还有 N 张图片" chips).
  void reset() => _next = 0;
}
