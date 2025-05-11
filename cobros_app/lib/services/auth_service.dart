import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Método para obtener los datos adicionales del usuario desde Firestore
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Obtiene los datos del usuario desde Firestore (suponiendo que los datos están en 'users/{userId}')
        DocumentSnapshot userData =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userData.exists) {
          return userData.data() as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
    return null;
  }

  // Registro básico con email y contraseña
  Future<User?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    String? officeId,
    String? officeName,
  }) async {
    try {
      // Registro en Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Crear perfil de usuario en Firestore
      await _createUserProfile(
        user: userCredential.user!,
        role: role,
        officeId: officeId,
        officeName: officeName,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    }
  }

  // Crear perfil de usuario en Firestore
  Future<void> _createUserProfile({
    required User user,
    required String role,
    String? officeId,
    String? officeName,
  }) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'role': role,
      'officeId': officeId,
      'officeName': officeName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  // Manejo de errores de autenticación
  Exception _handleAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
        return Exception('Credenciales inválidas');
      case 'email-already-in-use':
        return Exception('El correo ya está registrado');
      default:
        return Exception('Error de autenticación: $code');
    }
  }

  // Método para cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error al cerrar sesión: $e');
      rethrow;
    }
  }

  // Iniciar sesión con correo y contraseña
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Error de autenticación');
    }
  }
}
