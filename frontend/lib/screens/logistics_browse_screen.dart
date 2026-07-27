import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/dark_palette.dart';
import '../models/logistics_model.dart';
import '../providers/logistics_provider.dart';
import '../providers/marketplace_provider.dart' show LoadStatus;

class LogisticsBrowseScreen extends ConsumerStatefulWidget {
  const LogisticsBrowseScreen({super.key});

  @override
  ConsumerState<LogisticsBrowseScreen> createState() => _LogisticsBrowseScreenState();
}

class _LogisticsBrowseScreenState extends ConsumerState<LogisticsBrowseScreen> {
  final _locationController = TextEditingController();
  String? _selectedType;

  final _vehicleTypes = const ['truck', 'van', 'mini_truck', 'trailer'];

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(logisticsProvider.notifier).setFilters(
          vehicleType: _selectedType,
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
      filled: true,
      fillColor: DarkPalette.glassFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DarkPalette.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DarkPalette.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DarkPalette.leafGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(logisticsProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        foregroundColor: DarkPalette.textPrimary,
        elevation: 0,
        title: const Text('Find a Vehicle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
                        decoration: _fieldDecoration('Location'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        dropdownColor: DarkPalette.navyCard,
                        style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
                        decoration: _fieldDecoration('Vehicle type'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Any')),
                          ..._vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                        ],
                        onChanged: (v) => setState(() => _selectedType = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DarkPalette.leafGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Search', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: DarkPalette.glassBorder),
          Expanded(
            child: state.browseStatus == LoadStatus.loading
                ? const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen))
                : state.browseStatus == LoadStatus.error
                    ? Center(
                        child: Text(
                          state.browseError ?? 'Something went wrong',
                          style: const TextStyle(color: DarkPalette.textSecondary),
                        ),
                      )
                    : state.vehicles.isEmpty
                        ? const Center(
                            child: Text('No vehicles found',
                                style: TextStyle(color: DarkPalette.textMuted)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: state.vehicles.length,
                            itemBuilder: (context, index) {
                              final v = state.vehicles[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: DarkPalette.navyCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: DarkPalette.glassBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${v.vehicleType.toUpperCase()} · ${v.regNumber}',
                                            style: const TextStyle(
                                                color: DarkPalette.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Capacity: ${v.capacityKg} ${v.capacityUnit}',
                                            style: const TextStyle(
                                                color: DarkPalette.textSecondary, fontSize: 12),
                                          ),
                                          Text(
                                            'Base: ${v.baseLocation}',
                                            style: const TextStyle(
                                                color: DarkPalette.textSecondary, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₹${v.pricePerKm}/km · ${vehicleStatusLabel(v.status)}',
                                            style: const TextStyle(
                                                color: DarkPalette.leafGreen,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (v.status == VehicleStatus.available)
                                      IconButton(
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: DarkPalette.primaryButtonGradient,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.add_rounded,
                                              color: Colors.black, size: 18),
                                        ),
                                        onPressed: () => _showBookSheet(context, v),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showBookSheet(BuildContext context, VehicleModel vehicle) {
    final pickupController = TextEditingController();
    final dropController = TextEditingController();
    final cargoController = TextEditingController();
    final weightController = TextEditingController();
    DateTime? scheduledPickup;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DarkPalette.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Book ${vehicle.vehicleType} · ${vehicle.regNumber}',
                      style: const TextStyle(
                          color: DarkPalette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pickupController,
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
                      decoration: _fieldDecoration('Pickup location'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dropController,
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
                      decoration: _fieldDecoration('Drop location'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cargoController,
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
                      decoration: _fieldDecoration('Cargo details'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
                      decoration: _fieldDecoration('Weight (kg)'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DarkPalette.textSecondary,
                        side: const BorderSide(color: DarkPalette.glassBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(scheduledPickup == null
                          ? 'Select pickup date/time'
                          : scheduledPickup.toString()),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                        if (time == null) return;
                        setSheetState(() {
                          scheduledPickup =
                              DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Consumer(
                      builder: (ctx, ref, _) {
                        final isBooking = ref.watch(logisticsProvider.select((s) => s.isBooking));
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DarkPalette.leafGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isBooking
                              ? null
                              : () async {
                                  final weight = double.tryParse(weightController.text.trim());
                                  if (pickupController.text.trim().isEmpty ||
                                      dropController.text.trim().isEmpty ||
                                      weight == null) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Please fill pickup, drop and a valid weight')),
                                    );
                                    return;
                                  }
                                  final ok = await ref.read(logisticsProvider.notifier).bookVehicle(
                                        vehicleId: vehicle.id,
                                        pickupLocation: pickupController.text.trim(),
                                        dropLocation: dropController.text.trim(),
                                        cargoDetails: cargoController.text.trim(),
                                        weightKg: weight,
                                        scheduledPickup: scheduledPickup,
                                      );
                                  if (!ctx.mounted || !context.mounted) return;
                                  if (ok) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(content: Text('Booking created')));
                                  } else {
                                    final err = ref.read(logisticsProvider).bookingActionError;
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(err ?? 'Booking failed')),
                                    );
                                  }
                                },
                          child: isBooking
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.w600)),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
