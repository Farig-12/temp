import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/core/route/route_names.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/providers/guides_providers.dart';
import 'package:mendlify/shared/models/guide.dart';
import 'package:intl/intl.dart';

class MyGuidesScreen extends ConsumerStatefulWidget {
  const MyGuidesScreen({super.key});

  @override
  ConsumerState<MyGuidesScreen> createState() => _MyGuidesScreenState();
}

class _MyGuidesScreenState extends ConsumerState<MyGuidesScreen> {
  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);

    //  myGuidesProvider which fetches only user's guides
    final guidesAsync = ref.watch(myGuidesProvider);

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
            'My Guides',
            style: TextStyle(
              color: appMainTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // --- List of Guides ---
              Expanded(
                child: guidesAsync.when(
                  data: (guides) {
                    if (guides.isEmpty) {
                      return Center(
                        child: Text(
                          'No guides available yet',
                          style: const TextStyle(
                            color: appTextColor,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(myGuidesProvider);
                      },
                      color: appButtonColor,
                      child: ListView.builder(
                        itemCount: guides.length,
                        itemBuilder: (context, index) {
                          return _GuideCard(
                            guide: guides[index],
                            onTap: () {
                              route.push(
                                getRoutePath(guideDetailRoute),
                                extra: guides[index].id,
                              );
                            },
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
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error loading guides: ${error.toString()}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(myGuidesProvider);
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
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            route.push(getRoutePath(addGuideRoute));
          },
          backgroundColor: appButtonColor,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final Guide guide;
  final VoidCallback onTap;

  const _GuideCard({
    required this.guide,
    required this.onTap,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = guide.imageUrls.isNotEmpty
        ? guide.imageUrls.first
        : 'https://placehold.co/100x100/A0B9C6/000000?text=Guide';
    final likesCount = guide.likes.length;
    final commentsCount = guide.comments.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: appCardColor,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.withOpacity(0.3),
                  child: const Icon(Icons.build, color: appMainTextColor),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    guide.title,
                    style: const TextStyle(
                      color: appMainTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Author and Date
                  Text(
                    '${guide.username} • ${_formatDate(guide.createdAt)}',
                    style: const TextStyle(
                      color: appTextColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Likes and Comments
                  Row(
                    children: [
                      const Icon(
                        Icons.thumb_up_alt,
                        color: appButtonColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$likesCount',
                        style: const TextStyle(
                          color: appTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.comment_outlined,
                        color: appTextColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$commentsCount',
                        style: const TextStyle(
                          color: appTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
