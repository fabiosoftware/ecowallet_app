import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_datasource.dart';
import '../models/wallet_model.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletDataSource dataSource;

  WalletRepositoryImpl(this.dataSource);

  @override
  Future<WalletEntity> getWalletInfo() async {
    // Busca o Map do DataSource e converte usando o FromJson do modelo
    final map = await dataSource.getWalletInfo();
    return WalletModel.fromJson(map);
  }

  @override
  Future<WalletEntity> deposit(double amount) async {
    // Busca o Map do depósito e faz a conversão
    final map = await dataSource.deposit(amount);
    return WalletModel.fromJson(map);
  }

  @override
  Future<WalletEntity> withdraw(double amount) async {
    // Busca o Map do saque e faz a conversão
    final map = await dataSource.withdraw(amount);
    return WalletModel.fromJson(map);
  }
}
