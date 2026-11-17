import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:medday_flow/screens/home.dart';
import 'package:medday_flow/screens/legal_view.dart';
import 'package:medday_flow/services/apple_sign_in_service.dart';
import 'package:medday_flow/utils/passkey_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isAppleLoading = false;

  final RegExp vemail = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  final RegExp hasnum = RegExp(r'[0-9]');

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();

      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

      await userCredential.user!.updateDisplayName(name);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'fullName': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // ✅ Trigger Google Password Manager and Apple Passwords save dialog
      TextInput.finishAutofillContext(shouldSave: true);

      // ✅ Cache credentials for instant Passkey verification & login
      await PasskeyAuthService().savePasskeyCredential(
        email: email,
        password: password,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Signup successful!")));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Signup failed";
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already in use.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak.';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithApple() async {
    setState(() => _isAppleLoading = true);
    try {
      final credential = await AppleSignInService.signInWithFirebase();
      if (credential == null) return; // user cancelled

      final user = credential.user;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fullName': user.displayName ?? 'Apple User',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MyHome()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Apple sign-in failed. Please try again.';
        if (e is FirebaseAuthException) {
          errorMessage = 'Apple sign-in error [${e.code}]: ${e.message ?? 'Authentication rejected by Firebase.'}';
        } else if (e is SignInWithAppleAuthorizationException) {
          errorMessage = 'Apple authorization failed: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      debugPrint('Apple sign-in error on signup: $e');
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAppleAvailable = Platform.isIOS || Platform.isMacOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                            ),
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              } else {
                                return null;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.email,
                              AutofillHints.newUsername,
                            ],
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              } else if (!vemail.hasMatch(value)) {
                                return 'Please enter a valid email address';
                              } else {
                                return null;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                            ),
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value!.length < 6) {
                                return 'Password should be atleast 6 characters long';
                              } else if (!hasnum.hasMatch(value)) {
                                return 'Password must contain a number';
                              } else {
                                return null;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              border: OutlineInputBorder(),
                            ),
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signUp(),
                            validator:
                                (value) =>
                                    value != _passwordController.text
                                        ? 'Passwords do not match'
                                        : null,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _signUp,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),

                          if (isAppleAvailable) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade400)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('OR', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade400)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 48,
                              child: _isAppleLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : SignInWithAppleButton(
                                      style: isDark
                                          ? SignInWithAppleButtonStyle.white
                                          : SignInWithAppleButtonStyle.black,
                                      borderRadius: BorderRadius.circular(8),
                                      text: 'Sign up with Apple',
                                      onPressed: _signUpWithApple,
                                    ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already have an account?"),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Login"),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          // ── App Store Review Legal & Medical Compliance Footer ──
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Center(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(text: 'By continuing, you agree to our '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => LegalView.showTermsDialog(context),
                                    ),
                                    const TextSpan(text: ' & '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => LegalView.showPrivacyPolicyDialog(context),
                                    ),
                                    const TextSpan(text: ',\nand acknowledge our '),
                                    TextSpan(
                                      text: 'Medical Disclaimer',
                                      style: const TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => LegalView.showMedicalDisclaimerDialog(context),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
