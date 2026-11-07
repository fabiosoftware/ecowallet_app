/// Metadados do fator de emissão usado pela Climatiq no cálculo.
class EmissionFactorModel {
  const EmissionFactorModel({
    required this.name,
    required this.activityId,
    required this.id,
    required this.source,
    required this.year,
    required this.region,
    required this.category,
    this.sourceDataset,
    this.accessType,
  });

  final String name;
  final String activityId;
  final String id;
  final String source;
  final int? year;
  final String region;
  final String category;
  final String? sourceDataset;
  final String? accessType;

  factory EmissionFactorModel.fromJson(Map<String, dynamic> json) {
    return EmissionFactorModel(
      name: json['name'] as String? ?? '',
      activityId: json['activity_id'] as String? ?? '',
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      year: (json['year'] as num?)?.toInt(),
      region: json['region'] as String? ?? '',
      category: json['category'] as String? ?? '',
      sourceDataset: json['source_dataset'] as String?,
      accessType: json['access_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'activity_id': activityId,
      'id': id,
      'source': source,
      'year': year,
      'region': region,
      'category': category,
      'source_dataset': sourceDataset,
      'access_type': accessType,
    };
  }
}

/// Resposta do endpoint de estimativa da Climatiq (`POST /data/v1/estimate`).
class CarbonEstimateModel {
  const CarbonEstimateModel({
    required this.co2e,
    required this.co2eUnit,
    required this.emissionFactor,
    this.calculationMethod,
    this.calculationOrigin,
  });

  /// Emissão estimada em CO2 equivalente, na unidade de [co2eUnit].
  final double co2e;

  /// Unidade de [co2e] (normalmente `kg`).
  final String co2eUnit;

  final EmissionFactorModel emissionFactor;
  final String? calculationMethod;
  final String? calculationOrigin;

  /// [co2e] convertido para quilogramas (unidades desconhecidas contam como kg).
  double get co2eKg {
    switch (co2eUnit.toLowerCase()) {
      case 'g':
        return co2e / 1000;
      case 't':
        return co2e * 1000;
      default:
        return co2e;
    }
  }

  factory CarbonEstimateModel.fromJson(Map<String, dynamic> json) {
    final co2e = json['co2e'];
    if (co2e is! num) {
      throw const FormatException('Resposta da Climatiq sem o campo "co2e".');
    }

    final factor = json['emission_factor'];

    return CarbonEstimateModel(
      co2e: co2e.toDouble(),
      co2eUnit: json['co2e_unit'] as String? ?? 'kg',
      calculationMethod: json['co2e_calculation_method'] as String?,
      calculationOrigin: json['co2e_calculation_origin'] as String?,
      emissionFactor: EmissionFactorModel.fromJson(
        factor is Map<String, dynamic> ? factor : const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'co2e': co2e,
      'co2e_unit': co2eUnit,
      'co2e_calculation_method': calculationMethod,
      'co2e_calculation_origin': calculationOrigin,
      'emission_factor': emissionFactor.toJson(),
    };
  }
}
