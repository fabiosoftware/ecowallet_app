import '../repositories/dashboard_repository.dart';

class GetDashboardSummaryUseCase {
  final DashboardRepository repository;

  GetDashboardSummaryUseCase(this.repository);

  Future<Map<String, dynamic>> call() async {
    return await repository.getDashboardSummary();
  }
}
