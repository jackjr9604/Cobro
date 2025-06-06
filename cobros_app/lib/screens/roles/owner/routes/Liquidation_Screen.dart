import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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

class _DiscountItem {
  TextEditingController controller;
  String type;

  _DiscountItem({required this.controller, required this.type});
}

class _CollectorLiquidationScreenState extends State<CollectorLiquidationScreen> {
  DateTime? selectedDate;
  List<_DiscountItem> _discountItems = [
    _DiscountItem(controller: TextEditingController(), type: 'Gasolina'),
  ];

  double totalCollected = 0;
  List<Map<String, dynamic>> paymentsOfDay = [];
  double discountTotal = 0;
  double netTotal = 0;
  String officeId = '';
  double collectorBase = 0;
  bool isLoading = false;
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  late TextEditingController _baseController;
  double _originalBase = 0;

  @override
  void initState() {
    super.initState();
    _baseController = TextEditingController(); // Inicialización correcta aquí
    for (var item in _discountItems) {
      item.controller.addListener(_updateTotals);
    }
    _getOfficeId();
  }

  Future<void> _getOfficeId() async {
    setState(() => isLoading = true);
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(widget.collectorId).get();
      final data = userDoc.data();
      setState(() {
        officeId = data?['officeId'] ?? '';
        collectorBase = (data?['base'] ?? 0).toDouble();
        _originalBase = collectorBase; // Guarda la base original
        _baseController.text = collectorBase.toStringAsFixed(0); // Formatea sin decimales
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateTotals() {
    double total = 0;
    for (var item in _discountItems) {
      total += double.tryParse(item.controller.text) ?? 0;
    }
    setState(() {
      discountTotal = total;
      netTotal = totalCollected - discountTotal + _originalBase; // Usa la base original aquí
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        isLoading = true;
      });
      await _fetchPayments();
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchPayments() async {
    setState(() => isLoading = true);
    try {
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

        for (var entry in data.entries) {
          if (entry.key.startsWith('pay') && entry.value is Map<String, dynamic>) {
            final pay = entry.value as Map<String, dynamic>;
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
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _finalizeLiquidation() async {
    if (isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Liquidación'),
            content: const Text('¿Estás seguro de finalizar esta liquidación?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);
    try {
      // Obtiene el nuevo valor de base del controlador
      final newBase = double.tryParse(_baseController.text) ?? _originalBase;

      // Actualiza la base del cobrador con el nuevo valor
      await FirebaseFirestore.instance.collection('users').doc(widget.collectorId).update({
        'base': newBase,
      });

      final uuid = Uuid();
      final String liquidationId = uuid.v4();
      final liquidationDate = selectedDate ?? DateTime.now();

      // Resto del código de liquidación...
      final batch = FirebaseFirestore.instance.batch();
      for (var payment in paymentsOfDay) {
        batch.update(payment['creditRef'], {'${payment['payKey']}.isActive': false});
      }
      await batch.commit();

      final liquidationData = {
        'collectorId': widget.collectorId,
        'collectorName': widget.collectorName,
        'officeId': officeId,
        'date': liquidationDate,
        'totalCollected': totalCollected,
        'collectorBase': _originalBase, // Guarda la base original en la liquidación
        'newBase': newBase, // Guarda la nueva base como campo separado
        'discounts': {
          for (var item in _discountItems) item.type: (double.tryParse(item.controller.text) ?? 0),
        },
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Liquidación realizada con éxito. Base actualizada.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        selectedDate = null;
        paymentsOfDay = [];
        totalCollected = 0;
        discountTotal = 0;
        netTotal = 0;
        _discountItems = [
          _DiscountItem(type: 'Gasolina', controller: TextEditingController())
            ..controller.addListener(_updateTotals),
        ];
        // Actualiza la base local para futuras liquidaciones
        _originalBase = newBase;
        collectorBase = newBase;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildSummaryCard(String title, List<Widget> children, {Color? borderColor}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor ?? Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var item in _discountItems) {
      item.controller.removeListener(_updateTotals);
      item.controller.dispose();
    }
    _baseController.dispose(); // Disposición segura
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Liquidar a ${widget.collectorName}'),
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          if (selectedDate != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchPayments,
              tooltip: 'Actualizar',
            ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : selectedDate == null
              ? _buildDateSelectionView()
              : paymentsOfDay.isEmpty
              ? _buildNoPaymentsView()
              : _buildLiquidationForm(),
    );
  }

  Widget _buildDateSelectionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month,
            size: 80,
            color: Theme.of(context).primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Selecciona una fecha para liquidar',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CalendarDatePicker(
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                onDateChanged: (date) async {
                  setState(() {
                    selectedDate = date;
                  });
                  await _fetchPayments();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPaymentsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            'No hay pagos registrados para esta fecha',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CalendarDatePicker(
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                onDateChanged: (date) async {
                  setState(() {
                    selectedDate = date;
                  });
                  await _fetchPayments();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado con fecha
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, d MMMM y', 'es').format(selectedDate!),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _selectDate(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Resumen de pagos
          _buildSummaryCard('Resumen de Pagos (${paymentsOfDay.length})', [
            _buildAmountRow('Total recolectado:', totalCollected),
            _buildAmountRow('Base del cobrador:', _originalBase),
            const Divider(height: 20),
            _buildAmountRow('Total descuentos:', discountTotal, valueColor: Colors.red),
            const SizedBox(height: 8),
            _buildAmountRow(
              'Total neto:',
              netTotal,
              valueColor: netTotal >= 0 ? Colors.green : Colors.red,
            ),
          ], borderColor: Colors.blue.shade50),
          const SizedBox(height: 16),

          // Lista de pagos
          _buildSummaryCard('Detalle de Pagos', [
            ...paymentsOfDay.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Text(
                        p['clientName'].toString().substring(0, 1),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['clientName'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('h:mm a', 'es').format(p['date']),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currencyFormat.format(p['amount']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ], borderColor: Colors.green.shade50),
          const SizedBox(height: 16),

          //Base
          Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(1),
                          child: Text(
                            'Nueva Base: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12), // Espacio entre el texto y el campo
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _baseController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // Actualiza el valor local inmediatamente
                        final newBase = double.tryParse(value) ?? collectorBase;
                        setState(() {
                          collectorBase = newBase;
                          _updateTotals(); // Esto actualizará el netTotal con la nueva base
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Descuentos
          _buildSummaryCard('Descuentos', [
            ...List.generate(
              _discountItems.length,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _discountItems[i].type,
                        items:
                            ['Gasolina', 'Alimentación', 'Taller', 'Repuestos', 'Otros']
                                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _discountItems[i].type = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _discountItems[i].controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Valor',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _updateTotals(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _discountItems[i].controller.dispose();
                          _discountItems.removeAt(i);
                          _updateTotals();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Agregar descuento'),
              onPressed: () {
                setState(() {
                  final controller = TextEditingController();
                  controller.addListener(_updateTotals);
                  _discountItems.add(_DiscountItem(controller: controller, type: 'Gasolina'));
                });
              },
            ),
          ], borderColor: Colors.orange.shade50),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon:
                isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                    : const Icon(Icons.check_circle),
            label: const Text('Finalizar Liquidación'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
            ),
            onPressed: isLoading ? null : _finalizeLiquidation,
          ),
        ],
      ),
    );
  }
}
