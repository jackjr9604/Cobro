import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

bool _isLoading = true;

class LiquidationReportScreen extends StatefulWidget {
  const LiquidationReportScreen({super.key});

  @override
  State<LiquidationReportScreen> createState() => _LiquidationReportScreenState();
}

class _LiquidationReportScreenState extends State<LiquidationReportScreen> {
  List<DocumentSnapshot> liquidations = [];
  DateTime? selectedDate;

  Future<void> _fetchLiquidations() async {
    setState(() => _isLoading = true); // Inicia carga
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null || userData['officeId'] == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userOfficeId = userData['officeId'];

      Query query = FirebaseFirestore.instance
          .collection('liquidations')
          .where('officeId', isEqualTo: userOfficeId);

      if (selectedDate != null) {
        final start = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
        final end = start.add(const Duration(days: 1));
        query = query.where('date', isGreaterThanOrEqualTo: start).where('date', isLessThan: end);
      }

      final snapshot = await query.get();
      setState(() {
        liquidations = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al obtener liquidaciones: $e');
      setState(() => _isLoading = false);
    }
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : liquidations.isEmpty
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
