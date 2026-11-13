import '../entities/user_entity.dart';

abstract interface class UserRepository {
  Stream<UserEntity> watchUser();

  Future<void> saveUser(UserEntity user);
}
