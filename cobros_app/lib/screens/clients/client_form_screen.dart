import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class ClientFormScreen extends StatefulWidget {
  final String? clientId;
  final Map<String, dynamic>? initialData;
  final String officeId;

  const ClientFormScreen({super.key, this.clientId, this.initialData, required this.officeId});

  @override
  _ClientFormScreenState createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _clientName, _cc, _cellphone, _address, _refAlias, _phone, _address2, _city;
  late String _createdBy;
  late bool isEditing;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    _createdBy = user.uid;
    isEditing = widget.clientId != null;

    if (isEditing) {
      _loadClientData();
    }
  }

  Future<void> _loadClientData() async {
    final ownerId = await _getOwnerId(_createdBy);

    final clientDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .collection('offices')
            .doc(widget.officeId)
            .collection('clients')
            .doc(widget.clientId)
            .get();

    if (clientDoc.exists) {
      final data = clientDoc.data()!;
      setState(() {
        _clientName = data['clientName'];
        _cc = data['cc'];
        _cellphone = data['cellphone'];
        _address = data['address'];
        _refAlias = data['refAlias'] ?? '';
        _phone = data['phone'] ?? '';
        _address2 = data['address2'] ?? '';
        _city = data['city'] ?? '';
      });
    }
  }

  String _generateClientId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _saveClient() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final clientId = widget.clientId ?? _generateClientId();
        final now = FieldValue.serverTimestamp();
        final user = FirebaseAuth.instance.currentUser!;

        // Obtener el ownerId (para collectors será el createdBy, para owners será su propio UID)
        final ownerId = await _getOwnerId(user.uid);

        // Preparar los datos del cliente
        final data = {
          'clientName': _clientName,
          'cc': _cc,
          'cellphone': _cellphone,
          'address': _address,
          'refAlias': _refAlias,
          'phone': _phone,
          'address2': _address2,
          'city': _city,
          'createdAt': isEditing ? (widget.initialData?['createdAt'] ?? now) : now,
          'updatedAt': now,
          'officeId': widget.officeId,
          'createdBy': user.uid, // Siempre guardamos quien creó el cliente
        };

        // Referencia a la colección de clientes del OWNER
        final clientRef = FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .collection('offices')
            .doc(widget.officeId)
            .collection('clients')
            .doc(clientId);

        await clientRef.set(data, SetOptions(merge: isEditing));

        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Cliente actualizado' : 'Cliente creado'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Volver atrás
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Método para obtener el ownerId (nuevo)
  Future<String> _getOwnerId(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return userId; // Si el documento no existe, devolvemos el userId como fallback
      }

      final userData = userDoc.data();
      if (userData == null) {
        return userId; // Si data es null, devolvemos el userId como fallback
      }

      // Verificación segura del rol
      final role = userData['role'] as String?;
      if (role == 'collector') {
        return userData['createdBy'] as String? ?? userId;
      }

      return userId; // Para owners o cualquier otro caso
    } catch (e) {
      debugPrint('Error obteniendo ownerId: $e');
      return userId; // En caso de error, devolvemos el userId como fallback
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text('¿Estás seguro de eliminar este cliente?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      try {
        final ownerId = await _getOwnerId(_createdBy);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .collection('offices')
            .doc(widget.officeId)
            .collection('clients')
            .doc(widget.clientId)
            .delete();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isCollector = widget.initialData != null && user.uid != widget.initialData!['createdBy'];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Cliente' : 'Crear Cliente'),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [if (isEditing) IconButton(icon: Icon(Icons.delete), onPressed: _confirmDelete)],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Información Personal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildFormField(
                        context,
                        'Nombre completo',
                        'clientName',
                        Icons.person,
                        !isCollector,
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      _buildFormField(
                        context,
                        'Cédula',
                        'cc',
                        Icons.badge,
                        !isCollector,
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      _buildFormField(
                        context,
                        'Celular',
                        'cellphone',
                        Icons.phone_android,
                        true,
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildFormField(
                        context,
                        'Teléfono',
                        'phone',
                        Icons.phone,
                        true,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Información de Dirección',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildFormField(
                        context,
                        'Dirección principal',
                        'address',
                        Icons.location_on,
                        true,
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      _buildFormField(
                        context,
                        'Dirección secundaria',
                        'address2',
                        Icons.location_city,
                        true,
                      ),
                      _buildFormField(context, 'Ciudad', 'city', Icons.map, true),
                      _buildFormField(
                        context,
                        'Referencia/Alias',
                        'ref/Alias',
                        Icons.short_text,
                        true,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveClient,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 20),
                        SizedBox(width: 8),
                        Text(
                          isEditing ? 'ACTUALIZAR CLIENTE' : 'CREAR CLIENTE',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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
    String fieldKey,
    IconData icon,
    bool enabled, {
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: widget.initialData?[fieldKey] ?? '',
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: enabled ? Colors.grey[50] : Colors.grey[200],
        ),
        keyboardType: keyboardType,
        validator: validator,
        onSaved: (value) {
          switch (fieldKey) {
            case 'clientName':
              _clientName = value!;
              break;
            case 'cc':
              _cc = value!;
              break;
            case 'cellphone':
              _cellphone = value!;
              break;
            case 'address':
              _address = value!;
              break;
            case 'ref/Alias':
              _refAlias = value!;
              break;
            case 'phone':
              _phone = value!;
              break;
            case 'address2':
              _address2 = value!;
              break;
            case 'city':
              _city = value!;
              break;
          }
        },
      ),
    );
  }
}
