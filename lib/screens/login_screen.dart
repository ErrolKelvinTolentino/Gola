import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'register_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final auth = AuthService();

  bool loading = false;
  bool hidePassword = true;

  Future<void> login() async {
    setState(() => loading = true);

    try {
      await auth.login(
        usernameController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;

      // ✅ Navigate AFTER successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found for this username.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = 'Login failed. Please try again.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong.')));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final onBackground = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Aurora gradient background
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.auroraBackgroundGradient(brightness),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // ✨ Logo
                  Image.asset(
                    'lib/images/Gola Logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 24),

                  // 🎯 App name & tagline
                  Text(
                    'Gola',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.auroraPurple,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Make it happen.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onBackground.withOpacity(0.7),
                      fontWeight: FontWeight.w300,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // 👤 Username Field
                  _buildModernTextField(
                    controller: usernameController,
                    hintText: 'Username',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.text,
                  ),

                  const SizedBox(height: 16),

                  // 🔐 Password Field
                  _buildModernTextField(
                    controller: passwordController,
                    hintText: 'Password',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    hidePassword: hidePassword,
                    onPasswordToggle: () {
                      setState(() => hidePassword = !hidePassword);
                    },
                  ),

                  const SizedBox(height: 32),

                  // 🚀 Login Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.auroraPurple, AppTheme.auroraPink],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow(brightness),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: loading ? null : login,
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: loading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Login',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onBackground.withOpacity(0.7),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.auroraPink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Modern text field widget
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool hidePassword = true,
    VoidCallback? onPasswordToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(
          brightness,
        ).withOpacity(brightness == Brightness.dark ? 0.9 : 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.softShadow(brightness),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && hidePassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: theme.hintColor),
          prefixIcon: Icon(icon, color: AppTheme.auroraPurple, size: 20),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onPasswordToggle,
                  child: Icon(
                    hidePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.auroraBlue,
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }
}
