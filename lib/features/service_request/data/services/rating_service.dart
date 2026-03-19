import 'package:cloud_firestore/cloud_firestore.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rate a mechanic after service completion
  Future<void> rateMechanic({
    required String mechanicId,
    required String requestId,
    required String userId,
    required double rating,
  }) async {
    try {
      final mechanicRef = _firestore.collection('Mechanics').doc(mechanicId);

      await _firestore.runTransaction((transaction) async {
        final mechanicDoc = await transaction.get(mechanicRef);

        if (!mechanicDoc.exists) {
          throw Exception('Mechanic not found');
        }

        final data = mechanicDoc.data()!;
        final currentRating = (data['averageRating'] ?? 0.0).toDouble();
        final totalRatings = (data['totalRatings'] ?? 0) as int;

        // Calculate new average
        final newTotal = totalRatings + 1;
        final newAverage = ((currentRating * totalRatings) + rating) / newTotal;

        // Update mechanic document
        transaction.update(mechanicRef, {
          'averageRating': newAverage,
          'totalRatings': newTotal,
          'lastRatedAt': FieldValue.serverTimestamp(),
        });

        // Store individual rating in subcollection for future reference
        final ratingRef = mechanicRef.collection('ratings').doc(requestId);
        transaction.set(ratingRef, {
          'userId': userId,
          'requestId': requestId,
          'rating': rating,
          'ratedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to rate mechanic: $e');
    }
  }

  // Get mechanic's average rating
  Future<double?> getMechanicRating(String mechanicId) async {
    try {
      final doc =
          await _firestore.collection('Mechanics').doc(mechanicId).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data()!['averageRating'] ?? 0.0).toDouble();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if user has already rated this mechanic for this request
  Future<bool> hasUserRated(String mechanicId, String requestId) async {
    try {
      final doc = await _firestore
          .collection('Mechanics')
          .doc(mechanicId)
          .collection('ratings')
          .doc(requestId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
