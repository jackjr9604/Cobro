import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/register_screen.dart';
import 'main_screen.dart';
import '../services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Iniciar Sesión'),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    //Validación del formulario-Verifica si el formulario actual es válido (por ejemplo, que los campos de email y contraseña no estén vacíos).
    if (_formKey.currentState!.validate()) {
      // Mostrar indicador de carga
      setState(() => _isLoading = true);
      try {
        //Intento de inicio de sesión -Se llama a un método de autenticación, pasando el email y la contraseña sin espacios en blanco al inicio o final.
        //Se espera la respuesta (await) de un servicio que maneja la autenticación (_authService).
        //Si el inicio de sesión es exitoso, se recibe un user
        final user = await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (user != null && mounted) {
          //Se asegura de que el usuario fue autenticado y que el widget actual aún está montado
          //Obtener datos del usuario
          final userData =
              await UserService()
                  .getCurrentUserData(); //Llama a otro servicio (UserService) para obtener más datos del usuario, como su rol.
          final role =
              userData?['role'] ??
              'user'; //Si no hay rol en los datos, se asigna 'user' por defecto.

          //Redirección a la pantalla principal
          //Navega hacia MainScreen, reemplazando la pantalla actual (no se puede volver atrás).
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(userRole: role),
            ), //Se pasa el rol del usuario como parámetro a la pantalla principal.
          );
        }
      } catch (e) {
        // Manejo de errores
      } finally {
        //Ocultar el indicador de carga
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
