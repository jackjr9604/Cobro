import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfficesScreen extends StatefulWidget {
  const OfficesScreen({super.key});

  @override
  State<OfficesScreen> createState() => _OfficesScreenState();
}

class _OfficesScreenState extends State<OfficesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedOwnerUid;
  String? _previousOwnerUid;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Formatea la fecha en formato dd/MM/yyyy
  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  // Muestra el formulario para editar una oficina
  void _showEditOfficeDialog(DocumentSnapshot office) async {
    _nameController.text = office['name'];
    _addressController.text = office['address'];
    _selectedOwnerUid = office['createdBy'];
    _previousOwnerUid = office['createdBy'];

    List<QueryDocumentSnapshot> owners = [];

    // Obtenemos los usuarios con el rol 'owner' que no tienen oficina asignada
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'owner')
              .get();

      owners =
          querySnapshot.docs.where((user) {
            // Filtramos los que no tienen oficina asignada,
            // o el dueño actual de esta oficina
            final officeId = user.data()['officeId'];
            return officeId == null || user.id == _selectedOwnerUid;
          }).toList();
    } catch (e) {
      print('Error fetching owners: $e');
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: const Text('Editar Oficina'),
                  content:
                      _isLoading
                          ? const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          )
                          : Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre de la Oficina',
                                  ),
                                  validator:
                                      (value) =>
                                          value!.isEmpty ? 'Requerido' : null,
                                ),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Dirección',
                                  ),
                                  validator:
                                      (value) =>
                                          value!.isEmpty ? 'Requerido' : null,
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: _selectedOwnerUid,
                                  decoration: const InputDecoration(
                                    labelText: 'Dueño de la Oficina',
                                  ),
                                  items:
                                      owners.map((owner) {
                                        final ownerData =
                                            owner.data()
                                                as Map<String, dynamic>;
                                        final displayName =
                                            ownerData['displayName'] ??
                                            'Sin nombre';
                                        return DropdownMenuItem<String>(
                                          value: owner.id,
                                          child: Text(displayName),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      _selectedOwnerUid = value;
                                    });
                                  },
                                  validator:
                                      (value) =>
                                          value == null
                                              ? 'Seleccione un dueño'
                                              : null,
                                ),
                              ],
                            ),
                          ),
                  actions:
                      _isLoading
                          ? []
                          : [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) return;

                                setStateDialog(() {
                                  _isLoading = true;
                                });

                                try {
                                  final officeData = {
                                    'name': _nameController.text.trim(),
                                    'address': _addressController.text.trim(),
                                    'createdBy':
                                        _selectedOwnerUid ?? 'sin dueño',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };

                                  // Actualizamos la oficina
                                  await _firestore
                                      .collection('offices')
                                      .doc(office.id)
                                      .update(officeData);

                                  // Asignar officeId al nuevo dueño
                                  if (_selectedOwnerUid != null) {
                                    await _firestore
                                        .collection('users')
                                        .doc(_selectedOwnerUid)
                                        .update({'officeId': office.id});
                                  }

                                  // Eliminar officeId del dueño anterior si cambió
                                  if (_previousOwnerUid != null &&
                                      _previousOwnerUid != _selectedOwnerUid) {
                                    await _firestore
                                        .collection('users')
                                        .doc(_previousOwnerUid)
                                        .update({
                                          'officeId': FieldValue.delete(),
                                        });
                                  }

                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  print('Error updating office: $e');
                                } finally {
                                  setStateDialog(() {
                                    _isLoading = false;
                                  });
                                }
                              },
                              child: const Text('Guardar'),
                            ),
                          ],
                ),
          ),
    );
  }

  // Agregar una nueva oficina
  void _showCreateOfficeDialog() async {
    _nameController.clear();
    _addressController.clear();
    _selectedOwnerUid = null;

    List<QueryDocumentSnapshot> owners = [];

    // Obtenemos los usuarios con el rol 'owner' que no tienen oficina asignada
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'owner')
              .get();

      owners =
          querySnapshot.docs
              .where(
                (user) => user.data()['officeId'] == null,
              ) // Filtramos los que no tienen oficina asignada
              .toList();
    } catch (e) {
      print('Error fetching owners: $e');
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: const Text('Crear Oficina'),
                  content:
                      _isLoading
                          ? const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          )
                          : Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre de la Oficina',
                                  ),
                                  validator:
                                      (value) =>
                                          value!.isEmpty ? 'Requerido' : null,
                                ),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Dirección',
                                  ),
                                  validator:
                                      (value) =>
                                          value!.isEmpty ? 'Requerido' : null,
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: _selectedOwnerUid,
                                  decoration: const InputDecoration(
                                    labelText: 'Dueño de la Oficina',
                                  ),
                                  items:
                                      owners.map((owner) {
                                        final ownerData =
                                            owner.data()
                                                as Map<String, dynamic>;
                                        final displayName =
                                            ownerData['displayName'] ??
                                            'Sin nombre';
                                        return DropdownMenuItem<String>(
                                          value: owner.id,
                                          child: Text(displayName),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      _selectedOwnerUid = value;
                                    });
                                  },
                                  validator:
                                      (value) =>
                                          value == null
                                              ? 'Seleccione un dueño'
                                              : null,
                                ),
                              ],
                            ),
                          ),
                  actions:
                      _isLoading
                          ? []
                          : [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) return;

                                setStateDialog(() {
                                  _isLoading = true;
                                });

                                try {
                                  final officeData = {
                                    'name': _nameController.text.trim(),
                                    'address': _addressController.text.trim(),
                                    'createdBy':
                                        _selectedOwnerUid ?? 'sin dueño',
                                    'createdAt': FieldValue.serverTimestamp(),
                                  };

                                  // Creamos la nueva oficina
                                  final docRef = await _firestore
                                      .collection('offices')
                                      .add(officeData);

                                  // Asignamos el officeId al dueño
                                  if (_selectedOwnerUid != null) {
                                    await _firestore
                                        .collection('users')
                                        .doc(_selectedOwnerUid)
                                        .update({'officeId': docRef.id});
                                  }

                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  print('Error creating office: $e');
                                } finally {
                                  setStateDialog(() {
                                    _isLoading = false;
                                  });
                                }
                              },
                              child: const Text('Crear'),
                            ),
                          ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oficinas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateOfficeDialog,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestore.collection('offices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay oficinas disponibles.'));
          }

          final offices = snapshot.data!.docs;

          return ListView.builder(
            itemCount: offices.length,
            itemBuilder: (context, index) {
              final office = offices[index];
              final officeData = office.data();

              final name = officeData['name'] ?? 'Sin nombre';
              final address = officeData['address'] ?? 'Sin dirección';
              final createdAtTimestamp = officeData['createdAt'] as Timestamp?;
              final updatedAtTimestamp = officeData['updatedAt'] as Timestamp?;
              final createdByUid = officeData['createdBy'] ?? '';

              final createdAt =
                  createdAtTimestamp != null
                      ? _formatDate(createdAtTimestamp.toDate())
                      : 'Sin fecha';

              final updatedAt =
                  updatedAtTimestamp != null
                      ? _formatDate(updatedAtTimestamp.toDate())
                      : null;

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(createdByUid).get(),
                builder: (context, userSnapshot) {
                  String ownerName = 'Dueño desconocido';
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    ownerName = userData['displayName'] ?? 'Sin nombre';
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dirección: $address'),
                          Text('Dueño: $ownerName'),
                          Text('Creada: $createdAt'),
                          if (updatedAt != null)
                            Text('Actualizada: $updatedAt'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text('Eliminar Oficina'),
                                  content: const Text(
                                    '¿Estás seguro de que deseas eliminar esta oficina?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Eliminar',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                          );

                          if (confirm == true) {
                            try {
                              // Eliminar officeId del dueño
                              await _firestore
                                  .collection('users')
                                  .doc(createdByUid)
                                  .update({'officeId': FieldValue.delete()});

                              // Eliminar oficina
                              await _firestore
                                  .collection('offices')
                                  .doc(office.id)
                                  .delete();
                            } catch (e) {
                              print('Error al eliminar oficina: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error al eliminar la oficina'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () => _showEditOfficeDialog(office),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
