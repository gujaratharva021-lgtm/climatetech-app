import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/commodity_listing_model.dart';
import '../../models/order_model.dart';
import '../../models/payment_model.dart';
import '../../providers/marketplace_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/financing_provider.dart';
import '../../services/ai_trade_service.dart';
import '../ai_assistant/ai_chat_screen.dart' show aiServiceProvider;

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late final Razorpay _razorpay;
  OrderModel? _order;
  PaymentModel? _payment;
  ShipmentModel? _shipment;
  bool _loading = true;
  String? _error;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(orderServiceProvider);
      final order = await service.getOrderDetail(widget.orderId);
      final payment = await service.getPaymentStatus(widget.orderId);
      final shipment = await service.getShipmentByOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _payment = payment;
        _shipment = shipment;
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

  Future<void> _payNow() async {
    try {
      final service = ref.read(orderServiceProvider);
      final data = await service.createPaymentOrder(widget.orderId);
      final amount = (data['amount'] as num).toDouble();
      final options = {
        'key': data['key_id'],
        'amount': (amount * 100).round(),
        'currency': data['currency'] ?? 'INR',
        'name': 'OneClimate AI',
        'description': 'Order payment',
        'order_id': data['razorpay_order_id'],
      };
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final service = ref.read(orderServiceProvider);
      await service.verifyPayment(
        orderId: widget.orderId,
        razorpayOrderId: response.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment verification failed: $e')));
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: ${response.message ?? 'unknown error'}')));
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opened external wallet: ${response.walletName ?? ''}')));
  }

  Future<void> _runAction(Future<bool> Function() action, String successMessage) async {
    setState(() => _actionInProgress = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _actionInProgress = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mySeller = ref.watch(marketplaceProvider).mySeller;

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary), onPressed: () => context.pop()),
        title: const Text('Order Details', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: DarkPalette.textMuted)))
              : _order == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, _order!, mySeller?.id),
    );
  }

  Widget _buildBody(BuildContext context, OrderModel order, String? mySellerId) {
    final isSeller = mySellerId != null && mySellerId == order.sellerId;

    return RefreshIndicator(
      onRefresh: _load,
      color: DarkPalette.leafGreen,
      backgroundColor: DarkPalette.navyCard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(commodityTypeIcon(order.commodityType), color: DarkPalette.leafGreen, size: 22),
                    const SizedBox(width: 10),
                    Text(commodityTypeLabel(order.commodityType),
                        style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(orderStatusLabel(order.status),
                        style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                _row('Quantity', '${order.quantity.toStringAsFixed(0)} ${order.unit}'),
                _row('Price per unit', '\u20b9${order.pricePerUnit.toStringAsFixed(2)}'),
                _row('Total amount', '\u20b9${order.totalAmount.toStringAsFixed(2)}'),
                _row('Delivery address', order.deliveryAddress),
                _row('Source', order.source),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  _payment == null ? 'Not started yet' : paymentStatusLabel(_payment!.status),
                  style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_shipment != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shipment Tracking',
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _row('Status', shipmentStatusLabel(_shipment!.status)),
                  if (_shipment!.carrierName.isNotEmpty) _row('Carrier', _shipment!.carrierName),
                  if (_shipment!.vehicleNumber.isNotEmpty) _row('Vehicle', _shipment!.vehicleNumber),
                  if (_shipment!.driverName.isNotEmpty) _row('Driver', _shipment!.driverName),
                  if (_shipment!.driverPhone.isNotEmpty) _row('Driver phone', _shipment!.driverPhone),
                  if (_shipment!.trackingNumber.isNotEmpty) _row('Tracking #', _shipment!.trackingNumber),
                  if (_shipment!.currentLocation.isNotEmpty) _row('Current location', _shipment!.currentLocation),
                  if (_shipment!.estimatedDeliveryDate != null)
                    _row('Est. delivery',
                        '${_shipment!.estimatedDeliveryDate!.day}/${_shipment!.estimatedDeliveryDate!.month}/${_shipment!.estimatedDeliveryDate!.year}'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (!isSeller && (_payment == null || _payment!.status == PaymentStatus.created))
            ElevatedButton(
              onPressed: _payNow,
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(48)),
              child: const Text('Pay Now'),
            ),
          if (!isSeller) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _showRequestFinancingDialog(context, order.id, order.totalAmount),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Request Financing'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _showDraftContractDialog(context, order.id),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('AI: Draft Contract'),
          ),
          if (!isSeller && order.status == OrderStatus.placed) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _actionInProgress
                  ? null
                  : () => _runAction(() => ref.read(orderProvider.notifier).cancelOrder(order.id, asBuyer: true), 'Order cancelled'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Cancel Order'),
            ),
          ],
          if (!isSeller && order.status == OrderStatus.shipped) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _actionInProgress
                  ? null
                  : () => _runAction(() => ref.read(orderProvider.notifier).deliverOrder(order.id), 'Marked as delivered'),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(48)),
              child: const Text('Mark Delivered'),
            ),
          ],
          if (isSeller && order.status == OrderStatus.placed) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _actionInProgress
                  ? null
                  : () => _runAction(() => ref.read(orderProvider.notifier).confirmOrder(order.id), 'Order confirmed'),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(48)),
              child: const Text('Confirm Order'),
            ),
          ],
          if (isSeller && order.status == OrderStatus.confirmed && _shipment == null) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _showCreateShipmentDialog(context, order.id),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(48)),
              child: const Text('Add Shipment Details & Ship'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _actionInProgress
                  ? null
                  : () => _runAction(() => ref.read(orderProvider.notifier).shipOrder(order.id), 'Order marked shipped'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Mark Shipped (skip details)'),
            ),
          ],
          if (isSeller && _shipment != null && _shipment!.status != ShipmentStatus.delivered && _shipment!.status != ShipmentStatus.failed) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _showUpdateShipmentStatusDialog(context, _shipment!.id),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Update Shipment Status'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRequestFinancingDialog(BuildContext context, String orderId, double defaultAmount) async {
    final amountController = TextEditingController(text: defaultAmount.toStringAsFixed(0));
    final purposeController = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: DarkPalette.navyCard,
            title: const Text('Request Financing', style: TextStyle(color: DarkPalette.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: DarkPalette.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Requested amount (\u20b9)',
                    labelStyle: TextStyle(color: DarkPalette.textMuted),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: purposeController,
                  maxLines: 2,
                  style: const TextStyle(color: DarkPalette.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Purpose (optional)',
                    labelStyle: TextStyle(color: DarkPalette.textMuted),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final amount = double.tryParse(amountController.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('Enter a valid amount')),
                          );
                          return;
                        }
                        setDialogState(() => submitting = true);
                        final ok = await ref.read(financingProvider.notifier).createRequest(
                              orderId: orderId,
                              requestedAmount: amount,
                              purpose: purposeController.text.trim(),
                            );
                        if (!mounted) return;
                        if (ok) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Financing request submitted')),
                          );
                        } else {
                          setDialogState(() => submitting = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(ref.read(financingProvider).myRequestsError ?? 'Could not submit request')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
                child: const Text('Submit'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showDraftContractDialog(BuildContext context, String orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        backgroundColor: DarkPalette.navyCard,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: DarkPalette.leafGreen),
            SizedBox(width: 16),
            Text('Drafting contract...', style: TextStyle(color: DarkPalette.textPrimary)),
          ],
        ),
      ),
    );

    try {
      final data = await ref.read(aiServiceProvider).draftContract(orderId);
      if (!mounted) return;
      Navigator.pop(context);
      final contractText = data['contract_text'] as String? ?? '';
      final disclaimer = data['disclaimer'] as String? ?? '';
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: DarkPalette.navyCard,
          title: const Text('Draft Contract', style: TextStyle(color: DarkPalette.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contractText, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 12),
                Text(disclaimer, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showCreateShipmentDialog(BuildContext context, String orderId) async {
    final carrierController = TextEditingController();
    final vehicleController = TextEditingController();
    final driverNameController = TextEditingController();
    final driverPhoneController = TextEditingController();
    final trackingController = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: DarkPalette.navyCard,
            title: const Text('Shipment Details', style: TextStyle(color: DarkPalette.textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: carrierController,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Carrier name', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: vehicleController,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Vehicle number (optional)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: driverNameController,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Driver name (optional)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: driverPhoneController,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Driver phone (optional)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: trackingController,
                    style: const TextStyle(color: DarkPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Tracking number (optional)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
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
                        final carrier = carrierController.text.trim();
                        if (carrier.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('Carrier name is required')),
                          );
                          return;
                        }
                        setDialogState(() => submitting = true);
                        final ok = await ref.read(orderProvider.notifier).createShipment(
                              orderId: orderId,
                              carrierName: carrier,
                              vehicleNumber: vehicleController.text.trim(),
                              driverName: driverNameController.text.trim(),
                              driverPhone: driverPhoneController.text.trim(),
                              trackingNumber: trackingController.text.trim(),
                            );
                        if (!mounted) return;
                        if (ok) {
                          Navigator.pop(dialogContext);
                          _load();
                        } else {
                          setDialogState(() => submitting = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Could not save shipment details')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
                child: const Text('Save & Ship'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showUpdateShipmentStatusDialog(BuildContext context, String shipmentId) async {
    String selectedStatus = 'dispatched';
    final locationController = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: DarkPalette.navyCard,
            title: const Text('Update Shipment Status', style: TextStyle(color: DarkPalette.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedStatus,
                  dropdownColor: DarkPalette.navyCard,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'dispatched', child: Text('Dispatched', style: TextStyle(color: DarkPalette.textPrimary))),
                    DropdownMenuItem(value: 'in_transit', child: Text('In Transit', style: TextStyle(color: DarkPalette.textPrimary))),
                    DropdownMenuItem(value: 'delivered', child: Text('Delivered', style: TextStyle(color: DarkPalette.textPrimary))),
                    DropdownMenuItem(value: 'failed', child: Text('Failed', style: TextStyle(color: DarkPalette.textPrimary))),
                  ],
                  onChanged: (v) => setDialogState(() => selectedStatus = v ?? selectedStatus),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationController,
                  style: const TextStyle(color: DarkPalette.textPrimary),
                  decoration: const InputDecoration(labelText: 'Current location (optional)', labelStyle: TextStyle(color: DarkPalette.textMuted)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setDialogState(() => submitting = true);
                        final ok = await ref.read(orderProvider.notifier).updateShipmentStatus(
                              orderId: widget.orderId,
                              shipmentId: shipmentId,
                              status: selectedStatus,
                              currentLocation: locationController.text.trim(),
                            );
                        if (!mounted) return;
                        if (ok) {
                          Navigator.pop(dialogContext);
                          _load();
                        } else {
                          setDialogState(() => submitting = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Could not update shipment status')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
                child: const Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 12.5))),
          Expanded(child: Text(value, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12.5))),
        ],
      ),
    );
  }
}
