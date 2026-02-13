import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late AnimationController _characterController;

  int _focusDuration = 25;
  int _restDuration = 5;
  int _minutes = 25;
  int _seconds = 0;
  bool _isActive = false;
  bool _isFocusSession = true;
  Timer? _timer;
  String? _selectedTaskId;
  String _selectedTaskTitle = 'No task selected';
  String? _selectedGoalId;
  String? _selectedGoalTitle;
  int _sessionsCompleted = 0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _characterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    _characterController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _goalsWithPending(
    String uid,
  ) async {
    final goalsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .get();

    final results = await Future.wait(
      goalsSnapshot.docs.map((goal) async {
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('goals')
            .doc(goal.id)
            .collection('tasks')
            .get();

        final hasPending = tasksSnapshot.docs
            .any((task) => !(task.data()['isCompleted'] ?? false));

        return hasPending ? goal : null;
      }),
    );

    return results
        .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
        .toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _goalTasksOnce(
    String uid,
    String goalId,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc(goalId)
        .collection('tasks')
        .orderBy('createdAt')
        .get();
  }

  void _startTimer() {
    if (_isActive) return;

    setState(() {
      _isActive = true;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isActive) return;

      final currentTotalSeconds = _minutes * 60 + _seconds;

      if (currentTotalSeconds > 0) {
        setState(() {
          if (_seconds > 0) {
            _seconds--;
          } else if (_minutes > 0) {
            _minutes--;
            _seconds = 59;
          }
        });
      } else {
        _completeSession();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isActive = false;
    });
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _isFocusSession = true;
      _minutes = _focusDuration;
      _seconds = 0;
    });
  }

  void _completeSession() {
    _stopTimer();

    if (_isFocusSession) {
      setState(() {
        _sessionsCompleted++;
        _isFocusSession = false;
        _minutes = _restDuration;
        _seconds = 0;
      });
      _showSessionCompleteDialog('Focus session complete', 'Time for a break!');
    } else {
      setState(() {
        _isFocusSession = true;
        _minutes = _focusDuration;
        _seconds = 0;
      });
      _showSessionCompleteDialog(
        'Break time over',
        'Ready for another focus session?',
      );
    }
  }

  void _showGoalSelection(String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildGoalBottomSheet(uid);
      },
    );
  }

  void _showTaskSelection(
    String uid,
    String goalId,
    String goalTitle,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildTaskSelectionSheet(uid, goalId, goalTitle);
      },
    );
  }

  void _showSessionCompleteDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text(
              'Sessions Completed: $_sessionsCompleted',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final focusController = TextEditingController(
      text: _focusDuration.toString(),
    );
    final restController = TextEditingController(
      text: _restDuration.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timer Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: focusController,
                decoration: const InputDecoration(
                  labelText: 'Focus Duration (minutes)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: restController,
                decoration: const InputDecoration(
                  labelText: 'Rest Duration (minutes)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _focusDuration = int.tryParse(focusController.text) ?? 25;
                _restDuration = int.tryParse(restController.text) ?? 5;
                _minutes = _isFocusSession ? _focusDuration : _restDuration;
                _seconds = 0;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRunning = _isActive;
    final user = FirebaseAuth.instance.currentUser;
    final canMarkDone = _selectedTaskId != null && _selectedGoalId != null;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Mode'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.auroraBackgroundGradient(theme.brightness),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildStatusChip(
                            theme,
                            label: _isFocusSession
                                ? 'Focus Session'
                                : 'Rest Session',
                            icon: _isFocusSession
                                ? Icons.bolt_rounded
                                : Icons.self_improvement_rounded,
                            color: _isFocusSession
                                ? theme.colorScheme.primary
                                : Colors.green,
                          ),
                          _buildStatusChip(
                            theme,
                            label: 'Sessions $_sessionsCompleted',
                            icon: Icons.auto_awesome_rounded,
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: AppTheme.surfaceFor(theme.brightness)
                              .withOpacity(0.9),
                          boxShadow: AppTheme.softShadow(theme.brightness),
                        ),
                        child: Column(
                          children: [
                            _buildAwesomeTimer(theme, isRunning),
                            const SizedBox(height: 24),
                            _buildControlButtons(theme, isRunning),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Tappable Current Task Display
                      Material(
                        color: Colors.transparent,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => _showGoalSelection(user.uid),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: AppTheme.surfaceFor(theme.brightness)
                                      .withOpacity(0.95),
                                  boxShadow:
                                      AppTheme.softShadow(theme.brightness),
                                  border: Border.all(
                                    color:
                                        theme.colorScheme.primary.withAlpha(80),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withAlpha(30),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.task_alt_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current Task',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha(120),
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _selectedTaskTitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 17,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_selectedGoalTitle != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                _selectedGoalTitle!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withAlpha(130),
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: theme.colorScheme.primary
                                          .withAlpha(150),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (canMarkDone)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _confirmMarkCurrentTaskCompleted(
                                            user.uid),
                                    icon: const Icon(
                                      Icons.check_circle_rounded,
                                    ),
                                    label: const Text('Mark as Done'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(theme.brightness).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAwesomeTimer(ThemeData theme, bool isRunning) {
    final sessionDuration = _isFocusSession ? _focusDuration : _restDuration;
    final totalSeconds = sessionDuration * 60;
    final elapsedSeconds = (sessionDuration * 60) - (_minutes * 60 + _seconds);
    final progress = elapsedSeconds / totalSeconds;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Subtle Glow Effect
        if (isRunning)
          RotationTransition(
            turns: _glowController,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    theme.colorScheme.primary.withAlpha(0),
                    theme.colorScheme.primary.withAlpha(40),
                    theme.colorScheme.secondary.withAlpha(30),
                  ],
                ),
              ),
            ),
          ),

        // Background Circle with soft shadow
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(20),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
        ),

        // Animated Progress Ring
        SizedBox(
          width: 240,
          height: 240,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Color.lerp(
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                progress,
              )!,
            ),
            backgroundColor: theme.colorScheme.surface.withAlpha(30),
            strokeCap: StrokeCap.round,
          ),
        ),

        // Lumi Character with floating animation
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: SlideTransition(
            key: ValueKey<bool>(_isFocusSession),
            position: Tween<Offset>(
              begin: const Offset(0, -0.02),
              end: const Offset(0, 0.02),
            ).animate(_characterController),
            child: Image.asset(
              _isFocusSession
                  ? 'lib/images/lumi-focused.png'
                  : 'lib/images/lumi-meditate.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Timer Text positioned below character
        Positioned(
          bottom: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(220),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(60),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
                  child: Text(
                    '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontFeatures: [const FontFeature.tabularFigures()],
                      letterSpacing: 3,
                      fontSize: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(ThemeData theme, bool isRunning) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset Button
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withAlpha(50),
          ),
          child: IconButton(
            onPressed: _resetTimer,
            icon: const Icon(Icons.refresh_rounded),
            iconSize: 24,
            color: Colors.grey,
            tooltip: 'Reset',
          ),
        ),
        const SizedBox(width: 20),

        // Play/Pause Button
        GestureDetector(
          onTap: isRunning ? _stopTimer : _startTimer,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.secondary.withAlpha(150),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 45,
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Quick Start (Skip to next)
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withAlpha(50),
          ),
          child: IconButton(
            onPressed: _completeSession,
            icon: const Icon(Icons.skip_next_rounded),
            iconSize: 24,
            color: Colors.grey,
            tooltip: 'Skip',
          ),
        ),
      ],
    );
  }

  Widget _buildGoalBottomSheet(String uid) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child:
              FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _goalsWithPending(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final goals = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Choose a goal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (goals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No goals with pending tasks yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: goals.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.withAlpha(50),
                        ),
                        itemBuilder: (context, index) {
                          final goal = goals[index];
                          final data = goal.data();
                          final title = data['title'] ?? 'Untitled goal';
                          final description = data['description'] ?? '';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(title),
                            subtitle: description.isNotEmpty
                                ? Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showTaskSelection(uid, goal.id, title);
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTaskSelectionSheet(
    String uid,
    String goalId,
    String goalTitle,
  ) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: _goalTasksOnce(uid, goalId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = snapshot.data?.docs ?? [];
              final pendingTasks = tasks
                  .where((task) => !(task.data()['isCompleted'] ?? false))
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Pick a task',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      goalTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withAlpha(140),
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pendingTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No pending tasks yet for this goal.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: pendingTasks.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.withAlpha(50),
                        ),
                        itemBuilder: (context, index) {
                          final task = pendingTasks[index];
                          final data = task.data();
                          final title = data['title'] ?? 'Untitled task';
                          final isSelected = _selectedTaskId == task.id;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            title: Text(
                              title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.2),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedTaskId = task.id;
                                _selectedTaskTitle = title;
                                _selectedGoalId = goalId;
                                _selectedGoalTitle = goalTitle;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmMarkCurrentTaskCompleted(String uid) async {
    if (_selectedTaskId == null || _selectedGoalId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark task complete?'),
        content: Text(
          'Mark "$_selectedTaskTitle" as done? This will hide it from focus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark as Done'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _markCurrentTaskCompleted(uid);
    }
  }

  Future<void> _markCurrentTaskCompleted(String uid) async {
    if (_selectedTaskId == null || _selectedGoalId == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(_selectedGoalId)
          .collection('tasks')
          .doc(_selectedTaskId)
          .update({'isCompleted': true});

      if (!mounted) return;
      setState(() {
        _selectedTaskId = null;
        _selectedGoalId = null;
        _selectedTaskTitle = 'No task selected';
        _selectedGoalTitle = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task marked as done. Great job!')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not mark task done: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
