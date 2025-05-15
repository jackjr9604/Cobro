import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreditDetailScreen extends StatelessWidget {
  final DocumentSnapshot credit;

  const CreditDetailScreen({super.key, required this.credit});

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
                .map((e) => MapEntry(e.key, e.value as Map<String, dynamic>))
                .toList();

        pays.sort((a, b) => (a.value['date'] as Timestamp).compareTo(b.value['date'] as Timestamp));

        final cuotasPagadas = pays.length;
        final cuotasRestantes = cuot - cuotasPagadas;

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

            return Scaffold(
              appBar: AppBar(title: const Text('Detalle del Crédito')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📋 Datos del Cliente', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Nombre: ${client['name']}'),
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
                    Text(
                      '📆 Cuotas Pagadas (${cuotasPagadas})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...pays.map((entry) {
                      final key = entry.key;
                      final pago = entry.value;
                      final amount = (pago['amount'] ?? 0).toDouble();
                      final date = (pago['date'] as Timestamp).toDate();
                      final isActive = pago['isActive'] ?? true;

                      return ListTile(
                        leading: Icon(
                          Icons.check_circle,
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                        title: Text('Abono: \$${amount.toStringAsFixed(0)}'),
                        subtitle: Text('Fecha: ${DateFormat.yMd('es_CO').format(date)}'),
                        trailing:
                            isActive
                                ? PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      final controller = TextEditingController(
                                        text: amount.toStringAsFixed(0),
                                      );
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
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Cancelar'),
                                                ),
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

                                      if (newAmount != null) {
                                        await credit.reference.update({'$key.amount': newAmount});
                                      }
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text('Eliminar Abono'),
                                              content: const Text(
                                                '¿Estás seguro de eliminar este abono?',
                                              ),
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
                                        await credit.reference.update({key: FieldValue.delete()});
                                      }
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
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
                    Text('📊 Resumen', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Cuotas restantes: $cuotasRestantes'),
                    if (proximaCuota != null)
                      Text('Próxima cuota: ${DateFormat.yMMMMd('es_CO').format(proximaCuota)}'),
                    if (fechaFinal != null)
                      Text(
                        'Fecha de finalización estimada: ${DateFormat.yMMMMd('es_CO').format(fechaFinal)}',
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
}
