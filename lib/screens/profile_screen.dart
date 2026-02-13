import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gola_goal_guidance_app/main.dart';
import 'package:gola_goal_guidance_app/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _username;
  String? _email;
  bool _isLoadingProfile = true;
  static final RegExp _usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');
  static final RegExp _emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingProfile = false;
      });
      return;
    }

    final email = user.email;
    String? username;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usernames')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        username = snapshot.docs.first.data()['username'] as String?;
      }
    } catch (_) {
      // Leave username null if lookup fails.
    }

    setState(() {
      _email = email;
      _username = username ?? user.displayName;
      _isLoadingProfile = false;
    });
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _username ?? 'Username';
    final displayEmail = _email ?? 'Email';

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 30),
                child: Center(
                  child: Column(
                    children: [
                      // Profile Picture
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.scaffoldBackgroundColor,
                              ),
                              child: const CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey,
                                backgroundImage: AssetImage(
                                  'lib/images/lumi-asking-step-3.png',
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _isLoadingProfile
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Column(
                              children: [
                                Text(
                                  displayName,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayEmail,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),

            // Profile Stats Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildProfileStat(
                        context,
                        '12',
                        'Goals',
                        Icons.flag_rounded,
                        const Color(0xFF6366f1),
                      ),
                      _buildDivider(context),
                      _buildProfileStat(
                        context,
                        '48h',
                        'Focus',
                        Icons.timer_rounded,
                        const Color(0xFFf59e0b),
                      ),
                      _buildDivider(context),
                      _buildProfileStat(
                        context,
                        '5',
                        'Streak',
                        Icons.local_fire_department_rounded,
                        const Color(0xFFef4444),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Settings Sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSettingsTile(
                          context,
                          icon: Icons.person_outline,
                          title: 'Personal Info',
                          iconColor: const Color(0xFF6366f1),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: _showPersonalInfoDialog,
                        ),
                        Divider(height: 1, color: Colors.grey.withAlpha(30)),
                        _buildSettingsTile(
                          context,
                          icon: Icons.security_outlined,
                          title: 'Security',
                          iconColor: const Color(0xFF10b981),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: _showChangePasswordDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preferences',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildSettingsTile(
                      context,
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      subtitle: _themeLabel(themeNotifier.value),
                      iconColor: const Color(0xFFec4899),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      onTap: _showThemePicker,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withAlpha(50),
                        width: 1,
                      ),
                    ),
                    child: _buildSettingsTile(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Log Out',
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: () => _logout(context),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(height: 40, width: 1, color: Colors.grey.withAlpha(50));
  }

  Widget _buildProfileStat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? textColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? Theme.of(context).colorScheme.primary).withAlpha(
            20,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color:
              iconColor ?? textColor ?? Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  bool _isUsernameValid(String value) => _usernameRegex.hasMatch(value);

  bool _isEmailValid(String value) => _emailRegex.hasMatch(value);

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'requires-recent-login':
        return 'Please log in again to update sensitive info.';
      case 'wrong-password':
        return 'The current password is incorrect.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return error.message ?? 'Something went wrong.';
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
      default:
        return 'System';
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Light Mode'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeNotifier.value,
                onChanged: (value) {
                  themeNotifier.value = value ?? ThemeMode.light;
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Dark Mode'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeNotifier.value,
                onChanged: (value) {
                  themeNotifier.value = value ?? ThemeMode.dark;
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('System'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeNotifier.value,
                onChanged: (value) {
                  themeNotifier.value = value ?? ThemeMode.system;
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPersonalInfoDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final usernameController = TextEditingController(text: _username ?? '');
    final emailController =
        TextEditingController(text: _email ?? user.email ?? '');

    String? usernameError;
    String? emailError;
    String? generalError;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Personal Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return newValue.copyWith(
                      text: newValue.text.toLowerCase(),
                      selection: newValue.selection,
                    );
                  }),
                ],
                decoration: InputDecoration(
                  labelText: 'Username',
                  helperText: '3-20 chars, lowercase, letters/numbers/_',
                  errorText: usernameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: emailError,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              if (generalError != null) ...[
                const SizedBox(height: 12),
                Text(
                  generalError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newUsername =
                          _normalizeUsername(usernameController.text);
                      final newEmail = emailController.text.trim();

                      setDialogState(() {
                        usernameError = null;
                        emailError = null;
                        generalError = null;
                      });

                      if (!_isUsernameValid(newUsername)) {
                        setDialogState(() {
                          usernameError =
                              'Use 3-20 chars: lowercase, numbers, _';
                        });
                        return;
                      }

                      if (newEmail.isEmpty || !_isEmailValid(newEmail)) {
                        setDialogState(() {
                          emailError = 'Enter a valid email address.';
                        });
                        return;
                      }

                      if (newUsername == _username && newEmail == _email) {
                        setDialogState(() {
                          generalError = 'Nothing to update.';
                        });
                        return;
                      }

                      try {
                        final emailSnapshot = await FirebaseFirestore.instance
                            .collection('usernames')
                            .where('email', isEqualTo: newEmail)
                            .limit(1)
                            .get();
                        if (emailSnapshot.docs.isNotEmpty) {
                          final existingUid =
                              emailSnapshot.docs.first.data()['uid'] as String?;
                          if (existingUid != null && existingUid != user.uid) {
                            setDialogState(() {
                              emailError = 'That email is already in use.';
                            });
                            return;
                          }
                        }
                      } catch (_) {
                        setDialogState(() {
                          generalError =
                              'Unable to verify email right now. Try again.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        await _updateUsername(user.uid, newUsername, newEmail);
                        if (newEmail != user.email) {
                          await user.verifyBeforeUpdateEmail(newEmail);
                        }

                        if (!mounted) return;
                        setState(() {
                          _username = newUsername;
                          _email = newEmail;
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated.'),
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() {
                          generalError = _mapAuthError(e);
                        });
                      } catch (e) {
                        final message = e.toString();
                        setDialogState(() {
                          if (message.contains('Username already taken')) {
                            usernameError = 'That username is already taken.';
                          } else {
                            generalError = 'Update failed. Try again.';
                          }
                        });
                      } finally {
                        setDialogState(() {
                          isSaving = false;
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUsername(
    String uid,
    String newUsername,
    String email,
  ) async {
    final db = FirebaseFirestore.instance;
    final usernameRef = db.collection('usernames').doc(newUsername);

    if (_username != null && _username == newUsername) {
      await usernameRef.set({
        'uid': uid,
        'email': email,
        'username': newUsername,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newUsername);
      return;
    }

    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(usernameRef);
      if (snapshot.exists) {
        throw Exception('Username already taken.');
      }
      transaction.set(usernameRef, {
        'uid': uid,
        'email': email,
        'username': newUsername,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (_username != null && _username!.isNotEmpty) {
        transaction.delete(db.collection('usernames').doc(_username));
      }
    });

    await FirebaseAuth.instance.currentUser?.updateDisplayName(newUsername);
  }

  Future<void> _showChangePasswordDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? currentError;
    String? newError;
    String? confirmError;
    String? generalError;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  errorText: currentError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  helperText: 'At least 8 characters',
                  errorText: newError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  errorText: confirmError,
                ),
              ),
              if (generalError != null) ...[
                const SizedBox(height: 12),
                Text(
                  generalError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final current = currentController.text;
                      final next = newController.text;
                      final confirm = confirmController.text;

                      setDialogState(() {
                        currentError = null;
                        newError = null;
                        confirmError = null;
                        generalError = null;
                      });

                      if (current.isEmpty) {
                        setDialogState(() {
                          currentError = 'Enter your current password.';
                        });
                        return;
                      }

                      if (next.length < 8) {
                        setDialogState(() {
                          newError = 'Password must be at least 8 characters.';
                        });
                        return;
                      }

                      if (current == next) {
                        setDialogState(() {
                          newError = 'New password must be different.';
                        });
                        return;
                      }

                      if (next != confirm) {
                        setDialogState(() {
                          confirmError = 'Passwords do not match.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: current,
                        );
                        await user.reauthenticateWithCredential(credential);
                        await user.updatePassword(next);

                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password updated.')),
                        );
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() {
                          generalError = _mapAuthError(e);
                        });
                      } catch (_) {
                        setDialogState(() {
                          generalError = 'Password update failed. Try again.';
                        });
                      } finally {
                        setDialogState(() {
                          isSaving = false;
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
