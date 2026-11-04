abstract class WalletDataSource {
  Future<Map<String, dynamic>> getWalletInfo();
  Future<Map<String, dynamic>> deposit(double amount);
  Future<Map<String, dynamic>> withdraw(double amount);
}
