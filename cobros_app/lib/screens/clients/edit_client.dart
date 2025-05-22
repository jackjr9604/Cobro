import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditClientScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;
  final String clientId;

  const EditClientScreen({required this.clientData, required this.clientId, super.key});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ccController;
  late TextEditingController _addressController;
  late TextEditingController _cellphoneController;
  late TextEditingController _refController;
  late TextEditingController _phoneController;
  late TextEditingController _address2Controller;
  late TextEditingController _cityController;

  bool isOwner = false;
  String? selectedCollectorUid;
  List<Map<String, dynamic>> collectors = []; // Cambié el tipo de la lista

  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clientData['clientName']);
    _ccController = TextEditingController(text: widget.clientData['cc']);
    _addressController = TextEditingController(text: widget.clientData['address']);
    _cellphoneController = TextEditingController(text: widget.clientData['cellphone']);
    _refController = TextEditingController(text: widget.clientData['ref/Alias'] ?? '');
    _phoneController = TextEditingController(text: widget.clientData['phone'] ?? '');
    _address2Controller = TextEditingController(text: widget.clientData['address2'] ?? '');
    _cityController = TextEditingController(text: widget.clientData['city'] ?? '');

    fetchUserRoleAndCollectors();
  }

  Future<void> fetchUserRoleAndCollectors() async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    final userData = userDoc.data();
    if (userData == null) return;

    setState(() {
      isOwner = userData['role'] == 'owner';
    });

    if (isOwner) {
      final officeId = userData['officeId'];
      final query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'collector')
              .where('officeId', isEqualTo: officeId)
              .get();

      setState(() {
        collectors =
            query.docs
                .map((doc) => {'uid': doc.id, 'name': doc['displayName'] ?? 'Sin nombre'})
                .toList();

        selectedCollectorUid = widget.clientData['createdBy'];

        // Si el collector no está en la lista, asignar un valor predeterminado
        if (selectedCollectorUid != null &&
            !collectors.any((collector) => collector['uid'] == selectedCollectorUid)) {
          selectedCollectorUid = null; // o puedes asignar un valor predeterminado aquí
        }
      });
    }
  }

  Future<void> updateClient() async {
    if (!_formKey.currentState!.validate()) return;

    final updateData = {
      'address': _addressController.text,
      'cellphone': _cellphoneController.text,
      'refAlias': _refController.text,
      'phone': _phoneController.text,
      'address2': _address2Controller.text,
      'city': _cityController.text,
      'updatedAt': Timestamp.now(),
    };

    final clientRef = FirebaseFirestore.instance.collection('clients').doc(widget.clientId);

    // Solo si es owner puede cambiar el nombre, cc y createdBy
    if (isOwner) {
      updateData['clientName'] = _nameController.text;
      updateData['cc'] = _ccController.text;

      final originalCreatedBy = widget.clientData['createdBy'];
      final newCreatedBy = selectedCollectorUid ?? '';

      updateData['createdBy'] = newCreatedBy;

      await clientRef.update(updateData);

      // Si el createdBy fue cambiado, actualizar los créditos
      if (originalCreatedBy != newCreatedBy) {
        final creditsQuery =
            await FirebaseFirestore.instance
                .collection('credits')
                .where('clientId', isEqualTo: widget.clientId)
                .get();

        final batch = FirebaseFirestore.instance.batch();

        for (final doc in creditsQuery.docs) {
          batch.update(doc.reference, {'createdBy': newCreatedBy});
        }

        await batch.commit();
      }
    } else {
      // Si no es owner, solo actualiza los campos permitidos
      await clientRef.update(updateData);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Cliente')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                enabled: isOwner,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              TextFormField(
                controller: _ccController,
                enabled: isOwner,
                decoration: const InputDecoration(labelText: 'Cédula'),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              TextFormField(
                controller: _cellphoneController,
                decoration: const InputDecoration(labelText: 'Celular'),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              TextFormField(
                controller: _refController,
                decoration: const InputDecoration(labelText: 'Referencia/Alias'),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              TextFormField(
                controller: _address2Controller,
                decoration: const InputDecoration(labelText: 'Dirección 2'),
              ),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
              if (isOwner) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCollectorUid,
                  onChanged: (value) {
                    setState(() {
                      selectedCollectorUid = value;
                    });
                  },
                  items:
                      collectors.isNotEmpty
                          ? collectors.map((collector) {
                            return DropdownMenuItem<String>(
                              value: collector['uid'],
                              child: Text(collector['name']!),
                            );
                          }).toList()
                          : [], // Si no hay collectors, el dropdown estará vacío
                  decoration: const InputDecoration(labelText: 'Asignar a Collector'),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(onPressed: updateClient, child: const Text('Guardar cambios')),
            ],
          ),
        ),
      ),
    );
  }
}
