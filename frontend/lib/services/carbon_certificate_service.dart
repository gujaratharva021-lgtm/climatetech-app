import 'package:dio/dio.dart';

import '../models/carbon_certificate_model.dart';
import 'api_service.dart';

class CarbonCertificateException implements Exception {
  final String message;
  CarbonCertificateException(this.message);
  @override
  String toString() => message;
}

class CarbonCertificateService {
  final ApiService _api;
  CarbonCertificateService(this._api);

  Future<CarbonCertificateModel> createCertificate({
    required String registry,
    required String projectName,
    String? projectId,
    String? projectType,
    required int vintageYear,
    String? serialNumberRange,
    required double totalQuantity,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/carbon-certificates', data: {
        'registry': registry,
        'project_name': projectName,
        if (projectId != null && projectId.isNotEmpty) 'project_id': projectId,
        if (projectType != null && projectType.isNotEmpty) 'project_type': projectType,
        'vintage_year': vintageYear,
        if (serialNumberRange != null && serialNumberRange.isNotEmpty) 'serial_number_range': serialNumberRange,
        'total_quantity': totalQuantity,
      });
      return CarbonCertificateModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw CarbonCertificateException(_extractError(e));
    }
  }

  Future<void> attachToListing({required String certificateId, required String listingId}) async {
    try {
      await _api.dio.put('/marketplace/carbon-certificates/$certificateId/attach-listing', data: {
        'listing_id': listingId,
      });
    } on DioException catch (e) {
      throw CarbonCertificateException(_extractError(e));
    }
  }

  Future<CarbonCertificateModel> getCertificate(String id) async {
    try {
      final response = await _api.dio.get('/marketplace/carbon-certificates/$id');
      return CarbonCertificateModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw CarbonCertificateException(_extractError(e));
    }
  }

  Future<List<CarbonCertificateModel>> getMyCertificates() async {
    try {
      final response = await _api.dio.get('/marketplace/my-carbon-certificates');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => CarbonCertificateModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw CarbonCertificateException(_extractError(e));
    }
  }

  Future<CreditRetirementModel> retireCredits({
    required String certificateId,
    required double quantity,
    String? beneficiaryName,
    String? retirementReason,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/carbon-certificates/$certificateId/retire', data: {
        'quantity': quantity,
        if (beneficiaryName != null && beneficiaryName.isNotEmpty) 'beneficiary_name': beneficiaryName,
        if (retirementReason != null && retirementReason.isNotEmpty) 'retirement_reason': retirementReason,
      });
      return CreditRetirementModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw CarbonCertificateException(_extractError(e));
    }
  }

  Future<List<CreditRetirementModel>> getMyRetirements() async {
    try {
      final response = await _api.dio.get('/marketplace/my-retirements');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => CreditRetirementModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw CarbonCertificateException(_extractError(e));
    }
  }

  Future<List<CreditRetirementModel>> getRetirementsForCertificate(String certificateId) async {
    try {
      final response = await _api.dio.get('/marketplace/carbon-certificates/$certificateId/retirements');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => CreditRetirementModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw CarbonCertificateException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the carbon certificate service.';
  }
}
