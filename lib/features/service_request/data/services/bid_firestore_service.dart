import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mendlify/features/service_request/data/models/bid_model.dart';

class BidFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _requestsCollection = 'service_requests';
  static const String _bidsSubcollection = 'bids';

  // Create a new bid for a service request
  Future<String> createBid(BidModel bid) async {
    try {
      final requestRef =
          _firestore.collection(_requestsCollection).doc(bid.requestId);
      final requestDoc = await requestRef.get();
      if (!requestDoc.exists || requestDoc.data() == null) {
        throw Exception('This service request is no longer available.');
      }

      final requestData = requestDoc.data()!;
      final requestStatus = requestData['status'] as String? ?? 'pending';
      final expiresAtRaw = requestData['expiresAt'];
      final requestExpiresAt = expiresAtRaw is Timestamp
          ? expiresAtRaw.toDate()
          : DateTime.now().subtract(const Duration(seconds: 1));
      final requestExpired = DateTime.now().isAfter(requestExpiresAt);

      if (requestStatus != 'pending' || requestExpired) {
        throw Exception('This service request has expired.');
      }

      // Check if mechanic has already bid on this request within last 15 seconds
      final recentBid =
          await _getMechanicRecentBid(bid.requestId, bid.mechanicId);
      if (recentBid != null) {
        final timeSinceLastBid = DateTime.now().difference(recentBid.createdAt);
        if (timeSinceLastBid.inSeconds < 15) {
          final remainingSeconds = 15 - timeSinceLastBid.inSeconds;
          throw Exception(
              'Please wait $remainingSeconds seconds before bidding again on this request.');
        }
      }

      final docRef = _firestore
          .collection(_requestsCollection)
          .doc(bid.requestId)
          .collection(_bidsSubcollection)
          .doc();

      final bidWithId = bid.copyWith(bidId: docRef.id);
      await docRef.set(bidWithId.toMap());
      return docRef.id;
    } catch (e) {
      if (e.toString().contains('Please wait') ||
          e.toString().contains('expired') ||
          e.toString().contains('no longer available')) {
        rethrow; // Re-throw our custom error message
      }
      throw Exception('Failed to create bid: $e');
    }
  }

  // Helper method to get mechanic's most recent bid for a request
  Future<BidModel?> _getMechanicRecentBid(
      String requestId, String mechanicId) async {
    try {
      final snapshot = await _firestore
          .collection(_requestsCollection)
          .doc(requestId)
          .collection(_bidsSubcollection)
          .where('mechanicId', isEqualTo: mechanicId)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      // Get the most recent non-expired pending bid.
      final bids =
          snapshot.docs.map((doc) => BidModel.fromMap(doc.data())).toList();

      bids.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final bid in bids) {
        if (bid.status == 'pending' && bid.isExpired) {
          deleteBid(requestId, bid.bidId).catchError((_) {});
          continue;
        }
        if (bid.status == 'pending') {
          return bid;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Get all bids for a specific service request (live stream)
  Stream<List<BidModel>> getBidsForRequest(String requestId) {
    return _firestore
        .collection(_requestsCollection)
        .doc(requestId)
        .collection(_bidsSubcollection)
        .snapshots()
        .map((snapshot) {
      try {
        if (snapshot.docs.isEmpty) {
          return <BidModel>[];
        }

        final bids = snapshot.docs
            .map((doc) {
              try {
                return BidModel.fromMap(doc.data());
              } catch (e) {
                print('Error parsing bid ${doc.id}: $e');
                return null;
              }
            })
            .whereType<BidModel>()
            .toList();

        // Filter out expired bids (delete them asynchronously)
        final activeBids = <BidModel>[];
        for (var bid in bids) {
          if (bid.isExpired && bid.status == 'pending') {
            // Auto-delete expired bid (fire and forget)
            deleteBid(requestId, bid.bidId).catchError((e) {
              print('Error deleting expired bid: $e');
            });
          } else {
            // Keep non-expired bids or all accepted/rejected bids
            activeBids.add(bid);
          }
        }

        // Sort in memory instead of Firestore query (avoids index requirement)
        activeBids.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return activeBids;
      } catch (e) {
        print('Error in getBidsForRequest: $e');
        return <BidModel>[];
      }
    });
  }

  // Get a mechanic's bid for a specific request (to check if already bid)
  Future<BidModel?> getMechanicBidForRequest(
      String requestId, String mechanicId) async {
    try {
      final snapshot = await _firestore
          .collection(_requestsCollection)
          .doc(requestId)
          .collection(_bidsSubcollection)
          .get();

      // Filter in memory to avoid index requirements
      final mechanicBids = snapshot.docs
          .where((doc) => doc.data()['mechanicId'] == mechanicId)
          .map((doc) => BidModel.fromMap(doc.data()))
          .toList();

      if (mechanicBids.isEmpty) {
        return null;
      }

      mechanicBids.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final bid in mechanicBids) {
        if (bid.status == 'pending' && bid.isExpired) {
          deleteBid(requestId, bid.bidId).catchError((_) {});
          continue;
        }
        if (bid.status == 'pending') {
          return bid;
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get mechanic bid: $e');
    }
  }

  // Update bid status (for accepting/rejecting bids)
  Future<void> updateBidStatus(
      String requestId, String bidId, String status) async {
    try {
      await _firestore
          .collection(_requestsCollection)
          .doc(requestId)
          .collection(_bidsSubcollection)
          .doc(bidId)
          .update({'status': status});
    } catch (e) {
      throw Exception('Failed to update bid status: $e');
    }
  }

  // Delete a bid
  Future<void> deleteBid(String requestId, String bidId) async {
    try {
      await _firestore
          .collection(_requestsCollection)
          .doc(requestId)
          .collection(_bidsSubcollection)
          .doc(bidId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete bid: $e');
    }
  }
}
