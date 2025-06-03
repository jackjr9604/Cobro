import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // para Clipboard

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(context: context, builder: (_) => const AddUserDialog());
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar usuarios'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          if (users.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final data = user.data() as Map<String, dynamic>?;

              final isCurrentUser = user.id == currentUserUid;

              final displayName = data?['displayName'] ?? 'Sin nombre';
              final email = data?['email'] ?? 'Sin correo';
              final role = data?['role'] ?? 'Sin rol';
              final activeStatus = data?['activeStatus'] ?? {'isActive': false};
              final isActive = activeStatus['isActive'] ?? false;
              final startDate = activeStatus['startDate']?.toDate();
              final endDate = activeStatus['endDate']?.toDate();
              final timestamp = data?['createdAt'];
              final createdAt =
                  (timestamp is Timestamp)
                      ? timestamp.toDate().toString().split('.')[0]
                      : 'Sin fecha';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '⚠️ Este es tu usuario actual. No lo elimines por accidente.',
                        style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                      ),
                    ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => EditUserDialog(userId: user.id, currentData: data ?? {}),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Nombre: $displayName'),
                                  Text('Email: $email'),
                                  Text('Rol: $role'),
                                  Text('Creado: $createdAt'),
                                  if (startDate != null)
                                    Text(
                                      'Activo desde: ${DateFormat('dd/MM/yyyy').format(startDate)}',
                                    ),
                                  if (endDate != null)
                                    Text(
                                      'Activo hasta: ${DateFormat('dd/MM/yyyy').format(endDate)}',
                                    ),
                                  Text('Creado: $createdAt'),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.circle,
                              color: isActive ? Colors.green : Colors.red,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------
// DIALOGO PARA AGREGAR USUARIO
// ----------------------------------------
class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'admin';
  bool _loading = false;
  DateTime? _startDate;
  DateTime? _endDate;

  final _roles = ['admin', 'owner', 'collector'];

  Future<void> _createUser() async {
    try {
      setState(() => _loading = true);
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;
      final now = Timestamp.now();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'activeStatus': {
          'isActive': false,
          'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
          'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        },
        'createdAt': now,
      });

      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario creado exitosamente')));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'email-already-in-use'
                ? 'Este correo ya está registrado'
                : 'Error: ${e.message}',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Usuario'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              items:
                  _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedRole = value);
              },
              decoration: const InputDecoration(labelText: 'Rol'),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _startDate == null
                        ? 'Fechainicio no seleccionada'
                        : 'Inicio: ${DateFormat('dd/MM/yyyy').format(_startDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: () => _selectDate(context, true),
                  child: const Text('Seleccionar'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _endDate == null
                        ? 'Fecha final no encontrada'
                        : 'Fin: ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: () => _selectDate(context, false),
                  child: const Text('Seleccionar'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _createUser,
          child:
              _loading
                  ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Crear'),
        ),
      ],
    );
  }
}

// ----------------------------------------
// DIALOGO PARA EDITAR USUARIO
// ----------------------------------------
class EditUserDialog extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> currentData;

  const EditUserDialog({super.key, required this.userId, required this.currentData});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _deleteConfirmController;
  late String _selectedRole;
  bool _isActive = false;
  bool _loading = false;
  late Map<String, dynamic> _activeStatus;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;

  final List<String> _roles = ['admin', 'owner', 'collector'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentData['displayName'] ?? '');
    _emailController = TextEditingController(text: widget.currentData['email'] ?? '');
    _selectedRole = widget.currentData['role'] ?? 'admin';
    _isActive = widget.currentData['isActive'] ?? false;
    _deleteConfirmController = TextEditingController();
    _activeStatus =
        widget.currentData['activeStatus'] ??
        {'isActive': false, 'startDate': null, 'endDate': null};
    _tempStartDate = _activeStatus['startDate']?.toDate();
    _tempEndDate = _activeStatus['endDate']?.toDate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _deleteConfirmController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_tempStartDate != null && _tempEndDate != null && _tempStartDate!.isAfter(_tempEndDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha de inicio debe ser anterior a la fecha final')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'activeStatus': {
          'isActive': _activeStatus['isActive'],
          'startDate': _tempStartDate != null ? Timestamp.fromDate(_tempStartDate!) : null,
          'endDate': _tempEndDate != null ? Timestamp.fromDate(_tempEndDate!) : null,
        },
      });

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario actualizado correctamente')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _tempStartDate ?? DateTime.now() : _tempEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _tempStartDate = picked;
        } else {
          _tempEndDate = picked;
        }
      });
    }
  }

  Future<void> _deleteUser() async {
    if (_deleteConfirmController.text.trim() != 'Eliminar') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Confirmación incorrecta!')));
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).delete();

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario eliminado correctamente')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Usuario'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Nombre
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),

            // Rol
            DropdownButtonFormField<String>(
              value: _selectedRole,
              items:
                  _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedRole = value);
              },
              decoration: const InputDecoration(labelText: 'Rol'),
            ),
            const SizedBox(height: 16),
            // UID no editable con botón de copiar
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('UID: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: SelectableText(widget.currentData['uid'] ?? 'Desconocido')),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copiar UID',
                  onPressed: () {
                    final uid = widget.currentData['uid'] ?? '';
                    if (uid.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: uid));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('UID copiado al portapapeles')));
                    }
                  },
                ),
              ],
            ),
            // Switch activo
            Row(
              children: [
                const Text('Activo'),
                Switch(
                  value: _activeStatus['isActive'] ?? false,
                  onChanged:
                      (value) => setState(() {
                        _activeStatus['isActive'] = value;
                      }),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _tempStartDate == null
                        ? 'Fecha inicio no seleccionada'
                        : 'Inicio: ${DateFormat('dd/MM/yyyy').format(_tempStartDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: () => _selectDate(context, true),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _tempEndDate == null
                        ? 'Fecha final no seleccionada'
                        : 'Inicio: ${DateFormat('dd/MM/yyyy').format(_tempEndDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: () => _selectDate(context, false),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Confirmación para eliminar
            const Text('Si deseas eliminar este usuario, escribe "Eliminar" abajo:'),
            TextFormField(
              controller: _deleteConfirmController,
              decoration: const InputDecoration(labelText: 'Confirmar eliminación'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _saveChanges,
          child:
              _loading
                  ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Guardar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _deleteUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child:
              _loading
                  ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Eliminar Usuario'),
        ),
      ],
    );
  }
}
