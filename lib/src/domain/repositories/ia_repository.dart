import 'dart:async';

abstract class IaRepository {
  // Mudamos de buscar_dica_sustentavel para buscarDicaSustentavel
  Future<Map<String, dynamic>> buscarDicaSustentavel(
      Map<String, dynamic> dados);
}
