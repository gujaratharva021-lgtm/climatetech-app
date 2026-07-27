class PriceBand {
  final String unit;
  final double avgPrice;
  final double minPrice;
  final double maxPrice;
  final int sampleSize;

  PriceBand({
    required this.unit,
    required this.avgPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.sampleSize,
  });

  factory PriceBand.fromJson(Map<String, dynamic> json) {
    return PriceBand(
      unit: json['unit'] as String? ?? 'unit',
      avgPrice: (json['avg_price'] as num?)?.toDouble() ?? 0,
      minPrice: (json['min_price'] as num?)?.toDouble() ?? 0,
      maxPrice: (json['max_price'] as num?)?.toDouble() ?? 0,
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The current price picture for one commodity: ListingBands reflects what
/// sellers are currently asking, TransactedBands reflects what buyers
/// actually paid in the last 30 days.
class LiveIndexModel {
  final String commodityType;
  final List<PriceBand> listingBands;
  final List<PriceBand> transactedBands;
  final DateTime computedAt;

  LiveIndexModel({
    required this.commodityType,
    required this.listingBands,
    required this.transactedBands,
    required this.computedAt,
  });

  factory LiveIndexModel.fromJson(Map<String, dynamic> json) {
    final listingList = json['listing_bands'] as List<dynamic>? ?? [];
    final transactedList = json['transacted_bands'] as List<dynamic>? ?? [];
    return LiveIndexModel(
      commodityType: json['commodity_type'] as String? ?? 'other',
      listingBands: listingList.map((e) => PriceBand.fromJson(e as Map<String, dynamic>)).toList(),
      transactedBands: transactedList.map((e) => PriceBand.fromJson(e as Map<String, dynamic>)).toList(),
      computedAt: DateTime.tryParse(json['computed_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class PriceHistoryPoint {
  final String unit;
  final String source;
  final double avgPrice;
  final double minPrice;
  final double maxPrice;
  final int sampleSize;
  final DateTime recordedAt;

  PriceHistoryPoint({
    required this.unit,
    required this.source,
    required this.avgPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.sampleSize,
    required this.recordedAt,
  });

  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) {
    return PriceHistoryPoint(
      unit: json['unit'] as String? ?? 'unit',
      source: json['source'] as String? ?? 'transacted',
      avgPrice: (json['avg_price'] as num?)?.toDouble() ?? 0,
      minPrice: (json['min_price'] as num?)?.toDouble() ?? 0,
      maxPrice: (json['max_price'] as num?)?.toDouble() ?? 0,
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 0,
      recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
