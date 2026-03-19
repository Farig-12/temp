import 'package:cloud_firestore/cloud_firestore.dart';

class BidModel {
  final String bidId;
  final String requestId;
  final String mechanicId;
  final String mechanicName;
  final String mechanicPhone;
  final double? mechanicRating; // Average rating of mechanic
  final double bidAmount;
  final String? message;
  final String status; // pending, accepted, rejected, expired
  final DateTime createdAt;
  final DateTime expiresAt; // Bid expires after 15 seconds

  BidModel({
    required this.bidId,
    required this.requestId,
    required this.mechanicId,
    required this.mechanicName,
    required this.mechanicPhone,
    this.mechanicRating,
    required this.bidAmount,
    this.message,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'bidId': bidId,
      'requestId': requestId,
      'mechanicId': mechanicId,
      'mechanicName': mechanicName,
      'mechanicPhone': mechanicPhone,
      'mechanicRating': mechanicRating,
      'bidAmount': bidAmount,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  // Create from Firestore document
  factory BidModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    DateTime expiresAt;
    try {
      if (map['createdAt'] is Timestamp) {
        createdAt = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is DateTime) {
        createdAt = map['createdAt'];
      } else {
        createdAt = DateTime.now();
      }

      if (map['expiresAt'] is Timestamp) {
        expiresAt = (map['expiresAt'] as Timestamp).toDate();
      } else if (map['expiresAt'] is DateTime) {
        expiresAt = map['expiresAt'];
      } else {
        // Default to 15 seconds from createdAt if not present
        expiresAt = createdAt.add(const Duration(seconds: 15));
      }
    } catch (e) {
      createdAt = DateTime.now();
      expiresAt = createdAt.add(const Duration(seconds: 15));
    }

    return BidModel(
      bidId: map['bidId'] ?? '',
      requestId: map['requestId'] ?? '',
      mechanicId: map['mechanicId'] ?? '',
      mechanicName: map['mechanicName'] ?? '',
      mechanicPhone: map['mechanicPhone'] ?? '',
      mechanicRating: map['mechanicRating']?.toDouble(),
      bidAmount: (map['bidAmount'] ?? 0).toDouble(),
      message: map['message'],
      status: map['status'] ?? 'pending',
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  BidModel copyWith({
    String? bidId,
    String? requestId,
    String? mechanicId,
    String? mechanicName,
    String? mechanicPhone,
    double? mechanicRating,
    double? bidAmount,
    String? message,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return BidModel(
      bidId: bidId ?? this.bidId,
      requestId: requestId ?? this.requestId,
      mechanicId: mechanicId ?? this.mechanicId,
      mechanicName: mechanicName ?? this.mechanicName,
      mechanicPhone: mechanicPhone ?? this.mechanicPhone,
      mechanicRating: mechanicRating ?? this.mechanicRating,
      bidAmount: bidAmount ?? this.bidAmount,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // Check if bid has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
