enum VehicleStatus { available, booked, maintenance, inactive }

VehicleStatus vehicleStatusFromString(String s) {
  switch (s) {
    case 'booked':
      return VehicleStatus.booked;
    case 'maintenance':
      return VehicleStatus.maintenance;
    case 'inactive':
      return VehicleStatus.inactive;
    default:
      return VehicleStatus.available;
  }
}

String vehicleStatusLabel(VehicleStatus s) {
  switch (s) {
    case VehicleStatus.available:
      return 'Available';
    case VehicleStatus.booked:
      return 'Booked';
    case VehicleStatus.maintenance:
      return 'Maintenance';
    case VehicleStatus.inactive:
      return 'Inactive';
  }
}

enum BookingStatus { pending, confirmed, inTransit, delivered, cancelled }

BookingStatus bookingStatusFromString(String s) {
  switch (s) {
    case 'confirmed':
      return BookingStatus.confirmed;
    case 'in_transit':
      return BookingStatus.inTransit;
    case 'delivered':
      return BookingStatus.delivered;
    case 'cancelled':
      return BookingStatus.cancelled;
    default:
      return BookingStatus.pending;
  }
}

String bookingStatusToApiString(BookingStatus s) {
  switch (s) {
    case BookingStatus.confirmed:
      return 'confirmed';
    case BookingStatus.inTransit:
      return 'in_transit';
    case BookingStatus.delivered:
      return 'delivered';
    case BookingStatus.cancelled:
      return 'cancelled';
    case BookingStatus.pending:
      return 'pending';
  }
}

String bookingStatusLabel(BookingStatus s) {
  switch (s) {
    case BookingStatus.pending:
      return 'Pending';
    case BookingStatus.confirmed:
      return 'Confirmed';
    case BookingStatus.inTransit:
      return 'In Transit';
    case BookingStatus.delivered:
      return 'Delivered';
    case BookingStatus.cancelled:
      return 'Cancelled';
  }
}

class VehicleModel {
  final String id;
  final String ownerId;
  final String vehicleType;
  final String regNumber;
  final double capacityKg;
  final String capacityUnit;
  final String baseLocation;
  final double pricePerKm;
  final VehicleStatus status;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.ownerId,
    required this.vehicleType,
    required this.regNumber,
    required this.capacityKg,
    required this.capacityUnit,
    required this.baseLocation,
    required this.pricePerKm,
    required this.status,
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? 'truck',
      regNumber: json['reg_number'] as String? ?? '',
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 0,
      capacityUnit: json['capacity_unit'] as String? ?? 'kg',
      baseLocation: json['base_location'] as String? ?? '',
      pricePerKm: (json['price_per_km'] as num?)?.toDouble() ?? 0,
      status: vehicleStatusFromString(json['status'] as String? ?? 'available'),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class BookingModel {
  final String id;
  final String vehicleId;
  final VehicleModel? vehicle;
  final String bookedByUserId;
  final String pickupLocation;
  final String dropLocation;
  final String cargoDetails;
  final double weightKg;
  final DateTime? scheduledPickup;
  final BookingStatus status;
  final double estimatedCost;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.vehicleId,
    this.vehicle,
    required this.bookedByUserId,
    required this.pickupLocation,
    required this.dropLocation,
    required this.cargoDetails,
    required this.weightKg,
    this.scheduledPickup,
    required this.status,
    required this.estimatedCost,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      vehicle: json['vehicle'] != null ? VehicleModel.fromJson(json['vehicle'] as Map<String, dynamic>) : null,
      bookedByUserId: json['booked_by_user_id'] as String? ?? '',
      pickupLocation: json['pickup_location'] as String? ?? '',
      dropLocation: json['drop_location'] as String? ?? '',
      cargoDetails: json['cargo_details'] as String? ?? '',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      scheduledPickup:
          json['scheduled_pickup'] != null ? DateTime.tryParse(json['scheduled_pickup'] as String) : null,
      status: bookingStatusFromString(json['status'] as String? ?? 'pending'),
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
