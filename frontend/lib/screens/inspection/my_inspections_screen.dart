import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/inspection_model.dart';
import '../../providers/inspection_provider.dart';

class MyInspectionsScreen extends ConsumerStatefulWidget {
  const MyInspectionsScreen({super.key});

  @override
  ConsumerState<MyInspectionsScreen> createState() => _MyInspectionsScreenState();
}

class _MyInspectionsScreenState extends ConsumerState<MyInspectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(inspectionProvider.notifier).loadMyInspections();
    });
  }

  void _showRequestSheet() {
    final orderIdController = TextEditingController();
    final notesController = TextEditingController();
    String selectedType = 'pre_shipment';

    showModalBottomSheet(
      context: context,
      backgroundColor: DarkPalette.navyCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Request Inspection',
                    style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                  controller: orderIdController,
                  style: const TextStyle(color: DarkPalette.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Order ID',
                    hintStyle: const TextStyle(color: DarkPalette.textMuted),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Pre-shipment'),
                        selected: selectedType == 'pre_shipment',
                        onSelected: (_) => setSheetState(() => selectedType = 'pre_shipment'),
                        selectedColor: DarkPalette.leafGreen,
                        labelStyle: TextStyle(color: selectedType == 'pre_shipment' ? Colors.black : DarkPalette.textSecondary),
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Post-delivery'),
                        selected: selectedType == 'post_delivery',
                        onSelected: (_) => setSheetState(() => selectedType = 'post_delivery'),
                        selectedColor: DarkPalette.leafGreen,
                        labelStyle: TextStyle(color: selectedType == 'post_delivery' ? Colors.black : DarkPalette.textSecondary),
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: const TextStyle(color: DarkPalette.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Notes (optional)',
                    hintStyle: const TextStyle(color: DarkPalette.textMuted),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
                    onPressed: () async {
                      if (orderIdController.text.trim().isEmpty) return;
                      final ok = await ref.read(inspectionProvider.notifier).createRequest(
                            orderId: orderIdController.text.trim(),
                            inspectionType: selectedType,
                            notes: notesController.text.trim(),
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Inspection requested' : 'Could not request inspection')),
                        );
                      }
                    },
                    child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Quality & Inspection', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DarkPalette.leafGreen,
        foregroundColor: Colors.black,
        onPressed: _showRequestSheet,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(inspectionProvider.notifier).loadMyInspections(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: Builder(builder: (context) {
          if (state.myStatus == LoadStatus.loading && state.myInspections.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
          }
          if (state.myInspections.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(
                    child: Text(
                      'No inspection requests yet.\nTap + to request one against an order.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DarkPalette.textMuted, fontSize: 13),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            itemCount: state.myInspections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _inspectionCard(state.myInspections[i]),
          );
        }),
      ),
    );
  }

  Widget _inspectionCard(InspectionModel insp) {
    final typeLabel = insp.inspectionType == 'pre_shipment' ? 'Pre-shipment' : 'Post-delivery';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(typeLabel, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: DarkPalette.cyanAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(inspectionStatusLabel(insp.status),
                    style: const TextStyle(color: DarkPalette.cyanAccent, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (insp.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(insp.notes, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12.5)),
          ],
          if (insp.status == InspectionStatus.completed) ...[
            const SizedBox(height: 6),
            Text('Result: ${insp.result}${insp.grade.isNotEmpty ? ' · Grade: ${insp.grade}' : ''}',
                style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          if (insp.status == InspectionStatus.pending || insp.status == InspectionStatus.assigned || insp.status == InspectionStatus.scheduled) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final ok = await ref.read(inspectionProvider.notifier).cancelInspection(insp.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Inspection cancelled' : 'Could not cancel')),
                    );
                  }
                },
                child: const Text('Cancel', style: TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}