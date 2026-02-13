// goals_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    final goalsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('goals')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Goals"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add),
        onPressed: _showAddGoalDialog,
      ),
      body: StreamBuilder<QuerySnapshot>(
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

          return FutureBuilder(
            future: _computeGoals(goals),
            builder: (context, AsyncSnapshot<List<GoalModel>> snapshot) {
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
                    const Text("No active goals.",
                        style: TextStyle(color: Colors.grey)),
                  ...active.map(_buildGoalCard),
                  const SizedBox(height: 30),
                  _sectionHeader("Completed Goals"),
                  const SizedBox(height: 12),
                  if (completed.isEmpty)
                    const Text("Finish a goal to see it here.",
                        style: TextStyle(color: Colors.grey)),
                  ...completed.map(_buildGoalCard),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildGoalCard(GoalModel goal) {
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
                  child: const Text("Cancel")),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalTaskScreen(
                    goalId: goal.id,
                    title: goal.title,
                  ),
                ),
              );
            },
            child: Ink(
              decoration: BoxDecoration(
                gradient: goal.isCompleted
                    ? const LinearGradient(
                        colors: [Colors.grey, Colors.blueGrey])
                    : const LinearGradient(
                        colors: [
                          Color(0xFF6C63FF),
                          Color(0xFF00C6FF),
                        ],
                      ),
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
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "✨ Create a New Goal",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Break your ambition into actionable steps.",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    const Text("Goal Title",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: "e.g. Launch my portfolio website",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text("Description (Optional)",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      "Describe your goal for better and more specific task generation.",
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            "Include deadlines, constraints, or specific outcomes...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
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
                                    // 🔥 Generate AI FIRST
                                    final tasks =
                                        await GeminiService().generateTasks(
                                      goalTitle: title,
                                      description: description,
                                    );

                                    // 🔥 Create Goal AFTER tasks ready
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

                                    for (final task in tasks) {
                                      batch.set(
                                        goalDoc.collection('tasks').doc(),
                                        {
                                          'title': task,
                                          'isCompleted': false,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
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
