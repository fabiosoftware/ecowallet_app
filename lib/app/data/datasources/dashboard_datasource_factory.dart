import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'dashboard_datasource_fallback.dart';
import 'dashboard_datasource_mock.dart';
import 'dashboard_datasource_remote.dart';

/// Escolhe o datasource do dashboard. Sem [baseUrl] ou [companyId], o app usa
/// somente o [local] (comportamento atual, sem rede).
IDashboardDataSource buildDashboardDataSource({
  required IDashboardDataSource local,
  required String? baseUrl,
  required String? companyId,
  required Future<String?> Function() tokenProvider,
  http.Client? client,
}) {
  if (baseUrl == null || baseUrl.isEmpty || companyId == null || companyId.isEmpty) {
    return local;
  }
  return FallbackDashboardDataSource(
    primary: DashboardRemoteDataSource(
      client: client ?? http.Client(),
      baseUrl: baseUrl,
      companyId: companyId,
      tokenProvider: tokenProvider,
    ),
    fallback: local,
    onFallback: (error, _) => debugPrint('Dashboard API indisponível: $error'),
  );
}
