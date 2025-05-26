import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiquidationReportScreen extends StatefulWidget {
  const LiquidationReportScreen({super.key});

  @override
  State<LiquidationReportScreen> createState() => _LiquidationReportScreenState();
}

class ColumnDefinition {
  final String key;
  final String label;
  final bool numeric;
  final Comparable Function(DocumentSnapshot) getValue;

  ColumnDefinition({
    required this.key,
    required this.label,
    required this.numeric,
    required this.getValue,
  });
}

class _LiquidationReportScreenState extends State<LiquidationReportScreen> {
  List<DocumentSnapshot> liquidations = [];
  List<DocumentSnapshot> filteredLiquidations = [];
  DateTime? startDate;
  DateTime? endDate;
  bool _isLoading = true;

  // Para el filtro por cobrador con autocompletado
  String? _selectedCollector;
  List<String> _collectors = [];

  int? _sortColumnIndex;
  bool _sortAscending = true;

  final ScrollController _horizontalScrollController = ScrollController();
  final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

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

      if (startDate != null && endDate != null) {
        final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
        final end = DateTime(endDate!.year, endDate!.month, endDate!.day + 1);
        query = query.where('date', isGreaterThanOrEqualTo: start).where('date', isLessThan: end);
      }

      final snapshot = await query.get();
      setState(() {
        liquidations = snapshot.docs;

        // Obtener lista de cobradores única y ordenada
        final collectorsSet = <String>{};
        for (var doc in liquidations) {
          final data = doc.data() as Map<String, dynamic>;
          final collectorName = (data['collectorName'] ?? '').toString();
          if (collectorName.isNotEmpty) collectorsSet.add(collectorName);
        }
        _collectors = collectorsSet.toList()..sort();

        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error al obtener liquidaciones: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setQuickDateRange(String option) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (option) {
      case 'Hoy':
        start = DateTime(now.year, now.month, now.day);
        end = start;
        break;
      case 'Ayer':
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = start;
        break;
      case 'Este mes':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
        break;
      case 'Mes pasado':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        start = lastMonth;
        end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case 'Este año':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31);
        break;
      default:
        return;
    }

    setState(() {
      startDate = start;
      endDate = end;
    });

    _fetchLiquidations();
  }

  void _applyFilters() {
    filteredLiquidations =
        liquidations.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['collectorName'] ?? '').toString();
          if (_selectedCollector == null || _selectedCollector!.isEmpty) {
            return true;
          } else {
            return name == _selectedCollector;
          }
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

  void _clearFilters() {
    setState(() {
      _selectedCollector = null;
      startDate = null;
      endDate = null;
    });
    _fetchLiquidations();
  }

  late List<ColumnDefinition> allColumns;
  Set<String> visibleColumnsKeys = {}; // Las columnas seleccionadas visibles

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    startDate = DateTime(today.year, today.month, today.day); // inicio del día hoy
    endDate = DateTime(
      today.year,
      today.month,
      today.day,
    ); // fin del día hoy (igual, se sumará +1 en el query)
    _fetchLiquidations();

