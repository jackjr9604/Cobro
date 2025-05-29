import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes/pays_details.dart';
import '../routes/Collector_Settlement_Screen.dart';

class CreditsRoutesScreen extends StatelessWidget {
  final String collectorId;
  final String collectorName;

  const CreditsRoutesScreen({super.key, required this.collectorId, required this.collectorName});

  Future<Map<String, dynamic>> fetchClientName(String clientId) async {
    final doc = await FirebaseFirestore.instance.collection('clients').doc(clientId).get();
    return doc.data() ?? {};
  }

  int countPayments(Map<String, dynamic> data) {
    return data.keys.where((k) => k.startsWith('pay')).length;
  }

  double sumPayments(Map<String, dynamic> data) {
    return data.entries
        .where((e) => e.key.startsWith('pay'))
        .where((e) => e.value is Map<String, dynamic>) // Filtra solo los valores que son Map
        .map((e) => (e.value['amount'] ?? 0).toDouble())
        .fold(0.0, (prev, el) => prev + el);
  }

  @override
  Widget build(BuildContext context) {
    final creditsQuery = FirebaseFirestore.instance
        .collection('credits')
        .where('createdBy', isEqualTo: collectorId)
        .where('isActive', isEqualTo: true);

    return Scaffold(
      appBar: AppBar(title: Text('Cobros de $collectorName')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: creditsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay cobros activos'));
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

              return FutureBuilder<Map<String, dynamic>>(
                future: fetchClientName(clientId),
                builder: (context, clientSnapshot) {
                  final clientName = clientSnapshot.data?['clientName'] ?? 'Cliente desconocido';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        title: Text(
                          'Cliente: $clientName',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Préstamo: \$${credit.toStringAsFixed(2)}'),
                            Text('Interés: ${interest.toStringAsFixed(2)}%'),
                            Text('Total crédito: \$${totalCredit.toStringAsFixed(2)}'),
                            Text('Forma de pago: $method'),
                            Text('Cuotas: $cout'),
                            Text('Valor de cuota: \$${paymentValue.toStringAsFixed(2)}'),
                            const SizedBox(height: 4),
                            Text('Abonos realizados: $paymentsCount'),
                            Text('Total abonado: \$${totalPaid.toStringAsFixed(2)}'),
                            Text('faltante: \$${restPay.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.article),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PaysDetails(credit: creditDoc),
                                  ),
                                );
                              },
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CollectorLiquidationScreen(
                    collectorId: collectorId,
                    collectorName: collectorName,
                  ),
            ),
          );
        },
        icon: const Icon(Icons.monetization_on),
        label: const Text('Liquidar'),
      ),
    );
  }
}
