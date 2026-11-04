import 'package:ecowallet/app/presentation/controllers/chatbot_controller.dart';
import 'package:ecowallet/features/wallet/data/repositories/carbon_score_repository.dart';
import 'package:ecowallet/repositories/carbon_score_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements CarbonScoreRepository {
  _FakeRepository(this.total, {this.fail = false});

  final int total;
  final bool fail;

  @override
  Future<int> fetchTotalGreenPoints() async {
    if (fail) throw Exception('offline');
    return total;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatbotController _build(CarbonScoreRepository? repo) =>
    ChatbotController(carbonScores: repo, replyDelay: Duration.zero);

class _FakeScoring implements CarbonScoringRepository {
  _FakeScoring({this.fail = false});

  final bool fail;
  final calls = <Map<String, Object>>[];

  @override
  Future<void> updateCarbonScore({
    double valorTransacao = 0.0,
    String categoria = '',
    double pesoReciclagem = 0.0,
    String tipoMaterial = '',
  }) async {
    if (fail) throw Exception('offline');
    calls.add({
      'valor': valorTransacao,
      'categoria': categoria,
      'peso': pesoReciclagem,
      'material': tipoMaterial,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatbotController _buildScoring(CarbonScoringRepository? scoring) =>
    ChatbotController(carbonScoring: scoring, replyDelay: Duration.zero);

void main() {
  group('Carbon Scoring', () {
    test('reciclagem de latinhas chama updateCarbonScore', () async {
      final scoring = _FakeScoring();
      final controller = _buildScoring(scoring);
      addTearDown(controller.dispose);

      await controller.send('Reciclei 2 kg de latinhas de alumínio');

      expect(scoring.calls, hasLength(1));
      expect(scoring.calls.single['material'], 'aluminio');
      expect(scoring.calls.single['peso'], 2.0);
      expect(controller.messages.last.text, contains('+170.0 pontos'));
    });

    test('converte gramas para quilos', () async {
      final scoring = _FakeScoring();
      final controller = _buildScoring(scoring);
      addTearDown(controller.dispose);

      await controller.send('reciclei 500 g de papel');

      expect(scoring.calls.single['peso'], 0.5);
      expect(scoring.calls.single['material'], 'papel');
    });

    test('pede o peso quando não informado e não atualiza', () async {
      final scoring = _FakeScoring();
      final controller = _buildScoring(scoring);
      addTearDown(controller.dispose);

      await controller.send('reciclei latinhas');

      expect(scoring.calls, isEmpty);
      expect(controller.messages.last.text, contains('quantos quilos'));
    });

    test('gasto em combustível chama updateCarbonScore', () async {
      final scoring = _FakeScoring();
      final controller = _buildScoring(scoring);
      addTearDown(controller.dispose);

      await controller.send('Gastei R\$ 100,00 de gasolina');

      expect(scoring.calls.single['categoria'], 'combustivel');
      expect(scoring.calls.single['valor'], 100.0);
      expect(controller.messages.last.text, contains('30.0 pontos'));
    });

    test('compra ecológica usa gasto_sustentavel e informa ganho', () async {
      final scoring = _FakeScoring();
      final controller = _buildScoring(scoring);
      addTearDown(controller.dispose);

      await controller.send('Comprei R\$ 20 em produtos ecológicos');

      expect(scoring.calls.single['categoria'], 'gasto_sustentavel');
      expect(scoring.calls.single['valor'], 20.0);
      expect(controller.messages.last.text, contains('+100.0 pontos'));
    });

    test('responde com fallback quando a atualização falha', () async {
      final controller = _buildScoring(_FakeScoring(fail: true));
      addTearDown(controller.dispose);

      await controller.send('reciclei 1 kg de plástico');

      expect(controller.messages.last.text, contains('Não consegui registrar'));
    });

    test('sem repositório, avisa e não quebra', () async {
      final controller = _buildScoring(null);
      addTearDown(controller.dispose);

      await controller.send('reciclei 1 kg de papel');

      expect(controller.messages.last.text, contains('Não consegui registrar'));
    });

    test('perguntas comuns não disparam atualização', () async {
      final scoring = _FakeScoring();
      final controller = _buildScoring(scoring);
      addTearDown(controller.dispose);

      await controller.send('dicas de transporte');
      await controller.send('quantos pontos eu tenho?');

      expect(scoring.calls, isEmpty);
    });
  });

  group('Quick Suggestions', () {
    test('banco com 6 sugestões e 3 visíveis por vez', () {
      final controller = _build(null);
      addTearDown(controller.dispose);

      expect(ChatbotController.quickSuggestionBank, hasLength(6));
      expect(
        controller.quickSuggestions,
        ChatbotController.quickSuggestionBank.sublist(0, 3),
      );
    });

    test('rotateSuggestions avança e retorna ao início no fim do ciclo', () {
      final controller = _build(null);
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.rotateSuggestions();
      expect(
        controller.quickSuggestions,
        ChatbotController.quickSuggestionBank.sublist(3, 6),
      );

      controller.rotateSuggestions();
      expect(
        controller.quickSuggestions,
        ChatbotController.quickSuggestionBank.sublist(0, 3),
      );
      expect(notified, 2);
    });

    test('enviar mensagem ou tocar em um chip gira as sugestões', () async {
      final controller = _build(null);
      addTearDown(controller.dispose);

      await controller.selectSuggestion('Dicas de transporte');

      expect(controller.messages.first.text, 'Dicas de transporte');
      expect(
        controller.quickSuggestions,
        ChatbotController.quickSuggestionBank.sublist(3, 6),
      );
    });

    test('mensagem vazia não gira as sugestões', () async {
      final controller = _build(null);
      addTearDown(controller.dispose);

      await controller.send('   ');

      expect(
        controller.quickSuggestions,
        ChatbotController.quickSuggestionBank.sublist(0, 3),
      );
    });
  });

  group('Explicação e sugestões', () {
    test('explica como a pontuação funciona sem consultar o saldo', () async {
      final controller = _build(_FakeRepository(135));
      addTearDown(controller.dispose);

      await controller.send('Como funciona a pontuação?');
      expect(controller.messages.last.text, ChatbotController.scoreExplanation);

      await controller.send('como ganho pontos?');
      expect(controller.messages.last.text, ChatbotController.scoreExplanation);
    });

    test('sugere hábitos em rodízio', () async {
      final controller = _build(null);
      addTearDown(controller.dispose);

      await controller.send('me sugira um hábito sustentável');
      final first = controller.messages.last.text;
      await controller.send('mais uma sugestão');
      final second = controller.messages.last.text;

      expect(ChatbotController.habitSuggestions, contains(first));
      expect(ChatbotController.habitSuggestions, contains(second));
      expect(second, isNot(first));
    });

    test('o rodízio volta ao início depois da última dica', () async {
      final controller = _build(null);
      addTearDown(controller.dispose);

      final total = ChatbotController.habitSuggestions.length;
      for (var i = 0; i < total + 1; i++) {
        await controller.send('sugestão');
      }
      expect(
        controller.messages.last.text,
        ChatbotController.habitSuggestions.first,
      );
    });
  });

  test('responde com o total de pontos verdes ao perguntar sobre pontos',
      () async {
    final controller = _build(_FakeRepository(135));
    addTearDown(controller.dispose);

    await controller.send('Quantos pontos eu tenho?');

    expect(controller.messages.last.text, contains('135 pontos'));
  });

  test('intercepta "saldo verde" e "recompensas"', () async {
    final controller = _build(_FakeRepository(10));
    addTearDown(controller.dispose);

    await controller.send('qual meu saldo verde?');
    expect(controller.messages.last.text, contains('10 pontos'));

    await controller.send('ver recompensas');
    expect(controller.messages.last.text, contains('10 pontos'));
  });

  test('avisa quando o saldo é zero', () async {
    final controller = _build(_FakeRepository(0));
    addTearDown(controller.dispose);

    await controller.send('pontos');

    expect(controller.messages.last.text, contains('ainda não acumulou'));
  });

  test('usa mensagem de fallback quando a consulta falha', () async {
    final controller = _build(_FakeRepository(0, fail: true));
    addTearDown(controller.dispose);

    await controller.send('pontos');

    expect(controller.messages.last.text, contains('Não consegui consultar'));
  });

  test('sem repositório, usa fallback e perguntas comuns seguem normais',
      () async {
    final controller = _build(null);
    addTearDown(controller.dispose);

    await controller.send('pontos');
    expect(controller.messages.last.text, contains('Não consegui consultar'));

    await controller.send('dicas de transporte');
    expect(controller.messages.last.text, contains('CO₂ por viagem'));
  });
}
