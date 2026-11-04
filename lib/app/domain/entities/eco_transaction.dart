class EcoTransactionEntity {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final double carbonFootprintKg;
  final String ecoTip;

  EcoTransactionEntity({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.carbonFootprintKg,
    required this.ecoTip,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'carbonFootprintKg': carbonFootprintKg,
      'ecoTip': ecoTip,
    };
  }

  factory EcoTransactionEntity.fromMap(Map<String, dynamic> map) {
    return EcoTransactionEntity(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] ?? '',
      date: DateTime.parse(map['date']),
      carbonFootprintKg: (map['carbonFootprintKg'] as num).toDouble(),
      ecoTip: map['ecoTip'] ?? '',
    );
  }
}
