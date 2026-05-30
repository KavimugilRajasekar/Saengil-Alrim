class BirthdayTask {
  final String id;
  final String title;
  bool isCompleted;

  BirthdayTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  factory BirthdayTask.fromJson(Map<String, dynamic> json) {
    return BirthdayTask(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  BirthdayTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return BirthdayTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
