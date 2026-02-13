import 'package:flutter/material.dart';
import 'package:gola_goal_guidance_app/models/task.dart';

enum GoalStatus { active, completed, archived }

class Goal {
  final String id;
  final String title;
  final String category;
  double progress;
  final GoalStatus status;
  final IconData? iconData;

  // New Fields
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final List<Task> tasks;

  Goal({
    required this.id,
    required this.title,
    required this.category,
    this.progress = 0.0,
    this.status = GoalStatus.active,
    this.iconData,
    this.startDate,
    this.endDate,
    this.notes,
    this.tasks = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'progress': progress,
    'status': status.name,
    'iconData': iconData == null
        ? null
        : {
            'codePoint': iconData!.codePoint,
            'fontFamily': iconData!.fontFamily,
            'fontPackage': iconData!.fontPackage,
          },
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'notes': notes,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };

  factory Goal.fromJson(Map<String, dynamic> json) {
    final iconMap = json['iconData'] as Map<String, dynamic>?;
    IconData? icon;
    if (iconMap != null && iconMap['codePoint'] != null) {
      icon = IconData(
        iconMap['codePoint'] as int,
        fontFamily: iconMap['fontFamily'] as String?,
        fontPackage: iconMap['fontPackage'] as String?,
      );
    }

    final tasksJson = (json['tasks'] as List?) ?? [];
    return Goal(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? 'General').toString(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: _goalStatusFromString((json['status'] ?? '').toString()),
      iconData: icon,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      notes: json['notes']?.toString(),
      tasks: tasksJson
          .whereType<Map<String, dynamic>>()
          .map(Task.fromJson)
          .toList(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static GoalStatus _goalStatusFromString(String value) {
    switch (value) {
      case 'completed':
        return GoalStatus.completed;
      case 'archived':
        return GoalStatus.archived;
      case 'active':
      default:
        return GoalStatus.active;
    }
  }
}
