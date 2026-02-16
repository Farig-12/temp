import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
//import 'package:go_router/go_router.dart';
import 'package:mendlify/core/route/route_names.dart';
import 'package:mendlify/core/utils/image_resources.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/widgets/app_image.dart';
import 'package:mendlify/shared/widgets/app_svg.dart';
import 'package:mendlify/shared/widgets/app_text_form_field.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/providers/auth_providers.dart';
import 'dart:io';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();

    // Listen to auth state changes; logout handling
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        // User logged out
        _emailController.clear();
        _passwordController.clear();
        _emailFocusNode.unfocus();
        _passwordFocusNode.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          exit(0);
        }
      },
      child: AppBackground(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const AppImage(
                          path: appLoginBackgroundPath,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 70,
                          left: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, Welcome Back!',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(230),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                'Login',
                                style: TextStyle(
                                  color: appMainTextColor,
                                  fontSize: 60,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Form Section ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        AppTextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          hint: 'Email',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: appTextColor,
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 20),
                        AppTextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          hint: 'Password',
                          obscureText: _hidePassword,
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: appTextColor,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: appTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              route.push(
                                  getRoutePath(forgotPasswordEnterEmailRoute));
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: appTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() => _isLoading = true);

                                    try {
                                      final loginParams = LoginParams(
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                      );

                                      final loginResult = await ref.read(
                                        loginWithRoleProvider(loginParams)
                                            .future,
                                      );

                                      print(
                                          "User logged in: ${loginResult.userCredential.user?.email}, role: ${loginResult.role}");

                                      if (loginResult.role == 'admin') {
                                        route.push(getRoutePath(singUpRoute));
                                      } else if (loginResult.role == 'user') {
                                        route.push(getRoutePath(homeRoute));
                                      } else if (loginResult.role ==
                                          'mechanic') {
                                        route.push(
                                            getRoutePath(mechanicHomeRoute));
                                      }
                                    } on LoginException catch (e) {
                                      // Handle the approval pending case
                                      if (e.code == 'not-approved') {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: appCardColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title: const Row(
                                              children: [
                                                Icon(
                                                  Icons.pending_outlined,
                                                  color: Colors.orange,
                                                  size: 32,
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  'Approval Pending',
                                                  style: TextStyle(
                                                    color: appMainTextColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: const Text(
                                              'Your mechanic account is pending approval. Please check your email for updates from our admin team.',
                                              style: TextStyle(
                                                  color: appTextColor),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text(
                                                  'OK',
                                                  style: TextStyle(
                                                    color: appButtonColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(e.message),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      // Don't clear fields for LoginException,
                                      // user might want to retry
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text("Login Denied!")),
                                      );
                                      print(e.toString());
                                    } finally {
                                      setState(() => _isLoading = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appButtonColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Create An Account ",
                              style: TextStyle(color: appTextColor),
                            ),
                            GestureDetector(
                              onTap: () {
                                route.push(getRoutePath(choiceRoute));
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: appButtonColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildSocialButton({required String imagePath}) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(24),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: appSocialColor,
        child: AppSvg(path: imagePath, width: 24, height: 24),
      ),
    );
  }
}
