import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/user_entity.dart';

const String kCheckoutStarterUrl = 'https://ecowallet-app-2026.web.app';

class PlanGuardWidget extends StatelessWidget {
  const PlanGuardWidget({
    super.key,
    required this.userStream,
    required this.child,
    this.compact = false,
  });

  final Stream<UserEntity> userStream;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserEntity>(
      stream: userStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PlanStateError(compact: compact);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.plano == UserEntity.starterPlan) return child;
        return _StarterPaywall(compact: compact);
      },
    );
  }
}

class _PlanStateError extends StatelessWidget {
  const _PlanStateError({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final message = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 36),
        const SizedBox(height: 12),
        Text(
          'Não foi possível verificar seu plano. Confira sua conexão e tente novamente.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    if (compact) {
      return Card(
          child: Padding(padding: const EdgeInsets.all(20), child: message));
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: message),
        ),
      ),
    );
  }
}

class _StarterPaywall extends StatelessWidget {
  const _StarterPaywall({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: compact ? 36 : 52,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Plano Starter B2B para sua operação',
          textAlign: TextAlign.center,
          style: (compact
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.headlineSmall)
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Automatize registros de compras e acompanhe o histórico financeiro '
          'e indicadores ESG com estimativas de carbono. As estimativas são '
          'informativas e não substituem um inventário de emissões verificado.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text(
          'R\$ 499,00/mês',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => _openCheckout(context),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Conhecer o Plano Starter'),
        ),
      ],
    );

    if (compact) {
      return Card(
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCheckout(BuildContext context) async {
    final uri = Uri.parse(kCheckoutStarterUrl);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showCheckoutError(context);
      }
    } catch (error) {
      if (context.mounted) _showCheckoutError(context);
      debugPrint('Não foi possível abrir o checkout do Starter: $error');
    }
  }

  void _showCheckoutError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o checkout.')),
    );
  }
}
