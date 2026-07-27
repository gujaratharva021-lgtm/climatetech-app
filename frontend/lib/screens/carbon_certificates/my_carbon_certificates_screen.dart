import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/carbon_certificate_model.dart';
import '../../providers/carbon_certificate_provider.dart';

class MyCarbonCertificatesScreen extends ConsumerStatefulWidget {
  const MyCarbonCertificatesScreen({super.key});

  @override
  ConsumerState<MyCarbonCertificatesScreen> createState() => _MyCarbonCertificatesScreenState();
}

class _MyCarbonCertificatesScreenState extends ConsumerState<MyCarbonCertificatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(carbonCertificateProvider.notifier).loadMyCertificates();
    });
  }

  Future<void> _showCreateDialog() async {
    final registryController = TextEditingController();
    final projectNameController = TextEditingController();
    final vintageController = TextEditingController();
    final quantityController = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: DarkPalette.navyCard,
            title: const Text('Register Carbon Certificate', style: TextStyle(color: DarkPalette.textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: registryController,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Registry (e.g. Verra)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: projectNameController,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Project name', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: vintageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Vintage year', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Total quantity (tCO2e)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final registry = registryController.text.trim();
                        final projectName = projectNameController.text.trim();
                        final vintage = int.tryParse(vintageController.text.trim());
                        final quantity = double.tryParse(quantityController.text.trim());
                        if (registry.isEmpty || projectName.isEmpty || vintage == null || quantity == null || quantity <= 0) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('Fill all fields with valid values')),
                          );
                          return;
                        }
                        setDialogState(() => submitting = true);
                        final ok = await ref.read(carbonCertificateProvider.notifier).createCertificate(
                              registry: registry,
                              projectName: projectName,
                              vintageYear: vintage,
                              totalQuantity: quantity,
                            );
                        if (!mounted) return;
                        if (ok) {
                          Navigator.pop(dialogContext);
                        } else {
                          setDialogState(() => submitting = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(ref.read(carbonCertificateProvider).myCertificatesError ?? 'Could not register')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
                child: const Text('Register'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showRetireDialog(CarbonCertificateModel cert) async {
    final quantityController = TextEditingController();
    final beneficiaryController = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: DarkPalette.navyCard,
            title: const Text('Retire Credits', style: TextStyle(color: DarkPalette.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: DarkPalette.textPrimary),
                  decoration: const InputDecoration(labelText: 'Quantity (tCO2e)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: beneficiaryController,
                  style: const TextStyle(color: DarkPalette.textPrimary),
                  decoration: const InputDecoration(labelText: 'Beneficiary (optional)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final quantity = double.tryParse(quantityController.text.trim());
                        if (quantity == null || quantity <= 0) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('Enter a valid quantity')),
                          );
                          return;
                        }
                        setDialogState(() => submitting = true);
                        final ok = await ref.read(carbonCertificateProvider.notifier).retireCredits(
                              certificateId: cert.id,
                              quantity: quantity,
                              beneficiaryName: beneficiaryController.text.trim(),
                            );
                        if (!mounted) return;
                        if (ok) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credits retired')));
                        } else {
                          setDialogState(() => submitting = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(ref.read(carbonCertificateProvider).myRetirementsError ?? 'Could not retire credits')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
                child: const Text('Retire'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(carbonCertificateProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Carbon Certificates', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DarkPalette.leafGreen,
        foregroundColor: Colors.black,
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(carbonCertificateProvider.notifier).loadMyCertificates(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: Builder(builder: (context) {
          if (state.myCertificatesStatus == LoadStatus.loading && state.myCertificates.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
          }
          if (state.myCertificates.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(
                    child: Text(
                      'No carbon certificates yet.\nTap + to register one.',
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
            itemCount: state.myCertificates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _certCard(state.myCertificates[i]),
          );
        }),
      ),
    );
  }

  Widget _certCard(CarbonCertificateModel cert) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showRetireDialog(cert),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forest_rounded, color: DarkPalette.leafGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cert.projectName,
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                Text(cert.status == 'fully_retired' ? 'Fully retired' : 'Active',
                    style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${cert.registry} \u00b7 Vintage ${cert.vintageYear}',
                style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text('${cert.remainingQuantity.toStringAsFixed(1)} / ${cert.totalQuantity.toStringAsFixed(1)} tCO2e remaining',
                style: const TextStyle(color: DarkPalette.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
