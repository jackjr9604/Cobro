import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../clients/client_form_screen.dart';
import '../clients/edit_client.dart';
import '../credits/client_credits_screen.dart';
import '../../utils/office_verification_mixin.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sms/flutter_sms.dart';

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
  String? userId;
  String userRole = '';
  Map<String, dynamic>? userData;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadUserAndOfficeData();
  }

  Future<void> _loadUserAndOfficeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => userId = user.uid);

    try {
      // 1. Obtener datos del usuario logueado
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        setState(() {
          isLoading = false;
          hasOffice = false;
          isActive = false;
        });
        return;
      }

      userData = userDoc.data();
      userRole = userData?['role'] ?? '';

      // Para collectors, necesitamos verificar si están asignados a una oficina
      if (userRole == 'collector') {
        final ownerId = userData?['createdBy'];

        if (ownerId == null || ownerId.isEmpty) {
          setState(() {
            hasOffice = false;
            isActive = false;
          });
          return;
        }

        // Buscar en todas las oficinas del owner si este collector está asignado
        final officesQuery = FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .collection('offices');

        final officesSnapshot = await officesQuery.get();

        // Variable para almacenar si encontramos al collector en alguna oficina
        bool foundInOffice = false;
        String? foundOfficeId;
        bool isCollectorActive = false;

        // Verificar cada oficina
        for (final officeDoc in officesSnapshot.docs) {
          final collectorDoc =
              await officesQuery.doc(officeDoc.id).collection('collectors').doc(user.uid).get();

          if (collectorDoc.exists) {
            final collectorData = collectorDoc.data();
            if (collectorData != null && collectorData['activeStatus']?['isActive'] == true) {
              foundInOffice = true;
              foundOfficeId = officeDoc.id;
              isCollectorActive = true;
              break; // Salir del bucle si encontramos una oficina válida
            }
          }
        }

        setState(() {
          hasOffice = foundInOffice;
          officeId = foundOfficeId;
          isActive = isCollectorActive;
        });
      } else if (userRole == 'owner') {
        // Lógica existente para owner
        final isActiveStatus = userData?['activeStatus']?['isActive'] ?? false;
        final officeQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('offices')
                .limit(1)
                .get();

        setState(() {
          hasOffice = officeQuery.docs.isNotEmpty;
          officeId = officeQuery.docs.isNotEmpty ? officeQuery.docs.first.id : null;
          isActive = isActiveStatus;
        });
      }
    } catch (e) {
      debugPrint('Error loading office data: $e');
      setState(() {
        hasOffice = false;
        isActive = false;
      });
    } finally {
      setState(() => isLoading = false);
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
              userRole == 'collector'
                  ? 'No estás asignado a una oficina'
                  : 'Oficina no configurada',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              userRole == 'collector'
                  ? 'No tienes una oficina asignada actualmente. Contacta al administrador.'
                  : 'No tienes una oficina configurada o no está activa.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            if (userRole == 'owner') // Solo mostrar botón para owners
              ElevatedButton(
                onPressed: () {
                  // Navegar a la pantalla de configuración de oficina
                },
                child: const Text('Configurar Oficina'),
              ),
          ],
        ),
      ),
    );
  }

  Future<Query<Map<String, dynamic>>> getClientsQuery(User user) async {
    try {
      if (officeId == null) {
        throw Exception('Office ID is null');
      }

      if (userData == null) {
        throw Exception('User data not loaded');
      }

      final role = userData!['role'];
      final ownerId = userData!['createdBy'];

      if (role == 'owner') {
        return FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('offices')
            .doc(officeId)
            .collection('clients')
            .orderBy('clientName');
      } else if (role == 'collector') {
        if (ownerId == null || ownerId.isEmpty) {
          throw Exception('Collector has no owner assigned');
        }

        return FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId) // Usamos el ID del owner, no del collector
            .collection('offices')
            .doc(officeId)
            .collection('clients')
            .where('createdBy', isEqualTo: user.uid)
            .orderBy('clientName');
      } else {
        throw Exception('Invalid user role: $role');
      }
    } catch (e) {
      debugPrint('Error in getClientsQuery: $e');
      rethrow;
    }
  }

  Future<void> _deleteClient(BuildContext context, String clientId) async {
    if (officeId == null || userId == null) return;

    final role = userData?['role'];
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
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmation == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('offices')
            .doc(officeId)
            .collection('clients')
            .doc(clientId)
            .delete();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cliente eliminado con éxito')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar cliente: $e')));
      }
    }
  }

  // Método para construir filas de información con botones de acción
  // Método para construir filas de información con botones de acción
  Widget _buildInfoRow(
    IconData icon,
    String? text,
    BuildContext context, {
    bool isPhone = false, // Parámetro opcional con valor por defecto
  }) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final phoneNumber = isPhone ? text.replaceAll(RegExp(r'[^0-9+]'), '') : '';
    final showPhoneActions = isPhone && phoneNumber.length >= 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[800]))),
          if (showPhoneActions) ...[
            IconButton(
              icon: Icon(Icons.phone, size: 18, color: Colors.green),
              onPressed: () => _makePhoneCall(phoneNumber),
              tooltip: 'Llamar',
            ),
            IconButton(
              icon: Icon(Icons.message, size: 18, color: Colors.green),
              onPressed: () => _openWhatsApp(phoneNumber),
              tooltip: 'WhatsApp',
            ),
          ],
          IconButton(
            icon: Icon(Icons.copy, size: 18, color: Theme.of(context).primaryColor),
            onPressed: () => _copyToClipboard(context, text),
            tooltip: 'Copiar',
          ),
        ],
      ),
    );
  }

  // Método para realizar llamadas telefónicas
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo realizar la llamada a $phoneNumber')));
      }
    }
  }

  // Método para abrir WhatsApp
  Future<void> _openWhatsApp(String phoneNumber) async {
    // Eliminar el signo + si existe (WhatsApp lo necesita sin +)
    final cleanNumber = phoneNumber.startsWith('+') ? phoneNumber.substring(1) : phoneNumber;
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir WhatsApp con el número $phoneNumber')),
        );
      }
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
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                padding: const EdgeInsets.only(bottom: 80),
                physics: const AlwaysScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  final data = client.data();
                  return _ClientCard(
                    clientData: data,
                    clientId: client.id,
                    officeId: officeId!,
                    userId: user.uid,
                    userRole: userRole,
                    isExpanded: _expandedIndex == index,
                    onTap: () {
                      setState(() {
                        _expandedIndex = _expandedIndex == index ? null : index;
                      });
                    },
                    buildInfoRow: _buildInfoRow,
                    makePhoneCall: _makePhoneCall,
                    openWhatsApp: _openWhatsApp,
                    getUserDisplayName: getUserDisplayName,
                    formatTimestamp: formatTimestamp,
                    getLatestCreditInfo: getLatestCreditInfo,
                    copyToClipboard: _copyToClipboard,
                    deleteClient: _deleteClient,
                  );
                },
              );
            },
          );
        },
      ),

      floatingActionButton:
          (userData?['role'] == 'collector' || (userData?['role'] == 'owner' && isActive))
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ClientFormScreen(officeId: officeId!)),
                  );
                },
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> clientData;
  final String clientId;
  final String officeId;
  final String userId;
  final String userRole;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget Function(IconData, String?, BuildContext, {bool isPhone}) buildInfoRow;
  final Future<void> Function(String) makePhoneCall;
  final Future<void> Function(String) openWhatsApp;
  final Future<String> Function(String) getUserDisplayName;
  final String Function(Timestamp?) formatTimestamp;
  final Map<String, dynamic>? Function(Map<String, dynamic>) getLatestCreditInfo;
  final Future<void> Function(BuildContext, String) copyToClipboard;
  final Future<void> Function(BuildContext, String) deleteClient;

  const _ClientCard({
    required this.clientData,
    required this.clientId,
    required this.officeId,
    required this.userId,
    required this.userRole,
    required this.isExpanded,
    required this.onTap,
    required this.buildInfoRow,
    required this.makePhoneCall,
    required this.openWhatsApp,
    required this.getUserDisplayName,
    required this.formatTimestamp,
    required this.getLatestCreditInfo,
    required this.copyToClipboard,
    required this.deleteClient,
  });

  List<Widget> _buildCreditInfo(Map<String, dynamic> credit, BuildContext context) {
    return [
      buildInfoRow(Icons.credit_card, 'Crédito #${credit['credit#']}', context),
      buildInfoRow(Icons.attach_money, 'Valor: ${credit['credit']}', context),
      if (credit['createdAt'] is Timestamp)
        buildInfoRow(Icons.date_range, 'Fecha: ${formatTimestamp(credit['createdAt'])}', context),
    ];
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con información básica
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      clientData['clientName'] ?? 'Sin nombre',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (clientData['refAlias'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(clientData['refAlias'], style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Información básica siempre visible
              buildInfoRow(Icons.phone, clientData['cellphone'], context, isPhone: true),
              buildInfoRow(Icons.location_on, clientData['address'], context),

              // Sección expandible
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Información adicional
                    if (clientData['phone'] != null && clientData['phone'].isNotEmpty)
                      buildInfoRow(
                        Icons.phone,
                        'Teléfono fijo: ${clientData['phone']}',
                        context,
                        isPhone: true,
                      ),

                    if (clientData['address2'] != null && clientData['address2'].isNotEmpty)
                      buildInfoRow(
                        Icons.location_city,
                        'Dirección 2: ${clientData['address2']}',
                        context,
                      ),

                    if (clientData['city'] != null && clientData['city'].isNotEmpty)
                      buildInfoRow(Icons.map, 'Ciudad: ${clientData['city']}', context),

                    // Información para owners
                    if (userRole == 'owner') ...[
                      const SizedBox(height: 8),
                      if (clientData['createdBy'] != null)
                        FutureBuilder<String>(
                          future: getUserDisplayName(clientData['createdBy']),
                          builder: (context, snapshot) {
                            return buildInfoRow(
                              Icons.person_outline,
                              'Creado por: ${snapshot.data ?? 'Desconocido'}',
                              context,
                            );
                          },
                        ),

                      if (clientData['createdAt'] != null)
                        buildInfoRow(
                          Icons.calendar_today,
                          'Creado: ${formatTimestamp(clientData['createdAt'])}',
                          context,
                        ),

                      if (clientData['updatedAt'] != null)
                        buildInfoRow(
                          Icons.update,
                          'Actualizado: ${formatTimestamp(clientData['updatedAt'])}',
                          context,
                        ),
                    ],

                    // Información de crédito (si existe)
                    if (getLatestCreditInfo(clientData) != null) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('Último crédito', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._buildCreditInfo(getLatestCreditInfo(clientData)!, context),
                    ],
                  ],
                ),
              ),

              // Botones de acción (siempre visibles)
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(context, Icons.credit_card, Colors.blue, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ClientCreditsScreen(
                              clientId: clientId,
                              clientName: clientData['clientName'] ?? 'sin nombre',
                              officeId: officeId,
                              userId: userId,
                            ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  _buildActionButton(context, Icons.edit, Colors.orange, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => EditClientScreen(
                              clientData: clientData,
                              clientId: clientId,
                              officeId: officeId,
                            ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  if (userRole == 'owner')
                    _buildActionButton(
                      context,
                      Icons.delete,
                      Colors.red,
                      () => deleteClient(context, clientId),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
