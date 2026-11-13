class UserEntity {
  UserEntity({
    required this.id,
    String plano = defaultPlan,
  }) : plano = _validatePlan(plano);

  static const defaultPlan = 'free';
  static const starterPlan = 'starter';
  static const allowedPlans = {defaultPlan, starterPlan};

  final String id;
  final String plano;

  static String _validatePlan(String value) {
    if (!allowedPlans.contains(value)) {
      throw ArgumentError.value(value, 'plano', 'Plano inválido.');
    }
    return value;
  }
}
