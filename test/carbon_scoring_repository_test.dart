import 'package:ecowallet/repositories/carbon_score_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CarbonScoringRepository.calculateNewPoints', () {
    test('desconta a pegada gerada (combustível)', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 100,
        categoria: 'combustivel',
      );
      expect(pontos, closeTo(-30, 1e-9));
    });

    test('aceita acentos e maiúsculas na categoria', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 50,
        categoria: ' Alimentação ',
      );
      expect(pontos, closeTo(-4, 1e-9));
    });

    test('soma a pegada mitigada pela reciclagem', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        pesoReciclagem: 2,
        tipoMaterial: 'papel',
      );
      expect(pontos, closeTo(18, 1e-9));
    });

    test('limita a pegada mitigada a 50 kg por chamada', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        pesoReciclagem: 100,
        tipoMaterial: 'aluminio',
      );
      expect(pontos, closeTo(500, 1e-9));
    });

    test('combina emissão e mitigação', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 100,
        categoria: 'combustivel',
        pesoReciclagem: 4,
        tipoMaterial: 'plastico',
      );
      expect(pontos, closeTo(30, 1e-9));
    });

    test('gasto sustentável soma pontos (0.5 kg por real)', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 20,
        categoria: 'gasto_sustentavel',
      );
      expect(pontos, closeTo(100, 1e-9));
    });

    test('gasto sustentável respeita o teto de 50 kg por chamada', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 1000,
        categoria: 'gasto_sustentavel',
        pesoReciclagem: 10,
        tipoMaterial: 'aluminio',
      );
      expect(pontos, closeTo(500, 1e-9));
    });

    test('usa a mesma coleção e campo do painel de recompensas', () {
      expect(CarbonScoringRepository.scoreCollection, 'carbon_scores');
      expect(CarbonScoringRepository.scoreField, 'greenPointsEarned');
      expect(CarbonScoringRepository.userIdField, 'userId');
    });

    test('cada usuário tem seu próprio documento de saldo', () {
      expect(CarbonScoringRepository.documentIdFor('abc'), 'score_abc');
      expect(
        CarbonScoringRepository.documentIdFor('abc'),
        isNot(CarbonScoringRepository.documentIdFor('xyz')),
      );
    });

    test('calculateUpdatedScore soma, arredonda e nunca fica negativo', () {
      expect(CarbonScoringRepository.calculateUpdatedScore(100, 18.4), 118);
      expect(CarbonScoringRepository.calculateUpdatedScore(10, -30), 0);
      expect(CarbonScoringRepository.calculateUpdatedScore(0, 0), 0);
      expect(CarbonScoringRepository.calculateUpdatedScore(double.nan, 5), 5);
    });

    test('fatores públicos seguem a metodologia documentada', () {
      expect(CarbonScoringRepository.combustivel, 0.15);
      expect(CarbonScoringRepository.alimentacao, 0.04);
      expect(CarbonScoringRepository.aluminio, 8.5);
      expect(CarbonScoringRepository.plastico, 1.5);
      expect(CarbonScoringRepository.papel, 0.9);
      expect(CarbonScoringRepository.gastoSustentavel, 0.5);
      expect(CarbonScoringRepository.tetoMitigacaoKg, 50.0);
    });

    test('sem entradas o resultado é zero', () {
      expect(CarbonScoringRepository.calculateNewPoints(), 0);
    });

    test('alimentação gera emissão de 0.04 kg por real', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 100,
        categoria: 'alimentacao',
      );
      expect(pontos, closeTo(-8, 1e-9));
    });

    test('material aceita acento, maiúsculas e espaços', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        pesoReciclagem: 1,
        tipoMaterial: ' Alumínio ',
      );
      expect(pontos, closeTo(85, 1e-9));
    });

    test('cada material usa o seu fator', () {
      double pontos(String material) =>
          CarbonScoringRepository.calculateNewPoints(
            pesoReciclagem: 1,
            tipoMaterial: material,
          );
      expect(pontos('aluminio'), closeTo(85, 1e-9));
      expect(pontos('plastico'), closeTo(15, 1e-9));
      expect(pontos('papel'), closeTo(9, 1e-9));
    });

    test('peso sem material conhecido não gera mitigação', () {
      expect(
        CarbonScoringRepository.calculateNewPoints(pesoReciclagem: 10),
        0,
      );
      expect(
        CarbonScoringRepository.calculateNewPoints(
          pesoReciclagem: 10,
          tipoMaterial: 'vidro',
        ),
        0,
      );
    });

    test('material sem peso não gera mitigação', () {
      expect(
        CarbonScoringRepository.calculateNewPoints(tipoMaterial: 'aluminio'),
        0,
      );
    });

    test('teto: exatamente 50 kg não é cortado e acima disso é', () {
      // 50 / 0.9 kg de papel mitiga exatamente 50 kg.
      final noTeto = CarbonScoringRepository.calculateNewPoints(
        pesoReciclagem: 50 / 0.9,
        tipoMaterial: 'papel',
      );
      final acima = CarbonScoringRepository.calculateNewPoints(
        pesoReciclagem: 51 / 0.9,
        tipoMaterial: 'papel',
      );
      expect(noTeto, closeTo(500, 1e-6));
      expect(acima, closeTo(500, 1e-6));
      final abaixo = CarbonScoringRepository.calculateNewPoints(
        pesoReciclagem: 49 / 0.9,
        tipoMaterial: 'papel',
      );
      expect(abaixo, closeTo(490, 1e-6));
    });

    test('o teto vale só para a mitigação, nunca para a emissão', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 10000,
        categoria: 'combustivel',
      );
      expect(pontos, closeTo(-3000, 1e-9));

      final combinado = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 1000,
        categoria: 'combustivel',
        pesoReciclagem: 100,
        tipoMaterial: 'aluminio',
      );
      expect(combinado, closeTo(500 - 300, 1e-9));
    });

    test('gasto sustentável e reciclagem somam antes do teto', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 10,
        categoria: 'gasto_sustentavel',
        pesoReciclagem: 1,
        tipoMaterial: 'papel',
      );
      expect(pontos, closeTo(59, 1e-9));
    });

    test('gasto em categoria sem fator não pontua nem penaliza', () {
      expect(
        CarbonScoringRepository.calculateNewPoints(
          valorTransacao: 500,
          categoria: 'lazer',
        ),
        0,
      );
    });

    test('valores negativos, zero e infinitos contam como zero', () {
      expect(
        CarbonScoringRepository.calculateNewPoints(
          valorTransacao: -100,
          categoria: 'combustivel',
        ),
        0,
      );
      expect(
        CarbonScoringRepository.calculateNewPoints(
          valorTransacao: double.infinity,
          categoria: 'combustivel',
        ),
        0,
      );
      expect(
        CarbonScoringRepository.calculateNewPoints(
          pesoReciclagem: double.negativeInfinity,
          tipoMaterial: 'papel',
        ),
        0,
      );
      expect(
        CarbonScoringRepository.calculateNewPoints(
          pesoReciclagem: -5,
          tipoMaterial: 'papel',
        ),
        0,
      );
    });

    test('o resultado é sempre finito, mesmo com valores enormes', () {
      final pontos = CarbonScoringRepository.calculateNewPoints(
        valorTransacao: 1e300,
        categoria: 'gasto_sustentavel',
        pesoReciclagem: 1e300,
        tipoMaterial: 'aluminio',
      );
      expect(pontos.isFinite, isTrue);
      expect(pontos, closeTo(500, 1e-9));
    });

    test('calculateUpdatedScore: arredondamento e limites', () {
      expect(CarbonScoringRepository.calculateUpdatedScore(0, 0.4), 0);
      expect(CarbonScoringRepository.calculateUpdatedScore(0, 0.5), 1);
      expect(CarbonScoringRepository.calculateUpdatedScore(5, -5), 0);
      expect(CarbonScoringRepository.calculateUpdatedScore(-5, 3), 3);
      expect(CarbonScoringRepository.calculateUpdatedScore(10, double.nan), 0);
      expect(
        CarbonScoringRepository.calculateUpdatedScore(10, double.infinity),
        0,
      );
      expect(CarbonScoringRepository.calculateUpdatedScore(1000, -999.6), 0);
    });

    test('ignora entradas desconhecidas ou inválidas', () {
      expect(
        CarbonScoringRepository.calculateNewPoints(
          valorTransacao: -10,
          categoria: 'lazer',
          pesoReciclagem: double.nan,
          tipoMaterial: 'vidro',
        ),
        0,
      );
    });
  });
}
