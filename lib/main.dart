import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/core/notifications/notification_expense_capture_service.dart';
import 'app/core/notifications/reminder_scheduler.dart';
import 'app/data/repositories/firestore_expense_repository.dart';
import 'app/data/repositories/in_memory_expense_repository.dart';
import 'app/data/repositories/local_expense_repository.dart';
import 'app/domain/repositories/expense_repository.dart';
import 'app/presentation/controllers/expense_controller.dart';
import 'app/presentation/pages/main_navigation_page.dart';
import 'features/wallet/data/repositories/carbon_score_repository.dart';
import 'repositories/carbon_score_repository.dart';
import 'src/domain/services/card_transaction_listener_service.dart';

export 'app/presentation/pages/wallet_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

/// Mostra a interface imediatamente e inicializa os serviços em seguida,
/// para que a tela não fique preta enquanto o Firebase tenta conectar.
/// Se a inicialização falhar ou demorar demais, exibe uma tela de erro amigável.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<_AppServices> _future = _createServices();

  void _retry() => setState(() => _future = _createServices());

  void _continueOffline() => setState(() => _future = _createOfflineServices());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppServices>(
      future: _future,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (services != null) {
          return MyApp(
            controller: services.controller,
            carbonScores: services.carbonScores,
          );
        }
        return MaterialApp(
          title: 'EcoWallet',
          debugShowCheckedModeBanner: false,
          theme: _theme,
          home: snapshot.hasError
              ? _StartupErrorPage(
                  onRetry: _retry,
                  onContinueOffline: _continueOffline,
                )
              : const _LoadingPage(),
        );
      },
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({
    required this.onRetry,
    required this.onContinueOffline,
  });

  final VoidCallback onRetry;
  final VoidCallback onContinueOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Não foi possível iniciar o EcoWallet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Verifique sua conexão com a internet e tente novamente. '
                  'Você também pode continuar offline: seus gastos ficam '
                  'salvos neste aparelho.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  key: const Key('startup_retry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('startup_offline'),
                  onPressed: onContinueOffline,
                  child: const Text('Continuar offline'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Limite total da inicialização, para o app nunca ficar preso no carregamento.
const _startupTimeout = Duration(seconds: 45);

Future<FirebaseApp>? _firebaseInitialization;

/// Serviços prontos após a inicialização. [carbonScores] só existe quando o
/// Firebase e o login concluíram com sucesso; caso contrário é `null` e o
/// chatbot usa a resposta de fallback.
class _AppServices {
  const _AppServices({
    required this.controller,
    required this.notificationCapture,
    this.carbonScores,
  });

  final ExpenseController controller;
  final NotificationExpenseCaptureService notificationCapture;
  final CarbonScoreRepository? carbonScores;
}

class _RepositorySetup {
  const _RepositorySetup({
    required this.expenses,
    this.carbonScores,
    this.carbonScoring,
  });

  final ExpenseRepository expenses;
  final CarbonScoreRepository? carbonScores;
  final CarbonScoringRepository? carbonScoring;
}

Future<_AppServices> _createServices() async {
  final setup = await _createRepository().timeout(_startupTimeout);
  final controller = await _buildController(setup.expenses);
  final notificationCapture =
      _startCardListener(setup.expenses, setup.carbonScoring);
  return _AppServices(
    controller: controller,
    notificationCapture: notificationCapture,
    carbonScores: setup.carbonScores,
  );
}

Future<_AppServices> _createOfflineServices() async {
  final repository = await _createLocalRepository();
  final controller = await _buildController(repository, withReminders: false);
  final notificationCapture = _startCardListener(repository, null);
  return _AppServices(
    controller: controller,
    notificationCapture: notificationCapture,
  );
}

/// Ative a simulação com `--dart-define=SIMULATE_CARDS=true`.
const _simulateCards = bool.fromEnvironment('SIMULATE_CARDS');

CardTransactionListenerService? _cardListener;
NotificationExpenseCaptureService? _notificationCapture;

/// Liga o listener de cartão aos repositórios; substitui o anterior (retry).
NotificationExpenseCaptureService _startCardListener(
  ExpenseRepository expenses,
  CarbonScoringRepository? carbonScoring,
) {
  final previousCapture = _notificationCapture;
  if (previousCapture != null) unawaited(previousCapture.dispose());
  _cardListener?.dispose();
  final listener = CardTransactionListenerService(
    expenseRepository: expenses,
    carbonScoringRepository: carbonScoring,
  )..start();
  if (_simulateCards) listener.startSimulation();
  _cardListener = listener;
  final capture = NotificationExpenseCaptureService(
    cardTransactions: listener,
  );
  _notificationCapture = capture;
  unawaited(capture.startIfPermissionGranted());
  return capture;
}

Future<ExpenseController> _buildController(
  ExpenseRepository repository, {
  bool withReminders = true,
}) async {
  ReminderScheduler reminders = NoopReminderScheduler();
  if (withReminders && LocalReminderScheduler.isSupported) {
    try {
      final scheduler = LocalReminderScheduler();
      await scheduler.init().timeout(const Duration(seconds: 10));
      reminders = scheduler;
    } catch (e) {
      debugPrint('Lembretes desativados: $e');
    }
  }

  return ExpenseController(repository: repository, reminders: reminders)
    ..start();
}

final ThemeData _theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D32),
    brightness: Brightness.light,
  ),
);

/// Usa Firestore (com login anônimo) quando o Firebase está disponível;
/// caso contrário, persiste localmente com shared_preferences.
Future<_RepositorySetup> _createRepository() async {
  try {
    await _initializeFirebase().timeout(const Duration(seconds: 10));

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ??
        (await auth.signInAnonymously().timeout(const Duration(seconds: 10)))
            .user;

    if (user != null) {
      return _RepositorySetup(
        expenses: FirestoreExpenseRepository(userId: user.uid),
        carbonScores: CarbonScoreRepository(
          FirebaseFirestore.instance,
          userId: user.uid,
        ),
        carbonScoring: CarbonScoringRepository(userId: user.uid),
      );
    }
    debugPrint('Sem usuário autenticado, usando repositório local.');
  } catch (e) {
    debugPrint('Firebase indisponível, usando repositório local: $e');
  }
  return _RepositorySetup(expenses: await _createLocalRepository());
}

Future<FirebaseApp> _initializeFirebase() {
  if (Firebase.apps.isNotEmpty) {
    return Future<FirebaseApp>.value(Firebase.app());
  }

  final initialization = _firebaseInitialization;
  if (initialization != null) return initialization;

  final attempt = Firebase.initializeApp();
  _firebaseInitialization = attempt;
  return attempt.whenComplete(() {
    if (identical(_firebaseInitialization, attempt)) {
      _firebaseInitialization = null;
    }
  });
}

/// Repositório offline; se nem o armazenamento local funcionar, usa memória.
Future<ExpenseRepository> _createLocalRepository() async {
  try {
    return await LocalExpenseRepository.create();
  } catch (e) {
    debugPrint('Armazenamento local indisponível, usando memória: $e');
    return InMemoryExpenseRepository();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.controller,
    this.carbonScores,
    this.notificationCapture,
  });

  final ExpenseController controller;
  final CarbonScoreRepository? carbonScores;
  final NotificationExpenseCaptureService? notificationCapture;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoWallet',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: MainNavigationPage(
        controller: controller,
        carbonScores: carbonScores,
        notificationCapture: notificationCapture,
      ),
    );


