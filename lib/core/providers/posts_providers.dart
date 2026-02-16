import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/post.dart';
import 'home_providers.dart';
import '../config/api_config.dart';

// Create post provider
final createPostProvider =
    FutureProvider.family<void, String>((ref, content) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not logged in');
  }

  final token = await user.getIdToken();
  if (token == null) {
    throw Exception('Failed to get authentication token');
  }

  final response = await http.post(
    Uri.parse(ApiConfig.getEndpoint("posts")),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({"content": content}),
  );

  if (response.statusCode != 200) {
    throw Exception(
        "Failed to create post: ${response.statusCode} - ${response.body}");
  }
});

// Toggle like provider (autoDispose so each tap re-calls the API)
final toggleLikeProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, postId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not logged in');

  final token = await user.getIdToken();
  if (token == null) throw Exception('Failed to get auth token');

  final response = await http.post(
    Uri.parse(ApiConfig.getEndpoint("posts/$postId/like")),
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

// Add comment provider
final addCommentProvider =
    FutureProvider.family<void, Map<String, String>>((ref, params) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not logged in');
  }

  final token = await user.getIdToken();
  if (token == null) {
    throw Exception('Failed to get authentication token');
  }

  final postId = params['postId']!;
  final comment = params['comment']!;

  final response = await http.post(
    Uri.parse(ApiConfig.getEndpoint("posts/$postId/comment")),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({"comment": comment}),
  );

  if (response.statusCode != 200) {
    throw Exception(
        "Failed to add comment: ${response.statusCode} - ${response.body}");
  }
});

// My posts provider - gets posts created by the current user
final myPostsProvider = FutureProvider<List<Post>>(
  (ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Get token without forcing refresh
    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }

    // Call backend without UID query param
    final response = await http.get(
      Uri.parse(ApiConfig.getEndpoint("posts/my")),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
      return jsonList.map((json) {
        final postJson = json as Map<String, dynamic>;
        return Post.fromJson(postJson);
      }).toList();
    } else {
      print("My posts error: ${response.statusCode} - ${response.body}");
      throw Exception(
          "Failed to fetch my posts: ${response.statusCode} - ${response.body}");
    }
  },
);

// Provider to get all posts (depends on user ID)
final allPostsProvider = FutureProvider<List<Post>>(
  (ref) async {
    // Watch the current user ID
    final userIdAsync = ref.watch(currentUserIdProvider);

    // Get the user ID from the AsyncValue
    final userId = userIdAsync.when(
      data: (id) => id,
      loading: () => throw Exception('Loading user...'),
      error: (error, stack) => throw error,
    );

    if (userId == null) {
      throw Exception('User not logged in');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != userId) {
      throw Exception('User not logged in');
    }

    // Get token without forcing refresh to avoid clock skew issues
    // The token will be automatically refreshed if expired
    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }
    final response = await http.get(
      Uri.parse(ApiConfig.getEndpoint("posts")),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
      print('Received ${jsonList.length} posts'); // Debug log
      if (jsonList.isNotEmpty) {
        print('First post JSON: ${jsonList[0]}'); // Debug log - show first post
        print(
            'First post ID field: ${(jsonList[0] as Map<String, dynamic>)['id']}'); // Debug log
      }
      return jsonList.map((json) {
        final postJson = json as Map<String, dynamic>;
        print('Parsing post with keys: ${postJson.keys.toList()}'); // Debug log
        print('Post ID in JSON: ${postJson['id']}'); // Debug log
        return Post.fromJson(postJson);
      }).toList();
    } else {
      throw Exception("Failed to fetch posts: ${response.statusCode}");
    }
  },
);

// Provider to get a single post by ID (depends on user ID)
final postProvider = FutureProvider.family<Post, String>(
  (ref, postId) async {
    if (postId.isEmpty) {
      throw Exception('Post ID cannot be empty');
    }

    // Watch the current user ID
    final userIdAsync = ref.watch(currentUserIdProvider);

    // Get the user ID from the AsyncValue
    final userId = userIdAsync.when(
      data: (id) => id,
      loading: () => throw Exception('Loading user...'),
      error: (error, stack) => throw error,
    );

    if (userId == null) {
      throw Exception('User not logged in');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != userId) {
      throw Exception('User not logged in');
    }

    // Get token without forcing refresh to avoid clock skew issues
    // The token will be automatically refreshed if expired
    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get authentication token');
    }
    final url = ApiConfig.getEndpoint("posts/$postId");
    print('Fetching post from: $url'); // Debug log
    print('Token length: ${token.length}'); // Debug log - check if token exists
    print(
        'Token preview: ${token.length > 20 ? token.substring(0, 20) : token}...'); // Debug log

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    print('Response status: ${response.statusCode}'); // Debug log
    print('Response body: ${response.body}'); // Debug log

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Post.fromJson(json);
    } else {
      throw Exception(
          "Failed to fetch post: ${response.statusCode} - ${response.body}");
    }
  },
);

//like and unlike notifier
class PostNotifier extends StateNotifier<Post> {
  PostNotifier(Post post) : super(post);

  void updateLikes(List<Like> newLikes) {
    state = state.copyWith(likes: newLikes);
  }

  void updateComments(List<Comment> newComments) {
    state = state.copyWith(comments: newComments);
  }
}

// Use a family provider for different posts
final postStateProvider =
    StateNotifierProvider.family<PostNotifier, Post, String>((ref, postId) {
  final postAsync = ref.watch(postProvider(postId));
  return postAsync.when(
    data: (post) => PostNotifier(post),
    loading: () => throw Exception('Post is loading...'),
    error: (err, st) => throw err,
  );
});
