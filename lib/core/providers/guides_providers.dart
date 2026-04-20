import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/guide.dart';
import '../../shared/models/post.dart';
import 'home_providers.dart';
import '../config/api_config.dart';

// Create guide provider
final createGuideProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, guideData) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not logged in');
  }

  final token = await user.getIdToken();
  if (token == null) {
    throw Exception('Failed to get authentication token');
  }

  final requestBody = Map<String, dynamic>.from(guideData);
  requestBody['status'] = requestBody['status'] ?? 'pending';

  final response = await http
      .post(
    Uri.parse(ApiConfig.getEndpoint("guides")),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode(requestBody),
  )
      .timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      throw Exception('Request timeout: Guide creation took too long');
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
        "Failed to create guide: ${response.statusCode} - ${response.body}");
  }
});

// Toggle like provider for guides
final toggleGuideLikeProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, guideId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not logged in');

  final token = await user.getIdToken();
  if (token == null) throw Exception('Failed to get auth token');

  final response = await http.post(
    Uri.parse(ApiConfig.getEndpoint("guides/$guideId/like")),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
        "Failed to toggle like: ${response.statusCode} - ${response.body}");
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
});

// Add comment provider for guides
final addGuideCommentProvider =
    FutureProvider.family<void, Map<String, String>>((ref, params) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not logged in');
  }

  final token = await user.getIdToken();
  if (token == null) {
    throw Exception('Failed to get authentication token');
  }

  final guideId = params['guideId']!;
  final comment = params['comment']!;
  final username = params['username'];

  final response = await http
      .post(
    Uri.parse(ApiConfig.getEndpoint("guides/$guideId/comment")),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "comment": comment,
      "status": params['status'] ?? 'pending',
      if (username != null && username.isNotEmpty) "username": username,
    }),
  )
      .timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      throw Exception('Request timeout: Comment creation took too long');
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
        "Failed to add comment: ${response.statusCode} - ${response.body}");
  }
});

// My guides provider - gets guides created by the current user
final myGuidesProvider = FutureProvider<List<Guide>>(
  (ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }

    final response = await http.get(
      Uri.parse(ApiConfig.getEndpoint("guides/my")),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
      return jsonList
          .map((json) {
            final guideJson = json as Map<String, dynamic>;
            return Guide.fromJson(guideJson);
          })
          .where((guide) =>
              guide.status == 'verified' || guide.status == 'pending')
          .toList();
    } else {
      throw Exception(
          "Failed to fetch my guides: ${response.statusCode} - ${response.body}");
    }
  },
);

// Provider to get all guides (with optional search)
final allGuidesProvider = FutureProvider.family<List<Guide>, String?>(
  (ref, searchQuery) async {
    // Get current user directly instead of watching stream to avoid race conditions
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }

    // Build URL with optional search parameter
    final uri = Uri.parse(ApiConfig.getEndpoint("guides")).replace(
      queryParameters: searchQuery != null && searchQuery.isNotEmpty
          ? {'search': searchQuery}
          : null,
    );

    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
      return jsonList
          .map((json) {
            final guideJson = json as Map<String, dynamic>;
            return Guide.fromJson(guideJson);
          })
          .where((guide) =>
              guide.status == 'verified' || guide.status == 'pending')
          .toList();
    } else {
      throw Exception(
          "Failed to fetch guides: ${response.statusCode} - ${response.body}");
    }
  },
);

// Provider to get a single guide by ID
final guideProvider = FutureProvider.family<Guide, String>(
  (ref, guideId) async {
    if (guideId.isEmpty) {
      throw Exception('Guide ID cannot be empty');
    }

    // Get current user directly instead of watching stream to avoid race conditions
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }

    final response = await http.get(
      Uri.parse(ApiConfig.getEndpoint("guides/$guideId")),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Guide.fromJson(json);
    } else {
      throw Exception(
          "Failed to fetch guide: ${response.statusCode} - ${response.body}");
    }
  },
);

// Guide state notifier
class GuideNotifier extends StateNotifier<Guide> {
  GuideNotifier(Guide guide) : super(guide);

  void updateLikes(List<Like> newLikes) {
    state = state.copyWith(likes: newLikes);
  }

  void updateComments(List<Comment> newComments) {
    state = state.copyWith(comments: newComments);
  }
}

// Use a family provider for different guides
final guideStateProvider =
    StateNotifierProvider.family<GuideNotifier, Guide, String>((ref, guideId) {
  final guideAsync = ref.watch(guideProvider(guideId));
  return guideAsync.when(
    data: (guide) => GuideNotifier(guide),
    loading: () => throw Exception('Guide is loading...'),
    error: (err, st) => throw err,
  );
});
