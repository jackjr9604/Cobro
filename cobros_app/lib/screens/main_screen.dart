import '../screens/roles/admin/offices_screen.dart';
import '../screens/roles/admin/users_screen.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'home_screen.dart';
import 'roles/collector/pays/cobros_actives_screen.dart';
import 'roles/admin/admin_home_screen.dart'; // Importación corregida
import '../utils/responsive.dart';
import 'roles/owner/Register_Collector.dart';
import 'roles/collector/collector_home_screen.dart';
import 'roles/owner/office.dart';
import 'clients/clients_Screen.dart';
import 'roles/owner/Liquidations/Liquidation_Report_Screen.dart';
import '../screens/roles/owner/routes/routes_screen.dart';
import '../utils/app_theme.dart';

class MainScreen extends StatefulWidget {
  final String userRole; // Añade este parámetro

  const MainScreen({super.key, required this.userRole}); // Actualiza el constructor

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class RoleHelper {
  static String getRoleName(String? roleId, {String defaultName = 'Usuario'}) {
    switch (roleId) {
      case 'admin':
        return 'Admin';
      case 'owner':
        return 'Oficina';
      case 'collector':
        return 'Cobrador';
      default:
        return defaultName;
    }
  }

  // Opcional: Método para obtener icono según rol
  static IconData getRoleIcon(String? roleId) {
    switch (roleId) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'owner':
        return Icons.business;
      case 'collector':
        return Icons.attach_money;
      default:
        return Icons.person;
    }
  }
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _currentUserData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      debugPrint('Iniciando carga de datos del usuario...');
      final userData = await _userService.getCurrentUserData();
      debugPrint('Datos del usuario obtenidos: ${userData?.toString()}');

      if (mounted) {
        setState(() {
          _currentUserData = userData;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error al cargar datos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<Widget> _getScreensBasedOnRole() {
    if (_isLoading) return [const Center(child: CircularProgressIndicator())];

    switch (_currentUserData?['role']) {
      case 'admin':
        return [const AdminHomeScreen(), const UsersScreen(), const OfficesScreen()];
      case 'owner':
        return [
          const HomeScreen(),
          const OfficeManagementScreen(),
          const RegisterCollector(),
          const ClientsScreen(),
          const RoutesScreen(),
          const LiquidationReportScreen(),
        ];
      case 'collector':
        return [const CollectorHomeScreen(), const ClientsScreen(), const CobrosScreen()];
      default:
        return [const HomeScreen()];
    }
  }

  List<Widget> _getMenuItems(BuildContext context) {
    if (_isLoading) return [const SizedBox()];

    final menuItems = <Widget>[
      ListTile(
        leading: const Icon(Icons.home),
        title: const Text('Inicio'),
        selected: _selectedIndex == 0,
        selectedTileColor: Colors.blue[100],
        onTap: () => _updateIndex(0, context),
      ),
    ];

    if (_currentUserData?['role'] == 'admin') {
      menuItems.addAll([
        ListTile(
          leading: const Icon(Icons.supervised_user_circle),
          title: const Text('Usuarios'),
          selected: _selectedIndex == 1,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(1, context),
        ),
        ListTile(
          leading: const Icon(Icons.business),
          title: const Text('Oficinas'),
          selected: _selectedIndex == 2,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(2, context),
        ),
      ]);
    } else if (_currentUserData?['role'] == 'owner') {
      menuItems.addAll([
        ListTile(
          leading: const Icon(Icons.local_post_office),
          title: const Text('Oficina'),
          selected: _selectedIndex == 1,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(1, context),
        ),
        ListTile(
          leading: const Icon(Icons.badge),
          title: const Text('Cobradores'),
          selected: _selectedIndex == 2,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(2, context),
        ),
        ListTile(
          leading: const Icon(Icons.group),
          title: const Text('Clientes'),
          selected: _selectedIndex == 3,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(3, context),
        ),
        ListTile(
          leading: const Icon(Icons.payment),
          title: const Text('Cobros'),
          selected: _selectedIndex == 4,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(4, context),
        ),
        ListTile(
          leading: const Icon(Icons.report),
          title: const Text('Reporte'),
          selected: _selectedIndex == 5,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(5, context),
        ),
      ]);
    } else if (_currentUserData?['role'] == 'collector') {
      menuItems.addAll([
        ListTile(
          leading: const Icon(Icons.payment),
          title: const Text('Clientes'),
          selected: _selectedIndex == 1,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(1, context),
        ),
        ListTile(
          leading: const Icon(Icons.payment),
          title: const Text('Cobros'),
          selected: _selectedIndex == 2,
          selectedTileColor: Colors.blue[100],
          onTap: () => _updateIndex(2, context),
        ),
      ]);
    }
    menuItems.addAll([
      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Cerrar Sesión'),
        onTap: () async {
          await _authService.signOut();
          if (Responsive.isMobile(context)) Navigator.pop(context);
        },
      ),
    ]);

    return menuItems;
  }

  void _updateIndex(int index, BuildContext context) {
    setState(() => _selectedIndex = index);
    if (Responsive.isMobile(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final screens = _getScreensBasedOnRole();

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        toolbarHeight: isMobile ? 56 : 64,
        backgroundColor: Theme.of(context).primaryColor,
        automaticallyImplyLeading: isMobile,

        iconTheme: IconThemeData(
          color: Colors.white, // Cambia el color del ícono del menú hamburguesa
        ),
      ),
      drawer: isMobile ? _buildDrawer(context) : null,
      body: Row(
        children: [
          if (!isMobile) _buildDesktopMenu(context),
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    if (_isLoading) return const Text('Cargando...');

    return Row(
      children: [
        Text(
          'CLIQ',
          style: TextStyle(
            fontFamily: AppTheme.primaryFont, //nombre de tu fuente
            fontSize: 30, // Tamaño de la fuente
            color: AppTheme.neutroColor, // Color del texto
            fontWeight: FontWeight.bold, // Peso de la fuente (opcional)
          ),
        ),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    String roleName = RoleHelper.getRoleName(_currentUserData?['role']);

    IconData roleIcon = RoleHelper.getRoleIcon(_currentUserData?['role']);
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      elevation: 16, //sombra
      child: Container(
        decoration: BoxDecoration(color: Colors.white70),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                '$roleName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                _currentUserData?['email'] ?? 'ejemplo@ejemplo.com',
                style: const TextStyle(fontSize: 14),
              ),
              currentAccountPicture: CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.neutroColor,
                child: Icon(roleIcon, size: 40, color: AppTheme.primaryColor),
              ),
              decoration: BoxDecoration(color: AppTheme.primaryColor),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ..._getMenuItems(context).whereType<Widget>().toList(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMenu(BuildContext context) {
    String roleName = RoleHelper.getRoleName(_currentUserData?['role']);
    IconData roleIcon = RoleHelper.getRoleIcon(_currentUserData?['role']);

    return Container(
      width: 250,
      color: Colors.blue[50],
      child: Column(
        children: [
          Container(
            height: 200,
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    roleIcon,
                    color: AppTheme.neutroColor,
                    size: 80, // Cambia este valor al tamaño que necesites
                  ),
                  SizedBox(width: 8),
                  Text('$roleName', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 20),
                  Text(
                    _currentUserData?['email'] ?? 'ejemplo@ejemplo.com',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ..._getMenuItems(context).whereType<Widget>().toList(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
