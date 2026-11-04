import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/wallet/data/repositories/carbon_score_repository.dart';

/// Calcula e persiste o Carbon Score do usuário no Cloud Firestore.
///
/// O saldo é gravado na mesma coleção e no mesmo campo lidos pelo painel de
/// recompensas e pelo chatbot: `carbon_scores/score_{uid}`, campo
/// `greenPointsEarned`, com `userId` igual ao uid do dono. Os leitores filtram
/// por esse `userId`, então cada usuário vê apenas os próprios pontos.
class CarbonScoringRepository {
  CarbonScoringRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? userId,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _userId = userId;

  /// Fatores de emissão (kg de CO₂ por R$ gasto).
  static const double combustivel = 0.15;
  static const double alimentacao = 0.04;

  /// Fatores de mitigação por quilo reciclado (kg de CO₂ evitado por kg).
  static const double aluminio = 8.5;
  static const double plastico = 1.5;
  static const double papel = 0.9;

  /// Fator de mitigação por Real gasto em compras ecológicas (kg de CO₂ por R$).
  static const double gastoSustentavel = 0.5;

  /// Teto de pegada mitigada (kg de CO₂) por chamada.
  static const double tetoMitigacaoKg = 50.0;

  static const double _multiplicadorMitigacao = 10;
  static const double _multiplicadorEmissao = 2;

  /// Coleção e campo compartilhados com o painel de recompensas.
  static const String scoreCollection = CarbonScoreRepository.collectionName;
  static const String scoreField = 'greenPointsEarned';
  static const String userIdField = CarbonScoreRepository.userIdField;
  static const String documentPrefix = 'score_';

  static const Map<String, double> _fatoresEmissao = {
    'combustivel': combustivel,
    'alimentacao': alimentacao,
  };

  /// Fatores ESG de emissão por categoria (kg de CO₂ por R$ gasto), usados no
  /// score mensal.
  static const Map<String, double> fatoresIntensidade = {
    'combustivel': combustivel,
    'delivery': 0.10,
    'energia': 0.12,
    'supermercado': 0.06,
    'servicos_digitais': 0.01,
  };

  /// Intensidade (kg de CO₂ por R$) em que o score mensal chega a zero.
  static const double intensidadeMaxima = 0.15;
  static const int scoreMaximo = 1000;
  static const String monthlyScoreField = 'monthlyScore';

  static const Map<String, double> _fatoresMitigacaoPorKg = {
    'aluminio': aluminio,
    'plastico': plastico,
    'papel': papel,
  };

  static const Map<String, double> _fatoresMitigacaoPorReal = {
    'gasto_sustentavel': gastoSustentavel,
  };

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String? _userId;

  /// Calcula a variação de pontos de uma operação, sem acessar o Firestore.
  ///
  /// `novosPontos = (mitigada * 10) - (gerada * 2)`. A pegada mitigada soma a
  /// reciclagem (`pesoReciclagem * fator do material`) e as compras ecológicas
  /// (`valorTransacao * 0.5` quando a categoria é `gasto_sustentavel`), com
  /// teto de 50.0 kg por chamada. Categorias ou materiais desconhecidos têm
  /// fator zero; valores negativos ou inválidos contam como 0.
  static double calculateNewPoints({
    double valorTransacao = 0.0,
    String categoria = '',
    double pesoReciclagem = 0.0,
    String tipoMaterial = '',
  }) {
    final valor = _sanitize(valorTransacao);
    final peso = _sanitize(pesoReciclagem);
    final categoriaNormalizada = _normalize(categoria);

    final gerada = valor * (_fatoresEmissao[categoriaNormalizada] ?? 0.0);
    final mitigadaPorGasto =
        valor * (_fatoresMitigacaoPorReal[categoriaNormalizada] ?? 0.0);
    final mitigadaPorReciclagem =
        peso * (_fatoresMitigacaoPorKg[_normalize(tipoMaterial)] ?? 0.0);

    final mitigada = (mitigadaPorGasto + mitigadaPorReciclagem)
        .clamp(0.0, tetoMitigacaoKg)
        .toDouble();

    return (mitigada * _multiplicadorMitigacao) -
        (gerada * _multiplicadorEmissao);
  }

