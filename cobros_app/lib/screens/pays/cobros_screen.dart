import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'CreditDetailScreen.dart';

class CobrosScreen extends StatelessWidget {
  const CobrosScreen({super.key});

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

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                    payField: {'amount': valor, 'date': Timestamp.now(), 'isActive': true},
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Pago registrado exitosamente')));
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  Future<void> _closeCredit(DocumentSnapshot creditDoc) async {
    final docId = creditDoc.id;
    final creditRef = FirebaseFirestore.instance.collection('credits').doc(docId);
    await creditRef.update({'isActive': false});
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
      appBar: AppBar(title: const Text('Mis Créditos Activos')),
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

          return ListView.builder(
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final credit = credits[index];
              final data = credit.data() as Map<String, dynamic>;
              final createdAt = data['createdAt']?.toDate();
              final creditValue = (data['credit'] as num).toDouble();
              final interestPercent = (data['interest'] as num).toDouble();
              final total = creditValue + (creditValue * interestPercent / 100);

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

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreditDetailScreen(credit: credit)),
                    );
                  },
                  child: ListTile(
                    title: Text('Crédito: \$${NumberFormat('#,##0', 'es_CO').format(creditValue)}'),
                    subtitle: Text(
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
                          onPressed: puedeCerrar ? null : () => _registerPayment(context, credit),
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
              );
            },
          );
        },
      ),
    );
  }
}
