import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// ... (importaciones iguales)
class CollectorLiquidationScreen extends StatefulWidget {
  final String collectorId;
  final String collectorName;

  const CollectorLiquidationScreen({
    super.key,
    required this.collectorId,
    required this.collectorName,
  });

  @override
  State<CollectorLiquidationScreen> createState() => _CollectorLiquidationScreenState();
}

class _CollectorLiquidationScreenState extends State<CollectorLiquidationScreen> {
  DateTime? selectedDate;
  final _discountControllers = List.generate(5, (_) => TextEditingController());
  double totalCollected = 0;
  List<Map<String, dynamic>> paymentsOfDay = [];
  double discountTotal = 0;
  double netTotal = 0;
  String officeId = '';

  @override
  void initState() {
    super.initState();
    for (var controller in _discountControllers) {
      controller.addListener(_updateTotals);
    }
    _getOfficeId();
  }

  Future<void> _getOfficeId() async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(widget.collectorId).get();
    final data = userDoc.data();
    setState(() {
      officeId = data?['officeId'] ?? '';
    });
  }

  void _updateTotals() {
    double total = 0;
    for (var ctrl in _discountControllers) {
      total += double.tryParse(ctrl.text) ?? 0;
    }
    setState(() {
      discountTotal = total;
      netTotal = totalCollected - discountTotal;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      await _fetchPayments();
    }
  }

  Future<void> _fetchPayments() async {
    final creditsSnapshot =
        await FirebaseFirestore.instance
            .collection('credits')
            .where('createdBy', isEqualTo: widget.collectorId)
            .where('isActive', isEqualTo: true)
            .get();

    final List<Map<String, dynamic>> fetchedPayments = [];
    double collected = 0;

    for (var doc in creditsSnapshot.docs) {
      final data = doc.data();
      final clientId = data['clientId'];
      final creditRef = doc.reference;
      final clientSnapshot =
          await FirebaseFirestore.instance.collection('clients').doc(clientId).get();
      final clientName = clientSnapshot.data()?['clientName'] ?? 'Desconocido';

      final totalCredit = ((data['credit'] * data['interest']) / 100) + data['credit'];
      final cuot = data['cuot'];
      final dailyQuota = totalCredit / cuot;

      for (var entry in data.entries) {
        if (entry.key.startsWith('pay')) {
          final pay = entry.value;
          final payDate = (pay['date'] as Timestamp).toDate();
          if (pay['isActive'] == true &&
              DateFormat('yyyy-MM-dd').format(payDate) ==
                  DateFormat('yyyy-MM-dd').format(selectedDate!)) {
            fetchedPayments.add({
              'clientName': clientName,
              'amount': pay['amount'],
              'date': payDate,
              'creditRef': creditRef,
              'payKey': entry.key,
              'clientId': clientId,
            });
            collected += pay['amount'];
          }
        }
      }
    }

    setState(() {
      paymentsOfDay = fetchedPayments;
      totalCollected = collected;
      _updateTotals();
    });
  }

  Future<void> _finalizeLiquidation() async {
    final uuid = Uuid();
    final String liquidationId = uuid.v4();
    final liquidationDate = selectedDate ?? DateTime.now();

    for (var payment in paymentsOfDay) {
      await payment['creditRef'].update({'${payment['payKey']}.isActive': false});
    }

    final liquidationData = {
      'collectorId': widget.collectorId,
      'collectorName': widget.collectorName,
      'officeId': officeId,
      'date': liquidationDate,
      'totalCollected': totalCollected,
      'discounts': _discountControllers.map((e) => double.tryParse(e.text) ?? 0).toList(),
      'discountTotal': discountTotal,
      'netTotal': netTotal,
      'payments':
          paymentsOfDay
              .map(
                (p) => {
                  'clientId': p['clientId'],
                  'clientName': p['clientName'],
                  'amount': p['amount'],
                  'date': p['date'],
                },
              )
              .toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('liquidations')
        .doc(liquidationId)
        .set(liquidationData);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Liquidación realizada con éxito.')));

    setState(() {
      selectedDate = null;
      paymentsOfDay = [];
      totalCollected = 0;
      discountTotal = 0;
      netTotal = 0;
      for (var ctrl in _discountControllers) {
        ctrl.clear();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _discountControllers) {
      controller.removeListener(_updateTotals);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Liquidar a ${widget.collectorName}')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () => _selectDate(context),
            child: Text(
              selectedDate == null
                  ? 'Seleccionar fecha'
                  : 'Fecha: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}',
            ),
          ),
          if (paymentsOfDay.isNotEmpty)
            Expanded(
              child: ListView(
                children: [
                  ...paymentsOfDay.map(
                    (p) => Card(
                      child: ListTile(
                        title: Text(p['clientName']),
                        subtitle: Text(
                          'Valor: \$${p['amount']} - Fecha: ${DateFormat('yyyy-MM-dd').format(p['date'])}',
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total recolectado: \$${totalCollected.toStringAsFixed(2)}'),
                        const SizedBox(height: 10),
                        ...List.generate(
                          5,
                          (i) => TextField(
                            controller: _discountControllers[i],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Descuento ${i + 1}'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Total descuentos: \$${discountTotal.toStringAsFixed(2)}'),
                        Text('Total neto: \$${netTotal.toStringAsFixed(2)}'),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _finalizeLiquidation,
                          child: const Text('Finalizar Liquidación'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
