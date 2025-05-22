import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiquidationReportScreen extends StatefulWidget {
  const LiquidationReportScreen({super.key});

  @override
  State<LiquidationReportScreen> createState() => _LiquidationReportScreenState();
}

class _LiquidationReportScreenState extends State<LiquidationReportScreen> {
  List<DocumentSnapshot> liquidations = [];
  List<DocumentSnapshot> filteredLiquidations = [];
  DateTime? selectedDate;
  bool _isLoading = true;
  String _searchText = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;

  final ScrollController _horizontalScrollController = ScrollController();

  Future<void> _fetchLiquidations() async {
    setState(() => _isLoading = true);
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
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error al obtener liquidaciones: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    filteredLiquidations =
        liquidations.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['collectorName'] ?? '').toString().toLowerCase();
          return name.contains(_searchText.toLowerCase());
        }).toList();
  }

  void _onSort<T>(
    Comparable<T> Function(DocumentSnapshot d) getField,
    int columnIndex,
    bool ascending,
  ) {
    filteredLiquidations.sort((a, b) {
      final aVal = getField(a);
      final bVal = getField(b);
      return ascending ? Comparable.compare(aVal, bVal) : Comparable.compare(bVal, aVal);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
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
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Liquidaciones'),
        actions: [IconButton(icon: const Icon(Icons.date_range), onPressed: _selectDate)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por cobrador...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                  _applyFilters();
                });
              },
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredLiquidations.isEmpty
              ? const Center(child: Text('No hay liquidaciones registradas.'))
              : LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: Container(
                      width: constraints.maxWidth * 0.98,
                      height: constraints.maxHeight * 0.85,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: _horizontalScrollController,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontalScrollController,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1000),
                            child: SingleChildScrollView(
                              child: DataTable(
                                sortAscending: _sortAscending,
                                sortColumnIndex: _sortColumnIndex,
                                columns: [
                                  DataColumn(
                                    label: const Text('Fecha'),
                                    onSort:
                                        (i, asc) => _onSort(
                                          (d) => (d['date'] as Timestamp).toDate(),
                                          i,
                                          asc,
                                        ),
                                  ),
                                  DataColumn(
                                    label: const Text('Cobrador'),
                                    onSort:
                                        (i, asc) =>
                                            _onSort((d) => d['collectorName'] ?? '', i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Recaudado'),
                                    numeric: true,
                                    onSort:
                                        (i, asc) =>
                                            _onSort((d) => d['totalCollected'] ?? 0, i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Descuento'),
                                    numeric: true,
                                    onSort:
                                        (i, asc) => _onSort((d) => d['discountTotal'] ?? 0, i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Neto'),
                                    numeric: true,
                                    onSort: (i, asc) => _onSort((d) => d['netTotal'] ?? 0, i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Pagos'),
                                    numeric: true,
                                    onSort:
                                        (i, asc) => _onSort(
                                          (d) => (d['payments'] as List?)?.length ?? 0,
                                          i,
                                          asc,
                                        ),
                                  ),
                                ],
                                rows:
                                    filteredLiquidations.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final date = (data['date'] as Timestamp).toDate();
                                      final payments = List.from(data['payments'] ?? []);
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(DateFormat('yyyy-MM-dd').format(date))),
                                          DataCell(Text(data['collectorName'] ?? '')),
                                          DataCell(Text('\$${data['totalCollected'] ?? 0}')),
                                          DataCell(Text('\$${data['discountTotal'] ?? 0}')),
                                          DataCell(Text('\$${data['netTotal'] ?? 0}')),
                                          DataCell(Text('${payments.length}')),
                                        ],
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
