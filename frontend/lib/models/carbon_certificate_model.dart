class CarbonCertificateModel {
  final String id;
  final String sellerId;
  final String? listingId;
  final String registry;
  final String projectName;
  final String projectId;
  final String projectType;
  final int vintageYear;
  final String serialNumberRange;
  final double totalQuantity;
  final double remainingQuantity;
  final String status;
  final DateTime createdAt;

  CarbonCertificateModel({
    required this.id,
    required this.sellerId,
    this.listingId,
    required this.registry,
    required this.projectName,
    required this.projectId,
    required this.projectType,
    required this.vintageYear,
    required this.serialNumberRange,
    required this.totalQuantity,
    required this.remainingQuantity,
    required this.status,
    required this.createdAt,
  });

  factory CarbonCertificateModel.fromJson(Map<String, dynamic> json) {
    return CarbonCertificateModel(
      id: json['id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      listingId: json['listing_id'] as String?,
      registry: json['registry'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      projectType: json['project_type'] as String? ?? '',
      vintageYear: (json['vintage_year'] as num?)?.toInt() ?? 0,
      serialNumberRange: json['serial_number_range'] as String? ?? '',
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0,
      remainingQuantity: (json['remaining_quantity'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class CreditRetirementModel {
  final String id;
  final String certificateId;
  final String retiredByUserId;
  final double quantity;
  final String beneficiaryName;
  final String retirementReason;
  final String referenceNumber;
  final DateTime createdAt;

  CreditRetirementModel({
    required this.id,
    required this.certificateId,
    required this.retiredByUserId,
    required this.quantity,
    required this.beneficiaryName,
    required this.retirementReason,
    required this.referenceNumber,
    required this.createdAt,
  });

  factory CreditRetirementModel.fromJson(Map<String, dynamic> json) {
    return CreditRetirementModel(
      id: json['id'] as String? ?? '',
      certificateId: json['certificate_id'] as String? ?? '',
      retiredByUserId: json['retired_by_user_id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      beneficiaryName: json['beneficiary_name'] as String? ?? '',
      retirementReason: json['retirement_reason'] as String? ?? '',
      referenceNumber: json['reference_number'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
