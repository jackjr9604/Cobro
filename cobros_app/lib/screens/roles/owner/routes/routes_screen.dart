import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/credits_routes_screen.dart';
import '../../../../utils/office_verification_mixin.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> with OfficeVerificationMixin {
  //mixin de comprobacion cuenta activa y si es de oficina
  final currentUser = FirebaseAuth.instance.currentUser;
  late Future<DocumentSnapshot<Map<String, dynamic>>> userDocFuture;
  //Adición de variables de estado:
  bool isLoading = true;
  bool hasOffice = false;
  bool isActive = false;
  String? officeId;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadOfficeData();
    userDocFuture = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
  }

  //Implementación de _loadOfficeData:
  Future<void> _loadOfficeData() async {
    final verification = await verifyOfficeAndStatus();
    setState(() {
      hasOffice = verification['hasOffice'];
      isActive = verification['isActive'];
      officeId = verification['officeId'];
      userData = verification['userData'];
      isLoading = false;
    });
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
    //Verificación inicial del estado de carga y activación
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasOffice || !isActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rutas activas')),
        body: _buildInactiveAccountScreen(),
      );
    }
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

          final collectorsQuery = FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'collector')
              .where('officeId', isEqualTo: officeId)
              .where('activeStatus.isActive', isEqualTo: true);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collectorsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Cargando cobradores...', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay cobradores activos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No se encontraron cobradores activos en tu oficina',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final collectors = snapshot.data!.docs;

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
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
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
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
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.1),
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                color: Theme.of(context).primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  email,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$creditCount créditos',
                                              style: TextStyle(
                                                color: Theme.of(context).primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Creado: $createdAt',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                          if (collector['updatedAt'] != null)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.update,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Actualizado: $updatedAt',
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Agregar al final del ListView.builder
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Total cobradores activos: ${collectors.length}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
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
