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
  final Map<String, int> orderMap = {};
  final Map<String, TextEditingController> controllers = {};
  late String _collectorUid;
  late String _ownerUid;
  late String _officeId;
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    controllers.values.forEach((controller) => controller.dispose());
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

      // Manejo seguro de createdBy
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
      await _loadClients();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClients() async {
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

      setState(() {
        _clients = clientsQuery.docs;
      });
    } catch (e) {
      debugPrint('Error loading clients: $e');
    }
  }

  Future<void> _registerPayment(
    BuildContext context,
    DocumentSnapshot creditDoc,
    String clientId,
  ) async {
    final creditData = creditDoc.data() as Map<String, dynamic>;
    final creditId = creditDoc.id;

    // Cálculos correctos del crédito
    final creditAmount = (creditData['credit'] ?? 0).toDouble();
    final interestPercent = (creditData['interest'] ?? 0).toDouble();
    final totalCreditValue = creditAmount + (creditAmount * interestPercent / 100);
    final numberOfCuotas = (creditData['cuot'] ?? 1).toDouble();

    // Cálculo del valor del abono según la fórmula ((credit*interest/100)+credit)/cuot
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
      (sum, doc) => sum + ((doc.data() as Map<String, dynamic>)['amount'] ?? 0).toDouble(),
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
                      ),
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Valor del abono'),
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
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final amount = double.tryParse(controller.text);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Valor inválido')));
                          return;
                        }
                        if (amount > saldoRestante) {
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
        'isActive': true,
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

      try {
        await batch.commit();

        // Verificar si el crédito debe cerrarse (saldo <= 0)

        final newSaldo = saldoRestante - amount;
        if (newSaldo <= 0) {
          await _closeCredit(creditDoc, clientId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('¡Crédito pagado completamente y cerrado!')),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Pago registrado')));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Map<String, dynamic> _calculateOverdueInfo(Map<String, dynamic>? creditData) {
    final now = DateTime.now();
    int daysOverdue = 0;
    DateTime? nextPaymentDate;

    if (creditData != null) {
      try {
        final paymentSchedule =
            (creditData['paymentSchedule'] as List?)
                ?.map((date) => date is Timestamp ? date.toDate() : DateTime.parse(date.toString()))
                .toList() ??
            [];

        final nextPaymentIndex = (creditData['nextPaymentIndex'] as int?) ?? 0;

        if (nextPaymentIndex < paymentSchedule.length) {
          nextPaymentDate = paymentSchedule[nextPaymentIndex];
          if (nextPaymentDate != null && now.isAfter(nextPaymentDate)) {
            daysOverdue = now.difference(nextPaymentDate).inDays;
          }
        }
      } catch (e) {
        debugPrint('Error calculating overdue info: $e');
      }
    }

    return {'daysOverdue': daysOverdue, 'nextPaymentDate': nextPaymentDate};
  }

  // Método seguro para formatear números
  String _formatNumber(dynamic value) {
    try {
      final number = value != null ? double.parse(value.toString()) : 0.0;
      return NumberFormat('#,##0').format(number);
    } catch (e) {
      return '0';
    }
  }

  Color? _getCardColor(int daysOverdue) {
    if (daysOverdue > 30) return Colors.red[900];
    if (daysOverdue > 15) return Colors.red[600];
    if (daysOverdue > 0) return Colors.red[300];
    return null;
  }

  Future<void> _closeCredit(DocumentSnapshot creditDoc, String clientId) async {
    final creditId = creditDoc.id;

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
      'createdBy': _collectorUid, // Usamos createdBy en lugar de collectorId
      'officeId': _officeId,
      'clientId': clientId, // Guardamos referencia al cliente
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Crédito cerrado con éxito')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cerrar crédito: $e')));
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes clientes asignados',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'O todos los créditos están inactivos',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadClients,
            icon: const Icon(Icons.refresh),
            label: const Text('Intentar nuevamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildClientTile(
    BuildContext context,
    String name,
    String phone, {
    bool isLoading = false,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(phone),
      trailing:
          isLoading
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : null,
    );
  }

  Future<void> _showCreditDetails(
    BuildContext context,
    DocumentSnapshot creditDoc,
    String clientId,
  ) async {
    // Implementar navegación a pantalla de detalles
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CreditDetailScreen(
              userId: _ownerUid,
              officeId: _officeId,
              clientId: clientId,
              creditId: creditDoc.id,
            ),
      ),
    );
  }

  // Método para navegar:
  void _navigateToInactiveCredits(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => InactiveCreditsScreen(
              userId: _ownerUid,
              officeId: _officeId,
              collectorId: _collectorUid, // Envía el ID del cobrador
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
              Text('Cargando información...', style: Theme.of(context).textTheme.titleMedium),
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
          _clients.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _loadClients,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final clientDoc = _clients[index];
                    final clientData = clientDoc.data() as Map<String, dynamic>;
                    final clientId = clientDoc.id;
                    final clientName = clientData['clientName'] ?? 'Sin nombre';
                    final clientPhone = clientData['phone'] ?? 'Sin teléfono';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(_ownerUid)
                                .collection('offices')
                                .doc(_officeId)
                                .collection('clients')
                                .doc(clientId)
                                .collection('credits')
                                .where('isActive', isEqualTo: true)
                                .snapshots(),
                        builder: (context, creditsSnapshot) {
                          if (!creditsSnapshot.hasData) {
                            return _buildClientTile(
                              context,
                              clientName,
                              clientPhone,
                              isLoading: true,
                            );
                          }

                          final credits = creditsSnapshot.data!.docs;
                          if (credits.isEmpty) return Container();

                          return ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                clientName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              clientName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(clientPhone),
                            childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                            children:
                                credits.map((creditDoc) {
                                  final creditData = creditDoc.data() as Map<String, dynamic>;
                                  final creditId = creditDoc.id;
                                  final overdueInfo = _calculateOverdueInfo(creditData);
                                  final daysOverdue = overdueInfo['daysOverdue'] as int;

                                  final nextPaymentDate =
                                      overdueInfo['nextPaymentDate'] as DateTime?;

                                  // Cálculo correcto del valor total del crédito
                                  final creditAmount = (creditData['credit'] ?? 0).toDouble();
                                  final interestPercent = (creditData['interest'] ?? 0).toDouble();
                                  final totalCreditValue =
                                      creditAmount + (creditAmount * interestPercent / 100);

                                  // Cálculo del saldo restante (asumiendo que tienes un campo 'totalPaid')
                                  final totalPaid = (creditData['totalPaid'] ?? 0).toDouble();
                                  final remainingAmount = totalCreditValue - totalPaid;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          _getCardColor(daysOverdue)?.withOpacity(0.1) ??
                                          Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            _getCardColor(daysOverdue)?.withOpacity(0.3) ??
                                            Colors.grey[300]!,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      title: Text(
                                        'Crédito: \$${NumberFormat('#,##0').format(totalCreditValue)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: daysOverdue > 0 ? Colors.red : null,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Capital: \$${NumberFormat('#,##0').format(creditAmount)}',
                                          ),
                                          Text('Interés: ${interestPercent.toStringAsFixed(2)}%'),
                                          Text(
                                            'Saldo: \$${NumberFormat('#,##0').format(remainingAmount)}',
                                          ),
                                          if (daysOverdue > 0)
                                            Text(
                                              'Días en mora: $daysOverdue',
                                              style: const TextStyle(color: Colors.red),
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility),
                                            color: Theme.of(context).primaryColor,
                                            onPressed:
                                                () => _showCreditDetails(
                                                  context,
                                                  creditDoc,
                                                  clientId,
                                                ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.payment),
                                            color: Colors.green,
                                            onPressed:
                                                () =>
                                                    _registerPayment(context, creditDoc, clientId),
                                            tooltip: 'Registrar pago',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
