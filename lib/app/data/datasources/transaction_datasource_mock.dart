import 'transaction_datasource.dart';
import '../models/transaction_model.dart';

class TransactionDataSourceMock implements TransactionDataSource {
  @override
  Future<List<TransactionModel>> getTransactions() async {
    return [
      TransactionModel(
        id: '1',
        title: 'Reciclagem de Plástico',
        amount: 15.50,
        date: DateTime.now(),
      ),
      TransactionModel(
        id: '2',
        title: 'Compra Sustentável',
        amount: -45.00,
        date: DateTime.now(),
      ),
    ];
  }
}
