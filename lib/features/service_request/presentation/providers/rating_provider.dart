import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/features/service_request/data/services/rating_service.dart';

// Provider for rating service
final ratingServiceProvider = Provider<RatingService>((ref) {
  return RatingService();
});

// Provider to rate a mechanic
final rateMechanicProvider = FutureProvider.family<void, RateMechanicParams>(
  (ref, params) async {
    final service = ref.read(ratingServiceProvider);
    await service.rateMechanic(
      mechanicId: params.mechanicId,
      requestId: params.requestId,
      userId: params.userId,
      rating: params.rating,
    );
  },
);

// Provider to get mechanic rating
final mechanicRatingProvider =
    FutureProvider.family<double?, String>((ref, mechanicId) async {
  final service = ref.read(ratingServiceProvider);
  return await service.getMechanicRating(mechanicId);
});

// Parameters for rating a mechanic
class RateMechanicParams {
  final String mechanicId;
  final String requestId;
  final String userId;
  final double rating;

  RateMechanicParams({
    required this.mechanicId,
    required this.requestId,
    required this.userId,
    required this.rating,
  });
}
