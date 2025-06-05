import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../clients/client_form_screen.dart';
import '../clients/edit_client.dart';
import '../credits/client_credits_screen.dart';
import '../../utils/office_verification_mixin.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> with OfficeVerificationMixin {
  bool isLoading = true;
  bool hasOffice = false;
  bool isActive = false;
  String? officeId;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadOfficeData();
  }

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

  Future<Query<Map<String, dynamic>>> getClientsQuery(User user) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];
    final officeId = userDoc.data()?['officeId'];
    final activeStatus = userDoc.data()?['activeStatus'] as Map<String, dynamic>?;
    final isActive = activeStatus?['isActive'] ?? false;

    if (role == 'owner' && !isActive) {
      throw Exception('owner_inactive');
    }

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
          content: const Text(
            '¿Estás seguro de que deseas eliminar este crédito? Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              style: TextButton.styleFrom(backgroundColor: Colors.red[50]),
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

  Map<String, dynamic>? getLatestCreditInfo(Map<String, dynamic> data) {
    int maxCreditNumber = -1;
    Map<String, dynamic>? latestCredit;

    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic> && value.containsKey('credit#')) {
        final creditNum = value['credit#'];
        if (creditNum is int && creditNum > maxCreditNumber) {
          maxCreditNumber = creditNum;
          latestCredit = value;
        }
      }
    }

    return latestCredit;
  }

  Widget _buildInfoRow(IconData icon, String? text, BuildContext context) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[800]))),
          IconButton(
            icon: Icon(Icons.copy, size: 18, color: Theme.of(context).primaryColor),
            onPressed: () => _copyToClipboard(context, text),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: color), onPressed: onPressed, splashRadius: 20),
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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasOffice || !isActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de Clientes')),
        body: _buildInactiveAccountScreen(),
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Center(child: Text('Usuario no autenticado'));

    return Scaffold(
      appBar: AppBar(title: Text('Gestión de Clientes')),
      body: FutureBuilder(
        future: getClientsQuery(user),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('owner_inactive')) {
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final query = snapshot.data!;
          return StreamBuilder(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final clients = snapshot.data!.docs;
              if (clients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay clientes registrados',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Presiona el botón + para agregar uno',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.only(bottom: 80),
                physics: const AlwaysScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  final data = client.data();
                  final createdAt = formatTimestamp(data['createdAt']);
                  final updatedAt = formatTimestamp(data['updatedAt']);
                  final createdByUid = data['createdBy'] ?? '';
                  final currentUser = FirebaseAuth.instance.currentUser!;
                  final latestCredit = getLatestCreditInfo(data);

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
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                // Navegar al detalle del cliente si lo deseas
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['clientName'] ?? 'Sin nombre',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (data['refAlias'] != null)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              data['refAlias'],
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Información de contacto
                                    _buildInfoRow(Icons.phone, data['cellphone'], context),
                                    _buildInfoRow(Icons.location_on, data['address'], context),

                                    // Información adicional para owners
                                    if (role == 'owner') ...[
                                      const SizedBox(height: 8),
                                      if (creatorName.isNotEmpty)
                                        _buildInfoRow(
                                          Icons.person_outline,
                                          'Creado por: $creatorName',
                                          context,
                                        ),
                                      if (createdAt.isNotEmpty)
                                        _buildInfoRow(
                                          Icons.calendar_today,
                                          'Creado: $createdAt',
                                          context,
                                        ),
                                      if (updatedAt.isNotEmpty)
                                        _buildInfoRow(
                                          Icons.update,
                                          'Actualizado: $updatedAt',
                                          context,
                                        ),
                                    ],

                                    // Información de crédito
                                    if (latestCredit != null) ...[
                                      const SizedBox(height: 12),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Último crédito',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      _buildInfoRow(
                                        Icons.credit_card,
                                        'Crédito #${latestCredit['credit#']}',
                                        context,
                                      ),
                                      _buildInfoRow(
                                        Icons.attach_money,
                                        'Valor: ${latestCredit['credit']}',
                                        context,
                                      ),
                                      if (latestCredit['createdAt'] is Timestamp)
                                        _buildInfoRow(
                                          Icons.date_range,
                                          'Fecha: ${formatTimestamp(latestCredit['createdAt'])}',
                                          context,
                                        ),
                                    ],

                                    // Botones de acción
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _buildActionButton(
                                          context,
                                          Icons.credit_card,
                                          Colors.blue,
                                          () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => ClientCreditsScreen(
                                                      officeId: data['officeId'],
                                                      clientId: client.id,
                                                      clientName:
                                                          data['clientName'] ?? 'sin nombre',
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _buildActionButton(context, Icons.edit, Colors.orange, () {
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
                                        }),
                                        const SizedBox(width: 8),
                                        _buildActionButton(
                                          context,
                                          Icons.delete,
                                          Colors.red,
                                          () => _deleteClient(context, client.id),
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
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final role = snapshot.data!.data()?['role'];
          final activeStatus = snapshot.data!.data()?['activeStatus'] as Map<String, dynamic>?;
          final isActive = activeStatus?['isActive'] ?? false;

          // Solo mostrar FAB si es collector o owner activo
          if (role == 'collector' || (role == 'owner' && isActive)) {
            return FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientFormScreen()),
                );
              },
              child: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
