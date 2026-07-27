import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/dark_palette.dart';
import '../models/logistics_model.dart';
import '../providers/logistics_provider.dart';
import '../providers/marketplace_provider.dart' show LoadStatus;

class LogisticsMyBookingsScreen extends ConsumerStatefulWidget {
  const LogisticsMyBookingsScreen({super.key});

  @override
  ConsumerState<LogisticsMyBookingsScreen> createState() => _LogisticsMyBookingsScreenState();
}

class _LogisticsMyBookingsScreenState extends ConsumerState<LogisticsMyBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(logisticsProvider.notifier).loadMyBookings();
    });
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return const Color(0xFFFFC857);
      case BookingStatus.confirmed:
        return DarkPalette.cyanAccent;
      case BookingStatus.inTransit:
        return const Color(0xFFB98BF0);
      case BookingStatus.delivered:
        return DarkPalette.leafGreen;
      case BookingStatus.cancelled:
        return const Color(0xFFE0605A);
    }
  }

  Future<void> _confirmCancel(BuildContext context, BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkPalette.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel booking?', style: TextStyle(color: DarkPalette.textPrimary)),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: DarkPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: DarkPalette.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel', style: TextStyle(color: Color(0xFFE0605A))),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(logisticsProvider.notifier).cancelBooking(booking.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Booking cancelled' : 'Could not cancel booking')),
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
        title: const Text('My Bookings'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(logisticsProvider.notifier).loadMyBookings(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: state.bookingsStatus == LoadStatus.loading
            ? const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen))
            : state.bookingsStatus == LoadStatus.error
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          state.bookingsError ?? 'Something went wrong',
                          style: const TextStyle(color: DarkPalette.textSecondary),
                        ),
                      ),
                    ],
                  )
                : state.bookings.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text('No bookings yet',
                                style: TextStyle(color: DarkPalette.textMuted)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.bookings.length,
                        itemBuilder: (context, index) {
                          final b = state.bookings[index];
                          final canCancel =
                              b.status == BookingStatus.pending || b.status == BookingStatus.confirmed;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: DarkPalette.navyCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: DarkPalette.glassBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${b.pickupLocation} → ${b.dropLocation}',
                                        style: const TextStyle(
                                            color: DarkPalette.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(b.status).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _statusColor(b.status).withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        bookingStatusLabel(b.status),
                                        style: TextStyle(
                                          color: _statusColor(b.status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (b.vehicle != null)
                                  Text(
                                    '${b.vehicle!.vehicleType.toUpperCase()} · ${b.vehicle!.regNumber}',
                                    style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12),
                                  ),
                                Text(
                                  'Cargo: ${b.cargoDetails.isEmpty ? '-' : b.cargoDetails}',
                                  style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12),
                                ),
                                Text(
                                  'Weight: ${b.weightKg} kg',
                                  style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12),
                                ),
                                if (b.scheduledPickup != null)
                                  Text(
                                    'Scheduled: ${b.scheduledPickup}',
                                    style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Est. cost: ₹${b.estimatedCost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: DarkPalette.leafGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (canCancel) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _confirmCancel(context, b),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFFE0605A),
                                      ),
                                      child: const Text('Cancel booking'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
