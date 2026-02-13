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

    final goalRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(widget.goalId);

    final tasksRef = goalRef.collection('tasks');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteGoal();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete Goal',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Task"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: goalRef.snapshots(),
        builder: (context, goalSnapshot) {
          if (!goalSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final goalData = goalSnapshot.data!.data() as Map<String, dynamic>?;
          final description = goalData?['description'] ?? '';

          return StreamBuilder<QuerySnapshot>(
            stream: tasksRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text("Error:\n${snapshot.error}"),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

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

              final total = docs.length;
              final done = completed.length;
              final progress = total == 0 ? 0.0 : done / total;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildGoalCard(description, progress, done, total),
                  const SizedBox(height: 30),
                  if (pending.isNotEmpty) ...[
                    const Text(
                      "Pending Tasks",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(
      String description, double progress, int done, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.05),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 12,
              color: Colors.grey[300],
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: constraints.maxWidth * progress,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF4A90E2),
                            Color(0xFF8E44AD),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text("$done of $total tasks completed"),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGoal() async {
    final user = FirebaseAuth.instance.currentUser!;
    final goalRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(widget.goalId);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Goal?"),
        content: const Text(
            "This will permanently delete this goal and all its tasks."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final tasks = await goalRef.collection('tasks').get();
              for (var doc in tasks.docs) {
                await doc.reference.delete();
              }

              await goalRef.delete();

              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _onReorder(
      List<QueryDocumentSnapshot> pending, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final movedItem = pending.removeAt(oldIndex);
    pending.insert(newIndex, movedItem);

    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < pending.length; i++) {
      batch.update(pending[i].reference, {'order': i});
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
                await task.reference.update({'isCompleted': value ?? false});
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
              await task.reference
                  .update({'title': _taskController.text.trim()});
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
}
