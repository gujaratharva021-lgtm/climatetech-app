enum OrderStatus { placed, confirmed, shipped, delivered, cancelled }

OrderStatus orderStatusFromString(String s) {
  switch (s) {
    case 'confirmed':
      return OrderStatus.confirmed;
    case 'shipped':
      return OrderStatus.shipped;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.placed;
  }
}

String orderStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.placed:
      return 'Placed';
    case OrderStatus.confirmed:
      return 'Confirmed';
    case OrderStatus.shipped:
      return 'Shipped';
    case OrderStatus.delivered:
      return 'Delivered';
    case OrderStatus.cancelled:
      return 'Cancelled';
  }
}

class OrderModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final String source;
  final String? rfqId;
  final String? bidId;
  final String? listingId;
  final String commodityType;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalAmount;
  final String deliveryAddress;
  final OrderStatus status;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.source,
    this.rfqId,
    this.bidId,
    this.listingId,
    required this.commodityType,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.deliveryAddress,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      buyerId: json['buyer_id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      rfqId: json['rfq_id'] as String?,
      bidId: json['bid_id'] as String?,
      listingId: json['listing_id'] as String?,
      commodityType: json['commodity_type'] as String? ?? 'other',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'unit',
      pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      deliveryAddress: json['delivery_address'] as String? ?? '',
      status: orderStatusFromString(json['status'] as String? ?? 'placed'),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

enum ShipmentStatus { pending, dispatched, inTransit, delivered, failed }

ShipmentStatus shipmentStatusFromString(String s) {
  switch (s) {
    case 'dispatched':
      return ShipmentStatus.dispatched;
    case 'in_transit':
      return ShipmentStatus.inTransit;
    case 'delivered':
      return ShipmentStatus.delivered;
    case 'failed':
      return ShipmentStatus.failed;
    default:
      return ShipmentStatus.pending;
  }
}

String shipmentStatusLabel(ShipmentStatus s) {
  switch (s) {
    case ShipmentStatus.pending:
      return 'Pending';
    case ShipmentStatus.dispatched:
      return 'Dispatched';
    case ShipmentStatus.inTransit:
      return 'In Transit';
    case ShipmentStatus.delivered:
      return 'Delivered';
    case ShipmentStatus.failed:
      return 'Failed';
  }
}

class ShipmentModel {
  final String id;
  final String orderId;
  final String carrierName;
  final String vehicleNumber;
  final String driverName;
  final String driverPhone;
  final String trackingNumber;
  final String currentLocation;
  final ShipmentStatus status;
  final DateTime? estimatedDeliveryDate;
  final String proofOfDeliveryUrl;
  final DateTime createdAt;

  ShipmentModel({
    required this.id,
    required this.orderId,
    required this.carrierName,
    required this.vehicleNumber,
    required this.driverName,
    required this.driverPhone,
    required this.trackingNumber,
    required this.currentLocation,
    required this.status,
    this.estimatedDeliveryDate,
    required this.proofOfDeliveryUrl,
    required this.createdAt,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      carrierName: json['carrier_name'] as String? ?? '',
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      driverName: json['driver_name'] as String? ?? '',
      driverPhone: json['driver_phone'] as String? ?? '',
      trackingNumber: json['tracking_number'] as String? ?? '',
      currentLocation: json['current_location'] as String? ?? '',
      status: shipmentStatusFromString(json['status'] as String? ?? 'pending'),
      estimatedDeliveryDate: json['estimated_delivery_date'] != null
          ? DateTime.tryParse(json['estimated_delivery_date'] as String)
          : null,
      proofOfDeliveryUrl: json['proof_of_delivery_url'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
