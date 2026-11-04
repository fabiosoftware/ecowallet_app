import '../repositories/wallet_repository.dart';

class DepositUseCase {
  final WalletRepository repository;

  DepositUseCase(this.repository);

  Future<void> call(double amount) async {
    if (amount <= 0) {
      throw ArgumentError('O valor do depósito deve ser maior que zero.');
    }
    await repository.deposit(amount);
  }
}
