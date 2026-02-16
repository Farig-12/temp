import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mendlify/features/service_request/data/models/service_request_model.dart';
import 'dart:math';

class ServiceRequestFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'service_requests';

  // Create a new service request
  Future<String> createServiceRequest(ServiceRequestModel request) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final requestWithId = request.copyWith(requestId: docRef.id);

      await docRef.set(requestWithId.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create service request: $e');
    }
  }

  // Get all service requests for a user
  Stream<List<ServiceRequestModel>> getUserServiceRequests(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceRequestModel.fromMap(doc.data()))
            .toList());
  }

  // Get a single service request by ID
  Future<ServiceRequestModel?> getServiceRequestById(String requestId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        return ServiceRequestModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get service request: $e');
    }
  }

  // Update service request status
  Future<void> updateServiceRequestStatus(
      String requestId, String status) async {
    try {
      await _firestore.collection(_collectionName).doc(requestId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update service request status: $e');
    }
  }

  // Stream for mechanics to listen to nearby service requests (within 10km)
  // Note: For production, you should use GeoFlutterFire or similar for efficient geo queries
  Stream<List<ServiceRequestModel>> getNearbyServiceRequests({
    required double lat,
    required double lng,
    double radiusInKm = 10,
  }) {
    // Simple bounding box calculation
    // 1 degree of latitude ≈ 111km
    // 1 degree of longitude ≈ 111km * cos(latitude)
    final latDelta = radiusInKm / 111;
    final lngDelta =
        radiusInKm / (cos(111 * (lat * 0.0174533))); // Convert to radians

    final minLat = lat - latDelta;
    final maxLat = lat + latDelta;
    final minLng = lng - lngDelta;
    final maxLng = lng + lngDelta;

    return _firestore
        .collection(_collectionName)
        .where('status', isEqualTo: 'pending')
        .where('location.lat', isGreaterThanOrEqualTo: minLat)
        .where('location.lat', isLessThanOrEqualTo: maxLat)
        .snapshots()
        .map((snapshot) {
      // Filter by longitude and exact distance in memory
      final requests = snapshot.docs
          .map((doc) => ServiceRequestModel.fromMap(doc.data()))
          .where((request) {
        final requestLng = request.location.lng;
        if (requestLng < minLng || requestLng > maxLng) return false;

        // Calculate actual distance using Haversine formula
        final distance = _calculateDistance(
          lat,
          lng,
          request.location.lat,
          request.location.lng,
        );
        return distance <= radiusInKm;
      }).toList();

      return requests;
    });
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = (sin(dLat / 2)) * (sin(dLat / 2)) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            (sin(dLon / 2)) *
            (sin(dLon / 2));

    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * 0.0174533; // π / 180
  }

  // Delete a service request
  Future<void> deleteServiceRequest(String requestId) async {
    try {
      await _firestore.collection(_collectionName).doc(requestId).delete();
    } catch (e) {
      throw Exception('Failed to delete service request: $e');
    }
  }

  // Accept a bid (update service request with mechanic info)
  Future<void> acceptBid({
    required String requestId,
    required String mechanicId,
    required double bidAmount,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(requestId).update({
        'status': 'accepted',
        'acceptedMechanicId': mechanicId,
        'acceptedBidAmount': bidAmount,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to accept bid: $e');
    }
  }
}
