class AppUser {
  final String id;
  final String email;
  final String
  password; // En producción, NUNCA almacenes contraseñas en texto plano

  AppUser({required this.id, required this.email, required this.password});

  factory AppUser.fromFirestore(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      email: data['email'],
      password: data['password'], // Solo para ejemplo educativo
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'password':
          password, // En una app real, usa Firebase Auth y no almacenes contraseñas
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
