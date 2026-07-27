enum PaymentStatus { created, paid, released, refunded, failed }

PaymentStatus paymentStatusFromString(String s) {
  switch (s) {
    case 'paid':
      return PaymentStatus.paid;
    case 'released':
      return PaymentStatus.released;
    case 'refunded':
      return PaymentStatus.refunded;
    case 'failed':
      return PaymentStatus.failed;
    default:
      return PaymentStatus.created;
  }
}

String paymentStatusLabel(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.created:
      return 'Awaiting payment';
    case PaymentStatus.paid:
      return 'Paid';
    case PaymentStatus.released:
      return 'Released to seller';
    case PaymentStatus.refunded:
      return 'Refunded';
    case PaymentStatus.failed:
      return 'Failed';
  }
}

class PaymentModel {
  final String id;
  final String orderId;
  final String razorpayOrderId;
  final String razorpayPaymentId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    required this.orderId,
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      razorpayOrderId: json['razorpay_order_id'] as String? ?? '',
      razorpayPaymentId: json['razorpay_payment_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      status: paymentStatusFromString(json['status'] as String? ?? 'created'),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
