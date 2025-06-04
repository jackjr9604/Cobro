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

      try {
        // Mostrar diálogo de carga
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );

        final clientId = widget.clientId ?? _generateClientId(_officeId);
        final now = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance.collection('clients').doc(clientId).set({
          'clientName': _clientName,
          'cc': _cc,
          'cellphone': _cellphone,
          'address': _address,
          'ref/Alias': _refAlias,
          'phone': _phone,
          'address2': _address2,
          'city': _city,
          'createdAt':
              isEditing
                  ? (widget.initialData != null ? widget.initialData!['createdAt'] : now)
                  : now,
          'updatedAt': now,
          'officeId': _officeId,
          'createdBy': _createdBy,
        }, SetOptions(merge: isEditing));

        // Cerrar diálogo de carga
        if (mounted) Navigator.pop(context);

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Cliente actualizado' : 'Cliente creado'),
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
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirmar eliminación'),
            content: Text('¿Estás seguro de eliminar este cliente?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).delete();
      Navigator.pop(context);
    }
  }
}
