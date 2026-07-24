import 'package:dio/dio.dart';

import '../models/commodity_listing_model.dart';
import 'api_service.dart';

class EnergyTradeException implements Exception {
  final String message;
  EnergyTradeException(this.message);
  @override
  String toString() => message;
}

/// Talks to the same `/marketplace/listings` endpoints as MarketplaceService
/// (the backend's Listing model was extended in place to carry commodity
/// fields, not replaced), just with the commodity-specific request/response
/// shape this section of the app needs.
class EnergyTradeService {
  final ApiService _api;

  EnergyTradeService(this._api);

  Future<List<CommodityListingModel>> browseListings({
    String? commodityType,
    String? search,
    int limit = 20,
  }) async {
    try {
      final response = await _api.dio.get('/marketplace/listings', queryParameters: {
        if (commodityType != null && commodityType.isNotEmpty) 'commodity_type': commodityType,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
      });
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => CommodityListingModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw EnergyTradeException(_extractError(e));
    }
  }

  Future<CommodityListingModel> getListingDetail(String id) async {
    try {
      final response = await _api.dio.get('/marketplace/listings/$id');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final listingJson = data['listing'] as Map<String, dynamic>? ?? {};
      final sellerJson = data['seller'] as Map<String, dynamic>? ?? {};
      final contactJson = data['contact'] as Map<String, dynamic>? ?? {};
      // The detail endpoint nests seller/contact info separately rather
      // than flattening it onto the listing the way the browse endpoint
      // does -- merge everything this screen needs onto the listing json
      // so one fromJson factory handles both response shapes.
      final merged = {
        ...listingJson,
        'shop_name': sellerJson['shop_name'],
        'verified': sellerJson['verified'],
        'contact_name': contactJson['name'],
        'contact_phone': contactJson['phone'],
      };
      return CommodityListingModel.fromJson(merged);
    } on DioException catch (e) {
      throw EnergyTradeException(_extractError(e));
    }
  }

  Future<CommodityListingModel> createListing({
    required String title,
    String? description,
    required double pricePerUnit,
    required String commodityType,
    required double quantity,
    required String unit,
    double minOrderQty = 0,
    String? grade,
    List<String> imageUrls = const [],
    String? location,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/listings', data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'price': pricePerUnit,
        // The backend requires a `category` on every listing regardless of
        // type; for commodity listings the commodity type doubles as it.
        'category': commodityType,
        'image_urls': imageUrls,
        if (location != null && location.isNotEmpty) 'location': location,
        'commodity_type': commodityType,
        'quantity': quantity,
        'unit': unit,
        'min_order_qty': minOrderQty,
        if (grade != null && grade.isNotEmpty) 'grade': grade,
      });
      return CommodityListingModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw EnergyTradeException(_extractError(e));
    }
  }

  /// The `/marketplace/my-listings` endpoint returns every listing the
  /// seller owns, eco-goods and commodities alike (same underlying table) —
  /// filtered here to just the four real commodity types so this section
  /// only ever shows what it's actually for.
  Future<List<CommodityListingModel>> getMyListings() async {
    try {
      final response = await _api.dio.get('/marketplace/my-listings');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => CommodityListingModel.fromJson(e as Map<String, dynamic>))
          .where((l) => commodityTypes.contains(l.commodityType))
          .toList();
    } on DioException catch (e) {
      throw EnergyTradeException(_extractError(e));
    }
  }

  Future<void> deleteListing(String id) async {
    try {
      await _api.dio.delete('/marketplace/listings/$id');
    } on DioException catch (e) {
      throw EnergyTradeException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the energy trade marketplace.';
  }
}
