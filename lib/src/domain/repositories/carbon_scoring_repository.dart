import '../../data/models/carbon_estimate_model.dart';

/// Falha ao obter uma estimativa de carbono.
class CarbonScoringException implements Exception {
  const CarbonScoringException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'CarbonScoringException($statusCode): $message';
}

/// Teto do Green Score de uma transação.
const int greenScoreCeiling = 1000;

/// Resultado do cálculo do Green Score de uma transação.
class GreenScoreResult {
  const GreenScoreResult({
    required this.co2eKg,
    required this.reductionPoints,
    required this.bonusPoints,
    required this.score,
    required this.pointsEarned,
  });

  /// Emissão bruta considerada, em kg de CO2e.
  final double co2eKg;

  /// Pontos de Green Score descontados pela emissão.
  final int reductionPoints;

  /// Pontos de Green Score somados por categoria ecológica.
  final int bonusPoints;

  /// Green Score da transação, entre 0 e o teto de 1000.
  final int score;

  /// Pontos verdes (`greenPointsEarned`) creditados ao usuário.
  final int pointsEarned;
}

abstract class CarbonScoringRepository {
  /// Estima a emissão de CO2e de uma atividade.
  ///
  /// [activityId] identifica o fator de emissão na Climatiq e [parameters]
  /// traz os dados da atividade, ex.: `{'money': 50, 'money_unit': 'brl'}`.
  Future<CarbonEstimateModel> estimate({
    required String activityId,
    required Map<String, Object> parameters,
    String? region,
  });

  /// Calcula o Green Score a partir da emissão bruta ([co2eKg]) e da
  /// [category] da transação, que pode bonificar categorias ecológicas.
  GreenScoreResult calculateGreenScore({
    required double co2eKg,
    String category = '',
  });
}
