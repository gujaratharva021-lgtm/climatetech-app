import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shipment_service.dart';
import 'auth_provider.dart';

final shipmentServiceProvider = Provider<ShipmentService>((ref) {
  return ShipmentService(ref.read(apiServiceProvider));
});
