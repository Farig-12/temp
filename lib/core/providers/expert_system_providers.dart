import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

final expertSystemQuestionsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not logged in');
  }

  final token = await user.getIdToken();
  if (token == null) {
    throw Exception('Failed to get authentication token');
  }

  final response = await http.get(
    Uri.parse(ApiConfig.getEndpoint('expert-system/questions')),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  ).timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      throw Exception('Request timeout while loading expert-system questions');
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
        'Failed to load questions: ${response.statusCode} - ${response.body}');
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
});

final expertSystemDiagnoseProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>(
  (ref, payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }

    final response = await http
        .post(
      Uri.parse(ApiConfig.getEndpoint('expert-system/diagnose')),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    )
        .timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Request timeout while running diagnosis');
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to diagnose: ${response.statusCode} - ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  },
);

final expertSystemFeedbackProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>(
  (ref, payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }

    final response = await http
        .post(
      Uri.parse(ApiConfig.getEndpoint('expert-system/feedback')),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    )
        .timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Request timeout while saving expert-system feedback');
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to save feedback: ${response.statusCode} - ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  },
);
