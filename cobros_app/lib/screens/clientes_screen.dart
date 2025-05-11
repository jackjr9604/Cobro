import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Importación necesaria para DateFormat
import '../models/cliente_models.dart';
import '../data/database_helper.dart';
import 'nuevo_cliente_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> _clientes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    try {
      final clientes = await DatabaseHelper.instance.getClientes();
      setState(() {
        _clientes = clientes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar clientes: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadClientes),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _clientes.isEmpty
              ? const Center(child: Text('No hay clientes registrados'))
              : ListView.builder(
                itemCount: _clientes.length,
                itemBuilder: (context, index) {
                  final cliente = _clientes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(cliente.nombre),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cliente.telefono != null)
                            Text('Tel: ${cliente.telefono}'),
                          if (cliente.email != null)
                            Text('Email: ${cliente.email}'),
                          Text(
                            'Registrado: ${DateFormat('dd/MM/yyyy').format(cliente.fechaRegistro)}',
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Navegar a detalles/edición del cliente
                      },
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioCliente(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _mostrarFormularioCliente(BuildContext context) async {
    final nuevoCliente = await Navigator.push<Cliente>(
      context,
      MaterialPageRoute(builder: (context) => const NuevoClienteScreen()),
    );

    if (nuevoCliente != null) {
      // Mostrar snackbar de confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cliente ${nuevoCliente.nombre} guardado correctamente',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Actualizar la lista
      await _loadClientes();

      // Opcional: Mostrar el nuevo cliente en la parte superior
      setState(() {
        _clientes.insert(0, nuevoCliente);
      });
    }
  }
}
