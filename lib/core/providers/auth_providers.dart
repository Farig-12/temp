import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

// Login provider - takes email and password as parameters
final loginProvider = FutureProvider.family<UserCredential, LoginParams>(
  (ref, params) async {
    final userCredential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: params.email.trim(),
      password: params.password.trim(),
    );
    return userCredential;
  },
);

// User role provider - gets the role from Firestore based on user ID
final userRoleProvider = FutureProvider.family<String, String>(
  (ref, uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    if (!doc.exists) throw Exception("User record not found!");
    return doc.data()?['role'] ?? 'user';
  },
);

// Login result provider that combines login and role check
final loginWithRoleProvider = FutureProvider.family<LoginResult, LoginParams>(
  (ref, params) async {
    try {
      // Get login result
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: params.email.trim(),
        password: params.password.trim(),
      );

      final uid = userCredential.user!.uid;

      // Check in Users collection first
      var doc =
          await FirebaseFirestore.instance.collection('Users').doc(uid).get();

      if (doc.exists) {
        final role = doc.data()?['role'] ?? 'user';
        return LoginResult(
          userCredential: userCredential,
          role: role,
          uid: uid,
        );
      }

      // Check in Mechanics collection
      doc = await FirebaseFirestore.instance
          .collection('Mechanics')
          .doc(uid)
          .get();

      if (doc.exists) {
        final approved = doc.data()?['approved'] ?? false;

        // Check if mechanic is approved
        if (!approved) {
          // Sign out the user immediately
          await FirebaseAuth.instance.signOut();
          throw LoginException(
            'not-approved',
            'Your account is pending approval. Please check your email for updates.',
          );
        }

        final role = doc.data()?['role'] ?? 'mechanic';
        return LoginResult(
          userCredential: userCredential,
          role: role,
          uid: uid,
        );
      }

      throw Exception("User record not found!");
    } on FirebaseAuthException catch (e) {
      throw LoginException(e.code, e.message ?? 'Login failed');
    } catch (e) {
      if (e is LoginException) rethrow;
      throw LoginException('unknown', e.toString());
    }
  },
);

// Classes for type safety
class LoginParams {
  final String email;
  final String password;

  LoginParams({required this.email, required this.password});
}

class LoginResult {
  final UserCredential userCredential;
  final String role;
  final String uid;

  LoginResult({
    required this.userCredential,
    required this.role,
    required this.uid,
  });
}

class LoginException implements Exception {
  final String code;
  final String message;

  LoginException(this.code, this.message);

  @override
  String toString() => 'LoginException: $code - $message';
}

// Signup provider for user registration
final signupProvider = FutureProvider.family<UserCredential, SignupParams>(
  (ref, params) async {
    try {
      // Create user in Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: params.email.trim(),
        password: params.password.trim(),
      );

      final uid = userCredential.user!.uid;
      final storageService = StorageService();
      String? profilePicUrl;

      if (params.profileImageFile != null) {
        profilePicUrl = await storageService.uploadProfileImage(
          params.profileImageFile!,
        );
      }

      // Store user info in Firestore with role "user"
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'Name': params.name.trim(),
        'Phone': params.phone.trim(),
        'Email': params.email.trim(),
        'role': 'user',
        'created_at': FieldValue.serverTimestamp(),
        'profilePicUrl': profilePicUrl,
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw SignupException(e.code, e.message ?? 'Signup failed');
    } catch (e) {
      throw SignupException('unknown', e.toString());
    }
  },
);

// Classes for signup
class SignupParams {
  final String name;
  final String phone;
  final String email;
  final String password;
  final File? profileImageFile;

  SignupParams({
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
    this.profileImageFile,
  });
}

class SignupException implements Exception {
  final String code;
  final String message;

  SignupException(this.code, this.message);

  @override
  String toString() => 'SignupException: $code - $message';
}

// Forgot Password - Send reset email
final sendPasswordResetEmailProvider =
    FutureProvider.family<void, String>((ref, email) async {
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim(),
    );
  } on FirebaseAuthException catch (e) {
    throw PasswordResetException(
        e.code, e.message ?? 'Failed to send reset email');
  } catch (e) {
    throw PasswordResetException('unknown', e.toString());
  }
});

// Verify password reset code (action code from email link)
final verifyPasswordResetCodeProvider =
    FutureProvider.family<String, String>((ref, actionCode) async {
  try {
    // Verify the action code is valid
    await FirebaseAuth.instance.verifyPasswordResetCode(actionCode);
    return actionCode;
  } on FirebaseAuthException catch (e) {
    throw PasswordResetException(
        e.code, e.message ?? 'Invalid or expired reset code');
  } catch (e) {
    throw PasswordResetException('unknown', e.toString());
  }
});

// Confirm password reset with action code and new password
final confirmPasswordResetProvider =
    FutureProvider.family<void, ConfirmPasswordResetParams>(
        (ref, params) async {
  try {
    await FirebaseAuth.instance.confirmPasswordReset(
      code: params.actionCode,
      newPassword: params.newPassword.trim(),
    );
  } on FirebaseAuthException catch (e) {
    throw PasswordResetException(
        e.code, e.message ?? 'Failed to reset password');
  } catch (e) {
    throw PasswordResetException('unknown', e.toString());
  }
});

// Classes for password reset
class ConfirmPasswordResetParams {
  final String actionCode;
  final String newPassword;

  ConfirmPasswordResetParams({
    required this.actionCode,
    required this.newPassword,
  });
}

class PasswordResetException implements Exception {
  final String code;
  final String message;

  PasswordResetException(this.code, this.message);

  @override
  String toString() => 'PasswordResetException: $code - $message';
}

// Mechanic Signup provider
final mechanicSignupProvider =
    FutureProvider.family<UserCredential, MechanicSignupParams>(
  (ref, params) async {
    try {
      // Create mechanic in Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: params.email.trim(),
        password: params.password.trim(),
      );

      final uid = userCredential.user!.uid;
      final storageService = StorageService();
      String? idCardUrl;

      // Upload ID card image to Supabase
      if (params.idCardImageFile != null) {
        idCardUrl = await storageService.uploadMechanicIdCard(
          params.idCardImageFile!,
        );
      }

      // Store mechanic info in Firestore Mechanics collection
      await FirebaseFirestore.instance.collection('Mechanics').doc(uid).set({
        'Name': params.name.trim(),
        'Email': params.email.trim(),
        'Phone': params.phone.trim(),
        'idCardUrl': idCardUrl,
        'role': 'mechanic',
        'created_at': FieldValue.serverTimestamp(),
        'approved': false, // Default to not approved
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw SignupException(e.code, e.message ?? 'Mechanic signup failed');
    } catch (e) {
      throw SignupException('unknown', e.toString());
    }
  },
);

// Classes for mechanic signup
class MechanicSignupParams {
  final String name;
  final String phone;
  final String email;
  final String password;
  final File? idCardImageFile;

  MechanicSignupParams({
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
    this.idCardImageFile,
  });
}
