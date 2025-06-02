import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'users_detail_screen.dart';
import 'offices_detail_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variables de estadísticas
  int totalUsers = 0;
  int adminUsers = 0;
  int ownerUsers = 0;
  int collectorUsers = 0;
  int activeUsers = 0;
  int inactiveUsers = 0;
  int totalOffices = 0;
  int assignedOffices = 0;
  int unassignedOffices = 0;

  // Control de cache y estado
  bool isLoading = true;
  bool _isRefreshing = false;
  DateTime? _lastFetchTime;
  Map<String, dynamic>? _cachedData;
  static const Duration cacheDuration = kDebugMode ? Duration(seconds: 30) : Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchStatistics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_lastFetchTime != null && DateTime.now().difference(_lastFetchTime!) > cacheDuration) {
        _fetchStatistics(forceRefresh: true);
      }
    }
  }

  Future<void> _fetchStatistics({bool forceRefresh = false}) async {
    try {
      // Verificar si podemos usar datos cacheados
      final now = DateTime.now();
      final shouldUseCache =
          !forceRefresh &&
          _lastFetchTime != null &&
          now.difference(_lastFetchTime!) < cacheDuration &&
          _cachedData != null;

      if (shouldUseCache) {
        _applyCachedData();
        return;
      }

      // Mostrar estado de carga adecuado
      if (_cachedData == null) {
        setState(() => isLoading = true);
      } else {
        setState(() => _isRefreshing = true);
      }

      // Ejecutar todas las consultas en paralelo
      final users = _firestore.collection('users');
      final offices = _firestore.collection('offices');

      final results = await Future.wait([
        users.count().get(),
        users.where('role', isEqualTo: 'admin').count().get(),
        users.where('role', isEqualTo: 'owner').count().get(),
        users.where('role', isEqualTo: 'collector').count().get(),
        users.where('isActive', isEqualTo: true).count().get(),
        users.where('isActive', isEqualTo: false).count().get(),
        offices.count().get(),
        offices.where('createdBy', isNotEqualTo: null).count().get(),
        offices.where('createdBy', isEqualTo: null).count().get(),
      ]);

      // Guardar en cache
      final newData = {
        'totalUsers': results[0].count ?? 0,
        'adminUsers': results[1].count ?? 0,
        'ownerUsers': results[2].count ?? 0,
        'collectorUsers': results[3].count ?? 0,
        'activeUsers': results[4].count ?? 0,
        'inactiveUsers': results[5].count ?? 0,
        'totalOffices': results[6].count ?? 0,
        'assignedOffices': results[7].count ?? 0,
        'unassignedOffices': results[8].count ?? 0,
      };

      _lastFetchTime = DateTime.now();
      _cachedData = newData;

      // Actualizar UI
      setState(() {
        _applyCachedData();
        isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        _isRefreshing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyCachedData() {
    if (_cachedData == null) return;

    setState(() {
      totalUsers = _cachedData!['totalUsers'];
      adminUsers = _cachedData!['adminUsers'];
      ownerUsers = _cachedData!['ownerUsers'];
      collectorUsers = _cachedData!['collectorUsers'];
      activeUsers = _cachedData!['activeUsers'];
      inactiveUsers = _cachedData!['inactiveUsers'];
      totalOffices = _cachedData!['totalOffices'];
      assignedOffices = _cachedData!['assignedOffices'];
      unassignedOffices = _cachedData!['unassignedOffices'];
    });
  }

  Widget _buildStatCard(String title, int count, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 120,
        child: Card(
          color: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _fetchStatistics(forceRefresh: true),
                tooltip: 'Recargar datos',
              ),
              if (_isRefreshing)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchStatistics(forceRefresh: true),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Sección de Usuarios
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Usuarios', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int columns =
                            constraints.maxWidth > 1000
                                ? 4
                                : constraints.maxWidth > 600
                                ? 3
                                : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.5,
                          ),
                          itemCount: 6,
                          itemBuilder: (context, index) {
                            List<String> titles = [
                              'Totales',
                              'Admins',
                              'Owners',
                              'Collectors',
                              'Activos',
                              'Inactivos',
                            ];
                            List<int> counts = [
                              totalUsers,
                              adminUsers,
                              ownerUsers,
                              collectorUsers,
                              activeUsers,
                              inactiveUsers,
                            ];
                            List<Color> colors = [
                              Colors.blue,
                              Colors.green,
                              Colors.orange,
                              Colors.purple,
                              Colors.teal,
                              Colors.red,
                            ];
                            List<UserFilter> filters = [
                              UserFilter.all,
                              UserFilter.admin,
                              UserFilter.owner,
                              UserFilter.collector,
                              UserFilter.active,
                              UserFilter.inactive,
                            ];

                            return _buildStatCard(titles[index], counts[index], colors[index], () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UsersDetailScreen(filter: filters[index]),
                                ),
                              );
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Sección de Oficinas
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Oficinas', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int columns =
                            constraints.maxWidth > 1000
                                ? 3
                                : constraints.maxWidth > 600
                                ? 2
                                : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.5,
                          ),
                          itemCount: 3,
                          itemBuilder: (context, index) {
                            List<String> titles = ['Totales', 'Asignadas', 'Sin Dueño'];
                            List<int> counts = [totalOffices, assignedOffices, unassignedOffices];
                            List<Color> colors = [Colors.indigo, Colors.brown, Colors.black54];
                            List<OfficeFilter> filters = [
                              OfficeFilter.all,
                              OfficeFilter.assigned,
                              OfficeFilter.unassigned,
                            ];

                            return _buildStatCard(titles[index], counts[index], colors[index], () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OfficesDetailScreen(filter: filters[index]),
                                ),
                              );
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
