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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Oficina actualizada correctamente',
          style: TextStyle(fontSize: Responsive.isMobile(context) ? 14 : 16),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool optional = false,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final fontSize = Responsive.isMobile(context) ? 14.0 : 16.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.isMobile(context) ? 8.0 : 12.0),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: fontSize),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: fontSize, color: Colors.grey[600]),
          prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).primaryColor) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          suffixIcon:
              optional
                  ? Tooltip(
                    message: 'Campo opcional',
                    child: Icon(Icons.info_outline, color: Colors.grey[500]),
                  )
                  : null,
          filled: true,
          fillColor: Colors.grey[50],
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
      appBar: AppBar(
        title: Text('Editar Oficina', style: TextStyle(fontSize: titleFontSize)),

        iconTheme: IconThemeData(color: Colors.white),
      ),

      body:
          _isSaving
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      'Guardando cambios...',
                      style: TextStyle(
                        fontSize: Responsive.isMobile(context) ? 16 : 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
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
                        Text(
                          'Información de la Oficina',
                          style: TextStyle(
                            fontSize: titleFontSize * 0.8,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        _buildField('Nombre de la oficina', _nameController, icon: Icons.business),
                        _buildField(
                          'Dirección principal',
                          _addressController,
                          icon: Icons.location_on,
                        ),
                        _buildField(
                          'Teléfono celular',
                          _cellphoneController,
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Información Adicional (Opcional)',
                            style: TextStyle(
                              fontSize: Responsive.isMobile(context) ? 14 : 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          'Segunda dirección',
                          _address2Controller,
                          icon: Icons.location_city,
                          optional: true,
                        ),
                        _buildField(
                          'Teléfono alternativo',
                          _cellphone2Controller,
                          icon: Icons.phone_android,
                          optional: true,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveChanges,
                          icon: Icon(Icons.save, size: Responsive.isMobile(context) ? 20 : 24),
                          label: Text(
                            'GUARDAR CAMBIOS',
                            style: TextStyle(
                              fontSize: Responsive.isMobile(context) ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.isMobile(context) ? 16 : 20,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
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
