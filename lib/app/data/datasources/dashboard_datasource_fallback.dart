import '../models/dashboard_summary_model.dart';
import 'dashboard_datasource_mock.dart';

/// Tenta o datasource primário (API Go) e, em qualquer falha, usa o local,
/// mantendo o app funcional offline ou com o serviço fora do ar.
class FallbackDashboardDataSource implements IDashboardDataSource {
  FallbackDashboardDataSource({
    required this.primary,
    required this.fallback,
    this.onFallback,
  });

  final IDashboardDataSource primary;
  final IDashboardDataSource fallback;
  final void Function(Object error, StackTrace stackTrace)? onFallback;

  @override
  Future<DashboardSummaryModel> getDashboardSummary() async {
    try {
      return await primary.getDashboardSummary();
    } catch (error, stackTrace) {
      onFallback?.call(error, stackTrace);
      return fallback.getDashboardSummary();
    }
  }
}
