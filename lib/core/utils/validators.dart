abstract final class Validators {
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe seu nome completo.';
    }
    if (value.trim().length < 2) return 'Informe um nome válido.';
    if (value.trim().length > 120) return 'Use no máximo 120 caracteres.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe seu e-mail.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  static String? loginPassword(String? value) =>
      value == null || value.isEmpty ? 'Informe sua senha.' : null;

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Crie uma senha.';
    if (value.length < 8) return 'Use pelo menos 8 caracteres.';
    return null;
  }
}
