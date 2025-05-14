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
  final TextEditingController _daysController = TextEditingController();
  String _method = 'Diario';

  double get _credit => double.tryParse(_creditController.text) ?? 0.0;
  double get _interestPercent => double.tryParse(_interestController.text) ?? 0.0;
  int get _days => int.tryParse(_daysController.text) ?? 1;

  double get _interest => _credit * (_interestPercent / 100);
  double get _total => _credit + _interest;
  double get _installment {
    switch (_method) {
      case 'Semanal':
        return _total / (_days / 7);
      case 'Quincenal':
        return _total / (_days / 15);
      case 'Mensual':
        return _total / (_days / 30);
      default:
        return _total / _days;
    }
  }

  Future<void> _saveCredit() async {
    if (!_formKey.currentState!.validate()) return;

    final docId = '${widget.clientId}_${const Uuid().v4().substring(0, 10)}';
    final uid =
        FirebaseFirestore
            .instance
            .app
            .options
            .projectId; // Reemplazar por el UID real del usuario logueado

    await FirebaseFirestore.instance.collection('credits').doc(docId).set({
      'clientId': widget.clientId,
      'officeId': widget.officeId,
      'createdBy': uid,
      'createdAt': Timestamp.now(),
      'credit': _credit,
      'interest': _interestPercent,
      'method': _method,
      'days': _days,
      'isActive': true,
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
                onChanged: (value) => setState(() => _method = value!),
                decoration: const InputDecoration(labelText: 'Forma de pago'),
              ),
              TextFormField(
                controller: _daysController,
                decoration: const InputDecoration(labelText: 'Número de días'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              const Divider(),
              ListTile(
                title: Text('Interés'),
                trailing: Text('\$${NumberFormat('#,##0', 'es_CO').format(_interest)}'),
                dense: true,
              ),
              ListTile(
                title: Text('Saldo total'),
                trailing: Text('\$${NumberFormat('#,##0', 'es_CO').format(_total)}'),
                dense: true,
              ),
              ListTile(
                title: Text('Valor de la cuota'),
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
