import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

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
                  // Navegar a pantalla de renovación
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => RenewMembershipScreen()));
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('RENOVAR MEMBRESÍA'),
              ),
            ],
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
}
