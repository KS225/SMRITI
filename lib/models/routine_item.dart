class RoutineItem {
  final String id;
  final String title;
  final String description;
  final String time;
  final String category;
  final bool completed;

  const RoutineItem({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.category,
    this.completed = false,
  });
}