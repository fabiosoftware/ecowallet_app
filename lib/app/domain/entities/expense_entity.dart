import 'expense_category.dart';

class ExpenseEntity {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final String description;
  final DateTime date;

  const ExpenseEntity({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.description = '',
  });

  String get title => description.isEmpty ? category.label : description;
}
