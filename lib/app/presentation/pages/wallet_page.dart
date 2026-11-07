import 'package:flutter/material.dart';

import '../../core/notifications/notification_expense_capture_service.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/expense_entity.dart';
import '../controllers/expense_controller.dart';
import '../widgets/quick_add_expense_sheet.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({
    super.key,
    required this.controller,
    this.notificationCapture,
  });

  final ExpenseController controller;
  final NotificationExpenseCaptureService? notificationCapture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'EcoWallet',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (notificationCapture != null)
            ValueListenableBuilder<NotificationCaptureStatus>(
              valueListenable: notificationCapture!.status,
              builder: (context, status, _) => IconButton(
                key: const Key('notification_capture_button'),
                tooltip: status == NotificationCaptureStatus.listening
                    ? 'Captura de notificações ativa'
                    : 'Configurar captura de notificações',
                onPressed: () => _configureNotificationCapture(context),
                icon: Icon(
                  status == NotificationCaptureStatus.listening
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_outlined,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_expense_fab'),
        onPressed: () => showQuickAddExpenseSheet(context, controller),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Gasto'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _buildBody(context, theme),
        ),
      ),
    );
  }

  Future<void> _configureNotificationCapture(BuildContext context) async {
    final capture = notificationCapture;
    if (capture == null) return;

    if (capture.status.value == NotificationCaptureStatus.unsupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'A captura de notificações está disponível somente no Android.'),
        ),
      );
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Captura de compras'),
        content: const Text(
          'O Android exige acesso às notificações para esta função. '
          'Enquanto ativa, o EcoWallet analisa o conteúdo no aparelho para '
          'identificar notificações de transação. Somente mensagens que '
          'correspondam aos padrões de compra são convertidas em gastos; '
          'as demais não são guardadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (accepted != true) return;

    final enabled = await capture.requestPermissionAndStart();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Captura de compras ativada.'
              : 'O acesso às notificações não foi concedido.',
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    final groups = controller.groups;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      physics: const BouncingScrollPhysics(),
      children: [
        _SummaryCard(
          today: controller.todayTotal,
          month: controller.monthTotal,
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              controller.errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        if (controller.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (groups.isEmpty)
          const _EmptyState()
        else
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDayLabel(group.day, now),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    formatBrl(group.total),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final expense in group.items) _ExpenseTile(expense: expense),
          ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.today, required this.month});

  final double today;
  final double month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('wallet_summary_card'),
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gastos de hoje',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    formatBrl(today),
                    key: const Key('today_total'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Container(
                width: 1, height: 50, color: theme.colorScheme.outlineVariant),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gastos do mês',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      formatBrl(month),
                      key: const Key('month_total'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});

  final ExpenseEntity expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = expense.category;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(category.icon, color: category.color),
      ),
      title: Text(
        expense.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        '${category.label} · ${formatTime(expense.date)}',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        '- ${formatBrl(expense.amount)}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('Nenhum gasto ainda', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Toque em "Gasto" para registrar o primeiro.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
