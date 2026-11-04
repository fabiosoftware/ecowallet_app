import 'package:cloud_firestore/cloud_firestore.dart';

class CarbonScoreModel {
  const CarbonScoreModel({
    required this.transactionId,
    required this.carbonFootprintKg,
    required this.greenPointsEarned,
    required this.timestamp,
  });

  final String transactionId;
  final double carbonFootprintKg;
  final int greenPointsEarned;
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'carbonFootprintKg': carbonFootprintKg,
      'greenPointsEarned': greenPointsEarned,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory CarbonScoreModel.fromMap(Map<String, dynamic> map) {
    return CarbonScoreModel(
      transactionId: map['transactionId'] as String? ?? '',
      carbonFootprintKg: (map['carbonFootprintKg'] as num?)?.toDouble() ?? 0,
      greenPointsEarned: (map['greenPointsEarned'] as num?)?.toInt() ?? 0,
      timestamp: _parseTimestamp(map['timestamp']),
    );
  }

  /// Aceita tanto string ISO-8601 quanto `Timestamp` nativo do Firestore.
  static DateTime _parseTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
