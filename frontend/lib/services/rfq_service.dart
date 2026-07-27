import 'package:dio/dio.dart';

import '../models/rfq_model.dart';
import 'api_service.dart';

class RFQException implements Exception {
  final String message;
  RFQException(this.message);
  @override
  String toString() => message;
}

/// Talks to the /marketplace/rfq* endpoints -- the reverse-auction side of
/// the B2B marketplace. Buyers post RFQs (requirements); sellers respond
/// with bids; the buyer accepts one to award it.
class RFQService {
  final ApiService _api;
  RFQService(this._api);

  Future<RFQModel> createRFQ({
    required String commodityType,
    required double quantity,
    String unit = 'unit',
    double targetPrice = 0,
    String? grade,
    String? location,
    required DateTime deadline,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/rfq', data: {
        'commodity_type': commodityType,
        'quantity': quantity,
        'unit': unit,
        'target_price': targetPrice,
        if (grade != null && grade.isNotEmpty) 'grade': grade,
        if (location != null && location.isNotEmpty) 'location': location,
        'deadline': deadline.toUtc().toIso8601String(),
      });
      return RFQModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  Future<List<RFQModel>> browseRFQs({String? commodityType, int limit = 20}) async {
    try {
      final response = await _api.dio.get('/marketplace/rfq', queryParameters: {
        if (commodityType != null && commodityType.isNotEmpty) 'commodity_type': commodityType,
        'limit': limit,
      });
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final list = data['rfqs'] as List<dynamic>? ?? [];
      return list.map((e) => RFQModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  Future<RFQModel> getRFQDetail(String id) async {
    try {
      final response = await _api.dio.get('/marketplace/rfq/$id');
      return RFQModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  Future<List<RFQModel>> getMyRFQs() async {
    try {
      final response = await _api.dio.get('/marketplace/my-rfqs');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => RFQModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  Future<void> cancelRFQ(String id) async {
    try {
      await _api.dio.put('/marketplace/rfq/$id/cancel');
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  Future<BidModel> submitBid({
    required String rfqId,
    required double price,
    required double quantity,
    String? message,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/rfq/$rfqId/bids', data: {
        'price': price,
        'quantity': quantity,
        if (message != null && message.isNotEmpty) 'message': message,
      });
      return BidModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  Future<List<BidModel>> listBidsForRFQ(String rfqId) async {
    try {
      final response = await _api.dio.get('/marketplace/rfq/$rfqId/bids');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => BidModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  Future<List<BidModel>> getMyBids() async {
    try {
      final response = await _api.dio.get('/marketplace/my-bids');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => BidModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  Future<void> acceptBid({required String rfqId, required String bidId}) async {
    try {
      await _api.dio.put('/marketplace/rfq/$rfqId/bids/$bidId/accept');
    } on DioException catch (e) {
      throw RFQException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the RFQ marketplace.';
  }
}
