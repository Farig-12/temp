import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mendlify/features/service_request/data/models/service_request_model.dart';

// Provider to stream all service requests for mechanics
// Shows pending requests for all mechanics and accepted requests for the logged-in mechanic
final allServiceRequestsProvider =
    StreamProvider<List<ServiceRequestModel>>((ref) async* {
  // Wait for authentication to be fully initialized
  final authStream = FirebaseAuth.instance.authStateChanges();

  await for (final user in authStream) {
    // If user is not authenticated, yield empty list
    if (user == null) {
      yield [];
      continue;
    }

    // User is authenticated, now stream service requests
    await for (final snapshot in FirebaseFirestore.instance
        .collection('service_requests')
        .snapshots()) {
      final allRequests = snapshot.docs
          .map((doc) => ServiceRequestModel.fromMap(doc.data()))
          .toList();

      // Filter: show pending requests OR accepted requests by this mechanic
      final filteredRequests = allRequests.where((request) {
        return request.status == 'pending' ||
            (request.status == 'accepted' &&
                request.acceptedMechanicId == user.uid);
      }).toList();

      // Sort in memory by createdAt (newest first)
      filteredRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      yield filteredRequests;
    }
  }
});

// Provider to get a single service request by ID
final serviceRequestByIdProvider =
    StreamProvider.family<ServiceRequestModel?, String>((ref, requestId) {
  return FirebaseFirestore.instance
      .collection('service_requests')
      .doc(requestId)
      .snapshots()
      .map((doc) {
    if (doc.exists && doc.data() != null) {
      return ServiceRequestModel.fromMap(doc.data()!);
    }
    return null;
  });
});
