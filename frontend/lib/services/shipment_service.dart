import 'package:dio/dio.dart';

import '../models/shipment_model.dart';
import 'api_service.dart';

class ShipmentException implements Exception {
  final String message;
  ShipmentException(this.message);
  @override
  String toString() => message;
}

class ShipmentService {
  final ApiService _api;
  ShipmentService(this._api);

  Future<ShipmentModel> createShipment({
    required String orderId,
    required String carrierName,
    String? vehicleNumber,
    String? driverName,
    String? driverPhone,
    String? trackingNumber,
    DateTime? estimatedDeliveryDate,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/orders/$orderId/shipment', data: {
        'carrier_name': carrierName,
        if (vehicleNumber != null && vehicleNumber.isNotEmpty) 'vehicle_number': vehicleNumber,
        if (driverName != null && driverName.isNotEmpty) 'driver_name': driverName,
        if (driverPhone != null && driverPhone.isNotEmpty) 'driver_phone': driverPhone,
        if (trackingNumber != null && trackingNumber.isNotEmpty) 'tracking_number': trackingNumber,
        if (estimatedDeliveryDate != null) 'estimated_delivery_date': estimatedDeliveryDate.toUtc().toIso8601String(),
      });
      return ShipmentModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw ShipmentException(_extractError(e));
    }
  }

  Future<void> updateShipmentStatus({
    required String shipmentId,
    required ShipmentStatus status,
    String? currentLocation,
    String? proofOfDeliveryUrl,
  }) async {
    try {
      await _api.dio.put('/marketplace/shipments/$shipmentId/status', data: {
        'status': shipmentStatusToApiString(status),
        if (currentLocation != null && currentLocation.isNotEmpty) 'current_location': currentLocation,
        if (proofOfDeliveryUrl != null && proofOfDeliveryUrl.isNotEmpty) 'proof_of_delivery_url': proofOfDeliveryUrl,
      });
    } on DioException catch (e) {
      throw ShipmentException(_extractError(e));
    }
  }

  Future<ShipmentModel?> getShipmentByOrder(String orderId) async {
    try {
      final response = await _api.dio.get('/marketplace/orders/$orderId/shipment');
      final data = response.data['data'];
      if (data == null) return null;
      return ShipmentModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ShipmentException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the shipment service.';
  }
}
