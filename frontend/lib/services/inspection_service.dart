import 'package:dio/dio.dart';

import '../models/inspection_model.dart';
import 'api_service.dart';

class InspectionException implements Exception {
  final String message;
  InspectionException(this.message);
  @override
  String toString() => message;
}

class InspectionService {
  final ApiService _api;
  InspectionService(this._api);

  Future<InspectionModel> createInspectionRequest({
    required String orderId,
    required String inspectionType,
    String? notes,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/orders/$orderId/inspection', data: {
        'inspection_type': inspectionType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return InspectionModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw InspectionException(_extractError(e));
    }
  }

  Future<List<InspectionModel>> getMyInspections() async {
    try {
      final response = await _api.dio.get('/marketplace/my-inspections');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => InspectionModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw InspectionException(_extractError(e));
    }
  }

  Future<List<InspectionModel>> getAssignedInspections() async {
    try {
      final response = await _api.dio.get('/marketplace/inspector/assigned');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => InspectionModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw InspectionException(_extractError(e));
    }
  }

  Future<void> scheduleInspection({required String id, required DateTime scheduledDate}) async {
    try {
      await _api.dio.put('/marketplace/inspections/$id/schedule', data: {
        'scheduled_date': scheduledDate.toUtc().toIso8601String(),
      });
    } on DioException catch (e) {
      throw InspectionException(_extractError(e));
    }
  }

  Future<void> completeInspection({
    required String id,
    required String result,
    String? grade,
    String? reportNotes,
    String? reportFileUrl,
  }) async {
    try {
      await _api.dio.put('/marketplace/inspections/$id/complete', data: {
        'result': result,
        if (grade != null && grade.isNotEmpty) 'grade': grade,
        if (reportNotes != null && reportNotes.isNotEmpty) 'report_notes': reportNotes,
        if (reportFileUrl != null && reportFileUrl.isNotEmpty) 'report_file_url': reportFileUrl,
      });
    } on DioException catch (e) {
      throw InspectionException(_extractError(e));
    }
  }

  Future<void> cancelInspection(String id) async {
    try {
      await _api.dio.put('/marketplace/inspections/$id/cancel');
    } on DioException catch (e) {
      throw InspectionException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the inspection service.';
  }
}