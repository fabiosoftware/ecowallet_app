import '../repositories/ia_repository.dart';

/// Caso de uso responsável por intermediar a regra de negócio de busca de dicas.
class BuscarDicaSustentavelUsecase {
  final IaRepository repository;

  BuscarDicaSustentavelUsecase({required this.repository});

  /// Executa o caso de uso chamando o repositório com o método corrigido.
  Future<Map<String, dynamic>> call(Map<String, dynamic> dados) async {
    return await repository.buscarDicaSustentavel(dados);
  }
}
