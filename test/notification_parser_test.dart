import 'package:ecowallet/app/core/notifications/notification_parser.dart';
import 'package:ecowallet/app/domain/entities/expense_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = NotificationParser();

  test('extrai valor e estabelecimento de confirmação de compra', () {
    final result = parser.parse(
      title: 'Compra aprovada',
      content: 'No seu cartão no valor de R\$ 32,00 em Mercado Verde',
    );

    expect(result?.amount, 32);
    expect(result?.merchant, 'Mercado Verde');
  });

  test('extrai notificacao de compra do Nubank', () {
    final result = parser.parse(
      title: 'Compra no valor',
      content: 'Compra de R\$ 32,00 no estabelecimento Mercado Verde aprovada',
    );

    expect(result?.amount, 32);
    expect(result?.merchant, 'Mercado Verde');
  });

  test('extrai notificacao do Itau com cartao e estabelecimento', () {
    final result = parser.parse(
      title: 'Compra aprovada no seu cartao final 1234 - MERCADO CENTRAL '
          'R\$ 1.234,56',
      content: '',
    );

    expect(result?.amount, 1234.56);
    expect(result?.merchant, 'MERCADO CENTRAL');
  });

  test('extrai notificacao do Inter', () {
    final result = parser.parse(
      title: 'Voce gastou R\$ 45,90 no estabelecimento Padaria da Esquina',
      content: '',
    );

    expect(result?.amount, 45.90);
    expect(result?.merchant, 'Padaria da Esquina');
  });

  test('mantem timestamp informado e usa o relogio configurado como fallback',
      () {
    final expected = DateTime(2026, 11, 3, 10);
    final fixedParser = NotificationParser(clock: () => expected);
    final result = fixedParser.parse(
      title: 'Voce gastou R\$ 45,90 no estabelecimento Padaria da Esquina',
      content: '',
    );

    expect(result?.timestamp, expected);
  });

  test('converte separador de milhar e decimal brasileiro', () {
    final result = parser.parse(
      title: 'Pagamento aprovado',
      content: 'Compra no valor de R\$ 1.234,56 em Supermercado Central.',
    );

    expect(result?.amount, 1234.56);
    expect(result?.merchant, 'Supermercado Central');
  });

  test('extrai estabelecimento que aparece antes do valor', () {
    final result = parser.parse(
      title: 'Compra no Café Aurora',
      content: 'Compra aprovada no valor de R\$ 18,50',
    );

    expect(result?.merchant, 'Café Aurora');
    expect(result?.amount, 18.5);
  });

  test('ignora notificação que não descreve uma transação', () {
    final result = parser.parse(
      title: 'Oferta do dia',
      content: 'Economize R\$ 32,00 no mercado hoje',
    );

    expect(result, isNull);
  });

  test('extrai fatura Mercado Pago removendo cidade e usando categoria mercado',
      () {
    for (final text in [
      'MP *MERCADINHO Osasco R\$ 10,00 Cartão final 3694',
      'MP * "MERCADINHO" Osasco R\$ 10,00 Cartão final 3694',
    ]) {
      final result = parser.parse(title: '', content: text);

      expect(result?.amount, 10.0);
      expect(result?.merchant, 'MP *MERCADINHO');
      expect(result?.category, ExpenseCategory.market);
    }
  });

  test('ignora transação sem estabelecimento identificável', () {
    final result = parser.parse(
      title: 'Compra aprovada',
      content: 'No seu cartão no valor de R\$ 32,00',
    );

    expect(result, isNull);
  });
}
