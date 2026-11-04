import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class GetWalletInfoUseCase {
  final WalletRepository repository;

  GetWalletInfoUseCase(this.repository);

  Future<WalletEntity> call() async {
    return await repository.getWalletInfo();
  }
}
