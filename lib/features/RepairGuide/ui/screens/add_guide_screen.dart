import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/providers/guides_providers.dart';
import 'package:mendlify/core/services/storage_service.dart';

class AddGuideScreen extends ConsumerStatefulWidget {
  const AddGuideScreen({super.key});

  @override
  ConsumerState<AddGuideScreen> createState() => _AddGuideScreenState();
}

class _AddGuideScreenState extends ConsumerState<AddGuideScreen> {
  // Controllers for the input fields
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _stepsController;
  late TextEditingController _solutionController;
  late TextEditingController _partsController;
  late TextEditingController _costController;
  late TextEditingController _mechanicController;

  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  List<File> _selectedImages = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _stepsController = TextEditingController();
    _solutionController = TextEditingController();
    _partsController = TextEditingController();
    _costController = TextEditingController();
    _mechanicController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _solutionController.dispose();
    _partsController.dispose();
    _costController.dispose();
    _mechanicController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages =
              pickedFiles.map((xFile) => File(xFile.path)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createGuide() async {
    // Validate required fields
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the problem'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Fetch username from Firestore to pass to backend (avoids slow backend Firestore call)
      String? username;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            username = userData?['Name'] ?? userData?['name'];
          }
        } catch (e) {
          print('Error fetching username from Firestore: $e');
          // Continue without username - backend will handle fallback
        }
      }

      // Upload images to Firebase Storage
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls =
            await _storageService.uploadImages(_selectedImages, 'guides');
      }

      // Prepare guide data
      final guideData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'steps': _stepsController.text.trim(),
        'solution': _solutionController.text.trim(),
        'parts_tools': _partsController.text.trim().isEmpty
            ? null
            : _partsController.text.trim(),
        'cost': _costController.text.trim().isEmpty
            ? null
            : _costController.text.trim(),
        'mechanic_recommendation': _mechanicController.text.trim().isEmpty
            ? null
            : _mechanicController.text.trim(),
        'image_urls': imageUrls,
        if (username != null) 'username': username,
      };

      // Create the guide
      await ref.read(createGuideProvider(guideData).future);

      // Invalidate ALL guides providers to immediately refresh
      ref.invalidate(allGuidesProvider);
      ref.invalidate(myGuidesProvider);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guide created successfully!'),
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
            content: Text('Error creating guide: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: appMainTextColor),
            onPressed: () {
              ref.read(goRouterProvider).pop();
            },
          ),
          title: const Text(
            'Add Guide',
            style: TextStyle(
              color: appMainTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: _isUploading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(appButtonColor),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title of Problem
                    _CustomInputField(
                      controller: _titleController,
                      hintText: 'Title of Problem',
                    ),

                    // Describe the Problem
                    _CustomInputField(
                      controller: _descriptionController,
                      hintText: 'Describe the Problem',
                      isMultiLine: true,
                      maxLines: 5,
                    ),

                    // Steps Taken
                    _CustomInputField(
                      controller: _stepsController,
                      hintText: 'Steps Taken to Diagnose the Problem',
                      isMultiLine: true,
                      maxLines: 5,
                    ),

                    // Solution Applied
                    _CustomInputField(
                      controller: _solutionController,
                      hintText: 'Solution Applied',
                      isMultiLine: true,
                      maxLines: 5,
                    ),

                    // Parts/Tools Used
                    _CustomInputField(
                      controller: _partsController,
                      hintText: 'Parts/Tools Used (if any)',
                      isMultiLine: true,
                      maxLines: 3,
                    ),

                    // Cost of Repair
                    _CustomInputField(
                      controller: _costController,
                      hintText: 'Cost of Repair (if any)',
                    ),

                    // Image Selection
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: InkWell(
                        onTap: _pickImages,
                        borderRadius: BorderRadius.circular(10.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 18.0, horizontal: 16.0),
                          decoration: BoxDecoration(
                            color: appCardColor,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedImages.isEmpty
                                    ? 'Add Pictures (optional)'
                                    : '${_selectedImages.length} image(s) selected',
                                style: TextStyle(
                                  color: appTextColor.withAlpha(180),
                                  fontSize: 16,
                                ),
                              ),
                              const Icon(
                                Icons.camera_alt_outlined,
                                color: appMainTextColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Display selected images
                    if (_selectedImages.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.file(
                                      _selectedImages[index],
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    if (_selectedImages.isNotEmpty) const SizedBox(height: 20),

                    // Mechanic/Shop Recommendation
                    _CustomInputField(
                      controller: _mechanicController,
                      hintText:
                          'Any trusted mechanic, shop, or source you\'d recommend?',
                    ),

                    const SizedBox(height: 32),

                    // Post Button
                    ElevatedButton(
                      onPressed: _isUploading ? null : _createGuide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appButtonColor,
                        padding: const EdgeInsets.symmetric(vertical: 18.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        elevation: 4,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Post',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

// Helper Widget
class _CustomInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isMultiLine;
  final int maxLines;

  const _CustomInputField({
    required this.controller,
    required this.hintText,
    this.isMultiLine = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        maxLines: isMultiLine ? null : 1,
        minLines: isMultiLine ? maxLines : 1,
        keyboardType:
            isMultiLine ? TextInputType.multiline : TextInputType.text,
        style: const TextStyle(color: appMainTextColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: appTextColor.withAlpha(180)),
          fillColor: appCardColor,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: isMultiLine
              ? const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0)
              : const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
        ),
      ),
    );
  }
}
