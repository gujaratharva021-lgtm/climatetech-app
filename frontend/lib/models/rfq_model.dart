import 'package:flutter/material.dart';

enum RFQStatus { open, awarded, cancelled, expired }

RFQStatus rfqStatusFromString(String s) {
  switch (s) {
    case 'awarded':
      return RFQStatus.awarded;
    case 'cancelled':
      return RFQStatus.cancelled;
    case 'expired':
      return RFQStatus.expired;
    default:
      return RFQStatus.open;
  }
}

String rfqStatusLabel(RFQStatus s) {
  switch (s) {
    case RFQStatus.open:
      return 'Open';
    case RFQStatus.awarded:
      return 'Awarded';
    case RFQStatus.cancelled:
      return 'Cancelled';
    case RFQStatus.expired:
      return 'Expired';
  }
}

Color rfqStatusColor(RFQStatus s) {
  switch (s) {
    case RFQStatus.open:
      return const Color(0xFF3DD68C);
    case RFQStatus.awarded:
      return const Color(0xFF5AA9E0);
    case RFQStatus.cancelled:
      return const Color(0xFFE0605A);
    case RFQStatus.expired:
      return const Color(0xFF8A8F9C);
  }
}

/// A buyer's posted requirement on the reverse-auction / RFQ marketplace.
/// Sellers respond with [BidModel]s; the buyer accepts one to award it.
class RFQModel {
  final String id;
  final String buyerId;
  final String commodityType;
  final double quantity;
  final String unit;
  final double targetPrice;
  final String grade;
  final String location;
  final DateTime deadline;
  final RFQStatus status;
  final String? awardedBidId;
  final DateTime createdAt;

  RFQModel({
    required this.id,
    required this.buyerId,
    required this.commodityType,
    required this.quantity,
    required this.unit,
    required this.targetPrice,
    required this.grade,
    required this.location,
    required this.deadline,
    required this.status,
    required this.awardedBidId,
    required this.createdAt,
  });

  factory RFQModel.fromJson(Map<String, dynamic> json) {
    return RFQModel(
      id: json['id'] as String? ?? '',
      buyerId: json['buyer_id'] as String? ?? '',
      commodityType: json['commodity_type'] as String? ?? 'other',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'unit',
      targetPrice: (json['target_price'] as num?)?.toDouble() ?? 0,
      grade: json['grade'] as String? ?? '',
      location: json['location'] as String? ?? '',
      deadline: DateTime.tryParse(json['deadline'] as String? ?? '') ?? DateTime.now(),
      status: rfqStatusFromString(json['status'] as String? ?? 'open'),
      awardedBidId: json['awarded_bid_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

enum BidStatus { pending, accepted, rejected, withdrawn }

BidStatus bidStatusFromString(String s) {
  switch (s) {
    case 'accepted':
      return BidStatus.accepted;
    case 'rejected':
      return BidStatus.rejected;
    case 'withdrawn':
      return BidStatus.withdrawn;
    default:
      return BidStatus.pending;
  }
}

String bidStatusLabel(BidStatus s) {
  switch (s) {
    case BidStatus.pending:
      return 'Pending';
    case BidStatus.accepted:
      return 'Accepted';
    case BidStatus.rejected:
      return 'Rejected';
    case BidStatus.withdrawn:
      return 'Withdrawn';
  }
}

/// A seller's offer against a specific [RFQModel]. shopName/verified are
/// only populated when returned via ListBidsForRFQ (the buyer's view);
/// GetMyBids (the seller's own list) leaves them blank since the seller
/// already knows who they are.
class BidModel {
  final String id;
  final String rfqId;
  final String sellerId;
  final double price;
  final double quantity;
  final String message;
  final BidStatus status;
  final DateTime createdAt;
  final String shopName;
  final bool verified;

  BidModel({
    required this.id,
    required this.rfqId,
    required this.sellerId,
    required this.price,
    required this.quantity,
    required this.message,
    required this.status,
    required this.createdAt,
    this.shopName = '',
    this.verified = false,
  });

  factory BidModel.fromJson(Map<String, dynamic> json) {
    return BidModel(
      id: json['id'] as String? ?? '',
      rfqId: json['rfq_id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      message: json['message'] as String? ?? '',
      status: bidStatusFromString(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      shopName: json['shop_name'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
    );
  }
}

