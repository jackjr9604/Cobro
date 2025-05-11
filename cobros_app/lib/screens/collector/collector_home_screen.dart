import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';

class CollectorHomeScreen extends StatefulWidget {
  const CollectorHomeScreen({super.key});

  @override
  State<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends State<CollectorHomeScreen> {
  final AuthService _authService = AuthService();
  String? _officeId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOfficeData();
  }

  // Cargar datos de oficina y usuario
  Future<void> _loadOfficeData() async {
    try {
      final userData = await _authService.getCurrentUserData();
      setState(() {
        _officeId =
            userData?['officeId']; // Suponiendo que 'officeId' es uno de los campos en Firestore
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Cobros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOfficeData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _officeId == null
              ? const Center(child: Text('No estás asignado a una oficina'))
              : _buildCollectorContent(),
    );
  }

  // Contenido principal de la pantalla
  Widget _buildCollectorContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Resumen del Día',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('payments')
                            .where('officeId', isEqualTo: _officeId)
                            .where(
                              'collectorId',
                              isEqualTo: _authService.currentUser?.uid,
                            )
                            .where(
                              'date',
                              isEqualTo: DateFormat(
                                'yyyy-MM-dd',
                              ).format(DateTime.now()),
                            )
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final total = snapshot.data!.docs.fold<double>(
                        0,
                        (sum, doc) => sum + (doc['amount'] as num).toDouble(),
                      );

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            'Cobros',
                            snapshot.data!.docs.length.toString(),
                          ),
                          _buildSummaryItem(
                            'Total',
                            '\$${total.toStringAsFixed(2)}',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Últimos Cobros',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _buildRecentPayments(),
            ],
          ),
        ),
      ],
    );
  }

  // Crear el item de resumen
  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Mostrar los últimos cobros
  Widget _buildRecentPayments() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('payments')
              .where('officeId', isEqualTo: _officeId)
              .where('collectorId', isEqualTo: _authService.currentUser?.uid)
              .orderBy('date', descending: true)
              .limit(10)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay cobros registrados'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final payment = snapshot.data!.docs[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(payment['clientName']),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy').format(payment['date'].toDate()),
                ),
                trailing: Text(
                  '\$${payment['amount'].toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
