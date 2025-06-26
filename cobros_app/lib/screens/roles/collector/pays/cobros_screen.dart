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
  List<int> _creditOrder = []; // Lista para mantener el orden de los créditos

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

  // Primero verifica si el campo createdAt existe antes de ordenar
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

        // Primero verificar si hay créditos con createdAt
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

        // Si no hay resultados con orderBy, intentar sin él
        if (creditsQuery.docs.isEmpty) {
          continue;
        }

        // Verificar si los créditos tienen el campo createdAt
        final firstCredit = creditsQuery.docs.first.data();
        if (!firstCredit.containsKey('createdAt')) {
          // Actualizar créditos existentes para agregar createdAt
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in creditsQuery.docs) {
            batch.update(doc.reference, {'createdAt': FieldValue.serverTimestamp()});
          }
          await batch.commit();
        }

        // Ahora hacer la consulta con orderBy
        final orderedCreditsQuery =
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

        for (final creditDoc in orderedCreditsQuery.docs) {
          final creditData = creditDoc.data();
          allActiveCredits.add({
            ...creditData,
            'creditId': creditDoc.id,
            'clientId': clientId,
            'clientName': clientData['clientName'] ?? 'Sin nombre',
            'clientPhone': clientData['phone'] ?? 'Sin teléfono',
          });
        }
      }

      setState(() => _activeCredits = allActiveCredits);
    } catch (e) {
      debugPrint('Error loading credits: $e');
      // Fallback a consulta sin ordenar si hay error
      await _loadCreditsWithoutOrder();
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
  void _updateCreditOrder(int oldPosition, int newPosition) {
    setState(() {
      // Ajustar newPosition para que esté dentro de los límites
      newPosition = newPosition.clamp(1, _activeCredits.length);

      // Crear una copia de la lista original
      final List<Map<String, dynamic>> reorderedCredits = List.from(_activeCredits);

      // Mover el elemento a su nueva posición
      final Map<String, dynamic> creditToMove = reorderedCredits.removeAt(oldPosition);
      reorderedCredits.insert(newPosition - 1, creditToMove);

      // Actualizar los números de orden
      _creditOrder = List.generate(reorderedCredits.length, (index) => index + 1);

      // Actualizar la lista principal
      _activeCredits = reorderedCredits;
    });
  }

  /// Widget para el indicador de orden editable
  Widget _buildOrderIndicator(int index, BuildContext context) {
    return GestureDetector(
      onTap: () => _showEditOrderDialog(context, index),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
        ),
        child: Center(
          child: Text(
            (index + 1).toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditOrderDialog(BuildContext context, int currentIndex) async {
    final orderController = TextEditingController(text: (currentIndex + 1).toString());

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cambiar orden'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Actual orden: ${currentIndex + 1}'),
                const SizedBox(height: 16),
                TextField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo orden',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              TextButton(
                onPressed: () {
                  final newOrder = int.tryParse(orderController.text);
                  if (newOrder != null && newOrder >= 1 && newOrder <= _activeCredits.length) {
                    _updateCreditOrder(currentIndex, newOrder);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  // Reemplaza tu función _registerPayment con esta versión modificada
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Cargando créditos...', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos Activos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.credit_card_off),
            onPressed: () => _navigateToInactiveCredits(context),
            tooltip: 'Ver créditos cerrados',
          ),
        ],
      ),
      body:
          _activeCredits.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _loadActiveCredits,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _activeCredits.length,
                  itemBuilder: (context, index) {
                    final creditData = _activeCredits[index];
                    final overdueInfo = _calculateOverdueInfo(creditData);
                    final daysOverdue = overdueInfo['daysOverdue'] as int;

                    final creditAmount = (creditData['credit'] ?? 0).toDouble();
                    final interestPercent = (creditData['interest'] ?? 0).toDouble();
                    final totalCreditValue = creditAmount + (creditAmount * interestPercent / 100);
                    final totalPaid = (creditData['totalPaid'] ?? 0).toDouble();
                    final remainingAmount = totalCreditValue - totalPaid;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
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
                              // Fila superior con el indicador de orden
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Información del cliente
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
                                  // Indicador de orden editable
                                  _buildOverdueIndicator(overdueInfo),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16)),
                                  _buildOrderIndicator(index, context),
                                ],
                              ),

                              const Divider(),

                              // Información del crédito
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Valor crédito:',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        Text(
                                          '\$${NumberFormat('#,##0').format(totalCreditValue)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Capital:', style: TextStyle(color: Colors.grey[600])),
                                        Text('\$${NumberFormat('#,##0').format(creditAmount)}'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Interés:', style: TextStyle(color: Colors.grey[600])),
                                        Text('${interestPercent.toStringAsFixed(2)}%'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Saldo:', style: TextStyle(color: Colors.grey[600])),
                                        Text(
                                          '\$${NumberFormat('#,##0').format(remainingAmount)}',
                                          style: TextStyle(
                                            color: remainingAmount > 0 ? Colors.red : Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (daysOverdue > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Días en mora:',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                          Text(
                                            '$daysOverdue días',
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const Divider(),

                              // Modifica la sección de botones en tu ListTile del crédito:
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.visibility, size: 20),
                                    label: const Text('Detalles'),
                                    onPressed: () => _showCreditDetails(context, creditData),
                                  ),
                                  if (remainingAmount <= 0)
                                    FutureBuilder<bool>(
                                      future: _canCloseCredit(
                                        creditData['creditId'],
                                        creditData['clientId'],
                                      ),
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
                                          onPressed: null, // Botón desactivado
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.grey, // Color de texto gris
                                          ),
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
                    );
                  },
                ),
              ),
    );
  }
}
