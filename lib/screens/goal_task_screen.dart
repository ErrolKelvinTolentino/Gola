// goal_task_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';

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
    final theme = Theme.of(context);

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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.auroraBackgroundGradient(theme.brightness),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            color: theme.colorScheme.surface,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.auroraBackgroundGradient(theme.brightness),
        ),
        child: StreamBuilder<DocumentSnapshot>(
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
                    child: Text(
                      "Error:\n${snapshot.error}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
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
                    _buildGoalCard(
                      description,
                      progress,
                      done,
                      total,
                      theme,
                    ),
                    const SizedBox(height: 30),
                    if (pending.isNotEmpty) ...[
                      Text(
                        "Pending Tasks",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
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
                      Text(
                        "Completed Tasks",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
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
      ),
    );
  }

  Widget _buildGoalCard(
    String description,
    double progress,
    int done,
    int total,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.black.withOpacity(0.05),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 12,
              color: theme.colorScheme.surfaceVariant,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
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
          Text(
            "$done of $total tasks completed",
            style: theme.textTheme.bodySmall,
          ),
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
    final theme = Theme.of(context);
    final data = task.data() as Map<String, dynamic>;
    final isCompleted = data['isCompleted'] ?? false;
    final title = data['title'] ?? 'Task';

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: theme.colorScheme.surface,
      child: ListTile(
        leading: reorderable
            ? ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              )
            : const SizedBox(width: 24),
        iconColor: theme.colorScheme.onSurface,
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
                  color: theme.colorScheme.onSurface,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onSurface,
          ),
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditDialog(task);
            } else if (value == 'delete') {
              _confirmDelete(task);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(color: Color.fromARGB(255, 199, 190, 189)),
                  ),
                ],
              ),
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text("Add New Task"),
        content: TextField(
          controller: _taskController,
          autofocus: true,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.18),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.4),
              ),
            ),
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

  void _showEditDialog(QueryDocumentSnapshot task) {
    final data = task.data() as Map<String, dynamic>;
    _taskController.text = data['title'] ?? '';
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text("Edit Task"),
        content: TextField(
          controller: _taskController,
          autofocus: true,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.18),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.4),
              ),
            ),
          ),
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
