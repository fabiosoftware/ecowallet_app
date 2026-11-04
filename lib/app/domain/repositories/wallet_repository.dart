import '../entities/wallet_entity.dart';

abstract class WalletRepository {
  Future<WalletEntity> getWalletInfo();

  Future<WalletEntity> deposit(double amount);

  Future<WalletEntity> withdraw(double amount);
}
