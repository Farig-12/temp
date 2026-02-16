import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/core/route/route_names.dart';
import 'package:mendlify/core/providers/mechanic_providers.dart';
import 'package:intl/intl.dart';

class MechanicHomeScreen extends ConsumerWidget {
  const MechanicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(goRouterProvider);
    final user = FirebaseAuth.instance.currentUser;
    final serviceRequestsAsync = ref.watch(allServiceRequestsProvider);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Client Requests',
            style: TextStyle(
              color: appMainTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: appMainTextColor),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                route.go(getRoutePath(loginRoute));
              },
            ),
          ],
        ),
        body: SafeArea(
          child: serviceRequestsAsync.when(
            data: (requests) {
              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: appTextColor.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No service requests yet',
                        style: TextStyle(
                          color: appTextColor.withOpacity(0.7),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Waiting for client requests...',
                        style: TextStyle(
                          color: appTextColor.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(allServiceRequestsProvider);
                },
                color: appButtonColor,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _ServiceRequestCard(request: request);
                  },
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: appButtonColor,
              ),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading requests',
                    style: TextStyle(
                      color: appTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: appTextColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceRequestCard extends StatelessWidget {
  final dynamic request;

  const _ServiceRequestCard({required this.request});

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'engine':
        return Icons.settings;
      case 'brakes':
        return Icons.speed;
      case 'chain':
        return Icons.link;
      case 'tire':
        return Icons.album;
      case 'electrical':
        return Icons.electrical_services;
      case 'battery':
        return Icons.battery_charging_full;
      case 'oil':
        return Icons.opacity;
      default:
        return Icons.build;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'engine':
        return Colors.orange;
      case 'brakes':
        return Colors.red;
      case 'chain':
        return Colors.blue;
      case 'tire':
        return Colors.purple;
      case 'electrical':
        return Colors.yellow;
      case 'battery':
        return Colors.green;
      case 'oil':
        return Colors.brown;
      default:
        return appButtonColor;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryIcon = _getCategoryIcon(request.problemCategory);
    final categoryColor = _getCategoryColor(request.problemCategory);

    return Card(
      color: appCardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category icon and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryIcon,
                    color: categoryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.problem,
                        style: const TextStyle(
                          color: appMainTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.problemCategory.toUpperCase(),
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimeAgo(request.createdAt),
                  style: TextStyle(
                    color: appTextColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              request.description,
              style: TextStyle(
                color: appTextColor.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Client info
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: appTextColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  request.userName,
                  style: const TextStyle(
                    color: appTextColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.phone_outlined,
                  color: appTextColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  request.userPhone,
                  style: const TextStyle(
                    color: appTextColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: appButtonColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.location.address,
                    style: const TextStyle(
                      color: appTextColor,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
