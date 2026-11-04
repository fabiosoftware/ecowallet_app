import '../datasources/dashboard_datasource_mock.dart';
import '../models/dashboard_summary_model.dart';

abstract class IDashboardRepository {
  Future<DashboardSummaryModel> getSummary();
}

class DashboardRepositoryImpl implements IDashboardRepository {
  final IDashboardDataSource dataSource;

  DashboardRepositoryImpl(this.dataSource);

  @override
  Future<DashboardSummaryModel> getSummary() async {
    return await dataSource.getDashboardSummary();
  }
}
