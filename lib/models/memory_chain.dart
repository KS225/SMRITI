class MemoryChain {
  final String id;
  final String title;
  final String description;
  final List<String> memoryIds;
  final String category;

  const MemoryChain({
    required this.id,
    required this.title,
    required this.description,
    required this.memoryIds,
    this.category = 'Life Story',
  });

  MemoryChain copyWith({
    String? title,
    String? description,
    List<String>? memoryIds,
    String? category,
  }) {
    return MemoryChain(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      memoryIds: memoryIds ?? this.memoryIds,
      category: category ?? this.category,
    );
  }

  factory MemoryChain.fromJson(Map<String, dynamic> json) {
    return MemoryChain(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Memory Chain',
      description: json['description'] as String? ?? '',
      memoryIds: (json['memoryIds'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
      category: json['category'] as String? ?? 'Life Story',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'memoryIds': memoryIds,
      'category': category,
    };
  }
}
