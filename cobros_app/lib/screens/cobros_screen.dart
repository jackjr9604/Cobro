import 'package:flutter/material.dart';
import '../models/cobro_model.dart';
import '../data/database_helper.dart';
import 'package:intl/intl.dart';
import 'nuevo_cobro_screen.dart';

class CobrosScreen extends StatefulWidget {
  const CobrosScreen({super.key});

  @override
  State<CobrosScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends State<CobrosScreen> {
  List<Cobro> _cobros = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCobros();
  }

  Future<void> _loadCobros() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final cobros = await DatabaseHelper.instance.getCobros();

      setState(() {
        _cobros = cobros;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar cobros: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _mostrarFormularioCobro(BuildContext context) async {
    final nuevoCobro = await Navigator.push<Cobro>(
      context,
      MaterialPageRoute(
        builder:
            (context) => NuevoCobroScreen(
              onCobroCreado: (cobro) => Navigator.pop(context, cobro),
            ),
      ),
    );

    if (nuevoCobro != null) {
      try {
        setState(() => _isLoading = true);

        final id = await DatabaseHelper.instance.insertCobro(nuevoCobro);

        if (id > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cobro a ${nuevoCobro.clienteNombre} guardado correctamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
          await _loadCobros();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar cobro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCobro(int index) async {
    final cobro = _cobros[index];
    final cobroId = cobro.id;

    if (cobroId == null) return;

    try {
      setState(() => _isLoading = true);

      final result = await DatabaseHelper.instance.deleteCobro(cobroId);

      if (result > 0) {
        setState(() {
          _cobros.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cobro eliminado'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () async {
                try {
                  final newId = await DatabaseHelper.instance.insertCobro(
                    cobro,
                  );
                  if (newId > 0) {
                    setState(() {
                      _cobros.insert(index, cobro.copyWith(id: newId));
                    });
                  }
                } catch (e) {
                  debugPrint('Error al deshacer eliminación: $e');
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar cobro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de cobros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCobros,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioCobro(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 50),
            const SizedBox(height: 20),
            Text(
              'Error al cargar cobros',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadCobros,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_cobros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.list, size: 50, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'No hay cobros registrados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text('Presiona el botón + para agregar un nuevo cobro'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _cobros.length,
      itemBuilder: (context, index) {
        final cobro = _cobros[index];
        return Dismissible(
          key: Key('cobro_${cobro.id}_${cobro.fecha.millisecondsSinceEpoch}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Confirmar eliminación'),
                    content: Text(
                      '¿Eliminar cobro de ${cobro.clienteNombre} por \$${cobro.monto.toStringAsFixed(2)}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
            );
          },
          onDismissed: (direction) => _deleteCobro(index),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.payment, color: Colors.blue),
              title: Text(
                cobro.clienteNombre,
              ), // Cambiado de cliente a clienteNombre
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy - HH:mm').format(cobro.fecha)}',
                  ),
                  Text('Ubicación: ${cobro.ubicacion}'),
                ],
              ),
              trailing: Text(
                '\$${cobro.monto.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mostrar detalles de ${cobro.clienteNombre}'),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
