import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filePath.substring(lastDot);
  }

  /// Get MIME type based on file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }

  /// Upload a single image file to Supabase Storage
  /// Returns the download URL of the uploaded image
  Future<String> uploadImage(
    File imageFile,
    String folder, {
    String bucket = 'guideImages',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Create a unique filename
      final String extension = _getFileExtension(imageFile.path);
      final String fileName =
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final String filePath = '$folder/$fileName';

      // Upload the file to Supabase Storage
      //final fileBytes = await imageFile.readAsBytes();
      final supabase = Supabase.instance.client;
      final mimeType = _getMimeType(extension);

      await supabase.storage.from(bucket).upload(
            filePath,
            imageFile,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );

      // Get the public URL
      final String downloadUrl =
          supabase.storage.from(bucket).getPublicUrl(filePath);

      return downloadUrl;
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  /// Upload multiple images and return their URLs
  Future<List<String>> uploadImages(
    List<File> imageFiles,
    String folder, {
    String bucket = 'guideImages',
  }) async {
    try {
      final List<String> urls = [];

      for (final imageFile in imageFiles) {
        final url = await uploadImage(
          imageFile,
          folder,
          bucket: bucket,
        );
        urls.add(url);
      }

      return urls;
    } catch (e) {
      throw Exception('Error uploading images: $e');
    }
  }

  /// Delete an image from Supabase Storage using its URL
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract the path from the URL
      // Supabase public URLs format: https://[project].supabase.co/storage/v1/object/public/[bucket]/[path]
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the index of 'public' and get the path after the bucket name
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex == -1 || publicIndex >= pathSegments.length - 1) {
        throw Exception('Invalid Supabase Storage URL format');
      }

      // The path is everything after 'public/[bucket]/'
      final bucketName = pathSegments[publicIndex + 1];
      final filePath = pathSegments.sublist(publicIndex + 2).join('/');

      final supabase = Supabase.instance.client;
      await supabase.storage.from(bucketName).remove([filePath]);
    } catch (e) {
      throw Exception('Error deleting image: $e');
    }
  }

  /// Convenience helper for profile images bucket/folder
  Future<String> uploadProfileImage(File imageFile) {
    return uploadImage(
      imageFile,
      'profile',
      bucket: 'profilePic',
    );
  }

  /// Convenience helper for mechanic ID card images
  Future<String> uploadMechanicIdCard(File imageFile) {
    return uploadImage(
      imageFile,
      'idcards',
      bucket: 'MechanicIDCard',
    );
  }
}
