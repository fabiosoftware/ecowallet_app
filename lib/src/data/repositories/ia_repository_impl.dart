import '../datasources/ia_datasource.dart';

class IaRepositoryImpl {
  final IaDataSource dataSource;

  IaRepositoryImpl({required this.dataSource});

  Future<EcoTransactionModel> analyzeTransaction({
    required String title,
    required double amount,
    required String category,
  }) async {
    return await dataSource.analyzeTransaction(
      title: title,
      amount: amount,
      category: category,
    );
  }
}
