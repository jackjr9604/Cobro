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

    try {
      // Mostrar diálogo de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

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

      if (isOwner) {
        updateData['clientName'] = _nameController.text;
        updateData['cc'] = _ccController.text;
        updateData['createdBy'] = selectedCollectorUid ?? '';
      }

      await clientRef.update(updateData);

      // Si es owner y cambió el collector, actualizar créditos
      if (isOwner && selectedCollectorUid != widget.clientData['createdBy']) {
        final creditsQuery =
            await FirebaseFirestore.instance
                .collection('credits')
                .where('clientId', isEqualTo: widget.clientId)
                .get();

        final batch = FirebaseFirestore.instance.batch();
        for (final doc in creditsQuery.docs) {
          batch.update(doc.reference, {'createdBy': selectedCollectorUid});
        }
        await batch.commit();
      }

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cliente actualizado exitosamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Cerrar diálogo de carga si hay error
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Cliente'),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Información Básica',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        context,
                        'Nombre completo',
                        _nameController,
                        Icons.person,
                        isOwner,
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      _buildFormField(
                        context,
                        'Cédula',
                        _ccController,
                        Icons.badge,
                        isOwner,
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      _buildFormField(
                        context,
                        'Celular',
                        _cellphoneController,
                        Icons.phone_android,
                        true,
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      _buildFormField(context, 'Teléfono', _phoneController, Icons.phone, true),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Información de Dirección',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        context,
                        'Dirección principal',
                        _addressController,
                        Icons.location_on,
                        true,
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      _buildFormField(
                        context,
                        'Dirección secundaria',
                        _address2Controller,
                        Icons.location_city,
                        true,
                      ),
                      _buildFormField(context, 'Ciudad', _cityController, Icons.map, true),
                      _buildFormField(
                        context,
                        'Referencia/Alias',
                        _refController,
                        Icons.short_text,
                        true,
                      ),
                    ],
                  ),
                ),
              ),

              if (isOwner) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Asignación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildCollectorDropdown(),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: SizedBox(
                  width: double.infinity, // Ocupa todo el ancho disponible
                  child: ElevatedButton(
                    onPressed: updateClient,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16), // Altura del botón
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // Bordes redondeados
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.save, size: 20),
                        SizedBox(width: 8),
                        Text('GUARDAR CAMBIOS'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon,
    bool enabled, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: enabled ? Colors.grey[50] : Colors.grey[200],
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildCollectorDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedCollectorUid,
      decoration: InputDecoration(
        labelText: 'Asignar a Collector',
        prefixIcon: Icon(Icons.person_search, color: Theme.of(context).primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (value) => setState(() => selectedCollectorUid = value),
      items:
          collectors.map((collector) {
            return DropdownMenuItem<String>(
              value: collector['uid'],
              child: Text(
                collector['name']!,
                style: TextStyle(
                  color:
                      selectedCollectorUid == collector['uid']
                          ? Theme.of(context).primaryColor
                          : Colors.black,
                ),
              ),
            );
          }).toList(),
    );
  }
}
