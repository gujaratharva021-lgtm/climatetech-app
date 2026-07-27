import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/rfq_model.dart';
import '../../providers/rfq_provider.dart';

class MyBidsScreen extends ConsumerStatefulWidget {
  const MyBidsScreen({super.key});

  @override
  ConsumerState<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends ConsumerState<MyBidsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(rfqProvider.notifier).loadMyBids();
      }
    });
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
        title: const Text('My Bids', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(rfqProvider.notifier).loadMyBids(),
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
    if (state.myBidsStatus == LoadStatus.loading && state.myBids.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
      );
    }
    if (state.myBidsStatus == LoadStatus.error && state.myBids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(state.myBidsError ?? 'Could not load your bids.', textAlign: TextAlign.center, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(rfqProvider.notifier).loadMyBids(),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (state.myBids.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("You haven't placed any bids yet.", style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.myBids.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _bidTile(state.myBids[i]),
    );
  }

  Widget _bidTile(BidModel bid) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/rfq/${bid.rfqId}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₹${bid.price.toStringAsFixed(0)}/unit  ·  ${bid.quantity.toStringAsFixed(0)} units',
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (bid.message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(bid.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
                  ],
                ],
              ),
            ),
            Text(bidStatusLabel(bid.status), style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
