// goal_task_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final TextEditingController _taskController = TextEditingController();

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
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Task"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: tasksRef.snapshots(), // 🔥 DO NOT orderBy here
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No tasks yet"));
          }

          // 🔥 SAFE SORTING (handles old tasks without 'order')
          docs.sort((a, b) {
            final aOrder =
                (a.data() as Map<String, dynamic>)['order'] ?? 999999;
            final bOrder =
                (b.data() as Map<String, dynamic>)['order'] ?? 999999;
            return aOrder.compareTo(bOrder);
          });

          return ReorderableListView(
            padding: const EdgeInsets.all(20),
            onReorder: (oldIndex, newIndex) =>
                _onReorder(docs, oldIndex, newIndex),
            children: [
              for (int i = 0; i < docs.length; i++)
                _taskTile(docs[i], Key(docs[i].id)),
            ],
          );
        },
      ),
    );
  }

  // 🔁 DRAG REORDER
  Future<void> _onReorder(
      List<QueryDocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final newDocs = List.from(docs);
    final item = newDocs.removeAt(oldIndex);
    newDocs.insert(newIndex, item);

    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < newDocs.length; i++) {
      batch.update(newDocs[i].reference, {
        'order': i,
      });
    }

    await batch.commit();
  }

  // 🧩 TASK TILE
  Widget _taskTile(QueryDocumentSnapshot task, Key key) {
    final data = task.data() as Map<String, dynamic>;
    final isCompleted = data['isCompleted'] ?? false;

    return Card(
      key: key,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isCompleted,
          activeColor: const Color(0xFF6C63FF),
          onChanged: (value) async {
            await task.reference.update({
              'isCompleted': value,
            });
          },
        ),
        title: Text(
          data['title'] ?? 'Task',
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✏ EDIT
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDialog(task),
            ),
            // 🗑 DELETE
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(task),
            ),
          ],
        ),
      ),
    );
  }

  // ➕ SHOW ADD DIALOG
  void _showAddTaskDialog() {
    _taskController.clear();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Task"),
        content: TextField(
          controller: _taskController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter task...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _addTask,
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // 🔥 ADD TASK AT TOP
  Future<void> _addTask() async {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser!;

    final tasksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(widget.goalId)
        .collection('tasks');

    final snapshot = await tasksRef.get();
    final batch = FirebaseFirestore.instance.batch();

    // Shift existing tasks down
    for (final doc in snapshot.docs) {
      final currentOrder = (doc.data() as Map<String, dynamic>)['order'] ?? 0;

      batch.update(doc.reference, {
        'order': currentOrder + 1,
      });
    }

    // Add new task at top (order 0)
    final newDoc = tasksRef.doc();
    batch.set(newDoc, {
      'title': text,
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'order': 0,
    });

    await batch.commit();

    if (mounted) Navigator.pop(context);
  }

  // ✏ EDIT TASK
  void _showEditDialog(QueryDocumentSnapshot task) {
    final data = task.data() as Map<String, dynamic>;
    _taskController.text = data['title'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Task"),
        content: TextField(
          controller: _taskController,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = _taskController.text.trim();
              if (text.isEmpty) return;

              await task.reference.update({
                'title': text,
              });

              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // 🗑 DELETE CONFIRM
  void _confirmDelete(QueryDocumentSnapshot task) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Task?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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
}
