import 'package:flutter/material.dart';
import '../models/cobro_model.dart';
import '../models/cliente_models.dart';
import '../data/database_helper.dart';
import '../utils/responsive.dart';
import 'nuevo_cliente_screen.dart';

class NuevoCobroScreen extends StatefulWidget {
  final Function(Cobro) onCobroCreado;

  const NuevoCobroScreen({super.key, required this.onCobroCreado});

  @override
  State<NuevoCobroScreen> createState() => _NuevoCobroScreenState();
}

class _NuevoCobroScreenState extends State<NuevoCobroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _ubicacionController = TextEditingController();
  Cliente? _clienteSeleccionado;
  List<Cliente> _clientes = [];
  bool _cargandoClientes = true;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    try {
      final clientes = await DatabaseHelper.instance.getClientes();
      setState(() {
        _clientes = clientes;
        _cargandoClientes = false;
      });
    } catch (e) {
      setState(() => _cargandoClientes = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar clientes: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double paddingValue = isMobile ? 16.0 : 24.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Cobro'), centerTitle: !isMobile),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(paddingValue),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildClienteField(),
                    SizedBox(height: isMobile ? 16 : 20),
                    _buildTextField(
                      controller: _montoController,
                      label: 'Monto',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      isMobile: isMobile,
                    ),
                    SizedBox(height: isMobile ? 16 : 20),
                    _buildTextField(
                      controller: _ubicacionController,
                      label: 'Ubicación',
                      icon: Icons.location_on,
                      isMobile: isMobile,
                      hintText: 'Ej: Av. Principal #123, Ciudad',
                    ),
                    SizedBox(height: isMobile ? 24 : 32),
                    _buildSubmitButton(isMobile),
                    if (_clientes.isEmpty && !_cargandoClientes)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: TextButton(
                          onPressed: () {
                            // Opción para redirigir a crear cliente
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const NuevoClienteScreen(),
                              ),
                            ).then((_) => _cargarClientes());
                          },
                          child: const Text(
                            'No hay clientes. ¿Desea crear uno nuevo?',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClienteField() {
    return DropdownButtonFormField<Cliente>(
      value: _clienteSeleccionado,
      decoration: InputDecoration(
        labelText: 'Cliente',
        prefixIcon: const Icon(Icons.person),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
      ),
      items:
          _clientes.map((cliente) {
            return DropdownMenuItem<Cliente>(
              value: cliente,
              child: Text(cliente.nombre, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
      onChanged: (cliente) => setState(() => _clienteSeleccionado = cliente),
      validator: (value) {
        if (value == null) return 'Seleccione un cliente';
        return null;
      },
      isExpanded: true,
      hint:
          _cargandoClientes
              ? const Text('Cargando clientes...')
              : const Text('Seleccione un cliente'),
      disabledHint: const Text('No hay clientes disponibles'),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isMobile,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.symmetric(
          vertical: isMobile ? 12 : 16,
          horizontal: 16,
        ),
      ),
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingrese $label';
        }
        if (label == 'Monto' && double.tryParse(value) == null) {
          return 'Ingrese un número válido';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(bool isMobile) {
    return ElevatedButton(
      onPressed: _guardarCobro,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        'GUARDAR COBRO',
        style: TextStyle(
          fontSize: isMobile ? 16 : 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _guardarCobro() {
    if (_formKey.currentState!.validate() && _clienteSeleccionado != null) {
      final nuevoCobro = Cobro(
        clienteId: _clienteSeleccionado!.id!,
        clienteNombre: _clienteSeleccionado!.nombre,
        monto: double.parse(_montoController.text),
        fecha: DateTime.now(),
        ubicacion: _ubicacionController.text,
      );
      widget.onCobroCreado(nuevoCobro);
    } else if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleccione un cliente')));
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }
}
