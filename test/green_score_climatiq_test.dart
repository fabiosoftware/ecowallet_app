import 'package:ecowallet/app/presentation/controllers/chatbot_controller.dart';
import 'package:ecowallet/features/wallet/data/models/carbon_score_model.dart';
import 'package:ecowallet/features/wallet/data/repositories/carbon_score_repository.dart';
import 'package:ecowallet/src/data/models/carbon_estimate_model.dart';
import 'package:ecowallet/src/data/repositories/carbon_scoring_repository_impl.dart';
import 'package:ecowallet/src/domain/repositories/carbon_scoring_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScores implements CarbonScoreRepository {
  final saved = <CarbonScoreModel>[];

  @override
  Future<void> saveCarbonScore(CarbonScoreModel score) async =>
      saved.add(score);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEstimates implements CarbonScoringRepository {
  _FakeEstimates({this.co2e = 20, this.fail = false});

  final double co2e;
  final bool fail;
  final requests = <Map<String, Object>>[];

  @override
  Future<CarbonEstimateModel> estimate({
    required String activityId,
    required Map<String, Object> parameters,
    String? region,
  }) async {
    if (fail) throw const CarbonScoringException('offline');
    requests.add({'activityId': activityId, ...parameters});
    return CarbonEstimateModel(
      co2e: co2e,
      co2eUnit: 'kg',
      emissionFactor: const EmissionFactorModel(
        name: 'x',
        activityId: 'x',
        id: 'x',
        source: 'x',
        year: 2023,
        region: 'BR',
        category: 'x',
      ),
    );
  }

  @override
  GreenScoreResult calculateGreenScore({
    required double co2eKg,
    String category = '',
  }) =>
      CarbonScoringRepositoryImpl.computeGreenScore(
        co2eKg: co2eKg,
        category: category,
      );
}

void main() {
  group('Green Score', () {
    test('sem emissão mantém o teto de 1000', () {
      final r = CarbonScoringRepositoryImpl.computeGreenScore(co2eKg: 0);
      expect(r.score, 1000);
      expect(r.pointsEarned, 100);
    });

    test('desconta 10 pontos por kg de CO2e', () {
      final r = CarbonScoringRepositoryImpl.computeGreenScore(co2eKg: 12.5);
      expect(r.reductionPoints, 125);
      expect(r.score, 875);
      expect(r.pointsEarned, 87);
    });

    test('nunca fica abaixo de zero', () {
      final r = CarbonScoringRepositoryImpl.computeGreenScore(co2eKg: 5000);
      expect(r.score, 0);
      expect(r.pointsEarned, 0);
    });

    test('entradas inválidas não descontam', () {
      for (final v in [-3.0, double.nan, double.infinity]) {
        expect(CarbonScoringRepositoryImpl.calculateScoreReduction(v), 0);
      }
    });

    test('categoria ecológica recebe bônus, respeitando o teto', () {
      final r = CarbonScoringRepositoryImpl.computeGreenScore(
        co2eKg: 20,
        category: ' Transporte Limpo ',
      );
      expect(r.bonusPoints, 150);
      expect(r.score, 950);

      final capped = CarbonScoringRepositoryImpl.computeGreenScore(
        co2eKg: 0,
        category: 'reciclagem',
      );
      expect(capped.score, 1000);
    });

    test('categoria comum não recebe bônus', () {
      expect(CarbonScoringRepositoryImpl.calculateEcoBonus('combustivel'), 0);
    });
  });

  group('CarbonEstimateModel', () {
    test('converte a unidade para kg', () {
      CarbonEstimateModel build(String unit) => CarbonEstimateModel.fromJson({
            'co2e': 2000,
            'co2e_unit': unit,
            'emission_factor': {'name': 'n'},
          });
      expect(build('g').co2eKg, 2);
      expect(build('kg').co2eKg, 2000);
      expect(build('t').co2eKg, 2000000);
    });
  });

  group('ChatbotController + Climatiq', () {
    ChatbotController build(
      _FakeScores scores,
      _FakeEstimates estimates, {
      Map<String, String> ids = const {'combustivel': 'fuel-id'},
    }) =>
        ChatbotController(
          carbonScores: scores,
          carbonEstimates: estimates,
          climatiqActivityIds: ids,
          replyDelay: Duration.zero,
        );

    test('gasto usa a estimativa e grava greenPointsEarned', () async {
      final scores = _FakeScores();
      final estimates = _FakeEstimates(co2e: 20);
      final controller = build(scores, estimates);
      addTearDown(controller.dispose);

      await controller.send('Gastei R\$ 100 de gasolina');

      expect(estimates.requests.single['activityId'], 'fuel-id');
      expect(estimates.requests.single['money'], 100.0);
      expect(scores.saved, hasLength(1));
      expect(scores.saved.single.greenPointsEarned, 80);
      expect(scores.saved.single.carbonFootprintKg, 20);
      expect(controller.messages.last.text, contains('+80 pontos verdes'));
    });

    test('reciclagem recebe bônus sem chamar a API', () async {
      final scores = _FakeScores();
      final estimates = _FakeEstimates();
      final controller = build(scores, estimates);
      addTearDown(controller.dispose);

      await controller.send('Reciclei 2 kg de latinhas de alumínio');

      expect(estimates.requests, isEmpty);
      expect(scores.saved.single.greenPointsEarned, 100);
    });

    test('falha na API recai no fluxo local sem gravar', () async {
      final scores = _FakeScores();
      final controller = build(scores, _FakeEstimates(fail: true));
      addTearDown(controller.dispose);

      await controller.send('Gastei R\$ 100 de gasolina');

      expect(scores.saved, isEmpty);
      expect(controller.messages.last.text, contains('Não consegui registrar'));
    });

    test('categoria sem activity_id usa o fluxo local', () async {
      final scores = _FakeScores();
      final estimates = _FakeEstimates();
      final controller = build(scores, estimates, ids: const {});
      addTearDown(controller.dispose);

      await controller.send('Gastei R\$ 100 de gasolina');

      expect(estimates.requests, isEmpty);
      expect(scores.saved, isEmpty);
    });
  });
}
