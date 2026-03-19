import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String requestId;
  final String userId;
  final String userName;
  final String userPhone;
  final String problem;
  final String problemCategory;
  final String description;
  final List<String> photos;
  final LocationData location;
  final String status;
  final String? acceptedMechanicId;
  final double? acceptedBidAmount;
  final bool isCompleted; // Whether the service is completed
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt; // Request expires after 1 minute if not accepted

  ServiceRequestModel({
    required this.requestId,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.problem,
    required this.problemCategory,
    required this.description,
    required this.photos,
    required this.location,
    required this.status,
    this.acceptedMechanicId,
    this.acceptedBidAmount,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  // Check if request has expired
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt) && status == 'pending';

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'problem': problem,
      'problemCategory': problemCategory,
      'description': description,
      'photos': photos,
      'location': location.toMap(),
      'status': status,
      'acceptedMechanicId': acceptedMechanicId,
      'acceptedBidAmount': acceptedBidAmount,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  // Create from Firestore document
  factory ServiceRequestModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAt = (map['createdAt'] as Timestamp).toDate();
    DateTime expiresAt;

    if (map['expiresAt'] != null) {
      expiresAt = (map['expiresAt'] as Timestamp).toDate();
    } else {
      // Default to 1 minute from creation if not present
      expiresAt = createdAt.add(const Duration(minutes: 1));
    }

    return ServiceRequestModel(
      requestId: map['requestId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      problem: map['problem'] ?? '',
      problemCategory: map['problemCategory'] ?? '',
      description: map['description'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      location: LocationData.fromMap(map['location'] ?? {}),
      status: map['status'] ?? 'pending',
      acceptedMechanicId: map['acceptedMechanicId'],
      acceptedBidAmount: map['acceptedBidAmount']?.toDouble(),
      isCompleted: map['isCompleted'] ?? false,
      createdAt: createdAt,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      expiresAt: expiresAt,
    );
  }

  // Copy with method
  ServiceRequestModel copyWith({
    String? requestId,
    String? userId,
    String? userName,
    String? userPhone,
    String? problem,
    String? problemCategory,
    String? description,
    List<String>? photos,
    LocationData? location,
    String? status,
    String? acceptedMechanicId,
    double? acceptedBidAmount,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return ServiceRequestModel(
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      problem: problem ?? this.problem,
      problemCategory: problemCategory ?? this.problemCategory,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      location: location ?? this.location,
      status: status ?? this.status,
      acceptedMechanicId: acceptedMechanicId ?? this.acceptedMechanicId,
      acceptedBidAmount: acceptedBidAmount ?? this.acceptedBidAmount,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class LocationData {
  final double lat;
  final double lng;
  final String address;

  LocationData({
    required this.lat,
    required this.lng,
    required this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'address': address,
    };
  }

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      lat: map['lat']?.toDouble() ?? 0.0,
      lng: map['lng']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
    );
  }
}
