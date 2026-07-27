import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/logistics_model.dart';
import '../services/logistics_service.dart';
import 'auth_provider.dart';
import 'marketplace_provider.dart' show LoadStatus;

final logisticsServiceProvider = Provider<LogisticsService>((ref) {
  return LogisticsService(ref.read(apiServiceProvider));
});

class LogisticsState {
  final LoadStatus browseStatus;
  final List<VehicleModel> vehicles;
  final String? browseError;

  final LoadStatus bookingsStatus;
  final List<BookingModel> bookings;
  final String? bookingsError;

  final bool isBooking;
  final String? bookingActionError;

  const LogisticsState({
    this.browseStatus = LoadStatus.initial,
    this.vehicles = const [],
    this.browseError,
    this.bookingsStatus = LoadStatus.initial,
    this.bookings = const [],
    this.bookingsError,
    this.isBooking = false,
    this.bookingActionError,
  });

  LogisticsState copyWith({
    LoadStatus? browseStatus,
    List<VehicleModel>? vehicles,
    String? browseError,
    LoadStatus? bookingsStatus,
    List<BookingModel>? bookings,
    String? bookingsError,
    bool? isBooking,
    String? bookingActionError,
  }) {
    return LogisticsState(
      browseStatus: browseStatus ?? this.browseStatus,
      vehicles: vehicles ?? this.vehicles,
      browseError: browseError,
      bookingsStatus: bookingsStatus ?? this.bookingsStatus,
      bookings: bookings ?? this.bookings,
      bookingsError: bookingsError,
      isBooking: isBooking ?? this.isBooking,
      bookingActionError: bookingActionError,
    );
  }
}

class LogisticsNotifier extends StateNotifier<LogisticsState> {
  final LogisticsService _service;

  String? _vehicleType;
  String? _location;

  LogisticsNotifier(this._service) : super(const LogisticsState()) {
    loadVehicles();
  }

  Future<void> loadVehicles({String? vehicleType, String? location}) async {
    _vehicleType = vehicleType ?? _vehicleType;
    _location = location ?? _location;

    state = state.copyWith(browseStatus: LoadStatus.loading, browseError: null);
    try {
      final vehicles = await _service.browseVehicles(vehicleType: _vehicleType, location: _location);
      state = state.copyWith(browseStatus: LoadStatus.loaded, vehicles: vehicles);
    } catch (e) {
      state = state.copyWith(browseStatus: LoadStatus.error, browseError: e.toString());
    }
  }

  /// Explicitly clears an active filter (loadVehicles' own params only ever
  /// add/replace a filter, never remove one, since `?? _vehicleType` can't
  /// distinguish "no change" from "clear this").
  Future<void> setFilters({String? vehicleType, String? location}) async {
    _vehicleType = vehicleType;
    _location = location;
    state = state.copyWith(browseStatus: LoadStatus.loading, browseError: null);
    try {
      final vehicles = await _service.browseVehicles(vehicleType: _vehicleType, location: _location);
      state = state.copyWith(browseStatus: LoadStatus.loaded, vehicles: vehicles);
    } catch (e) {
      state = state.copyWith(browseStatus: LoadStatus.error, browseError: e.toString());
    }
  }

  Future<void> loadMyBookings() async {
    state = state.copyWith(bookingsStatus: LoadStatus.loading, bookingsError: null);
    try {
      final bookings = await _service.getMyBookings();
      state = state.copyWith(bookingsStatus: LoadStatus.loaded, bookings: bookings);
    } catch (e) {
      state = state.copyWith(bookingsStatus: LoadStatus.error, bookingsError: e.toString());
    }
  }

  Future<bool> bookVehicle({
    required String vehicleId,
    required String pickupLocation,
    required String dropLocation,
    String? cargoDetails,
    required double weightKg,
    DateTime? scheduledPickup,
  }) async {
    state = state.copyWith(isBooking: true, bookingActionError: null);
    try {
      final booking = await _service.createBooking(
        vehicleId: vehicleId,
        pickupLocation: pickupLocation,
        dropLocation: dropLocation,
        cargoDetails: cargoDetails,
        weightKg: weightKg,
        scheduledPickup: scheduledPickup,
      );
      state = state.copyWith(isBooking: false, bookings: [booking, ...state.bookings]);
      return true;
    } catch (e) {
      state = state.copyWith(isBooking: false, bookingActionError: e.toString());
      return false;
    }
  }

  Future<bool> cancelBooking(String id) async {
    try {
      await _service.updateBookingStatus(id: id, status: BookingStatus.cancelled);
      final idx = state.bookings.indexWhere((b) => b.id == id);
      if (idx == -1) return true;

      final old = state.bookings[idx];
      final updated = BookingModel(
        id: old.id,
        vehicleId: old.vehicleId,
        vehicle: old.vehicle,
        bookedByUserId: old.bookedByUserId,
        pickupLocation: old.pickupLocation,
        dropLocation: old.dropLocation,
        cargoDetails: old.cargoDetails,
        weightKg: old.weightKg,
        scheduledPickup: old.scheduledPickup,
        status: BookingStatus.cancelled,
        estimatedCost: old.estimatedCost,
        createdAt: old.createdAt,
      );

      final newBookings = [...state.bookings];
      newBookings[idx] = updated;
      state = state.copyWith(bookings: newBookings);
      return true;
    } catch (e) {
      state = state.copyWith(bookingActionError: e.toString());
      return false;
    }
  }
}

final logisticsProvider = StateNotifierProvider<LogisticsNotifier, LogisticsState>((ref) {
  return LogisticsNotifier(ref.read(logisticsServiceProvider));
});
