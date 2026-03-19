import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/core/utils/image_resources.dart';
import 'package:mendlify/shared/widgets/app_image.dart';
import 'package:mendlify/core/providers/posts_providers.dart';
import 'package:mendlify/shared/models/post.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../../core/route/go_router_provider.dart';
import '../../../../../core/route/route_names.dart';

class MyPostsScreen extends ConsumerStatefulWidget {
  const MyPostsScreen({super.key});

  @override
  ConsumerState<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends ConsumerState<MyPostsScreen> {
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, FocusNode> _commentFocusNodes = {};

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _commentFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  TextEditingController _getCommentController(String postId) {
    if (!_commentControllers.containsKey(postId)) {
      _commentControllers[postId] = TextEditingController();
    }
    return _commentControllers[postId]!;
  }

  FocusNode _getCommentFocusNode(String postId) {
    if (!_commentFocusNodes.containsKey(postId)) {
      _commentFocusNodes[postId] = FocusNode();
    }
    return _commentFocusNodes[postId]!;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute(s) ago';
      }
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day(s) ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  bool _isLikedByCurrentUser(Post post) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;
    return post.likes.any((like) => like.userId == currentUserId);
  }

  Future<void> _toggleLike(Post post) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      final postNotifier = ref.read(postStateProvider(post.id).notifier);
      final postState = ref.read(postStateProvider(post.id));

      //  update the UI
      final updatedLikes = List<Like>.from(postState.likes);
      if (_isLikedByCurrentUser(postState)) {
        updatedLikes.removeWhere((like) => like.userId == currentUserId);
      } else {
        updatedLikes.add(Like(userId: currentUserId, likedAt: DateTime.now()));
      }

      postNotifier.updateLikes(updatedLikes);

      // Call backend
      await ref.read(toggleLikeProvider(post.id).future);

      // Invalidate ALL posts; immediately refresh
      ref.invalidate(postProvider(post.id));
      ref.invalidate(allPostsProvider);
      ref.invalidate(myPostsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addComment(String postId) async {
    final controller = _getCommentController(postId);
    if (controller.text.trim().isEmpty) {
      return;
    }

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

      await ref.read(addCommentProvider({
        'postId': postId,
        'comment': controller.text.trim(),
        if (username != null) 'username': username,
      }).future);

      // Clear comment field
      controller.clear();
      _getCommentFocusNode(postId).unfocus();

      // Invalidate ALL posts; immediately refresh
      ref.invalidate(postProvider(postId));
      ref.invalidate(allPostsProvider);
      ref.invalidate(myPostsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);
    final postsAsync = ref.watch(myPostsProvider);

    return Scaffold(
      backgroundColor: appBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.only(top: 20.0, left: 16.0, right: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: appMainTextColor),
                      onPressed: () {
                        if (route.canPop()) {
                          route.pop();
                        }
                      },
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'My Posts',
                          style: TextStyle(
                            color: appMainTextColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: postsAsync.when(
                  data: (posts) {
                    if (posts.isEmpty) {
                      return const Center(
                        child: Text(
                          'No posts available',
                          style: TextStyle(color: appTextColor),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(myPostsProvider);
                      },
                      color: appButtonColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final postState =
                              ref.watch(postStateProvider(post.id));
                          final isLiked = _isLikedByCurrentUser(postState);
                          final commentController =
                              _getCommentController(post.id);
                          final commentFocusNode =
                              _getCommentFocusNode(post.id);
                          final showCommentInput = commentFocusNode.hasFocus;

                          return _PostCard(
                            post: postState,
                            isLiked: isLiked,
                            formatDate: _formatDate,
                            onLike: () => _toggleLike(postState),
                            onCommentTap: () {
                              commentFocusNode.requestFocus();
                            },
                            onPostTap: () {
                              route.push(
                                getRoutePath(postDetailRoute),
                                extra: post.id,
                              );
                            },
                            commentController: commentController,
                            commentFocusNode: commentFocusNode,
                            showCommentInput: showCommentInput,
                            onCommentSubmit: () => _addComment(post.id),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(appButtonColor),
                    ),
                  ),
                  error: (error, stackTrace) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error loading posts',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ref.invalidate(myPostsProvider);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20.0,
            right: 20.0,
            child: FloatingActionButton(
              onPressed: () {
                route.push(getRoutePath(createPostRoute));
              },
              backgroundColor: appButtonColor,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final bool isLiked;
  final String Function(DateTime) formatDate;
  final VoidCallback onLike;
  final VoidCallback onCommentTap;
  final VoidCallback onPostTap;
  final TextEditingController commentController;
  final FocusNode commentFocusNode;
  final bool showCommentInput;
  final VoidCallback onCommentSubmit;

  const _PostCard({
    required this.post,
    required this.isLiked,
    required this.formatDate,
    required this.onLike,
    required this.onCommentTap,
    required this.onPostTap,
    required this.commentController,
    required this.commentFocusNode,
    required this.showCommentInput,
    required this.onCommentSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: appCardColor,
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header - Clickable to go to detail
          InkWell(
            onTap: onPostTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author and Date
                  Row(
                    children: [
                      ClipOval(
                        child: AppImage(
                          path: fatimaImagePath, // Placeholder
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.username,
                              style: const TextStyle(
                                color: appMainTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatDate(post.createdAt),
                              style: const TextStyle(
                                color: appTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Post Content
                  Text(
                    post.content,
                    style: const TextStyle(
                      color: appMainTextColor,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Like and Comment Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Like Button
                InkWell(
                  onTap: onLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color: isLiked ? appButtonColor : appTextColor,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          post.likes.length.toString(),
                          style: TextStyle(
                            color: isLiked ? appButtonColor : appTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Comment Button
                InkWell(
                  onTap: onCommentTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          color: commentFocusNode.hasFocus
                              ? appButtonColor
                              : appTextColor,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          post.comments.length.toString(),
                          style: TextStyle(
                            color: commentFocusNode.hasFocus
                                ? appButtonColor
                                : appTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // View Comments Text
                InkWell(
                  onTap: onPostTap,
                  child: Text(
                    'View all comments',
                    style: TextStyle(
                      color: appButtonColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Comment Input
          if (showCommentInput)
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: appCardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: appButtonColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      focusNode: commentFocusNode,
                      style: const TextStyle(color: appMainTextColor),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: const TextStyle(color: appTextColor),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => onCommentSubmit(),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: appButtonColor),
                    onPressed: onCommentSubmit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
