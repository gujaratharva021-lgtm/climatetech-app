import 'package:dio/dio.dart';

import '../models/price_index_model.dart';
import 'api_service.dart';

class PriceIndexException implements Exception {
  final String message;
  PriceIndexException(this.message);
  @override
  String toString() => message;
}

class PriceIndexApiService {
  final ApiService _api;
  PriceIndexApiService(this._api);

  Future<List<LiveIndexModel>> getAllPriceIndexes() async {
    try {
      final response = await _api.dio.get('/marketplace/price-index');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => LiveIndexModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw PriceIndexException(_extractError(e));
    }
  }

  Future<LiveIndexModel> getPriceIndex(String commodityType) async {
    try {
      final response = await _api.dio.get('/marketplace/price-index/$commodityType');
      return LiveIndexModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw PriceIndexException(_extractError(e));
    }
  }

  Future<List<PriceHistoryPoint>> getPriceHistory(
    String commodityType, {
    int days = 90,
    String source = 'transacted',
  }) async {
    try {
      final response = await _api.dio.get('/marketplace/price-index/$commodityType/history', queryParameters: {
        'days': days,
        'source': source,
      });
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => PriceHistoryPoint.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw PriceIndexException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the price index service.';
  }
}
