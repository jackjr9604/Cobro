//Este archivo es el punto de entrada principal

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/user_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import '/utils/app_theme.dart';
import 'package:workmanager/workmanager.dart';
import 'services/auth_service.dart';
import 'package:provider/provider.dart';
import 'screens/roles/owner/member_ship_screen.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'membershipCheck') {
      try {
        final auth = FirebaseAuth.instance;
        final user = auth.currentUser;
        if (user != null) {
          final service = AuthService();
          await service.checkAndUpdateMembershipStatus();
        }
      } catch (e) {
        debugPrint('Error en background task: $e');
      }
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  // Configuración inicial
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Error al inicializar Firebase: $e');
  }

  // Configuración adicional
  await initializeDateFormatting('es_CO', null);

  // Workmanager solo en mobile
  if (Platform.isAndroid || Platform.isIOS) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'membershipCheck',
      'membershipCheck',
      frequency: const Duration(hours: 12),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<UserService>(create: (_) => UserService()),
      ],
      child: const AuthWrapper(),
    ),
  );
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  DateTime? _lastVerificationTime;
  static const _verificationInterval = Duration(minutes: 15);
  bool _isCheckingMembership = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastVerificationTime = DateTime.now(); // Inicializar con tiempo actual
    _verifyInitialMembership();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMembershipOnResume();
    }
  }

  Future<void> _checkMembershipOnResume() async {
    final now = DateTime.now();
    debugPrint('App reanudada a las $now');

    if (_lastVerificationTime != null) {
      final timeSinceLastCheck = now.difference(_lastVerificationTime!);
      debugPrint('Tiempo desde última verificación: $timeSinceLastCheck');

      if (timeSinceLastCheck >= _verificationInterval) {
        debugPrint('Realizando verificación de membresía');
        await _verifyMembershipStatus();
        _lastVerificationTime = DateTime.now(); // Actualizar momento de última verificación
      } else {
        debugPrint(
          'No se requiere verificación aún. Faltan: ${_verificationInterval - timeSinceLastCheck}',
        );
      }
    }
  }

  Future<void> _verifyInitialMembership() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _verifyMembershipStatus();
      _lastVerificationTime = DateTime.now(); // Actualizar después de verificación inicial
    }
  }

  Future<void> _verifyMembershipStatus() async {
    if (_isCheckingMembership || !mounted) return;

    setState(() => _isCheckingMembership = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.checkAndUpdateMembershipStatus();
    } catch (e) {
      debugPrint('Error verificando membresía: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingMembership = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Cobros',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          // Manejo de estados
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen('Verificando autenticación...');
          }

          if (authSnapshot.hasError) {
            return _buildErrorScreen(authSnapshot.error.toString());
          }

          // Usuario no autenticado
          if (authSnapshot.data == null) {
            return const LoginScreen();
          }

          // Usuario autenticado
          return FutureBuilder<Map<String, dynamic>?>(
            future: Provider.of<UserService>(context, listen: false).getCurrentUserData(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen('Cargando datos...');
              }

              if (userSnapshot.hasError) {
                return _buildErrorScreen(userSnapshot.error.toString());
              }

              final userData = userSnapshot.data;
              final role = userData?['role'] ?? 'user';

              // Verificación de membresía optimizada
              final membershipStatus = userData?['activeStatus'] ?? {};
              final isActive = membershipStatus['isActive'] ?? false;
              final endDate = membershipStatus['endDate']?.toDate();

              if (userData?.containsKey('activeStatus') == true &&
                  (!isActive || (endDate != null && DateTime.now().isAfter(endDate)))) {
                return const MembershipScreen();
              }

              return MainScreen(userRole: role);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(message)],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red))),
    );
  }
}
