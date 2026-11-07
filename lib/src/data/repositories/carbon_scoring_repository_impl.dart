import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/repositories/carbon_scoring_repository.dart';
import '../models/carbon_estimate_model.dart';

class CarbonScoringRepositoryImpl implements CarbonScoringRepository {
  CarbonScoringRepositoryImpl({
    required String apiKey,
    http.Client? client,
    this.dataVersion = '^34',
    this.timeout = const Duration(seconds: 15),
  })  : _apiKey = apiKey,
        _client = client ?? http.Client();

  static final Uri estimateEndpoint =
      Uri.parse('https://api.climatiq.io/data/v1/estimate');

  /// Teto do Green Score de uma transação.
  static const int scoreCeiling = greenScoreCeiling;

  /// Pontos de Green Score descontados por kg de CO2e emitido.
  static const int pointsPerKgCo2e = 10;

  /// Pontos de Green Score somados em categorias explicitamente ecológicas.
  static const int ecoBonusPoints = 150;

  /// Conversão do Green Score (0–1000) em pontos verdes (0–100).
  static const int scoreToPointsDivisor = 10;

  static const Set<String> ecoCategories = {
    'reciclagem',
    'transporte_limpo',
    'gasto_sustentavel',
    'energia_renovavel',
  };

  final String _apiKey;
  final http.Client _client;

  /// Versão do conjunto de fatores de emissão da Climatiq.
  final String dataVersion;
  final Duration timeout;

  /// Pontos de Green Score descontados pela emissão bruta [co2eKg].
  /// Valores negativos, `NaN` e infinitos não descontam nada.
  static int calculateScoreReduction(double co2eKg) {
    if (!co2eKg.isFinite || co2eKg <= 0) return 0;
    return (co2eKg * pointsPerKgCo2e).round();
  }

  /// Bônus de Green Score para categorias ecológicas; 0 nas demais.
  static int calculateEcoBonus(String category) {
    return ecoCategories.contains(_normalizeCategory(category))
        ? ecoBonusPoints
        : 0;
  }

  /// Green Score da transação: `teto − redução + bônus`, entre 0 e o teto.
  static GreenScoreResult computeGreenScore({
    required double co2eKg,
    String category = '',
  }) {
    final reduction = calculateScoreReduction(co2eKg);
    final bonus = calculateEcoBonus(category);
    final score = (scoreCeiling - reduction + bonus).clamp(0, scoreCeiling);
    return GreenScoreResult(
      co2eKg: co2eKg.isFinite && co2eKg > 0 ? co2eKg : 0,
      reductionPoints: reduction,
      bonusPoints: bonus,
      score: score,
      pointsEarned: score ~/ scoreToPointsDivisor,
    );
  }

  @override
  GreenScoreResult calculateGreenScore({
    required double co2eKg,
    String category = '',
  }) {
    return computeGreenScore(co2eKg: co2eKg, category: category);
  }

  static String _normalizeCategory(String value) {
    const withAccent = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const withoutAccent = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final char in value.trim().toLowerCase().split('')) {
      final index = withAccent.indexOf(char);
      buffer.write(index >= 0 ? withoutAccent[index] : char);
    }
    return buffer.toString().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  @override
  Future<CarbonEstimateModel> estimate({
    required String activityId,
    required Map<String, Object> parameters,
    String? region,
  }) async {
    final body = {
      'emission_factor': {
        'activity_id': activityId,
        'data_version': dataVersion,
        if (region != null) 'region': region,
      },
      'parameters': parameters,
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            estimateEndpoint,
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const CarbonScoringException(
          'Tempo esgotado ao consultar a Climatiq.');
    } on http.ClientException catch (e) {
      throw CarbonScoringException(
          'Falha de rede ao consultar a Climatiq: ${e.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CarbonScoringException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
            'Resposta da Climatiq em formato inesperado.');
      }
      return CarbonEstimateModel.fromJson(decoded);
    } on FormatException catch (e) {
      throw CarbonScoringException(
        e.message,
        statusCode: response.statusCode,
      );
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } on FormatException {
      // Corpo não é JSON; usa a mensagem genérica abaixo.
    }
    return 'Erro ${response.statusCode} ao consultar a Climatiq.';
  }

  void dispose() => _client.close();
}
