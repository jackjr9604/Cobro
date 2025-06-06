import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaysDetails extends StatelessWidget {
  final DocumentSnapshot credit;

  const PaysDetails({super.key, required this.credit});

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
        final method = data['method'] ?? 'Diario';

        final total = creditValue + (creditValue * interest / 100);
        final cuota = total / cuot;
        final methodColor = _getMethodColor(method);
        final methodIcon = _getMethodIcon(method);

        final pays =
            data.entries
                .where((e) => e.key.startsWith('pay'))
                .where((e) => e.value is Map<String, dynamic>)
                .map((e) => MapEntry(e.key, e.value as Map<String, dynamic>))
                .toList();

        pays.sort((a, b) => (a.value['date'] as Timestamp).compareTo(b.value['date'] as Timestamp));

        final cuotasPagadas = pays.length;
        final cuotasRestantes = cuot - cuotasPagadas;
        final totalPagado = pays.fold(0.0, (sum, e) => sum + (e.value['amount'] ?? 0).toDouble());
        final totalPendiente = total - totalPagado;

        DateTime? lastPaymentDate;
        if (pays.isNotEmpty) {
          lastPaymentDate = (pays.last.value['date'] as Timestamp).toDate();
        } else {
          lastPaymentDate = data['createdAt']?.toDate();
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
          stream: FirebaseFirestore.instance.collection('clients').doc(clientId).snapshots(),
          builder: (context, clientSnapshot) {
            if (!clientSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final client = clientSnapshot.data!.data() as Map<String, dynamic>;
            final formatCurrency = NumberFormat('#,##0', 'es_CO');

            return Scaffold(
              appBar: AppBar(
                title: const Text('Detalle del Crédito'),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tarjeta de información del cliente
                    _buildInfoCard('📋 Información del Cliente', [
                      _buildInfoRow('Nombre', client['clientName'] ?? 'No especificado'),
                      _buildInfoRow('Celular', client['cellphone'] ?? 'No especificado'),
                      if (client['ref'] != null) _buildInfoRow('Ref/Alias', client['ref']!),
                      if (client['address'] != null) _buildInfoRow('Dirección', client['address']!),
                    ]),

                    // Tarjeta de resumen del crédito
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
                      _buildInfoRow('Valor del crédito', '\$${formatCurrency.format(creditValue)}'),
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

                    // Tarjeta de progreso
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

                    // Tarjeta de próximos pagos
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

                    // Lista de pagos realizados
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
                            ...pays.map((entry) {
                              final pago = entry.value;
                              final amount = (pago['amount'] ?? 0).toDouble();
                              final date = (pago['date'] as Timestamp).toDate();
                              final isActive = pago['isActive'] ?? true;

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
                                            onPressed: () {
                                              showModalBottomSheet(
                                                context: context,
                                                builder:
                                                    (context) => Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        ListTile(
                                                          leading: const Icon(Icons.edit),
                                                          title: const Text('Editar pago'),
                                                          onTap: () async {
                                                            Navigator.pop(context);
                                                            final controller =
                                                                TextEditingController(
                                                                  text: amount.toStringAsFixed(0),
                                                                );
                                                            final newAmount =
                                                                await showDialog<double>(
                                                                  context: context,
                                                                  builder:
                                                                      (context) => AlertDialog(
                                                                        title: const Text(
                                                                          'Editar Pago',
                                                                        ),
                                                                        content: TextField(
                                                                          controller: controller,
                                                                          keyboardType:
                                                                              TextInputType.number,
                                                                          decoration:
                                                                              const InputDecoration(
                                                                                labelText:
                                                                                    'Nuevo valor',
                                                                              ),
                                                                        ),
                                                                        actions: [
                                                                          TextButton(
                                                                            onPressed:
                                                                                () => Navigator.pop(
                                                                                  context,
                                                                                ),
                                                                            child: const Text(
                                                                              'Cancelar',
                                                                            ),
                                                                          ),
                                                                          ElevatedButton(
                                                                            onPressed: () {
                                                                              final edited =
                                                                                  double.tryParse(
                                                                                    controller.text,
                                                                                  );
                                                                              if (edited != null) {
                                                                                Navigator.pop(
                                                                                  context,
                                                                                  edited,
                                                                                );
                                                                              }
                                                                            },
                                                                            child: const Text(
                                                                              'Guardar',
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                );

                                                            if (newAmount != null) {
                                                              await credit.reference.update({
                                                                '${entry.key}.amount': newAmount,
                                                              });
                                                            }
                                                          },
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(
                                                            Icons.delete,
                                                            color: Colors.red,
                                                          ),
                                                          title: const Text(
                                                            'Eliminar pago',
                                                            style: TextStyle(color: Colors.red),
                                                          ),
                                                          onTap: () async {
                                                            Navigator.pop(context);
                                                            final confirm = await showDialog<bool>(
                                                              context: context,
                                                              builder:
                                                                  (context) => AlertDialog(
                                                                    title: const Text('Confirmar'),
                                                                    content: const Text(
                                                                      '¿Eliminar este pago?',
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () => Navigator.pop(
                                                                              context,
                                                                              false,
                                                                            ),
                                                                        child: const Text(
                                                                          'Cancelar',
                                                                        ),
                                                                      ),
                                                                      TextButton(
                                                                        onPressed:
                                                                            () => Navigator.pop(
                                                                              context,
                                                                              true,
                                                                            ),
                                                                        child: const Text(
                                                                          'Eliminar',
                                                                          style: TextStyle(
                                                                            color: Colors.red,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                            );

                                                            if (confirm == true) {
                                                              await credit.reference.update({
                                                                entry.key: FieldValue.delete(),
                                                              });
                                                            }
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                              );
                                            },
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
}
