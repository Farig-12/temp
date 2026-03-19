import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/features/service_request/data/models/bid_model.dart';
import 'package:mendlify/features/service_request/data/services/bid_firestore_service.dart';

// Provider for bid service
final bidServiceProvider = Provider<BidFirestoreService>((ref) {
  return BidFirestoreService();
});

// Provider to create a bid
final createBidProvider =
    FutureProvider.autoDispose.family<String, BidModel>((ref, bid) async {
  final service = ref.read(bidServiceProvider);
  return await service.createBid(bid);
});

// Provider to get all bids for a specific request (live stream)
final bidsForRequestProvider =
    StreamProvider.autoDispose.family<List<BidModel>, String>((ref, requestId) {
  final service = ref.read(bidServiceProvider);
  return service.getBidsForRequest(requestId);
});

// Provider to check if mechanic has already bid on a request
final mechanicBidForRequestProvider = FutureProvider.autoDispose
    .family<BidModel?, BidCheckParams>((ref, params) async {
  final service = ref.read(bidServiceProvider);
  return await service.getMechanicBidForRequest(
    params.requestId,
    params.mechanicId,
  );
});

// Helper class for bid check parameters
class BidCheckParams {
  final String requestId;
  final String mechanicId;

  BidCheckParams({
    required this.requestId,
    required this.mechanicId,
  });
}
