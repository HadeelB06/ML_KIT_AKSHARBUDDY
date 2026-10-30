import '../theme/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/buddy_brand.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with LanguageRebuild<LoginScreen> {
  bool isLogin = true;
  bool _busy = false;
  bool obscurePassword = true;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  late AuthService auth;

  @override
  void initState() {
    super.initState();
    auth = AuthService();
  }

  // HANDLE LOGIN / REGISTER
  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (_busy) return;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText("Please enter email & password")),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (isLogin) {
        // LOGIN
        final user = await auth.login(email, password);

        if (!mounted) return;
        if (user != null) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // REGISTER
        final user = await auth.register(email, password);

        if (!mounted) return;
        if (user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: LText("Registered successfully! Please login"),
            ),
          );
          setState(() {
            isLogin = true;
          });
        }
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      const messages = {
        'invalid-credential': 'The email or password is incorrect.',
        'wrong-password': 'The email or password is incorrect.',
        'user-not-found': 'The email or password is incorrect.',
        'invalid-email': 'Enter a valid email address.',
        'email-already-in-use':
            'An account already uses this email. Try signing in.',
        'weak-password':
            'Choose a stronger password with at least six characters.',
        'too-many-requests': 'Too many attempts. Please wait and try again.',
        'network-request-failed':
            'Check your internet connection and try again.',
        'user-disabled':
            'This account is disabled. Contact your administrator.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LText(
            messages[error.code] ?? 'Sign-in is unavailable. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LText('Could not sign in. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const BuddyMark(size: 64),
                  ),
                  const SizedBox(height: 24),
                  LText(
                    isLogin ? 'Welcome to AksharBuddy' : 'Create your account',
                    style: styles.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  LText(
                    'Your next chapter starts here.',
                    style: styles.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    children: [
                      ChoiceChip(
                        label: const LText('Sign in'),
                        selected: isLogin,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => isLogin = true),
                      ),
                      ChoiceChip(
                        label: const LText('Register'),
                        selected: !isLogin,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => isLogin = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: tr('Email address'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    autofillHints: [
                      isLogin
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    decoration: InputDecoration(
                      labelText: tr('Password'),
                      suffixIcon: IconButton(
                        tooltip: obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _busy ? null : handleAuth,
                    child: LText(
                      _busy
                          ? 'Please wait…'
                          : isLogin
                          ? 'Sign in'
                          : 'Create account',
                    ),
                  ),
                  const SizedBox(height: 16),
                  LText(
                    'Your reading preferences stay saved on this device.',
                    style: styles.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