    allColumns = [
      ColumnDefinition(
        key: 'date',
        label: 'Fecha',
        numeric: false,
        getValue: (d) => (d['date'] as Timestamp).toDate(),
      ),
      ColumnDefinition(
        key: 'collectorName',
        label: 'Cobrador',
        numeric: false,
        getValue: (d) => d['collectorName'] ?? '',
      ),
      ColumnDefinition(
        key: 'totalCollected',
        label: 'Recaudado',
        numeric: true,
        getValue: (d) => d['totalCollected'] ?? 0,
      ),
      ColumnDefinition(
        key: 'alimentaciónDiscount',
        label: 'Alimentación',
        numeric: true,
        getValue: (d) {
          final data = d.data() as Map<String, dynamic>;
          final discounts = data['discounts'] as Map<String, dynamic>? ?? {};
          return discounts['Alimentación'] ?? 0;
        },
      ),
      ColumnDefinition(
        key: 'gasolineDiscount',
        label: 'Gasolina',
        numeric: true,
        getValue: (d) {
          final data = d.data() as Map<String, dynamic>;
          final discounts = data['discounts'] as Map<String, dynamic>? ?? {};
          return discounts['Gasolina'] ?? 0;
        },
      ),
      ColumnDefinition(
        key: 'tallerDiscount',
        label: 'Taller',
        numeric: true,
        getValue: (d) {
          final data = d.data() as Map<String, dynamic>;
          final discounts = data['discounts'] as Map<String, dynamic>? ?? {};
          return discounts['Taller'] ?? 0;
        },
      ),
      ColumnDefinition(
        key: 'repuestosDiscount',
        label: 'Repuestos',
        numeric: true,
        getValue: (d) {
          final data = d.data() as Map<String, dynamic>;
          final discounts = data['discounts'] as Map<String, dynamic>? ?? {};
          return discounts['Repuestos'] ?? 0;
        },
      ),
      ColumnDefinition(
        key: 'otrosDiscount',
        label: 'Otros',
        numeric: true,
        getValue: (d) {
          final data = d.data() as Map<String, dynamic>;
          final discounts = data['discounts'] as Map<String, dynamic>? ?? {};
          return discounts['Otros'] ?? 0;
        },
      ),
      ColumnDefinition(
        key: 'discountTotal',
        label: 'Descuento',
        numeric: true,
        getValue: (d) => d['discountTotal'] ?? 0,
      ),
      ColumnDefinition(
        key: 'netTotal',
        label: 'Neto',
        numeric: true,
        getValue: (d) => d['netTotal'] ?? 0,
      ),
      ColumnDefinition(
        key: 'payments',
        label: 'Pagos',
        numeric: true,
        getValue: (d) => (d['payments'] as List).length,
      ),
    ];

