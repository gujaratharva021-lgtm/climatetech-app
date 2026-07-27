import 'package:dio/dio.dart';

import '../models/logistics_model.dart';
import 'api_service.dart';

class LogisticsException implements Exception {
  final String message;
  LogisticsException(this.message);
  @override
  String toString() => message;
}

class LogisticsService {
  final ApiService _api;
  LogisticsService(this._api);

  Future<List<VehicleModel>> browseVehicles({String? vehicleType, String? location}) async {
    try {
      final response = await _api.dio.get('/logistics/vehicles', queryParameters: {
        if (vehicleType != null && vehicleType.isNotEmpty) 'vehicle_type': vehicleType,
        if (location != null && location.isNotEmpty) 'location': location,
      });
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final list = data['vehicles'] as List<dynamic>? ?? [];
      return list.map((e) => VehicleModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw LogisticsException(_extractError(e));
    }
  }

  Future<List<VehicleModel>> getMyVehicles() async {
    try {
      final response = await _api.dio.get('/logistics/my-vehicles');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => VehicleModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw LogisticsException(_extractError(e));
    }
  }

  Future<VehicleModel> createVehicle({
    required String vehicleType,
    required String regNumber,
    required double capacityKg,
    String capacityUnit = 'kg',
    String? baseLocation,
    required double pricePerKm,
  }) async {
    try {
      final response = await _api.dio.post('/logistics/vehicles', data: {
        'vehicle_type': vehicleType,
        'reg_number': regNumber,
        'capacity_kg': capacityKg,
        'capacity_unit': capacityUnit,
        if (baseLocation != null && baseLocation.isNotEmpty) 'base_location': baseLocation,
        'price_per_km': pricePerKm,
      });
      return VehicleModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw LogisticsException(_extractError(e));
    }
  }

  Future<List<BookingModel>> getMyBookings() async {
    try {
      final response = await _api.dio.get('/logistics/my-bookings');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => BookingModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw LogisticsException(_extractError(e));
    }
  }

  Future<BookingModel> createBooking({
    required String vehicleId,
    required String pickupLocation,
    required String dropLocation,
    String? cargoDetails,
    required double weightKg,
    DateTime? scheduledPickup,
  }) async {
    try {
      final response = await _api.dio.post('/logistics/bookings', data: {
        'vehicle_id': vehicleId,
        'pickup_location': pickupLocation,
        'drop_location': dropLocation,
        if (cargoDetails != null && cargoDetails.isNotEmpty) 'cargo_details': cargoDetails,
        'weight_kg': weightKg,
        if (scheduledPickup != null) 'scheduled_pickup': scheduledPickup.toUtc().toIso8601String(),
      });
      return BookingModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw LogisticsException(_extractError(e));
    }
  }

  Future<void> updateBookingStatus({required String id, required BookingStatus status}) async {
    try {
      await _api.dio.put('/logistics/bookings/$id/status', data: {
        'status': bookingStatusToApiString(status),
      });
    } on DioException catch (e) {
      throw LogisticsException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the logistics service.';
  }
}
