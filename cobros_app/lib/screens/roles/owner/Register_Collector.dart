import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final data = userDoc.data();

    if (data != null &&
        data['role'] == 'owner' &&
        data['isActive'] == true &&
        data.containsKey('officeId')) {
      setState(() {
        ownerOfficeId = data['officeId'];
        isOwnerActive = true;
      });
      await loadCollectors();
    }

    setState(() => isLoading = false);
  }

  Future<void> loadCollectors() async {
    final query =
        await _firestore
            .collection('users')
            .where('role', isEqualTo: 'collector')
            .where('officeId', isEqualTo: ownerOfficeId)
            .get();

    setState(() {
      collectors =
          query.docs.map((doc) {
            var data = doc.data();
            data['uid'] = doc.id;
            return data;
          }).toList();
    });
  }

  Future<void> registerCollector() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final ownerCredential = _auth.currentUser!;
      final authResult = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final collectorUID = authResult.user!.uid;

      await _firestore.collection('users').doc(collectorUID).set({
        'displayName': name,
        'email': email,
        'role': 'collector',
        'officeId': ownerOfficeId,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'UID': collectorUID,
      });

      await _auth.signInWithEmailAndPassword(
        email: ownerCredential.email!,
        password: await _getOwnerPasswordDialog(context),
      );

      setState(() {
        showForm = false;
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
      });

      await loadCollectors();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collector registrado correctamente.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al registrar: $e')));
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
                  child: const Text('Confirmar'),
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
    bool newStatus,
  ) async {
    await _firestore.collection('users').doc(collector['uid']).update({
      'displayName': newName,
      'isActive': newStatus,
      'updateAt': FieldValue.serverTimestamp(),
    });
    await loadCollectors();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Actualizado correctamente.')));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (!isOwnerActive || ownerOfficeId == null) {
      return const Center(
        child: Text('No tienes permisos para ver esta información.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobradores'),
        actions: [
          if (isOwnerActive && ownerOfficeId != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => showForm = !showForm),
            ),
        ],
      ),
      body: Column(
        children: [
          if (showForm)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Ingrese un nombre'
                                  : null,
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Ingrese un correo válido'
                                  : null,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator:
                          (value) =>
                              value == null || value.length < 6
                                  ? 'Mínimo 6 caracteres'
                                  : null,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: registerCollector,
                      child: const Text('Registrar Collector'),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          Expanded(
            child:
                collectors.isEmpty
                    ? const Center(
                      child: Text('No hay cobradores registrados.'),
                    )
                    : ListView.builder(
                      itemCount: collectors.length,
                      itemBuilder: (context, index) {
                        final collector = collectors[index];
                        final uid = collector['uid'];
                        final expanded = expandedCards[uid] ?? false;
                        final nameController = TextEditingController(
                          text: collector['displayName'],
                        );

                        return Card(
                          child: Column(
                            children: [
                              ListTile(
                                title: Text(
                                  collector['displayName'] ?? 'Sin nombre',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(collector['email'] ?? ''),
                                    Text(
                                      'Creado: ${collector['createdAt']?.toDate().toString().substring(0, 19) ?? 'N/D'}',
                                    ),
                                    if (collector['updateAt'] != null)
                                      Text(
                                        'Actualizado: ${collector['updateAt']?.toDate().toString().substring(0, 19)}',
                                      ),
                                  ],
                                ),
                                trailing: Icon(
                                  collector['isActive'] == true
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color:
                                      collector['isActive'] == true
                                          ? Colors.green
                                          : Colors.red,
                                ),
                                onTap:
                                    () => setState(() {
                                      expandedCards[uid] = !expanded;
                                    }),
                              ),
                              if (expanded)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: nameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Editar nombre',
                                        ),
                                      ),
                                      SwitchListTile(
                                        title: const Text('Activo'),
                                        value: collector['isActive'] ?? true,
                                        onChanged: (value) {
                                          setState(() {
                                            collector['isActive'] = value;
                                          });
                                        },
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await _updateCollector(
                                            collector,
                                            nameController.text.trim(),
                                            collector['isActive'] ?? true,
                                          );
                                        },
                                        child: const Text('Guardar'),
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
