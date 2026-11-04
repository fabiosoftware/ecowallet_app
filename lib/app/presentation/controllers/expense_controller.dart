import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/notifications/reminder_scheduler.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/expense_repository.dart';

class ExpenseDayGroup {
  final DateTime day;
  final List<ExpenseEntity> items;

  ExpenseDayGroup(this.day, this.items);

  double get total => items.fold(0.0, (sum, e) => sum + e.amount);
}

class ExpenseController extends ChangeNotifier {
  ExpenseController({
    required ExpenseRepository repository,
    ReminderScheduler? reminders,
    DateTime Function()? clock,
  })  : _repository = repository,
        _reminders = reminders ?? NoopReminderScheduler(),
        _now = clock ?? DateTime.now;

  final ExpenseRepository _repository;
  final ReminderScheduler _reminders;
  final DateTime Function() _now;

  StreamSubscription<List<ExpenseEntity>>? _subscription;

  List<ExpenseEntity> expenses = const [];
  bool isLoading = true;
  String? errorMessage;

  void start() {
    _subscription?.cancel();
    _subscription = _repository.watchExpenses().listen(
      (items) {
        expenses = items;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
        _reminders.reschedule(registeredToday: hasExpenseToday);
      },
      onError: (Object e) {
        isLoading = false;
        errorMessage = 'Não foi possível carregar seus gastos.';
        notifyListeners();
      },
    );
  }

  /// Não espera a confirmação do servidor: offline, o Firestore só conclui o
  /// Future ao sincronizar, mas a lista local já é atualizada pelo stream.
  void addExpense({
    required double amount,
    required ExpenseCategory category,
    String description = '',
  }) {
    final now = _now();
    final expense = ExpenseEntity(
      id: now.microsecondsSinceEpoch.toString(),
      amount: amount,
      category: category,
      description: description.trim(),
      date: now,
    );
    _repository.addExpense(expense).catchError((Object _) {
      errorMessage = 'Não foi possível salvar o gasto.';
      notifyListeners();
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get hasExpenseToday {
    final now = _now();
    return expenses.any((e) => _isSameDay(e.date, now));
  }

  double get todayTotal {
    final now = _now();
    return expenses
        .where((e) => _isSameDay(e.date, now))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get monthTotal {
    final now = _now();
    return expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  List<ExpenseDayGroup> get groups {
    final result = <ExpenseDayGroup>[];
    for (final e in expenses) {
      if (result.isNotEmpty && _isSameDay(result.last.day, e.date)) {
        result.last.items.add(e);
      } else {
        result.add(ExpenseDayGroup(e.date, [e]));
      }
    }
    return result;
  }

  /// Categorias ordenadas pelo uso recente, para o registro ser mais rápido.
  List<ExpenseCategory> get categoriesByUsage {
    final counts = <ExpenseCategory, int>{};
    for (final e in expenses.take(100)) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    final all = [...ExpenseCategory.values];
    all.sort((a, b) {
      final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      return byCount != 0 ? byCount : a.index.compareTo(b.index);
    });
    return all;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
