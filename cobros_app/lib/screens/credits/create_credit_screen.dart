import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateCreditScreen extends StatefulWidget {
  final String clientId;
  final String officeId;
  final String userId;

  const CreateCreditScreen({
    super.key,
    required this.clientId,
    required this.officeId,
    required this.userId,
  });

  @override
  State<CreateCreditScreen> createState() => _CreateCreditScreenState();
}

class _CreateCreditScreenState extends State<CreateCreditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _cuotController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _creditController.addListener(_formatCreditValue);
  }

  @override
  void dispose() {
    _creditController.removeListener(_formatCreditValue);
    super.dispose();
  }

  void _formatCreditValue() {
    final text = _creditController.text;
    final selection = _creditController.selection;

    // Si el texto está vacío, no hacer nada
    if (text.isEmpty) return;

    // Guardar la posición original del cursor
    final cursorPosition = selection.extentOffset;

    // Limpiar el texto (eliminar todos los puntos)
    final cleanText = text.replaceAll('.', '');

    // Formatear el número
    String formattedText;
    try {
      final number = int.parse(cleanText);
      formattedText = NumberFormat('#,##0', 'es_CO').format(number);
    } catch (e) {
      formattedText = text;
    }

    // Calcular la nueva posición del cursor
    int newCursorPosition = cursorPosition + (formattedText.length - text.length);

    // Asegurar que la posición del cursor esté dentro de los límites
    newCursorPosition = newCursorPosition.clamp(0, formattedText.length);

    // Solo actualizar si hubo cambios
    if (formattedText != text) {
      _creditController.value = TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    }
  }

  // Modificar el getter para limpiar el valor
  double get _credit {
    final cleanValue = _creditController.text.replaceAll('.', '');
    return double.tryParse(cleanValue) ?? 0.0;
  }

  String _method = 'Diario';
  String? _selectedDay;

  double get _interestPercent => double.tryParse(_interestController.text) ?? 0.0;
  int get _cuot => int.tryParse(_cuotController.text) ?? 1;

  double get _interest => _credit * (_interestPercent / 100);
  double get _total => _credit + _interest;
  double get _installment => _total / (_cuot > 0 ? _cuot : 1);

  // Función para calcular fechas de pago basadas en el método
  List<DateTime> _calculatePaymentDates(DateTime startDate, String method, String? dayOfWeek) {
    final dates = <DateTime>[];
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day); // Fecha sin hora

    switch (method) {
      case 'Diario':
        for (int i = 1; i <= _cuot; i++) {
          dates.add(startDate.add(Duration(days: i)));
        }
        break;

      case 'Semanal':
        if (dayOfWeek != null) {
          final weekDays = [
            'Lunes',
            'Martes',
            'Miércoles',
            'Jueves',
            'Viernes',
            'Sábado',
            'Domingo',
          ];
          final targetDay = weekDays.indexOf(dayOfWeek);

          DateTime nextDate = startDate;
          while (nextDate.weekday != targetDay + 1) {
            nextDate = nextDate.add(const Duration(days: 1));
          }

          for (int i = 0; i < _cuot; i++) {
            dates.add(nextDate.add(Duration(days: i * 7)));
          }
        }
        break;

      case 'Quincenal':
        for (int i = 1; i <= _cuot; i++) {
          dates.add(startDate.add(Duration(days: i * 15)));
        }
        break;

      case 'Mensual':
        for (int i = 1; i <= _cuot; i++) {
          // Añadir meses manteniendo el día (ajustando si el día no existe en el mes)
          final nextMonth = startDate.month + i;
          final year = startDate.year + (nextMonth ~/ 12);
          final month = nextMonth % 12;
          final day = startDate.day;

          DateTime nextDate;
          try {
            nextDate = DateTime(year, month, day);
          } catch (e) {
            // Si el día no existe en el mes (ej. 31 en abril), usar último día del mes
            nextDate = DateTime(year, month + 1, 0);
          }

          dates.add(nextDate);
        }
        break;
    }

    return dates;
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, selecciona un día de la semana'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      // Mostrar diálogo de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Obtener el ownerId (el collector debe crear en la estructura del owner)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();

      // Verificación segura del rol
      final userData = userDoc.data();
      final ownerId =
          (userData != null && userData['role'] == 'collector')
              ? (userData['createdBy'] as String? ?? widget.userId)
              : widget.userId;

      // 2. Verificar que el cliente existe en la estructura del owner
      final clientDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(ownerId)
              .collection('offices')
              .doc(widget.officeId)
              .collection('clients')
              .doc(widget.clientId)
              .get();

      if (!clientDoc.exists) {
        throw Exception('Cliente no encontrado en la oficina del propietario');
      }

      final clientData = clientDoc.data();
      final clientCreatorUid = clientData?['createdBy'] ?? ownerId;

      // 3. Generar ID para el crédito
      final creditId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();

      // 4. Calcular fechas de pago
      final paymentDates = _calculatePaymentDates(now, _method, _selectedDay);
      final paymentSchedule = paymentDates.map((date) => date.toIso8601String()).toList();

      // 5. Datos del crédito
      final creditData = {
        'clientId': widget.clientId,
        'officeId': widget.officeId,
        'createdBy': widget.userId,
        'createdAt': Timestamp.now(),
        'credit': _credit,
        'interest': _interestPercent,
        'method': _method,
        'cuot': _cuot,
        'isActive': true,
        'paymentSchedule': paymentSchedule,
        'nextPaymentIndex': 0,
        'lastPaymentDate': null,
        'daysOverdue': 0,
        'accumulatedInterest': 0.0,
        'order': 0, // Nuevo campo para el orden personalizado
        if (_method == 'Semanal') 'day': _selectedDay,
      };

      // 6. Guardar el crédito en la estructura del owner
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .collection('offices')
          .doc(widget.officeId)
          .collection('clients')
          .doc(widget.clientId)
          .collection('credits')
          .doc(creditId)
          .set(creditData);

      // 7. Actualizar referencia en el cliente
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .collection('offices')
          .doc(widget.officeId)
          .collection('clients')
          .doc(widget.clientId)
          .update({'lastCreditId': creditId, 'updatedAt': Timestamp.now()});

      // Cerrar diálogo de carga y mostrar éxito
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crédito creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatNumber(String value) {
    if (value.isEmpty) return '';

    // Eliminar todos los caracteres no numéricos
    String cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');

    // Convertir a número y formatear
    try {
      final number = int.parse(cleanValue);
      return NumberFormat('#,##0', 'es_CO').format(number);
    } catch (e) {
      return value; // Si hay error, devolver el valor original
    }
  }

  Widget _buildFormField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon,
    TextInputType keyboardType,
    String? Function(String?)? validator,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: validator,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
    IconData icon, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items:
            items.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Text(
            '\$${NumberFormat('#,##0', 'es_CO').format(value)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo crédito'),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Información del Crédito',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        context,
                        'Valor del crédito',
                        _creditController,
                        Icons.attach_money,
                        TextInputType.numberWithOptions(
                          decimal: false,
                        ), // Teclado numérico sin decimales
                        (value) {
                          if (value == null || value.isEmpty) return 'Campo requerido';
                          final cleanValue = value.replaceAll('.', '');
                          if (double.tryParse(cleanValue) == null) return 'Ingrese un valor válido';
                          if (double.parse(cleanValue) <= 0)
                            return 'El valor debe ser mayor a cero';
                          return null;
                        },
                      ),
                      _buildFormField(
                        context,
                        'Interés %',
                        _interestController,
                        Icons.percent,
                        TextInputType.number,
                        (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      _buildDropdownField(
                        'Forma de pago',
                        _method,
                        ['Diario', 'Semanal', 'Quincenal', 'Mensual'],
                        (value) => setState(() {
                          _method = value!;
                          if (_method != 'Semanal') _selectedDay = null;
                        }),
                        Icons.payment,
                      ),
                      _buildFormField(
                        context,
                        'Número de cuotas',
                        _cuotController,
                        Icons.format_list_numbered,
                        TextInputType.number,
                        (value) {
                          if (value == null || value.isEmpty) return 'Campo requerido';
                          if (int.tryParse(value) == null || int.parse(value) <= 0) {
                            return 'Ingrese un número válido mayor a 0';
                          }
                          return null;
                        },
                      ),
                      if (_method == 'Semanal') ...[
                        const SizedBox(height: 8),
                        _buildDropdownField(
                          'Día de la semana',
                          _selectedDay,
                          _daysOfWeek,
                          (value) => setState(() => _selectedDay = value),
                          Icons.calendar_today,
                          validator: (value) {
                            if (_method == 'Semanal' && (value == null || value.isEmpty)) {
                              return 'Selecciona un día';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Resumen del cálculo
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Resumen del Crédito',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow('Interés:', _interest),
                      _buildSummaryRow('Saldo total:', _total),
                      _buildSummaryRow('Valor de la cuota:', _installment),
                    ],
                  ),
                ),
              ),

              // Botón de guardar
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveCredit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'GUARDAR CRÉDITO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
