import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'credit_detail_screen.dart';
import 'inactive_credits_screen.dart';

class CobrosScreen extends StatefulWidget {
  const CobrosScreen({super.key});

  @override
  State<CobrosScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends State<CobrosScreen> {
  final Map<String, int> orderMap = {};
  final Map<String, TextEditingController> controllers = {};

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _registerPayment(BuildContext context, DocumentSnapshot creditDoc) async {
    final docId = creditDoc.id;
    final data = creditDoc.data() as Map<String, dynamic>;

    final credit = (data['credit'] ?? 0) as num;
    final interestPercent = (data['interest'] ?? 0) as num;
    final cuot = (data['cuot'] ?? 1) as num;

    final interest = credit * interestPercent / 100;
    final total = credit + interest;
    final cuotaSugerida = total / cuot;

    final controller = TextEditingController(text: cuotaSugerida.toStringAsFixed(0));
    final totalAbonado = _sumActivePayments(data);
    final saldoRestante = total - totalAbonado;

    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Registrar pago'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Saldo restante: \$${NumberFormat('#,##0', 'es_CO').format(saldoRestante)}',
                    ),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Valor del abono'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed:
                              () => setState(() {
                                selectedDate = DateTime.now();
                              }),
                          child: const Text('Hoy'),
                        ),
                        ElevatedButton(
                          onPressed:
                              () => setState(() {
                                selectedDate = DateTime.now().add(const Duration(days: 1));
                              }),
                          child: const Text('Mañana'),
                        ),
                        IconButton(
                          tooltip: 'Seleccionar fecha',
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Fecha seleccionada: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final valor = int.tryParse(controller.text);
                      if (valor == null || valor <= 0) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Valor inválido')));
                        return;
                      }
                      if (valor > saldoRestante) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El pago excede el saldo restante')),
                        );
                        return;
                      }

                      final creditRef = FirebaseFirestore.instance.collection('credits').doc(docId);
                      final creditSnapshot = await creditRef.get();
                      final existingData = creditSnapshot.data() ?? {};

                      final pays = existingData.keys.where((key) => key.startsWith('pay')).toList();
                      final nextPayNumber = pays.length + 1;
                      final payField = 'pay$nextPayNumber';

                      await creditRef.update({
                        payField: {
                          'amount': valor,
                          'date': Timestamp.fromDate(selectedDate),
                          'isActive': true,
                        },
                      });

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Pago registrado exitosamente')));
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _closeCredit(DocumentSnapshot creditDoc) async {
    final docId = creditDoc.id;
    final creditRef = FirebaseFirestore.instance.collection('credits').doc(docId);

    // Actualiza el crédito como cerrado
    await creditRef.update({
      'isActive': false,
      'paid': Timestamp.now(), // fecha y hora del cierre
    });

    // Obtener el clientId para actualizar el cliente
    final creditData = creditDoc.data() as Map<String, dynamic>;
    final clientId = creditData['clientId'];

    if (clientId != null) {
      final clientRef = FirebaseFirestore.instance.collection('clients').doc(clientId);

      // Campo con la key del crédito que se está cerrando y se añade 'paidAt'
      final String creditFieldKey = docId;

      // La fecha actual para paidAt
      final Timestamp paidAtTimestamp = Timestamp.now();

      // Usar FieldValue para actualizar solo el campo dentro del map
      await clientRef.update({'$creditFieldKey.paidAt': paidAtTimestamp});
    }

    // Luego, actualizar el orden y los controladores localmente
    setState(() {
      orderMap.remove(docId);
      controllers.remove(docId);

      final activeCreditIds = orderMap.keys.toList();
      activeCreditIds.sort((a, b) => orderMap[a]!.compareTo(orderMap[b]!));

      for (int i = 0; i < activeCreditIds.length; i++) {
        final id = activeCreditIds[i];
        orderMap[id] = i + 1;
        if (controllers.containsKey(id)) {
          controllers[id]!.text = (i + 1).toString();
        }
      }
    });
  }

  int _sumActivePayments(Map<String, dynamic> data) {
    int sum = 0;
    data.forEach((key, value) {
      if (key.startsWith('pay') && value is Map<String, dynamic> && value['isActive'] == true) {
        final amount = value['amount'];
        if (amount is int) {
          sum += amount;
        } else if (amount is num) {
          sum += amount.toInt();
        }
      }
    });
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Usuario no autenticado')));
    }

    final uid = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Créditos Activos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver créditos inactivos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InactiveCreditsScreen()),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('credits')
                .where('createdBy', isEqualTo: uid)
                .where('isActive', isEqualTo: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes créditos activos aún.'));
          }

          final credits = snapshot.data!.docs;

          for (var i = 0; i < credits.length; i++) {
            final id = credits[i].id;
            orderMap.putIfAbsent(id, () => i + 1);
            controllers.putIfAbsent(
              id,
              () => TextEditingController(text: orderMap[id]!.toString()),
            );
          }

          credits.sort((a, b) => orderMap[a.id]!.compareTo(orderMap[b.id]!));

          return ListView.builder(
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final credit = credits[index];
              final data = credit.data() as Map<String, dynamic>;
              final createdAt = data['createdAt']?.toDate();
              final creditValue = (data['credit'] as num).toDouble();
              final interestPercent = (data['interest'] as num).toDouble();
              final total = creditValue + (creditValue * interestPercent / 100);
              final clientId = data['clientId'];

              final totalAbonado = _sumActivePayments(data);
              final saldoRestante = total - totalAbonado;

              final puedeCerrar = totalAbonado >= total;

              String? dayDisplay;
              if (data.containsKey('day')) {
                final day = data['day'];
                if (day is String) {
                  dayDisplay = day;
                } else if (day is int) {
                  final daysOfWeek = [
                    'Lunes',
                    'Martes',
                    'Miércoles',
                    'Jueves',
                    'Viernes',
                    'Sábado',
                    'Domingo',
                  ];
                  if (day >= 1 && day <= 7) dayDisplay = daysOfWeek[day - 1];
                }
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('clients').doc(clientId).get(),
                builder: (context, clientSnapshot) {
                  if (clientSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(title: Text('Cargando cliente...'));
                  }
                  if (!clientSnapshot.hasData || !clientSnapshot.data!.exists) {
                    return const ListTile(title: Text('Cliente no encontrado'));
                  }

                  final clientData = clientSnapshot.data!.data() as Map<String, dynamic>;
                  final clientName = clientData['clientName'] ?? 'Sin nombre';
                  final id = credit.id;

                  return Stack(
                    children: [
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CreditDetailScreen(credit: credit)),
                            );
                          },
                          child: ListTile(
                            title: Text('Cliente: $clientName'),
                            subtitle: Text(
                              'Crédito: \$${NumberFormat('#,##0', 'es_CO').format(creditValue)}\n'
                              'Interés: ${interestPercent.toStringAsFixed(2)}%\n'
                              'Forma de pago: ${data['method']}\n'
                              '${dayDisplay != null ? 'Día: $dayDisplay\n' : ''}'
                              'Total a pagar: \$${NumberFormat('#,##0', 'es_CO').format(total)}\n'
                              'Abonado: \$${NumberFormat('#,##0', 'es_CO').format(totalAbonado)}\n'
                              'Saldo faltante: \$${NumberFormat('#,##0', 'es_CO').format(saldoRestante)}\n'
                              'Fecha: ${createdAt != null ? DateFormat('yyyy-MM-dd – kk:mm').format(createdAt) : 'N/A'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.attach_money_rounded),
                                  tooltip: 'Registrar pago',
                                  onPressed:
                                      puedeCerrar ? null : () => _registerPayment(context, credit),
                                ),
                                if (puedeCerrar)
                                  ElevatedButton(
                                    onPressed: () async {
                                      await _closeCredit(credit);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Crédito cerrado con éxito')),
                                      );
                                    },
                                    child: const Text('Cerrar Crédito'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () async {
                            final newOrder = await showDialog<int>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Editar número'),
                                    content: TextField(
                                      controller: controllers[id],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Nuevo número'),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          final value = int.tryParse(controllers[id]!.text);
                                          Navigator.pop(context, value);
                                        },
                                        child: const Text('Guardar'),
                                      ),
                                    ],
                                  ),
                            );

                            if (newOrder != null && newOrder > 0 && newOrder <= credits.length) {
                              setState(() {
                                final currentOrder = orderMap[id]!;
                                if (newOrder != currentOrder) {
                                  if (newOrder < currentOrder) {
                                    // Subió de posición, desplazar hacia abajo a los que están entre newOrder y currentOrder -1
                                    orderMap.forEach((key, value) {
                                      if (value >= newOrder && value < currentOrder) {
                                        orderMap[key] = value + 1;
                                        controllers[key]!.text = (value + 1).toString();
                                      }
                                    });
                                  } else {
                                    // Bajó de posición, desplazar hacia arriba a los que están entre currentOrder + 1 y newOrder
                                    orderMap.forEach((key, value) {
                                      if (value <= newOrder && value > currentOrder) {
                                        orderMap[key] = value - 1;
                                        controllers[key]!.text = (value - 1).toString();
                                      }
                                    });
                                  }
                                  // Finalmente, asignar el nuevo orden a la tarjeta movida
                                  orderMap[id] = newOrder;
                                  controllers[id]!.text = newOrder.toString();
                                }
                              });
                            }
                          },
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue,
                            child: Text(
                              '${orderMap[id]}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
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
