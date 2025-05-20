import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LiquidationReportScreen extends StatefulWidget {
  const LiquidationReportScreen({super.key});

  @override
  State<LiquidationReportScreen> createState() => _LiquidationReportScreenState();
}

class _LiquidationReportScreenState extends State<LiquidationReportScreen> {
  List<DocumentSnapshot> liquidations = [];
  DateTime? selectedDate;

  Future<void> _fetchLiquidations() async {
    Query query = FirebaseFirestore.instance
        .collection('liquidations')
        .orderBy('date', descending: true);

    if (selectedDate != null) {
      final start = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
      final end = start.add(const Duration(days: 1));
      query = query.where('date', isGreaterThanOrEqualTo: start).where('date', isLessThan: end);
    }

    final snapshot = await query.get();
    setState(() => liquidations = snapshot.docs);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _fetchLiquidations();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLiquidations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Liquidaciones'),
        actions: [IconButton(icon: const Icon(Icons.date_range), onPressed: _selectDate)],
      ),
      body:
          liquidations.isEmpty
              ? const Center(child: Text('No hay liquidaciones registradas.'))
              : ListView.builder(
                itemCount: liquidations.length,
                itemBuilder: (context, index) {
                  final data = liquidations[index].data() as Map<String, dynamic>;
                  final date = (data['date'] as Timestamp).toDate();
                  final payments = List.from(data['payments'] ?? []);
                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: ListTile(
                      title: Text(
                        '${data['collectorName']} - ${DateFormat('yyyy-MM-dd').format(date)}',
                      ),
                      subtitle: Text(
                        'Recaudado: \$${data['totalCollected']}\n'
                        'Descuento: \$${data['discountTotal']}\n'
                        'Neto: \$${data['netTotal']}\n'
                        'Pagos: ${payments.length}',
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
