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



  Map<String, dynamic> _calculateOverdueInfo(Map<String, dynamic> creditData) {
    final now = DateTime.now();
    final paymentSchedule =
        (creditData['paymentSchedule'] as List<dynamic>?)
            ?.map((dateStr) => DateTime.parse(dateStr as String))
            .toList() ??
        [];

    final nextPaymentIndex = (creditData['nextPaymentIndex'] as int?) ?? 0;
    final lastPaymentDate = (creditData['lastPaymentDate'] as Timestamp?)?.toDate();
    final interestRate = (creditData['interest'] as num?)?.toDouble() ?? 0.0;
    final creditValue = (creditData['credit'] as num?)?.toDouble() ?? 0.0;

    int daysOverdue = 0;
    double accumulatedInterest = 0.0;
    DateTime? nextPaymentDate;

    if (paymentSchedule.isNotEmpty && nextPaymentIndex < paymentSchedule.length) {
      nextPaymentDate = paymentSchedule[nextPaymentIndex];

      if (now.isAfter(nextPaymentDate)) {
        daysOverdue = now.difference(nextPaymentDate).inDays;

        // Calcular interés acumulado (ejemplo: 1% adicional por día de mora)
        final dailyPenaltyRate = interestRate / 100 / 30; // 1/30 del interés mensual
        accumulatedInterest = creditValue * dailyPenaltyRate * daysOverdue;
      }
    }

    return {
      'daysOverdue': daysOverdue,
      'accumulatedInterest': accumulatedInterest,
      'nextPaymentDate': nextPaymentDate,
      'nextPaymentIndex': nextPaymentIndex,
    };
  }

  @override
  void dispose() {
    controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<String?> _getCurrentUserId() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }


  Future<String?> _getOfficeId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['officeId'] as String?;
  }

  Future<void> _registerPayment(BuildContext context, DocumentSnapshot creditDoc) async {
    final data = creditDoc.data() as Map<String, dynamic>;
    final creditValue = (data['credit'] ?? 0).toDouble();
    final interestPercent = (data['interest'] ?? 0).toDouble();
    final cuot = (data['cuot'] ?? 1).toInt();

    final interest = creditValue * interestPercent / 100;
    final total = creditValue + interest;
    final cuotaSugerida = total / cuot;

    final controller = TextEditingController(text: cuotaSugerida.toStringAsFixed(0));
    final totalAbonado = await _getTotalPayments(creditDoc.reference);
    final saldoRestante = total - totalAbonado;

    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Registrar pago'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Saldo restante: \$${NumberFormat('#,##0', 'es_CO').format(saldoRestante)}'),
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
                      onPressed: () => setState(() => selectedDate = DateTime.now()),
                      child: const Text('Hoy'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => selectedDate = DateTime.now().add(const Duration(days: 1))),
                      child: const Text('Mañana'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => selectedDate = picked);
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
                onPressed: () => _processPayment(
                  context: context,
                  creditDoc: creditDoc,
                  valor: double.tryParse(controller.text),
                  selectedDate: selectedDate,
                  saldoRestante: saldoRestante,
                ),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processPayment({
    required BuildContext context,
    required DocumentSnapshot creditDoc,
    required double? valor,
    required DateTime selectedDate,
    required double saldoRestante,
  }) async {
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valor inválido')));
      return;
    }

    if (valor > saldoRestante) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El pago excede el saldo restante')));
      return;
    }

    final userId = await _getCurrentUserId();
    final officeId = await _getOfficeId();

    if (userId == null || officeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: No se pudo obtener información del usuario')));
      return;
    }

    try {
      final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
      final batch = FirebaseFirestore.instance.batch();

      // 1. Crear documento en la subcolección payments
      final paymentRef = creditDoc.reference.collection('payments').doc(paymentId);
      batch.set(paymentRef, {
        'amount': valor,
        'date': Timestamp.fromDate(selectedDate),
        'isActive': true,
        'timestamp': Timestamp.now(),
        'paymentId': paymentId,
        'collectorId': userId,
        'officeId': officeId,
      });

      // 2. Actualizar crédito
      batch.update(creditDoc.reference, {
        'lastPaymentDate': Timestamp.fromDate(selectedDate),
        'nextPaymentIndex': FieldValue.increment(1),
        'daysOverdue': 0,
        'accumulatedInterest': 0.0,
        'updatedAt': Timestamp.now(),
      });

      // 3. Actualizar dailyCollections
      final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
      final dailyCollectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('offices')
          .doc(officeId)
          .collection('dailyCollections')
          .doc(dateKey);

      batch.set(dailyCollectionRef, {
        'total': FieldValue.increment(valor),
        'payments': FieldValue.arrayUnion([paymentId]),
        'timestamp': Timestamp.fromDate(selectedDate),
      }, SetOptions(merge: true));

      // 4. Actualizar balance de la oficina
      final officeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('offices')
          .doc(officeId);

      batch.update(officeRef, {'totalBalance': FieldValue.increment(valor)});

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }



  Future<double> _getTotalPayments(DocumentReference creditRef) async {
    final payments = await creditRef.collection('payments').get();
    return payments.docs.fold(0.0, (sum, doc) => sum + (doc['amount'] ?? 0).toDouble());
  }

  Future<bool> _canCloseCredit(DocumentReference creditRef) async {
    final creditData = (await creditRef.get()).data() as Map<String, dynamic>;
    final totalPayments = await _getTotalPayments(creditRef);
    final creditValue = (creditData['credit'] ?? 0).toDouble();
    final interest = creditValue * ((creditData['interest'] ?? 0).toDouble() / 100);
    final total = creditValue + interest;

    if (totalPayments < total) return false;

    final activePayments = await creditRef
        .collection('payments')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    return activePayments.docs.isEmpty;
  }

  Future<void> _closeCredit(DocumentSnapshot creditDoc) async {
    final batch = FirebaseFirestore.instance.batch();
    final creditRef = creditDoc.reference;
    final clientId = creditDoc['clientId'];
    final userId = await _getCurrentUserId();
    final officeId = await _getOfficeId();

    if (userId == null || officeId == null) return;

    // 1. Marcar crédito como cerrado
    batch.update(creditRef, {
      'isActive': false,
      'paidAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    // 2. Marcar todos los pagos como inactivos
    final payments = await creditRef.collection('payments').get();
    for (final payment in payments.docs) {
      batch.update(payment.reference, {'isActive': false});
    }

    // 3. Actualizar cliente si existe
    if (clientId != null) {
      final clientRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('offices')
          .doc(officeId)
          .collection('clients')
          .doc(clientId);

      batch.update(clientRef, {
        'updatedAt': Timestamp.now(),
        'lastCreditStatus': 'closed',
      });
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crédito cerrado con éxito')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cerrar crédito: $e')));
      }
    }
  }

   Future<bool> _allPaymentsInactive(DocumentReference creditRef) async {
    final activePayments = await creditRef
        .collection('payments')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    return activePayments.docs.isEmpty;
  }







  int _sumActivePayments(Map<String, dynamic> data) {
    int sum = 0;
    data.forEach((key, value) {
      if (key.startsWith('pay') && value is Map<String, dynamic>) {
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
        stream: FirebaseFirestore.instance
            .collectionGroup('credits') // Usamos collectionGroup para buscar en todas las subcolecciones
            .where('createdBy', isEqualTo: currentUser.uid)
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


              final puedeCerrar = totalAbonado >= total && await _allPaymentsInactive(data);




              // Calcular información de morosidad
              final overdueInfo = _calculateOverdueInfo(data);
              final daysOverdue = overdueInfo['daysOverdue'] as int;
              final accumulatedInterest = overdueInfo['accumulatedInterest'] as double;
              final nextPaymentDate = overdueInfo['nextPaymentDate'] as DateTime?;

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
                        color:
                            daysOverdue > 30
                                ? Colors.red[900]
                                : daysOverdue > 15
                                ? Colors.red[600]
                                : daysOverdue > 0
                                ? Colors.red[300]
                                : null,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CreditDetailScreen(credit: credit)),
                            );
                          },
                          child: ListTile(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (daysOverdue == 0)
                                  Text(
                                    'Cliente: $clientName',
                                    style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
                                  )
                                else if (daysOverdue > 0)
                                  Text(
                                    'Cliente: $clientName',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                              ],
                            ),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (daysOverdue == 0) ...[
                                  Text(
                                    'Crédito: \$${NumberFormat('#,##0', 'es_CO').format(creditValue)}',
                                  ),
                                  Text('Interés: ${interestPercent.toStringAsFixed(2)}%'),
                                  Text('Forma de pago: ${data['method']}'),
                                  if (dayDisplay != null) Text('Día: $dayDisplay'),
                                  Text(
                                    'Total a pagar: \$${NumberFormat('#,##0', 'es_CO').format(total)}',
                                  ),
                                  Text(
                                    'Abonado: \$${NumberFormat('#,##0', 'es_CO').format(totalAbonado)}',
                                  ),
                                  Text(
                                    'Saldo faltante: \$${NumberFormat('#,##0', 'es_CO').format(saldoRestante)}',
                                  ),

                                  // Nueva información de pagos y morosidad
                                  if (nextPaymentDate != null)
                                    Text(
                                      'Próximo pago: ${DateFormat('yyyy-MM-dd').format(nextPaymentDate)}',
                                    ),
                                  Text(
                                    'Fecha: ${createdAt != null ? DateFormat('yyyy-MM-dd – kk:mm').format(createdAt) : 'N/A'}',
                                  ),
                                ],

                                if (daysOverdue > 0) ...[
                                  Text(
                                    'Crédito: \$${NumberFormat('#,##0', 'es_CO').format(creditValue)}',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                  Text(
                                    'Interés: ${interestPercent.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                  Text(
                                    'Forma de pago: ${data['method']}',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                  if (dayDisplay != null)
                                    Text(
                                      'Día: $dayDisplay',
                                      style: TextStyle(
                                        color: const Color.fromARGB(255, 255, 255, 255),
                                      ),
                                    ),
                                  Text(
                                    'Total a pagar: \$${NumberFormat('#,##0', 'es_CO').format(total)}',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                  Text(
                                    'Abonado: \$${NumberFormat('#,##0', 'es_CO').format(totalAbonado)}',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                  Text(
                                    'Saldo faltante: \$${NumberFormat('#,##0', 'es_CO').format(saldoRestante)}',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                  Text(
                                    'Días en mora: $daysOverdue',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                  Text(
                                    'Interés acumulado: \$${NumberFormat('#,##0', 'es_CO').format(accumulatedInterest)}',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                  if (nextPaymentDate != null)
                                    Text(
                                      'Próximo pago: ${DateFormat('yyyy-MM-dd').format(nextPaymentDate)}',
                                      style: TextStyle(
                                        color: const Color.fromARGB(255, 255, 255, 255),
                                      ),
                                    ),
                                  Text(
                                    'Fecha: ${createdAt != null ? DateFormat('yyyy-MM-dd – kk:mm').format(createdAt) : 'N/A'}',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 255, 255, 255),
                                    ),
                                  ),
                                ],
                              ],
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
