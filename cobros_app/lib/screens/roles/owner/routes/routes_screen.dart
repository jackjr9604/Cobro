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
  //variables de estado:
  bool isLoading = true;
  bool hasOffice = false;
  bool isActive = false;
  String? officeId;
  String? userId;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadUserAndOfficeData();
  }

  Future<void> _loadUserAndOfficeData() async {
    if (currentUser == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // 1. Cargar datos del usuario
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();

      if (!userDoc.exists) {
        setState(() {
          isLoading = false;
          hasOffice = false;
          isActive = false;
        });
        return;
      }

      userData = userDoc.data();
      final userRole = userData?['role'] ?? '';
      final activeStatus = userData?['activeStatus'] as Map<String, dynamic>?;
      final userIsActive = activeStatus?['isActive'] ?? false;

      // 2. Buscar oficina según el rol
      if (userRole == 'owner') {
        final officeQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .collection('offices')
                .limit(1)
                .get();

        setState(() {
          hasOffice = officeQuery.docs.isNotEmpty;
          officeId = hasOffice ? officeQuery.docs.first.id : null;
          isActive = userIsActive;
        });
      } else if (userRole == 'collector') {
        // Para collectors, verificamos si tienen officeId asignado
        final collectorOfficeId = userData?['officeId'];
        setState(() {
          hasOffice = collectorOfficeId != null;
          officeId = collectorOfficeId;
          isActive = userIsActive;
        });
      } else {
        setState(() {
          hasOffice = false;
          isActive = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        hasOffice = false;
        isActive = false;
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<int> getCreditsCount(String collectorId) async {
    if (officeId == null || currentUser == null) return 0;

    try {
      // Nueva consulta que busca en la estructura correcta
      final query =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .collection('offices')
              .doc(officeId)
              .collection('clients')
              .where('createdBy', isEqualTo: collectorId)
              .get();

      // Para cada cliente, contar sus créditos activos
      int totalActiveCredits = 0;

      for (final clientDoc in query.docs) {
        final creditsQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .collection('offices')
                .doc(officeId)
                .collection('clients')
                .doc(clientDoc.id)
                .collection('credits')
                .where('isActive', isEqualTo: true)
                .get();

        totalActiveCredits += creditsQuery.size;
      }

      return totalActiveCredits;
    } catch (e) {
      debugPrint('Error counting credits: $e');
      return 0;
    }
  }

  Widget _buildInactiveAccountScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              hasOffice ? 'Cuenta no activa' : 'Oficina no configurada',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              hasOffice
                  ? 'Tu cuenta no está activa actualmente. Contacta al administrador.'
                  : 'No tienes una oficina asignada o configurada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  //Implementación de _loadOfficeData:

  @override
  Widget build(BuildContext context) {
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .collection('offices')
                .doc(officeId)
                .collection('collectors')
                .where('activeStatus.isActive', isEqualTo: true)
                .snapshots(),
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

                    final name = collector['name'] ?? 'Sin nombre';
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              // 1. Verificar que currentUser no sea nulo
                              final currentUser = FirebaseAuth.instance.currentUser;
                              if (currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Usuario no autenticado')),
                                );
                                return;
                              }

                              // 2. Verificar que officeId no sea nulo
                              if (officeId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No se ha configurado la oficina')),
                                );
                                return;
                              }

                              // 3. Asegurarse que collectorName está definido
                              // (asumiendo que viene de algún lugar en tu código)
                              final collectorName =
                                  collector['name'] ?? 'Cobrador'; // Ajusta según tu estructura

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => CreditsRoutesScreen(
                                        collectorId:
                                            collectorId, // Asegúrate que collectorId está definido
                                        collectorName: collectorName,
                                        userId: currentUser.uid,
                                        officeId:
                                            officeId!, // Usamos ! porque ya verificamos que no es nulo
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
                                          color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                                            const Icon(Icons.update, size: 16, color: Colors.grey),
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
      ),
    );
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Sin fecha';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
