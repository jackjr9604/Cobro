import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class CreateCreditScreen extends StatefulWidget {
  final String clientId;
  final String officeId;

  const CreateCreditScreen({super.key, required this.clientId, required this.officeId});

  @override
  State<CreateCreditScreen> createState() => _CreateCreditScreenState();
}

class _CreateCreditScreenState extends State<CreateCreditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _cuotController = TextEditingController();

  String _method = 'Diario';
  String? _selectedDay;

  double get _credit => double.tryParse(_creditController.text) ?? 0.0;
  double get _interestPercent => double.tryParse(_interestController.text) ?? 0.0;
  int get _cuot => int.tryParse(_cuotController.text) ?? 1;

  double get _interest => _credit * (_interestPercent / 100);
  double get _total => _credit + _interest;
  double get _installment => _total / (_cuot > 0 ? _cuot : 1);

  final List<String> _daysOfWeek = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  Future<void> _saveCredit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_method == 'Semanal' && (_selectedDay == null || _selectedDay!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Por favor, selecciona un día de la semana')));
      return;
    }

    // Obtener el UID del cobrador desde el cliente
    final clientDoc =
        await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).get();

    final clientData = clientDoc.data();
    if (clientData == null || !clientData.containsKey('createdBy')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: el cliente no tiene un creador asignado')),
      );
      return;
    }

    final clientCreatorUid = clientData['createdBy'];

    final docId = '${widget.clientId}_${const Uuid().v4().substring(0, 10)}';

    Map<String, dynamic> dataToSave = {
      'clientId': widget.clientId,
      'officeId': widget.officeId,
      'createdBy': clientCreatorUid,
      'createdAt': Timestamp.now(),
      'credit': _credit,
      'interest': _interestPercent,
      'method': _method,
      'cuot': _cuot,
      'isActive': true,
    };

    if (_method == 'Semanal') {
      dataToSave['day'] = _selectedDay;
    }

    // Guardar el crédito
    await FirebaseFirestore.instance.collection('credits').doc(docId).set(dataToSave);

    // Obtener todos los créditos actuales del cliente
    final clientCreditsSnapshot =
        await FirebaseFirestore.instance
            .collection('credits')
            .where('clientId', isEqualTo: widget.clientId)
            .get();

    // El número consecutivo será la cantidad de créditos + 1 (porque este aún no cuenta si se consulta antes)
    final creditNumber = clientCreditsSnapshot.docs.length;

    // Crear el Map a agregar al documento del cliente
    final creditMap = {
      'credit#': creditNumber,
      'credit': _credit,
      'interest': _interestPercent,
      'method': _method,
      'createdAt': Timestamp.now(),
      'creditId': docId,
    };

    // Actualizar el documento del cliente con un nuevo campo con ID del crédito
    await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).update({
      docId: creditMap,
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo crédito')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _creditController,
                decoration: const InputDecoration(labelText: 'Valor del crédito'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                onChanged: (_) => setState(() {}),
              ),
              TextFormField(
                controller: _interestController,
                decoration: const InputDecoration(labelText: 'Interés %'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                onChanged: (_) => setState(() {}),
              ),
              DropdownButtonFormField<String>(
                value: _method,
                items: const [
                  DropdownMenuItem(value: 'Diario', child: Text('Diario')),
                  DropdownMenuItem(value: 'Semanal', child: Text('Semanal')),
                  DropdownMenuItem(value: 'Quincenal', child: Text('Quincenal')),
                  DropdownMenuItem(value: 'Mensual', child: Text('Mensual')),
                ],
                onChanged:
                    (value) => setState(() {
                      _method = value!;
                      if (_method != 'Semanal') _selectedDay = null;
                    }),
                decoration: const InputDecoration(labelText: 'Forma de pago'),
              ),
              TextFormField(
                controller: _cuotController,
                decoration: const InputDecoration(labelText: 'Número de cuotas'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Campo requerido';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Ingrese un número válido mayor a 0';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),

              if (_method == 'Semanal') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDay,
                  decoration: const InputDecoration(labelText: 'Día de la semana'),
                  items:
                      _daysOfWeek
                          .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                          .toList(),
                  onChanged: (value) => setState(() => _selectedDay = value),
                  validator: (value) {
                    if (_method == 'Semanal' && (value == null || value.isEmpty)) {
                      return 'Por favor, selecciona un día de la semana';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 20),

              const Divider(),
              ListTile(
                title: const Text('Interés'),
                trailing: Text('\$${NumberFormat('#,##0', 'es_CO').format(_interest)}'),
                dense: true,
              ),
              ListTile(
                title: const Text('Saldo total'),
                trailing: Text('\$${NumberFormat('#,##0', 'es_CO').format(_total)}'),
                dense: true,
              ),
              ListTile(
                title: const Text('Valor de la cuota'),
                trailing: Text('\$${NumberFormat('#,##0', 'es_CO').format(_installment)}'),
                dense: true,
              ),

              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saveCredit, child: const Text('Guardar crédito')),
            ],
          ),
        ),
      ),
    );
  }
}
