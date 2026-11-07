import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../app/domain/entities/expense_category.dart';
import '../../../app/domain/entities/expense_entity.dart';
import '../../../app/domain/repositories/expense_repository.dart';
import '../../../repositories/carbon_score_repository.dart';

/// Emissor/maquininha que originou a operação.
enum CardSource {
  infinitePay('InfinitePay'),
  nubank('Nubank');

  const CardSource(this.label);

  final String label;
}

/// Operação de cartão interceptada (ou simulada).
class CardTransactionEvent {
  const CardTransactionEvent({
    required this.id,
    required this.valor,
    required this.estabelecimento,
    required this.timestamp,
    this.origem = CardSource.nubank,
    this.sourceLabel,
  });

  final String id;
  final double valor;
  final String estabelecimento;
  final DateTime timestamp;
  final CardSource origem;
  final String? sourceLabel;
}

/// Lança automaticamente cada operação de cartão como despesa e atualiza o
/// score de carbono, sem digitação do usuário.
///
/// Fontes de eventos: [onCardTransaction] (dados reais interceptados) e
/// [startSimulation] (dados simulados para testes).
class CardTransactionListenerService {
  CardTransactionListenerService({
    required ExpenseRepository expenseRepository,
    CarbonScoringRepository? carbonScoringRepository,
    void Function(Object error, StackTrace stackTrace)? onError,
  })  : _expenses = expenseRepository,
        _carbon = carbonScoringRepository,
        _onError = onError;

  final ExpenseRepository _expenses;
  final CarbonScoringRepository? _carbon;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  final StreamController<CardTransactionEvent> _controller =
      StreamController<CardTransactionEvent>.broadcast();
  final Set<String> _processed = <String>{};
  final Random _random = Random();

  StreamSubscription<CardTransactionEvent>? _subscription;
  Timer? _simulationTimer;
  int _simulationCounter = 0;
  bool _disposed = false;

  /// Stream de transações recebidas.
  Stream<CardTransactionEvent> get events => _controller.stream;

  bool get isListening => _subscription != null;

  /// Começa a processar os eventos da [events]. Chamadas repetidas são ignoradas.
  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _controller.stream.listen(
      (event) => unawaited(_process(event)),
    );
  }

  /// Injeta uma operação de cartão recebida de uma fonte real.
  void onCardTransaction(CardTransactionEvent event) {
    if (_disposed) return;
    _controller.add(event);
  }

  /// Gera transações aleatórias a cada [interval] para testes.
  void startSimulation({Duration interval = const Duration(seconds: 20)}) {
    if (_disposed) return;
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(interval, (_) {
      final merchant = _merchants[_random.nextInt(_merchants.length)];
      final now = DateTime.now();
      final valor = 10 + _random.nextDouble() * 190;
      onCardTransaction(
        CardTransactionEvent(
          id: 'card_${now.microsecondsSinceEpoch}_${_simulationCounter++}',
          valor: double.parse(valor.toStringAsFixed(2)),
          estabelecimento: merchant,
          timestamp: now,
          origem: CardSource.values[_random.nextInt(CardSource.values.length)],
        ),
      );
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    stopSimulation();
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _controller.close();
  }

  Future<void> _process(CardTransactionEvent event) async {
    if (!event.valor.isFinite || event.valor <= 0) return;
    if (!_processed.add(event.id)) return;

    final match = _classify(event.estabelecimento);

    try {
      await _expenses.addExpense(
        ExpenseEntity(
          id: event.id,
          amount: event.valor,
          category: match.category,
          date: event.timestamp,
          description:
              '${event.estabelecimento} (${event.sourceLabel ?? event.origem.label})',
        ),
      );
    } catch (error, stack) {
      _processed.remove(event.id);
      _onError?.call(error, stack);
      debugPrint('Falha ao lançar despesa automática: $error');
      return;
    }

    final carbon = _carbon;
    if (carbon == null) return;
    try {
      await carbon.updateCarbonScore(
        valorTransacao: event.valor,
        categoria: match.carbonKey,
      );
    } catch (error, stack) {
      _onError?.call(error, stack);
      debugPrint('Falha ao atualizar score de carbono: $error');
    }
  }

  static const List<String> _merchants = [
    'Posto Ipiranga',
    'Restaurante Sabor Verde',
    'Supermercado Pão de Açúcar',
    'Starbucks',
    'Uber',
    'Netflix',
    'Farmácia Pague Menos',
    'Cinema Cinemark',
  ];

  static const List<_Rule> _rules = [
    _Rule(['posto', 'shell', 'ipiranga', 'combust'], ExpenseCategory.transport,
        'combustivel'),
    _Rule(['uber', '99', 'metro', 'ônibus', 'onibus'],
        ExpenseCategory.transport, 'transporte'),
    _Rule(['starbucks', 'café', 'cafe', 'padaria', 'lanchonete'],
        ExpenseCategory.coffee, 'alimentacao'),
    _Rule(['restaurante', 'ifood', 'burger', 'pizza', 'lanche'],
        ExpenseCategory.food, 'alimentacao'),
    _Rule(['mercado', 'supermercado', 'atacad'], ExpenseCategory.market,
        'alimentacao'),
    _Rule(['netflix', 'spotify', 'assinatura', 'prime'],
        ExpenseCategory.subscription, 'servicos_digitais'),
    _Rule(['farmácia', 'farmacia', 'drogaria', 'hospital'],
        ExpenseCategory.health, 'saude'),
    _Rule(['cinema', 'teatro', 'show', 'parque'], ExpenseCategory.leisure,
        'lazer'),
  ];

  static _Rule _classify(String estabelecimento) {
    final name = estabelecimento.toLowerCase();
    for (final rule in _rules) {
      if (rule.keywords.any(name.contains)) return rule;
    }
    return const _Rule([], ExpenseCategory.other, 'outros');
  }
}

class _Rule {
  const _Rule(this.keywords, this.category, this.carbonKey);

  final List<String> keywords;
  final ExpenseCategory category;
  final String carbonKey;
}
