import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CategoryExpenseEntity {
  final String categoryName;
  final double amount;
  final double percentage;

  const CategoryExpenseEntity({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });
}

class CategoryExpensesChartWidget extends StatelessWidget {
  final List<CategoryExpenseEntity> categories;
  final int touchedIndex;
  final Function(int) onSectionTouched;

  const CategoryExpensesChartWidget({
    super.key,
    required this.categories,
    required this.touchedIndex,
    required this.onSectionTouched,
  });

  static const List<Color> _chartColors = [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.red,
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gastos por Categoria',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        onSectionTouched(-1);
                        return;
                      }
                      onSectionTouched(
                        pieTouchResponse.touchedSection!.touchedSectionIndex,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: List.generate(categories.length, (index) {
                    final isTouched = index == touchedIndex;
                    final fontSize = isTouched ? 18.0 : 12.0;
                    final radius = isTouched ? 65.0 : 55.0;
                    final category = categories[index];
                    final color = _chartColors[index % _chartColors.length];

                    return PieChartSectionData(
                      color: color,
                      value: category.amount,
                      title: '${category.percentage.toStringAsFixed(1)}%',
                      radius: radius,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: List.generate(categories.length, (index) {
                final category = categories[index];
                final color = _chartColors[index % _chartColors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${category.categoryName} (R\$ ${category.amount.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
