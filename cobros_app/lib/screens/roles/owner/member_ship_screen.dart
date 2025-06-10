import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  File? _comprobanteImage;
  final TextEditingController _transactionIdController = TextEditingController();
  bool _showPaymentSection = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    setState(() {
      _userData = doc.data();
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _comprobanteImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _sendViaWhatsApp() async {
    if (_transactionIdController.text.isEmpty && _comprobanteImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa el número de transacción o adjunta un comprobante'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final userName = _userData?['displayName'] ?? 'Usuario';
    final userEmail = user?.email ?? 'No especificado';
    final uid = _userData?['uid'] ?? 'uid';

    // Construir el mensaje
    String message = 'Hola, quiero renovar mi membresía.\n\n';
    message += '*Nombre:* $userName\n';
    message += '*Email:* $userEmail\n\n';
    message += '*UID:* $uid\n\n';

    if (_transactionIdController.text.isNotEmpty) {
      message += '*Número de transacción:* ${_transactionIdController.text}\n';
    } else {
      message += '(Adjunté comprobante de pago)\n';
    }

    message += '\nPor favor verifica mi pago. ¡Gracias!';

    // Número de WhatsApp de la empresa (reemplaza con tu número)
    const whatsappNumber = '573506191443'; // Formato internacional sin signos

    final urlsToTry = [
      // Intentar con el esquema 'whatsapp://'
      Uri.parse('whatsapp://send?phone=$whatsappNumber&text=${Uri.encodeComponent(message)}'),
      // Intentar con el esquema 'https://wa.me/'
      Uri.parse('https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}'),
      // Intentar solo con el número (para que el usuario elija cómo abrirlo)
      Uri.parse(
        'https://api.whatsapp.com/send?phone=$whatsappNumber&text=${Uri.encodeComponent(message)}',
      ),
    ];

    bool whatsappOpened = false;

    for (final url in urlsToTry) {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          whatsappOpened = true;
          break;
        }
      } catch (e) {
        debugPrint('Error al intentar abrir WhatsApp: $e');
      }
    }

    if (!whatsappOpened) {
      // Si no se pudo abrir WhatsApp, mostrar opciones al usuario
      _showWhatsAppNotInstalledDialog(context, message, whatsappNumber);
    }
  }

  void _showWhatsAppNotInstalledDialog(
    BuildContext context,
    String message,
    String whatsappNumber,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('No se pudo abrir WhatsApp'),
            content: const Text(
              'Parece que WhatsApp no está instalado o no se pudo abrir. '
              'Puedes copiar la información y enviarla manualmente o instalar WhatsApp.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Copiar el mensaje al portapapeles
                  Clipboard.setData(ClipboardData(text: 'Número: $whatsappNumber\n\n$message'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Información copiada al portapapeles')),
                  );
                },
                child: const Text('COPIAR INFORMACIÓN'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Abrir Play Store/App Store para instalar WhatsApp
                  launchUrl(
                    Uri.parse(
                      Platform.isAndroid
                          ? 'https://play.google.com/store/apps/details?id=com.whatsapp'
                          : 'https://apps.apple.com/app/whatsapp-messenger/id310633997',
                    ),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('INSTALAR WHATSAPP'),
              ),
            ],
          ),
    );
  }

  Widget _buildStatusIndicator(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.green : Colors.red, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.error,
            color: isActive ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'ACTIVA' : 'INACTIVA',
            style: TextStyle(
              color: isActive ? Colors.green[800] : Colors.red[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(String title, Timestamp? date) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              date != null ? DateFormat('dd MMM yyyy').format(date.toDate()) : 'No definida',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Realizar pago manual',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Información de pago Nequi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Realiza el pago a nuestro número Nequi:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_android, color: Colors.purple),
                      const SizedBox(width: 8),
                      SelectableText(
                        '3506191443',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          // Copiar al portapapeles
                          Clipboard.setData(const ClipboardData(text: '3506191443'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Número copiado al portapapeles')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Valor a pagar: \$50.000 COP',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Después de realizar el pago, por favor:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Opción 1: Subir comprobante (para adjuntar en WhatsApp)

            // Opción 2: Ingresar número de transacción
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Ingresa el número de transacción Nequi:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _transactionIdController,
                  decoration: const InputDecoration(
                    hintText: 'Número de transacción Nequi',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2.Dar en el boton de enviar, seras redirigido a un mensaje de Whatsapp, no edites nada y envia el mensaje, opcionalmente adjunta el pantallazo de la transaccion para agilizar el proceso de renovación:',
                ),
                const SizedBox(height: 8),
              ],
            ),

            const SizedBox(height: 20),

            // Botón para enviar por WhatsApp
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendViaWhatsApp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('ENVIAR', style: TextStyle(color: Colors.white)),
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              'Nota: Al hacer clic se abrirá WhatsApp con un mensaje predefinido. '
              'Si adjuntaste una imagen, deberás enviarla manualmente en la conversación.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeStatus = _userData?['activeStatus'] as Map<String, dynamic>?;
    final isActive = activeStatus?['isActive'] ?? false;
    final startDate = activeStatus?['startDate'] as Timestamp?;
    final endDate = activeStatus?['endDate'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Membresía'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadUserData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Estado actual
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Estado de tu membresía',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusIndicator(isActive),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDateCard('Fecha de inicio', startDate),
                        _buildDateCard('Fecha de fin', endDate),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Barra de progreso si está activa
            if (isActive && endDate != null)
              Column(
                children: [
                  const Text(
                    'Tiempo restante de tu membresía',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _calculateProgress(startDate!, endDate),
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRemainingTime(endDate),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

            // Acciones
            if (!isActive) ...[
              const SizedBox(height: 32),
              const Text(
                'Tu membresía ha expirado',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showPaymentSection = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('RENOVAR MEMBRESÍA'),
              ),
            ],

            // Sección de pago
            if (_showPaymentSection) _buildPaymentSection(),
          ],
        ),
      ),
    );
  }

  double _calculateProgress(Timestamp start, Timestamp end) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    if (now >= endMs) return 1.0;
    if (now <= startMs) return 0.0;

    return (now - startMs) / (endMs - startMs);
  }

  String _getRemainingTime(Timestamp endDate) {
    final now = DateTime.now();
    final end = endDate.toDate();

    if (now.isAfter(end)) return 'Membresía vencida';

    final difference = end.difference(now);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} meses restantes';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} días restantes';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} horas restantes';
    } else {
      return 'Menos de 1 hora restante';
    }
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
  }
}
