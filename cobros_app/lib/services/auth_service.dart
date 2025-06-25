import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Streams públicos
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<Map<String, dynamic>?> userDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      return snapshot.data()?..['emailVerified'] = _auth.currentUser?.emailVerified ?? false;
    });
  }

  // Usuario actual
  User? get currentUser => _auth.currentUser;

  // Método unificado para manejo de membresía
  Future<Map<String, dynamic>?> checkAndUpdateMembershipStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = _firestore.collection('users').doc(user.uid);
      final doc = await userDoc.get();

      if (!doc.exists) return null;

      final activeStatus = doc.data()?['activeStatus'] as Map<String, dynamic>?;
      if (activeStatus == null) return null;

      final now = DateTime.now();
      final endDate = (activeStatus['endDate'] as Timestamp).toDate();
      final isActive = activeStatus['isActive'] as bool;

      if (now.isAfter(endDate) && isActive) {
        final updatedStatus = {
          'isActive': false,
          'startDate': activeStatus['startDate'],
          'endDate': activeStatus['endDate'],
        };

        await userDoc.update({'activeStatus': updatedStatus});
        return updatedStatus;
      }

      return activeStatus;
    } catch (e) {
      debugPrint('Error en membresía: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      // Verificar y actualizar estado de membresía primero
      await checkAndUpdateMembershipStatus();

      return {
        ...doc.data() as Map<String, dynamic>,
        'emailVerified': user.emailVerified,
        'isMembershipActive': await _checkMembershipActiveStatus(user.uid),
      };
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  Future<bool> _checkMembershipActiveStatus(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final activeStatus = doc.data()?['activeStatus'] as Map<String, dynamic>?;
      if (activeStatus == null) return false;

      final endDate = (activeStatus['endDate'] as Timestamp).toDate();
      return activeStatus['isActive'] as bool && !DateTime.now().isAfter(endDate);
    } catch (e) {
      debugPrint('Error checking membership: $e');
      return false;
    }
  }

  // Autenticación
  Future<void> signInWithEmailAndPassword({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
      await checkAndUpdateMembershipStatus();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      debugPrint('Error en login: $e');
      throw const AuthException('Error al iniciar sesión');
    }
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    String? displayName,
    String? officeId,
    String? officeName,
    bool sendEmailVerification = true,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'displayName': displayName ?? userCredential.user!.displayName ?? '',
        'role': role,
        'officeId': officeId,
        'officeName': officeName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'emailVerified': false,
        'photoUrl': userCredential.user!.photoURL,
      });

      if (sendEmailVerification) {
        await userCredential.user!.sendEmailVerification();
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      debugPrint('Error en registro: $e');
      throw const AuthException('Error en el registro');
    }
  }

  // Métodos simplificados de perfil
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const AuthException('No autenticado');

      await Future.wait([
        if (displayName != null) user.updateDisplayName(displayName),
        if (photoUrl != null) user.updatePhotoURL(photoUrl),
        _firestore.collection('users').doc(user.uid).update({
          if (displayName != null) 'displayName': displayName,
          if (photoUrl != null) 'photoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ]);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      debugPrint('Error actualizando perfil: $e');
      throw const AuthException('Error al actualizar perfil');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error en logout: $e');
      throw const AuthException('Error al cerrar sesión');
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

  const AuthException(this.message, [this.code]);

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
        debugPrint('Código de error no manejado: $code');
        return const AuthException('Error de autenticación');
    }
  }

  @override
  String toString() => message;
}
