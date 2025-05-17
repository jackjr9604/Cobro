import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/credits_routes_screen.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  late Future<DocumentSnapshot<Map<String, dynamic>>> userDocFuture;

  @override
  void initState() {
    super.initState();
    userDocFuture = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Sin fecha';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<int> getCreditsCount(String uid) async {
    final query =
        await FirebaseFirestore.instance
            .collection('credits')
            .where('createdBy', isEqualTo: uid)
            .get();
    return query.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas activas')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: userDocFuture,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('Usuario no encontrado'));
          }

          final userData = userSnapshot.data!.data()!;
          final role = userData['role'];
          final officeId = userData['officeId'];

          if (role != 'owner') {
            return const Center(child: Text('Acceso denegado'));
          }

          final collectorsQuery = FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'collector')
              .where('officeId', isEqualTo: officeId)
              .where('isActive', isEqualTo: true);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collectorsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay cobradores activos'));
              }

              final collectors = snapshot.data!.docs;

              return ListView.builder(
                itemCount: collectors.length,
                itemBuilder: (context, index) {
                  final collectorDoc = collectors[index];
                  final collector = collectorDoc.data();
                  final collectorId = collectorDoc.id;

                  final name = collector['displayName'] ?? 'Sin nombre';
                  final email = collector['email'] ?? 'Sin correo';
                  final createdAt = formatTimestamp(collector['createdAt']);
                  final updatedAt = formatTimestamp(collector['updatedAt']);

                  return FutureBuilder<int>(
                    future: getCreditsCount(collectorId),
                    builder: (context, countSnapshot) {
                      final creditCount = countSnapshot.data ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CreditsRoutesScreen(
                                      collectorId: collectorId,
                                      collectorName: name,
                                    ),
                              ),
                            );
                          },
                          child: ListTile(
                            title: Text(name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Correo: $email'),
                                Text('Cobros asignados: $creditCount'),
                                Text('Creado: $createdAt'),
                                if (collector['updatedAt'] != null) Text('Actualizado: $updatedAt'),
                              ],
                            ),
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
      ),
    );
  }
}
