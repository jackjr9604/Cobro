import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';
import '../../../utils/app_theme.dart';

class EditOfficeScreen extends StatefulWidget {
  final String officeId;
  final Map<String, dynamic> initialData;

  const EditOfficeScreen({super.key, required this.officeId, required this.initialData});

  @override
  State<EditOfficeScreen> createState() => _EditOfficeScreenState();
}

class _EditOfficeScreenState extends State<EditOfficeScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cellphoneController;
  late final TextEditingController _address2Controller;
  late final TextEditingController _cellphone2Controller;

  final _firestore = FirebaseFirestore.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name'] ?? '');
    _addressController = TextEditingController(text: widget.initialData['address'] ?? '');
    _cellphoneController = TextEditingController(text: widget.initialData['cellphone'] ?? '');
    _address2Controller = TextEditingController(text: widget.initialData['address2'] ?? '');
    _cellphone2Controller = TextEditingController(text: widget.initialData['cellphone2'] ?? '');
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    await _firestore.collection('offices').doc(widget.officeId).update({
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'cellphone': _cellphoneController.text.trim(),
      'address2': _address2Controller.text.trim(),
      'cellphone2': _cellphone2Controller.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oficina actualizada')));

    Navigator.pop(context);
  }

  Widget _buildField(String label, TextEditingController controller, {bool optional = false}) {
    final fontSize = Responsive.isMobile(context) ? 14.0 : 16.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.isMobile(context) ? 8.0 : 12.0),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: fontSize),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: fontSize),
          border: const OutlineInputBorder(),
          suffixIcon: optional ? const Icon(Icons.info_outline) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = Responsive.screenWidth(context);
    final contentWidth = Responsive.isMobile(context) ? screenWidth * 0.95 : 600.0;
    final padding = Responsive.isMobile(context) ? 16.0 : 24.0;
    final titleFontSize = Responsive.isMobile(context) ? 20.0 : 26.0;

    return Scaffold(
      appBar: AppBar(title: Text('Editar Oficina', style: TextStyle(fontSize: titleFontSize))),
      body:
          _isSaving
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: Container(
                    width: contentWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!Responsive.isMobile(context))
                          BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2),
                      ],
                    ),
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildField('Nombre de la oficina', _nameController),
                        _buildField('Dirección principal', _addressController),
                        _buildField('Teléfono celular', _cellphoneController),
                        const SizedBox(height: 16),
                        const Text('Campos opcionales'),
                        _buildField('Segunda dirección', _address2Controller, optional: true),
                        _buildField('Teléfono alternativo', _cellphone2Controller, optional: true),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _saveChanges,
                          icon: const Icon(Icons.save),
                          label: const Text(
                            'Guardar cambios',
                            style: TextStyle(
                              fontFamily: AppTheme.primaryFont,
                              color: AppTheme.neutroColor,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.isMobile(context) ? 14 : 18,
                            ),
                            textStyle: TextStyle(fontSize: Responsive.isMobile(context) ? 16 : 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
