import 'package:dio/dio.dart';

import '../models/financing_model.dart';
import 'api_service.dart';

class FinancingException implements Exception {
  final String message;
  FinancingException(this.message);
  @override
  String toString() => message;
}

class FinancingService {
  final ApiService _api;
  FinancingService(this._api);

  Future<FinancingRequestModel> createFinancingRequest({
    required String orderId,
    required double requestedAmount,
    String? purpose,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/orders/$orderId/financing', data: {
        'requested_amount': requestedAmount,
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
      });
      return FinancingRequestModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw FinancingException(_extractError(e));
    }
  }

  Future<List<FinancingRequestModel>> getFinancingForOrder(String orderId) async {
    try {
      final response = await _api.dio.get('/marketplace/orders/$orderId/financing');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => FinancingRequestModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw FinancingException(_extractError(e));
    }
  }

  Future<List<FinancingRequestModel>> getMyFinancingRequests() async {
    try {
      final response = await _api.dio.get('/marketplace/my-financing');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => FinancingRequestModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw FinancingException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the financing service.';
  }
}
