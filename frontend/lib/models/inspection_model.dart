enum InspectionStatus { pending, assigned, scheduled, completed, cancelled }

InspectionStatus inspectionStatusFromString(String s) {
  switch (s) {
    case 'assigned':
      return InspectionStatus.assigned;
    case 'scheduled':
      return InspectionStatus.scheduled;
    case 'completed':
      return InspectionStatus.completed;
    case 'cancelled':
      return InspectionStatus.cancelled;
    default:
      return InspectionStatus.pending;
  }
}

String inspectionStatusLabel(InspectionStatus s) {
  switch (s) {
    case InspectionStatus.pending:
      return 'Pending';
    case InspectionStatus.assigned:
      return 'Assigned';
    case InspectionStatus.scheduled:
      return 'Scheduled';
    case InspectionStatus.completed:
      return 'Completed';
    case InspectionStatus.cancelled:
      return 'Cancelled';
  }
}

class InspectionModel {
  final String id;
  final String orderId;
  final String requesterId;
  final String requesterRole;
  final String inspectionType;
  final String notes;
  final InspectionStatus status;
  final String? inspectorId;
  final DateTime? scheduledDate;
  final String result;
  final String grade;
  final String reportNotes;
  final String reportFileUrl;
  final DateTime? completedAt;
  final DateTime createdAt;

  InspectionModel({
    required this.id,
    required this.orderId,
    required this.requesterId,
    required this.requesterRole,
    required this.inspectionType,
    required this.notes,
    required this.status,
    this.inspectorId,
    this.scheduledDate,
    required this.result,
    required this.grade,
    required this.reportNotes,
    required this.reportFileUrl,
    this.completedAt,
    required this.createdAt,
  });

  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    return InspectionModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      requesterRole: json['requester_role'] as String? ?? 'buyer',
      inspectionType: json['inspection_type'] as String? ?? 'pre_shipment',
      notes: json['notes'] as String? ?? '',
      status: inspectionStatusFromString(json['status'] as String? ?? 'pending'),
      inspectorId: json['inspector_id'] as String?,
      scheduledDate: json['scheduled_date'] != null ? DateTime.tryParse(json['scheduled_date'] as String) : null,
      result: json['result'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      reportNotes: json['report_notes'] as String? ?? '',
      reportFileUrl: json['report_file_url'] as String? ?? '',
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}