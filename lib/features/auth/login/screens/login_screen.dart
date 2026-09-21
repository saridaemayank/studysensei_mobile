import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/common/widgets/sensei_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isNavigating = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32.0),
                // Logo and Welcome Text
                Column(
                  children: [
                    // App logo with rounded corners
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 90,
                        width: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Text('StudySensei', style: AppTypography.cardTitle),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome back.',
                      style: AppTypography.pageTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Show. Understand. Learn.',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 40.0),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip:
                          _obscurePassword ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8.0),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _sendPasswordResetEmail,
                    child: Text(
                      'Forgot Password?',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),

                SenseiPrimaryButton(
                    text: 'Login',
                    onPressed: _submitForm,
                    isLoading: _isLoading),
                const SizedBox(height: 24.0),

                // Sign Up Link
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_isLoading || _isNavigating) return;
                        _isNavigating = true;
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pushReplacementNamed('/register');
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontFamily: 'SubHeading',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset password.')),
      );
      return;
    }

    final emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailPattern.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'user-not-found' => 'No user found for that email.',
        'invalid-email' => 'The email address is not valid.',
        _ => 'Could not send reset email. Please try again.',
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading || _isNavigating) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the UserProvider instance
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Sign in using UserProvider
      await userProvider.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      _isNavigating = true;
      FocusScope.of(context).unfocus();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';

      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Invalid email or password.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many failed attempts. Please try again later.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
