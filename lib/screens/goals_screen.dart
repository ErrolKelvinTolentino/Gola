// goals_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../services/gemini_service.dart';
import 'goal_task_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final goalsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('goals')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("My Goals"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add),
        onPressed: _showAddGoalDialog,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.auroraBackgroundGradient(brightness),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: goalsRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final goals = snapshot.data!.docs;

            if (goals.isEmpty) {
              return const Center(
                child: Text(
                  "No goals yet.\nTap + to create one.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return FutureBuilder<List<GoalModel>>(
              future: _computeGoals(goals),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final active = snapshot.data!
                    .where((g) => !g.isCompleted)
                    .toList()
                  ..sort((a, b) => a.progress.compareTo(b.progress));

                final completed =
                    snapshot.data!.where((g) => g.isCompleted).toList();

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _sectionHeader("Active Goals"),
                    const SizedBox(height: 12),
                    if (active.isEmpty)
                      Text(
                        "No active goals.",
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.6) ??
                              Colors.grey,
                        ),
                      ),
                    ...active.map(_buildGoalCard),
                    const SizedBox(height: 30),
                    _sectionHeader("Completed Goals"),
                    const SizedBox(height: 12),
                    if (completed.isEmpty)
                      Text(
                        "Finish a goal to see it here.",
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.6) ??
                              Colors.grey,
                        ),
                      ),
                    ...completed.map(_buildGoalCard),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildGoalCard(GoalModel goal) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeGradient = LinearGradient(
      colors: isDark
          ? [
              theme.colorScheme.primary.withOpacity(0.9),
              theme.colorScheme.secondary.withOpacity(0.85),
            ]
          : const [
              Color(0xFF6C63FF),
              Color(0xFF00C6FF),
            ],
    );
    final completedGradient = LinearGradient(
      colors: isDark
          ? [
              theme.colorScheme.surfaceVariant,
              theme.colorScheme.surface,
            ]
          : const [Colors.grey, Colors.blueGrey],
    );

    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 20),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Delete Goal?"),
            content: const Text("This will permanently delete this goal."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await goal.ref.delete();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 20),
        child: Material(
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalTaskScreen(
                    goalId: goal.id,
                    title: goal.title,
                  ),
                ),
              );

              // 🔥 FORCE REBUILD WHEN RETURNING
              if (mounted) {
                setState(() {});
              }
            },
            child: Ink(
              decoration: BoxDecoration(
                gradient: goal.isCompleted ? completedGradient : activeGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: goal.progress,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${(goal.progress * 100).toInt()}%",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        "${goal.completed} / ${goal.total} tasks",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<GoalModel>> _computeGoals(
      List<QueryDocumentSnapshot> goals) async {
    List<GoalModel> result = [];

    for (var goal in goals) {
      final tasks = await goal.reference.collection('tasks').get();

      final total = tasks.docs.length;
      final completed =
          tasks.docs.where((d) => (d['isCompleted'] ?? false) == true).length;

      final progress = total == 0 ? 0.0 : completed / total;

      result.add(
        GoalModel(
          id: goal.id,
          title: goal['title'],
          ref: goal.reference,
          total: total,
          completed: completed,
          progress: progress,
          isCompleted: total > 0 && completed == total,
        ),
      );
    }

    return result;
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return Dialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "✨ Create a New Goal",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Break your ambition into actionable steps.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7) ??
                            Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Goal Title",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: "e.g. Launch my portfolio website",
                        hintStyle: TextStyle(
                          color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.6) ??
                              Colors.grey,
                        ),
                        filled: true,
                        fillColor:
                            theme.colorScheme.surfaceVariant.withOpacity(0.9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.18),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Description (Optional)",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor:
                            theme.colorScheme.surfaceVariant.withOpacity(0.9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.18),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    if (isLoading) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Generating AI tasks...",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed:
                              isLoading ? null : () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final title = titleController.text.trim();
                                  final description =
                                      descriptionController.text.trim();

                                  if (title.isEmpty) return;

                                  setDialogState(() => isLoading = true);

                                  try {
                                    final tasks =
                                        await GeminiService().generateTasks(
                                      goalTitle: title,
                                      description: description,
                                    );

                                    final goalDoc = await FirebaseFirestore
                                        .instance
                                        .collection('users')
                                        .doc(user!.uid)
                                        .collection('goals')
                                        .add({
                                      'title': title,
                                      'description': description,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    final batch =
                                        FirebaseFirestore.instance.batch();

                                    for (int i = 0; i < tasks.length; i++) {
                                      final task = tasks[i];
                                      batch.set(
                                        goalDoc.collection('tasks').doc(),
                                        {
                                          'title': task,
                                          'isCompleted': false,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                          'order': i,
                                        },
                                      );
                                    }

                                    await batch.commit();

                                    if (mounted) Navigator.pop(context);
                                  } catch (e) {
                                    setDialogState(() => isLoading = false);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Error: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Create Goal",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class GoalModel {
  final String id;
  final String title;
  final DocumentReference ref;
  final int total;
  final int completed;
  final double progress;
  final bool isCompleted;

  GoalModel({
    required this.id,
    required this.title,
    required this.ref,
    required this.total,
    required this.completed,
    required this.progress,
    required this.isCompleted,
  });
}
