import 'package:ecowallet/app/data/repositories/in_memory_expense_repository.dart';
import 'package:ecowallet/app/presentation/controllers/expense_controller.dart';
import 'package:ecowallet/app/presentation/pages/main_navigation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('web shows a clean wallet and the Starter dialog',
      (tester) async {
    final controller = ExpenseController(
      repository: InMemoryExpenseRepository(),
    )..start();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationPage(controller: controller, isWeb: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet_summary_card')), findsOneWidget);
    expect(find.text('Finanças empresariais com visão ESG'), findsNothing);
    expect(find.text('Uma base modular para evoluir'), findsNothing);

    await tester.tap(find.byKey(const Key('starter_plan_app_bar_button')));
    await tester.pumpAndSettle();
    expect(find.text('Finanças empresariais com visão ESG'), findsOneWidget);
    expect(find.text('Uma base modular para evoluir'), findsOneWidget);
    expect(find.text('R\$ 499,00/mês'), findsOneWidget);
    expect(find.text('Conhecer o Plano Starter'), findsOneWidget);

    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Finanças empresariais com visão ESG'), findsNothing);
  });

  testWidgets('web rewards remain visible to free users with a Starter banner',
      (tester) async {
    final controller = ExpenseController(
      repository: InMemoryExpenseRepository(),
    )..start();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationPage(controller: controller, isWeb: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recompensas'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rewards_total_points')), findsOneWidget);
    expect(find.text('Resgatar recompensas'), findsOneWidget);
    expect(find.text('Plano Starter B2B · R\$ 499,00/mês'), findsOneWidget);
    expect(find.text('Plano Starter B2B para sua operação'), findsNothing);
    await tester.tap(find.text('Conhecer o Plano Starter'));
    await tester.pumpAndSettle();
    expect(find.text('Plano Starter B2B'), findsOneWidget);
    expect(find.text('R\$ 499,00/mês'), findsOneWidget);
  });

  testWidgets('mobile continues to guard the rewards page', (tester) async {
    final controller = ExpenseController(
      repository: InMemoryExpenseRepository(),
    )..start();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationPage(controller: controller, isWeb: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recompensas'));
    await tester.pumpAndSettle();

    expect(find.text('Plano Starter B2B para sua operação'), findsOneWidget);
    expect(find.byKey(const Key('rewards_total_points')), findsNothing);
  });
}
