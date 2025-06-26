import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditClientScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;
  final String clientId;
  final String officeId; // Nuevo parámetro requerido

  const EditClientScreen({
    required this.clientData,
    required this.clientId,
    required this.officeId, // Hacemos officeId obligatorio
    super.key,
  });

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
  List<Map<String, dynamic>> collectors = [];
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _fetchUserRoleAndCollectors();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.clientData['clientName']);
    _ccController = TextEditingController(text: widget.clientData['cc']);
    _addressController = TextEditingController(text: widget.clientData['address']);
    _cellphoneController = TextEditingController(text: widget.clientData['cellphone']);
    _refController = TextEditingController(text: widget.clientData['refAlias'] ?? '');
    _phoneController = TextEditingController(text: widget.clientData['phone'] ?? '');
    _address2Controller = TextEditingController(text: widget.clientData['address2'] ?? '');
    _cityController = TextEditingController(text: widget.clientData['city'] ?? '');
  }

  Future<void> _fetchUserRoleAndCollectors() async {
    if (currentUser == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();

    if (!userDoc.exists) return;

    setState(() {
      isOwner = userDoc.data()?['role'] == 'owner';
    });

    if (isOwner) {
      await _loadCollectors();
      selectedCollectorUid = widget.clientData['createdBy'];
    }
  }

  Future<void> _loadCollectors() async {
    final query =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('offices')
            .doc(widget.officeId)
            .collection('collectors')
            .get();

    setState(() {
      collectors = [
        {'uid': 'unassigned', 'name': 'Sin asignar'},
        ...query.docs.map((doc) {
          return {'uid': doc.id, 'name': doc['name'] ?? 'Sin nombre'};
        }),
      ];
    });
  }

  Future<void> updateClient() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final updateData = {
        'clientName': _nameController.text,
        'cc': _ccController.text,
        'address': _addressController.text,
        'cellphone': _cellphoneController.text,
        'refAlias': _refController.text,
        'phone': _phoneController.text,
        'address2': _address2Controller.text,
        'city': _cityController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Referencia al cliente en la nueva estructura
      final clientRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('offices')
          .doc(widget.officeId)
          .collection('clients')
          .doc(widget.clientId);

      // Si es owner y cambió el collector, actualizamos
      if (isOwner) {
        if (selectedCollectorUid == 'unassigned') {
          updateData['createdBy'] = FieldValue.delete();
        } else if (selectedCollectorUid != widget.clientData['createdBy']) {
          updateData['createdBy'] = selectedCollectorUid!;
          await _updateCreditsCollector(selectedCollectorUid!);
        }
      }

      await clientRef.update(updateData);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Volver atrás
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateCreditsCollector(String? newCollectorId) async {
    final creditsQuery =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('offices')
            .doc(widget.officeId)
            .collection('credits')
            .where('clientId', isEqualTo: widget.clientId)
            .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in creditsQuery.docs) {
      batch.update(doc.reference, {'createdBy': newCollectorId});
    }
    await batch.commit();
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
      onChanged: (value) {
        setState(() {
          selectedCollectorUid = value;
        });
      },
      decoration: const InputDecoration(
        labelText: 'Asignar a Collector',
        border: OutlineInputBorder(),
      ),
      items:
          collectors.map((collector) {
            return DropdownMenuItem<String>(
              value: collector['uid'],
              child: Text(collector['name']),
            );
          }).toList(),
    );
  }
}
