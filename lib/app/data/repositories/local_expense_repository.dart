import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/expense_repository.dart';

/// Repositório offline que persiste as despesas em `shared_preferences`.
class LocalExpenseRepository implements ExpenseRepository {
  LocalExpenseRepository._(this._prefs, this._items);

  static const _storageKey = 'local_expenses_v1';

  final SharedPreferences _prefs;
  final List<ExpenseEntity> _items;
  final StreamController<List<ExpenseEntity>> _controller =
      StreamController<List<ExpenseEntity>>.broadcast();

  static Future<LocalExpenseRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    final items = <ExpenseEntity>[];
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List<dynamic>) {
          items.add(_fromMap(e as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Dados locais corrompidos, ignorando: $e');
        items.clear();
      }
    }
    return LocalExpenseRepository._(prefs, items);
  }

  List<ExpenseEntity> get _sorted =>
      List.unmodifiable([..._items]..sort((a, b) => b.date.compareTo(a.date)));

  @override
  Stream<List<ExpenseEntity>> watchExpenses() async* {
    yield _sorted;
    yield* _controller.stream;
  }

  @override
  Future<void> addExpense(ExpenseEntity expense) async {
    _items.add(expense);
    _controller.add(_sorted);
    await _prefs.setString(
      _storageKey,
      jsonEncode(_items.map(_toMap).toList()),
    );
  }

  static Map<String, dynamic> _toMap(ExpenseEntity e) => {
        'id': e.id,
        'amount': e.amount,
        'category': e.category.name,
        'description': e.description,
        'date': e.date.toIso8601String(),
      };

  static ExpenseEntity _fromMap(Map<String, dynamic> m) => ExpenseEntity(
        id: m['id'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: ExpenseCategory.values.firstWhere(
          (c) => c.name == m['category'],
          orElse: () => ExpenseCategory.other,
        ),
        description: (m['description'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
      );
}
