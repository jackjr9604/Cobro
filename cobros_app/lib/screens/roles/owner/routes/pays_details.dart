import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaysDetails extends StatelessWidget {
  final String userId;
  final String officeId;
  final String clientId;
  final String creditId;

  const PaysDetails({
    super.key,
    required this.userId,
    required this.officeId,
    required this.clientId,
    required this.creditId,
  });

  // Métodos auxiliares (mantener igual)
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

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

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

    final clientRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('offices')
        .doc(officeId)
        .collection('clients')
        .doc(clientId);

    return StreamBuilder<DocumentSnapshot>(
      stream: creditRef.snapshots(),
      builder: (context, creditSnapshot) {
        if (!creditSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final creditData = creditSnapshot.data!.data() as Map<String, dynamic>;
        final creditValue = (creditData['credit'] ?? 0).toDouble();
        final interest = (creditData['interest'] ?? 0).toDouble();
        final cuot = (creditData['cuot'] ?? 1).toInt();
        final method = creditData['method'] ?? 'Diario';
        final total = creditValue + (creditValue * interest / 100);
        final cuota = total / cuot;
        final methodColor = _getMethodColor(method);
        final methodIcon = _getMethodIcon(method);

        return StreamBuilder<QuerySnapshot>(
          stream: creditRef.collection('payments').orderBy('date').snapshots(),
          builder: (context, paymentsSnapshot) {
            if (!paymentsSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final payments = paymentsSnapshot.data!.docs;
            final cuotasPagadas = payments.length;
            final cuotasRestantes = cuot - cuotasPagadas;

            final totalPagado = payments.fold(0.0, (sum, doc) {
              final data = doc.data() as Map<String, dynamic>;
              final amount = data['amount'];
              if (amount is int) return sum + amount.toDouble();
              if (amount is double) return sum + amount;
              if (amount is String) return sum + (double.tryParse(amount) ?? 0.0);
              return sum;
            });

            final totalPendiente = total - totalPagado;

            // Cálculo de fechas (mantener igual)
            DateTime? lastPaymentDate;
            if (payments.isNotEmpty) {
              lastPaymentDate = (payments.last['date'] as Timestamp).toDate();
            } else {
              lastPaymentDate = creditData['createdAt']?.toDate();
            }

            DateTime? proximaCuota;
            switch (method) {
              case 'Diario':
                proximaCuota = lastPaymentDate?.add(const Duration(days: 1));
                break;
              case 'Semanal':
                proximaCuota = lastPaymentDate?.add(const Duration(days: 7));
                break;
              case 'Quincenal':
                proximaCuota = lastPaymentDate?.add(const Duration(days: 15));
                break;
              case 'Mensual':
                proximaCuota = DateTime(
                  lastPaymentDate!.year,
                  lastPaymentDate.month + 1,
                  lastPaymentDate.day,
                );
                break;
            }

            final diasEntreCuotas = switch (method) {
              'Semanal' => 7,
              'Quincenal' => 15,
              'Mensual' => 30,
              _ => 1,
            };

            final fechaFinal = proximaCuota?.add(
              Duration(days: (cuotasRestantes - 1) * diasEntreCuotas),
            );

            return StreamBuilder<DocumentSnapshot>(
              stream: clientRef.snapshots(),
              builder: (context, clientSnapshot) {
                if (!clientSnapshot.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                final client = clientSnapshot.data!.data() as Map<String, dynamic>;
                final formatCurrency = NumberFormat('#,##0', 'es_CO');

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Detalle del Crédito'),
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Información del cliente
                        _buildInfoCard('📋 Información del Cliente', [
                          _buildInfoRow('Nombre', client['clientName'] ?? 'No especificado'),
                          _buildInfoRow('Celular', client['cellphone'] ?? 'No especificado'),
                          if (client['ref'] != null) _buildInfoRow('Ref/Alias', client['ref']!),
                          if (client['address'] != null)
                            _buildInfoRow('Dirección', client['address']!),
                        ]),

                        // Resumen del crédito
                        _buildInfoCard('💰 Resumen del Crédito', [
                          Row(
                            children: [
                              Icon(methodIcon, size: 20, color: methodColor),
                              const SizedBox(width: 8),
                              Text(
                                method,
                                style: TextStyle(fontWeight: FontWeight.bold, color: methodColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Valor del crédito',
                            '\$${formatCurrency.format(creditValue)}',
                          ),
                          _buildInfoRow('Interés', '${interest.toStringAsFixed(2)}%'),
                          _buildInfoRow('Total a pagar', '\$${formatCurrency.format(total)}'),
                          _buildInfoRow('Cuotas', '$cuot'),
                          _buildInfoRow('Valor cuota', '\$${cuota.toStringAsFixed(0)}'),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pagado', style: TextStyle(color: Colors.grey[600])),
                                  Text(
                                    '\$${formatCurrency.format(totalPagado)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Pendiente', style: TextStyle(color: Colors.grey[600])),
                                  Text(
                                    '\$${formatCurrency.format(totalPendiente)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: totalPendiente > 0 ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ]),

                        // Progreso del pago
                        Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '📊 Progreso del pago',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: cuotasPagadas / cuot,
                                  backgroundColor: Colors.grey[200],
                                  color: Theme.of(context).primaryColor,
                                  minHeight: 10,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Cuotas pagadas: $cuotasPagadas/$cuot',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${((cuotasPagadas / cuot) * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Próximos pagos
                        _buildInfoCard('📅 Próximos pagos', [
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
                          _buildInfoRow('Cuotas restantes', '$cuotasRestantes'),
                        ]),

                        // Pagos realizados
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '💳 Pagos realizados',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        cuotasPagadas.toString(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Theme.of(context).primaryColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...payments.map((paymentDoc) {
                                  final payment = paymentDoc.data() as Map<String, dynamic>;
                                  final amount = (payment['amount'] ?? 0).toDouble();
                                  final date = (payment['date'] as Timestamp).toDate();
                                  final isActive = payment['isActive'] ?? true;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        isActive ? Icons.check_circle : Icons.remove_circle,
                                        color: isActive ? Colors.green : Colors.grey,
                                      ),
                                      title: Text(
                                        '\$${formatCurrency.format(amount)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(DateFormat.yMMMMd('es_CO').format(date)),
                                      trailing:
                                          isActive
                                              ? IconButton(
                                                icon: const Icon(Icons.more_vert),
                                                onPressed:
                                                    () => _showPaymentOptions(
                                                      context,
                                                      creditRef,
                                                      paymentDoc.id,
                                                      amount,
                                                    ),
                                              )
                                              : null,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
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

  void _showPaymentOptions(
    BuildContext context,
    DocumentReference creditRef,
    String paymentId,
    double amount,
  ) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar pago'),
                onTap: () {
                  Navigator.pop(context);
                  _editPayment(context, creditRef, paymentId, amount);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar pago', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePayment(context, creditRef, paymentId);
                },
              ),
            ],
          ),
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
            title: const Text('Editar Pago'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nuevo valor'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final edited = double.tryParse(controller.text);
                  if (edited != null) Navigator.pop(context, edited);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );

    if (newAmount != null) {
      try {
        await creditRef.collection('payments').doc(paymentId).update({'amount': newAmount});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pago actualizado correctamente')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    }
  }

  Future<void> _deletePayment(
    BuildContext context,
    DocumentReference creditRef,
    String paymentId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar'),
            content: const Text('¿Eliminar este pago?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await creditRef.collection('payments').doc(paymentId).delete();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pago eliminado correctamente')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }
}
