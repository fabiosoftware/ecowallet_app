class TransactionEvent {
  final String id;
  final double valor;
  final String descricao;
  final DateTime timestamp;

  /// Chave da categoria (ex.: 'combustivel', 'alimentacao', 'food').
  final String categoria;

  const TransactionEvent({
    required this.id,
    required this.valor,
    required this.descricao,
    required this.timestamp,
    required this.categoria,
  });

  @override
  String toString() =>
      'TransactionEvent(id: $id, valor: $valor, categoria: $categoria)';
}
