class Memory {
  final String id;
  final String title;
  final String description;
  final String date;
  final String location;
  final List<String> people;
  final String? imageUrl;
  final String? voiceMessage;
  final List<String> tags;

  const Memory({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.people,
    this.imageUrl,
    this.voiceMessage,
    this.tags = const [],
  });

  factory Memory.fromJson(
      Map<String, dynamic> json,
      ) {
    return Memory(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      date: json['date'] as String? ?? '',
      location: json['location'] as String? ?? '',
      people: (json['people'] as List?)
          ?.map((item) => item.toString())
          .toList() ??
          [],
      imageUrl: json['imageUrl'] as String?,
      voiceMessage: json['voiceMessage'] as String?,
      tags: (json['tags'] as List?)
          ?.map((item) => item.toString())
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'location': location,
      'people': people,
      'imageUrl': imageUrl,
      'voiceMessage': voiceMessage,
      'tags': tags,
    };
  }
}