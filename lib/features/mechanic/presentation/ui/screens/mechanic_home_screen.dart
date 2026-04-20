import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mendlify/shared/widgets/app_background.dart';
import 'package:mendlify/core/utils/theme/app_colors.dart';
import 'package:mendlify/core/route/go_router_provider.dart';
import 'package:mendlify/core/route/route_names.dart';
import 'package:mendlify/core/providers/mechanic_providers.dart';
import 'package:mendlify/features/service_request/data/models/bid_model.dart';
import 'package:mendlify/features/service_request/presentation/providers/bid_provider.dart';
import 'package:mendlify/features/service_request/presentation/providers/service_request_provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class MechanicHomeScreen extends ConsumerStatefulWidget {
  const MechanicHomeScreen({super.key});

  @override
  ConsumerState<MechanicHomeScreen> createState() => _MechanicHomeScreenState();
}

class _MechanicHomeScreenState extends ConsumerState<MechanicHomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    //prevent manual reload ig....
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        ref.invalidate(allServiceRequestsProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(goRouterProvider);
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

class _ServiceRequestCard extends ConsumerStatefulWidget {
  final dynamic request;

  const _ServiceRequestCard({required this.request});

  @override
  ConsumerState<_ServiceRequestCard> createState() =>
      _ServiceRequestCardState();
}

class _ServiceRequestCardState extends ConsumerState<_ServiceRequestCard> {
  DateTime? _lastBidTime;
  bool _isChecking = true;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _checkRecentBid();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_canPlaceBid) {
        setState(() {}); // Refresh UI to update countdown
      } else if (_canPlaceBid) {
        if (mounted) {
          setState(() {
            _lastBidTime = null;
          });
        }
        timer.cancel(); // Stop timer when cooldown is over
      }
    });
  }

  Future<void> _checkRecentBid() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isChecking = false);
        return;
      }

      final bidService = ref.read(bidServiceProvider);
      final recentBid = await bidService.getMechanicBidForRequest(
        widget.request.requestId,
        user.uid,
      );

      if (recentBid != null) {
        setState(() {
          _lastBidTime = recentBid.createdAt;
          _isChecking = false;
        });
        if (!_canPlaceBid) {
          _startCooldownTimer();
        }
      } else {
        setState(() {
          _lastBidTime = null;
          _isChecking = false;
        });
      }
    } catch (e) {
      setState(() => _isChecking = false);
    }
  }

  bool get _canPlaceBid {
    if (_lastBidTime == null) return true;
    final timeSince = DateTime.now().difference(_lastBidTime!);
    return timeSince.inSeconds >= 15;
  }

  int get _remainingCooldownSeconds {
    if (_lastBidTime == null) return 0;
    final timeSince = DateTime.now().difference(_lastBidTime!);
    final remaining = 15 - timeSince.inSeconds;
    return remaining > 0 ? remaining : 0;
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
    final canBid = _canPlaceBid && !_isChecking;
    final cooldownSeconds = _remainingCooldownSeconds;

    // Check if this request is accepted by current mechanic
    final user = FirebaseAuth.instance.currentUser;
    final isAcceptedByMe = widget.request.status == 'accepted' &&
        widget.request.acceptedMechanicId == user?.uid;

    return Card(
      color: appCardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isAcceptedByMe
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge for accepted requests
            if (isAcceptedByMe) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    const Text(
                      'ACCEPTED - YOUR BID WON',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                  widget.request.userName,
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
                  widget.request.userPhone,
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
                    widget.request.location.address,
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
            const SizedBox(height: 16),

            // Action buttons based on status
            if (isAcceptedByMe && !widget.request.isCompleted) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openGoogleMaps(
                        widget.request.location.lat,
                        widget.request.location.lng,
                        widget.request.location.address,
                      ),
                      icon: const Icon(Icons.location_on, size: 20),
                      label: const Text('Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appButtonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsCompleted(context, ref),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (widget.request.status == 'pending') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canBid ? () => _showBidDialog(context, ref) : null,
                  icon: Icon(
                    cooldownSeconds > 0 ? Icons.timer : Icons.attach_money,
                    size: 20,
                  ),
                  label: Text(
                    cooldownSeconds > 0
                        ? 'Wait ${cooldownSeconds}s to bid again'
                        : _isChecking
                            ? 'Checking...'
                            : 'Place Bid',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appButtonColor,
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

  // Open Google Maps with location
  Future<void> _openGoogleMaps(double lat, double lng, String address) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mark as completed
  Future<void> _markAsCompleted(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: appCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Mark as Completed?',
          style: TextStyle(
            color: appMainTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Have you completed the service? The client will be prompted to rate your service.',
          style: TextStyle(color: appTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: appTextColor.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final requestService = ref.read(serviceRequestServiceProvider);
        await requestService.markRequestAsCompleted(widget.request.requestId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service marked as completed!'),
              backgroundColor: Colors.green,
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
  }

  void _showBidDialog(BuildContext context, WidgetRef ref) {
    final bidAmountController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final bidService =
        ref.read(bidServiceProvider); // Reading service befor dialog box

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: appCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Place Your Bid',
          style: TextStyle(
            color: appMainTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request: ${widget.request.problem}',
                style: TextStyle(
                  color: appTextColor.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: bidAmountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: appMainTextColor),
                decoration: InputDecoration(
                  labelText: 'Bid Amount (PKR)',
                  hintText: 'e.g. 2500',
                  hintStyle: TextStyle(color: appTextColor.withOpacity(0.45)),
                  labelStyle: TextStyle(color: appTextColor.withOpacity(0.72)),
                  floatingLabelStyle: const TextStyle(
                    color: appButtonColor,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon:
                      const Icon(Icons.attach_money, color: appButtonColor),
                  filled: true,
                  fillColor: appCardColor.withOpacity(0.55),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: appTextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: appButtonColor),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter bid amount';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: messageController,
                maxLines: 3,
                style: const TextStyle(color: appMainTextColor),
                decoration: InputDecoration(
                  labelText: 'Message (Optional)',
                  hintText:
                      'Add a short note about timeline or service details',
                  hintStyle: TextStyle(color: appTextColor.withOpacity(0.45)),
                  labelStyle: TextStyle(color: appTextColor.withOpacity(0.72)),
                  floatingLabelStyle: const TextStyle(
                    color: appButtonColor,
                    fontWeight: FontWeight.w600,
                  ),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: appCardColor.withOpacity(0.55),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: appTextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: appButtonColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: appTextColor.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  throw Exception('You must be logged in');
                }

                // Get mechanic info from Firestore
                final mechanicDoc = await FirebaseFirestore.instance
                    .collection('Mechanics')
                    .doc(user.uid)
                    .get();

                if (!mechanicDoc.exists) {
                  throw Exception('Mechanic profile not found');
                }

                final mechanicData = mechanicDoc.data()!;
                final mechanicName = mechanicData['Name'] ?? 'Unknown';
                final mechanicPhone = mechanicData['Phone'] ?? '';
                final mechanicRating =
                    (mechanicData['averageRating'] ?? 0.0).toDouble();

                final now = DateTime.now();
                // Create bid with 15-second expiration
                final bid = BidModel(
                  bidId: '', // Will be set by Firestore
                  requestId: widget.request.requestId,
                  mechanicId: user.uid,
                  mechanicName: mechanicName,
                  mechanicPhone: mechanicPhone,
                  mechanicRating: mechanicRating > 0 ? mechanicRating : null,
                  bidAmount: double.parse(bidAmountController.text.trim()),
                  message: messageController.text.trim().isEmpty
                      ? null
                      : messageController.text.trim(),
                  status: 'pending',
                  createdAt: now,
                  expiresAt: now.add(const Duration(seconds: 15)),
                );

                // Submit bid to Firestore
                await bidService.createBid(bid);

                // Update state with new bid time
                if (mounted) {
                  setState(() {
                    _lastBidTime = now;
                  });
                  _startCooldownTimer(); // Restart timer for countdown
                }

                // Close dialog
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bid placed successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                // Close dialog on error
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                // Show error message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: appButtonColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Bid'),
          ),
        ],
      ),
    );
  }
}
