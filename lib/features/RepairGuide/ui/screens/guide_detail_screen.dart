import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/core/providers/guides_providers.dart';
import 'package:mendlify/core/providers/home_providers.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/models/guide.dart';
import 'package:mendlify/shared/models/post.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class GuideDetailScreen extends ConsumerStatefulWidget {
  final String? guideId;

  const GuideDetailScreen({super.key, this.guideId});

  @override
  ConsumerState<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends ConsumerState<GuideDetailScreen> {
  late final TextEditingController _commentController;
  String? _actualGuideId;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    // Get guideId from widget or from route extra
    _actualGuideId = widget.guideId;
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

  Future<void> _openYoutubeLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      throw Exception('Invalid YouTube link');
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception('Could not open YouTube link');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || _actualGuideId == null) {
      return;
    }
    setState(() {
      _isPosting = true;
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

      await ref.read(addGuideCommentProvider({
        'guideId': _actualGuideId!,
        'comment': _commentController.text.trim(),
        if (username != null) 'username': username,
      }).future);

      // Invalidate ALL guides; immediately refresh
      ref.invalidate(guideProvider(_actualGuideId!));
      ref.invalidate(guideStateProvider(_actualGuideId!));
      ref.invalidate(allGuidesProvider);
      ref.invalidate(myGuidesProvider);

      // Clear the comment field
      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  bool _isLikedByCurrentUser(Guide guide) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;
    return guide.likes.any((like) => like.userId == currentUserId);
  }

  Future<void> _toggleLike() async {
    if (_actualGuideId == null) return;

    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      final guideNotifier =
          ref.read(guideStateProvider(_actualGuideId!).notifier);
      final guideState = ref.read(guideStateProvider(_actualGuideId!));

      //update the UI
      final updatedLikes = List<Like>.from(guideState.likes);
      if (_isLikedByCurrentUser(guideState)) {
        updatedLikes.removeWhere((like) => like.userId == currentUserId);
      } else {
        updatedLikes.add(Like(userId: currentUserId, likedAt: DateTime.now()));
      }

      guideNotifier.updateLikes(updatedLikes);

      // Call backend
      await ref.read(toggleGuideLikeProvider(_actualGuideId!).future);

      // Invalidate ALL guides; immediately refresh
      ref.invalidate(guideProvider(_actualGuideId!));
      ref.invalidate(allGuidesProvider);
      ref.invalidate(myGuidesProvider);
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

  Widget _buildCard(Widget child) {
    return Card(
      elevation: 5,
      color: appCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildProblemDetailsCardContent(Guide guide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: guide.title,
          subtitle:
              "Posted by ${guide.username} • ${_formatDate(guide.createdAt)}",
          showAvatar: true,
          userId: guide.userId,
          displayName: guide.username,
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Problem Details', appButtonColor),
        _buildDetailSection(
          'Description:',
          guide.description,
        ),
      ],
    );
  }

  Widget _buildSolutionAndStatsCardContent(
      Guide guide, bool isLiked, int likesCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Solution Provided', appButtonColor),
        if (guide.steps.isNotEmpty) ...[
          _buildDetailSection(
            'Diagnosis:',
            guide.steps,
          ),
          const Divider(color: Colors.white24, height: 30, thickness: 1),
        ],
        _buildDetailSection(
          'Fix:',
          guide.solution,
        ),
        if (guide.partsTools != null && guide.partsTools!.isNotEmpty) ...[
          const Divider(color: Colors.white24, height: 30, thickness: 1),
          _buildDetailSection(
            'Parts/Tools:',
            guide.partsTools!,
          ),
        ],
        const SizedBox(height: 15),
        if (guide.cost != null && guide.cost!.isNotEmpty)
          _buildStatRow('Cost:', guide.cost!),
        if (guide.youtubeLink != null && guide.youtubeLink!.isNotEmpty) ...[
          const Divider(color: Colors.white24, height: 30, thickness: 1),
          _buildYoutubeLinkSection(guide.youtubeLink!),
        ],
        const Divider(color: Colors.white24, height: 30, thickness: 1),
        Row(
          children: [
            GestureDetector(
              onTap: _toggleLike,
              child: Icon(
                isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                color: isLiked ? appButtonColor : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$likesCount',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 15),
            const Icon(Icons.comment_outlined, color: Colors.white70, size: 24),
            const SizedBox(width: 8),
            Text(
              '${guide.comments.length}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildImageGallery(List<String> imageUrls) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Images', appButtonColor),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrls[index],
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey.withOpacity(0.3),
                      child: const Icon(Icons.image_outlined,
                          size: 50, color: Colors.white54),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExtraRecommendationCardContent(Guide guide) {
    if (guide.mechanicRecommendation == null ||
        guide.mechanicRecommendation!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Extra', appButtonColor),
        _buildDetailSection(
          'Mechanic Recommendation:',
          guide.mechanicRecommendation!,
        ),
      ],
    );
  }

  Widget _buildYoutubeLinkSection(String youtubeLink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Video', appButtonColor),
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            try {
              await _openYoutubeLink(youtubeLink);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not open video: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: appMainTextColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: appButtonColor.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.play_circle_fill, color: appButtonColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Watch on YouTube',
                    style: TextStyle(
                      color: appMainTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.open_in_new, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required String title,
    required String subtitle,
    bool showAvatar = false,
    String? userId,
    String? displayName,
  }) {
    return Row(
      children: [
        if (showAvatar)
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: _UserAvatar(
              userId: userId ?? '',
              displayName: displayName ?? 'U',
              size: 50,
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: appMainTextColor,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: appTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: Colors.white70),
            children: [
              TextSpan(
                text: '$title ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: appMainTextColor,
                ),
              ),
              TextSpan(text: content),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: appMainTextColor,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(Guide guide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Comments', appButtonColor),
        if (guide.comments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text(
              'No comments yet. Be the first to comment!',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          )
        else
          ...guide.comments
              .map((comment) => _buildCommentTile(comment))
              .toList(),
      ],
    );
  }

  Widget _buildCommentTile(Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserAvatar(
            userId: comment.userId,
            displayName: comment.username,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: appMainTextColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: appMainTextColor,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ' • ${_formatDate(comment.commentedAt)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.comment,
                    style: const TextStyle(
                      color: appMainTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputBar() {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.transparent,
      child: SafeArea(
        child: Row(
          children: [
            _UserAvatar(
              userId: user?.uid ?? '',
              displayName: user?.displayName ?? 'U',
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: appTextColor.withOpacity(0.5)),
                    filled: true,
                    fillColor: appCardColor.withOpacity(0.65),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          BorderSide(color: appTextColor.withOpacity(0.25)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          BorderSide(color: appTextColor.withOpacity(0.25)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                      borderSide: BorderSide(color: appButtonColor),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  style: const TextStyle(color: appMainTextColor),
                  onSubmitted: (_) => _addComment(),
                  enabled: !_isPosting,
                ),
              ),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: _isPosting ? null : _addComment, // Disable while posting
              child: _isPosting
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(appButtonColor),
                      ),
                    )
                  : const Icon(Icons.send, color: appButtonColor, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_actualGuideId == null) {
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: appMainTextColor),
              onPressed: () {
                ref.read(goRouterProvider).pop();
              },
            ),
            title: const Text(
              'Repair Guide',
              style: TextStyle(
                color: appMainTextColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: const Center(
            child: Text(
              'Guide ID not found',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    // Use guideStateProvider for reactive updates (it handles loading/error internally)
    final guideStateAsync = ref.watch(guideProvider(_actualGuideId!));
    final guideState = ref.watch(guideStateProvider(_actualGuideId!));

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
            'Repair Guide',
            style: TextStyle(
              color: appMainTextColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: guideStateAsync.when(
          data: (_) {
            //reactive updates
            final currentUser = FirebaseAuth.instance.currentUser;
            final isLiked =
                guideState.likes.any((like) => like.userId == currentUser?.uid);
            final likesCount = guideState.likes.length;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildCard(
                              _buildProblemDetailsCardContent(guideState)),
                          const SizedBox(height: 16),
                          _buildCard(_buildSolutionAndStatsCardContent(
                              guideState, isLiked, likesCount)),
                          if (guideState.imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildCard(
                                _buildImageGallery(guideState.imageUrls)),
                          ],
                          if (guideState.mechanicRecommendation != null &&
                              guideState
                                  .mechanicRecommendation!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildCard(_buildExtraRecommendationCardContent(
                                guideState)),
                          ],
                          const SizedBox(height: 16),
                          _buildCard(_buildCommentsSection(guideState)),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildCommentInputBar(),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(appButtonColor),
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading guide: ${error.toString()}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(guideProvider(_actualGuideId!));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appButtonColor,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
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
