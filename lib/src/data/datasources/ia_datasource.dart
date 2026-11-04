import 'dart:async';

class EcoTransactionModel {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final double carbonFootprintKg;
  final String ecoTip;
  EcoTransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.carbonFootprintKg,
    required this.ecoTip,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'carbonFootprintKg': carbonFootprintKg,
      'ecoTip': ecoTip,
    };
  }

  factory EcoTransactionModel.fromMap(Map<String, dynamic> map) {
    return EcoTransactionModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] ?? '',
      date: DateTime.parse(map['date']),
      carbonFootprintKg: (map['carbonFootprintKg'] as num).toDouble(),
      ecoTip: map['ecoTip'] ?? '',
    );
  }
}

abstract class IaDataSource {
  Future<EcoTransactionModel> analyzeTransaction({
    required String title,
    required double amount,
    required String category,
  });
}

class IaDataSourceImpl implements IaDataSource {
  @override
  Future<EcoTransactionModel> analyzeTransaction({
    required String title,
    required double amount,
    required String category,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    double carbonFactor = 0.15;
    String tip = "Boa escolha de consumo consciente!";

    final lowerCategory = category.toLowerCase();
    final lowerTitle = title.toLowerCase();

    if (lowerCategory.contains("transporte") ||
        lowerTitle.contains("uber") ||
        lowerTitle.contains("gasolina")) {
      carbonFactor = 0.45;
      tip =
          "Dica Eco: Transitar de transporte público ou bicicleta reduz sua pegada de carbono em até 70%.";
    } else if (lowerCategory.contains("alimentacao") ||
        lowerTitle.contains("restaurante") ||
        lowerTitle.contains("ifood")) {
      carbonFactor = 0.25;
      tip =
          "Dica Eco: Opte por estabelecimentos locais com produtos orgânicos para diminuir a pegada de frete.";
    } else if (lowerCategory.contains("energia") ||
        lowerCategory.contains("servicos")) {
      carbonFactor = 0.35;
      tip =
          "Dica Eco: Desligar aparelhos em standby pode economizar até 10% na conta de luz e emissões.";
    } else {
      carbonFactor = 0.10;
      tip =
          "Dica Eco: Acompanhar seus pequenos gastos evita emissões desnecessárias da cadeia produtiva.";
    }

    final calculatedCarbon = amount * carbonFactor;

    return EcoTransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      category: category,
      date: DateTime.now(),
      carbonFootprintKg: double.parse(calculatedCarbon.toStringAsFixed(2)),
      ecoTip: tip,
    );
  }
}
