import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_theme.dart';

import 'package:flutter/services.dart';

// quita los . decimales de los numeros
int parseFormattedNumber(String text) {
  final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
  return int.parse(cleaned);
}

//formateador denumeros con $ y . decimales
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat formatter = NumberFormat.decimalPattern('es_CO');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Eliminar todo lo que no sea número (incluye quitar puntos)
    String numericString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numericString.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    // Parsear a número para luego formatear
    int number = int.parse(numericString);

    // Formatear con puntos
    String newText = formatter.format(number);

    // Calcular nueva posición del cursor
    int offset = newText.length - (oldValue.text.length - oldValue.selection.end);

    if (offset < 0) offset = 0;
    if (offset > newText.length) offset = newText.length;

    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: offset));
  }
}

class RegisterCollector extends StatefulWidget {
  const RegisterCollector({super.key});

  @override
  State<RegisterCollector> createState() => _OwnerCollectorsScreenState();
}

class _OwnerCollectorsScreenState extends State<RegisterCollector> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> collectors = [];
  String? ownerOfficeId;
  bool isOwnerActive = false;
  bool isLoading = true;
  bool showForm = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baseController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Map<String, bool> expandedCards = {};

  @override
  void initState() {
    super.initState();
    loadOwnerData();
  }

  Future<void> loadOwnerData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();

      if (userData == null || userData['role'] != 'owner') {
        setState(() => isLoading = false);
        return;
      }

      final officesQuery =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('offices')
              .limit(1)
              .get();

      if (officesQuery.docs.isNotEmpty) {
        final officeDoc = officesQuery.docs.first;

        // Asegurarnos que la oficina tenga createdBy
        if (officeDoc.data()['createdBy'] == null) {
          await officeDoc.reference.update({
            'createdBy': currentUser.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        setState(() {
          ownerOfficeId = officeDoc.id;
          isOwnerActive = (userData['activeStatus'] as Map<String, dynamic>?)?['isActive'] ?? false;
        });

        await loadCollectors();
      }
    } catch (e) {
      debugPrint('Error loading owner data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadCollectors() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || ownerOfficeId == null || !mounted) return;

    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('offices')
              .doc(ownerOfficeId)
              .collection('collectors')
              .get();

      if (!mounted) return;

      setState(() {
        collectors =
            querySnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] ?? 'Sin nombre',
                'email': data['email'] ?? '',
                'base': data['base'] ?? 0,
                'activeStatus': data['activeStatus'] ?? {'isActive': false},
                'createdAt': data['createdAt'],
                'updatedAt': data['updatedAt'],
              };
            }).toList();
      });
    } catch (e) {
      debugPrint('Error cargando cobradores: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al cargar cobradores')));
      }
    }
  }

  // 3. Mejora en registerCollector() para consistencia de datos:
  Future<void> registerCollector() async {
    if (!_formKey.currentState!.validate() || !mounted) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null || ownerOfficeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario no autenticado o oficina no encontrada')),
        );
      }
      return;
    }

    try {
      final authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final collectorUID = authResult.user!.uid;

      // Datos mínimos en users collection
      await _firestore.collection('users').doc(collectorUID).set({
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'collector',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Datos completos en offices/collectors
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('offices')
          .doc(ownerOfficeId)
          .collection('collectors')
          .doc(collectorUID)
          .set({
            'id': collectorUID,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'base': 0,
            'assignedClients': [],
            'officeId': ownerOfficeId,
            'createdBy': currentUser.uid,
            'activeStatus': {'isActive': true, 'lastUpdate': FieldValue.serverTimestamp()},
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          showForm = false;
          _nameController.clear();
          _emailController.clear();
          _passwordController.clear();
        });
        await loadCollectors();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cobrador creado exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al crear cobrador: ${e.toString()}')));
      }
      debugPrint('Error al crear cobrador: $e');
    }
  }

  Future<String> _getOwnerPasswordDialog(BuildContext context) async {
    final TextEditingController _pwController = TextEditingController();
    return await showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirma tu contraseña'),
              content: TextField(
                controller: _pwController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, _pwController.text),
                  child: const Text(
                    'Confirmar',
                    style: TextStyle(fontFamily: AppTheme.primaryFont, color: AppTheme.neutroColor),
                  ),
                ),
              ],
            );
          },
        ) ??
        '';
  }

  Future<void> _updateCollector(
    Map<String, dynamic> collector,
    String newName,
    int newBase,
    bool newStatus,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || ownerOfficeId == null) return;

    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('offices')
        .doc(ownerOfficeId)
        .collection('collectors')
        .doc(collector['id'])
        .update({
          'name': newName,
          'base': newBase,
          'activeStatus': {'isActive': newStatus, 'lastUpdate': FieldValue.serverTimestamp()},
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Actualizar también el nombre en users/{userId} si es necesario
    await _firestore.collection('users').doc(collector['id']).update({'displayName': newName});

    await loadCollectors();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Actualizado correctamente.')));
  }

  Widget _buildEditableField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputFormatters: isNumber ? [ThousandsSeparatorInputFormatter()] : null,
    );
  }

  Widget _buildInactiveAccountScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              'Cuenta no activa',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              'Tu cuenta de propietario no está activa actualmente. Por favor, contacta al administrador para más información.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (!isOwnerActive || ownerOfficeId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Gestión de Cobradores')),
        body: _buildInactiveAccountScreen(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Cobradores'),
        actions: [
          if (isOwnerActive && ownerOfficeId != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppTheme.neutroColor, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: AppTheme.primaryColor),
              ),
              onPressed: () => setState(() => showForm = !showForm),
            ),
        ],
      ),
      body: Column(
        children: [
          if (showForm)
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        'Registrar Nuevo Cobrador',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person, color: Theme.of(context).primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator:
                            (value) => value == null || value.isEmpty ? 'Ingrese un nombre' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email, color: Theme.of(context).primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator:
                            (value) =>
                                value == null || value.isEmpty ? 'Ingrese un correo válido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock, color: Theme.of(context).primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator:
                            (value) =>
                                value == null || value.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: registerCollector,
                          child: const Text('Registrar Cobrador', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Divider(),
          Expanded(
            child:
                collectors.isEmpty
                    ? const Center(child: Text('No hay cobradores registrados.'))
                    : ListView.builder(
                      itemCount: collectors.length,
                      itemBuilder: (context, index) {
                        final collector = collectors[index];
                        final collectorId = collector['id'];
                        final expanded = expandedCards[collectorId] ?? false;
                        final formatter = NumberFormat.decimalPattern('es_CO');

                        final baseController = TextEditingController(
                          text: formatter.format(collector['base'] ?? 0),
                        );
                        final nameController = TextEditingController(text: collector['name']);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ExpansionTile(
                            title: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                child: Icon(Icons.person, color: Theme.of(context).primaryColor),
                              ),
                              title: Text(collector['name']),
                              subtitle: Text(collector['email']),
                              trailing: Chip(
                                backgroundColor:
                                    (collector['activeStatus']?['isActive'] ?? false)
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                label: Text(
                                  (collector['activeStatus']?['isActive'] ?? false)
                                      ? 'Activo'
                                      : 'Inactivo',
                                  style: TextStyle(
                                    color:
                                        (collector['activeStatus']?['isActive'] ?? false)
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildEditableField(
                                      context,
                                      'Nombre',
                                      nameController,
                                      Icons.person_outline,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildEditableField(
                                      context,
                                      'Base',
                                      baseController,
                                      Icons.attach_money,
                                      isNumber: true,
                                    ),
                                    const SizedBox(height: 16),
                                    SwitchListTile(
                                      title: const Text('Estado del cobrador'),
                                      value: collector['activeStatus']?['isActive'] ?? false,
                                      onChanged: (value) {
                                        setState(() {
                                          collector['activeStatus'] = {
                                            'isActive': value,
                                            'lastUpdate': FieldValue.serverTimestamp(),
                                          };
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed:
                                                () => setState(
                                                  () => expandedCards[collectorId] = false,
                                                ),
                                            child: const Text('Cancelar'),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              await _updateCollector(
                                                collector,
                                                nameController.text.trim(),
                                                parseFormattedNumber(baseController.text.trim()),
                                                collector['activeStatus']?['isActive'] ?? true,
                                              );
                                            },
                                            child: const Text('Guardar'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
