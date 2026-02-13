enum TaskType { oneTime, daily, weekly }

class Task {
  final String id;
  final String title;
  bool isCompleted;
  final TaskType type;
  final int? weekNumber; // For roadmap structure (e.g., Week 1, Week 2)

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.type,
    this.weekNumber,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'type': type.name,
    'weekNumber': weekNumber,
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      isCompleted: json['isCompleted'] == true,
      type: _taskTypeFromString((json['type'] ?? '').toString()),
      weekNumber: json['weekNumber'] is int
          ? json['weekNumber'] as int
          : int.tryParse(json['weekNumber']?.toString() ?? ''),
    );
  }

  static TaskType _taskTypeFromString(String value) {
    switch (value) {
      case 'oneTime':
      case 'one_time':
      case 'one-time':
      case 'onetime':
        return TaskType.oneTime;
      case 'weekly':
        return TaskType.weekly;
      case 'daily':
      default:
        return TaskType.daily;
    }
  }
}
