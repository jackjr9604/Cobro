import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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
  String? _officeId;
  bool _isUserActive = false;
  bool _isDisposed = false;
  List<Future> _pendingFutures = [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // ← Verificar si el widget sigue montado
        _checkUserStatus().then((_) {
          if (_isUserActive && mounted) {
            // ← Doble verificación
            _loadDashboardData();
          } else if (mounted) {
            _safeSetState(() => _isLoading = false);
          }
        });
      }
    });
  }

  Future<void> _checkUserStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _safeSetState(() => _isUserActive = false);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _safeSetState(() => _isUserActive = false);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final activeStatus = userData['activeStatus'] as Map<String, dynamic>?;
      final isActive = activeStatus?['isActive'] ?? false;

      await _safeSetState(() => _isUserActive = isActive);
    } catch (e) {
      debugPrint('Error checking user status: $e');
      await _safeSetState(() => _isUserActive = false);
    }
  }

  Future<void> _loadDashboardData() async {
    if (_isDisposed) return;

    await _safeSetState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 1. Obtener datos del usuario
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) {
        await _safeSetState(() => _isLoading = false);
        return;
      }

      // 2. Obtener la oficina del usuario
      final officesQuery =
          await _firestore.collection('users').doc(user.uid).collection('offices').limit(1).get();

      if (officesQuery.docs.isEmpty) {
        await _safeSetState(() {
          _isLoading = false;
          _officeData = null;
        });
        return;
      }

      final officeDoc = officesQuery.docs.first;
      await _safeSetState(() {
        _officeId = officeDoc.id;
        _officeData = officeDoc.data();
      });

      // 3. Obtener cobradores activos
      final collectorsQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('offices')
              .doc(_officeId)
              .collection('collectors')
              .where('activeStatus.isActive', isEqualTo: true)
              .get();

      await _safeSetState(() {
        _collectors =
            collectorsQuery.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
      });

      // 4. Obtener todos los clientes de la oficina
      final clientsQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('offices')
              .doc(_officeId)
              .collection('clients')
              .get();

      double totalCollected = 0;
      double activeCredits = 0;
      double monthlyTotal = 0;

      // Fechas para el cálculo mensual
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final firstDayNextMonth = DateTime(now.year, now.month + 1, 1);

      // 5. Procesar cada cliente, sus créditos y pagos
      for (var clientDoc in clientsQuery.docs) {
        final creditsQuery = await clientDoc.reference.collection('credits').get();

        for (var creditDoc in creditsQuery.docs) {
          final creditData = creditDoc.data();

          // Sumar créditos activos
          if (creditData['isActive'] == true) {
            activeCredits += (creditData['credit'] ?? 0).toDouble();
          }

          // Obtener todos los pagos de este crédito
          final paymentsQuery = await creditDoc.reference.collection('payments').get();

          for (var paymentDoc in paymentsQuery.docs) {
            final paymentData = paymentDoc.data();
            final amount = (paymentData['amount'] ?? 0).toDouble();

            // Sumar al total general
            totalCollected += amount;

            // Sumar al total mensual si corresponde
            final paymentDate = (paymentData['date'] as Timestamp).toDate();
            if (paymentDate.isAfter(firstDayOfMonth) && paymentDate.isBefore(firstDayNextMonth)) {
              monthlyTotal += amount;
            }
          }
        }
      }

      // 6. Obtener liquidaciones recientes
      final liquidationsQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('offices')
              .doc(_officeId)
              .collection('liquidations')
              .orderBy('date', descending: true)
              .limit(5)
              .get();

      // 7. Actualizar el estado con todos los datos
      await _safeSetState(() {
        _collectedThisMonth = monthlyTotal;
        _activeCredits = activeCredits;
        _totalBalance = totalCollected;
        _recentLiquidations =
            liquidationsQuery.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
        _isLoading = false;
      });

      // 8. Calcular recaudo diario
      await _calculateDailyCollection();
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      await _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _calculateDailyCollection() async {
    // 1. Verificar condiciones iniciales y si el widget sigue activo
    if (_officeId == null || _auth.currentUser == null || _isDisposed) {
      return;
    }

    // 2. Registrar esta operación para posible cancelación
    final future = _executeDailyCollectionCalculation();
    _pendingFutures.add(future);

    try {
      await future;
    } finally {
      _pendingFutures.remove(future);
    }
  }

  Future<void> _executeDailyCollectionCalculation() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    try {
      double dailyTotal = 0;

      // 3. Obtener clientes (con verificación de mounted)
      if (!mounted || _isDisposed) return;
      final clientsQuery =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('offices')
              .doc(_officeId)
              .collection('clients')
              .get();

      // 4. Procesar cada cliente y sus pagos
      for (final clientDoc in clientsQuery.docs) {
        if (!mounted || _isDisposed) return;

        final creditsQuery = await clientDoc.reference.collection('credits').get();

        for (final creditDoc in creditsQuery.docs) {
          if (!mounted || _isDisposed) return;

          final paymentsQuery =
              await creditDoc.reference
                  .collection('payments')
                  .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
                  .where('date', isLessThan: Timestamp.fromDate(todayEnd))
                  .get();

          for (final paymentDoc in paymentsQuery.docs) {
            final paymentData = paymentDoc.data();
            dailyTotal += (paymentData['amount'] ?? 0).toDouble();
          }
        }
      }

      // 5. Actualizar estado de forma segura
      await _safeSetState(() {
        _dailyCollection = dailyTotal;
      });

      // 6. Guardar en Firestore (si aún estamos activos)
      if (!mounted || _isDisposed) return;
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('offices')
          .doc(_officeId)
          .collection('dailyCollections')
          .doc(todayKey)
          .set({
            'total': dailyTotal,
            'date': Timestamp.now(),
            'officeId': _officeId,
            'userId': _auth.currentUser!.uid,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error calculando recaudo diario: $e');

      // 7. Intentar recuperar el valor guardado si hay error
      if (!mounted || _isDisposed) return;
      final doc =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('offices')
              .doc(_officeId)
              .collection('dailyCollections')
              .doc(todayKey)
              .get();

      await _safeSetState(() {
        _dailyCollection = (doc.data()?['total'] ?? 0).toDouble();
      });
    }
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String helpText,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 600;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.all(6),
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(minHeight: isLargeScreen ? 150 : 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Icon(icon, size: isLargeScreen ? 28 : 24, color: color),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: isLargeScreen ? 16 : 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.help_outline,
                        size: isLargeScreen ? 22 : 18,
                        color: Colors.grey,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text(title),
                                content: Text(helpText),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Entendido'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 22 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollectorItem(Map<String, dynamic> collector) {
    final isActive = collector['activeStatus']?['isActive'] ?? false;
    final lastLiquidation = collector['lastLiquidationDate'] as Timestamp?;
    final monthlyCollection = collector['monthlyCollection'] ?? 0;
    final name = collector['name'] ?? 'Sin nombre';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive ? Colors.green[100] : Colors.grey[200],
        child: Text(name[0]),
      ),
      title: Text(name),
      subtitle: Text(
        lastLiquidation != null
            ? 'Últ. liquidación: ${DateFormat('dd/MM/yy').format(lastLiquidation.toDate())}'
            : 'Sin liquidaciones',
      ),
      trailing: Chip(
        backgroundColor: isActive ? Colors.green[100] : Colors.grey[200],
        label: Text(
          currencyFormat.format(monthlyCollection),
          style: TextStyle(color: isActive ? Colors.green[800] : Colors.grey[600]),
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
              'No se encontró oficina registrada',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Text(
              'ID de usuario: ${_auth.currentUser?.uid ?? 'no logueado'}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Revisa la consola para más detalles',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadDashboardData, child: const Text('Reintentar')),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OfficeManagementScreen()),
                );
                _loadDashboardData();
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
    // 1. Verificar autenticación
    if (_auth.currentUser == null) {
      return const Center(child: Text('Usuario no autenticado'));
    }

    // 2. Verificar estado activo
    if (!_isUserActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: _buildInactiveAccountScreen(),
      );
    }

    // 3. Verificar si tiene oficina
    if (_officeData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
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
            const Text(
              'Resumen General',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isLargeScreen = constraints.maxWidth > 600;
                final crossAxisCount = isLargeScreen ? 3 : 2;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  padding: const EdgeInsets.all(8),
                  children: [
                    _buildSummaryCard(
                      'Recaudado Hoy',
                      currencyFormat.format(_dailyCollection),
                      Icons.today,
                      Colors.purple,
                      'Monto total recaudado en el día de hoy por todos tus cobradores.',
                    ),
                    _buildSummaryCard(
                      'Recaudo Mes',
                      currencyFormat.format(_collectedThisMonth),
                      Icons.attach_money,
                      Colors.purple,
                      'Suma de todos los pagos recibidos en el mes actual.',
                    ),
                    _buildSummaryCard(
                      'Balance Total',
                      currencyFormat.format(_totalBalance),
                      Icons.account_balance_wallet,
                      Colors.blue,
                      'Total histórico de dinero recaudado desde que comenzaste a usar la aplicación.',
                    ),
                    _buildSummaryCard(
                      'Créd. Activos',
                      currencyFormat.format(_activeCredits),
                      Icons.credit_card,
                      Colors.green,
                      'Valor total de los créditos que actualmente están activos y en proceso de pago.',
                    ),

                    if (isLargeScreen && crossAxisCount == 3)
                      const SizedBox.shrink(), // Espacio vacío para mantener alineación
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Cobradores activos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cobradores Activos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 1, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _collectors.length.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Recaudación Mensual'),
                            content: const Text(
                              'Esta sección muestra los cobradores activos. '
                              'Incluye la suma de todo lo recolectado por cada cobrador en el mes actual, este calculo se realiza luego de la liquidacion',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Entendido'),
                              ),
                            ],
                          ),
                    );
                  },
                  child: const Icon(Icons.help_outline, size: 20, color: Colors.grey),
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
