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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

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
        stream: tasksRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          print("GOAL ID: ${widget.goalId}");
          print("TOTAL TASKS FOUND: ${docs.length}");

          if (docs.isEmpty) {
            return const Center(child: Text("No tasks yet"));
          }

          // 🔥 SAFE SORT (no Firestore orderBy dependency)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aOrder = aData['order'] ?? 0;
            final bOrder = bData['order'] ?? 0;

            return aOrder.compareTo(bOrder);
          });

          final pending = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return !(data['isCompleted'] ?? false);
          }).toList();

          final completed = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isCompleted'] ?? false;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (pending.isNotEmpty) ...[
                const Text(
                  "Pending Tasks",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: pending.length,
                  onReorder: (oldIndex, newIndex) =>
                      _onReorder(pending, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final task = pending[index];
                    return _taskTile(
                      task,
                      ValueKey(task.id),
                      index,
                      reorderable: true,
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
              if (completed.isNotEmpty) ...[
                const Text(
                  "Completed Tasks",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...completed.map(
                  (task) => _taskTile(
                    task,
                    ValueKey(task.id),
                    0,
                    reorderable: false,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // 🔥 REORDER PENDING ONLY
  Future<void> _onReorder(
      List<QueryDocumentSnapshot> pending, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final movedItem = pending.removeAt(oldIndex);
    pending.insert(newIndex, movedItem);

    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < pending.length; i++) {
      batch.update(pending[i].reference, {
        'order': i,
      });
    }

    await batch.commit();
  }

  Widget _taskTile(
    QueryDocumentSnapshot task,
    Key key,
    int index, {
    required bool reorderable,
  }) {
    final data = task.data() as Map<String, dynamic>;
    final isCompleted = data['isCompleted'] ?? false;
    final title = data['title'] ?? 'Task';

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: reorderable
            ? ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              )
            : const SizedBox(width: 24),
        title: Row(
          children: [
            Checkbox(
              value: isCompleted,
              onChanged: (value) async {
                await task.reference.update({
                  'isCompleted': value ?? false,
                });
              },
            ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDialog(task),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(task),
            ),
          ],
        ),
      ),
    );
  }

  // ADD TASK
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

    await tasksRef.add({
      'title': text,
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'order': DateTime.now().millisecondsSinceEpoch,
    });

    _taskController.clear();
    if (mounted) Navigator.pop(context);
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Task"),
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
            onPressed: _addTask,
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(QueryDocumentSnapshot task) {
    final data = task.data() as Map<String, dynamic>;
    _taskController.text = data['title'] ?? '';

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
              await task.reference.update({
                'title': _taskController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(QueryDocumentSnapshot task) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Task?"),
        content: const Text("This action cannot be undone."),
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
