import 'package:flutter/material.dart';

enum ExpenseCategory {
  food('Alimentação', Icons.restaurant_rounded, Colors.orange),
  coffee('Café/Lanche', Icons.local_cafe_rounded, Colors.brown),
  transport('Transporte', Icons.directions_car_filled_rounded, Colors.amber),
  market('Mercado', Icons.shopping_bag_rounded, Colors.purple),
  subscription('Assinaturas', Icons.subscriptions_rounded, Colors.indigo),
  leisure('Lazer', Icons.celebration_rounded, Colors.pink),
  health('Saúde', Icons.favorite_rounded, Colors.red),
  other('Outros', Icons.category_rounded, Colors.blueGrey);

  const ExpenseCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static ExpenseCategory fromName(String? name) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ExpenseCategory.other,
    );
  }
}
