import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

mixin OfficeVerificationMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> verifyOfficeAndStatus() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'hasOffice': false, 'isActive': false};
    }

    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final data = userDoc.data();

    if (data != null && data['role'] == 'owner' && data.containsKey('officeId')) {
      final activeStatus = data['activeStatus'] as Map<String, dynamic>?;
      final isActive = activeStatus?['isActive'] ?? false;

      return {
        'hasOffice': true,
        'isActive': isActive,
        'officeId': data['officeId'],
        'userData': data,
      };
    }

    return {'hasOffice': false, 'isActive': false};
  }
}
