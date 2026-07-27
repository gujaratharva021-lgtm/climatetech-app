enum FinancingStatus { pending, underReview, approved, rejected, disbursed, repaid, defaulted }

FinancingStatus financingStatusFromString(String s) {
  switch (s) {
    case 'under_review':
      return FinancingStatus.underReview;
    case 'approved':
      return FinancingStatus.approved;
    case 'rejected':
      return FinancingStatus.rejected;
    case 'disbursed':
      return FinancingStatus.disbursed;
    case 'repaid':
      return FinancingStatus.repaid;
    case 'defaulted':
      return FinancingStatus.defaulted;
    default:
      return FinancingStatus.pending;
  }
}

String financingStatusLabel(FinancingStatus s) {
  switch (s) {
    case FinancingStatus.pending:
      return 'Pending';
    case FinancingStatus.underReview:
      return 'Under review';
    case FinancingStatus.approved:
      return 'Approved';
    case FinancingStatus.rejected:
      return 'Rejected';
    case FinancingStatus.disbursed:
      return 'Disbursed';
    case FinancingStatus.repaid:
      return 'Repaid';
    case FinancingStatus.defaulted:
      return 'Defaulted';
  }
}

class FinancingRequestModel {
  final String id;
  final String orderId;
  final String requesterId;
  final String requesterRole;
  final double requestedAmount;
  final String purpose;
  final FinancingStatus status;
  final String lenderName;
  final double approvedAmount;
  final double interestRate;
  final String adminNotes;
  final DateTime? disbursedAt;
  final DateTime? repaidAt;
  final DateTime createdAt;

  FinancingRequestModel({
    required this.id,
    required this.orderId,
    required this.requesterId,
    required this.requesterRole,
    required this.requestedAmount,
    required this.purpose,
    required this.status,
    required this.lenderName,
    required this.approvedAmount,
    required this.interestRate,
    required this.adminNotes,
    this.disbursedAt,
    this.repaidAt,
    required this.createdAt,
  });

  factory FinancingRequestModel.fromJson(Map<String, dynamic> json) {
    return FinancingRequestModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      requesterRole: json['requester_role'] as String? ?? 'buyer',
      requestedAmount: (json['requested_amount'] as num?)?.toDouble() ?? 0,
      purpose: json['purpose'] as String? ?? '',
      status: financingStatusFromString(json['status'] as String? ?? 'pending'),
      lenderName: json['lender_name'] as String? ?? '',
      approvedAmount: (json['approved_amount'] as num?)?.toDouble() ?? 0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0,
      adminNotes: json['admin_notes'] as String? ?? '',
      disbursedAt: json['disbursed_at'] != null ? DateTime.tryParse(json['disbursed_at'] as String) : null,
      repaidAt: json['repaid_at'] != null ? DateTime.tryParse(json['repaid_at'] as String) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
