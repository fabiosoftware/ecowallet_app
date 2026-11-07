import 'package:ecowallet/app/data/datasources/dashboard_datasource_factory.dart';
import 'package:ecowallet/app/data/datasources/dashboard_datasource_fallback.dart';
import 'package:ecowallet/app/data/datasources/dashboard_datasource_mock.dart';
import 'package:ecowallet/app/data/datasources/dashboard_datasource_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

DashboardRemoteDataSource _remote(http.Client c, {String? token = 't'}) =>
    DashboardRemoteDataSource(
      client: c,
      baseUrl: 'http://api/',
      companyId: 'acme',
      tokenProvider: () async => token,
    );

void main() {
  const okBody =
      '{"total_balance":10.5,"co2_saved_kg":3,"trees_equivalent":2}';

  test('remote mapeia o JSON e envia Bearer token', () async {
    late http.Request captured;
    final ds = _remote(MockClient((req) async {
      captured = req;
      return http.Response(okBody, 200);
    }));

    final m = await ds.getDashboardSummary();

    expect(m.totalBalance, 10.5);
    expect(m.co2SavedKg, 3.0);
    expect(m.treesPlanted, 2);
    expect(captured.url.toString(), 'http://api/v1/companies/acme/carbon/summary');
    expect(captured.headers['Authorization'], 'Bearer t');
  });

  test('remote lança em status != 200, payload inválido e sem token', () async {
    expect(
      _remote(MockClient((_) async => http.Response('x', 403))).getDashboardSummary(),
      throwsA(isA<DashboardRemoteException>()),
    );
    expect(
      _remote(MockClient((_) async => http.Response('{}', 200))).getDashboardSummary(),
      throwsA(isA<DashboardRemoteException>()),
    );
    expect(
      _remote(MockClient((_) async => http.Response(okBody, 200)), token: null)
          .getDashboardSummary(),
      throwsA(isA<DashboardRemoteException>()),
    );
  });

  test('fallback usa o local quando a API falha', () async {
    Object? reported;
    final ds = FallbackDashboardDataSource(
      primary: _remote(MockClient((_) async => throw http.ClientException('down'))),
      fallback: DashboardDataSourceMock(),
      onFallback: (e, _) => reported = e,
    );

    final m = await ds.getDashboardSummary();

    expect(m.treesPlanted, 5);
    expect(reported, isNotNull);
  });

  test('factory retorna o local quando a URL não está configurada', () {
    final local = DashboardDataSourceMock();
    final ds = buildDashboardDataSource(
      local: local,
      baseUrl: '',
      companyId: 'acme',
      tokenProvider: () async => 't',
    );
    expect(identical(ds, local), isTrue);
  });
}
