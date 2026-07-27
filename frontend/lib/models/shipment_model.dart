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

String shipmentStatusToApiString(ShipmentStatus s) {
  switch (s) {
    case ShipmentStatus.dispatched:
      return 'dispatched';
    case ShipmentStatus.inTransit:
      return 'in_transit';
    case ShipmentStatus.delivered:
      return 'delivered';
    case ShipmentStatus.failed:
      return 'failed';
    case ShipmentStatus.pending:
      return 'pending';
  }
}

String shipmentStatusLabel(ShipmentStatus s) {
  switch (s) {
    case ShipmentStatus.pending:
      return 'Pending';
    case ShipmentStatus.dispatched:
      return 'Dispatched';
    case ShipmentStatus.inTransit:
      return 'In transit';
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
