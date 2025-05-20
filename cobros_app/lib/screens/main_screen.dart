import 'package:cobros_app/screens/roles/admin/offices_screen.dart';
import 'package:cobros_app/screens/roles/admin/users_screen.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'home_screen.dart';
import 'roles/collector/pays/cobros_screen.dart';
import 'roles/admin/admin_home_screen.dart'; // Importación corregida
import '../utils/responsive.dart';
import 'roles/owner/Register_Collector.dart';
import 'roles/collector/collector_home_screen.dart';
import 'roles/owner/office.dart';
import 'clients/clients_Screen.dart';
import '../screens/roles/owner/routes/Local_Report_Screen.dart.dart';
import '../screens/roles/owner/routes/routes_screen.dart';

class MainScreen extends StatefulWidget {
  final String userRole; // Añade este parámetro

  const MainScreen({super.key, required this.userRole}); // Actualiza el constructor

  @override
  State<MainScreen> createState() => _MainScreenState();
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
      final userData = await _userService.getCurrentUserData();
      setState(() {
        _currentUserData = userData;
        _isLoading = false;
      });
    } catch (e) {
      // Maneja cualquier error que ocurra al cargar los datos
      setState(() {
        _isLoading = false;
      });
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
        actions: _buildAppBarActions(),
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

    String roleName;
    switch (_currentUserData?['role']) {
      case 'admin':
        roleName = 'Admin';
        break;
      case 'owner':
        roleName = 'Oficina';
        break;
      case 'collector':
        roleName = 'Cobrador';
        break;
      default:
        roleName = 'Usuario';
    }

    return Row(
      children: [
        Text(
          'CLIQ',
          style: TextStyle(
            fontFamily: 'roboto', //nombre de tu fuente
            fontSize: 24, // Tamaño de la fuente
            color: Colors.white, // Color del texto
            fontWeight: FontWeight.bold, // Peso de la fuente (opcional)
          ),
        ),
        const SizedBox(width: 20), // Espacio entre "CLIQ" y el roleName
        Text(
          '$roleName',
          style: TextStyle(
            fontFamily: 'arial', //nombre de tu fuente
            fontSize: 15, // Tamaño de la fuente
            color: Colors.white, // Color del texto
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      if (!_isLoading && _currentUserData != null)
        GestureDetector(
          onTap: () {
            // Mostrar un SnackBar al tocar el ícono en pantallas táctiles
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_currentUserData?['email'] ?? 'No disponible'),
                duration: const Duration(seconds: 3),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.account_circle),
          ),
        ),
      IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUserData),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(child: ListView(padding: EdgeInsets.zero, children: _getMenuItems(context)));
  }

  Widget _buildDesktopMenu(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.blue[50],
      child: Column(
        children: [
          Container(
            height: 150,
            color: Colors.blue,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        _currentUserData?['photoUrl'] != null
                            ? NetworkImage(_currentUserData!['photoUrl'])
                            : null,
                    child:
                        _currentUserData?['photoUrl'] == null
                            ? const Icon(Icons.person, size: 30)
                            : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentUserData?['displayName'] ?? 'Usuario',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: ListView(children: _getMenuItems(context))),
        ],
      ),
    );
  }
}
