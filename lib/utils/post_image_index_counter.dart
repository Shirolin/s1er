/// Assigns sequential [data-image-index] values within one post floor.
class PostImageIndexCounter {
  int _next = 0;

  int assign() => _next++;

  int get assignedCount => _next;
}
