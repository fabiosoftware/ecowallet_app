import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../features/wallet/data/models/carbon_score_model.dart';
import '../../../features/wallet/data/repositories/carbon_score_repository.dart';
import '../../../repositories/carbon_score_repository.dart' as scoring;
import '../../../src/domain/repositories/carbon_scoring_repository.dart'
    as climatiq;

enum ChatAuthor { user, bot }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.author,
    required this.sentAt,
  });

  final String id;
  final String text;
  final ChatAuthor author;
  final DateTime sentAt;

  bool get isUser => author == ChatAuthor.user;
}

/// Ação sustentável identificada na conversa.
class SustainableAction {
  const SustainableAction.recycling({
    required this.material,
    required this.weightKg,
  })  : category = '',
        value = 0,
        isMissingWeight = false;

  const SustainableAction.spending({
    required this.category,
    required this.value,
  })  : material = '',
        weightKg = 0,
        isMissingWeight = false;

  const SustainableAction.missingWeight()
      : material = '',
        weightKg = 0,
        category = '',
        value = 0,
        isMissingWeight = true;

  final String material;
  final double weightKg;
  final String category;
  final double value;
  final bool isMissingWeight;

  bool get isRecycling => material.isNotEmpty;
}

/// Controlador do chat. As respostas são simuladas localmente; para usar uma
/// IA real, basta substituir [replyFor] por uma chamada ao serviço.
class ChatbotController extends ChangeNotifier {
  ChatbotController({
    CarbonScoreRepository? carbonScores,
    scoring.CarbonScoringRepository? carbonScoring,
    climatiq.CarbonScoringRepository? carbonEstimates,
    Map<String, String> climatiqActivityIds = const {},
    this.replyDelay = const Duration(milliseconds: 900),
    DateTime Function()? clock,
  })  : _carbonScores = carbonScores,
        _carbonScoring = carbonScoring,
        _carbonEstimates = carbonEstimates,
        _activityIds = climatiqActivityIds,
        _now = clock ?? DateTime.now;

  static const welcomeText =
      'Olá! Sou o EcoBot 🌱 Posso ajudar você a economizar dinheiro e reduzir '
      'sua pegada de carbono. Pergunte sobre transporte, mercado, energia ou '
      'investimentos sustentáveis.';

  static const _pointsKeywords = ['pontos', 'saldo verde', 'recompensas'];
  static const _queryTimeout = Duration(seconds: 8);

  static const _recyclingKeywords = [
    'recicl',
    'reciclei',
    'descartei',
    'coleta seletiva',
  ];
  static const _spendingKeywords = [
    'gastei',
    'paguei',
    'comprei',
    'abasteci',
    'gasto',
  ];

  /// Palavras que identificam o material reciclado (chave = tipo do material).
  static const _materialKeywords = <String, List<String>>{
    'aluminio': ['alumínio', 'aluminio', 'latinha', 'lata'],
    'plastico': ['plástico', 'plastico', 'garrafa'],
    'papel': ['papel', 'papelão', 'papelao', 'jornal', 'revista'],
  };

  /// Palavras que identificam a categoria do gasto.
  static const _categoryKeywords = <String, List<String>>{
    'gasto_sustentavel': [
      'sustentável',
      'sustentavel',
      'ecológic',
      'ecologic',
      'orgânico',
      'organico',
      'produto verde',
      'reutilizável',
      'reutilizavel',
    ],
    'combustivel': [
      'combustível',
      'combustivel',
      'gasolina',
      'etanol',
      'diesel',
      'abasteci',
    ],
    'alimentacao': [
      'alimentação',
      'alimentacao',
      'mercado',
      'comida',
      'restaurante',
      'feira',
    ],
  };

