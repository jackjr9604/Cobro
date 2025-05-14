import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../credits/credit_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientCreditsScreen extends StatelessWidget {
  final String clientId;
  final String clientName;
  final String officeId;

  const ClientCreditsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.officeId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Créditos de $clientName')),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection('credits')
                .where('clientId', isEqualTo: clientId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Este cliente no tiene créditos aún.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => CreateCreditScreen(clientId: clientId, officeId: officeId),
                        ),
                      );
                    },
                    child: const Text('Crear nuevo crédito'),
                  ),
                ],
              ),
            );
          }

          final credits = snapshot.data!.docs;

          return ListView.builder(
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final credit = credits[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Crédito: \$${NumberFormat('#,##0', 'es_CO').format(credit['credit'])}',
                      ),
                      subtitle: Text(
                        'Interés: ${NumberFormat('#,##0', 'es_CO').format(credit['interest'])}%\nCuota: ${credit['method']}\nFecha de creacion: ${credit['createdAt']?.toDate().toString().substring(0, 19)} \nEstado: ${credit['isActive'] ? 'Activo' : 'Inactivo'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteCredit(context, credit.id),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateCreditScreen(clientId: clientId, officeId: officeId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _deleteCredit(BuildContext context, String creditId) async {
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
    await FirebaseFirestore.instance.collection('credits').doc(creditId).delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cliente eliminado con éxito')));
  }
}
