import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreditDetailScreen extends StatelessWidget {
  final String userId;
  final String officeId;
  final String clientId;
  final String creditId;

  const CreditDetailScreen({
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

        final creditData = creditSnapshot.data!.data() as Map<String, dynamic>;
        final creditValue = creditData['credit'] ?? 0;
        final interest = creditData['interest'] ?? 0;
        final cuot = creditData['cuot'] ?? 1;
        final method = creditData['method'] ?? 'Diario';

        final total = creditValue + (creditValue * interest / 100);
        final cuota = total / cuot;

        return StreamBuilder<QuerySnapshot>(
          // Consulta a la subcolección de pagos
          stream: creditRef.collection('payments').orderBy('date').snapshots(),
          builder: (context, paymentsSnapshot) {
            if (!paymentsSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final payments = paymentsSnapshot.data!.docs;
            final cuotasPagadas = payments.length;
            final cuotasRestantes = cuot - cuotasPagadas;

            DateTime? lastPaymentDate;
            if (payments.isNotEmpty) {
              lastPaymentDate = (payments.last['date'] as Timestamp).toDate();
            } else {
              lastPaymentDate = creditData['createdAt']?.toDate();
            }

            // Cálculo de próxima cuota y fecha final
            DateTime? proximaCuota;
            DateTime? fechaFinal;
            final diasEntreCuotas = switch (method) {
              'Semanal' => 7,
              'Quincenal' => 15,
              'Mensual' => 30,
              _ => 1,
            };

            if (lastPaymentDate != null) {
              proximaCuota = lastPaymentDate.add(Duration(days: diasEntreCuotas));
              final fechaFinal = proximaCuota.add(
                Duration(days: (cuotasRestantes - 1) * diasEntreCuotas),
              );
            }

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

                final client = clientSnapshot.data!.data() as Map<String, dynamic>;

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
                        Text('Nombre: ${client['clientName']}'),
                        Text('Celular: ${client['cellphone']}'),
                        if (client['refAlias'] != null) Text('Ref/Alias: ${client['refAlias']}'),
                        if (client['address'] != null) Text('Dirección: ${client['address']}'),
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
                        Text('Valor de la cuota: \$${cuota.toStringAsFixed(0)}'),
                        const Divider(height: 32),

                        // Sección de pagos
                        Text(
                          '📆 Cuotas Pagadas ($cuotasPagadas)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...payments.map((paymentDoc) {
                          final payment = paymentDoc.data() as Map<String, dynamic>;
                          final amount = (payment['amount'] ?? 0).toDouble();
                          final date = (payment['date'] as Timestamp).toDate();
                          final isActive = payment['isActive'] ?? true;
                          final paymentId = paymentDoc.id;

                          return ListTile(
                            leading: Icon(
                              Icons.check_circle,
                              color: isActive ? Colors.green : Colors.grey,
                            ),
                            title: Text('Abono: \$${amount.toStringAsFixed(0)}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Fecha: ${DateFormat.yMd('es_CO').format(date)}'),
                                if (payment['receiptNumber'] != null)
                                  Text('Recibo: ${payment['receiptNumber']}'),
                              ],
                            ),
                            trailing:
                                isActive
                                    ? PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          await _editPayment(context, creditRef, paymentId, amount);
                                        } else if (value == 'delete') {
                                          await _deletePayment(
                                            context,
                                            creditRef,
                                            paymentId,
                                            amount,
                                          );
                                        }
                                      },
                                      itemBuilder:
                                          (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Editar'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Eliminar'),
                                            ),
                                          ],
                                    )
                                    : null,
                          );
                        }),
                        const Divider(height: 32),

                        // Sección de resumen
                        Text('📊 Resumen', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Cuotas restantes: $cuotasRestantes'),
                        if (proximaCuota != null)
                          Text('Próxima cuota: ${DateFormat.yMMMMd('es_CO').format(proximaCuota)}'),
                        if (fechaFinal != null)
                          Text(
                            'Fecha final estimada: ${DateFormat.yMMMMd('es_CO').format(fechaFinal)}',
                          ),
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

  Future<void> _editPayment(
    BuildContext context,
    DocumentReference creditRef,
    String paymentId,
    double currentAmount,
  ) async {
    final controller = TextEditingController(text: currentAmount.toStringAsFixed(0));
    final newAmount = await showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Editar Abono'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nuevo valor del abono'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final edited = double.tryParse(controller.text);
                  if (edited != null) {
                    Navigator.pop(context, edited);
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );

    if (newAmount != null && newAmount != currentAmount) {
      try {
        // Actualizar el pago
        await creditRef.collection('payments').doc(paymentId).update({
          'amount': newAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Actualizar el total pagado en el crédito
        final difference = newAmount - currentAmount;
        await creditRef.update({
          'totalPaid': FieldValue.increment(difference),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pago actualizado correctamente')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar pago: $e')));
      }
    }
  }

  Future<void> _deletePayment(
    BuildContext context,
    DocumentReference creditRef,
    String paymentId,
    double amount,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar Abono'),
            content: const Text('¿Estás seguro de eliminar este abono?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        // 1. Eliminar el pago
        batch.delete(creditRef.collection('payments').doc(paymentId));

        // 2. Actualizar el crédito
        batch.update(creditRef, {
          'totalPaid': FieldValue.increment(-amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pago eliminado correctamente')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar pago: $e')));
        }
      }
    }
  }
}
