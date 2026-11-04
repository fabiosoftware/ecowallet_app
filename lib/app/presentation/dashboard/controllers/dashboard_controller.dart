import 'package:flutter/foundation.dart';
import '../../../domain/usecases/get_dashboard_summary_usecase.dart';

class DashboardController extends ChangeNotifier {
  final GetDashboardSummaryUseCase getDashboardSummaryUseCase;

  DashboardController({required this.getDashboardSummaryUseCase});

  Map<String, dynamic>? dashboardData;
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchDashboardData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      dashboardData = await getDashboardSummaryUseCase.call();
    } catch (e) {
      errorMessage = 'Erro ao carregar dashboard: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
