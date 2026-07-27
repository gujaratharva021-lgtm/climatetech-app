import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/financing_model.dart';
import '../../providers/financing_provider.dart';

class MyFinancingScreen extends ConsumerStatefulWidget {
  const MyFinancingScreen({super.key});

  @override
  ConsumerState<MyFinancingScreen> createState() => _MyFinancingScreenState();
}

class _MyFinancingScreenState extends ConsumerState<MyFinancingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(financingProvider.notifier).loadMyRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financingProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Trade Finance', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(financingProvider.notifier).loadMyRequests(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: Builder(builder: (context) {
          if (state.myRequestsStatus == LoadStatus.loading && state.myRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
          }
          if (state.myRequests.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: Text('No financing requests yet.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            itemCount: state.myRequests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _requestCard(state.myRequests[i]),
          );
        }),
      ),
    );
  }

  Widget _requestCard(FinancingRequestModel req) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('₹${req.requestedAmount.toStringAsFixed(0)} requested',
                    style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: DarkPalette.cyanAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(financingStatusLabel(req.status), style: const TextStyle(color: DarkPalette.cyanAccent, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (req.purpose.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(req.purpose, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
          ],
          if (req.approvedAmount > 0) ...[
            const SizedBox(height: 6),
            Text('Approved: ₹${req.approvedAmount.toStringAsFixed(0)} @ ${req.interestRate}% p.a.',
                style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
