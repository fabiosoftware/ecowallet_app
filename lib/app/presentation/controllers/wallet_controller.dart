import 'package:flutter/foundation.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/usecases/get_wallet_info_usecase.dart';
import '../../domain/usecases/deposit_usecase.dart';
import '../../domain/usecases/withdraw_usecase.dart';

class WalletController extends ChangeNotifier {
  final GetWalletInfoUseCase getWalletInfoUseCase;
  final DepositUseCase depositUseCase;
  final WithdrawUseCase withdrawUseCase;

  WalletController({
    required this.getWalletInfoUseCase,
    required this.depositUseCase,
    required this.withdrawUseCase,
  });

  WalletEntity? wallet;
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchWallet() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Executa de forma genérica dinâmica para evitar quebra de assinatura do método
      final dynamic result = await (getWalletInfoUseCase as dynamic).execute();
      if (result is WalletEntity) {
        wallet = result;
      }
    } catch (e) {
      errorMessage = 'Erro ao carregar carteira: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> executeDeposit(double amount) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Executa de forma dinâmica blindando o tipo primitivo recebido
      final dynamic result = await (depositUseCase as dynamic).execute(amount);
      if (result is WalletEntity) {
        wallet = result;
      }
    } catch (e) {
      errorMessage = 'Erro ao efetuar depósito: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> executeWithdraw(double amount) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Executa de forma dinâmica blindando o tipo primitivo recebido
      final dynamic result = await (withdrawUseCase as dynamic).execute(amount);
      if (result is WalletEntity) {
        wallet = result;
      }
    } catch (e) {
      errorMessage = 'Erro ao efetuar saque: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
