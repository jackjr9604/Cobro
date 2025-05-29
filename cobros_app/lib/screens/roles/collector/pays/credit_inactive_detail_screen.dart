import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreditInactiveDetailScreen extends StatelessWidget {
  final DocumentSnapshot credit;

  const CreditInactiveDetailScreen({super.key, required this.credit});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: credit.reference.snapshots(),
      builder: (context, creditSnapshot) {
        if (!creditSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = creditSnapshot.data!.data() as Map<String, dynamic>;
        final clientId = data['clientId'];
        final creditValue = data['credit'] ?? 0;
        final interest = data['interest'] ?? 0;
        final cuot = data['cuot'] ?? 1;

        final total = creditValue + (creditValue * interest / 100);
        final cuota = total / cuot;
        final method = data['method'] ?? 'Diario';

        final pays =
            data.entries
                .where((e) => e.key.startsWith('pay'))
                .where(
                  (e) => e.value is Map<String, dynamic>,
                ) // Filtra solo los valores que son Map
                .map((e) => MapEntry(e.key, e.value as Map<String, dynamic>))
                .toList();

        pays.sort((a, b) => (a.value['date'] as Timestamp).compareTo(b.value['date'] as Timestamp));

        final paid = data['paid']?.toDate();
        final createdAt = data['createdAt']?.toDate();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('clients').doc(clientId).snapshots(),
          builder: (context, clientSnapshot) {
            if (!clientSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final client = clientSnapshot.data!.data() as Map<String, dynamic>;

            return Scaffold(
              appBar: AppBar(title: const Text('Detalle del Crédito')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📋 Datos del Cliente', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Nombre: ${client['clientName']}'),
                    Text('Celular: ${client['cellphone']}'),
                    if (client['ref'] != null) Text('Ref/Alias: ${client['ref']}'),
                    if (client['address'] != null) Text('Dirección: ${client['address']}'),
                    if (client['phone'] != null) Text('Teléfono: ${client['phone']}'),
                    if (client['address2'] != null) Text('Dirección 2: ${client['address2']}'),
                    if (client['city'] != null) Text('Ciudad: ${client['city']}'),
                    const Divider(height: 32),
                    Text('💰 Datos del Crédito', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Valor: \$${NumberFormat('#,##0', 'es_CO').format(creditValue)}'),
                    Text('Interés: ${interest.toStringAsFixed(2)}%'),
                    Text('Total a pagar: \$${NumberFormat('#,##0', 'es_CO').format(total)}'),
                    Text('Método: $method'),
                    Text('Cuotas: $cuot'),
                    Text('Valor de la cuota: \$${cuota.toStringAsFixed(0)}'),

                    const Divider(height: 32),
                    Text('📊 Resumen', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Fecha del credito: ${createdAt != null ? DateFormat('yyyy-MM-dd – kk:mm').format(createdAt) : 'N/A'}',
                    ),
                    Text(
                      'Cierre de credito: ${paid != null ? DateFormat('yyyy-MM-dd – kk:mm').format(paid) : 'N/A'}',
                    ),
                    Text('📆 Cuotas', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...pays.map((entry) {
                      final pago = entry.value;
                      final amount = (pago['amount'] ?? 0).toDouble();
                      final date = (pago['date'] as Timestamp).toDate();

                      return ListTile(
                        title: Text('Abono: \$${amount.toStringAsFixed(0)}'),
                        subtitle: Text('Fecha: ${DateFormat.yMd('es_CO').format(date)}'),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
