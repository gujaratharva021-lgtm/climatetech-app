import 'package:dio/dio.dart';

import '../models/order_model.dart';
import '../models/payment_model.dart';
import 'api_service.dart';

class OrderException implements Exception {
  final String message;
  OrderException(this.message);
  @override
  String toString() => message;
}

/// Talks to the /marketplace/orders* endpoints -- order fulfillment
/// (placed -> confirmed -> shipped -> delivered) and the shipment/logistics
/// tracking attached to each order.
class OrderService {
  final ApiService _api;
  OrderService(this._api);

  Future<OrderModel> createOrderFromRFQ({required String rfqId, required String deliveryAddress}) async {
    try {
      final response = await _api.dio.post('/marketplace/rfq/$rfqId/order', data: {
        'delivery_address': deliveryAddress,
      });
      return OrderModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<OrderModel> createOrderFromListing({
    required String listingId,
    required double quantity,
    required String deliveryAddress,
  }) async {
    try {
      final response = await _api.dio.post('/marketplace/listings/$listingId/order', data: {
        'quantity': quantity,
        'delivery_address': deliveryAddress,
      });
      return OrderModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> createPaymentOrder(String orderId) async {
    try {
      final response = await _api.dio.post('/marketplace/orders/$orderId/payment/create');
      return response.data['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<void> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      await _api.dio.post('/marketplace/orders/$orderId/payment/verify', data: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      });
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<PaymentModel?> getPaymentStatus(String orderId) async {
    try {
      final response = await _api.dio.get('/marketplace/orders/$orderId/payment');
      final data = response.data['data'];
      if (data == null) return null;
      return PaymentModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<List<OrderModel>> getMyOrdersAsBuyer() async {
    try {
      final response = await _api.dio.get('/marketplace/my-orders');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<List<OrderModel>> getMySellerOrders() async {
    try {
      final response = await _api.dio.get('/marketplace/seller/orders');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<OrderModel> getOrderDetail(String id) async {
    try {
      final response = await _api.dio.get('/marketplace/orders/$id');
      return OrderModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<void> confirmOrder(String id) async {
    try {
      await _api.dio.put('/marketplace/orders/$id/confirm');
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<void> shipOrder(String id) async {
    try {
      await _api.dio.put('/marketplace/orders/$id/ship');
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<void> deliverOrder(String id) async {
    try {
      await _api.dio.put('/marketplace/orders/$id/deliver');
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<void> cancelOrder(String id) async {
    try {
      await _api.dio.put('/marketplace/orders/$id/cancel');
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<ShipmentModel?> getShipmentByOrder(String orderId) async {
    try {
      final response = await _api.dio.get('/marketplace/orders/$orderId/shipment');
      final data = response.data['data'];
      if (data == null) return null;
      return ShipmentModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

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
        if (estimatedDeliveryDate != null)
          'estimated_delivery_date': estimatedDeliveryDate.toUtc().toIso8601String(),
      });
      return ShipmentModel.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  Future<void> updateShipmentStatus({
    required String shipmentId,
    required String status,
    String? currentLocation,
    String? proofOfDeliveryUrl,
  }) async {
    try {
      await _api.dio.put('/marketplace/shipments/$shipmentId/status', data: {
        'status': status,
        if (currentLocation != null && currentLocation.isNotEmpty) 'current_location': currentLocation,
        if (proofOfDeliveryUrl != null && proofOfDeliveryUrl.isNotEmpty) 'proof_of_delivery_url': proofOfDeliveryUrl,
      });
    } on DioException catch (e) {
      throw OrderException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the order service.';
  }
}
