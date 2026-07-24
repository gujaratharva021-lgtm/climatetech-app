import 'package:flutter/material.dart';

/// The four real tradeable commodities on the B2B energy marketplace.
/// "other" is a valid backend value too (generic/eco-goods listings use
/// it implicitly), but it's never shown as a choice here — this screen is
/// specifically for energy commodity trading.
const List<String> commodityTypes = ['coal', 'biomass', 'coke', 'carbon_credit'];

String commodityTypeLabel(String type) {
  switch (type) {
    case 'coal':
      return 'Coal';
    case 'biomass':
      return 'Biomass';
    case 'coke':
      return 'Coke';
    case 'carbon_credit':
      return 'Carbon Credit';
    default:
      return type;
  }
}

IconData commodityTypeIcon(String type) {
  switch (type) {
    case 'coal':
      return Icons.local_fire_department_rounded;
    case 'biomass':
      return Icons.grass_rounded;
    case 'coke':
      return Icons.factory_rounded;
    case 'carbon_credit':
      return Icons.forest_rounded;
    default:
      return Icons.category_outlined;
  }
}

/// A listing on the B2B energy commodity marketplace. This is a separate
/// model from ListingModel (used by the original eco-goods classifieds
/// section) even though both are backed by the same `listings` table and
/// `/marketplace/listings` endpoints on the server — keeping them separate
/// here means neither section's Dart code can ever accidentally break the
/// other's.
class CommodityListingModel {
  final String id;
  final String sellerId;
  final String title;
  final String description;
  final double pricePerUnit;
  final List<String> imageUrls;
  final String location;
  final bool isActive;
  final DateTime createdAt;
  final String shopName;
  final bool verified;

  final String commodityType;
  final double quantity;
  final String unit;
  final double minOrderQty;
  final String grade;

  // Only populated by getListingDetail() -- the browse-list endpoint
  // doesn't return contact info (a buyer needs to open a specific listing
  // before seeing how to reach the seller), so these are empty strings on
  // anything parsed from browseListings()/getMyListings().
  final String contactName;
  final String contactPhone;

  CommodityListingModel({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.pricePerUnit,
    required this.imageUrls,
    required this.location,
    required this.isActive,
    required this.createdAt,
    required this.shopName,
    required this.verified,
    required this.commodityType,
    required this.quantity,
    required this.unit,
    required this.minOrderQty,
    required this.grade,
    this.contactName = '',
    this.contactPhone = '',
  });

  factory CommodityListingModel.fromJson(Map<String, dynamic> json) {
    final images = json['image_urls'] as List<dynamic>? ?? [];
    return CommodityListingModel(
      id: json['id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pricePerUnit: (json['price'] as num?)?.toDouble() ?? 0,
      imageUrls: images.whereType<String>().toList(),
      location: json['location'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      shopName: json['shop_name'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
      commodityType: json['commodity_type'] as String? ?? 'other',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'unit',
      minOrderQty: (json['min_order_qty'] as num?)?.toDouble() ?? 0,
      grade: json['grade'] as String? ?? '',
      contactName: json['contact_name'] as String? ?? '',
      contactPhone: json['contact_phone'] as String? ?? '',
    );
  }
}
