import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';
import 'auth_provider.dart';
import 'marketplace_provider.dart' show LoadStatus;

export 'marketplace_provider.dart' show LoadStatus;

final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(ref.read(apiServiceProvider));
});

class OrderState {
  final LoadStatus myOrdersStatus;
  final List<OrderModel> myOrders;
  final String? myOrdersError;

  final LoadStatus sellerOrdersStatus;
  final List<OrderModel> sellerOrders;
  final String? sellerOrdersError;

  final LoadStatus shipmentStatus;
  final ShipmentModel? shipment;
  final String? shipmentError;

  const OrderState({
    this.myOrdersStatus = LoadStatus.initial,
    this.myOrders = const [],
    this.myOrdersError,
    this.sellerOrdersStatus = LoadStatus.initial,
    this.sellerOrders = const [],
    this.sellerOrdersError,
    this.shipmentStatus = LoadStatus.initial,
    this.shipment,
    this.shipmentError,
  });

  OrderState copyWith({
    LoadStatus? myOrdersStatus,
    List<OrderModel>? myOrders,
    String? myOrdersError,
    LoadStatus? sellerOrdersStatus,
    List<OrderModel>? sellerOrders,
    String? sellerOrdersError,
    LoadStatus? shipmentStatus,
    ShipmentModel? shipment,
    bool clearShipment = false,
    String? shipmentError,
  }) {
    return OrderState(
      myOrdersStatus: myOrdersStatus ?? this.myOrdersStatus,
      myOrders: myOrders ?? this.myOrders,
      myOrdersError: myOrdersError,
      sellerOrdersStatus: sellerOrdersStatus ?? this.sellerOrdersStatus,
      sellerOrders: sellerOrders ?? this.sellerOrders,
      sellerOrdersError: sellerOrdersError,
      shipmentStatus: shipmentStatus ?? this.shipmentStatus,
      shipment: clearShipment ? null : (shipment ?? this.shipment),
      shipmentError: shipmentError,
    );
  }
}

class OrderNotifier extends StateNotifier<OrderState> {
  final OrderService _service;

  OrderNotifier(this._service) : super(const OrderState());

  Future<void> loadMyOrders() async {
    state = state.copyWith(myOrdersStatus: LoadStatus.loading, myOrdersError: null);
    try {
      final orders = await _service.getMyOrdersAsBuyer();
      state = state.copyWith(myOrdersStatus: LoadStatus.loaded, myOrders: orders);
    } catch (e) {
      state = state.copyWith(myOrdersStatus: LoadStatus.error, myOrdersError: e.toString());
    }
  }

  Future<void> loadSellerOrders() async {
    state = state.copyWith(sellerOrdersStatus: LoadStatus.loading, sellerOrdersError: null);
    try {
      final orders = await _service.getMySellerOrders();
      state = state.copyWith(sellerOrdersStatus: LoadStatus.loaded, sellerOrders: orders);
    } catch (e) {
      state = state.copyWith(sellerOrdersStatus: LoadStatus.error, sellerOrdersError: e.toString());
    }
  }

  Future<OrderModel?> getOrderDetail(String id) async {
    try {
      return await _service.getOrderDetail(id);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadShipment(String orderId) async {
    state = state.copyWith(shipmentStatus: LoadStatus.loading, shipmentError: null, clearShipment: true);
    try {
      final shipment = await _service.getShipmentByOrder(orderId);
      state = state.copyWith(shipmentStatus: LoadStatus.loaded, shipment: shipment);
    } catch (e) {
      state = state.copyWith(shipmentStatus: LoadStatus.error, shipmentError: e.toString());
    }
  }

  Future<bool> confirmOrder(String id) async {
    try {
      await _service.confirmOrder(id);
      await loadSellerOrders();
      return true;
    } catch (e) {
      state = state.copyWith(sellerOrdersError: e.toString());
      return false;
    }
  }

  Future<bool> shipOrder(String id) async {
    try {
      await _service.shipOrder(id);
      await loadSellerOrders();
      return true;
    } catch (e) {
      state = state.copyWith(sellerOrdersError: e.toString());
      return false;
    }
  }

  Future<bool> deliverOrder(String id) async {
    try {
      await _service.deliverOrder(id);
      await loadMyOrders();
      return true;
    } catch (e) {
      state = state.copyWith(myOrdersError: e.toString());
      return false;
    }
  }

  Future<bool> cancelOrder(String id, {required bool asBuyer}) async {
    try {
      await _service.cancelOrder(id);
      if (asBuyer) {
        await loadMyOrders();
      } else {
        await loadSellerOrders();
      }
      return true;
    } catch (e) {
      state = state.copyWith(myOrdersError: e.toString());
      return false;
    }
  }

  Future<bool> createShipment({
    required String orderId,
    required String carrierName,
    String? vehicleNumber,
    String? driverName,
    String? driverPhone,
    String? trackingNumber,
    DateTime? estimatedDeliveryDate,
  }) async {
    try {
      await _service.createShipment(
        orderId: orderId,
        carrierName: carrierName,
        vehicleNumber: vehicleNumber,
        driverName: driverName,
        driverPhone: driverPhone,
        trackingNumber: trackingNumber,
        estimatedDeliveryDate: estimatedDeliveryDate,
      );
      await loadShipment(orderId);
      await loadSellerOrders();
      return true;
    } catch (e) {
      state = state.copyWith(shipmentError: e.toString());
      return false;
    }
  }

  Future<bool> updateShipmentStatus({
    required String orderId,
    required String shipmentId,
    required String status,
    String? currentLocation,
    String? proofOfDeliveryUrl,
  }) async {
    try {
      await _service.updateShipmentStatus(
        shipmentId: shipmentId,
        status: status,
        currentLocation: currentLocation,
        proofOfDeliveryUrl: proofOfDeliveryUrl,
      );
      await loadShipment(orderId);
      return true;
    } catch (e) {
      state = state.copyWith(shipmentError: e.toString());
      return false;
    }
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  return OrderNotifier(ref.read(orderServiceProvider));
});
