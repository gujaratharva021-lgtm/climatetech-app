import 'package:dio/dio.dart';

import 'api_service.dart';

class AIException implements Exception {
  final String message;
  AIException(this.message);
  @override
  String toString() => message;
}

class ChatTurn {
  final String role;
  final String content;
  ChatTurn({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AIService {
  final ApiService _api;
  AIService(this._api);

  Future<String> chat({required String message, List<ChatTurn> history = const []}) async {
    try {
      final response = await _api.dio.post('/marketplace/ai/chat', data: {
        'message': message,
        'history': history.map((h) => h.toJson()).toList(),
      });
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      return data['reply'] as String? ?? '';
    } on DioException catch (e) {
      throw AIException(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> getMarketInsights(String commodityType) async {
    try {
      final response = await _api.dio.get('/marketplace/ai/market-insights/$commodityType');
      return response.data['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw AIException(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> draftContract(String orderId) async {
    try {
      final response = await _api.dio.post('/marketplace/orders/$orderId/ai/draft-contract');
      return response.data['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw AIException(_extractError(e));
    }
  }

  Future<List<Map<String, dynamic>>> recommendListings(String query) async {
    try {
      final response = await _api.dio.post('/marketplace/ai/recommend-listings', data: {'query': query});
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final list = data['recommendations'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw AIException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'AI assistant is unavailable right now.';
  }
}
