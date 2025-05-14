import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class ClientFormScreen extends StatefulWidget {
  final String? clientId;
  final Map<String, dynamic>? initialData;

  const ClientFormScreen({super.key, this.clientId, this.initialData});

  @override
  _ClientFormScreenState createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _clientName, _cc, _cellphone, _address, _refAlias, _phone, _address2, _city;
  late String _officeId, _createdBy;
  late bool isEditing;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    _createdBy = user.uid;
    _officeId = ''; // Inicializamos vacío el officeId
    isEditing = widget.clientId != null;
    if (isEditing) {
      _loadClientData();
    } else {
      // Obtenemos el officeId del documento del usuario
      _getOfficeId(user);
    }
  }

  Future<void> _getOfficeId(User user) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      _officeId = userDoc.data()?['officeId'] ?? ''; // Asignamos el officeId del usuario
    });
  }

  Future<void> _loadClientData() async {
    final clientDoc =
        await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).get();
    final data = clientDoc.data()!;
    _clientName = data['clientName'];
    _cc = data['cc'];
    _cellphone = data['cellphone'];
    _address = data['address'];
    _refAlias = data['ref/Alias'] ?? '';
    _phone = data['phone'] ?? '';
    _address2 = data['address2'] ?? '';
    _city = data['city'] ?? '';
    _officeId = data['officeId']; // Si es edición, tomamos el officeId del cliente
    setState(() {});
  }

  String _generateClientId(String officeId) {
    // 4 primeros dígitos del officeId + 6 alfanuméricos aleatorios
    String randomString = '';
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    for (int i = 0; i < 6; i++) {
      randomString += chars[random.nextInt(chars.length)];
    }
    return '${officeId.substring(0, 4)}$randomString';
  }

  Future<void> _saveClient() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      final clientId = widget.clientId ?? _generateClientId(_officeId);

      await FirebaseFirestore.instance.collection('clients').doc(clientId).set({
        'clientName': _clientName,
        'cc': _cc,
        'cellphone': _cellphone,
        'address': _address,
        'ref/Alias': _refAlias,
        'phone': _phone,
        'address2': _address2,
        'city': _city,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'officeId': _officeId, // Ahora se guarda correctamente el officeId
        'createdBy': _createdBy,
      });

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isCollector = widget.initialData != null && user.uid != widget.initialData!['createdBy'];

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar Cliente' : 'Crear Cliente')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Nombre completo
              TextFormField(
                initialValue: widget.initialData?['clientName'] ?? '',
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                onSaved: (value) => _clientName = value!,
                validator: (value) => value!.isEmpty ? 'El nombre es obligatorio' : null,
                enabled: !isCollector,
              ),
              // Cédula
              TextFormField(
                initialValue: widget.initialData?['cc'] ?? '',
                decoration: const InputDecoration(labelText: 'Cédula'),
                onSaved: (value) => _cc = value!,
                validator: (value) => value!.isEmpty ? 'La cédula es obligatoria' : null,
                enabled: !isCollector,
              ),
              // Celular
              TextFormField(
                initialValue: widget.initialData?['cellphone'] ?? '',
                decoration: const InputDecoration(labelText: 'Celular'),
                onSaved: (value) => _cellphone = value!,
                validator: (value) => value!.isEmpty ? 'El celular es obligatorio' : null,
              ),
              // Dirección
              TextFormField(
                initialValue: widget.initialData?['address'] ?? '',
                decoration: const InputDecoration(labelText: 'Dirección'),
                onSaved: (value) => _address = value!,
                validator: (value) => value!.isEmpty ? 'La dirección es obligatoria' : null,
              ),
              // Referencia / Alias
              TextFormField(
                initialValue: widget.initialData?['ref/Alias'] ?? '',
                decoration: const InputDecoration(labelText: 'Referencia / Alias'),
                onSaved: (value) => _refAlias = value!,
              ),
              // Teléfono
              TextFormField(
                initialValue: widget.initialData?['phone'] ?? '',
                decoration: const InputDecoration(labelText: 'Teléfono'),
                onSaved: (value) => _phone = value!,
              ),
              // Dirección 2
              TextFormField(
                initialValue: widget.initialData?['address2'] ?? '',
                decoration: const InputDecoration(labelText: 'Dirección 2'),
                onSaved: (value) => _address2 = value!,
              ),
              // Ciudad
              TextFormField(
                initialValue: widget.initialData?['city'] ?? '',
                decoration: const InputDecoration(labelText: 'Ciudad'),
                onSaved: (value) => _city = value!,
              ),
              // Botón de guardar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(onPressed: _saveClient, child: const Text('Guardar Cliente')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
