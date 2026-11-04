import 'wallet_datasource.dart';

class WalletDataSourceMock implements WalletDataSource {
  double _balance = 1250.75;

  @override
  Future<Map<String, dynamic>> getWalletInfo() async {
    return {
      'id': 'wallet_01',
      'balance': _balance,
      'currency': 'BRL',
    };
  }

  @override
  Future<Map<String, dynamic>> deposit(double amount) async {
    _balance += amount;
    return {
      'id': 'wallet_01',
      'balance': _balance,
      'currency': 'BRL',
    };
  }

  @override
  Future<Map<String, dynamic>> withdraw(double amount) async {
    _balance -= amount;
    return {
      'id': 'wallet_01',
      'balance': _balance,
      'currency': 'BRL',
    };
  }
}
