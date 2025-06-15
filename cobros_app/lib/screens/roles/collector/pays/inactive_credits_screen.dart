import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'credit_inactive_detail_screen.dart';

class InactiveCreditsScreen extends StatefulWidget {
  final String userId;
  final String officeId;
  final String? collectorId; // Nuevo parámetro opcional

  const InactiveCreditsScreen({
    super.key,
    required this.userId,
    required this.officeId,
    this.collectorId,
  });

  @override
  State<InactiveCreditsScreen> createState() => _InactiveCreditsScreenState();
}

class _InactiveCreditsScreenState extends State<InactiveCreditsScreen> {
  final Map<String, int> orderMap = {};
  final Map<String, TextEditingController> controllers = {};

  @override
  void dispose() {
    controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos Cerrados'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {}))],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('offices')
                .doc(widget.officeId)
                .collection('clients')
                .where('createdBy', isEqualTo: widget.collectorId)
                .snapshots(),
        builder: (context, clientsSnapshot) {
          if (clientsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!clientsSnapshot.hasData || clientsSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes clientes asignados'));
          }

          final clientDocs = clientsSnapshot.data!.docs;

          return ListView.builder(
            itemCount: clientDocs.length,
            itemBuilder: (context, clientIndex) {
              final clientDoc = clientDocs[clientIndex];
              final clientId = clientDoc.id;
              final clientData = clientDoc.data() as Map<String, dynamic>;
              final clientName = clientData['clientName'] ?? 'Sin nombre';

              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.userId)
                        .collection('offices')
                        .doc(widget.officeId)
                        .collection('clients')
                        .doc(clientId)
                        .collection('credits')
                        .where('isActive', isEqualTo: false)
                        .snapshots(),
                builder: (context, creditsSnapshot) {
                  if (!creditsSnapshot.hasData || creditsSnapshot.data!.docs.isEmpty) {
                    return Container(); // No mostrar clientes sin créditos inactivos
                  }

                  final credits = creditsSnapshot.data!.docs;

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ExpansionTile(
                      title: Text(clientName),
                      subtitle: Text('${credits.length} crédito(s) cerrado(s)'),
                      children:
                          credits.map((creditDoc) {
                            final creditData = creditDoc.data() as Map<String, dynamic>;
                            final creditId = creditDoc.id;
                            final creditAmount = (creditData['credit'] ?? 0).toDouble();
                            final interest = (creditData['interest'] ?? 0).toDouble();
                            final total = creditAmount + (creditAmount * interest / 100);
                            final closedAt = creditData['closedAt']?.toDate();

                            return ListTile(
                              title: Text('Crédito: \$${NumberFormat('#,##0').format(total)}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Capital: \$${NumberFormat('#,##0').format(creditAmount)}'),
                                  Text('Interés: ${interest.toStringAsFixed(2)}%'),
                                  if (closedAt != null)
                                    Text('Cerrado: ${DateFormat('dd/MM/yyyy').format(closedAt)}'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => CreditInactiveDetailScreen(
                                            userId: widget.userId,
                                            officeId: widget.officeId,
                                            clientId: clientId,
                                            creditId: creditId,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                    ),
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
