import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/users_detail_screen.dart';
import '../admin/offices_detail_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int totalUsers = 0;
  int adminUsers = 0;
  int ownerUsers = 0;
  int collectorUsers = 0;
  int activeUsers = 0;
  int inactiveUsers = 0;
  int totalOffices = 0;
  int assignedOffices = 0;
  int unassignedOffices = 0;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    final users = _firestore.collection('users');
    final offices = _firestore.collection('offices');

    final totalUsersSnap = await users.count().get();
    final adminSnap =
        await users.where('role', isEqualTo: 'admin').count().get();
    final ownerSnap =
        await users.where('role', isEqualTo: 'owner').count().get();
    final collectorSnap =
        await users.where('role', isEqualTo: 'collector').count().get();
    final activeSnap =
        await users.where('isActive', isEqualTo: true).count().get();
    final inactiveSnap =
        await users.where('isActive', isEqualTo: false).count().get();
    final totalOfficesSnap = await offices.count().get();
    final assignedOfficesSnap =
        await offices.where('createdBy', isNotEqualTo: null).count().get();
    final unassignedSnap =
        await offices.where('createdBy', isEqualTo: null).count().get();

    setState(() {
      totalUsers = totalUsersSnap.count ?? 0;
      adminUsers = adminSnap.count ?? 0;
      ownerUsers = ownerSnap.count ?? 0;
      collectorUsers = collectorSnap.count ?? 0;
      activeUsers = activeSnap.count ?? 0;
      inactiveUsers = inactiveSnap.count ?? 0;
      totalOffices = totalOfficesSnap.count ?? 0;
      assignedOffices = assignedOfficesSnap.count ?? 0;
      unassignedOffices = unassignedSnap.count ?? 0;
      isLoading = false;
    });
  }

  Widget _buildStatCard(
    String title,
    int count,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity, // Ocupa todo el ancho posible
        height: 120, // Ajusta esto según el tamaño deseado
        child: Card(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      appBar: AppBar(title: const Text('Panel de Administración')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sección de Usuarios
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usuarios',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  // Sección responsive para tarjetas de usuarios
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int columns = constraints.maxWidth > 600 ? 3 : 3;
                      return GridView.builder(
                        shrinkWrap:
                            true, // Evita que el GridView tome mucho espacio
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns, // Número de columnas
                          crossAxisSpacing:
                              8, // Espacio entre las tarjetas horizontalmente
                          mainAxisSpacing:
                              8, // Espacio entre las tarjetas verticalmente
                          childAspectRatio:
                              1.5, // Ajuste la relación de aspecto (ancho/alto)
                        ),
                        itemCount: 6, // 6 tarjetas de usuarios
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

                          return _buildStatCard(
                            titles[index],
                            counts[index],
                            colors[index],
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => UsersDetailScreen(
                                        filter: filters[index],
                                      ),
                                ),
                              );
                            },
                          );
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
                  Text(
                    'Oficinas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  // Sección responsive para tarjetas de oficinas
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int columns = constraints.maxWidth > 600 ? 3 : 3;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns, // Número de columnas
                          crossAxisSpacing:
                              8, // Espacio entre las tarjetas horizontalmente
                          mainAxisSpacing:
                              8, // Espacio entre las tarjetas verticalmente
                          childAspectRatio:
                              1.5, // Ajuste la relación de aspecto (ancho/alto)
                        ),
                        itemCount: 3, // 3 tarjetas de oficinas
                        itemBuilder: (context, index) {
                          List<String> titles = [
                            'Totales',
                            'Asignadas',
                            'Sin Dueño',
                          ];
                          List<int> counts = [
                            totalOffices,
                            assignedOffices,
                            unassignedOffices,
                          ];
                          List<Color> colors = [
                            Colors.indigo,
                            Colors.brown,
                            Colors.black54,
                          ];
                          List<OfficeFilter> filters = [
                            OfficeFilter.all,
                            OfficeFilter.assigned,
                            OfficeFilter.unassigned,
                          ];

                          return _buildStatCard(
                            titles[index],
                            counts[index],
                            colors[index],
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => OfficesDetailScreen(
                                        filter: filters[index],
                                      ),
                                ),
                              );
                            },
                          );
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
    );
  }
}
