import 'package:ecowallet/app/data/models/user_model.dart';
import 'package:ecowallet/app/domain/entities/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses free as the default plan and persists the plan field', () {
    final user = UserModel.fromMap(id: 'user-1', map: const {});

    expect(user.plano, UserEntity.defaultPlan);
    expect(user.toMap(), {'plano': 'free'});
    expect(user.toEntity().plano, 'free');
  });

  test('accepts starter and rejects unsupported plans', () {
    final user = UserModel.fromMap(
      id: 'user-1',
      map: const {'plano': 'starter'},
    );

    expect(user.toEntity().plano, 'starter');
    expect(
      () => UserModel.fromMap(
        id: 'user-1',
        map: const {'plano': 'enterprise'},
      ),
      throwsArgumentError,
    );
  });

  test('rejects a non-string plan value', () {
    expect(
      () => UserModel.fromMap(id: 'user-1', map: const {'plano': 1}),
      throwsFormatException,
    );
  });
}
