import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../models/rfq_model.dart';
import '../../providers/rfq_provider.dart';

class MyRFQsScreen extends ConsumerStatefulWidget {
  const MyRFQsScreen({super.key});

  @override
  ConsumerState<MyRFQsScreen> createState() => _MyRFQsScreenState();
}

class _MyRFQsScreenState extends ConsumerState<MyRFQsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(rfqProvider.notifier).loadMyRFQs();
      }
    });
  }

  Future<void> _cancel(RFQModel rfq) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkPalette.navyCard,
        title: const Text('Cancel RFQ?', style: TextStyle(color: DarkPalette.textPrimary)),
        content: const Text('Sellers will no longer be able to bid on this requirement.', style: TextStyle(color: DarkPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel RFQ', style: TextStyle(color: Color(0xFFE0605A)))),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await ref.read(rfqProvider.notifier).cancelRFQ(rfq.id);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(rfqProvider).myRFQsError ?? 'Could not cancel RFQ.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rfqProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('My RFQs', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(rfqProvider.notifier).loadMyRFQs(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: _buildBody(state),
        ),
      ),
    );
  }

  Widget _buildBody(RFQState state) {
    if (state.myRFQsStatus == LoadStatus.loading && state.myRFQs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
      );
    }
    if (state.myRFQsStatus == LoadStatus.error && state.myRFQs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(state.myRFQsError ?? 'Could not load your RFQs.', textAlign: TextAlign.center, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(rfqProvider.notifier).loadMyRFQs(),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (state.myRFQs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("You haven't posted any RFQs yet.", style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.myRFQs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _rfqTile(state.myRFQs[i]),
    );
  }

  Widget _rfqTile(RFQModel rfq) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/rfq/${rfq.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(commodityTypeIcon(rfq.commodityType), color: DarkPalette.leafGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${rfq.quantity.toStringAsFixed(0)} ${rfq.unit} ${commodityTypeLabel(rfq.commodityType)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: rfqStatusColor(rfq.status).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(rfqStatusLabel(rfq.status), style: TextStyle(color: rfqStatusColor(rfq.status), fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            if (rfq.status == RFQStatus.open)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFFE0605A), size: 20),
                onPressed: () => _cancel(rfq),
              ),
          ],
        ),
      ),
    );
  }
}
