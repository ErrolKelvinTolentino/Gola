import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _dailyQuotes = [
    'Small steps, massive momentum.',
    'Focus on progress, not perfection.',
    'Your future self will thank you.',
    'Consistency beats intensity.',
    'One task at a time, done well.',
    'Dreams get real when you do.',
    'Start where you are. Use what you have.',
    'Tiny wins build big days.',
    'Discipline is a love letter to your goals.',
    'Keep going. You are closer than you think.',
    'Show up. Do the work. Repeat.',
    'Momentum loves a clear next step.',
  ];

  LinearGradient _heroGradient(ThemeData theme) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        theme.colorScheme.primary.withOpacity(0.95),
        AppTheme.auroraPurple.withOpacity(0.9),
        theme.colorScheme.secondary.withOpacity(0.95),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _goalsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  int _dayOfYear(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    return date.difference(start).inDays + 1;
  }

  String _greetingName(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.auroraBackgroundGradient(brightness),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _goalsStream(user.uid),
            builder: (context, goalSnapshot) {
              if (goalSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingLayout(theme, user);
              }

              final goals = goalSnapshot.data?.docs ?? [];

              return FutureBuilder<Map<String, int>>(
                future: _calculateStats(user.uid, goals),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _buildLoadingLayout(theme, user);
                  }

                  final totalTasks = snapshot.data!['totalTasks']!;
                  final completedTasks = snapshot.data!['completedTasks']!;
                  final completedGoals = snapshot.data!['completedGoals']!;
                  final totalGoals = snapshot.data!['totalGoals']!;

                  final remainingTasks = totalTasks - completedTasks;
                  final progress =
                      totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'Hello, ${_greetingName(user)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: _buildHeroHeader(
                            theme,
                            completedTasks,
                            totalTasks,
                            progress,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'Your momentum',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.1,
                          ),
                          delegate: SliverChildListDelegate(
                            [
                              _buildStatTile(
                                theme,
                                title: 'Total tasks',
                                value: totalTasks.toString(),
                                subtitle: 'Across all goals',
                                icon: Icons.layers_rounded,
                                accent: theme.colorScheme.primary,
                              ),
                              _buildStatTile(
                                theme,
                                title: 'Completed tasks',
                                value: completedTasks.toString(),
                                subtitle: 'Well done',
                                icon: Icons.check_circle_rounded,
                                accent: theme.colorScheme.secondary,
                              ),
                              _buildStatTile(
                                theme,
                                title: 'Remaining',
                                value: remainingTasks.toString(),
                                subtitle: 'Keep going',
                                icon: Icons.flag_rounded,
                                accent: Colors.orange,
                              ),
                              _buildStatTile(
                                theme,
                                title: 'Goals completed',
                                value: '$completedGoals / $totalGoals',
                                subtitle: 'Fully finished',
                                icon: Icons.emoji_events_rounded,
                                accent: AppTheme.auroraPurple,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverToBoxAdapter(
                          child: _buildDailyQuote(theme),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 36),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingLayout(ThemeData theme, User user) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Hello, ${_greetingName(user)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: AppTheme.surfaceFor(theme.brightness).withOpacity(0.4),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: AppTheme.surfaceFor(theme.brightness).withOpacity(0.4),
                ),
              ),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader(
    ThemeData theme,
    int completedTasks,
    int totalTasks,
    double progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: _heroGradient(theme),
        boxShadow: AppTheme.softShadow(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$completedTasks of $totalTasks tasks completed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    ThemeData theme, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.surfaceFor(theme.brightness).withOpacity(0.95),
        boxShadow: AppTheme.softShadow(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(title, style: theme.textTheme.bodyMedium),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuote(ThemeData theme) {
    final quote =
        _dailyQuotes[_dayOfYear(DateTime.now()) % _dailyQuotes.length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppTheme.surfaceFor(theme.brightness).withOpacity(0.95),
        boxShadow: AppTheme.softShadow(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily motivation',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            quote,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _calculateStats(
    String uid,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> goals,
  ) async {
    int totalTasks = 0;
    int completedTasks = 0;
    int completedGoals = 0;

    for (final goal in goals) {
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goal.id)
          .collection('tasks')
          .get();

      final tasks = tasksSnapshot.docs;
      if (tasks.isEmpty) continue;

      final completedTaskCount =
          tasks.where((doc) => doc.data()['isCompleted'] == true).length;

      totalTasks += tasks.length;
      completedTasks += completedTaskCount;

      if (completedTaskCount == tasks.length) {
        completedGoals++;
      }
    }

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'completedGoals': completedGoals,
      'totalGoals': goals.length,
    };
  }
}
