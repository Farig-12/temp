import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/features/service_request/data/models/service_request_model.dart';
import 'package:mendlify/features/service_request/data/models/bid_model.dart';
import 'package:mendlify/features/service_request/presentation/providers/service_request_provider.dart';
import 'package:mendlify/features/service_request/presentation/providers/bid_provider.dart';
import 'package:mendlify/features/service_request/presentation/providers/rating_provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class MyServiceRequestsScreen extends ConsumerWidget {
  const MyServiceRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login to view your requests'),
        ),
      );
    }

    final requestsAsync = ref.watch(userServiceRequestsProvider(user.uid));

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'My Service Requests',
            style: TextStyle(
              color: appMainTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        body: SafeArea(
          child: requestsAsync.when(
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
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(userServiceRequestsProvider(user.uid));
                },
                color: appButtonColor,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _RequestCard(request: request);
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

class _RequestCard extends ConsumerStatefulWidget {
  final ServiceRequestModel request;

  const _RequestCard({required this.request});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _hasShownRatingDialog = false;

  @override
  void didUpdateWidget(_RequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if request was just marked as completed
    if (!oldWidget.request.isCompleted &&
        widget.request.isCompleted &&
        !_hasShownRatingDialog) {
      _hasShownRatingDialog = true;
      // Show rating dialog after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showRatingDialog();
        }
      });
    }
  }

  void _showRatingDialog() async {
    if (widget.request.acceptedMechanicId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if already rated
    final ratingService = ref.read(ratingServiceProvider);
    final hasRated = await ratingService.hasUserRated(
      widget.request.acceptedMechanicId!,
      widget.request.requestId,
    );

    if (hasRated) return;

    if (!mounted) return;

    double? selectedRating;

    final shouldRate = await showDialog<double?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: appCardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Rate Mechanic',
            style: TextStyle(
              color: appMainTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How would you rate your experience with this mechanic?',
                style: TextStyle(color: appTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final rating = (index + 1).toDouble();
                  final isSelected =
                      selectedRating != null && rating <= selectedRating!;
                  return IconButton(
                    icon: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      size: 40,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedRating = rating;
                      });
                    },
                  );
                }),
              ),
              if (selectedRating != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${selectedRating!.toInt()} Star${selectedRating! > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: appMainTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(
                'Skip',
                style: TextStyle(color: appTextColor.withOpacity(0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: selectedRating != null
                  ? () => Navigator.of(dialogContext).pop(selectedRating)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: appButtonColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );

    if (shouldRate != null && mounted) {
      try {
        await ratingService.rateMechanic(
          mechanicId: widget.request.acceptedMechanicId!,
          requestId: widget.request.requestId,
          userId: user.uid,
          rating: shouldRate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for your rating!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting rating: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

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
    final categoryIcon = _getCategoryIcon(widget.request.problemCategory);
    final categoryColor = _getCategoryColor(widget.request.problemCategory);

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
            // Header
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
                        widget.request.problem,
                        style: const TextStyle(
                          color: appMainTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.request.problemCategory.toUpperCase(),
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
                  _formatTimeAgo(widget.request.createdAt),
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
              widget.request.description,
              style: TextStyle(
                color: appTextColor.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Status badge and expiration info
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        _getStatusColor(widget.request.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.request.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(widget.request.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.request.status == 'pending') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RequestExpirationTimer(
                        expiresAt: widget.request.expiresAt),
                  ),
                ],
                if (widget.request.isCompleted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'COMPLETED',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Bids section
            _BidsSection(
                requestId: widget.request.requestId, request: widget.request),

            // Action buttons for pending requests
            if (widget.request.status == 'pending') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showCancelDialog(context, ref, widget.request.requestId),
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('Cancel Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(
      BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: appCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Cancel Request?',
          style: TextStyle(
            color: appMainTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this service request? This action cannot be undone.',
          style: TextStyle(
            color: appTextColor.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'No, Keep It',
              style: TextStyle(color: appTextColor.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final service = ref.read(serviceRequestServiceProvider);
                await service.cancelServiceRequest(requestId);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'bidding':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'in-progress':
        return Colors.purple;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return appTextColor;
    }
  }
}

class _RequestExpirationTimer extends StatefulWidget {
  final DateTime expiresAt;

  const _RequestExpirationTimer({required this.expiresAt});

  @override
  State<_RequestExpirationTimer> createState() =>
      _RequestExpirationTimerState();
}

class _RequestExpirationTimerState extends State<_RequestExpirationTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Refresh to update countdown
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getRemainingTime() {
    final now = DateTime.now();
    final remaining = widget.expiresAt.difference(now);

    if (remaining.isNegative) {
      return 'Expired';
    }

    final seconds = remaining.inSeconds;
    if (seconds < 60) {
      return '${seconds}s left';
    } else {
      return '${(seconds / 60).floor()}m ${seconds % 60}s left';
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final isExpiring = remaining.inSeconds < 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isExpiring
            ? Colors.red.withOpacity(0.2)
            : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: isExpiring ? Colors.red : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            _getRemainingTime(),
            style: TextStyle(
              color: isExpiring ? Colors.red : Colors.orange,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BidsSection extends ConsumerWidget {
  final String requestId;
  final ServiceRequestModel request;

  const _BidsSection({required this.requestId, required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(bidsForRequestProvider(requestId));

    return bidsAsync.when(
      data: (bids) {
        if (bids.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appBackgroundColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: appTextColor.withOpacity(0.5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'No bids yet',
                  style: TextStyle(
                    color: appTextColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_offer,
                  color: appButtonColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Bids (${bids.length})',
                  style: const TextStyle(
                    color: appMainTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...bids.map((bid) => _BidCard(bid: bid, request: request)).toList(),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(
            color: appButtonColor,
            strokeWidth: 2,
          ),
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error loading bids',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                color: Colors.red.shade200,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BidCard extends ConsumerStatefulWidget {
  final BidModel bid;
  final ServiceRequestModel request;

  const _BidCard({required this.bid, required this.request});

  @override
  ConsumerState<_BidCard> createState() => _BidCardState();
}

class _BidCardState extends ConsumerState<_BidCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update UI every second to show live countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Refresh to update countdown
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    } else {
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    }
  }

  String _getRemainingTime(DateTime expiresAt) {
    final now = DateTime.now();
    final remaining = expiresAt.difference(now);

    if (remaining.isNegative) {
      return 'Expired';
    }

    return '${remaining.inSeconds}s left';
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = widget.bid.isExpired;
    final isPending = widget.request.status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appBackgroundColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired
              ? Colors.red.withOpacity(0.3)
              : appButtonColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Mechanic info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          color: appButtonColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.bid.mechanicName,
                          style: const TextStyle(
                            color: appMainTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          color: appTextColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.bid.mechanicPhone,
                          style: TextStyle(
                            color: appTextColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // Rating display
                    if (widget.bid.mechanicRating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < widget.bid.mechanicRating!.floor()
                                  ? Icons.star
                                  : (index < widget.bid.mechanicRating!
                                      ? Icons.star_half
                                      : Icons.star_border),
                              color: Colors.amber,
                              size: 14,
                            );
                          }),
                          const SizedBox(width: 6),
                          Text(
                            widget.bid.mechanicRating!.toStringAsFixed(1),
                            style: TextStyle(
                              color: appTextColor.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Bid amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${widget.bid.bidAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: appButtonColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatTimeAgo(widget.bid.createdAt),
                    style: TextStyle(
                      color: appTextColor.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Expiration timer (only for pending bids)
          if (widget.bid.status == 'pending' && !isExpired) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    _getRemainingTime(widget.bid.expiresAt),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.bid.message != null && widget.bid.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: appBackgroundColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.bid.message!,
                style: TextStyle(
                  color: appTextColor.withOpacity(0.8),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // Accept button (only for pending bids on pending requests)
          if (isPending && widget.bid.status == 'pending' && !isExpired) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAcceptDialog(context),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Accept This Bid'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],

          // Status badge for accepted/rejected bids
          if (widget.bid.status != 'pending') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.bid.status == 'accepted'
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.bid.status.toUpperCase(),
                style: TextStyle(
                  color: widget.bid.status == 'accepted'
                      ? Colors.green
                      : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAcceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: appCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Accept Bid?',
          style: TextStyle(
            color: appMainTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to accept this bid:',
              style: TextStyle(
                color: appTextColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: appBackgroundColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: appButtonColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        widget.bid.mechanicName,
                        style: const TextStyle(
                          color: appMainTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, color: appTextColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.bid.mechanicPhone,
                        style: TextStyle(
                          color: appTextColor.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_money,
                          color: Colors.green, size: 18),
                      Text(
                        'PKR ${widget.bid.bidAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The mechanic will be notified and will be on their way.',
              style: TextStyle(
                color: appTextColor.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: appTextColor.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Accept the bid
                final bidService = ref.read(bidServiceProvider);
                await bidService.updateBidStatus(
                  widget.request.requestId,
                  widget.bid.bidId,
                  'accepted',
                );

                // Update the service request
                final requestService = ref.read(serviceRequestServiceProvider);
                await requestService.acceptBid(
                  requestId: widget.request.requestId,
                  mechanicId: widget.bid.mechanicId,
                  bidAmount: widget.bid.bidAmount,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (context.mounted) {
                  // Show success message
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (successDialogContext) => AlertDialog(
                      backgroundColor: appCardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your mechanic is on the way!',
                            style: TextStyle(
                              color: appMainTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${widget.bid.mechanicName} has been notified and will arrive shortly.',
                            style: TextStyle(
                              color: appTextColor.withOpacity(0.8),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(successDialogContext).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appButtonColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 45),
                          ),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
