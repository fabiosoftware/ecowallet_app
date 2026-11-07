import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dashboard_summary_model.dart';
import 'dashboard_datasource_mock.dart';

class DashboardRemoteException implements Exception {
  final String message;
  final int? statusCode;

  const DashboardRemoteException(this.message, {this.statusCode});

  @override
  String toString() => 'DashboardRemoteException($statusCode): $message';
}

/// Busca o resumo do dashboard no microsserviço Go (REST).
class DashboardRemoteDataSource implements IDashboardDataSource {
  DashboardRemoteDataSource({
    required http.Client client,
    required String baseUrl,
    required String companyId,
    required Future<String?> Function() tokenProvider,
    Duration timeout = const Duration(seconds: 8),
  })  : _client = client,
        _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _companyId = companyId,
        _tokenProvider = tokenProvider,
        _timeout = timeout;

  final http.Client _client;
  final String _baseUrl;
  final String _companyId;
  final Future<String?> Function() _tokenProvider;
  final Duration _timeout;

  @override
  Future<DashboardSummaryModel> getDashboardSummary() async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const DashboardRemoteException('Usuário não autenticado.');
    }

    final uri = Uri.parse(
      '$_baseUrl/v1/companies/${Uri.encodeComponent(_companyId)}/carbon/summary',
    );

    final http.Response res;
    try {
      res = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
    } on TimeoutException {
      throw const DashboardRemoteException('Tempo esgotado ao chamar a API.');
    }

    if (res.statusCode != 200) {
      throw DashboardRemoteException(
        'Resposta inesperada da API.',
        statusCode: res.statusCode,
      );
    }

    try {
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return DashboardSummaryModel(
        totalBalance: (json['total_balance'] as num).toDouble(),
        co2SavedKg: (json['co2_saved_kg'] as num).toDouble(),
        treesPlanted: (json['trees_equivalent'] as num).toInt(),
      );
    } catch (_) {
      throw DashboardRemoteException(
        'Payload inválido.',
        statusCode: res.statusCode,
      );
    }
  }
}
