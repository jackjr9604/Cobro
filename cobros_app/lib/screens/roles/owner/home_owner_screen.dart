import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../owner/Liquidations/Liquidation_Report_Screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

  Map<String, dynamic>? _officeData;
  List<Map<String, dynamic>> _collectors = [];
  List<Map<String, dynamic>> _recentLiquidations = [];
  double _totalBalance = 0;
  double _activeCredits = 0;
  double _collectedThisMonth = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Obtener datos de la oficina
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final officeId = userDoc.data()?['officeId'];
      if (officeId == null) return;

      final officeDoc = await _firestore.collection('offices').doc(officeId).get();
      setState(() => _officeData = officeDoc.data());

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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  Widget _buildLiquidationItem(Map<String, dynamic> liquidation) {
    return ListTile(
      leading: const Icon(Icons.monetization_on, color: Colors.green),
      title: Text(
        liquidation['collectorName'] ?? 'Cobrador desconocido',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(DateFormat('dd/MM/yyyy').format((liquidation['date'] as Timestamp).toDate())),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currencyFormat.format(liquidation['netTotal'] ?? 0),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${liquidation['payments']?.length ?? 0} pagos',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_officeData?['name'] ?? 'Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboardData)],
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
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildSummaryCard(
                  'Balance Total',
                  currencyFormat.format(_totalBalance),
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Créditos Activos',
                  currencyFormat.format(_activeCredits),
                  Icons.credit_card,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Recaudado Mes',
                  currencyFormat.format(_collectedThisMonth),
                  Icons.attach_money,
                  Colors.purple,
                ),
                _buildSummaryCard(
                  'Cobradores Activos',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Liquidaciones Recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LiquidationReportScreen()),
                    );
                  },
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Column(
                children: [
                  for (var liquidation in _recentLiquidations) _buildLiquidationItem(liquidation),
                  if (_recentLiquidations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No hay liquidaciones recientes'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Acción rápida (ej. agregar cobro)
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
