import 'package:ecowallet/app/presentation/controllers/chatbot_controller.dart';
import 'package:ecowallet/app/presentation/pages/chatbot_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra boas-vindas e responde a uma pergunta', (tester) async {
    final controller =
        ChatbotController(replyDelay: const Duration(milliseconds: 10));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ChatbotPage(controller: controller)),
    );
    expect(find.byKey(const Key('typing_indicator')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text(ChatbotController.welcomeText), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat_input')), 'transporte');
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pump();
    expect(find.text('transporte'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('CO₂ por viagem'), findsOneWidget);
  });
}
