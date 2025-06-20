import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

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
              fechaFinal = proximaCuota.add(
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
                  appBar: AppBar(
                    title: const Text('Detalle del Crédito'),
                    centerTitle: true,
                    elevation: 0,
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección de datos del cliente
                        _buildSectionHeader(context, '📋 Datos del Cliente'),
                        _buildInfoCard(
                          children: [
                            _buildInfoRow('Nombre', client['clientName']),
                            _buildInfoRow('Celular', client['cellphone']),
                            if (client['refAlias'] != null)
                              _buildInfoRow('Ref/Alias', client['refAlias']),
                            if (client['address'] != null)
                              _buildInfoRow('Dirección', client['address']),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Sección de datos del crédito
                        _buildSectionHeader(context, '💰 Datos del Crédito'),
                        _buildInfoCard(
                          children: [
                            _buildInfoRow(
                              'Valor',
                              '\$${NumberFormat('#,##0', 'es_CO').format(creditValue)}',
                              isAmount: true,
                            ),
                            _buildInfoRow('Interés', '${interest.toStringAsFixed(2)}%'),
                            _buildInfoRow(
                              'Total a pagar',
                              '\$${NumberFormat('#,##0', 'es_CO').format(total)}',
                              isAmount: true,
                            ),
                            _buildInfoRow('Método', method),
                            _buildInfoRow('Cuotas', '$cuot'),
                            _buildInfoRow(
                              'Valor de la cuota',
                              '\$${cuota.toStringAsFixed(0)}',
                              isAmount: true,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Sección de pagos
                        _buildSectionHeader(context, '📆 Cuotas Pagadas ($cuotasPagadas/${cuot})'),
                        if (payments.isEmpty) _buildEmptyState('No hay pagos registrados'),
                        ...payments.map((paymentDoc) {
                          final payment = paymentDoc.data() as Map<String, dynamic>;
                          final amount = (payment['amount'] ?? 0).toDouble();
                          final date = (payment['date'] as Timestamp).toDate();
                          final isActive = payment['isActive'] ?? true;
                          final paymentId = paymentDoc.id;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      isActive
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isActive ? Icons.check_circle : Icons.remove_circle,
                                  color: isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                              title: Text(
                                '\$${amount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat.yMMMMd('es_CO').format(date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (payment['receiptNumber'] != null)
                                    Text(
                                      'Recibo: ${payment['receiptNumber']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing:
                                  isActive
                                      ? PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _editPayment(
                                              context,
                                              creditRef,
                                              paymentId,
                                              amount,
                                            );
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
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit, size: 20),
                                                    SizedBox(width: 8),
                                                    Text('Editar'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete, size: 20, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Eliminar',
                                                      style: TextStyle(color: Colors.red),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                      )
                                      : null,
                            ),
                          );
                        }),

                        const SizedBox(height: 20),

                        // Sección de resumen
                        _buildSectionHeader(context, '📊 Resumen del Crédito'),
                        _buildInfoCard(
                          children: [
                            _buildInfoRow(
                              'Cuotas restantes',
                              '$cuotasRestantes',
                              valueColor: cuotasRestantes > 0 ? Colors.orange : Colors.green,
                            ),
                            if (proximaCuota != null)
                              _buildInfoRow(
                                'Próxima cuota',
                                DateFormat.yMMMMd('es_CO').format(proximaCuota),
                              ),
                            if (fechaFinal != null)
                              _buildInfoRow(
                                'Fecha final estimada',
                                DateFormat.yMMMMd('es_CO').format(fechaFinal),
                              ),
                            _buildProgressIndicator(context, cuotasPagadas, cuot),
                          ],
                        ),
                      ],
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => _addPayment(context, creditRef, cuota),
                    child: const Icon(Icons.add),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAmount = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? (isAmount ? Colors.green : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, int paid, int total) {
    final percentage = (paid / total * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Progreso: $paid/$total ($percentage%)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: paid / total,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            percentage >= 100 ? Colors.green : Theme.of(context).primaryColor,
          ),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey),
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _addPayment(BuildContext context, DocumentReference creditRef, double cuota) async {
    final amountController = TextEditingController(text: cuota.toStringAsFixed(0));
    final receiptController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat.yMd('es_CO').format(DateTime.now()),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Registrar Pago'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor del pago',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: receiptController,
                    decoration: const InputDecoration(
                      labelText: 'Número de recibo (opcional)',
                      prefixIcon: Icon(Icons.receipt),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Fecha del pago',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        dateController.text = DateFormat.yMd('es_CO').format(date);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null) {
                    Navigator.pop(context, {
                      'amount': amount,
                      'receiptNumber': receiptController.text,
                      'date': dateController.text,
                    });
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        await creditRef.collection('payments').add({
          'amount': result['amount'],
          'receiptNumber': result['receiptNumber'].isEmpty ? null : result['receiptNumber'],
          'date': DateFormat.yMd('es_CO').parse(result['date']),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await creditRef.update({
          'totalPaid': FieldValue.increment(result['amount']),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pago registrado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al registrar pago: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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
              decoration: const InputDecoration(
                labelText: 'Nuevo valor del abono',
                border: OutlineInputBorder(),
              ),
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
                child: const Text('Guardar Cambios'),
              ),
            ],
          ),
    );

    if (newAmount != null && newAmount != currentAmount) {
      try {
        await creditRef.collection('payments').doc(paymentId).update({
          'amount': newAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await creditRef.update({
          'totalPaid': FieldValue.increment(newAmount - currentAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pago actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar pago: $e'), backgroundColor: Colors.red),
          );
        }
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
            content: const Text(
              '¿Estás seguro de eliminar este abono? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        batch.delete(creditRef.collection('payments').doc(paymentId));
        batch.update(creditRef, {
          'totalPaid': FieldValue.increment(-amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pago eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar pago: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
