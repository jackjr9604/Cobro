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

  @override
  void initState() {
    super.initState();
    // Calcular rangos de fecha
    final now = DateTime.now();
    _currentWeekRange = _getCurrentWeekRange(now);
    _currentMonthRange = _getCurrentMonthRange(now);
    _loadCollectorData();
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // 1. Obtener datos básicos del collector
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw Exception('Usuario no encontrado');

      final userData = userDoc.data();
      _collectorName = userData?['displayName'] ?? 'Cobrador';

      // 2. Buscar la oficina asignada (a través de los clients)
      final clientsSnapshot =
          await _firestore
              .collectionGroup('clients')
              .where('createdBy', isEqualTo: user.uid)
              .limit(1)
              .get();

      if (clientsSnapshot.docs.isEmpty) {
        throw Exception('No tienes clientes asignados');
      }

      _officeId = clientsSnapshot.docs.first['officeId'];

      // 3. Cargar datos de pagos
      await _loadPaymentsData(user.uid);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error en _loadCollectorData: $e'); // Mejor para Flutter
      print('Error en _loadCollectorData: $e'); // Alternativa

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadPaymentsData(String collectorId) async {
    final today = DateTime.now();
    final todayFormatted = DateFormat('yyyy-MM-dd').format(today);

    double todayTotal = 0;
    int todayCount = 0;
    double weeklyTotal = 0;
    double monthlyTotal = 0;
    int overdueCount = 0;
    final recentPayments = <Map<String, dynamic>>[];
    final upcomingPayments = <Map<String, dynamic>>[];

    final clientsQuery =
        await _firestore
            .collectionGroup('clients')
            .where('createdBy', isEqualTo: collectorId)
            .get();

    for (final clientDoc in clientsQuery.docs) {
      final clientData = clientDoc.data();
      final creditsQuery =
          await clientDoc.reference.collection('credits').where('isActive', isEqualTo: true).get();

      for (final creditDoc in creditsQuery.docs) {
        final creditData = creditDoc.data();

        // 1. Procesar pagos existentes
        final paymentsQuery =
            await creditDoc.reference
                .collection('payments')
                .orderBy('date', descending: true)
                .get();

        for (final paymentDoc in paymentsQuery.docs) {
          final paymentData = paymentDoc.data();
          final paymentDate =
              paymentData['date'] is Timestamp
                  ? (paymentData['date'] as Timestamp).toDate()
                  : paymentData['date'] as DateTime;
          final paymentDateFormatted = DateFormat('yyyy-MM-dd').format(paymentDate);
          final amount = (paymentData['amount'] as num).toDouble();

          final paymentInfo = {
            ...paymentData,
            'clientName': clientData['clientName'],
            'date': paymentDate,
            'amount': amount,
            'creditId': creditDoc.id,
            'clientId': clientDoc.id,
          };

          recentPayments.add(paymentInfo);

          // Cálculos de totales
          if (paymentDateFormatted == todayFormatted) {
            todayTotal += amount;
            todayCount++;
          }

          if (_currentWeekRange!.start.isBefore(paymentDate) &&
              _currentWeekRange!.end.isAfter(paymentDate)) {
            weeklyTotal += amount;
          }

          if (_currentMonthRange!.start.isBefore(paymentDate) &&
              _currentMonthRange!.end.isAfter(paymentDate)) {
            monthlyTotal += amount;
          }
        }

        // 2. Buscar próximos vencimientos
        if (creditData['paymentSchedule'] != null) {
          final paymentSchedule = List<String>.from(creditData['paymentSchedule']);
          final nextPaymentIndex = creditData['nextPaymentIndex'] ?? 0;

          if (nextPaymentIndex < paymentSchedule.length) {
            final nextPaymentDateStr = paymentSchedule[nextPaymentIndex];
            final nextPaymentDate = DateTime.parse(nextPaymentDateStr);
            final daysUntilDue = nextPaymentDate.difference(today).inDays;

            if (daysUntilDue <= 7) {
              // Mostrar solo vencimientos en los próximos 7 días
              final paymentValue =
                  (creditData['credit'] * (1 + creditData['interest'] / 100)) / creditData['cuot'];

              upcomingPayments.add({
                'clientName': clientData['clientName'],
                'dueDate': nextPaymentDate,
                'daysUntilDue': daysUntilDue,
                'amount': paymentValue,
                'creditId': creditDoc.id,
                'clientId': clientDoc.id,
                'isOverdue': daysUntilDue < 0,
              });

              if (daysUntilDue < 0) {
                overdueCount++;
              }
            }
          }
        }
      }
    }

    // Ordenar vencimientos: primero los vencidos, luego los más próximos
    upcomingPayments.sort((a, b) {
      if (a['isOverdue'] && !b['isOverdue']) return -1;
      if (!a['isOverdue'] && b['isOverdue']) return 1;
      return a['daysUntilDue'].compareTo(b['daysUntilDue']);
    });

    setState(() {
      _todayTotal = todayTotal;
      _todayPaymentsCount = todayCount;
      _weeklyTotal = weeklyTotal;
      _monthlyTotal = monthlyTotal;
      _recentPayments = recentPayments.take(10).toList();
      _upcomingPayments = upcomingPayments;
      _overduePaymentsCount = overdueCount;
    });
  }

  Widget _buildUpcomingPaymentsSection() {
    if (_upcomingPayments.isEmpty) return const SizedBox.shrink();

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
                  label: Text(
                    '$_overduePaymentsCount vencidos',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                ),
            ],
          ),
        ),
        SizedBox(
          height: 160, // Altura fija para el carrusel
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0, right: 8.0),
            itemCount: _upcomingPayments.length,
            itemBuilder: (context, index) {
              final payment = _upcomingPayments[index];
              return Container(
                width: 300, // Ancho fijo para cada tarjeta
                margin: const EdgeInsets.only(right: 8.0),
                child: _buildUpcomingPaymentCard(payment),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    if (_upcomingPayments.length <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        _upcomingPayments.length,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == 0 ? Colors.blue : Colors.grey[300],
          ),
        ),
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSummarySection(),
                if (_upcomingPayments.isNotEmpty) _buildUpcomingPaymentsSection(),
                _buildRecentPaymentsSection(),
                // Espacio adicional al final si es necesario
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        );
      },
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Resumen Financiero',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  _buildPeriodSelector(),
                ],
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
              _buildAdditionalStats(),
            ],
          ),
        ),
      ),
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
                onPressed: () => _showAllPayments(context),
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

  Widget _buildPeriodSelector() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.calendar_month),
      itemBuilder:
          (context) => [
            const PopupMenuItem(value: 'day', child: Text('Ver por día')),
            const PopupMenuItem(value: 'week', child: Text('Ver por semana')),
            const PopupMenuItem(value: 'month', child: Text('Ver por mes')),
          ],
      onSelected: (value) {
        // Implementar cambio de período si es necesario
      },
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

  Widget _buildAdditionalStats() {
    final now = DateTime.now();
    final weekProgress = (_currentWeekRange!.end.difference(now).inDays / 7);
    final monthProgress = now.day / _currentMonthRange!.end.day;

    return Column(
      children: [
        // Progreso de la semana
        _buildProgressIndicator(
          'Progreso semanal',
          weekProgress,
          '${7 - _currentWeekRange!.end.difference(now).inDays} de 7 días',
        ),

        const SizedBox(height: 8),

        // Progreso del mes
        _buildProgressIndicator(
          'Progreso mensual',
          monthProgress,
          'Día ${now.day} de ${_currentMonthRange!.end.day}',
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(String label, double progress, String info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(info, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final paymentDate =
        payment['date'] is Timestamp
            ? (payment['date'] as Timestamp).toDate()
            : payment['date'] as DateTime;
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No hay cobros registrados',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _loadCollectorData, child: const Text('Recargar')),
        ],
      ),
    );
  }

  Future<void> _showAllPayments(BuildContext context) async {
    // Implementar navegación a pantalla completa de pagos
  }

  int _countActiveClients() {
    // Implementar lógica para contar clientes activos
    return 0;
  }
}
