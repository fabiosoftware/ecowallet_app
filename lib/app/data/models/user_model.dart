import '../../domain/entities/user_entity.dart';

class UserModel {
  UserModel({
    required this.id,
    String plano = UserEntity.defaultPlan,
  }) : plano = UserEntity(
          id: id,
          plano: plano,
        ).plano;

  final String id;
  final String plano;

  factory UserModel.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final rawPlan = map['plano'];
    if (rawPlan != null && rawPlan is! String) {
      throw const FormatException('O campo "plano" deve ser uma string.');
    }
    return UserModel(
        id: id, plano: rawPlan as String? ?? UserEntity.defaultPlan);
  }

  factory UserModel.fromEntity(UserEntity entity) =>
      UserModel(id: entity.id, plano: entity.plano);

  UserEntity toEntity() => UserEntity(id: id, plano: plano);

  Map<String, dynamic> toMap() => {'plano': plano};
}