  /// Emissões (kg de CO₂) de um gasto em Reais: valor * fator da categoria.
  /// Retorna 0 se o valor for menor ou igual a zero ou a categoria for
  /// desconhecida.
  static double calculateEmissions(String categoria, double valor) {
    if (!(valor > 0) || !valor.isFinite) return 0.0;
    return valor * (fatoresIntensidade[_normalize(categoria)] ?? 0.0);
  }

  /// Score mensal inverso de 0 a 1000: quanto maior a intensidade de emissões
  /// por Real gasto, menor a nota. Sem gasto poluidor, retorna 1000.
  static int calculateMonthlyScore(double emissoes, double totalGasto) {
    if (!(totalGasto > 0) || !totalGasto.isFinite) return scoreMaximo;
    if (!(emissoes > 0) || !emissoes.isFinite) return scoreMaximo;
    final intensidade = emissoes / totalGasto;
    final score = scoreMaximo * (1 - intensidade / intensidadeMaxima);
    return score.round().clamp(0, scoreMaximo);
  }

  /// Salva o score mensal no documento de saldo do usuário no Firestore,
  /// sem alterar `greenPointsEarned`. Se o Firestore estiver offline, a
  /// gravação fica na fila local e é sincronizada quando a conexão voltar.
  Future<void> saveMonthlyScore(int score) {
    final now = DateTime.now().toUtc();
    final mes = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _scoreReference().set(
      {
        'transactionId': documentIdFor(_resolveUserId()),
        userIdField: _resolveUserId(),
        monthlyScoreField: score.clamp(0, scoreMaximo),
        'monthlyScoreMonth': mes,
        'timestamp': now.toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  /// Soma [novosPontos] ao saldo [atual], arredonda para inteiro (o painel lê
  /// `greenPointsEarned` como inteiro) e nunca retorna menos que zero.
  static int calculateUpdatedScore(double atual, double novosPontos) {
    final total = _sanitize(atual) + novosPontos;
    if (!total.isFinite || total <= 0) return 0;
    return total.round();
  }

  /// Soma a variação calculada ao score atual do usuário e salva o resultado,
  /// que nunca fica abaixo de zero. A leitura e a escrita ocorrem em uma
  /// transação para evitar perda de atualizações concorrentes.
  Future<void> updateCarbonScore({
    double valorTransacao = 0.0,
    String categoria = '',
    double pesoReciclagem = 0.0,
    String tipoMaterial = '',
  }) async {
    final novosPontos = calculateNewPoints(
      valorTransacao: valorTransacao,
      categoria: categoria,
      pesoReciclagem: pesoReciclagem,
      tipoMaterial: tipoMaterial,
    );
    final geradaKg = _sanitize(valorTransacao) *
        (_fatoresEmissao[_normalize(categoria)] ?? 0.0);

    final reference = _scoreReference();
    final uid = _resolveUserId();

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      final atual = (data?[scoreField] as num?)?.toDouble() ?? 0.0;
      final pegadaAtual = (data?['carbonFootprintKg'] as num?)?.toDouble() ?? 0;

      // Mantém o formato de CarbonScoreModel para o painel listar o documento.
      transaction.set(
        reference,
        {
          'transactionId': reference.id,
          userIdField: uid,
          'carbonFootprintKg': pegadaAtual + geradaKg,
          scoreField: calculateUpdatedScore(atual, novosPontos),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    });
  }

  DocumentReference<Map<String, dynamic>> _scoreReference() {
    return _firestore
        .collection(scoreCollection)
        .doc(documentIdFor(_resolveUserId()));
  }

  /// ID do documento de saldo do usuário.
  static String documentIdFor(String uid) => '$documentPrefix$uid';

  String _resolveUserId() {
    final uid = _userId ?? (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Nenhum usuário autenticado para atualizar o score.');
    }
    return uid;
  }

  static double _sanitize(double value) =>
      value.isFinite && value > 0 ? value : 0.0;

  /// Normaliza para comparação: minúsculas, sem espaços nas pontas e sem acentos.
  static String _normalize(String value) {
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const semAcento = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final rune in value.trim().toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = comAcento.indexOf(char);
      buffer.write(index >= 0 ? semAcento[index] : char);
    }
    return buffer.toString();
  }
}
