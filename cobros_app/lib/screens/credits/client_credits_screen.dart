import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'create_credit_screen.dart';
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
      appBar: AppBar(
        title: Text('Créditos de $clientName'),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection('credits')
                .where('clientId', isEqualTo: clientId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Cargando créditos...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          Widget _buildCreditInfoRow(String label, String value, IconData icon) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          value,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No hay créditos registrados',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Puedes crear un nuevo crédito para este cliente',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CreateCreditScreen(clientId: clientId, officeId: officeId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Crear nuevo crédito'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final credits = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.only(bottom: 80),
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final credit = credits[index];
              final isActive = credit['isActive'] ?? false;
              final createdAt = credit['createdAt']?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Navegar al detalle del crédito si es necesario
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Crédito #${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green[50] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive ? Colors.green : Colors.grey,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isActive ? 'ACTIVO' : 'INACTIVO',
                                style: TextStyle(
                                  color: isActive ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildCreditInfoRow(
                          'Valor del crédito:',
                          '\$${NumberFormat('#,##0', 'es_CO').format(credit['credit'])}',
                          Icons.attach_money,
                        ),
                        _buildCreditInfoRow(
                          'Tasa de interés:',
                          '${NumberFormat('#,##0', 'es_CO').format(credit['interest'])}%',
                          Icons.percent,
                        ),
                        _buildCreditInfoRow(
                          'Método de pago:',
                          credit['method']?.toString().toUpperCase() ?? 'N/D',
                          Icons.payment,
                        ),
                        if (createdAt != null) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd/MM/yyyy - HH:mm').format(createdAt),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCredit(context, credit.id),
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
    await FirebaseFirestore.instance.collection('credits').doc(creditId).delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cliente eliminado con éxito')));
  }
}
