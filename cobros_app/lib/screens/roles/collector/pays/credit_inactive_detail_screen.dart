import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreditInactiveDetailScreen extends StatelessWidget {
  final String userId;
  final String officeId;
  final String clientId;
  final String creditId;

  const CreditInactiveDetailScreen({
    super.key,
    required this.userId,
    required this.officeId,
    required this.clientId,
    required this.creditId,
  });
  @override
  Widget build(BuildContext context) {
    // Referencia al crédito en la nueva estructura
    final creditRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('offices')
        .doc(officeId)
        .collection('clients')
        .doc(clientId)
        .collection('credits')
        .doc(creditId);

    return StreamBuilder<DocumentSnapshot>(
      stream: creditRef.snapshots(),
      builder: (context, creditSnapshot) {
        if (!creditSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final creditData = creditSnapshot.data!.data() as Map<String, dynamic>?;
        if (creditData == null) {
          return const Scaffold(body: Center(child: Text('Crédito no encontrado')));
        }

        final creditValue = (creditData['credit'] ?? 0).toDouble();
        final interest = (creditData['interest'] ?? 0).toDouble();
        final cuot = (creditData['cuot'] ?? 1).toInt();
        final method = creditData['method'] ?? 'Diario';
        final total = creditValue + (creditValue * interest / 100);
        final cuotaValue = total / cuot;
        final createdAt = creditData['createdAt']?.toDate();
        final closedAt = creditData['closedAt']?.toDate();

        return StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('offices')
                  .doc(officeId)
                  .collection('clients')
                  .doc(clientId)
                  .snapshots(),
          builder: (context, clientSnapshot) {
            if (!clientSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final clientData = clientSnapshot.data!.data() as Map<String, dynamic>?;
            if (clientData == null) {
              return const Scaffold(body: Center(child: Text('Cliente no encontrado')));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: creditRef.collection('payments').orderBy('date').snapshots(),
              builder: (context, paymentsSnapshot) {
                final payments = paymentsSnapshot.data?.docs ?? [];

                return Scaffold(
                  appBar: AppBar(title: const Text('Detalle del Crédito')),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección de datos del cliente
                        Text(
                          '📋 Datos del Cliente',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Nombre: ${clientData['clientName'] ?? 'No especificado'}'),
                        Text('Celular: ${clientData['cellphone'] ?? 'No especificado'}'),
                        if (clientData['refAlias'] != null)
                          Text('Ref/Alias: ${clientData['refAlias']}'),
                        if (clientData['address'] != null)
                          Text('Dirección: ${clientData['address']}'),
                        if (clientData['phone'] != null) Text('Teléfono: ${clientData['phone']}'),
                        if (clientData['address2'] != null)
                          Text('Dirección 2: ${clientData['address2']}'),
                        if (clientData['city'] != null) Text('Ciudad: ${clientData['city']}'),

                        const Divider(height: 32),

                        // Sección de datos del crédito
                        Text(
                          '💰 Datos del Crédito',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Valor: \$${NumberFormat('#,##0', 'es_CO').format(creditValue)}'),
                        Text('Interés: ${interest.toStringAsFixed(2)}%'),
                        Text('Total a pagar: \$${NumberFormat('#,##0', 'es_CO').format(total)}'),
                        Text('Método: $method'),
                        Text('Cuotas: $cuot'),
                        Text('Valor de la cuota: \$${cuotaValue.toStringAsFixed(0)}'),

                        const Divider(height: 32),

                        // Sección de resumen
                        Text('📊 Resumen', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Fecha del crédito: ${createdAt != null ? DateFormat('yyyy-MM-dd – kk:mm').format(createdAt) : 'N/A'}',
                        ),
                        Text(
                          'Cierre de crédito: ${closedAt != null ? DateFormat('yyyy-MM-dd – kk:mm').format(closedAt) : 'N/A'}',
                        ),

                        // Sección de pagos
                        Text('📆 Pagos', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),

                        if (payments.isEmpty) const Text('No hay registros de pagos'),

                        ...payments.map((paymentDoc) {
                          final payment = paymentDoc.data() as Map<String, dynamic>;
                          final amount = (payment['amount'] ?? 0).toDouble();
                          final date = (payment['date'] as Timestamp).toDate();
                          final receipt = payment['receiptNumber'] ?? 'Sin recibo';
                          final method = payment['paymentMethod'] ?? 'Efectivo';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('\$${NumberFormat('#,##0', 'es_CO').format(amount)}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fecha: ${DateFormat.yMd('es_CO').format(date)}'),
                                  Text('Método: $method'),
                                  Text('Recibo: $receipt'),
                                ],
                              ),
                              trailing: Text(
                                payment['isActive'] == true ? '✅' : '❌',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
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
      },
    );
  }
}
