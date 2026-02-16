import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// Current user ID provider - watches auth state changes
final currentUserIdProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
});

// User name provider - gets the user's name from Firestore (depends on user ID)
final userNameProvider = FutureProvider.family<String, String>(
  (ref, userId) async {
    final doc =
        await FirebaseFirestore.instance.collection('Users').doc(userId).get();

    return doc.data()?['Name'] ?? 'User';
  },
);

// User profile provider - gets name, phone, email and profile image url
final userProfileProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, userId) {
  // Force refresh when auth state changes
  ref.watch(currentUserIdProvider);

  if (userId.isEmpty) {
    return Stream.value({
      'name': 'User',
      'phone': '',
      'email': '',
      'profilePicUrl': null,
    });
  }

  return FirebaseFirestore.instance
      .collection('Users')
      .doc(userId)
      .snapshots()
      .map((doc) {
    final data = doc.data() ?? {};

    return {
      'name': data['Name'] ?? 'User',
      'phone': data['Phone'] ?? '',
      'email': data['Email'] ?? '',
      'profilePicUrl': data['profilePicUrl'],
    };
  });
});

// FastAPI data provider - gets data from the backend API (depends on user ID)
final fastApiDataProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, userId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != userId) {
      throw Exception('User not logged in');
    }

    // Get token without forcing refresh to avoid clock skew issues
    // The token will be automatically refreshed if expired
    final token = await user.getIdToken();
    final response = await http.get(
      Uri.parse(ApiConfig.getEndpoint("user/data")),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("FastAPI fetch failed: ${response.statusCode}");
    }
  },
);

// Combined home data provider that provides both user name and FastAPI data
final homeDataProvider = FutureProvider<HomeData>((ref) async {
  // Watch the current user ID
  final userIdAsync = ref.watch(currentUserIdProvider);

  // Wait for the user ID to be available
  final userId = await userIdAsync.when(
    data: (id) => id,
    loading: () => throw Exception('Loading user ID'),
    error: (err, stack) => throw Exception('Error fetching user ID: $err'),
  );

  if (userId == null) {
    throw Exception('User not logged in');
  }

  // Wait for both providers to complete with the current user ID
  final userName = await ref.watch(userNameProvider(userId).future);
  final fastApiData = await ref.watch(fastApiDataProvider(userId).future);

  return HomeData(
    userName: userName,
    fastApiData: fastApiData,
  );
});

// Class for type safety
class HomeData {
  final String userName;
  final Map<String, dynamic> fastApiData;

  HomeData({
    required this.userName,
    required this.fastApiData,
  });
}
