import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CollectorHomeScreen extends StatefulWidget {
  const CollectorHomeScreen({super.key});

  @override
  State<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends State<CollectorHomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _officeId;
  bool _isLoading = true;
  String? _errorMessage;
  String? _collectorName;
  double _todayTotal = 0;
  int _todayPaymentsCount = 0;
  List<Map<String, dynamic>> _recentPayments = [];
  double _weeklyTotal = 0;
  double _monthlyTotal = 0;
  DateTimeRange? _currentWeekRange;
  DateTimeRange? _currentMonthRange;
  List<Map<String, dynamic>> _upcomingPayments = [];
  int _overduePaymentsCount = 0;
  int _totalExpectedPaymentsToday = 0;
  int _completedPaymentsToday = 0;
  double _totalExpectedAmountToday = 0;
  double _remainingAmountToday = 0;
  bool _isDisposed = false; // ← Controla si el widget fue eliminado
  List<Future> _pendingFutures = []; // ← Guarda operaciones asíncronas pendientes

  @override
  void dispose() {
    _isDisposed = true; // ← Marca como eliminado
    _pendingFutures.clear(); // ← Cancela futuros pendientes
    super.dispose();
  }

  Future<void> _safeSetState(Function() updateFn) async {
    if (!mounted || _isDisposed) return; // ← No actualizar si no está activo
    setState(updateFn);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentWeekRange = _getCurrentWeekRange(now);
    _currentMonthRange = _getCurrentMonthRange(now);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCollectorData();
      }
    });
  }

  DateTimeRange _getCurrentWeekRange(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _getCurrentMonthRange(DateTime date) {
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _loadCollectorData() async {
    if (_isDisposed) return;

    await _safeSetState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw Exception('Usuario no encontrado');

      final userData = userDoc.data();
      await _safeSetState(() {
        _collectorName = userData?['displayName'] ?? 'Cobrador';
      });

      final clientsSnapshot =
          await _firestore
              .collectionGroup('clients')
              .where('createdBy', isEqualTo: user.uid)
              .limit(1)
              .get();

      if (clientsSnapshot.docs.isEmpty) {
        throw Exception('No tienes clientes asignados');
      }

      await _safeSetState(() {
        _officeId = clientsSnapshot.docs.first['officeId'];
      });

      final future = _loadPaymentsData(user.uid);
      _pendingFutures.add(future);
      await future;
      _pendingFutures.remove(future);

      await _safeSetState(() => _isLoading = false);
    } catch (e) {
      if (!mounted || _isDisposed) return;
      debugPrint('Error loading collector data: $e');
      await _safeSetState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadPaymentsData(String collectorId) async {
    // 1. Verificar si el widget sigue activo
    if (!mounted || _isDisposed) return;

    final today = DateTime.now();
    final todayFormatted = DateFormat('yyyy-MM-dd').format(today);

    // 2. Variables locales para cálculos (evitamos setState innecesarios)
    double todayTotal = 0;
    int todayCount = 0;
    int totalExpected = 0;
    int completedPayments = 0;
    double totalExpectedAmount = 0;
    double weeklyTotal = 0;
    double monthlyTotal = 0;
    int overdueCount = 0;
    final recentPayments = <Map<String, dynamic>>[];
    final upcomingPayments = <Map<String, dynamic>>[];

    try {
      // 3. Obtener clientes con verificación de mounted
      if (!mounted || _isDisposed) return;
      final clientsQuery =
          await _firestore
              .collectionGroup('clients')
              .where('createdBy', isEqualTo: collectorId)
              .get();

      // 4. Procesar cada cliente
      for (final clientDoc in clientsQuery.docs) {
        if (!mounted || _isDisposed) return;

        final clientData = clientDoc.data();
        final creditsQuery =
            await clientDoc.reference
                .collection('credits')
                .where('isActive', isEqualTo: true)
                .get();

        // 5. Procesar cada crédito
        for (final creditDoc in creditsQuery.docs) {
          if (!mounted || _isDisposed) return;

          final creditData = creditDoc.data();
          final method = creditData['method'] ?? 'Diario';
          final diasEntreCuotas = _getDiasEntreCuotas(method);

          // Calcular valor de la cuota
          final creditAmount = (creditData['credit'] ?? 0).toDouble();
          final interestPercent = (creditData['interest'] ?? 0).toDouble();
          final totalCreditValue = creditAmount + (creditAmount * interestPercent / 100);
          final cuot = (creditData['cuot'] ?? 1).toInt();
          final paymentValue = totalCreditValue / cuot;

          // 6. Obtener pagos de hoy
          final paymentsQuery =
              await creditDoc.reference
                  .collection('payments')
                  .where(
                    'date',
                    isGreaterThanOrEqualTo: DateTime(today.year, today.month, today.day),
                  )
                  .where('date', isLessThan: DateTime(today.year, today.month, today.day + 1))
                  .get();

          for (final paymentDoc in paymentsQuery.docs) {
            final paymentData = paymentDoc.data();
            final amount = (paymentData['amount'] ?? 0).toDouble();

            todayTotal += amount;
            todayCount++;
            completedPayments++;

            recentPayments.add({
              ...paymentData,
              'clientName': clientData['clientName'],
              'date': paymentData['date'].toDate(),
              'amount': amount,
            });
          }

          // 7. Calcular próximos vencimientos
          DateTime? lastPaymentDate = creditData['lastPaymentDate']?.toDate();
          if (lastPaymentDate == null) {
            lastPaymentDate = creditData['createdAt']?.toDate();
          }

          if (lastPaymentDate != null) {
            final nextPaymentDate = lastPaymentDate.add(Duration(days: diasEntreCuotas));
            final daysUntilDue = nextPaymentDate.difference(today).inDays;

            if (daysUntilDue <= 7) {
              upcomingPayments.add({
                'clientName': clientData['clientName'],
                'dueDate': nextPaymentDate,
                'daysUntilDue': daysUntilDue,
                'amount': paymentValue,
                'creditId': creditDoc.id,
                'clientId': clientDoc.id,
                'isOverdue': daysUntilDue < 0,
              });

              if (daysUntilDue < 0) overdueCount++;

              // 8. Verificar pagos esperados para hoy
              final isDueToday = DateFormat('yyyy-MM-dd').format(nextPaymentDate) == todayFormatted;
              if (isDueToday && !paymentsQuery.docs.any((p) => p.id == creditDoc.id)) {
                totalExpected++;
                totalExpectedAmount += paymentValue;
              }
            }
          }

          // 9. Calcular totales semanales/mensuales
          final allPaymentsQuery =
              await creditDoc.reference
                  .collection('payments')
                  .orderBy('date', descending: true)
                  .limit(30)
                  .get();

          for (final paymentDoc in allPaymentsQuery.docs) {
            final paymentData = paymentDoc.data();
            final paymentDate = paymentData['date'].toDate();
            final amount = (paymentData['amount'] ?? 0).toDouble();

            if (_currentWeekRange!.start.isBefore(paymentDate) &&
                _currentWeekRange!.end.isAfter(paymentDate)) {
              weeklyTotal += amount;
            }

            if (_currentMonthRange!.start.isBefore(paymentDate) &&
                _currentMonthRange!.end.isAfter(paymentDate)) {
              monthlyTotal += amount;
            }
          }
        }
      }

      // 10. Calcular montos pendientes
      final remainingAmount =
          (totalExpectedAmount - todayTotal).clamp(0, double.infinity).toDouble();

      // 11. Ordenar resultados
      upcomingPayments.sort((a, b) => a['daysUntilDue'].compareTo(b['daysUntilDue']));
      recentPayments.sort((a, b) => b['date'].compareTo(a['date']));

      // 12. Actualización final segura
      await _safeSetState(() {
        _todayTotal = todayTotal;
        _todayPaymentsCount = todayCount;
        _weeklyTotal = weeklyTotal;
        _monthlyTotal = monthlyTotal;
        _recentPayments = recentPayments.take(10).toList();
        _upcomingPayments = upcomingPayments;
        _overduePaymentsCount = overdueCount;
        _totalExpectedPaymentsToday = totalExpected;
        _completedPaymentsToday = completedPayments;
        _totalExpectedAmountToday = totalExpectedAmount + todayTotal;
        _remainingAmountToday = remainingAmount;
      });
    } catch (e) {
      debugPrint('Error en _loadPaymentsData: $e');
      if (!mounted || _isDisposed) return;
      await _safeSetState(() {
        _errorMessage = 'Error al cargar pagos: ${e.toString()}';
      });
    }
  }

  // Función auxiliar para obtener días entre cuotas
  int _getDiasEntreCuotas(String method) {
    return switch (method) {
      'Semanal' => 7,
      'Quincenal' => 15,
      'Mensual' => 30,
      _ => 1,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_collectorName != null ? 'Cobros de $_collectorName' : 'Mis Cobros'),
        actions: [
          if (_overduePaymentsCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Badge(
                label: Text('$_overduePaymentsCount'),
                backgroundColor: Colors.red,
                child: const Icon(Icons.warning, color: Colors.white),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCollectorData),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSummarySection(),
          if (_upcomingPayments.isNotEmpty) _buildUpcomingPaymentsSection(),
          _buildRecentPaymentsSection(),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Resumen Financiero',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Hoy', _todayTotal, Icons.today, Colors.blue),
                  _buildSummaryItem('Semana', _weeklyTotal, Icons.calendar_view_week, Colors.green),
                  _buildSummaryItem('Mes', _monthlyTotal, Icons.calendar_today, Colors.orange),
                ],
              ),
              const SizedBox(height: 16),
              _buildDailyStatsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyStatsSection() {
    return Column(
      children: [
        const Text(
          'Detalle de Cobros Hoy',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildPaymentStatsRow(
          'Cobros realizados',
          '$_completedPaymentsToday/${_totalExpectedPaymentsToday + _completedPaymentsToday}',
          _completedPaymentsToday >= _totalExpectedPaymentsToday ? Colors.green : Colors.blue,
        ),
        const SizedBox(height: 4),
        _buildPaymentStatsRow(
          'Dinero recolectado',
          '\$${_todayTotal.toStringAsFixed(2)} de \$${_totalExpectedAmountToday.toStringAsFixed(2)}',
          _todayTotal >= _totalExpectedAmountToday ? Colors.green : Colors.blue,
        ),
        const SizedBox(height: 4),
        if (_remainingAmountToday > 0)
          _buildPaymentStatsRow(
            'Faltante por cobrar',
            '\$${_remainingAmountToday.toStringAsFixed(2)}',
            Colors.orange,
          ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _totalExpectedAmountToday > 0 ? _todayTotal / _totalExpectedAmountToday : 0,
          backgroundColor: Colors.grey[200],
          color: _todayTotal >= _totalExpectedAmountToday ? Colors.green : Colors.blue,
        ),
      ],
    );
  }

  Widget _buildUpcomingPaymentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Próximos Vencimientos',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_overduePaymentsCount > 0)
                Chip(
                  label: Text('$_overduePaymentsCount vencidos'),
                  backgroundColor: Colors.red,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0, right: 8.0),
            itemCount: _upcomingPayments.length,
            itemBuilder: (context, index) {
              final payment = _upcomingPayments[index];
              return Container(
                width: 300,
                margin: const EdgeInsets.only(right: 8.0),
                child: _buildUpcomingPaymentCard(payment),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPaymentsSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Últimos Cobros',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {}, // Implementar navegación si es necesario
                child: const Text('Ver todos'),
              ),
            ],
          ),
        ),
        _recentPayments.isEmpty
            ? _buildEmptyPaymentsState()
            : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8.0),
              itemCount: _recentPayments.length,
              itemBuilder: (context, index) {
                final payment = _recentPayments[index];
                return _buildPaymentCard(payment);
              },
            ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double value, IconData icon, Color color) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          formatter.format(value),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPaymentStatsRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingPaymentCard(Map<String, dynamic> payment) {
    final isOverdue = payment['isOverdue'];
    final daysUntilDue = payment['daysUntilDue'];
    final dueDate =
        payment['dueDate'] is Timestamp
            ? (payment['dueDate'] as Timestamp).toDate()
            : payment['dueDate'] as DateTime;

    return Card(
      color: isOverdue ? Colors.red[50] : null,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue ? Colors.red : Colors.grey[300]!,
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning_rounded : Icons.calendar_today_rounded,
                      color: isOverdue ? Colors.red : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOverdue ? 'VENCIDO' : 'PRÓXIMO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('dd/MM/yy').format(dueDate),
                  style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              payment['clientName'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              isOverdue ? '${daysUntilDue.abs()} días de retraso' : 'Vence en $daysUntilDue días',
              style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[600], fontSize: 14),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${payment['amount'].toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final paymentDate =
        payment['date'] is Timestamp
            ? (payment['date'] as Timestamp).toDate()
            : payment['date'] as DateTime;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Text(
                payment['clientName']?.substring(0, 1) ?? '?',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment['clientName'] ?? 'Cliente desconocido',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy - hh:mm a', 'es').format(paymentDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (payment['paymentMethod'] != null) ...[
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(payment['paymentMethod'], style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${payment['amount'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                if (payment['receiptNumber'] != null)
                  Text(
                    payment['receiptNumber'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPaymentsState() {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No hay cobros recientes', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}
