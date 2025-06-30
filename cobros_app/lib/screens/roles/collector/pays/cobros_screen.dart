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
  final Map<String, TextEditingController> controllers = {};
  late String _collectorUid;
  late String _ownerUid;
  late String _officeId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeCredits = [];
  List<int> _creditOrder = [];
  bool _isEditingOrder = false;
  List<Map<String, dynamic>> _localOrderedCredits = [];
  List<int> _originalOrderValues = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      _collectorUid = currentUser.uid;

      final collectorDoc =
          await FirebaseFirestore.instance.collection('users').doc(_collectorUid).get();

      if (!collectorDoc.exists) return;

      _ownerUid = collectorDoc.data()?['createdBy'] ?? '';
      if (_ownerUid.isEmpty) return;

      final officesQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_ownerUid)
              .collection('offices')
              .limit(1)
              .get();

      if (officesQuery.docs.isEmpty) return;

      _officeId = officesQuery.docs.first.id;
      await _loadActiveCredits();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActiveCredits() async {
    try {
      final clientsQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_ownerUid)
              .collection('offices')
              .doc(_officeId)
              .collection('clients')
              .where('createdBy', isEqualTo: _collectorUid)
              .get();

      List<Map<String, dynamic>> allActiveCredits = [];

      for (final clientDoc in clientsQuery.docs) {
        final clientId = clientDoc.id;
        final clientData = clientDoc.data();

        final creditsQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_ownerUid)
                .collection('offices')
                .doc(_officeId)
                .collection('clients')
                .doc(clientId)
                .collection('credits')
                .where('isActive', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .get();

        for (final creditDoc in creditsQuery.docs) {
          final creditData = creditDoc.data();
          // Precalculamos la información aquí para evitar múltiples llamadas
          final creditInfo = await _calculateCreditInfo({
            ...creditData,
            'creditId': creditDoc.id,
            'clientId': clientId,
          });

          allActiveCredits.add({
            ...creditData,
            'creditId': creditDoc.id,
            'clientId': clientId,
            'clientName': clientData['clientName'] ?? 'Sin nombre',
            'clientPhone': clientData['phone'] ?? 'Sin teléfono',
            'creditInfo': creditInfo, // Almacenamos la información calculada
          });
        }
      }

      allActiveCredits.sort((a, b) {
        final aOrder = (a['order'] as int?) ?? 0;
        final bOrder = (b['order'] as int?) ?? 0;

        if (aOrder == 0 && bOrder == 0) {
          final aDate = a['createdAt'] ?? Timestamp.now();
          final bDate = b['createdAt'] ?? Timestamp.now();
          return bDate.compareTo(aDate);
        } else if (aOrder == 0) {
          return -1;
        } else if (bOrder == 0) {
          return 1;
        } else {
          return aOrder.compareTo(bOrder);
        }
      });

      setState(() {
        _activeCredits = allActiveCredits;
        _localOrderedCredits = List.from(allActiveCredits);
        _originalOrderValues = allActiveCredits.map((c) => (c['order'] as int?) ?? 0).toList();
      });
    } catch (e) {
      debugPrint('Error loading credits: $e');
    }
  }

  // 2. Simplifica el builder principal
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos Activos'),
        actions: [
          IconButton(
            icon: Icon(_isEditingOrder ? Icons.close : Icons.edit),
            onPressed: _toggleEditOrder,
            tooltip: _isEditingOrder ? 'Cancelar edición' : 'Editar orden',
          ),
          if (_isEditingOrder)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveCreditOrder,
              tooltip: 'Guardar orden',
            ),
          IconButton(
            icon: const Icon(Icons.credit_card_off),
            onPressed: () => _navigateToInactiveCredits(context),
            tooltip: 'Ver créditos cerrados',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _activeCredits.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _loadActiveCredits,
                child:
                    _isEditingOrder
                        ? ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          padding: const EdgeInsets.all(8),
                          itemCount: _localOrderedCredits.length,
                          itemBuilder: (context, index) {
                            final creditData = _localOrderedCredits[index];
                            return _buildCreditItem(context, creditData, index, isEditing: true);
                          },
                          onReorder: _reorderCredit,
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _activeCredits.length,
                          itemBuilder: (context, index) {
                            final creditData = _activeCredits[index];
                            return _buildCreditItem(context, creditData, index, isEditing: false);
                          },
                        ),
              ),
    );
  }

  // 3. Nuevo método para construir los ítems de crédito
  Widget _buildCreditItem(
    BuildContext context,
    Map<String, dynamic> creditData,
    int index, {
    required bool isEditing,
  }) {
    final creditInfo = creditData['creditInfo'] as Map<String, dynamic>;
    final overdueInfo = _calculateOverdueInfo(creditData);

    return Row(
      key: ValueKey(creditData['creditId']),
      children: [
        Expanded(
          child: Card(
            elevation: isEditing ? 4 : 2,
            margin: const EdgeInsets.symmetric(vertical: 8),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _getStatusColor(overdueInfo['status']), width: 2),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getStatusColor(overdueInfo['status']).withOpacity(0.05),
                    _getStatusColor(overdueInfo['status']).withOpacity(0.02),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con nombre del cliente y estado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(overdueInfo['status']),
                              child: Text(
                                creditData['clientName'].substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              creditData['clientName'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(creditData['clientPhone']),
                          ),
                        ),
                        _buildOverdueIndicator(overdueInfo),
                        SizedBox(width: 8),
                        _buildOrderIndicator(index, context, isEditing: isEditing),
                      ],
                    ),

                    const Divider(),

                    // Información del crédito
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Valor del crédito
                          _buildInfoRow(
                            'Valor del crédito:',
                            '\$${NumberFormat('#,##0').format(creditInfo['totalCreditValue'])}',
                            isBold: true,
                          ),
                          const SizedBox(height: 8),

                          // Total abonado (nueva fila)
                          _buildInfoRow(
                            'Total abonado:',
                            '\$${NumberFormat('#,##0').format(creditInfo['totalPaid'])}',
                            valueColor: Colors.green, // Color verde para valores positivos
                            isBold: true,
                          ),
                          const SizedBox(height: 8),

                          // Saldo
                          _buildInfoRow(
                            'Saldo:',
                            '\$${NumberFormat('#,##0').format(creditInfo['remainingAmount'])}',
                            valueColor:
                                creditInfo['remainingAmount'] > 0 ? Colors.red : Colors.green,
                            isBold: true,
                          ),
                          const SizedBox(height: 8),

                          // Cuotas restantes
                          _buildInfoRow(
                            'Cuotas restantes:',
                            '${creditInfo['cuotasRestantes']}/${creditInfo['totalCuotas']}',
                          ),
                          const SizedBox(height: 8),

                          // Fecha final estimada
                          if (creditInfo['fechaFinal'] != null)
                            Column(
                              children: [
                                _buildInfoRow(
                                  'Fecha final estimada:',
                                  DateFormat('dd/MM/yyyy').format(creditInfo['fechaFinal']),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),

                          // Barra de progreso
                          _buildProgressBar(
                            creditInfo['progress'] ?? 0,
                            creditInfo['cuotasPagadas'] ?? 0,
                            creditInfo['totalCuotas'] ?? 1,
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.visibility, size: 20),
                          label: const Text('Detalles'),
                          onPressed: () => _showCreditDetails(context, creditData),
                        ),
                        if ((creditInfo['remainingAmount'] ?? 0) <= 0)
                          FutureBuilder<bool>(
                            future: _canCloseCredit(creditData['creditId'], creditData['clientId']),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }
                              if (snapshot.data == true) {
                                return TextButton.icon(
                                  icon: const Icon(Icons.lock, size: 20),
                                  label: const Text('Cerrar Crédito'),
                                  onPressed:
                                      () => _closeCredit(
                                        creditData['creditId'],
                                        creditData['clientId'],
                                      ),
                                );
                              }
                              return TextButton.icon(
                                icon: const Icon(Icons.payment, size: 20),
                                label: const Text('Pagar'),
                                onPressed: null,
                                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                              );
                            },
                          )
                        else
                          TextButton.icon(
                            icon: const Icon(Icons.payment, size: 20),
                            label: const Text('Pagar'),
                            onPressed: () => _registerPayment(context, creditData),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isEditing) _buildDragHandleWithSeparator(index),
      ],
    );
  }

  // Método para calcular la información del crédito
  Future<Map<String, dynamic>> _calculateCreditInfo(Map<String, dynamic> creditData) async {
    final creditAmount = (creditData['credit'] ?? 0).toDouble();
    final interestPercent = (creditData['interest'] ?? 0).toDouble();
    final totalCreditValue = creditAmount + (creditAmount * interestPercent / 100);
    final cuot = (creditData['cuot'] ?? 1).toInt();
    final method = creditData['method'] ?? 'Diario';

    // Obtener TODOS los pagos (sin filtrar por isActive)
    final paymentsQuery =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_ownerUid)
            .collection('offices')
            .doc(_officeId)
            .collection('clients')
            .doc(creditData['clientId'])
            .collection('credits')
            .doc(creditData['creditId'])
            .collection('payments')
            .get();

    // Calcular total pagado sumando todos los pagos (activos e inactivos)
    final totalPaid = paymentsQuery.docs.fold(
      0.0,
      (sum, doc) => sum + (doc.data()['amount'] ?? 0).toDouble(),
    );

    final remainingAmount = totalCreditValue - totalPaid;
    final cuotasPagadas = paymentsQuery.size;
    final cuotasRestantes = cuot - cuotasPagadas;
    final progress = cuot > 0 ? cuotasPagadas / cuot : 0;

    // Calcular fechas
    DateTime? fechaFinal;
    DateTime? lastPaymentDate = creditData['lastPaymentDate']?.toDate();
    DateTime? createdAt = creditData['createdAt']?.toDate();

    if (lastPaymentDate == null && createdAt != null) {
      lastPaymentDate = createdAt;
    }

    if (lastPaymentDate != null) {
      final diasEntreCuotas = switch (method) {
        'Semanal' => 7,
        'Quincenal' => 15,
        'Mensual' => 30,
        _ => 1,
      };

      fechaFinal = lastPaymentDate.add(Duration(days: cuot * diasEntreCuotas));
    }

    return {
      'totalCreditValue': totalCreditValue,
      'totalPaid': totalPaid,
      'remainingAmount': remainingAmount,
      'cuotasPagadas': cuotasPagadas,
      'cuotasRestantes': cuotasRestantes,
      'totalCuotas': cuot,
      'fechaFinal': fechaFinal,
      'progress': progress,
      // Incluir el total pagado calculado
    };
  }

  // Widget para la barra de progreso
  Widget _buildProgressBar(double progress, int cuotasPagadas, int totalCuotas) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0), // Asegurar que esté entre 0 y 1
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 1 ? Colors.green : Theme.of(context).primaryColor,
          ),
          minHeight: 10,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 4),
        Text(
          '$cuotasPagadas/$totalCuotas cuotas (${(progress * 100).toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // Primero verifica si el campo createdAt existe antes de ordenar

  Future<void> _toggleEditOrder() async {
    if (_isEditingOrder) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Descartar cambios'),
              content: const Text('¿Estás seguro de salir sin guardar los cambios en el orden?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Descartar'),
                ),
              ],
            ),
      );

      if (confirm != true) return;
    }

    setState(() {
      _isEditingOrder = !_isEditingOrder;
      if (_isEditingOrder) {
        _localOrderedCredits = List.from(_activeCredits);
        for (int i = 0; i < _localOrderedCredits.length; i++) {
          _localOrderedCredits[i]['localOrder'] = i + 1;
        }
      }
    });
  }

  void _reorderCredit(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final movedCredit = _localOrderedCredits.removeAt(oldIndex);
      _localOrderedCredits.insert(newIndex, movedCredit);

      // Animación suave
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            // Actualizar valores de orden localmente
            for (int i = 0; i < _localOrderedCredits.length; i++) {
              _localOrderedCredits[i]['localOrder'] = i + 1;
            }
          });
        }
      });
    });
  }

  Future<void> _saveCreditOrder() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();

      for (int i = 0; i < _localOrderedCredits.length; i++) {
        final credit = _localOrderedCredits[i];
        final creditRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_ownerUid)
            .collection('offices')
            .doc(_officeId)
            .collection('clients')
            .doc(credit['clientId'])
            .collection('credits')
            .doc(credit['creditId']);

        batch.update(creditRef, {'order': i + 1, 'updatedAt': now});
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Orden guardado correctamente')));

        // Actualizar la lista activa con el nuevo orden
        setState(() {
          _activeCredits = List.from(_localOrderedCredits);
          _isEditingOrder = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar orden: $e')));
      }
    }
  }

  // Método de fallback
  Future<void> _loadCreditsWithoutOrder() async {
    try {
      final clientsQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_ownerUid)
              .collection('offices')
              .doc(_officeId)
              .collection('clients')
              .where('createdBy', isEqualTo: _collectorUid)
              .get();

      List<Map<String, dynamic>> allActiveCredits = [];

      for (final clientDoc in clientsQuery.docs) {
        final clientId = clientDoc.id;
        final clientData = clientDoc.data();

        final creditsQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_ownerUid)
                .collection('offices')
                .doc(_officeId)
                .collection('clients')
                .doc(clientId)
                .collection('credits')
                .where('isActive', isEqualTo: true)
                .get();

        for (final creditDoc in creditsQuery.docs) {
          final creditData = creditDoc.data();
          allActiveCredits.add({
            ...creditData,
            'creditId': creditDoc.id,
            'clientId': clientId,
            'clientName': clientData['clientName'] ?? 'Sin nombre',
            'clientPhone': clientData['phone'] ?? 'Sin teléfono',
            'createdAt': creditData['createdAt'] ?? Timestamp.now(), // Valor por defecto
          });
        }
      }

      // Ordenar localmente por createdAt si está disponible
      allActiveCredits.sort((a, b) {
        final aDate = a['createdAt'] ?? Timestamp.now();
        final bDate = b['createdAt'] ?? Timestamp.now();
        return bDate.compareTo(aDate); // Orden descendente
      });

      setState(() => _activeCredits = allActiveCredits);
    } catch (e) {
      debugPrint('Error loading credits without order: $e');
    }
  }

  // Función para actualizar el orden de los créditos

  /// Widget para el indicador de orden editable
  Widget _buildOrderIndicator(int index, BuildContext context, {required bool isEditing}) {
    final displayOrder = index + 1; // Mostrar siempre el orden basado en la posición

    return Tooltip(
      message: isEditing ? 'Orden editable' : 'Orden',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isEditing
                  ? Colors.orange.withOpacity(0.1)
                  : Theme.of(context).primaryColor.withOpacity(0.1),
          border: Border.all(
            color: isEditing ? Colors.orange : Theme.of(context).primaryColor,
            width: 2,
          ),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(2, 2))],
        ),
        child: Center(
          child: Text(
            '$displayOrder',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isEditing ? Colors.orange : Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandleWithSeparator(int index) {
    return Container(
      width: 48, // Aumenté el ancho de 40 a 48
      decoration: BoxDecoration(
        border: const Border(left: BorderSide(color: Colors.grey, width: 1)),
        color: Colors.grey[100], // Fondo gris claro
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.drag_handle,
                color: Colors.grey,
                size: 24, // Icono más grande
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerPayment(BuildContext context, Map<String, dynamic> creditData) async {
    final creditId = creditData['creditId'];
    final clientId = creditData['clientId'];

    // Cálculos del crédito
    final creditAmount = (creditData['credit'] ?? 0).toDouble();
    final interestPercent = (creditData['interest'] ?? 0).toDouble();
    final totalCreditValue = creditAmount + (creditAmount * interestPercent / 100);
    final numberOfCuotas = (creditData['cuot'] ?? 1).toDouble();
    final valorAbonoDefault =
        ((creditAmount * interestPercent / 100) + creditAmount) / numberOfCuotas;

    // Obtener pagos existentes
    final paymentsQuery =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_ownerUid)
            .collection('offices')
            .doc(_officeId)
            .collection('clients')
            .doc(clientId)
            .collection('credits')
            .doc(creditId)
            .collection('payments')
            .where('isActive', isEqualTo: true)
            .get();

    // Calcular total abonado
    final totalAbonado = paymentsQuery.docs.fold(
      0.0,
      (sum, doc) => sum + ((doc.data())['amount'] ?? 0).toDouble(),
    );

    // Calcular saldo restante
    final saldoRestante = totalCreditValue - totalAbonado;

    final controller = TextEditingController(text: valorAbonoDefault.toStringAsFixed(0));
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Registrar pago'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Saldo restante: \$${NumberFormat('#,##0', 'es_CO').format(saldoRestante)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: saldoRestante <= 0 ? Colors.green : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Valor del abono',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => setState(() => selectedDate = DateTime.now()),
                            child: const Text('Hoy'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed:
                                () => setState(
                                  () => selectedDate = selectedDate.add(const Duration(days: 1)),
                                ),
                            child: const Text('Mañana'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) setState(() => selectedDate = date);
                            },
                          ),
                        ],
                      ),
                      Text('Fecha: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                      if (saldoRestante <= 0) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Crédito pagado completamente',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Puedes cerrarlo manualmente cuando todos los pagos estén liquidados',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(controller.text);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Valor inválido')));
                          return;
                        }
                        if (amount > saldoRestante && saldoRestante > 0) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('El pago excede el saldo')));
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
          ),
    );

    if (result == true) {
      final amount = double.parse(controller.text);
      final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
      final batch = FirebaseFirestore.instance.batch();

      // 1. Crear documento de pago
      final paymentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_ownerUid)
          .collection('offices')
          .doc(_officeId)
          .collection('clients')
          .doc(clientId)
          .collection('credits')
          .doc(creditId)
          .collection('payments')
          .doc(paymentId);

      batch.set(paymentRef, {
        'amount': amount,
        'date': Timestamp.fromDate(selectedDate),
        'isActive': true, // Se marca como activo inicialmente
        'timestamp': FieldValue.serverTimestamp(),
        'collectorId': _collectorUid,
        'paymentMethod': 'Efectivo',
        'receiptNumber': 'RC-${paymentId.substring(0, 5)}',
        'notes': '',
      });

      // 2. Actualizar crédito
      final creditRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_ownerUid)
          .collection('offices')
          .doc(_officeId)
          .collection('clients')
          .doc(clientId)
          .collection('credits')
          .doc(creditId);

      batch.update(creditRef, {
        'lastPaymentDate': Timestamp.fromDate(selectedDate),
        'nextPaymentIndex': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'totalPaid': FieldValue.increment(amount),
      });

      // En tu función _registerPayment, modifica la parte final:
      try {
        await batch.commit();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pago registrado correctamente')));
        }

        // Recargar los créditos después del pago
        await _loadActiveCredits();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al registrar pago: $e')));
        }
      }
    }
  }

  // Agrega esta nueva función para verificar si se puede cerrar el crédito
  Future<bool> _canCloseCredit(String creditId, String clientId) async {
    try {
      // Verificar que no haya pagos activos
      final paymentsQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_ownerUid)
              .collection('offices')
              .doc(_officeId)
              .collection('clients')
              .doc(clientId)
              .collection('credits')
              .doc(creditId)
              .collection('payments')
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

      return paymentsQuery.docs.isEmpty;
    } catch (e) {
      debugPrint('Error verificando cierre de crédito: $e');
      return false;
    }
  }

  // Modifica la función _closeCredit para verificar antes de cerrar
  Future<void> _closeCredit(String creditId, String clientId) async {
    final canClose = await _canCloseCredit(creditId, clientId);
    if (!canClose) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede cerrar el crédito. Asegúrate que:')),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('1. El saldo esté en cero')));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('2. Todos los pagos estén liquidados')));
      }
      return;
    }

    final batch = FirebaseFirestore.instance.batch();

    final creditRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_ownerUid)
        .collection('offices')
        .doc(_officeId)
        .collection('clients')
        .doc(clientId)
        .collection('credits')
        .doc(creditId);

    batch.update(creditRef, {
      'isActive': false,
      'status': 'completed',
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'closedBy': _collectorUid,
    });

    final clientRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_ownerUid)
        .collection('offices')
        .doc(_officeId)
        .collection('clients')
        .doc(clientId);

    batch.update(clientRef, {'updatedAt': FieldValue.serverTimestamp()});

    try {
      await batch.commit();
      await _loadActiveCredits();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Crédito cerrado con éxito')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cerrar crédito: $e')));
      }
    }
  }

  // Agrega esta función para liquidar pagos
  Future<void> _liquidatePayment(
    BuildContext context,
    String creditId,
    String clientId,
    String paymentId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Liquidar Pago'),
            content: const Text('¿Estás seguro de marcar este pago como liquidado?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Liquidar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_ownerUid)
            .collection('offices')
            .doc(_officeId)
            .collection('clients')
            .doc(clientId)
            .collection('credits')
            .doc(creditId)
            .collection('payments')
            .doc(paymentId)
            .update({
              'isActive': false,
              'liquidatedAt': FieldValue.serverTimestamp(),
              'liquidatedBy': _collectorUid,
            });

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pago liquidado correctamente')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al liquidar pago: $e')));
        }
      }
    }
  }

  Map<String, dynamic> _calculateOverdueInfo(Map<String, dynamic> creditData) {
    final now = DateTime.now();
    int daysOverdue = 0;
    DateTime? nextPaymentDate;
    int? nextPaymentIndex;
    double? nextPaymentAmount;
    String overdueStatus = 'al día';

    try {
      final paymentSchedule =
          (creditData['paymentSchedule'] as List?)
              ?.map((date) => date is Timestamp ? date.toDate() : DateTime.parse(date.toString()))
              .toList() ??
          [];

      nextPaymentIndex = (creditData['nextPaymentIndex'] as int?) ?? 0;
      final creditAmount = (creditData['credit'] ?? 0).toDouble();
      final interestPercent = (creditData['interest'] ?? 0).toDouble();
      final totalCreditValue = creditAmount + (creditAmount * interestPercent / 100);
      final numberOfCuotas = (creditData['cuot'] ?? 1).toDouble();
      nextPaymentAmount = totalCreditValue / numberOfCuotas;

      if (nextPaymentIndex < paymentSchedule.length) {
        nextPaymentDate = paymentSchedule[nextPaymentIndex];
        if (now.isAfter(nextPaymentDate)) {
          daysOverdue = now.difference(nextPaymentDate).inDays;
          overdueStatus = _getOverdueStatus(daysOverdue);
        } else {
          overdueStatus = 'próximo';
        }
      }
    } catch (e) {
      debugPrint('Error calculating overdue info: $e');
    }

    return {
      'daysOverdue': daysOverdue,
      'nextPaymentDate': nextPaymentDate,
      'nextPaymentIndex': nextPaymentIndex,
      'nextPaymentAmount': nextPaymentAmount,
      'status': overdueStatus,
    };
  }

  String _getOverdueStatus(int daysOverdue) {
    if (daysOverdue <= 0) return 'al día';
    if (daysOverdue <= 7) return 'moroso leve';
    if (daysOverdue <= 15) return 'moroso moderado';
    if (daysOverdue <= 30) return 'moroso severo';
    return 'moroso crítico';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'al día':
        return Colors.green;
      case 'próximo':
        return Colors.blue;
      case 'moroso leve':
        return Colors.orange;
      case 'moroso moderado':
        return Colors.deepOrange;
      case 'moroso severo':
        return Colors.red;
      case 'moroso crítico':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOverdueIndicator(Map<String, dynamic> overdueInfo) {
    final status = overdueInfo['status'];
    final daysOverdue = overdueInfo['daysOverdue'];
    final nextPaymentDate = overdueInfo['nextPaymentDate'];
    final nextPaymentAmount = overdueInfo['nextPaymentAmount'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor(status), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getStatusIcon(status), size: 16, color: _getStatusColor(status)),
              const SizedBox(width: 6),
              Text(
                status.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(status)),
              ),
            ],
          ),
          if (daysOverdue > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$daysOverdue días',
              style: TextStyle(fontSize: 12, color: _getStatusColor(status)),
            ),
          ],
          if (nextPaymentDate != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yy').format(nextPaymentDate),
              style: TextStyle(fontSize: 10, color: _getStatusColor(status)),
            ),
          ],
          if (nextPaymentAmount != null && status == 'próximo') ...[
            const SizedBox(height: 4),
            Text(
              '\$${nextPaymentAmount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 10, color: _getStatusColor(status)),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'al día':
        return Icons.check_circle;
      case 'próximo':
        return Icons.calendar_today;
      case 'moroso leve':
        return Icons.warning_amber;
      case 'moroso moderado':
        return Icons.warning;
      case 'moroso severo':
        return Icons.error;
      case 'moroso crítico':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  Color? _getCardColor(int daysOverdue) {
    if (daysOverdue > 30) return Colors.red[900];
    if (daysOverdue > 15) return Colors.red[600];
    if (daysOverdue > 0) return Colors.red[300];
    return null;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes créditos activos',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadActiveCredits,
            icon: const Icon(Icons.refresh),
            label: const Text('Intentar nuevamente'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreditDetails(BuildContext context, Map<String, dynamic> creditData) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CreditDetailScreen(
              userId: _ownerUid,
              officeId: _officeId,
              clientId: creditData['clientId'],
              creditId: creditData['creditId'],
            ),
      ),
    );
  }

  void _navigateToInactiveCredits(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => InactiveCreditsScreen(
              userId: _ownerUid,
              officeId: _officeId,
              collectorId: _collectorUid,
            ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: valueColor?.withOpacity(0.1) ?? Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
