import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream de cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Usuario actual
  User? get currentUser => _auth.currentUser;

  // Obtener datos del usuario actual desde Firestore
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return {...doc.data() as Map<String, dynamic>, 'emailVerified': user.emailVerified};
    } catch (e) {
      debugPrint('Error getting user data: $e');
      throw AuthException('Error al obtener datos del usuario');
    }
  }

  // Iniciar sesión con email y contraseña
  Future<void> signInWithEmailAndPassword({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw AuthException('Correo y contraseña son obligatorios');
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException: code=${e.code}, message=${e.message}');
      if (e.code == 'unknown-error') {
        throw AuthException('Error desconocido de Firebase. Revise su conexión o datos');
      }
      throw AuthException.fromFirebase(e.code);
    } catch (e, s) {
      print('🚨 Error inesperado: $e');
      print('Stack trace: $s');
      throw AuthException('Error inesperado. Intente nuevamente');
    }
  }

  // Registrar nuevo usuario
  // Registrar nuevo usuario
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    String? displayName,
    String? officeId,
    String? officeName,
    bool sendEmailVerification = true,
  }) async {
    UserCredential? userCredential; // Declaramos aquí para que esté disponible en el catch

    try {
      // Crear usuario en Firebase Auth
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Actualizar display name si se proporcionó
      if (displayName != null) {
        await userCredential.user!.updateDisplayName(displayName);
      }

      // Crear perfil en Firestore
      await _createUserProfile(
        user: userCredential.user!,
        role: role,
        officeId: officeId,
        officeName: officeName,
        displayName: displayName,
      );

      // Enviar email de verificación si es necesario
      if (sendEmailVerification) {
        await userCredential.user!.sendEmailVerification();
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Si falla el registro en Firestore, eliminar el usuario de Auth
      if (e.code != 'email-already-in-use' && userCredential?.user != null) {
        await userCredential?.user?.delete();
      }
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      debugPrint('Registration error: $e');
      if (userCredential?.user != null) {
        await userCredential?.user?.delete();
      }
      throw AuthException('Error en el registro');
    }
  }

  // Crear perfil de usuario en Firestore
  Future<void> _createUserProfile({
    required User user,
    required String role,
    String? officeId,
    String? officeName,
    String? displayName,
  }) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName,
        'role': role,
        'officeId': officeId,
        'officeName': officeName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'emailVerified': user.emailVerified,
        'photoUrl': user.photoURL,
      });
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      throw AuthException('Error al crear perfil de usuario');
    }
  }

  // Obtener datos de usuario desde Firestore
  Future<Map<String, dynamic>?> _getUserData(String? uid) async {
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw AuthException('Error al cerrar sesión');
    }
  }

  // Enviar email para restablecer contraseña
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      debugPrint('Password reset error: $e');
      throw AuthException('Error al enviar email de recuperación');
    }
  }

  // Verificar si el email está verificado
  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Enviar nuevo email de verificación
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw AuthException('No hay usuario autenticado');
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      debugPrint('Email verification error: $e');
      throw AuthException('Error al enviar email de verificación');
    }
  }

  // Actualizar perfil de usuario
  Future<void> updateUserProfile({String? displayName, String? photoUrl}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw AuthException('No hay usuario autenticado');

      // Actualizar en Firebase Auth
      await user.updateDisplayName(displayName);
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);

      // Actualizar en Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': displayName ?? user.displayName,
        'photoUrl': photoUrl ?? user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      debugPrint('Update profile error: $e');
      throw AuthException('Error al actualizar perfil');
    }
  }

  // Eliminar cuenta de usuario
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw AuthException('No hay usuario autenticado');

      // Primero eliminar de Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Luego eliminar de Auth
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      debugPrint('Delete account error: $e');
      throw AuthException('Error al eliminar cuenta');
    }
  }
}

class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, [this.code]);

  factory AuthException.fromFirebase(String code) {
    switch (code) {
      case 'user-not-found':
        return AuthException('No existe una cuenta con este correo electrónico');
      case 'wrong-password':
        return AuthException('Contraseña incorrecta');
      case 'email-already-in-use':
        return AuthException('El correo ya está registrado');
      case 'invalid-email':
        return AuthException('El formato del correo electrónico no es válido');
      case 'user-disabled':
        return AuthException('Esta cuenta ha sido deshabilitada');
      case 'too-many-requests':
        return AuthException('Demasiados intentos fallidos. Por favor, espere un momento');
      case 'network-request-failed':
        return AuthException('Error de conexión. Verifique su acceso a internet');
      case 'weak-password':
        return AuthException('La contraseña es demasiado débil');
      case 'operation-not-allowed':
        return AuthException('Operación no permitida');
      case 'requires-recent-login':
        return AuthException('Requiere inicio de sesión reciente');
      case 'invalid-credential':
        return AuthException('Credenciales inválidas o expiradas');
      case 'account-exists-with-different-credential':
        return AuthException('Ya existe una cuenta con este correo usando un método diferente');
      case 'credential-already-in-use':
        return AuthException('Estas credenciales ya están en uso por otra cuenta');
      case 'invalid-verification-code':
        return AuthException('El código de verificación es incorrecto');
      case 'invalid-verification-id':
        return AuthException('El ID de verificación no es válido');
      case 'unknown':
      case 'unknown-error':
        return AuthException('Error desconocido. Verifique los datos e intente de nuevo');

      default:
        debugPrint('Unhandled Firebase auth error code: $code');
        return AuthException('Error de autenticación. Por favor intente nuevamente');
    }
  }

  @override
  String toString() => message;
}
