import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/expense_category.dart';
import '../controllers/expense_controller.dart';

Future<void> showQuickAddExpenseSheet(
  BuildContext context,
  ExpenseController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => QuickAddExpenseSheet(controller: controller),
  );
}

class QuickAddExpenseSheet extends StatefulWidget {
  const QuickAddExpenseSheet({super.key, required this.controller});

  final ExpenseController controller;

  @override
  State<QuickAddExpenseSheet> createState() => _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends State<QuickAddExpenseSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final List<ExpenseCategory> _categories =
      widget.controller.categoriesByUsage;
  late ExpenseCategory _selected = _categories.first;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseBrl(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Informe um valor maior que zero');
      return;
    }
    widget.controller.addExpense(
      amount: amount,
      category: _selected,
      description: _descriptionController.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Novo gasto',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('expense_amount_field'),
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                hintText: '0,00',
                errorText: _error,
                border: InputBorder.none,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in _categories)
                  ChoiceChip(
                    key: Key('category_${category.name}'),
                    avatar: Icon(category.icon,
                        size: 18,
                        color: _selected == category ? null : category.color),
                    label: Text(category.label),
                    selected: _selected == category,
                    onSelected: (_) => setState(() => _selected = category),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('expense_description_field'),
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Descrição (opcional)',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('save_expense_button'),
                onPressed: _save,
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
