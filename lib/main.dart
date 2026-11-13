import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/core/notifications/notification_expense_capture_service.dart';
import 'app/core/notifications/reminder_scheduler.dart';
import 'app/data/repositories/firestore_expense_repository.dart';
import 'app/data/repositories/firestore_user_repository.dart';
import 'app/data/repositories/local_expense_repository.dart';
import 'app/domain/repositories/expense_repository.dart';
import 'app/domain/repositories/user_repository.dart';
import 'app/presentation/controllers/expense_controller.dart';
import 'app/presentation/pages/main_navigation_page.dart';
import 'features/wallet/data/repositories/carbon_score_repository.dart';
import 'repositories/carbon_score_repository.dart';
import 'src/data/repositories/carbon_scoring_repository_impl.dart';
import 'src/domain/repositories/carbon_scoring_repository.dart' as climatiq;
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
            carbonEstimates: services.carbonEstimates,
            userRepository: services.userRepository,
            climatiqActivityIds: _climatiqActivityIds,
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
                  'Não foi possível iniciar os serviços ou o armazenamento '
                  'local. Tente novamente ou tente continuar offline.',
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
const _firebaseStepTimeout = Duration(seconds: 10);
const _localRepositoryTimeout = Duration(seconds: 10);

Future<FirebaseApp>? _firebaseInitialization;

/// Chave da Climatiq: `--dart-define=CLIMATIQ_API_KEY=...`. Sem ela, o chatbot
/// mantém o cálculo local de pontos.
const _climatiqApiKey = String.fromEnvironment('CLIMATIQ_API_KEY');

/// `activity_id` da Climatiq por categoria de gasto do chatbot
/// (`combustivel`, `alimentacao`, `gasto_sustentavel`). Categorias ausentes
/// usam o cálculo local; preencha com IDs válidos do Data Explorer.
const Map<String, String> _climatiqActivityIds = {};

/// Serviços prontos após a inicialização. [carbonScores] só existe quando o
/// Firebase e o login concluíram com sucesso; caso contrário é `null` e o
/// chatbot usa a resposta de fallback.
class _AppServices {
  const _AppServices({
    required this.controller,
    required this.notificationCapture,
    this.carbonScores,
    this.carbonEstimates,
    this.userRepository,
  });

  final ExpenseController controller;
  final NotificationExpenseCaptureService notificationCapture;
  final CarbonScoreRepository? carbonScores;
  final climatiq.CarbonScoringRepository? carbonEstimates;
  final UserRepository? userRepository;
}

class _RepositorySetup {
  const _RepositorySetup({
    required this.expenses,
    this.carbonScores,
    this.carbonScoring,
    this.userRepository,
  });

  final ExpenseRepository expenses;
  final CarbonScoreRepository? carbonScores;
  final CarbonScoringRepository? carbonScoring;
  final UserRepository? userRepository;
}

Future<_AppServices> _createServices() async {
  final setup = await _createRepository().timeout(_startupTimeout);
  final controller = await _buildController(setup.expenses);
  final notificationCapture = _startCardListener(
    setup.expenses,
    setup.carbonScoring,
    setup.userRepository?.watchUser().map((user) => user.plano == 'starter'),
  );
  return _AppServices(
    controller: controller,
    notificationCapture: notificationCapture,
    carbonScores: setup.carbonScores,
    carbonEstimates: setup.carbonScores == null || _climatiqApiKey.isEmpty
        ? null
        : CarbonScoringRepositoryImpl(apiKey: _climatiqApiKey),
    userRepository: setup.userRepository,
  );
}

Future<_AppServices> _createOfflineServices() async {
  final repository = await _createLocalRepository();
  final controller = await _buildController(repository, withReminders: false);
  final notificationCapture =
      _startCardListener(repository, null, Stream<bool>.value(false));
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
  Stream<bool>? planAccess,
) {
  final previousCapture = _notificationCapture;
  if (previousCapture != null) unawaited(previousCapture.dispose());
  _cardListener?.dispose();
  final listener = CardTransactionListenerService(
    expenseRepository: expenses,
    carbonScoringRepository: carbonScoring,
    planAccess: planAccess,
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
  return initializeWithOfflineFallback(
    online: _createFirebaseRepository,
    offline: () async =>
        _RepositorySetup(expenses: await _createLocalRepository()),
    timeout: _firebaseStepTimeout * 2 + const Duration(seconds: 1),
    onError: (error) =>
        debugPrint('Firebase indisponível, usando repositório local: $error'),
  );
}

@visibleForTesting
Future<T> initializeWithOfflineFallback<T>({
  required Future<T> Function() online,
  required Future<T> Function() offline,
  required Duration timeout,
  required void Function(Object error) onError,
}) async {
  try {
    return await Future<T>.sync(online).timeout(timeout);
  } catch (e) {
    onError(e);
    return offline();
  }
}

Future<_RepositorySetup> _createFirebaseRepository() async {
  await _initializeFirebase();

  final auth = FirebaseAuth.instance;
  final user = auth.currentUser ??
      (await auth.signInAnonymously().timeout(_firebaseStepTimeout)).user;

  if (user == null) {
    throw StateError('Firebase não retornou um usuário autenticado.');
  }
  return _RepositorySetup(
    expenses: FirestoreExpenseRepository(userId: user.uid),
    carbonScores: CarbonScoreRepository(
      FirebaseFirestore.instance,
      userId: user.uid,
    ),
    carbonScoring: CarbonScoringRepository(userId: user.uid),
    userRepository: FirestoreUserRepository(userId: user.uid),
  );
}

Future<FirebaseApp> _initializeFirebase() async {
  try {
    if (Firebase.apps.isNotEmpty) return Firebase.app();

    var attempt = _firebaseInitialization;
    if (attempt == null) {
      late final Future<FirebaseApp> pending;
      pending =
          Future<FirebaseApp>.sync(Firebase.initializeApp).whenComplete(() {
        if (identical(_firebaseInitialization, pending)) {
          _firebaseInitialization = null;
        }
      });
      _firebaseInitialization = pending;
      attempt = pending;
    }

    return await attempt.timeout(_firebaseStepTimeout);
  } on TimeoutException catch (error) {
    debugPrint('Tempo limite ao inicializar o Firebase: $error');
    rethrow;
  } catch (error) {
    // Inclui falhas de rede; o chamador seleciona o repositório local.
    debugPrint('Falha ao inicializar o Firebase: $error');
    rethrow;
  }
}

/// Não inicia uma sessão sem persistência se o armazenamento local falhar.
Future<ExpenseRepository> _createLocalRepository() async {
  try {
    return await LocalExpenseRepository.create()
        .timeout(_localRepositoryTimeout);
  } catch (e) {
    debugPrint('Armazenamento local indisponível: $e');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.controller,
    this.carbonScores,
    this.carbonEstimates,
    this.userRepository,
    this.climatiqActivityIds = const {},
    this.notificationCapture,
  });

  final ExpenseController controller;
  final CarbonScoreRepository? carbonScores;
  final climatiq.CarbonScoringRepository? carbonEstimates;
  final UserRepository? userRepository;
  final Map<String, String> climatiqActivityIds;
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
        carbonEstimates: carbonEstimates,
        userRepository: userRepository,
        climatiqActivityIds: climatiqActivityIds,
        notificationCapture: notificationCapture,
      ),
    );
  }
}
