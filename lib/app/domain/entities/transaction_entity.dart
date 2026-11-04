class TransactionEntity {
  final String id;
  final String title;
  final double value;
  final DateTime date;
  final String type; // 'income' ou 'expense'

  TransactionEntity({
    required this.id,
    required this.title,
    required this.value,
    required this.date,
    required this.type,
  });
}
