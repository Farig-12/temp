import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mendlify/features/service_request/data/models/service_request_model.dart';
import 'package:mendlify/features/service_request/data/services/service_request_firestore_service.dart';

final serviceRequestServiceProvider =
    Provider<ServiceRequestFirestoreService>((ref) {
  return ServiceRequestFirestoreService();
});

// Provider to create a service request
final createServiceRequestProvider = FutureProvider.autoDispose
    .family<String, ServiceRequestModel>((ref, request) async {
  final service = ref.read(serviceRequestServiceProvider);
  return await service.createServiceRequest(request);
});

// Provider to get user's service requests
final userServiceRequestsProvider = StreamProvider.autoDispose
    .family<List<ServiceRequestModel>, String>((ref, userId) {
  final service = ref.read(serviceRequestServiceProvider);
  return service.getUserServiceRequests(userId);
});

// Provider for nearby requests (for mechanics)
final nearbyServiceRequestsProvider = StreamProvider.autoDispose
    .family<List<ServiceRequestModel>, LocationParams>((ref, params) {
  final service = ref.read(serviceRequestServiceProvider);
  return service.getNearbyServiceRequests(
    lat: params.lat,
    lng: params.lng,
    radiusInKm: params.radiusInKm,
  );
});

class LocationParams {
  final double lat;
  final double lng;
  final double radiusInKm;

  LocationParams({
    required this.lat,
    required this.lng,
    this.radiusInKm = 10,
  });
}
