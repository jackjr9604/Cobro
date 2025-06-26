import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../../../../utils/app_theme.dart';

class LiquidationReportScreen extends StatefulWidget {
  final String officeId; // Añadir esta propiedad

  const LiquidationReportScreen({
    super.key,
    required this.officeId, // Hacerla requerida
  });

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

  // Nuevas variables para paginación
  int _currentPage = 0;
  int _rowsPerPage = 20; // Puedes ajustar este número según prefieras
  final List<int> _rowsPerPageOptions = [10, 20, 50, 100]; // Opciones para cambiar items por página

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  Future<void> _fetchLiquidations() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Construir consulta base con la nueva estructura
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('offices')
          .doc(widget.officeId)
          .collection('liquidations')
          .orderBy('date', descending: true);

      // 2. Aplicar filtros de fecha si existen
      if (startDate != null && endDate != null) {
        final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
        final end = DateTime(endDate!.year, endDate!.month, endDate!.day + 1);
        query = query
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(end));
      }

      // 3. Ejecutar consulta
      final snapshot = await query.get();

      setState(() {
        liquidations = snapshot.docs;

        // Obtener lista única de cobradores
        final collectorsSet = <String>{};
        for (var doc in liquidations) {
          final data = doc.data() as Map<String, dynamic>;
          final collectorName = data['collectorName']?.toString() ?? '';
          if (collectorName.isNotEmpty) collectorsSet.add(collectorName);
        }
        _collectors = collectorsSet.toList()..sort();

        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error al obtener liquidaciones: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar liquidaciones: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setQuickDateRange(String option) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (option) {
      case 'Hoy':
        start = DateTime(now.year, now.month, now.day);
        end = start.add(Duration(days: 1)); // Incluye todo el día
        break;
      case 'Ayer':
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = start.add(Duration(days: 1));
        break;
      case 'Esta semana':
        // Calcula el lunes de esta semana
        final daysFromMonday = now.weekday - DateTime.monday;
        start = DateTime(now.year, now.month, now.day - daysFromMonday);
        // El fin de semana es hasta el domingo a medianoche
        end = start.add(Duration(days: 7));
        break;
      case 'Semana pasada':
        final today = DateTime(now.year, now.month, now.day);
        final startOfCurrentWeek = today.subtract(Duration(days: today.weekday - DateTime.monday));
        final startOfLastWeek = startOfCurrentWeek.subtract(const Duration(days: 7));
        end = startOfCurrentWeek;
        start = startOfLastWeek;
        break;
      case 'Este mes':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;
      case 'Mes pasado':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        start = lastMonth;
        end = DateTime(lastMonth.year, lastMonth.month + 1, 1);
        break;
      case 'Este año':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        break;
      default:
        return;
    }

    setState(() {
      startDate = start;
      endDate = end.subtract(Duration(seconds: 1)); // Ajuste para incluir todo el último día
    });

    _fetchLiquidations();
  }

  Widget _buildPaginationControls() {
    final totalPages = (filteredLiquidations.length / _rowsPerPage).ceil();
    final firstItem = _currentPage * _rowsPerPage + 1;
    final lastItem = math.min((_currentPage + 1) * _rowsPerPage, filteredLiquidations.length);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón primera página
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
            tooltip: 'Primera página',
          ),

          // Botón página anterior
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            tooltip: 'Página anterior',
          ),

          // Indicador de página
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '$firstItem-$lastItem de ${filteredLiquidations.length}',
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // Botón página siguiente
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
            tooltip: 'Página siguiente',
          ),

          // Botón última página
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed:
                _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
            tooltip: 'Última página',
          ),

          // Selector de items por página
          PopupMenuButton<int>(
            icon: const Icon(Icons.settings),
            itemBuilder:
                (context) =>
                    _rowsPerPageOptions.map((value) {
                      return PopupMenuItem<int>(
                        value: value,
                        child: Text('$value items por página'),
                      );
                    }).toList(),
            onSelected: (value) {
              setState(() {
                _rowsPerPage = value;
                _currentPage = 0; // Reset a la primera página
              });
            },
            tooltip: 'Items por página',
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 0; // Resetear a la primera página
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
    });
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

    // Columnas visibles por defecto
    visibleColumnsKeys = {
      'date',
      'collectorName',
      'totalCollected',
      'discountTotal',
      'netTotal',
      'payments',
    };
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
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
                        final isEssential = ['date', 'collectorName'].contains(col.key);
                        return CheckboxListTile(
                          value: selectedKeys.contains(col.key),
                          title: Text(col.label),
                          onChanged:
                              isEssential
                                  ? null // Deshabilitar check para columnas esenciales
                                  : (bool? value) {
                                    setStateDialog(() {
                                      if (value == true) {
                                        selectedKeys.add(col.key);
                                      } else {
                                        selectedKeys.remove(col.key);
                                      }
                                    });
                                  },
                          activeColor: isEssential ? Colors.grey : null,
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
                      // Forzar las columnas esenciales siempre visibles
                      visibleColumnsKeys =
                          selectedKeys
                            ..add('date')
                            ..add('collectorName');
                    });
                    Navigator.pop(context);
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

  // Reemplaza el cálculo manual por este método
  Map<String, dynamic> _calculateTotals() {
    if (filteredLiquidations.isEmpty) {
      return {
        'totalCollected': 0.0,
        'totalDiscount': 0.0,
        'totalAlimentacion': 0.0,
        'totalGasoline': 0.0,
        'totalRepuestos': 0.0,
        'totalTaller': 0.0,
        'totalOtros': 0.0,
        'totalNet': 0.0,
        'totalPayments': 0,
      };
    }

    return filteredLiquidations.fold(
      {
        'totalCollected': 0.0,
        'totalDiscount': 0.0,
        'totalAlimentacion': 0.0,
        'totalGasoline': 0.0,
        'totalRepuestos': 0.0,
        'totalTaller': 0.0,
        'totalOtros': 0.0,
        'totalNet': 0.0,
        'totalPayments': 0,
      },
      (totals, doc) {
        final data = doc.data() as Map<String, dynamic>;
        final discounts = data['discounts'] as Map<String, dynamic>? ?? {};

        totals['totalCollected'] += (data['totalCollected'] ?? 0).toDouble();
        totals['totalDiscount'] += (data['discountTotal'] ?? 0).toDouble();
        totals['totalNet'] += (data['netTotal'] ?? 0).toDouble();
        totals['totalPayments'] += (data['payments'] as List?)?.length ?? 0;

        // Sumar cada tipo de descuento
        totals['totalGasoline'] += (discounts['Gasolina'] ?? 0).toDouble();
        totals['totalAlimentacion'] += (discounts['Alimentación'] ?? 0).toDouble();
        totals['totalTaller'] += (discounts['Taller'] ?? 0).toDouble();
        totals['totalRepuestos'] += (discounts['Repuestos'] ?? 0).toDouble();
        totals['totalOtros'] += (discounts['Otros'] ?? 0).toDouble();

        return totals;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();

    final visibleColumns = allColumns.where((col) => visibleColumnsKeys.contains(col.key)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Liquidaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_column),
            color: AppTheme.neutroColor,
            tooltip: 'Seleccionar columnas',
            onPressed: _showColumnSelectionDialog,
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2022),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(
                  start: startDate ?? DateTime.now(),
                  end: endDate ?? DateTime.now(),
                ),
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
            icon: const Icon(Icons.filter_alt, color: AppTheme.neutroColor),

            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'Hoy', child: Text('Hoy')),
                  const PopupMenuItem(value: 'Ayer', child: Text('Ayer')),
                  const PopupMenuItem(value: 'Esta semana', child: Text('Esta semana')),
                  const PopupMenuItem(value: 'Semana pasada', child: Text('Semana pasada')),
                  const PopupMenuItem(value: 'Este mes', child: Text('Este mes')),
                  const PopupMenuItem(value: 'Mes pasado', child: Text('Mes pasado')),
                  const PopupMenuItem(value: 'Este año', child: Text('Este año')),
                ],
          ),

          IconButton(
            icon: const Icon(Icons.clear, color: AppTheme.neutroColor),
            onPressed: _clearFilters,
            tooltip: 'Limpiar todos los filtros',
          ),
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
                    ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No hay liquidaciones en este rango'),
                          Text('Prueba con otros filtros', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        Expanded(
                          child:
                              _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : filteredLiquidations.isEmpty
                                  ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text('No hay liquidaciones en este rango'),
                                        Text(
                                          'Prueba con otros filtros',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                  : Column(
                                    children: [
                                      Expanded(
                                        child: Scrollbar(
                                          controller: _horizontalScrollController,
                                          thumbVisibility: true,
                                          trackVisibility: true,
                                          child: SingleChildScrollView(
                                            controller: _horizontalScrollController,
                                            scrollDirection: Axis.horizontal,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minWidth: MediaQuery.of(context).size.width,
                                              ),
                                              child: DataTable(
                                                columnSpacing: 20,
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
                                                  ...filteredLiquidations
                                                      .skip(_currentPage * _rowsPerPage)
                                                      .take(_rowsPerPage)
                                                      .map((doc) {
                                                        final data =
                                                            doc.data() as Map<String, dynamic>;
                                                        return DataRow(
                                                          cells:
                                                              visibleColumns.map((col) {
                                                                final value = col.getValue(doc);
                                                                final displayValue =
                                                                    value is DateTime
                                                                        ? DateFormat(
                                                                          'yyyy-MM-dd',
                                                                        ).format(value)
                                                                        : (col.key == 'payments' &&
                                                                                value is num
                                                                            ? value
                                                                                .toInt()
                                                                                .toString()
                                                                            : (col.numeric &&
                                                                                    value is num
                                                                                ? currencyFormat
                                                                                    .format(value)
                                                                                : value
                                                                                    .toString()));
                                                                return DataCell(Text(displayValue));
                                                              }).toList(),
                                                        );
                                                      }),
                                                  DataRow(
                                                    color: WidgetStateProperty.all(
                                                      Colors.grey[300],
                                                    ),
                                                    cells:
                                                        visibleColumns.map((col) {
                                                          String text = '';
                                                          switch (col.key) {
                                                            case 'totalCollected':
                                                              text = currencyFormat.format(
                                                                totals['totalCollected'],
                                                              );
                                                              break;
                                                            case 'alimentaciónDiscount':
                                                              text = currencyFormat.format(
                                                                totals['totalAlimentacion'],
                                                              );
                                                              break;
                                                            case 'gasolineDiscount':
                                                              text = currencyFormat.format(
                                                                totals['totalGasoline'],
                                                              );
                                                              break;
                                                            case 'repuestosDiscount':
                                                              text = currencyFormat.format(
                                                                totals['totalRepuestos'],
                                                              );
                                                              break;
                                                            case 'tallerDiscount':
                                                              text = currencyFormat.format(
                                                                totals['totalTaller'],
                                                              );
                                                              break;
                                                            case 'otrosDiscount':
                                                              text = currencyFormat.format(
                                                                totals['totalOtros'],
                                                              );
                                                              break;
                                                            case 'discountTotal':
                                                              text = currencyFormat.format(
                                                                totals['totalDiscount'],
                                                              );
                                                              break;
                                                            case 'netTotal':
                                                              text = currencyFormat.format(
                                                                totals['totalNet'],
                                                              );
                                                              break;
                                                            case 'payments':
                                                              text =
                                                                  totals['totalPayments']
                                                                      .toString();
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
                                      _buildPaginationControls(),
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
