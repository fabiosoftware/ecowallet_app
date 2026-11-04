import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class WithdrawUseCase {
  final WalletRepository repository;

  WithdrawUseCase(this.repository);

  Future<WalletEntity> call(double amount) async {
    return await repository.withdraw(amount);
  }
}
