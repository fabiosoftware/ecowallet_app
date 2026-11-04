import 'package:ecowallet/app/data/repositories/in_memory_expense_repository.dart';
import 'package:ecowallet/app/presentation/controllers/expense_controller.dart';
import 'package:ecowallet/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registra um gasto pelo botão rápido e agrupa no extrato', (
    WidgetTester tester,
  ) async {
    final controller = ExpenseController(
      repository: InMemoryExpenseRepository(),
    )..start();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum gasto ainda'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_expense_fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('expense_amount_field')), '15,50');
    await tester.tap(find.byKey(const Key('category_coffee')));
    await tester.tap(find.byKey(const Key('save_expense_button')));
    await tester.pumpAndSettle();

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('- R\$ 15,50'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('today_total'))).data,
      'R\$ 15,50',
    );
  });

  testWidgets('rejeita valor vazio', (WidgetTester tester) async {
    final controller = ExpenseController(
      repository: InMemoryExpenseRepository(),
    )..start();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.tap(find.byKey(const Key('add_expense_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_expense_button')));
    await tester.pump();

    expect(find.text('Informe um valor maior que zero'), findsOneWidget);
  });
}
