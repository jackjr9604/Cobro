import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_office.dart';

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
  bool _isEditing = false;
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

  Future<void> _updateOffice() async {
    if (_officeId == null) return;

    await _firestore.collection('offices').doc(_officeId).update({
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'cellphone': _cellphoneController.text.trim(),
      'address2': _address2Controller.text.trim(),
      'cellphone2': _cellphone2Controller.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    setState(() => _isEditing = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oficina actualizada')));

    await _loadOffice();
  }

  Widget _buildField(String label, TextEditingController controller, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        readOnly: !_isEditing && _hasOffice,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: optional ? const Icon(Icons.info_outline) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Oficina'),
        actions:
            _hasOffice
                ? [
                  ElevatedButton(
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
                      ).then((_) => _loadOffice()); // Al volver, recarga datos
                    },
                    child: const Text('Editar oficina'),
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
                    child: ListView(
                      children: [
                        const Text(
                          'Perfil de la Oficina',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildField('Nombre de la oficina', _nameController),
                        _buildField('Dirección principal', _addressController),
                        _buildField('Teléfono celular', _cellphoneController),
                        const SizedBox(height: 16),
                        const Text('Campos opcionales'),
                        _buildField('Segunda dirección', _address2Controller, optional: true),
                        _buildField('Teléfono alternativo', _cellphone2Controller, optional: true),
                        const SizedBox(height: 16),
                        if (_createdAt != null)
                          Text(
                            'Creado: ${_createdAt!.toDate()}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        if (_updatedAt != null)
                          Text(
                            'Actualizado: ${_updatedAt!.toDate()}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                )
                : ListView(
                  children: [
                    const Text(
                      'Crear nueva oficina',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildField('Nombre de la oficina', _nameController),
                    _buildField('Dirección principal', _addressController),
                    _buildField('Teléfono celular', _cellphoneController),
                    const SizedBox(height: 16),
                    const Text('Campos opcionales'),
                    _buildField('Segunda dirección', _address2Controller, optional: true),
                    _buildField('Teléfono alternativo', _cellphone2Controller, optional: true),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _createOffice, child: const Text('Crear oficina')),
                  ],
                ),
      ),
    );
  }
}
