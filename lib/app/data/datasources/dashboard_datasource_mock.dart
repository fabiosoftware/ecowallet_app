import '../models/dashboard_summary_model.dart';

abstract class IDashboardDataSource {
  Future<DashboardSummaryModel> getDashboardSummary();
}

class DashboardDataSourceMock implements IDashboardDataSource {
  @override
  Future<DashboardSummaryModel> getDashboardSummary() async {
    return DashboardSummaryModel(
      totalBalance: 1250.75,
      co2SavedKg: 34.2,
      treesPlanted: 5,
    );
  }
}
