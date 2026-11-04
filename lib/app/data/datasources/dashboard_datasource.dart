import '../models/dashboard_summary_model.dart';

abstract class DashboardDataSource {
  Future<DashboardSummaryModel> getDashboardSummary();
}
