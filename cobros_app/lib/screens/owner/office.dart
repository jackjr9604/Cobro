import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/responsive.dart'; // Tu helper
import '../owner/edit_office.dart';

class OfficeManagementScreen extends StatefulWidget {
  const OfficeManagementScreen({super.key});

  @override
  State<OfficeManagementScreen> createState() => _OfficeManagementScreenState();
}

class _OfficeManagementScreenState extends State<OfficeManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _officeData;
  String? _officeId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOffice();
  }

  Future<void> _loadOffice() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data();

    if (userData == null) return;

    String? linkedOfficeId = userData['officeId'];

    if (linkedOfficeId != null) {
      final officeDoc =
          await _firestore.collection('offices').doc(linkedOfficeId).get();
      if (officeDoc.exists) {
        setState(() {
          _officeId = officeDoc.id;
          _officeData = officeDoc.data();
          _isLoading = false;
        });
        return;
      }
    }

    final offices =
        await _firestore
            .collection('offices')
            .where('createdBy', isEqualTo: currentUser.uid)
            .get();

    if (offices.docs.isNotEmpty) {
      final doc = offices.docs.first;
      setState(() {
        _officeId = doc.id;
        _officeData = doc.data();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildField(String label, String? value) {
    final labelStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: Responsive.isMobile(context) ? 14 : 18,
    );
    final valueStyle = TextStyle(
      fontSize: Responsive.isMobile(context) ? 14 : 16,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: Responsive.isMobile(context) ? 6 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: labelStyle),
          Expanded(
            child: Text(
              value?.isNotEmpty == true ? value! : 'No registrado',
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = Responsive.screenWidth(context);
    final horizontalPadding = Responsive.isMobile(context) ? 16.0 : 32.0;
    final verticalSpacing = Responsive.isMobile(context) ? 16.0 : 24.0;
    final titleFontSize = Responsive.isMobile(context) ? 20.0 : 26.0;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_officeData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Oficina')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              // Ir a la pantalla de creación
            },
            child: const Text('Crear oficina'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _officeData?['name'] ?? '',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalSpacing,
        ),
        child: Center(
          child: Container(
            width: Responsive.isMobile(context) ? screenWidth * 0.95 : 600,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!Responsive.isMobile(context))
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField('Dirección principal', _officeData?['address']),
                _buildField('Teléfono celular', _officeData?['cellphone']),
                _buildField('Dirección secundaria', _officeData?['address2']),
                _buildField('Teléfono secundario', _officeData?['cellphone2']),
                if (_officeData?['createdAt'] != null)
                  _buildField(
                    'Fecha de creación',
                    (_officeData!['createdAt'] as Timestamp)
                        .toDate()
                        .toString(),
                  ),
                if (_officeData?['updatedAt'] != null)
                  _buildField(
                    'Última actualización',
                    (_officeData!['updatedAt'] as Timestamp)
                        .toDate()
                        .toString(),
                  ),
                SizedBox(height: verticalSpacing),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar oficina'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => EditOfficeScreen(
                                officeId: _officeId!,
                                initialData: {
                                  'name': _officeData?['name'] ?? '',
                                  'address': _officeData?['address'] ?? '',
                                  'cellphone': _officeData?['cellphone'] ?? '',
                                  'address2': _officeData?['address2'] ?? '',
                                  'cellphone2':
                                      _officeData?['cellphone2'] ?? '',
                                },
                              ),
                        ),
                      ).then((_) => _loadOffice());
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
