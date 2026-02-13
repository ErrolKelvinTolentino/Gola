import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final auth = AuthService();

  bool loading = false;
  bool hidePassword = true;
  bool hideConfirm = true;

  // 🔐 Password rules
  bool get isUpper => passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get isLower => passwordController.text.contains(RegExp(r'[a-z]'));
  bool get isNumber => passwordController.text.contains(RegExp(r'[0-9]'));
  bool get isSpecial =>
      passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  bool get isLong => passwordController.text.length >= 8;

  bool get isUsernameValid => RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(
        usernameController.text.trim().toLowerCase(),
      );

  bool get passwordsMatch =>
      passwordController.text == confirmController.text &&
      confirmController.text.isNotEmpty;

  bool get isFormValid =>
      isUsernameValid &&
      isUpper &&
      isLower &&
      isNumber &&
      isSpecial &&
      isLong &&
      passwordsMatch;

  // ✅ Requirement indicator widget (IN SCOPE)
  Widget requirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: met ? AppTheme.auroraBlue : Colors.grey[400],
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: met ? AppTheme.auroraBlue : Colors.grey[500],
              fontSize: 12,
              fontWeight: met ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> register() async {
    if (!isFormValid) return;

    setState(() => loading = true);
    try {
      await auth.register(
        emailController.text.trim(),
        passwordController.text.trim(),
        usernameController.text.trim(),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Back button + Title
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceFor(brightness).withOpacity(
                              brightness == Brightness.dark ? 0.9 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: AppTheme.softShadow(brightness),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: AppTheme.auroraPurple,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Create Account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.auroraPurple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Join Gola and achieve your goals!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onBackground.withOpacity(0.7),
                      fontWeight: FontWeight.w300,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 📧 Email
                  _buildModernTextField(
                    controller: emailController,
                    hintText: 'Email',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 20),

                  // 👤 Username
                  _buildModernTextField(
                    controller: usernameController,
                    hintText: 'Username (lowercase, 3-20 chars)',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.text,
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 12),

                  // ✅ Username requirements
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceFor(
                        brightness,
                      ).withOpacity(
                        brightness == Brightness.dark ? 0.85 : 0.7,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        requirement('3-20 characters', isUsernameValid),
                        requirement(
                            'Lowercase letters, numbers, _', isUsernameValid),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔐 Password
                  _buildModernTextField(
                    controller: passwordController,
                    hintText: 'Password',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    hidePassword: hidePassword,
                    onPasswordToggle: () {
                      setState(() => hidePassword = !hidePassword);
                    },
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 16),

                  // ✅ Password requirements
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceFor(
                        brightness,
                      ).withOpacity(brightness == Brightness.dark ? 0.85 : 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        requirement('At least 8 characters', isLong),
                        requirement('Contains uppercase letter', isUpper),
                        requirement('Contains lowercase letter', isLower),
                        requirement('Contains number', isNumber),
                        requirement('Contains special character', isSpecial),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔁 Confirm password
                  _buildModernTextField(
                    controller: confirmController,
                    hintText: 'Confirm Password',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    hidePassword: hideConfirm,
                    onPasswordToggle: () {
                      setState(() => hideConfirm = !hideConfirm);
                    },
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 8),

                  // Password match indicator
                  if (confirmController.text.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          passwordsMatch
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: passwordsMatch
                              ? AppTheme.auroraBlue
                              : Colors.grey[400],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          passwordsMatch
                              ? 'Passwords match'
                              : "Passwords don't match",
                          style: TextStyle(
                            color: passwordsMatch
                                ? AppTheme.auroraBlue
                                : Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),

                  // 🚀 Register Button
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
                          onTap: loading || !isFormValid ? null : register,
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
                                    'Create Account',
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
    ValueChanged<String>? onChanged,
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
        onChanged: onChanged,
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
