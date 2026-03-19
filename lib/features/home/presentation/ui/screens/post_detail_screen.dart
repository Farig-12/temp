import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/core/providers/home_providers.dart';
import 'package:mendlify/core/providers/posts_providers.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/models/post.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/shared/widgets/app_text_form_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, this.postId});

  final String? postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  bool _isLikedByCurrentUser(Post post) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;
    return post.likes.any((like) => like.userId == currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.postId;

    if (postId == null || postId.isEmpty) {
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Post ID not provided',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  'Post ID value: ${postId ?? "null"}',
                  style: const TextStyle(color: appTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final postAsync = ref.watch(postProvider(postId));

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.only(top: 20.0, left: 16.0, right: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: appMainTextColor),
                    onPressed: () {
                      ref.read(goRouterProvider).pop();
                    },
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Post',
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
            Expanded(
              child: postAsync.when(
                data: (post) {
                  final postState = ref.watch(postStateProvider(post.id));
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: appCardColor,
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _UserAvatar(
                                    userId: post.userId,
                                    displayName: post.username,
                                    size: 50,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.username,
                                          style: const TextStyle(
                                            color: appMainTextColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(post.createdAt),
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
                              Text(
                                post.content,
                                style: const TextStyle(
                                  color: appMainTextColor,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      try {
                                        final currentUserId = FirebaseAuth
                                            .instance.currentUser!.uid;

                                        final postNotifier = ref.read(
                                            postStateProvider(post.id)
                                                .notifier);
                                        final postState = ref
                                            .read(postStateProvider(post.id));

                                        // update the UI
                                        final updatedLikes =
                                            List<Like>.from(postState.likes);
                                        if (_isLikedByCurrentUser(postState)) {
                                          updatedLikes.removeWhere((like) =>
                                              like.userId == currentUserId);
                                        } else {
                                          updatedLikes.add(Like(
                                              userId: currentUserId,
                                              likedAt: DateTime.now()));
                                        }

                                        postNotifier.updateLikes(updatedLikes);

                                        // Call backend
                                        await ref.read(
                                            toggleLikeProvider(post.id).future);

                                        ref.invalidate(postProvider(post.id));
                                        //ref.invalidate(allPostsProvider);
                                        //ref.invalidate(myPostsProvider);
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Error: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isLikedByCurrentUser(postState)
                                              ? Icons.thumb_up
                                              : Icons.thumb_up_outlined,
                                          color:
                                              _isLikedByCurrentUser(postState)
                                                  ? appButtonColor
                                                  : appTextColor,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          postState.likes.length.toString(),
                                          style: const TextStyle(
                                              color: appTextColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Icon(Icons.chat_bubble_outline,
                                      color: appTextColor, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    post.comments.length.toString(),
                                    style: const TextStyle(color: appTextColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Comments',
                          style: TextStyle(
                            color: appMainTextColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (post.comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No comments yet',
                              style: TextStyle(color: appTextColor),
                            ),
                          )
                        else
                          ListView.builder(
                            itemCount: post.comments.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final comment = post.comments[index];
                              return _CommentTile(
                                userId: comment.userId,
                                author: comment.username,
                                date: _formatDate(comment.commentedAt),
                                comment: comment.comment,
                              );
                            },
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading post',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          ref.invalidate(postProvider(postId));
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _AddCommentBar(controller: _commentController, postId: postId),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final String userId;
  final String author;
  final String date;
  final String comment;

  const _CommentTile({
    required this.userId,
    required this.author,
    required this.date,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: appCardColor.withAlpha(150),
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserAvatar(
            userId: userId,
            displayName: author,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        color: appMainTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(
                        color: appTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment,
                  style: const TextStyle(
                    color: appMainTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCommentBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String postId;
  const _AddCommentBar({required this.controller, required this.postId});

  @override
  ConsumerState<_AddCommentBar> createState() => _AddCommentBarState();
}

class _AddCommentBarState extends ConsumerState<_AddCommentBar> {
  late final FocusNode _commentFocusNode;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _commentFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0).copyWith(
        bottom: MediaQuery.of(context).padding.bottom + 12.0,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: appCardColor, width: 1.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _UserAvatar(
            userId: currentUser?.uid ?? '',
            displayName: currentUser?.displayName ?? 'U',
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppTextFormField(
              controller: widget.controller,
              focusNode: _commentFocusNode,
              hint: 'Add a comment...',
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 24,
            backgroundColor: appButtonColor,
            child: _isPosting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 22),
                    onPressed: () async {
                      if (widget.controller.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a comment'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _isPosting = true; // start loading
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

                        await ref.read(addCommentProvider({
                          'postId': widget.postId,
                          'comment': widget.controller.text.trim(),
                          if (username != null) 'username': username,
                        }).future);

                        widget.controller.clear();

                        ref.invalidate(postProvider(widget.postId));
                        ref.invalidate(allPostsProvider);
                        ref.invalidate(myPostsProvider);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Comment added successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() {
                          _isPosting = false; // stop loading
                        });
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends ConsumerWidget {
  final String userId;
  final String displayName;
  final double size;

  const _UserAvatar({
    required this.userId,
    required this.displayName,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider(userId));

    return ClipOval(
      child: userProfileAsync.when(
        data: (data) {
          final profileUrl = data['profilePicUrl'] as String?;

          if (profileUrl != null && profileUrl.isNotEmpty) {
            return Image.network(
              profileUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading profile image: $error');
                return _DefaultAvatar(displayName: displayName, size: size);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _LoadingAvatar(size: size);
              },
            );
          }
          return _DefaultAvatar(displayName: displayName, size: size);
        },
        loading: () => _LoadingAvatar(size: size),
        error: (error, stackTrace) {
          debugPrint('Error loading user profile: $error');
          return _DefaultAvatar(displayName: displayName, size: size);
        },
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  final String displayName;
  final double size;

  const _DefaultAvatar({required this.displayName, this.size = 50});

  @override
  Widget build(BuildContext context) {
    final initials =
        displayName.isNotEmpty ? displayName.trim()[0].toUpperCase() : 'U';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LoadingAvatar extends StatelessWidget {
  final double size;

  const _LoadingAvatar({this.size = 50});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.grey,
        ),
      ),
    );
  }
}
