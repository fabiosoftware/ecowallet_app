import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/carbon_score_model.dart';

/// Acesso às pontuações de carbono do usuário logado. Todas as consultas e
/// gravações são restritas a documentos cujo campo `userId` é [userId].
class CarbonScoreRepository {
  CarbonScoreRepository(this._firestore, {required this.userId});

  final FirebaseFirestore _firestore;

  /// UID do usuário autenticado dono dos dados.
  final String userId;

  static const collectionName = 'carbon_scores';
  static const userIdField = 'userId';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Query<Map<String, dynamic>> get _userScores =>
      _collection.where(userIdField, isEqualTo: userId);

  /// Salva (ou sobrescreve) o score usando o `transactionId` como ID do
  /// documento, sempre associado ao [userId] deste repositório.
  Future<void> saveCarbonScore(CarbonScoreModel score) {
    return _collection.doc(score.transactionId).set({
      ...score.toMap(),
      userIdField: userId,
    });
  }

  /// Fluxo em tempo real dos scores do usuário, do mais recente para o mais
  /// antigo. A ordenação é feita no cliente para não exigir índice composto.
  Stream<List<CarbonScoreModel>> getCarbonScoresStream() {
    return _userScores.snapshots().map((snapshot) {
      final scores = snapshot.docs
          .map((doc) => CarbonScoreModel.fromMap(doc.data()))
          .toList();
      scores.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return scores;
    });
  }

  /// Soma `greenPointsEarned` apenas dos documentos do usuário atual.
  Future<int> fetchTotalGreenPoints() async {
    final snapshot = await _userScores.get();
    return snapshot.docs.fold<int>(
      0,
      (total, doc) =>
          total + ((doc.data()['greenPointsEarned'] as num?)?.toInt() ?? 0),
    );
  }
}
