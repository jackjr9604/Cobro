import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart'; // Importación de sqflite
import 'package:path_provider/path_provider.dart'; // Para getDatabasesPath
import 'dart:io'; // Para Directory
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/user_service.dart';

Future<void> main() async {
  // 0. Inicializar sqflite_common_ffi para desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // 1. Asegurar la inicialización de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Configuración inicial de la base de datos
  try {
    // Verificar/crear directorio de la base de datos
    final databasesPath = await getDatabasesPath();
    await Directory(databasesPath).create(recursive: true);
    print('Ruta de la base de datos: $databasesPath');
  } catch (e) {
    print('Error al configurar ruta de DB: $e');
  }

  // 3. Inicialización de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase inicializado correctamente');
  } catch (e) {
    print('Error al inicializar Firebase: $e');
    // Puedes decidir si quieres continuar sin Firebase o terminar la app
  }

  // 4. Ejecutar la aplicación
  runApp(const AuthWrapper());
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Cobros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Estado de conexión
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Verificando autenticación...'),
                  ],
                ),
              ),
            );
          }

          // Errores
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Error: ${snapshot.error.toString()}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // Usuario autenticado
          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: UserService().getCurrentUserData(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                final role = userSnapshot.data?['role'] ?? 'user';

                return MainScreen(userRole: role);
              },
            );
          }

          // No autenticado
          return const LoginScreen();
        },
      ),
    );
  }
}
