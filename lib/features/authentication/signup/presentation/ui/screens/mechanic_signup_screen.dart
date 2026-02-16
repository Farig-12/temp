import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/widgets/app_text_form_field.dart';
import 'package:mendlify/core/providers/auth_providers.dart';
import '../../../../../../core/route/go_router_provider.dart';
import '../../../../../../core/route/route_names.dart';
import 'package:mendlify/core/utils/image_resources.dart';
import 'package:mendlify/shared/widgets/app_image.dart';

class MechanicSignupScreen extends ConsumerStatefulWidget {
  const MechanicSignupScreen({super.key});

  @override
  ConsumerState<MechanicSignupScreen> createState() =>
      _MechanicSignupScreenState();
}

class _MechanicSignupScreenState extends ConsumerState<MechanicSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();
  File? _idCardImageFile;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _pickIdCardImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _idCardImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_idCardImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your ID card image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final signupParams = MechanicSignupParams(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        idCardImageFile: _idCardImageFile,
      );

      await ref.read(mechanicSignupProvider(signupParams).future);

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: appCardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Registration Successful!',
              style: TextStyle(
                color: appMainTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Your mechanic account has been created successfully. Your account is pending approval. You will be notified via email once approved.',
              style: TextStyle(color: appTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  final route = ref.read(goRouterProvider);
                  route.push(getRoutePath(loginRoute));
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('SignupException: ', '')),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                              'Welcome Mechanic!',
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Sign Up',
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
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // Name field
                        AppTextFormField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          hint: 'Name',
                          prefixIcon: const Icon(Icons.person_outline,
                              color: appTextColor),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                          onChanged: (_) => _formKey.currentState?.validate(),
                        ),
                        const SizedBox(height: 20),

                        // Phone field
                        AppTextFormField(
                          controller: _phoneController,
                          focusNode: _phoneFocus,
                          hint: 'Phone',
                          prefixIcon: const Icon(Icons.phone_outlined,
                              color: appTextColor),
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (value.trim().length != 11) {
                              return 'Phone number must be 11 digits';
                            }
                            return null;
                          },
                          onChanged: (_) => _formKey.currentState?.validate(),
                        ),
                        const SizedBox(height: 20),

                        // Email field
                        AppTextFormField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          hint: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined,
                              color: appTextColor),
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          onChanged: (_) => _formKey.currentState?.validate(),
                        ),
                        const SizedBox(height: 20),

                        // Password field
                        AppTextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          hint: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: appTextColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: appTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          onChanged: (_) => _formKey.currentState?.validate(),
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password field
                        AppTextFormField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocus,
                          hint: 'Confirm your password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: appTextColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: appTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          onChanged: (_) => _formKey.currentState?.validate(),
                        ),
                        const SizedBox(height: 30),

                        // ID Card Image Picker
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: appCardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _idCardImageFile != null
                                  ? appButtonColor
                                  : appTextColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _idCardImageFile != null
                                    ? Icons.check_circle
                                    : Icons.badge_outlined,
                                size: 48,
                                color: _idCardImageFile != null
                                    ? appButtonColor
                                    : appTextColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _idCardImageFile != null
                                    ? 'ID Card Uploaded'
                                    : 'Upload ID Card',
                                style: TextStyle(
                                  color: _idCardImageFile != null
                                      ? appMainTextColor
                                      : appTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _idCardImageFile != null
                                    ? 'Tap to change'
                                    : 'Required for verification',
                                style: TextStyle(
                                  color: appTextColor.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _pickIdCardImage,
                                icon: const Icon(
                                  Icons.upload_file,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: Text(
                                  _idCardImageFile != null
                                      ? 'Change Image'
                                      : 'Choose Image',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appButtonColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Create Account button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appButtonColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Create Mechanic Account',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Sign In link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: appTextColor,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  route.push(getRoutePath(loginRoute));
                                },
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: appButtonColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
