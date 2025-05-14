import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../clients/client_form_screen.dart';
import '../clients/edit_client.dart';
import '../credits/client_credits_screen.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  Future<Query<Map<String, dynamic>>> getClientsQuery(User user) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];
    final officeId = userDoc.data()?['officeId'];

    if (officeId == null) {
      throw Exception('No tienes asignado un officeId');
    }

    final clientsRef = FirebaseFirestore.instance.collection('clients');

    if (role == 'owner') {
      return clientsRef.where('officeId', isEqualTo: officeId);
    } else {
      return clientsRef.where('createdBy', isEqualTo: user.uid);
    }
  }

  Future<void> _deleteClient(BuildContext context, String clientId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];

    if (role != 'owner') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No tienes permisos para eliminar clientes')));
      return;
    }

    final confirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar este cliente?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmation == true) {
      await FirebaseFirestore.instance.collection('clients').doc(clientId).delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cliente eliminado con éxito')));
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Información copiada al portapapeles')));
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  Future<String> getUserDisplayName(String uid) async {
    if (uid.isEmpty) return '';
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data()?['displayName'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Center(child: Text('Usuario no autenticado'));

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: FutureBuilder(
        future: getClientsQuery(user),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final query = snapshot.data!;
          return StreamBuilder(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final clients = snapshot.data!.docs;
              if (clients.isEmpty) return const Center(child: Text('No hay clientes'));
              return ListView.builder(
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  final data = client.data();
                  final createdAt = formatTimestamp(data['createdAt']);
                  final updatedAt = formatTimestamp(data['updatedAt']);
                  final createdByUid = data['createdBy'] ?? '';
                  final currentUser = FirebaseAuth.instance.currentUser!;

                  return FutureBuilder(
                    future:
                        FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
                    builder: (context, snapshotUser) {
                      if (!snapshotUser.hasData) return const SizedBox.shrink();
                      final role = snapshotUser.data!.data()?['role'];

                      return FutureBuilder<String>(
                        future:
                            role == 'owner' && createdByUid.isNotEmpty
                                ? getUserDisplayName(createdByUid)
                                : Future.value(''),
                        builder: (context, snapshotName) {
                          final creatorName = snapshotName.data ?? '';
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              title: Text(data['clientName'] ?? 'Sin nombre'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (data['refAlias'] != null) Text('Alias: ${data['refAlias']}'),
                                  if (data['cellphone'] != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 16),
                                        Text(' ${data['cellphone']}'),
                                        IconButton(
                                          icon: const Icon(Icons.copy),
                                          onPressed:
                                              () => _copyToClipboard(context, data['cellphone']),
                                        ),
                                      ],
                                    ),
                                  if (data['address'] != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16),
                                        Text(' ${data['address']}'),
                                        IconButton(
                                          icon: const Icon(Icons.copy),
                                          onPressed:
                                              () => _copyToClipboard(context, data['address']),
                                        ),
                                      ],
                                    ),
                                  if (role == 'owner') ...[
                                    if (creatorName.isNotEmpty) Text('Creado por: $creatorName'),
                                    if (createdAt.isNotEmpty) Text('Fecha de creación: $createdAt'),
                                    if (updatedAt.isNotEmpty)
                                      Text('Última actualización: $updatedAt'),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.credit_card),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => ClientCreditsScreen(
                                                officeId: data['officeId'],
                                                clientId: client.id,
                                                clientName: data['clientName'] ?? 'sin nombre',
                                              ),
                                        ),
                                      );
                                    },
                                  ),

                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => EditClientScreen(
                                                clientData: data,
                                                clientId: client.id,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteClient(context, client.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
