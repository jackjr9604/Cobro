import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_office.dart';
import '../../../utils/app_theme.dart';
import 'package:intl/intl.dart'; // para Clipboard

class OfficeManagementScreen extends StatefulWidget {
  const OfficeManagementScreen({super.key});

  @override
  State<OfficeManagementScreen> createState() => _OfficeManagementScreenState();
}

class _OfficeManagementScreenState extends State<OfficeManagementScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cellphoneController = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cellphone2Controller = TextEditingController();

  bool _isLoading = true;
  bool _hasOffice = false;
  String? _officeId;
  Timestamp? _createdAt;
  Timestamp? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadOffice();
  }

  Future<void> _loadOffice() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    String? officeId = userData?['officeId'];

    if (officeId == null) {
      final officeQuery =
          await _firestore
              .collection('offices')
              .where('createdBy', isEqualTo: user.uid)
              .limit(1)
              .get();
      if (officeQuery.docs.isNotEmpty) {
        final doc = officeQuery.docs.first;
        officeId = doc.id;
        await _firestore.collection('users').doc(user.uid).update({'officeId': officeId});
      }
    }

    if (officeId != null) {
      final officeDoc = await _firestore.collection('offices').doc(officeId).get();
      final data = officeDoc.data();
      if (data != null) {
        _officeId = officeId;
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _cellphoneController.text = data['cellphone'] ?? '';
        _address2Controller.text = data['address2'] ?? '';
        _cellphone2Controller.text = data['cellphone2'] ?? '';
        _createdAt = data['createdAt'];
        _updatedAt = data['updatedAt'];
        _hasOffice = true;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _generateOfficeId() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(20, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _createOffice() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final cellphone = _cellphoneController.text.trim();

    if (name.isEmpty || address.isEmpty || cellphone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Completa todos los campos obligatorios')));
      return;
    }

    final officeId = _generateOfficeId();
    final now = FieldValue.serverTimestamp();

    await _firestore.collection('offices').doc(officeId).set({
      'name': name,
      'address': address,
      'cellphone': cellphone,
      'address2': _address2Controller.text.trim(),
      'cellphone2': _cellphone2Controller.text.trim(),
      'createdBy': user.uid,
      'createdAt': now,
    });

    await _firestore.collection('users').doc(user.uid).update({'officeId': officeId});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oficina creada correctamente')));

    setState(() {
      _officeId = officeId;
      _hasOffice = true;
      _isLoading = true;
    });

    await _loadOffice();
  }

  Widget _buildFormField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(String label, DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}',
        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Oficina', style: Theme.of(context).textTheme.displayLarge),
        actions:
            _hasOffice
                ? [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => EditOfficeScreen(
                                officeId: _officeId!,
                                initialData: {
                                  'name': _nameController.text,
                                  'address': _addressController.text,
                                  'cellphone': _cellphoneController.text,
                                  'address2': _address2Controller.text,
                                  'cellphone2': _cellphone2Controller.text,
                                },
                              ),
                        ),
                      ).then((_) => _loadOffice());
                    },
                  ),
                ]
                : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _hasOffice
                ? Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.business, size: 28, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 10),
                            Text(
                              _nameController.text,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppTheme.primaryFont,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Sección de información principal
                        _buildInfoItem(
                          Icons.location_on,
                          'Dirección Principal',
                          _addressController.text,
                        ),
                        _buildInfoItem(
                          Icons.phone,
                          'Teléfono Principal',
                          _cellphoneController.text,
                        ),
                        // Sección opcional solo si existe información
                        if (_address2Controller.text.isNotEmpty)
                          _buildInfoItem(
                            Icons.location_city,
                            'Dirección Alternativa',
                            _address2Controller.text,
                          ),
                        if (_cellphone2Controller.text.isNotEmpty)
                          _buildInfoItem(
                            Icons.phone_android,
                            'Teléfono Alternativo',
                            _cellphone2Controller.text,
                          ),
                        //Metadata
                        const SizedBox(height: 20),
                        if (_createdAt != null) _buildMetaInfo('Creado el', _createdAt!.toDate()),
                        if (_updatedAt != null)
                          _buildMetaInfo('Actualizado el', _updatedAt!.toDate()),
                      ],
                    ),
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crear nueva oficina',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFormField('Nombre de la oficina', _nameController, Icons.business),
                    _buildFormField('Dirección principal', _addressController, Icons.location_on),
                    _buildFormField('Teléfono celular', _cellphoneController, Icons.phone),
                    // Sección opcional
                    const SizedBox(height: 16),
                    Text(
                      'Información adicional (opcional)',
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                    _buildFormField('Segunda dirección', _address2Controller, Icons.location_city),
                    _buildFormField(
                      'Teléfono alternativo',
                      _cellphone2Controller,
                      Icons.phone_android,
                    ),
                    // Botón de creación
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _createOffice,
                        child: const Text('Crear oficina'),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
