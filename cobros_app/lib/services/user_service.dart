import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener todos los usuarios registrados en Firestore
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final usersSnapshot = await _firestore.collection('users').get();

    return usersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        ...data,
        'isAdmin': data['role'] == 'admin',
        'isOwner': data['role'] == 'owner',
        'isCollector': data['role'] == 'collector',
      };
    }).toList();
  }

  // Verificar si el usuario actual es admin
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.exists && userDoc.data()?['role'] == 'admin';
  }

  // Convertir usuario en admin
  Future<void> promoteToAdmin(String uid, String admin) async {
    await _firestore.collection('users').doc(uid).set({
      'role': admin,
      'promotedAt': FieldValue.serverTimestamp(),
      'promotedBy': _auth.currentUser?.uid,
    });
  }

  // Remover permisos de admin
  Future<void> demoteAdmin(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // Obtener datos del usuario actual con información de Auth + Firestore
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      //Leer documento en Firestore
      final doc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get(); //Accede a la colección users en Firestore y busca el documento con el mismo uid del usuario autenticado.

      if (!doc.exists) {
        print('Documento de usuario no existe'); //Verificar existencia del documento
        return null;
      }

      // Extraer y devolver los datos
      return {
        'uid': user.uid, //ID único del usuario en Firebase.
        'email': user.email, //Correo electrónico del usuario.
        'role':
            doc.data()?['role'] ??
            'user', // Rol del usuario obtenido de Firestore, o 'user' si no existe.
        'officeId':
            doc.data()?['officeId'], //ID de oficina al que pertenece (útil para filtrar accesos o datos).
        //El uso de doc.data()?['campo'] es para evitar errores si el data() es null.
      };
    } catch (e) {
      print('Error detallado: $e'); // Log más descriptivo
      return null;
    }
  }
}
