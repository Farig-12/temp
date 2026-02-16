import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/core/providers/auth_providers.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/core/utils/image_resources.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/shared/widgets/app_image.dart';
import 'package:mendlify/shared/widgets/app_text_form_field.dart';

import '../../../../../../core/route/route_names.dart';

class ForgotPasswordEnterEmailScreen extends ConsumerStatefulWidget {
  const ForgotPasswordEnterEmailScreen({super.key});

  @override
  ConsumerState<ForgotPasswordEnterEmailScreen> createState() =>
      _ForgotPasswordEnterEmailScreenState();
}

class _ForgotPasswordEnterEmailScreenState
    extends ConsumerState<ForgotPasswordEnterEmailScreen> {
  late TextEditingController _emailController;
  late FocusNode _emailFocusNode;
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _emailFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await ref.read(sendPasswordResetEmailProvider(_emailController.text.trim()).future);

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Email Sent'),
            content: Text(
              'A password reset link has been sent to ${_emailController.text.trim()}.\n\n'
              'Please check your email and click on the link to reset your password.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate to login page
                  ref.read(goRouterProvider).go(getRoutePath(loginRoute));
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send reset email. Please try again.';
        if (e is PasswordResetException) {
          if (e.code == 'user-not-found') {
            errorMessage = 'No account found with this email address.';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'Invalid email address.';
          } else {
            errorMessage = e.message;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 50),

                  // Logo Image
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: const AppImage(
                        path: appLogoPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Reset Password Header
                  const Text(
                    'Reset Password?',
                    style: TextStyle(
                      color: appMainTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your Email, we will send you a password reset link.',
                    style: TextStyle(
                      color: appTextColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Email Input Field
                  AppTextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    hint: 'Your Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 15.0, right: 10.0),
                      child: Icon(Icons.email_outlined, color: appTextColor),
                    ),
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    onSubmitted: (_) => _sendResetEmail(),
                  ),
                  const SizedBox(height: 30),

                  // Send Code Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendResetEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appButtonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18.0),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Send Reset Link',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  // Back Button
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _isSending
                        ? null
                        : () {
                            route.pop();
                          },
                    child: const Text(
                      'Back to Login',
                      style: TextStyle(color: appTextColor),
                    ),
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
