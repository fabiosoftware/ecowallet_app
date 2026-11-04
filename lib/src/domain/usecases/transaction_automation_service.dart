import 'dart:async';

import 'package:ecowallet/app/domain/entities/expense_category.dart';
import 'package:ecowallet/app/domain/entities/expense_entity.dart';
import 'package:ecowallet/app/domain/repositories/expense_repository.dart';
import 'package:ecowallet/repositories/carbon_score_repository.dart';
import 'package:ecowallet/src/domain/transaction_event.dart';

/// Escuta um Stream de transações e lança cada uma automaticamente como
/// despesa e no score de carbono do usuário.
class TransactionAutomationService {
  TransactionAutomationService({
    required ExpenseRepository expenseRepository,
    required CarbonScoringRepository carbonScoringRepository,
    void Function(Object error, StackTrace stackTrace)? onError,
  })  : _expenseRepository = expenseRepository,
        _carbonScoringRepository = carbonScoringRepository,
        _onError = onError;

  final ExpenseRepository _expenseRepository;
  final CarbonScoringRepository _carbonScoringRepository;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  StreamSubscription<TransactionEvent>? _subscription;
  final Set<String> _processed = <String>{};

  bool get isListening => _subscription != null;

  /// Começa a escutar [events]. Uma escuta anterior é cancelada.
  Future<void> start(Stream<TransactionEvent> events) async {
    await stop();
    _subscription = events.listen(
      (event) => unawaited(_handle(event)),
      onError: (Object error, StackTrace stack) => _onError?.call(error, stack),
    );
  }

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> _handle(TransactionEvent event) async {
    if (!_processed.add(event.id)) return;
    try {
      await _expenseRepository.addExpense(
        ExpenseEntity(
          id: event.id,
          amount: event.valor,
          category: ExpenseCategory.fromName(event.categoria),
          date: event.timestamp,
          description: event.descricao,
        ),
      );
      await _carbonScoringRepository.updateCarbonScore(
        valorTransacao: event.valor,
        categoria: event.categoria,
      );
    } catch (error, stack) {
      _processed.remove(event.id);
      _onError?.call(error, stack);
    }
  }
}