    // Por defecto mostrar todas las columnas
    visibleColumnsKeys = allColumns.map((c) => c.key).toSet();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _showColumnSelectionDialog() async {
    Set<String> selectedKeys = Set<String>.from(visibleColumnsKeys);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Seleccionar columnas a mostrar'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      allColumns.map((col) {
                        return CheckboxListTile(
                          value: selectedKeys.contains(col.key),
                          title: Text(col.label),
                          onChanged: (bool? value) {
                            setStateDialog(() {
                              if (value == true) {
                                selectedKeys.add(col.key);
                              } else {
                                selectedKeys.remove(col.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      visibleColumnsKeys = selectedKeys;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalCollected = 0;
    double totalDiscount = 0;
    double totalAlimentacion = 0;
    double totalGasoline = 0;
    double totalRepuestos = 0;
    double totalTaller = 0;
    double totalOtros = 0;
    double totalNet = 0;
    int totalPayments = 0;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final visibleColumns = allColumns.where((col) => visibleColumnsKeys.contains(col.key)).toList();

    for (var doc in filteredLiquidations) {
      final data = doc.data() as Map<String, dynamic>;
      totalCollected += (data['totalCollected'] ?? 0).toDouble();
      totalDiscount += (data['discountTotal'] ?? 0).toDouble();
      totalNet += (data['netTotal'] ?? 0).toDouble();
      totalPayments += (data['payments'] as List?)?.length ?? 0;

      final discounts = data['discounts'] as Map<String, dynamic>? ?? {};
      totalGasoline += (discounts['Gasolina'] ?? 0).toDouble();
      totalRepuestos += (discounts['Repuestos'] ?? 0).toDouble();
      totalAlimentacion += (discounts['Alimentación'] ?? 0).toDouble();
      totalTaller += (discounts['Taller'] ?? 0).toDouble();
      totalOtros += (discounts['Otros'] ?? 0).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Liquidaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_column),
            tooltip: 'Seleccionar columnas',
            onPressed: _showColumnSelectionDialog,
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2022),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  startDate = picked.start;
                  endDate = picked.end;
                });
                _fetchLiquidations();
              }
            },
            icon: const Icon(Icons.date_range),
            label: const Text('Filtrar por fecha'),
          ),
          PopupMenuButton<String>(
            onSelected: _setQuickDateRange,
            icon: const Icon(Icons.filter_alt),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'Hoy', child: Text('Hoy')),
                  const PopupMenuItem(value: 'Ayer', child: Text('Ayer')),
                  const PopupMenuItem(value: 'Este mes', child: Text('Este mes')),
                  const PopupMenuItem(value: 'Mes pasado', child: Text('Mes pasado')),
                  const PopupMenuItem(value: 'Este año', child: Text('Este año')),
                ],
          ),

          IconButton(icon: const Icon(Icons.clear), onPressed: _clearFilters),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('Filtrar por cobrador: '),
                const SizedBox(width: 10),
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      return _collectors.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setState(() {
                        _selectedCollector = selection;
                      });
                      _applyFilters();
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      controller.text = _selectedCollector ?? '';
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onEditingComplete: onEditingComplete,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un nombre',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          if (startDate != null && endDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text(
                        'Rango de fechas: ${DateFormat('yyyy-MM-dd').format(startDate!)} → ${DateFormat('yyyy-MM-dd').format(endDate!)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Divider(),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredLiquidations.isEmpty
                    ? const Center(child: Text('No hay liquidaciones registradas.'))
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          height: screenHeight,
                          width: screenWidth,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(),
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: MediaQuery.of(context).size.width,
                                ),
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    sortColumnIndex: _sortColumnIndex,
                                    sortAscending: _sortAscending,
                                    columns:
                                        visibleColumns
                                            .asMap()
                                            .entries
                                            .map(
                                              (entry) => DataColumn(
                                                label: Text(entry.value.label),
                                                numeric: entry.value.numeric,
                                                onSort:
                                                    (columnIndex, ascending) => _onSort(
                                                      entry.value.getValue,
                                                      columnIndex,
                                                      ascending,
                                                    ),
                                              ),
                                            )
                                            .toList(),
                                    rows: [
                                      ...filteredLiquidations.map((doc) {
                                        return DataRow(
                                          cells:
                                              allColumns
                                                  .where(
                                                    (col) => visibleColumnsKeys.contains(col.key),
                                                  )
                                                  .map((col) {
                                                    final value = col.getValue(doc);
                                                    final displayValue =
                                                        value is DateTime
                                                            ? DateFormat('yyyy-MM-dd').format(value)
                                                            : (col.key == 'payments' && value is num
                                                                ? value.toInt().toString()
                                                                : (col.numeric && value is num
                                                                    ? currencyFormat.format(value)
                                                                    : value.toString()));

                                                    return DataCell(Text(displayValue));
                                                  })
                                                  .toList(),
                                        );
                                      }),
                                      DataRow(
                                        color: MaterialStateProperty.all(Colors.grey[300]),
                                        cells:
                                            visibleColumns.map((col) {
                                              String text = '';
                                              switch (col.key) {
                                                case 'totalCollected':
                                                  text = currencyFormat.format(totalCollected);
                                                  break;
                                                case 'alimentaciónDiscount':
                                                  text = currencyFormat.format(totalAlimentacion);
                                                  break;
                                                case 'gasolineDiscount':
                                                  text = currencyFormat.format(totalGasoline);
                                                  break;
                                                case 'repuestosDiscount':
                                                  text = currencyFormat.format(totalRepuestos);
                                                  break;
                                                case 'tallerDiscount':
                                                  text = currencyFormat.format(totalTaller);
                                                  break;
                                                case 'otrosDiscount':
                                                  text = currencyFormat.format(totalOtros);
                                                  break;
                                                case 'discountTotal':
                                                  text = currencyFormat.format(totalDiscount);
                                                  break;
                                                case 'netTotal':
                                                  text = currencyFormat.format(totalNet);
                                                  break;
                                                case 'payments':
                                                  text = totalPayments.toString();
                                                  break;
                                                case 'date':
                                                  text = 'Totales';
                                                  break;
                                                default:
                                                  text = '';
                                              }
                                              return DataCell(
                                                Text(
                                                  text,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
