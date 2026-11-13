import 'package:ecowallet/app/domain/entities/user_entity.dart';
import 'package:ecowallet/app/presentation/widgets/plan_guard_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blocks free users with the Starter plan offer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlanGuardWidget(
          userStream: Stream.value(UserEntity(id: 'user-1')),
          child: const Text('Conteúdo avançado'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo avançado'), findsNothing);
    expect(find.text('Plano Starter B2B para sua operação'), findsOneWidget);
    expect(find.text('R\$ 499,00/mês'), findsOneWidget);
  });

  testWidgets('shows guarded content to Starter users', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlanGuardWidget(
          userStream: Stream.value(
            UserEntity(id: 'user-1', plano: UserEntity.starterPlan),
          ),
          child: const Text('Conteúdo avançado'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo avançado'), findsOneWidget);
    expect(find.text('Plano Starter B2B para sua operação'), findsNothing);
  });
}