  static final _weightPattern = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(kg|quilos?|quilogramas?|gramas?|g)\b',
  );
  static final _moneyPattern = RegExp(
    r'(?:r\$\s*(\d+(?:[.,]\d+)?))|(?:(\d+(?:[.,]\d+)?)\s*reais)',
  );

  final CarbonScoreRepository? _carbonScores;
  final scoring.CarbonScoringRepository? _carbonScoring;

  /// Estimativas de emissão (Climatiq). Quando presente junto de
  /// [_carbonScores], o score das ações é calculado por emissão e gravado como
  /// `greenPointsEarned`; qualquer falha recai no cálculo local.
  final climatiq.CarbonScoringRepository? _carbonEstimates;

  /// `activity_id` da Climatiq por categoria de gasto.
  final Map<String, String> _activityIds;
  final Duration replyDelay;
  final DateTime Function() _now;

  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _disposed = false;
  int _counter = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;

  /// Dispara a mensagem de boas-vindas simulada.
  Future<void> start() async {
    if (_messages.isNotEmpty) return;
    await _botReply(Future.value(welcomeText));
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    _messages.add(_build(trimmed, ChatAuthor.user));
    _advanceSuggestions();
    notifyListeners();
    await _botReply(_resolveReply(trimmed));
  }

  /// Identifica ações sustentáveis (reciclagem ou gasto) para pontuar e
  /// intercepta perguntas sobre pontos, consultando o saldo em tempo real.
  Future<String> _resolveReply(String input) async {
    final q = input.toLowerCase();

    final action = _detectAction(q);
    if (action != null) {
      return _applyAction(action);
    }
    if (_scoreExplanationKeywords.any(q.contains)) {
      return Future.value(scoreExplanation);
    }
    if (_pointsKeywords.any(q.contains)) {
      return _pointsReply();
    }
    return replyFor(input);
  }

  /// Explica as regras de [scoring.CarbonScoringRepository] em linguagem simples.
  static const scoreExplanation =
      'Seu Carbon Score funciona assim 🌍: reciclar e comprar produtos '
      'sustentáveis evitam CO₂ e rendem pontos (cada kg de CO₂ evitado vale '
      '10 pontos, até 500 por registro). Gastos com combustível e '
      'alimentação geram pegada e descontam pontos (2 por kg de CO₂). O '
      'saldo nunca fica negativo. Reciclar alumínio rende mais que plástico '
      'ou papel. Os valores são estimativas para incentivar bons hábitos.';

  /// Dicas de hábitos sustentáveis, sugeridas em rodízio.
  static const habitSuggestions = [
    'Que tal reciclar? ♻️ Separe latinhas, garrafas e papel: 1 kg de '
        'alumínio evita 8,5 kg de CO₂ (+85 pontos). Me conte, por exemplo: '
        '"reciclei 2 kg de latinhas".',
    'Experimente o transporte público ou a bike 🚲 em um trajeto por '
        'semana: economiza combustível e reduz sua pegada.',
    'Prefira produtos ecológicos e reutilizáveis 🌿. Compras sustentáveis '
        'geram pontos: "comprei R\$ 20 em produtos ecológicos".',
    'Planeje as compras do mercado 🛒 para evitar desperdício e inclua '
        'refeições sem carne algumas vezes por semana.',
    'Desligue aparelhos da tomada e troque lâmpadas por LED 💡: menos '
        'energia, menos emissões e conta mais baixa.',
  ];

  static const _scoreExplanationKeywords = [
    'como funciona',
    'como calcul',
    'como ganho',
    'como ganhar',
    'como pontu',
    'pontuação',
    'pontuacao',
    'carbon score',
    'por que perdi',
    'por que meus pontos',
  ];

  static const _habitKeywords = [
    'hábito',
    'habito',
    'sugest',
    'sugira',
    'o que posso fazer',
    'como melhorar',
    'como aumentar',
  ];

  int _habitIndex = 0;

  /// Banco de sugestões rápidas (chips) focadas em sustentabilidade.
  static const quickSuggestionBank = [
    'Como funciona a pontuação?',
    'Quantos pontos eu tenho?',
    'Me sugira um hábito sustentável',
    'Dicas de transporte',
    'Reciclei 2 kg de latinhas',
    'Como reduzir minha pegada de carbono?',
  ];

  /// Quantidade de chips exibidos por vez.
  static const visibleSuggestionCount = 3;

  int _suggestionOffset = 0;

  /// Os [visibleSuggestionCount] chips atuais, sempre na ordem do banco.
  List<String> get quickSuggestions => List.unmodifiable([
        for (var i = 0; i < visibleSuggestionCount; i++)
          quickSuggestionBank[
              (_suggestionOffset + i) % quickSuggestionBank.length],
      ]);

  /// Avança o rodízio para o próximo grupo de chips; ao fim do banco volta ao
  /// início.
  void rotateSuggestions() {
    _advanceSuggestions();
    notifyListeners();
  }

  void _advanceSuggestions() {
    _suggestionOffset = (_suggestionOffset + visibleSuggestionCount) %
        quickSuggestionBank.length;
  }

  /// Envia o texto do chip como mensagem do usuário (o que também gira os
  /// chips).
  Future<void> selectSuggestion(String suggestion) => send(suggestion);

  /// Extrai da frase uma ação pontuável; `null` se não houver dados suficientes
  /// (ou se a frase for uma pergunta comum).
  @visibleForTesting
  SustainableAction? detectAction(String input) =>
      _detectAction(input.toLowerCase());

  SustainableAction? _detectAction(String q) {
    final material = _matchKey(q, _materialKeywords);
    if (_recyclingKeywords.any(q.contains) && material != null) {
      final weight = _parseWeightKg(q);
      return weight == null
          ? const SustainableAction.missingWeight()
          : SustainableAction.recycling(
              material: material,
              weightKg: weight,
            );
    }

    final category = _matchKey(q, _categoryKeywords);
    if (_spendingKeywords.any(q.contains) && category != null) {
      final value = _parseMoney(q);
      if (value != null) {
        return SustainableAction.spending(category: category, value: value);
      }
    }
    return null;
  }

  String? _matchKey(String q, Map<String, List<String>> keywords) {
    for (final entry in keywords.entries) {
      if (entry.value.any(q.contains)) return entry.key;
    }
    return null;
  }

  double? _parseWeightKg(String q) {
    final match = _weightPattern.firstMatch(q);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return null;
    return match.group(2)! == 'g' || match.group(2)!.startsWith('gram')
        ? amount / 1000
        : amount;
  }

  double? _parseMoney(String q) {
    final match = _moneyPattern.firstMatch(q);
    if (match == null) return null;
    final raw = match.group(1) ?? match.group(2);
    final value = double.tryParse(raw!.replaceAll(',', '.'));
    return value == null || value <= 0 ? null : value;
  }

  /// Registra a ação no Firestore via [scoring.CarbonScoringRepository] e
  /// devolve a resposta do bot; falhas nunca interrompem a conversa.
  Future<String> _applyAction(SustainableAction action) async {
    if (action.isMissingWeight) {
      return 'Ótimo ter reciclado! ♻️ Me diga quantos quilos (ex.: "2 kg") '
          'para eu calcular seus pontos.';
    }

    final estimated = await _applyEstimatedAction(action);
    if (estimated != null) return estimated;

    final points = scoring.CarbonScoringRepository.calculateNewPoints(
      valorTransacao: action.value,
      categoria: action.category,
      pesoReciclagem: action.weightKg,
      tipoMaterial: action.material,
    );

    final repository = _carbonScoring;
    if (repository == null) {
      return 'Não consegui registrar seus pontos agora. Verifique sua '
          'conexão e tente novamente.';
    }

    try {
      await repository
          .updateCarbonScore(
            valorTransacao: action.value,
            categoria: action.category,
            pesoReciclagem: action.weightKg,
            tipoMaterial: action.material,
          )
          .timeout(_queryTimeout);
    } catch (e) {
      debugPrint('Falha ao atualizar carbon score: $e');
      return 'Não consegui registrar seus pontos agora. Verifique sua '
          'conexão e tente novamente.';
    }

    final rounded = points.abs().toStringAsFixed(1);
    if (action.isRecycling) {
      return 'Parabéns por reciclar! ♻️ Registrei sua ação: +$rounded pontos '
          'no seu Carbon Score.';
    }
    if (points > 0) {
      return 'Compra sustentável registrada! 🌿 Você ganhou +$rounded pontos '
          'no seu Carbon Score.';
    }
    return points < 0
        ? 'Gasto registrado. Ele gera pegada de carbono e reduz seu Carbon '
            'Score em $rounded pontos. Recicle para recuperar pontos! 🌱'
        : 'Gasto registrado no seu Carbon Score.';
  }

  /// Calcula o Green Score pela emissão (reciclagem não emite; gastos usam a
  /// Climatiq) e grava o resultado em `carbon_scores`, de onde a aba
  /// Recompensas lê `greenPointsEarned`. Devolve `null` quando não for
  /// possível, para o fluxo local assumir.
  Future<String?> _applyEstimatedAction(SustainableAction action) async {
    final estimates = _carbonEstimates;
    final repository = _carbonScores;
    if (estimates == null || repository == null) return null;

    final category = action.isRecycling ? 'reciclagem' : action.category;
    final activityId = _activityIds[action.category];
    if (!action.isRecycling && activityId == null) return null;

    try {
      var co2eKg = 0.0;
      if (!action.isRecycling) {
        final estimate = await estimates.estimate(
          activityId: activityId!,
          parameters: {'money': action.value, 'money_unit': 'brl'},
        ).timeout(_queryTimeout);
        co2eKg = estimate.co2eKg;
      }

      final result =
          estimates.calculateGreenScore(co2eKg: co2eKg, category: category);
      final now = _now();
      await repository
          .saveCarbonScore(
            CarbonScoreModel(
              transactionId: 'chat_${now.microsecondsSinceEpoch}',
              carbonFootprintKg: result.co2eKg,
              greenPointsEarned: result.pointsEarned,
              timestamp: now,
            ),
          )
          .timeout(_queryTimeout);

      final footprint = result.co2eKg.toStringAsFixed(1);
      final bonus = result.bonusPoints > 0 ? ' (bônus ecológico incluído)' : '';
      return 'Ação registrada! 🌿 Pegada estimada: $footprint kg CO₂e. '
          'Green Score ${result.score}/${climatiq.greenScoreCeiling}$bonus: '
          '+${result.pointsEarned} pontos verdes.';
    } catch (e) {
      debugPrint('Falha ao pontuar via Climatiq: $e');
      return null;
    }
  }

  Future<String> _pointsReply() async {
    final total = await _fetchUserGreenPoints();
    if (total == null) {
      return 'Não consegui consultar seu saldo verde agora. Verifique sua '
          'conexão ou veja seus EcoPoints na aba Recompensas.';
    }
    if (total == 0) {
      return 'Você ainda não acumulou pontos verdes. Registre gastos '
          'sustentáveis e conclua missões para começar a ganhar!';
    }
    return 'Seu saldo verde acumulado é de $total pontos 🌿. Continue '
        'escolhendo opções sustentáveis para ganhar ainda mais!';
  }

  /// Soma `greenPointsEarned` de todos os documentos salvos; `null` se a
  /// consulta não estiver disponível, falhar ou demorar demais (sem rede).
  Future<int?> _fetchUserGreenPoints() async {
    final repository = _carbonScores;
    if (repository == null) return null;
    try {
      return await repository.fetchTotalGreenPoints().timeout(_queryTimeout);
    } catch (e) {
      debugPrint('Falha ao buscar pontos verdes: $e');
      return null;
    }
  }

  Future<void> _botReply(Future<String> reply) async {
    _isTyping = true;
    notifyListeners();

    await Future<void>.delayed(replyDelay);
    final text = await reply;
    if (_disposed) return;

    _messages.add(_build(text, ChatAuthor.bot));
    _isTyping = false;
    notifyListeners();
  }

  ChatMessage _build(String text, ChatAuthor author) => ChatMessage(
        id: '${_counter++}',
        text: text,
        author: author,
        sentAt: _now(),
      );

  @visibleForTesting
  String replyFor(String input) {
    final q = input.toLowerCase();

    bool has(List<String> words) => words.any(q.contains);

    if (has(_habitKeywords)) {
      final suggestion =
          habitSuggestions[_habitIndex % habitSuggestions.length];
      _habitIndex++;
      return suggestion;
    }
    if (has(['transporte', 'ônibus', 'onibus', 'carro', 'bike', 'metrô'])) {
      return 'Trocar um trajeto de carro por transporte público ou bicicleta '
          'pode cortar até 2 kg de CO₂ por viagem e ainda poupar combustível '
          'e estacionamento. Registre o gasto como Transporte para ganhar '
          'EcoPoints!';
    }
    if (has(['mercado', 'comida', 'alimenta', 'carne'])) {
      return 'No mercado, priorize alimentos locais e da estação, planeje a '
          'lista para evitar desperdício e reduza a carne vermelha algumas '
          'vezes por semana: economiza dinheiro e carbono.';
    }
    if (has(['energia', 'luz', 'conta de luz', 'eletric'])) {
      return 'Para gastar menos energia: troque lâmpadas por LED, desligue '
          'aparelhos da tomada e use eletrodomésticos nos horários de tarifa '
          'mais baixa. Pequenos hábitos reduzem a conta e as emissões.';
    }
    if (has(['invest', 'poupar', 'economizar', 'guardar'])) {
      return 'Uma boa regra é guardar de 10% a 20% da renda. Fundos e títulos '
          'ESG (verdes) direcionam seu dinheiro a projetos sustentáveis. '
          'Esta é uma orientação geral, não uma recomendação financeira.';
    }
    if (has(['carbono', 'co2', 'co₂', 'pegada', 'emiss'])) {
      return 'Sua pegada vem principalmente de transporte, energia e '
          'alimentação. Comece medindo seus gastos por categoria no EcoWallet '
          'e escolha uma para reduzir neste mês.';
    }
    if (has(['ponto', 'ecopoints', 'missão', 'missao', 'recompensa'])) {
      return 'Complete missões sustentáveis na aba Recompensas para ganhar '
          'EcoPoints e trocá-los por benefícios na loja.';
    }
    if (has(['oi', 'olá', 'ola', 'bom dia', 'boa tarde', 'boa noite'])) {
      return 'Olá! Como posso ajudar com suas finanças sustentáveis hoje?';
    }
    return 'Ainda estou aprendendo sobre isso. Tente perguntar sobre '
        'transporte, mercado, energia, investimentos ou pegada de carbono.';
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
