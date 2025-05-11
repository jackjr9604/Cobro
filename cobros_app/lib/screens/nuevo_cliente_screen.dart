import 'package:flutter/material.dart';
import '../models/cliente_models.dart';
import '../data/database_helper.dart';

class NuevoClienteScreen extends StatefulWidget {
  const NuevoClienteScreen({super.key});

  @override
  State<NuevoClienteScreen> createState() => _NuevoClienteScreenState();
}

class _NuevoClienteScreenState extends State<NuevoClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();

  bool _isLoading = false; // <-- Añade esta línea

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Cliente')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingrese el nombre';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _telefonoController,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      TextFormField(
                        controller: _direccionController,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _guardarCliente,
                        child: const Text('Guardar Cliente'),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  void _guardarCliente() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true); // Activar loading

      final nuevoCliente = Cliente(
        nombre: _nombreController.text,
        telefono:
            _telefonoController.text.isNotEmpty
                ? _telefonoController.text
                : null,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        direccion:
            _direccionController.text.isNotEmpty
                ? _direccionController.text
                : null,
      );

      try {
        final id = await DatabaseHelper.instance.insertCliente(nuevoCliente);
        final clienteGuardado = nuevoCliente.copyWith(id: id);

        if (mounted) {
          Navigator.pop(context, clienteGuardado);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar cliente: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false); // Desactivar loading
        }
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    super.dispose();
  }
}
