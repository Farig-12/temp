import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/widgets/app_text_form_field.dart';
import '../../../../../../core/route/go_router_provider.dart';
import '../../../../../../core/providers/home_providers.dart';

class EditPersonalInfoScreen extends ConsumerStatefulWidget {
  const EditPersonalInfoScreen({super.key});

  @override
  ConsumerState<EditPersonalInfoScreen> createState() =>
      _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState
    extends ConsumerState<EditPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameController.text = data['Name'] ?? '';
        _phoneController.text = data['Phone'] ?? '';
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _savePersonalInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .update({
        'Name': _nameController.text.trim(),
        'Phone': _phoneController.text.trim(),
      });

      // Invalidate ALL; immediately refresh
      ref.invalidate(userNameProvider(user.uid));
      ref.invalidate(fastApiDataProvider(user.uid));
      ref.invalidate(homeDataProvider);
      ref.invalidate(userProfileProvider(user.uid));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal info updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        final route = ref.read(goRouterProvider);
        if (route.canPop()) {
          route.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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

    if (!_isInitialized) {
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: appMainTextColor),
            onPressed: () {
              if (route.canPop()) {
                route.pop();
              }
            },
          ),
          title: const Text(
            'Edit Personal Info',
            style: TextStyle(
              color: appMainTextColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Update your personal information',
                    style: TextStyle(
                      color: appTextColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Name field
                  AppTextFormField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    hint: 'Name',
                    prefixIcon:
                        const Icon(Icons.person_outline, color: appTextColor),
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
                    prefixIcon:
                        const Icon(Icons.phone_outlined, color: appTextColor),
                    textInputAction: TextInputAction.done,
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
                  const SizedBox(height: 30),

                  // Info text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: appCardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: appTextColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Email cannot be changed. Profile picture can be updated from the profile tab.',
                            style: TextStyle(
                              color: appTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePersonalInfo,
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
