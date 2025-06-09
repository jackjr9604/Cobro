import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../owner/Liquidations/Liquidation_Report_Screen.dart';
import '../owner/member_ship_screen.dart';
import '../owner/office.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final currencyFormat = NumberFormat('\$ #,##0', 'es_CO');

  Map<String, dynamic>? _officeData;
  List<Map<String, dynamic>> _collectors = [];
  List<Map<String, dynamic>> _recentLiquidations = [];
  double _totalBalance = 0;
  double _activeCredits = 0;
  double _collectedThisMonth = 0;
  bool _isLoading = true;
  double _dailyCollection = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData().then((_) => _calculateDailyCollection());
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Obtener datos del usuario (no solo officeId)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) return;

      final officeId = userData['officeId'];
      if (officeId == null) {
        setState(() {
          _isLoading = false;
          _officeData = null;
        });
        return;
      }

      // 2. Obtener datos de la oficina y estado activo
      final officeDoc = await _firestore.collection('offices').doc(officeId).get();
      if (!officeDoc.exists) {
        setState(() {
          _isLoading = false;
          _officeData = null;
        });
        return;
      }

      // Combinar datos del usuario y la oficina
      setState(() {
        _officeData = officeDoc.data();
        _officeData?['officeId'] = officeId;
        _officeData?['userActiveStatus'] = userData['activeStatus']; // Estado activo del usuario
      });

      // 2. Obtener cobradores activos
      final collectorsQuery =
          await _firestore
              .collection('users')
              .where('officeId', isEqualTo: officeId)
              .where('role', isEqualTo: 'collector')
              .where('activeStatus.isActive', isEqualTo: true)
              .get();

      setState(
        () =>
            _collectors =
                collectorsQuery.docs.map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id;
                  return data;
                }).toList(),
      );

      await _calculateDailyCollection();

      // 3. Obtener liquidaciones recientes
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final liquidationsQuery =
          await _firestore
              .collection('liquidations')
              .where('officeId', isEqualTo: officeId)
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
              .orderBy('date', descending: true)
              .limit(5)
              .get();

      setState(
        () =>
            _recentLiquidations =
                liquidationsQuery.docs.map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id;
                  return data;
                }).toList(),
      );

      // 4. Calcular balances
      double totalBalance = 0;
      double activeCredits = 0;
      double collectedThisMonth = 0;

      // Calcular total recaudado este mes
      for (var liquidation in _recentLiquidations) {
        collectedThisMonth += (liquidation['netTotal'] ?? 0).toDouble();
      }

      // Calcular créditos activos (requeriría una consulta adicional)
      final creditsQuery =
          await _firestore
              .collection('credits')
              .where('officeId', isEqualTo: officeId)
              .where('isActive', isEqualTo: true)
              .get();

      for (var credit in creditsQuery.docs) {
        final data = credit.data();
        activeCredits += (data['credit'] ?? 0).toDouble();
      }

      // Balance total (asumiendo que está almacenado en officeData)
      totalBalance = (_officeData?['totalBalance'] ?? 0).toDouble();

      setState(() {
        _totalBalance = totalBalance;
        _activeCredits = activeCredits;
        _collectedThisMonth = collectedThisMonth;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateDailyCollection() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Obtener officeId del usuario
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final officeId = userDoc.data()?['officeId'];
      if (officeId == null) return;

      // Obtener la fecha actual (sin hora)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Consultar todos los créditos de la oficina
      final creditsQuery =
          await _firestore.collection('credits').where('officeId', isEqualTo: officeId).get();

      double dailyTotal = 0;

      // Recorrer cada crédito
      for (var creditDoc in creditsQuery.docs) {
        final creditData = creditDoc.data(); // Eliminado el cast

        // Buscar todos los campos que comienzan con 'pay'
        creditData.forEach((key, value) {
          if (key.startsWith('pay') && value is Map<String, dynamic>) {
            final payment = value;
            final paymentDate = (payment['date'] as Timestamp?)?.toDate();

            if (paymentDate != null) {
              final paymentDay = DateTime(paymentDate.year, paymentDate.month, paymentDate.day);

              if (paymentDay.isAtSameMomentAs(today)) {
                dailyTotal += (payment['amount'] ?? 0).toDouble();
              }
            }
          }
        });
      }

      setState(() => _dailyCollection = dailyTotal);
    } catch (e) {
      print('Error calculando recaudo diario: $e');
    }
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14, // Tamaño fijo adecuado para móviles
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18, // Tamaño más grande para el valor
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectorItem(Map<String, dynamic> collector) {
    return ListTile(
      leading: CircleAvatar(child: Text(collector['displayName']?[0] ?? '?')),
      title: Text(collector['displayName'] ?? 'Sin nombre'),
      subtitle: Text(
        'Últ. liquidación: ${collector['lastLiquidationDate'] != null ? DateFormat('dd/MM/yy').format((collector['lastLiquidationDate'] as Timestamp).toDate()) : 'N/A'}',
      ),
      trailing: Chip(
        label: Text(
          currencyFormat.format(collector['monthlyCollection'] ?? 0),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildNoOfficeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business, size: 64, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              'No tienes una oficina registrada',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              'Para acceder al dashboard, primero necesitas crear una oficina.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OfficeManagementScreen()),
                );
                _loadDashboardData(); // Forzar recarga al volver
              },
              child: const Text('Crear Oficina', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveAccountScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              'Cuenta no activa',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              'Tu membresía no está activa actualmente. Por favor, realiza el pago para activar tu cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () {
                // Navegar a la pantalla de pagos
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MembershipScreen()),
                );
              },
              child: const Text('Activar Membresía', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Verificar si tiene oficina
    if (_officeData == null || _officeData!['officeId'] == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_officeData?['name'] ?? 'Dashboard'),

          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadDashboardData,
            ),
          ],
        ),
        body: _buildNoOfficeScreen(),
      );
    }

    // Verificar estado activo CORREGIDO
    final userActiveStatus = _officeData?['userActiveStatus'] as Map<String, dynamic>?;
    final isActive = userActiveStatus?['isActive'] ?? false;

    if (!isActive) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_officeData?['name'] ?? 'Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadDashboardData,
            ),
          ],
        ),
        body: _buildInactiveAccountScreen(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_officeData?['name'] ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumen rápido
            const Text(
              'Resumen General',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            GridView.count(
              crossAxisCount: 2, // Mantener 2 columnas en móviles
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4, // Relación de aspecto ligeramente mayor
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              padding: const EdgeInsets.all(4),
              children: [
                _buildSummaryCard(
                  'Recaudado Hoy',
                  currencyFormat.format(_dailyCollection),
                  Icons.today,
                  Colors.purple,
                ),
                _buildSummaryCard(
                  'Recaudo Mes',
                  currencyFormat.format(_collectedThisMonth),
                  Icons.attach_money,
                  Colors.purple,
                ),
                _buildSummaryCard(
                  'Balance Total',
                  currencyFormat.format(_totalBalance),
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Créd. Activos',
                  currencyFormat.format(_activeCredits),
                  Icons.credit_card,
                  Colors.green,
                ),

                _buildSummaryCard(
                  'Cobradores',
                  _collectors.length.toString(),
                  Icons.people,
                  Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Gráfico de recaudación mensual (simplificado)
            const Text(
              'Recaudación Mensual',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 24),

            // Cobradores activos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cobradores Activos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Column(
                children: [
                  for (var collector in _collectors.take(3)) _buildCollectorItem(collector),
                  if (_collectors.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No hay cobradores activos'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Liquidaciones recientes
          ],
        ),
      ),
    );
  }
}
