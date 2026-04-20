import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/core/utils/image_resources.dart';
import 'package:mendlify/shared/widgets/app_image.dart';
import 'package:mendlify/core/services/storage_service.dart';

import '../../../../../core/route/go_router_provider.dart';
import '../../../../../core/route/route_names.dart';
import '../../../../../core/providers/home_providers.dart';
import '../../../../../core/providers/logout_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  bool _isUpdatingImage = false;

  Future<void> _handleProfileImageUpdate({required bool remove}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      final docRef =
          FirebaseFirestore.instance.collection('Users').doc(user.uid);
      final snapshot = await docRef.get();
      final currentUrl = snapshot.data()?['profilePicUrl'] as String?;

      if (remove) {
        if (currentUrl != null && currentUrl.isNotEmpty) {
          await _storageService.deleteImage(currentUrl);
        }
        await docRef.update({'profilePicUrl': null});
      } else {
        final pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        if (pickedFile == null) {
          setState(() {
            _isUpdatingImage = false;
          });
          return;
        }

        final newUrl =
            await _storageService.uploadProfileImage(File(pickedFile.path));

        if (currentUrl != null && currentUrl.isNotEmpty) {
          await _storageService.deleteImage(currentUrl);
        }

        await docRef.update({'profilePicUrl': newUrl});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remove ? 'Profile photo removed' : 'Profile photo updated',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      ref.invalidate(userProfileProvider(user.uid));
      ref.invalidate(userNameProvider(user.uid));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: appCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(
            // Make all text white
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white),
              titleMedium: TextStyle(color: Colors.white),
            ),

            // Icons white
            iconTheme: const IconThemeData(color: Colors.white),

            // ListTile text + icon colors
            listTileTheme: const ListTileThemeData(
              iconColor: Color.fromARGB(255, 215, 46, 46),
              textColor: Colors.white,
            ),

            // InkWell ripple
            splashColor: Colors.white24,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),

                // Title
                const Text(
                  "Profile Picture",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Change profile photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleProfileImageUpdate(remove: false);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleProfileImageUpdate(remove: true);
                  },
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email ?? '';
    final userId = currentUser?.uid;

    final userProfileAsync = userId != null
        ? ref.watch(userProfileProvider(userId))
        : const AsyncValue<Map<String, dynamic>>.loading();
    final userNameAsync = userId != null
        ? ref.watch(userNameProvider(userId))
        : const AsyncValue<String>.loading();

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 340,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const AppImage(
                    path: appProfileGradientPath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 360,
                  ),
                  Positioned(
                    top: 220,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundColor: appBackgroundColor,
                          child: CircleAvatar(
                            radius: 65,
                            backgroundColor: appCardColor,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                userProfileAsync.when(
                                  data: (data) {
                                    final profilePicUrl =
                                        data['profilePicUrl'] as String?;
                                    if (profilePicUrl != null &&
                                        profilePicUrl.isNotEmpty) {
                                      return ClipOval(
                                        child: Image.network(
                                          profilePicUrl,
                                          width: 130,
                                          height: 130,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Icon(Icons.person,
                                                size: 60, color: appTextColor);
                                          },
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                color: appTextColor,
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }
                                    return const Icon(Icons.person,
                                        size: 60, color: appTextColor);
                                  },
                                  loading: () => const Icon(Icons.person,
                                      size: 60, color: appTextColor),
                                  error: (error, stack) => const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: appTextColor),
                                ),
                                if (_isUpdatingImage)
                                  Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: appButtonColor,
                                child: const Icon(
                                  Icons.edit,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(40),
                                    onTap: _isUpdatingImage
                                        ? null
                                        : _showImageOptions,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            userNameAsync.when(
              data: (userName) => Text(
                userName,
                style: const TextStyle(
                  color: appMainTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              loading: () => const Text(
                'Loading...',
                style: TextStyle(
                  color: appMainTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              error: (error, stack) => const Text(
                'User',
                style: TextStyle(
                  color: appMainTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            userProfileAsync.when(
              data: (data) {
                final phone = data['phone'] as String? ?? '';
                final email = data['email'] as String? ?? userEmail;
                final hasPhone = phone.isNotEmpty;
                final hasEmail = email.isNotEmpty;
                final subtitle = [
                  if (hasEmail) email,
                  if (hasPhone) phone,
                ].join(' | ');
                return Text(
                  subtitle.isNotEmpty ? subtitle : 'No contact info',
                  style: const TextStyle(
                    color: appTextColor,
                    fontSize: 14,
                  ),
                );
              },
              loading: () => const Text(
                'Loading contact info...',
                style: TextStyle(
                  color: appTextColor,
                  fontSize: 14,
                ),
              ),
              error: (error, stack) => const Text(
                'Contact info unavailable',
                style: TextStyle(
                  color: appTextColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  _ProfileActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit Personal Info',
                    onTap: () {
                      route.push(getRoutePath(editPersonalInfoRoute));
                    },
                  ),
                  const SizedBox(width: 16),
                  _ProfileActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit Bike Info',
                    onTap: () {
                      route.push(getRoutePath(bikeInfoRoute));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _ProfileListTile(
                    icon: Icons.menu_book_outlined,
                    label: 'My Guides',
                    onTap: () {
                      route.push(getRoutePath(myGuidesRoute));
                    },
                  ),
                  const SizedBox(height: 12),
                  _ProfileListTile(
                    icon: Icons.article_outlined,
                    label: 'My Posts',
                    onTap: () {
                      route.push(getRoutePath(myPostsRoute));
                    },
                  ),
                  const SizedBox(height: 12),
                  _ProfileListTile(
                    icon: Icons.history_outlined,
                    label: 'Diagnosis History',
                    onTap: () {
                      route.push(getRoutePath(expertSystemRoute));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Use logout provider to clear all cache
                    await ref.read(logoutProvider)();
                    // Navigate to login
                    route.go(getRoutePath(loginRoute));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appButtonColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20), // Padding at the bottom
          ],
        ),
      ),
    );
  }
}

// Helper widget for the top two buttons
class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: appCardColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: appTextColor, size: 32),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: appMainTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper widget for the list items
class _ProfileListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileListTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: appCardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: appTextColor, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: appMainTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: appTextColor, size: 16),
          ],
        ),
      ),
    );
  }
}
