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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  GoalSort _sort = GoalSort.newest;
  final Map<String, bool> _pinOverrides = {};
  Future<List<GoalModel>>? _goalsFuture;
  String _goalsSignature = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

            _syncPinOverrides(goals);

            final signature = _goalsSignatureFor(goals);
            if (signature != _goalsSignature) {
              _goalsSignature = signature;
              _goalsFuture = _computeGoals(goals);
            }

            return FutureBuilder<List<GoalModel>>(
              future: _goalsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final active = _applySortAndFilter(
                  snapshot.data!.where((g) => !g.isCompleted).toList(),
                );

                final completed = _applySortAndFilter(
                  snapshot.data!.where((g) => g.isCompleted).toList(),
                );

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSearchAndSort(theme),
                    const SizedBox(height: 16),
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

  void _syncPinOverrides(List<QueryDocumentSnapshot> goals) {
    for (final goal in goals) {
      final data = goal.data() as Map<String, dynamic>;
      final serverPinned = data['pinned'] == true;
      final override = _pinOverrides[goal.id];
      if (override != null && override == serverPinned) {
        _pinOverrides.remove(goal.id);
      }
    }
  }

  void _invalidateGoalsCache() {
    _goalsSignature = '';
    _goalsFuture = null;
  }

  String _goalsSignatureFor(List<QueryDocumentSnapshot> goals) {
    final buffer = StringBuffer();
    for (final goal in goals) {
      final data = goal.data() as Map<String, dynamic>;
      buffer
        ..write(goal.id)
        ..write('|')
        ..write(data['title'] ?? '')
        ..write('|')
        ..write(data['pinned'] == true ? '1' : '0')
        ..write('|')
        ..write(data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0)
        ..write(';');
    }
    return buffer.toString();
  }

  Widget _buildSearchAndSort(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search goals',
                hintStyle: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6) ??
                      Colors.grey,
                ),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildSortMenu(theme),
        ],
      ),
    );
  }

  Widget _buildSortMenu(ThemeData theme) {
    return PopupMenuButton<GoalSort>(
      tooltip: 'Sort goals',
      onSelected: (value) {
        setState(() {
          _sort = value;
        });
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: GoalSort.newest,
          child: Text('Newest first'),
        ),
        PopupMenuItem(
          value: GoalSort.oldest,
          child: Text('Oldest first'),
        ),
        PopupMenuItem(
          value: GoalSort.titleAsc,
          child: Text('Title A-Z'),
        ),
        PopupMenuItem(
          value: GoalSort.progressDesc,
          child: Text('Progress high-low'),
        ),
        PopupMenuItem(
          value: GoalSort.progressAsc,
          child: Text('Progress low-high'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 6),
            Text(
              _sortLabel(_sort),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(GoalSort sort) {
    switch (sort) {
      case GoalSort.newest:
        return 'Newest';
      case GoalSort.oldest:
        return 'Oldest';
      case GoalSort.titleAsc:
        return 'Title';
      case GoalSort.progressDesc:
        return 'Progress';
      case GoalSort.progressAsc:
        return 'Progress';
    }
  }

  List<GoalModel> _applySortAndFilter(List<GoalModel> goals) {
    final filtered = _searchQuery.isEmpty
        ? goals
        : goals
            .where((g) => g.title.toLowerCase().contains(_searchQuery))
            .toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      switch (_sort) {
        case GoalSort.newest:
          return b.createdAt.compareTo(a.createdAt);
        case GoalSort.oldest:
          return a.createdAt.compareTo(b.createdAt);
        case GoalSort.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case GoalSort.progressDesc:
          return b.progress.compareTo(a.progress);
        case GoalSort.progressAsc:
          return a.progress.compareTo(b.progress);
      }
    });

    return filtered;
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
                _invalidateGoalsCache();
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _togglePin(goal),
                        icon: Icon(
                          goal.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: goal.isPinned ? 'Unpin' : 'Pin',
                      ),
                    ],
                  ),
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
    final futures = goals.map((goal) async {
      final tasks = await goal.reference.collection('tasks').get();

      final total = tasks.docs.length;
      final completed =
          tasks.docs.where((d) => (d['isCompleted'] ?? false) == true).length;

      final progress = total == 0 ? 0.0 : completed / total;

      final data = goal.data() as Map<String, dynamic>;
      final createdAtRaw = data['createdAt'];
      final createdAt = createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final pinned = _pinOverrides[goal.id] ?? (data['pinned'] == true);

      return GoalModel(
        id: goal.id,
        title: goal['title'],
        ref: goal.reference,
        total: total,
        completed: completed,
        progress: progress,
        isCompleted: total > 0 && completed == total,
        isPinned: pinned,
        createdAt: createdAt,
      );
    });

    return Future.wait(futures);
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isLoading = false;
    bool useAiTasks = true;

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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Generate tasks with AI',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch(
                            value: useAiTasks,
                            onChanged: isLoading
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      useAiTasks = value;
                                    });
                                  },
                          ),
                        ],
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
                                    final goalCollection = FirebaseFirestore
                                        .instance
                                        .collection('users')
                                        .doc(user!.uid)
                                        .collection('goals');

                                    final tasks = useAiTasks
                                        ? await GeminiService().generateTasks(
                                            goalTitle: title,
                                            description: description,
                                          )
                                        : <String>[];

                                    final goalDoc = goalCollection.doc();
                                    final batch =
                                        FirebaseFirestore.instance.batch();

                                    batch.set(goalDoc, {
                                      'title': title,
                                      'description': description,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'pinned': false,
                                    });

                                    if (useAiTasks) {
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

  Future<void> _togglePin(GoalModel goal) async {
    final nextPinned = !goal.isPinned;
    setState(() {
      _pinOverrides[goal.id] = nextPinned;
    });

    try {
      await goal.ref.update({'pinned': nextPinned});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pinOverrides.remove(goal.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pin failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
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
  final bool isPinned;
  final DateTime createdAt;

  GoalModel({
    required this.id,
    required this.title,
    required this.ref,
    required this.total,
    required this.completed,
    required this.progress,
    required this.isCompleted,
    required this.isPinned,
    required this.createdAt,
  });
}

enum GoalSort {
  newest,
  oldest,
  titleAsc,
  progressDesc,
  progressAsc,
}
