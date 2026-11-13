import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _document =>
      _firestore.collection('users').doc(userId);

  @override
  Stream<UserEntity> watchUser() {
    return _document.snapshots().map((snapshot) {
      if (!snapshot.exists) return UserEntity(id: userId);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('O documento do usuário está vazio.');
      }
      return UserModel.fromMap(id: snapshot.id, map: data).toEntity();
    });
  }

  @override
  Future<void> saveUser(UserEntity user) {
    if (user.id != userId) {
      throw ArgumentError.value(
          user.id, 'user.id', 'UID do usuário divergente.');
    }
    return _document.set(
      UserModel.fromEntity(user).toMap(),
      SetOptions(merge: true),
    );
  }
}
