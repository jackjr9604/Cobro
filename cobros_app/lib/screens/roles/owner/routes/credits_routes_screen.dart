import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes/pays_details.dart';
import 'Liquidation_Screen.dart';

class CreditsRoutesScreen extends StatelessWidget {
  const CreditsRoutesScreen({
    super.key,
    required this.collectorId,
    required this.collectorName,
    required this.officeId, // Nuevo parámetro requerido
  });

  final String collectorId;
  final String collectorName;
  final String officeId;

  Future<Map<String, dynamic>> fetchClientName(String clientId) async {
    final doc = await FirebaseFirestore.instance.collection('clients').doc(clientId).get();
    return doc.data() ?? {};
  }

  int countPayments(Map<String, dynamic> data) {
    // Ahora solo cuenta las llaves que empiezan con "pay"
    // Y cuyo valor es un mapa (un pago real)
    return data.entries
        .where((e) => e.key.startsWith('pay') && e.value is Map<String, dynamic>)
        .length;
  }

  double sumPayments(Map<String, dynamic> data) {
    return data.entries
        .where((e) => e.key.startsWith('pay'))
        .where((e) => e.value is Map<String, dynamic>) // Filtra solo los valores que son Map
        .map((e) => (e.value['amount'] ?? 0).toDouble())
        .fold(0.0, (prev, el) => prev + el);
  }

  Color _getMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'diario':
        return Colors.blue;
      case 'semanal':
        return Colors.green;
      case 'quincenal':
        return Colors.orange;
      case 'mensual':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'diario':
        return Icons.calendar_view_day;
      case 'semanal':
        return Icons.calendar_view_week;
      case 'quincenal':
        return Icons.event_available;
      case 'mensual':
        return Icons.calendar_today;
      default:
        return Icons.payment;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creditsQuery = FirebaseFirestore.instance
        .collection('credits')
        .where('createdBy', isEqualTo: collectorId)
        .where('isActive', isEqualTo: true);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cobros de $collectorName'),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: creditsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay créditos activos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Este cobrador no tiene créditos activos actualmente',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final credits = snapshot.data!.docs;

          return ListView.builder(
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final creditDoc = credits[index];
              final data = creditDoc.data();
              final clientId = data['clientId'] ?? '';
              final credit = (data['credit'] ?? 0).toDouble();
              final interest = (data['interest'] ?? 0).toDouble();
              final method = data['method'] ?? 'Sin método';
              final cout = (data['cuot'] ?? 0).toInt();
              final totalCredit = ((credit * interest) / 100) + credit;
              final paymentValue = totalCredit / cout;
              final paymentsCount = countPayments(data);
              final totalPaid = sumPayments(data);
              final restPay = (totalCredit - totalPaid);

              final methodColor = _getMethodColor(method);
              final methodIcon = _getMethodIcon(method);

              return FutureBuilder<Map<String, dynamic>>(
                future: fetchClientName(clientId),
                builder: (context, clientSnapshot) {
                  final clientName = clientSnapshot.data?['clientName'] ?? 'Cliente desconocido';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PaysDetails(credit: creditDoc)),
                        );
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
                                    clientName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    '${paymentsCount}/$cout',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor:
                                      paymentsCount == cout
                                          ? Colors.green
                                          : Theme.of(context).primaryColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Barra de progreso

                            // Información resumida
                            Row(
                              children: [
                                Icon(methodIcon, size: 18, color: methodColor),
                                const SizedBox(width: 8),
                                Text(
                                  method,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: methodColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            LinearProgressIndicator(
                              value: paymentsCount / cout,
                              backgroundColor: Colors.grey[200],
                              color:
                                  paymentsCount == cout
                                      ? Colors.green
                                      : Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow('Total', '\$${totalCredit.toStringAsFixed(2)}'),
                                    _buildInfoRow('Abonado', '\$${totalPaid.toStringAsFixed(2)}'),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildInfoRow('Faltante', '\$${restPay.toStringAsFixed(2)}'),
                                    _buildInfoRow('Cuota', '\$${paymentValue.toStringAsFixed(2)}'),
                                  ],
                                ),
                              ],
                            ),

                            // Botones de acción
                            const SizedBox(height: 12),
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
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'settlement',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CollectorLiquidationScreen(
                        collectorId: collectorId,
                        collectorName: collectorName,
                        officeId: officeId,
                      ),
                ),
              );
            },
            icon: const Icon(Icons.monetization_on),
            label: const Text('Liquidar'),
          ),
        ],
      ),
    );
  }
}
