// goal_task_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gemini_service.dart';

class GoalTaskScreen extends StatefulWidget {
  final String goalId;
  final String title;

  const GoalTaskScreen({
    super.key,
    required this.goalId,
    required this.title,
  });

  @override
  State<GoalTaskScreen> createState() => _GoalTaskScreenState();
}

class _GoalTaskScreenState extends State<GoalTaskScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    final tasksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(widget.goalId)
        .collection('tasks');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _generateTasks,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.auto_awesome),
        label: Text(_isLoading ? "Generating..." : "AI Plan"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: tasksRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final active =
              docs.where((d) => (d['isCompleted'] ?? false) == false);
          final completed =
              docs.where((d) => (d['isCompleted'] ?? false) == true);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (active.isNotEmpty) ...[
                const Text("Active",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...active.map((task) => _taskTile(task, false)),
                const SizedBox(height: 30),
              ],
              if (completed.isNotEmpty) ...[
                const Text("Completed",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...completed.map((task) => _taskTile(task, true)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _taskTile(QueryDocumentSnapshot task, bool isCompleted) {
    final data = task.data() as Map<String, dynamic>;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Checkbox(
          value: isCompleted,
          activeColor: const Color(0xFF6C63FF),
          onChanged: (value) async {
            await task.reference.update({'isCompleted': value});
          },
        ),
        title: Text(
          data['title'] ?? 'Task',
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDelete(task),
        ),
      ),
    );
  }

  void _confirmDelete(QueryDocumentSnapshot task) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Task?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await task.reference.delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTasks() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser!;
    final tasksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(widget.goalId)
        .collection('tasks');

    final tasks = await GeminiService().generateTasks(goalTitle: widget.title);

    final batch = FirebaseFirestore.instance.batch();

    for (final t in tasks) {
      batch.set(tasksRef.doc(), {
        'title': t,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (mounted) setState(() => _isLoading = false);
  }
}
