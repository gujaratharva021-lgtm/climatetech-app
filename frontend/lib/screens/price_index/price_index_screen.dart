import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../models/price_index_model.dart';
import '../../providers/price_index_provider.dart';
import '../../providers/marketplace_provider.dart' show LoadStatus;

class PriceIndexScreen extends ConsumerWidget {
  const PriceIndexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(priceIndexProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Live Price Index', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(priceIndexProvider.notifier).loadAll(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PriceIndexState state) {
    if (state.status == LoadStatus.loading && state.indexes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
      );
    }
    if (state.status == LoadStatus.error && state.indexes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(state.error ?? 'Could not load price index.', textAlign: TextAlign.center, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    if (state.indexes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('No price data yet.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: state.indexes.map((index) => _indexCard(context, index)).toList(),
    );
  }

  Widget _indexCard(BuildContext context, LiveIndexModel index) {
    final band = index.transactedBands.isNotEmpty ? index.transactedBands.first : (index.listingBands.isNotEmpty ? index.listingBands.first : null);
    final isTransacted = index.transactedBands.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(commodityTypeIcon(index.commodityType), color: DarkPalette.leafGreen, size: 20),
              const SizedBox(width: 8),
              Text(commodityTypeLabel(index.commodityType),
                  style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PriceHistoryScreen(commodityType: index.commodityType)),
                ),
                child: const Text('History', style: TextStyle(color: DarkPalette.cyanAccent, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (band == null)
            const Text('No price data available.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 12.5))
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${band.avgPrice.toStringAsFixed(0)}',
                    style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('/${band.unit}', style: const TextStyle(color: DarkPalette.textMuted, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: DarkPalette.cyanAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(isTransacted ? 'Market price' : 'Asking price',
                        style: const TextStyle(color: DarkPalette.cyanAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Range: ₹${band.minPrice.toStringAsFixed(0)} – ₹${band.maxPrice.toStringAsFixed(0)}  ·  ${band.sampleSize} samples',
                style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

class PriceHistoryScreen extends ConsumerStatefulWidget {
  final String commodityType;
  const PriceHistoryScreen({super.key, required this.commodityType});

  @override
  ConsumerState<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  List<PriceHistoryPoint> _points = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final points = await ref.read(priceIndexProvider.notifier).loadHistory(widget.commodityType);
      if (!mounted) return;
      setState(() {
        _points = points;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => Navigator.of(context).pop()),
        title: Text('${commodityTypeLabel(widget.commodityType)} price history', style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 15)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 13)))
              : _points.isEmpty
                  ? const Center(child: Text('No history recorded yet.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13)))
                  : Padding(
                      padding: const EdgeInsets.all(18),
                      child: _chart(),
                    ),
    );
  }

  Widget _chart() {
    final spots = <FlSpot>[];
    for (var i = 0; i < _points.length; i++) {
      spots.add(FlSpot(i.toDouble(), _points[i].avgPrice));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: DarkPalette.leafGreen,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: DarkPalette.leafGreen.withOpacity(0.12)),
          ),
        ],
      ),
    );
  }
}
